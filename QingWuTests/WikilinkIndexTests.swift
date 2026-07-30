import XCTest

@testable import QingWu

/// Exercises the pure-string ingestion path of `WikilinkIndex.updateNote`,
/// which does not require `Note`/`Storage` bootstrapping. This is what runs
/// during live editing and is the regression surface most worth covering.
@MainActor
final class WikilinkIndexTests: XCTestCase {

    private var index: WikilinkIndex { WikilinkIndex.shared }

    // XCTestCase's setUp/tearDown across Swift 6.1's strict concurrency
    // are awkward: the sync variants are nonisolated (can't touch the
    // @MainActor index), and `super.setUp()` in the async variants flags
    // XCTestCase as non-Sendable. Sidestep both by cleaning the shared
    // index inline at the start of each test instead.
    private func resetIndex() {
        for title in ["A", "B", "C", "D"] {
            // removeNote on a non-existent title is a no-op, so this is
            // safe even on a fresh index.
            index.removeNote(title: title)
        }
    }

    func testUpdateNoteRecordsOutlinks() {
        resetIndex()
        index.updateNote(title: "A", content: "see [[B]] and [[C]]")

        XCTAssertEqual(Set(index.getOutlinks(for: "A")), Set(["B", "C"]))
    }

    func testBacklinksReverseUpdateNote() {
        resetIndex()
        index.updateNote(title: "A", content: "links to [[B]]")
        index.updateNote(title: "C", content: "also links to [[B]]")

        XCTAssertEqual(Set(index.getBacklinks(for: "B")), Set(["A", "C"]))
    }

    func testUpdateNoteReplacesPreviousOutlinks() {
        resetIndex()
        index.updateNote(title: "A", content: "[[B]]")
        index.updateNote(title: "A", content: "[[C]]")

        XCTAssertEqual(index.getOutlinks(for: "A"), ["C"])
        XCTAssertTrue(index.getBacklinks(for: "B").isEmpty, "stale backlink to B should be cleared")
        XCTAssertEqual(index.getBacklinks(for: "C"), ["A"])
    }

    func testRemoveNoteClearsBothDirections() {
        resetIndex()
        index.updateNote(title: "A", content: "[[B]]")
        index.removeNote(title: "A")

        XCTAssertTrue(index.getOutlinks(for: "A").isEmpty)
        XCTAssertTrue(index.getBacklinks(for: "B").isEmpty)
    }

    func testWhitespaceInsideBracketsIsTrimmed() {
        resetIndex()
        index.updateNote(title: "A", content: "[[  B  ]]")

        XCTAssertEqual(index.getOutlinks(for: "A"), ["B"])
    }

    func testEmptyContentYieldsNoLinks() {
        resetIndex()
        index.updateNote(title: "A", content: "no wikilinks here")

        XCTAssertTrue(index.getOutlinks(for: "A").isEmpty)
    }

    func testMultipleOccurrencesOfSameLinkAreDeduped() {
        resetIndex()
        index.updateNote(title: "A", content: "[[B]] then [[B]] then [[B]]")

        XCTAssertEqual(index.getOutlinks(for: "A"), ["B"])
    }

    // MARK: - Logseq-style targets

    func testAliasIndexesUnderTarget() {
        resetIndex()
        index.updateNote(title: "A", content: "see [[B|pretty label]]")

        XCTAssertEqual(index.getOutlinks(for: "A"), ["B"])
    }

    func testCanonicalTargetStripsAliasAndWhitespace() {
        XCTAssertEqual(WikilinkIndex.canonicalTarget("namespace/Page|label"), "namespace/Page")
        XCTAssertEqual(WikilinkIndex.canonicalTarget("  My Page  "), "My Page")
        XCTAssertEqual(WikilinkIndex.canonicalTarget("Plain"), "Plain")
    }

    func testTitleCandidatesEncodeLogseqNamespace() {
        XCTAssertEqual(WikilinkIndex.titleCandidates(for: "Plain"), ["Plain"])
        XCTAssertEqual(
            WikilinkIndex.titleCandidates(for: "namespace/Sub Page"),
            ["namespace/Sub Page", "namespace___Sub Page"])
    }

    func testResolveAllMatchesCaseInsensitively() throws {
        let note = try makeTitledNote("My Page")
        let matches = WikilinkIndex.resolveAll("my page", in: [note])

        XCTAssertEqual(matches.count, 1)
        XCTAssertTrue(matches[0] === note)
    }

    func testResolveAllPrefersExactCase() throws {
        let lower = try makeTitledNote("my page")
        let upper = try makeTitledNote("My Page")
        let matches = WikilinkIndex.resolveAll("My Page", in: [lower, upper])

        XCTAssertTrue(matches.first === upper)
    }

    func testResolveAllMapsLogseqNamespaceFilename() throws {
        // Logseq stores [[work/Plans]] as work___Plans.md on disk.
        let note = try makeTitledNote("work___Plans")
        let matches = WikilinkIndex.resolveAll("work/Plans", in: [note])

        XCTAssertEqual(matches.count, 1)
        XCTAssertTrue(matches[0] === note)
    }

    private func makeTitledNote(_ title: String) throws -> Note {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QingWuWikilinkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let project = Project(url: dir, label: "test")
        let note = Note(url: dir.appendingPathComponent("\(title).md"), with: project)
        note.title = title
        return note
    }

    // MARK: - Block refs

    func testExtractBlocksFindsOwningBlock() {
        let content = "- TODO Write the release notes\n  id:: 6651e4f2-9a2b\n  collapsed:: true\n- Other block"
        let blocks = WikilinkIndex.extractBlocks(from: content)

        XCTAssertEqual(blocks["6651e4f2-9a2b"], "TODO Write the release notes")
    }

    func testExtractBlocksSkipsPropertyOnlyContext() {
        // No owning block above the id → no entry.
        let blocks = WikilinkIndex.extractBlocks(from: "id:: orphan-1234")
        XCTAssertTrue(blocks.isEmpty)
    }

    func testResolveBlockAfterUpdateNote() {
        resetIndex()
        index.updateNote(title: "A", content: "- Ship it\n  id:: abc-def-123")

        XCTAssertEqual(index.resolveBlock("abc-def-123"), "Ship it")
    }

    func testUpdateNoteReplacesOldBlocks() {
        resetIndex()
        index.updateNote(title: "A", content: "- Old\n  id:: abc-def-123")
        index.updateNote(title: "A", content: "- New content without ids")

        XCTAssertNil(index.resolveBlock("abc-def-123"))
    }

    func testRemoveNoteClearsBlocks() {
        resetIndex()
        index.updateNote(title: "A", content: "- Ship it\n  id:: abc-def-123")
        index.removeNote(title: "A")

        XCTAssertNil(index.resolveBlock("abc-def-123"))
    }

    // MARK: - Backlink key normalization

    func testBacklinkMergesNamespaceEncodings() {
        resetIndex()
        // The page on disk is work___Plans.md (title "work___Plans"); the
        // link was written Logseq-style as [[work/Plans]].
        index.updateNote(title: "A", content: "see [[work/Plans]]")

        XCTAssertEqual(index.getBacklinks(for: "work___Plans"), ["A"])
        XCTAssertEqual(index.getBacklinks(for: "work/Plans"), ["A"])
    }

    func testBacklinkMergesCaseVariants() {
        resetIndex()
        index.updateNote(title: "A", content: "see [[my page]]")
        index.updateNote(title: "B", content: "also [[My Page]]")

        XCTAssertEqual(Set(index.getBacklinks(for: "My Page")), Set(["A", "B"]))
    }

    func testBacklinkFromAliasLink() {
        resetIndex()
        index.updateNote(title: "A", content: "see [[B|pretty label]]")

        XCTAssertEqual(index.getBacklinks(for: "B"), ["A"])
    }
}

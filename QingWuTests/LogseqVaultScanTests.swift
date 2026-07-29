import XCTest

@testable import QingWu

/// Logseq vault compatibility: a vault carries internals (`logseq/` config and
/// backups, `assets/` attachments, hidden sync dirs) that must never surface as
/// projects or notes, while `journals/` and `pages/` stay fully visible.
final class LogseqVaultScanTests: XCTestCase {

    private var vaultDir: URL!
    private let extensions = ["md", "markdown", "txt"]

    override func setUp() {
        super.setUp()
        vaultDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QingWuLogseqVaultTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: vaultDir)
        super.tearDown()
    }

    private func makeFile(_ relativePath: String) {
        let url = vaultDir.appendingPathComponent(relativePath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
    }

    /// Builds a typical Logseq vault layout under `vaultDir`.
    private func makeVault() {
        makeFile("journals/2026_07_29.md")
        makeFile("pages/Reading Notes.md")
        makeFile("logseq/config.edn")
        makeFile("logseq/bak/pages/Reading Notes.md")
        makeFile("logseq/bak/journals/2026_07_28.md")
        makeFile("assets/image.png")
        makeFile("assets/copied-note.md")
        makeFile(".stversions/journals/2026_07_29.md")
    }

    func testReservedFolderNamesCoverLogseqInternals() {
        for name in ["logseq", "assets", "i", "files", ".Trash"] {
            XCTAssertTrue(Storage.reservedFolderNames.contains(name), "\(name) should be reserved")
        }
        XCTAssertFalse(Storage.reservedFolderNames.contains("journals"))
        XCTAssertFalse(Storage.reservedFolderNames.contains("pages"))
    }

    @MainActor
    func testSubFolderDiscoverySkipsLogseqAndAssets() {
        makeVault()

        let subFolders = Storage.sharedInstance().getSubFolders(url: vaultDir)?
            .compactMap { ($0 as URL).lastPathComponent } ?? []

        XCTAssertTrue(subFolders.contains("journals"))
        XCTAssertTrue(subFolders.contains("pages"))
        XCTAssertFalse(subFolders.contains("logseq"))
        XCTAssertFalse(subFolders.contains("assets"))
        XCTAssertFalse(subFolders.contains(".stversions"))
    }

    @MainActor
    func testImportScanSkipsLogseqBackupsAndAssets() {
        makeVault()

        let files = ViewController.collectImportableFiles(from: [vaultDir], allowedExtensions: extensions)
        let names = files.map { $0.lastPathComponent }.sorted()

        XCTAssertEqual(names, ["2026_07_29.md", "Reading Notes.md"])
    }

    /// Saving through the normal note path must be byte-preserving for
    /// Logseq-flavored content: `id::` / `collapsed::` properties, block refs,
    /// task markers, and CRLF line endings all round-trip untouched.
    @MainActor
    func testSavePreservesLogseqContentByteForByte() throws {
        let content = "- TODO Write the release notes\r\n  id:: 6651e4f2-9a2b-4c7d-8f00-1a2b3c4d5e6f\r\n  collapsed:: true\r\n- DONE Review ((6651e4f2-9a2b-4c7d-8f00-1a2b3c4d5e6f))\r\n- See [[Another Page]]\r\n"
        let noteURL = vaultDir.appendingPathComponent("pages/Byte Preserving.md")
        try FileManager.default.createDirectory(at: noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: noteURL, atomically: true, encoding: .utf8)

        let project = Project(url: noteURL.deletingLastPathComponent(), label: "pages")
        let note = Note(url: noteURL, with: project)
        note.save(attributed: NSAttributedString(string: content))
        note.flushPendingSave(globalStorage: false)

        let saved = try String(contentsOf: noteURL, encoding: .utf8)
        XCTAssertEqual(saved, content)
    }
}

import XCTest

@testable import QingWu

/// Logseq-flavored constructs in preview: task keywords become status badges,
/// `key:: value` block properties become muted property lines, and Logseq's
/// reading-mode-hidden properties (`id::`, `collapsed::`) are dropped.
/// Fenced/inline code must stay verbatim.
final class LogseqRenderTests: XCTestCase {

    // MARK: - Task badges

    func testTodoBecomesBadge() {
        let html = renderMarkdownHTML(markdown: "- TODO Write the release notes", useGithubLineBreak: false)!

        XCTAssertTrue(html.contains(#"<span class="logseq-task logseq-task-todo">TODO</span>"#))
        XCTAssertTrue(html.contains("Write the release notes"))
    }

    func testAllTaskKeywordsBecomeBadges() {
        for keyword in ["TODO", "DOING", "DONE", "NOW", "LATER", "WAITING", "CANCELED"] {
            let html = renderMarkdownHTML(markdown: "- \(keyword) body", useGithubLineBreak: false)!
            XCTAssertTrue(
                html.contains("logseq-task-\(keyword.lowercased())"),
                "missing badge class for \(keyword)")
        }
    }

    func testKeywordMidSentenceIsNotABadge() {
        let html = renderMarkdownHTML(markdown: "- Remember the TODO list format", useGithubLineBreak: false)!

        XCTAssertFalse(html.contains("logseq-task"))
    }

    func testTodoInsideCodeFenceStaysVerbatim() {
        let markdown = """
            ```
            - TODO not a task
            ```
            """
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertFalse(html.contains("logseq-task"))
        XCTAssertTrue(html.contains("TODO not a task"))
    }

    // MARK: - Block properties

    func testHiddenPropertiesAreDropped() {
        let markdown = """
            - TODO Ship it
              id:: 6651e4f2-9a2b-4c7d-8f00-1a2b3c4d5e6f
              collapsed:: true
            """
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertFalse(html.contains("6651e4f2"), "id:: value must not render")
        XCTAssertFalse(html.contains("collapsed"))
    }

    func testVisiblePropertyRendersMuted() {
        let html = renderMarkdownHTML(markdown: "author:: Tw93", useGithubLineBreak: false)!

        XCTAssertTrue(html.contains(#"<span class="logseq-prop">"#))
        XCTAssertTrue(html.contains(#"<span class="logseq-prop-key">author</span>"#))
        XCTAssertTrue(html.contains(#"<span class="logseq-prop-value">Tw93</span>"#))
    }

    func testPropertyInsideCodeFenceStaysVerbatim() {
        let markdown = """
            ```
            id:: keep-me-verbatim
            ```
            """
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertTrue(html.contains("keep-me-verbatim"))
        XCTAssertFalse(html.contains("logseq-prop"))
    }

    // MARK: - Tab-indented outlines

    /// Logseq nests blocks with tabs; without expansion cmark treats the whole
    /// outline as an indented code block.
    func testTabIndentedOutlineRendersAsList() {
        let markdown = "- parent\n\t- child [[Some Page]]\n\t- second child"
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertTrue(html.contains("<ul"), "tab-indented outline must render as a list, got: \(html)")
        XCTAssertTrue(html.contains("child"))
        XCTAssertFalse(html.contains("<pre"))
    }

    func testTopLevelTabbedBlockRendersAsList() {
        // Logseq demo graphs indent even top-level blocks with a tab.
        let markdown = "## Welcome\n\t- Click on [[Project/PKM Workshop]]"
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertTrue(html.contains("<ul"))
        XCTAssertFalse(html.contains("<pre"))
    }

    func testTabsInsideCodeFenceArePreserved() {
        let markdown = "```\n\t- not a list\n```"
        let html = renderMarkdownHTML(markdown: markdown, useGithubLineBreak: false)!

        XCTAssertTrue(html.contains("<pre"))
        XCTAssertTrue(html.contains("- not a list"))
        XCTAssertFalse(html.contains("<ul"))
    }

    // MARK: - Block refs

    func testBlockRefExpandsWithResolver() {
        let html = renderMarkdownHTML(
            markdown: "See ((abc-123))",
            useGithubLineBreak: false,
            blockResolver: { uuid in uuid == "abc-123" ? "the referenced block" : nil })!

        XCTAssertTrue(html.contains(#"<span class="logseq-blockref">the referenced block</span>"#))
        XCTAssertFalse(html.contains("((abc-123))"))
    }

    func testBlockRefStaysLiteralWithoutResolver() {
        let html = renderMarkdownHTML(markdown: "See ((abc-123))", useGithubLineBreak: false)!

        XCTAssertTrue(html.contains("((abc-123))"))
        XCTAssertFalse(html.contains("logseq-blockref"))
    }

    func testBlockRefStaysLiteralWhenUnknown() {
        let html = renderMarkdownHTML(
            markdown: "See ((abc-123))",
            useGithubLineBreak: false,
            blockResolver: { _ in nil })!

        XCTAssertTrue(html.contains("((abc-123))"))
    }

    func testBlockRefInsideCodeFenceStaysVerbatim() {
        let markdown = "```\n((abc-123))\n```"
        let html = renderMarkdownHTML(
            markdown: markdown,
            useGithubLineBreak: false,
            blockResolver: { _ in "should not appear" })!

        XCTAssertTrue(html.contains("((abc-123))"))
        XCTAssertFalse(html.contains("should not appear"))
    }
}

import Foundation

@MainActor
final class WikilinkIndex: ObservableObject {
    static let shared = WikilinkIndex()

    private var outlinks: [String: Set<String>] = [:]
    private var inlinks: [String: Set<String>] = [:]

    private init() {}

    func rebuild(notes: [Note]) {
        outlinks.removeAll()
        inlinks.removeAll()

        for note in notes {
            let title = note.title
            let links = extractWikilinks(from: note.content.string)

            outlinks[title] = links

            for target in links {
                inlinks[target, default: []].insert(title)
            }
        }
    }

    func getBacklinks(for noteTitle: String) -> [String] {
        Array(inlinks[noteTitle] ?? []).sorted()
    }

    func getOutlinks(for noteTitle: String) -> [String] {
        Array(outlinks[noteTitle] ?? []).sorted()
    }

    /// Target group only; an optional `|label` alias (Logseq/Obsidian style)
    /// is matched but never captured, so `[[a|b]]` indexes under `a`.
    private static let wikilinkRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]"#)

    private func extractWikilinks(from text: String) -> Set<String> {
        guard let regex = Self.wikilinkRegex else {
            return []
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var links = Set<String>()

        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let link = String(text[range]).trimmingCharacters(in: .whitespaces)
                links.insert(link)
            }
        }

        return links
    }

    func updateNote(title: String, content: String) {
        let links = extractWikilinks(from: content)

        if let oldLinks = outlinks[title] {
            for oldTarget in oldLinks where !links.contains(oldTarget) {
                inlinks[oldTarget]?.remove(title)
            }
        }

        outlinks[title] = links

        for target in links {
            inlinks[target, default: []].insert(title)
        }
    }

    func removeNote(title: String) {
        if let links = outlinks[title] {
            for target in links {
                inlinks[target]?.remove(title)
            }
        }
        outlinks.removeValue(forKey: title)
        inlinks.removeValue(forKey: title)
    }

    // MARK: - Logseq-style target resolution

    /// Canonical wikilink target: strips an optional `|alias` suffix and trims.
    /// `[[namespace/Page|label]]` resolves as `namespace/Page`.
    static func canonicalTarget(_ raw: String) -> String {
        let target = raw.components(separatedBy: "|").first ?? raw
        return target.trimmingCharacters(in: .whitespaces)
    }

    /// Title forms a Logseq-style target may correspond to on disk, most
    /// specific first: the verbatim title (QingWu maps `:` in filenames to
    /// `/` in titles), then Logseq's namespace encoding (`/` → `___` in
    /// filenames). Mirrored by QingWuMobile `NoteFileStore.titleCandidates` —
    /// change both in the same commit.
    static func titleCandidates(for target: String) -> [String] {
        let verbatim = canonicalTarget(target)
        let logseqNamespace = verbatim.replacingOccurrences(of: "/", with: "___")
        return logseqNamespace == verbatim ? [verbatim] : [verbatim, logseqNamespace]
    }

    /// All notes whose title matches any candidate, case-insensitively.
    /// Exact-case hits sort first so callers can prefer them.
    static func resolveAll(_ raw: String, in notes: [Note]) -> [Note] {
        let candidates = titleCandidates(for: raw)
        var exact: [Note] = []
        var folded: [Note] = []
        for note in notes {
            if candidates.contains(note.title) {
                exact.append(note)
            } else if candidates.contains(where: { $0.compare(note.title, options: .caseInsensitive) == .orderedSame }) {
                folded.append(note)
            }
        }
        return exact + folded
    }
}

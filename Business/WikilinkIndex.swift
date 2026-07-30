import Foundation

@MainActor
final class WikilinkIndex: ObservableObject {
    static let shared = WikilinkIndex()

    private var outlinks: [String: Set<String>] = [:]
    private var inlinks: [String: Set<String>] = [:]

    /// Logseq block refs: `id:: <uuid>` property → owning block's first line.
    private var blockIndex: [String: String] = [:]
    private var noteBlocks: [String: Set<String>] = [:]

    private init() {}

    func rebuild(notes: [Note]) {
        outlinks.removeAll()
        inlinks.removeAll()
        blockIndex.removeAll()
        noteBlocks.removeAll()

        for note in notes {
            let title = note.title
            let links = extractWikilinks(from: note.content.string)

            outlinks[title] = links

            for target in links {
                inlinks[Self.normalizeKey(target), default: []].insert(title)
            }

            indexBlocks(from: note.content.string, title: title)
        }
    }

    func getBacklinks(for noteTitle: String) -> [String] {
        Array(inlinks[Self.normalizeKey(noteTitle)] ?? []).sorted()
    }

    func getOutlinks(for noteTitle: String) -> [String] {
        Array(outlinks[noteTitle] ?? []).sorted()
    }

    /// Target group only; an optional `|label` alias (Logseq/Obsidian style)
    /// is matched but never captured, so `[[a|b]]` indexes under `a`.
    private static let wikilinkRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]"#)

    /// Backlink keys are normalized so the same page is found regardless of
    /// how the link was written: alias stripped, Logseq `___` namespace
    /// encoding unified with `/`, and case folded. Outlink keys stay exact
    /// titles (they key per-note state); only inlink keys normalize.
    static func normalizeKey(_ raw: String) -> String {
        canonicalTarget(raw)
            .replacingOccurrences(of: "___", with: "/")
            .lowercased()
    }

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
                inlinks[Self.normalizeKey(oldTarget)]?.remove(title)
            }
        }

        outlinks[title] = links

        for target in links {
            inlinks[Self.normalizeKey(target), default: []].insert(title)
        }

        if let oldUUIDs = noteBlocks[title] {
            for uuid in oldUUIDs {
                blockIndex.removeValue(forKey: uuid)
            }
        }
        indexBlocks(from: content, title: title)
    }

    // MARK: - Block refs

    private static let blockIDRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?m)^[ \t]*id::[ \t]*([0-9a-fA-F-]{8,})[ \t]*$"#)
    private static let propertyLineRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[ \t]*[A-Za-z][\w.-]*::"#)

    /// The block owning an `id::` property is the nearest previous non-empty,
    /// non-property line; its first line (list marker stripped) is the embed text.
    static func extractBlocks(from content: String) -> [String: String] {
        guard let idRegex = blockIDRegex, let propRegex = propertyLineRegex else { return [:] }
        let lines = content.components(separatedBy: "\n")
        var blocks: [String: String] = [:]

        for (index, line) in lines.enumerated() {
            let nsLine = line as NSString
            guard let match = idRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
                let uuidRange = Range(match.range(at: 1), in: line)
            else { continue }
            let uuid = String(line[uuidRange])

            for prev in stride(from: index - 1, through: 0, by: -1) {
                let candidate = lines[prev]
                let trimmed = candidate.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                let nsCandidate = candidate as NSString
                if propRegex.firstMatch(in: candidate, range: NSRange(location: 0, length: nsCandidate.length)) != nil {
                    continue
                }
                var text = trimmed
                if text.hasPrefix("- ") {
                    text = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                blocks[uuid] = text
                break
            }
        }

        return blocks
    }

    private func indexBlocks(from content: String, title: String) {
        let blocks = Self.extractBlocks(from: content)
        noteBlocks[title] = Set(blocks.keys)
        for (uuid, text) in blocks {
            blockIndex[uuid] = text
        }
    }

    /// Embed text for a `((uuid))` block ref, nil when the id is unknown.
    func resolveBlock(_ uuid: String) -> String? {
        blockIndex[uuid]
    }

    /// Value snapshot of the block-ref map, safe to capture into the
    /// background `Task.detached` rendering paths.
    func blockIndexSnapshot() -> [String: String] {
        blockIndex
    }

    func removeNote(title: String) {
        if let links = outlinks[title] {
            for target in links {
                inlinks[Self.normalizeKey(target)]?.remove(title)
            }
        }
        outlinks.removeValue(forKey: title)
        inlinks.removeValue(forKey: Self.normalizeKey(title))
        if let uuids = noteBlocks.removeValue(forKey: title) {
            for uuid in uuids {
                blockIndex.removeValue(forKey: uuid)
            }
        }
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

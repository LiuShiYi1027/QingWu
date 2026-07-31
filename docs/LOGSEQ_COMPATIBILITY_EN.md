# QingWu's Logseq Compatibility

> What works, what doesn't, and why — when you open a Logseq graph in QingWu.
> 中文版：[LOGSEQ_COMPATIBILITY.md](LOGSEQ_COMPATIBILITY.md)

## In one sentence

QingWu reads Logseq's **files** well: open a graph and you can read, navigate, and write long-form articles immediately. It does not re-implement Logseq's **engine** — anything that needs execution (queries, dynamic blocks) is out of scope, because building that would mean rewriting Logseq, which is not QingWu's goal.

## Supported (reading & writing)

- **Open a graph directly.** `journals/` and `pages/` appear in the sidebar; `logseq/` (config, backups) and `assets/` are hidden automatically.
- **Task markers**: `TODO` / `DOING` / `DONE` / `NOW` / `LATER` / `WAITING` / `CANCELED` render as colored status badges in preview.
- **Properties**: `key:: value` lines render muted; `id::` and `collapsed::` are hidden while reading (matching Logseq's reading mode).
- **Outlines**: Logseq's tab-indented nested outlines render as proper nested lists.
- **Wikilinks**: `[[Page]]` is clickable; `[[target|label]]` aliases, case-insensitive matching, and `[[namespace/Page]]` → `namespace___Page.md` filename mapping all work.
- **Block refs**: `((uuid))` expands inline to the referenced block's first line in preview, export, and Copy HTML (graph-wide on macOS; iOS currently resolves within the current note only, cross-note refs stay literal until V2).
- **Today's Journal**: `cmd+shift+D` opens or creates `journals/yyyy_MM_dd.md`, fully compatible with Logseq's journal naming.
- **Safe editing**: saving a note in QingWu preserves the file byte for byte — `id::` properties, line endings, and everything you didn't touch stay untouched.

## Not supported (deliberately)

- **`{{query}}`**: requires a query engine — Logseq's core power and its core complexity. Not our scope.
- **Full dynamic block semantics**: block refs expand to plain first-line text only; no recursive expansion, no nested formatting, no live sync with the source block.
- **Editable embeds**: `{{embed}}` is not supported.
- **Namespace tree navigation**: pages are listed flat.
- **Outline collapsing and block dragging**: Logseq's editor interaction layer — rewriting Logseq territory.
- **`.edn` config, plugins, themes**: neither read nor applied.
- **Whole-file auto-format**: in a Logseq graph, Format and Clean Typography are disabled in the Edit menu. Both rewrite the entire file, and the graph owns its formatting (tab indentation, `id::` properties) — QingWu does not fight Logseq for it. In plain Markdown folders they work as usual.

If you need those, the right tool is Logseq itself. QingWu serves what comes *after* capturing: reading your graph back and turning it into publishable articles.

## Write policy (trust commitments)

Letting a third-party tool open a graph you've kept for years is scary. Our rules:

- **Never write inside the vault**, except for notes you explicitly edit.
- **New notes** use QingWu's own filename convention (macOS filenames cannot contain `/`; hierarchy uses `:`). Logseq's `___` encoding is read-only and never rewritten.
- **Pins and cursor positions** live in file extended attributes (xattr) — file bytes unchanged, invisible to `git status`.
- **Conflict backups** go to `~/Library/Application Support/com.qingwu.app/Conflicts`, never inside your graph.
- **No telemetry, no analytics.** Everything stays local.
- **Editing the same note in both Logseq and QingWu**: external changes are last-write-wins (unsaved editor content is backed up to the conflicts directory with a notice). Edit any given note in one place at a time.

## Feedback

File issues at [GitHub Issues](https://github.com/LiuShiYi1027/QingWu/issues). Requests from the "not supported" list are deferred per the product roadmap and recorded in the [parking list](../ROADMAP.md) for a batch review instead of one-off versions.

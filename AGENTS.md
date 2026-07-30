# QingWu Agent Guide

> `CLAUDE.md` is a symlink to this file. Claude Code, Codex, and any other
> agent reading `AGENTS.md` share this single source so the guide stays in
> sync.
>
> Agent skills for this repo live in `.agents/skills/`:
> `release`, `appstore`, `lint`, `code-review`, `github-ops`.
>
> **Product positioning and scheduling live in `PRODUCT.md` and
> `ROADMAP.md` — they are the arbiter for every feature decision.** Before
> proposing or building anything, check it against the positioning and the
> roadmap's stop-line (停手线): after V1.x, new "Logseq render
> compatibility" requests default to no and go to the roadmap's parking
> list (搁置清单). When positioning changes, the docs change first, code
> second.

## Project

QingWu is a lightweight Markdown editor built with Swift. The main app is
macOS/AppKit, and the repository also contains an iOS target under
`QingWuMobile/`. Current version triplet: 1.0.0 (see `MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION` in `QingWu.xcodeproj/project.pbxproj`).

## Tech Stack

- **Markdown rendering**: `swift-cmark-gfm` parses GitHub Flavored Markdown.
- **Syntax highlight**: `Highlightr`.
- **Math / diagrams**: LaTeX formulas, Mermaid, PlantUML supported via the
  preview renderer.
- **Slide mode**: based on Reveal.js. `---` separators delimit slides.
- **Note storage**: filesystem-backed with folder nesting, file-system watch,
  auto-save, and version history.
- **Editor**: live preview, syntax highlight, keyboard shortcuts,
  Prettier-integrated auto-format.
- **iOS target**: SwiftUI under `QingWuMobile/`, sharing core models in
  `Business/` with the macOS app.
- **Dependencies**: SPM, declared in `Package.swift` (Sparkle, Highlightr,
  ZipArchive, swift-cmark-gfm, KeyboardShortcuts, Prettier). The `targets:`
  array is intentionally empty — the Xcode project consumes the packages via
  standard SPM integration. `DEPENDENCIES.md` is the human-readable source of
  truth for what each dependency does. Platforms: macOS 11+, iOS 18+.

## Repository Map

- `Controllers/` - view controllers and window controllers.
- `Views/` - UI components.
- `Business/` - models and business logic.
- `Helpers/` - utilities and services.
- `Extensions/` - Swift extensions.
- `Resources/` - bundled resources, including `DownView.bundle` (HTML/CSS/JS
  for preview) and `Localization/` (Base + es/ja/zh-Hans/zh-Hant).
- `QingWuMobile/` - iOS app target: SwiftUI views, mobile services, mobile
  resources.
- `QingWuTests/` - unit tests for pure-logic surfaces.
- `QingWu.xcodeproj/` - Xcode project and version settings.
- `Package.swift` / `Package.resolved` - SPM dependency declarations;
  platforms macOS 11 / iOS 18.
- `scripts/` - local build, App Store, release, project maintenance scripts,
  and the `qingwu` CLI.
- `scripts/release-ci/` - release note rendering, appcast, notarization, and
  package helpers.
- `skills/miaoyan/` - published Agent Skill (tracked) describing QingWu's
  Markdown, PPT, and `miao` CLI surfaces to outside agents; it restates
  product syntax, so it drifts when those surfaces change.
- `.agents/skills/` - agent skills used when working in this repo.
- `.github/RELEASE_NOTES.md` - public release note source for GitHub release
  and appcast body generation.
- `.github/workflows/` - holds `ci.yml` only; release builds are not driven by
  a tracked release workflow.
- `ARCHITECTURE.md` - the real top-level dependency map; read it before
  non-trivial work.
- `DEPENDENCIES.md` - runtime dependency inventory, kept in sync with
  `Package.swift`.

## Commands

```bash
xcodebuild -project QingWu.xcodeproj -scheme QingWu -configuration Debug build
xcodebuild clean
xcodebuild test -project QingWu.xcodeproj -scheme QingWu -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild -project QingWu.xcodeproj -scheme QingWuMobile -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
swiftlint lint --strict
swift-format lint --recursive . --strict   # --strict is what CI runs; without it a local pass can still fail CI
bash scripts/build.sh
bash scripts/build-appstore.sh
ruby scripts/add_tests_target.rb     # only when re-wiring QingWuTests after pbxproj reset
```

Use the narrowest relevant command first. Full app builds are the default
verification for Swift or project changes.

The Xcode project uses classic pbxproj groups (no filesystem-synchronized
groups). Adding a new source file requires manual registration at 4 sites in
`QingWu.xcodeproj/project.pbxproj`: a `PBXBuildFile` entry, a
`PBXFileReference` entry, the owning group's `children` list, and the target's
`PBXSourcesBuildPhase` files list. Mimic an existing sibling entry and use a
fresh unique 24-hex ID for each new object.

## Code Style

- Formatting is enforced by swift-format (`.swift-format`): 4-space indent,
  240-column line length, Allman braces off, trailing commas always. Four
  rules are deliberately disabled because the codebase violates them on
  purpose (`AlwaysUseLowerCamelCase`, `AvoidRetroactiveConformances`,
  `NoBlockComments`, `ReplaceForEachWithForLoop`).
- SwiftLint (`.swiftlint.yml`) disables `force_cast`/`force_try` and various
  length rules, opts into a set of correctness rules, and sets generous
  budgets (line 240/300, file 2000/2500, cyclomatic complexity 22/24).
- Custom rule `no_direct_singleton_in_new_code`: new code must use
  `AppEnvironment.current.<service>` instead of raw singletons
  (`Storage.sharedInstance()`, `WikilinkIndex.shared`, ...). Severity is
  `warning`, but CI runs `swiftlint lint --strict`, which promotes it to a
  merge gate. Existing call sites are grandfathered via an explicit
  `excluded` list — do not add new files to that list.
- Swift 6 toolchain (`SWIFT_VERSION = 6.0`), Xcode 16+. macOS 13+ host for
  development.
- Match the surrounding file's comment density, naming, and idioms; keep
  diffs minimal and scoped.

## Testing

Unit tests live under `QingWuTests/`. Coverage targets pure-logic surfaces
(`ImageLinkParser`, `WikilinkIndex.updateNote`, `String+`, frontmatter
stripping, `TypographyCleaner`, etc.). UI flows are verified by manual smoke
after build, not by XCUITest.

Add a new test:

1. Create `QingWuTests/<Subject>Tests.swift` (XCTest, `@MainActor` on the
   test methods if they touch `@MainActor`-isolated types; `setUp()` overrides
   cannot be `@MainActor`, construct isolated objects inside the tests).
2. Register the file manually at the same 4 pbxproj sites as an app source,
   but into the `QingWuTests` group and the `QingWuTests` target's
   `PBXSourcesBuildPhase`. Mimic the `NoteFrontmatterTests.swift` sibling
   entries. `scripts/add_tests_target.rb` is a no-op once the target exists
   (it only bootstraps the target after a pbxproj reset), and the `xcodeproj`
   gem it needs is not installed on this machine anyway.
3. Run `xcodebuild test ...` locally, then push.

`CODE_SIGNING_ALLOWED=NO` is required on the local test command because
the dev signing identity used for `QingWu.app` and the per-developer
identity used for `QingWuTests.xctest` end up with different Team IDs,
which makes dyld refuse to load the test bundle into the host app. `ci.yml`
passes the same flag on every xcodebuild invocation, so it is not a
local-only workaround.

## CI

`.github/workflows/ci.yml` runs on every PR and push to `main`:

- macOS Debug build, then `xcodebuild test` for the unit suite (no signing
  required)
- iOS Debug build for `QingWuMobile`. This job pins `runs-on: macos-26`
  because the iOS target uses iOS 26 SwiftUI APIs (glassEffect / Liquid
  Glass) that only ship in Xcode 26 SDKs; every other job is `macos-15`. If
  that runner is unavailable, wait for it rather than downgrading the iOS
  code
- SwiftLint and swift-format, both `--strict`, so any warning is a merge gate
- Release-notes rendering smoke (`scripts/release-ci/notes_to_html.sh` and
  `render_release_body.sh`) so a broken `.github/RELEASE_NOTES.md` is caught
  before release time, not during it
- On tag pushes (`V*`): version-triplet consistency check
  (`MARKETING_VERSION == CURRENT_PROJECT_VERSION == tag`, across every
  target/config) to prevent the V3.5.1 / #524 incident recurrence

CI does NOT run the App Store packaging or notarization scripts; those need
maintainer-managed signing keys and run only on the maintainer's machine.

## Error Reporting

`AppDelegate.trackError` is the single funnel for runtime errors:

- DEBUG: still prints to stdout (kept for Xcode console workflow).
- RELEASE: routes through `Helpers/Diagnostics.swift`, which writes a
  `.fault` os_log entry plus a JSON-line ring buffer at
  `~/Library/Logs/QingWu/diagnostics.log` (50 entries max).
- Users can attach the diagnostics log to bug reports without us running an
  analytics SDK (local-first stance).

When wiring a new failure path, call `AppDelegate.trackError(error, context:)`
rather than `print(...)` or silently swallowing with `try?`. The `context`
string is the only breadcrumb the maintainer has when triaging.

## 产品偏好

- **付费用户视角**: 默认按 App Store 付费版的精致度做。每次视觉 / 交互改动思考"对得起付费用户吗"。能精致一分就精致一分。
- **Markdown 预览里图片 / 视频 / iframe / 表格必须 `max-width: 100%`**, 禁止横向滚动。任何引入 raw HTML 渲染的改动都要复查这一条。
- **设计参考**: UI / CSS 抄不出来时去看 `~/www/weekly` 和 `~/www/tw93.github.io`, 那里有维护者已经满意的样式。不要凭空发挥。
- **目标视觉风格**: macOS 26 风格的 sidebar (玻璃态、透明、SF Symbols 最新一代) 是长期方向, 不是经典 Big Sur 风格。
- **不要再提议整套 macOS 26 / Liquid Glass 重设计**。一次实机改造 (侧栏换原生 `.sidebar` 半透明材质 + 选中态改强调色玻璃 pill + 图标整体迁 SF Symbols + 自绘 pill `ChromeToolbarButton`) 已被维护者否决, 原话"还不如之前好看, 不强求这个"。要打磨侧栏 / 按钮就在现有不透明设计上做小步增量: 间距、对齐、hover、focus、字重。不要整体换材质或换图标体系, 除非维护者在当前回合明确要求。
- **cmd-数字快捷键已占满 0-5**, 不要冲突: 1 侧栏, 2 笔记列表, 3 Toggle Preview, 4 Toggle Presentation, 5 TOC, 0 Actual Size。新增前先 `grep 'keyEquivalent="N"' Resources/Localization/Base.lproj/Main.storyboard` 核对, 绑定只存在于 storyboard, 代码里没有 keyBindings 表。打字机滚动 / 链接相关另开模式或子开关即可。

## Working Rules

- Keep UI updates on the main thread.
- Avoid force unwraps unless the invariant is obvious and local.
- Prefer `AppEnvironment.current.<service>` over direct singleton access in
  new code. The SwiftLint `no_direct_singleton_in_new_code` rule is
  `severity: warning` in `.swiftlint.yml`, but CI runs
  `swiftlint lint --strict`, which promotes it to a merge gate. Existing call
  sites are grandfathered.
- Keep file writes scoped to user documents or app-controlled locations.
- Do not add network calls, shell execution, or broad file access without
  clear user need.
- Keep the macOS editor core, preview pipeline, and existing storyboard
  scenes on AppKit. A new self-contained panel may host SwiftUI through
  `NSHostingView`; that is not licence to push SwiftUI into `EditTextView` /
  `MPreviewView` / `ViewController`. `QingWuMobile/` is SwiftUI throughout,
  and UI layers are not shared across the two targets.
- Preserve recoverability for delete flows. Notes and attachments should move
  through the app Trash or system Trash path that matches the current
  context, not disappear through direct deletion.
- Treat iCloud sync and symlinked directories as file-system-sensitive
  surfaces; resolve paths deliberately and avoid loops or duplicate indexing.
- Storyboard bindings (`@IBOutlet`/`@IBAction` on `ViewController`, cell
  identifiers `NoteCellView` / `DataCell`, First Responder selectors) break
  at runtime without compile errors if renamed. See `ARCHITECTURE.md`
  "Storyboard Anchors" before moving any of these. Main-menu actions target
  a storyboard-level `ViewController` object whose outlets are nil — new
  menu items must forward to the real wired instance via
  `ViewController.shared()` (the `fileMenuNewNote` pattern), never call
  logic on `self` directly, or the app traps on the first outlet touch.

## Security Considerations

- The app is local-first: no analytics SDK, no telemetry. Diagnostics stay on
  the user's machine (`~/Library/Logs/QingWu/diagnostics.log`).
- The only outbound network call in normal use is image upload to a local
  PicGo/PicList endpoint at `127.0.0.1:36677`
  (`Helpers/ClipboardManager.swift`), permitted via `NSAllowsLocalNetworking`
  in the macOS `Info.plist`. Do not widen ATS back to
  `NSAllowsArbitraryLoads`.
- Entitlements are split per channel: `QingWu.entitlements` (direct),
  `QingWu-AppStore.entitlements` (sandboxed App Store),
  `QingWuMobile.entitlements` (iOS).
- The iOS preview scheme handler (`qingwu-asset://` in
  `MobileHtmlRenderer.swift`) only serves files under the current library
  root (`allowedRoot`). Keep that root restriction when touching the handler.
- Never commit signing keys, notarization credentials, Sparkle private keys,
  or local credential paths. Release automation depends on
  maintainer-managed credentials.
- Branch workflow: `dev` is the default branch for PRs, `main` is the release
  branch (see `CONTRIBUTING.md`).

## Investigation Order

When scope is incomplete, start with:

1. `ARCHITECTURE.md` for the real top-level dependency map
2. `Controllers/AppDelegate.swift`
3. `Controllers/MainWindowController.swift`
4. `Controllers/ViewController.swift`
5. `QingWuMobile/` when the task touches iOS, sync, mobile reading, or
   mobile editing behavior
6. Narrow related files under `Helpers/`, `Views/`, `Business/`, or
   `Extensions/`
7. Relevant Xcode project settings only when build, signing, target
   membership, or version behavior is involved

Avoid broad scans of `build/`, `.build/`, `dist/`, and bundled web assets
unless the task targets them.

## Current Risk Areas

- Editor buffer ownership (#543): in preview/presentation/PPT modes
  `EditTextView.note` follows the list selection while `textStorage` keeps
  the last edited note, so the two legitimately diverge.
  `EditTextView.storageNote` records which note the buffer belongs to; every
  wholesale storage assignment must go through `publishStorage(_:owner:)`,
  and every whole-buffer persist through `saveTextStorageContent(to:)`, which
  refuses cross-note targets. Never persist the buffer based on
  `EditTextView.note` or the table selection alone, and never compare
  `EditTextView.note` against itself as a guard (that tautology is how the
  V4.0.0 content-swap shipped).
- Wikilinks and backlinks depend on `Business/WikilinkIndex.swift`, note
  loading, search, and sidebar refresh behavior. Keep `[[note]]` parsing,
  recursive search, and Trash exclusions consistent.
- iCloud sync spans macOS storage, `Business/CloudSyncManager.swift`, and
  `QingWuMobile/Services/CloudSyncManager.swift`. Verify fallback behavior
  when iCloud is unavailable.
- `QingWuMobile/` is a real iOS target, not sample code. Keep SwiftUI, file
  reading, mobile rendering, and target membership aligned.
- Trash handling spans `Business/Storage.swift`, `Business/Note.swift`,
  sidebar drag/drop, attachment cleanup, and system Trash fallback.
- Logseq vault compatibility is a product invariant: opening a Logseq vault
  must never write into it except for user-edited notes. Vault internals stay
  hidden via the reserved-folder list — macOS `Storage.reservedFolderNames`
  and iOS `NoteFileStore.ignoredFolderNames` are mirrored deliberately; change
  both in the same commit. Conflict backups live in
  `~/Library/Application Support/com.qingwu.app/Conflicts`, never inside the
  storage root. External-edit handling is last-write-wins with a debounced
  recheck window (see `FileSystemEventManager.reloadNote`); a real merge is
  planned but not implemented — treat any change there as high risk.
- Logseq syntax rendering (`TODO` badges, `key::` property lines, hidden
  `id::`/`collapsed::`, tab-indented outline expansion) lives in
  `renderMarkdownHTML` (`Business/Markdown.swift`): `expandLogseqTabIndentation`
  runs before cmark (render-only, fence-aware), `transformLogseqFlavor` at the
  end. Both have deliberate mirrors in
  `QingWuMobile/Services/MobileHtmlRenderer.swift`; change both in the same
  commit. Styling uses `--logseq-task-color` variables in
  `typography.css` with explicit dark restatements in `theme-dark.css`;
  `mobile-reader.css` mirrors the same rules.
- `((uuid))` block refs resolve through a block index in `WikilinkIndex`
  (`id::` → owning block's first line), passed into `renderMarkdownHTML` as
  `blockResolver`; background `Task.detached` render paths capture
  `blockIndexSnapshot()` first (the index is `@MainActor`). iOS mirrors the
  extraction in `MobileHtmlRenderer.extractLogseqBlocks` but resolves
  within the current note only — cross-note refs stay literal until a
  mobile block index exists.
- Logseq wikilink targets resolve through `WikilinkIndex.canonicalTarget` /
  `titleCandidates` / `resolveAll` (`Business/WikilinkIndex.swift`): alias
  stripping, case-insensitive matching, and `namespace/Page` ↔
  `namespace___Page` filename mapping. `RouteQingWuGoto` consumes it on
  macOS; iOS mirrors `titleCandidates` in `NoteFileStore` (`FileReader.swift`).
  Change both platforms in the same commit. QingWu keeps its own `:`
  filename convention for newly created notes — the Logseq encodings are
  read-only compatibility.
- Version history lives in `Business/NoteVersionManager.swift` and
  `Controllers/VersionHistoryViewController.swift`; keep file IO off the main
  thread and UI updates on the main thread.
- Mermaid and PDF export span `Business/HtmlManager.swift`,
  `Helpers/PdfExportController.swift`, and
  `Extensions/MPreviewView+Export.swift`. Wait for images and Mermaid
  rendering before capture.
- Async note/image/file loading is intentional. Do not reintroduce blocking
  reads on the main thread for large notes or previews.
- Directory symlinks are supported by storage scanning. Avoid recursion loops
  and duplicate notes when following symlinked directories.
- The iOS editor is `QingWuMobile/Views/MarkdownEditorView.swift` +
  `Services/MarkdownHighlighter.swift`: plain-markdown UITextView with regex
  highlighting. Never mutate `textStorage` attributes while
  `markedTextRange != nil` (breaks CJK IME composition), and keep
  `lineBreakStrategy = []` (re-enabling push-out reintroduces premature CJK
  line wraps).
- Note attachments follow the shared `i/` convention: images live in an `i/`
  folder next to the note, referenced as `![](/i/<name>)` on both platforms.
  The iOS reader cannot load `file://` subresources (`loadHTMLString`), so
  `MobileHtmlRenderer` rewrites local srcs to the `qingwu-asset://` scheme
  served by `LocalAssetSchemeHandler`, which only serves files under the
  current library root (`allowedRoot`). Keep that root restriction when
  touching the handler.
- Image upload posts to a local PicGo/PicList HTTP endpoint at
  `127.0.0.1:36677` (`Helpers/ClipboardManager.swift`). The macOS
  `Info.plist` ATS permits this via `NSAllowsLocalNetworking`; do not widen
  it back to `NSAllowsArbitraryLoads`. The markdown preview loads through
  `loadFileURL` (file://), not a local web server, so ATS does not gate
  preview rendering.
- iOS user-facing strings live in
  `QingWuMobile/Resources/Localizable.xcstrings` and ship `en` + `zh-Hans`
  only (the macOS app ships five languages). Add a `zh-Hans` value for every
  new iOS string, or Chinese users fall back to English.
- `renderMarkdownHTML` in `Business/Markdown.swift` is the single
  markdown-to-HTML funnel for preview, split view, export, PPT, and actions.
  Post-render transforms (the GitHub Alerts callout rewrite lives there)
  belong at the end of that function, never in individual call sites. Alert
  styling lives in `DownView.bundle/css/typography.css` with dark overrides
  in `theme-dark.css` (the `.darkmode *` color rule forces explicit dark
  restatements).
- Frontmatter stripping is a per-surface invariant, not a two-file rule:
  every surface that outputs note or markdown content (macOS preview/export,
  iOS preview, appcast/release-notes rendering, any future export) must strip
  leading YAML frontmatter, and a new rendering surface adds its stripping in
  the same commit (`---date/image---` has leaked verbatim through both the
  appcast body and the iOS preview). The copies are deliberately duplicated
  per platform: `Note.cleanMetaData` (macOS),
  `MobileHtmlRenderer.stripFrontmatter` (iOS preview) and the private
  `stripFrontmatter` in `QingWuMobile/Services/FileReader.swift` must keep
  identical semantics; change all three in the same commit. CRLF gotcha all
  copies share: `"\r\n"` is one Swift grapheme, so `range(of: "\n---")` never
  matches inside it; search both `"\n---"` and `"\r\n---"`.
- `Helpers/TypographyCleaner.swift` (Edit → Clean Typography) must never
  rewrite protected regions: fenced/inline code, math, link targets,
  wikilinks, bare URLs, frontmatter. Extend the segment parser, don't bypass
  it. `Helpers/HtmlToMarkdown.swift` converts pasted HTML only when
  block-structure tags are present, so plain-text paste stays authoritative
  for code copied from editors; keep that gate.
- New macOS menu items need the storyboard entry plus an ObjectID-keyed
  `.title` line in all four `Main.strings` (es/ja/zh-Hans/zh-Hant); new
  toasts need the English text as key in all four `Localizable.strings` (Base
  has no Localizable.strings, English falls back to the key itself). Missing
  a file silently ships English to that locale.

## Release Channels

QingWu ships through two independent channels. Publishing one never updates
the other: one version means two separate publishes, and release readiness
must be reported per channel.

| | Direct download (GitHub) | Mac App Store |
|---|---|---|
| Build | `scripts/build.sh`, Developer ID + notarization, Sparkle included | `scripts/build-appstore.sh`, App Store entitlements, no Sparkle |
| Publish surface | GitHub Release assets + `miaoyan.app/Release/` ZIP + appcast entry | App Store Connect submission + review |
| How users update | Sparkle in-app update via `https://miaoyan.app/appcast.xml` | App Store update after review approval |

- `appcast.xml` lives on the miaoyan.app site, not in this repository.
  `scripts/release-ci/update_appcast.sh` produces the entry and
  `scripts/build.sh` prints the enclosure line.
- App Store users never see the appcast. After a direct-download release, the
  App Store version stays old until a separate submission passes review; do
  not report a version as "released" without naming which channel it reached.
- When an App Store build is prepared, deliver ready-to-paste submission copy
  with it: Promotional Text (170-char limit) and What's New, in en and
  zh-Hans, derived from `.github/RELEASE_NOTES.md`. Do not wait for the
  maintainer to ask from the Connect submission page.

## Release Notes

- Tag format is uppercase `Vx.y.z`.
- Version changes must keep both `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION` in `QingWu.xcodeproj/project.pbxproj` aligned
  with the release tag. Sparkle compares `sparkle:version` in appcast.xml
  against `CFBundleVersion` (mapped from `CURRENT_PROJECT_VERSION`), not
  `CFBundleShortVersionString`. If the two diverge, users get an infinite
  update prompt loop (V3.5.1 incident, #524).
- `.github/RELEASE_NOTES.md` is the public release note source. Release
  scripts under `scripts/release-ci/` render it for GitHub release and
  appcast content, including the current sectionless format.
- Release titles follow `V{x.y.z} {Codename} {emoji}` (e.g.
  `V4.0.0 Valstrax 🚀`). Before drafting notes, `gh release view` the
  previous release and mirror its exact body shape instead of rebuilding it
  from memory; the full format and reaction ritual live in
  `.agents/skills/release`.
- Publishing ends with the six positive reactions (`+1`, `laugh`, `heart`,
  `hooray`, `rocket`, `eyes`) added via `gh api` and read back to confirm.
  Never add `-1` or `confused`.
- Direct-download Sparkle signing must use the QingWu release key, not the
  default Sparkle Keychain account. Before pushing appcast changes, verify
  the signature against the published ZIP and the app's embedded
  `SUPublicEDKey` with `scripts/release-ci/verify_sparkle_signature.sh`; a
  signature-only appcast fix is valid only when ZIP bytes and length are
  unchanged.
- Direct-download release builds use repository scripts; no tracked workflow
  packages a release.
- Release automation depends on maintainer-managed signing, notarization, and
  Sparkle credentials. Do not document or commit local credential paths,
  private key filenames, or secret values.

## Verification

- Swift changes: run the Debug `xcodebuild` command above.
- UI or interaction fixes: launch the built app and exercise the changed flow
  before reporting done; a green build is not visual proof. If the first fix
  attempt does not hold, stop guessing and add `#if DEBUG` runtime logging to
  capture evidence before the next code change.
- Lint or formatting changes: run SwiftLint and swift-format checks.
- iOS changes: verification bar equals macOS. Inspect `QingWuMobile/` target
  membership, build, then run the affected flow in the Simulator (for example
  the new-note title flow or preview first frame) before reporting done; a
  green build alone is not done. Performance complaints need a measurable
  budget in the fix (for example: detail-page first frame past the budget
  shows a skeleton instead of blocking).
- Release or signing changes: verify version alignment and inspect the
  relevant repository script; do not assume a tracked `release.yml` exists.
- Release note changes: inspect `.github/RELEASE_NOTES.md` and the affected
  `scripts/release-ci/` renderer.
- Export changes: verify Mermaid, images, PDF pagination, and async readiness
  behavior together.
- Documentation-only changes: check links and command accuracy.

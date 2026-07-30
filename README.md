<h4 align="right">English | <strong><a href="https://github.com/liushiyi1027/QingWu/blob/main/README_CN.md">简体中文</a></strong></h4>

<p align="center">
  <h1 align="center">QingWu</h1>
  <div align="center">Lightweight Markdown note-taking app for macOS</div>
</p>

QingWu is forked from [MiaoYan](https://github.com/tw93/MiaoYan) by Tw93 (MIT License).

## Features

- **Fantastic**: Local-first, no data collection, split editor & preview, wikilink backlinks, LaTeX, Mermaid
- **Beautiful**: Minimalist design, three-column layout, dark mode, macOS 26 glass, distraction-free
- **Fast**: Swift 6 native, better performance than Electron-based apps
- **Simple**: Lightweight, version history, keyboard shortcuts, auto-formatting

## For Logseq users

QingWu gives Logseq graphs first-class read support: open your graph and go — task badges, property folding, outline rendering, wikilink navigation, block-ref expansion, and Today's Journal (⌘⇧D). It **never writes inside your vault**. See the full [Logseq compatibility notes](docs/LOGSEQ_COMPATIBILITY_EN.md) ([中文](docs/LOGSEQ_COMPATIBILITY.md)) for what's supported, what isn't, and the write policy.

## Installation

**GitHub Releases**: download the latest DMG from [GitHub Releases](https://github.com/liushiyi1027/QingWu/releases/latest) (macOS 11.5+)

After installing, create a `QingWu` folder in iCloud Drive, a desktop cloud-drive folder, or your preferred location, open Preferences (⌘,), and set the storage path.

## Sync with Nutstore or Other Cloud Drives

QingWu is local-first and does not sign in to WebDAV or cloud-drive accounts. It reads and writes the Markdown folder you choose. iCloud Drive, Nutstore, Dropbox, or another cloud-drive client handles cross-device sync.

- **Mac**: Create a `QingWu` folder inside the local folder synced by the Nutstore desktop client, then point QingWu's storage location to it in Preferences.
- **iPhone**: Pick the same cloud-drive folder from the system Files app. If a provider does not expose a writable folder in Files, use iCloud Drive or make the folder available offline in that provider app before choosing it.
- **Folder check**: QingWu verifies read and write access before switching folders. If the folder is unavailable, the current storage path stays unchanged.

## CLI

QingWu provides a command-line interface for quick note operations.

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/liushiyi1027/QingWu/main/scripts/install.sh | bash

# Usage
qingwu open <title|path>    # Open note or folder
qingwu new <title> [text]   # Create new note
qingwu search <query>       # Search notes in terminal
qingwu list [folder]        # List top-level folders, or markdown in folder
qingwu cat <title|path>     # Print note content
qingwu update               # Update CLI
```

## Split Editor & Preview Mode

Edit and preview side by side with real-time preview and 60fps bidirectional scroll sync.

**Quick Toggle**: Press `⌘\` to instantly toggle split view mode, or enable it in Preferences → Interface → Edit Mode → Split Mode.

Why not WYSIWYG like Typora? We prioritize pure Markdown editing experience, and implementing WYSIWYG in native Swift is overly complex with reliability concerns. Split mode maintains clean editing while providing instant visual feedback.

## Documentation

- [Markdown Syntax Guide](Resources/Initial/QingWu%20Markdown%20Syntax%20Guide.md) - Complete syntax reference with advanced features
- [PPT Presentation Mode](Resources/Initial/QingWu%20PPT.md) - Guide to creating presentations with `---` slide separators
- [QingWu Agent Skill](skills/miaoyan) - Teach your agent QingWu syntax, attachments, PPT patterns, and CLI workflows

## Acknowledgments

- [tw93/MiaoYan](https://github.com/tw93/MiaoYan) - The upstream project QingWu is forked from
- [glushchenko/fsnotes](https://github.com/glushchenko/fsnotes) - Initial project structure reference
- [stackotter/swift-cmark-gfm](https://github.com/stackotter/swift-cmark-gfm) - Swift Markdown parser
- [simonbs/Prettier](https://github.com/simonbs/Prettier) - Markdown formatting utilities
- [raspu/Highlightr](https://github.com/raspu/Highlightr) - Syntax highlighting
- [TsangerType](https://tsanger.cn/product) - TsangerJinKai font (default font)
- [hakimel/reveal.js](https://github.com/hakimel/reveal.js) - PPT presentation framework

## License

MIT License - Feel free to use and contribute.

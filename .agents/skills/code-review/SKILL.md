---
name: code-review
description: MiaoYan project adapter for Waza check/code-review. Use for Swift, AppKit, iOS target, and release-safety review.
version: 1.1.0
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
disable-model-invocation: true
---

# MiaoYan Code Review Adapter

Use Waza `/check` for the generic review method. This adapter adds MiaoYan-specific commands, hard stops, and target awareness.

## Quick Commands

```bash
# View PR diff
gh pr diff 123

# Build check
xcodebuild -project MiaoYan.xcodeproj -scheme MiaoYan -configuration Debug build

# Lint
swiftlint lint --strict

# Format check
swift-format lint --recursive .
```

## MiaoYan-Specific Checks

- [ ] No retain cycles (weak/unowned used correctly)
- [ ] Main thread UI updates only
- [ ] File I/O uses proper error handling
- [ ] No force unwraps (`!`) without justification
- [ ] Follows existing patterns in the codebase
- [ ] No unnecessary class where struct suffices
- [ ] Uses Swift concurrency correctly (async/await, actors)
- [ ] AppKit changes stay in the macOS app; SwiftUI changes stay in `MiaoYanMobile/` unless the task explicitly requires cross-target work
- [ ] SwiftLint passes: `swiftlint lint --strict`
- [ ] No dead code or commented-out blocks
- [ ] Clear naming, no abbreviations
- [ ] No new external network calls without user consent
- [ ] File writes are scoped to user documents or app-controlled locations
- [ ] No shell injection in CLI-related code
- [ ] Changes under `MiaoYanMobile/` consider target membership, sync behavior, and mobile resource paths

## Review Output Format

Follow Waza `/check`: findings first, ordered by severity, with tight file/line references. Keep summaries brief.

## Safety Rules

1. **NEVER** post review comments without explicit user request.
2. **ALWAYS** prepare feedback for user review first.
3. Draft responses in the same language as the PR author.

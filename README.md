# HallPass

> [!IMPORTANT]
> LLM disclosure: This codebase was written with substantial help from large language models: AI coding agents working from the [`AGENTS.md`](AGENTS.md) brief in this repo.

<img src="assets/HallPass-icon.png" width="160" height="160" alt="HallPass app icon">

A SwiftUI app for managing system-wide CIDR exemptions from local-network privacy restrictions. Requires **macOS Tahoe (26)** and **Xcode 26 or later**, with no external dependencies.

**Latest release:** v<!-- version -->1.0.0<!-- /version --> · [Download](https://github.com/L-K-M/HallPass/releases/latest)

HallPass manages **system-wide** exemptions that apply to **all apps on this Mac**, in every network using the specified address ranges. It does not manage per-app local-network permissions, firewall rules, or Wi-Fi network names.

## Usage

The interface is in German. **Hilfe → HallPass-Hilfe** explains the scope, CIDR notation, and backups.

1. Open HallPass. **Mit Beispieldaten ausprobieren** (Try Sample Data) explores the app without system access. **Darstellung → Vorschau beenden…** returns to real settings.
2. Choose **Konfiguration laden…** (Load Configuration, ⌘L) and authenticate as a macOS administrator.
3. Select **WLAN** (Wi-Fi, ⌘1) or **Ethernet** (⌘2). **Netzbereich hinzufügen…** (Add Range, ⌘N) accepts IPv4 or IPv6 CIDRs, optionally for both connections.
4. **Änderungen prüfen** (Check Changes) lists additions and removals. **Übernehmen** (Apply) writes them with administrator privileges.
5. Reboot the Mac. macOS applies the changes only after restart.

Examples: `169.254.0.0/16`, `192.168.1.0/24`, `fe80::/10`. Use `/32` (IPv4) or `/128` (IPv6) for a single address. Host bits are normalized, e.g. `192.168.1.42/24` becomes `192.168.1.0/24`.

Each interface supports up to 512 entries.

## Mac interface

- The native sidebar resizes and collapses. The toolbar groups loading, editing, review, and inspector controls; Tahoe supplies its Liquid Glass appearance.
- The searchable table supports keyboard navigation, ⇧/⌘ multi-selection, copying, Delete, and contextual actions. Double-click or Return edits one entry. ⌘F focuses search.
- **Informationen** (Inspector, ⌥⌘I) shows the selected range, prefix, scope, and draft status. Invalid legacy values remain inspectable and editable.
- Draft additions, edits, removals, imports, resets, and reverts have named undo/redo (⌘Z / ⇧⌘Z). Text fields retain normal text editing. Successful loading or applying starts a new undo history; applied system changes are restored through backups.
- Return confirms editing/review sheets; Escape cancels. Commands that would conflict with a sheet or an administrator operation are disabled.
- One utility window owns the machine-wide draft. Closing it keeps HallPass running; the Dock or **Fenster → HallPass** (⌘0) reopens it. Closing or quitting with pending changes asks before discarding. Native resizing, fullscreen, and window restoration remain available.
- System typography, semantic colors, and standard controls follow appearance and accessibility preferences. No custom motion or translucent content panels are used.

## Scope

HallPass reads and writes exactly two keys in the fixed Apple preference domain `com.apple.network.local-network`:

- `AllowedWiFiLocalNetworkAddresses`
- `AllowedEthernetLocalNetworkAddresses`

Access uses `/usr/bin/osascript` and `/usr/bin/defaults` under administrator privileges, with the same domain and execution identity as Apple's `sudo defaults` example. Arrays are passed as typed XML property lists; the result is equivalent to `defaults write DOMAIN KEY -array …`. The on-disk storage path is not assumed.

No background service is installed. HallPass requires no network connection. Help and the inspector link to [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) in the default browser.

## Backups

Before each real save, HallPass writes the previously loaded state to `~/Library/Application Support/HallPass/Backups/`. **Ablage** (File) contains export, import (⌘O), and **Backupordner öffnen** (Open Backup Folder). Export (⇧⌘E) writes the last loaded or saved state, excluding pending edits.

Imports use a native open sheet, or accept one JSON backup dropped into the loaded configuration. The import replaces the draft and can be undone. Canceling either file panel leaves the configuration untouched. Imports modify system settings only after **Änderungen prüfen → Übernehmen** (Review Changes → Apply).

**Alle Freigaben entfernen…** (Remove All Exemptions) clears both exemption lists in the draft. After applying and rebooting, apps revert to their regular local-network permissions. Other keys in the same domain are preserved.

Before writing, the baseline is re-checked; concurrent changes by other tools cause an abort and a prompt to reload. Write errors trigger a best-effort rollback of the affected keys. This is not a system-wide transaction.

Missing keys and empty arrays are distinguished. Unusual string values found on disk are preserved through load and backup cycles but must be valid CIDRs before saving.

Real drafts are atomically saved to `~/Library/Application Support/HallPass/Draft.json` after each change, with private file permissions. On relaunch, recovery restores both the draft and its original baseline; saving still checks for external changes. Successful loading/applying or explicitly discarding removes recovery. Preview never creates recovery files or automatic backups.

Unreadable or unsupported recovery files are preserved unchanged in the backup folder before new drafts are written. If preservation fails, real editing stays disabled until the folder permissions are fixed and HallPass is restarted. Ending a preview also checks for an existing real draft.

HallPass edits system configuration, not user documents. JSON backup version 1 is unchanged; no general `.json` Finder association is installed.

## Build

Install Xcode 26 or later at `/Applications/Xcode.app` on macOS 26. No package downloads are required. From a fresh checkout:

1. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
2. `sudo xcodebuild -runFirstLaunch`
3. `swift test`
4. `./scripts/build-app.sh`
5. `open dist/HallPass.app`

This produces `dist/HallPass.app` on the host architecture. Set `HALLPASS_BUILD_DIR` and/or `HALLPASS_OUTPUT_DIR` to override the build and output directories.

The app is locally ad-hoc signed; it is not signed with an Apple developer certificate nor notarized.

## Icon artwork

The full square source is [assets/HallPass-icon.png](assets/HallPass-icon.png). The build resamples it into all ten macOS icon sizes and packages `HallPass.icns`; the artwork also appears in the welcome screen. Its [generation prompt](assets/HallPass-icon.prompt.txt) is included.

## Tests

```sh
swift test
```

Tests cover CIDR edge cases, legacy backup compatibility, duplicate-aware review, recovery, named draft undo/redo, import/export, conflict detection, unrelated-key preservation, and save/rollback logic. Integration tests use temporary plist domains — no real network settings or administrator prompts. A restrictive sandbox may block these temporary accesses.

The format/editing tests also run on Linux; AppKit model tests and the seven `defaults` integration tests require macOS. CI uses macOS 26 with Xcode 26.0.1 to run debug/release tests, verify host/universal builds and signing, and exercise the actual app through mouse and keyboard. Screenshots and the universal app archive are retained; see [CICD.md](CICD.md).

For a manual session, quit HallPass first, then launch preview:

```sh
open dist/HallPass.app --args --demo
```

Check menus and shortcuts; sidebar, table, and inspector; search and text-field focus; multi-selection; add/edit/delete and undo/redo; import/export cancellation and round-trip; review; dirty-window close/cancel; Dock reopening; minimum size; fullscreen; light/dark and accessibility appearances. Real draft recovery can be checked by relaunching after an unexpected exit, before applying anything.

The real privileged write path and post-reboot effect were not exercised during development testing; validating them requires a test installation, a reboot, and a normally-launched GUI app (terminal and root processes already have exemptions per Apple).

## License

HallPass's own code is released under the [Unlicense](LICENSE). The app bundles no third-party components.

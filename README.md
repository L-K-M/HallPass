# HallPass

> [!IMPORTANT]
> LLM disclosure: This codebase was written with substantial help from large language models: AI coding agents working from the [`AGENTS.md`](AGENTS.md) brief in this repo.

<img src="assets/HallPass-icon.png" width="160" height="160" alt="HallPass app icon">

A SwiftUI macOS app for managing system-wide CIDR exemptions from the local-network privacy restriction. Requires **macOS 15.5 or later**, with no external dependencies.

**Latest release:** v<!-- version -->1.0.0<!-- /version --> · [Download](https://github.com/L-K-M/HallPass/releases/latest)

HallPass manages **system-wide** exemptions that apply to **all apps on this Mac**, in every network using the specified address ranges. It does not manage per-app local-network permissions, firewall rules, or Wi-Fi network names.

## Usage

The interface is currently in German. Click **ⓘ** beside a control for contextual documentation.

1. Open HallPass. Optionally, **Vorschau** (Preview) lets you explore with sample data and no system access. Exit preview with **×** before loading real settings.
2. Click **Konfiguration laden** (Load Configuration) and authenticate as a macOS administrator to read the current settings.
3. Select **WLAN** (Wi-Fi) or **Ethernet**. Click **Hinzufügen** (Add) to enter an IPv4 or IPv6 range in CIDR notation. The toggle in the dialog optionally applies the same entry to both interfaces.
4. **Änderungen prüfen** (Check Changes) lists additions and removals. **Übernehmen** (Apply) writes them with administrator privileges.
5. Reboot the Mac. macOS applies the changes only after restart.

Examples: `169.254.0.0/16`, `192.168.1.0/24`, `fe80::/10`. Use `/32` (IPv4) or `/128` (IPv6) for a single address. Host bits are normalized, e.g. `192.168.1.42/24` becomes `192.168.1.0/24`.

Each interface supports up to 512 entries.

## Scope

HallPass reads and writes exactly two keys in the fixed Apple preference domain `com.apple.network.local-network`:

- `AllowedWiFiLocalNetworkAddresses`
- `AllowedEthernetLocalNetworkAddresses`

Access uses `/usr/bin/osascript` and `/usr/bin/defaults` under administrator privileges, with the same domain and execution identity as Apple's `sudo defaults` example. Arrays are passed as typed XML property lists; the result is equivalent to `defaults write DOMAIN KEY -array …`. The on-disk storage path is not assumed.

No background service is installed. HallPass requires no network connection. The main **ⓘ** popover includes a link to [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), which opens in the default browser.

## Backups

Before each real save, HallPass writes the previously loaded state to `~/Library/Application Support/HallPass/Backups/`. The **Backups** menu lets you export the last loaded or saved state, import a backup as a draft, and open the backup folder. Imports modify system settings only after **Änderungen prüfen → Übernehmen** (Check Changes → Apply).

**Alle Freigaben entfernen…** (Remove All Exemptions) clears both exemption lists in the draft. After applying and rebooting, apps revert to their regular local-network permissions. Other keys in the same domain are preserved.

Before writing, the baseline is re-checked; concurrent changes by other tools cause an abort and a prompt to reload. Write errors trigger a best-effort rollback of the affected keys. This is not a system-wide transaction.

Missing keys and empty arrays are distinguished. Unusual string values found on disk are preserved through load and backup cycles but must be valid CIDRs before saving.

## Build

Prerequisites: Xcode with Swift 6 and the macOS SDK. No package downloads are required.

```sh
./scripts/build-app.sh
open dist/HallPass.app
```

This produces `dist/HallPass.app` on the host architecture. Set `HALLPASS_BUILD_DIR` and/or `HALLPASS_OUTPUT_DIR` to override the build and output directories.

The app is locally ad-hoc signed; it is not signed with an Apple developer certificate nor notarized.

## Icon artwork

The full square source is [assets/HallPass-icon.png](assets/HallPass-icon.png). The build resamples it into all ten macOS icon sizes and packages `HallPass.icns`; the same artwork appears in the sidebar. The artwork was created with the built-in image generation tool; its [exact prompt](assets/HallPass-icon.prompt.txt) is included.

## Tests

```sh
swift test
```

Tests cover CIDR edge cases, backup serialization, type handling, conflict detection, preservation of unrelated keys, and save/rollback logic. Integration tests use only temporary plist domains — no real network settings and no administrator prompts. The macOS preferences service may block these temporary accesses in a restrictive sandbox.

The real privileged write path and post-reboot effect were not exercised during development testing; validating them requires a test installation, a reboot, and a normally-launched GUI app (terminal and root processes already have exemptions per Apple).

## License

HallPass's own code is released under the [Unlicense](LICENSE). The app bundles no third-party components.

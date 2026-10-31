# Changelog

All notable changes to this project are documented in this file, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-10-31

- Add the HallPass SwiftUI app: load the system-wide local-network CIDR
  exemptions for Wi-Fi and Ethernet, draft additions and removals in a preview
  or against the live configuration, and apply them with administrator
  privileges.
- Add `HallPassCore` with CIDR parsing and normalization, configuration
  diffing, backup round-trips, baseline conflict detection and best-effort
  rollback on write errors.
- Add backup export/import and a remove-all-exemptions draft action.

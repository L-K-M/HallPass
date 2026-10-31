# AGENTS.md

Guidance for AI coding agents working in the **HallPass** repository.

## What HallPass Is

HallPass is a SwiftUI macOS app that manages **system-wide** CIDR exemptions from
the macOS local-network privacy restriction (Apple TN3179). The exemptions it
edits apply to *all apps on the Mac*, not to HallPass itself. Requires macOS 26.
The interface is in German; Help and the selection inspector explain its scope.

## Tech Stack

- **Language:** Swift 6 (`swift-tools-version: 6.0`). No external dependencies —
  Foundation, SwiftUI and AppKit only.
- **Layout:** `Package.swift` at the root (two modules, no `.xcodeproj`):
  - `Sources/HallPassCore/` — pure logic: `CIDR`, `Configuration`,
    `PreferencePlan`, configuration editing and draft recovery formats.
  - `Sources/HallPass/` — the app: SwiftUI views, `HallPassModel`,
    `BackupStore`, `SystemPreferencesService` (the privileged boundary).
- **System access:** `/usr/bin/osascript` + `/usr/bin/defaults` under
  administrator privileges. Reads and writes exactly two keys in the fixed
  domain `com.apple.network.local-network`
  (`AllowedWiFiLocalNetworkAddresses`, `AllowedEthernetLocalNetworkAddresses`).
- **Backups:** before each real save, the loaded state is written to
  `~/Library/Application Support/HallPass/Backups/`.
- **Recovery:** real drafts and their original baselines are atomically saved to
  `~/Library/Application Support/HallPass/Draft.json`; preview never writes it.
  Failed recovery originals are moved unchanged into Backups. If that fails,
  real editing is blocked so the original cannot be overwritten.
- **Window:** one machine-wide draft; native sidebar, table, inspector and
  toolbar. Closing the window keeps the app running. Draft undo is separate
  from committed system state and clears on successful loading/applying.

## Build & Test

```sh
swift build            # package
swift test             # Core + AppKit model tests; temp plist domains, no admin prompts
./scripts/build-app.sh # dist/HallPass.app, ad-hoc signed (--debug, --universal)
```

Use Xcode 26 or later. `HallPassCoreTests` also runs on Linux; the app, model
tests and `defaults` integration tests require macOS. CI launches preview and
retains an actual screenshot alongside the universal app archive.

`scripts/build.sh` / `scripts/release.sh` are thin stubs over the shared
`lkm-build` / `lkm-release` engines (the `release-tool` repo); the build engine
delegates assembly to `scripts/build-app.sh` via the `swiftpm` kind. The release
engine's `plist` kind bumps `CFBundleShortVersionString` in `Info.plist` and
keeps the README version marker in step. Releases are cut by tagging:
`scripts/release.sh X.Y.Z --push` — see `CICD.md`.

## Conventions

- Standard Swift API Design Guidelines; one type per file; `// MARK:` sections.
- Keep `HallPassCore` free of AppKit, privilege escalation and process spawning —
  it is the half that must stay unit-testable.
- Comments explain *why*; the privileged-write design (baseline re-check,
  rollback, missing-vs-empty distinction) is deliberate and load-bearing.

## Critical Constraints

- **Never touch preference keys outside the two managed ones.** Other keys in
  the domain must survive load/save cycles untouched.
- **Writes re-check the baseline first.** A concurrent change by another tool
  aborts the save and prompts a reload; write errors trigger a best-effort
  rollback of the affected keys. Don't weaken either guard.
- **Missing keys and empty arrays are different states** — preserve the
  distinction through load, draft and backup.
- **Unusual on-disk values are preserved** through load/backup but must parse as
  valid CIDRs before a save may proceed.
- **No background service, no network access.** Preview mode must keep working
  with zero system access.
- **Bundle id is `ch.lkmc.HallPass`** — keep it and
  `NSHumanReadableCopyright` ("Public domain (Unlicense)") consistent with
  `LICENSE`; `ci.yml` asserts both.

## Testing Notes

- Unit-test pure logic in `HallPassCore`: CIDR parse/normalize edge cases,
  plan diffs, backup serialization, preservation and rollback rules.
- Integration tests use only temporary plist domains — never real network
  settings. The macOS preferences service may block temp-domain access in a
  restrictive sandbox; that's environmental, not a code failure.
- The privileged write path and the post-reboot effect need a real macOS
  install and a reboot; they are verified manually and cannot run in CI.

## Do / Don't

- **Do** update `README.md`/`AGENTS.md`/`CICD.md` when behavior or workflows change.
- **Don't** add third-party dependencies; system frameworks only.
- **Don't** commit signing credentials or provisioning profiles.
- **Don't** widen the privileged surface: no new preference domains, no helper
  daemon, no per-app permission management.

<!-- shared-rules:start -->

## Working practices

- Follow explicit task instructions over the default workflow below.
- Writing the code is not finishing the task. A task is finished when
  its changes are merged to main through a PR that passed CI and review,
  or when the user explicitly accepts a different end state.
- Start every task on current code. Fetch first, then cut the task
  branch from origin/main — never from a stale local branch or an old
  checkout. To continue existing work, rebase or merge the latest
  origin/main into it before editing. Never overwrite existing work to
  update.
- Resolve ambiguity before making consequential changes. State low-risk
  assumptions; ask when scope, safety, or expected behavior is unclear.
- Keep changes focused. Do not modify unrelated code, formatting, or comments.
- Prefer surgical edits over whole-file rewrites when the result is equivalent.
- Stage only intended files. Inspect the diff before committing.

## Communication

- Be concise, factual, and direct. Preserve necessary context and uncertainty.
- Avoid praise, motivational filler, emojis, and em dashes in new prose.
- Address the reader directly in user-facing copy.
- Report what was verified and what remains unverified. Never imply that an
  unavailable check passed.

## Code design

- Prefer early returns and shallow nesting. Separate logical blocks with
  blank lines.
- Use descriptive constants or enums for meaningful or repeated values.
  Use existing standard definitions for protocol/specification constants.
  Keep obvious, one-off values inline.
- Use enums for behavioral modes that would otherwise require ambiguous
  boolean arguments.
- Default members to private. Widen visibility only for required consumers,
  and review the change as an API design decision.
- Follow the repository's declared dependency boundaries. UI and controllers
  must use application services rather than directly accessing databases,
  subprocesses, sockets, or other low-level mechanisms.
- Encapsulate low-level mechanics behind domain-oriented interfaces.
- Reuse genuinely shared logic. Avoid speculative abstractions and layers
  that only forward calls.
- Prefer pure functions for business rules and immutable data where practical.
  Isolate side effects; document non-obvious state ownership or synchronization.
- Explain non-obvious intent, constraints, and tradeoffs in comments.
  Do not narrate obvious code. Add examples or diagrams when they clarify it.

## Validation and errors

- Validate untrusted input at entry points. Where practical, represent valid
  states in types and enforce persistent invariants in database schemas.
- Represent absence and failure explicitly.
- Use assertions for internal programming invariants, not external-input
  validation or required runtime error handling.
- Prefer explicit, actionable errors over silent failure or undocumented
  fallback. Document intentional recovery behavior.
- Never report a skipped or failed operation as successful.

## Bug fixes

1. Identify the root cause and define an observable success criterion.
2. Add a regression test and observe the relevant failure before fixing it.
3. Implement the fix and observe the test passing.
4. Check surrounding behavior for regressions and architectural consistency.

If an automated regression test is impractical, document the reproduction
and verification procedure. State any inability to reproduce the failure.

## Verification

- Run relevant tests and lint after changes.
- Choose coverage by affected behavior and risk, not patch size.
- Use integration or end-to-end tests for critical workflows and boundaries;
  test isolated business rules at the lowest effective level.
- Run broader suites for cross-cutting or high-risk changes, and the full
  required release checks before releasing.
- Validate the requested command, options, platform, and configuration.
  Unrelated green CI is not proof that the reported problem is fixed.
- Recheck after the final edit. Distinguish local checks from CI results.

## Commit messages

- Use a capitalized, imperative subject without a final period.
- Target 50 characters; never exceed 72.
- Separate the subject and body with one blank line.
- Wrap body text at 72 characters.
- Explain what changed and why. Leave implementation mechanics to the code.

## Implementation and review

Unless explicitly instructed otherwise:

1. Work on a focused branch cut from the latest origin/main and open a PR
   against main before reporting the task as done.
2. Inspect CI results and completed review feedback for the latest commit.
   A successful reviewer job does not mean the review found no problems.
3. Address important findings or explain why they do not apply. Handle minor
   findings according to the stopping rules below.
4. Evaluate each fix in the surrounding project, add regression coverage,
   and rerun affected checks before pushing.
5. Repeat until a stopping criterion is met.
6. Merge without asking again once the stopping criterion is met, required
   checks pass on the latest commit, and no unresolved blockers or required
   human review requests remain.

### Reviewer context limits

The automated PR reviewer does not see the user's original prompt or
conversation. It may suggest changes that go against or beyond what the
user asked for. Do not implement such suggestions. Note each conflict and
report it to the user at the end of the thread.

### Automated review stopping rules

Judge findings by verified impact, not the reviewer's severity label.
Important findings concern correctness, security, data loss, broken builds,
or materially degraded behavior/performance.

Track completed review rounds and consecutive rounds without important
findings. Reruns of the same revision and integration failures do not count.

- No applicable actionable feedback: finish immediately.
- First minor-only round: optionally fix worthwhile, low-risk findings.
  Do not manufacture another push merely to obtain another review.
- Two consecutive rounds without important findings: stop responding to
  automated nitpicks, even if actionable minor suggestions remain.
  Defer worthwhile leftovers rather than continuing the cycle.
- A confirmed important finding resets the minor-only streak. Address it
  and verify the fix before continuing.

After ten completed rounds, enter stabilization:

- Stop optional cleanup, refactoring, and nitpick fixes.
- One completed review without confirmed important findings is sufficient
  to finish, even if minor suggestions remain.
- Continue only for confirmed important defects. If resolving them stalls,
  report the blockers rather than continuing indefinitely.

These limits end optional automated-feedback work. They do not waive
confirmed blockers, unresolved human review requests, or required checks.

### Reviewer integration failures

After two consecutive reviewer-integration failures, stop and report the
review gap. Do not treat failures as approval. An explicit user instruction
may waive review; report that waiver rather than claiming review passed.

## Ending a task

- A task ends with its changes merged to main — not with code written,
  and not with a PR merely opened. An open PR is work in progress:
  monitor CI on the latest commit, address review findings per the
  stopping rules, and merge once the criteria are met.
- Never finish with uncommitted changes or unpushed commits in the
  worktree. Commit, push, and open or update the PR first.
- If a step is impossible (missing push access, CI failure, reviewer
  outage), report the exact blocker instead. Never present unreviewed or
  unmerged work as finished.
- Before finishing, confirm: the requested behavior is implemented
  without unrelated changes; relevant checks pass on the latest code;
  important review findings are addressed or rejected with reasons;
  deferred suggestions, remaining risks, and validation gaps are
  disclosed.
- The final response states where the work stands: branch, PR, CI
  status, review rounds completed, and whether it is merged.

<!-- shared-rules:end -->

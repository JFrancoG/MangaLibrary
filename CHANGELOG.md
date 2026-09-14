# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- 2026-09-10 | ✨ feat(watch): add read-only reading companion
- 2026-09-07 | ✨ feat(widget): add reading and collection widgets
- 2026-09-06 | ✨ feat(deluxe): publish committed reading events
- 2026-09-06 | ✨ feat(deluxe): prepare durable reading covers
- 2026-09-06 | ✨ feat(deluxe): bound reading publications
- 2026-09-06 | ✨ feat(deluxe): project persisted reading state
- 2026-09-06 | ✨ feat(deluxe): add durable reading bridge
- 2026-09-04 | ✨ feat(session): resolve pending logout work
- 2026-09-04 | ✨ feat(collection): resolve uncertain outcomes
- 2026-09-03 | ✨ feat(collection): add safe outbox recovery states
- 2026-09-03 | ✨ feat(ui): distinguish tabs and volume controls
- 2026-09-03 | ✨ feat(collection): cap volume numbers at 300
- 2026-09-03 | ✨ feat(collection): sync collection deletions
- 2026-09-02 | ✨ feat(collection): upload queued collection changes
- 2026-09-02 | ✨ feat(collection): import remote snapshot
- 2026-09-01 | ✨ feat(collection): add offline collection flows
- 2026-09-01 | ✨ feat(collection): add atomic SwiftData core
- 2026-09-01 | ✨ feat(account): complete S2.2 account flows
- 2026-08-31 | ✨ feat(account): add fail-closed registration linked to S1
- 2026-08-30 | ✨ feat(session): add recoverable dual-token identity session
- 2026-08-28 | ✨ feat(ui): implement Library Red

### Changed

- 2026-09-14 | ♻️ refactor(ui): simplify forms and confirmations

- 2026-09-14 | ♻️ refactor(collection): simplify outbox validation and flight cleanup

- 2026-09-14 | 💄 style(deluxe): compact image type validation

- 2026-09-12 | ♻️ refactor(project): organize files and compact Swift

- 2026-09-12 | ♻️ refactor(collection): extract blocked outcome persistence

- 2026-09-12 | ♻️ refactor(app): extract debug UI testing bootstrap

- 2026-09-12 | ♻️ refactor(deluxe): centralize shared contract constants

- 2026-09-12 | ♻️ refactor(concurrency): remove redundant annotations

- 2026-09-11 | 💄 style(swift): normalize S01 source layout

- 2026-09-03 | 💄 style(swift): normalize R2 source layout
- 2026-09-02 | ♻️ refactor(concurrency): remove redundant Sendable conformances
- 2026-09-01 | ♻️ refactor(ui): simplify typed color resources
- 2026-09-01 | 💄 style(swift): normalize source layout

### Fixed

- 2026-09-14 | 🐛 fix(app): recover from storage startup failures

- 2026-09-14 | 🐛 fix(catalog): recover loading after cancelled reentry

- 2026-09-11 | 🐛 fix(ui): use brand ink for collection completion

- 2026-09-11 | 🐛 fix(collection): scope outbox to active user

- 2026-09-11 | 🐛 fix(watch): retry failed cache persistence

- 2026-09-11 | 🐛 fix(deluxe): authorize Watch recovery
- 2026-09-11 | 🐛 fix(deluxe): preserve dates and record DX6 validation
- 2026-09-08 | 🐛 fix(widget): complete accessible widget states
- 2026-09-06 | 🐛 fix(accessibility): unblock keyboard sign out
- 2026-09-04 | 🐛 fix(accessibility): preserve VoiceOver context
- 2026-09-02 | 🐛 fix(session): use Collection-compatible single JWT
- 2026-09-02 | 🐛 fix(sync): prevent collection auth loop
- 2026-08-31 | 🐛 fix(account): improve signed-out actions

### Documentation

- 2026-09-11 | 📝 docs(delivery): align D01 presentation drafts

- 2026-09-11 | 📝 docs(api): clarify D03 functional acceptance

- 2026-09-11 | 📝 docs(deluxe): reconcile D02 delivery status

- 2026-09-10 | 📝 docs(deluxe): record DX5 delivery
- 2026-09-08 | 📝 docs(deluxe): record DX4 delivery

- 2026-09-06 | 📝 docs(deluxe): link the DX3 delivery

- 2026-09-06 | 📝 docs(delivery): record Deluxe pull requests
- 2026-09-06 | 📝 docs(deluxe): approve DX1 reading contract
- 2026-09-06 | 📝 docs(deluxe): record approved implementation plan
- 2026-09-04 | 📝 docs(delivery): record Q2 pull request
- 2026-09-04 | 📝 docs(delivery): record A1 pull request
- 2026-09-04 | 📝 docs(validation): record R2.4 DocC gate
- 2026-09-04 | 📝 docs(delivery): record R2.4 pull request
- 2026-09-03 | 📝 docs(delivery): record R2.3 pull request
- 2026-09-03 | 📝 docs(collection): define safe R2.3 outbox recovery
- 2026-09-03 | 📝 docs(delivery): record UI polish pull request
- 2026-09-03 | 📝 docs(delivery): record volume cap pull request
- 2026-09-03 | 📝 docs(delivery): record R2 pull request
- 2026-09-02 | 📝 docs(delivery): record single-JWT PR
- 2026-09-02 | 📝 docs(session): adopt single-JWT authority and Keychain V3
- 2026-09-02 | 📝 docs(collection): resolve remote manga identity
- 2026-09-02 | 📝 docs(delivery): record auth loop PR
- 2026-09-02 | 📝 docs(delivery): record R1 pull request
- 2026-09-02 | 📝 docs(delivery): record Sendable cleanup PR
- 2026-09-01 | 📝 docs(delivery): record L2 pull request
- 2026-09-01 | 📝 docs(delivery): record Color cleanup PR
- 2026-09-01 | 📝 docs(delivery): record Swift style PR
- 2026-09-01 | 📝 docs(delivery): reconcile L1 status
- 2026-09-01 | 📝 docs(delivery): record L1 pull request
- 2026-09-01 | 📝 docs(collection): record L1 validation
- 2026-09-01 | 📝 docs(governance): route Swift style through reusable audit skill
- 2026-09-01 | 📝 docs(delivery): record S2.2 pull request
- 2026-08-31 | 📝 docs(delivery): record S2.1 pull request
- 2026-08-31 | 📝 docs(delivery): record S2 pull request
- 2026-08-31 | 📝 docs(account): record S2 registration contract and evidence
- 2026-08-30 | 📝 docs(session): record S1 delivery
- 2026-08-30 | 📝 docs(session): define versioned Keychain and ledger authority
- 2026-08-28 | 📝 docs(roadmap): sequence identity, local persistence and sync

### Tests

- 2026-09-14 | ✅ test(quality): make test gates deterministic

- 2026-09-11 | ✅ test(quality): remove structural tests and strengthen T02 oracles

- 2026-09-06 | ✅ test(deluxe): verify the complete publication pipeline

### Maintenance

- 2026-09-11 | 🔧 chore(previews): add local widget component previews

- 2026-09-11 | 🔧 chore(widget): remove seven retired localization keys

- 2026-09-11 | 📦 build(deluxe): enforce complete release gates

- 2026-09-04 | 🔧 chore(release): enforce clean Advanced gate

### Tests

- 2026-09-04 | ✅ test(tooling): enforce the native test-plan partition
- 2026-09-02 | ✅ test(collection): cover safe POST outbox pipeline
- 2026-09-02 | ✅ test(session): cover JWT renewal and V3 migration
- 2026-09-01 | ✅ test(collection): cover persistence contract
- 2026-08-31 | ✅ test(account): cover registration contract, uncertainty and synthetic UI flow
- 2026-08-30 | ✅ test(session): cover authentication, persistence recovery and Account states
- 2026-08-28 | ✅ test(catalog): remove tautological query tests

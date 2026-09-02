# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- 2026-09-02 | ✨ feat(collection): import remote snapshot
- 2026-09-01 | ✨ feat(collection): add offline collection flows
- 2026-09-01 | ✨ feat(collection): add atomic SwiftData core
- 2026-09-01 | ✨ feat(account): complete S2.2 account flows
- 2026-08-31 | ✨ feat(account): add fail-closed registration linked to S1
- 2026-08-30 | ✨ feat(session): add recoverable dual-token identity session
- 2026-08-28 | ✨ feat(ui): implement Library Red

### Changed

- 2026-09-02 | ♻️ refactor(concurrency): remove redundant Sendable conformances
- 2026-09-01 | ♻️ refactor(ui): simplify typed color resources
- 2026-09-01 | 💄 style(swift): normalize source layout

### Fixed

- 2026-09-02 | 🐛 fix(session): use Collection-compatible single JWT
- 2026-09-02 | 🐛 fix(sync): prevent collection auth loop
- 2026-08-31 | 🐛 fix(account): improve signed-out actions

### Documentation

- 2026-09-02 | 📝 docs(delivery): record single-JWT PR
- 2026-09-02 | 📝 docs(session): adopt single-JWT authority and Keychain V3
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

- 2026-09-02 | ✅ test(session): cover JWT renewal and V3 migration
- 2026-09-01 | ✅ test(collection): cover persistence contract
- 2026-08-31 | ✅ test(account): cover registration contract, uncertainty and synthetic UI flow
- 2026-08-30 | ✅ test(session): cover authentication, persistence recovery and Account states
- 2026-08-28 | ✅ test(catalog): remove tautological query tests

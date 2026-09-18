# Manga Library

**English** | [Español](README.es.md)

A native SwiftUI app for browsing manga and managing a personal collection on
iPhone and iPad. Track owned volumes, reading progress and complete collections
with local persistence and account-based synchronization. Home Screen widgets
and a read-only Apple Watch companion extend the experience.

## Features

- **Catalog:** incremental pagination, search, filters, top-rated manga, list and grid layouts, and detail views. Browsing does not require an account.
- **Collection:** offline access to locally available data, owned volumes, reading progress and complete-collection status, stored with SwiftData.
- **Account and sync:** registration, a single JWT session in Keychain, an outbox for local changes, and explicit resolution of uncertain remote writes.
- **Widgets:** small and large widgets show reading progress; the medium widget shows a collection entry. Updates follow committed local changes, with bounded rotation; WidgetKit controls when content actually appears.
- **Apple Watch:** read-only reading snapshots delivered through WatchConnectivity, with compatible offline cache and no independent login.
- **Interface:** Spanish and English, adaptive iPhone/iPad navigation, Library Red light/dark colors, and accessibility evidence recorded per surface.

## Project status

Documentation reviewed on **September 18, 2026**, against `main` at `6dfc59d`.

**Advanced is delivered and the technical implementation of Deluxe DX1–DX7 is
integrated.** Formal Deluxe tracking remains at **5/7 completed subphases**:
DX6 and the full Deluxe Release Gate retain physical checks in
[#88](https://github.com/JFrancoG/MangaLibrary/issues/88) and
[#77](https://github.com/JFrancoG/MangaLibrary/issues/77).

- **H01:** iPhone protection before first unlock remains limited/not observable and pending; it has not been deferred.
- **H02–H04:** physical Watch pairing, reconnection, background delivery and assistive-technology checks are deferred until after delivery by the recorded owner decision. Simulator evidence does not complete them.
- **Latest integrated change:** C6 prepared-cover reuse, [PR #125](https://github.com/JFrancoG/MangaLibrary/pull/125). Maintenance since DX7 also covers catalog cancellation/re-entry, deterministic tests, recoverable storage startup and simpler collection/account flows.

The latest recorded automated checkpoint is **C6, September 14**: ReleaseGate
passed **846 test declarations / 1,274 invocations**, including 13 UI tests, on
iPhone 17 Simulator with iOS 27. Five-target Debug/Release builds and the DocC
archive completed without warnings or errors. These are dated results, not a
new validation run or approval of the full physical gate. See
[progress and evidence](docs/Progress.md).

The original delivery target was September 15, 2026. Public access for assessment
does not itself establish completion of the delivery criteria in
[SDD 08](docs/specs/08-delivery-presentation-and-video.md). The video is optional.

## Requirements and setup

- Xcode 27 with the Swift 6.4 compiler, Swift 6 language mode and strict concurrency checking.
- iOS/iPadOS 27 for the main app and widgets; watchOS 27 for the companion.
- Apple frameworks only; no third-party package installation.

1. Open `MangaLibrary.xcodeproj` in Xcode.
2. Select the shared `MangaLibrary` scheme and an iPhone or iPad simulator with iOS 27. Use `MangaLibraryWatch Watch App` for companion work.
3. Run the app to browse the public catalog. Normal catalog requests need a network connection; offline collection access uses previously stored data.
4. To enable registration, copy [`Configuration/Local.xcconfig.example`](Configuration/Local.xcconfig.example) to `Configuration/Local.xcconfig` and set `MANGA_LIBRARY_APP_TOKEN` locally using the approved private channel. The copy is ignored by Git. Missing registration configuration does not prevent public catalog browsing.

For physical devices, use the approved signing and App Group setup; capability
or entitlement changes require separate authorization. Tests and previews use
synthetic fixtures and do not require real accounts, tokens or production access.

## Architecture and quality

Features own their state and navigation. The composition root creates shared
dependencies; SwiftData and `@Query` provide the local source observed by the
interface, with serialized mutations through `@ModelActor`. Remote and transient
presentation state belongs to `@Observable @MainActor` models. Cross-isolation
work uses identifiers and `Sendable` values with structured concurrency.

The main app owns authentication, collection edits and synchronization. Widgets
and Watch consume read-only projections; they do not become independent data
authorities. [Specifications](docs/README.md#especificaciones) and
[accepted ADRs](docs/adr/README.md) define the contracts.

The shared scheme provides four test plans: `Fast` (default), `Integration`,
`UI` and `ReleaseGate`. Unit and integration tests use Swift Testing; approved
UI tests use XCUITest. Swift, Clang and DocC warnings are errors. Test execution,
five-target builds, DocC and manual evidence are separate validation steps.

See the [development and validation guide](docs/development.md) for local
configuration, official Xcode MCP usage and reproducible gate commands.

## Documentation

Detailed project documentation is maintained mainly in Spanish. This README and
its [Spanish version](README.es.md) describe the same scope and limitations.

- [Documentation index](docs/README.md)
- [Development and validation](docs/development.md)
- [Repository instructions](AGENTS.md)
- [Progress and dated evidence](docs/Progress.md) · [Changelog](CHANGELOG.md)
- [Architecture decisions](docs/adr/README.md)
- [Presentation outline](docs/presentation/outline.md) · [Optional video storyboard](docs/video/storyboard.md)
- [Sources and authority](docs/Sources.md)

Human documentation lives in `docs/`; the DocC source catalog lives in
`MangaLibrary/Documentation/MangaLibrary.docc/`. Generated archives, presentation
files, video and private preparation notes stay outside Git.

## Access and reuse

The owner has made this repository **temporarily public for academic assessment**.
[ADR 0023](docs/adr/0023-temporary-public-access-for-assessment.md) records that
exception and preserves the existing source and privacy boundaries.

Do not commit usable credentials, real accounts or private paths. The only
approved complete teaching source is the sanitized assignment; its sample
`App-Token` is replaced by 42 `X` characters. See [source boundaries](docs/Sources.md).

This repository does not include a reuse license. Access does not grant
permission to redistribute the code or teaching material; all rights reserved.

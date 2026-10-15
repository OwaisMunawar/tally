# Contributing

Thanks for taking a look. Tally is small on purpose, so changes are easiest to
review when they stay in one package and come with tests.

## Setup

Requirements: Xcode 26.6, XcodeGen 2.46, SwiftLint 0.65 and an iOS 26.5 simulator.

```sh
brew install xcodegen swiftlint
xcodegen generate
open Tally.xcodeproj
```

`Tally.xcodeproj` is generated from `project.yml` and is not committed. Edit
`project.yml` and re-run `xcodegen generate` instead of changing project settings
in Xcode. Xcode 26 installs the Metal compiler separately; if the build stops at
`Holographic.metal`, run `xcodebuild -downloadComponent MetalToolchain` once.

## Where code goes

| Change | Package |
| --- | --- |
| Money, FX, dates, recurrence, CSV, budgets, queries | `TallyCore` (no Apple UI frameworks) |
| Persistence | `TallyData` |
| Anything that talks to Foundation Models | `TallyIntelligence` |
| Reusable views, charts, the shader | `TallyUI` |
| Screens and wiring | `App/`; widget and control in `Widgets/`; intents shared by both in `Shared/` |

Rules that reviews hold to:

- Money is `Money` (minor units) or `Decimal`. Never `Double`, except `chartValue` for drawing.
- New numbers shown to the user come from `LedgerQueryEngine`, so Ask Tally can be held to them.
- Every new Ask Tally tool returns pre-computed figures in words; the model never does arithmetic.
- No singletons in domain code. Pass dependencies in.
- Swift 6 strict concurrency with warnings as errors, and `swiftlint lint --strict` clean.

## Tests

```sh
swift test --package-path Packages/TallyCore
swift test --package-path Packages/TallyData
swift test --package-path Packages/TallyIntelligence
xcodebuild -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

Tests use Swift Testing. The StoreKit purchase suite in `AppTests` needs a
build that Xcode installed for development, so run it from Xcode with
`STOREKIT_TESTING=1` in the Tally scheme's test environment. It skips everywhere else.

The `TallyUITests` scheme drives SpringBoard to add the widget and the control
and uses them. It is slow and not part of CI.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/): `feat(core): …`,
`fix(app): …`, `docs: …`. Keep each commit building.

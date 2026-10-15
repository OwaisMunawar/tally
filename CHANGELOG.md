# Changelog

All notable changes to Tally are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-15

### Added
- Accounts (cash, bank, card) in any currency, with user-entered exchange rates and no network access.
- Transactions with payee, notes, tags and recurring templates that post themselves idempotently.
- CSV import with RFC 4180 parsing, column mapping, date and decimal-format detection and a line-by-line preview.
- Ask Tally: on-device Foundation Models chat that answers through five typed tools, with every figure checked against tool output and a visible tool trace.
- Hybrid auto-categoriser: learned rules, shipped keyword rules, then `@Generable` guided generation with a confidence score.
- Monthly insight written on device, with a deterministic template fallback.
- Monthly category budgets with progress rings and a once-per-month over-budget notification.
- Swift Charts for cumulative spend, category share and cash flow, all with interactive selection.
- App Intents for adding an expense, asking how much was spent and showing budgets; App Shortcuts; `IndexedEntity` transactions and payees.
- Home-screen widget with budget left and one-tap repeat purchases, plus a Control Center control for quick add.
- Liquid Glass throughout and a Metal holographic sheen on account cards.
- Face ID / passcode app lock with a privacy shield in the app switcher.
- Tally Plus via StoreKit 2 `SubscriptionStoreView`, with entitlements derived from `Transaction.currentEntitlements`.
- `-demoData` launch argument with six months of fictional data across three accounts and two currencies.

[0.1.0]: https://github.com/OwaisMunawar/tally/releases/tag/0.1.0

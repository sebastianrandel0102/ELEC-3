# SaveTrack global currency system

## Implemented behavior

Open **Profile → Currency Settings** to search by ISO code, English currency name, or associated country/region. The mint gradient screen includes a current-currency card, popular choices, selected indicators, a PHP 1,000 conversion preview, Apply Currency, provider/fetch timestamps, a real refresh action, and a standalone converter with direction swap. Catalog rows are lazy. Animations respect reduced-motion settings.

The catalog contains **155 active fiat currencies**, generated from the [SIX ISO 4217 List One](https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml), published **2026-09-17**. English names/symbols come from [Unicode CLDR](https://github.com/unicode-org/cldr-json/tree/main/cldr-json/cldr-numbers-full/main/en). Metals, funds, accounting units, crypto, and retired codes are excluded. The provider's documented coverage is bundled separately. Recognized currencies, unsupported currencies, and temporarily absent quotes are distinct; a conversion requires both applicable validated quotes. Newly documented codes can also become available from actual provider responses. No exchange rates are bundled in production.

Run `py -3 tools/update_currency_catalog.py` to refresh metadata and synchronize the active-code and precision rules; then format, inspect the diff, and run the tests. Catalog updates do not migrate existing records. Historical denominations lacking current metadata remain displayed in their original code with conversion unavailable.

## Provider and refresh policy

The integration uses [ExchangeRate-API's documented open endpoint](https://www.exchangerate-api.com/docs/free): `https://open.er-api.com/v6/latest/USD`. This is a public, keyless service with daily updates and rate limiting. Direct HTTPS retrieval and browser CORS were checked during implementation; the endpoint responded successfully with `Access-Control-Allow-Origin: *`. Its [terms](https://www.exchangerate-api.com/terms) permit local end-use caching and require attribution. Currency Settings retains clickable attribution, rate status, and full timestamps. The bottom currency-status strip was removed at the user's request. The app does not redistribute raw rate data through a public API.

There are no provider credentials in source, assets, Firebase configuration, or public documents. No new backend or paid service was introduced. The provider supplies informational reference rates, not executable bank quotes or real currency exchange. The open endpoint has no historical-rate API and offers no tick-by-tick pricing or availability guarantee. Pricing/coverage/terms can change; recheck the linked documentation before a release or provider migration.

The app loads one validated device-local snapshot before making requests. Refresh runs at sign-in/startup when needed, foreground resume, and a 15-minute foreground timer that checks freshness without fetching on every tick. `CurrencyController.refreshInterval` defaults to one day and is configurable; provider `time_next_update_unix` also determines staleness. Requests are deduplicated and throttled to **one attempt per hour**, including manual refresh. A fresh cached fetch also prevents repeated requests across restarts. Network failures retain the previous snapshot. Refresh never runs during widget builds or on each amount keystroke.

Snapshot metadata includes provider, base, quote map, snapshot ID, provider timestamp, next-update timestamp, fetch timestamp, and cache schema version. Validation rejects malformed JSON, non-success responses, incorrect base quotes, nonpositive/nonfinite rates, malformed/future timestamps, and regressions to older snapshots. A missing quote never defaults to 1. HTTP 429, HTTP failures, timeout, and invalid local cache are handled without fabricated values.

## Persistence and authoritative money

Existing personal goals retain their numeric `targetAmount` and `savedAmount` in major units. Missing `currencyCode` means **PHP**. New goals store `currencyCode`; the denomination is fixed after creation. Editing a display preference never writes goal balances, targets, transactions, task data, or shared records. No destructive migration occurs.

User preference is `users/{uid}.preferredCurrencyCode`, merged into the existing profile. It falls back to the existing `currency` field, then PHP. The authenticated UID scopes the local preference. Applying a choice persists locally and queues the profile merge, so cached currencies remain usable offline. A pending sync is labeled, retained across restarts, retried on the next session, and protected from being overwritten by an old remote profile. A local save failure keeps the previous selection; a cloud sync failure is shown explicitly. Sign-out disposes profile/rate listeners and removes the user-specific controller.

Rate snapshots are cached in SharedPreferences under `savetrack.exchangeRates.v1`. Currency choices use UID-specific keys. Local snapshots are always validated before use; local caching is not a trusted server exchange-rate authority. There is no globally writable Firestore rate collection. Firestore remains the existing cloud database.

## Conversion and precision

`ExactDecimal` uses BigInt rational arithmetic, reducing fractions throughout addition, subtraction, multiplication, division, and aggregation. Cross quotes are `rate(base→target) / rate(base→source)`. Same-currency conversion works without any rate snapshot. All conversions start from authoritative amounts; display strings and previously rounded equivalents are never reused as inputs.

Half-away-from-zero rounding occurs at currency boundaries. SIX minor units support PHP/USD at two decimals, JPY at zero, KWD at three, and the other catalog conventions. Amounts use English UI grouping and explicit ISO codes with CLDR symbols where available, so dollars and pesos remain unambiguous. Large conversion previews use exact arithmetic. New stored personal amounts are limited to safely round-trippable numeric values up to 1 trillion major units; shared records retain the existing PHP 1 billion ledger cap. Existing records are not rewritten to fit these limits.

Dashboard and personal reports convert each goal before adding into a common currency, using one snapshot. Aggregation rounds at the final display boundary. If a conversion is unavailable, totals show grouped original denominations and an unavailable marker, without silently omitting goals. Cross-currency aggregate progress is hidden when its total cannot be computed. Each goal's completion percentage, deadlines, remaining amount, and daily/weekly requirements are calculated in its original denomination before display conversion.

## Deposits, decreases, history, and Save Together

Personal Add Savings and Decrease Savings default to the goal currency. A different input currency shows original input, goal-currency amount, exact applicable rate, provider time, and resulting balance before confirmation. Cross-currency recording requires a fresh applicable snapshot; stale snapshots remain usable for display estimates. Same-currency input and previews require no exchange-rate network call. Financial commits require the existing authenticated Firestore service to confirm the operation.

`LockedMoneyEntry` freezes the input and rate. Personal balance/history updates use a Firestore transaction with a stable request ID, balance revalidation, owner/session checks, and replay detection. Duplicate retries do not apply the amount twice. Decreases cannot overdraw; a known rejected request can be corrected while an uncertain request retains its confirmed payload.

Transaction `amount` remains the authoritative amount in the goal currency. New records add `currencyCode`; older deposits without type or denomination remain readable. Cross entries add a `conversion` map containing input amount/currency, goal currency, exchange rate, exact numerator/denominator, provider timestamp/name, and snapshot ID. The authoritative amount is not duplicated in a competing converted balance field. This metadata is immutable in the new recording flow.

Save Together keeps its **one authoritative PHP centavo ledger** and existing schema version 2. Shared balance, target, remaining amount, pace, group deposit/decrease reports, member deposits, invitations, and activity display equivalents in the member's chosen currency. Cross-currency shared entries confirm a PHP equivalent, validate locked metadata, and commit it through the existing atomic ledger protocol. Owner-only decreases, attribution, membership revocation, invitation limits, and idempotent receipts remain enforced. A group decrease preserves each member's lifetime deposit total. Shared goals currently cannot be created in non-PHP denominations; new personal goals can. Copying a non-PHP personal goal into a new shared goal converts only its copied target with fresh rates and starts a separate zero balance.

Historical activity displays the authoritative recorded amount, original cross-currency input and locked rate, and a separately labeled current-rate estimated equivalent. Existing reports have balance/progress and shared activity summaries, rather than historical personal monthly charts. No invented historical rates or new productivity-report changes are included. Shared group balances remain separate from personal savings and are never added into personal dashboard totals.

## Security and deployment

The updated rules preserve user isolation and shared permissions, fix denominations after creation, bind currency-aware personal records to their atomic balance update, constrain confirmed metadata, and keep new currency-aware history immutable. Shared centavo/balance/member invariants remain enforced. The rules also deny client writes to global exchange-rate documents. Locked rates represent user-confirmed tracking estimates; they are not server-attested financial settlement rates or authorization to transfer funds.

**Deployment remains external:** deploy `firestore.rules` to the existing Firebase project before shipping this app version (`firebase deploy --only firestore:rules`). Nothing was deployed to the live project during this task. Existing Firebase/OAuth configuration remains required for real account sign-in and live cloud sync. No currency Cloud Function, API key, App Check policy change, new database, or billing upgrade is needed. Android's debug build reports the existing Firebase plugins' Kotlin Gradle Plugin migration warning; the build succeeds.

## Files and dependencies

- New: `lib/currency_catalog_data.dart`, `currency_money.dart`, `currency_service.dart`, `currency_widgets.dart`, `currency_settings_screen.dart`, `currency_transactions.dart`, `currency_savings_dialog.dart`.
- Integration: `lib/main.dart`, `shared_savings_models.dart`, `shared_savings_repository.dart`, `shared_savings_screens.dart`, `shared_savings_store.dart`, and `firestore.rules`.
- Maintenance/report: `tools/update_currency_catalog.py`, this document, and `README.md`.
- Tests: new currency system/widget/rules tests; existing UI assertions updated for grouped ISO/symbol formatting; the existing emulator runner includes currency checks.
- Direct dependencies: `http`, `shared_preferences`, `intl`, `url_launcher`; corresponding lockfile and generated desktop plugin registrations updated.

## Verification and manual acceptance

Executed locally:

- `flutter pub get`: succeeded.
- `dart format .`: completed; all Dart files formatted.
- `flutter analyze`: no issues.
- `flutter test`: **254 tests passed**, including 38 new currency unit tests and 14 new currency widget tests alongside the existing regressions.
- `py -3 test/run_shared_emulator.py --java "D:/Program Files/Android/Android Studio/jbr/bin/java.exe"`: **51 rules tests passed**, including nine new currency security/compatibility checks.
- `flutter build web`: succeeded, including the Wasm compatibility dry run.
- `flutter build apk --debug`: succeeded; artifact at `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: no whitespace errors.
- Currency widget previews rendered and visually inspected at regular and narrow/large-text sizes. The mobile keyboard picker layout is tested separately.

Deterministic tests use fixed rate fixtures and no live forex requests. Security tests use an isolated demo emulator with unprivileged tokens and never connect to the production database. Widget previews are available under `build/ui-preview/currency-*.png` when run with `--dart-define=SAVE_UI_PREVIEWS=true`.

1. After deploying rules, sign in to an existing PHP account and confirm original goals still show their original values.
2. Open Currency Settings, search `USD`, apply it, and inspect dashboard, goal cards, pace, and reports. Switch PHP→USD→PHP and confirm stored balances never change.
3. Apply EUR, JPY, then KWD; verify ISO labels, zero/three-decimal formatting, actual timestamps, and updates across open financial screens.
4. Create a JPY personal goal and record same-currency savings. Choose USD input, inspect the confirmed JPY estimate, save, and inspect original input/locked metadata in history. Decrease below the balance, then attempt an overdraw.
5. Switch display currency after recording; the historical goal amount and locked rate must remain fixed while the current equivalent can change.
6. Use two accounts with a PHP shared goal and different display currencies. Confirm group balance consistency, contributor attribution, owner-only decreases, and separation from personal savings.
7. Cache rates, disconnect, and reopen. Cached estimates, provider times, locally saved preferences, and pending sync must be labeled. With stale/no quotes, cross entries are blocked while original denominations and unrelated planner features remain usable.
8. Try a recognized unsupported currency, an invalid amount, failed refresh, and repeated refresh taps. No fabricated equivalent or duplicate financial commit should appear.

Live two-account sign-in, real OAuth, actual offline Firestore synchronization, and release-device behavior still require manual acceptance with the configured project. Automated authentication/planner/password/shared regressions cover local code paths; they do not certify live credentials or production data.

# Daftari (دفتري) — V1 Development Plan

**Status:** Planning approved; implementation not started.  
**Platform:** Android first. **Audience:** Egyptian small-shop owners. **Language:** Arabic-first RTL, with English LTR.  
**Android application ID:** `com.mgb.daftari` — do not change without owner approval.

## 1. Product and scope

Daftari replaces a shopkeeper's paper credit notebook. The primary workflow must let a user add a customer credit or payment in **under 10 seconds** on a typical supported Android device. The ledger works without an account or internet. Drift/SQLite is the source of truth; Supabase is optional **backup and restore**, not live multi-device synchronization.

**Confirmed V1 core:** customers; credit/payment transactions; derived balances; dashboard; customer statements with WhatsApp sharing; PIN lock with optional biometric unlock; Arabic/English settings and light/dark/system theme; three-screen onboarding; optional email/password authentication; cloud backup; cloud restore and device transfer; Firebase Crashlytics; Google Play production preparation.

**Remaining scope reconciliation:** The original plan also mentioned contact import, keypad amount shortcuts, change-customer chooser, and dashboard tip cards. These are not yet explicitly allocated to the approved feature tasks; confirm their inclusion with the owner before implementation rather than silently removing or adding them. WhatsApp statements and PIN/biometrics **are included** as dedicated Phases 9 and 10.

**Non-goals:** payment processing, invoicing, multi-shop accounts, simultaneous multi-device cloud sync, push reminders, PDF reports, iOS release, and automatic Google Play publishing.

## 2. Decisions and invariants

1. **Money:** Store integer Egyptian piasters (`int`), never floating-point money. Balance = active credit sum − active payment sum; do not store an editable balance.
2. **Customers:** A customer may be soft-deleted even with an outstanding balance. Confirm with the amount, hide the customer and their transactions, and exclude them from dashboard totals. Preserve records; no restore UI in V1.
3. **Transactions:** Editing and soft-deleting a transaction records its previous values in append-only `transaction_audit_logs` with action, timestamp, UUID, and transaction ID. Perform the data change and audit insert atomically. Recalculate derived balances. Include audit logs in cloud backup/restore.
4. **Offline-first:** No login or network required for local ledger functionality. Network availability must not block local writes.
5. **Account isolation:** Signing out never erases local data. A ledger linked to account A cannot be opened under account B. The first account link for an unlinked local ledger must be deliberate and safe. No multi-profile support.
6. **Cloud backup:** One cloud-active phone per account. New phone may explicitly take over and restore the latest confirmed backup; old phone remains locally usable but loses backup authority. Do not build a conflict-resolution or live sync engine.
7. **Backup correctness:** Stable UUIDs, idempotent uploads, retries, acknowledgments before marking backed up, and revision checks so edits during upload stay pending. Persist deletion tombstones and audit history. Show last confirmed backup time; disclose that recent offline changes may not be in the cloud.
8. **Restore safety:** Never automatically overwrite a populated local ledger. Require confirmation, validate ownership, and restore atomically with duplication safeguards. Restoring cannot promise recovery of changes never backed up.
9. **Supabase ownership:** Enable RLS; `customers` has unique `(id, user_id)` and `transactions(customer_id, user_id)` references `customers(id, user_id)` to prevent cross-account customer/transaction association. Apply analogous account ownership checks to audit logs. Enforce backup-active device authority server-side, not only in the UI.
10. **Privacy:** Never send customer names, phone numbers, or monetary values to logs or Crashlytics custom keys.
11. **Design:** `design/` contains Figma UI references only. `assets/images/`, `assets/icons/`, and `assets/fonts/` contain actual runtime resources. Before any UI implementation, inspect the relevant design; do not invent an alternative layout. Flag missing designs or assets.
12. **Simplicity:** Avoid speculative abstractions, extra packages, and unrequested functionality.

## 3. Technology and dependencies

- Flutter/Dart, Material 3, `flutter_bloc` (Cubit), `get_it`, `go_router`.
- Drift/SQLite (`drift`, `drift_flutter`, `drift_dev`, `build_runner`), `uuid`, `fpdart` for consistent failures/results where useful.
- `shared_preferences` for theme/language/onboarding; `flutter_secure_storage` for sensitive local secrets when required.
- `flutter_localizations`, `intl`, ARB/gen-l10n, `flutter_screenutil` used through centralized `AppSpacing` and shared responsive helpers.
- Firebase: `firebase_core`, `firebase_crashlytics`; App Distribution through Fastlane plugin, not a Flutter runtime dependency.
- `supabase_flutter` installed in Phase 0, initialized only in the authentication/backup phases.
- `flutter_native_splash`, `flutter_launcher_icons` for Phase 3.
- `connectivity_plus`, `url_launcher`, `share_plus` and any approved original-plan V1 dependencies; omit `google_sign_in` because V1 authentication is email/password only. Include `local_auth` for the approved Phase 10 security feature; do not add a contact-picker package unless contact import is approved.
- Tests: `flutter_test`, `bloc_test`, `mocktail`, `integration_test`; lint package selected once. Include Marionette debug tooling required by the project's available integration, without shipping debug hooks in production.
- Select compatible package versions at setup time, commit `pubspec.lock`, and do not add packages in later feature phases without owner approval. Do not pin a Flutter SDK version until it is verified against the manually created project.

## 4. Architecture and folders

Dependency direction: **presentation → domain ← data**. Domain has no Flutter UI, Drift, or Supabase imports. Use cases and repository contracts are introduced only when the feature needs them. Core database DAOs are shared infrastructure; feature data repositories use them rather than creating duplicate schemas.

```text
design/                         # Figma UI references, never runtime assets
assets/{images,icons,fonts}/    # Actual runtime resources
lib/
  main.dart
  app.dart
  core/
    constants/
    theme/                     # AppColors, AppTypography, AppSpacing, AppTheme
    widgets/
    utils/
    errors/
    extensions/
    services/
    routing/
    di/
    database/                  # Added in Phase 4
      tables/
      daos/
      migrations/
  features/
    onboarding/
    settings/
    customers/
    transactions/
    dashboard/
    statements/
    security/
    auth/
    backup/
    restore/
  l10n/
test/
integration_test/
```

Each implemented business feature can contain `presentation/{screens,widgets,cubit}`, `domain/{entities,repositories,usecases}`, and `data/{models,repositories}`; create only necessary folders and files when that task starts. No empty feature skeletons in Phase 1.

## 5. Pre-Phase 0 — Owner preparation (manual)

Owner creates the Flutter project, Firebase project, Firebase Android app registered as `com.mgb.daftari`, GitHub repository with `master` and `development`, `design/` references, and `assets/` resources. Owner configures FlutterFire/Firebase project access and supplies required configuration. AI agent **must not recreate projects or change the application ID**. Verify the existing Android ID before Firebase setup. Keep secrets in secure GitHub configuration, not committed source files.

## 6. Approved phase-by-phase build order

### Phase 0 — Setup Daftari

**Goal:** Configure the existing projects and build pipeline, not app architecture.

Tasks: verify Flutter/Android package ID and Firebase registration; install approved V1 packages; configure Firebase Core and Crashlytics minimally (including uncaught Flutter/Dart error handlers); configure Android Firebase files; configure Fastlane **only** for Firebase App Distribution; configure the GitHub workflow; establish lint/format/test checks. Keep `lib/` otherwise at default project structure—**no core folders, theme, routing, widgets, or Drift code yet**.

**Done:** Android build succeeds; Crashlytics wiring is configured; `flutter pub get`, format, analyze, and tests pass; master-only CI builds and distributes a test APK after Firebase credentials and signing are configured.

### Phase 1 — Project Structure & Shared Components

Inspect **all** Figma references in `design/` first. Create `assets/` organization, `lib/core/` and `lib/features/` foundations, localization, `app.dart`, basic `go_router` placeholder route, `get_it` setup, theme tokens (`AppColors`, `AppTypography`, `AppSpacing`), `flutter_screenutil` integration, and genuinely reusable widgets (buttons, fields, scaffold, loading, empty/error states, confirmation dialog). Reuse only real assets from `assets/`. If a design is ambiguous, ask; do not invent a design system.

**Do not:** implement feature screens, feature Cubits, Drift tables, or Supabase repositories.

**Done:** Arabic RTL and English LTR, themes and responsive shared widgets work; placeholder screen launches; UI checked against references where applicable; tests pass.

### Phase 2 — Add Base Services to Daftari

Implement in `core/` only: `ConnectivityService`, simple-preferences `LocalStorageService`, privacy-safe `AppLogger`; `AppException`, `AppFailure`, `ErrorHandler`; money/date/validation utilities; small extensions; and `get_it` registrations. Money utility uses integer piasters. Avoid unnecessary service interfaces.

**Do not:** implement business features, Drift tables, Supabase backup, or feature-specific rules.

**Done:** focused unit tests, analyzer, and full tests pass.

### Phase 3 — App Intro

Configure launcher icon from `assets/icons/` and native splash from `assets/images/` using the installed tools, including Android 12+ constraints. Implement **three onboarding screens**: screen 1 uses the supplied Figma reference in `design/`; agent **proposes content only** for screens 2 and 3 for owner approval, and reuses the same approved design. Do not invent additional illustrations or layouts. Persist first-run completion, then navigate to the placeholder route. No auth or business logic.

**Done:** icon/splash work, onboarding is shown only until completion, navigation/RTL work, Marionette comparison and tests pass.

### Phase 4 — Write Database (DB)

Create Drift SQLite database in `core/database/`: `customers`, `transactions`, `transaction_audit_logs`; optional `app_settings` only if needed. UUIDs, integer piasters, timestamps, `deleted_at`, and local revision/backup tracking fields sufficient for later backup. Enforce foreign keys and indexes; define initial migration strategy. Implement customer and transaction DAOs, search, derived balances, soft deletion, and atomic transaction edit/delete + audit insert. Exclude deleted customers/transactions from active totals without physically deleting history.

**Done:** in-memory and persistence tests cover CRUD, balance math, FK constraints, soft deletion, audit atomicity, migration, and restart. No feature UI, Cubits, or Supabase code.

### Phase 5 — Settings Screen

Build the Figma-referenced Settings UI. Working settings only: Arabic/English with immediate RTL/LTR change; Light/Dark/System themes; persistence; About app/version; privacy and terms links **only when actual URLs exist**. Use a small `SettingsCubit` and Phase 2 preferences. No nonfunctional account, backup, security, or notification rows.

**Done:** Marionette visual verification, persistence tests, language/theme widget tests, analysis and tests pass.

### Phase 6 — Customers Feature

**Task 1 UI:** Customer list, search, add/edit, details and appropriate empty/error states based on `design/`; mock data only. **Task 2 Domain:** entities, rules, repository contract, use cases. **Task 3 Data:** repository implementation and Drift DAO mapping. **Task 4 Integration:** Cubits, real streams, loading/error states, balance-aware deletion warning, soft delete, tests. Confirm any original-plan extras (e.g., contact import) before adding.

**Done:** offline CRUD, search, deletion-with-debt warning, accurate active totals, responsive RTL/LTR UI, Marionette checks, tests.

### Phase 7 — Transactions Feature

**Task 1 UI:** Figma-based credit/payment entry and history using mock data. **Task 2 Domain:** transaction entities, validation, use cases, contracts. **Task 3 Data:** Drift repository, history, audit integration. **Task 4 Integration:** Cubits, actual UI, edits/deletes, balance refresh, tests. Preserve past-dated entries; confirm original-plan keypad shortcuts and customer chooser before including.

**Done:** credit/payment flows, derived balances, edits and soft-deletes with append-only audit records, atomic writes, under-10-second entry usability test, Marionette and automated tests.

### Phase 8 — Dashboard Feature

**Task 1 UI:** Figma-referenced dashboard with mock data. **Task 2 Domain:** only needed aggregate contracts/use cases (do not duplicate customer/transaction logic). **Task 3 Data:** efficient Drift aggregate/watch queries using existing DAOs. **Task 4 Integration:** Cubit and live totals, top debtors, recent activity, appropriate loading/empty states.

**Done:** accurate offline totals and recent activity; deleted customers excluded; performant list rendering; Marionette and tests. **Do not show backup reassurance/status until Phase 12 supplies real confirmed backup state.** Confirm any original-plan dashboard extras before implementing.

### Phase 9 — Customer Statements & WhatsApp Sharing

**Task 1 UI:** Follow `design/` statement/WhatsApp reference; build preview and sharing actions with mock customer history. **Task 2 Domain:** Define statement model, date range and formatting rules, repository contract/use cases only as needed. **Task 3 Data:** Read active customer transactions through existing Drift repositories/DAOs; generate a correctly ordered, localized plain-text statement and accurate derived totals. **Task 4 Integration:** Connect Cubit/UI, share to WhatsApp using supported URL/share mechanisms, and provide a generic system share fallback if WhatsApp is unavailable. Do not require internet to generate or preview a statement. Do not add PDF export, payment processing, or unnecessary reporting infrastructure.

**Done:** correct statement for credit/payment history, deleted-transaction handling, Arabic/English formatting, empty-history behavior, fallback sharing, privacy-safe error handling, Marionette verification and tests. Push each verified task to `development`.

### Phase 10 — App Security — PIN & Biometrics

**Task 1 UI:** Follow `design/` lock screen reference; build PIN setup, confirmation, unlock, change/disable and optional biometric prompts with mock state. **Task 2 Domain:** Define lock rules, attempts/lockout behavior, and small repository/use-case contracts as necessary. **Task 3 Data:** Store a salted PIN verifier securely (never plaintext PIN), use `flutter_secure_storage` and `local_auth` for optional device-supported biometrics, and persist only necessary lock preferences. **Task 4 Integration:** Add lock/session guard and auto-lock on background/resume, PIN fallback for biometric failure/unavailability, and functional security settings. No Supabase dependency or remote authentication requirement.

**Done:** PIN cannot be bypassed via navigation or restart, sensitive values never logged, biometric fallback works, app remains usable offline, settings are functional, Marionette verification and tests pass. Push each verified task to `development`.

### Phase 11 — Authentication

**Optional Supabase email + password only.** Task sequence: UI from `design/` → domain contracts/use cases → Supabase Auth repository → AuthCubit/session integration → tests. Sign up, email verification, sign in/out, password reset, persistent sessions. Local use continues signed out/offline. Signing out preserves ledger. Link a previously unlinked ledger to the first account safely; block a different account from accessing a linked local ledger. No Google login, SMS, multi-account profiles, or backup logic here.

**Done:** successful account flows, offline local use, account isolation, Marionette and tests.

### Phase 12 — Cloud Backup

Tasks: Supabase tables/RLS/ownership constraints; server-enforced active backup device; idempotent backup service for customers, transactions, soft-deletion tombstones and audit logs; safe retries and revision/acknowledgment tracking; functional Settings backup control and confirmed timestamp; tests. No bidirectional sync. Show limitations of pending offline data. Reassurance UI appears only when supported by real backup status and Figma reference.

**Done:** ownership/RLS tests, failed/retried/edited-during-upload tests, verified cloud contents, audit-history preservation, Marionette and tests.

### Phase 13 — Cloud Restore & Device Transfer

Tasks: validate/download last confirmed backup; confirmation and safe restore into an empty or explicitly approved local ledger; atomic local restore with duplicate protection; explicit new-device takeover of cloud-backup authority; old phone remains locally functional but can no longer back up; UI and tests. Never silently overwrite local records; do not claim unsent data can be recovered.

**Done:** restore all supported tables and audit history, block cross-account restore, test interruption/duplicates/takeover and old-device restrictions, Marionette and tests.

### Phase 14 — Final Testing & Production Release Preparation

Full offline and online end-to-end checks, including WhatsApp statements, PIN/biometric lock, and their interactions with onboarding/auth; balance/audit/deletion and restore integrity; Marionette review of all screens in Arabic/English and light/dark; low-end Android performance, scrolling, startup and rebuilds; Supabase RLS/security; Crashlytics reporting in release; Android permissions, app identity, signing, versioning and store compliance; build signed `.aab`; prepare Google Play listing, screenshots, privacy policy, Data safety and required declarations; closed testing where applicable. No new features. Owner manually submits/publishes to Google Play; no Play deployment lane or auto-publishing.

**Done:** no known critical bugs, all tests and release build pass, signed AAB and store materials ready for owner review. Store approval is not guaranteed.

## 7. Task delivery and Git policy

For **each task** (including the four ordered tasks within feature phases): inspect relevant designs; implement only task scope; run `dart format`, `flutter analyze --fatal-infos`, and `flutter test`; for UI tasks run Marionette on a running debug app and compare screen to Figma references in Arabic RTL and relevant themes/sizes; fix failures; commit a descriptive change; **push only to `origin/development`**. Do not proceed until the current task is verified and pushed. If Marionette or checks cannot run, report the blocker rather than claiming success. Never automatically push to `master`, merge, or open PRs. Owner controls merges.

### Master-only CI/CD

GitHub Actions triggers **only** on `push` to `master`, not PRs or `development`. A successful quality job builds a release APK through one Fastlane `firebase` lane and distributes it to Firebase App Distribution testers. Any push to master triggers it (not just merges); protect master to enforce owner-controlled merges. No automated Google Play deployment. Keep a Gemfile, Gemfile.lock, and `fastlane-plugin-firebase_app_distribution` dependency. Prefer service-account credentials over deprecated Firebase CLI tokens; configure secret management before first distribution. Confirm release APK signing is valid and app ID matches Firebase registration.

Suggested workflow (`.github/workflows/daftari_workflow.yml`):

```yaml
name: Flutter CI/CD
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: flutter-ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - name: Distribute release APK
        env:
          FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}
          FIREBASE_SERVICE_ACCOUNT_JSON: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}
        run: bundle exec fastlane android firebase --fastfile android/fastlane/Fastfile
```

**Fastlane intent:** `default_platform(:android)`; lane `firebase` changes to project root, runs `flutter clean` and `flutter build apk --release`, and calls `firebase_app_distribution(app: ENV.fetch('FIREBASE_APP_ID'), android_artifact_path: 'build/app/outputs/flutter-apk/app-release.apk', testers: '<owner-provided-tester-email>', release_notes: 'Automated CI build')`. Configure the Firebase plugin's supported service-account authentication method for the installed version; **never** hardcode credentials. The owner-provided tester address must be configured in Fastlane. Keep this as a simple single lane.

## 8. Mandatory acceptance tests

- **Speed:** Usability-test typical add-transaction flow under 10 seconds on a representative Android phone.
- **Offline:** Customers, transactions, dashboard, and settings work without internet or account; app restart retains data.
- **Money:** Correct piaster arithmetic, credit minus payment, deleted-customer exclusion, and balance refresh after edits/deletes.
- **Statements/security:** Customer statements use correct active ledger history and share with a fallback; PIN/biometrics protect access with an offline PIN fallback and secure storage.
- **Audit:** Every transaction edit/delete stores old values atomically; audit survives cloud backup and restore.
- **Backup:** Retry and idempotency; records modified during upload remain pending; confirmed timestamp never advances on failed uploads.
- **Isolation:** A different signed-in account cannot access a locally linked ledger; RLS rejects cross-user rows and cross-customer transaction references.
- **Transfer:** New phone takes backup authority; old phone still reads/writes locally but is denied cloud backup.
- **Design:** Marionette verification of relevant screens, Arabic RTL, English LTR, responsive sizing, and light/dark appearance.
- **Quality:** `dart format`, `flutter analyze --fatal-infos`, `flutter test` and applicable integration tests pass; no sensitive values in Crashlytics.
- **Release:** Correct package ID `com.mgb.daftari`, signed AAB, store declarations, verified release Crashlytics and Firebase test distribution.

## 9. Agent instructions

`agent.md` is the **single source of truth for how to code and verify work**. This plan defines **what to build, when, and how to accept it**. Read both before starting any task. Do not silently expand scope or reinterpret the owner's approved decisions.

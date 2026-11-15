# Daftari (دفتري) — AI Coding Agent Instructions

## 1. Project Identity

- **App name:** Daftari — دفتري
- **Android Application ID:** `com.mgb.daftari`
- **Platform:** Flutter, Android first
- **Primary language:** Arabic (RTL)
- **Secondary language:** English (LTR)
- **Architecture:** Feature-first Clean Architecture
- **State management:** Cubit using `flutter_bloc`
- **Local database:** Drift + SQLite
- **Cloud backend:** Supabase
- **Crash reporting:** Firebase Crashlytics
- **Test distribution:** Firebase App Distribution using Fastlane
- **Development branch:** `development`
- **Release branch:** `master`

Daftari is an offline-first credit ledger for small Egyptian shopkeepers.

The primary goal is to let a shopkeeper record customer credit or payment in under 10 seconds.

The application must remain fully usable without an internet connection or account.

---

## 2. Source of Truth

Before writing any code:

1. Read `DAFTARI_PLAN.md` completely.
2. Read this file completely.
3. Inspect the existing Flutter project.
4. Identify the current development phase and task.
5. Inspect relevant files in `design/` before implementing any UI.
6. Check existing shared components before creating new ones.

### Priority of instructions

1. Explicit user instructions and approvals.
2. This `agent.md` file.
3. `DAFTARI_PLAN.md`.
4. Existing code conventions.
5. Flutter and Dart best practices.

If instructions conflict, ask the user before proceeding.

Never silently change an approved requirement.

---

## 3. Project Preparation

The user creates the following manually before Phase 0:

- Flutter project.
- Firebase project.
- Firebase Android application registration.
- GitHub repository.
- `master` and `development` branches.
- `design/` directory containing Figma reference screens.
- `assets/` directory containing actual application assets.

### Important rules

- Do not recreate the Flutter project.
- Do not recreate the Firebase project.
- Do not change the Android Application ID.
- Verify that the Android Application ID is `com.mgb.daftari`.
- Verify Android namespace and Kotlin package configuration.
- Verify Firebase configuration matches the Android Application ID.
- Report missing configurations instead of inventing values.

Never change `com.mgb.daftari` without explicit user approval.

---

## 4. General Coding Rules

### Rule 1 — Write simple code

Write clean, readable, maintainable Dart code.

Avoid:

- Overengineering.
- Unnecessary abstractions.
- Unused interfaces.
- Premature optimization.
- Duplicate utilities.
- Unnecessary dependencies.

Implement only what is required for the current phase.

### Rule 2 — Avoid unnecessary comments

Do not write long comments explaining obvious code.

Use short comments only when necessary to explain complex logic or important decisions.

### Rule 3 — Follow the approved architecture

Use feature-first Clean Architecture where it provides value.

```text
presentation → domain ← data
```

- Presentation contains UI, Cubits, and widgets.
- Domain contains entities, repository contracts, and use cases.
- Data contains repository implementations, models, and data sources.

Domain code must not depend on Flutter UI, Drift, or Supabase.

Avoid creating layers or use cases that provide no meaningful benefit.

### Rule 4 — Keep files focused

Separate complex or reusable widgets into their own files.

Screens should primarily compose widgets rather than contain large amounts of business logic.

Do not split tiny widgets into separate files unnecessarily.

### Rule 5 — Reuse existing components

Before creating a widget, service, helper, or utility:

1. Search for an existing implementation.
2. Reuse or extend it when appropriate.
3. Create a new implementation only when necessary.

---

## 5. Design and UI Rules

### Figma references

The `design/` directory contains reference designs exported from Figma.

**Every UI implementation must follow its relevant design reference.**

Before implementing a screen:

1. Find its corresponding design in `design/`.
2. Inspect the layout, spacing, typography, colors, icons, and states.
3. Identify reusable components.
4. Implement the screen using the shared theme and widgets.
5. Verify the result using Marionette.

Never invent alternative screen designs without user approval.

If a design is missing or unclear, ask the user.

### Assets

`design/` is reference-only.

Runtime resources belong in:

```text
assets/
  images/
  icons/
  fonts/
```

Never load reference screenshots from `design/` as application assets.

### Onboarding

The user provides one onboarding design.

Build three onboarding screens using exactly the same visual layout.

Suggest text for the additional screens and request approval before finalizing their content.

Do not invent new onboarding illustrations or layouts.

### Responsive UI

Use `flutter_screenutil` through centralized sizing helpers such as `AppSpacing`.

Avoid scattered `.w`, `.h`, and `.sp` values throughout feature widgets.

Use centralized:

- Colors.
- Typography.
- Spacing.
- Border radii.
- Button styles.
- Input styles.
- Icon sizing.

Prefer directional Flutter layout APIs to support RTL.

### Localization

- Arabic is the default language.
- English is supported.
- All user-facing strings must be localized.
- Use ARB localization files.
- Do not hardcode visible text in widgets.
- Verify RTL and LTR layouts.
- Support Light, Dark, and System themes.

---

## 6. UI Verification With Marionette

After every UI task:

1. Run the Flutter application.
2. Connect Marionette.
3. Navigate to the implemented screen.
4. Capture or inspect the rendered UI.
5. Compare it with the relevant Figma design.
6. Check Arabic RTL behavior.
7. Check English LTR behavior.
8. Check Light and Dark themes where applicable.
9. Correct mismatches.
10. Verify again.

Check:

- Layout structure.
- Alignment.
- Spacing.
- Typography.
- Colors.
- Icons.
- Overflow.
- Navigation.
- Interactions.

If Marionette is unavailable, explicitly report that UI verification is incomplete.

Never claim that a UI matches the design without inspecting the rendered application.

Do not commit temporary verification screenshots.

---

## 7. Flutter Performance Rules

Avoid unnecessary widget rebuilds.

Use:

- `const` constructors where possible.
- Small, focused widgets.
- `BlocSelector` when a widget needs only part of a state.
- `buildWhen` when rebuilding should depend on specific state changes.
- `listenWhen` for relevant one-time side effects.
- Value equality for Cubit states.
- `ValueKey` for dynamic list items where appropriate.

Do not add selectors or rebuild filters without a clear purpose.

Use `ListView.builder` for long or dynamic lists.

Keep scrolling responsive on low-end Android devices.

Avoid expensive calculations inside widget `build()` methods.

---

## 8. Dependency Management

All approved V1 Flutter dependencies must be declared during Phase 0.

The initial dependency set includes, as applicable:

- `flutter_bloc`
- `get_it`
- `go_router`
- `drift`
- `drift_flutter`
- `sqlite3_flutter_libs` if required by the selected Drift version
- `supabase_flutter`
- `firebase_core`
- `firebase_crashlytics`
- `flutter_screenutil`
- `flutter_localizations`
- `intl`
- `shared_preferences`
- `flutter_secure_storage`
- `local_auth`
- `connectivity_plus`
- `uuid`
- `fpdart`
- `freezed_annotation`
- `json_annotation`
- `equatable` if needed
- `share_plus`
- `url_launcher`
- `flutter_launcher_icons`
- `flutter_native_splash`
- `build_runner`
- `drift_dev`
- `freezed`
- `json_serializable`
- `bloc_test`
- `mocktail`
- `integration_test`
- Flutter testing and lint packages

Use only packages required by the approved V1 plan.

Resolve compatible package versions during Phase 0 and commit `pubspec.lock`.

Do not introduce new dependencies during later feature phases without explicit user approval.

Do not add packages simply because they are popular.

---

## 9. Offline-First Database Rules

Drift SQLite is the local source of truth.

All essential ledger operations must work without internet access.

### Money

Store money as integer Egyptian piasters.

Never use `double` or floating-point arithmetic for stored monetary values.

Use centralized money formatting and parsing utilities.

### Customer balances

Balances must be derived from transactions:

```text
balance = sum(active credit) - sum(active payment)
```

Never allow users to directly edit a stored balance.

### IDs

Use UUIDs for customer, transaction, and audit records.

### Soft deletion

Use `deleted_at` rather than permanently removing business records.

When a customer is soft-deleted:

- Hide the customer from active lists.
- Hide their transactions from normal views.
- Exclude the customer and their transactions from dashboard totals.
- Preserve the underlying records.
- Allow deletion even when an outstanding balance exists, after clear confirmation.

No customer restore interface is required for V1.

### Transaction audit history

Editing or deleting a transaction must:

1. Preserve its previous values in an audit record.
2. Record the action and timestamp.
3. Apply the transaction change.
4. Complete all changes atomically within one SQLite transaction.

Audit history must be append-only.

Balances must reflect only active transactions.

### Database quality

- Enable foreign key enforcement.
- Create appropriate indexes.
- Use migrations for schema changes.
- Test migrations.
- Test balances and deletion behavior.
- Test audit history.
- Avoid destructive schema resets.

---

## 10. Authentication Rules

Authentication uses Supabase Email + Password only.

Do not implement:

- Google sign-in.
- SMS sign-in.
- Social sign-in.

The app must remain usable without authentication.

Authentication is required only for optional cloud backup and restore.

Support:

- Sign up.
- Login.
- Logout.
- Email verification.
- Forgot password.
- Password reset.
- Session persistence.

Signing out must never delete local ledger data.

An existing local ledger may be linked to its first authenticated account.

If local data belongs to one account, block signing in with a different account against that same ledger.

Do not implement multi-profile support in V1.

---

## 11. Cloud Backup Rules

Cloud backup uses Supabase.

It is optional.

Do not implement real-time multi-device synchronization.

The local Drift database remains authoritative for normal app operations.

Back up:

- Customers.
- Transactions.
- Transaction audit history.

### Security

- Use Supabase Row Level Security.
- Enforce ownership by authenticated user ID.
- Never expose service-role credentials in the Flutter application.
- Validate transaction ownership of referenced customers.
- Use composite ownership constraints where appropriate.

### Reliability

- Use UUIDs for deduplication.
- Retry failed uploads safely.
- Mark data as backed up only after server confirmation.
- Preserve pending changes if a record changes during upload.
- Track the last confirmed backup time.
- Never silently discard local changes.

### Device transfer

V1 supports one cloud-active phone per account.

When the account is transferred to a new phone:

- The new phone becomes cloud-active.
- The previous phone retains its local ledger.
- The previous phone may continue working offline.
- The previous phone cannot perform new cloud backups while inactive.

Clearly explain the possibility of unsynced data.

Do not build a full multi-device conflict resolution engine.

---

## 12. Customer Statements and WhatsApp Sharing

Customer statements are included in V1.

The statement must be generated from local ledger data.

It must work without a Supabase account.

Support:

- Customer identification.
- Transaction history.
- Credit entries.
- Payment entries.
- Current balance.
- Readable Arabic text.
- English localization.

Use the corresponding design reference for the statement screen.

Provide WhatsApp sharing through an appropriate supported mechanism.

Provide a system-sharing fallback when WhatsApp is unavailable.

Do not require internet merely to generate or preview the statement.

Do not introduce PDF generation unless explicitly approved.

Never silently share customer information without a user action.

---

## 13. PIN and Biometric Security

App security is included in V1.

Support:

- PIN setup.
- PIN confirmation.
- PIN unlock.
- Change PIN.
- Disable PIN after verification.
- Optional biometric unlock.
- Automatic app locking.
- Appropriate lock-screen navigation guards.

Use the relevant design reference.

Do not store PINs in plaintext.

Use secure storage and an appropriate PIN verification strategy.

Biometric unlock must be optional and available only on supported devices.

Provide a PIN fallback when biometrics are unavailable.

Do not confuse local app PIN security with Supabase authentication.

Protect existing local ledger data from accidental deletion during security configuration changes.

---

## 14. Git Workflow

The AI agent works on the `development` branch.

After every completed task:

1. Finish the implementation.
2. Run formatting.
3. Run static analysis.
4. Run relevant tests.
5. Perform Marionette verification for UI tasks.
6. Review the changed files.
7. Commit the completed task.
8. Push to `development`.

Never automatically:

- Push to `master`.
- Merge into `master`.
- Open a pull request.
- Publish to Google Play.

Only the user decides when changes are merged into `master`.

If verification fails, do not mark the task complete.

Report failures and fix them before committing.

Do not commit secrets, generated screenshots, or temporary debugging files.

---

## 15. Required Quality Checks

After every development task, run:

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

Run relevant targeted tests as needed.

Before completing a phase, verify:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
```

Do not claim tests passed unless they actually ran successfully.

If a command cannot run, explain why.

When fixing a bug, add a regression test where practical.

---

## 16. GitHub Actions and Fastlane

The GitHub Actions workflow must trigger only on pushes to `master`.

Do not add triggers for:

- Pull requests.
- Pushes to `development`.
- Tags unless explicitly approved.
- Scheduled jobs.

The workflow must:

1. Check out the repository.
2. Configure Java and Flutter.
3. Install dependencies.
4. Check Dart formatting.
5. Run Flutter static analysis.
6. Run Flutter tests with coverage.
7. Build and distribute a release APK through Fastlane only after successful quality checks.

Fastlane must provide an Android `firebase` lane.

The lane must:

1. Run `flutter clean`.
2. Build a release APK.
3. Upload it to Firebase App Distribution.
4. Include release notes.
5. Distribute to the approved tester:

```text
mostafagalal1712004@gmail.com
```

Use secure GitHub secrets and service-account credentials.

Do not commit Firebase service-account JSON or Android signing secrets.

Do not configure automatic Google Play publishing.

The user will manually upload and publish the production Android App Bundle.

---

## 17. Phase Roadmap

Follow `DAFTARI_PLAN.md` for detailed tasks and acceptance criteria.

### Pre-Phase 0 — Manual Project Preparation

Performed by the user.

Create Flutter, Firebase, GitHub, design references, and assets.

### Phase 0 — Setup Daftari

- Verify existing Flutter project.
- Verify Android Application ID.
- Verify Firebase configuration.
- Install all approved V1 dependencies.
- Configure Crashlytics.
- Configure Fastlane.
- Configure GitHub Actions.
- Verify build and quality checks.

Do not implement feature screens or database tables.

### Phase 1 — Project Structure and Shared Components

- Create approved folders.
- Inspect Figma references.
- Establish design tokens.
- Configure localization.
- Configure theme.
- Create shared widgets.
- Configure routing and dependency injection.

Do not implement business features.

### Phase 2 — Base Services

- Connectivity.
- Preferences.
- Logging.
- Error handling.
- Money utilities.
- Date utilities.
- Validators.
- Dependency registration.
- Unit tests.

### Phase 3 — App Intro

- Launcher icon.
- Native splash.
- Three onboarding screens.
- Onboarding persistence.
- Navigation and RTL verification.

### Phase 4 — Database

- Drift database.
- Customers table.
- Transactions table.
- Transaction audit logs.
- DAOs.
- Migrations.
- Balance calculations.
- Soft deletion.
- Database tests.

### Phase 5 — Settings

- Language switching.
- Theme switching.
- Settings persistence.
- About/version.
- Relevant working settings only.

Do not create nonfunctional settings options.

### Phase 6 — Customers

Complete tasks in order:

1. UI using mock data.
2. Domain layer.
3. Data layer.
4. Cubit integration and tests.

### Phase 7 — Transactions

Complete tasks in order:

1. UI using mock data.
2. Domain layer.
3. Data layer.
4. Cubit integration and tests.

Include transaction edit/delete and audit history.

### Phase 8 — Dashboard

Complete tasks in order:

1. UI using mock data.
2. Domain/query contracts.
3. Data integration.
4. Cubit integration and tests.

Exclude deleted records from totals.

### Phase 9 — Customer Statements and WhatsApp Sharing

Complete tasks in order:

1. Statement UI from design.
2. Statement domain logic.
3. Local ledger data integration.
4. Sharing integration and tests.

Include WhatsApp and system-sharing fallback.

### Phase 10 — PIN and Biometric Security

Complete tasks in order:

1. Security UI from design.
2. PIN and lock domain logic.
3. Secure storage and biometric integration.
4. Cubit/navigation integration and tests.

### Phase 11 — Authentication

Complete tasks in order:

1. Authentication UI from design.
2. Domain layer.
3. Supabase data layer.
4. Cubit integration and tests.

Email and password only.

### Phase 12 — Cloud Backup

- Supabase database schema.
- RLS.
- Account ownership.
- Customer backup.
- Transaction backup.
- Audit-history backup.
- Backup status.
- Retry handling.
- Tests.

### Phase 13 — Cloud Restore and Device Transfer

- Cloud restore.
- Backup validation.
- Duplicate prevention.
- Local-data protection.
- Device transfer.
- Active-device enforcement.
- Restore and transfer tests.

### Phase 14 — Final Testing and Production Release

- End-to-end tests.
- Arabic RTL verification.
- English LTR verification.
- Light/Dark verification.
- Offline testing.
- Low-end Android performance.
- Database integrity tests.
- Backup/restore tests.
- Security and RLS review.
- Crashlytics verification.
- Release signing.
- Signed Android App Bundle.
- Google Play listing preparation.
- Privacy and policy requirements.

Google Play publishing is manual.

---

## 18. Feature Task Workflow

For feature phases, follow this sequence unless the phase plan specifies otherwise.

### Task 1 — UI

- Inspect Figma design.
- Implement UI using mock data.
- Reuse shared widgets.
- Verify with Marionette.
- Run quality checks.
- Commit and push to `development`.

### Task 2 — Domain

- Implement entities.
- Implement repository contracts.
- Implement required use cases.
- Add unit tests.
- Run quality checks.
- Commit and push to `development`.

### Task 3 — Data

- Implement repository adapters.
- Integrate Drift or Supabase as required.
- Add data tests.
- Run quality checks.
- Commit and push to `development`.

### Task 4 — Integration

- Implement Cubit.
- Connect UI to domain and data.
- Test user flows.
- Verify UI with Marionette.
- Run quality checks.
- Commit and push to `development`.

Never skip a task without user approval.

---

## 19. Definition of Done

A task is complete only when:

- Its approved requirements are implemented.
- Relevant tests pass.
- Static analysis passes.
- Formatting passes.
- UI has been verified with Marionette where applicable.
- No sensitive data is logged.
- No unapproved dependencies were introduced.
- Changes are committed and pushed to `development`.

A phase is complete only when all its tasks meet these criteria.

Do not mark unfinished work as complete.

---

## 20. Communication Rules

Before starting a task, briefly state:

- Current phase.
- Current task.
- What will be implemented.
- Which design reference applies, if any.

After finishing a task, report:

- What was implemented.
- Files changed.
- Tests and checks executed.
- Marionette verification status.
- Commit and push status.
- Any blockers or unresolved questions.

Do not claim a commit, push, test, deployment, or verification succeeded unless it actually did.

Ask for approval before:

- Changing approved architecture.
- Adding dependencies after Phase 0.
- Changing application identity.
- Changing design behavior.
- Introducing features outside the roadmap.
- Deleting user data.
- Altering cloud ownership or transfer rules.
- Modifying CI/CD triggers.
- Publishing production releases.

---

## 21. Final Principles

1. Offline first.
2. Arabic first.
3. Fast transaction entry.
4. Accurate balances.
5. Never lose ledger history.
6. Keep the implementation simple.
7. Follow the Figma designs.
8. Verify every UI task.
9. Test every completed task.
10. Push completed tasks only to `development`.
11. Never silently change approved requirements.
12. Keep cloud backup optional.
13. Protect customer data.
14. Keep V1 focused and maintainable.

**Always read `DAFTARI_PLAN.md` before starting the next phase.**
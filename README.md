# Daftari (دفتري)
<img width="1024" height="500" alt="feature_graphic" src="https://github.com/user-attachments/assets/9a455d3d-0dbb-4c95-a24f-e1362c4a9b01" />

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Android-blue)

## 📜 Description
**Daftari (دفتري)** is an offline-first digital credit ledger built for Egyptian small-shop owners to replace traditional paper credit notebooks. Designed for speed and reliability, Daftari lets shopkeepers record a customer credit or payment in **under 10 seconds** without requiring an account or an internet connection. **Drift / SQLite** serves as the local source of truth with exact integer-piaster arithmetic and append-only audit trails, while optional **Supabase** integration provides single-device cloud backup, safe cloud restore, and device transfer. Built Arabic-first (RTL) with full English (LTR) support, adaptive light/dark themes, PIN & biometric security, and shareable customer statements.

## 📱 Screenshots
<img width="540" height="1204" alt="daftari-1" src="https://github.com/user-attachments/assets/ca72610d-8ba8-40a6-befd-e84fcd306b52" />
<img width="540" height="1204" alt="daftari-7" src="https://github.com/user-attachments/assets/b6948692-9647-4df9-9341-450969f8e3ff" />
<img width="540" height="1204" alt="daftari-8" src="https://github.com/user-attachments/assets/42bf62a1-029c-482e-9ac4-c93c2ef99648" />
<img width="540" height="1204" alt="daftari-10" src="https://github.com/user-attachments/assets/16818b69-19ca-459c-9ea9-10f10b3735d6" />
<img width="540" height="1204" alt="daftari-11" src="https://github.com/user-attachments/assets/434a54a8-5be0-4afa-a56f-738dae31b1ee" />
<img width="540" height="1204" alt="daftari-17" src="https://github.com/user-attachments/assets/e946f087-87b3-407b-bdec-0ca18e38b320" />
<img width="540" height="1204" alt="daftari-19" src="https://github.com/user-attachments/assets/166e637b-8a16-4388-a6f8-68c0d065283f" />
<img width="540" height="1204" alt="daftari-20" src="https://github.com/user-attachments/assets/251d9bb5-3870-47a6-8607-f88f01d983fe" />

## 🎦 Video Demonstration
<!-- 🎥 [Watch App Demo](YOUR_VIDEO_URL) -->

## 🚀 Features
- **Offline-First Credit Ledger** — Full customer, credit, and payment workflows powered by Drift/SQLite with zero account or internet dependency
- **Exact Integer-Piaster Accounting** — All amounts stored as integer Egyptian piasters (`int`) with derived balances (`active credits − active payments`) and zero floating-point rounding errors
- **Fast Transaction Entry & Audit Trail** — Sub-10-second credit/payment entry with past-date support, edit/soft-delete handling, and atomic append-only `transaction_audit_logs`
- **Customer Management & Contact Import** — Add, edit, import contacts from the device address book, search on a dedicated search screen, and safeguard deletions with balance-aware warnings
- **Live Dashboard Overview** — Real-time aggregate totals, top debtors, and recent activity driven by reactive Drift database streams
- **Customer Statements & Sharing** — Date-filtered, localized customer statements rendered as multi-page statement images ready to share via WhatsApp or the system share sheet
- **PIN & Biometric App Lock** — Salted PBKDF2-SHA256 PIN verification in `flutter_secure_storage`, lockout protection, background auto-lock guard, and optional biometric unlock with offline PIN fallback
- **Optional Email/Password Authentication** — Supabase PKCE auth with sign-up, email verification, sign-in/out, password recovery, and strict single-account local ledger isolation
- **Idempotent Cloud Backup** — Single-device-authority Supabase cloud backup with scheduled Android background worker support, revision/retry tracking, deletion tombstones, and audit-history preservation
- **Safe Cloud Restore & Device Transfer** — Snapshot validation, atomic local restore with duplicate safeguards, and explicit new-device authority takeover without silently overwriting local data
- **Arabic-First RTL & English LTR** — Instant runtime switching between Arabic (`ar`) and English (`en`) with `Cairo` typography
- **Adaptive Theming & Responsive Design** — Light, Dark, and System themes with smooth animated transitions, Lottie feedback animations, and responsive phone/tablet layouts

## 📜 Architecture
The project follows a **Feature-first Clean Architecture** organized into a shared `core/` module and 13 independent feature modules with strict dependency direction (**Presentation → Domain ← Data**):

```text
lib/
├── core/                          # Shared infrastructure
│   ├── database/                  # Drift SQLite DB, 6 tables, 3 DAOs, migrations
│   ├── di/                        # Dependency injection (GetIt)
│   ├── routing/                   # GoRouter (22 routes) + lock/auth redirect guards
│   ├── theme/                     # Material 3 colors, typography, spacing, theme switcher
│   ├── services/                  # Storage, connectivity, contacts, logger, image exporter
│   ├── errors/                    # AppException, AppFailure & centralized ErrorHandler
│   ├── widgets/                   # Shared design system & Lottie feedback components
│   └── ...
├── features/                      # 13 feature modules
│   ├── auth/                      # Optional Supabase email/password auth & session isolation
│   ├── backup/                    # Cloud backup, scheduling & Android background worker
│   ├── customers/                 # Customer CRUD, details, contact import & soft delete
│   ├── dashboard/                 # Live totals, top debtors & recent activity
│   ├── layout/                    # Persistent 3-tab bottom navigation shell
│   ├── onboarding/                # 3-step first-run onboarding flow
│   ├── restore/                   # Cloud restore, snapshot validation & device transfer
│   ├── search/                    # Dedicated customer search experience
│   ├── security/                  # PIN & biometric app lock with lockout policy
│   ├── settings/                  # Language, theme, security & backup/account settings
│   ├── splash/                    # Animated Flutter splash screen
│   ├── statements/                # Customer statements & PNG image sharing
│   └── transactions/              # Credit/payment entry, history & atomic audit logs
├── l10n/                          # Arabic (RTL) & English (LTR) ARB localizations
└── main.dart
```

### Layer Breakdown
- **Data Layer** — Drift DAOs, local/secure storage services, Android platform bridge, and optional Supabase cloud repositories implementing domain contracts
- **Domain Layer** — Pure Dart entities, business policies (lockout, backup cutoff/schedule, restore validation), abstract repository contracts, and use cases with zero Flutter, Drift, or Supabase imports
- **Presentation Layer** — Flutter screens, reusable widgets, and `flutter_bloc` Cubits reacting to local streams and user actions

State management is handled by **flutter_bloc Cubits** registered modularly in **GetIt**, while `GoRouter` listens to `AppLockCubit` and `AuthSessionCubit` to coordinate the startup and security flow: `Splash → App Lock (if enabled) / Onboarding → Main Shell (Home, Customers, Settings)`.

## 🔨 Tech Stack

| **Aspect** | **Details** |
|---|---|
| **Framework** | Flutter (Android-first) |
| **Language** | Dart 3.x |
| **State Management** | flutter_bloc (Cubits) + equatable |
| **Architecture** | Feature-first Clean Architecture (Data, Domain, Presentation) |
| **Navigation** | GoRouter (`StatefulShellRoute.indexedStack` — 3 persistent bottom tabs, 22 routes) |
| **Dependency Injection** | GetIt (modular per-feature DI registration) |
| **Local Database** | Drift + drift_flutter + sqlite3_flutter_libs (SQLite, 6 tables, 3 DAOs) |
| **Cloud Backend & Auth** | Supabase (`supabase_flutter` PKCE Auth + PostgreSQL with RLS) |
| **Security & Storage** | flutter_secure_storage, local_auth, shared_preferences, PBKDF2-SHA256 |
| **Crash Reporting** | Firebase Core + Firebase Crashlytics (privacy-safe logging) |
| **Localization** | flutter_localizations + intl (`gen-l10n`, Arabic RTL & English LTR) |
| **UI & Animation** | flutter_screenutil, animated_theme_switcher, flutter_animate, lottie, flutter_svg, Cairo font |
| **Functional & Codegen** | fpdart (`Either` / `AppFailure`), freezed, json_serializable, drift_dev, build_runner, uuid |
| **Device & Sharing** | share_plus, url_launcher, flutter_native_contact_picker, connectivity_plus |
| **CI/CD** | GitHub Actions + Fastlane (Firebase App Distribution) |
| **Testing** | flutter_test, bloc_test, mocktail, integration_test, marionette_flutter, embedded-postgres |

## 📁 Project Structure
```text
lib/
├── app.dart                       # Root DaftariApp widget, theme & lock guard
├── main.dart                      # Entry point, Firebase init & backup worker entrypoint
├── main_marionette.dart           # Debug Marionette binding entry point
├── firebase_options.dart          # FlutterFire configuration
├── l10n/                          # app_ar.arb, app_en.arb & generated localizations
├── core/
│   ├── animation/                 # Theme transition & custom route transitions
│   ├── constants/                 # App constants, locales & design sizing
│   ├── database/                  # AppDatabase, tables, DAOs & schema migrations
│   ├── di/                        # GetIt service locator wiring
│   ├── errors/                    # AppException, AppFailure & ErrorHandler
│   ├── extensions/                # BuildContext, theme & l10n helpers
│   ├── routing/                   # GoRouter config (22 routes) & redirect guards
│   ├── services/                  # Connectivity, contact picker, date, image exporter, storage, logger, session gate
│   ├── theme/                     # Colors, gradients, spacing, text theme & ThemeSwitcherCubit
│   ├── utils/                     # Integer-piaster money, date & validation utilities
│   └── widgets/                   # Buttons, inputs, dialogs, empty/error states & Lottie feedback
└── features/
    ├── auth/                      # Login, sign-up, verify email, forgot/update password & session
    ├── backup/                    # Cloud backup, scheduler, Android worker & status UI
    ├── customers/                 # Customer list, add/edit, details & contact import
    ├── dashboard/                 # Home dashboard totals, top debtors & recent activity
    ├── layout/                    # Liquid bottom navigation bar shell (3 tabs)
    ├── onboarding/                # 3-step intro carousel
    ├── restore/                   # Cloud snapshot preview, restore & device transfer
    ├── search/                    # Dedicated customer search screen
    ├── security/                  # PIN setup/verify/change/disable, biometrics & AppLockGuard
    ├── settings/                  # Language, theme, security & backup/account settings
    ├── splash/                    # Animated splash screen
    ├── statements/                # Statement preview, date range filter & image sharing
    └── transactions/              # Credit/payment form, edit/soft-delete & audit logging
```

## 🧗 Challenges Solved
- **Built a true offline-first accounting engine** in Drift/SQLite using integer Egyptian piasters (`int`), derived balances (`credits − payments`), strict foreign keys, soft-deletion tombstones, and atomic transaction edit/delete writes paired with append-only `transaction_audit_logs`
- **Enforced single-device cloud backup authority server-side** using Supabase PostgreSQL Row-Level Security (RLS) and composite `(id, user_id)` foreign keys, validated against a disposable local PostgreSQL server with multi-connection concurrency tests
- **Engineered idempotent, crash-safe cloud backup and restore** featuring in-flight batch tracking (`backup_in_flight_batches`), revision checks so edits made during upload stay pending, Android background worker execution, and atomic restore with explicit device takeover
- **Implemented a non-bypassable App Lock & Security Guard** combining salted PBKDF2-SHA256 PIN verification in secure storage, failed-attempt lockout policies, optional biometric unlock with offline PIN fallback, and GoRouter redirect guards coordinated with splash, onboarding, and password recovery
- **Designed a privacy-safe observability pipeline** wrapping Firebase Crashlytics so customer names, phone numbers, and monetary amounts are never logged or attached to crash reports
- **Delivered a bilingual Arabic-first RTL / English LTR UI** with Cairo variable typography, animated Light/Dark/System theme switching, responsive phone/tablet layouts, and multi-page PNG customer statement rendering for WhatsApp and system sharing
- **Automated quality checks and tester delivery** via GitHub Actions (`dart format`, `flutter analyze --fatal-infos`, `flutter test --coverage`) and Fastlane distribution to Firebase App Distribution

## 🛠️ Installation

```bash
# Clone the repository
git clone https://github.com/MG-B17/Daftari-App.git
cd Daftari-App

# Install dependencies
flutter pub get

# Generate Drift, Freezed, JSON, and localization files
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Run the app (works fully offline without Supabase credentials)
flutter run

# Run with Supabase cloud backup & restore enabled
flutter run --dart-define-from-file=env/supabase.json
```

## ⚙️ Configuration

### Firebase Setup
- Place `google-services.json` in `android/app/` (Android package ID: `com.mgb.daftari`)
- Or run `flutterfire configure` to regenerate `lib/firebase_options.dart`

### Supabase Setup (Optional — Cloud Backup & Restore)
- Copy `env/supabase.example.json` to `env/supabase.json` and configure `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Apply the SQL migrations in `supabase/migrations/` to your Supabase project
- Pass `--dart-define-from-file=env/supabase.json` when running or building (if omitted, Daftari runs cleanly in offline-only mode)

### CI/CD & Distribution (Optional)
- `.github/workflows/daftari_workflow.yml` runs on pushes to `master` and distributes release APKs via Fastlane (`android/fastlane/Fastfile`)
- Configure repository secrets: `FIREBASE_APP_ID`, `FIREBASE_CREDENTIALS`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY`

## 🧪 Testing

```bash
# Check formatting and static analysis
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos

# Run all unit and widget tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run Supabase SQL migration & RLS concurrency tests
npm --prefix supabase/tests ci
npm --prefix supabase/tests test
```

Testing tools: `flutter_test`, `bloc_test`, `mocktail`, `integration_test`, `marionette_flutter`, and `embedded-postgres`.

## 🗺️ Roadmap
- [ ] Google Play production store release
- [ ] iOS platform release & App Store distribution
- [ ] PDF customer statement export alongside image sharing
- [ ] Automated payment reminder notifications
- [ ] Multi-shop / multi-ledger account support
- [ ] Soft-deleted customer recovery UI

## 📄 License
This project is licensed under the MIT License.

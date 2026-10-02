# Abuakwa Area Connect (`cop-abuakwa-app`)

[![Flutter CI](https://github.com/nkansahisaac436-dotcom/cop-abuakwa-app/actions/workflows/ios.yml/badge.svg)](https://github.com/nkansahisaac436-dotcom/cop-abuakwa-app/actions/workflows/ios.yml)
[![Deploy Web App to GitHub Pages](https://github.com/nkansahisaac436-dotcom/cop-abuakwa-app/actions/workflows/deploy_web.yml/badge.svg)](https://github.com/nkansahisaac436-dotcom/cop-abuakwa-app/actions/workflows/deploy_web.yml)

**Abuakwa Area Connect** is the official digital administration and community platform for **The Church of Pentecost, Abuakwa Area**, providing centralized oversight, pastoral collaboration, and member engagement across **~33 districts**.

---

## 🏛️ Key Roles & Features

### 1. 👑 Area Head (Executive Oversight)
- **District Governance:** Activate or deactivate district self-registration for all 33 districts.
- **Invitation Hub:** Generate secure, single-use invite codes (`ABK-XXXX-XX`) for incoming pastors and ministry leaders, with multi-channel sharing (WhatsApp, SMS, clipboard) and active invite cancellation.
- **Supervisory Logs:** Record on-site supervision visits with location tagging, photos, and leadership notes.
- **Tenure & Transfer Decisions:** Review transfer requests, approve handovers, and access permanent read-only tenure archives.
- **Area-Wide Broadcasts:** Publish priority announcements directly to all members and leaders.

### 2. 📖 District Pastors
- **District Projects & Events:** Create and track district infrastructure projects and events with milestone updates and progress percentages.
- **Pastoral Thoughts Feed:** Share biblical reflections, devotionals, and pastoral messages with the Area.
- **Virtual Pastoral Calls:** Instant and scheduled group audio/video calls via integrated Jitsi Meet.
- **Tenure Transfer Request:** 1-tap transfer request submission that compiles a comprehensive tenure dossier (projects, events, updates, thoughts) and generates standardized PDF archives (`Pastor <Full Name>, <StartYear>-<EndYear>`).

### 3. 👥 Ministry Leaders
- Dedicated management and announcement publishing for the **5 Core Ministries**:
  - 🕊️ Youth Ministry
  - 📢 Evangelism Ministry
  - 🧒 Children's Ministry
  - 👔 PEMEM (Men's Ministry)
  - 🌸 Women's Ministry

### 4. ⛪ Church Members
- **Area & Ministry Feeds:** Real-time updates filtered by Row-Level-Security (RLS).
- **Public Projects & Events:** View public district milestones, chapel builds, and upcoming events.
- **Controlled Sign-Up:** Secure registration restricted to approved, active districts and verified local assemblies.

---

## 🔐 Authentication & Invite Security

- **4-Role Chip Selector:** Member, Pastor, Leader, Area Head.
- **Two-Step Invite Flow:** Pastors and leaders redeem cryptographic invite codes auto-formatted as `ABK-XXXX-XX`. Includes rate-limiting (15-minute lockout after 5 consecutive failed attempts).
- **Tenure Integrity:** Roles, district assignments, and ministry allocations are bound to verified invite tokens—never editable by the end user.
- **Role Verification Guard:** Strict role matching on sign-in prevents unauthorized privilege escalation.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev/) (Dart 3.x, Null Safety, Material 3) |
| **State Management** | [Flutter Riverpod 2.x](https://riverpod.dev/) (`AsyncNotifier`, `FutureProvider`) |
| **Routing** | [GoRouter](https://pub.dev/packages/go_router) with declarative role guards & `AuthRouterRefreshListenable` |
| **Backend & Database** | [Supabase](https://supabase.com/) (PostgreSQL 15, Auth, Storage, Edge Functions, RLS) |
| **Offline Cache** | [Hive](https://pub.dev/packages/hive_flutter) for offline drafts and local caching |
| **Virtual Meetings** | [Jitsi Meet](https://jitsi.org/) integration with audio-first flags |
| **PDF Generation** | [pdf](https://pub.dev/packages/pdf) package for printable tenure archive dossiers |
| **Design System** | Pentecost Navy (`#1F3A5F`), Harvest Gold (`#B8860B`), Source Serif 4 & Nunito Sans |

---

## 📁 Project Architecture

```
lib/
├── core/
│   ├── config/          # Network configuration and Supabase initializers
│   ├── constants/       # AppColors, AppDimensions, AppStrings
│   ├── network/         # SupabaseClient wrapper with offline/mock fallback
│   ├── router/          # Declarative GoRouter configuration and route guards
│   ├── theme/           # Light & Dark theme tokens, typography (Source Serif 4, Nunito Sans)
│   └── widgets/         # DistrictRingLogo, AppTextField, PrimaryButton, WarningBanner
├── features/
│   ├── auth/            # 4-role login, 2-step invite redemption, sign-up, session providers
│   ├── districts/       # 33 Districts management, assembly lists, activation toggle
│   ├── feeds/           # Area feed, pastoral thoughts, create post modal bottom sheet
│   ├── meetings/        # Pastoral group calls & virtual meeting scheduler
│   ├── ministries/      # 5 Ministries directory & dedicated ministry feeds
│   ├── notifications/   # In-app notifications & alerts
│   ├── profile/         # User profile, role switching, sign-out
│   ├── projects/        # District projects & events tracker, updates log, map overview
│   ├── supervision/     # Area Head visit logging & supervision archive
│   └── transfer/        # Transfer request workflow, tenure archive, PDF export engine
└── main.dart            # Application entry point with ProviderScope & GoRouter
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24+ recommended)
- [Git](https://git-scm.com/)

### 1. Clone & Configure
```bash
git clone https://github.com/nkansahisaac436-dotcom/cop-abuakwa-app.git
cd cop-abuakwa-app
cp .env.example .env
```

Edit `.env` with your Supabase credentials:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Database Setup (Supabase)
Run the migration and seed scripts located in `supabase/`:
- `supabase/migrations/` — Tables, enums, triggers, and Row Level Security policies.
- `supabase/seeds/03_users_seed.sql` — Idempotent auth users and initial profile seeding.

### 4. Run App
```bash
# Run on Chrome / Web
flutter run -d chrome

# Run on Android / iOS device or emulator
flutter run
```

---

## 🧪 Testing & Verification

Run the comprehensive test suite (28+ automated unit and widget tests covering all role logins, invite code redemption, transfer PDF generation, and responsive layouts):

```bash
# Run static analysis
flutter analyze

# Run all tests
flutter test --reporter=expanded
```

---

## 📄 License

Copyright &copy; 2026 The Church of Pentecost, Abuakwa Area. All rights reserved.

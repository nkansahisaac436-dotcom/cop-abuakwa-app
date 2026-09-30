# Abuakwa Area Connect (cop-abuakwa-app)

**Abuakwa Area Connect** is a dedicated mobile application for **The Church of Pentecost, Abuakwa Area** (~33 districts).

## Key Pillars & Jobs
1. **Pastoral Collaboration & Area Supervision:** Enables pastors and the Area Head to share district projects, events, pastoral thoughts, and hold group calls. The Area Head can oversee all district activities and log supervision visits.
2. **Tenure Archive & Transfer Management:** When a pastor is transferred, one tap initiates a transfer request. Upon Area Head approval, the pastor's work is permanently archived into a read-only record (with PDF export), while district projects remain intact for incoming pastors.
3. **Public & Ministry Feeds:** Church members follow the Area feed and five core ministries (Youth, Evangelism, Children's, Pemem, Women's) with Row-Level-Security filtered content.

---

## Tech Stack
- **Mobile:** Flutter (Dart 3.x)
- **State Management:** Riverpod 2.x
- **Navigation:** go_router
- **Backend:** Supabase (PostgreSQL 15+, Auth, Storage, Edge Functions, Row Level Security)
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Group Calls:** Jitsi Meet integration
- **PDF Export:** Flutter PDF package & Supabase Edge Functions
- **Offline Storage:** Hive
- **Typography:** Source Serif 4 (App name & titles) & Nunito Sans (Body, inputs, buttons)

---

## Project Structure
```
lib/
├── core/
│   ├── constants/       # AppColors, AppStrings, AppDimensions
│   ├── network/         # Supabase client and network handlers
│   ├── theme/           # Light & Dark themes, Typography
│   ├── utils/           # Formatters, helpers, image compression
│   └── widgets/         # DistrictRingLogo, AppTextField, PrimaryButton, WarningBanner
├── features/
│   ├── auth/            # Login, Sign-up, Role guards, Area Head seed
│   ├── districts/       # 33 Districts management, Activation, Assemblies
│   ├── feeds/           # Area Feed, Thoughts, Post creation
│   ├── ministries/      # 5 Ministries (Youth, Evangelism, Children's, Pemem, Women's)
│   ├── projects/        # District projects & events, updates, GPS maps
│   ├── supervision/     # Area Head visit logs
│   ├── transfer/        # Pastor transfer requests, tenure archiving, PDF export
│   ├── meetings/        # Jitsi group meetings & scheduling
│   ├── notifications/   # In-app notifications & device tokens
│   └── profile/         # User profile, role badges, settings
└── main.dart
```

---

## Getting Started
1. Copy `.env.example` to `.env` and fill in your Supabase credentials.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## Testing
Run Flutter widget and unit tests:
```bash
flutter test
```

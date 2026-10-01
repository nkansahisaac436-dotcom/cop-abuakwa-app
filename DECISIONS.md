# Architecture Decisions & Choices (DECISIONS.md)

### Project: Abuakwa Area Connect
**Client:** The Church of Pentecost, Abuakwa Area (33 Districts)

---

### Decision 1: Folder Architecture & State Management
- **Architecture:** Feature-first structure `lib/features/<feature>/{data,domain,presentation}` alongside `lib/core/` for shared widgets, theme, services, and utilities.
- **State Management:** Riverpod 2.x (`flutter_riverpod`) for robust dependency injection, async state management, auth state listening, and reactive UI.
- **Navigation:** `go_router` with declarative routes and role-based redirect guards.

### Decision 2: Theme, Typography & Design Tokens
- **Typography:** Google Fonts:
  - `Source Serif 4` (Bold) for App Name, Header titles, and screen headings.
  - `Nunito Sans` for body copy, form fields, buttons, labels, and feed text.
- **Color Palette:**
  - Navy Primary: `#1F3A5F`
  - Navy Dark (Gradient End): `#14294A`
  - Gold Accent: `#B8860B`
  - Light Gold: `#E8C766`
  - Page Background: `#F5F7FA`
  - Disabled Input/Container: `#EEF0F4`
  - Text Primary: `#1B2433`
  - Soft Grey / Subtitle: `#6B7686`
  - Border: `#DDE2EA`
  - Error: `#B3261E`
  - Warning Banner Fill: `#FFF4E0`, Border: `#E0A11B`, Text: `#7A4A00`
- **Component Styling:**
  - White Cards: Border radius `26.0`, soft elevation shadow
  - Inputs: Border radius `14.0`, always-visible labels, minimum touch targets of 48px
  - Buttons: Pill shape (`StadiumBorder` or `BorderRadius.circular(27.0)`), height `54.0`

### Decision 3: Backend & Database (Supabase)
- **Supabase Client:** Initialized via `.env` credentials with fallback graceful mock/offline mode when credentials are not yet populated.
- **Row Level Security (RLS):** Strictly enforced at database level with Postgres RLS policies for members, pastors, ministry leaders, and Area Head.
- **Archive Isolation:** Transferred pastor tenure records are snapshotted in `tenure_archives` with read-only permissions, preserving district project history.

### Decision 4: Offline & Local Storage
- **Hive / Hive Flutter:** Used for local caching of feeds and offline draft persistence.

### Decision 5: One Login Page, Four Ways In & Invite Codes (Section 5.1b)
- **Role Selector:** Single login page with 4 chips (`Member`, `Pastor`, `Leader`, `Area Head`) that adjusts the input form dynamically. Fits on 360px viewports without wrapping.
- **Role Guard:** Post-authentication validation compares user's real database role with the selected role. On mismatch, the session is cancelled and an informative error is displayed.
- **Pastor & Leader Invite Codes:** Format `ABK-XXXX-XX`, single-use, 7-day expiration, rate-limited (locked for 15 minutes after 5 failed attempts). Verification card displays assigned role and district/ministry.
- **Area Head Invites Hub:** Area Head generates codes for incoming pastors and ministry leaders with one-tap WhatsApp, SMS, and clipboard sharing, plus active invite cancellation.

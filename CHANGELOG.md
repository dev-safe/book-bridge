# CHANGELOG

## Unreleased

### Privacy

- Listing locations are now rounded to about 1 km by a database trigger (`20261020000000_coarse_listing_location.sql`), and existing listings are rounded too. Other users no longer see a seller's exact GPS position. No app update is needed.

## 1.6.3 - October 6, 2026

Safety release for Google Play's user-generated content policy.

### Added

- **Report a listing or a user** from the ⋮ menu on book details and in chat. Pick a reason (spam, scam, inappropriate, harassment, prohibited item, other) and add optional details. Up to 20 reports a day per user; reporting the same thing twice is ignored.
- **Block a user** from the same menus. Their books disappear from home and search, the conversation is hidden from your chats, and neither of you can message the other (enforced in the database). Blocked users are listed under **Profile → Blocked users**, where you can unblock them.
- **Edit Listing** button on your own book's details page (opened from Home, Discover or a shared link). It opens the same edit form as Profile → My Books.
- **Admin → Reports** tab to review open reports: dismiss, or remove the reported listing. Served by new Rust endpoints `GET /admin/reports`, `POST /admin/reports/{id}/dismiss` and `POST /admin/reports/{id}/remove-listing`.

### Database

- `20261019000000_reports_and_blocks.sql`: `content_reports` and `user_blocks` tables, the daily report limit and the message block. Run it **before** deploying the Rust service.

## 1.6.2 - October 6, 2026

### Changed

- **Android package name is now `cm.devsafe.bookbridge`** because `com.bookbridge.app` is already taken on Google Play. Installs as a new app; earlier sideloaded APKs (`com.bookbridge.app`) are not upgraded in place. Firebase and Google Sign-In are registered for the new package, and `assetlinks.json` lists both packages so book links keep opening in either app.

## 1.6.1 - October 18, 2026

Google Play compliance release.

### Added

- **In-app account deletion** (Profile → Delete account): deletes the profile, ID documents, photos, messages, favourites and sign-in details, and signs out every device. Purchase, payment and rating records are kept without the user's name. Blocked while an order, dispute or reservation is in progress. Served by the new Rust endpoint `POST /account/delete`.
- Public **Delete your account** page at `/delete-account` on the website, linked from the footer and the Privacy Policy.

### Changed

- **Power Seller, listing boosts and donations are hidden** in Play builds, because Google Play requires Play Billing for digital goods. Re-enable with `--dart-define=ENABLE_DIGITAL_PAYMENTS=true`. Book purchases (escrow) are unchanged. The 3-active-listing limit for free sellers no longer suggests upgrading.
- Privacy Policy updated with in-app deletion and what is kept after deletion.

### Database

- `20261018000000_id_documents_owner_delete.sql`: users can delete their own ID documents (needed by account deletion). Run it **before** deploying the Rust service.

## 1.6.0 - October 6, 2026

### Added

- **Server-side Fapshi payments & escrow**: payments are initiated, confirmed, released and disputed through the Rust core; atomic escrow claims, unmatched-payment recording and refunds, admin dispute resolution, and auto-release via cron.
- **Buyer protection**: buyer pays a 6% service fee on top, seller receives the full price; guard against two buyers paying for the same listing.
- **Age-based ID verification** with admin review, 18+/guardian self-declaration and an online-safety reminder before child users can send chat messages.
- **Listings**: up to 3 photos (multi-select from gallery), meetup zones and pickup map, distance filter, class level / subject / school filters, Discover tab.
- **Power Seller subscription**, server-side push notifications (FCM) and link-only WhatsApp sharing with deep links.
- **My orders, easier to find**: Home header orders badge, "Orders need your attention" card and Profile "My orders" entry with badge.
- **Compact sticky buyer bar** on book details: Message Seller + Buy Now.
- **"See books near you" prompt** on Home when phone location is off or permission is denied, with a one-tap fix (turn on location, allow, or open app settings).
- **In-app donations** (Home, Profile, About) and "Powered by DevSafe" on the About screen.

### Changed

- Light mode is now the default theme; consistent dark-mode header colour across screens.
- Updated contact details (WhatsApp, LinkedIn → DevSafe company page, TikTok).
- Interim Terms & Conditions covering fees, escrow, disputes and age.

### Fixed

- Dark-mode contrast: Discover search text, Sell-screen buy-back toggle, profile switches, payment sheet, escrow tabs.
- Seller profile "not found", overflowing escrow action buttons, ID upload permission error, CO₂ saved units.
- Pending-order badges can no longer show a previous account's counts.
- Grants migration no longer fails on databases where `reviews`/`boost_payments` don't exist (CI schema rebuild).

### Security

- Hardened RLS and table grants (no client TRUNCATE; read-only transactions), moved WhatsApp number and FCM token to owner-only storage, rate-limited public Rust endpoints, webhook logs no longer include header values.

---

## 1.3.0 - February 15, 2026

### Added

- **Multi-language Support**: Full support for English and French localization across the app.
- **Fapshi Integration**: Integrated community donation support via a dedicated Fapshi checkout link.
- **SvelteKit Landing Page**: Initial production build of the web front-end.

### Changed

- **UI Refinements**: Compacted promotional section for a more native feel (155px height).
- **Design System**: Harmonized UI with "pill" style capsule containers for icons and buttons.
- **Project Structure**: Cleaned up 20+ redundant files and migrated to local `l10n` imports for stability.
- **Git Hygiene**: Comprehensive `.gitignore` updates for a cleaner development environment.

### Fixed

- **Layout Overflows**: Resolved persistent "RIGHT OVERFLOWED" and "BOTTOM OVERFLOWED" issues on the home screen.
- **Localization Bug**: Fixed critical "Undefined name 'AppLocalizations'" regression.

---

## 1.2.0 - February 14, 2026

### Added

- **Nearby Books**: Initial implementation of location-based listing discovery.
- **Promo Banners**: Dynamic PageView for promotional messaging.

---

### Added

- **Custom App Launcher Icon**: Beautiful BookBridge logo with intricate patterns on an open book design
- **App Icon Assets**: Added `assets/app_icon.png` to project resources
- **Adaptive Icons**: Configured adaptive icons for Android with black background

### Changed

- Updated `pubspec.yaml` to include app icon configuration
- Integrated `flutter_launcher_icons` package for icon generation

### Technical

- Generated launcher icons for both Android and iOS platforms
- Configured adaptive icon foreground and background for Android

---

## 1.0.0 - January 2026

### Features Implemented

#### Authentication

- Email/password sign-up and sign-in via Supabase Auth
- User profile creation with full name and locality
- Password reset functionality
- Automatic profile creation via database trigger
- Auth state-based navigation

#### Listings Management

- Browse available book listings in grid layout
- Infinite scroll pagination (50 items per page)
- Create new listings with image upload
- Image upload to Supabase Storage (`book_images` bucket)
- Delete own listings with confirmation
- View listing details with seller information

#### Search

- Full-text search across book titles and authors
- PostgreSQL tsvector-based search with ranking
- Real-time search results

#### Profile

- View and edit user profile
- Manage user's own listings
- WhatsApp contact integration
- Sign out functionality

#### UI/UX

- Material Design 3 implementation
- "Knowledge & Trust" visual identity
  - Scholar Blue (#1A4D8C) primary color
  - Bridge Orange (#F2994A) secondary color
  - Growth Green (#27AE60) tertiary color
- Google Fonts integration (Montserrat, Inter)
- Bottom navigation bar (Home, Search, Sell, Profile)
- Pull-to-refresh on home screen
- Loading states and error handling
- Empty states with helpful messages

### Architecture

- Clean Architecture with Domain/Data/Presentation layers
- Provider state management with ChangeNotifier
- Dependency injection with GetIt
- Navigation with go_router and auth-based redirection
- Error handling with Either<Failure, Success> pattern (dartz)

### Database

- PostgreSQL tables: `profiles`, `listings`
- Row Level Security (RLS) policies
- Full-text search function
- Automatic profile creation trigger
- Indexes for optimized queries

### Storage

- Supabase Storage for book images
- Public bucket with RLS policies
- User-specific folder structure

### Documentation

- Comprehensive README with architecture overview
- Detailed Supabase setup guide (665 lines)
- Implementation documentation
- Brand identity guide
- Social venture vision document

---

## 0.1.0 - Initial Setup

- Initial release of BookBridge application
- Flutter project setup with Clean Architecture and MVVM
- Supabase integration planned for Auth, PostgreSQL, and Storage
- Dark theme applied
- Core features (Auth, Home Feed, Search, Sell, Profile, Book Details) outlined

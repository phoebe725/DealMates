# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DealMates is a native iOS (SwiftUI) app for finding dining companions at nearby restaurants. Users browse restaurants, create or join short-lived "plans" (group meetups, often ASAP), and chat in real time inside each plan.

- Xcode project: `DealMates.xcodeproj` (no workspace)
- App target: `DealMates`, bundle id `com.jj.DealMates`
- Swift 5.0, deployment target iOS 26.5, universal (iPhone + iPad)
- No tests, lint, or CI configured in the repo

## Build / run

Open in Xcode and run on a simulator:

```bash
open DealMates.xcodeproj
```

Command-line build (the scheme name matches the target):

```bash
xcodebuild -project DealMates.xcodeproj -scheme DealMates \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

SPM dependencies (resolved by Xcode automatically): `supabase-swift` (≥2.5.1), `ios-maps-sdk`, `ios-places-sdk`. The Google Maps/Places SDKs are linked but the in-app map currently uses Apple `MapKit` (`RestaurantMapView.swift`) — keep this in mind before adding Google-specific code.

## Architecture

MVVM layered on top of Supabase. Three concentric layers:

1. **`Services/`** — singletons that own all I/O.
   - `SupabaseManager.shared` exposes the single `SupabaseClient` plus shared `JSONEncoder`/`JSONDecoder`. The decoder handles ISO-8601 dates with/without fractional seconds. Key strategy is `.useDefaultKeys` — **models must declare explicit `CodingKeys` for snake_case columns** (every model under `Models/` does this).
   - `AuthService.shared` wraps Supabase Auth (anonymous + email/password) and the `users` table. `ensureUserProfileExists` is the canonical "get-or-create profile" path; it upserts on `id` (never on `email`) and falls back to fetch-by-email only if it sees a unique-constraint error.
   - `DatabaseService.shared` owns restaurants, plans, messages, and realtime subscriptions. `listenToPlans` / `listenToMessages` return cancellable `Task`s subscribed via `realtimeV2.channel(...).postgresChange(...)` filtered server-side. Cancel the returned task to unsubscribe.

2. **`ViewModels/`** — `@MainActor`, `ObservableObject`. One per feature surface (`AuthViewModel`, `RestaurantViewModel`, `PlanViewModel(restaurantId:)`, `ChatViewModel(planId:)`). View models only call services — they don't touch `SupabaseManager` directly. The realtime view models follow a `startListening()` / `stopListening()` pattern and cancel their `listenerTask` in `deinit`.

3. **`Views/`** — SwiftUI. `DealMatesApp` is the root and decides between `SplashView` / `LoginView` / `ContentView` (a `TabView`) based on `AuthViewModel.isLoading` and `isSignedIn`. `AuthViewModel` is injected as an `@EnvironmentObject` from the root; other VMs are `@StateObject` inside the view that owns them. Reusable cells live in `Views/Components/`.

### Auth model worth knowing

Sessions are bootstrapped in `AuthViewModel.init` → `bootstrap()`. If no session exists, the user is **signed in anonymously** immediately so the app always has a `currentUser`. `isSignedIn` is true only for non-anonymous users; gate features that require a real account on `isSignedIn`, not on `currentUser != nil`. `signOut()` deliberately signs back in anonymously rather than dropping to a nil user.

### Plans data flow

A `Plan` row carries `member_ids: [String]`, `current_people`, and `expires_at`. Joining/leaving is done by reading the plan, mutating those fields, and writing back via a small ad-hoc `Encodable` `Patch` struct — this pattern is used throughout `DatabaseService` and `AuthService` to send a partial update with snake_case keys. When `joinPlan`/`leavePlan` succeed they also insert a system `ChatMessage` (`isSystem: true`, `senderId: "system"`). "My Plans" queries use `.contains("member_ids", value: [userId])` + `.gt("expires_at", now)`.

## Supabase backend

The app is wired to a hosted Supabase project; credentials live in `DealMates/Config.swift` (anon publishable key — safe to commit, but rotate via the dashboard if changed). Expected schema:

- `users` — primary key `id` (auth uid as lowercase uuid string), columns include `email`, `display_name`, `bio`, `avatar_url`, `is_anonymous`, `blocked_users`, `reported_plans`, `created_at`, `updated_at`. Unique constraint on `email` (the auth code branches on `users_email_key` violations).
- `restaurants` — `id`, `name`, `cuisine`, `address`, `image_url`, `latitude`, `longitude`.
- `plans` — see `Plan.CodingKeys` for the exact column list (`restaurant_id`, `creator_id`, `is_asap`, `scheduled_at`, `needed_people`, `current_people`, `member_ids`, `purpose`, `expires_at`, `reported_by`, …).
- `messages` — `id`, `plan_id`, `sender_id`, `sender_name`, `text`, `timestamp`, `is_system`. Realtime must be enabled on `plans` and `messages` for the listeners to fire.
- Storage bucket `avatars` — public, objects keyed `{uid}.jpg`. `AuthService.uploadAvatar` upserts then appends a `?t=<epoch>` cache-buster to the public URL so `AsyncImage` refetches.

## Conventions

- All Codable models use **explicit `CodingKeys`** to map camelCase Swift ↔ snake_case Postgres. Don't rely on automatic key conversion — the shared decoder/encoder are deliberately set to `.useDefaultKeys`.
- IDs are lowercased UUID strings (`.uuidString.lowercased()`); follow this when constructing new ids.
- All services are singletons accessed via `.shared`; view models hold them via `private let service = …` rather than DI. Stay consistent unless you're deliberately refactoring.
- Partial updates use a one-off nested `struct Patch: Encodable { … }` with `CodingKeys`. Reuse that pattern instead of mutating a full model and round-tripping it.
- `[DEBUG]` `print` statements are used for tracing auth/data flow; keep new ones in the same style or remove existing ones if cleaning up.

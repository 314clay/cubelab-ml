# CubeLab: Flutter Frontend — Full Build-Out

## What To Do Each Iteration

You are iterating on the CubeLab Flutter app — a Rubik's Cube training platform. Each iteration, read this prompt, check what was done previously (`git log`, existing files, `flutter analyze`), identify the highest-priority incomplete step, and push it forward. Run `flutter analyze` after every change to confirm zero errors.

## Project Root

`/Users/clayarnold/Documents/github/cubelab/`

## Current State

The app compiles and runs on Flutter web (`flutter run -d chrome --web-port=3456`). All 80+ Dart files exist. `flutter analyze` returns 0 errors, 0 warnings (127 info-level lints only).

**What works:**
- Home page with 4 feature cards + profile icon
- Navigation to all 5 sections (Cross Trainer, Algorithms, Timer, Daily Scramble, Profile)
- SectionShell (tabbed page container) for Cross Trainer, Algorithms, Daily Scramble
- Standalone pages for Timer and Profile
- All 6 Supabase repository implementations exist
- All repository interfaces and providers wired up
- Graceful error handling when Supabase is not connected (every page shows friendly error instead of red crash screen)

**What's stubbed/placeholder:**
- No Supabase initialization in `main.dart` (no `Supabase.initialize()` call)
- No auth flow — no login/signup screens
- No local-first fallback — everything crashes gracefully but shows "can't connect" errors
- Timer scramble generator is naive random (no WCA-quality scrambles)
- Profile page shows stub data from `StubProfileRepository`
- No settings/preferences persistence
- No 3D cube visualization anywhere
- No algorithm images or diagrams
- No onboarding flow

---

## Architecture

### Tech Stack
- **Framework:** Flutter 3.x (Dart)
- **State:** Riverpod (`flutter_riverpod ^2.4.0`)
- **Backend:** Supabase (`supabase_flutter ^2.3.0`)
- **IDs:** `uuid ^4.5.2`
- **Platform:** Web (also set up for iOS)

### Design System

**Colors** (`lib/core/theme/app_colors.dart`):
```
background: #121212 (dark)
surface:    #1E1E1E (cards/containers)
primary:    #4CAF50 (green — accents, buttons, active states)
textPrimary:   #FFFFFF
textSecondary: #9E9E9E
textTertiary:  #616161
border:     #2C2C2C
error:      #EF5350
success:    #66BB6A
```

**Text Styles** (`lib/core/theme/app_text_styles.dart`):
- `h2` (24px bold), `h3` (20px w600), `body` (16px), `bodySecondary` (16px gray), `caption` (12px), `overline` (11px w600 spaced), `buttonText` (16px w500), `timerLarge` (48px bold mono), `scramble` (15px mono)

**Spacing** (`lib/core/theme/app_spacing.dart`):
- `xs=4, sm=8, md=12, lg=24, xl=32`, `pagePadding=20`, `cardRadius=12`, `buttonRadius=8`

### Patterns

**Pages:** `ConsumerWidget` or `ConsumerStatefulWidget` extending Riverpod
**State:** `StateNotifierProvider` for interactive flows (timer, practice), `FutureProvider` for data fetching
**Error handling:** Every provider that accesses a repository is wrapped in try-catch with `.errored()` factory constructors. UI checks `state.error != null` before rendering.
**Friendly errors:** `import 'package:cubelab/core/utils/error_utils.dart'` → `friendlyError(error.toString())` strips internal file paths
**Navigation:** `NavigationUtils.goToX(context)` for top-level nav, `Navigator.push(context, MaterialPageRoute(...))` for sub-pages
**Sections:** `SectionShell(title, pages: [SectionPage(label, page)])` for tabbed feature areas
**Standalone pages:** Timer and Profile use their own Scaffold with back button

---

## File Inventory (80 files)

### Core (`lib/core/`)
| File | Status | Purpose |
|------|--------|---------|
| `theme/app_colors.dart` | DONE | Color constants |
| `theme/app_text_styles.dart` | DONE | TextStyle constants |
| `theme/app_spacing.dart` | DONE | Spacing/radius constants |
| `theme/widgets/app_card.dart` | DONE | Reusable card widget |
| `utils/error_utils.dart` | DONE | `friendlyError()` strips internal paths |
| `utils/navigation_utils.dart` | DONE | Static nav methods to all sections |

### Data Models (`lib/data/models/`) — 20 files
| File | Status | Purpose |
|------|--------|---------|
| `algorithm.dart` | DONE | Algorithm with id, name, set, notation, imageUrl |
| `algorithm_case.dart` | DONE | AlgorithmCase |
| `algorithm_mastery.dart` | DONE | Mastery tracking |
| `algorithm_review.dart` | DONE | SRS review record |
| `algorithm_solve.dart` | DONE | Individual algorithm solve |
| `cross_session.dart` | DONE | Cross training session |
| `cross_solve.dart` | DONE | Cross solve with inspection+execution times |
| `cross_srs_item.dart` | DONE | Cross SRS item with SRSState |
| `daily_algorithm_challenge.dart` | DONE | Daily algorithm challenge |
| `daily_challenge_attempt.dart` | DONE | Daily challenge attempt |
| `daily_challenge.dart` | DONE | DailyChallenge + DailyScrambleSolve |
| `leaderboard.dart` | DONE | LeaderboardEntry, CrossLeaderboard, AlgorithmLeaderboard |
| `models.dart` | DONE | Barrel export file |
| `pro_solve.dart` | DONE | Professional reconstruction (solver, moves, video) |
| `solve_comment.dart` | DONE | Comment on a solve |
| `srs_state.dart` | DONE | SRSState + SRSRating for spaced repetition |
| `stats.dart` | DONE | CrossStats, LevelStats, AlgorithmStats |
| `timer_session.dart` | DONE | TimerSession with computed Ao5/Ao12 |
| `timer_solve.dart` | DONE | TimerSolve with penalty/DNF |
| `timer_stats_snapshot.dart` | DONE | All-time timer stats (TimerStats) |
| `training_session.dart` | DONE | Training session + SessionMode |
| `training_solve.dart` | DONE | Training solve |
| `training_stats.dart` | DONE | Training stats |
| `user_algorithm.dart` | DONE | User's relationship to an algorithm |
| `user.dart` | DONE | User model |
| `zbll_subset.dart` | DONE | ZBLLSubset + ZBLLStructure |

### Repository Interfaces (`lib/data/repositories/`) — 7 files
| File | Status | Purpose |
|------|--------|---------|
| `algorithm_repository.dart` | DONE | 30+ methods for algorithm CRUD, SRS, training |
| `cross_trainer_repository.dart` | DONE | Cross practice, SRS, stats, scramble gen |
| `daily_challenge_repository.dart` | DONE | Daily challenge, solves, community, GOAT |
| `leaderboard_repository.dart` | DONE | Cross + algorithm leaderboards |
| `profile_repository.dart` | DONE | Aggregated profile stats |
| `timer_repository.dart` | DONE | Session, solve, stats persistence |
| `user_repository.dart` | DONE | User CRUD, auth state |

### Supabase Implementations (`lib/data/supabase/`) — 6 files
| File | Status | Purpose |
|------|--------|---------|
| `supabase_algorithm_repository.dart` | DONE | Full Supabase implementation |
| `supabase_cross_trainer_repository.dart` | DONE | Full Supabase implementation |
| `supabase_daily_challenge_repository.dart` | DONE | Full Supabase implementation |
| `supabase_leaderboard_repository.dart` | DONE | Full Supabase implementation |
| `supabase_timer_repository.dart` | DONE | Full Supabase implementation |
| `supabase_user_repository.dart` | DONE | Full Supabase implementation |

### Stubs (`lib/data/stubs/`)
| File | Status | Purpose |
|------|--------|---------|
| `json_loader.dart` | DONE | Asset loading helpers |
| `stub_profile_repository.dart` | DONE | Returns placeholder profile data |

### Shared (`lib/shared/`)
| File | Status | Purpose |
|------|--------|---------|
| `providers/repository_providers.dart` | DONE | All repository providers (Supabase-backed) |
| `providers/supabase_providers.dart` | DONE | `supabaseClientProvider` |
| `widgets/section_shell.dart` | DONE | Tabbed section container (TabBar + PageView) |

### Features

**Home (`lib/features/home/`):**
| File | Status | Purpose |
|------|--------|---------|
| `home_page.dart` | DONE | 4 feature cards + profile nav |
| `providers/home_provider.dart` | DONE | Re-exports daily scramble providers |
| `widgets/daily_scramble_card.dart` | DONE | Home card showing today's challenge status |

**Daily Scramble (`lib/features/daily_scramble/`):**
| File | Status | Purpose |
|------|--------|---------|
| `daily_scramble_section.dart` | DONE | SectionShell: Solve / Community / GOAT tabs |
| `models/daily_scramble_state.dart` | DONE | DailyScrambleState + DailySolvePhase enum |
| `providers/daily_scramble_providers.dart` | DONE | DailyScrambleNotifier + convenience providers |
| `pages/daily_scramble_page.dart` | DONE | Hold-to-start timer, result card, already-completed view |
| `pages/daily_scramble_submit_page.dart` | DONE | Submit form: notes, pairs, xcross/zbll toggles |
| `pages/daily_scramble_results_page.dart` | DONE | Results: user time, community ranking, GOAT preview |
| `pages/community_solves_page.dart` | DONE | Ranked list of community solves |
| `pages/goat_list_page.dart` | DONE | List of pro reconstructions |
| `pages/goat_reconstruction_page.dart` | DONE | Pro solve detail: scramble, solution, video link |
| `widgets/scramble_display.dart` | DONE | Monospace scramble text in styled container |
| `widgets/goat_summary_card.dart` | DONE | Pro solve summary card |
| `widgets/solve_timer.dart` | DONE | Timer widget with hold-to-start |

**Cross Trainer (`lib/features/cross_trainer/`):**
| File | Status | Purpose |
|------|--------|---------|
| `cross_trainer_section.dart` | DONE | SectionShell: Practice / SRS / Stats tabs |
| `providers/cross_trainer_providers.dart` | DONE | CrossPracticeNotifier, SRS + stats providers |
| `pages/cross_practice_page.dart` | DONE | Scramble, inspection/execution timer, success/fail |
| `pages/cross_srs_page.dart` | DONE | SRS review queue for cross scrambles |
| `pages/cross_stats_page.dart` | DONE | Stats dashboard: totals, rates, per-level breakdown |

**Algorithms (`lib/features/algorithm/`):**
| File | Status | Purpose |
|------|--------|---------|
| `algorithm_section.dart` | DONE | SectionShell: Catalog / Train / SRS / Stats tabs |
| `providers/algorithm_providers.dart` | DONE | Catalog, training, SRS, stats providers |
| `pages/algorithm_catalog_page.dart` | DONE | Browse by set (OLL/PLL/ZBLL), expand/enable toggle |
| `pages/algorithm_training_page.dart` | DONE | Active drill: show case, timer, rate performance |
| `pages/algorithm_srs_page.dart` | DONE | SRS review queue for due algorithms |
| `pages/algorithm_stats_page.dart` | DONE | Stats: learned count, due today, per-set breakdown |

**Timer (`lib/features/timer/`):**
| File | Status | Purpose |
|------|--------|---------|
| `timer_page.dart` | DONE | Standalone page: scramble, hold-to-start timer, solve list |
| `providers/timer_providers.dart` | DONE | TimerNotifier with scramble gen, session, stats |
| `widgets/timer_stats_bar.dart` | DONE | Horizontal stats: PB, Ao5, Ao12, total |
| `widgets/solve_list.dart` | DONE | Scrollable list with swipe-to-delete, penalty toggle |

**Profile (`lib/features/profile/`):**
| File | Status | Purpose |
|------|--------|---------|
| `profile_page.dart` | DONE | User info, stats cards, sign out |
| `providers/profile_providers.dart` | DONE | Profile state from profileRepositoryProvider |

---

## Steps (work in order, verify each before proceeding)

### STEP 1: Fix all lint warnings

Run `flutter analyze` and fix every `info`-level lint. These are mostly:
- `prefer_const_constructors` — add `const` where possible
- `prefer_const_literals_to_create_immutables` — const lists
- `unnecessary_this` — remove `this.` prefix
- `prefer_final_locals` — use `final` for non-reassigned locals

**Verification:**
- [ ] `flutter analyze` returns `No issues found!`

---

### STEP 2: Add Supabase initialization and environment config

Currently `main.dart` has no Supabase initialization. The app needs:

1. Add `Supabase.initialize(url: ..., anonKey: ...)` in `main()` before `runApp()`
2. Create `lib/core/config/env.dart` with environment config:
   - Read Supabase URL and anon key from `--dart-define` or `String.fromEnvironment`
   - Fallback to empty strings (app degrades gracefully)
3. Update `supabase_providers.dart` to use the initialized client
4. Add `WidgetsFlutterBinding.ensureInitialized()` before Supabase init

**Verification:**
- [ ] App launches without Supabase credentials (graceful degradation)
- [ ] App launches WITH credentials and connects (`flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`)
- [ ] `flutter analyze` — 0 errors

---

### STEP 3: Build local-first data layer with SQLite/Hive

The app currently requires Supabase for everything. Add a local-first layer so the app works offline.

1. Add `hive_flutter` (or `sqflite` + `path_provider`) to pubspec.yaml
2. Create local repository implementations in `lib/data/local/`:
   - `local_timer_repository.dart` — Store timer sessions/solves locally
   - `local_cross_trainer_repository.dart` — Store cross practice data locally
   - `local_algorithm_repository.dart` — Store algorithm progress locally
3. Update `repository_providers.dart` to use local repos when Supabase is unavailable:
   ```dart
   final timerRepositoryProvider = Provider<TimerRepository>((ref) {
     try {
       final client = ref.watch(supabaseClientProvider);
       return SupabaseTimerRepository(client);
     } catch (_) {
       return LocalTimerRepository();
     }
   });
   ```
4. Algorithms catalog should load from bundled JSON assets (`assets/algorithms/`) even without Supabase

**Verification:**
- [ ] Timer works fully offline (scramble → hold → solve → save → appears in list)
- [ ] Cross Trainer practice works offline
- [ ] Algorithm catalog loads from local assets
- [ ] `flutter analyze` — 0 errors

---

### STEP 4: Auth flow — login, signup, session persistence

1. Create `lib/features/auth/` with:
   - `auth_page.dart` — Login/signup screen with email+password
   - `providers/auth_providers.dart` — Auth state, login/logout methods
2. Update `main.dart` to check auth state on launch:
   - If logged in → HomePage
   - If not → AuthPage
3. Add Supabase auth methods to `UserRepository`:
   - `signIn(email, password)`
   - `signUp(email, password)`
   - `signOut()`
   - `getCurrentUser()` stream
4. Profile page sign out button should actually call sign out

**Verification:**
- [ ] Can create account with email/password
- [ ] Can log in with existing account
- [ ] Session persists across app restarts
- [ ] Sign out returns to auth page
- [ ] App works without auth (anonymous/local mode)
- [ ] `flutter analyze` — 0 errors

---

### STEP 5: WCA-quality scramble generator

The current timer scramble generator is naive random:
```dart
// Current: picks random face + suffix, only avoids same-face consecutive
String _generateScramble() { ... }
```

Replace with WCA-legal random-state scrambles:

1. Create `lib/core/utils/scramble_generator.dart`:
   - Generates random-state 3x3 scrambles (20-25 moves)
   - Avoids: same face consecutive, same axis consecutive (R then L, etc.)
   - Properly distributes move counts
2. Use it in `timer_providers.dart` and `cross_trainer_providers.dart`
3. Also use it for the Daily Scramble if generating locally

**Verification:**
- [ ] Generated scrambles are 20+ moves, no consecutive same-face or same-axis
- [ ] Timer page shows proper scrambles
- [ ] Cross Trainer generates proper scrambles
- [ ] `flutter analyze` — 0 errors

---

### STEP 6: Algorithm catalog with bundled data

The algorithm catalog currently requires Supabase to load algorithms. Bundle algorithm data locally:

1. Create `assets/algorithms/oll.json` — All 57 OLL cases with names, notations, images
2. Create `assets/algorithms/pll.json` — All 21 PLL cases
3. Create `assets/algorithms/zbll.json` — ZBLL subsets and cases
4. Update `json_loader.dart` to load from assets
5. Create `LocalAlgorithmRepository` that serves catalog from assets
6. Algorithm catalog page should show real algorithm data with case images
7. Add algorithm images (SVGs or PNGs) to assets

**Verification:**
- [ ] Algorithm Catalog tab shows all 57 OLL cases with names and notations
- [ ] Algorithm Catalog tab shows all 21 PLL cases
- [ ] Tapping an algorithm shows its details (notation, image)
- [ ] Filter by set (OLL/PLL) works
- [ ] `flutter analyze` — 0 errors

---

### STEP 7: Interactive 3D cube visualization

Add a cube visualization widget that can display a scrambled state:

1. Add a 3D rendering package (`flutter_cube` or custom Canvas paint)
2. Create `lib/shared/widgets/cube_visualizer.dart`:
   - Takes a scramble string → applies moves → renders 3D cube
   - Shows all 6 faces with correct colors
   - Supports rotation (drag to rotate)
3. Integrate into:
   - `ScrambleDisplay` (replace text-only with cube + text)
   - Timer page (show scrambled state above timer)
   - Daily Scramble page (show scramble visually)

**Verification:**
- [ ] Cube renders with correct colors for a given scramble
- [ ] Drag to rotate works
- [ ] Appears on Timer page and Daily Scramble page
- [ ] `flutter analyze` — 0 errors

---

### STEP 8: Polish UI/UX

1. **Loading skeletons**: Replace `CircularProgressIndicator` with shimmer/skeleton loading states
2. **Animations**: Add hero transitions between pages, fade-in for lists
3. **Pull-to-refresh**: Add to Community Solves, GOAT list, Algorithm catalog
4. **Haptic feedback**: Add on timer start/stop, button taps (mobile)
5. **Empty states**: Improve all empty state illustrations (currently just icon + text)
6. **Responsive layout**: Ensure all pages look good on phone, tablet, and web widths
7. **Keyboard shortcuts** (web): Space to start/stop timer, Enter to confirm

**Verification:**
- [ ] Every page has a loading skeleton (no spinners)
- [ ] Timer start/stop has haptic feedback on mobile
- [ ] Pages look good at 375px, 768px, and 1200px widths
- [ ] `flutter analyze` — 0 errors

---

### STEP 9: Testing

1. **Unit tests** (`test/`):
   - All data models: fromJson/toJson round-trip
   - Scramble generator: validates output format
   - Timer state machine: idle → holding → solving → stopped transitions
   - Cross practice state machine: all phase transitions
2. **Widget tests** (`test/`):
   - Home page renders 4 feature cards
   - Timer page shows scramble and timer
   - SectionShell renders tabs correctly
3. **Integration tests** (`integration_test/`):
   - Full timer flow: open → scramble → hold → solve → save
   - Daily scramble flow: open → solve → submit → see results
   - Navigation: home → each section → back

**Verification:**
- [ ] `flutter test` — all tests pass
- [ ] >80% code coverage on state notifiers
- [ ] >50% overall coverage
- [ ] `flutter analyze` — 0 errors

---

### STEP 10: Supabase schema and sync

Define and apply the Supabase database schema, then verify end-to-end data flow:

1. Create `supabase/migrations/` with SQL migration files matching the Supabase repository implementations
2. Tables needed (derived from Supabase repos):
   - `users`, `daily_challenges`, `daily_scramble_solves`, `pro_solves`
   - `algorithms`, `user_algorithms`, `algorithm_reviews`, `training_sessions`, `training_solves`
   - `cross_solves`, `cross_srs_items`, `cross_sessions`
   - `timer_sessions`, `timer_solves`
   - `leaderboard_entries`
3. Add RLS (Row Level Security) policies for user data isolation
4. Test full sync: local solve → Supabase → retrieve on another session

**Verification:**
- [ ] All tables created with correct columns
- [ ] RLS policies prevent cross-user data access
- [ ] Timer solve saves to Supabase and appears in stats
- [ ] Daily scramble solve saves and appears in community list
- [ ] `flutter analyze` — 0 errors

---

## Conventions

- **Imports:** Always use `package:cubelab/...` (not relative)
- **Theme:** Use `AppColors.*`, `AppTextStyles.*`, `AppSpacing.*` exclusively — never hardcode colors/sizes
- **Errors:** Wrap all repository access in try-catch. Use `friendlyError()` for display.
- **State:** Riverpod `StateNotifierProvider` for interactive flows, `FutureProvider` for data fetching
- **No over-engineering:** Don't add features not in the current step. Don't refactor working code unless the step requires it.
- **Test after every change:** Run `flutter analyze` after every file modification

---

## Running the App

```bash
# Development (web)
flutter run -d chrome --web-port=3456

# With Supabase credentials
flutter run -d chrome --web-port=3456 \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# Analyze
flutter analyze

# Test
flutter test
```

## Completion

When ALL of these are true:
- Step 1: `flutter analyze` — no issues at all
- Step 2: Supabase initialization with env config
- Step 3: Local-first data layer (app works offline)
- Step 4: Auth flow (login/signup/session persistence)
- Step 5: WCA-quality scramble generator
- Step 6: Algorithm catalog with bundled data
- Step 7: 3D cube visualization
- Step 8: UI/UX polish (skeletons, animations, responsive)
- Step 9: Tests passing with >80% notifier coverage
- Step 10: Supabase schema deployed and syncing

Output: `<promise>FRONTEND COMPLETE</promise>`

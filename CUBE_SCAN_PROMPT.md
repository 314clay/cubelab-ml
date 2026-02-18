# Cube Scan Feature — Ralph Loop Prompt

## What This Is

You are iterating on the "Cube Scan" feature for CubeLab, a Flutter Rubik's Cube training app. Each iteration, read this prompt, check what was done previously (git log, existing files, `flutter analyze`), and push the next piece forward.

## Current State

The UI scaffolding is built with stub data. The following files exist and pass `flutter analyze`:

### Already Built (11 new files + 3 modified)
- `lib/data/models/cube_scan_result.dart` — CubeScanResult, SolvePath, SolveStep
- `lib/data/models/cube_scan_encounter.dart` — CubeScanEncounter with Supabase serialization
- `lib/data/services/cube_analysis_service.dart` — Abstract ML inference interface
- `lib/data/services/stub_cube_analysis_service.dart` — Hardcoded OLL 27 stub
- `lib/data/repositories/cube_scan_repository.dart` — Abstract scan history interface
- `lib/data/stubs/stub_cube_scan_repository.dart` — In-memory list implementation
- `lib/features/cube_scan/cube_scan_page.dart` — Full state-machine page (camera/processing/results/error/done)
- `lib/features/cube_scan/providers/cube_scan_providers.dart` — CubeScanNotifier + providers
- `lib/features/cube_scan/widgets/phase_badge_widget.dart` — Phase display with colored accent
- `lib/features/cube_scan/widgets/solve_path_card.dart` — Expandable solve path with timeline
- `lib/features/cube_scan/widgets/srs_action_widget.dart` — Discovery/enrollment prompt
- Modified: `home_page.dart` (5th card), `navigation_utils.dart` (goToCubeScan), `repository_providers.dart` (cubeScanRepo)

### What's Stubbed (needs real implementation)
1. **Camera** — No real camera. "Simulate Scan" button sends empty bytes. Needs `camera` package.
2. **ML inference** — StubCubeAnalysisService returns hardcoded data. Needs real server or on-device inference.
3. **SRS wiring** — "Add to Practice Queue" / "Skip" buttons just transition to done. Not calling `algorithmRepository.setAlgorithmEnabled()` or `recordReview()`.
4. **Scan history persistence** — In-memory stub. Needs Supabase table + implementation.
5. **Photo overlay** — Not built. Needs CV localization + CustomPainter for sticker highlighting.

## Remaining Work (in priority order)

### Step 1: Wire SRS Integration
Connect the SRS action buttons to the existing algorithm repository:
- In `cube_scan_page.dart`, when "Add to Practice Queue" is tapped:
  - Look up the algorithm by caseName via `algorithmRepositoryProvider`
  - Call `setAlgorithmEnabled(algorithmId, true)`
  - Show snackbar confirmation
- When user already has the algorithm, show the 4-button SRS rating (Again/Hard/Good/Easy) instead of discovery prompt
- Record `AlgorithmReview` via `recordReview()`
- The `CubeScanNotifier` needs access to `AlgorithmRepository` (pass via constructor or ref)

### Step 2: Improve Stub Variety
Make `StubCubeAnalysisService` return different results randomly (not always OLL 27):
- Randomly pick from: OLL 27, PLL T-Perm, solved state, OLL 45, PLL H-Perm
- This helps test different UI states (OLL phase, PLL phase, solved)

### Step 3: Add Camera Support
Add the `camera` package and replace the placeholder:
- `pubspec.yaml`: add `camera: ^0.11.0`
- Create `lib/features/cube_scan/widgets/camera_preview_widget.dart`
- Initialize camera in `CubeScanPage` initState
- Replace the dark placeholder with actual CameraPreview
- Capture photo bytes on shutter tap
- Handle camera permissions (iOS Info.plist, Android manifest)

### Step 4: Photo Overlay (Sticker Highlighting)
- Create `lib/data/services/cube_localization_service.dart` — CV corner detection
- Create `lib/features/cube_scan/widgets/sticker_overlay_painter.dart` — CustomPainter
- In results phase, display captured photo with overlay highlighting wrong stickers
- Highlighting rules by phase:
  - OLL: orange glow on non-white U-face stickers, green on correct ones
  - PLL: amber on mispositioned side stickers
  - Solved: all green

### Step 5: Real ML Service
- Create server endpoint running Python `pipeline.py`
- Create `lib/data/services/remote_cube_analysis_service.dart` — HTTP POST implementation
- OR convert ResNet-18 to CoreML/TFLite and create local implementation
- Swap the provider from stub to real

### Step 6: Scan History Persistence
- Create Supabase table `cube_scan_encounters`
- Create `lib/data/supabase/supabase_cube_scan_repository.dart`
- Log every scan with phase, case, confidence, SRS action taken

## Existing Codebase Patterns (FOLLOW THESE)
- **State management**: Riverpod StateNotifier (see `lib/features/algorithm/providers/algorithm_providers.dart`)
- **UI**: ConsumerWidget + AppCard + AppColors/AppTextStyles/AppSpacing
- **Models**: fromJson/toJson/fromSupabase/toSupabase + copyWith
- **Repositories**: Abstract in `lib/data/repositories/`, impl in `lib/data/supabase/` or `lib/data/stubs/`

## Constraints
- `flutter analyze --no-fatal-infos` must pass after every change
- Do NOT modify existing feature code except home_page.dart and navigation_utils.dart
- Follow exact patterns from existing codebase

## Completion Criteria
All steps 1-6 complete. SRS wiring works, camera captures real photos, ML inference runs (server or on-device), photo overlay highlights stickers, scan history persists to Supabase.

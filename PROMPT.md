# CubeLab: End-to-End Rubik's Cube Photo Analysis Pipeline

## What To Do Each Iteration
You are iterating on the Rubik's Cube photo analysis pipeline. Each iteration, read this prompt, check what was done previously (git log, existing files, test results), and push the next piece forward.

## Ultimate Goal
Given a photo of a Rubik's Cube showing 3 faces (Top, Front, Right), reconstruct the full 54-sticker cube state and solve it.

Pipeline: **Photo → ML model → 27 visible stickers → derive full 54-sticker state → solver → solution**

### Key Insight: 27 Visible Stickers = Full Cube State

When viewing U, F, R faces, we see 27 of 54 stickers. The other 27 (on D, B, L) are ALL determinable:

1. **12 stickers from completely occluded pieces** (1 corner DBL + 3 edges DB/DL/BL + 3 centers D/B/L) — these are F2L pieces, always solved, so their colors are known by definition.

2. **15 stickers from partially visible pieces** — each belongs to a piece that has at least one sticker on a visible face:
   - Corners with 2 visible stickers (UFL, UBR): 3rd sticker is the remaining color of the identified piece
   - Corner with 1 visible sticker (UBL): determined by elimination (other 3 corners identified)
   - Edges with 1 visible sticker (UB, UL): identified by the visible sticker color, or by elimination + parity constraint when both are oriented (White on top)

**Zero actual unknowns.** The full state can be fed directly to Kociemba or any cube solver.

## Project Root
`/Users/clayarnold/iCloud Drive (Archive)/Documents/github/cubelab/cubelab/experimentation/`

## Key Files

### CV Pipeline (cube-photo-solve/)
| File | Purpose |
|------|---------|
| `cube-photo-solve/state_resolver.py` | `Cube` class (move simulation) + `StateResolver` (brute-force lookup table) |
| `cube-photo-solve/algorithms.py` | All 57 OLL + 21 PLL algorithms as move strings |
| `cube-photo-solve/cube_vision.py` | `CubeVision` class: OpenCV hexagon detection, Y-junction, grid sampling, K-means color classification |
| `cube-photo-solve/cube_analyzer.py` | CLI entry point wiring vision + resolver together |
| `cube-photo-solve/requirements.txt` | opencv-python, numpy, scikit-learn, kociemba |
| `cube-photo-solve/tests/test_resolver.py` | Existing unit tests for Cube + StateResolver |
| `cube-photo-solve/tests/test_vision.py` | Existing unit tests for CubeVision |
| `cube-photo-solve/tests/test_cube_moves.py` | Move correctness tests (created during this work) |

### Blender Rendering (ml/blender/)
| File | Purpose |
|------|---------|
| `ml/blender/render_known_states.py` | Renders cubes with known OLL/PLL states at fixed camera angle |
| `ml/blender/render_training_data.py` | Generates randomized renders (varied camera/lighting) for ML training |
| `ml/blender/verify_training_data.py` | Spot-checks renders against JSON ground truth labels |
| `ml/data/verified_renders/` | 11 verified renders with JSON ground truth |
| `ml/data/training_renders/` | 2,436 randomized renders (2×1,218 OLL×PLL combos, seeds 42+123) |

### ML Sticker Classifier (ml/src/)
| File | Purpose |
|------|---------|
| `ml/src/sticker_model.py` | `StickerClassifier`: ResNet-18 backbone → 27×6 logits |
| `ml/src/sticker_dataset.py` | `StickerDataset`: loads PNG+JSON pairs, train/val split |
| `ml/src/train_sticker.py` | Training loop: freeze/unfreeze schedule, checkpointing |
| `ml/src/evaluate_sticker.py` | Evaluation: per-sticker/per-image accuracy, confusion matrix |
| `ml/checkpoints/sticker_classifier.pt` | Trained model (98.4% per-sticker, 70.2% per-image) |

### Test Images
| Path | Description |
|------|-------------|
| `cube-photo-solve/test_images/IMG_1051.jpg` | Real photo of cube |
| `cube-photo-solve/test_images/IMG_1052.jpg` | Real photo of cube |
| `cube-photo-solve/test_images/IMG_1053.jpg` | Real photo of cube |
| `ml/data/test_configs/images/` | 21 Blender renders (various angles/lightboxes) |

### Environment
- Blender 5.0.1 at `/opt/homebrew/bin/blender`
- Python 3.12
- macOS (Darwin)

---

## Current State
- Steps 1-11 complete, Step 7 skipped (replaced by ML)
- ML sticker classifier v2 trained on expanded dataset: **93.6% per-sticker, 50.2% per-image** on combined val set
  - Original LL stickered: **99.8% per-sticker** (no regression)
  - Stickerless (LL+F2L): **95.9% per-sticker**
  - F2L stickered: **90.4% per-sticker**
- Training data: **6,660 renders** across 3 directories (2,435 stickered LL + 2,225 stickerless + 2,000 F2L stickered)
- State reconstructor: **4956/4956** (100%) on all OLL×PLL×AUF combos
- Kociemba solutions verified on all 20 verified renders (apply solution → solved cube)
- Full pipeline: 97.1% of ML-perfect predictions produce correct full state
- Solver tree wired into pipeline: `PhaseDetector` → `CubeSolver` with OLL, PLL, COLL, ZBLL, OLLCP, ELL, F2L, ZBLS paths
- Pipeline returns algorithm-based solving paths alongside Kociemba (4956/4956 coverage)
- Multi-directory dataset loading: `StickerDataset` accepts single or list of dirs
- All steps complete

---

## Steps (work in order, verify each before proceeding)

### STEP 1: Verify Cube class move correctness
**File:** `cube-photo-solve/state_resolver.py` (class `Cube`)
**Test file:** `cube-photo-solve/tests/test_cube_moves.py`

The Cube class has faces U/D/F/B/L/R, each a 9-element list indexed:
```
0 1 2
3 4 5
6 7 8
```
Solved state: U=White, D=Yellow, F=Red, B=Orange, L=Green, R=Blue

**Verification (all must pass):**
- [ ] Each basic move (R, L, U, D, F, B) applied 4x returns to solved
- [ ] Each move followed by its prime returns to solved (R then R' = identity)
- [ ] X2 equals X applied twice
- [ ] R move: U[2,5,8] get F colors, F[2,5,8] get D colors, D[2,5,8] get B[6,3,0] colors, B[0,3,6] get U[2,5,8] colors
- [ ] U move cycle: F top row <- R top row <- B top row <- L top row <- F top row
- [ ] F move: U[6,7,8] <- L[8,5,2], R[0,3,6] <- U[6,7,8], D[2,1,0] <- R[0,3,6], L[2,5,8] <- D[0,1,2]
- [ ] Face rotation CW: [0,1,2,3,4,5,6,7,8] -> [6,3,0,7,4,1,8,5,2]
- [ ] R does not affect L face; U does not affect D face; F does not affect B face
- [ ] M move follows L-layer direction (U->F->D->B cycle on middle column)
- [ ] r (wide) equals R + M'
- [ ] Sune (R U R' U R U2 R') applied 6x returns to solved
- [ ] Sexy move (R U R' U') applied 6x returns to solved
- [ ] T-Perm applied 2x returns to solved
- [ ] y rotation = U + E' + D' (must include middle layer, not just U + D')
- [ ] x rotation = R + M' + L'
- [ ] y and x applied 4x each return to solved

**If any test fails:** Fix the move implementation in state_resolver.py BEFORE proceeding. Everything downstream depends on correct moves.

---

### STEP 2: Verify state resolver lookup table
**File:** `cube-photo-solve/state_resolver.py` (class `StateResolver`)
**Test file:** `cube-photo-solve/tests/test_state_resolver.py` (create or extend)

The StateResolver builds a lookup table: apply every OLL alg, then every PLL alg, store the resulting visible 15 stickers as a key mapping to the case name.

**Verification (all must pass):**
- [ ] Solved cube visible stickers = [W]*9 + [R]*3 + [B]*3
- [ ] Solved cube matches "OLL Skip + Solved" in lookup table
- [ ] Apply OLL 45 (F R U R' U' F') to solved cube -> get visible stickers -> lookup returns OLL 45
- [ ] Apply T-Perm to solved cube -> get visible stickers -> lookup returns T-Perm
- [ ] Apply OLL 27 then T-Perm -> lookup returns "OLL 27 + T-Perm"
- [ ] For at least 5 different OLL+PLL combos: forward-apply, extract stickers, lookup matches
- [ ] Lookup table size is reasonable (thousands of entries, not millions or dozens)
- [ ] Every entry in the lookup table has valid fields: oll_case, pll_case, combined_name, oll_algorithm, pll_algorithm

**Key question:** The resolver applies algorithms to a SOLVED cube to generate the lookup. But OLL/PLL algorithms are meant to SOLVE the last layer, not scramble it. So applying OLL 45 to a solved cube gives you the INVERSE of the OLL 45 state. The resolver needs to apply the INVERSE (i.e., the scramble that OLL 45 would fix). Verify this logic is correct or fix it.

---

### STEP 3: Build simple Blender renders with known cube states
**Blender:** `/opt/homebrew/bin/blender`
**Output dir:** `ml/data/verified_renders/`
**Script:** `ml/blender/render_known_states.py` (create this)

Create a Blender Python script that:
1. Creates a cube mesh where each of the 54 sticker positions is a separate face with its own material
2. Colors each sticker according to the Cube class state for a given scramble
3. Positions camera at standard corner view (Top, Front, Right visible)
4. Uses simple flat lighting (uniform, no shadows, no effects) -- CORRECTNESS ONLY
5. Renders at 480x480 resolution
6. Saves image + JSON ground truth label

**Ground truth JSON format:**
```json
{
  "image": "solved.png",
  "oll_case": "OLL Skip",
  "pll_case": "Solved",
  "visible_stickers": ["W","W","W","W","W","W","W","W","W","R","R","R","B","B","B"],
  "top_face": ["W","W","W","W","W","W","W","W","W"],
  "front_top_row": ["R","R","R"],
  "right_top_row": ["B","B","B"],
  "full_state": { "U": [...], "D": [...], "F": [...], "B": [...], "L": [...], "R": [...] }
}
```

**Renders to generate:**
1. Solved cube (sanity check -- all white on top, red front, blue right)
2. OLL 45 applied (F R U R' U' F') -- simple case
3. OLL 27 applied (R U R' U R U2 R') -- Sune
4. T-Perm applied
5. OLL 27 + T-Perm applied
6. H-Perm applied
7. OLL 33 + J-Perm(b) applied

**Verification (all must pass):**
- [ ] Each render visually shows the correct sticker colors (open and check)
- [ ] Sample pixel colors from each sticker region in the rendered image, confirm they match the expected face color (R=red, B=blue, W=white, etc.)
- [ ] The JSON label sticker list matches the Cube class output for that scramble
- [ ] The solved cube render has: all-white top, red front row, blue right row

---

### STEP 4: Run CV pipeline on known renders and score accuracy
**Test file:** `cube-photo-solve/tests/test_end_to_end.py` (create this)

For each verified render from Step 3:
1. Run `CubeVision.detect_stickers(image_path)` to get 15 detected colors
2. Compare against ground truth from the JSON label
3. Score: X/15 stickers correct

**Verification output (machine-readable):**
```
=== END TO END RESULTS ===
solved.png:           15/15 correct (PASS)
oll_45.png:           12/15 correct (FAIL - stickers 3,7,11 wrong)
oll_27.png:            9/15 correct (FAIL - hexagon misdetected)
t_perm.png:           15/15 correct (PASS)
oll27_tperm.png:      13/15 correct (FAIL - colors 2,8 wrong)
h_perm.png:           11/15 correct (FAIL - grid offset)
oll33_jperm.png:       0/15 correct (FAIL - hexagon not found)
=== AGGREGATE: 75/105 = 71.4% ===
```

**Also test the full pipeline (vision + resolver):**
- [ ] For images where all 15 stickers are correct, does the resolver return the right OLL/PLL case?
- [ ] For images with partial matches, what is the closest match distance?

**Categorize failures:**
- HEXAGON_FAIL: Could not detect cube outline
- YJUNCTION_FAIL: Y-junction in wrong location
- GRID_FAIL: Grid points not centered on stickers
- COLOR_FAIL: Grid points correct but colors misclassified
- RESOLVER_FAIL: Colors correct but no lookup match (indicates Step 2 bug)

---

### STEP 5: Fix failures and iterate
Based on Step 4 failure categories, fix the most impactful issue first.

Priority order:
1. HEXAGON_FAIL -- if the cube outline isnt found, nothing works
2. YJUNCTION_FAIL -- if faces arent partitioned right, grid is wrong
3. GRID_FAIL -- if sample points are off, colors will be wrong
4. COLOR_FAIL -- K-means params or HSV thresholds need tuning
5. RESOLVER_FAIL -- lookup table generation bug

After each fix:
- Re-run Step 4 test harness
- Record before/after accuracy
- Continue until aggregate accuracy exceeds 90%

---

---

### STEP 6: Generate randomized training data with varied camera/lighting
**Script:** `ml/blender/render_training_data.py` (create this)
**Output dir:** `ml/data/training_renders/`
**Verification:** `ml/blender/verify_training_data.py` (create this)

The fixed-camera renders from Step 3 prove the pipeline works. Now generate hundreds of renders with randomized parameters to stress-test the CV pipeline under realistic variation.

#### 6a: Create `render_training_data.py`

A Blender script that generates randomized renders. Reuses shared functions from `render_known_states.py` via `exec()` with a custom globals dict (set `__name__` to avoid re-running `main()`):

```python
render_globals = {"__name__": "render_known_states", "__builtins__": __builtins__}
exec(open(os.path.join(SCRIPT_DIR, "render_known_states.py")).read(), render_globals)
clear_scene = render_globals['clear_scene']
# ... pull other needed symbols
```

**Randomized parameters (from notebook `explore_cube_positioning-checkpoint.ipynb`):**

| Parameter | Range | Notes |
|-----------|-------|-------|
| Distance | 3.0 - 10.0 | Camera distance from cube |
| Azimuth | -75° to -15° | Constrained so U, F, R faces are all visible (standard view ≈ -45°) |
| Elevation | 15° - 65° | Camera height angle |
| Focal length | 24 - 70mm | Phone to webcam range |
| Look-at X offset | -1.5 to +1.5 | Shifts cube left/right in frame |
| Look-at Y offset | -0.5 to +0.5 | Minimal effect |
| Look-at Z offset | -1.0 to +1.0 | Shifts cube up/down in frame |

**Camera setup:** Use Blender `TRACK_TO` constraint pointing at an empty at the look-at point. This avoids gimbal lock from manual Euler angles.

**Rejection sampling:** ~75-85% of random configs put the cube outside the frame. Use a retry loop (max 100 attempts per render) with pinhole projection math to check all 8 cube corners are within frame bounds before rendering.

**OLL/PLL coverage:** Build the full cartesian product: 58 OLL states (57 + OLL Skip, excluding aliases Sune/Anti-Sune) × 21 PLL states = 1,218 combinations. Each combo gets one render with random camera/lighting. Support `--count N` for smaller test runs.

**5 lighting presets** (one chosen randomly per render):
1. **standard** — Dual sun (3.0 + 1.5) + ambient. Current baseline.
2. **warm_studio** — Warm area lights, orange-tinted ambient. Indoor table lighting.
3. **cool_daylight** — Blueish key sun + warm fill. Window light.
4. **high_contrast** — Single hard sun (5.0), no fill, dark ambient. Strong shadows.
5. **soft_diffuse** — World-only lighting (strength 2.0), no directional lights. Overcast.

Each preset also randomizes background gray value (0.1-0.5).

**Output per render:**
- PNG image (480×480, CYCLES 64 samples)
- JSON label (same format as verified_renders, plus `camera` and `lighting_preset` metadata)

**Manifest:** `manifest.json` summarizing: total renders, OLL/PLL coverage, parameter ranges, rejection rate, timing.

**CLI:**
```bash
# Full run (all 1,218 combos)
/opt/homebrew/bin/blender --background --python ml/blender/render_training_data.py -- --seed 42

# Quick test (50 renders)
/opt/homebrew/bin/blender --background --python ml/blender/render_training_data.py -- --count 50 --seed 42
```

#### 6b: Create `verify_training_data.py`

A standard Python script (not Blender) that spot-checks renders by running `CubeVision.detect_stickers()` on a random sample and comparing against JSON labels.

```bash
python3 ml/blender/verify_training_data.py --sample-size 50
```

**Verification (all must pass):**
- [ ] `render_training_data.py` runs without errors with `--count 5`
- [ ] 5 PNG + 5 JSON files appear in `ml/data/training_renders/`
- [ ] `manifest.json` has correct field structure
- [ ] JSON labels have all expected fields (same as verified_renders + camera + lighting_preset)
- [ ] `verify_training_data.py` runs on the 5 test renders
- [ ] Full run (`--count 0` or no flag) generates ~1,218 renders
- [ ] Spot-check 50 random renders: document sticker accuracy %

#### 6c: Run full generation and verify

1. Run `--count 5` test, inspect outputs
2. Run `--count 50`, run verification, fix issues
3. Run full generation (all 1,218 combos)
4. Run verification on 50-sample spot check
5. Document accuracy in manifest

---

### STEP 7: Improve CV pipeline accuracy on varied renders
**Test:** Run `verify_training_data.py` on the full training set

The CV pipeline was tuned for fixed-camera renders (99.4% at one angle). Varied camera angles and lighting will expose new failure modes:
- Different hexagon shapes at extreme angles
- Color classification failures under warm/cool/high-contrast lighting
- Y-junction detection failures when face proportions change

**Priority order (same as Step 5):**
1. HEXAGON_FAIL — adjust segmentation for varied backgrounds
2. YJUNCTION_FAIL — seam detection under different lighting
3. GRID_FAIL — warp orientation for non-standard camera angles
4. COLOR_FAIL — HSV thresholds need to handle lighting variation

After each fix:
- Re-run `verify_training_data.py --sample-size 100`
- Record before/after accuracy
- Continue until accuracy exceeds 85% on varied renders

---

### STEP 8: Build single ML model for 27-sticker classification
**Goal:** Replace the classical CV pipeline (CubeVision) with a single neural network that takes a cube image and outputs all 27 visible sticker colors (3 faces × 9 stickers each).

The CV pipeline only extracts 15 stickers (top 9 + front top row 3 + right top row 3). An ML model has no such limitation — it can learn all 27 visible sticker positions across the Top, Front, and Right faces.

The CV pipeline (hexagon → Y-junction → warp → HSV threshold) achieves 99.4% on fixed-camera renders but ~10% on varied angles. Rather than patching each CV stage, train a CNN that learns the mapping directly.

#### Architecture

**Input:** 224×224 RGB image (resized from 480×480 render)
**Output:** 27 sticker predictions, each one of 6 colors (W, Y, R, O, G, B)

Sticker order: `U[0-8]` then `F[0-8]` then `R[0-8]` (row-major per face, matching Cube class indexing).

Use a pretrained **ResNet-18** backbone (torchvision) with the final FC layer replaced:
```
ResNet-18 backbone (pretrained=True, frozen early layers)
  → AdaptiveAvgPool → 512-d feature vector
  → FC(512, 256) → ReLU → Dropout(0.3)
  → FC(256, 162) → reshape to (27, 6)
  → per-sticker softmax
```

**Loss:** Sum of CrossEntropyLoss across all 27 sticker positions.

**Why ResNet-18:** Small enough for CPU/MPS training (~11M params), pretrained features transfer well to color/shape recognition, well-documented.

#### Files to create

All under `ml/src/`:

| File | Purpose |
|------|---------|
| `sticker_model.py` | `StickerClassifier` class: ResNet-18 backbone + classification head |
| `sticker_dataset.py` | `StickerDataset` class: loads PNG + JSON pairs from training_renders/ |
| `train_sticker.py` | Training loop with train/val split, checkpointing, logging |
| `evaluate_sticker.py` | Evaluation: per-sticker accuracy, per-image accuracy, confusion matrix |

#### Dataset (`sticker_dataset.py`)

- Reads from `ml/data/training_renders/` (or any dir with PNG + matching JSON)
- Each sample: load PNG → resize to 224×224 → normalize with ImageNet stats
- Label: 27-element tensor of class indices (color_to_idx: W=0, Y=1, R=2, O=3, G=4, B=5)
- Parse from JSON: `full_state['U']` (9) + `full_state['F']` (9) + `full_state['R']` (9) = 27 stickers
- Train/val split: 80/20 by index, deterministic with seed
- Data augmentation (train only): ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.05), RandomHorizontalFlip is **NOT** used (sticker positions are spatial)

#### Training (`train_sticker.py`)

```bash
python3 ml/src/train_sticker.py --data-dir ml/data/training_renders/ --epochs 30 --device mps
```

**Training details:**
- Optimizer: AdamW, lr=1e-3, weight_decay=1e-4
- Scheduler: CosineAnnealingLR over total epochs
- Batch size: 32
- Device: auto-detect (MPS on macOS, CUDA if available, else CPU)
- Freeze ResNet layers 1-2 for first 5 epochs, then unfreeze all
- Save best checkpoint by val per-sticker accuracy to `ml/checkpoints/sticker_classifier.pt`
- Print per-epoch: train loss, val loss, val per-sticker accuracy, val per-image accuracy (all 27 correct)

**CLI flags:**
- `--data-dir PATH` — training_renders directory (default: `ml/data/training_renders/`)
- `--epochs N` — number of epochs (default: 30)
- `--batch-size N` — batch size (default: 32)
- `--lr FLOAT` — learning rate (default: 1e-3)
- `--device DEVICE` — cpu/mps/cuda (default: auto)
- `--checkpoint PATH` — save path (default: `ml/checkpoints/sticker_classifier.pt`)
- `--seed N` — random seed (default: 42)

#### Evaluation (`evaluate_sticker.py`)

```bash
python3 ml/src/evaluate_sticker.py --checkpoint ml/checkpoints/sticker_classifier.pt --data-dir ml/data/training_renders/
```

**Output:**
```
=== STICKER CLASSIFIER EVALUATION ===
Per-sticker accuracy: 1512/1620 = 93.3%
Per-image accuracy:   42/60 = 70.0%

Per-position accuracy:
  U0: 95.0%  U1: 96.7%  U2: 93.3%  U3: 95.0%  U4: 98.3%  U5: 93.3%  U6: 91.7%  U7: 95.0%  U8: 93.3%
  F0: 91.7%  F1: 90.0%  F2: 88.3%  F3: 93.3%  F4: 96.7%  F5: 90.0%  F6: 88.3%  F7: 91.7%  F8: 90.0%
  R0: 93.3%  R1: 95.0%  R2: 91.7%  R3: 90.0%  R4: 96.7%  R5: 93.3%  R6: 88.3%  R7: 90.0%  R8: 91.7%

Confusion matrix (all positions pooled):
         W    Y    R    O    G    B
  W    145    0    0    2    0    0
  Y      0  138    0    5    1    0
  ...
```

**CLI flags:**
- `--checkpoint PATH` — model checkpoint
- `--data-dir PATH` — test data directory
- `--device DEVICE` — cpu/mps/cuda

#### Training data generation

Before training, generate enough data. Use `render_training_data.py`:

```bash
# Generate 500 renders for initial training (takes ~10 min)
/opt/homebrew/bin/blender --background --python ml/blender/render_training_data.py -- --count 500 --seed 42

# If accuracy plateaus, generate more with different seed
/opt/homebrew/bin/blender --background --python ml/blender/render_training_data.py -- --count 500 --seed 123
```

Start with 500 renders. If validation accuracy plateaus below target, generate more.

#### Step-by-step execution order

1. Generate training data: `--count 500 --seed 42` (skip if renders already exist)
2. Create `sticker_model.py` with `StickerClassifier`
3. Create `sticker_dataset.py` with `StickerDataset`
4. Create `train_sticker.py` — verify it runs for 1 epoch without errors
5. Train full model: 30 epochs, save best checkpoint
6. Create `evaluate_sticker.py` — run evaluation on val set
7. If val per-sticker accuracy < 90%, diagnose and fix (more data, tune hyperparams, adjust augmentation)
8. Document final accuracy in evaluation output

#### Verification (all must pass)

- [ ] `sticker_model.py`: `StickerClassifier` forward pass works on dummy input `(1, 3, 224, 224)` → output shape `(1, 27, 6)`
- [ ] `sticker_dataset.py`: loads training_renders, returns correct tensor shapes
- [ ] `train_sticker.py`: completes 1 epoch without errors on MPS/CPU
- [ ] `train_sticker.py`: completes full training, saves checkpoint
- [ ] `evaluate_sticker.py`: loads checkpoint, reports per-sticker and per-image accuracy
- [ ] Val per-sticker accuracy > 90%
- [ ] Val per-image accuracy > 70%

---

### STEP 9: Derive full 54-sticker state and wire end-to-end pipeline
**Goal:** Take the ML model's 27 sticker predictions, reconstruct the full 54-sticker cube state, and produce a solution.

#### 9a: Create `state_reconstructor.py` (in `cube-photo-solve/`)

A module that takes 27 predicted sticker colors (U[0-8] + F[0-8] + R[0-8]) and reconstructs all 54 stickers.

**Logic:**

1. **Known stickers (27 visible):** Directly from ML model output.

2. **Solved F2L stickers (21 known by definition):**
   - D face: all Yellow (9 stickers)
   - F[3-8]: all Red (6 stickers) — middle and bottom rows of front
   - R[3-8]: all Blue (6 stickers) — middle and bottom rows of right

   Note: F[3-8] and R[3-8] are in the visible 27 and should always be their solved colors. Use these as a **sanity check** — if they aren't R/B respectively, flag a prediction error.

3. **Derivable stickers (6 remaining):** B[0-2] and L[0-2] (back and left top rows).

   **Corners (use piece identification):**
   - UFL corner: visible U[6] + F[0] → identify piece → L[0] is the third color
   - UBR corner: visible U[2] + R[0] → identify piece → B[0] is the third color
   - UBL corner: U[0] visible, other 3 corners identified → UBL is remaining piece, U[0] determines twist → B[2] and L[2] derived

   **Edges (use elimination + parity):**
   - UF edge: visible U[7] + F[1] → identified
   - UR edge: visible U[5] + R[1] → identified
   - Remaining 2 edges (WO, WG, WR, WB minus the two identified) go to UB and UL
   - If edge is flipped (U sticker ≠ W), the U sticker directly identifies it → derive B[1] or L[1]
   - If both UB and UL are oriented (both White on top), use **parity constraint** (edge permutation parity must match corner permutation parity) to resolve which is where → derive B[1] and L[1]

4. **Remaining hidden stickers (L[3-8] and B[3-8]):** All solved.
   - L[3-8]: all Green (6 stickers)
   - B[3-8]: all Orange (6 stickers)

**Output:** Complete `Cube` object with all 54 stickers, or a Kociemba-format string.

**Sanity checks:**
- Each color appears exactly 9 times across all 54 stickers
- Each piece has a valid color combination (exists in the physical cube)
- F2L stickers match solved state

#### 9b: Create `pipeline.py` (in `cube-photo-solve/`)

End-to-end CLI that wires everything together:

```bash
python3 cube-photo-solve/pipeline.py image.jpg
```

**Pipeline steps:**
1. Load image → resize to 224×224 → normalize
2. Run `StickerClassifier` inference → 27 sticker predictions
3. Run `StateReconstructor` → full 54-sticker state
4. Convert to Kociemba format string
5. Run `kociemba.solve()` → solution moves
6. Also run `StateResolver.match_state()` → OLL/PLL case identification

**Output:**
```
=== CUBE ANALYSIS ===
Visible stickers (27): W W G R W B ...
Full state (54):       W W G R W B ... Y Y Y Y Y Y Y Y Y ...
OLL case: OLL 27 (Sune)
PLL case: T-Perm
Solution: R U R' U R U2 R' (OLL) → R U R' F' R U R' U' R' F R2 U' R' (PLL)
Kociemba solution: R U R' U R U2 R' U R U R' F' R U R' U' R' F R2 U' R' (21 moves)
```

#### 9c: Test on Blender renders with known ground truth

Run the full pipeline on verified renders and training renders:
- Compare reconstructed 54-sticker state against JSON ground truth `full_state`
- Verify Kociemba solution is valid (apply solution to state, check if solved)
- Score: % of images where full state is correctly reconstructed

#### Verification (all must pass)

- [ ] `state_reconstructor.py`: Given ground-truth 27 stickers, reconstructs correct 54-sticker state for all verified renders
- [ ] `state_reconstructor.py`: Sanity checks pass (9 of each color, valid pieces)
- [ ] `state_reconstructor.py`: Parity resolution works for PLL-only cases (all White top, edges permuted)
- [ ] `pipeline.py`: Runs end-to-end on a Blender render, outputs OLL/PLL case + solution
- [ ] `pipeline.py`: Kociemba solution is valid (applying it to the state produces solved cube)
- [ ] Full pipeline accuracy on val set: >95% of correctly-predicted images produce correct full state

---

### STEP 10: Wire pipeline through the solver tree
**Goal:** Replace the raw Kociemba-only output with the full solver tree (`PhaseDetector` → `CubeSolver`) so the pipeline returns algorithm-based solving paths (OLL → PLL, COLL → PLL, ZBLL one-look, etc.) alongside the Kociemba solution.

#### Existing solver infrastructure (already committed)

| File | What it does |
|------|-------------|
| `phase_detector.py` | `PhaseDetector` — classifies cube state: solved / pll / oll / oll_edges_oriented / f2l_last_pair / f2l_partial |
| `solver.py` | `CubeSolver` — finds multiple solving paths ranked by move count. Strategies: direct lookup (PLL, ZBLL), two-step chains (OLL→PLL, COLL→PLL, OLLCP→PLL), combined OLL×PLL table, F2L→LL chains, ZBLS→LL chains |
| `state_resolver.py` | `ExpandedStateResolver` — lookup tables for OLL, PLL, COLL, ZBLL, OLLCP, F2L, combined OLL×PLL |

The solver currently works on **15 visible stickers** (`solve()`) or a **full Cube object** (`solve_from_cube()`). The pipeline has 27 stickers → full 54-sticker state, so we can use `solve_from_cube()`.

#### 10a: Update `pipeline.py` to use `CubeSolver`

Modify `run_pipeline()` to:
1. Reconstruct full 54-sticker state (existing)
2. Convert to `Cube` object via `StateReconstructor.to_cube()`
3. Run `PhaseDetector.detect_phase_full(cube)` → get phase
4. Run `CubeSolver.solve_from_cube(cube)` → get ranked solving paths
5. Also run `kociemba.solve()` as fallback/comparison
6. Return both: algorithm-based paths AND Kociemba solution

**Updated output format:**
```
=== CUBE ANALYSIS ===
Visible stickers (27): R W O W W W B W W ...
Full state (54):       R W O W W W B W W Y Y Y ...
Phase: OLL

--- Algorithm Solutions (ranked by move count) ---
1. OLL 27 → T-Perm (24 moves)
   Step 1: OLL 27 — R U2 R' U' R U' R' (7 moves)
   Step 2: T-Perm — F R U' R' U' R U R' F' R U R' U' R' F R F' (17 moves)

2. OLL 27 → PLL Skip (7 moves)
   Step 1: OLL 27 — R U2 R' U' R U' R' (7 moves)

--- Kociemba Solution ---
L' U' L U' L' U2 L' U L2 U' F2 D R2 U' R2 F2 D' (17 moves)
```

#### 10b: Handle solver initialization performance

`CubeSolver` initializes `ExpandedStateResolver` which builds multiple large lookup tables. This is expensive (~10-30 seconds). Options:
- Lazy-initialize the solver (like the existing `_get_resolver()` pattern)
- Cache the solver alongside the existing `_resolver_cache`
- For ground-truth testing mode, make solver optional (skip if `--no-solver` flag)

#### 10c: Test solver tree integration

For each verified render:
1. Run pipeline with solver tree
2. Verify that the detected phase is correct (OLL for OLL cases, PLL for PLL cases, etc.)
3. Verify that at least one algorithm path actually solves the cube (apply all steps → solved)
4. Verify Kociemba solution still works as fallback

**Also test on the full OLL×PLL×AUF space:**
- For each of the 4956 combinations, reconstruct → detect phase → solve
- Verify that solver returns at least one valid path for every case
- Compare solver path move counts against Kociemba move counts

#### Verification (all must pass)

- [ ] `pipeline.py`: Returns algorithm-based solving paths alongside Kociemba solution
- [ ] Phase detection correct for all verified renders (OLL cases → "oll", PLL cases → "pll", etc.)
- [ ] At least one algorithm path verifies (apply steps to cube → solved) for every verified render
- [ ] Solver returns valid paths for >99% of the 4956 OLL×PLL×AUF combinations
- [ ] Kociemba solution still works as fallback for all cases
- [ ] Pipeline output shows both algorithm names and move sequences
- [ ] Performance: solver initialization happens once and is cached

---

### STEP 11: Expand training data with F2L states and stickerless cube renders
**Goal:** The ML model was trained exclusively on OLL×PLL states rendered with a stickered cube model. Expand training data to include (a) F2L-incomplete states and (b) stickerless cube renders, so the model generalizes to real-world cubes and non-LL states.

#### Existing infrastructure

| File | What it does |
|------|-------------|
| `ml/blender/render_training_data.py` | Generates randomized stickered renders (camera, lighting, OLL×PLL states). Uses `render_known_states.py` via `exec()`. |
| `ml/blender/render_stickerless.py` | Stickerless cube renderer: 26 beveled cubies, ABS plastic materials, realistic colors. Only renders 6 hardcoded cases. `build_stickerless_cube(cube_state)` accepts a `Cube` object. |
| `ml/data/training_renders/` | ~2,436 stickered OLL×PLL renders (480×480, Cycles 64 samples) |
| `cube-photo-solve/algorithms.py` | `F2L_CASES` (41 cases), `OLL_CASES` (57), `PLL_CASES` (21) |
| `cube-photo-solve/state_resolver.py` | `Cube` class with `is_f2l_solved()`, `count_solved_pairs()`, `get_unsolved_slots()` |

#### 11a: Create `ml/blender/f2l_scrambler.py` — F2L state generator

Pure Python (no bpy), importable by any renderer. Generates F2L-incomplete states by applying inverse F2L algorithms to specific slots.

**Slot-to-rotation mapping** (F2L algorithms target the FR slot by default, so rotate target slot to FR first):
```python
SLOT_ROTATION = {
    'FR': '',      # Already the target slot
    'FL': "y'",    # Rotate FL to FR
    'BR': 'y',     # Rotate BR to FR
    'BL': 'y2',    # Rotate BL to FR
}
INV_ROTATION = {'': '', 'y': "y'", "y'": 'y', 'y2': 'y2'}
```

**`build_f2l_state(cube, slots, rng)`:**
1. For each slot in `slots`:
   - Pick a random F2L case from `F2L_CASES`
   - Apply `SLOT_ROTATION[slot]` to rotate target slot to FR
   - Apply the INVERSE of the F2L algorithm (scrambles the pair)
   - Apply `INV_ROTATION[slot]` to rotate back
2. Return scramble details: `[{slot, f2l_case, inverse_alg}, ...]`

**Verification (all must pass):**
- [ ] For each of the 41 F2L cases applied to FR slot: `cube.count_solved_pairs() == 3`
- [ ] For 2-slot scramble (FR+FL): `cube.count_solved_pairs() == 2`
- [ ] For 4-slot scramble: `cube.count_solved_pairs() == 0`
- [ ] F2L scramble + OLL + PLL on top: cube state is valid (54 stickers, 9 of each color)
- [ ] All 4 slots produce valid scrambles independently

#### 11b: Create `ml/blender/render_stickerless_training.py` — Stickerless training data

Mirrors `render_training_data.py` pattern but uses stickerless cube model from `render_stickerless.py`.

Import stickerless functions via `exec()` (same pattern as `render_training_data.py` uses with `render_known_states.py`):
```python
stickerless_globals = {"__name__": "render_stickerless", "__builtins__": __builtins__}
exec(open(os.path.join(SCRIPT_DIR, "render_stickerless.py")).read(), stickerless_globals)
build_stickerless_cube = stickerless_globals['build_stickerless_cube']
clear_scene = stickerless_globals['clear_scene']
# etc.
```

**Camera parameters (scaled for stickerless cube, CUBE_HALF≈0.92 vs stickered 1.5):**

| Parameter | Stickerless Range | Notes |
|-----------|-------------------|-------|
| Distance | 2.0 – 6.5 | Scaled from stickered 3.0–10.0 |
| Azimuth | 15° to 75° | Positive convention (matches stickerless camera) |
| Elevation | 15° – 65° | Same as stickered |
| Focal length | 24 – 70mm | Same as stickered |
| Look-at offsets | Scaled by 0.61 | (0.92/1.5 ratio) |

**Camera position** (stickerless uses positive azimuth with negated Y):
```python
cam_x = distance * cos(elevation) * cos(azimuth)
cam_y = -distance * cos(elevation) * sin(azimuth)
cam_z = distance * sin(elevation)
```

**Modes** via `--mode` flag:
- `ll`: Full OLL×PLL coverage (1,218 combos)
- `f2l`: F2L-incomplete states via `f2l_scrambler.py`. Distribution: 40% 1-pair, 30% 2-pair, 20% 3-pair, 10% 4-pair. Optionally apply OLL+PLL on top.
- `mixed`: 60% ll, 40% f2l

**Render settings:** 480×480, 96 samples (Cycles + denoise), GPU/Metal. Reset `_material_cache = {}` between renders.

**5 lighting presets** (reuse from `render_training_data.py`): standard, warm_studio, cool_daylight, high_contrast, soft_diffuse.

**Rejection sampling:** Same pinhole projection math as stickered, but use `CUBE_HALF = 0.92` for cube corner bounds.

**CLI:**
```bash
# Quick test (5 renders)
/opt/homebrew/bin/blender --background --python ml/blender/render_stickerless_training.py -- --mode mixed --count 5 --seed 77

# Full LL coverage
/opt/homebrew/bin/blender --background --python ml/blender/render_stickerless_training.py -- --mode ll --seed 77

# F2L batch
/opt/homebrew/bin/blender --background --python ml/blender/render_stickerless_training.py -- --mode f2l --count 1000 --seed 78
```

**Output:** `ml/data/stickerless_renders/` with PNG + JSON pairs + `manifest.json`

**Label format:**
```json
{
  "image": "0042_oll_27_t_perm.png",
  "cube_type": "stickerless",
  "solve_phase": "ll",
  "oll_case": "OLL 27",
  "pll_case": "T-Perm",
  "full_state": {"U": [...], "D": [...], "F": [...], "B": [...], "L": [...], "R": [...]},
  "camera": {"distance": ..., "azimuth_rad": ..., "elevation_rad": ..., "focal_length": ...},
  "lighting_preset": "warm_studio"
}
```

For F2L states, add: `"solve_phase": "f2l"`, `"f2l_pairs_solved": N`, `"f2l_unsolved_slots": [...]`

**Verification (all must pass):**
- [ ] `--mode ll --count 5` produces 5 PNG + 5 JSON files in output dir
- [ ] Rendered PNGs visually show beveled stickerless cubies (not flat stickers)
- [ ] U, F, R faces visible in all renders (camera angles correct)
- [ ] JSON labels have `cube_type == "stickerless"` and valid `full_state`
- [ ] `--mode f2l --count 5` produces F2L-incomplete states with correct metadata
- [ ] `manifest.json` has correct counts and coverage stats

#### 11c: Create `ml/blender/render_f2l_stickered.py` — Stickered F2L renders

Same architecture as `render_training_data.py` but generates F2L-incomplete states using `f2l_scrambler.py`.

- Distribution: 40% 1-pair unsolved, 30% 2-pair, 20% 3-pair, 10% 4-pair
- Optionally applies random OLL+PLL on top
- Same camera/lighting randomization as `render_training_data.py`
- Output: `ml/data/f2l_stickered_renders/`

**CLI:**
```bash
/opt/homebrew/bin/blender --background --python ml/blender/render_f2l_stickered.py -- --count 5 --seed 99
```

**Verification (all must pass):**
- [ ] `--count 5` produces 5 PNG + 5 JSON pairs
- [ ] JSON labels: `f2l_pairs_solved + len(f2l_unsolved_slots) == 4`
- [ ] `full_state` has non-solved colors in F[3-8] and/or R[3-8] (F2L broken)
- [ ] Visual inspection: bottom/middle rows of F/R faces have mixed colors

#### 11d: Update `ml/src/sticker_dataset.py` — Multi-directory support

Update `StickerDataset.__init__` to accept `data_dir` as `str` or `list[str]`:

```python
def __init__(self, data_dir, split='train', seed=42, val_ratio=0.2, augment=True):
    if isinstance(data_dir, str):
        data_dirs = [data_dir]
    else:
        data_dirs = list(data_dir)

    all_samples = []
    for d in data_dirs:
        jsons = sorted(f for f in os.listdir(d) if f.endswith('.json') and f != 'manifest.json')
        for j in jsons:
            all_samples.append((d, j))  # (directory, filename) tuples
```

`__getitem__` unpacks `(d, json_file)` to construct correct paths. Backward compatible — single string still works.

**Verification (all must pass):**
- [ ] `StickerDataset('ml/data/training_renders/')` still works (backward compatible)
- [ ] `StickerDataset(['ml/data/training_renders/', 'ml/data/stickerless_renders/'])` loads from both dirs
- [ ] `img.shape == (3, 224, 224)` and `label.shape == (27,)` for all samples
- [ ] Train/val split is deterministic across multi-dir datasets

#### 11e: Update `ml/src/train_sticker.py` — Comma-separated data dirs

Change `--data-dir` to accept comma-separated paths:
```bash
python3 ml/src/train_sticker.py \
  --data-dir "ml/data/training_renders/,ml/data/f2l_stickered_renders/,ml/data/stickerless_renders/" \
  --epochs 30 --device mps
```

#### 11f: Generate training data and retrain

**Step-by-step execution order:**

1. Test `f2l_scrambler.py` standalone — verify all 41 cases × 4 slots
2. Test `render_stickerless_training.py` with `--mode ll --count 5`
3. Test `render_f2l_stickered.py` with `--count 5`
4. Visually inspect test renders (open PNGs)
5. Generate full stickerless LL batch: `--mode ll --seed 77` (~1,218 renders)
6. Generate stickerless F2L batch: `--mode f2l --count 1000 --seed 78`
7. Generate stickered F2L batch: `--count 2000 --seed 99`
8. Test multi-dir dataset loading
9. Retrain model on combined dataset (30 epochs)
10. Evaluate: check per-sticker accuracy on each subset

**Target data composition:**

| Dataset | Cube Type | States | Count |
|---------|-----------|--------|-------|
| Existing `training_renders/` | Stickered | LL only | ~2,436 |
| New `f2l_stickered_renders/` | Stickered | F2L + LL | ~2,000 |
| New `stickerless_renders/` | Stickerless | LL + F2L | ~2,218 |
| **Total** | | | **~6,654** |

#### Verification (all must pass)

- [ ] `f2l_scrambler.py`: All 41 F2L cases × 4 slots produce valid scrambles
- [ ] `render_stickerless_training.py`: Produces stickerless renders with correct labels
- [ ] `render_f2l_stickered.py`: Produces F2L-incomplete stickered renders
- [ ] `StickerDataset` loads from multiple directories (backward compatible)
- [ ] Full training data generated: ~6,654 renders across 3 directories
- [ ] Retrained model: per-sticker accuracy >90% on combined val set
- [ ] No regression: per-sticker accuracy on original LL stickered val >95%
- [ ] Stickerless val subset: per-sticker accuracy >85%
- [ ] F2L val subset: per-sticker accuracy >85%

---

## Completion

When ALL of these are true:
- Step 1: All Cube class move tests pass (64/64) ✅
- Step 2: All state resolver verification tests pass ✅
- Step 3: 20 verified Blender renders with JSON ground truth ✅
- Step 4: Test harness runs, 99.4% accuracy on fixed-camera renders ✅
- Step 5: Aggregate sticker accuracy > 90% on verified renders ✅
- Step 6: Training data generator produces renders with varied camera/lighting ✅
- Step 7: CV pipeline accuracy > 85% on varied training renders (SKIPPED — replaced by ML approach) ✅
- Step 8: ML sticker classifier achieves >90% per-sticker accuracy on val set ✅
- Step 9: Full pipeline (photo → 27 stickers → 54 state → Kociemba solver) works end-to-end ✅
- Step 10: Pipeline wired through solver tree (phase detection + algorithm-based solving paths) ✅
- Step 11: Training data expanded with F2L states + stickerless renders, model retrained >90% accuracy

Output: `<promise>EXPANDED TRAINING DATA WITH STICKERLESS AND F2L</promise>`

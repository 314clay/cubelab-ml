# CubeLab: End-to-End Rubik's Cube Photo Analysis Pipeline

## What To Do Each Iteration
You are iterating on the Rubik's Cube photo analysis pipeline. Each iteration, read this prompt, check what was done previously (git log, existing files, test results), and push the next piece forward.

## Ultimate Goal
Given a photo of a Rubik's Cube showing 3 faces (Top, Front, Right), identify the exact OLL/PLL case and output the solution algorithm.

Pipeline: **Photo -> 15 sticker colors -> OLL/PLL case name + algorithm**

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

### Blender Rendering (ml/)
| File | Purpose |
|------|---------|
| `ml/blender/__pycache__/lightboxes.cpython-311.pyc` | Compiled lightbox presets (source deleted). Functions: lightbox_hdri, lightbox_soft_pastel, lightbox_dark_studio, lightbox_textured, lightbox_high_contrast, setup_camera, setup_render_settings |
| `ml/data/test_configs/labels.csv` | 21 labeled renders with 8 corner keypoints (x,y,visibility) |
| `ml/data/test_configs/images/` | Rendered cube images (000000.jpg - 000021.jpg) |
| `ml/src/train.py` | UNetMini training script for corner keypoint detection |

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
- The reverse pipeline (photo -> state -> algorithm) scores **0/11** on real test photos
- Closest matches are 3-6 stickers wrong
- Multiple different photos produce identical output (grid positioning bug)
- No ground truth exists for any test image (we dont know the actual cube states)

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
| Azimuth | 0 - 2π | Full rotation around cube |
| Elevation | 10° - 75° | Camera height angle |
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

### STEP 8: Build single ML model for 15-sticker classification
**Goal:** Replace the classical CV pipeline (CubeVision) with a single neural network that takes a cube image and outputs all 15 visible sticker colors.

The CV pipeline (hexagon → Y-junction → warp → HSV threshold) achieves 99.4% on fixed-camera renders but ~10% on varied angles. Rather than patching each CV stage, train a CNN that learns the mapping directly.

#### Architecture

**Input:** 224×224 RGB image (resized from 480×480 render)
**Output:** 15 sticker predictions, each one of 6 colors (W, Y, R, O, G, B)

Use a pretrained **ResNet-18** backbone (torchvision) with the final FC layer replaced:
```
ResNet-18 backbone (pretrained=True, frozen early layers)
  → AdaptiveAvgPool → 512-d feature vector
  → FC(512, 256) → ReLU → Dropout(0.3)
  → FC(256, 90) → reshape to (15, 6)
  → per-sticker softmax
```

**Loss:** Sum of CrossEntropyLoss across all 15 sticker positions.

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
- Label: 15-element tensor of class indices (color_to_idx: W=0, Y=1, R=2, O=3, G=4, B=5)
- Parse `visible_stickers` from the JSON label
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
- Print per-epoch: train loss, val loss, val per-sticker accuracy, val per-image accuracy (all 15 correct)

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
Per-sticker accuracy: 847/900 = 94.1%
Per-image accuracy:   48/60 = 80.0%

Per-position accuracy:
  U0: 95.0%  U1: 96.7%  U2: 93.3%  ...
  F0: 91.7%  F1: 90.0%  F2: 88.3%
  R0: 93.3%  R1: 95.0%  R2: 91.7%

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

- [ ] `sticker_model.py`: `StickerClassifier` forward pass works on dummy input `(1, 3, 224, 224)` → output shape `(1, 15, 6)`
- [ ] `sticker_dataset.py`: loads training_renders, returns correct tensor shapes
- [ ] `train_sticker.py`: completes 1 epoch without errors on MPS/CPU
- [ ] `train_sticker.py`: completes full training, saves checkpoint
- [ ] `evaluate_sticker.py`: loads checkpoint, reports per-sticker and per-image accuracy
- [ ] Val per-sticker accuracy > 90%
- [ ] Val per-image accuracy > 70%

---

## Completion

When ALL of these are true:
- Step 1: All Cube class move tests pass (42/42) ✅
- Step 2: All state resolver verification tests pass (15/15) ✅
- Step 3: 11 verified Blender renders with JSON ground truth, user-confirmed ✅
- Step 4: Test harness runs, 99.4% accuracy on fixed-camera renders ✅
- Step 5: Aggregate sticker accuracy > 90% on verified renders ✅
- Step 6: Training data generator produces renders with varied camera/lighting ✅
- Step 7: CV pipeline accuracy > 85% on varied training renders (SKIPPED — replaced by ML approach)
- Step 8: ML sticker classifier achieves >90% per-sticker accuracy on val set

Output: `<promise>STICKER CLASSIFIER TRAINED</promise>`

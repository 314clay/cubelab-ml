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

## Completion

When ALL of these are true:
- Step 1: All Cube class move tests pass
- Step 2: All state resolver verification tests pass
- Step 3: At least 5 Blender renders exist with verified JSON ground truth
- Step 4: Test harness runs and reports accuracy
- Step 5: Aggregate sticker accuracy > 90% on verified renders

Output: `<promise>PIPELINE VERIFIED</promise>`

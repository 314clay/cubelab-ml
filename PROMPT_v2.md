# CubeLab v2: Multi-Path Cube Solver

## What To Do Each Iteration
You are building a multi-path Rubik's Cube solver. Each iteration, read this prompt, check what was done previously (`git log`, existing files, test results), and push the next incomplete step forward. Steps must be done in order. If a step's verification criteria are already met, move to the next.

## Parallelism
**Use teams and parallel sub-agents aggressively.** Many steps have independent sub-tasks that can run concurrently. For example:
- Steps 1 and 2 (S/E slices and wide moves) can be worked in parallel by separate agents
- Step 3 (fetching algorithms) and Step 4 (validation) can overlap — start validating sets as they're fetched
- Step 6 (building lookup tables) can parallelize table generation per algorithm set (OLL, PLL, COLL, ZBLL, OLLCP each built independently)
- Step 9 (Blender renders) and Step 10 (integration tests) can run render generation and test writing in parallel
- When writing tests, one agent can write tests while another implements the feature

Spawn teams, delegate to sub-agents, and run independent work streams concurrently whenever possible. Don't serialize work that doesn't need to be serial.

## Ultimate Goal
Given an image of a cube (or a cube state), the system should:
1. **Identify** which solving phase the cube is in
2. **Know** which algorithm sets apply to that phase
3. **Find** multiple paths to solved — different algorithm sequences that each solve the cube

Pipeline: **Image/State → Phase Detection → Algorithm Set Selection → Multi-Path Solve → Ranked Solutions**

## Project Root
`/Users/clayarnold/iCloud Drive (Archive)/Documents/GitHub/cubelab/cubelab/experimentation/`

## Key Existing Files

### CV Pipeline (cube-photo-solve/)
| File | Purpose |
|------|---------|
| `cube-photo-solve/state_resolver.py` | `Cube` class (move simulation) + `StateResolver` (OLL×PLL lookup) |
| `cube-photo-solve/algorithms.py` | 57 OLL + 21 PLL algorithms as move strings |
| `cube-photo-solve/cube_vision.py` | OpenCV sticker detection from photos (15 stickers) |
| `cube-photo-solve/cube_analyzer.py` | CLI wiring vision + resolver |
| `cube-photo-solve/tests/` | Move tests, resolver tests, e2e tests (99.4% accuracy) |

### Blender (ml/)
| File | Purpose |
|------|---------|
| `ml/blender/render_known_states.py` | Renders cubes with known states |
| `ml/data/verified_renders/` | 11 verified renders with JSON ground truth |

### Environment
- Python 3.12, venv at `cube-photo-solve/venv/`
- Activate: `source cube-photo-solve/venv/bin/activate`
- Tests: `cd cube-photo-solve && python -m pytest tests/ -v`
- Blender: `/opt/homebrew/bin/blender`

## Current Limitations
- Only recognizes OLL+PLL states (78 algorithms)
- Cannot identify solving phase — assumes F2L is already solved
- Returns one match, not multiple paths
- Cube class is missing slice moves S/E and several wide moves
- `y` and `z` rotations don't move the middle layer (broken)

---

## Steps

### STEP 1: Fix Cube class — add S, E slice moves
**Modify:** `cube-photo-solve/state_resolver.py`
**Modify:** `cube-photo-solve/tests/test_cube_moves.py`

The expanded algorithm sets (ZBLL, COLL, OLLCP) use S and E moves extensively. These are currently missing.

**S move** (Standing slice — follows F direction on middle layer):
- `U[3]→R[1]`, `U[4]→R[4]`, `U[5]→R[7]`
- `R[1]→D[5]`, `R[4]→D[4]`, `R[7]→D[3]`
- `D[5]→L[7]`, `D[4]→L[4]`, `D[3]→L[1]`
- `L[7]→U[3]`, `L[4]→U[4]`, `L[1]→U[5]`

**E move** (Equatorial slice — follows D direction on middle layer):
- `F[3,4,5]→R[3,4,5]→B[3,4,5]→L[3,4,5]→F[3,4,5]`

Wait — E follows D direction. D sends `F→L→B→R→F` (looking from below, CW). So:
- `F[3]→R[3]` is WRONG. D direction: front goes to RIGHT? No.
- D move cycle: `F[6,7,8]→R[6,7,8]` NO. Check carefully.
- Standard D: looking from bottom, CW. From top view, that's CCW. So D sends `F bottom→L bottom→B bottom→R bottom→F bottom`.
- E follows D: `F[3,4,5]→L[3,4,5]→B[3,4,5]→R[3,4,5]→F[3,4,5]`

**IMPORTANT**: Cross-reference with the existing D move implementation in `state_resolver.py` to get the cycle direction right. E must follow D's direction exactly.

Add to `_apply_single_move`:
```python
elif move == 'S': self._move_S()
elif move == 'E': self._move_E()
```

**Tests to add:**
- S×4 = identity, S+S' = identity
- E×4 = identity, E+E' = identity
- S specific: on solved cube, after S, `U[4]` should have what was at `L[4]` (Green) since L→U in the S cycle
- E specific: on solved cube, after E, `F[4]` should have what was at `R[4]` (Blue)? No — E follows D direction. If D sends F→L, then E sends F[4]→L[4]. So after E, L[4] has Red (from F). And F[4] gets R[4]'s color (Blue)? Only if R→F in the cycle. D: F→L→B→R→F. So R→F. After E, F[4] = what was at R[4] = Blue. Test that.

**Verification:**
- [ ] All existing tests still pass
- [ ] S×4 = identity
- [ ] E×4 = identity
- [ ] S and E specific permutation tests pass

---

### STEP 2: Fix Cube class — add/fix wide moves and rotations
**Modify:** `cube-photo-solve/state_resolver.py`
**Modify:** `cube-photo-solve/tests/test_cube_moves.py`

**Wide moves** = face + adjacent slice:

| Move | Definition | Status |
|------|-----------|--------|
| `r` | R + M' | Works |
| `l` | L + M | Missing |
| `u` | U + E' | Missing |
| `d` | D + E | Missing |
| `f` | F + S | Broken (only does F) |
| `b` | B + S' | Missing |

**Rotations** = two faces + middle slice:

| Move | Definition | Status |
|------|-----------|--------|
| `x` | R + M' + L' | Works |
| `y` | U + E' + D' | Broken (missing E') |
| `z` | F + S + B' | Broken (missing S) |

Implement all missing wide moves. Fix `f`, `y`, `z`.

**Tests to add:**
- Each wide move ×4 = identity
- `l` = L+M, `u` = U+E', `d` = D+E, `f` = F+S, `b` = B+S' (compare against applying the two moves separately)
- `y` moves middle layer: mark F[4]='X', apply y, verify it ends up at the correct position
- `z` moves middle layer similarly
- y×4 = identity, z×4 = identity (may already exist — verify they still pass)

**Verification:**
- [ ] All existing tests still pass (especially e2e — re-run `python -m pytest tests/test_end_to_end.py -v`)
- [ ] All wide moves ×4 = identity
- [ ] All rotations verified against their definitions
- [ ] If e2e accuracy drops after fixing y/z/f, investigate: the lookup table will now generate different entries for algorithms using those moves. Re-render ground truth if needed.

---

### STEP 3: Fetch comprehensive algorithm database
**Create:** `cube-photo-solve/fetch_algorithms.py`
**Create:** `cube-photo-solve/algorithm_db.json`
**Modify:** `cube-photo-solve/algorithms.py`

Download algorithm data from `spencerchubb/cubingapp` GitHub repo. The JSON files live at:
`https://raw.githubusercontent.com/spencerchubb/cubingapp/main/alg-codegen/algs/`

Files to fetch: `OLL.json`, `PLL.json`, `COLL.json`, `ZBLL.json`, `OLLCP.json`, `F2L.json`, `Winter-Variation.json`

If that URL doesn't work, clone the repo or find the actual path by fetching the repo's directory listing first.

**cubingapp JSON format:**
```json
{
  "puzzle": "3x3",
  "cases": {
    "CASE_NAME": {
      "subset": "CATEGORY",
      "algs": {
        "R U R' U'": {},
        "alternative alg": {"note": "..."}
      }
    }
  }
}
```

**fetch_algorithms.py** should:
1. Download each JSON file
2. For each case, take the FIRST algorithm from `algs`
3. Normalize notation: remove parentheses (grouping only), ensure space-separated
4. Write unified `algorithm_db.json`:

```json
{
  "metadata": {
    "source": "spencerchubb/cubingapp",
    "fetched_at": "ISO_TIMESTAMP",
    "total_algorithms": 1002
  },
  "algorithm_sets": {
    "OLL": {
      "phase": "orient_last_layer",
      "precondition": "F2L solved",
      "postcondition": "Last layer oriented (top face uniform color)",
      "cases": {
        "OLL 1": { "algorithm": "R U2 R2 F R F' U2 R' F R F'", "subset": "Dot" }
      }
    },
    "PLL": {
      "phase": "permute_last_layer",
      "precondition": "F2L + OLL solved",
      "postcondition": "Cube solved",
      "cases": {}
    },
    "COLL": {
      "phase": "corners_last_layer",
      "precondition": "F2L solved + LL edges oriented",
      "postcondition": "LL corners oriented + permuted (only EPLL remains)",
      "cases": {}
    },
    "ZBLL": {
      "phase": "last_layer_one_look",
      "precondition": "F2L solved + LL edges oriented",
      "postcondition": "Cube solved",
      "cases": {}
    },
    "OLLCP": {
      "phase": "orient_ll_permute_corners",
      "precondition": "F2L solved",
      "postcondition": "LL edges oriented + corners permuted",
      "cases": {}
    },
    "F2L": {
      "phase": "first_two_layers",
      "precondition": "Cross solved",
      "postcondition": "F2L solved",
      "cases": {}
    },
    "WV": {
      "phase": "last_slot_plus_orient",
      "precondition": "3 F2L pairs solved + last pair connected",
      "postcondition": "F2L + OLL solved",
      "cases": {}
    }
  }
}
```

**Update `algorithms.py`**: Load from `algorithm_db.json`. Keep existing `OLL_CASES`/`PLL_CASES` dict interfaces. Add `COLL_CASES`, `ZBLL_CASES`, `OLLCP_CASES`, `F2L_CASES`, `WV_CASES`. Add `get_all_algorithm_sets()` helper.

**Create:** `cube-photo-solve/tests/test_algorithms.py`
- OLL=57, PLL=21, COLL≈42, ZBLL≈472, F2L≈41 (allow some variance)
- Every algorithm string is parseable into valid move tokens
- Every move token is one the Cube class can execute
- OLL/PLL algorithms match or closely match the originals

**Verification:**
- [ ] `python fetch_algorithms.py` creates `algorithm_db.json`
- [ ] JSON has 7 algorithm sets
- [ ] `python -m pytest tests/test_algorithms.py -v` passes
- [ ] `python -c "from algorithms import ZBLL_CASES; print(len(ZBLL_CASES))"` prints ~472

---

### STEP 4: Validate all algorithms execute on Cube class
**Create:** `cube-photo-solve/tests/test_algorithm_execution.py`

Every algorithm must:
1. Execute without errors (no unknown moves)
2. Produce a valid cube state (9 of each color)

**IMPORTANT**: Change the `pass` in `_apply_single_move` for unknown moves to `raise ValueError(f"Unknown move: {move}")` so failures are explicit.

**Tests:**
- `test_every_algorithm_executes`: Apply each algorithm to solved cube, verify no exception and 9-of-each-color
- `test_oll_only_affects_last_layer`: Apply each OLL alg, verify D face unchanged and F/B/L/R bottom 6 stickers unchanged
- `test_pll_preserves_top_orientation`: Apply each PLL alg, verify all 9 U stickers are still White
- `test_sample_algorithms_have_finite_order`: For 20 sampled algorithms, verify applying N times returns to start (N < 1000)

If any algorithm uses an unsupported move, implement that move before proceeding.

**Verification:**
- [ ] `python -m pytest tests/test_algorithm_execution.py -v` — all pass
- [ ] Zero unsupported moves across all ~1000 algorithms

---

### STEP 5: Build PhaseDetector — identify solving phase from cube state
**Create:** `cube-photo-solve/phase_detector.py`
**Create:** `cube-photo-solve/tests/test_phase_detection.py`

This is the core of requirement #1: given a cube state, what phase of solving is it in?

```python
class PhaseDetector:
    """Given visible stickers or full cube state, detect solving phase."""

    def detect_phase(self, visible_stickers: list[str]) -> PhaseResult:
        """
        Args:
            visible_stickers: 15 colors [9 top + 3 front row + 3 right row]

        Returns:
            PhaseResult with:
              - phase: str (one of the phases below)
              - applicable_sets: list[str] (which algorithm sets can solve from here)
              - details: dict (what was detected)
        """
```

**Phases to detect** (from most solved to least):

| Phase | How to detect from 15 stickers | Applicable algorithm sets |
|-------|-------------------------------|--------------------------|
| `solved` | All 9 top same color, front row uniform, right row uniform, all 3 colors different | None — already solved |
| `pll` | Top 9 all same color, but front/right rows have mixed colors OR don't match expected | PLL, ZBLL (if edges were oriented) |
| `oll_edges_oriented` | Top edges (indices 1,3,5,7) match center, corners don't all match | COLL, ZBLL |
| `oll` | F2L solved (front/right rows uniform) but top face not all same color | OLL, OLLCP |
| `f2l_partial` | Front row or right row not uniform | F2L (limited — we only see top row of 2 faces) |
| `unknown` | Can't determine | Report closest matches |

**Detection logic:**
1. Top center = `stickers[4]`
2. Front row = `stickers[9:12]`, right row = `stickers[12:15]`
3. Check if front row is uniform (all same) and right row is uniform (all same) → F2L likely solved
4. If F2L solved: count top stickers matching center
   - 9/9 match → **pll** (or solved, check sides)
   - Edges (1,3,5,7) all match but not all corners → **oll_edges_oriented**
   - Otherwise → **oll**
5. If F2L not solved → **f2l_partial**

**PhaseResult should include applicable algorithm sets:**
```python
@dataclass
class PhaseResult:
    phase: str
    applicable_sets: list[str]  # e.g., ["OLL", "OLLCP"] or ["COLL", "ZBLL"]
    confidence: float
    details: dict
```

**Tests:**
- Solved cube → phase="solved", applicable_sets=[]
- Apply T-Perm → phase="pll", applicable_sets=["PLL"]
- Apply OLL 45 → phase="oll", applicable_sets=["OLL", "OLLCP"]
- Apply a COLL case → phase="oll_edges_oriented", applicable_sets=["COLL", "ZBLL"]
- Scramble F2L → phase="f2l_partial"

**Verification:**
- [ ] `python -m pytest tests/test_phase_detection.py -v` — all pass
- [ ] At least 5 different states correctly classified
- [ ] Applicable sets make sense for each phase

---

### STEP 6: Build expanded lookup tables for all algorithm sets
**Modify:** `cube-photo-solve/state_resolver.py`
**Create:** `cube-photo-solve/tests/test_expanded_resolver.py`

Create `ExpandedStateResolver` that builds lookup tables for multiple algorithm sets:

```python
class ExpandedStateResolver:
    def __init__(self, sets=None):
        """
        Args:
            sets: Algorithm set names to load. Default: ['OLL', 'PLL', 'COLL', 'ZBLL', 'OLLCP']
        """
        self.tables = {}  # {set_name: {sticker_key: match_info}}
        self.phase_detector = PhaseDetector()
        for set_name in (sets or ['OLL', 'PLL', 'COLL', 'ZBLL', 'OLLCP']):
            self.tables[set_name] = self._build_table_for_set(set_name)
```

**Table generation per set:**
- Each algorithm is applied to a solved cube (this produces the "scramble" that the algorithm solves)
- The resulting 15 visible stickers become the lookup key
- Generate across 24 orientations × 4 AUF rotations

**For OLL+PLL combinations**: Keep the existing combined table approach — apply OLL then PLL to get combined states.

**For COLL**: Precondition is "edges oriented." Apply each COLL case to solved cube. The result has oriented edges but scrambled corners — exactly the state COLL would solve.

**For ZBLL**: Same precondition as COLL. Apply each of ~472 ZBLL cases to solved cube.

**For OLLCP**: Same precondition as OLL. Apply each OLLCP case to solved cube.

Each table entry stores:
```python
{
    'set': 'COLL',
    'case': 'AS 1',
    'algorithm': 'R U R\' U R U2 R\'',
    'subset': 'Antisune',
    'rotation': 'y',
    'visible_stickers': [...]
}
```

**Tests:**
- Apply COLL "AS 1" → lookup in COLL table → found
- Apply ZBLL case → lookup in ZBLL table → found
- Original OLL+PLL lookups still work
- Table sizes reasonable (COLL: 1K-50K, ZBLL: 10K-500K)

**Verification:**
- [ ] `python -m pytest tests/test_expanded_resolver.py -v` — all pass
- [ ] COLL and ZBLL cases round-trip correctly
- [ ] OLL+PLL regression test passes

---

### STEP 7: Build multi-path solver
**Create:** `cube-photo-solve/solver.py`
**Create:** `cube-photo-solve/tests/test_solver.py`

This is the core of requirement #3: find **multiple paths** from a detected state to solved.

```python
class CubeSolver:
    """Find multiple algorithm paths from a cube state to solved."""

    def __init__(self):
        self.resolver = ExpandedStateResolver()
        self.phase_detector = PhaseDetector()

    def solve(self, visible_stickers: list[str], max_paths: int = 5) -> list[SolvePath]:
        """
        Returns multiple solving paths, ranked by move count.

        Each SolvePath is a sequence of algorithm applications that
        takes the cube from the detected state to solved.
        """
```

**SolvePath structure:**
```python
@dataclass
class SolveStep:
    algorithm_set: str      # e.g., "OLL"
    case_name: str          # e.g., "OLL 45"
    algorithm: str          # e.g., "F R U R' U' F'"
    move_count: int
    phase_before: str       # e.g., "oll"
    phase_after: str        # e.g., "pll"

@dataclass
class SolvePath:
    steps: list[SolveStep]
    total_moves: int
    description: str        # e.g., "OLL 45 → T-Perm"
```

**Multi-path logic:**

For a detected OLL state, multiple paths exist:
1. **Standard OLL → PLL**: Find OLL case, apply it (simulated), detect PLL state, find PLL case
2. **OLLCP → EPLL**: Find OLLCP case (orients + permutes corners), then only edge permutation remains
3. **If edges are oriented**: COLL → EPLL, or ZBLL (one-look solve)

Algorithm:
1. Detect phase with `PhaseDetector`
2. Get applicable algorithm sets for that phase
3. For each applicable set, find matching cases in the lookup table
4. For each match, simulate applying the algorithm to the cube state
5. Check the resulting state — is it solved? If not, recursively find the next step
6. Collect all paths, rank by total move count
7. Return top N paths

**Handling "close matches"**: If no exact match exists, use the existing `find_closest_matches()` with a threshold (e.g., ≤2 stickers different). Report confidence based on match distance.

**Example output for an OLL state:**
```
Path 1 (14 moves): OLL 45 (F R U R' U' F') → PLL Skip
Path 2 (25 moves): OLL 45 (F R U R' U' F') → T-Perm (R U R' U' R' F R2 U' R' U' R U R' F')
Path 3 (18 moves): OLLCP 45-3 (longer alg but skips PLL)
```

**Tests:**
- Solved cube → 0 paths (already solved)
- Apply T-Perm → finds path: [PLL T-Perm] (one step)
- Apply OLL 45 → finds multiple paths including OLL→PLL chain
- Apply OLL 45 + T-Perm → finds path: [OLL 45, T-Perm] (two steps)
- Apply COLL case → finds COLL path AND ZBLL path (if edges oriented)
- All returned paths actually solve the cube when applied (simulate and verify)

**Verification:**
- [ ] `python -m pytest tests/test_solver.py -v` — all pass
- [ ] T-Perm state returns at least 1 path
- [ ] OLL state returns at least 2 different paths
- [ ] All returned paths verified: simulating the algorithms on the state produces solved cube
- [ ] Paths are ranked by move count (shortest first)

---

### STEP 8: Update CLI with multi-path output
**Modify:** `cube-photo-solve/cube_analyzer.py`

Update the CLI to use the new `CubeSolver`:

```bash
# From image:
python cube_analyzer.py image.jpg

# From state string (new feature):
python cube_analyzer.py --state "W,W,W,R,W,B,W,W,W,R,R,R,B,B,B"
```

**Output format:**
```json
{
  "input": "image.jpg",
  "detected_stickers": ["W","W","W","R","W","B","W","W","W","R","R","R","B","B","B"],
  "phase": "oll",
  "paths": [
    {
      "rank": 1,
      "total_moves": 6,
      "description": "OLL 45 → PLL Skip",
      "steps": [
        {
          "set": "OLL",
          "case": "OLL 45",
          "algorithm": "F R U R' U' F'",
          "moves": 6
        }
      ]
    },
    {
      "rank": 2,
      "total_moves": 20,
      "description": "OLL 45 → T-Perm",
      "steps": [...]
    }
  ]
}
```

**CLI args to add:**
- `--state`: Accept comma-separated 15 sticker colors instead of an image
- `--max-paths`: Number of solving paths to return (default 5)
- `--sets`: Which algorithm sets to load (default all)

**Verification:**
- [ ] `python cube_analyzer.py --state "W,W,W,W,W,W,W,W,W,R,R,R,B,B,B"` returns "solved"
- [ ] `python cube_analyzer.py --state <T-Perm state>` returns PLL path
- [ ] Image input still works
- [ ] JSON output includes paths array

---

### STEP 9: Generate expanded test renders and verify end-to-end
**Modify:** `ml/blender/render_known_states.py`
**Modify:** `cube-photo-solve/tests/test_end_to_end.py`

Add Blender renders for the new algorithm sets:
- 3 COLL cases
- 3 ZBLL cases
- 2 OLLCP cases
- 1 edge-oriented-only state

Render: `/opt/homebrew/bin/blender --background --python ml/blender/render_known_states.py`

Update e2e tests to:
1. Detect stickers from each render
2. Run through CubeSolver
3. Verify at least one path is found
4. Verify the path actually solves the cube (simulate it)

**Verification:**
- [ ] New renders in `ml/data/verified_renders/`
- [ ] `python -m pytest tests/test_end_to_end.py -v` — sticker accuracy ≥ 95%
- [ ] Solver finds correct paths for COLL/ZBLL/OLLCP renders
- [ ] Every returned path, when simulated, produces a solved cube

---

### STEP 10: Integration test — full pipeline on all algorithm sets
**Create:** `cube-photo-solve/tests/test_full_pipeline.py`

Final integration: for a sample of algorithms from EVERY set, verify the complete pipeline:
1. Start from solved cube
2. Apply algorithm (creates the state the algorithm solves)
3. Extract visible stickers
4. Run CubeSolver
5. Verify solver finds a path that includes the original algorithm (or equivalent)

Test at least:
- 5 OLL cases
- 5 PLL cases
- 5 COLL cases
- 10 ZBLL cases
- 5 OLLCP cases

Also test combined states:
- OLL + PLL combination → solver returns 2-step path
- COLL + EPLL → solver finds both COLL path and equivalent OLL+PLL path

**Verification:**
- [ ] `python -m pytest tests/test_full_pipeline.py -v` — all pass
- [ ] For every tested state, at least one valid solving path is found
- [ ] Combined states produce multi-step paths
- [ ] Same state produces multiple different paths (multi-path working)

---

## Completion

When ALL of these are true:
- Steps 1-2: Cube class supports all standard moves (S, E, wide l/u/d/f/b, rotations x/y/z)
- Step 3: `algorithm_db.json` has 7 sets with ~1000+ algorithms
- Step 4: All algorithms execute correctly on Cube class
- Step 5: PhaseDetector classifies solving phase from 15 stickers
- Step 6: Expanded lookup tables for OLL, PLL, COLL, ZBLL, OLLCP
- Step 7: CubeSolver finds multiple paths to solved
- Step 8: CLI supports `--state` input and multi-path JSON output
- Step 9: Expanded test renders verify ≥95% accuracy
- Step 10: Full pipeline integration tests pass for all algorithm sets

Output: `<promise>ALGORITHMS EXPANDED</promise>`

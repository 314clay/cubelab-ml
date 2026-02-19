"""
Multi-slot F2L search engine: enumeration and random walk.

Generates scrambled cube states where exactly two F2L slots are unsolved
(cross solved, other two slots solved). Two search strategies:

1. Enumeration: Systematically apply every pair of F2L inverse algorithms
   with AUF variations to find all reachable 2-slot-unsolved states.

2. Random walk: Apply weighted random moves to a solved cube and check
   whether the result has exactly the target two slots unsolved.

Both strategies call an add_callback(cube, solution, source) provided
by the integrator, keeping this module free of scoring/canonicalization
concerns.
"""

import os
import sys
import random
import time

# ---------------------------------------------------------------------------
# Path setup — locate the cube-photo-solve and blender modules
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "cube-photo-solve"))
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "ml", "blender"))

from state_resolver import Cube
from algorithms import F2L_CASES, parse_algorithm
from f2l_scrambler import invert_alg, SLOT_ROTATION, INV_ROTATION

# ---------------------------------------------------------------------------
# Move lists and weights for random walk
# ---------------------------------------------------------------------------

# Only face turns — wide moves (r, r') rotate centers via M slice, which
# breaks color-based piece finding and cross checking.  Solutions containing
# wide moves can still be discovered as equivalent face-turn sequences.
SEARCH_MOVES = [
    'R', "R'", 'R2',
    'U', "U'", 'U2',
    'F', "F'", 'F2',
    'L', "L'", 'L2',
    'D', "D'", 'D2',
    'B', "B'",
]

MOVE_WEIGHTS = {
    'R': 10, "R'": 10, 'R2': 5,
    'U': 10, "U'": 10, 'U2': 5,
    'F': 6,  "F'": 6,  'F2': 3,
    'L': 6,  "L'": 6,  'L2': 3,
    'D': 2,  "D'": 2,  'D2': 1,
    'B': 1,  "B'": 1,
}

# Pre-compute cumulative weight list for random.choices
_WEIGHTS_LIST = [MOVE_WEIGHTS[m] for m in SEARCH_MOVES]

ALL_SLOTS = ('FR', 'FL', 'BR', 'BL')


# ---------------------------------------------------------------------------
# Target-state checker
# ---------------------------------------------------------------------------

def check_target_only(cube, target_slots):
    """Check that the cube has cross solved and exactly target_slots unsolved.

    Returns True when:
    - The D-layer cross is solved.
    - Each slot in target_slots is NOT solved.
    - Every other slot IS solved.
    """
    if not cube.is_cross_solved():
        return False

    for slot in ALL_SLOTS:
        solved = cube._is_pair_solved(slot)
        if slot in target_slots:
            # Target slot must be unsolved
            if solved:
                return False
        else:
            # Non-target slot must be solved
            if not solved:
                return False

    return True


# ---------------------------------------------------------------------------
# Enumeration search
# ---------------------------------------------------------------------------

def _get_f2l_list():
    """Return list of (name, algorithm) for all non-empty F2L cases."""
    return [(name, alg) for name, alg in F2L_CASES.items() if alg]


def _apply_slot_scramble(cube, slot, alg_str):
    """Scramble a single slot by applying the inverse of an F2L algorithm.

    Uses y-rotation bracketing so that algorithms written for FR
    can target any slot.
    """
    rot = SLOT_ROTATION[slot]
    inv_rot = INV_ROTATION[rot]
    inv = invert_alg(alg_str)

    if rot:
        cube.apply_algorithm(rot)
    cube.apply_algorithm(inv)
    if inv_rot:
        cube.apply_algorithm(inv_rot)


def _build_slot_solution(slot, alg_str):
    """Build the move sequence that solves a single slot.

    The solution is: rotate to FR, apply the F2L algorithm, rotate back.
    Returns the moves as a space-separated string.
    """
    rot = SLOT_ROTATION[slot]
    inv_rot = INV_ROTATION[rot]

    parts = []
    if rot:
        parts.append(rot)
    parts.append(alg_str)
    if inv_rot:
        parts.append(inv_rot)

    return ' '.join(parts)


def enumerate_f2l_pairs(slot_pair, add_callback):
    """Enumerate all 2-slot scrambles by combining F2L inverse algorithms.

    For every combination of (case_a x case_b x AUF), builds a cube
    with exactly slot_pair[0] and slot_pair[1] unsolved, then calls
    add_callback with the scrambled cube and a sequential solution.

    The scramble order is:
        1. Unsolve slot_a (the first slot in slot_pair)
        2. Apply AUF (U, U', U2, or nothing)
        3. Unsolve slot_b (the second slot)

    The sequential solution (to undo this) is:
        1. Solve slot_b (rotation-bracketed F2L alg)
        2. Undo the AUF
        3. Solve slot_a (rotation-bracketed F2L alg)

    Args:
        slot_pair: Tuple of two slot names, e.g. ('FR', 'FL').
        add_callback: Callable(cube, solution_str, source_str).
    """
    f2l_list = _get_f2l_list()
    slot_a, slot_b = slot_pair

    auf_moves = ['', 'U', 'U2', "U'"]
    # Inverse of each AUF for the solution
    auf_inv = {'': '', 'U': "U'", "U'": 'U', 'U2': 'U2'}

    total_combos = 0
    valid_count = 0

    for name_a, alg_a in f2l_list:
        for name_b, alg_b in f2l_list:
            for auf in auf_moves:
                total_combos += 1

                # Build the scrambled state
                cube = Cube()
                _apply_slot_scramble(cube, slot_a, alg_a)
                if auf:
                    cube.apply_algorithm(auf)
                _apply_slot_scramble(cube, slot_b, alg_b)

                # Check that exactly the target pair is unsolved
                if not check_target_only(cube, slot_pair):
                    continue

                valid_count += 1

                # Build sequential solution: solve_b, undo_auf, solve_a
                sol_b = _build_slot_solution(slot_b, alg_b)
                sol_a = _build_slot_solution(slot_a, alg_a)
                undo_auf = auf_inv[auf]

                solution_parts = [sol_b]
                if undo_auf:
                    solution_parts.append(undo_auf)
                solution_parts.append(sol_a)
                solution = ' '.join(solution_parts)

                add_callback(cube.copy(), solution, 'enumeration')

    print(f"[enumerate] slot_pair={slot_pair}: "
          f"{total_combos} combos tried, {valid_count} valid states found")


# ---------------------------------------------------------------------------
# Random walk search
# ---------------------------------------------------------------------------

def random_walk_search(slot_pair, add_callback, num_trials=100_000,
                       min_depth=4, max_depth=15, seed=None,
                       progress_interval=10_000):
    """Search for 2-slot-unsolved states via weighted random moves.

    Applies a random sequence of moves to a solved cube, then checks
    whether exactly the two target slots are unsolved (with cross and
    other slots intact). Hits are rare but produce states unreachable
    by simple enumeration.

    Args:
        slot_pair: Tuple of two slot names, e.g. ('FR', 'FL').
        add_callback: Callable(cube, solution_str, source_str).
        num_trials: Number of random walks to attempt.
        min_depth: Minimum move count per walk.
        max_depth: Maximum move count per walk.
        seed: RNG seed for reproducibility.
        progress_interval: Print progress every N trials.
    """
    rng = random.Random(seed)
    hit_count = 0
    seen_states = set()
    t0 = time.time()

    for trial in range(1, num_trials + 1):
        cube = Cube()
        depth = rng.randint(min_depth, max_depth)

        # Pick moves using weighted random selection
        moves = rng.choices(SEARCH_MOVES, weights=_WEIGHTS_LIST, k=depth)

        # Apply each move
        for m in moves:
            cube.apply_move(m)

        # Check if this is a valid target state
        if check_target_only(cube, slot_pair):
            hit_count += 1
            state_key = cube.get_state_string()
            if state_key not in seen_states:
                seen_states.add(state_key)
                # The solution is the inverse of the applied moves
                solution = invert_alg(' '.join(moves))
                add_callback(cube.copy(), solution, 'random_walk')

        # Progress reporting
        if trial % progress_interval == 0:
            elapsed = time.time() - t0
            rate = trial / elapsed if elapsed > 0 else 0
            print(f"[random_walk] {trial}/{num_trials} trials | "
                  f"{hit_count} hits | {len(seen_states)} unique | "
                  f"{elapsed:.1f}s | {rate:.0f} trials/sec")

    elapsed = time.time() - t0
    print(f"[random_walk] DONE: {num_trials} trials, {hit_count} hits, "
          f"{len(seen_states)} unique states, {elapsed:.1f}s")


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=" * 60)
    print("  Multi-slot F2L Search Engine — Self-Test")
    print("=" * 60)

    # --- Test 1: check_target_only with known states ---
    print("\n--- Test 1: check_target_only ---")

    # Solved cube: no slots should be flagged as target-only
    cube = Cube()
    assert not check_target_only(cube, ('FR', 'FL')), \
        "Solved cube should not match (all slots solved)"
    print("  Solved cube correctly rejected")

    # Scramble exactly FR+FL
    cube = Cube()
    f2l_list = _get_f2l_list()
    _apply_slot_scramble(cube, 'FR', f2l_list[0][1])
    _apply_slot_scramble(cube, 'FL', f2l_list[0][1])
    result = check_target_only(cube, ('FR', 'FL'))
    print(f"  FR+FL scrambled, check ('FR','FL'): {result}")
    assert result, "FR+FL scramble should match target ('FR','FL')"

    # Same cube should NOT match a different target pair
    assert not check_target_only(cube, ('FR', 'BR')), \
        "FR+FL scramble should NOT match target ('FR','BR')"
    print("  Correctly rejected wrong target pair")
    print("  PASS")

    # --- Test 2: Enumeration for FR+FL ---
    print("\n--- Test 2: Enumeration (FR, FL) ---")
    enum_results = {}

    def enum_collector(c, sol, src):
        key = c.get_state_string()
        if key not in enum_results:
            enum_results[key] = sol

    t0 = time.time()
    enumerate_f2l_pairs(('FR', 'FL'), enum_collector)
    t1 = time.time()
    print(f"  Distinct states: {len(enum_results)}")
    print(f"  Time: {t1 - t0:.2f}s")

    # Verify a few solutions actually solve the cube
    verify_count = min(20, len(enum_results))
    all_ok = True
    for i, (state_key, sol) in enumerate(list(enum_results.items())[:verify_count]):
        # Reconstruct the cube from the state
        cube = Cube()
        # Re-parse state string back into faces
        for fi, face in enumerate(['U', 'D', 'F', 'B', 'L', 'R']):
            cube.faces[face] = list(state_key[fi * 9:(fi + 1) * 9])
        cube.apply_algorithm(sol)
        if not cube.is_f2l_solved():
            print(f"  FAIL: solution #{i} does not solve F2L")
            all_ok = False
            break
    if all_ok:
        print(f"  Verified {verify_count} solutions: all solve F2L correctly")
        print("  PASS")
    else:
        print("  FAIL")

    # --- Test 3: Short random walk ---
    print("\n--- Test 3: Random walk (100K trials, FR+FL) ---")
    rw_results = {}

    def rw_collector(c, sol, src):
        key = c.get_state_string()
        if key not in rw_results:
            rw_results[key] = sol

    random_walk_search(('FR', 'FL'), rw_collector,
                       num_trials=100_000, seed=42,
                       progress_interval=25_000)
    print(f"  Distinct states from random walk: {len(rw_results)}")

    # Verify solutions
    verify_count = min(20, len(rw_results))
    all_ok = True
    for i, (state_key, sol) in enumerate(list(rw_results.items())[:verify_count]):
        cube = Cube()
        for fi, face in enumerate(['U', 'D', 'F', 'B', 'L', 'R']):
            cube.faces[face] = list(state_key[fi * 9:(fi + 1) * 9])
        cube.apply_algorithm(sol)
        if not cube.is_f2l_solved():
            print(f"  FAIL: random walk solution #{i} does not solve F2L")
            all_ok = False
            break
    if all_ok:
        print(f"  Verified {verify_count} random walk solutions: all correct")
        print("  PASS")
    else:
        print("  FAIL")

    print("\n" + "=" * 60)
    print("  Self-test complete")
    print("=" * 60)

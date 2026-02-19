"""
F2L state generator: creates F2L-incomplete cube states.

Pure Python (no bpy dependency) — importable by any renderer or test script.

Generates states with 1-4 unsolved F2L pairs by applying the inverse of F2L
algorithms to specific slots via y-rotation bracketing.
"""

import os
import sys
import random

# Import Cube class and F2L algorithms
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)

from state_resolver import Cube
from algorithms import F2L_CASES, OLL_CASES, PLL_CASES, parse_algorithm

# F2L algorithms target the FR slot. To scramble other slots, rotate the
# target slot to FR, apply the inverse, then rotate back.
SLOT_ROTATION = {
    'FR': '',       # Already the target slot
    'FL': "y'",     # Rotate FL to FR
    'BR': 'y',      # Rotate BR to FR
    'BL': 'y2',     # Rotate BL to FR
}
INV_ROTATION = {'': '', 'y': "y'", "y'": 'y', 'y2': 'y2'}

ALL_SLOTS = ['FR', 'FL', 'BR']  # BL excluded: not visible from camera angle


def invert_alg(alg_str):
    """Compute the inverse of an algorithm string."""
    moves = parse_algorithm(alg_str)
    if not moves:
        return ''
    inv = []
    for m in reversed(moves):
        if m.endswith("'"):
            inv.append(m[:-1])
        elif m.endswith('2'):
            inv.append(m)
        else:
            inv.append(m + "'")
    return ' '.join(inv)


def _get_f2l_list():
    """Return list of (case_name, algorithm) tuples for non-empty F2L cases."""
    return [(name, alg) for name, alg in F2L_CASES.items() if alg]


def build_f2l_state(cube, slots, rng=None):
    """Apply inverse F2L algorithms to unsolved specific slots.

    Args:
        cube: Cube object (modified in place). Should start solved or with
              only LL scrambled.
        slots: List of slot names to unsolve, e.g. ['FR', 'FL'].
        rng: random.Random instance (default: create new one).

    Returns:
        List of dicts with scramble details:
        [{'slot': 'FR', 'f2l_case': 'F2L 4', 'inverse_alg': "R' U' R"}, ...]
    """
    if rng is None:
        rng = random.Random()

    f2l_list = _get_f2l_list()
    details = []

    for slot in slots:
        rot = SLOT_ROTATION[slot]
        inv_rot = INV_ROTATION[rot]

        case_name, alg = rng.choice(f2l_list)
        inv = invert_alg(alg)

        if rot:
            cube.apply_algorithm(rot)
        cube.apply_algorithm(inv)
        if inv_rot:
            cube.apply_algorithm(inv_rot)

        details.append({
            'slot': slot,
            'f2l_case': case_name,
            'inverse_alg': inv,
        })

    return details


def build_random_f2l_state(rng=None, max_unsolved=3, apply_ll=True):
    """Build a complete random F2L-incomplete state.

    Args:
        rng: random.Random instance.
        max_unsolved: Maximum number of pairs to unsolve (1-3).
        apply_ll: If True, also apply random OLL + PLL on top.

    Returns:
        (cube, metadata) where metadata is a dict with all scramble info.
    """
    if rng is None:
        rng = random.Random()

    # Choose number of unsolved pairs (weighted distribution)
    weights = {1: 40, 2: 30, 3: 20}
    max_unsolved = min(max_unsolved, len(ALL_SLOTS))
    choices = [n for n in range(1, max_unsolved + 1)]
    w = [weights[n] for n in choices]
    n_unsolved = rng.choices(choices, weights=w)[0]

    # Choose which slots to unsolve
    slots = rng.sample(ALL_SLOTS, n_unsolved)

    # Build F2L state
    cube = Cube()
    f2l_details = build_f2l_state(cube, slots, rng)

    # Optionally apply OLL + PLL
    oll_name = "OLL Skip"
    pll_name = "Solved"
    if apply_ll:
        oll_names = list(OLL_CASES.keys())
        pll_names = list(PLL_CASES.keys())
        oll_name = rng.choice(oll_names)
        pll_name = rng.choice(pll_names)

        if oll_name != "OLL Skip" and OLL_CASES[oll_name]:
            cube.apply_algorithm(OLL_CASES[oll_name])
        if pll_name != "Solved" and PLL_CASES[pll_name]:
            cube.apply_algorithm(PLL_CASES[pll_name])

    metadata = {
        'solve_phase': 'f2l',
        'f2l_pairs_solved': 4 - n_unsolved,
        'f2l_unsolved_slots': slots,
        'f2l_scramble_details': f2l_details,
        'oll_case': oll_name,
        'pll_case': pll_name,
    }

    return cube, metadata


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=== F2L Scrambler Self-Test ===\n")

    f2l_list = _get_f2l_list()
    print(f"F2L cases available: {len(f2l_list)}")

    # Test 1: Each F2L case on FR slot leaves 3 pairs solved
    ok = 0
    for name, alg in f2l_list:
        cube = Cube()
        inv = invert_alg(alg)
        cube.apply_algorithm(inv)
        if cube.count_solved_pairs() == 3:
            ok += 1
    print(f"\nTest 1 — FR slot, all 41 cases: {ok}/41 leave 3 pairs solved",
          "PASS" if ok == 41 else "FAIL")

    # Test 2: Each slot independently
    slot_ok = 0
    for slot in ALL_SLOTS:
        cube = Cube()
        details = build_f2l_state(cube, [slot], random.Random(42))
        pairs = cube.count_solved_pairs()
        unsolved = cube.get_unsolved_slots()
        status = "PASS" if pairs == 3 and unsolved == [slot] else "FAIL"
        print(f"Test 2 — {slot}: pairs={pairs}, unsolved={unsolved} {status}")
        if pairs == 3:
            slot_ok += 1
    print(f"  All slots: {slot_ok}/4", "PASS" if slot_ok == 4 else "FAIL")

    # Test 3: 2-slot scramble
    cube = Cube()
    details = build_f2l_state(cube, ['FR', 'FL'], random.Random(42))
    pairs = cube.count_solved_pairs()
    print(f"\nTest 3 — FR+FL: pairs={pairs}", "PASS" if pairs == 2 else "FAIL")

    # Test 4: 4-slot scramble
    cube = Cube()
    details = build_f2l_state(cube, ALL_SLOTS, random.Random(42))
    pairs = cube.count_solved_pairs()
    print(f"Test 4 — All 4: pairs={pairs}", "PASS" if pairs == 0 else "FAIL")

    # Test 5: F2L + OLL + PLL state is valid (9 of each color)
    cube, meta = build_random_f2l_state(random.Random(42), apply_ll=True)
    all_stickers = []
    for face in cube.faces.values():
        all_stickers.extend(face)
    from collections import Counter
    counts = Counter(all_stickers)
    valid = all(counts[c] == 9 for c in 'WYROGB')
    print(f"\nTest 5 — F2L+OLL+PLL state valid: {valid}",
          "PASS" if valid else f"FAIL {dict(counts)}")
    print(f"  Metadata: pairs={meta['f2l_pairs_solved']}, "
          f"unsolved={meta['f2l_unsolved_slots']}, "
          f"OLL={meta['oll_case']}, PLL={meta['pll_case']}")

    # Test 6: build_random_f2l_state distribution (100 samples)
    dist = {1: 0, 2: 0, 3: 0, 4: 0}
    rng = random.Random(123)
    for _ in range(100):
        _, m = build_random_f2l_state(rng)
        n = 4 - m['f2l_pairs_solved']
        dist[n] += 1
    print(f"\nTest 6 — Distribution (100 samples): {dict(dist)}")

    print("\n=== Done ===")

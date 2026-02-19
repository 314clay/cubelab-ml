"""
State canonicalization for multi-slot F2L finder.

Provides functions to identify F2L piece positions and encode cube state
into canonical string keys, with AUF (Adjust U Face) normalization so that
states differing only by a U-layer rotation map to the same canonical key.

Face indexing:
    0 1 2
    3 4 5
    6 7 8

Colors: U=W, D=Y, F=R, B=O, L=G, R=B
"""

import os
import sys

# ---------------------------------------------------------------------------
# Path setup — allow importing Cube, algorithms, and f2l_scrambler
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "cube-photo-solve"))
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "ml", "blender"))

from state_resolver import Cube
from algorithms import F2L_CASES, parse_algorithm
from f2l_scrambler import invert_alg, SLOT_ROTATION, INV_ROTATION, build_f2l_state

# ---------------------------------------------------------------------------
# Position tables
# ---------------------------------------------------------------------------

# Corner positions: maps position name -> list of (face, index) tuples.
# Sticker order matches the standard 3-color corner convention:
#   U/D sticker first, then the two side stickers in the face order.
CORNER_POSITIONS = {
    'UFR': [('U', 8), ('F', 2), ('R', 0)],
    'UFL': [('U', 6), ('F', 0), ('L', 2)],
    'UBR': [('U', 2), ('B', 0), ('R', 2)],
    'UBL': [('U', 0), ('B', 2), ('L', 0)],
    'DFR': [('D', 2), ('F', 8), ('R', 6)],
    'DFL': [('D', 0), ('F', 6), ('L', 8)],
    'DBR': [('D', 8), ('B', 6), ('R', 8)],
    'DBL': [('D', 6), ('B', 8), ('L', 6)],
}

# Edge positions: U-layer + E-layer edges (the ones relevant to F2L).
# D-layer edges are omitted because they belong to the cross.
EDGE_POSITIONS = {
    'UF': [('U', 7), ('F', 1)],
    'UR': [('U', 5), ('R', 1)],
    'UB': [('U', 1), ('B', 1)],
    'UL': [('U', 3), ('L', 1)],
    'FR': [('F', 5), ('R', 3)],
    'FL': [('F', 3), ('L', 5)],
    'BR': [('B', 3), ('R', 5)],
    'BL': [('B', 5), ('L', 3)],
}

# Piece identity: which sticker colors belong to each F2L slot's corner/edge.
SLOT_CORNER_COLORS = {
    'FR': frozenset(['Y', 'R', 'B']),
    'FL': frozenset(['Y', 'R', 'G']),
    'BR': frozenset(['Y', 'O', 'B']),
    'BL': frozenset(['Y', 'O', 'G']),
}

SLOT_EDGE_COLORS = {
    'FR': frozenset(['R', 'B']),
    'FL': frozenset(['R', 'G']),
    'BR': frozenset(['O', 'B']),
    'BL': frozenset(['O', 'G']),
}

# AUF moves to try for canonical_key normalization
_AUF_MOVES = ['', 'U', 'U2', "U'"]


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

def find_piece(cube, piece_colors, positions_dict):
    """Find a piece (corner or edge) on the cube by its color set.

    Scans every position in positions_dict, reads the sticker colors at that
    position, and checks if they match piece_colors (as a frozenset).

    Args:
        cube: Cube instance.
        piece_colors: frozenset of the piece's sticker colors (e.g. {'Y','R','B'}).
        positions_dict: CORNER_POSITIONS or EDGE_POSITIONS.

    Returns:
        (position_name, sticker_tuple) where sticker_tuple contains the actual
        color values in the position's sticker order.

    Raises:
        ValueError: If the piece is not found (indicates a bug or invalid state).
    """
    for pos_name, facets in positions_dict.items():
        stickers = tuple(cube.faces[face][idx] for face, idx in facets)
        if frozenset(stickers) == piece_colors:
            return pos_name, stickers
    raise ValueError(f"Piece {piece_colors} not found in {list(positions_dict.keys())}")


def make_state_key(cube, target_slots):
    """Build a deterministic string key encoding the positions and orientations
    of the corner and edge pieces for the given F2L slots.

    The key uniquely represents where each target piece currently sits and how
    its stickers are oriented, so two cubes with the same key have the same
    F2L state for those slots.

    Args:
        cube: Cube instance.
        target_slots: tuple/list of slot names, e.g. ('FR', 'FL').

    Returns:
        Key string, e.g. "FL:c=UBL:R.G.Y,e=UF:R.G|FR:c=DFR:Y.R.B,e=FR:B.R"
    """
    parts = []
    for slot in sorted(target_slots):
        c_colors = SLOT_CORNER_COLORS[slot]
        e_colors = SLOT_EDGE_COLORS[slot]

        c_pos, c_stickers = find_piece(cube, c_colors, CORNER_POSITIONS)
        e_pos, e_stickers = find_piece(cube, e_colors, EDGE_POSITIONS)

        c_str = f"c={c_pos}:{'.'.join(c_stickers)}"
        e_str = f"e={e_pos}:{'.'.join(e_stickers)}"
        parts.append(f"{slot}:{c_str},{e_str}")

    return '|'.join(parts)


def canonical_key(cube, target_slots):
    """Compute a canonical state key that is invariant under AUF (U moves).

    Tries all four U-layer adjustments ('', U, U2, U'), computes make_state_key
    for each, and returns the lexicographically smallest key along with the AUF
    move that produced it.

    Args:
        cube: Cube instance.
        target_slots: tuple/list of slot names.

    Returns:
        (key_str, auf_str) — the canonical key and the AUF move that maps the
        cube to its canonical orientation.
    """
    best_key = None
    best_auf = ''

    for auf in _AUF_MOVES:
        test = cube.copy()
        if auf:
            test.apply_algorithm(auf)
        key = make_state_key(test, target_slots)
        if best_key is None or key < best_key:
            best_key = key
            best_auf = auf

    return best_key, best_auf


# ---------------------------------------------------------------------------
# Self-tests
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    import random

    print("=== _canonicalize.py Self-Test ===\n")

    passed = 0
    failed = 0

    def check(label, condition):
        global passed, failed
        if condition:
            print(f"  PASS: {label}")
            passed += 1
        else:
            print(f"  FAIL: {label}")
            failed += 1

    # ------------------------------------------------------------------
    # Test 1: Solved cube — all pieces in home positions
    # ------------------------------------------------------------------
    print("Test 1: Solved cube state key")
    cube = Cube()
    key = make_state_key(cube, ('FR', 'FL', 'BR', 'BL'))
    print(f"  Key: {key}")

    # On a solved cube, each slot's pieces should be in their home D-layer
    # corner and E-layer edge positions.
    check("FR corner at DFR", "FR:c=DFR:" in key)
    check("FR edge at FR",    ",e=FR:" in key)
    check("FL corner at DFL", "FL:c=DFL:" in key)
    check("FL edge at FL",    "FL:" in key and "e=FL:" in key)
    check("BR corner at DBR", "BR:c=DBR:" in key)
    check("BR edge at BR",    "BR:" in key and "e=BR:" in key)
    check("BL corner at DBL", "BL:c=DBL:" in key)
    check("BL edge at BL",    "BL:" in key and "e=BL:" in key)

    # ------------------------------------------------------------------
    # Test 2: Apply R U R' — displaces FR corner and edge
    # ------------------------------------------------------------------
    print("\nTest 2: After R U R' — FR pieces displaced")
    cube2 = Cube()
    cube2.apply_algorithm("R U R'")
    key2 = make_state_key(cube2, ('FR',))
    print(f"  Key: {key2}")
    # The FR corner should no longer be at DFR
    check("FR corner NOT at DFR after R U R'", "c=DFR:" not in key2)

    # ------------------------------------------------------------------
    # Test 3: AUF normalization — U should not change canonical key
    # ------------------------------------------------------------------
    print("\nTest 3: AUF normalization")
    cube3a = Cube()
    cube3a.apply_algorithm("R U R'")
    ckey_a, auf_a = canonical_key(cube3a, ('FR',))

    cube3b = cube3a.copy()
    cube3b.apply_algorithm("U")
    ckey_b, auf_b = canonical_key(cube3b, ('FR',))

    cube3c = cube3a.copy()
    cube3c.apply_algorithm("U2")
    ckey_c, auf_c = canonical_key(cube3c, ('FR',))

    cube3d = cube3a.copy()
    cube3d.apply_algorithm("U'")
    ckey_d, auf_d = canonical_key(cube3d, ('FR',))

    print(f"  Base key:  {ckey_a} (AUF={auf_a!r})")
    print(f"  After U:   {ckey_b} (AUF={auf_b!r})")
    print(f"  After U2:  {ckey_c} (AUF={auf_c!r})")
    print(f"  After U':  {ckey_d} (AUF={auf_d!r})")
    check("canonical_key invariant under U",  ckey_a == ckey_b)
    check("canonical_key invariant under U2", ckey_a == ckey_c)
    check("canonical_key invariant under U'", ckey_a == ckey_d)

    # ------------------------------------------------------------------
    # Test 4: build_f2l_state scrambles specific slots
    # ------------------------------------------------------------------
    print("\nTest 4: build_f2l_state integration")
    rng = random.Random(42)
    cube4 = Cube()
    details = build_f2l_state(cube4, ['FR', 'FL'], rng)
    key4 = make_state_key(cube4, ('FR', 'FL'))
    print(f"  Key: {key4}")
    # Scrambled slots should NOT have pieces in home position
    # (extremely unlikely for a random F2L inverse)
    solved_key = make_state_key(Cube(), ('FR', 'FL'))
    check("Scrambled state differs from solved", key4 != solved_key)
    # Verify we can still find all the pieces (no crash)
    check("All pieces found (no ValueError)", True)

    # ------------------------------------------------------------------
    # Test 5: Multi-slot canonical key with AUF
    # ------------------------------------------------------------------
    print("\nTest 5: Multi-slot canonical key")
    cube5 = Cube()
    build_f2l_state(cube5, ['FR', 'BR'], random.Random(99))
    ckey5a, auf5a = canonical_key(cube5, ('FR', 'BR'))

    cube5u = cube5.copy()
    cube5u.apply_algorithm("U")
    ckey5b, auf5b = canonical_key(cube5u, ('FR', 'BR'))
    print(f"  Key:       {ckey5a} (AUF={auf5a!r})")
    print(f"  After U:   {ckey5b} (AUF={auf5b!r})")
    check("Multi-slot canonical_key invariant under U", ckey5a == ckey5b)

    # ------------------------------------------------------------------
    # Test 6: find_piece raises on impossible colors
    # ------------------------------------------------------------------
    print("\nTest 6: find_piece error handling")
    try:
        find_piece(Cube(), frozenset(['X', 'Y', 'Z']), CORNER_POSITIONS)
        check("ValueError raised for bogus colors", False)
    except ValueError:
        check("ValueError raised for bogus colors", True)

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    print(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed:
        sys.exit(1)

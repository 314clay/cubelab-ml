"""
StateReconstructor: Derive full 54-sticker cube state from 27 visible stickers.

Given ML model predictions for U[0-8] + F[0-8] + R[0-8], reconstruct all 54
stickers by leveraging the F2L-solved constraint and piece identification.

Key insight: For a last-layer state (F2L solved), ALL 27 hidden stickers are
determinable from the 27 visible ones. Zero unknowns.
"""

import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent))

from state_resolver import Cube

# The 4 U-layer corner pieces (by color set)
U_CORNERS = [
    frozenset({'W', 'G', 'R'}),  # Home: UFR
    frozenset({'W', 'G', 'O'}),  # Home: UFL
    frozenset({'W', 'B', 'R'}),  # Home: UBR
    frozenset({'W', 'B', 'O'}),  # Home: UBL
]

# The 4 U-layer edge pieces
U_EDGES = [
    frozenset({'W', 'G'}),  # Home: UF
    frozenset({'W', 'R'}),  # Home: UR
    frozenset({'W', 'B'}),  # Home: UB
    frozenset({'W', 'O'}),  # Home: UL
]

# Home position indices for parity calculation
CORNER_HOME = {
    frozenset({'W', 'G', 'R'}): 0,
    frozenset({'W', 'G', 'O'}): 1,
    frozenset({'W', 'B', 'R'}): 2,
    frozenset({'W', 'B', 'O'}): 3,
}

EDGE_HOME = {
    frozenset({'W', 'G'}): 0,
    frozenset({'W', 'R'}): 1,
    frozenset({'W', 'B'}): 2,
    frozenset({'W', 'O'}): 3,
}

# Kociemba color mapping (our colors -> kociemba face letters)
COLOR_TO_KOCIEMBA = {'W': 'U', 'Y': 'D', 'G': 'F', 'B': 'B', 'O': 'L', 'R': 'R'}


class StateReconstructor:
    """Reconstruct full 54-sticker state from 27 visible stickers."""

    def __init__(self):
        self._ufl_table, self._ubr_table, self._ubl_table = self._build_corner_tables()

    def _build_corner_tables(self):
        """Build direct sticker lookup tables for each hidden corner position.

        UFL and UBR each have 2 visible stickers, which uniquely determine the
        hidden one (due to corner chirality — each piece has a fixed cyclic
        color order). UBL has only 1 visible sticker (U[0]), so we need the
        piece identity (from elimination) plus U[0] to determine the twist.

        Returns:
            ufl_table: (U[6], F[0]) -> L[2]
            ubr_table: (U[2], R[2]) -> B[0]
            ubl_table: (piece_frozenset, U[0]) -> (B[2], L[0])
        """
        from algorithms import OLL_CASES, PLL_CASES

        ufl_table = {}  # (U[6], F[0]) -> L[2]
        ubr_table = {}  # (U[2], R[2]) -> B[0]
        ubl_table = {}  # (piece_frozenset, U[0]) -> (B[2], L[0])

        for oll_alg in OLL_CASES.values():
            for pll_alg in PLL_CASES.values():
                for auf in ['', 'U', "U'", 'U2']:
                    cube = Cube()
                    alg = ' '.join(filter(None, [oll_alg, pll_alg, auf]))
                    if alg.strip():
                        try:
                            cube.apply_algorithm(alg.strip())
                        except Exception:
                            continue

                    ufl_key = (cube.faces['U'][6], cube.faces['F'][0])
                    if ufl_key not in ufl_table:
                        ufl_table[ufl_key] = cube.faces['L'][2]

                    ubr_key = (cube.faces['U'][2], cube.faces['R'][2])
                    if ubr_key not in ubr_table:
                        ubr_table[ubr_key] = cube.faces['B'][0]

                    u0 = cube.faces['U'][0]
                    b2 = cube.faces['B'][2]
                    l0 = cube.faces['L'][0]
                    piece = frozenset({u0, b2, l0})
                    if piece in U_CORNERS:
                        ubl_key = (piece, u0)
                        if ubl_key not in ubl_table:
                            ubl_table[ubl_key] = (b2, l0)

        return ufl_table, ubr_table, ubl_table

    @staticmethod
    def _perm_parity(perm: List[int]) -> int:
        """Compute parity of a permutation: 0=even, 1=odd."""
        n = len(perm)
        visited = [False] * n
        parity = 0
        for i in range(n):
            if not visited[i]:
                j = i
                cycle_len = 0
                while not visited[j]:
                    visited[j] = True
                    j = perm[j]
                    cycle_len += 1
                parity += cycle_len - 1
        return parity % 2

    def _derive_corners(self, U, F, R):
        """Derive hidden corner stickers using direct lookup tables.

        Corner chirality means 2 visible stickers uniquely determine the hidden one.
        For UBL (only 1 visible), we need the UBL-specific table.

        Returns: (L2, B0, B2, L0) — the 4 hidden corner stickers.
        Also returns the 4 corner piece frozensets for parity calculation.
        """
        # UFR: all 3 visible
        ufr = frozenset({U[8], F[2], R[0]})
        if ufr not in U_CORNERS:
            raise ValueError(f"UFR colors {set(ufr)} not a valid corner piece")

        # UFL: U[6] and F[0] visible, L[2] hidden
        ufl_key = (U[6], F[0])
        if ufl_key not in self._ufl_table:
            raise ValueError(f"UFL stickers {ufl_key} not in lookup table")
        L2 = self._ufl_table[ufl_key]
        ufl = frozenset({U[6], F[0], L2})

        # UBR: U[2] and R[2] visible, B[0] hidden
        ubr_key = (U[2], R[2])
        if ubr_key not in self._ubr_table:
            raise ValueError(f"UBR stickers {ubr_key} not in lookup table")
        B0 = self._ubr_table[ubr_key]
        ubr = frozenset({U[2], R[2], B0})

        # UBL: only U[0] visible — identify piece by elimination, then lookup twist
        ubl = [p for p in U_CORNERS if p not in {ufr, ufl, ubr}]
        if len(ubl) != 1:
            raise ValueError(f"Could not determine UBL piece by elimination")
        ubl = ubl[0]
        ubl_key = (ubl, U[0])
        if ubl_key not in self._ubl_table:
            raise ValueError(
                f"UBL twist not in table: piece={set(ubl)}, U[0]={U[0]}")
        B2, L0 = self._ubl_table[ubl_key]

        return L2, B0, B2, L0, ufr, ufl, ubr, ubl

    def _identify_edges(self, U, F, R, corner_parity):
        """Identify which physical piece is at each U-layer edge slot.

        Returns: (uf_piece, ur_piece, ub_piece, ul_piece) as frozensets.
        """
        # UF: both visible
        uf = frozenset({U[7], F[1]})
        if uf not in U_EDGES:
            raise ValueError(f"UF edge {set(uf)} not a valid edge piece")

        # UR: both visible
        ur = frozenset({U[5], R[1]})
        if ur not in U_EDGES:
            raise ValueError(f"UR edge {set(ur)} not a valid edge piece")

        pool = [e for e in U_EDGES if e not in {uf, ur}]

        ub_u = U[1]
        ul_u = U[3]

        if ub_u != 'W':
            # UB edge flipped: non-W color visible on U
            ub = frozenset({'W', ub_u})
            if ub not in pool:
                raise ValueError(f"UB edge {{W, {ub_u}}} not in remaining pool")
            ul = [e for e in pool if e != ub][0]
        elif ul_u != 'W':
            # UL edge flipped
            ul = frozenset({'W', ul_u})
            if ul not in pool:
                raise ValueError(f"UL edge {{W, {ul_u}}} not in remaining pool")
            ub = [e for e in pool if e != ul][0]
        else:
            # Both oriented (W on top) — use parity to resolve
            # Try assignment 0: pool[0] at UB, pool[1] at UL
            perm0 = [EDGE_HOME[uf], EDGE_HOME[ur],
                     EDGE_HOME[pool[0]], EDGE_HOME[pool[1]]]
            edge_par0 = self._perm_parity(perm0)

            if edge_par0 == corner_parity:
                ub, ul = pool[0], pool[1]
            else:
                ub, ul = pool[1], pool[0]

        return uf, ur, ub, ul

    def reconstruct(self, visible_27: List[str]) -> Dict[str, List[str]]:
        """Reconstruct full 54-sticker state from 27 visible stickers.

        Args:
            visible_27: 27 color chars in order U[0-8] + F[0-8] + R[0-8]

        Returns:
            Dict with keys U/D/F/B/L/R, each a 9-element color list.

        Raises:
            ValueError if reconstruction fails.
        """
        if len(visible_27) != 27:
            raise ValueError(f"Expected 27 stickers, got {len(visible_27)}")

        U = list(visible_27[0:9])
        F = list(visible_27[9:18])
        R = list(visible_27[18:27])

        # Initialize hidden faces with F2L solved colors
        D = ['Y'] * 9
        B = [None, None, None, 'O', 'O', 'O', 'O', 'O', 'O']
        L = [None, None, None, 'G', 'G', 'G', 'G', 'G', 'G']

        # Derive hidden corner stickers using chirality-based lookup
        L[2], B[0], B[2], L[0], ufr, ufl, ubr, ubl = self._derive_corners(U, F, R)

        # Compute corner permutation parity for edge resolution
        corner_perm = [CORNER_HOME[ufr], CORNER_HOME[ufl],
                       CORNER_HOME[ubr], CORNER_HOME[ubl]]
        corner_par = self._perm_parity(corner_perm)

        # Identify edges
        uf, ur, ub, ul = self._identify_edges(U, F, R, corner_par)

        # Derive UB hidden sticker: B[1]
        B[1] = list(ub - {U[1]})[0]

        # Derive UL hidden sticker: L[1]
        L[1] = list(ul - {U[3]})[0]

        state = {
            'U': U, 'D': D, 'F': F,
            'B': B, 'L': L, 'R': R,
        }

        return state

    def validate(self, state: Dict[str, List[str]]) -> List[str]:
        """Check reconstructed state for consistency.

        Returns list of error strings (empty = valid).
        """
        errors = []

        # Check each color appears exactly 9 times
        all_stickers = []
        for face in ['U', 'D', 'F', 'B', 'L', 'R']:
            all_stickers.extend(state[face])

        if len(all_stickers) != 54:
            errors.append(f"Expected 54 stickers, got {len(all_stickers)}")
            return errors

        from collections import Counter
        counts = Counter(all_stickers)
        for color in 'WYROGB':
            if counts.get(color, 0) != 9:
                errors.append(f"Color {color}: {counts.get(color, 0)} (expected 9)")

        # Check centers
        expected_centers = {'U': 'W', 'D': 'Y', 'F': 'R', 'B': 'O', 'L': 'G', 'R': 'B'}
        for face, expected in expected_centers.items():
            if state[face][4] != expected:
                errors.append(f"{face} center={state[face][4]} (expected {expected})")

        # Check F2L rows are solved
        for i in range(3, 9):
            if state['F'][i] != 'R':
                errors.append(f"F[{i}]={state['F'][i]} (expected R)")
            if state['R'][i] != 'B':
                errors.append(f"R[{i}]={state['R'][i]} (expected B)")
            if state['B'][i] != 'O':
                errors.append(f"B[{i}]={state['B'][i]} (expected O)")
            if state['L'][i] != 'G':
                errors.append(f"L[{i}]={state['L'][i]} (expected G)")

        return errors

    @staticmethod
    def to_kociemba(state: Dict[str, List[str]]) -> str:
        """Convert state dict to kociemba format string (URFDLB order)."""
        s = ''
        for face in ['U', 'R', 'F', 'D', 'L', 'B']:
            for color in state[face]:
                s += COLOR_TO_KOCIEMBA[color]
        return s

    @staticmethod
    def to_cube(state: Dict[str, List[str]]) -> 'Cube':
        """Convert state dict to a Cube object."""
        cube = Cube()
        for face in ['U', 'D', 'F', 'B', 'L', 'R']:
            cube.faces[face] = list(state[face])
        return cube


if __name__ == "__main__":
    # Quick self-test with known states
    from algorithms import OLL_CASES, PLL_CASES

    recon = StateReconstructor()
    print(f"UBL twist table: {len(recon._ubl_table)} entries")

    test_cases = [
        ("Solved", ""),
        ("OLL 27", OLL_CASES["OLL 27"]),
        ("T-Perm", PLL_CASES["T-Perm"]),
        ("OLL 27 + T-Perm", f"{OLL_CASES['OLL 27']} {PLL_CASES['T-Perm']}"),
        ("OLL 45", OLL_CASES["OLL 45"]),
        ("H-Perm", PLL_CASES["H-Perm"]),
    ]

    passed = 0
    for name, alg in test_cases:
        cube = Cube()
        if alg:
            cube.apply_algorithm(alg)

        # Extract 27 visible stickers
        vis = cube.faces['U'] + cube.faces['F'] + cube.faces['R']

        # Reconstruct
        try:
            state = recon.reconstruct(vis)
            errors = recon.validate(state)

            # Compare against ground truth
            match = True
            for face in ['U', 'D', 'F', 'B', 'L', 'R']:
                if state[face] != cube.faces[face]:
                    match = False
                    print(f"  {face}: got {state[face]}, expected {cube.faces[face]}")

            status = "PASS" if match and not errors else "FAIL"
            if errors:
                status += f" (validation: {errors})"
            print(f"{name:30s} {status}")
            if match:
                passed += 1
        except Exception as e:
            print(f"{name:30s} ERROR: {e}")

    print(f"\n{passed}/{len(test_cases)} passed")

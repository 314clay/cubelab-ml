"""
StateResolver: Generates valid Last Layer states and matches detected stickers
Uses brute-force lookup table approach with cube state representation
"""

import numpy as np
from typing import List, Dict, Tuple, Optional
from algorithms import OLL_CASES, PLL_CASES, parse_algorithm


class Cube:
    """
    Simple Rubik's Cube representation.
    Faces: U (top), D (bottom), F (front), B (back), L (left), R (right)
    Each face is a 3x3 grid indexed as:
    0 1 2
    3 4 5
    6 7 8
    """

    def __init__(self):
        """Initialize a solved cube."""
        # Each face is represented by its center color
        self.faces = {
            'U': ['W'] * 9,  # White top
            'D': ['Y'] * 9,  # Yellow bottom
            'F': ['R'] * 9,  # Red front
            'B': ['O'] * 9,  # Orange back
            'L': ['G'] * 9,  # Green left
            'R': ['B'] * 9,  # Blue right
        }

    def copy(self):
        """Create a deep copy of the cube."""
        new_cube = Cube()
        for face in self.faces:
            new_cube.faces[face] = self.faces[face].copy()
        return new_cube

    def get_state_string(self) -> str:
        """Get a string representation of the cube state."""
        return ''.join([
            ''.join(self.faces['U']),
            ''.join(self.faces['D']),
            ''.join(self.faces['F']),
            ''.join(self.faces['B']),
            ''.join(self.faces['L']),
            ''.join(self.faces['R']),
        ])

    def get_visible_stickers(self) -> List[str]:
        """
        Get the 15 visible stickers: Top (9) + Front top row (3) + Right top row (3)
        """
        visible = []

        # Top face (all 9)
        visible.extend(self.faces['U'])

        # Front face top row (indices 0, 1, 2)
        visible.extend(self.faces['F'][0:3])

        # Right face top row (indices 0, 1, 2)
        visible.extend(self.faces['R'][0:3])

        return visible

    def apply_move(self, move: str):
        """
        Apply a single move to the cube.
        Supports: R, L, U, D, F, B, M, r, x, y, z
        Modifiers: ' (counterclockwise), 2 (double)
        """
        # Handle modifiers
        if move.endswith("'"):
            base_move = move[:-1]
            times = 3  # Counterclockwise = 3 clockwise
        elif move.endswith("2"):
            base_move = move[:-1]
            times = 2
        else:
            base_move = move
            times = 1

        # Apply the move 'times' times
        for _ in range(times):
            self._apply_single_move(base_move)

    def _apply_single_move(self, move: str):
        """Apply a single clockwise move."""
        if move == 'R':
            self._move_R()
        elif move == 'L':
            self._move_L()
        elif move == 'U':
            self._move_U()
        elif move == 'D':
            self._move_D()
        elif move == 'F':
            self._move_F()
        elif move == 'B':
            self._move_B()
        elif move == 'M':
            self._move_M()
        elif move == 'S':
            self._move_S()
        elif move == 'E':
            self._move_E()
        elif move == 'r':
            self._move_r()
        elif move == 'l':
            self._move_l()
        elif move == 'u':
            self._move_u()
        elif move == 'd':
            self._move_d()
        elif move == 'f':
            self._move_f()
        elif move == 'b':
            self._move_b()
        elif move == 'x':
            self._move_x()
        elif move == 'y':
            self._move_y()
        elif move == 'z':
            self._move_z()
        else:
            raise ValueError(f"Unknown move: {move}")

    def _rotate_face_cw(self, face: str):
        """Rotate a face 90 degrees clockwise."""
        f = self.faces[face]
        self.faces[face] = [f[6], f[3], f[0], f[7], f[4], f[1], f[8], f[5], f[2]]

    def _move_R(self):
        """R move: Right face clockwise."""
        self._rotate_face_cw('R')

        # Cycle edges
        temp = [self.faces['U'][2], self.faces['U'][5], self.faces['U'][8]]
        self.faces['U'][2], self.faces['U'][5], self.faces['U'][8] = \
            self.faces['F'][2], self.faces['F'][5], self.faces['F'][8]
        self.faces['F'][2], self.faces['F'][5], self.faces['F'][8] = \
            self.faces['D'][2], self.faces['D'][5], self.faces['D'][8]
        self.faces['D'][2], self.faces['D'][5], self.faces['D'][8] = \
            self.faces['B'][6], self.faces['B'][3], self.faces['B'][0]
        self.faces['B'][6], self.faces['B'][3], self.faces['B'][0] = temp

    def _move_L(self):
        """L move: Left face clockwise."""
        self._rotate_face_cw('L')

        # Cycle edges
        temp = [self.faces['U'][0], self.faces['U'][3], self.faces['U'][6]]
        self.faces['U'][0], self.faces['U'][3], self.faces['U'][6] = \
            self.faces['B'][8], self.faces['B'][5], self.faces['B'][2]
        self.faces['B'][8], self.faces['B'][5], self.faces['B'][2] = \
            self.faces['D'][0], self.faces['D'][3], self.faces['D'][6]
        self.faces['D'][0], self.faces['D'][3], self.faces['D'][6] = \
            self.faces['F'][0], self.faces['F'][3], self.faces['F'][6]
        self.faces['F'][0], self.faces['F'][3], self.faces['F'][6] = temp

    def _move_U(self):
        """U move: Top face clockwise."""
        self._rotate_face_cw('U')

        # Cycle edges
        temp = [self.faces['F'][0], self.faces['F'][1], self.faces['F'][2]]
        self.faces['F'][0], self.faces['F'][1], self.faces['F'][2] = \
            self.faces['R'][0], self.faces['R'][1], self.faces['R'][2]
        self.faces['R'][0], self.faces['R'][1], self.faces['R'][2] = \
            self.faces['B'][0], self.faces['B'][1], self.faces['B'][2]
        self.faces['B'][0], self.faces['B'][1], self.faces['B'][2] = \
            self.faces['L'][0], self.faces['L'][1], self.faces['L'][2]
        self.faces['L'][0], self.faces['L'][1], self.faces['L'][2] = temp

    def _move_D(self):
        """D move: Bottom face clockwise."""
        self._rotate_face_cw('D')

        # Cycle edges
        temp = [self.faces['F'][6], self.faces['F'][7], self.faces['F'][8]]
        self.faces['F'][6], self.faces['F'][7], self.faces['F'][8] = \
            self.faces['L'][6], self.faces['L'][7], self.faces['L'][8]
        self.faces['L'][6], self.faces['L'][7], self.faces['L'][8] = \
            self.faces['B'][6], self.faces['B'][7], self.faces['B'][8]
        self.faces['B'][6], self.faces['B'][7], self.faces['B'][8] = \
            self.faces['R'][6], self.faces['R'][7], self.faces['R'][8]
        self.faces['R'][6], self.faces['R'][7], self.faces['R'][8] = temp

    def _move_F(self):
        """F move: Front face clockwise."""
        self._rotate_face_cw('F')

        # Cycle edges
        temp = [self.faces['U'][6], self.faces['U'][7], self.faces['U'][8]]
        self.faces['U'][6], self.faces['U'][7], self.faces['U'][8] = \
            self.faces['L'][8], self.faces['L'][5], self.faces['L'][2]
        self.faces['L'][2], self.faces['L'][5], self.faces['L'][8] = \
            self.faces['D'][0], self.faces['D'][1], self.faces['D'][2]
        self.faces['D'][0], self.faces['D'][1], self.faces['D'][2] = \
            self.faces['R'][6], self.faces['R'][3], self.faces['R'][0]
        self.faces['R'][0], self.faces['R'][3], self.faces['R'][6] = temp

    def _move_B(self):
        """B move: Back face clockwise."""
        self._rotate_face_cw('B')

        # Cycle edges
        temp = [self.faces['U'][0], self.faces['U'][1], self.faces['U'][2]]
        self.faces['U'][0], self.faces['U'][1], self.faces['U'][2] = \
            self.faces['R'][2], self.faces['R'][5], self.faces['R'][8]
        self.faces['R'][2], self.faces['R'][5], self.faces['R'][8] = \
            self.faces['D'][8], self.faces['D'][7], self.faces['D'][6]
        self.faces['D'][6], self.faces['D'][7], self.faces['D'][8] = \
            self.faces['L'][0], self.faces['L'][3], self.faces['L'][6]
        self.faces['L'][0], self.faces['L'][3], self.faces['L'][6] = temp

    def _move_M(self):
        """M move: Middle layer (between L and R), same direction as L.
        Cycle: U <- B(reversed) <- D <- F <- U (same pattern as L)."""
        temp = [self.faces['U'][1], self.faces['U'][4], self.faces['U'][7]]
        self.faces['U'][1], self.faces['U'][4], self.faces['U'][7] = \
            self.faces['B'][7], self.faces['B'][4], self.faces['B'][1]
        self.faces['B'][7], self.faces['B'][4], self.faces['B'][1] = \
            self.faces['D'][1], self.faces['D'][4], self.faces['D'][7]
        self.faces['D'][1], self.faces['D'][4], self.faces['D'][7] = \
            self.faces['F'][1], self.faces['F'][4], self.faces['F'][7]
        self.faces['F'][1], self.faces['F'][4], self.faces['F'][7] = temp

    def _move_S(self):
        """S move: Standing slice, same direction as F, on middle layer."""
        temp = [self.faces['U'][3], self.faces['U'][4], self.faces['U'][5]]
        # U middle row gets L middle column (reversed)
        self.faces['U'][3], self.faces['U'][4], self.faces['U'][5] = \
            self.faces['L'][7], self.faces['L'][4], self.faces['L'][1]
        # L middle column gets D middle row
        self.faces['L'][1], self.faces['L'][4], self.faces['L'][7] = \
            self.faces['D'][3], self.faces['D'][4], self.faces['D'][5]
        # D middle row gets R middle column (reversed)
        self.faces['D'][3], self.faces['D'][4], self.faces['D'][5] = \
            self.faces['R'][7], self.faces['R'][4], self.faces['R'][1]
        # R middle column gets old U middle row
        self.faces['R'][1], self.faces['R'][4], self.faces['R'][7] = temp

    def _move_E(self):
        """E move: Equatorial slice, same direction as D, on middle layer."""
        temp = [self.faces['F'][3], self.faces['F'][4], self.faces['F'][5]]
        # Same cycle as D: F←L←B←R←F
        self.faces['F'][3], self.faces['F'][4], self.faces['F'][5] = \
            self.faces['L'][3], self.faces['L'][4], self.faces['L'][5]
        self.faces['L'][3], self.faces['L'][4], self.faces['L'][5] = \
            self.faces['B'][3], self.faces['B'][4], self.faces['B'][5]
        self.faces['B'][3], self.faces['B'][4], self.faces['B'][5] = \
            self.faces['R'][3], self.faces['R'][4], self.faces['R'][5]
        self.faces['R'][3], self.faces['R'][4], self.faces['R'][5] = temp

    def _move_r(self):
        """r move: Right two layers (R + M')."""
        self._move_R()
        self.apply_move("M'")

    def _move_l(self):
        """l move: Left two layers (L + M)."""
        self._move_L()
        self._move_M()

    def _move_u(self):
        """u move: Upper two layers (U + E')."""
        self._move_U()
        self.apply_move("E'")

    def _move_d(self):
        """d move: Down two layers (D + E)."""
        self._move_D()
        self._move_E()

    def _move_f(self):
        """f move: Front two layers (F + S)."""
        self._move_F()
        self._move_S()

    def _move_b(self):
        """b move: Back two layers (B + S')."""
        self._move_B()
        self.apply_move("S'")

    def _move_x(self):
        """x rotation: Entire cube rotation around R axis (R + M' + L')."""
        self._move_R()
        self.apply_move("M'")
        self.apply_move("L'")

    def _move_y(self):
        """y rotation: Entire cube rotation around U axis (U + E' + D')."""
        self._move_U()
        self.apply_move("E'")
        self.apply_move("D'")

    def _move_z(self):
        """z rotation: Entire cube rotation around F axis (F + S + B')."""
        self._move_F()
        self._move_S()
        self.apply_move("B'")

    def apply_algorithm(self, algorithm: str):
        """
        Apply a full algorithm (sequence of moves) to the cube.

        Args:
            algorithm: Space-separated moves (e.g., "R U R' U'")
        """
        moves = parse_algorithm(algorithm)
        for move in moves:
            self.apply_move(move)


class StateResolver:
    """
    Generates lookup table of valid Last Layer states and matches detected stickers.
    """

    def __init__(self):
        """Initialize the state resolver."""
        self.lookup_table: Dict[str, Dict] = {}
        self._build_lookup_table()

    def _get_all_orientations(self) -> List[Cube]:
        """
        Generate all 24 possible cube orientations from a solved cube.

        24 orientations = 6 possible top faces × 4 possible front faces for each top.
        Achieved by applying x, y, z rotations to a solved cube.

        Returns:
            List of 24 Cube objects in different orientations
        """
        orientations = []

        # Define rotation sequences for all 24 orientations
        # Format: (rotation_sequence, description)
        rotation_sequences = [
            # Top = U (White top in standard orientation)
            ('', 'U-top, F-front'),
            ('y', 'U-top, R-front'),
            ('y2', 'U-top, B-front'),
            ("y'", 'U-top, L-front'),

            # Top = D (Yellow top)
            ('x2', 'D-top, F-front'),
            ('x2 y', 'D-top, R-front'),
            ('x2 y2', 'D-top, B-front'),
            ("x2 y'", 'D-top, L-front'),

            # Top = F (Red top)
            ("x'", 'F-top, U-front'),
            ("x' y", 'F-top, L-front'),
            ("x' y2", 'F-top, D-front'),
            ("x' y'", 'F-top, R-front'),

            # Top = B (Orange top)
            ('x', 'B-top, U-front'),
            ('x y', 'B-top, R-front'),
            ('x y2', 'B-top, D-front'),
            ("x y'", 'B-top, L-front'),

            # Top = L (Green top)
            ("z'", 'L-top, U-front'),
            ("z' y", 'L-top, F-front'),
            ("z' y2", 'L-top, D-front'),
            ("z' y'", 'L-top, B-front'),

            # Top = R (Blue top)
            ('z', 'R-top, U-front'),
            ('z y', 'R-top, B-front'),
            ('z y2', 'R-top, D-front'),
            ("z y'", 'R-top, F-front'),
        ]

        for rotation_seq, desc in rotation_sequences:
            cube = Cube()  # Start with solved cube
            if rotation_seq:
                cube.apply_algorithm(rotation_seq)
            orientations.append(cube)

        return orientations

    def _build_lookup_table(self):
        """
        Generate all valid LL states by applying OLL + PLL algorithms.
        Store in lookup table with visible stickers as key.

        Generates states for all 24 possible cube orientations.
        """
        print("Building lookup table of valid LL states for all cube orientations...")

        state_count = 0

        # Get all 24 possible cube orientations
        base_orientations = self._get_all_orientations()

        # For each base orientation
        for base_cube in base_orientations:
            # First, generate PLL-only states (OLL already solved)
            for pll_name, pll_alg in PLL_CASES.items():
                state_cube = base_cube.copy()
                if pll_alg:  # PLL might be empty (already solved)
                    state_cube.apply_algorithm(pll_alg)

                # Generate 4 rotations
                for rotation in ['', 'y', 'y2', "y'"]:
                    rotated_cube = state_cube.copy()
                    if rotation:
                        rotated_cube.apply_algorithm(rotation)

                    # Get visible stickers
                    visible = rotated_cube.get_visible_stickers()
                    visible_key = ''.join(visible)

                    # Store in lookup table
                    if visible_key not in self.lookup_table:
                        self.lookup_table[visible_key] = {
                            'oll_case': 'OLL Skip',
                            'pll_case': pll_name,
                            'combined_name': f"OLL Skip + {pll_name}",
                            'oll_algorithm': '',
                            'pll_algorithm': pll_alg,
                            'rotation': rotation,
                            'visible_stickers': visible
                        }
                        state_count += 1

            # Then apply each OLL algorithm
            for oll_name, oll_alg in OLL_CASES.items():
                if not oll_alg:  # Skip empty algorithms
                    continue

                # Apply OLL
                oll_cube = base_cube.copy()
                oll_cube.apply_algorithm(oll_alg)

                # Then apply each PLL algorithm
                for pll_name, pll_alg in PLL_CASES.items():
                    # Apply PLL
                    state_cube = oll_cube.copy()
                    if pll_alg:  # PLL might be empty (already solved)
                        state_cube.apply_algorithm(pll_alg)

                    # Generate 4 rotations (y, y2, y', no rotation)
                    for rotation in ['', 'y', 'y2', "y'"]:
                        rotated_cube = state_cube.copy()
                        if rotation:
                            rotated_cube.apply_algorithm(rotation)

                        # Get visible stickers
                        visible = rotated_cube.get_visible_stickers()
                        visible_key = ''.join(visible)

                        # Store in lookup table (only if not already stored)
                        if visible_key not in self.lookup_table:
                            self.lookup_table[visible_key] = {
                                'oll_case': oll_name,
                                'pll_case': pll_name,
                                'combined_name': f"{oll_name} + {pll_name}",
                                'oll_algorithm': oll_alg,
                                'pll_algorithm': pll_alg,
                                'rotation': rotation,
                                'visible_stickers': visible
                            }
                            state_count += 1

        print(f"Generated {state_count} unique LL states")

    def match_state(self, detected_stickers: List[str]) -> Optional[Dict]:
        """
        Match detected stickers against the lookup table.

        Args:
            detected_stickers: 15-element list of face colors

        Returns:
            Dictionary with case info if match found, None otherwise
        """
        if len(detected_stickers) != 15:
            raise ValueError(f"Expected 15 stickers, got {len(detected_stickers)}")

        visible_key = ''.join(detected_stickers)

        if visible_key in self.lookup_table:
            return self.lookup_table[visible_key]
        else:
            return None

    def find_closest_matches(self, detected_stickers: List[str], n=5) -> List[Tuple[Dict, int]]:
        """
        Find the N closest matches in the lookup table.

        Args:
            detected_stickers: 15-element list of face colors
            n: Number of matches to return

        Returns:
            List of (match_info, difference_count) tuples
        """
        visible_key = ''.join(detected_stickers)

        # Calculate Hamming distance for each entry
        matches = []
        for stored_key, info in self.lookup_table.items():
            diff = sum(c1 != c2 for c1, c2 in zip(visible_key, stored_key))
            matches.append((info, diff))

        # Sort by difference
        matches.sort(key=lambda x: x[1])

        return matches[:n]


if __name__ == "__main__":
    # Test the state resolver
    print("Testing StateResolver...")

    resolver = StateResolver()

    # Test with a solved cube
    solved_cube = Cube()
    visible = solved_cube.get_visible_stickers()
    print(f"\nSolved cube visible stickers: {visible}")

    match = resolver.match_state(visible)
    if match:
        print(f"Match found: {match['combined_name']}")
    else:
        print("No exact match found")
        closest = resolver.find_closest_matches(visible, n=3)
        print(f"Closest matches:")
        for info, diff in closest:
            print(f"  {info['combined_name']} (diff: {diff})")

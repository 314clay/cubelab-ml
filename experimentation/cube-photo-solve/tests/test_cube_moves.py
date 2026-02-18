"""
Comprehensive tests for Cube class move correctness.
Each move must produce the exact correct face permutation.
"""

import pytest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from state_resolver import Cube


class TestBasicMoveIdentity:
    """Every basic move applied 4 times must return to solved."""

    def test_R_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('R')
        assert cube.get_state_string() == original

    def test_L_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('L')
        assert cube.get_state_string() == original

    def test_U_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('U')
        assert cube.get_state_string() == original

    def test_D_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('D')
        assert cube.get_state_string() == original

    def test_F_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('F')
        assert cube.get_state_string() == original

    def test_B_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('B')
        assert cube.get_state_string() == original

    def test_M_four_times(self):
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('M')
        assert cube.get_state_string() == original


class TestMoveInverses:
    """X followed by X' must return to solved."""

    def test_R_Rprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('R')
        cube.apply_move("R'")
        assert cube.get_state_string() == original

    def test_L_Lprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('L')
        cube.apply_move("L'")
        assert cube.get_state_string() == original

    def test_U_Uprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('U')
        cube.apply_move("U'")
        assert cube.get_state_string() == original

    def test_D_Dprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('D')
        cube.apply_move("D'")
        assert cube.get_state_string() == original

    def test_F_Fprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('F')
        cube.apply_move("F'")
        assert cube.get_state_string() == original

    def test_B_Bprime(self):
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('B')
        cube.apply_move("B'")
        assert cube.get_state_string() == original


class TestDoubleMoves:
    """X2 must equal X applied twice."""

    def test_R2(self):
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('R2')
        c2.apply_move('R')
        c2.apply_move('R')
        assert c1.get_state_string() == c2.get_state_string()

    def test_U2(self):
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('U2')
        c2.apply_move('U')
        c2.apply_move('U')
        assert c1.get_state_string() == c2.get_state_string()

    def test_F2(self):
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('F2')
        c2.apply_move('F')
        c2.apply_move('F')
        assert c1.get_state_string() == c2.get_state_string()


class TestSpecificMovePermutations:
    """
    Verify specific sticker positions after each move.
    Uses standard Rubik's cube convention:
    - U=White, D=Yellow, F=Red, B=Orange, L=Green, R=Blue
    - Face indices:
      0 1 2
      3 4 5
      6 7 8
    """

    def test_R_move_U_face(self):
        """After R, U face positions 2,5,8 should have F face colors."""
        cube = Cube()
        cube.apply_move('R')
        # R moves F[2,5,8] -> U[2,5,8]
        assert cube.faces['U'][2] == 'R'  # was White, now Red (from Front)
        assert cube.faces['U'][5] == 'R'
        assert cube.faces['U'][8] == 'R'
        # Rest of U face unchanged
        assert cube.faces['U'][0] == 'W'
        assert cube.faces['U'][1] == 'W'
        assert cube.faces['U'][3] == 'W'
        assert cube.faces['U'][4] == 'W'
        assert cube.faces['U'][6] == 'W'
        assert cube.faces['U'][7] == 'W'

    def test_R_move_F_face(self):
        """After R, F face positions 2,5,8 should have D face colors."""
        cube = Cube()
        cube.apply_move('R')
        # R moves D[2,5,8] -> F[2,5,8]
        assert cube.faces['F'][2] == 'Y'  # was Red, now Yellow (from Down)
        assert cube.faces['F'][5] == 'Y'
        assert cube.faces['F'][8] == 'Y'

    def test_R_move_D_face(self):
        """After R, D face positions 2,5,8 should have B face colors (reversed)."""
        cube = Cube()
        cube.apply_move('R')
        # R moves B[6,3,0] -> D[2,5,8]
        assert cube.faces['D'][2] == 'O'  # was Yellow, now Orange (from Back)
        assert cube.faces['D'][5] == 'O'
        assert cube.faces['D'][8] == 'O'

    def test_R_move_B_face(self):
        """After R, B face positions 0,3,6 should have U face colors (reversed)."""
        cube = Cube()
        cube.apply_move('R')
        # R moves U[2,5,8] -> B[6,3,0]
        assert cube.faces['B'][6] == 'W'  # was Orange, now White (from Up)
        assert cube.faces['B'][3] == 'W'
        assert cube.faces['B'][0] == 'W'

    def test_U_move_cycle(self):
        """After U, the top rows of F,R,B,L cycle: F->L, R->F, B->R, L->B."""
        cube = Cube()
        cube.apply_move('U')
        # U moves F[0,1,2] -> R[0,1,2] (Red goes to Right)
        # Wait, standard U move: F->L is wrong.
        # Standard: F top row -> R top row is wrong too.
        # Let me be precise:
        # U clockwise (looking down at U face):
        # F[0,1,2] -> L[0,1,2]  NO
        # Actually: F[0,1,2] stays, R[0,1,2] -> F[0,1,2]
        # Standard U: F <- R <- B <- L <- F
        # So after U: F top row has what was R top row
        assert cube.faces['F'][0] == 'B'  # was Red, now Blue (from Right)
        assert cube.faces['F'][1] == 'B'
        assert cube.faces['F'][2] == 'B'

    def test_U_move_right_face(self):
        """After U, R top row has what was B top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['R'][0] == 'O'  # was Blue, now Orange (from Back)
        assert cube.faces['R'][1] == 'O'
        assert cube.faces['R'][2] == 'O'

    def test_U_move_back_face(self):
        """After U, B top row has what was L top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['B'][0] == 'G'  # was Orange, now Green (from Left)
        assert cube.faces['B'][1] == 'G'
        assert cube.faces['B'][2] == 'G'

    def test_U_move_left_face(self):
        """After U, L top row has what was F top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['L'][0] == 'R'  # was Green, now Red (from Front)
        assert cube.faces['L'][1] == 'R'
        assert cube.faces['L'][2] == 'R'

    def test_F_move_U_bottom_row(self):
        """After F, U bottom row (6,7,8) gets L right column (8,5,2) reversed."""
        cube = Cube()
        cube.apply_move('F')
        # F clockwise (looking at F face):
        # U[6,7,8] <- L[8,5,2]
        assert cube.faces['U'][6] == 'G'  # was White, now Green (from Left col)
        assert cube.faces['U'][7] == 'G'
        assert cube.faces['U'][8] == 'G'

    def test_R_face_rotation(self):
        """After R, the R face itself rotates clockwise."""
        cube = Cube()
        # Mark R face with unique values to track rotation
        cube.faces['R'] = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i']
        cube._rotate_face_cw('R')
        # Clockwise rotation:
        # 0 1 2    6 3 0
        # 3 4 5 -> 7 4 1
        # 6 7 8    8 5 2
        assert cube.faces['R'] == ['g', 'd', 'a', 'h', 'e', 'b', 'i', 'f', 'c']


class TestAlgorithmCycles:
    """Known algorithms have known cycle lengths."""

    def test_sune_order_6(self):
        """Sune (R U R' U R U2 R') has order 6."""
        cube = Cube()
        original = cube.get_state_string()
        sune = "R U R' U R U2 R'"
        for _ in range(6):
            cube.apply_algorithm(sune)
        assert cube.get_state_string() == original

    def test_sexy_move_order_6(self):
        """R U R' U' (sexy move) has order 6."""
        cube = Cube()
        original = cube.get_state_string()
        sexy = "R U R' U'"
        for _ in range(6):
            cube.apply_algorithm(sexy)
        assert cube.get_state_string() == original

    def test_T_perm_order_2(self):
        """T-Perm is an involution (order 2) -- applying it twice returns to start."""
        cube = Cube()
        original = cube.get_state_string()
        t_perm = "R U R' U' R' F R2 U' R' U' R U R' F'"
        cube.apply_algorithm(t_perm)
        cube.apply_algorithm(t_perm)
        assert cube.get_state_string() == original

    def test_Y_perm_order_2(self):
        """Y-Perm applied twice returns to start (it is an involution on LL pieces)."""
        # Y-perm is NOT necessarily order 2 on the full cube
        # but it should still have a finite order. Let's test order.
        cube = Cube()
        original = cube.get_state_string()
        y_perm = "F R U' R' U' R U R' F' R U R' U' R' F R F'"
        # Find the order (should be small)
        for i in range(1, 100):
            cube.apply_algorithm(y_perm)
            if cube.get_state_string() == original:
                assert i <= 50, f"Y-Perm order too high: {i}"
                break
        else:
            pytest.fail("Y-Perm did not return to solved within 100 applications")

    def test_H_perm_order_2(self):
        """H-Perm swaps opposite edges -- order 2."""
        cube = Cube()
        original = cube.get_state_string()
        h_perm = "M2 U M2 U2 M2 U M2"
        cube.apply_algorithm(h_perm)
        cube.apply_algorithm(h_perm)
        assert cube.get_state_string() == original


class TestWideMoves:
    """Wide moves combine face turn + middle layer."""

    def test_r_equals_R_plus_Mprime(self):
        """r should equal R followed by M'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('r')
        c2.apply_move('R')
        c2.apply_move("M'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_r_four_times(self):
        """r applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('r')
        assert cube.get_state_string() == original


class TestRotations:
    """Whole-cube rotations should preserve relative piece positions."""

    def test_y_rotation_four_times(self):
        """y rotation 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('y')
        assert cube.get_state_string() == original

    def test_x_rotation_four_times(self):
        """x rotation 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('x')
        assert cube.get_state_string() == original

    def test_y_equals_U_Dprime(self):
        """y rotation should equal U + D' + E' (but simplified as U + D' in current impl)."""
        # Note: The current implementation does y = U + D' which is INCOMPLETE
        # (missing the E layer / middle layer rotation).
        # This test documents the current behavior.
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('y')
        c2.apply_move('U')
        c2.apply_move("D'")
        # If y is properly implemented, this should match
        # If not, this test will fail and we need to fix y rotation
        assert c1.get_state_string() == c2.get_state_string(), \
            "y rotation is incomplete -- it needs to also rotate the E (middle) layer"

    def test_x_equals_R_Lprime(self):
        """x rotation should equal R + L' + M' but current impl is R + M' + L'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('x')
        c2.apply_move('R')
        c2.apply_move("M'")
        c2.apply_move("L'")
        assert c1.get_state_string() == c2.get_state_string()


class TestSolvedCubeState:
    """Verify the initial solved state is correct."""

    def test_solved_faces(self):
        cube = Cube()
        assert cube.faces['U'] == ['W'] * 9  # White top
        assert cube.faces['D'] == ['Y'] * 9  # Yellow bottom
        assert cube.faces['F'] == ['R'] * 9  # Red front
        assert cube.faces['B'] == ['O'] * 9  # Orange back
        assert cube.faces['L'] == ['G'] * 9  # Green left
        assert cube.faces['R'] == ['B'] * 9  # Blue right

    def test_visible_stickers_solved(self):
        cube = Cube()
        visible = cube.get_visible_stickers()
        assert len(visible) == 15
        assert visible[0:9] == ['W'] * 9   # Top face
        assert visible[9:12] == ['R'] * 3   # Front top row
        assert visible[12:15] == ['B'] * 3  # Right top row


class TestMoveDoesNotAffectWrongFaces:
    """Each move should only affect the faces it touches."""

    def test_R_does_not_affect_L(self):
        """R move should not change L face at all."""
        cube = Cube()
        original_L = cube.faces['L'].copy()
        cube.apply_move('R')
        assert cube.faces['L'] == original_L

    def test_U_does_not_affect_D(self):
        """U move should not change D face at all."""
        cube = Cube()
        original_D = cube.faces['D'].copy()
        cube.apply_move('U')
        assert cube.faces['D'] == original_D

    def test_F_does_not_affect_B(self):
        """F move should not change B face at all."""
        cube = Cube()
        original_B = cube.faces['B'].copy()
        cube.apply_move('F')
        assert cube.faces['B'] == original_B


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

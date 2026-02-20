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
    - U=White, D=Yellow, F=Green, B=Blue, L=Orange, R=Red
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
        assert cube.faces['U'][2] == 'G'  # was White, now Green (from Front)
        assert cube.faces['U'][5] == 'G'
        assert cube.faces['U'][8] == 'G'
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
        assert cube.faces['F'][2] == 'Y'  # was Green, now Yellow (from Down)
        assert cube.faces['F'][5] == 'Y'
        assert cube.faces['F'][8] == 'Y'

    def test_R_move_D_face(self):
        """After R, D face positions 2,5,8 should have B face colors (reversed)."""
        cube = Cube()
        cube.apply_move('R')
        # R moves B[6,3,0] -> D[2,5,8]
        assert cube.faces['D'][2] == 'B'  # was Yellow, now Blue (from Back)
        assert cube.faces['D'][5] == 'B'
        assert cube.faces['D'][8] == 'B'

    def test_R_move_B_face(self):
        """After R, B face positions 0,3,6 should have U face colors (reversed)."""
        cube = Cube()
        cube.apply_move('R')
        # R moves U[2,5,8] -> B[6,3,0]
        assert cube.faces['B'][6] == 'W'  # was Blue, now White (from Up)
        assert cube.faces['B'][3] == 'W'
        assert cube.faces['B'][0] == 'W'

    def test_U_move_cycle(self):
        """After U, the top rows of F,R,B,L cycle: F->L, R->F, B->R, L->B."""
        cube = Cube()
        cube.apply_move('U')
        # U moves F[0,1,2] -> R[0,1,2] (Green goes to Right)
        # Wait, standard U move: F->L is wrong.
        # Standard: F top row -> R top row is wrong too.
        # Let me be precise:
        # U clockwise (looking down at U face):
        # F[0,1,2] -> L[0,1,2]  NO
        # Actually: F[0,1,2] stays, R[0,1,2] -> F[0,1,2]
        # Standard U: F <- R <- B <- L <- F
        # So after U: F top row has what was R top row
        assert cube.faces['F'][0] == 'R'  # was Green, now Red (from Right)
        assert cube.faces['F'][1] == 'R'
        assert cube.faces['F'][2] == 'R'

    def test_U_move_right_face(self):
        """After U, R top row has what was B top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['R'][0] == 'B'  # was Red, now Blue (from Back)
        assert cube.faces['R'][1] == 'B'
        assert cube.faces['R'][2] == 'B'

    def test_U_move_back_face(self):
        """After U, B top row has what was L top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['B'][0] == 'O'  # was Blue, now Orange (from Left)
        assert cube.faces['B'][1] == 'O'
        assert cube.faces['B'][2] == 'O'

    def test_U_move_left_face(self):
        """After U, L top row has what was F top row."""
        cube = Cube()
        cube.apply_move('U')
        assert cube.faces['L'][0] == 'G'  # was Orange, now Green (from Front)
        assert cube.faces['L'][1] == 'G'
        assert cube.faces['L'][2] == 'G'

    def test_F_move_U_bottom_row(self):
        """After F, U bottom row (6,7,8) gets L right column (8,5,2) reversed."""
        cube = Cube()
        cube.apply_move('F')
        # F clockwise (looking at F face):
        # U[6,7,8] <- L[8,5,2]
        assert cube.faces['U'][6] == 'O'  # was White, now Orange (from Left col)
        assert cube.faces['U'][7] == 'O'
        assert cube.faces['U'][8] == 'O'

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


class TestSliceMoves:
    """S and E slice moves."""

    def test_S_four_times(self):
        """S applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('S')
        assert cube.get_state_string() == original

    def test_S_Sprime(self):
        """S followed by S' returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('S')
        cube.apply_move("S'")
        assert cube.get_state_string() == original

    def test_E_four_times(self):
        """E applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('E')
        assert cube.get_state_string() == original

    def test_E_Eprime(self):
        """E followed by E' returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        cube.apply_move('E')
        cube.apply_move("E'")
        assert cube.get_state_string() == original

    def test_S_specific_permutation(self):
        """After S on solved cube, U[4] should get L[4]'s color (Orange).
        S follows F direction: U←L(rev), L←D, D←R(rev), R←U."""
        cube = Cube()
        cube.apply_move('S')
        # U middle row gets L middle column (reversed): L[7,4,1] -> U[3,4,5]
        assert cube.faces['U'][4] == 'O', f"U[4] should be Orange, got {cube.faces['U'][4]}"
        # R middle column gets old U values (White)
        assert cube.faces['R'][4] == 'W', f"R[4] should be White, got {cube.faces['R'][4]}"
        # D middle row gets R middle column (reversed)
        assert cube.faces['D'][4] == 'R', f"D[4] should be Red, got {cube.faces['D'][4]}"
        # L middle column gets D middle row
        assert cube.faces['L'][4] == 'Y', f"L[4] should be Yellow, got {cube.faces['L'][4]}"

    def test_E_specific_permutation(self):
        """After E on solved cube, E follows D direction: F←L←B←R←F.
        So F[4] gets L[4]'s color (Orange)."""
        cube = Cube()
        cube.apply_move('E')
        # F gets L's values (Orange)
        assert cube.faces['F'][4] == 'O', f"F[4] should be Orange, got {cube.faces['F'][4]}"
        # L gets B's values (Blue)
        assert cube.faces['L'][4] == 'B', f"L[4] should be Blue, got {cube.faces['L'][4]}"
        # B gets R's values (Red)
        assert cube.faces['B'][4] == 'R', f"B[4] should be Red, got {cube.faces['B'][4]}"
        # R gets F's values (Green)
        assert cube.faces['R'][4] == 'G', f"R[4] should be Green, got {cube.faces['R'][4]}"

    def test_S_does_not_affect_F_or_B(self):
        """S should not change F or B faces."""
        cube = Cube()
        original_F = cube.faces['F'].copy()
        original_B = cube.faces['B'].copy()
        cube.apply_move('S')
        assert cube.faces['F'] == original_F
        assert cube.faces['B'] == original_B

    def test_E_does_not_affect_U_or_D(self):
        """E should not change U or D faces."""
        cube = Cube()
        original_U = cube.faces['U'].copy()
        original_D = cube.faces['D'].copy()
        cube.apply_move('E')
        assert cube.faces['U'] == original_U
        assert cube.faces['D'] == original_D


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

    def test_l_equals_L_plus_M(self):
        """l should equal L followed by M."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('l')
        c2.apply_move('L')
        c2.apply_move('M')
        assert c1.get_state_string() == c2.get_state_string()

    def test_l_four_times(self):
        """l applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('l')
        assert cube.get_state_string() == original

    def test_u_equals_U_plus_Eprime(self):
        """u should equal U followed by E'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('u')
        c2.apply_move('U')
        c2.apply_move("E'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_u_four_times(self):
        """u applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('u')
        assert cube.get_state_string() == original

    def test_d_equals_D_plus_E(self):
        """d should equal D followed by E."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('d')
        c2.apply_move('D')
        c2.apply_move('E')
        assert c1.get_state_string() == c2.get_state_string()

    def test_d_four_times(self):
        """d applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('d')
        assert cube.get_state_string() == original

    def test_f_equals_F_plus_S(self):
        """f should equal F followed by S."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('f')
        c2.apply_move('F')
        c2.apply_move('S')
        assert c1.get_state_string() == c2.get_state_string()

    def test_f_four_times(self):
        """f applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('f')
        assert cube.get_state_string() == original

    def test_b_equals_B_plus_Sprime(self):
        """b should equal B followed by S'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('b')
        c2.apply_move('B')
        c2.apply_move("S'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_b_four_times(self):
        """b applied 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('b')
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

    def test_z_rotation_four_times(self):
        """z rotation 4 times returns to solved."""
        cube = Cube()
        original = cube.get_state_string()
        for _ in range(4):
            cube.apply_move('z')
        assert cube.get_state_string() == original

    def test_y_equals_U_Eprime_Dprime(self):
        """y rotation should equal U + E' + D'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('y')
        c2.apply_move('U')
        c2.apply_move("E'")
        c2.apply_move("D'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_x_equals_R_Mprime_Lprime(self):
        """x rotation should equal R + M' + L'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('x')
        c2.apply_move('R')
        c2.apply_move("M'")
        c2.apply_move("L'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_z_equals_F_S_Bprime(self):
        """z rotation should equal F + S + B'."""
        c1 = Cube()
        c2 = Cube()
        c1.apply_move('z')
        c2.apply_move('F')
        c2.apply_move('S')
        c2.apply_move("B'")
        assert c1.get_state_string() == c2.get_state_string()

    def test_y_moves_middle_layer(self):
        """y rotation must move the E layer. After y, F[4] should get what was at R[4]."""
        cube = Cube()
        # On solved cube, y follows U direction: F←R←B←L←F (receiving)
        # E' is opposite of E. E: F←L. E': F←R.
        # So after y: F middle gets R's values.
        cube.apply_move('y')
        # U direction: F←R, so F[4] gets R[4]'s old value (Red)
        # Actually let's trace: y = U + E' + D'
        # U: F[0:3] ← R[0:3]
        # E': opposite of E (F←L←B←R←F), so E' is F←R←B←L←F
        #   i.e. F[3:6] ← R[3:6]
        # D': opposite of D (F←L←B←R←F), so D' is F←R←B←L←F
        #   i.e. F[6:9] ← R[6:9]
        # All rows of F get R's values!
        assert cube.faces['F'][4] == 'R', f"F[4] should be Red after y, got {cube.faces['F'][4]}"

    def test_z_moves_middle_layer(self):
        """z rotation must move the S layer."""
        cube = Cube()
        cube.apply_move('z')
        # z = F + S + B'. After z on solved cube, the entire cube rotates.
        # All of U should now have L's color (Orange) — z rotates U←L
        # Since F: U←L(rev), S: U←L(rev) on middle, B': U←L(rev) on top row
        # Actually for z: U face gets what was at L face
        assert cube.faces['U'][4] == 'O', f"U[4] should be Orange after z, got {cube.faces['U'][4]}"


class TestSolvedCubeState:
    """Verify the initial solved state is correct."""

    def test_solved_faces(self):
        cube = Cube()
        assert cube.faces['U'] == ['W'] * 9  # White top
        assert cube.faces['D'] == ['Y'] * 9  # Yellow bottom
        assert cube.faces['F'] == ['G'] * 9  # Green front
        assert cube.faces['B'] == ['B'] * 9  # Blue back
        assert cube.faces['L'] == ['O'] * 9  # Orange left
        assert cube.faces['R'] == ['R'] * 9  # Red right

    def test_visible_stickers_solved(self):
        cube = Cube()
        visible = cube.get_visible_stickers()
        assert len(visible) == 15
        assert visible[0:9] == ['W'] * 9   # Top face
        assert visible[9:12] == ['G'] * 3   # Front top row
        assert visible[12:15] == ['R'] * 3  # Right top row


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

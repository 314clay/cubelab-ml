"""Tests for F2L, ZBLS, and ELL solving paths via solve_from_cube()."""

import pytest
from state_resolver import Cube
from solver import CubeSolver
from phase_detector import PhaseDetector
from algorithms import F2L_CASES, ZBLS_CASES, ELL_CASES


@pytest.fixture(scope="module")
def solver():
    return CubeSolver()


@pytest.fixture(scope="module")
def detector():
    return PhaseDetector()


# ---- Cube inspection methods ----

class TestCubeInspection:
    def test_solved_cube_is_f2l_solved(self):
        c = Cube()
        assert c.is_cross_solved()
        assert c.is_f2l_solved()
        assert c.count_solved_pairs() == 4
        assert c.get_unsolved_slots() == []
        assert c.is_ll_edges_oriented()

    def test_f2l_scramble_breaks_one_pair(self):
        c = Cube()
        c.apply_algorithm("R U R'")
        assert c.is_cross_solved()
        assert c.count_solved_pairs() == 3
        assert c.get_unsolved_slots() == ['FR']
        assert not c.is_f2l_solved()

    def test_cross_scramble(self):
        c = Cube()
        c.apply_algorithm("D R D'")  # Breaks cross
        assert not c.is_cross_solved()

    def test_all_slots_independent(self):
        """Each F2L slot checks independently."""
        for slot in ('FR', 'FL', 'BR', 'BL'):
            c = Cube()
            assert c._is_pair_solved(slot), f"{slot} should be solved on fresh cube"

    def test_ll_edges_oriented_after_pll(self):
        c = Cube()
        c.apply_algorithm("R U R' U' R' F R2 U' R' U' R U R' F'")  # T-Perm
        assert c.is_ll_edges_oriented()  # PLL doesn't break edge orientation

    def test_ll_edges_not_oriented_after_oll(self):
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")  # OLL 45
        assert not c.is_ll_edges_oriented()


# ---- Phase detection with full cube ----

class TestPhaseDetectionFull:
    def test_solved(self, detector):
        c = Cube()
        r = detector.detect_phase_full(c)
        assert r.phase == "solved"

    def test_f2l_last_pair(self, detector):
        c = Cube()
        c.apply_algorithm("R U R'")
        r = detector.detect_phase_full(c)
        assert r.phase == "f2l_last_pair"
        assert "F2L" in r.applicable_sets
        assert "ZBLS" in r.applicable_sets

    def test_oll_phase(self, detector):
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")
        r = detector.detect_phase_full(c)
        assert r.phase == "oll"

    def test_pll_phase(self, detector):
        c = Cube()
        c.apply_algorithm("R U R' U' R' F R2 U' R' U' R U R' F'")
        r = detector.detect_phase_full(c)
        assert r.phase == "pll"

    def test_edges_oriented_phase(self, detector):
        c = Cube()
        c.apply_algorithm("R U2 R' U' R U R' U' R U' R'")  # OLL 21 (edges oriented)
        r = detector.detect_phase_full(c)
        assert r.phase == "oll_edges_oriented"

    def test_f2l_partial_multiple_pairs(self, detector):
        c = Cube()
        c.apply_algorithm("R U R'")  # Break FR
        c.apply_algorithm("L U L'")  # Break FL (actually BL from this angle)
        r = detector.detect_phase_full(c)
        # Might be f2l_last_pair or f2l_partial depending on how many pairs broke
        assert r.phase in ("f2l_last_pair", "f2l_partial")


# ---- F2L solving ----

class TestF2LSolving:
    def test_f2l_case_4_pure(self, solver):
        """F2L case 4 (R U R') should find F2L 4 → Solved."""
        c = Cube()
        c.apply_algorithm("R U R'")
        paths = solver.solve_from_cube(c, max_paths=10)
        assert len(paths) > 0
        # Should find the direct F2L 4 solution
        descs = [p.description for p in paths]
        assert any("F2L 4" in d for d in descs)

    def test_f2l_paths_all_verified(self, solver):
        """Every returned path must actually solve the cube."""
        c = Cube()
        c.apply_algorithm("R U R'")
        paths = solver.solve_from_cube(c, max_paths=10)
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"Path '{p.description}' did not solve the cube"

    def test_f2l_plus_oll(self, solver):
        """F2L scramble + OLL should find F2L → OLL → PLL chain."""
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")  # OLL 45
        c.apply_algorithm("R U R'")           # F2L 4
        paths = solver.solve_from_cube(c, max_paths=10)
        assert len(paths) > 0
        # Should find multi-step path
        multi_step = [p for p in paths if len(p.steps) >= 2]
        assert len(multi_step) > 0, "Should find at least one multi-step path"
        # Verify all
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"Path '{p.description}' did not solve"

    def test_f2l_case_1(self, solver):
        """F2L case 1 (U R U' R')."""
        c = Cube()
        c.apply_algorithm("U R U' R'")
        paths = solver.solve_from_cube(c, max_paths=5)
        assert len(paths) > 0
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved()

    @pytest.mark.parametrize("case_name", ["F2L 1", "F2L 4", "F2L 5", "F2L 9", "F2L 17"])
    def test_f2l_round_trip(self, solver, case_name):
        """Apply F2L alg to create state, solver should find it."""
        alg = F2L_CASES.get(case_name)
        if not alg:
            pytest.skip(f"{case_name} not found")
        c = Cube()
        c.apply_algorithm(alg)
        paths = solver.solve_from_cube(c, max_paths=5)
        assert len(paths) > 0, f"No paths found for {case_name}"
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"Path '{p.description}' for {case_name} didn't solve"


# ---- ZBLS solving ----

class TestZBLSSolving:
    def test_zbls_case_4_pure(self, solver):
        """ZBLS case 4 should find ZBLS → Solved (or ZBLS → LL)."""
        alg = ZBLS_CASES.get("ZBLS 4")
        if not alg:
            pytest.skip("ZBLS 4 not found")
        c = Cube()
        c.apply_algorithm(alg)
        paths = solver.solve_from_cube(c, max_paths=10)
        assert len(paths) > 0
        # Verify all
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"Path '{p.description}' did not solve"

    def test_zbls_finds_zbls_path(self, solver):
        """When ZBLS applies, paths should include ZBLS-labeled steps."""
        c = Cube()
        c.apply_algorithm("R U R'")  # Simple scramble
        paths = solver.solve_from_cube(c, max_paths=10)
        zbls_paths = [p for p in paths if any(s.algorithm_set == "ZBLS" for s in p.steps)]
        # ZBLS paths may or may not exist depending on whether ZBLS alg inverses
        # happen to solve F2L+orient edges for this state
        # But for R U R', ZBLS 4 = "R U R'" so its inverse should work
        assert len(zbls_paths) > 0, "Should find ZBLS paths for F2L 4 state"

    def test_zbls_paths_verified(self, solver):
        """All ZBLS paths must solve the cube."""
        alg = ZBLS_CASES.get("ZBLS 1")
        if not alg:
            pytest.skip("ZBLS 1 not found")
        c = Cube()
        c.apply_algorithm(alg)
        paths = solver.solve_from_cube(c, max_paths=10)
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"ZBLS path '{p.description}' did not solve"


# ---- Solution tree structure ----

class TestSolutionTree:
    def test_paths_ranked_by_moves(self, solver):
        c = Cube()
        c.apply_algorithm("R U R'")
        paths = solver.solve_from_cube(c, max_paths=10)
        for i in range(len(paths) - 1):
            assert paths[i].total_moves <= paths[i + 1].total_moves

    def test_f2l_step_labels(self, solver):
        """F2L steps should have correct algorithm_set label."""
        c = Cube()
        c.apply_algorithm("R U R'")
        paths = solver.solve_from_cube(c, max_paths=5)
        f2l_paths = [p for p in paths if p.steps[0].algorithm_set == "F2L"]
        assert len(f2l_paths) > 0
        for p in f2l_paths:
            assert p.steps[0].phase_before == "f2l_last_pair"

    def test_ll_delegation_for_oll_state(self, solver):
        """OLL state should delegate to existing 15-sticker solver."""
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")
        paths = solver.solve_from_cube(c, max_paths=5)
        assert len(paths) > 0
        assert all(s.algorithm_set in ("OLL", "OLLCP", "PLL") for p in paths for s in p.steps)

    def test_solved_returns_empty(self, solver):
        c = Cube()
        paths = solver.solve_from_cube(c)
        assert paths == []

    def test_ll_delegation_for_ell_state(self, solver):
        """ELL state should find ELL solutions."""
        c = Cube()
        c.apply_algorithm(ELL_CASES["ELL 8"])
        paths = solver.solve_from_cube(c, max_paths=5)
        assert len(paths) > 0
        assert any(s.algorithm_set == "ELL" for p in paths for s in p.steps)


# ---- Cube corner inspection ----

class TestCubeCornerInspection:
    def test_solved_cube_corners_solved(self):
        c = Cube()
        assert c.is_ll_corners_solved()

    def test_ell_state_corners_solved(self):
        """ELL algs only move edges — corners should remain solved."""
        for name in ["ELL 1", "ELL 8", "ELL 22"]:
            alg = ELL_CASES.get(name)
            if not alg:
                continue
            c = Cube()
            c.apply_algorithm(alg)
            assert c.is_ll_corners_solved(), f"{name} should leave corners solved"
            assert not c.is_solved(), f"{name} should not leave cube solved"

    def test_oll_state_corners_not_solved(self):
        """OLL scramble disrupts corners."""
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")  # OLL 45
        assert not c.is_ll_corners_solved()

    def test_pll_state_corners_may_be_unsolved(self):
        """T-Perm disrupts corner permutation."""
        c = Cube()
        c.apply_algorithm("R U R' U' R' F R2 U' R' U' R U R' F'")  # T-Perm
        assert not c.is_ll_corners_solved()


# ---- ELL phase detection ----

class TestELLPhaseDetection:
    def test_ell_phase_detected(self, detector):
        """ELL state should be detected as ell phase."""
        c = Cube()
        c.apply_algorithm(ELL_CASES["ELL 8"])
        r = detector.detect_phase_full(c)
        assert r.phase == "ell"
        assert "ELL" in r.applicable_sets

    def test_epll_detected_as_pll_with_ell(self, detector):
        """EPLL cases (ELL 4-7) have top oriented → pll phase, but ELL applicable."""
        c = Cube()
        c.apply_algorithm(ELL_CASES["ELL 4"])  # U-PLL a
        r = detector.detect_phase_full(c)
        assert r.phase == "pll"
        assert "ELL" in r.applicable_sets

    def test_ell_not_detected_for_oll(self, detector):
        """OLL state should NOT be detected as ell."""
        c = Cube()
        c.apply_algorithm("F R U R' U' F'")
        r = detector.detect_phase_full(c)
        assert r.phase == "oll"


# ---- ELL solving ----

class TestELLSolving:
    @pytest.mark.parametrize("case_name", [
        "ELL 1", "ELL 4", "ELL 8", "ELL 14", "ELL 22", "ELL 28",
    ])
    def test_ell_round_trip(self, solver, case_name):
        """Apply ELL alg, solver should find a path back to solved."""
        alg = ELL_CASES.get(case_name)
        if not alg:
            pytest.skip(f"{case_name} not found")
        c = Cube()
        c.apply_algorithm(alg)
        paths = solver.solve_from_cube(c, max_paths=5)
        assert len(paths) > 0, f"No paths found for {case_name}"
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved(), f"Path '{p.description}' for {case_name} didn't solve"

    def test_ell_finds_ell_labeled_path(self, solver):
        """ELL solutions should include ELL-labeled steps."""
        c = Cube()
        c.apply_algorithm(ELL_CASES["ELL 1"])
        paths = solver.solve_from_cube(c, max_paths=5)
        ell_paths = [p for p in paths if any(s.algorithm_set == "ELL" for s in p.steps)]
        assert len(ell_paths) > 0, "Should find ELL-labeled paths"

    def test_ell_via_15_sticker_solve(self, solver):
        """ELL should also be found via 15-sticker solve()."""
        c = Cube()
        c.apply_algorithm(ELL_CASES["ELL 8"])
        visible = c.get_visible_stickers()
        paths = solver.solve(visible, max_paths=5)
        assert len(paths) > 0
        for p in paths:
            v = c.copy()
            for s in p.steps:
                v.apply_algorithm(s.algorithm)
            assert v.is_solved()

    def test_all_ell_cases_executable(self):
        """Every ELL algorithm should execute without error."""
        for name, alg in ELL_CASES.items():
            c = Cube()
            c.apply_algorithm(alg)
            assert c.is_f2l_solved(), f"{name} should not break F2L"

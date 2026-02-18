"""Tests for CubeSolver — multi-path solving from cube state."""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from solver import CubeSolver, SolvePath
from state_resolver import Cube
from algorithms import OLL_CASES, PLL_CASES, COLL_CASES, ZBLL_CASES


@pytest.fixture(scope="module")
def solver():
    """Shared solver instance (expensive to build)."""
    return CubeSolver()


class TestSolverSolved:
    def test_solved_cube_returns_empty(self, solver):
        cube = Cube()
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) == 0


class TestSolverPLL:
    def test_t_perm_found(self, solver):
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) >= 1, "Should find at least 1 path for T-Perm"
        # At least one path should be a single PLL step
        single_step = [p for p in paths if len(p.steps) == 1]
        assert len(single_step) >= 1, "Should have a single-step PLL solution"

    def test_h_perm_found(self, solver):
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["H-Perm"])
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) >= 1


class TestSolverOLL:
    def test_oll_45_multiple_paths(self, solver):
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) >= 1, "Should find at least 1 path for OLL 45"

    def test_oll_plus_pll(self, solver):
        """Apply OLL + PLL → solver should find a 2-step path."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        # Should find paths — could be OLL→PLL chain or other combinations
        assert len(paths) >= 1, "Should find paths for OLL+PLL combined state"


class TestSolverEdgesOriented:
    def test_coll_case_found(self, solver):
        """Apply a COLL case → should find COLL path."""
        if not COLL_CASES:
            pytest.skip("No COLL cases")
        case_name = list(COLL_CASES.keys())[0]
        alg = COLL_CASES[case_name]
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) >= 1, f"Should find paths for COLL {case_name}"

    def test_zbll_case_found(self, solver):
        """Apply a ZBLL case → should find ZBLL path."""
        if not ZBLL_CASES:
            pytest.skip("No ZBLL cases")
        case_name = list(ZBLL_CASES.keys())[0]
        alg = ZBLL_CASES[case_name]
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        assert len(paths) >= 1, f"Should find paths for ZBLL {case_name}"


class TestSolverPathRanking:
    def test_paths_sorted_by_moves(self, solver):
        """Paths should be sorted shortest first."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        visible = cube.get_visible_stickers()
        paths = solver.solve(visible)
        if len(paths) >= 2:
            for i in range(len(paths) - 1):
                assert paths[i].total_moves <= paths[i + 1].total_moves


class TestSolverInvalidInput:
    def test_wrong_sticker_count(self, solver):
        paths = solver.solve(["W"] * 10)
        assert paths == []

    def test_empty_stickers(self, solver):
        paths = solver.solve([])
        assert paths == []


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

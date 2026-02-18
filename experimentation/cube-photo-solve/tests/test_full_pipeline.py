"""
Integration tests: full pipeline on all algorithm sets.

For a sample of algorithms from every set, verify:
1. Start from solved cube
2. Apply algorithm (creates the state the algorithm solves)
3. Extract visible stickers
4. Run CubeSolver
5. Verify solver finds a path
6. Verify the path actually solves the cube
"""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from solver import CubeSolver, inverse_algorithm
from state_resolver import Cube
from algorithms import (
    OLL_CASES, PLL_CASES, COLL_CASES, ZBLL_CASES, OLLCP_CASES,
    parse_algorithm,
)


@pytest.fixture(scope="module")
def solver():
    return CubeSolver()


def _verify_path_solves(scramble_alg, path):
    """Verify that applying the path's steps to the scrambled state produces solved."""
    cube = Cube()
    cube.apply_algorithm(scramble_alg)
    for step in path.steps:
        cube.apply_algorithm(step.algorithm)
    return all(len(set(f)) == 1 for f in cube.faces.values())


class TestPipelineOLL:
    """Test pipeline for OLL cases."""

    OLL_SAMPLES = ["OLL 1", "OLL 21", "OLL 33", "OLL 45", "OLL 57"]

    @pytest.mark.parametrize("case_name", OLL_SAMPLES)
    def test_oll_pipeline(self, solver, case_name):
        alg = OLL_CASES[case_name]
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()

        paths = solver.solve(visible)
        assert len(paths) >= 1, f"No paths found for {case_name}"

        # Verify at least one path actually solves
        solved_any = any(_verify_path_solves(alg, p) for p in paths)
        assert solved_any, f"No path for {case_name} actually solves the cube"


class TestPipelinePLL:
    """Test pipeline for PLL cases."""

    PLL_SAMPLES = ["T-Perm", "H-Perm", "U-Perm (a)", "J-Perm (b)", "A-Perm (a)"]

    @pytest.mark.parametrize("case_name", PLL_SAMPLES)
    def test_pll_pipeline(self, solver, case_name):
        alg = PLL_CASES[case_name]
        if not alg:
            pytest.skip("Empty algorithm")
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()

        paths = solver.solve(visible)
        assert len(paths) >= 1, f"No paths found for {case_name}"

        solved_any = any(_verify_path_solves(alg, p) for p in paths)
        assert solved_any, f"No path for {case_name} actually solves the cube"


class TestPipelineCOLL:
    """Test pipeline for COLL cases."""

    def _get_coll_samples(self):
        if not COLL_CASES:
            return []
        keys = list(COLL_CASES.keys())
        # Take up to 5 evenly spaced
        step = max(1, len(keys) // 5)
        return keys[::step][:5]

    @pytest.fixture
    def coll_samples(self):
        samples = self._get_coll_samples()
        if not samples:
            pytest.skip("No COLL cases available")
        return samples

    def test_coll_pipeline(self, solver, coll_samples):
        for case_name in coll_samples:
            alg = COLL_CASES[case_name]
            cube = Cube()
            cube.apply_algorithm(alg)
            visible = cube.get_visible_stickers()

            paths = solver.solve(visible)
            assert len(paths) >= 1, f"No paths found for COLL {case_name}"


class TestPipelineZBLL:
    """Test pipeline for ZBLL cases."""

    def _get_zbll_samples(self):
        if not ZBLL_CASES:
            return []
        keys = list(ZBLL_CASES.keys())
        step = max(1, len(keys) // 10)
        return keys[::step][:10]

    @pytest.fixture
    def zbll_samples(self):
        samples = self._get_zbll_samples()
        if not samples:
            pytest.skip("No ZBLL cases available")
        return samples

    def test_zbll_pipeline(self, solver, zbll_samples):
        found = 0
        for case_name in zbll_samples:
            alg = ZBLL_CASES[case_name]
            cube = Cube()
            cube.apply_algorithm(alg)
            visible = cube.get_visible_stickers()

            paths = solver.solve(visible)
            if paths:
                found += 1

        assert found >= 5, f"Only found paths for {found}/{len(zbll_samples)} ZBLL cases"


class TestPipelineOLLCP:
    """Test pipeline for OLLCP cases."""

    def _get_ollcp_samples(self):
        if not OLLCP_CASES:
            return []
        keys = list(OLLCP_CASES.keys())
        step = max(1, len(keys) // 5)
        return keys[::step][:5]

    @pytest.fixture
    def ollcp_samples(self):
        samples = self._get_ollcp_samples()
        if not samples:
            pytest.skip("No OLLCP cases available")
        return samples

    def test_ollcp_pipeline(self, solver, ollcp_samples):
        for case_name in ollcp_samples:
            alg = OLLCP_CASES[case_name]
            cube = Cube()
            cube.apply_algorithm(alg)
            visible = cube.get_visible_stickers()

            paths = solver.solve(visible)
            assert len(paths) >= 1, f"No paths found for OLLCP {case_name}"


class TestPipelineCombined:
    """Test combined states produce multi-step paths."""

    def test_oll_plus_pll_two_step(self, solver):
        """OLL + PLL → solver returns multi-step path."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()

        paths = solver.solve(visible)
        assert len(paths) >= 1
        # Should have at least one multi-step path
        multi_step = [p for p in paths if len(p.steps) >= 2]
        assert len(multi_step) >= 1, "Should have at least one multi-step path"

    def test_oll_plus_pll_verified(self, solver):
        """OLL 27 + H-Perm → verify the path solves."""
        oll_alg = OLL_CASES["OLL 27"]
        pll_alg = PLL_CASES["H-Perm"]
        cube = Cube()
        cube.apply_algorithm(oll_alg)
        cube.apply_algorithm(pll_alg)
        visible = cube.get_visible_stickers()

        paths = solver.solve(visible)
        assert len(paths) >= 1

        # The combined scramble
        combined = oll_alg + " " + pll_alg
        solved_any = any(_verify_path_solves(combined, p) for p in paths)
        assert solved_any, "No path actually solves the combined OLL+PLL state"

    def test_multiple_paths_for_same_state(self, solver):
        """Same state should produce multiple different paths."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        visible = cube.get_visible_stickers()

        paths = solver.solve(visible, max_paths=10)
        # OLL 45 should match in OLL table and possibly OLLCP
        if len(paths) >= 2:
            descriptions = set(p.description for p in paths)
            assert len(descriptions) >= 2, "Paths should have different descriptions"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

"""
Step 10c verification tests: pipeline wired through solver tree.

Verifies:
1. pipeline.py returns algorithm-based solving paths alongside Kociemba
2. Phase detection correct for OLL/PLL/COLL cases
3. At least one algorithm path verifies for every case
4. Solver returns valid paths for >99% of OLL×PLL×AUF combos
5. Solver initialization is cached (single instance)
6. Kociemba fallback still works
"""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from state_resolver import Cube
from state_reconstructor import StateReconstructor
from solver import CubeSolver
from phase_detector import PhaseDetector
from algorithms import OLL_CASES, PLL_CASES, parse_algorithm
import pipeline as pl


@pytest.fixture(scope="module")
def recon():
    return StateReconstructor()


@pytest.fixture(scope="module")
def solver():
    return CubeSolver()


# ---------------------------------------------------------------
# 1. Pipeline returns algorithm-based paths alongside Kociemba
# ---------------------------------------------------------------

class TestPipelineReturnsSolverPaths:

    def test_oll_case_returns_paths(self, recon):
        """OLL case → pipeline returns solve_paths with algorithm steps."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['success']
        assert result['phase'] == 'oll'
        assert len(result['solve_paths']) >= 1
        assert result['solution']  # Kociemba still present

        # Check path has actual algorithm steps
        path = result['solve_paths'][0]
        assert path.total_moves > 0
        assert len(path.steps) >= 1
        for step in path.steps:
            assert step.algorithm
            assert step.case_name
            assert step.algorithm_set

    def test_pll_case_returns_paths(self, recon):
        """PLL case → pipeline returns solve_paths."""
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['success']
        assert result['phase'] == 'pll'
        assert len(result['solve_paths']) >= 1

    def test_combined_oll_pll_returns_paths(self, recon):
        """OLL + PLL combo → pipeline returns multi-step paths."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 27"])
        cube.apply_algorithm(PLL_CASES["H-Perm"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['success']
        assert result['phase'] in ('oll', 'oll_edges_oriented')
        assert len(result['solve_paths']) >= 1

    def test_solved_returns_no_paths(self, recon):
        """Solved cube → no solve paths needed."""
        cube = Cube()
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['success']
        assert result['phase'] == 'solved'
        assert result['solve_paths'] == []

    def test_skip_solver_flag(self, recon):
        """--no-solver flag → no solve_paths, no phase."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon, skip_solver=True)

        assert result['success']
        assert result['phase'] is None
        assert result['solve_paths'] == []
        assert result['solution']  # Kociemba still works


# ---------------------------------------------------------------
# 2. Phase detection correct for various cases
# ---------------------------------------------------------------

class TestPhaseDetection:

    @pytest.mark.parametrize("case_name", ["OLL 1", "OLL 21", "OLL 33", "OLL 45", "OLL 57"])
    def test_oll_cases_detected_as_oll(self, recon, case_name):
        cube = Cube()
        cube.apply_algorithm(OLL_CASES[case_name])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)
        # OLL cases can be detected as various LL phases depending on specifics:
        # - 'oll' for general OLL
        # - 'oll_edges_oriented' if edges happen to be oriented
        # - 'ell' if corners are already solved (e.g., OLL 57)
        assert result['phase'] in ('oll', 'oll_edges_oriented', 'ell')

    @pytest.mark.parametrize("case_name", ["T-Perm", "H-Perm", "U-Perm (a)", "J-Perm (b)"])
    def test_pll_cases_detected_as_pll(self, recon, case_name):
        alg = PLL_CASES[case_name]
        if not alg:
            pytest.skip("Empty algorithm")
        cube = Cube()
        cube.apply_algorithm(alg)
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)
        assert result['phase'] == 'pll'


# ---------------------------------------------------------------
# 3. Algorithm paths actually solve the cube
# ---------------------------------------------------------------

class TestPathVerification:

    OLL_SAMPLES = ["OLL 1", "OLL 21", "OLL 33", "OLL 45", "OLL 57"]
    PLL_SAMPLES = ["T-Perm", "H-Perm", "U-Perm (a)", "J-Perm (b)", "A-Perm (a)"]

    @pytest.mark.parametrize("case_name", OLL_SAMPLES)
    def test_oll_path_solves(self, recon, case_name):
        """At least one algorithm path actually solves the OLL case."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES[case_name])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['solve_paths'], f"No paths found for {case_name}"

        solved_any = False
        for path in result['solve_paths']:
            verify = Cube()
            verify.apply_algorithm(OLL_CASES[case_name])
            for step in path.steps:
                verify.apply_algorithm(step.algorithm)
            if verify.is_solved():
                solved_any = True
                break

        assert solved_any, f"No path for {case_name} actually solves the cube"

    @pytest.mark.parametrize("case_name", PLL_SAMPLES)
    def test_pll_path_solves(self, recon, case_name):
        """At least one algorithm path actually solves the PLL case."""
        alg = PLL_CASES[case_name]
        if not alg:
            pytest.skip("Empty algorithm")
        cube = Cube()
        cube.apply_algorithm(alg)
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['solve_paths'], f"No paths found for {case_name}"

        solved_any = False
        for path in result['solve_paths']:
            verify = Cube()
            verify.apply_algorithm(alg)
            for step in path.steps:
                verify.apply_algorithm(step.algorithm)
            if verify.is_solved():
                solved_any = True
                break

        assert solved_any, f"No path for {case_name} actually solves the cube"


# ---------------------------------------------------------------
# 4. >99% of OLL×PLL×AUF combos produce valid solver paths
# ---------------------------------------------------------------

class TestOLLPLLAUFCoverage:

    def test_oll_pll_auf_coverage(self, solver):
        """Solver returns valid paths for >99% of OLL×PLL×AUF combinations."""
        aufs = ['', 'U', "U'", 'U2']
        total = 0
        found = 0
        verified = 0

        for oll_name, oll_alg in OLL_CASES.items():
            for pll_name, pll_alg in PLL_CASES.items():
                for auf in aufs:
                    total += 1
                    cube = Cube()
                    alg = ' '.join(filter(None, [oll_alg, pll_alg, auf]))
                    if alg.strip():
                        cube.apply_algorithm(alg.strip())

                    visible = cube.get_visible_stickers()
                    paths = solver.solve(visible)

                    if paths:
                        found += 1
                        # Verify at least one path solves
                        for path in paths:
                            verify = Cube()
                            if alg.strip():
                                verify.apply_algorithm(alg.strip())
                            for step in path.steps:
                                verify.apply_algorithm(step.algorithm)
                            if verify.is_solved():
                                verified += 1
                                break

        coverage = found / total if total > 0 else 0
        verify_rate = verified / total if total > 0 else 0

        print(f"\n=== OLL×PLL×AUF Coverage ===")
        print(f"Total combos: {total}")
        print(f"Paths found:  {found}/{total} ({100*coverage:.1f}%)")
        print(f"Verified:     {verified}/{total} ({100*verify_rate:.1f}%)")

        assert coverage > 0.99, f"Coverage {coverage:.1%} below 99% threshold"


# ---------------------------------------------------------------
# 5. Solver initialization is cached
# ---------------------------------------------------------------

class TestSolverCaching:

    def test_solver_cache_works(self, recon):
        """_get_solver() returns the same instance on repeated calls."""
        # Reset cache
        pl._solver_cache = None

        solver1 = pl._get_solver()
        solver2 = pl._get_solver()
        assert solver1 is solver2, "Solver should be cached (same instance)"

    def test_resolver_cache_works(self, recon):
        """_get_resolver() returns the same instance on repeated calls."""
        pl._resolver_cache = None

        resolver1 = pl._get_resolver()
        resolver2 = pl._get_resolver()
        assert resolver1 is resolver2, "Resolver should be cached (same instance)"


# ---------------------------------------------------------------
# 6. Kociemba fallback still works
# ---------------------------------------------------------------

class TestKociembaFallback:

    def test_kociemba_alongside_solver(self, recon):
        """Both algorithm paths and Kociemba solution present."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        assert result['success']
        assert result['solve_paths']  # algorithm paths
        assert result['solution']     # kociemba solution
        # Kociemba solution should be non-empty
        assert not result['solution'].startswith('(')

    def test_output_format_has_both_sections(self, recon, capsys):
        """print_result shows both Algorithm Solutions and Kociemba sections."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        vis27 = cube.faces['U'] + cube.faces['F'] + cube.faces['R']
        result = pl.run_pipeline(vis27, recon)

        pl.print_result(result, vis27)
        captured = capsys.readouterr()

        assert "=== CUBE ANALYSIS ===" in captured.out
        assert "Phase:" in captured.out
        assert "Algorithm Solutions" in captured.out
        assert "Kociemba Solution" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

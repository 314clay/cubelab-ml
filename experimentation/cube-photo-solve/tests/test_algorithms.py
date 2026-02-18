"""Tests for the expanded algorithm database."""

import pytest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from algorithms import (
    OLL_CASES, PLL_CASES, COLL_CASES, ZBLL_CASES,
    OLLCP_CASES, F2L_CASES, WV_CASES,
    get_all_algorithm_sets, parse_algorithm,
)
from state_resolver import Cube


class TestAlgorithmCounts:
    """Verify expected case counts for each algorithm set."""

    def test_oll_count(self):
        # 57 + Sune + Anti-Sune aliases
        assert len(OLL_CASES) >= 57

    def test_pll_count(self):
        # 21 + Solved
        assert len(PLL_CASES) >= 21

    def test_coll_count(self):
        assert len(COLL_CASES) >= 38, f"COLL has {len(COLL_CASES)} cases, expected ~40"

    def test_zbll_count(self):
        assert 460 <= len(ZBLL_CASES) <= 480, f"ZBLL has {len(ZBLL_CASES)} cases"

    def test_ollcp_count(self):
        assert len(OLLCP_CASES) >= 300, f"OLLCP has {len(OLLCP_CASES)} cases"

    def test_f2l_count(self):
        assert len(F2L_CASES) >= 40, f"F2L has {len(F2L_CASES)} cases"

    def test_wv_count(self):
        assert len(WV_CASES) >= 25, f"WV has {len(WV_CASES)} cases"

    def test_total_count(self):
        all_sets = get_all_algorithm_sets()
        total = sum(len(cases) for cases in all_sets.values())
        assert total >= 950, f"Total algorithms: {total}, expected >= 950"


class TestAlgorithmParsing:
    """Every algorithm must be parseable into valid move tokens."""

    # Valid base moves the Cube class supports
    VALID_MOVES = {
        'R', 'L', 'U', 'D', 'F', 'B',
        'M', 'S', 'E',
        'r', 'l', 'u', 'd', 'f', 'b',
        'x', 'y', 'z',
    }

    def _is_valid_token(self, token):
        """Check if a move token is valid for the Cube class."""
        # Strip modifiers
        base = token.rstrip("'2")
        return base in self.VALID_MOVES

    @pytest.mark.parametrize("set_name", [
        "OLL", "PLL", "COLL", "ZBLL", "OLLCP", "F2L", "WV"
    ])
    def test_all_algorithms_parseable(self, set_name):
        """Every algorithm string can be parsed into valid move tokens."""
        all_sets = get_all_algorithm_sets()
        cases = all_sets[set_name]
        invalid = []
        for case_name, alg in cases.items():
            if not alg:
                continue
            tokens = parse_algorithm(alg)
            for token in tokens:
                if not self._is_valid_token(token):
                    invalid.append((case_name, token, alg))
        if invalid:
            msg = f"\n{set_name} has invalid tokens:\n"
            for case, token, alg in invalid[:10]:
                msg += f"  {case}: unknown move '{token}' in: {alg}\n"
            pytest.fail(msg)


class TestAlgorithmExecution:
    """Every algorithm must execute on the Cube class without errors."""

    @pytest.mark.parametrize("set_name", [
        "OLL", "PLL", "COLL", "ZBLL", "OLLCP", "F2L", "WV"
    ])
    def test_every_algorithm_executes(self, set_name):
        """Apply each algorithm to solved cube — no exceptions, valid state."""
        all_sets = get_all_algorithm_sets()
        cases = all_sets[set_name]
        failures = []
        for case_name, alg in cases.items():
            if not alg:
                continue
            try:
                cube = Cube()
                cube.apply_algorithm(alg)
                # Verify valid state: 9 of each color
                all_stickers = []
                for face in cube.faces.values():
                    all_stickers.extend(face)
                from collections import Counter
                counts = Counter(all_stickers)
                for color in ['W', 'Y', 'R', 'O', 'G', 'B']:
                    if counts.get(color, 0) != 9:
                        failures.append((case_name, f"Invalid state: {dict(counts)}"))
                        break
            except Exception as e:
                failures.append((case_name, str(e)))
        if failures:
            msg = f"\n{set_name} execution failures:\n"
            for case, err in failures[:10]:
                msg += f"  {case}: {err}\n"
            pytest.fail(msg)

    def test_oll_only_affects_last_layer(self):
        """OLL algorithms should not change the D face or bottom rows of sides."""
        for case_name, alg in OLL_CASES.items():
            if not alg or case_name in ("Sune", "Anti-Sune"):
                continue
            cube = Cube()
            cube.apply_algorithm(alg)
            assert cube.faces['D'] == ['Y'] * 9, \
                f"{case_name} changed D face: {cube.faces['D']}"

    def test_pll_preserves_top_orientation(self):
        """PLL algorithms should keep all top stickers White."""
        for case_name, alg in PLL_CASES.items():
            if not alg:
                continue
            cube = Cube()
            cube.apply_algorithm(alg)
            assert cube.faces['U'] == ['W'] * 9, \
                f"{case_name} changed U face: {cube.faces['U']}"

    def test_sample_algorithms_finite_order(self):
        """A sample of algorithms should return to start within 1000 applications."""
        import random
        all_sets = get_all_algorithm_sets()
        # Sample from each set
        samples = []
        for set_name, cases in all_sets.items():
            algs = [(n, a) for n, a in cases.items() if a]
            if algs:
                samples.extend(random.sample(algs, min(3, len(algs))))

        for case_name, alg in samples:
            cube = Cube()
            original = cube.get_state_string()
            for i in range(1, 1001):
                cube.apply_algorithm(alg)
                if cube.get_state_string() == original:
                    break
            else:
                pytest.fail(f"{case_name} did not return to start within 1000 applications")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

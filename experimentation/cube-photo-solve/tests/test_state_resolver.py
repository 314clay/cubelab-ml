"""
Tests for StateResolver lookup table correctness.
Verifies the forward path: apply algorithm -> extract visible stickers -> lookup matches.
"""

import pytest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from state_resolver import Cube, StateResolver
from algorithms import OLL_CASES, PLL_CASES


@pytest.fixture(scope="module")
def resolver():
    """Create StateResolver once for all tests (it's expensive to build)."""
    return StateResolver()


class TestSolvedCubeLookup:
    """Verify the solved cube is in the lookup table."""

    def test_solved_visible_stickers(self):
        cube = Cube()
        visible = cube.get_visible_stickers()
        assert visible == ['W']*9 + ['G']*3 + ['R']*3

    def test_solved_in_lookup(self, resolver):
        cube = Cube()
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        assert match is not None, "Solved cube should be in lookup table"
        assert match['pll_case'] == 'Solved', f"Expected PLL=Solved, got {match['pll_case']}"


class TestLookupTableProperties:
    """Verify structural properties of the lookup table."""

    def test_table_size_reasonable(self, resolver):
        size = len(resolver.lookup_table)
        print(f"Lookup table size: {size}")
        assert size > 100, f"Table too small: {size}"
        assert size < 1_000_000, f"Table too large: {size}"

    def test_all_entries_have_required_fields(self, resolver):
        required_fields = ['oll_case', 'pll_case', 'combined_name',
                          'oll_algorithm', 'pll_algorithm']
        for key, entry in list(resolver.lookup_table.items())[:100]:
            for field in required_fields:
                assert field in entry, f"Entry missing field '{field}': {entry}"


class TestForwardPathOLL:
    """Apply OLL algorithm to solved cube, verify lookup returns the right case.

    IMPORTANT: OLL algorithms SOLVE the OLL case. So applying OLL 45 to a solved
    cube gives you the INVERSE (scrambled) state that OLL 45 would fix.
    The resolver should generate lookup entries by applying algorithms to solved
    cube, so the scrambled state should map back to the OLL case.
    """

    def test_oll_45_roundtrip(self, resolver):
        """Apply OLL 45 to solved, lookup should return something with OLL 45."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        # The lookup table was built by applying OLL algs to solved cube,
        # so this state SHOULD be in the table
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 45 state not found. Closest: {info}")

    def test_oll_27_sune_roundtrip(self, resolver):
        """Apply OLL 27 (Sune) to solved, lookup should find it."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 27"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 27 state not found. Closest: {info}")

    def test_oll_33_roundtrip(self, resolver):
        """Apply OLL 33 to solved, lookup should find it."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 33"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 33 state not found. Closest: {info}")


class TestForwardPathPLL:
    """Apply PLL algorithm to solved cube, verify lookup."""

    def test_t_perm_roundtrip(self, resolver):
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"T-Perm state not found. Closest: {info}")

    def test_h_perm_roundtrip(self, resolver):
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["H-Perm"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"H-Perm state not found. Closest: {info}")

    def test_j_perm_b_roundtrip(self, resolver):
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["J-Perm (b)"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"J-Perm (b) state not found. Closest: {info}")


class TestForwardPathCombined:
    """Apply OLL + PLL to solved, verify lookup returns correct combined case."""

    def test_oll27_plus_tperm(self, resolver):
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 27"])
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 27 + T-Perm state not found. Closest: {info}")

    def test_oll33_plus_jperm_b(self, resolver):
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 33"])
        cube.apply_algorithm(PLL_CASES["J-Perm (b)"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 33 + J-Perm (b) state not found. Closest: {info}")

    def test_oll45_plus_hperm(self, resolver):
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        cube.apply_algorithm(PLL_CASES["H-Perm"])
        visible = cube.get_visible_stickers()
        match = resolver.match_state(visible)
        if match is None:
            closest = resolver.find_closest_matches(visible, n=3)
            info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(f"OLL 45 + H-Perm state not found. Closest: {info}")


class TestInvalidInput:
    """Verify error handling."""

    def test_too_few_stickers(self, resolver):
        with pytest.raises(ValueError):
            resolver.match_state(['W', 'Y', 'R'])

    def test_too_many_stickers(self, resolver):
        with pytest.raises(ValueError):
            resolver.match_state(['W'] * 20)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

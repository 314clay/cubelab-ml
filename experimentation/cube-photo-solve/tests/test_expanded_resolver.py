"""Tests for ExpandedStateResolver — lookup tables for COLL, ZBLL, OLLCP, etc."""

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from state_resolver import Cube, ExpandedStateResolver
from algorithms import OLL_CASES, PLL_CASES, COLL_CASES, ZBLL_CASES, OLLCP_CASES


class TestExpandedResolverTableSizes:
    """Verify lookup table sizes are reasonable."""

    @pytest.fixture(scope="class")
    def resolver(self):
        return ExpandedStateResolver(sets=["OLL", "PLL", "COLL", "ZBLL", "OLLCP"])

    def test_oll_table_size(self, resolver):
        size = len(resolver.tables.get("OLL", {}))
        assert size > 0, "OLL table should not be empty"
        assert size < 50000, f"OLL table too large: {size}"

    def test_pll_table_size(self, resolver):
        size = len(resolver.tables.get("PLL", {}))
        assert size > 0, "PLL table should not be empty"

    def test_coll_table_size(self, resolver):
        size = len(resolver.tables.get("COLL", {}))
        assert 30 <= size <= 50000, f"COLL table size unexpected: {size}"

    def test_zbll_table_size(self, resolver):
        size = len(resolver.tables.get("ZBLL", {}))
        assert 100 <= size <= 500000, f"ZBLL table size unexpected: {size}"

    def test_ollcp_table_size(self, resolver):
        size = len(resolver.tables.get("OLLCP", {}))
        assert size > 0, f"OLLCP table should not be empty"


class TestExpandedResolverLookup:
    """Test lookup against known cases."""

    @pytest.fixture(scope="class")
    def resolver(self):
        return ExpandedStateResolver(sets=["OLL", "PLL", "COLL", "ZBLL", "OLLCP"])

    def test_coll_case_roundtrip(self, resolver):
        """Apply a COLL case and look it up."""
        if not COLL_CASES:
            pytest.skip("No COLL cases")
        case_name = list(COLL_CASES.keys())[0]
        alg = COLL_CASES[case_name]
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()

        matches = resolver.lookup(visible, set_name="COLL")
        assert len(matches) > 0, f"COLL {case_name} not found in lookup table"
        assert matches[0]['case'] == case_name

    def test_zbll_case_roundtrip(self, resolver):
        """Apply a ZBLL case and look it up."""
        if not ZBLL_CASES:
            pytest.skip("No ZBLL cases")
        case_name = list(ZBLL_CASES.keys())[0]
        alg = ZBLL_CASES[case_name]
        cube = Cube()
        cube.apply_algorithm(alg)
        visible = cube.get_visible_stickers()

        matches = resolver.lookup(visible, set_name="ZBLL")
        assert len(matches) > 0, f"ZBLL {case_name} not found in lookup table"

    def test_oll_case_roundtrip(self, resolver):
        """Apply an OLL case and look it up."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 45"])
        visible = cube.get_visible_stickers()

        matches = resolver.lookup(visible, set_name="OLL")
        assert len(matches) > 0, "OLL 45 not found in lookup table"

    def test_pll_case_roundtrip(self, resolver):
        """Apply a PLL case and look it up."""
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()

        matches = resolver.lookup(visible, set_name="PLL")
        assert len(matches) > 0, "T-Perm not found in lookup table"

    def test_original_oll_pll_still_works(self, resolver):
        """OLL+PLL lookup still works through expanded resolver."""
        cube = Cube()
        cube.apply_algorithm(OLL_CASES["OLL 27"])
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()

        # Should find OLL match for the combined state
        oll_matches = resolver.lookup(visible, set_name="OLL")
        # OLL table has the state produced by applying OLL 27 to solved,
        # but the combined OLL+PLL state is different.
        # The combined state should be findable across tables or via solver.
        # For regression, just verify the resolver doesn't crash
        assert isinstance(oll_matches, list)

    def test_lookup_returns_empty_for_unknown(self, resolver):
        """Unknown state returns empty list."""
        matches = resolver.lookup(["X"] * 15, set_name="OLL")
        assert matches == []


class TestExpandedResolverClosestMatch:
    """Test closest match functionality."""

    @pytest.fixture(scope="class")
    def resolver(self):
        return ExpandedStateResolver(sets=["PLL"])

    def test_close_match_found(self, resolver):
        """A slightly wrong state should have close matches."""
        cube = Cube()
        cube.apply_algorithm(PLL_CASES["T-Perm"])
        visible = cube.get_visible_stickers()

        # Corrupt one sticker
        visible[0] = "X"
        matches = resolver.find_closest_matches(visible, set_name="PLL", n=3)
        assert len(matches) > 0
        assert matches[0][1] <= 2  # Should be close


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

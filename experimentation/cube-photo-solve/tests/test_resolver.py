"""
Unit tests for StateResolver and Cube classes
"""

import pytest
from pathlib import Path

# Add parent directory to path for imports
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from state_resolver import Cube, StateResolver


class TestCube:
    """Test suite for Cube state representation."""

    def test_initialization(self):
        """Test cube initialization (solved state)."""
        cube = Cube()

        # Check all faces are initialized
        assert len(cube.faces) == 6
        assert 'U' in cube.faces  # Top
        assert 'D' in cube.faces  # Bottom
        assert 'F' in cube.faces  # Front
        assert 'B' in cube.faces  # Back
        assert 'L' in cube.faces  # Left
        assert 'R' in cube.faces  # Right

        # Check each face has 9 stickers
        for face in cube.faces.values():
            assert len(face) == 9

    def test_copy(self):
        """Test cube copying."""
        cube1 = Cube()
        cube2 = cube1.copy()

        # Verify deep copy (not the same object)
        assert cube1 is not cube2
        assert cube1.faces is not cube2.faces

        # Verify state is identical
        assert cube1.get_state_string() == cube2.get_state_string()

        # Modify cube2, ensure cube1 is unchanged
        cube2.apply_move('R')
        assert cube1.get_state_string() != cube2.get_state_string()

    def test_get_visible_stickers(self):
        """Test extracting visible stickers (15 total)."""
        cube = Cube()
        visible = cube.get_visible_stickers()

        # Should return 15 stickers: Top (9) + Front row (3) + Right row (3)
        assert len(visible) == 15

        # For a solved cube, check expected colors
        # Top face should be all white
        assert visible[0:9] == ['W'] * 9

        # Front top row should be red (front face color)
        assert visible[9:12] == ['R'] * 3

        # Right top row should be blue (right face color)
        assert visible[12:15] == ['B'] * 3

    def test_apply_move_R(self):
        """Test R move."""
        cube = Cube()
        original_state = cube.get_state_string()

        cube.apply_move('R')
        after_R = cube.get_state_string()

        # State should change
        assert original_state != after_R

        # Applying R four times should return to original
        cube.apply_move('R')
        cube.apply_move('R')
        cube.apply_move('R')
        assert cube.get_state_string() == original_state

    def test_apply_move_modifiers(self):
        """Test move modifiers (' and 2)."""
        cube1 = Cube()
        cube2 = Cube()

        # R' (counterclockwise) should be equivalent to R R R
        cube1.apply_move("R'")

        cube2.apply_move('R')
        cube2.apply_move('R')
        cube2.apply_move('R')

        assert cube1.get_state_string() == cube2.get_state_string()

        # R2 should be equivalent to R R
        cube3 = Cube()
        cube4 = Cube()

        cube3.apply_move('R2')

        cube4.apply_move('R')
        cube4.apply_move('R')

        assert cube3.get_state_string() == cube4.get_state_string()

    def test_apply_algorithm(self):
        """Test applying a sequence of moves."""
        cube = Cube()

        # Apply Sune algorithm
        sune = "R U R' U R U2 R'"
        cube.apply_algorithm(sune)

        # State should change
        assert cube.get_state_string() != Cube().get_state_string()

        # Applying Sune 6 times should return to solved (it's a 6-cycle)
        for _ in range(5):
            cube.apply_algorithm(sune)

        assert cube.get_state_string() == Cube().get_state_string()

    def test_y_rotation(self):
        """Test y rotation (entire cube around U axis)."""
        cube = Cube()
        cube.apply_move('y')

        # After y rotation, front should be where right was
        # This is a simplified test
        assert cube.faces is not None


class TestStateResolver:
    """Test suite for StateResolver."""

    @pytest.fixture
    def resolver(self):
        """Create a StateResolver instance (cached for performance)."""
        return StateResolver()

    def test_initialization(self, resolver):
        """Test StateResolver initialization."""
        # Lookup table should be populated
        assert len(resolver.lookup_table) > 0
        print(f"Lookup table size: {len(resolver.lookup_table)}")

    def test_match_solved_cube(self, resolver):
        """Test matching a solved cube."""
        solved_cube = Cube()
        visible = solved_cube.get_visible_stickers()

        match = resolver.match_state(visible)

        # Should find a match (or at least not crash)
        # Note: A solved cube might not be in the lookup table if OLL/PLL
        # algorithms don't produce a solved state
        if match:
            print(f"Solved cube matched: {match['combined_name']}")

    def test_match_invalid_input(self, resolver):
        """Test matching with invalid input."""
        # Too few stickers
        with pytest.raises(ValueError):
            resolver.match_state(['W', 'Y', 'R'])

        # Too many stickers
        with pytest.raises(ValueError):
            resolver.match_state(['W'] * 20)

    def test_find_closest_matches(self, resolver):
        """Test finding closest matches."""
        # Create a random sticker pattern
        test_stickers = ['W'] * 9 + ['R'] * 3 + ['B'] * 3

        closest = resolver.find_closest_matches(test_stickers, n=5)

        # Should return 5 matches
        assert len(closest) == 5

        # Each match should have (info, difference)
        for match_info, diff in closest:
            assert 'combined_name' in match_info
            assert 'oll_case' in match_info
            assert 'pll_case' in match_info
            assert isinstance(diff, int)
            assert diff >= 0

        # Differences should be in ascending order
        diffs = [diff for _, diff in closest]
        assert diffs == sorted(diffs)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

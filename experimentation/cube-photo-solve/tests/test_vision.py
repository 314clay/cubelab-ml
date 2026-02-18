"""
Unit tests for CubeVision class
"""

import pytest
import numpy as np
from pathlib import Path

# Add parent directory to path for imports
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from cube_vision import CubeVision


class TestCubeVision:
    """Test suite for CubeVision computer vision pipeline."""

    def test_initialization(self):
        """Test CubeVision initialization with default parameters."""
        vision = CubeVision()
        assert vision.min_area == 1000
        assert vision.max_area == 50000
        assert vision.aspect_ratio_range == (0.75, 1.25)

    def test_initialization_custom_params(self):
        """Test CubeVision initialization with custom parameters."""
        vision = CubeVision(min_area=500, max_area=60000, aspect_ratio_range=(0.8, 1.2))
        assert vision.min_area == 500
        assert vision.max_area == 60000
        assert vision.aspect_ratio_range == (0.8, 1.2)

    def test_preprocess(self):
        """Test image preprocessing."""
        vision = CubeVision()

        # Create a dummy color image
        dummy_image = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)

        gray, blurred = vision._preprocess(dummy_image)

        # Check output shapes
        assert gray.shape == (100, 100)
        assert blurred.shape == (100, 100)

    def test_detect_edges(self):
        """Test edge detection and dilation."""
        vision = CubeVision()

        # Create a dummy grayscale image
        dummy_gray = np.random.randint(0, 255, (100, 100), dtype=np.uint8)

        edges = vision._detect_edges(dummy_gray)

        # Check output shape
        assert edges.shape == (100, 100)

    def test_extract_colors(self):
        """Test color extraction from contours."""
        vision = CubeVision()

        # Create a dummy color image
        dummy_image = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)

        # Create dummy contours (simple squares)
        contour1 = np.array([[[10, 10]], [[20, 10]], [[20, 20]], [[10, 20]]])
        contour2 = np.array([[[30, 30]], [[40, 30]], [[40, 40]], [[30, 40]]])
        contours = [contour1, contour2]

        colors = vision._extract_colors(dummy_image, contours)

        # Check output shape
        assert colors.shape == (2, 3)  # 2 contours, 3 HSV channels

    def test_classify_colors_kmeans(self):
        """Test K-Means color classification."""
        vision = CubeVision()

        # Create dummy HSV colors (15 samples, 6 clusters)
        dummy_colors = np.random.rand(15, 3) * 255

        labels = vision._classify_colors_kmeans(dummy_colors, n_clusters=6)

        # Check output
        assert len(labels) == 15
        assert all(0 <= label < 6 for label in labels)

    # Integration tests (require actual images)

    @pytest.mark.skip(reason="Requires sample cube image")
    def test_detect_stickers_integration(self):
        """Integration test for full sticker detection pipeline."""
        vision = CubeVision()

        # This would require a real cube image
        image_path = "tests/sample_images/cube_view.jpg"

        if not Path(image_path).exists():
            pytest.skip(f"Sample image not found: {image_path}")

        colors, annotated = vision.detect_stickers(image_path)

        # Verify output
        assert len(colors) == 15
        assert all(c in ['W', 'Y', 'R', 'O', 'B', 'G'] for c in colors)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

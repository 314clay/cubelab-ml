"""
Y-Junction Detection for Rubik's Cube

This module implements standalone Y-junction detection using Harris corner detection,
edge detection, and color analysis. The Y-junction is the internal vertex where
the Top, Front, and Right faces of the cube meet.
"""

import cv2
import numpy as np
from typing import List, Tuple


def get_local_maxima(corners: np.ndarray, threshold: float) -> List[Tuple[int, int]]:
    """
    Extract local maxima from Harris corner response map using non-maximum suppression.

    Args:
        corners: Harris corner response map (H x W array)
        threshold: Minimum corner strength (as fraction of maximum, e.g., 0.01)

    Returns:
        List of (x, y) coordinates for corner candidates
    """
    # Apply threshold
    corner_mask = corners > threshold * corners.max()

    # Dilate to find local maxima regions
    kernel = np.ones((5, 5), np.uint8)
    dilated = cv2.dilate(corners, kernel)

    # Keep only points that are local maxima
    local_max_mask = (corners == dilated) & corner_mask

    # Find coordinates
    coords = np.argwhere(local_max_mask)

    # Return as (x, y) tuples (note: argwhere returns (row, col) = (y, x))
    return [(int(x), int(y)) for y, x in coords]


def cluster_angles(angles: List[float], threshold: float = 20.0) -> List[float]:
    """
    Group nearby angles and return cluster centroids.

    Args:
        angles: List of angles in degrees
        threshold: Maximum angular distance to be in same cluster

    Returns:
        List of cluster centroids
    """
    if not angles:
        return []

    # Handle wraparound: convert to unit vectors and cluster
    angles_sorted = sorted(angles)
    clusters = []
    current_cluster = [angles_sorted[0]]

    for angle in angles_sorted[1:]:
        # Check if angle is within threshold of cluster
        if angle - current_cluster[-1] <= threshold:
            current_cluster.append(angle)
        else:
            # Check wraparound case (e.g., 350° and 10° are close)
            if len(clusters) == 0 and angle > 360 - threshold:
                # This might wrap around to first cluster
                current_cluster.append(angle)
            else:
                # Finish current cluster
                clusters.append(np.mean(current_cluster))
                current_cluster = [angle]

    # Handle last cluster
    if current_cluster:
        clusters.append(np.mean(current_cluster))

    # Check for wraparound between first and last cluster
    if len(clusters) > 1 and clusters[-1] > 360 - threshold and clusters[0] < threshold:
        # Merge first and last cluster
        wrapped_angles = [(a - 360 if a > 180 else a) for a in [clusters[0], clusters[-1]]]
        merged = np.mean(wrapped_angles)
        if merged < 0:
            merged += 360
        clusters = [merged] + clusters[1:-1]

    return clusters


def find_edges_from_point(edges: np.ndarray, center: Tuple[int, int]) -> List[float]:
    """
    Find edges radiating from a center point by casting rays radially.

    Args:
        edges: Binary edge image (Canny output)
        center: (cx, cy) center point coordinates

    Returns:
        List of angles (in degrees) for each edge direction found
    """
    cx, cy = center
    h, w = edges.shape

    # Search in radial directions from center
    edge_angles = []

    for angle_deg in range(0, 360, 10):  # Check every 10 degrees
        angle_rad = np.radians(angle_deg)

        # Cast ray from center in this direction
        max_dist = min(cx, cy, w - cx - 1, h - cy - 1)  # Stay within window
        max_dist = max(5, max_dist)  # Need at least radius 5

        for dist in range(5, max_dist, 2):  # Start at radius 5, step by 2
            x = int(cx + dist * np.cos(angle_rad))
            y = int(cy + dist * np.sin(angle_rad))

            # Check bounds
            if 0 <= y < h and 0 <= x < w:
                if edges[y, x] > 0:  # Found an edge
                    edge_angles.append(angle_deg)
                    break  # Move to next direction

    # Cluster nearby angles (within 20°) and take centroids
    clustered_angles = cluster_angles(edge_angles, threshold=20)

    return clustered_angles


def compute_angles_between_edges(edge_angles: List[float]) -> List[float]:
    """
    Compute angles between consecutive edges.

    Args:
        edge_angles: List of 3 edge directions (in degrees)

    Returns:
        List of 3 angles between consecutive edges
    """
    if len(edge_angles) != 3:
        return []

    # Sort edges by angle
    sorted_edges = sorted(edge_angles)

    # Compute angles between consecutive edges
    angles_between = []
    for i in range(3):
        angle1 = sorted_edges[i]
        angle2 = sorted_edges[(i + 1) % 3]

        diff = angle2 - angle1
        if diff < 0:
            diff += 360

        angles_between.append(diff)

    return angles_between


def sample_colors_around_junction(
    window: np.ndarray,
    center: Tuple[int, int],
    edge_angles: List[float]
) -> List[np.ndarray]:
    """
    Sample colors along each edge direction from the junction.

    Args:
        window: BGR image window
        center: (cx, cy) center point in window coordinates
        edge_angles: List of edge directions in degrees

    Returns:
        List of HSV color vectors (one per edge)
    """
    cx, cy = center
    hsv = cv2.cvtColor(window, cv2.COLOR_BGR2HSV)
    h, w = window.shape[:2]
    colors = []

    for angle_deg in edge_angles:
        angle_rad = np.radians(angle_deg)

        # Sample at distance 12 pixels from center
        sample_dist = 12
        x = int(cx + sample_dist * np.cos(angle_rad))
        y = int(cy + sample_dist * np.sin(angle_rad))

        # Check bounds
        if 2 <= y < h - 2 and 2 <= x < w - 2:
            # Sample 5x5 region and take median
            region = hsv[y - 2:y + 3, x - 2:x + 3]
            if region.size > 0:
                color = np.median(region.reshape(-1, 3), axis=0)
                colors.append(color)
        else:
            # Out of bounds, use center color as fallback
            colors.append(hsv[cy, cx])

    return colors


def count_unique_colors(colors: List[np.ndarray], hue_threshold: float = 15.0) -> int:
    """
    Count how many distinct colors are present based on hue differences.

    Args:
        colors: List of HSV color vectors
        hue_threshold: Minimum hue difference to be considered different colors

    Returns:
        Number of unique colors (1-3)
    """
    if len(colors) < 2:
        return len(colors)

    unique_count = 1
    for i in range(1, len(colors)):
        # Compare hue values (colors[i][0])
        is_unique = True
        for j in range(i):
            hue_diff = abs(colors[i][0] - colors[j][0])

            # Handle hue wraparound (0° = 180° in OpenCV HSV)
            if hue_diff > 90:
                hue_diff = 180 - hue_diff

            if hue_diff < hue_threshold:
                is_unique = False
                break

        if is_unique:
            unique_count += 1

    return unique_count


def validate_y_junction(window: np.ndarray, center: Tuple[int, int], image: np.ndarray = None) -> Tuple[float, dict]:
    """
    Validate that a corner point is actually a Y-junction.

    Args:
        window: BGR image window around the corner (60x60 pixels)
        center: (cx, cy) center point in window coordinates
        image: Optional full image for computing Harris response

    Returns:
        Tuple of (score, details_dict) where:
            - score: Validation score (0 = not Y-junction, higher = more confident)
            - details_dict: Dictionary with validation details for debugging
    """
    cx, cy = center
    score = 0.0
    details = {}

    # Test 1: Find edges radiating from center
    gray = cv2.cvtColor(window, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, threshold1=50, threshold2=150)
    edge_angles = find_edges_from_point(edges, center)

    details['num_edges'] = len(edge_angles)
    details['edge_angles'] = edge_angles

    if len(edge_angles) != 3:
        return 0.0, details  # Must have exactly 3 edges

    score += 30.0  # Base score for having 3 edges

    # Test 2: Check angles between edges (all should be > 90°)
    angles_between = compute_angles_between_edges(edge_angles)
    details['angles_between'] = angles_between

    if not angles_between or not all(angle > 90 for angle in angles_between):
        return 0.0, details  # All angles must be obtuse

    score += 30.0  # Bonus for correct angles

    # Test 3: Check for 3 different colors at junction
    colors = sample_colors_around_junction(window, center, edge_angles)
    unique_colors = count_unique_colors(colors)

    details['num_unique_colors'] = unique_colors
    details['colors'] = colors

    if unique_colors >= 3:
        score += 20.0  # Bonus for color diversity

    # Test 4: Check corner strength (Harris response)
    corners = cv2.cornerHarris(gray, blockSize=2, ksize=3, k=0.04)
    harris_response = corners[cy, cx] / (corners.max() + 1e-6)

    details['harris_response'] = harris_response
    score += min(harris_response * 100, 20.0)  # Cap at 20 points

    return score, details


def find_y_junction_candidates(image: np.ndarray) -> List[Tuple[int, int, float, dict]]:
    """
    Find Y-junction candidates in a raw cube image.

    Args:
        image: BGR image

    Returns:
        List of (x, y, score, details) tuples for candidate Y-junctions,
        sorted by score (highest first)
    """
    # Step 1: Run Harris corner detection on entire image
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    corners = cv2.cornerHarris(gray, blockSize=2, ksize=3, k=0.04)

    # Step 2: Find local maxima (non-maximum suppression)
    corner_coords = get_local_maxima(corners, threshold=0.01)

    print(f"\nHarris corners found: {len(corner_coords)} points")

    # Step 3: For each corner candidate, validate Y-junction properties
    candidates = []
    window_size = 30  # 60x60 window (30 pixels in each direction)

    for x, y in corner_coords:
        # Check if we can extract a full window
        h, w = image.shape[:2]
        if y - window_size < 0 or y + window_size >= h or x - window_size < 0 or x + window_size >= w:
            continue  # Skip corners too close to image boundary

        # Extract local window
        window = image[y - window_size:y + window_size, x - window_size:x + window_size]

        # Validate Y-junction properties
        score, details = validate_y_junction(window, center=(window_size, window_size), image=image)

        if score > 0:  # If validation passes
            candidates.append((x, y, score, details))

    # Step 4: Sort by score (highest first)
    candidates.sort(key=lambda c: c[2], reverse=True)

    # Print statistics
    candidates_3_edges = sum(1 for c in candidates if c[3]['num_edges'] == 3)
    candidates_correct_angles = sum(1 for c in candidates if c[3].get('angles_between') and all(a > 90 for a in c[3]['angles_between']))
    candidates_3_colors = sum(1 for c in candidates if c[3]['num_unique_colors'] >= 3)

    print(f"\nAfter validation:")
    print(f"  Candidates with 3 edges: {candidates_3_edges} points")
    print(f"  Candidates with correct angles: {candidates_correct_angles} points")
    print(f"  Candidates with 3 colors: {candidates_3_colors} points")

    return candidates

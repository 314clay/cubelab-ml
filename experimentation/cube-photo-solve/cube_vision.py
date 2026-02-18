"""
CubeVision: OpenCV-based Rubik's Cube sticker detection and color classification
Implements the Qbr methodology for robust cube scanning
"""

import cv2
import numpy as np
from sklearn.cluster import KMeans
from typing import List, Tuple, Dict, Optional


class CubeVision:
    """
    Detects and classifies Rubik's Cube stickers from a single image.
    Extracts 15 visible stickers: Top face (9) + Front top row (3) + Right top row (3)
    """

    def __init__(self, min_area=1000, max_area=50000, aspect_ratio_range=(0.4, 3.0), debug_output_prefix=None):
        """
        Initialize CubeVision with detection parameters.

        Args:
            min_area: Minimum contour area for sticker detection
            max_area: Maximum contour area for sticker detection
            aspect_ratio_range: (min, max) aspect ratio for square detection
            debug_output_prefix: If provided, save debug images with this prefix
        """
        self.min_area = min_area
        self.max_area = max_area
        self.aspect_ratio_range = aspect_ratio_range
        self.color_map = {}  # Maps cluster IDs to face colors
        self.debug_output_prefix = debug_output_prefix

    def detect_stickers(self, image_path: str) -> Tuple[List[str], np.ndarray]:
        """
        Main pipeline: Detect and classify 15 visible stickers using hexagon/Y-junction method.

        This method is rewritten to handle stickerless cubes by using geometric
        partitioning instead of individual sticker contour detection.

        Args:
            image_path: Path to the cube image

        Returns:
            Tuple of (color_list, annotated_image)
            - color_list: 15-element list of face colors ['W', 'Y', 'R', 'O', 'B', 'G']
            - annotated_image: Image with detected stickers highlighted
        """
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not load image: {image_path}")

        # Step 1: Preprocessing (KEEP - works fine)
        gray, blurred = self._preprocess(image)

        # Step 2: Edge detection (not used anymore for hexagon, but kept for Y-junction)
        edges = self._detect_edges(blurred)

        # Step 3: NEW - Find hexagon outline using color segmentation
        try:
            hexagon = self._find_hexagon(image, image.shape)
        except ValueError as e:
            raise ValueError(f"Could not find cube hexagon: {e}")

        # Step 4: NEW - Find Y-junction (internal vertex) and seam indices
        y_junction, seam_indices = self._find_y_junction(hexagon, image)

        # Step 5: NEW - Partition into 3 faces using seam indices
        faces = self._partition_into_quadrilaterals(hexagon, y_junction, seam_indices)

        # Step 6-8: Perspective-warp each face to a square, sample sticker colors
        hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        warp_size = 150  # 150x150 square → 50x50 per sticker cell

        sticker_colors = []

        # Sample top face (all 9 stickers)
        top_colors = self._sample_face_warped(hsv_image, faces['top'], warp_size)
        sticker_colors.extend(top_colors)

        # Sample front top row (3 stickers)
        front_colors = self._sample_face_warped(hsv_image, faces['front'], warp_size)
        sticker_colors.extend(front_colors[:3])

        # Sample right top row (3 stickers)
        right_colors = self._sample_face_warped(hsv_image, faces['right'], warp_size)
        sticker_colors.extend(right_colors[:3])

        sticker_colors = np.array(sticker_colors)

        # Classify each sticker color directly using HSV thresholds
        face_colors = self._classify_colors_direct(sticker_colors)

        # Step 10: Create annotated image for debugging
        top_grid = self._create_grid(faces['top'])
        front_grid = self._create_grid(faces['front'])
        right_grid = self._create_grid(faces['right'])
        annotated = self._annotate_image_with_grid(
            image.copy(),
            hexagon,
            y_junction,
            [top_grid, front_grid, right_grid],
            face_colors
        )

        return face_colors, annotated

    def _preprocess(self, image: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Convert to grayscale and apply Gaussian blur.

        Args:
            image: BGR image from cv2.imread

        Returns:
            (grayscale, blurred) images
        """
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        return gray, blurred

    def _detect_edges(self, blurred: np.ndarray) -> np.ndarray:
        """
        Apply Canny edge detection and dilation.

        Args:
            blurred: Blurred grayscale image

        Returns:
            Edge-detected and dilated image
        """
        # Canny edge detection (lower thresholds to capture more edges)
        edges = cv2.Canny(blurred, 50, 150)

        # Dilation to merge sticker gaps
        kernel = np.ones((3, 3), np.uint8)
        dilated = cv2.dilate(edges, kernel, iterations=2)

        return dilated

    def _find_hexagon(self, image: np.ndarray, image_shape: Tuple) -> np.ndarray:
        """
        Detect the hexagonal projection of the cube using COLOR SEGMENTATION.

        For stickerless cubes, edge detection fails because same-color stickers
        have no edges between them. Instead, we segment the cube from the background
        based on color saturation - the cube has vibrant colors, the background doesn't.

        Args:
            image: BGR color image
            image_shape: Original image shape (height, width, channels)

        Returns:
            6x2 array of corner points (x, y) ordered by angle from centroid
        """
        # Convert to HSV for color analysis
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        hue, saturation, value = cv2.split(hsv)

        # HYBRID APPROACH:
        # 1. Estimate background color from image corners
        # 2. Create mask of pixels that differ from background (catches white stickers too)
        # 3. Also include high-saturation pixels
        # 4. Run K-means on masked region

        # Step 1: Estimate background color from image corners
        h, w = image_shape[:2]
        corner_size = max(20, min(h, w) // 10)
        corners = [
            hsv[:corner_size, :corner_size],           # top-left
            hsv[:corner_size, w-corner_size:],         # top-right
            hsv[h-corner_size:, :corner_size],         # bottom-left
            hsv[h-corner_size:, w-corner_size:],       # bottom-right
        ]
        bg_pixels = np.vstack([c.reshape(-1, 3) for c in corners])
        bg_color = np.median(bg_pixels, axis=0)  # Median is robust to outliers

        # Create mask: pixels that differ significantly from background
        all_pixels = hsv.reshape(-1, 3).astype(np.float32)
        bg_diff = np.linalg.norm(all_pixels - bg_color.astype(np.float32), axis=1)
        bg_diff_2d = bg_diff.reshape(image_shape[:2])

        # Threshold: anything that differs from background by more than 30 in HSV space
        bg_mask = bg_diff_2d > 30

        # Also include any pixel with high saturation (catches colored stickers on any bg)
        sat_mask = saturation > 50

        # Combine: either different from background OR high saturation
        rough_mask = bg_mask | sat_mask

        # Step 2: Extract only pixels from cube region for K-means
        cube_pixels_mask = rough_mask.flatten()
        cube_pixels = hsv.reshape(-1, 3)[cube_pixels_mask].astype(np.float32)

        # Run K-means with k=6 on ONLY cube pixels
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 100, 0.2)
        _, cube_labels, centers = cv2.kmeans(cube_pixels, 6, None, criteria, 10, cv2.KMEANS_PP_CENTERS)

        # Map full image pixels to nearest cluster
        all_pixels = hsv.reshape(-1, 3).astype(np.float32)
        distances = np.zeros((all_pixels.shape[0], 6))
        for i, center in enumerate(centers):
            # Euclidean distance in HSV space
            distances[:, i] = np.linalg.norm(all_pixels - center, axis=1)

        labels = np.argmin(distances, axis=1)
        min_distances = np.min(distances, axis=1)

        # Only assign pixels that are close enough to a cluster (within distance threshold)
        # This prevents background pixels from being incorrectly assigned to cube colors
        distance_threshold = 80  # HSV distance threshold
        too_far = min_distances > distance_threshold
        labels[too_far] = -1  # Mark as unassigned

        # Map each cluster to a face color (R, O, Y, G, B, W) or BACKGROUND
        cluster_colors = self._classify_cluster_colors(centers)

        # Store cluster centers for later color classification
        self.cube_cluster_centers = centers
        self.cube_cluster_colors = cluster_colors

        # Debug: Save cluster visualization and print color assignments
        if hasattr(self, 'debug_output_prefix') and self.debug_output_prefix:
            # Create visualization of 6 clusters
            cluster_img = centers[labels.flatten()].reshape(image.shape).astype(np.uint8)
            cluster_img = cv2.cvtColor(cluster_img, cv2.COLOR_HSV2BGR)
            cv2.imwrite(f"{self.debug_output_prefix}_1_kmeans_clusters.jpg", cluster_img)

            # Print cluster color assignments
            print("\n=== K-MEANS CLUSTER COLORS ===")
            for i, (center, color) in enumerate(zip(centers, cluster_colors)):
                h, s, v = center
                print(f"Cluster {i}: HSV=({h:.0f}, {s:.0f}, {v:.0f}) → {color}")
            print("=" * 31)

        # Create mask: pixels that match any of the 6 cube colors
        labels_2d = labels.reshape(image_shape[:2])
        mask = np.zeros(image_shape[:2], dtype=np.uint8)

        # For each cluster, include all non-background colors (excluding unassigned pixels)
        cube_color_count = 0
        for cluster_id, color in enumerate(cluster_colors):
            if color != 'BACKGROUND':  # Only include actual cube colors
                cluster_mask = (labels_2d == cluster_id).astype(np.uint8) * 255
                pixel_count = np.sum(cluster_mask > 0)
                mask = cv2.bitwise_or(mask, cluster_mask)
                cube_color_count += 1

                if hasattr(self, 'debug_output_prefix') and self.debug_output_prefix:
                    print(f"  Cluster {cluster_id} ({color}): {pixel_count} pixels")

        # Debug: Save color-based mask
        if hasattr(self, 'debug_output_prefix') and self.debug_output_prefix:
            total_mask_pixels = np.sum(mask > 0)
            print(f"  Total mask pixels: {total_mask_pixels} ({cube_color_count} cube colors)")
            cv2.imwrite(f"{self.debug_output_prefix}_2_color_mask.jpg", mask)

        # Morphological operations to clean up noise and close gaps
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=3)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=2)

        # Debug: Save after morphology
        if hasattr(self, 'debug_output_prefix') and self.debug_output_prefix:
            cv2.imwrite(f"{self.debug_output_prefix}_3_after_morphology.jpg", mask)

        # CRITICAL: Keep only the largest connected component (the cube)
        # This removes edge noise that would cause findContours to trace image boundaries
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(mask, connectivity=8)

        if num_labels < 2:
            raise ValueError("No connected components found in mask")

        # Find largest component (excluding background which is label 0)
        largest_label = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])

        # Create new mask with only the largest component
        mask = np.zeros_like(mask)
        mask[labels == largest_label] = 255

        # Debug: Save largest component
        if hasattr(self, 'debug_output_prefix') and self.debug_output_prefix:
            cv2.imwrite(f"{self.debug_output_prefix}_4_largest_component.jpg", mask)

        # Add a black border to prevent contours from touching image edges
        # This ensures we find the CUBE boundary, not the image boundary
        border_size = 10
        mask = cv2.copyMakeBorder(mask, border_size, border_size, border_size, border_size,
                                  cv2.BORDER_CONSTANT, value=0)

        # Find contours of the segmented cube
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if not contours:
            raise ValueError("No contours found in color segmentation")

        # Sort by area - largest should be the cube
        contours = sorted(contours, key=cv2.contourArea, reverse=True)

        # Try to approximate the largest contour to a hexagon
        best_hexagon = None

        for contour in contours[:3]:  # Check top 3 largest contours
            area = cv2.contourArea(contour)

            # Must be substantial portion of image
            if area < 0.05 * (image_shape[0] * image_shape[1]):
                continue

            # Use convex hull to ensure no inward-pointing vertices.
            # The cube silhouette is always convex, but mask gaps from seam lines
            # can create concavities that cause approxPolyDP to add interior vertices.
            hull = cv2.convexHull(contour)
            perimeter = cv2.arcLength(hull, True)

            # Try different epsilon values to find hexagon
            for epsilon_factor in [0.015, 0.02, 0.025, 0.03, 0.035, 0.04]:
                epsilon = epsilon_factor * perimeter
                approx = cv2.approxPolyDP(hull, epsilon, True)

                if len(approx) == 6:
                    best_hexagon = approx.reshape(6, 2)
                    best_hexagon -= border_size
                    break

                if 5 <= len(approx) <= 8 and best_hexagon is None:
                    best_hexagon = approx.reshape(len(approx), 2)
                    best_hexagon -= border_size

            if best_hexagon is not None and len(best_hexagon) == 6:
                break  # Found perfect hexagon, stop searching

        if best_hexagon is None:
            raise ValueError("Could not approximate cube outline to hexagon")

        # Sort vertices by angle from centroid (ensures consistent ordering)
        centroid = np.mean(best_hexagon, axis=0)

        def angle_from_centroid(point):
            return np.arctan2(point[1] - centroid[1], point[0] - centroid[0])

        sorted_hexagon = sorted(best_hexagon, key=angle_from_centroid)

        # Normalize to exactly 6 vertices if needed
        num_vertices = len(sorted_hexagon)

        if num_vertices == 6:
            # Perfect! Return as-is
            return np.array(sorted_hexagon)
        elif num_vertices > 6:
            # Select 6 evenly spaced vertices
            indices = np.linspace(0, num_vertices - 1, 6, dtype=int)
            selected_vertices = [sorted_hexagon[i] for i in indices]
            return np.array(selected_vertices)
        else:
            # num_vertices < 6 (probably 5)
            # Interpolate to add extra vertices
            result_vertices = []
            for i in range(6):
                # Map to the available vertices
                idx = int(i * num_vertices / 6.0)
                result_vertices.append(sorted_hexagon[idx % num_vertices])
            return np.array(result_vertices)

    def _find_y_junction(self, hexagon: np.ndarray, image: np.ndarray) -> Tuple[Tuple[int, int], List[int]]:
        """
        Find the internal Y-junction vertex where Top, Front, and Right faces meet.

        Uses ridge-based detection: identifies which 3 alternating hexagon vertices
        have dark seam lines running toward the interior, fits lines through the
        dark ridge pixels, and finds their intersection.

        Args:
            hexagon: 6x2 array of hexagon vertices (sorted by angle from centroid)
            image: Original grayscale or color image

        Returns:
            Tuple of ((x, y), seam_indices):
            - (x, y): coordinates of the Y-junction
            - seam_indices: list of 3 hexagon vertex indices that connect to Y-junction
        """
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image

        centroid = np.mean(hexagon, axis=0)

        # Step 1: Identify which set of alternating vertices has seam lines.
        # Cast rays from each vertex toward centroid and measure average darkness.
        # The 3 seam vertices will have darker rays (black body lines between faces).
        def ray_darkness(vertex, target, num_samples=50):
            samples = []
            for t in np.linspace(0.1, 0.8, num_samples):
                x = int(vertex[0] + t * (target[0] - vertex[0]))
                y = int(vertex[1] + t * (target[1] - vertex[1]))
                if 0 <= y < gray.shape[0] and 0 <= x < gray.shape[1]:
                    samples.append(gray[y, x])
            return np.mean(samples) if samples else 255

        set_a = [0, 2, 4]
        set_b = [1, 3, 5]
        score_a = sum(ray_darkness(hexagon[i], centroid) for i in set_a) / 3
        score_b = sum(ray_darkness(hexagon[i], centroid) for i in set_b) / 3
        seam_indices = set_a if score_a < score_b else set_b

        # Step 2: For each seam vertex, collect dark pixels along the ridge
        # toward the centroid and fit a line through them.
        def collect_dark_ridge_points(vertex, target, strip_width=8, dark_thresh=100):
            dx = target[0] - vertex[0]
            dy = target[1] - vertex[1]
            length = np.sqrt(dx**2 + dy**2)
            if length < 1:
                return None
            dx, dy = dx / length, dy / length

            dark_points = []
            for dist in range(5, int(length * 0.95), 2):
                cx = vertex[0] + dist * dx
                cy = vertex[1] + dist * dy
                if cv2.pointPolygonTest(hexagon.astype(np.float32),
                                        (float(cx), float(cy)), False) < 0:
                    continue
                min_val = 255
                min_pos = None
                for offset in range(-strip_width, strip_width + 1):
                    px = int(cx - offset * dy)
                    py = int(cy + offset * dx)
                    if 0 <= py < gray.shape[0] and 0 <= px < gray.shape[1]:
                        val = gray[py, px]
                        if val < min_val:
                            min_val = val
                            min_pos = (px, py)
                if min_pos and min_val < dark_thresh:
                    dark_points.append(min_pos)
            return np.array(dark_points) if dark_points else None

        # Step 3: Fit lines to ridge points and find intersections
        ridge_lines = []
        for i in seam_indices:
            points = collect_dark_ridge_points(hexagon[i], centroid)
            if points is not None and len(points) >= 5:
                vx, vy, x0, y0 = cv2.fitLine(
                    points.astype(np.float32), cv2.DIST_L2, 0, 0.01, 0.01)
                ridge_lines.append((vx[0], vy[0], x0[0], y0[0]))

        if len(ridge_lines) >= 2:
            intersections = []
            for i in range(len(ridge_lines)):
                for j in range(i + 1, len(ridge_lines)):
                    vx1, vy1, x1, y1 = ridge_lines[i]
                    vx2, vy2, x2, y2 = ridge_lines[j]
                    denom = vx1 * vy2 - vy1 * vx2
                    if abs(denom) < 1e-10:
                        continue
                    t = ((x2 - x1) * vy2 - (y2 - y1) * vx2) / denom
                    ix = x1 + t * vx1
                    iy = y1 + t * vy1
                    if cv2.pointPolygonTest(hexagon.astype(np.float32),
                                            (float(ix), float(iy)), False) >= 0:
                        intersections.append((ix, iy))
            if intersections:
                avg = np.mean(intersections, axis=0)
                return (int(avg[0]), int(avg[1])), seam_indices

        # Fallback: hexagon centroid
        return (int(centroid[0]), int(centroid[1])), seam_indices

    def _partition_into_quadrilaterals(
        self,
        hexagon: np.ndarray,
        y_junction: Tuple[int, int],
        seam_indices: List[int]
    ) -> Dict[str, np.ndarray]:
        """
        Divide the hexagon into 3 quadrilaterals (Top, Front, Right faces).

        Uses the known seam indices to directly construct the 3 quadrilateral faces.
        Each face is bounded by: Y-junction, seam_vertex_i, non_seam_vertex, seam_vertex_j.

        Args:
            hexagon: 6x2 array of hexagon vertices (sorted by angle from centroid)
            y_junction: (x, y) coordinates of the Y-junction
            seam_indices: list of 3 hexagon vertex indices that connect to Y-junction

        Returns:
            Dictionary with keys 'top', 'front', 'right', each containing a 4-point array
        """
        jx, jy = y_junction
        junction_point = np.array([jx, jy])

        # Build the 3 quadrilateral faces directly from seam indices.
        seam_sorted = sorted(seam_indices)
        quads = []
        for idx in range(3):
            s_i = seam_sorted[idx]
            s_j = seam_sorted[(idx + 1) % 3]
            non_seam = (s_i + 1) % 6
            quad = np.array([
                junction_point,
                hexagon[s_i],
                hexagon[non_seam],
                hexagon[s_j]
            ])
            centroid = np.mean(quad, axis=0)
            quads.append((quad, centroid))

        # Classify which face is Top, Front, Right by centroid position.
        quads.sort(key=lambda q: q[1][1])  # Sort by centroid Y ascending
        top_quad, top_centroid = quads[0]
        remaining = sorted(quads[1:], key=lambda q: q[1][0])
        front_quad, front_centroid = remaining[0]
        right_quad, right_centroid = remaining[1]

        def order_quad_vertices(quad):
            """Order 4 vertices for perspective warp (TL, TR, BR, BL)."""
            sorted_by_y = sorted(quad, key=lambda v: v[1])
            top_two = sorted(sorted_by_y[:2], key=lambda v: v[0])
            bottom_two = sorted(sorted_by_y[2:], key=lambda v: v[0])
            return np.array([top_two[0], top_two[1], bottom_two[1], bottom_two[0]])

        def order_top_face(quad, junction_pt):
            """Order top face vertices using known geometry.

            The top face diamond has: junction at bottom, non-seam vertex at top,
            left seam vertex on the left, right seam vertex on the right.

            Empirically verified mapping (matching Cube class U face indexing):
            TL=top(U[0]), TR=right(U[2]), BR=junction(U[8]), BL=left(U[6]).
            """
            pts = list(quad)
            # Identify junction vertex (closest to junction point)
            dists = [np.linalg.norm(p - junction_pt) for p in pts]
            junc_idx = np.argmin(dists)
            junc = pts.pop(junc_idx)

            # Of remaining 3, the one with lowest Y (highest in image) is the top (non-seam)
            remaining = sorted(pts, key=lambda v: v[1])
            top_vertex = remaining[0]
            sides = remaining[1:]

            # Of the two side vertices, lower X = left, higher X = right
            sides.sort(key=lambda v: v[0])
            left_vertex = sides[0]
            right_vertex = sides[1]

            # TL=top(U[0]), TR=right(U[2]), BR=junction(U[8]), BL=left(U[6])
            return np.array([top_vertex, right_vertex, junc, left_vertex])

        top_quad = order_top_face(top_quad, junction_point)
        front_quad = order_quad_vertices(front_quad)
        right_quad = order_quad_vertices(right_quad)

        return {
            'top': top_quad,
            'front': front_quad,
            'right': right_quad
        }

    def _sample_face_warped(
        self,
        hsv_image: np.ndarray,
        quad: np.ndarray,
        warp_size: int = 90
    ) -> List[np.ndarray]:
        """
        Perspective-warp a face quadrilateral to a square and sample 9 sticker colors.

        This gives much more accurate sticker sampling than bilinear grid interpolation
        because it correctly handles perspective distortion.

        Args:
            hsv_image: HSV image
            quad: 4x2 array of quadrilateral vertices (TL, TR, BR, BL order)
            warp_size: Size of the output square (default 90 → 30px per sticker)

        Returns:
            List of 9 HSV color arrays, one per sticker in row-major order
        """
        src_pts = quad.astype(np.float32)
        dst_pts = np.array([
            [0, 0],
            [warp_size, 0],
            [warp_size, warp_size],
            [0, warp_size]
        ], dtype=np.float32)

        M = cv2.getPerspectiveTransform(src_pts, dst_pts)
        warped = cv2.warpPerspective(hsv_image, M, (warp_size, warp_size))

        cell_size = warp_size // 3
        margin = int(cell_size * 0.25)  # 25% margin — balances edge avoidance with coverage

        colors = []
        for row in range(3):
            for col in range(3):
                y_start = row * cell_size + margin
                y_end = (row + 1) * cell_size - margin
                x_start = col * cell_size + margin
                x_end = (col + 1) * cell_size - margin

                roi = warped[y_start:y_end, x_start:x_end].reshape(-1, 3)

                # Filter out black body pixels: require colored (S>30) or bright (V>150)
                mask = (roi[:, 1] > 30) | (roi[:, 2] > 150)
                if np.sum(mask) > 3:
                    # Use median for robustness against color bleeding from adjacent stickers
                    colors.append(np.median(roi[mask].astype(np.float64), axis=0))
                else:
                    colors.append(np.median(roi.astype(np.float64), axis=0))

        return colors

    def _create_grid(self, quadrilateral: np.ndarray) -> List[Tuple[int, int]]:
        """
        Divide a quadrilateral into a 3×3 grid using bilinear interpolation.

        This handles perspective distortion by interpolating between the edges
        of the quadrilateral, which may not be parallel.

        Args:
            quadrilateral: 3 or 4 vertices defining the face region

        Returns:
            List of 9 (x, y) points representing the centers of the 3×3 grid
        """
        # Handle both triangles and quadrilaterals
        if len(quadrilateral) == 3:
            # For a triangle, we'll create a simple grid
            # This is a fallback case - ideally all faces should be quads

            # Use the 3 vertices to define a bounding region
            p0, p1, p2 = quadrilateral

            # Create a simple grid by interpolating within the triangle
            grid_points = []
            for row in range(3):
                for col in range(3):
                    # Barycentric coordinates for triangle interpolation
                    u = (col + 0.5) / 3.0
                    v = (row + 0.5) / 3.0

                    # Simple average (not true barycentric, but works for visualization)
                    if u + v <= 1.0:
                        point = (1 - u - v) * p0 + u * p1 + v * p2
                    else:
                        # Reflect for the other half of the grid
                        point = p0 + u * (p1 - p0) + v * (p2 - p0)

                    grid_points.append((int(point[0]), int(point[1])))

            return grid_points

        # Standard case: 4 vertices forming a quadrilateral
        # Order should be: p0 (Y-junction/top-left), p1, p2, p3 going around
        p0, p1, p2, p3 = quadrilateral

        grid_points = []

        # Divide into 3×3 grid using bilinear interpolation
        # Each grid cell center is at (col+0.5)/3, (row+0.5)/3
        for row in range(3):
            for col in range(3):
                # Interpolation parameters for the center of each grid cell.
                # Inset from edges to avoid sampling on black body gaps between stickers.
                # Use 0.2-0.8 range instead of 0.167-0.833 to stay away from face edges.
                u = 0.2 + (col / 2.0) * 0.6
                v = 0.2 + (row / 2.0) * 0.6

                # Bilinear interpolation formula:
                # point = (1-v)(1-u)p0 + (1-v)(u)p1 + (v)(u)p2 + (v)(1-u)p3
                #
                # This assumes:
                # p0 = top-left corner
                # p1 = top-right corner
                # p2 = bottom-right corner
                # p3 = bottom-left corner

                point = (
                    (1 - v) * (1 - u) * p0 +
                    (1 - v) * u * p1 +
                    v * u * p2 +
                    v * (1 - u) * p3
                )

                grid_points.append((int(point[0]), int(point[1])))

        return grid_points

    def _sample_color_at_point(self, image: np.ndarray, point: Tuple[int, int], sample_size: int = 10) -> np.ndarray:
        """
        Extract average HSV color from a region around a point.

        Args:
            image: Original BGR image
            point: (x, y) coordinates of the center point
            sample_size: Radius of the sampling region (in pixels)

        Returns:
            Average HSV color as a 3-element array [H, S, V]
        """
        # Convert to HSV
        hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        x, y = point

        # Define sampling region (square around the point)
        x_min = max(0, x - sample_size)
        x_max = min(image.shape[1], x + sample_size)
        y_min = max(0, y - sample_size)
        y_max = min(image.shape[0], y + sample_size)

        # Extract region of interest
        roi = hsv_image[y_min:y_max, x_min:x_max]

        if roi.size > 0:
            # Filter out black body pixels (very dark, low saturation = cube body gaps)
            roi_flat = roi.reshape(-1, 3)
            # Keep pixels that are either colorful (S>30) or bright (V>100)
            mask = (roi_flat[:, 1] > 30) | (roi_flat[:, 2] > 100)
            if np.sum(mask) > 0:
                return np.mean(roi_flat[mask], axis=0)
            return np.mean(roi_flat, axis=0)
        else:
            return hsv_image[y, x]

    def _find_sticker_contours(self, edges: np.ndarray, image_shape: Tuple) -> List[np.ndarray]:
        """
        Find contours and filter for square stickers.

        Args:
            edges: Edge-detected image
            image_shape: Original image shape for area filtering

        Returns:
            List of contours representing stickers
        """
        # Find all contours
        contours, _ = cv2.findContours(edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

        # Filter contours
        valid_contours = []
        for contour in contours:
            # Check area
            area = cv2.contourArea(contour)
            if area < self.min_area or area > self.max_area:
                continue

            # Approximate polygon (should have 4 corners for a square)
            # Use adaptive epsilon based on perimeter - larger for bigger contours
            perimeter = cv2.arcLength(contour, True)
            epsilon = max(0.02, min(0.05, 10.0 / np.sqrt(perimeter)))
            approx = cv2.approxPolyDP(contour, epsilon * perimeter, True)

            if len(approx) != 4:
                continue

            # Check if convex (commented out for perspective tolerance)
            # if not cv2.isContourConvex(approx):
            #     continue

            # Check aspect ratio (should be ~1 for squares)
            x, y, w, h = cv2.boundingRect(approx)
            aspect_ratio = float(w) / h

            if not (self.aspect_ratio_range[0] <= aspect_ratio <= self.aspect_ratio_range[1]):
                continue

            valid_contours.append(approx)

        # Sort contours by Y-position (top to bottom) for proper face ordering
        # This ensures we get top face first, then front row, then right row
        def get_centroid_y(contour):
            M = cv2.moments(contour)
            if M["m00"] != 0:
                return int(M["m01"] / M["m00"])
            return 0

        valid_contours = sorted(valid_contours, key=get_centroid_y)[:20]

        return valid_contours

    def _extract_colors(self, image: np.ndarray, contours: List[np.ndarray]) -> np.ndarray:
        """
        Extract average HSV color from center of each sticker.

        Args:
            image: Original BGR image
            contours: List of sticker contours

        Returns:
            Array of HSV colors (N x 3)
        """
        hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        colors = []

        for contour in contours:
            # Get bounding rectangle
            x, y, w, h = cv2.boundingRect(contour)

            # Sample from center 50% of the sticker (avoid edges)
            center_x = x + w // 2
            center_y = y + h // 2
            sample_size = min(w, h) // 4

            # Extract center region
            roi = hsv_image[
                center_y - sample_size:center_y + sample_size,
                center_x - sample_size:center_x + sample_size
            ]

            # Average HSV value
            if roi.size > 0:
                avg_color = np.mean(roi, axis=(0, 1))
                colors.append(avg_color)

        return np.array(colors)

    def _classify_colors_direct(self, sticker_colors: np.ndarray) -> List[str]:
        """
        Classify sticker colors directly using HSV thresholds.

        More robust than K-means for small sample sizes. Uses known Rubik's cube
        color ranges in HSV space (OpenCV convention: H=0-180, S=0-255, V=0-255).

        Args:
            sticker_colors: Array of HSV colors (N x 3)

        Returns:
            List of face color strings ('W', 'Y', 'R', 'O', 'B', 'G')
        """
        colors = []
        for hsv in sticker_colors:
            hue, sat, val = hsv

            # Very dark pixels = black body (should have been filtered, but just in case)
            if val < 50:
                colors.append('W')  # Default to white if very dark
                continue

            # Low saturation = White (or gray background)
            # Blender renders: white stickers have S=0, colored corners go as low as S=38
            if sat < 30:
                colors.append('W')
                continue

            # Use hue to determine color (OpenCV HSV: H is 0-180)
            # Boundaries calibrated for Blender Cycles renders with standard lighting
            if hue < 12 or hue > 170:
                colors.append('R')
            elif 12 <= hue < 28:
                colors.append('O')
            elif 28 <= hue < 35:
                colors.append('Y')
            elif 35 <= hue < 85:
                colors.append('G')
            elif 85 <= hue < 135:
                colors.append('B')
            else:
                colors.append('R')  # Purple/magenta → treat as red

        return colors

    def _classify_colors_kmeans(self, sticker_colors: np.ndarray, n_clusters=6) -> np.ndarray:
        """
        Use K-Means clustering to group stickers into 6 colors.

        Args:
            sticker_colors: Array of HSV colors (N x 3)
            n_clusters: Number of color clusters (6 for Rubik's Cube)

        Returns:
            Array of cluster labels for each sticker
        """
        # K-Means clustering
        self.kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        labels = self.kmeans.fit_predict(sticker_colors)

        return labels

    def _map_clusters_to_faces(
        self,
        cluster_labels: np.ndarray,
        contours: List[np.ndarray],
        image_shape: Tuple
    ) -> List[str]:
        """
        Map cluster IDs to face color names (W, Y, R, O, B, G).

        Uses HSV hue values from K-Means cluster centers to identify colors.

        Args:
            cluster_labels: Cluster ID for each sticker
            contours: Sticker contours
            image_shape: Image dimensions

        Returns:
            List of face colors for 15 stickers
        """
        # Get cluster centers from K-Means (HSV values)
        cluster_centers = self.kmeans.cluster_centers_

        # Map each cluster to a face color based on HSV values
        color_mapping = {}

        for cluster_id, center in enumerate(cluster_centers):
            hue, saturation, value = center

            # Use HSV to determine color
            # Low saturation = White or Gray (desaturated colors)
            if saturation < 50:
                # Could be white, black, or gray
                if value > 150:
                    color = 'W'  # White
                elif value < 100:
                    color = 'B'  # Black (unlikely on a standard cube, but possible)
                else:
                    color = 'W'  # Gray - treat as white
            else:
                # Use hue to determine color
                # OpenCV HSV: H is 0-180, S is 0-255, V is 0-255
                if hue < 10 or hue > 170:
                    color = 'R'  # Red
                elif 10 <= hue < 25:
                    color = 'O'  # Orange
                elif 25 <= hue < 40:
                    color = 'Y'  # Yellow
                elif 40 <= hue < 85:
                    color = 'G'  # Green
                elif 85 <= hue < 130:
                    color = 'B'  # Blue
                else:
                    # Purple/Violet - uncommon, might be misclassified
                    color = 'R'  # Default to red

            color_mapping[cluster_id] = color

        # Map stickers to face colors
        face_colors = [color_mapping[label] for label in cluster_labels[:15]]

        return face_colors

    def _classify_cluster_colors(self, cluster_centers: np.ndarray) -> List[str]:
        """
        Classify K-means cluster centers as cube colors or background.

        Args:
            cluster_centers: 6x3 array of HSV cluster centers

        Returns:
            List of 6 color labels: 'R', 'O', 'Y', 'G', 'B', 'W', or 'BACKGROUND'
        """
        colors = []

        for center in cluster_centers:
            hue, saturation, value = center

            # Very low saturation and low/mid value = background (gray/black)
            if saturation < 40 and value < 180:
                colors.append('BACKGROUND')
                continue

            # Low saturation, high value = White
            if saturation < 50 and value > 150:
                colors.append('W')
                continue

            # High saturation = colored sticker
            # Use hue to determine color (OpenCV HSV: H is 0-180)
            if hue < 10 or hue > 170:
                colors.append('R')  # Red
            elif 10 <= hue < 25:
                colors.append('O')  # Orange
            elif 25 <= hue < 40:
                colors.append('Y')  # Yellow
            elif 40 <= hue < 85:
                colors.append('G')  # Green
            elif 85 <= hue < 130:
                colors.append('B')  # Blue (even low-saturation blue)
            else:
                # Purple/Violet or unusual - might be background
                colors.append('BACKGROUND')

        return colors

    def _annotate_image_with_grid(
        self,
        image: np.ndarray,
        hexagon: np.ndarray,
        y_junction: Tuple[int, int],
        grids: List[List[Tuple[int, int]]],
        face_colors: List[str]
    ) -> np.ndarray:
        """
        Draw hexagon, Y-junction, grid points, and colors on the image.

        Args:
            image: Original image
            hexagon: 6 vertices of the hexagon
            y_junction: (x, y) coordinates of Y-junction
            grids: List of 3 grids (top, front, right), each with 9 points
            face_colors: 15 detected colors

        Returns:
            Annotated image
        """
        color_map = {
            'W': (255, 255, 255),  # White
            'Y': (0, 255, 255),    # Yellow
            'R': (0, 0, 255),      # Red
            'O': (0, 165, 255),    # Orange
            'B': (255, 0, 0),      # Blue
            'G': (0, 255, 0),      # Green
        }

        # Draw hexagon outline
        hexagon_int = hexagon.astype(np.int32)
        cv2.polylines(image, [hexagon_int], isClosed=True, color=(255, 0, 255), thickness=3)

        # Draw Y-junction
        cv2.circle(image, y_junction, 8, (255, 0, 255), -1)
        cv2.putText(image, 'Y', (y_junction[0] - 10, y_junction[1] - 10),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 0, 255), 2)

        # Draw ALL grid points with indices to show what we're sampling
        face_names = ['TOP', 'FRONT', 'RIGHT']
        color_index = 0

        for grid_idx, grid in enumerate(grids):
            face_name = face_names[grid_idx]
            num_points_sampled = 9 if grid_idx == 0 else 3

            # Draw ALL 9 points in each grid to show the full 3×3 layout
            for i in range(min(9, len(grid))):
                point = grid[i]

                # Is this point being sampled for color detection?
                is_sampled = i < num_points_sampled

                if is_sampled and color_index < len(face_colors):
                    # Sampled point - draw with detected color
                    color = face_colors[color_index]
                    bgr_color = color_map.get(color, (128, 128, 128))
                    cv2.circle(image, point, 7, bgr_color, -1)

                    # Draw color label
                    cv2.putText(
                        image,
                        f"{color}",
                        (point[0] - 8, point[1] + 5),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.5,
                        (0, 0, 0),
                        2
                    )
                    color_index += 1
                else:
                    # Not sampled - draw as gray circle
                    cv2.circle(image, point, 4, (100, 100, 100), 1)

                # Draw index number for ALL points
                cv2.putText(
                    image,
                    str(i),
                    (point[0] - 6, point[1] + 20),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.4,
                    (255, 255, 255),
                    1
                )

                # Highlight center piece (index 4) with a special marker
                if i == 4:
                    cv2.circle(image, point, 10, (0, 255, 255), 2)
                    cv2.putText(
                        image,
                        "CENTER",
                        (point[0] - 25, point[1] - 15),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.4,
                        (0, 255, 255),
                        1
                    )

        return image

    def _annotate_image(
        self,
        image: np.ndarray,
        contours: List[np.ndarray],
        face_colors: List[str]
    ) -> np.ndarray:
        """
        Draw detected stickers and their colors on the image.
        (DEPRECATED - kept for backward compatibility with old contour-based method)

        Args:
            image: Original image
            contours: Sticker contours
            face_colors: Classified colors

        Returns:
            Annotated image
        """
        color_map = {
            'W': (255, 255, 255),  # White
            'Y': (0, 255, 255),    # Yellow
            'R': (0, 0, 255),      # Red
            'O': (0, 165, 255),    # Orange
            'B': (255, 0, 0),      # Blue
            'G': (0, 255, 0),      # Green
        }

        for i, (contour, color) in enumerate(zip(contours[:15], face_colors)):
            # Draw contour
            cv2.drawContours(image, [contour], -1, color_map.get(color, (255, 255, 255)), 3)

            # Draw label
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
                cv2.putText(
                    image,
                    color,
                    (cx - 10, cy + 10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.6,
                    (0, 0, 0),
                    2
                )

        return image


if __name__ == "__main__":
    # Test the vision pipeline
    import sys

    if len(sys.argv) < 2:
        print("Usage: python cube_vision.py <image_path>")
        sys.exit(1)

    vision = CubeVision()
    try:
        colors, annotated = vision.detect_stickers(sys.argv[1])
        print(f"Detected colors: {colors}")

        # Save annotated image
        output_path = "annotated_" + sys.argv[1].split('/')[-1]
        cv2.imwrite(output_path, annotated)
        print(f"Annotated image saved to: {output_path}")
    except Exception as e:
        print(f"Error: {e}")

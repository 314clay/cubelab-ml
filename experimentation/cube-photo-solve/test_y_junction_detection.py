"""
Test script for Y-junction detection with visualization.

Usage:
    python test_y_junction_detection.py IMG_1053_small.jpg
"""

import cv2
import numpy as np
from pathlib import Path
import sys
from y_junction_detector import find_y_junction_candidates


def visualize_candidates(image: np.ndarray, candidates: list) -> np.ndarray:
    """
    Draw annotated visualization showing Y-junction candidates.

    Args:
        image: BGR image
        candidates: List of (x, y, score, details) tuples

    Returns:
        Annotated BGR image
    """
    vis_image = image.copy()
    h, w = image.shape[:2]

    # Draw all candidates with color coding by score
    for i, (x, y, score, details) in enumerate(candidates):
        # Color code by score
        if score >= 80:
            color = (0, 255, 0)  # Green - high confidence
        elif score >= 60:
            color = (0, 255, 255)  # Yellow - medium confidence
        elif score >= 40:
            color = (0, 165, 255)  # Orange - low confidence
        else:
            color = (128, 128, 128)  # Gray - very low

        # Draw circle
        if i == 0:
            # Top candidate - large red circle with crosshairs
            cv2.circle(vis_image, (x, y), 15, (0, 0, 255), 3)
            cv2.line(vis_image, (x - 20, y), (x + 20, y), (0, 0, 255), 2)
            cv2.line(vis_image, (x, y - 20), (x, y + 20), (0, 0, 255), 2)
        else:
            # Other candidates - smaller circles
            cv2.circle(vis_image, (x, y), 8, color, 2)

        # Draw score label
        label = f"{score:.1f}"
        label_pos = (x + 12, y - 12)
        cv2.putText(vis_image, label, label_pos, cv2.FONT_HERSHEY_SIMPLEX,
                    0.5, color, 2)

        # For top candidate, draw edge directions and angles
        if i == 0 and 'edge_angles' in details and len(details['edge_angles']) == 3:
            edge_angles = details['edge_angles']
            edge_colors = [(0, 0, 255), (0, 255, 0), (255, 0, 0)]  # Red, Green, Blue

            # Draw edges
            for angle_deg, edge_color in zip(edge_angles, edge_colors):
                angle_rad = np.radians(angle_deg)
                length = 40
                end_x = int(x + length * np.cos(angle_rad))
                end_y = int(y + length * np.sin(angle_rad))
                cv2.line(vis_image, (x, y), (end_x, end_y), edge_color, 3)

                # Label edge angle
                label_x = int(x + (length + 10) * np.cos(angle_rad))
                label_y = int(y + (length + 10) * np.sin(angle_rad))
                cv2.putText(vis_image, f"{angle_deg:.0f}°", (label_x, label_y),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.4, edge_color, 1)

            # Draw angles between edges
            if 'angles_between' in details:
                angles_between = details['angles_between']
                # Position angle labels between the edge lines
                sorted_edges = sorted(edge_angles)
                for i, angle_between in enumerate(angles_between):
                    angle1 = sorted_edges[i]
                    angle2 = sorted_edges[(i + 1) % 3]
                    mid_angle = (angle1 + angle2) / 2
                    if mid_angle - angle1 > 180:
                        mid_angle -= 180

                    mid_angle_rad = np.radians(mid_angle)
                    label_dist = 55
                    label_x = int(x + label_dist * np.cos(mid_angle_rad))
                    label_y = int(y + label_dist * np.sin(mid_angle_rad))

                    cv2.putText(vis_image, f"({angle_between:.0f}°)", (label_x, label_y),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)

    return vis_image


def main(image_path: str):
    """Test Y-junction detection on a single image."""
    print("=" * 60)
    print("=== Y-JUNCTION DETECTION ===")
    print("=" * 60)

    # Load image
    if not Path(image_path).exists():
        print(f"Error: Image not found: {image_path}")
        return

    image = cv2.imread(image_path)
    if image is None:
        print(f"Error: Failed to load image: {image_path}")
        return

    h, w = image.shape[:2]
    print(f"Image: {Path(image_path).name} ({w}x{h})")

    # Run detection
    candidates = find_y_junction_candidates(image)

    if not candidates:
        print("\n⚠ No Y-junction candidates found!")
        return

    # Print top candidates
    print(f"\nTop {min(5, len(candidates))} candidates:")
    for i, (x, y, score, details) in enumerate(candidates[:5]):
        print(f"\n  {i + 1}. ({x}, {y}) - Score: {score:.1f}")

        if 'edge_angles' in details:
            print(f"     Edges at: {', '.join(f'{a:.0f}°' for a in details['edge_angles'])}")

        if 'angles_between' in details and details['angles_between']:
            print(f"     Angles between: {', '.join(f'{a:.0f}°' for a in details['angles_between'])}")

        if 'colors' in details and len(details['colors']) > 0:
            hues = [int(c[0]) for c in details['colors']]
            print(f"     Colors: {', '.join(f'H={h}' for h in hues)}")

        print(f"     Harris response: {details.get('harris_response', 0):.3f}")
        print(f"     Unique colors: {details.get('num_unique_colors', 0)}")

    # Visualize
    print("\nGenerating visualization...")
    vis_image = visualize_candidates(image, candidates)

    # Save output
    output_path = f"y_junction_debug_{Path(image_path).stem}.jpg"
    cv2.imwrite(output_path, vis_image)

    print(f"\n✓ Visualization saved to: {output_path}")
    print("=" * 60)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_y_junction_detection.py <image_path>")
        print("Example: python test_y_junction_detection.py IMG_1053_small.jpg")
        sys.exit(1)

    main(sys.argv[1])

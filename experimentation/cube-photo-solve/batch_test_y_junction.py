"""
Batch test script for Y-junction detection.

Tests Y-junction detection on all images in batch_results directory and generates summary.
"""

import cv2
from pathlib import Path
from y_junction_detector import find_y_junction_candidates


def test_image(image_path: Path):
    """Test Y-junction detection on a single image."""
    image = cv2.imread(str(image_path))
    if image is None:
        return None

    candidates = find_y_junction_candidates(image)

    if not candidates:
        return {"top_score": 0, "num_candidates": 0}

    top = candidates[0]
    return {
        "top_score": top[2],
        "top_position": (top[0], top[1]),
        "num_candidates": len(candidates),
        "top_details": top[3]
    }


def main():
    """Run batch test on all test images."""
    batch_dir = Path("batch_results_small_20260114_223837")

    if not batch_dir.exists():
        print(f"Error: Batch directory not found: {batch_dir}")
        return

    print("=" * 80)
    print("BATCH Y-JUNCTION DETECTION TEST")
    print("=" * 80)

    # Find all test images
    image_dirs = sorted([d for d in batch_dir.iterdir() if d.is_dir()])

    results = []

    for img_dir in image_dirs:
        img_path = img_dir / f"{img_dir.name}_small.jpg"

        if not img_path.exists():
            continue

        print(f"\nTesting: {img_dir.name}")
        print("-" * 40)

        result = test_image(img_path)

        if result is None:
            print("  ✗ Failed to load image")
            results.append({"image": img_dir.name, "status": "FAILED"})
            continue

        if result["num_candidates"] == 0:
            print("  ✗ No candidates found")
            results.append({"image": img_dir.name, "status": "NO_CANDIDATES"})
            continue

        print(f"  ✓ Top score: {result['top_score']:.1f}")
        print(f"  ✓ Position: {result['top_position']}")
        print(f"  ✓ Total candidates: {result['num_candidates']}")

        details = result["top_details"]
        if "num_unique_colors" in details:
            print(f"  ✓ Unique colors: {details['num_unique_colors']}")
        if "angles_between" in details:
            print(f"  ✓ Angles: {', '.join(f'{a:.0f}°' for a in details['angles_between'])}")

        results.append({
            "image": img_dir.name,
            "status": "SUCCESS",
            "score": result["top_score"]
        })

    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)

    total = len(results)
    success = sum(1 for r in results if r["status"] == "SUCCESS")
    high_score = sum(1 for r in results if r.get("score", 0) > 80)

    print(f"Total images tested: {total}")
    print(f"Successful detections: {success}/{total} ({100 * success / total:.0f}%)")
    print(f"High confidence (score > 80): {high_score}/{total}")

    if success > 0:
        avg_score = sum(r.get("score", 0) for r in results if r["status"] == "SUCCESS") / success
        print(f"Average top score: {avg_score:.1f}")


if __name__ == "__main__":
    main()

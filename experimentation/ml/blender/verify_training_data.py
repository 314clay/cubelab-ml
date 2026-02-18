"""
Spot-check training renders by running CubeVision on a random sample
and comparing detected stickers against JSON ground truth labels.

Usage:
    python3 ml/blender/verify_training_data.py [OPTIONS]

Options:
    --sample-size N   Number of renders to check (default: 50)
    --data-dir PATH   Path to training_renders directory
    --seed N          Random seed for sample selection (default: 42)
"""

import json
import os
import sys
import random
import argparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)

from cube_vision import CubeVision

DEFAULT_DATA_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "training_renders")


def load_manifest(data_dir):
    """Load manifest.json and return its contents."""
    manifest_path = os.path.join(data_dir, "manifest.json")
    if not os.path.exists(manifest_path):
        print(f"ERROR: No manifest.json in {data_dir}")
        sys.exit(1)
    with open(manifest_path) as f:
        return json.load(f)


def verify_render(image_path, label_path, vision):
    """
    Run CubeVision on one render and compare against ground truth.

    Returns:
        (correct_count, total_stickers, details_dict)
    """
    with open(label_path) as f:
        label = json.load(f)

    expected = label['visible_stickers']

    try:
        detected, _ = vision.detect_stickers(image_path)
    except Exception as e:
        return 0, len(expected), {
            "error": str(e),
            "category": "HEXAGON_FAIL",
        }

    if len(detected) != len(expected):
        return 0, len(expected), {
            "error": f"detected {len(detected)} stickers, expected {len(expected)}",
            "category": "GRID_FAIL",
        }

    correct = sum(1 for e, d in zip(expected, detected) if e == d)
    wrong = [
        {"index": i, "expected": e, "detected": d}
        for i, (e, d) in enumerate(zip(expected, detected))
        if e != d
    ]

    return correct, len(expected), {
        "correct": correct,
        "total": len(expected),
        "wrong": wrong,
    }


def main():
    parser = argparse.ArgumentParser(description="Verify training renders with CubeVision")
    parser.add_argument('--sample-size', type=int, default=50,
                        help='Number of renders to spot-check')
    parser.add_argument('--data-dir', type=str, default=DEFAULT_DATA_DIR,
                        help='Path to training_renders directory')
    parser.add_argument('--seed', type=int, default=42,
                        help='Random seed for sample selection')
    args = parser.parse_args()

    manifest = load_manifest(args.data_dir)
    renders = manifest.get('renders', [])

    if not renders:
        print("ERROR: No renders listed in manifest")
        sys.exit(1)

    rng = random.Random(args.seed)
    sample = rng.sample(renders, min(args.sample_size, len(renders)))

    print(f"Verifying {len(sample)}/{len(renders)} renders from {args.data_dir}")
    print("=" * 72)

    vision = CubeVision()

    total_correct = 0
    total_stickers = 0
    category_counts = {
        "PERFECT": 0,
        "COLOR_FAIL": 0,
        "HEXAGON_FAIL": 0,
        "GRID_FAIL": 0,
    }

    for i, render_info in enumerate(sample):
        image_file = render_info['image']
        image_path = os.path.join(args.data_dir, image_file)
        label_path = os.path.join(args.data_dir, image_file.replace('.png', '.json'))

        if not os.path.exists(image_path) or not os.path.exists(label_path):
            print(f"  [{i + 1:3d}] {image_file:55s} SKIP (files missing)")
            continue

        correct, total, details = verify_render(image_path, label_path, vision)
        total_correct += correct
        total_stickers += total

        if 'error' in details:
            cat = details['category']
            category_counts[cat] = category_counts.get(cat, 0) + 1
            print(f"  [{i + 1:3d}] {image_file:55s}  0/{total} {cat}: {details['error'][:35]}")
        elif correct == total:
            category_counts["PERFECT"] += 1
            print(f"  [{i + 1:3d}] {image_file:55s} {correct:2d}/{total} PASS")
        else:
            category_counts["COLOR_FAIL"] += 1
            wrong_idx = [w['index'] for w in details['wrong']]
            print(f"  [{i + 1:3d}] {image_file:55s} {correct:2d}/{total} FAIL stickers {wrong_idx}")

    # Summary
    accuracy = 100 * total_correct / total_stickers if total_stickers else 0
    print(f"\n{'=' * 72}")
    print("=== VERIFICATION RESULTS ===")
    print(f"  Sticker accuracy:    {total_correct}/{total_stickers} = {accuracy:.1f}%")
    print(f"  Perfect detections:  {category_counts['PERFECT']}/{len(sample)}")
    print(f"  Color failures:      {category_counts['COLOR_FAIL']}")
    print(f"  Hexagon failures:    {category_counts['HEXAGON_FAIL']}")
    print(f"  Grid failures:       {category_counts['GRID_FAIL']}")
    print("=" * 72)


if __name__ == "__main__":
    main()

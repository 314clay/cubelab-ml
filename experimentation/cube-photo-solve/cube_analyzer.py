#!/usr/bin/env python3
"""
Rubik's Cube Last Layer Analyzer
Analyzes a cube photo and identifies the OLL/PLL case with solution algorithm
"""

import argparse
import json
import sys
from pathlib import Path

import cv2

from cube_vision import CubeVision
from state_resolver import StateResolver


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Analyze Rubik\'s Cube Last Layer from a photo',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python cube_analyzer.py cube_view.jpg
  python cube_analyzer.py cube_view.jpg --output result.json
  python cube_analyzer.py cube_view.jpg --debug
        """
    )

    parser.add_argument(
        'image',
        type=str,
        help='Path to the cube image (showing Top, Front, and Right faces)'
    )

    parser.add_argument(
        '--output',
        '-o',
        type=str,
        default='cube_result.json',
        help='Output JSON file path (default: cube_result.json)'
    )

    parser.add_argument(
        '--debug',
        action='store_true',
        help='Save annotated debug image showing detected stickers'
    )

    parser.add_argument(
        '--min-area',
        type=int,
        default=1000,
        help='Minimum contour area for sticker detection (default: 1000)'
    )

    parser.add_argument(
        '--max-area',
        type=int,
        default=50000,
        help='Maximum contour area for sticker detection (default: 50000)'
    )

    args = parser.parse_args()

    # Validate input file
    if not Path(args.image).exists():
        print(f"Error: Image file not found: {args.image}", file=sys.stderr)
        sys.exit(1)

    print(f"Analyzing cube image: {args.image}")
    print("=" * 60)

    # Step 1: Initialize vision system
    print("\n[1/4] Initializing computer vision system...")
    vision = CubeVision(
        min_area=args.min_area,
        max_area=args.max_area
    )

    # Step 2: Detect and classify stickers
    print("[2/4] Detecting stickers and classifying colors...")
    try:
        detected_colors, annotated_image = vision.detect_stickers(args.image)
        print(f"✓ Detected {len(detected_colors)} stickers")
        print(f"  Colors: {' '.join(detected_colors)}")

        # Save debug image if requested
        if args.debug:
            debug_path = f"debug_{Path(args.image).name}"
            cv2.imwrite(debug_path, annotated_image)
            print(f"  Debug image saved: {debug_path}")

    except Exception as e:
        print(f"✗ Error detecting stickers: {e}", file=sys.stderr)
        sys.exit(1)

    # Step 3: Initialize state resolver
    print("\n[3/4] Building lookup table of valid Last Layer states...")
    resolver = StateResolver()

    # Step 4: Match detected state
    print("[4/4] Matching detected state...")
    match = resolver.match_state(detected_colors)

    if match:
        print(f"✓ Match found!")
        print(f"  Case: {match['combined_name']}")
        print(f"  OLL: {match['oll_case']} - {match['oll_algorithm']}")
        print(f"  PLL: {match['pll_case']} - {match['pll_algorithm']}")

        if match['rotation']:
            print(f"  Rotation applied: {match['rotation']}")

        # Build result JSON
        result = {
            'success': True,
            'case_name': match['combined_name'],
            'oll_case': match['oll_case'],
            'pll_case': match['pll_case'],
            'oll_algorithm': match['oll_algorithm'],
            'pll_algorithm': match['pll_algorithm'],
            'rotation': match['rotation'],
            'detected_colors': {
                'top': detected_colors[0:9],
                'front_row': detected_colors[9:12],
                'right_row': detected_colors[12:15]
            },
            'confidence': 1.0,
            'input_image': str(Path(args.image).absolute())
        }

    else:
        print(f"✗ No exact match found")
        print(f"  Searching for closest matches...")

        closest_matches = resolver.find_closest_matches(detected_colors, n=5)
        print(f"\n  Top 5 closest matches:")
        for i, (info, diff) in enumerate(closest_matches, 1):
            print(f"    {i}. {info['combined_name']} ({diff} stickers different)")

        # Build error result JSON
        result = {
            'success': False,
            'error': 'No exact match found in lookup table',
            'detected_colors': {
                'top': detected_colors[0:9],
                'front_row': detected_colors[9:12],
                'right_row': detected_colors[12:15]
            },
            'closest_matches': [
                {
                    'case_name': info['combined_name'],
                    'oll_case': info['oll_case'],
                    'pll_case': info['pll_case'],
                    'difference': diff
                }
                for info, diff in closest_matches
            ],
            'input_image': str(Path(args.image).absolute())
        }

    # Step 5: Write output JSON
    print(f"\n{'=' * 60}")
    print(f"Writing results to: {args.output}")

    with open(args.output, 'w') as f:
        json.dump(result, f, indent=2)

    print(f"✓ Analysis complete!")

    if not match:
        sys.exit(1)


if __name__ == "__main__":
    main()

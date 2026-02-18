#!/usr/bin/env python3
"""
Rubik's Cube Multi-Path Analyzer
Analyzes a cube photo or state string and finds multiple solving paths.
"""

import argparse
import json
import sys
from pathlib import Path


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Analyze Rubik\'s Cube and find multiple solving paths',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python cube_analyzer.py cube_view.jpg
  python cube_analyzer.py --state "W,W,W,W,W,W,W,W,W,R,R,R,B,B,B"
  python cube_analyzer.py --state "W,W,G,W,W,R,W,O,G,B,W,R,W,W,W" --max-paths 10
        """
    )

    parser.add_argument(
        'image',
        type=str,
        nargs='?',
        default=None,
        help='Path to the cube image (showing Top, Front, and Right faces)'
    )

    parser.add_argument(
        '--state',
        type=str,
        default=None,
        help='Comma-separated 15 sticker colors (9 top + 3 front + 3 right)'
    )

    parser.add_argument(
        '--output',
        '-o',
        type=str,
        default='cube_result.json',
        help='Output JSON file path (default: cube_result.json)'
    )

    parser.add_argument(
        '--max-paths',
        type=int,
        default=5,
        help='Maximum number of solving paths to return (default: 5)'
    )

    parser.add_argument(
        '--sets',
        type=str,
        nargs='+',
        default=None,
        help='Algorithm sets to load (default: all). Options: OLL PLL COLL ZBLL OLLCP'
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

    if args.image is None and args.state is None:
        parser.error("Either an image path or --state must be provided")

    # Get sticker colors from image or state string
    if args.state:
        detected_colors = [c.strip() for c in args.state.split(',')]
        if len(detected_colors) != 15:
            print(f"Error: Expected 15 stickers, got {len(detected_colors)}", file=sys.stderr)
            sys.exit(1)
        input_source = "state_string"
    else:
        if not Path(args.image).exists():
            print(f"Error: Image file not found: {args.image}", file=sys.stderr)
            sys.exit(1)

        import cv2
        from cube_vision import CubeVision

        print(f"Analyzing cube image: {args.image}")
        print("=" * 60)

        print("\n[1/3] Detecting stickers...")
        vision = CubeVision(min_area=args.min_area, max_area=args.max_area)

        try:
            detected_colors, annotated_image = vision.detect_stickers(args.image)
            print(f"  Detected {len(detected_colors)} stickers: {' '.join(detected_colors)}")

            if args.debug:
                debug_path = f"debug_{Path(args.image).name}"
                cv2.imwrite(debug_path, annotated_image)
                print(f"  Debug image saved: {debug_path}")
        except Exception as e:
            print(f"Error detecting stickers: {e}", file=sys.stderr)
            sys.exit(1)

        input_source = str(Path(args.image).absolute())

    # Phase detection and solving
    from phase_detector import PhaseDetector
    from solver import CubeSolver

    print("\n[2/3] Detecting phase...")
    detector = PhaseDetector()
    phase_result = detector.detect_phase(detected_colors)
    print(f"  Phase: {phase_result.phase}")
    print(f"  Applicable sets: {phase_result.applicable_sets}")
    print(f"  Confidence: {phase_result.confidence:.0%}")

    if phase_result.phase == "solved":
        result = {
            "input": input_source,
            "detected_stickers": detected_colors,
            "phase": "solved",
            "paths": [],
        }
        print("\n  Cube is already solved!")
    else:
        print(f"\n[3/3] Finding solving paths (max {args.max_paths})...")
        solver = CubeSolver(sets=args.sets)
        paths = solver.solve(detected_colors, max_paths=args.max_paths)

        result = {
            "input": input_source,
            "detected_stickers": detected_colors,
            "phase": phase_result.phase,
            "paths": [],
        }

        if paths:
            for i, path in enumerate(paths, 1):
                path_entry = {
                    "rank": i,
                    "total_moves": path.total_moves,
                    "description": path.description,
                    "steps": [
                        {
                            "set": step.algorithm_set,
                            "case": step.case_name,
                            "algorithm": step.algorithm,
                            "moves": step.move_count,
                        }
                        for step in path.steps
                    ],
                }
                result["paths"].append(path_entry)
                print(f"  Path {i} ({path.total_moves} moves): {path.description}")
                for step in path.steps:
                    print(f"    {step.algorithm_set} {step.case_name}: {step.algorithm}")
        else:
            print("  No solving paths found.")

    # Write output
    print(f"\n{'=' * 60}")
    print(f"Writing results to: {args.output}")
    with open(args.output, 'w') as f:
        json.dump(result, f, indent=2)
    print("Done!")


if __name__ == "__main__":
    main()

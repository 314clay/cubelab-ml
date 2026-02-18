"""
End-to-end test harness: Run CV pipeline on verified Blender renders
and score accuracy against known ground truth.
"""

import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from cube_vision import CubeVision
from state_resolver import StateResolver

RENDERS_DIR = Path(__file__).parent.parent.parent / "ml" / "data" / "verified_renders"


def load_all_test_cases():
    """Load all render JSON labels from verified_renders/."""
    cases = []
    for json_file in sorted(RENDERS_DIR.glob("*.json")):
        with open(json_file) as f:
            label = json.load(f)
        image_path = RENDERS_DIR / label["image"]
        if image_path.exists():
            cases.append((label, str(image_path)))
    return cases


TEST_CASES = load_all_test_cases()


def classify_failure(vision_result, ground_truth):
    """
    Classify why the pipeline failed.

    Returns one of:
    - HEXAGON_FAIL: Could not detect cube outline
    - YJUNCTION_FAIL: Y-junction detection failed
    - GRID_FAIL: Grid sampling returned wrong positions
    - COLOR_FAIL: Colors misclassified
    - RESOLVER_FAIL: Colors correct but resolver returned wrong case
    - PASS: Everything correct
    """
    if vision_result is None:
        return "HEXAGON_FAIL"

    detected_colors, _ = vision_result
    if detected_colors is None or len(detected_colors) != 15:
        return "HEXAGON_FAIL"

    # Count correct stickers
    expected = ground_truth["visible_stickers"]
    correct = sum(1 for d, e in zip(detected_colors, expected) if d == e)

    if correct == 15:
        return "PASS"
    elif correct < 5:
        return "GRID_FAIL"  # So many wrong that grid is probably off
    else:
        return "COLOR_FAIL"


@pytest.fixture(scope="module")
def vision():
    return CubeVision()


@pytest.fixture(scope="module")
def resolver():
    return StateResolver()


class TestEndToEndAccuracy:
    """Score the CV pipeline on all verified renders."""

    @pytest.mark.parametrize("label,image_path",
                             TEST_CASES,
                             ids=[c[0]["image"] for c in TEST_CASES])
    def test_sticker_detection(self, vision, label, image_path):
        """Detect stickers and compare against ground truth."""
        expected = label["visible_stickers"]

        try:
            result = vision.detect_stickers(image_path)
            if result is None:
                detected = None
            else:
                detected, _ = result
        except Exception as e:
            pytest.fail(f"CubeVision crashed: {e}")
            return

        if detected is None:
            pytest.fail(
                f"HEXAGON_FAIL: Could not detect cube in {label['image']}. "
                f"Expected: {expected}"
            )
            return

        if len(detected) != 15:
            pytest.fail(
                f"Wrong sticker count: got {len(detected)}, expected 15. "
                f"Detected: {detected}"
            )
            return

        # Score
        correct = sum(1 for d, e in zip(detected, expected) if d == e)
        wrong_indices = [i for i, (d, e) in enumerate(zip(detected, expected)) if d != e]

        if correct < 15:
            failure_type = classify_failure((detected, None), label)
            detail = f"{correct}/15 correct. Wrong at indices {wrong_indices}. "
            detail += f"Detected: {detected}. Expected: {expected}. "
            detail += f"Failure type: {failure_type}"
            pytest.fail(detail)


class TestEndToEndResolver:
    """For renders where vision is correct, verify resolver returns the right case."""

    @pytest.mark.parametrize("label,image_path",
                             TEST_CASES,
                             ids=[c[0]["image"] for c in TEST_CASES])
    def test_full_pipeline(self, vision, resolver, label, image_path):
        """Full pipeline: image -> stickers -> OLL/PLL case."""
        try:
            result = vision.detect_stickers(image_path)
            if result is None:
                pytest.skip("Vision failed - skipping resolver test")
                return
            detected, _ = result
        except Exception:
            pytest.skip("Vision crashed - skipping resolver test")
            return

        if detected is None or len(detected) != 15:
            pytest.skip("Vision returned invalid stickers")
            return

        # Check resolver
        match = resolver.match_state(detected)
        closest = resolver.find_closest_matches(detected, n=3)

        expected_oll = label["oll_case"]
        expected_pll = label["pll_case"]

        if match is not None:
            assert match["oll_case"] == expected_oll, \
                f"OLL mismatch: got {match['oll_case']}, expected {expected_oll}"
            assert match["pll_case"] == expected_pll, \
                f"PLL mismatch: got {match['pll_case']}, expected {expected_pll}"
        else:
            closest_info = [(m['combined_name'], d) for m, d in closest]
            pytest.fail(
                f"RESOLVER_FAIL: No exact match. "
                f"Expected: {expected_oll} + {expected_pll}. "
                f"Closest: {closest_info}"
            )


def run_accuracy_report():
    """Standalone accuracy report (run directly, not via pytest)."""
    vision = CubeVision()
    resolver = StateResolver()

    print("=== END TO END RESULTS ===")
    total_correct = 0
    total_stickers = 0
    results = []

    for label, image_path in TEST_CASES:
        expected = label["visible_stickers"]
        name = label["image"]

        try:
            result = vision.detect_stickers(image_path)
            if result is None:
                detected = None
            else:
                detected, _ = result
        except Exception as e:
            detected = None
            print(f"{name:30s} ERROR: {e}")
            continue

        if detected is None:
            print(f"{name:30s}  0/15 correct (HEXAGON_FAIL)")
            total_stickers += 15
            results.append((name, 0, 15, "HEXAGON_FAIL"))
            continue

        correct = sum(1 for d, e in zip(detected, expected) if d == e)
        total_correct += correct
        total_stickers += 15

        wrong = [i for i, (d, e) in enumerate(zip(detected, expected)) if d != e]
        failure_type = classify_failure((detected, None), label)
        status = "PASS" if correct == 15 else f"FAIL - {failure_type} wrong@{wrong}"
        print(f"{name:30s} {correct:2d}/15 correct ({status})")
        results.append((name, correct, 15, failure_type))

        # Also test resolver
        match = resolver.match_state(detected)
        if match:
            resolver_status = f"-> {match['combined_name']}"
        else:
            closest = resolver.find_closest_matches(detected, n=1)
            if closest:
                resolver_status = f"-> closest: {closest[0][0]['combined_name']} (diff {closest[0][1]})"
            else:
                resolver_status = "-> no match"
        print(f"{'':30s} Resolver: {resolver_status}")

    pct = (total_correct / total_stickers * 100) if total_stickers > 0 else 0
    print(f"=== AGGREGATE: {total_correct}/{total_stickers} = {pct:.1f}% ===")
    return pct


if __name__ == "__main__":
    run_accuracy_report()

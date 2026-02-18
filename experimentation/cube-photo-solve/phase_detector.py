"""
PhaseDetector: Identify the solving phase of a Rubik's Cube from visible stickers.

Given 15 visible stickers (9 top + 3 front row + 3 right row), determines
which solving phase the cube is in and which algorithm sets apply.
"""

from dataclasses import dataclass, field
from typing import List


OPPOSITE_COLOR = {"W": "Y", "Y": "W", "R": "O", "O": "R", "G": "B", "B": "G"}


@dataclass
class PhaseResult:
    phase: str
    applicable_sets: List[str]
    confidence: float
    details: dict = field(default_factory=dict)


class PhaseDetector:
    """Given visible stickers or full cube state, detect solving phase."""

    SOLVED = "solved"
    PLL = "pll"
    OLL_EDGES_ORIENTED = "oll_edges_oriented"
    OLL = "oll"
    F2L_LAST_PAIR = "f2l_last_pair"
    F2L_PARTIAL = "f2l_partial"
    UNKNOWN = "unknown"

    def detect_phase(self, visible_stickers: List[str]) -> PhaseResult:
        """
        Detect the solving phase from 15 visible stickers.

        The 15 visible stickers are all part of the last layer:
        - 9 top face stickers
        - 3 front face top row stickers
        - 3 right face top row stickers

        Since we can't see the F2L directly, we use a heuristic:
        if the bottom color (opposite of top center) doesn't appear in any
        visible sticker, F2L is likely solved.
        """
        if len(visible_stickers) != 15:
            return PhaseResult(
                phase=self.UNKNOWN,
                applicable_sets=[],
                confidence=0.0,
                details={"error": f"Expected 15 stickers, got {len(visible_stickers)}"},
            )

        top = visible_stickers[0:9]
        front_row = visible_stickers[9:12]
        right_row = visible_stickers[12:15]
        top_center = top[4]

        # Heuristic: if the bottom-face color appears in the visible stickers,
        # the F2L is disrupted. LL-only algorithms never expose the bottom color.
        bottom_color = OPPOSITE_COLOR.get(top_center)
        has_bottom_color = bottom_color is not None and bottom_color in visible_stickers

        if has_bottom_color:
            return PhaseResult(
                phase=self.F2L_PARTIAL,
                applicable_sets=["F2L"],
                confidence=0.7,
                details={
                    "bottom_color_found": bottom_color,
                    "front_row": front_row,
                    "right_row": right_row,
                },
            )

        # F2L likely solved — analyze the top face to determine LL phase
        top_matching = sum(1 for s in top if s == top_center)
        top_edges = [top[1], top[3], top[5], top[7]]
        top_corners = [top[0], top[2], top[6], top[8]]
        edges_matching = sum(1 for s in top_edges if s == top_center)
        corners_matching = sum(1 for s in top_corners if s == top_center)

        if top_matching == 9:
            # Top fully oriented → PLL or solved
            # If both side rows are uniform and all 3 colors are distinct,
            # this is very likely solved
            front_uniform = len(set(front_row)) == 1
            right_uniform = len(set(right_row)) == 1
            if front_uniform and right_uniform:
                front_color = front_row[0]
                right_color = right_row[0]
                all_different = len({top_center, front_color, right_color}) == 3
                if all_different:
                    return PhaseResult(
                        phase=self.SOLVED,
                        applicable_sets=[],
                        confidence=0.9,
                        details={
                            "top_center": top_center,
                            "front_color": front_color,
                            "right_color": right_color,
                            "note": "All visible stickers consistent with solved state",
                        },
                    )

            return PhaseResult(
                phase=self.PLL,
                applicable_sets=["PLL"],
                confidence=0.95,
                details={
                    "top_matching": top_matching,
                    "front_row": front_row,
                    "right_row": right_row,
                    "top_center": top_center,
                },
            )

        if edges_matching == 4:
            # All 4 edges match center, but not all corners
            # Edges oriented → COLL or ZBLL territory
            return PhaseResult(
                phase=self.OLL_EDGES_ORIENTED,
                applicable_sets=["COLL", "ZBLL"],
                confidence=0.9,
                details={
                    "top_matching": top_matching,
                    "edges_matching": edges_matching,
                    "corners_matching": corners_matching,
                    "top_center": top_center,
                },
            )

        # Top not fully oriented → OLL
        return PhaseResult(
            phase=self.OLL,
            applicable_sets=["OLL", "OLLCP"],
            confidence=0.9,
            details={
                "top_matching": top_matching,
                "edges_matching": edges_matching,
                "corners_matching": corners_matching,
                "top_center": top_center,
            },
        )

    def detect_phase_full(self, cube) -> PhaseResult:
        """
        Detect phase from a full Cube object (all 6 faces visible).
        More accurate than detect_phase since we see all stickers.
        """
        if cube.is_solved():
            return PhaseResult(
                phase=self.SOLVED,
                applicable_sets=[],
                confidence=1.0,
                details={"note": "Cube is fully solved"},
            )

        if cube.is_f2l_solved():
            # F2L done — determine LL phase
            if cube.is_ll_edges_oriented():
                # Check if top face is fully oriented
                uc = cube.faces['U'][4]
                top_all_match = all(s == uc for s in cube.faces['U'])
                if top_all_match:
                    return PhaseResult(
                        phase=self.PLL,
                        applicable_sets=["PLL"],
                        confidence=1.0,
                    )
                return PhaseResult(
                    phase=self.OLL_EDGES_ORIENTED,
                    applicable_sets=["COLL", "ZBLL"],
                    confidence=1.0,
                )
            return PhaseResult(
                phase=self.OLL,
                applicable_sets=["OLL", "OLLCP"],
                confidence=1.0,
            )

        if cube.is_cross_solved():
            solved_pairs = cube.count_solved_pairs()
            unsolved = cube.get_unsolved_slots()
            if solved_pairs == 3:
                return PhaseResult(
                    phase=self.F2L_LAST_PAIR,
                    applicable_sets=["F2L", "ZBLS"],
                    confidence=1.0,
                    details={
                        "solved_pairs": solved_pairs,
                        "unsolved_slot": unsolved[0],
                    },
                )
            return PhaseResult(
                phase=self.F2L_PARTIAL,
                applicable_sets=["F2L"],
                confidence=1.0,
                details={"solved_pairs": solved_pairs, "unsolved_slots": unsolved},
            )

        return PhaseResult(
            phase=self.F2L_PARTIAL,
            applicable_sets=[],
            confidence=0.8,
            details={"note": "Cross not solved"},
        )

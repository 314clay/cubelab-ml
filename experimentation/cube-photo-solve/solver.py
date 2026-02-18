"""
CubeSolver: Find multiple algorithm paths from a cube state to solved.

The lookup tables map visible stickers to the algorithm that CREATED the state
(by being applied to a solved cube). To SOLVE the state, we apply the INVERSE
of that algorithm.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from algorithms import parse_algorithm
from phase_detector import PhaseDetector
from state_resolver import Cube, ExpandedStateResolver


@dataclass
class SolveStep:
    algorithm_set: str
    case_name: str
    algorithm: str
    move_count: int
    phase_before: str
    phase_after: str


@dataclass
class SolvePath:
    steps: List[SolveStep]
    total_moves: int
    description: str


def inverse_algorithm(alg_string: str) -> str:
    """Compute the inverse of an algorithm string.

    Reverses the move order and inverts each move:
    R → R', R' → R, R2 → R2
    """
    moves = parse_algorithm(alg_string)
    if not moves:
        return ""
    inv_moves = []
    for move in reversed(moves):
        if move.endswith("'"):
            inv_moves.append(move[:-1])
        elif move.endswith("2"):
            inv_moves.append(move)
        else:
            inv_moves.append(move + "'")
    return " ".join(inv_moves)


class CubeSolver:
    """Find multiple algorithm paths from a cube state to solved."""

    def __init__(self, sets=None):
        self.resolver = ExpandedStateResolver(sets=sets)
        self.phase_detector = PhaseDetector()

    def solve(self, visible_stickers: List[str], max_paths: int = 5) -> List[SolvePath]:
        """
        Find multiple solving paths from the detected state.

        Returns list of SolvePath objects, ranked by total move count.
        """
        if len(visible_stickers) != 15:
            return []

        phase_result = self.phase_detector.detect_phase(visible_stickers)

        if phase_result.phase in ("solved", "unknown"):
            return []

        paths = []

        # For PLL phase: look up in PLL table for direct one-step solutions
        if phase_result.phase == "pll":
            self._find_direct_solutions(
                visible_stickers, "PLL", phase_result.phase, paths
            )

        # For OLL phase: try multiple strategies
        if phase_result.phase == "oll":
            # Strategy 1: OLL → PLL chain
            self._find_two_step_solutions(
                visible_stickers, "OLL", phase_result.phase, paths
            )
            # Strategy 2: OLLCP (may skip PLL or reduce to EPLL)
            self._find_two_step_solutions(
                visible_stickers, "OLLCP", phase_result.phase, paths
            )
            # Strategy 3: Combined OLL+PLL lookup (for combined scrambles)
            self._find_combined_oll_pll_solutions(
                visible_stickers, phase_result.phase, paths
            )

        # For edges-oriented phase: try COLL, ZBLL, OLL, and combined OLL_PLL
        if phase_result.phase == "oll_edges_oriented":
            # Strategy 1: ZBLL one-look solve
            self._find_direct_solutions(
                visible_stickers, "ZBLL", phase_result.phase, paths
            )
            # Strategy 2: COLL → PLL chain
            self._find_two_step_solutions(
                visible_stickers, "COLL", phase_result.phase, paths
            )
            # Strategy 3: OLL → PLL chain (OLL works on edges-oriented too)
            self._find_two_step_solutions(
                visible_stickers, "OLL", phase_result.phase, paths
            )
            # Strategy 4: Combined OLL+PLL lookup
            self._find_combined_oll_pll_solutions(
                visible_stickers, phase_result.phase, paths
            )

        # For F2L partial: limited — just report the phase
        # F2L solving from 15 stickers is not well-supported

        # Deduplicate by description
        seen = set()
        unique_paths = []
        for path in paths:
            key = path.description
            if key not in seen:
                seen.add(key)
                unique_paths.append(path)

        unique_paths.sort(key=lambda p: p.total_moves)
        return unique_paths[:max_paths]

    def _find_combined_oll_pll_solutions(self, visible_stickers: List[str],
                                            phase_before: str,
                                            paths: List[SolvePath]):
        """Find solutions using the combined OLL×PLL table."""
        matches = self.resolver.lookup(visible_stickers, set_name="OLL_PLL")
        for match in matches:
            oll_alg = match.get('oll_algorithm', '')
            pll_alg = match.get('pll_algorithm', '')

            if not oll_alg:
                continue

            # Solution order: first undo PLL (inverse), then undo OLL (inverse)
            # Scramble was: solved → OLL_alg → PLL_alg
            # Solve is:     state → PLL_inv → OLL_inv → solved
            pll_solve = inverse_algorithm(pll_alg) if pll_alg else ""
            oll_solve = inverse_algorithm(oll_alg)

            steps = []
            total = 0

            if pll_alg:
                pll_moves = len(parse_algorithm(pll_solve))
                steps.append(SolveStep(
                    algorithm_set="PLL",
                    case_name=match.get('pll_case', ''),
                    algorithm=pll_solve,
                    move_count=pll_moves,
                    phase_before=phase_before,
                    phase_after="oll",
                ))
                total += pll_moves

            oll_moves = len(parse_algorithm(oll_solve))
            steps.append(SolveStep(
                algorithm_set="OLL",
                case_name=match.get('oll_case', ''),
                algorithm=oll_solve,
                move_count=oll_moves,
                phase_before="oll" if pll_alg else phase_before,
                phase_after="solved",
            ))
            total += oll_moves

            # Verify the solution
            cube = Cube()
            cube.apply_algorithm(oll_alg)
            if pll_alg:
                cube.apply_algorithm(pll_alg)
            # Solve: PLL_inv then OLL_inv
            if pll_solve:
                cube.apply_algorithm(pll_solve)
            cube.apply_algorithm(oll_solve)

            if all(len(set(f)) == 1 for f in cube.faces.values()):
                desc_parts = [match.get('oll_case', '')]
                if pll_alg:
                    pll_name = match.get('pll_case', 'PLL')
                    if pll_name != "Solved":
                        desc_parts.append(pll_name)
                    else:
                        desc_parts.append("PLL Skip")
                paths.append(SolvePath(
                    steps=steps,
                    total_moves=total,
                    description=" → ".join(desc_parts),
                ))

    def _find_direct_solutions(self, visible_stickers: List[str],
                                 set_name: str, phase_before: str,
                                 paths: List[SolvePath]):
        """Find one-step solutions by looking up in a table and inverting."""
        matches = self.resolver.lookup(visible_stickers, set_name=set_name)
        for match in matches:
            scramble_alg = match['algorithm']
            if not scramble_alg:
                continue
            solve_alg = inverse_algorithm(scramble_alg)
            move_count = len(parse_algorithm(solve_alg))

            # Verify: reconstruct full state and apply inverse
            cube = Cube()
            cube.apply_algorithm(scramble_alg)  # Recreate the state
            cube.apply_algorithm(solve_alg)      # Apply inverse

            if all(len(set(f)) == 1 for f in cube.faces.values()):
                paths.append(SolvePath(
                    steps=[SolveStep(
                        algorithm_set=set_name,
                        case_name=match['case'],
                        algorithm=solve_alg,
                        move_count=move_count,
                        phase_before=phase_before,
                        phase_after="solved",
                    )],
                    total_moves=move_count,
                    description=f"{match['case']}",
                ))

    def _find_two_step_solutions(self, visible_stickers: List[str],
                                   first_set: str, phase_before: str,
                                   paths: List[SolvePath]):
        """Find two-step solutions: first_set → PLL."""
        matches = self.resolver.lookup(visible_stickers, set_name=first_set)
        for match in matches:
            scramble_alg = match['algorithm']
            if not scramble_alg:
                continue
            solve_alg_1 = inverse_algorithm(scramble_alg)
            move_count_1 = len(parse_algorithm(solve_alg_1))

            # Reconstruct the state and apply the inverse to get PLL state
            cube = Cube()
            cube.apply_algorithm(scramble_alg)
            cube.apply_algorithm(solve_alg_1)

            # Check result
            result_phase = self.phase_detector.detect_phase_full(cube)

            if result_phase.phase == "solved":
                # No PLL needed — first step solved everything
                paths.append(SolvePath(
                    steps=[SolveStep(
                        algorithm_set=first_set,
                        case_name=match['case'],
                        algorithm=solve_alg_1,
                        move_count=move_count_1,
                        phase_before=phase_before,
                        phase_after="solved",
                    )],
                    total_moves=move_count_1,
                    description=f"{match['case']} → PLL Skip",
                ))
            elif result_phase.phase == "pll":
                # Need PLL step — look up
                result_visible = cube.get_visible_stickers()
                pll_matches = self.resolver.lookup(result_visible, set_name="PLL")
                for pll_match in pll_matches:
                    pll_scramble = pll_match['algorithm']
                    if not pll_scramble:
                        # Already solved
                        paths.append(SolvePath(
                            steps=[SolveStep(
                                algorithm_set=first_set,
                                case_name=match['case'],
                                algorithm=solve_alg_1,
                                move_count=move_count_1,
                                phase_before=phase_before,
                                phase_after="solved",
                            )],
                            total_moves=move_count_1,
                            description=f"{match['case']} → PLL Skip",
                        ))
                        continue

                    pll_solve = inverse_algorithm(pll_scramble)
                    move_count_2 = len(parse_algorithm(pll_solve))

                    # Verify the full chain solves the cube
                    verify_cube = Cube()
                    verify_cube.apply_algorithm(scramble_alg)
                    verify_cube.apply_algorithm(solve_alg_1)
                    verify_cube.apply_algorithm(pll_solve)

                    if all(len(set(f)) == 1 for f in verify_cube.faces.values()):
                        paths.append(SolvePath(
                            steps=[
                                SolveStep(
                                    algorithm_set=first_set,
                                    case_name=match['case'],
                                    algorithm=solve_alg_1,
                                    move_count=move_count_1,
                                    phase_before=phase_before,
                                    phase_after="pll",
                                ),
                                SolveStep(
                                    algorithm_set="PLL",
                                    case_name=pll_match['case'],
                                    algorithm=pll_solve,
                                    move_count=move_count_2,
                                    phase_before="pll",
                                    phase_after="solved",
                                ),
                            ],
                            total_moves=move_count_1 + move_count_2,
                            description=f"{match['case']} → {pll_match['case']}",
                        ))

    def verify_path(self, visible_stickers: List[str], path: SolvePath) -> bool:
        """Verify that applying all steps in a path produces a solved cube.

        Reconstructs the full cube state from the first step's lookup match,
        then applies all solving algorithms.
        """
        # Find the original scramble algorithm from the first step
        first_step = path.steps[0]
        first_matches = self.resolver.lookup(
            visible_stickers, set_name=first_step.algorithm_set
        )

        for match in first_matches:
            if match['case'] == first_step.case_name:
                # Reconstruct full state
                cube = Cube()
                cube.apply_algorithm(match['algorithm'])

                # Apply all solving steps
                for step in path.steps:
                    try:
                        cube.apply_algorithm(step.algorithm)
                    except (ValueError, Exception):
                        return False

                return all(len(set(f)) == 1 for f in cube.faces.values())

        return False

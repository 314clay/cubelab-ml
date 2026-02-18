"""
CubeSolver: Find multiple algorithm paths from a cube state to solved.

The lookup tables map visible stickers to the algorithm that CREATED the state
(by being applied to a solved cube). To SOLVE the state, we apply the INVERSE
of that algorithm.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from algorithms import parse_algorithm, F2L_CASES, ZBLS_CASES
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
            # Strategy 3: ELL direct (15-sticker can't distinguish ELL from OLL)
            self._find_direct_solutions(
                visible_stickers, "ELL", phase_result.phase, paths
            )
            # Strategy 4: Combined OLL+PLL lookup (for combined scrambles)
            self._find_combined_oll_pll_solutions(
                visible_stickers, phase_result.phase, paths
            )

        # For ELL phase: corners solved, only edges remain
        if phase_result.phase == "ell":
            # Strategy 1: ELL direct solve
            self._find_direct_solutions(
                visible_stickers, "ELL", phase_result.phase, paths
            )
            # Strategy 2: PLL can also solve edges-only states
            self._find_direct_solutions(
                visible_stickers, "PLL", phase_result.phase, paths
            )

        # For edges-oriented phase: try COLL, ZBLL, OLL, and combined OLL_PLL
        if phase_result.phase == "oll_edges_oriented":
            # Strategy 1: ZBLL one-look solve
            self._find_direct_solutions(
                visible_stickers, "ZBLL", phase_result.phase, paths
            )
            # Strategy 2: ELL direct (edges-oriented ELL = EPLL subset)
            self._find_direct_solutions(
                visible_stickers, "ELL", phase_result.phase, paths
            )
            # Strategy 3: COLL → ELL chain
            self._find_two_step_solutions(
                visible_stickers, "COLL", phase_result.phase, paths,
                second_set="ELL"
            )
            # Strategy 4: COLL → PLL chain
            self._find_two_step_solutions(
                visible_stickers, "COLL", phase_result.phase, paths
            )
            # Strategy 5: OLL → PLL chain (OLL works on edges-oriented too)
            self._find_two_step_solutions(
                visible_stickers, "OLL", phase_result.phase, paths
            )
            # Strategy 6: Combined OLL+PLL lookup
            self._find_combined_oll_pll_solutions(
                visible_stickers, phase_result.phase, paths
            )

        # For F2L partial: limited from 15 stickers — use solve_from_cube() instead

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
                                   paths: List[SolvePath],
                                   second_set: str = "PLL"):
        """Find two-step solutions: first_set → second_set (default PLL)."""
        matches = self.resolver.lookup(visible_stickers, set_name=first_set)
        for match in matches:
            scramble_alg = match['algorithm']
            if not scramble_alg:
                continue
            solve_alg_1 = inverse_algorithm(scramble_alg)
            move_count_1 = len(parse_algorithm(solve_alg_1))

            # Reconstruct the state and apply the inverse
            cube = Cube()
            cube.apply_algorithm(scramble_alg)
            cube.apply_algorithm(solve_alg_1)

            # Check result
            result_phase = self.phase_detector.detect_phase_full(cube)

            if result_phase.phase == "solved":
                # No second step needed — first step solved everything
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
                    description=f"{match['case']} → {second_set} Skip",
                ))
            elif result_phase.phase in ("pll", "ell") or second_set in result_phase.applicable_sets:
                # Need second step — look up
                result_visible = cube.get_visible_stickers()
                second_matches = self.resolver.lookup(result_visible, set_name=second_set)
                for second_match in second_matches:
                    second_scramble = second_match['algorithm']
                    if not second_scramble:
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
                            description=f"{match['case']} → {second_set} Skip",
                        ))
                        continue

                    second_solve = inverse_algorithm(second_scramble)
                    move_count_2 = len(parse_algorithm(second_solve))

                    # Verify the full chain solves the cube
                    verify_cube = Cube()
                    verify_cube.apply_algorithm(scramble_alg)
                    verify_cube.apply_algorithm(solve_alg_1)
                    verify_cube.apply_algorithm(second_solve)

                    if all(len(set(f)) == 1 for f in verify_cube.faces.values()):
                        second_phase = "ell" if second_set == "ELL" else "pll"
                        paths.append(SolvePath(
                            steps=[
                                SolveStep(
                                    algorithm_set=first_set,
                                    case_name=match['case'],
                                    algorithm=solve_alg_1,
                                    move_count=move_count_1,
                                    phase_before=phase_before,
                                    phase_after=second_phase,
                                ),
                                SolveStep(
                                    algorithm_set=second_set,
                                    case_name=second_match['case'],
                                    algorithm=second_solve,
                                    move_count=move_count_2,
                                    phase_before=second_phase,
                                    phase_after="solved",
                                ),
                            ],
                            total_moves=move_count_1 + move_count_2,
                            description=f"{match['case']} → {second_match['case']}",
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

    # ------------------------------------------------------------------
    # Full-cube solving (supports F2L and ZBLS phases)
    # ------------------------------------------------------------------

    AUF_SETUPS = ['', 'U', 'U2', "U'"]

    def solve_from_cube(self, cube: 'Cube', max_paths: int = 5) -> 'List[SolvePath]':
        """Find solving paths from a full cube state.

        Unlike solve() which uses 15 visible stickers, this accepts a full
        Cube object and can handle F2L-level states via trial-based matching.

        Supports paths like:
          - F2L → OLL → PLL
          - ZBLS → ZBLL
          - ZBLS → COLL → PLL
          - (plus all existing LL paths)
        """
        phase_result = self.phase_detector.detect_phase_full(cube)

        if phase_result.phase in ("solved", "unknown"):
            return []

        paths = []

        if phase_result.phase == "f2l_last_pair":
            # Try F2L → LL chains
            self._find_f2l_solutions(cube, paths)
            # Try ZBLS → LL chains
            self._find_zbls_solutions(cube, paths)

        elif phase_result.phase in ("pll", "oll", "oll_edges_oriented", "ell"):
            # Delegate to existing 15-sticker solver for LL phases
            visible = cube.get_visible_stickers()
            return self.solve(visible, max_paths=max_paths)

        elif phase_result.phase == "f2l_partial":
            # Multiple pairs unsolved — can't solve with single F2L alg
            return []

        # Deduplicate and rank
        seen = set()
        unique_paths = []
        for path in paths:
            key = path.description
            if key not in seen:
                seen.add(key)
                unique_paths.append(path)

        unique_paths.sort(key=lambda p: p.total_moves)
        return unique_paths[:max_paths]

    def _try_f2l_alg(self, cube: 'Cube', case_name: str, alg: str,
                      auf: str) -> 'Optional[Cube]':
        """Try applying AUF + inverse of an F2L/ZBLS alg. Return resulting cube or None."""
        solve_alg = inverse_algorithm(alg)
        test = cube.copy()
        try:
            if auf:
                test.apply_algorithm(auf)
            test.apply_algorithm(solve_alg)
        except (ValueError, Exception):
            return None
        return test

    def _find_f2l_solutions(self, cube: 'Cube', paths: 'List[SolvePath]'):
        """Find F2L → LL solving paths by trial.

        For each F2L algorithm × 4 AUF setups, apply the inverse and check
        if F2L becomes solved. If so, continue with LL solving.
        """
        for case_name, alg in F2L_CASES.items():
            if not alg:
                continue
            for auf in self.AUF_SETUPS:
                result = self._try_f2l_alg(cube, case_name, alg, auf)
                if result is None or not result.is_f2l_solved():
                    continue

                # F2L solved — now solve LL
                f2l_solve = inverse_algorithm(alg)
                full_f2l = f"{auf} {f2l_solve}".strip() if auf else f2l_solve
                f2l_moves = len(parse_algorithm(full_f2l))

                f2l_step = SolveStep(
                    algorithm_set="F2L",
                    case_name=f"{case_name}" + (f" (AUF {auf})" if auf else ""),
                    algorithm=full_f2l,
                    move_count=f2l_moves,
                    phase_before="f2l_last_pair",
                    phase_after="",  # filled below
                )

                # Solve LL from the post-F2L state
                ll_visible = result.get_visible_stickers()
                ll_paths = self.solve(ll_visible, max_paths=3)

                if not ll_paths:
                    # F2L solved the whole cube (unlikely) or no LL match
                    if result.is_solved():
                        f2l_step.phase_after = "solved"
                        paths.append(SolvePath(
                            steps=[f2l_step],
                            total_moves=f2l_moves,
                            description=f"{case_name} → Solved",
                        ))
                    continue

                for ll_path in ll_paths:
                    # Verify full path against original cube
                    verify = cube.copy()
                    try:
                        verify.apply_algorithm(full_f2l)
                        for s in ll_path.steps:
                            verify.apply_algorithm(s.algorithm)
                    except (ValueError, Exception):
                        continue
                    if not verify.is_solved():
                        continue

                    f2l_step_copy = SolveStep(
                        algorithm_set=f2l_step.algorithm_set,
                        case_name=f2l_step.case_name,
                        algorithm=f2l_step.algorithm,
                        move_count=f2l_step.move_count,
                        phase_before=f2l_step.phase_before,
                        phase_after=ll_path.steps[0].phase_before,
                    )
                    combined_steps = [f2l_step_copy] + ll_path.steps
                    total = f2l_moves + ll_path.total_moves
                    desc = f"{case_name} → {ll_path.description}"
                    paths.append(SolvePath(
                        steps=combined_steps,
                        total_moves=total,
                        description=desc,
                    ))

    def _find_zbls_solutions(self, cube: 'Cube', paths: 'List[SolvePath]'):
        """Find ZBLS → LL solving paths by trial.

        ZBLS solves F2L + orients LL edges. After ZBLS, the cube is in
        oll_edges_oriented phase → ZBLL or COLL+PLL.
        """
        for case_name, alg in ZBLS_CASES.items():
            if not alg:
                continue
            for auf in self.AUF_SETUPS:
                result = self._try_f2l_alg(cube, case_name, alg, auf)
                if result is None:
                    continue
                # ZBLS postcondition: F2L solved AND LL edges oriented
                if not result.is_f2l_solved() or not result.is_ll_edges_oriented():
                    continue

                zbls_solve = inverse_algorithm(alg)
                full_zbls = f"{auf} {zbls_solve}".strip() if auf else zbls_solve
                zbls_moves = len(parse_algorithm(full_zbls))

                zbls_step = SolveStep(
                    algorithm_set="ZBLS",
                    case_name=f"{case_name}" + (f" (AUF {auf})" if auf else ""),
                    algorithm=full_zbls,
                    move_count=zbls_moves,
                    phase_before="f2l_last_pair",
                    phase_after="",
                )

                # After ZBLS: edges oriented → ZBLL, COLL+PLL, or solved
                ll_visible = result.get_visible_stickers()
                ll_paths = self.solve(ll_visible, max_paths=3)

                if not ll_paths:
                    if result.is_solved():
                        zbls_step.phase_after = "solved"
                        paths.append(SolvePath(
                            steps=[zbls_step],
                            total_moves=zbls_moves,
                            description=f"{case_name} → Solved",
                        ))
                    continue

                for ll_path in ll_paths:
                    # Verify full path against original cube
                    verify = cube.copy()
                    try:
                        verify.apply_algorithm(full_zbls)
                        for s in ll_path.steps:
                            verify.apply_algorithm(s.algorithm)
                    except (ValueError, Exception):
                        continue
                    if not verify.is_solved():
                        continue

                    zbls_step_copy = SolveStep(
                        algorithm_set=zbls_step.algorithm_set,
                        case_name=zbls_step.case_name,
                        algorithm=zbls_step.algorithm,
                        move_count=zbls_step.move_count,
                        phase_before=zbls_step.phase_before,
                        phase_after=ll_path.steps[0].phase_before,
                    )
                    combined_steps = [zbls_step_copy] + ll_path.steps
                    total = zbls_moves + ll_path.total_moves
                    desc = f"{case_name} (ZBLS) → {ll_path.description}"
                    paths.append(SolvePath(
                        steps=combined_steps,
                        total_moves=total,
                        description=desc,
                    ))


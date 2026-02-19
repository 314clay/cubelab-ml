"""
Ergonomic scorer and move simplification for F2L algorithms.

Scores algorithms by summing per-move costs, regrip penalties, and trigger
bonuses. Lower score = more ergonomic. Also provides stack-based move
simplification (cancellation/merging of consecutive same-face moves).
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# 1. Move costs — base cost for each individual move token
# ---------------------------------------------------------------------------

MOVE_COSTS: dict[str, float] = {
    "R": 1.0, "R'": 1.0, "R2": 1.2,
    "U": 1.0, "U'": 1.0, "U2": 1.3,
    "r": 1.1, "r'": 1.1,
    "F": 1.8, "F'": 1.8, "F2": 2.0,
    "L": 2.0, "L'": 2.0, "L2": 2.2,
    "D": 2.5, "D'": 2.5, "D2": 2.7,
    "B": 3.5, "B'": 3.5, "B2": 3.8,
}

# ---------------------------------------------------------------------------
# 2. Regrip detection — grip zones and penalties
# ---------------------------------------------------------------------------

# Each move belongs to a grip zone. Switching zones costs a regrip penalty.
MOVE_GRIP_ZONE: dict[str, str] = {
    "R": "standard", "R'": "standard", "R2": "standard",
    "U": "standard", "U'": "standard", "U2": "standard",
    "r": "standard", "r'": "standard",
    "L": "left",  "L'": "left",  "L2": "left",
    "F": "front", "F'": "front", "F2": "front",
    "D": "down",  "D'": "down",  "D2": "down",
    "B": "back",  "B'": "back",  "B2": "back",
}

REGRIP_PENALTY = 2.0
# standard <-> front is common (e.g. F after R U R'), so reduced penalty.
REDUCED_REGRIP_PENALTY = 1.0

_REDUCED_REGRIP_PAIRS = frozenset([
    ("standard", "front"),
    ("front", "standard"),
])


def _count_regrip_cost(moves: list[str]) -> float:
    """Walk the move list and accumulate regrip penalties."""
    cost = 0.0
    prev_zone: str | None = None
    for m in moves:
        zone = MOVE_GRIP_ZONE.get(m)
        if zone is None:
            continue  # unknown move — skip
        if prev_zone is not None and zone != prev_zone:
            if (prev_zone, zone) in _REDUCED_REGRIP_PAIRS:
                cost += REDUCED_REGRIP_PENALTY
            else:
                cost += REGRIP_PENALTY
        prev_zone = zone
    return cost


# ---------------------------------------------------------------------------
# 3. Trigger bonuses — common ergonomic patterns get a negative bonus
# ---------------------------------------------------------------------------

# Each entry is (move_sequence, bonus). Bonus is negative (reduces score).
# Sorted longest-first so greedy matching prefers longer triggers.
TRIGGER_BONUSES: list[tuple[list[str], float]] = sorted(
    [
        (["R", "U", "R'", "U'"],           -2.0),   # sexy move
        (["R", "U'", "R'", "U"],            -2.0),   # reverse sexy
        (["R", "U", "R'"],                  -1.5),   # right insert
        (["R'", "U'", "R"],                 -1.5),   # reverse right insert
        (["R", "U'", "R'"],                 -1.5),   # right insert variant
        (["R'", "U", "R"],                  -1.5),   # reverse right insert variant
        (["R", "U2", "R'"],                 -1.0),   # wide insert
        (["L'", "U'", "L"],                 -1.0),   # left insert
        (["L'", "U", "L"],                  -1.0),   # left insert variant
        (["R'", "F", "R", "F'"],            -1.5),   # sledgehammer
        (["F", "R", "U", "R'", "U'", "F'"], -2.0),  # OLL trigger
    ],
    key=lambda t: len(t[0]),
    reverse=True,  # longest first
)


def _apply_trigger_bonuses(moves: list[str]) -> float:
    """Greedy left-to-right, longest-first trigger matching.

    Returns total bonus (negative value = score improvement).
    Consumed positions are skipped so triggers don't overlap.
    """
    consumed: set[int] = set()
    total_bonus = 0.0

    i = 0
    while i < len(moves):
        if i in consumed:
            i += 1
            continue
        matched = False
        for pattern, bonus in TRIGGER_BONUSES:
            plen = len(pattern)
            if i + plen > len(moves):
                continue
            # Collect non-consumed positions for this window
            positions = []
            j = i
            while j < len(moves) and len(positions) < plen:
                if j not in consumed:
                    positions.append(j)
                j += 1
            if len(positions) < plen:
                continue
            # Check if the moves at these positions match the pattern
            if all(moves[positions[k]] == pattern[k] for k in range(plen)):
                for p in positions:
                    consumed.add(p)
                total_bonus += bonus
                matched = True
                break  # restart scan from next position
        if not matched:
            i += 1
        else:
            i += 1
    return total_bonus


# ---------------------------------------------------------------------------
# 4. Top-level scoring function
# ---------------------------------------------------------------------------

def parse_algorithm(alg: str) -> list[str]:
    """Split an algorithm string into a list of move tokens."""
    return alg.strip().split()


def ergonomic_score(algorithm: str) -> float:
    """Score an algorithm string. Lower = more ergonomic.

    Total = sum(move costs) + regrip penalties + trigger bonuses.
    """
    moves = parse_algorithm(algorithm)
    if not moves:
        return 0.0

    # Per-move base costs
    cost = sum(MOVE_COSTS.get(m, 3.0) for m in moves)

    # Regrip penalties
    cost += _count_regrip_cost(moves)

    # Trigger bonuses (negative values reduce cost)
    cost += _apply_trigger_bonuses(moves)

    return cost


# ---------------------------------------------------------------------------
# 5. Move simplification — stack-based cancellation and merging
# ---------------------------------------------------------------------------

# Quarter-turn count modulo 4: how many clockwise quarter turns each suffix
# represents. R=1, R2=2, R'=3.  R+R = 2 qturns = R2, etc.
def _move_quarters(move: str) -> int:
    """Return the quarter-turn count (1, 2, or 3) for a move token."""
    if move.endswith("2"):
        return 2
    elif move.endswith("'"):
        return 3  # a prime is 3 quarter-turns (== -1 mod 4)
    else:
        return 1


def _base_face(move: str) -> str:
    """Strip modifier suffix to get the base face letter (e.g. R' -> R)."""
    if move.endswith("'") or move.endswith("2"):
        return move[:-1]
    return move


def _quarters_to_move(face: str, quarters: int) -> str | None:
    """Convert a face + quarter-turn count (mod 4) back to a move string.

    Returns None when quarters == 0 (moves cancel completely).
    """
    q = quarters % 4
    if q == 0:
        return None
    elif q == 1:
        return face
    elif q == 2:
        return f"{face}2"
    else:  # q == 3
        return f"{face}'"


def simplify_moves(moves: list[str]) -> list[str]:
    """Stack-based cancellation and merging of consecutive same-face moves.

    Examples:
        ["R", "R"]   -> ["R2"]
        ["R", "R'"]  -> []
        ["R", "R", "R"] -> ["R'"]  (3 quarter-turns = inverse)
        ["R2", "R2"] -> []         (4 quarter-turns = identity)
        ["R2", "R'"] -> ["R"]
    """
    stack: list[str] = []
    for move in moves:
        if not stack:
            stack.append(move)
            continue

        top = stack[-1]
        if _base_face(top) == _base_face(move):
            # Same face — merge quarter-turn counts
            combined = (_move_quarters(top) + _move_quarters(move)) % 4
            stack.pop()
            result = _quarters_to_move(_base_face(move), combined)
            if result is not None:
                stack.append(result)
            # If result is None the moves cancelled completely — nothing pushed
        else:
            stack.append(move)

    return stack


# ---------------------------------------------------------------------------
# 6. Self-tests
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=" * 60)
    print("Running _scorer self-tests")
    print("=" * 60)

    errors = 0

    def check(label: str, got, expected):
        global errors
        ok = got == expected
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {label}: got={got!r}, expected={expected!r}")
        if not ok:
            errors += 1

    # -- simplify_moves tests --
    print("\n--- simplify_moves ---")
    check("R + R = R2",
          simplify_moves(["R", "R"]), ["R2"])
    check("R + R' = cancel",
          simplify_moves(["R", "R'"]), [])
    check("R + R + R = R'",
          simplify_moves(["R", "R", "R"]), ["R'"])
    check("R2 + R2 = cancel",
          simplify_moves(["R2", "R2"]), [])
    check("R2 + R' = R",
          simplify_moves(["R2", "R'"]), ["R"])
    check("R' + R2 = R",
          simplify_moves(["R'", "R2"]), ["R"])
    check("No merge across different faces",
          simplify_moves(["R", "U", "R"]), ["R", "U", "R"])

    # -- ergonomic_score tests --
    print("\n--- ergonomic_score ---")

    sexy_score = ergonomic_score("R U R' U'")
    print(f"  Sexy move score: {sexy_score:.2f}")
    # 4 cheap moves (1+1+1+1=4) + no regrips + sexy trigger (-2.0) = 2.0
    check("Sexy move = 2.0", sexy_score, 2.0)

    bad_score = ergonomic_score("B D' B' D")
    print(f"  B D' B' D score: {bad_score:.2f}")
    # B=3.5 + D'=2.5 + B'=3.5 + D=2.5 = 12.0
    # Regrips: back->down (2.0) + down->back (2.0) + back->down (2.0) = 6.0
    # No triggers match => 18.0
    check("Bad alg has regrips", bad_score > 15.0, True)

    rur_sexy = ergonomic_score("R U R' U' R U R'")
    print(f"  R U R' U' R U R' score: {rur_sexy:.2f}")
    # Move costs: 7 * 1.0 = 7.0, no regrips
    # Sexy trigger on first 4 moves: -2.0, right insert on last 3: -1.5
    # Total = 7.0 - 2.0 - 1.5 = 3.5
    check("Sexy + insert trigger bonus", rur_sexy, 3.5)

    empty_score = ergonomic_score("")
    check("Empty alg = 0", empty_score, 0.0)

    # -- Regrip-specific tests --
    print("\n--- Regrip detection ---")
    # standard->front should be reduced penalty
    rf_cost = _count_regrip_cost(["R", "F"])
    check("R->F reduced regrip = 1.0", rf_cost, 1.0)

    # standard->left should be full penalty
    rl_cost = _count_regrip_cost(["R", "L"])
    check("R->L full regrip = 2.0", rl_cost, 2.0)

    # No regrip within same zone
    ru_cost = _count_regrip_cost(["R", "U", "R'"])
    check("R U R' no regrip = 0.0", ru_cost, 0.0)

    print("\n" + "=" * 60)
    if errors == 0:
        print("All tests passed!")
    else:
        print(f"{errors} test(s) FAILED")
    print("=" * 60)

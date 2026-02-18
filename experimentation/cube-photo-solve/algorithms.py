"""
Algorithm Database for CubeLab
Loads from algorithm_db.json (fetched from spencerchubb/cubingapp).
Falls back to hardcoded OLL/PLL if JSON not available.
"""

import json
import os

_DB_PATH = os.path.join(os.path.dirname(__file__), "algorithm_db.json")
_db = None


def _load_db():
    """Load the algorithm database from JSON."""
    global _db
    if _db is not None:
        return _db
    if os.path.exists(_DB_PATH):
        with open(_DB_PATH) as f:
            _db = json.load(f)
    else:
        _db = {"algorithm_sets": {}}
    return _db


def _get_cases_dict(set_name: str) -> dict:
    """Get {case_name: algorithm_string} for a given algorithm set."""
    db = _load_db()
    alg_set = db.get("algorithm_sets", {}).get(set_name, {})
    cases = alg_set.get("cases", {})
    return {name: info["algorithm"] for name, info in cases.items()}


# ---- Primary dict interfaces (used by StateResolver and tests) ----

# OLL (Orientation of Last Layer) - 57 cases
# Hardcoded as canonical source; JSON overrides only if present
OLL_CASES = {
    "OLL 1": "R U2 R2 F R F' U2 R' F R F'",
    "OLL 2": "F R U R' U' F' f R U R' U' f'",
    "OLL 3": "f R U R' U' f' U' F R U R' U' F'",
    "OLL 4": "f R U R' U' f' U F R U R' U' F'",
    "OLL 5": "r' U2 R U R' U r",
    "OLL 6": "r U2 R' U' R U' r'",
    "OLL 7": "r U R' U R U2 r'",
    "OLL 8": "r' U' R U' R' U2 r",
    "OLL 9": "R U R' U' R' F R2 U R' U' F'",
    "OLL 10": "R U R' U R' F R F' R U2 R'",
    "OLL 11": "r U R' U R' F R F' R U2 r'",
    "OLL 12": "M' R' U' R U' R' U2 R U' R r'",
    "OLL 13": "F U R U' R2 F' R U R U' R'",
    "OLL 14": "R' F R U R' F' R F U' F'",
    "OLL 15": "r' U' r R' U' R U r' U r",
    "OLL 16": "r U r' R U R' U' r U' r'",
    "OLL 17": "R U R' U R' F R F' U2 R' F R F'",
    "OLL 18": "r U R' U R U2 r2 U' R U' R' U2 r",
    "OLL 19": "M U R U R' U' M' R' F R F'",
    "OLL 20": "M U R U R' U' M2 U R U' r'",
    "OLL 21": "R U2 R' U' R U R' U' R U' R'",
    "OLL 22": "R U2 R2 U' R2 U' R2 U2 R",
    "OLL 23": "R2 D' R U2 R' D R U2 R",
    "OLL 24": "r U R' U' r' F R F'",
    "OLL 25": "F' r U R' U' r' F R",
    "OLL 26": "R U2 R' U' R U' R'",
    "OLL 27": "R U R' U R U2 R'",
    "OLL 28": "r U R' U' r' R U R U' R'",
    "OLL 29": "R U R' U' R U' R' F' U' F R U R'",
    "OLL 30": "F R' F R2 U' R' U' R U R' F2",
    "OLL 31": "R' U' F U R U' R' F' R",
    "OLL 32": "L U F' U' L' U L F L'",
    "OLL 33": "R U R' U' R' F R F'",
    "OLL 34": "R U R2 U' R' F R U R U' F'",
    "OLL 35": "R U2 R2 F R F' R U2 R'",
    "OLL 36": "L' U' L U' L' U L U L F' L' F",
    "OLL 37": "F R U' R' U' R U R' F'",
    "OLL 38": "R U R' U R U' R' U' R' F R F'",
    "OLL 39": "L F' L' U' L U F U' L'",
    "OLL 40": "R' F R U R' U' F' U R",
    "OLL 41": "R U R' U R U2 R' F R U R' U' F'",
    "OLL 42": "R' U' R U' R' U2 R F R U R' U' F'",
    "OLL 43": "F' U' L' U L F",
    "OLL 44": "F U R U' R' F'",
    "OLL 45": "F R U R' U' F'",
    "OLL 46": "R' U' R' F R F' U R",
    "OLL 47": "R' U' R' F R F' R' F R F' U R",
    "OLL 48": "F R U R' U' R U R' U' F'",
    "OLL 49": "r U' r2 U r2 U r2 U' r",
    "OLL 50": "r' U r2 U' r2 U' r2 U r'",
    "OLL 51": "f R U R' U' R U R' U' f'",
    "OLL 52": "R' F' U' F U' R U R' U R",
    "OLL 53": "r' U' R U' R' U R U' R' U2 r",
    "OLL 54": "r U R' U R U' R' U R U2 r'",
    "OLL 55": "R U2 R2 U' R U' R' U2 F R F'",
    "OLL 56": "r U r' U R U' R' U R U' R' r U' r'",
    "OLL 57": "R U R' U' M' U R U' r'",
    "Sune": "R U R' U R U2 R'",
    "Anti-Sune": "R U2 R' U' R U' R'",
}

# PLL (Permutation of Last Layer) - 21 cases
PLL_CASES = {
    "T-Perm": "R U R' U' R' F R2 U' R' U' R U R' F'",
    "J-Perm (a)": "x R2 F R F' R U2 r' U r U2 x'",
    "J-Perm (b)": "R U R' F' R U R' U' R' F R2 U' R'",
    "F-Perm": "R' U' F' R U R' U' R' F R2 U' R' U' R U R' U R",
    "R-Perm (a)": "R U' R' U' R U R D R' U' R D' R' U2 R'",
    "R-Perm (b)": "R' U2 R U2 R' F R U R' U' R' F' R2",
    "Y-Perm": "F R U' R' U' R U R' F' R U R' U' R' F R F'",
    "V-Perm": "R' U R' U' y R' F' R2 U' R' U R' F R F",
    "N-Perm (a)": "R U R' U R U R' F' R U R' U' R' F R2 U' R' U2 R U' R'",
    "N-Perm (b)": "R' U R U' R' F' U' F R U R' F R' F' R U' R",
    "U-Perm (a)": "R2 U R U R' U' R' U' R' U R'",
    "U-Perm (b)": "R' U R' U' R' U' R' U R U R2",
    "Z-Perm": "M2 U M2 U M' U2 M2 U2 M' U2",
    "H-Perm": "M2 U M2 U2 M2 U M2",
    "A-Perm (a)": "x R' U R' D2 R U' R' D2 R2 x'",
    "A-Perm (b)": "x R2 D2 R U R' D2 R U' R x'",
    "G-Perm (a)": "R2 U R' U R' U' R U' R2 D U' R' U R D'",
    "G-Perm (b)": "R' U' R U D' R2 U R' U R U' R U' R2 D",
    "G-Perm (c)": "R2 U' R U' R U R' U R2 D' U R U' R' D",
    "G-Perm (d)": "R U R' U' D R2 U' R U' R' U R' U R2 D'",
    "Solved": "",
}

# Extended algorithm sets loaded from JSON
COLL_CASES = _get_cases_dict("COLL")
ZBLL_CASES = _get_cases_dict("ZBLL")
OLLCP_CASES = _get_cases_dict("OLLCP")
F2L_CASES = _get_cases_dict("F2L")
WV_CASES = _get_cases_dict("WV")


def parse_algorithm(alg_string):
    """Parse algorithm string into list of moves.
    Example: "R U R' U'" -> ['R', 'U', "R'", "U'"]
    """
    if not alg_string:
        return []
    return alg_string.split()


def get_all_algorithm_sets():
    """Return all algorithm sets as {set_name: {case_name: algorithm}}."""
    return {
        "OLL": OLL_CASES.copy(),
        "PLL": PLL_CASES.copy(),
        "COLL": COLL_CASES.copy(),
        "ZBLL": ZBLL_CASES.copy(),
        "OLLCP": OLLCP_CASES.copy(),
        "F2L": F2L_CASES.copy(),
        "WV": WV_CASES.copy(),
    }


def get_algorithm_set_metadata():
    """Return metadata for each algorithm set from the JSON database."""
    db = _load_db()
    metadata = {}
    for set_name, set_data in db.get("algorithm_sets", {}).items():
        metadata[set_name] = {
            "phase": set_data.get("phase", ""),
            "precondition": set_data.get("precondition", ""),
            "postcondition": set_data.get("postcondition", ""),
            "count": set_data.get("count", 0),
        }
    return metadata


def get_algorithm_by_name(case_name):
    """Get algorithm by case name. Searches all algorithm sets."""
    all_sets = get_all_algorithm_sets()
    for set_cases in all_sets.values():
        if case_name in set_cases:
            return set_cases[case_name]
    return None


if __name__ == "__main__":
    all_sets = get_all_algorithm_sets()
    total = sum(len(cases) for cases in all_sets.values())
    print(f"Total algorithms across all sets: {total}")
    for name, cases in all_sets.items():
        print(f"  {name}: {len(cases)} cases")

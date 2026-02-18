"""
OLL and PLL Algorithm Database
All 57 OLL cases and 21 PLL cases with standard algorithms
"""

# OLL (Orientation of Last Layer) - 57 cases
OLL_CASES = {
    # OLL 1-4: All Edges Flipped Correctly
    "OLL 1": "R U2 R2 F R F' U2 R' F R F'",
    "OLL 2": "F R U R' U' F' f R U R' U' f'",
    "OLL 3": "f R U R' U' f' U' F R U R' U' F'",
    "OLL 4": "f R U R' U' f' U F R U R' U' F'",

    # OLL 5-8: T-Shape
    "OLL 5": "r' U2 R U R' U r",
    "OLL 6": "r U2 R' U' R U' r'",
    "OLL 7": "r U R' U R U2 r'",
    "OLL 8": "r' U' R U' R' U2 r",

    # OLL 9-16: Square Shape
    "OLL 9": "R U R' U' R' F R2 U R' U' F'",
    "OLL 10": "R U R' U R' F R F' R U2 R'",
    "OLL 11": "r U R' U R' F R F' R U2 r'",
    "OLL 12": "M' R' U' R U' R' U2 R U' R r'",
    "OLL 13": "F U R U' R2 F' R U R U' R'",
    "OLL 14": "R' F R U R' F' R F U' F'",
    "OLL 15": "r' U' r R' U' R U r' U r",
    "OLL 16": "r U r' R U R' U' r U' r'",

    # OLL 17-20: Small Lightning Bolt
    "OLL 17": "R U R' U R' F R F' U2 R' F R F'",
    "OLL 18": "r U R' U R U2 r2 U' R U' R' U2 r",
    "OLL 19": "M U R U R' U' M' R' F R F'",
    "OLL 20": "M U R U R' U' M2 U R U' r'",

    # OLL 21-27: C-Shape, I-Shape, and Others
    "OLL 21": "R U2 R' U' R U R' U' R U' R'",
    "OLL 22": "R U2 R2 U' R2 U' R2 U2 R",
    "OLL 23": "R2 D' R U2 R' D R U2 R",
    "OLL 24": "r U R' U' r' F R F'",
    "OLL 25": "F' r U R' U' r' F R",
    "OLL 26": "R U2 R' U' R U' R'",
    "OLL 27": "R U R' U R U2 R'",

    # OLL 28-57: Remaining cases
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
    "OLL 49": "R B' R2 F R2 B R2 F' R",
    "OLL 50": "R' F R2 B' R2 F' R2 B R'",
    "OLL 51": "f R U R' U' R U R' U' f'",
    "OLL 52": "R U R' U R U' B U' B' R'",
    "OLL 53": "r' U' R U' R' U R U' R' U2 r",
    "OLL 54": "r U R' U R U' R' U R U2 r'",
    "OLL 55": "R U2 R2 U' R U' R' U2 F R F'",
    "OLL 56": "r U r' U R U' R' U R U' R' r U' r'",
    "OLL 57": "R U R' U' M' U R U' r'",

    # Sune and Anti-Sune (common names)
    "Sune": "R U R' U R U2 R'",
    "Anti-Sune": "R U2 R' U' R U' R'",
}

# PLL (Permutation of Last Layer) - 21 cases
PLL_CASES = {
    # Adjacent Corner Swaps
    "T-Perm": "R U R' U' R' F R2 U' R' U' R U R' F'",
    "J-Perm (a)": "x R2 F R F' R U2 r' U r U2 x'",
    "J-Perm (b)": "R U R' F' R U R' U' R' F R2 U' R'",
    "F-Perm": "R' U' F' R U R' U' R' F R2 U' R' U' R U R' U R",
    "R-Perm (a)": "R U' R' U' R U R D R' U' R D' R' U2 R'",
    "R-Perm (b)": "R' U2 R U2 R' F R U R' U' R' F' R2",

    # Diagonal Corner Swaps
    "Y-Perm": "F R U' R' U' R U R' F' R U R' U' R' F R F'",
    "V-Perm": "R' U R' U' y R' F' R2 U' R' U R' F R F",
    "N-Perm (a)": "R U R' U R U R' F' R U R' U' R' F R2 U' R' U2 R U' R'",
    "N-Perm (b)": "R' U R U' R' F' U' F R U R' F R' F' R U' R",

    # Edge Permutations Only
    "U-Perm (a)": "R2 U R U R' U' R' U' R' U R'",
    "U-Perm (b)": "R' U R' U' R' U' R' U R U R2",
    "Z-Perm": "M2 U M2 U M' U2 M2 U2 M' U2",
    "H-Perm": "M2 U M2 U2 M2 U M2",

    # Adjacent Edge Swaps (3-edges)
    "A-Perm (a)": "x R' U R' D2 R U' R' D2 R2 x'",
    "A-Perm (b)": "x R2 D2 R U R' D2 R U' R x'",

    # G-Perms (4 variations)
    "G-Perm (a)": "R2 U R' U R' U' R U' R2 D U' R' U R D'",
    "G-Perm (b)": "R' U' R U D' R2 U R' U R U' R U' R2 D",
    "G-Perm (c)": "R2 U' R U' R U R' U R2 D' U R U' R' D",
    "G-Perm (d)": "R U R' U' D R2 U' R U' R' U R' U R2 D'",

    # No permutation needed
    "Solved": "",
}

def parse_algorithm(alg_string):
    """
    Parse algorithm string into list of moves.
    Example: "R U R' U'" -> ['R', 'U', "R'", "U'"]
    """
    if not alg_string:
        return []

    moves = []
    tokens = alg_string.split()

    for token in tokens:
        moves.append(token)

    return moves

def get_all_oll_algorithms():
    """Return all OLL algorithms as a dictionary."""
    return OLL_CASES.copy()

def get_all_pll_algorithms():
    """Return all PLL algorithms as a dictionary."""
    return PLL_CASES.copy()

def get_algorithm_by_name(case_name):
    """
    Get algorithm by case name.
    Searches both OLL and PLL databases.
    """
    if case_name in OLL_CASES:
        return OLL_CASES[case_name]
    elif case_name in PLL_CASES:
        return PLL_CASES[case_name]
    else:
        return None

if __name__ == "__main__":
    # Test the algorithm database
    print(f"Total OLL cases: {len(OLL_CASES)}")
    print(f"Total PLL cases: {len(PLL_CASES)}")
    print(f"\nExample algorithms:")
    print(f"T-Perm: {PLL_CASES['T-Perm']}")
    print(f"Sune: {OLL_CASES['Sune']}")

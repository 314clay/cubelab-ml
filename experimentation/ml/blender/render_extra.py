"""Render extra verification cases: Z-Perm + random OLLs."""
import bpy
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)

# Re-use all functions from the main render script
exec(open(os.path.join(SCRIPT_DIR, "render_known_states.py")).read())

from algorithms import OLL_CASES, PLL_CASES

extra_renders = [
    {
        "name": "z_perm",
        "algorithms": [("PLL", "Z-Perm", PLL_CASES["Z-Perm"])],
        "oll_case": "OLL Skip",
        "pll_case": "Z-Perm",
    },
    {
        "name": "oll_21",
        "algorithms": [("OLL", "OLL 21", OLL_CASES["OLL 21"])],
        "oll_case": "OLL 21",
        "pll_case": "Solved",
    },
    {
        "name": "oll_1",
        "algorithms": [("OLL", "OLL 1", OLL_CASES["OLL 1"])],
        "oll_case": "OLL 1",
        "pll_case": "Solved",
    },
    {
        "name": "oll_57",
        "algorithms": [("OLL", "OLL 57", OLL_CASES["OLL 57"])],
        "oll_case": "OLL 57",
        "pll_case": "Solved",
    },
]

for render_config in extra_renders:
    print(f"\n{'='*60}")
    print(f"Rendering: {render_config['name']}")
    print(f"{'='*60}")
    cube = Cube()
    for alg_type, alg_name, alg_str in render_config.get("algorithms", []):
        print(f"  Applying {alg_name}: {alg_str}")
        cube.apply_algorithm(alg_str)
    render_cube_state(
        cube,
        render_config["name"],
        {"oll_case": render_config["oll_case"], "pll_case": render_config["pll_case"]},
    )

print("\nDone!")

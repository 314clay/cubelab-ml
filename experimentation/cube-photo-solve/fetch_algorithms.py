"""
Fetch algorithm data from spencerchubb/cubingapp GitHub repo
and build a unified algorithm_db.json for CubeLab.
"""

import json
import re
import urllib.request
from datetime import datetime, timezone

BASE_URL = "https://raw.githubusercontent.com/spencerchubb/cubingapp/main/alg-codegen/algs"

# Algorithm sets to fetch with their phase metadata
ALGORITHM_SETS = {
    "OLL": {
        "file": "OLL.json",
        "phase": "orient_last_layer",
        "precondition": "F2L solved",
        "postcondition": "Last layer oriented (top face uniform color)",
    },
    "PLL": {
        "file": "PLL.json",
        "phase": "permute_last_layer",
        "precondition": "F2L + OLL solved",
        "postcondition": "Cube solved",
    },
    "COLL": {
        "file": "COLL.json",
        "phase": "corners_last_layer",
        "precondition": "F2L solved + LL edges oriented",
        "postcondition": "LL corners oriented + permuted (only EPLL remains)",
    },
    "ZBLL": {
        "file": "ZBLL.json",
        "phase": "last_layer_one_look",
        "precondition": "F2L solved + LL edges oriented",
        "postcondition": "Cube solved",
    },
    "OLLCP": {
        "file": "OLLCP.json",
        "phase": "orient_ll_permute_corners",
        "precondition": "F2L solved",
        "postcondition": "LL edges oriented + corners permuted",
    },
    "F2L": {
        "file": "F2L.json",
        "phase": "first_two_layers",
        "precondition": "Cross solved",
        "postcondition": "F2L solved",
    },
    "WV": {
        "file": "Winter-Variation.json",
        "phase": "last_slot_plus_orient",
        "precondition": "3 F2L pairs solved + last pair connected",
        "postcondition": "F2L + OLL solved",
    },
}


def normalize_algorithm(alg_str: str) -> str:
    """Normalize algorithm notation.

    - Remove parentheses (grouping only)
    - Ensure space-separated
    - Handle R2' (same as R2)
    """
    # Remove parentheses
    alg_str = alg_str.replace('(', '').replace(')', '')
    # Remove brackets
    alg_str = alg_str.replace('[', '').replace(']', '')
    # Normalize whitespace
    alg_str = ' '.join(alg_str.split())
    # R2' is the same as R2 — remove trailing ' after 2
    alg_str = re.sub(r"(\w2)'", r"\1", alg_str)
    return alg_str.strip()


def fetch_json(filename: str) -> dict:
    """Fetch a JSON file from the cubingapp repo."""
    url = f"{BASE_URL}/{filename}"
    print(f"  Fetching {url}...")
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())


def extract_cases(raw_data: dict) -> dict:
    """Extract cases from cubingapp JSON format.

    Top-level has: puzzle, diagramType, subsets, cases, etc.
    cases: { "CASE_NAME": { "subset": "...", "algs": { "alg": {}, ... } } }
    Take the FIRST algorithm for each case.
    """
    cases_data = raw_data.get("cases", raw_data)
    cases = {}
    for case_name, case_data in cases_data.items():
        if not isinstance(case_data, dict):
            continue
        subset = case_data.get("subset", "")
        algs = case_data.get("algs", {})
        if not algs:
            continue
        # Take the first algorithm
        first_alg = next(iter(algs))
        normalized = normalize_algorithm(first_alg)
        cases[case_name] = {
            "algorithm": normalized,
            "subset": subset,
        }
    return cases


def main():
    print("Fetching algorithm database from spencerchubb/cubingapp...")

    algorithm_sets = {}
    total_count = 0

    for set_name, config in ALGORITHM_SETS.items():
        print(f"\n--- {set_name} ---")
        try:
            raw_data = fetch_json(config["file"])
            cases = extract_cases(raw_data)
            count = len(cases)
            total_count += count
            print(f"  Found {count} cases")

            algorithm_sets[set_name] = {
                "phase": config["phase"],
                "precondition": config["precondition"],
                "postcondition": config["postcondition"],
                "count": count,
                "cases": cases,
            }
        except Exception as e:
            print(f"  ERROR fetching {set_name}: {e}")
            raise

    # Build unified database
    db = {
        "metadata": {
            "source": "spencerchubb/cubingapp",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "total_algorithms": total_count,
        },
        "algorithm_sets": algorithm_sets,
    }

    # Write output
    output_path = "algorithm_db.json"
    with open(output_path, 'w') as f:
        json.dump(db, f, indent=2)

    print(f"\n=== SUMMARY ===")
    print(f"Total algorithm sets: {len(algorithm_sets)}")
    print(f"Total algorithms: {total_count}")
    for name, data in algorithm_sets.items():
        print(f"  {name}: {data['count']} cases")
    print(f"\nWritten to {output_path}")


if __name__ == "__main__":
    main()

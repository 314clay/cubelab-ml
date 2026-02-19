#!/usr/bin/env python3
"""
Multislot F2L Algorithm Finder

Exhaustively searches for algorithms that solve two F2L pairs simultaneously,
ranked by an ergonomic fingertrick heuristic. Most multislot algorithms used
by top speedcubers were found by intuition — this tool finds them systematically.

Two search strategies:
  1. Enumeration: combine all F2L case pairs × AUF variations (baseline)
  2. Random walk: biased inverse random walk to discover shorter solutions

Usage:
  python multislot_finder.py --pair FR,FL --trials 1000000 --validate
  python multislot_finder.py --pair FR,BR --trials 5000000 --output results.json
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass, asdict

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "cube-photo-solve"))
sys.path.insert(0, os.path.join(EXPERIMENT_DIR, "ml", "blender"))

from state_resolver import Cube
from algorithms import F2L_CASES, parse_algorithm
from f2l_scrambler import invert_alg

# Import components
from _scorer import ergonomic_score, simplify_moves
from _canonicalize import canonical_key, make_state_key
from _search import enumerate_f2l_pairs, random_walk_search, check_target_only

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

ALL_SLOT_PAIRS = [
    ('FR', 'FL'),   # Adjacent (share F face)
    ('FR', 'BR'),   # Adjacent (share R face)
    ('FL', 'BL'),   # Adjacent (share L face)
    ('BR', 'BL'),   # Adjacent (share B face)
    ('FR', 'BL'),   # Diagonal
    ('FL', 'BR'),   # Diagonal
]


@dataclass
class AlgEntry:
    algorithm: str
    score: float
    move_count: int
    source: str        # 'enumeration' or 'random_walk'
    auf: str           # pre-AUF needed (e.g. "U'")


class MultislotCatalog:
    """Catalog of multislot F2L algorithms organized by canonical state."""

    def __init__(self, slot_pair, max_per_case=5):
        self.slot_pair = tuple(slot_pair)
        self.max_per_case = max_per_case
        self.cases = {}          # canonical_key -> list[AlgEntry]
        self._total_added = 0
        self._total_rejected = 0

    def add(self, canonical_key_str, alg, score, move_count, source, auf=''):
        """Add an algorithm. Returns True if it was kept (new or better)."""
        entry = AlgEntry(
            algorithm=alg,
            score=score,
            move_count=move_count,
            source=source,
            auf=auf,
        )

        if canonical_key_str not in self.cases:
            self.cases[canonical_key_str] = [entry]
            self._total_added += 1
            return True

        entries = self.cases[canonical_key_str]

        # Check for duplicate algorithm
        full_alg = f"{auf} {alg}".strip() if auf else alg
        for e in entries:
            existing_full = f"{e.auf} {e.algorithm}".strip() if e.auf else e.algorithm
            if existing_full == full_alg:
                self._total_rejected += 1
                return False

        # Add and keep top N by score
        entries.append(entry)
        entries.sort(key=lambda e: e.score)
        if len(entries) > self.max_per_case:
            entries.pop()
            if entry not in entries:
                self._total_rejected += 1
                return False

        self._total_added += 1
        return True

    def stats(self):
        """Return summary statistics."""
        if not self.cases:
            return {
                'total_cases': 0, 'total_algorithms': 0,
                'avg_score': 0, 'best_score': 0, 'worst_best_score': 0,
                'avg_move_count': 0,
            }

        all_entries = [e for entries in self.cases.values() for e in entries]
        best_per_case = [entries[0] for entries in self.cases.values()]
        scores = [e.score for e in all_entries]
        best_scores = [e.score for e in best_per_case]
        move_counts = [e.move_count for e in all_entries]
        sources = {}
        for e in all_entries:
            sources[e.source] = sources.get(e.source, 0) + 1

        return {
            'total_cases': len(self.cases),
            'total_algorithms': len(all_entries),
            'avg_score': sum(scores) / len(scores),
            'best_score': min(scores),
            'worst_best_score': max(best_scores),
            'avg_best_score': sum(best_scores) / len(best_scores),
            'avg_move_count': sum(move_counts) / len(move_counts),
            'min_move_count': min(move_counts),
            'max_move_count': max(move_counts),
            'sources': sources,
        }

    def to_json(self):
        """Export as JSON-serializable dict."""
        cases_out = {}
        for key, entries in sorted(self.cases.items()):
            cases_out[key] = [asdict(e) for e in entries]
        return {
            'slot_pair': list(self.slot_pair),
            'stats': self.stats(),
            'cases': cases_out,
        }

    def save(self, path):
        """Save catalog to JSON file."""
        data = self.to_json()
        data['generated_at'] = time.strftime('%Y-%m-%dT%H:%M:%S')
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Saved catalog to {path}")

    @classmethod
    def load(cls, path):
        """Load catalog from JSON file."""
        with open(path) as f:
            data = json.load(f)
        cat = cls(tuple(data['slot_pair']))
        for key, entries in data['cases'].items():
            cat.cases[key] = [AlgEntry(**e) for e in entries]
        return cat


# ---------------------------------------------------------------------------
# Callback: wires search results into scorer + canonicalizer + catalog
# ---------------------------------------------------------------------------

def make_add_callback(catalog):
    """Create a callback for the search functions that scores, canonicalizes,
    and adds results to the catalog."""

    def add_callback(scrambled_cube, solution_alg, source):
        # Simplify the solution
        moves = parse_algorithm(solution_alg)
        simplified = simplify_moves(moves)
        if not simplified:
            return
        clean_alg = ' '.join(simplified)

        # Canonicalize the scrambled state
        ckey, auf = canonical_key(scrambled_cube, catalog.slot_pair)

        # Build the full solution with AUF prefix
        if auf:
            full_alg = f"{auf} {clean_alg}"
            full_moves = parse_algorithm(full_alg)
            full_simplified = simplify_moves(full_moves)
            full_alg = ' '.join(full_simplified)
        else:
            full_alg = clean_alg

        # Score the full solution
        score = ergonomic_score(full_alg)
        move_count = len(parse_algorithm(full_alg))

        catalog.add(ckey, clean_alg, score, move_count, source, auf)

    return add_callback


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_catalog(catalog):
    """Validate every algorithm in the catalog.

    For each algorithm:
    1. Start from a solved cube
    2. Apply inverse of (auf + algorithm) to create the scrambled state
    3. Verify: cross intact, exactly target slots unsolved
    4. Apply (auf + algorithm)
    5. Verify: F2L fully solved
    """
    passed = 0
    failed = 0
    errors = []

    for key, entries in catalog.cases.items():
        for entry in entries:
            try:
                # Build full solution
                if entry.auf:
                    full_solution = f"{entry.auf} {entry.algorithm}"
                else:
                    full_solution = entry.algorithm

                # Create scrambled state by applying inverse
                cube = Cube()
                scramble = invert_alg(full_solution)
                cube.apply_algorithm(scramble)

                # Verify scrambled state
                if not check_target_only(cube, catalog.slot_pair):
                    failed += 1
                    errors.append({
                        'key': key,
                        'alg': full_solution,
                        'error': 'Scrambled state does not match target pair',
                        'cross_ok': cube.is_cross_solved(),
                        'unsolved': cube.get_unsolved_slots(),
                    })
                    continue

                # Apply solution
                cube.apply_algorithm(full_solution)

                # Verify solved
                if not cube.is_f2l_solved():
                    failed += 1
                    errors.append({
                        'key': key,
                        'alg': full_solution,
                        'error': 'Solution does not fully solve F2L',
                        'unsolved_after': cube.get_unsolved_slots(),
                    })
                    continue

                passed += 1

            except Exception as e:
                failed += 1
                errors.append({
                    'key': key,
                    'alg': entry.algorithm,
                    'error': str(e),
                })

    return {'passed': passed, 'failed': failed, 'errors': errors}


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def print_report(catalog, search_time=None, num_trials=None):
    """Print a human-readable summary report."""
    s = catalog.stats()
    pair_str = '+'.join(catalog.slot_pair)

    print("\n" + "=" * 65)
    print(f"  Multislot F2L Catalog: {pair_str}")
    print("=" * 65)

    print(f"\n  Cases found:       {s['total_cases']}")
    print(f"  Total algorithms:  {s['total_algorithms']}")
    if s['total_algorithms'] > 0:
        print(f"  Avg score:         {s['avg_score']:.1f}")
        print(f"  Best score:        {s['best_score']:.1f}")
        print(f"  Avg best/case:     {s['avg_best_score']:.1f}")
        print(f"  Worst best/case:   {s['worst_best_score']:.1f}")
        print(f"  Avg move count:    {s['avg_move_count']:.1f}")
        print(f"  Move count range:  {s['min_move_count']}-{s['max_move_count']}")
        print(f"  Sources:           {s['sources']}")
    if search_time:
        print(f"  Search time:       {search_time:.1f}s")
    if num_trials:
        print(f"  Random walk trials:{num_trials:,}")

    # Top 20 best algorithms (by score)
    if s['total_algorithms'] > 0:
        print(f"\n  Top 20 Best Algorithms (by ergonomic score):")
        print(f"  {'Score':>6}  {'Moves':>5}  {'AUF':>3}  {'Source':>11}  Algorithm")
        print(f"  {'-'*6}  {'-'*5}  {'-'*3}  {'-'*11}  {'-'*30}")

        all_entries = []
        for key, entries in catalog.cases.items():
            for e in entries:
                all_entries.append(e)
        all_entries.sort(key=lambda e: e.score)

        for e in all_entries[:20]:
            auf_str = e.auf if e.auf else ' - '
            print(f"  {e.score:6.1f}  {e.move_count:5d}  {auf_str:>3}  "
                  f"{e.source:>11}  {e.algorithm}")

    # Score distribution
    if s['total_cases'] > 0:
        best_scores = [entries[0].score for entries in catalog.cases.values()]
        buckets = {}
        for sc in best_scores:
            bucket = int(sc // 5) * 5
            buckets[bucket] = buckets.get(bucket, 0) + 1
        print(f"\n  Score Distribution (best per case):")
        for bucket in sorted(buckets.keys()):
            bar = '#' * min(buckets[bucket], 50)
            print(f"  {bucket:3d}-{bucket+4:3d}: {buckets[bucket]:5d} {bar}")

    print("\n" + "=" * 65)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Multislot F2L Algorithm Finder — systematic search for '
                    '2-pair F2L algorithms ranked by ergonomic score.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python multislot_finder.py --pair FR,FL --trials 1000000 --validate
  python multislot_finder.py --pair FR,BR --trials 5000000 --output my_results.json
  python multislot_finder.py --pair FR,FL --skip-walk   # enumeration only
  python multislot_finder.py --pair FR,FL --skip-enum   # random walk only
        """,
    )
    parser.add_argument('--pair', default='FR,FL',
                        help='Slot pair to search (e.g. FR,FL). Default: FR,FL')
    parser.add_argument('--trials', type=int, default=1_000_000,
                        help='Number of random walk trials. Default: 1,000,000')
    parser.add_argument('--max-depth', type=int, default=16,
                        help='Maximum algorithm depth for random walk. Default: 16')
    parser.add_argument('--min-depth', type=int, default=4,
                        help='Minimum algorithm depth for random walk. Default: 4')
    parser.add_argument('--seed', type=int, default=None,
                        help='Random seed for reproducibility')
    parser.add_argument('--output', default=None,
                        help='Output JSON path. Default: multislot_SLOT1_SLOT2.json')
    parser.add_argument('--skip-enum', action='store_true',
                        help='Skip F2L enumeration baseline')
    parser.add_argument('--skip-walk', action='store_true',
                        help='Skip random walk search')
    parser.add_argument('--validate', action='store_true',
                        help='Validate all found algorithms after search')
    parser.add_argument('--top-per-case', type=int, default=5,
                        help='Keep top N algorithms per case. Default: 5')

    args = parser.parse_args()

    slot_pair = tuple(args.pair.split(','))
    if len(slot_pair) != 2:
        parser.error("--pair must be exactly two slots separated by comma")
    valid_slots = {'FR', 'FL', 'BR', 'BL'}
    for s in slot_pair:
        if s not in valid_slots:
            parser.error(f"Invalid slot '{s}'. Must be one of: {valid_slots}")

    print(f"Multislot F2L Finder — target pair: {slot_pair[0]}+{slot_pair[1]}")
    print(f"Settings: trials={args.trials:,}, depth={args.min_depth}-{args.max_depth}, "
          f"top_per_case={args.top_per_case}")

    catalog = MultislotCatalog(slot_pair, max_per_case=args.top_per_case)
    callback = make_add_callback(catalog)
    t_start = time.time()

    # Phase 1: Enumeration
    if not args.skip_enum:
        print(f"\n--- Phase 1: Enumeration ---")
        t0 = time.time()
        enumerate_f2l_pairs(slot_pair, callback)
        t1 = time.time()
        s = catalog.stats()
        print(f"After enumeration: {s['total_cases']} cases, "
              f"{s['total_algorithms']} algs ({t1-t0:.1f}s)")

    # Phase 2: Random walk
    if not args.skip_walk:
        print(f"\n--- Phase 2: Random Walk ({args.trials:,} trials) ---")
        cases_before = len(catalog.cases)
        random_walk_search(
            slot_pair, callback,
            num_trials=args.trials,
            min_depth=args.min_depth,
            max_depth=args.max_depth,
            seed=args.seed,
            progress_interval=max(args.trials // 10, 10_000),
        )
        s = catalog.stats()
        new_cases = len(catalog.cases) - cases_before
        print(f"After random walk: {s['total_cases']} cases, "
              f"{s['total_algorithms']} algs ({new_cases} new cases from walk)")

    t_total = time.time() - t_start

    # Phase 3: Validation
    if args.validate:
        print(f"\n--- Phase 3: Validation ---")
        results = validate_catalog(catalog)
        print(f"Validation: {results['passed']} passed, {results['failed']} failed")
        if results['errors']:
            for err in results['errors'][:5]:
                print(f"  Error: {err}")

    # Phase 4: Report and save
    print_report(catalog, search_time=t_total, num_trials=args.trials)

    output_path = args.output or f"multislot_{slot_pair[0]}_{slot_pair[1]}.json"
    catalog.save(output_path)


if __name__ == '__main__':
    main()

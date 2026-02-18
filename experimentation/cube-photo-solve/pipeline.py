"""
End-to-end pipeline: Photo → ML model → 27 stickers → 54-sticker state → solver.

Usage:
    # Run on a single image with ML inference
    python3 cube-photo-solve/pipeline.py image.jpg

    # Run on a Blender render with JSON ground truth (skip ML, use labels)
    python3 cube-photo-solve/pipeline.py --ground-truth render.json

    # Test on all verified renders
    python3 cube-photo-solve/pipeline.py --test-dir ml/data/verified_renders/

    # Test on training renders (validation split)
    python3 cube-photo-solve/pipeline.py --test-val ml/data/training_renders/
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Add this directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from state_reconstructor import StateReconstructor, COLOR_TO_KOCIEMBA


def load_ml_model(checkpoint_path, device='cpu'):
    """Load the trained StickerClassifier model."""
    import torch
    sys.path.insert(0, str(Path(__file__).parent.parent / 'ml' / 'src'))
    from sticker_model import StickerClassifier, COLOR_CLASSES

    model = StickerClassifier(pretrained=False)
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=True)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    model.to(device)
    return model, COLOR_CLASSES


def predict_stickers(model, color_classes, image_path, device='cpu'):
    """Run ML inference on an image to get 27 sticker predictions."""
    import torch
    from torchvision import transforms
    from PIL import Image

    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                             std=[0.229, 0.224, 0.225]),
    ])

    image = Image.open(image_path).convert('RGB')
    tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        logits = model(tensor)  # (1, 27, 6)
        preds = logits.argmax(dim=2)[0]  # (27,)

    return [color_classes[i] for i in preds.tolist()]


def load_ground_truth(json_path):
    """Load 27 visible stickers from a ground-truth JSON file."""
    with open(json_path) as f:
        data = json.load(f)

    full_state = data['full_state']
    visible_27 = full_state['U'] + full_state['F'] + full_state['R']
    return visible_27, data


def solve_kociemba(kociemba_str):
    """Run Kociemba solver on the state string."""
    try:
        import kociemba
        solution = kociemba.solve(kociemba_str)
        return solution
    except ImportError:
        return "(kociemba not installed)"
    except Exception as e:
        return f"(solver error: {e})"


_resolver_cache = None
_solver_cache = None


def _get_resolver():
    """Lazily create and cache the StateResolver (expensive to build)."""
    global _resolver_cache
    if _resolver_cache is None:
        from state_resolver import StateResolver
        _resolver_cache = StateResolver()
    return _resolver_cache


def _get_solver():
    """Lazily create and cache the CubeSolver (expensive — builds lookup tables)."""
    global _solver_cache
    if _solver_cache is None:
        from solver import CubeSolver
        _solver_cache = CubeSolver()
    return _solver_cache


def run_pipeline(visible_27, recon, skip_solver=False):
    """Run the reconstruction + solve pipeline on 27 visible stickers.

    Returns dict with results or raises on failure.
    """
    # Reconstruct full state
    state = recon.reconstruct(visible_27)
    errors = recon.validate(state)

    if errors:
        return {'success': False, 'errors': errors, 'state': state}

    # Convert to Kociemba format
    kociemba_str = StateReconstructor.to_kociemba(state)

    # Kociemba solution (always run as fallback)
    kociemba_solution = solve_kociemba(kociemba_str)

    # Algorithm-based solving via CubeSolver
    phase = None
    solve_paths = []
    oll_case = None
    pll_case = None

    if not skip_solver:
        try:
            cube = StateReconstructor.to_cube(state)
            solver = _get_solver()

            # Phase detection
            from phase_detector import PhaseDetector
            phase_result = solver.phase_detector.detect_phase_full(cube)
            phase = phase_result.phase

            # Algorithm-based solving paths
            solve_paths = solver.solve_from_cube(cube)

            # Also extract OLL/PLL case names from the best path
            if solve_paths:
                for step in solve_paths[0].steps:
                    if step.algorithm_set == 'OLL':
                        oll_case = step.case_name
                    elif step.algorithm_set == 'PLL':
                        pll_case = step.case_name
                    elif step.algorithm_set == 'OLLCP':
                        oll_case = step.case_name

            # Fallback: use basic StateResolver for OLL/PLL identification
            if not oll_case and not pll_case:
                try:
                    resolver = _get_resolver()
                    visible_15 = state['U'] + state['F'][:3] + state['R'][:3]
                    match = resolver.match_state(visible_15)
                    if match:
                        oll_case = match['oll_case']
                        pll_case = match['pll_case']
                except Exception:
                    pass
        except Exception:
            pass

    return {
        'success': True,
        'state': state,
        'kociemba': kociemba_str,
        'solution': kociemba_solution,
        'phase': phase,
        'solve_paths': solve_paths,
        'oll_case': oll_case,
        'pll_case': pll_case,
    }


def format_face(stickers):
    """Format a 9-element face as 3x3 grid."""
    return f"{stickers[0]} {stickers[1]} {stickers[2]}\n{stickers[3]} {stickers[4]} {stickers[5]}\n{stickers[6]} {stickers[7]} {stickers[8]}"


def print_result(result, visible_27):
    """Print pipeline result in human-readable format."""
    print("=== CUBE ANALYSIS ===")
    print(f"Visible stickers (27): {' '.join(visible_27)}")

    if not result['success']:
        print(f"RECONSTRUCTION FAILED: {result['errors']}")
        return

    state = result['state']
    all_54 = []
    for face in ['U', 'D', 'F', 'B', 'L', 'R']:
        all_54.extend(state[face])
    print(f"Full state (54):       {' '.join(all_54)}")

    if result.get('phase'):
        print(f"Phase: {result['phase']}")

    # Algorithm-based solving paths
    solve_paths = result.get('solve_paths', [])
    if solve_paths:
        print(f"\n--- Algorithm Solutions (ranked by move count) ---")
        for i, path in enumerate(solve_paths, 1):
            print(f"{i}. {path.description} ({path.total_moves} moves)")
            for step in path.steps:
                print(f"   Step: {step.case_name} — {step.algorithm} ({step.move_count} moves)")
    else:
        if result.get('oll_case'):
            print(f"OLL case: {result['oll_case']}")
        if result.get('pll_case'):
            print(f"PLL case: {result['pll_case']}")

    # Kociemba fallback
    print(f"\n--- Kociemba Solution ---")
    print(f"{result['solution']}")


def test_on_json(json_path, recon, verbose=True, skip_solver=False):
    """Test pipeline on a single ground-truth JSON file.

    Returns (success, state_match, details).
    """
    visible_27, gt_data = load_ground_truth(json_path)
    result = run_pipeline(visible_27, recon, skip_solver=skip_solver)

    if not result['success']:
        if verbose:
            print(f"  FAIL (reconstruction): {result['errors']}")
        return False, False, result

    # Compare against ground truth full state
    gt_state = gt_data['full_state']
    state_match = all(
        result['state'][f] == gt_state[f]
        for f in ['U', 'D', 'F', 'B', 'L', 'R']
    )

    if verbose and not state_match:
        for f in ['U', 'D', 'F', 'B', 'L', 'R']:
            if result['state'][f] != gt_state[f]:
                print(f"  {f}: got {result['state'][f]}")
                print(f"       exp {gt_state[f]}")

    return True, state_match, result


def test_directory(data_dir, recon, verbose=True, skip_solver=False):
    """Test pipeline on all JSON files in a directory."""
    json_files = sorted(
        f for f in os.listdir(data_dir)
        if f.endswith('.json') and f != 'manifest.json'
    )

    total = 0
    recon_ok = 0
    state_match = 0

    for jf in json_files:
        jp = os.path.join(data_dir, jf)
        total += 1

        ok, match, result = test_on_json(jp, recon, verbose=False,
                                          skip_solver=skip_solver)

        if ok:
            recon_ok += 1
        if match:
            state_match += 1
        elif verbose and total <= 10:
            name = jf.replace('.json', '')
            status = "RECON_FAIL" if not ok else "STATE_MISMATCH"
            print(f"  {name:30s} {status}")

    print(f"\n=== PIPELINE TEST RESULTS ===")
    print(f"Total:              {total}")
    print(f"Reconstruction OK:  {recon_ok}/{total} ({100*recon_ok/total:.1f}%)")
    print(f"Full state match:   {state_match}/{total} ({100*state_match/total:.1f}%)")

    return state_match, total


def test_val_split(data_dir, checkpoint_path, device='cpu'):
    """Test full ML pipeline on validation split (ML inference + reconstruction)."""
    import torch
    sys.path.insert(0, str(Path(__file__).parent.parent / 'ml' / 'src'))
    from sticker_model import COLOR_CLASSES
    from sticker_dataset import StickerDataset

    model, color_classes = load_ml_model(checkpoint_path, device)
    recon = StateReconstructor()

    dataset = StickerDataset(data_dir, split='val', augment=False)
    print(f"Validation samples: {len(dataset)}")

    total = 0
    ml_sticker_correct = 0
    ml_sticker_total = 0
    ml_image_correct = 0
    recon_ok = 0
    full_ok = 0

    for i in range(len(dataset)):
        image, label = dataset[i]
        gt_stickers = [color_classes[c] for c in label.tolist()]

        # ML prediction
        with torch.no_grad():
            logits = model(image.unsqueeze(0).to(device))
            preds = logits.argmax(dim=2)[0]
        pred_stickers = [color_classes[c] for c in preds.tolist()]

        # Count ML accuracy
        total += 1
        correct = sum(p == g for p, g in zip(pred_stickers, gt_stickers))
        ml_sticker_correct += correct
        ml_sticker_total += 27
        if correct == 27:
            ml_image_correct += 1

        # Run reconstruction
        try:
            result = run_pipeline(pred_stickers, recon)
            if result['success']:
                recon_ok += 1

                # Check if full state matches ground truth
                json_file = dataset.samples[i]
                json_path = os.path.join(data_dir, json_file)
                with open(json_path) as f:
                    gt_data = json.load(f)
                gt_state = gt_data['full_state']

                match = all(
                    result['state'][f] == gt_state[f]
                    for f in ['U', 'D', 'F', 'B', 'L', 'R']
                )
                if match:
                    full_ok += 1
        except Exception:
            pass

    print(f"\n=== FULL PIPELINE (ML + RECONSTRUCTION) ===")
    print(f"ML per-sticker accuracy: {ml_sticker_correct}/{ml_sticker_total} "
          f"({100*ml_sticker_correct/ml_sticker_total:.1f}%)")
    print(f"ML per-image accuracy:   {ml_image_correct}/{total} "
          f"({100*ml_image_correct/total:.1f}%)")
    print(f"Reconstruction success:  {recon_ok}/{total} "
          f"({100*recon_ok/total:.1f}%)")
    print(f"Full pipeline correct:   {full_ok}/{total} "
          f"({100*full_ok/total:.1f}%)")


def main():
    parser = argparse.ArgumentParser(description='Cube analysis pipeline')
    parser.add_argument('image', nargs='?', help='Image file to analyze')
    parser.add_argument('--ground-truth', '-g', help='JSON ground truth file')
    parser.add_argument('--test-dir', '-t', help='Test on all JSONs in directory')
    parser.add_argument('--test-val', help='Test full ML pipeline on val split')
    parser.add_argument('--checkpoint', '-c',
                        default=str(Path(__file__).parent.parent /
                                    'ml' / 'checkpoints' / 'sticker_classifier.pt'),
                        help='Model checkpoint path')
    parser.add_argument('--device', '-d', default='cpu',
                        help='Device (cpu/mps/cuda)')
    parser.add_argument('--no-solver', action='store_true',
                        help='Skip solver tree (faster, Kociemba only)')

    args = parser.parse_args()

    recon = StateReconstructor()

    if args.test_dir:
        test_directory(args.test_dir, recon, skip_solver=args.no_solver)
    elif args.test_val:
        test_val_split(args.test_val, args.checkpoint, args.device)
    elif args.ground_truth:
        ok, match, result = test_on_json(args.ground_truth, recon,
                                          skip_solver=args.no_solver)
        visible_27, _ = load_ground_truth(args.ground_truth)
        print_result(result, visible_27)
        if match:
            print("\nFull state matches ground truth: YES")
        else:
            print("\nFull state matches ground truth: NO")
    elif args.image:
        model, color_classes = load_ml_model(args.checkpoint, args.device)
        visible_27 = predict_stickers(model, color_classes, args.image, args.device)
        result = run_pipeline(visible_27, recon, skip_solver=args.no_solver)
        print_result(result, visible_27)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()

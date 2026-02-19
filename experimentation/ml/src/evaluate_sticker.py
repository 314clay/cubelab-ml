"""
Evaluate the StickerClassifier on a dataset.

Usage:
    python3 ml/src/evaluate_sticker.py --checkpoint ml/checkpoints/sticker_classifier.pt --data-dir ml/data/training_renders/
"""

import argparse
import os
import sys

import torch
from torch.utils.data import DataLoader

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

from sticker_model import StickerClassifier, COLOR_CLASSES, NUM_STICKERS, NUM_COLORS
from sticker_dataset import StickerDataset


POSITION_NAMES = (
    [f"U{i}" for i in range(9)] +
    [f"F{i}" for i in range(9)] +
    [f"R{i}" for i in range(9)]
)


def auto_device():
    if torch.backends.mps.is_available():
        return 'mps'
    if torch.cuda.is_available():
        return 'cuda'
    return 'cpu'


def evaluate(model, loader, device):
    model.eval()

    # Per-position accuracy tracking
    position_correct = [0] * NUM_STICKERS
    position_total = [0] * NUM_STICKERS

    # Confusion matrix (all positions pooled)
    confusion = [[0] * NUM_COLORS for _ in range(NUM_COLORS)]

    total_correct = 0
    total_stickers = 0
    total_images_correct = 0
    total_images = 0

    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            labels = labels.to(device)

            logits = model(images)  # (B, 27, 6)
            preds = logits.argmax(dim=2)  # (B, 27)

            for b in range(images.size(0)):
                all_correct = True
                for s in range(NUM_STICKERS):
                    pred_c = preds[b, s].item()
                    true_c = labels[b, s].item()
                    position_total[s] += 1
                    confusion[true_c][pred_c] += 1
                    if pred_c == true_c:
                        position_correct[s] += 1
                        total_correct += 1
                    else:
                        all_correct = False
                    total_stickers += 1

                if all_correct:
                    total_images_correct += 1
                total_images += 1

    return (total_correct, total_stickers, total_images_correct, total_images,
            position_correct, position_total, confusion)


def main():
    parser = argparse.ArgumentParser(description="Evaluate StickerClassifier")
    parser.add_argument('--checkpoint', type=str, required=True)
    parser.add_argument('--data-dir', type=str, default='ml/data/training_renders/')
    parser.add_argument('--device', type=str, default='auto')
    parser.add_argument('--seed', type=int, default=42)
    args = parser.parse_args()

    device = torch.device(args.device if args.device != 'auto' else auto_device())

    # Load model
    model = StickerClassifier(pretrained=False).to(device)
    checkpoint = torch.load(args.checkpoint, map_location=device, weights_only=True)
    model.load_state_dict(checkpoint['model_state_dict'])
    print(f"Loaded checkpoint from epoch {checkpoint['epoch']}")
    print(f"  Checkpoint val_sticker_acc: {checkpoint['val_sticker_acc']:.3f}")
    print(f"  Checkpoint val_image_acc: {checkpoint['val_image_acc']:.3f}")

    # Parse comma-separated data dirs
    data_dirs = [d.strip() for d in args.data_dir.split(',')]
    data_dir = data_dirs if len(data_dirs) > 1 else data_dirs[0]

    # Dataset (val split only)
    val_ds = StickerDataset(data_dir, split='val', seed=args.seed, augment=False)
    val_loader = DataLoader(val_ds, batch_size=32, shuffle=False, num_workers=0)
    print(f"Val samples: {len(val_ds)}")

    # Evaluate
    (total_correct, total_stickers, total_images_correct, total_images,
     position_correct, position_total, confusion) = evaluate(model, val_loader, device)

    sticker_acc = total_correct / total_stickers if total_stickers > 0 else 0
    image_acc = total_images_correct / total_images if total_images > 0 else 0

    print(f"\n=== STICKER CLASSIFIER EVALUATION ===")
    print(f"Per-sticker accuracy: {total_correct}/{total_stickers} = {sticker_acc:.1%}")
    print(f"Per-image accuracy:   {total_images_correct}/{total_images} = {image_acc:.1%}")

    # Per-position accuracy
    print(f"\nPer-position accuracy:")
    for face_start, face_name in [(0, 'U'), (9, 'F'), (18, 'R')]:
        parts = []
        for i in range(9):
            idx = face_start + i
            acc = position_correct[idx] / position_total[idx] if position_total[idx] > 0 else 0
            parts.append(f"{POSITION_NAMES[idx]}: {acc:.1%}")
        print(f"  {' '.join(parts)}")

    # Confusion matrix
    print(f"\nConfusion matrix (all positions pooled):")
    header = "      " + "  ".join(f"{c:>5}" for c in COLOR_CLASSES)
    print(header)
    for i, row_color in enumerate(COLOR_CLASSES):
        row = f"  {row_color}   " + "  ".join(f"{confusion[i][j]:>5}" for j in range(NUM_COLORS))
        print(row)


if __name__ == "__main__":
    main()

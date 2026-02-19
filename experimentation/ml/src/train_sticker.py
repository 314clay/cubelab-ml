"""
Training loop for the StickerClassifier model.

Usage:
    python3 ml/src/train_sticker.py --data-dir ml/data/training_renders/ --epochs 30 --device mps
"""

import argparse
import os
import sys
import time

import torch
import torch.nn as nn
from torch.utils.data import DataLoader

# Allow running from experimentation/ directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

from sticker_model import StickerClassifier
from sticker_dataset import StickerDataset


def auto_device():
    if torch.backends.mps.is_available():
        return 'mps'
    if torch.cuda.is_available():
        return 'cuda'
    return 'cpu'


def train_epoch(model, loader, optimizer, criterion, device):
    model.train()
    total_loss = 0.0
    total_correct = 0
    total_stickers = 0

    for images, labels in loader:
        images = images.to(device)
        labels = labels.to(device)  # (B, 27)

        logits = model(images)  # (B, 27, 6)

        # Reshape for cross-entropy: (B*27, 6) vs (B*27,)
        loss = criterion(logits.reshape(-1, 6), labels.reshape(-1))

        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * images.size(0)
        preds = logits.argmax(dim=2)  # (B, 27)
        total_correct += (preds == labels).sum().item()
        total_stickers += labels.numel()

    avg_loss = total_loss / len(loader.dataset)
    accuracy = total_correct / total_stickers
    return avg_loss, accuracy


def validate(model, loader, criterion, device):
    model.eval()
    total_loss = 0.0
    total_correct = 0
    total_stickers = 0
    total_images_correct = 0
    total_images = 0

    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            labels = labels.to(device)

            logits = model(images)
            loss = criterion(logits.reshape(-1, 6), labels.reshape(-1))

            total_loss += loss.item() * images.size(0)
            preds = logits.argmax(dim=2)
            total_correct += (preds == labels).sum().item()
            total_stickers += labels.numel()

            # Per-image accuracy: all 27 stickers correct
            all_correct = (preds == labels).all(dim=1)
            total_images_correct += all_correct.sum().item()
            total_images += images.size(0)

    avg_loss = total_loss / len(loader.dataset)
    sticker_acc = total_correct / total_stickers
    image_acc = total_images_correct / total_images
    return avg_loss, sticker_acc, image_acc


def main():
    parser = argparse.ArgumentParser(description="Train StickerClassifier")
    parser.add_argument('--data-dir', type=str, default='ml/data/training_renders/')
    parser.add_argument('--epochs', type=int, default=30)
    parser.add_argument('--batch-size', type=int, default=32)
    parser.add_argument('--lr', type=float, default=1e-3)
    parser.add_argument('--device', type=str, default='auto')
    parser.add_argument('--checkpoint', type=str, default='ml/checkpoints/sticker_classifier.pt')
    parser.add_argument('--seed', type=int, default=42)
    args = parser.parse_args()

    torch.manual_seed(args.seed)

    device = torch.device(args.device if args.device != 'auto' else auto_device())
    print(f"Device: {device}")

    # Parse comma-separated data dirs
    data_dirs = [d.strip() for d in args.data_dir.split(',')]
    data_dir = data_dirs if len(data_dirs) > 1 else data_dirs[0]

    # Datasets
    train_ds = StickerDataset(data_dir, split='train', seed=args.seed)
    val_ds = StickerDataset(data_dir, split='val', seed=args.seed, augment=False)
    print(f"Train: {len(train_ds)} samples, Val: {len(val_ds)} samples")

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=0)

    # Model
    model = StickerClassifier(pretrained=True).to(device)
    num_params = sum(p.numel() for p in model.parameters())
    print(f"Model parameters: {num_params:,}")

    # Freeze early layers initially
    model.freeze_early_layers()
    frozen_params = sum(1 for p in model.parameters() if not p.requires_grad)
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Trainable parameters (frozen mode): {trainable_params:,}")

    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = torch.optim.AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=args.lr, weight_decay=1e-4
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    # Checkpoint dir
    os.makedirs(os.path.dirname(args.checkpoint), exist_ok=True)

    best_sticker_acc = 0.0
    start = time.time()

    for epoch in range(1, args.epochs + 1):
        # Unfreeze all layers after epoch 5
        if epoch == 6:
            print("\n--- Unfreezing all layers ---")
            model.unfreeze_all()
            # Rebuild optimizer with all params at reduced LR
            optimizer = torch.optim.AdamW(
                model.parameters(), lr=args.lr * 0.3, weight_decay=1e-4
            )
            scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
                optimizer, T_max=args.epochs - 5
            )

        train_loss, train_acc = train_epoch(model, train_loader, optimizer, criterion, device)
        val_loss, val_sticker_acc, val_image_acc = validate(model, val_loader, criterion, device)
        scheduler.step()

        lr = optimizer.param_groups[0]['lr']
        print(f"Epoch {epoch:2d}/{args.epochs}  "
              f"train_loss={train_loss:.4f}  train_sticker_acc={train_acc:.3f}  "
              f"val_loss={val_loss:.4f}  val_sticker_acc={val_sticker_acc:.3f}  "
              f"val_image_acc={val_image_acc:.3f}  lr={lr:.6f}")

        if val_sticker_acc > best_sticker_acc:
            best_sticker_acc = val_sticker_acc
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'val_sticker_acc': val_sticker_acc,
                'val_image_acc': val_image_acc,
            }, args.checkpoint)
            print(f"  -> Saved best checkpoint (sticker_acc={val_sticker_acc:.3f})")

    elapsed = time.time() - start
    print(f"\nTraining complete in {elapsed:.1f}s")
    print(f"Best val sticker accuracy: {best_sticker_acc:.3f}")
    print(f"Checkpoint: {args.checkpoint}")


if __name__ == "__main__":
    main()

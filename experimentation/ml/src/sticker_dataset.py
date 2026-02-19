"""
StickerDataset: loads PNG + JSON pairs from training_renders/ directory.

Each sample returns:
  - image: (3, 224, 224) tensor, normalized with ImageNet stats
  - label: (27,) tensor of class indices (W=0, Y=1, R=2, O=3, G=4, B=5)
"""

import json
import os

import torch
from torch.utils.data import Dataset
from torchvision import transforms
from PIL import Image


COLOR_TO_IDX = {'W': 0, 'Y': 1, 'R': 2, 'O': 3, 'G': 4, 'B': 5}
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


class StickerDataset(Dataset):
    def __init__(self, data_dir, split='train', seed=42, val_ratio=0.2, augment=True,
                 whitelist_path=None):
        """
        Args:
            data_dir: path (str) or list of paths to directories with PNG + JSON pairs
            split: 'train' or 'val'
            seed: random seed for deterministic split
            val_ratio: fraction of data for validation
            augment: whether to apply data augmentation (train only)
            whitelist_path: optional TSV file of (dir, json_filename) pairs to include
        """
        if isinstance(data_dir, str):
            data_dirs = [data_dir]
        else:
            data_dirs = list(data_dir)

        # Collect all (directory, json_filename) pairs
        all_samples = []

        if whitelist_path:
            # Load only whitelisted samples
            allowed = set()
            with open(whitelist_path) as wf:
                for line in wf:
                    line = line.strip()
                    if line:
                        parts = line.split('\t')
                        allowed.add((parts[0], parts[1]))
            for d in data_dirs:
                jsons = sorted(
                    f for f in os.listdir(d)
                    if f.endswith('.json') and f != 'manifest.json'
                )
                for j in jsons:
                    if (d, j) in allowed:
                        all_samples.append((d, j))
        else:
            for d in data_dirs:
                jsons = sorted(
                    f for f in os.listdir(d)
                    if f.endswith('.json') and f != 'manifest.json'
                )
                for j in jsons:
                    all_samples.append((d, j))

        # Deterministic train/val split by index
        import random
        rng = random.Random(seed)
        indices = list(range(len(all_samples)))
        rng.shuffle(indices)

        n_val = int(len(indices) * val_ratio)
        if split == 'val':
            selected = sorted(indices[:n_val])
        else:
            selected = sorted(indices[n_val:])

        self.samples = [all_samples[i] for i in selected]

        # Transforms
        base_transforms = [
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]

        if augment and split == 'train':
            self.transform = transforms.Compose([
                transforms.Resize((224, 224)),
                transforms.ColorJitter(
                    brightness=0.3, contrast=0.3, saturation=0.3, hue=0.08
                ),
                transforms.RandomAffine(
                    degrees=5, translate=(0.05, 0.05), scale=(0.9, 1.1)
                ),
                transforms.ToTensor(),
                transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
            ])
        else:
            self.transform = transforms.Compose(base_transforms)

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        data_dir, json_file = self.samples[idx]
        json_path = os.path.join(data_dir, json_file)

        with open(json_path) as f:
            label_data = json.load(f)

        # Load image
        img_file = label_data['image']
        img_path = os.path.join(data_dir, img_file)
        image = Image.open(img_path).convert('RGB')
        image = self.transform(image)

        # Extract 27 sticker labels: U[0-8] + F[0-8] + R[0-8]
        full_state = label_data['full_state']
        stickers = full_state['U'] + full_state['F'] + full_state['R']
        label = torch.tensor([COLOR_TO_IDX[c] for c in stickers], dtype=torch.long)

        return image, label


if __name__ == "__main__":
    import sys
    arg = sys.argv[1] if len(sys.argv) > 1 else "ml/data/training_renders"
    # Support comma-separated directories
    data_dirs = [d.strip() for d in arg.split(',')]
    data_dir = data_dirs if len(data_dirs) > 1 else data_dirs[0]
    ds = StickerDataset(data_dir, split='train')
    print(f"Train samples: {len(ds)}")
    if len(ds) > 0:
        img, label = ds[0]
        print(f"Image shape: {img.shape}")
        print(f"Label shape: {label.shape}")
        print(f"Label values: {label.tolist()}")
    ds_val = StickerDataset(data_dir, split='val')
    print(f"Val samples: {len(ds_val)}")

"""
StickerClassifier: ResNet-18 backbone for 27-sticker color classification.

Input:  (B, 3, 224, 224) RGB image
Output: (B, 27, 6) logits — 27 sticker positions, 6 color classes each
"""

import torch
import torch.nn as nn
from torchvision.models import resnet18, ResNet18_Weights


COLOR_CLASSES = ['W', 'Y', 'R', 'O', 'G', 'B']
NUM_COLORS = len(COLOR_CLASSES)
NUM_STICKERS = 27  # U[0-8] + F[0-8] + R[0-8]


class StickerClassifier(nn.Module):
    def __init__(self, pretrained=True):
        super().__init__()
        weights = ResNet18_Weights.DEFAULT if pretrained else None
        backbone = resnet18(weights=weights)

        # Keep everything except the final FC layer
        self.features = nn.Sequential(
            backbone.conv1,
            backbone.bn1,
            backbone.relu,
            backbone.maxpool,
            backbone.layer1,
            backbone.layer2,
            backbone.layer3,
            backbone.layer4,
        )
        self.pool = nn.AdaptiveAvgPool2d(1)

        # Classification head: 512 -> 256 -> 27*6
        self.head = nn.Sequential(
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(256, NUM_STICKERS * NUM_COLORS),
        )

    def forward(self, x):
        """
        Args:
            x: (B, 3, 224, 224) input images
        Returns:
            (B, 27, 6) logits per sticker position
        """
        feat = self.features(x)           # (B, 512, 7, 7)
        feat = self.pool(feat)            # (B, 512, 1, 1)
        feat = feat.flatten(1)            # (B, 512)
        logits = self.head(feat)          # (B, 162)
        return logits.view(-1, NUM_STICKERS, NUM_COLORS)  # (B, 27, 6)

    def freeze_early_layers(self):
        """Freeze ResNet layers 1-2 (conv1, bn1, layer1, layer2)."""
        for i, child in enumerate(self.features.children()):
            if i < 5:  # conv1, bn1, relu, maxpool, layer1 — plus layer2 at index 5
                for p in child.parameters():
                    p.requires_grad = False
        # Also freeze layer2 (index 5)
        for p in list(self.features.children())[5].parameters():
            p.requires_grad = False

    def unfreeze_all(self):
        """Unfreeze all parameters."""
        for p in self.parameters():
            p.requires_grad = True


if __name__ == "__main__":
    model = StickerClassifier(pretrained=False)
    dummy = torch.randn(1, 3, 224, 224)
    out = model(dummy)
    print(f"Input:  {dummy.shape}")
    print(f"Output: {out.shape}")
    assert out.shape == (1, 27, 6), f"Expected (1, 27, 6), got {out.shape}"
    print("OK — forward pass verified")

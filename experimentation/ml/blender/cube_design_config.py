"""
CubeDesignConfig: parameterizes Rubik's cube geometry, materials, and colors
for training data variety.

Provides:
  - CubeDesignConfig dataclass with all variable parameters
  - Named presets for common cube types
  - random_config(rng) to sample from realistic ranges per render
  - default_*_config() to reproduce current hardcoded behavior exactly

Pure Python — no bpy dependency. Importable by Blender scripts and tests.
"""

from dataclasses import dataclass, field, asdict
from typing import Dict, Tuple, Optional
import random
import copy


@dataclass
class CubeDesignConfig:
    """Complete configuration for a rendered Rubik's cube design."""

    # --- Cube type ---
    cube_style: str = 'stickerless'  # 'stickerless' or 'stickered'

    # --- Stickerless geometry ---
    cubie_size: float = 0.60
    gap: float = 0.02
    bevel_radius: float = 0.04
    bevel_segments: int = 3
    florian_mod: bool = False         # Inner edge rounding
    florian_radius: float = 0.02
    florian_segments: int = 2
    pillow: bool = False              # Convex face effect
    pillow_strength: float = 0.0
    overall_scale: float = 1.0        # 0.96–1.04 maps ~55mm to ~57mm

    # --- Stickered geometry ---
    sticker_size: float = 0.85
    sticker_grid_spacing: float = 0.95
    sticker_elevation: float = 0.01
    body_size: float = 3.0
    sticker_corner_radius: float = 0.0

    # --- Surface material ---
    roughness: float = 0.20
    metallic: float = 0.0
    ior: float = 1.49
    specular_ior_level: float = 0.6
    sss_weight_base: float = 0.02
    sss_weight_luminance_scale: float = 0.03
    coat_weight: float = 0.15
    coat_roughness: float = 0.3

    # --- Body material (stickered cubes) ---
    body_color: Tuple[float, float, float] = (0.02, 0.02, 0.02)
    body_roughness: float = 0.5

    # --- Internal mechanism (stickerless gaps) ---
    internal_color: Tuple[float, float, float] = (0.015, 0.015, 0.015)

    # --- Color palette ---
    colors: Dict[str, Tuple[float, float, float]] = field(default_factory=lambda: {
        'W': (0.92, 0.92, 0.90),
        'Y': (1.0, 0.85, 0.0),
        'R': (0.85, 0.08, 0.08),
        'O': (1.0, 0.45, 0.0),
        'G': (0.0, 0.65, 0.15),
        'B': (0.0, 0.25, 0.85),
    })
    color_jitter: float = 0.0  # Max per-channel RGB offset applied

    def to_dict(self):
        """Serialize for JSON labels."""
        return asdict(self)


# ---------------------------------------------------------------------------
# Named presets
# ---------------------------------------------------------------------------

def preset_modern_stickerless() -> CubeDesignConfig:
    """Modern speedcube (GAN 356, MoYu RS3M). Matches current defaults."""
    return CubeDesignConfig()


def preset_stickerless_bright() -> CubeDesignConfig:
    """Bright stickerless (QiYi, YJ bright scheme)."""
    return CubeDesignConfig(
        roughness=0.18, coat_weight=0.20, coat_roughness=0.25,
        colors={
            'W': (0.97, 0.97, 0.95), 'Y': (1.0, 0.92, 0.0),
            'R': (0.95, 0.10, 0.10), 'O': (1.0, 0.55, 0.0),
            'G': (0.0, 0.80, 0.20),  'B': (0.0, 0.35, 0.95),
        },
    )


def preset_stickerless_matte() -> CubeDesignConfig:
    """Matte/frosted stickerless speedcube."""
    return CubeDesignConfig(
        roughness=0.45, coat_weight=0.02, coat_roughness=0.6, ior=1.46,
        colors={
            'W': (0.88, 0.88, 0.86), 'Y': (0.95, 0.80, 0.0),
            'R': (0.80, 0.10, 0.10), 'O': (0.95, 0.42, 0.0),
            'G': (0.0, 0.60, 0.15),  'B': (0.0, 0.22, 0.80),
        },
    )



def preset_classic_stickered_black() -> CubeDesignConfig:
    """Classic Rubik's: black body + vinyl stickers."""
    return CubeDesignConfig(
        cube_style='stickered',
        body_color=(0.02, 0.02, 0.02), body_roughness=0.5,
        roughness=0.5, coat_weight=0.0, coat_roughness=0.5,
        ior=1.45, specular_ior_level=0.5,
        sss_weight_base=0.0, sss_weight_luminance_scale=0.0,
        colors={
            'W': (1.0, 1.0, 1.0), 'Y': (1.0, 1.0, 0.0),
            'R': (1.0, 0.0, 0.0), 'O': (1.0, 0.5, 0.0),
            'G': (0.0, 0.8, 0.0), 'B': (0.0, 0.0, 1.0),
        },
    )


def preset_stickered_white() -> CubeDesignConfig:
    """White-body stickered cube."""
    cfg = preset_classic_stickered_black()
    cfg.body_color = (0.88, 0.88, 0.85)
    cfg.body_roughness = 0.4
    return cfg


def preset_stickered_primary() -> CubeDesignConfig:
    """Primary-color body stickered (Rubik's brand modern)."""
    cfg = preset_classic_stickered_black()
    cfg.body_color = (0.15, 0.15, 0.15)
    cfg.roughness = 0.35
    cfg.coat_weight = 0.10
    return cfg


def preset_budget_cube() -> CubeDesignConfig:
    """Budget stickerless: wider gaps, less bevel, duller finish."""
    return CubeDesignConfig(
        cubie_size=0.58, gap=0.04, bevel_radius=0.02, bevel_segments=2,
        roughness=0.35, coat_weight=0.05, coat_roughness=0.5, ior=1.46,
        colors={
            'W': (0.85, 0.85, 0.82), 'Y': (0.90, 0.78, 0.0),
            'R': (0.78, 0.10, 0.10), 'O': (0.90, 0.40, 0.0),
            'G': (0.0, 0.55, 0.12),  'B': (0.0, 0.20, 0.75),
        },
    )


PRESETS = {
    'modern_stickerless': preset_modern_stickerless,
    'stickerless_bright': preset_stickerless_bright,
    'stickerless_matte': preset_stickerless_matte,
'classic_stickered_black': preset_classic_stickered_black,
    'stickered_white': preset_stickered_white,
    'stickered_primary': preset_stickered_primary,
    'budget_cube': preset_budget_cube,
}


# ---------------------------------------------------------------------------
# Color palettes (brand-inspired)
# ---------------------------------------------------------------------------

_PALETTE_POOL = [
    # Standard MoYu / GAN
    {'W': (0.92, 0.92, 0.90), 'Y': (1.0, 0.85, 0.0), 'R': (0.85, 0.08, 0.08),
     'O': (1.0, 0.45, 0.0), 'G': (0.0, 0.65, 0.15), 'B': (0.0, 0.25, 0.85)},
    # QiYi bright
    {'W': (0.97, 0.97, 0.95), 'Y': (1.0, 0.92, 0.0), 'R': (0.95, 0.10, 0.10),
     'O': (1.0, 0.55, 0.0), 'G': (0.0, 0.80, 0.20), 'B': (0.0, 0.35, 0.95)},
    # Classic Rubik's sticker
    {'W': (1.0, 1.0, 1.0), 'Y': (1.0, 1.0, 0.0), 'R': (1.0, 0.0, 0.0),
     'O': (1.0, 0.5, 0.0), 'G': (0.0, 0.8, 0.0), 'B': (0.0, 0.0, 1.0)},
    # DaYan / older speedcube
    {'W': (0.90, 0.90, 0.88), 'Y': (0.95, 0.82, 0.0), 'R': (0.80, 0.06, 0.06),
     'O': (0.95, 0.40, 0.0), 'G': (0.0, 0.58, 0.12), 'B': (0.0, 0.20, 0.78)},
    # Warm-shifted (GAN 12)
    {'W': (0.94, 0.93, 0.88), 'Y': (1.0, 0.88, 0.05), 'R': (0.88, 0.05, 0.05),
     'O': (1.0, 0.50, 0.02), 'G': (0.0, 0.70, 0.10), 'B': (0.05, 0.30, 0.90)},
]


def _jitter_color(rgb, jitter, rng):
    """Apply per-channel jitter, clamped to [0, 1]."""
    return tuple(max(0.0, min(1.0, c + rng.uniform(-jitter, jitter))) for c in rgb)


# ---------------------------------------------------------------------------
# Random config sampler
# ---------------------------------------------------------------------------

def random_config(rng: random.Random, style: str = None) -> CubeDesignConfig:
    """
    Sample a random CubeDesignConfig from realistic speedcube ranges.

    Args:
        rng: seeded random.Random instance
        style: force 'stickerless' or 'stickered', or None for random
               (70% stickerless, 30% stickered)
    """
    if style is None:
        style = 'stickerless' if rng.random() < 0.70 else 'stickered'

    # Pick base palette then jitter
    base_palette = rng.choice(_PALETTE_POOL)
    jitter = rng.uniform(0.0, 0.06)
    colors = {k: _jitter_color(v, jitter, rng) for k, v in base_palette.items()}

    # Shared material params
    roughness = rng.uniform(0.12, 0.50)
    coat_weight = rng.uniform(0.0, 0.25)
    coat_roughness = rng.uniform(0.15, 0.60)
    ior = rng.uniform(1.44, 1.58)
    sss_base = rng.uniform(0.0, 0.04)
    sss_scale = rng.uniform(0.0, 0.05)

    # Geometry
    overall_scale = rng.uniform(0.96, 1.04)

    # Florian mod: ~30% of stickerless cubes get rounded sticker corners
    florian = rng.random() < 0.30 if style == 'stickerless' else False
    florian_radius = rng.uniform(0.02, 0.05) if florian else 0.0
    florian_segments = rng.choice([2, 3, 4]) if florian else 2

    if style == 'stickerless':
        return CubeDesignConfig(
            cube_style='stickerless',
            cubie_size=rng.uniform(0.56, 0.64),
            gap=rng.uniform(0.01, 0.05),
            bevel_radius=rng.uniform(0.02, 0.06),
            bevel_segments=rng.choice([2, 3, 3, 4]),
            florian_mod=florian,
            florian_radius=florian_radius,
            florian_segments=florian_segments,
            overall_scale=overall_scale,
            roughness=roughness,
            coat_weight=coat_weight,
            coat_roughness=coat_roughness,
            ior=ior,
            sss_weight_base=sss_base,
            sss_weight_luminance_scale=sss_scale,
            internal_color=(rng.uniform(0.01, 0.03),) * 3,
            colors=colors,
            color_jitter=jitter,
        )
    else:
        body_color = rng.choice([
            (0.02, 0.02, 0.02),   # Black
            (0.88, 0.88, 0.85),   # White
            (0.15, 0.15, 0.15),   # Dark gray
        ])
        return CubeDesignConfig(
            cube_style='stickered',
            body_color=body_color,
            body_roughness=rng.uniform(0.35, 0.55),
            sticker_size=rng.uniform(0.80, 0.88),
            sticker_grid_spacing=rng.uniform(0.92, 0.98),
            sticker_elevation=rng.uniform(0.008, 0.015),
            body_size=3.0,
            overall_scale=overall_scale,
            roughness=roughness,
            coat_weight=coat_weight,
            coat_roughness=coat_roughness,
            ior=ior,
            specular_ior_level=0.5,
            sss_weight_base=sss_base,
            sss_weight_luminance_scale=sss_scale,
            colors=colors,
            color_jitter=jitter,
        )


# ---------------------------------------------------------------------------
# Default configs (reproduce current hardcoded behavior exactly)
# ---------------------------------------------------------------------------

def default_stickerless_config() -> CubeDesignConfig:
    """Matches current render_stickerless.py constants exactly."""
    return preset_modern_stickerless()


def default_stickered_config() -> CubeDesignConfig:
    """Matches current render_known_states.py constants exactly."""
    return preset_classic_stickered_black()

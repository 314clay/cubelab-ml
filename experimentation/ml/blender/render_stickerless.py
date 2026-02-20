"""
Stickerless Rubik's Cube renderer for Blender.

Generates realistic stickerless cube renders where each cubie is a separate
mesh with colored ABS plastic materials (no stickers).

Run with:
    blender --background --python render_stickerless.py
    blender --background --python render_stickerless.py -- --case t_perm
    blender --background --python render_stickerless.py -- --case solved
"""

import bpy
import bmesh
import math
import json
import os
import sys
import random

# ---------------------------------------------------------------------------
# Path setup — import Cube class and algorithms from cube-photo-solve
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)

from state_resolver import Cube
from algorithms import OLL_CASES, PLL_CASES

sys.path.insert(0, SCRIPT_DIR)
from cube_design_config import CubeDesignConfig, default_stickerless_config

# Module-level config — overridden by training scripts via exec() globals
CUBE_DESIGN_CONFIG = None

def _get_config():
    global CUBE_DESIGN_CONFIG
    if CUBE_DESIGN_CONFIG is None:
        CUBE_DESIGN_CONFIG = default_stickerless_config()
    return CUBE_DESIGN_CONFIG

OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "stickerless_renders")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Stickerless color palette — realistic ABS plastic RGB values
# These match modern stickerless speedcubes (e.g. MoYu RS3M, GAN)
# ---------------------------------------------------------------------------
STICKERLESS_COLORS = {
    'W': (0.92, 0.92, 0.90),   # Off-white plastic
    'Y': (1.0, 0.85, 0.0),     # Warm yellow
    'R': (0.85, 0.08, 0.08),   # Deep red
    'O': (1.0, 0.45, 0.0),     # Bright orange
    'G': (0.0, 0.65, 0.15),    # Forest green
    'B': (0.0, 0.25, 0.85),    # Royal blue
}

# Internal mechanism color (visible in gaps between cubies)
INTERNAL_COLOR = (0.015, 0.015, 0.015)  # Near-black

# Cube geometry constants
CUBE_SIZE = 1.92          # Full cube is ~57mm, normalized to ~1.92 units
CUBIE_SIZE = 0.60         # Each cubie ~0.60 units (with gap)
GAP = 0.02                # Gap between cubies (reveals internal mechanism)
BEVEL_RADIUS = 0.04       # Rounded edges on each cubie
BEVEL_SEGMENTS = 3        # Smoothness of bevel

# ---------------------------------------------------------------------------
# Which face indices map to which cubie positions
# Face layout:
#   0 1 2
#   3 4 5
#   6 7 8
#
# Cubie grid positions: (col, row) where (0,0) is top-left of face
# ---------------------------------------------------------------------------

# 26 cubies: 8 corners + 12 edges + 6 centers
# Each cubie is defined by its grid position (x, y, z) in {-1, 0, 1}
# and which face colors it shows

def _cubie_world_pos(gx, gy, gz, config=None):
    """Convert grid position (-1,0,1) to world coordinates (scale-baked)."""
    if config is None:
        config = _get_config()
    spacing = (config.cubie_size + config.gap) * config.overall_scale
    return (gx * spacing, gy * spacing, gz * spacing)


def _face_index(row, col):
    """Convert (row, col) to face index 0-8."""
    return row * 3 + col


# Map from (grid_x, grid_y, grid_z) -> dict of {face_name: face_index}
# Grid: x = R(+1)/L(-1), y = B(+1)/F(-1), z = U(+1)/D(-1)
# Face U: looking down at top, row 0 = back, col 0 = left
# Face F: looking at front, row 0 = top, col 0 = left
# Face R: looking at right, row 0 = top, col 0 = front

CUBIE_FACE_MAP = {}

for gx in (-1, 0, 1):
    for gy in (-1, 0, 1):
        for gz in (-1, 0, 1):
            if gx == 0 and gy == 0 and gz == 0:
                continue  # No center-of-cube cubie

            faces = {}

            # U face (z = +1): row from back(0) to front(2), col from left(0) to right(2)
            if gz == 1:
                u_row = {1: 0, 0: 1, -1: 2}[gy]  # back=0, front=2
                u_col = {-1: 0, 0: 1, 1: 2}[gx]   # left=0, right=2
                faces['U'] = _face_index(u_row, u_col)

            # D face (z = -1): row from front(0) to back(2), col from left(0) to right(2)
            if gz == -1:
                d_row = {-1: 0, 0: 1, 1: 2}[gy]  # front=0, back=2
                d_col = {-1: 0, 0: 1, 1: 2}[gx]
                faces['D'] = _face_index(d_row, d_col)

            # F face (y = -1): row from top(0) to bottom(2), col from left(0) to right(2)
            if gy == -1:
                f_row = {1: 0, 0: 1, -1: 2}[gz]  # top=0, bottom=2
                f_col = {-1: 0, 0: 1, 1: 2}[gx]
                faces['F'] = _face_index(f_row, f_col)

            # B face (y = +1): row from top(0) to bottom(2), col from right(0) to left(2)
            if gy == 1:
                b_row = {1: 0, 0: 1, -1: 2}[gz]
                b_col = {1: 0, 0: 1, -1: 2}[gx]  # mirrored
                faces['B'] = _face_index(b_row, b_col)

            # L face (x = -1): row from top(0) to bottom(2), col from front(0) to back(2)
            if gx == -1:
                l_row = {1: 0, 0: 1, -1: 2}[gz]
                l_col = {-1: 0, 0: 1, 1: 2}[gy]
                faces['L'] = _face_index(l_row, l_col)

            # R face (x = +1): row from top(0) to bottom(2), col from back(0) to front(2)
            if gx == 1:
                r_row = {1: 0, 0: 1, -1: 2}[gz]
                r_col = {1: 0, 0: 1, -1: 2}[gy]  # mirrored
                faces['R'] = _face_index(r_row, r_col)

            CUBIE_FACE_MAP[(gx, gy, gz)] = faces


# ---------------------------------------------------------------------------
# Blender helpers
# ---------------------------------------------------------------------------

def clear_scene():
    """Remove all objects, materials, and meshes."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)


_material_cache = {}

def get_abs_material(name, color_rgb, config=None):
    """
    Create or retrieve a realistic ABS plastic material.

    Settings based on real ABS plastic properties:
    - IOR ~1.46-1.61 (varies slightly by pigment)
    - Semi-glossy surface
    - Very subtle subsurface scattering (more on lighter colors)
    """
    if config is None:
        config = _get_config()
    cache_key = (name, color_rgb, id(config))
    if cache_key in _material_cache:
        return _material_cache[cache_key]

    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")

    bsdf.inputs['Base Color'].default_value = (*color_rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = config.roughness
    bsdf.inputs['Metallic'].default_value = config.metallic
    bsdf.inputs['IOR'].default_value = config.ior
    bsdf.inputs['Specular IOR Level'].default_value = config.specular_ior_level

    luminance = 0.299 * color_rgb[0] + 0.587 * color_rgb[1] + 0.114 * color_rgb[2]
    sss_weight = config.sss_weight_base + config.sss_weight_luminance_scale * luminance
    bsdf.inputs['Subsurface Weight'].default_value = sss_weight
    bsdf.inputs['Subsurface Radius'].default_value = (color_rgb[0] * 0.5 + 0.1,
                                                       color_rgb[1] * 0.5 + 0.1,
                                                       color_rgb[2] * 0.5 + 0.1)

    bsdf.inputs['Coat Weight'].default_value = config.coat_weight
    bsdf.inputs['Coat Roughness'].default_value = config.coat_roughness

    _material_cache[cache_key] = mat
    return mat


def _create_rounded_rect_mesh(name, width, height, corner_radius, segments):
    """Create a mesh object with a rounded-rectangle face in the XY plane at z=0.

    Face normal points +Z. Used as a sticker overlay for Florian-modded cubies.
    """
    bm = bmesh.new()
    hw, hh = width / 2.0, height / 2.0
    r = min(corner_radius, hw * 0.49, hh * 0.49)
    segs = max(segments, 1)

    verts = []
    if r < 0.0005:
        # Plain rectangle (CCW from bottom-right for +Z normal)
        for x, y in [(hw, -hh), (hw, hh), (-hw, hh), (-hw, -hh)]:
            verts.append(bm.verts.new((x, y, 0)))
    else:
        # Four corner arcs, CCW: bottom-right → top-right → top-left → bottom-left
        corner_data = [
            (hw - r,    -(hh - r), -math.pi / 2),
            (hw - r,     hh - r,    0),
            (-(hw - r),  hh - r,    math.pi / 2),
            (-(hw - r), -(hh - r),  math.pi),
        ]
        for cx, cy, start_a in corner_data:
            for i in range(segs):
                angle = start_a + (math.pi / 2) * i / segs
                verts.append(bm.verts.new((
                    cx + r * math.cos(angle),
                    cy + r * math.sin(angle),
                    0,
                )))

    bm.faces.new(verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _add_florian_stickers(gx, gy, gz, cube_state, config):
    """Add rounded-rectangle sticker overlays on external faces of a cubie.

    Each sticker is a separate mesh object colored with the appropriate
    ABS material.  The cubie itself is left all-dark so the rounded corners
    reveal the internal color — visually identical to Florian inner-edge
    rounding with zero mesh-bevel complexity.
    """
    face_map = CUBIE_FACE_MAP.get((gx, gy, gz), {})
    if not face_map:
        return

    scale = config.overall_scale
    cubie_half = config.cubie_size * scale / 2.0

    # Sticker covers the flat face area (cubie minus bevel on each side)
    sticker_size = (config.cubie_size - 2 * config.bevel_radius) * scale
    elevation = 0.002 * scale  # Tiny offset to prevent z-fighting

    cubie_pos = _cubie_world_pos(gx, gy, gz, config)
    cx, cy, cz = cubie_pos

    for face_name, face_idx in face_map.items():
        color_letter = cube_state.faces[face_name][face_idx]
        color_rgb = config.colors[color_letter]
        mat = get_abs_material(f"ABS_{color_letter}", color_rgb, config)

        sticker = _create_rounded_rect_mesh(
            f"Sticker_{gx}_{gy}_{gz}_{face_name}",
            sticker_size, sticker_size,
            config.florian_radius * scale,
            config.florian_segments,
        )

        # Position and orient so face normal points outward from the cubie
        if face_name == 'U':
            sticker.location = (cx, cy, cz + cubie_half + elevation)
        elif face_name == 'D':
            sticker.location = (cx, cy, cz - cubie_half - elevation)
            sticker.rotation_euler = (math.pi, 0, 0)
        elif face_name == 'F':
            sticker.location = (cx, cy - cubie_half - elevation, cz)
            sticker.rotation_euler = (math.pi / 2, 0, 0)
        elif face_name == 'B':
            sticker.location = (cx, cy + cubie_half + elevation, cz)
            sticker.rotation_euler = (-math.pi / 2, 0, 0)
        elif face_name == 'R':
            sticker.location = (cx + cubie_half + elevation, cy, cz)
            sticker.rotation_euler = (0, math.pi / 2, 0)
        elif face_name == 'L':
            sticker.location = (cx - cubie_half - elevation, cy, cz)
            sticker.rotation_euler = (0, -math.pi / 2, 0)

        sticker.data.materials.append(mat)


def create_cubie_mesh(gx, gy, gz, cube_state, config=None):
    """
    Create a single cubie mesh with per-face colored materials.

    Each cubie is a beveled cube. External faces get the appropriate color
    material, internal faces (facing other cubies) get the black internal material.
    """
    if config is None:
        config = _get_config()

    pos = _cubie_world_pos(gx, gy, gz, config)
    face_map = CUBIE_FACE_MAP.get((gx, gy, gz), {})

    # Bake overall_scale into mesh size (positions already scaled)
    scaled_cubie = config.cubie_size * config.overall_scale
    bpy.ops.mesh.primitive_cube_add(size=scaled_cubie, location=pos)
    obj = bpy.context.active_object
    obj.name = f"Cubie_{gx}_{gy}_{gz}"

    # Standard bevel modifier for outer edges (always applied)
    bevel = obj.modifiers.new(name="Bevel", type='BEVEL')
    bevel.width = config.bevel_radius * config.overall_scale
    bevel.segments = config.bevel_segments
    bevel.limit_method = 'ANGLE'
    bevel.angle_limit = math.radians(60)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Bevel")

    if config.florian_mod and config.florian_radius > 0:
        # Florian mode: cubie is all-dark, rounded sticker overlays provide color
        internal_mat = get_abs_material("Internal_Black", config.internal_color, config)
        obj.data.materials.append(internal_mat)
        # All polys default to material_index 0 (dark) — no per-face assignment
        _add_florian_stickers(gx, gy, gz, cube_state, config)
    else:
        # Standard mode: per-face colored material assignment
        internal_mat = get_abs_material("Internal_Black", config.internal_color, config)
        obj.data.materials.append(internal_mat)

        face_direction_materials = {}
        for face_name, face_idx in face_map.items():
            color_letter = cube_state.faces[face_name][face_idx]
            color_rgb = config.colors[color_letter]
            mat_name = f"ABS_{color_letter}"
            mat = get_abs_material(mat_name, color_rgb, config)
            slot_idx = len(obj.data.materials)
            obj.data.materials.append(mat)
            face_direction_materials[face_name] = slot_idx

        mesh = obj.data
        mesh.update()
        THRESHOLD = 0.5

        for poly in mesh.polygons:
            nx, ny, nz = poly.normal
            assigned = False
            if nz > THRESHOLD and 'U' in face_direction_materials:
                poly.material_index = face_direction_materials['U']
                assigned = True
            elif nz < -THRESHOLD and 'D' in face_direction_materials:
                poly.material_index = face_direction_materials['D']
                assigned = True
            elif ny < -THRESHOLD and 'F' in face_direction_materials:
                poly.material_index = face_direction_materials['F']
                assigned = True
            elif ny > THRESHOLD and 'B' in face_direction_materials:
                poly.material_index = face_direction_materials['B']
                assigned = True
            elif nx < -THRESHOLD and 'L' in face_direction_materials:
                poly.material_index = face_direction_materials['L']
                assigned = True
            elif nx > THRESHOLD and 'R' in face_direction_materials:
                poly.material_index = face_direction_materials['R']
                assigned = True
            if not assigned:
                poly.material_index = 0

    return obj


def create_internal_mechanism(config=None):
    """
    Create the black internal structure visible through gaps.
    A slightly smaller cube behind the cubies.
    """
    if config is None:
        config = _get_config()
    cube_size = (config.cubie_size + config.gap) * 2 + config.cubie_size
    inner_size = cube_size * 0.92 * config.overall_scale
    bpy.ops.mesh.primitive_cube_add(size=inner_size, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "InternalMechanism"
    mat = get_abs_material("Internal_Core", config.internal_color, config)
    obj.data.materials.append(mat)
    return obj


def build_stickerless_cube(cube_state, config=None):
    """Build the complete stickerless cube from 26 cubies + internal core."""
    if config is None:
        config = _get_config()
    cubies = []
    for (gx, gy, gz) in CUBIE_FACE_MAP:
        cubie = create_cubie_mesh(gx, gy, gz, cube_state, config)
        cubies.append(cubie)
    mechanism = create_internal_mechanism(config)
    return cubies, mechanism


# ---------------------------------------------------------------------------
# Camera & Lighting
# ---------------------------------------------------------------------------

def setup_camera(distance=5.5, azimuth_deg=45, elevation_deg=35, focal_length=50):
    """
    Position camera to see Top, Front, and Right faces.

    Args:
        distance: Distance from origin
        azimuth_deg: Horizontal angle (45 = classic corner view)
        elevation_deg: Vertical angle above horizon
        focal_length: Camera lens focal length in mm
    """
    az = math.radians(azimuth_deg)
    el = math.radians(elevation_deg)

    x = distance * math.cos(el) * math.cos(az)
    y = -distance * math.cos(el) * math.sin(az)
    z = distance * math.sin(el)

    bpy.ops.object.camera_add(location=(x, y, z))
    camera = bpy.context.active_object
    camera.name = "Camera"

    # Point camera at cube center
    constraint = camera.constraints.new(type='TRACK_TO')
    constraint.target = bpy.data.objects.get("InternalMechanism")
    if constraint.target is None:
        # Fallback: create empty at origin
        bpy.ops.object.empty_add(location=(0, 0, 0))
        target = bpy.context.active_object
        target.name = "CubeCenter"
        constraint.target = target
    constraint.track_axis = 'TRACK_NEGATIVE_Z'
    constraint.up_axis = 'UP_Y'

    camera.data.type = 'PERSP'
    camera.data.lens = focal_length
    camera.data.clip_end = 100

    bpy.context.scene.camera = camera
    return camera


def setup_lighting_studio():
    """
    Three-point studio lighting for clean, well-lit renders.
    """
    # Key light — warm, from upper right
    bpy.ops.object.light_add(type='AREA', location=(4, -3, 6))
    key = bpy.context.active_object
    key.name = "KeyLight"
    key.data.energy = 200
    key.data.size = 3.0
    key.data.color = (1.0, 0.95, 0.9)  # Slightly warm
    key.rotation_euler = (math.radians(45), 0, math.radians(30))

    # Fill light — cooler, from left
    bpy.ops.object.light_add(type='AREA', location=(-5, -2, 3))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 80
    fill.data.size = 4.0
    fill.data.color = (0.9, 0.93, 1.0)  # Slightly cool
    fill.rotation_euler = (math.radians(60), 0, math.radians(-150))

    # Rim/back light — for edge definition
    bpy.ops.object.light_add(type='AREA', location=(1, 5, 4))
    rim = bpy.context.active_object
    rim.name = "RimLight"
    rim.data.energy = 120
    rim.data.size = 2.0
    rim.rotation_euler = (math.radians(30), 0, math.radians(180))

    # Environment — subtle gradient background
    world = bpy.data.worlds.get("World")
    if world is None:
        world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs['Color'].default_value = (0.18, 0.18, 0.20, 1.0)
        bg.inputs['Strength'].default_value = 0.3


def setup_render_settings(resolution=720, samples=128):
    """Configure Cycles render settings."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'

    # Use GPU if available
    prefs = bpy.context.preferences.addons.get('cycles')
    if prefs:
        prefs.preferences.compute_device_type = 'METAL'  # macOS
        for device in prefs.preferences.devices:
            device.use = True
        scene.cycles.device = 'GPU'

    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True  # Transparent background


# ---------------------------------------------------------------------------
# Render cases
# ---------------------------------------------------------------------------

RENDER_CASES = {
    "solved": {
        "algorithms": [],
        "description": "Solved cube — all faces uniform color",
    },
    "t_perm": {
        "algorithms": [("PLL", "T-Perm", PLL_CASES["T-Perm"])],
        "description": "T-Perm applied to solved cube",
    },
    "h_perm": {
        "algorithms": [("PLL", "H-Perm", PLL_CASES["H-Perm"])],
        "description": "H-Perm applied",
    },
    "z_perm": {
        "algorithms": [("PLL", "Z-Perm", PLL_CASES["Z-Perm"])],
        "description": "Z-Perm applied",
    },
    "sune": {
        "algorithms": [("OLL", "OLL 27", OLL_CASES["OLL 27"])],
        "description": "Sune (OLL 27) applied",
    },
    "oll45_tperm": {
        "algorithms": [
            ("OLL", "OLL 45", OLL_CASES["OLL 45"]),
            ("PLL", "T-Perm", PLL_CASES["T-Perm"]),
        ],
        "description": "OLL 45 + T-Perm",
    },
}


def render_case(case_name, case_config):
    """Render a single case and save image + JSON label."""
    global _material_cache
    _material_cache = {}

    print(f"\n{'='*60}")
    print(f"Rendering: {case_name}")
    print(f"Description: {case_config['description']}")
    print(f"{'='*60}")

    clear_scene()

    # Build cube state
    cube = Cube()
    for alg_type, alg_name, alg_str in case_config.get("algorithms", []):
        print(f"  Applying {alg_name}: {alg_str}")
        cube.apply_algorithm(alg_str)

    # Build stickerless geometry
    cubies, mechanism = build_stickerless_cube(cube)
    print(f"  Created {len(cubies)} cubies")

    # Setup scene
    setup_camera()
    setup_lighting_studio()
    setup_render_settings()

    # Render
    image_path = os.path.join(OUTPUT_DIR, f"{case_name}.png")
    bpy.context.scene.render.filepath = image_path
    bpy.ops.render.render(write_still=True)

    # Save ground truth label
    visible = cube.get_visible_stickers()
    label = {
        "image": f"{case_name}.png",
        "style": "stickerless",
        "description": case_config["description"],
        "algorithms_applied": [
            {"type": t, "name": n, "moves": m}
            for t, n, m in case_config.get("algorithms", [])
        ],
        "visible_stickers": visible,
        "full_state": {k: list(v) for k, v in cube.faces.items()},
    }

    label_path = os.path.join(OUTPUT_DIR, f"{case_name}.json")
    with open(label_path, 'w') as f:
        json.dump(label, f, indent=2)

    print(f"  Saved image: {image_path}")
    print(f"  Saved label: {label_path}")
    print(f"  Visible stickers: {visible}")

    return image_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    # Parse args after "--"
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    # Simple arg parsing
    case_name = None
    render_all = False
    for i, arg in enumerate(argv):
        if arg == "--case" and i + 1 < len(argv):
            case_name = argv[i + 1]
        elif arg == "--all":
            render_all = True

    if render_all:
        for name, config in RENDER_CASES.items():
            render_case(name, config)
    elif case_name:
        if case_name in RENDER_CASES:
            render_case(case_name, RENDER_CASES[case_name])
        else:
            print(f"Unknown case: {case_name}")
            print(f"Available: {', '.join(RENDER_CASES.keys())}")
            sys.exit(1)
    else:
        # Default: render T-perm
        render_case("t_perm", RENDER_CASES["t_perm"])

    print(f"\nAll renders saved to: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()

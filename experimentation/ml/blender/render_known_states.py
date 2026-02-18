"""
Blender script to render Rubik's Cubes with known states.
Run with: blender --background --python render_known_states.py

Generates images + JSON ground truth labels for pipeline verification.
"""

import bpy
import bmesh
import json
import math
import os
import sys

# Add cube-photo-solve to path so we can import the Cube class
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)

from state_resolver import Cube
from algorithms import OLL_CASES, PLL_CASES

OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "verified_renders")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Standard Rubik's cube colors (RGB 0-1 range for Blender)
COLOR_MAP = {
    'W': (1.0, 1.0, 1.0),      # White
    'Y': (1.0, 1.0, 0.0),      # Yellow
    'R': (1.0, 0.0, 0.0),      # Red
    'O': (1.0, 0.5, 0.0),      # Orange
    'G': (0.0, 0.8, 0.0),      # Green
    'B': (0.0, 0.0, 1.0),      # Blue
}

# Face normal directions for each face (used to position stickers)
# In Blender: +X=right, +Y=forward, +Z=up
# Offset stickers slightly (0.01) above the cube surface to avoid z-fighting
FACE_CONFIG = {
    'U': {'normal': (0, 0, 1),  'up': (0, 1, 0),  'center_offset': (0, 0, 1.51)},
    'D': {'normal': (0, 0, -1), 'up': (0, -1, 0), 'center_offset': (0, 0, -1.51)},
    'F': {'normal': (0, -1, 0), 'up': (0, 0, 1),  'center_offset': (0, -1.51, 0)},
    'B': {'normal': (0, 1, 0),  'up': (0, 0, 1),  'center_offset': (0, 1.51, 0)},
    'L': {'normal': (-1, 0, 0), 'up': (0, 0, 1),  'center_offset': (-1.51, 0, 0)},
    'R': {'normal': (1, 0, 0),  'up': (0, 0, 1),  'center_offset': (1.51, 0, 0)},
}

def clear_scene():
    """Remove all objects from the scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # Clear orphan data
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)


def create_material(name, color_rgb):
    """Create a simple diffuse material with the given color."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs['Base Color'].default_value = (*color_rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.5
    bsdf.inputs['Metallic'].default_value = 0.0
    # Make it look more like plastic
    bsdf.inputs['Specular IOR Level'].default_value = 0.5
    return mat


def get_sticker_position(face, row, col):
    """
    Calculate the 3D position for a sticker on a given face.

    Face indices:
    0 1 2
    3 4 5
    6 7 8

    Row 0 = top of face, Row 2 = bottom of face
    Col 0 = left of face, Col 2 = right of face
    """
    config = FACE_CONFIG[face]
    nx, ny, nz = config['normal']
    cx, cy, cz = config['center_offset']
    ux, uy, uz = config['up']

    # Calculate right vector (cross product of up and normal)
    rx = uy * nz - uz * ny
    ry = uz * nx - ux * nz
    rz = ux * ny - uy * nx

    # Sticker offsets from center (-0.9, 0, +0.9 for 3x3 grid)
    # Row goes along -up direction (top=0 means high up value)
    col_offset = (col - 1) * 0.95
    row_offset = -(row - 1) * 0.95  # Negative because row 0 is top

    x = cx + col_offset * rx + row_offset * ux
    y = cy + col_offset * ry + row_offset * uy
    z = cz + col_offset * rz + row_offset * uz

    return (x, y, z)


def get_sticker_rotation(face):
    """Get euler rotation for a sticker plane on the given face."""
    rotations = {
        'U': (0, 0, 0),
        'D': (math.pi, 0, 0),
        'F': (math.pi/2, 0, 0),
        'B': (-math.pi/2, 0, math.pi),
        'L': (math.pi/2, 0, math.pi/2),
        'R': (math.pi/2, 0, -math.pi/2),
    }
    return rotations[face]


def create_cube_with_state(cube_state):
    """
    Create a Rubik's cube mesh in Blender with the given state.

    Args:
        cube_state: Cube object with the desired face colors
    """
    # Create the black cube body
    bpy.ops.mesh.primitive_cube_add(size=3.0, location=(0, 0, 0))
    body = bpy.context.active_object
    body.name = "CubeBody"

    body_mat = create_material("BlackBody", (0.02, 0.02, 0.02))
    body.data.materials.append(body_mat)

    # Create individual sticker planes for each face position
    for face_name, face_colors in cube_state.faces.items():
        for idx, color in enumerate(face_colors):
            row = idx // 3
            col = idx % 3

            pos = get_sticker_position(face_name, row, col)
            rot = get_sticker_rotation(face_name)

            # Create a small plane for the sticker
            bpy.ops.mesh.primitive_plane_add(
                size=0.85,
                location=pos,
                rotation=rot
            )
            sticker = bpy.context.active_object
            sticker.name = f"Sticker_{face_name}_{idx}"

            # Apply color material
            mat_name = f"Mat_{face_name}_{idx}_{color}"
            mat = create_material(mat_name, COLOR_MAP[color])
            sticker.data.materials.append(mat)


def setup_camera():
    """Position camera to see Top, Front, and Right faces."""
    bpy.ops.object.camera_add(
        location=(5.5, -5.5, 5.0),
        rotation=(math.radians(55), 0, math.radians(45))
    )
    camera = bpy.context.active_object
    camera.name = "Camera"
    bpy.context.scene.camera = camera

    # Set camera properties
    camera.data.type = 'PERSP'
    camera.data.lens = 50


def setup_lighting():
    """Simple uniform lighting for correctness (not beauty)."""
    # Key light from above-front-right
    bpy.ops.object.light_add(
        type='SUN',
        location=(5, -5, 10)
    )
    sun = bpy.context.active_object
    sun.name = "SunLight"
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(45))

    # Fill light from opposite side (softer)
    bpy.ops.object.light_add(
        type='SUN',
        location=(-5, 5, 5)
    )
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.5
    fill.rotation_euler = (math.radians(60), 0, math.radians(-135))

    # Ambient light (world background)
    world = bpy.data.worlds.get("World")
    if world is None:
        world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs['Color'].default_value = (0.3, 0.3, 0.3, 1.0)
        bg.inputs['Strength'].default_value = 0.5


def setup_render_settings():
    """Configure render for speed + correctness."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 64  # Low samples for speed
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.image_settings.file_format = 'PNG'


def render_cube_state(cube_state, filename, label_data):
    """
    Render a cube with the given state and save image + label.

    Args:
        cube_state: Cube object
        filename: Output filename (without extension)
        label_data: Dict with ground truth info (oll_case, pll_case, etc.)
    """
    clear_scene()
    create_cube_with_state(cube_state)
    setup_camera()
    setup_lighting()
    setup_render_settings()

    # Render
    image_path = os.path.join(OUTPUT_DIR, f"{filename}.png")
    bpy.context.scene.render.filepath = image_path
    bpy.ops.render.render(write_still=True)

    # Save ground truth label
    visible = cube_state.get_visible_stickers()
    label = {
        "image": f"{filename}.png",
        "oll_case": label_data.get("oll_case", ""),
        "pll_case": label_data.get("pll_case", ""),
        "visible_stickers": visible,
        "top_face": list(cube_state.faces['U']),
        "front_top_row": list(cube_state.faces['F'][0:3]),
        "right_top_row": list(cube_state.faces['R'][0:3]),
        "full_state": {k: list(v) for k, v in cube_state.faces.items()},
    }

    label_path = os.path.join(OUTPUT_DIR, f"{filename}.json")
    with open(label_path, 'w') as f:
        json.dump(label, f, indent=2)

    print(f"Rendered: {image_path}")
    print(f"Label: {label_path}")
    print(f"Visible stickers: {visible}")


def main():
    """Generate all test renders."""

    renders = [
        # 1. Solved cube
        {
            "name": "solved",
            "algorithms": [],
            "oll_case": "OLL Skip",
            "pll_case": "Solved",
        },
        # 2. OLL 45 only
        {
            "name": "oll_45",
            "algorithms": [("OLL", "OLL 45", OLL_CASES["OLL 45"])],
            "oll_case": "OLL 45",
            "pll_case": "Solved",
        },
        # 3. OLL 27 (Sune) only
        {
            "name": "oll_27",
            "algorithms": [("OLL", "OLL 27", OLL_CASES["OLL 27"])],
            "oll_case": "OLL 27",
            "pll_case": "Solved",
        },
        # 4. T-Perm only
        {
            "name": "t_perm",
            "algorithms": [("PLL", "T-Perm", PLL_CASES["T-Perm"])],
            "oll_case": "OLL Skip",
            "pll_case": "T-Perm",
        },
        # 5. OLL 27 + T-Perm
        {
            "name": "oll27_tperm",
            "algorithms": [
                ("OLL", "OLL 27", OLL_CASES["OLL 27"]),
                ("PLL", "T-Perm", PLL_CASES["T-Perm"]),
            ],
            "oll_case": "OLL 27",
            "pll_case": "T-Perm",
        },
        # 6. H-Perm only
        {
            "name": "h_perm",
            "algorithms": [("PLL", "H-Perm", PLL_CASES["H-Perm"])],
            "oll_case": "OLL Skip",
            "pll_case": "H-Perm",
        },
        # 7. OLL 33 + J-Perm(b)
        {
            "name": "oll33_jperm_b",
            "algorithms": [
                ("OLL", "OLL 33", OLL_CASES["OLL 33"]),
                ("PLL", "J-Perm (b)", PLL_CASES["J-Perm (b)"]),
            ],
            "oll_case": "OLL 33",
            "pll_case": "J-Perm (b)",
        },
    ]

    for render_config in renders:
        print(f"\n{'='*60}")
        print(f"Rendering: {render_config['name']}")
        print(f"{'='*60}")

        # Build cube state
        cube = Cube()
        for alg_type, alg_name, alg_str in render_config.get("algorithms", []):
            print(f"  Applying {alg_name}: {alg_str}")
            cube.apply_algorithm(alg_str)

        # Render
        render_cube_state(
            cube,
            render_config["name"],
            {
                "oll_case": render_config["oll_case"],
                "pll_case": render_config["pll_case"],
            }
        )

    print(f"\n{'='*60}")
    print(f"All renders complete! Output: {OUTPUT_DIR}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()

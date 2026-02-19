"""
Blender script to generate stickered F2L-incomplete training data.

Same architecture as render_training_data.py but generates F2L-incomplete states
using f2l_scrambler.py.

Run with:
    /opt/homebrew/bin/blender --background --python ml/blender/render_f2l_stickered.py -- [OPTIONS]

Options:
    --count N         Number of renders (default: 2000)
    --seed N          Random seed (default: 99)
    --resolution N    Image resolution in pixels (default: 480)
    --samples N       Cycles render samples (default: 64)
    --output-dir PATH Output directory override
"""

import bpy
import math
import json
import os
import sys
import time
import random

# --- Reuse shared functions from render_known_states.py via exec() ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)
sys.path.insert(0, SCRIPT_DIR)

render_globals = {
    "__name__": "render_known_states",
    "__builtins__": __builtins__,
    "__file__": os.path.join(SCRIPT_DIR, "render_known_states.py"),
}
exec(open(os.path.join(SCRIPT_DIR, "render_known_states.py")).read(), render_globals)

clear_scene = render_globals['clear_scene']
create_cube_with_state = render_globals['create_cube_with_state']

from state_resolver import Cube
from f2l_scrambler import build_random_f2l_state

DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "f2l_stickered_renders")

# ---------------------------------------------------------------------------
# Cube geometry for rejection sampling (same as render_training_data.py)
# ---------------------------------------------------------------------------
CUBE_HALF = 1.5


def get_cube_corners():
    h = CUBE_HALF
    return [
        (h, h, h), (-h, h, h), (-h, -h, h), (h, -h, h),
        (h, h, -h), (-h, h, -h), (-h, -h, -h), (h, -h, -h),
    ]


def _vec_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _vec_cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _vec_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _vec_norm(a):
    length = math.sqrt(_vec_dot(a, a))
    if length < 1e-12:
        return (0, 0, 0)
    return (a[0] / length, a[1] / length, a[2] / length)


def check_all_corners_in_frame(cam_pos, look_at, focal_mm, img_size, margin=30):
    forward = _vec_norm(_vec_sub(look_at, cam_pos))
    if _vec_dot(forward, forward) < 0.5:
        return False

    world_up = (0, 0, 1)
    right = _vec_norm(_vec_cross(forward, world_up))
    if _vec_dot(right, right) < 0.5:
        return False
    up = _vec_cross(right, forward)

    sensor_width_mm = 36.0
    f_px = (focal_mm / sensor_width_mm) * img_size

    for corner in get_cube_corners():
        d = _vec_sub(corner, cam_pos)
        cam_x = _vec_dot(d, right)
        cam_y = _vec_dot(d, up)
        cam_z = _vec_dot(d, forward)

        if cam_z <= 0:
            return False

        px = (cam_x / cam_z) * f_px + img_size / 2
        py = -(cam_y / cam_z) * f_px + img_size / 2

        if px < -margin or px > img_size + margin:
            return False
        if py < -margin or py > img_size + margin:
            return False

    return True


# ---------------------------------------------------------------------------
# Lighting presets (same as render_training_data.py)
# ---------------------------------------------------------------------------

def _setup_world(bg_gray, strength, color=None):
    world = bpy.data.worlds.get("World")
    if world is None:
        world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        if color:
            bg.inputs['Color'].default_value = (*color, 1.0)
        else:
            bg.inputs['Color'].default_value = (bg_gray, bg_gray, bg_gray, 1.0)
        bg.inputs['Strength'].default_value = strength


def setup_lighting_standard(bg_gray):
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 10))
    sun = bpy.context.active_object
    sun.name = "KeyLight"
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(45), 0, math.radians(45))

    bpy.ops.object.light_add(type='SUN', location=(-5, 5, 5))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.5
    fill.rotation_euler = (math.radians(60), 0, math.radians(-135))

    _setup_world(bg_gray, 0.5)


def setup_lighting_warm_studio(bg_gray):
    bpy.ops.object.light_add(type='AREA', location=(3, -3, 5))
    key = bpy.context.active_object
    key.name = "KeyArea"
    key.data.energy = 150
    key.data.size = 3.0
    key.data.color = (1.0, 0.9, 0.7)
    key.rotation_euler = (math.radians(50), 0, math.radians(30))

    bpy.ops.object.light_add(type='AREA', location=(-3, 3, 3))
    fill = bpy.context.active_object
    fill.name = "FillArea"
    fill.data.energy = 80
    fill.data.size = 2.0
    fill.data.color = (1.0, 0.85, 0.65)
    fill.rotation_euler = (math.radians(60), 0, math.radians(-120))

    _setup_world(bg_gray, 0.3, color=(1.0, 0.9, 0.75))


def setup_lighting_cool_daylight(bg_gray):
    bpy.ops.object.light_add(type='SUN', location=(4, -6, 8))
    key = bpy.context.active_object
    key.name = "KeySun"
    key.data.energy = 4.0
    key.data.color = (0.85, 0.9, 1.0)
    key.rotation_euler = (math.radians(40), 0, math.radians(35))

    bpy.ops.object.light_add(type='SUN', location=(-3, 4, 3))
    fill = bpy.context.active_object
    fill.name = "FillSun"
    fill.data.energy = 1.0
    fill.data.color = (1.0, 0.95, 0.85)
    fill.rotation_euler = (math.radians(70), 0, math.radians(-140))

    _setup_world(bg_gray, 0.4, color=(0.9, 0.95, 1.0))


def setup_lighting_high_contrast(bg_gray):
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 8))
    sun = bpy.context.active_object
    sun.name = "HardSun"
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(35), 0, math.radians(40))

    _setup_world(bg_gray, 0.15)


def setup_lighting_soft_diffuse(bg_gray):
    _setup_world(bg_gray, 2.0)


LIGHTING_PRESETS = {
    'standard': setup_lighting_standard,
    'warm_studio': setup_lighting_warm_studio,
    'cool_daylight': setup_lighting_cool_daylight,
    'high_contrast': setup_lighting_high_contrast,
    'soft_diffuse': setup_lighting_soft_diffuse,
}


# ---------------------------------------------------------------------------
# Randomized camera (stickered convention: negative azimuth)
# ---------------------------------------------------------------------------

def setup_randomized_camera(rng, img_size):
    max_attempts = 100

    for attempt in range(max_attempts):
        distance = rng.uniform(3.0, 10.0)
        azimuth = rng.uniform(math.radians(-75), math.radians(-15))
        elevation = rng.uniform(math.radians(15), math.radians(65))
        focal_mm = rng.uniform(24, 70)

        look_x = rng.uniform(-1.5, 1.5)
        look_y = rng.uniform(-0.5, 0.5)
        look_z = rng.uniform(-1.0, 1.0)

        cam_x = distance * math.cos(elevation) * math.cos(azimuth)
        cam_y = distance * math.cos(elevation) * math.sin(azimuth)
        cam_z = distance * math.sin(elevation)

        cam_pos = (cam_x, cam_y, cam_z)
        look_at = (look_x, look_y, look_z)

        if not check_all_corners_in_frame(cam_pos, look_at, focal_mm, img_size):
            continue

        bpy.ops.object.camera_add(location=cam_pos)
        camera = bpy.context.active_object
        camera.name = "Camera"
        camera.data.type = 'PERSP'
        camera.data.lens = focal_mm
        bpy.context.scene.camera = camera

        bpy.ops.object.empty_add(type='PLAIN_AXES', location=look_at)
        target = bpy.context.active_object
        target.name = "CameraTarget"

        constraint = camera.constraints.new(type='TRACK_TO')
        constraint.target = target
        constraint.track_axis = 'TRACK_NEGATIVE_Z'
        constraint.up_axis = 'UP_Y'

        return {
            'distance': round(distance, 4),
            'azimuth_rad': round(azimuth, 4),
            'elevation_deg': round(math.degrees(elevation), 2),
            'focal_length_mm': round(focal_mm, 2),
            'look_at_offset': [round(look_x, 4), round(look_y, 4), round(look_z, 4)],
            'position': [round(cam_x, 4), round(cam_y, 4), round(cam_z, 4)],
            'attempts': attempt + 1,
        }

    return None


# ---------------------------------------------------------------------------
# Render settings
# ---------------------------------------------------------------------------

def configure_render(resolution, samples):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.image_settings.file_format = 'PNG'


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    argv = sys.argv
    if '--' in argv:
        argv = argv[argv.index('--') + 1:]
    else:
        argv = []

    import argparse
    parser = argparse.ArgumentParser(description="Generate stickered F2L training renders")
    parser.add_argument('--count', type=int, default=2000,
                        help='Number of renders (default: 2000)')
    parser.add_argument('--seed', type=int, default=99)
    parser.add_argument('--resolution', type=int, default=480)
    parser.add_argument('--samples', type=int, default=64)
    parser.add_argument('--output-dir', type=str, default=None)
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = parse_args()
    rng = random.Random(args.seed)

    output_dir = args.output_dir or DEFAULT_OUTPUT_DIR
    os.makedirs(output_dir, exist_ok=True)

    print(f"Stickered F2L training: {args.count} renders "
          f"(seed={args.seed}, res={args.resolution}, samples={args.samples})")

    lighting_names = list(LIGHTING_PRESETS.keys())
    start_time = time.time()
    total_attempts = 0
    skipped = 0
    results = []

    for i in range(args.count):
        # Generate F2L-incomplete state
        cube, meta = build_random_f2l_state(rng, apply_ll=True)
        meta['cube_type'] = 'stickered'

        n_unsolved = 4 - meta['f2l_pairs_solved']
        print(f"\n[{i + 1}/{args.count}] F2L({n_unsolved}p) {meta['oll_case']}")

        # Clear scene and create stickered cube
        clear_scene()
        create_cube_with_state(cube)

        # Randomized camera
        cam_params = setup_randomized_camera(rng, args.resolution)
        if cam_params is None:
            print("  SKIP: no valid camera config")
            skipped += 1
            continue

        total_attempts += cam_params['attempts']

        # Randomized lighting
        preset_name = rng.choice(lighting_names)
        bg_gray = rng.uniform(0.1, 0.5)
        LIGHTING_PRESETS[preset_name](bg_gray)

        # Render settings
        configure_render(args.resolution, args.samples)

        # File naming
        safe_oll = meta['oll_case'].lower().replace(' ', '_')
        filename = f"{i:04d}_f2l_{n_unsolved}p_{safe_oll}"

        # Render
        image_path = os.path.join(output_dir, f"{filename}.png")
        bpy.context.scene.render.filepath = image_path
        bpy.ops.render.render(write_still=True)

        # Save label
        label = {
            "image": f"{filename}.png",
            "cube_type": "stickered",
            "solve_phase": "f2l",
            "f2l_pairs_solved": meta['f2l_pairs_solved'],
            "f2l_unsolved_slots": meta['f2l_unsolved_slots'],
            "f2l_scramble_details": meta['f2l_scramble_details'],
            "oll_case": meta['oll_case'],
            "pll_case": meta['pll_case'],
            "full_state": {k: list(v) for k, v in cube.faces.items()},
            "camera": cam_params,
            "lighting_preset": preset_name,
        }

        label_path = os.path.join(output_dir, f"{filename}.json")
        with open(label_path, 'w') as f:
            json.dump(label, f, indent=2)

        results.append({
            "image": f"{filename}.png",
            "f2l_pairs_solved": meta['f2l_pairs_solved'],
            "oll_case": meta['oll_case'],
            "lighting_preset": preset_name,
        })

        print(f"  Rendered: {filename}.png ({preset_name}, tries={cam_params['attempts']})")

    # Manifest
    elapsed = time.time() - start_time
    avg_attempts = total_attempts / len(results) if results else 0

    pair_dist = {}
    for r in results:
        p = r['f2l_pairs_solved']
        pair_dist[p] = pair_dist.get(p, 0) + 1

    manifest = {
        "total_renders": len(results),
        "skipped": skipped,
        "seed": args.seed,
        "resolution": args.resolution,
        "samples": args.samples,
        "cube_type": "stickered",
        "solve_phase": "f2l",
        "elapsed_seconds": round(elapsed, 1),
        "pair_distribution": pair_dist,
        "avg_camera_attempts": round(avg_attempts, 1),
        "lighting_distribution": {
            name: sum(1 for r in results if r['lighting_preset'] == name)
            for name in lighting_names
        },
    }

    manifest_path = os.path.join(output_dir, "manifest.json")
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"\n{'=' * 60}")
    print(f"F2L stickered generation complete!")
    print(f"  Renders:  {len(results)}/{args.count}")
    print(f"  Skipped:  {skipped}")
    print(f"  Pairs:    {pair_dist}")
    if results:
        print(f"  Time:     {elapsed:.1f}s ({elapsed / len(results):.1f}s per render)")
    print(f"  Output:   {output_dir}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()

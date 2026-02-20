"""
Blender script to generate stickerless cube training data with randomized camera/lighting.

Supports both LL-only (OLL×PLL) and F2L-incomplete states.

Run with:
    /opt/homebrew/bin/blender --background --python ml/blender/render_stickerless_training.py -- [OPTIONS]

Options:
    --mode {ll,f2l,mixed}  Render mode (default: mixed)
    --count N              Number of renders (0 = all combos for ll mode, default: 0)
    --seed N               Random seed (default: 77)
    --resolution N         Image resolution in pixels (default: 480)
    --samples N            Cycles render samples (default: 96)
    --output-dir PATH      Output directory override
    --hdri-dir PATH        Directory of .exr/.hdr files for HDRI backgrounds
"""

import bpy
import math
import json
import os
import sys
import time
import random

# ---------------------------------------------------------------------------
# Path setup
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPERIMENT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CUBE_SOLVE_DIR = os.path.join(EXPERIMENT_DIR, "cube-photo-solve")
sys.path.insert(0, CUBE_SOLVE_DIR)
sys.path.insert(0, SCRIPT_DIR)

from cube_design_config import random_config

# Import stickerless renderer via exec() (same pattern as render_training_data.py)
stickerless_globals = {
    "__name__": "render_stickerless",
    "__builtins__": __builtins__,
    "__file__": os.path.join(SCRIPT_DIR, "render_stickerless.py"),
}
exec(open(os.path.join(SCRIPT_DIR, "render_stickerless.py")).read(), stickerless_globals)

build_stickerless_cube = stickerless_globals['build_stickerless_cube']
clear_scene = stickerless_globals['clear_scene']

# Load HDRI environment utility
hdri_globals = {
    "__name__": "hdri_env",
    "__builtins__": __builtins__,
    "__file__": os.path.join(SCRIPT_DIR, "hdri_env.py"),
}
exec(open(os.path.join(SCRIPT_DIR, "hdri_env.py")).read(), hdri_globals)
setup_hdri_world = hdri_globals['setup_hdri_world']
get_hdri_files = hdri_globals['get_hdri_files']
adjust_scene_lights = hdri_globals['adjust_scene_lights']
cleanup_hdri_images = hdri_globals['cleanup_hdri_images']

from state_resolver import Cube
from algorithms import OLL_CASES, PLL_CASES
from f2l_scrambler import build_random_f2l_state

DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "stickerless_renders")

# ---------------------------------------------------------------------------
# Cube geometry for rejection sampling (stickerless cube is smaller)
# ---------------------------------------------------------------------------
CUBE_HALF = 0.92  # Stickerless cube outer extent


def get_cube_corners(cube_half=0.92):
    """Get 8 cube corners in world coordinates."""
    h = cube_half
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


def check_all_corners_in_frame(cam_pos, look_at, focal_mm, img_size, margin=30, cube_half=0.92):
    """Check if all 8 cube corners project within the image frame."""
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

    for corner in get_cube_corners(cube_half):
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
# Lighting presets (reused from render_training_data.py)
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
# Randomized camera (stickerless convention: positive azimuth, negated Y)
# ---------------------------------------------------------------------------

def setup_randomized_camera(rng, img_size, cube_half=0.92):
    """Create a randomized camera for stickerless cube viewing U/F/R faces."""
    max_attempts = 100

    for attempt in range(max_attempts):
        # Scaled ranges for smaller stickerless cube
        distance = rng.uniform(2.0, 6.5)
        # Positive azimuth convention (stickerless camera)
        azimuth = rng.uniform(math.radians(15), math.radians(75))
        elevation = rng.uniform(math.radians(15), math.radians(65))
        focal_mm = rng.uniform(24, 70)

        # Scaled look-at offsets (0.92/1.5 ≈ 0.61 ratio)
        look_x = rng.uniform(-0.9, 0.9)
        look_y = rng.uniform(-0.3, 0.3)
        look_z = rng.uniform(-0.6, 0.6)

        cam_x = distance * math.cos(elevation) * math.cos(azimuth)
        cam_y = -distance * math.cos(elevation) * math.sin(azimuth)
        cam_z = distance * math.sin(elevation)

        cam_pos = (cam_x, cam_y, cam_z)
        look_at = (look_x, look_y, look_z)

        if not check_all_corners_in_frame(cam_pos, look_at, focal_mm, img_size, cube_half=cube_half):
            continue

        # Valid config — create Blender camera
        bpy.ops.object.camera_add(location=cam_pos)
        camera = bpy.context.active_object
        camera.name = "Camera"
        camera.data.type = 'PERSP'
        camera.data.lens = focal_mm
        camera.data.clip_end = 100
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
# OLL x PLL combinations
# ---------------------------------------------------------------------------

def build_oll_pll_combos():
    """Build full cartesian product of 58 OLL × 21 PLL states."""
    oll_names = ["OLL Skip"]
    for key in OLL_CASES:
        if key.startswith("OLL "):
            oll_names.append(key)

    pll_names = list(PLL_CASES.keys())

    combos = []
    for oll in oll_names:
        for pll in pll_names:
            combos.append((oll, pll))
    return combos


# ---------------------------------------------------------------------------
# Render settings
# ---------------------------------------------------------------------------

def configure_render(resolution, samples):
    """Configure Cycles render settings for stickerless cube."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'

    # Use GPU if available (Metal on macOS)
    prefs = bpy.context.preferences.addons.get('cycles')
    if prefs:
        prefs.preferences.compute_device_type = 'METAL'
        for device in prefs.preferences.devices:
            device.use = True
        scene.cycles.device = 'GPU'

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
    parser = argparse.ArgumentParser(description="Generate stickerless training renders")
    parser.add_argument('--mode', choices=['ll', 'f2l', 'mixed'], default='mixed',
                        help='Render mode: ll=OLL×PLL, f2l=F2L states, mixed=both')
    parser.add_argument('--count', type=int, default=0,
                        help='Number of renders (0=all combos for ll mode, default: 0)')
    parser.add_argument('--seed', type=int, default=77)
    parser.add_argument('--resolution', type=int, default=480)
    parser.add_argument('--samples', type=int, default=96)
    parser.add_argument('--output-dir', type=str, default=None)
    parser.add_argument('--hdri-dir', type=str, default=None,
                        help='Directory of .exr/.hdr files for HDRI backgrounds')
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = parse_args()
    rng = random.Random(args.seed)

    output_dir = args.output_dir or DEFAULT_OUTPUT_DIR
    os.makedirs(output_dir, exist_ok=True)

    hdri_files = None
    if args.hdri_dir:
        hdri_files = get_hdri_files(args.hdri_dir)
        if not hdri_files:
            print(f"ERROR: No .exr/.hdr files found in {args.hdri_dir}")
            sys.exit(1)
        print(f"HDRI mode: {len(hdri_files)} environment maps from {args.hdri_dir}")

    # Build render list based on mode
    render_list = []  # list of (cube, metadata) tuples to render

    if args.mode in ('ll', 'mixed'):
        combos = build_oll_pll_combos()
        if args.mode == 'mixed':
            # 60% LL
            n_ll = int((args.count or len(combos)) * 0.6) if args.count else len(combos)
            ll_combos = rng.sample(combos, min(n_ll, len(combos)))
        elif args.count > 0:
            ll_combos = rng.sample(combos, min(args.count, len(combos)))
        else:
            ll_combos = list(combos)
            rng.shuffle(ll_combos)

        for oll_name, pll_name in ll_combos:
            cube = Cube()
            if oll_name != "OLL Skip" and OLL_CASES.get(oll_name):
                cube.apply_algorithm(OLL_CASES[oll_name])
            if pll_name != "Solved" and PLL_CASES.get(pll_name):
                cube.apply_algorithm(PLL_CASES[pll_name])

            meta = {
                'cube_type': 'stickerless',
                'solve_phase': 'll',
                'oll_case': oll_name,
                'pll_case': pll_name,
            }
            render_list.append((cube, meta))

    if args.mode in ('f2l', 'mixed'):
        if args.mode == 'mixed':
            n_f2l = int((args.count or 800) * 0.4) if args.count else 800
        elif args.count > 0:
            n_f2l = args.count
        else:
            n_f2l = 1000

        for _ in range(n_f2l):
            cube, meta = build_random_f2l_state(rng, apply_ll=True)
            meta['cube_type'] = 'stickerless'
            render_list.append((cube, meta))

    print(f"Stickerless training: {len(render_list)} renders "
          f"(mode={args.mode}, seed={args.seed}, res={args.resolution}, "
          f"samples={args.samples})")

    lighting_names = list(LIGHTING_PRESETS.keys())
    start_time = time.time()
    total_attempts = 0
    skipped = 0
    results = []

    for i, (cube, meta) in enumerate(render_list):
        phase = meta.get('solve_phase', 'll')
        case_desc = meta.get('oll_case', '') + ' + ' + meta.get('pll_case', '')
        if phase == 'f2l':
            n_unsolved = 4 - meta.get('f2l_pairs_solved', 4)
            case_desc = f"F2L({n_unsolved}p) {meta.get('oll_case', '')}"

        print(f"\n[{i + 1}/{len(render_list)}] {case_desc}")

        # Reset material cache and clear scene
        stickerless_globals['_material_cache'] = {}
        clear_scene()
        cleanup_hdri_images()

        # Randomize cube design per render
        design_config = random_config(rng, style='stickerless')
        stickerless_globals['CUBE_DESIGN_CONFIG'] = design_config

        # Compute cube extents for rejection sampling
        spacing = design_config.cubie_size + design_config.gap
        cube_half = (spacing + design_config.cubie_size / 2.0) * design_config.overall_scale

        # Build stickerless geometry
        cubies, mechanism = build_stickerless_cube(cube)

        # Randomized camera
        cam_params = setup_randomized_camera(rng, args.resolution, cube_half=cube_half)
        if cam_params is None:
            print("  SKIP: no valid camera config")
            skipped += 1
            continue

        total_attempts += cam_params['attempts']

        # Randomized lighting
        preset_name = rng.choice(lighting_names)
        bg_gray = rng.uniform(0.1, 0.5)
        LIGHTING_PRESETS[preset_name](bg_gray)

        # HDRI background override (replaces gray world, keeps directional lights)
        hdri_params = None
        if hdri_files:
            hdri_path = rng.choice(hdri_files)
            hdri_params = setup_hdri_world(hdri_path, rng)
            hdri_params['light_mode'] = adjust_scene_lights(rng)

        # Render settings
        configure_render(args.resolution, args.samples)

        # File naming
        if phase == 'll':
            safe_oll = meta['oll_case'].lower().replace(' ', '_')
            safe_pll = (meta['pll_case'].lower()
                        .replace(' ', '_').replace('(', '').replace(')', ''))
            filename = f"{i:04d}_{safe_oll}_{safe_pll}"
        else:
            n_unsolved = 4 - meta.get('f2l_pairs_solved', 4)
            filename = f"{i:04d}_f2l_{n_unsolved}p_{meta.get('oll_case', 'skip').lower().replace(' ', '_')}"

        # Render
        image_path = os.path.join(output_dir, f"{filename}.png")
        bpy.context.scene.render.filepath = image_path
        bpy.ops.render.render(write_still=True)

        # Save label
        label = {
            "image": f"{filename}.png",
            "cube_type": "stickerless",
            "solve_phase": meta.get('solve_phase', 'll'),
            "oll_case": meta.get('oll_case', 'OLL Skip'),
            "pll_case": meta.get('pll_case', 'Solved'),
            "full_state": {k: list(v) for k, v in cube.faces.items()},
            "camera": cam_params,
            "lighting_preset": preset_name,
            "cube_design": design_config.to_dict(),
        }
        if hdri_params:
            label['hdri'] = hdri_params

        # Add F2L-specific metadata
        if phase == 'f2l':
            label['f2l_pairs_solved'] = meta['f2l_pairs_solved']
            label['f2l_unsolved_slots'] = meta['f2l_unsolved_slots']
            if 'f2l_scramble_details' in meta:
                label['f2l_scramble_details'] = meta['f2l_scramble_details']

        label_path = os.path.join(output_dir, f"{filename}.json")
        with open(label_path, 'w') as f:
            json.dump(label, f, indent=2)

        results.append({
            "image": f"{filename}.png",
            "solve_phase": phase,
            "oll_case": meta.get('oll_case', ''),
            "lighting_preset": preset_name,
            "camera_distance": cam_params['distance'],
        })

        print(f"  Rendered: {filename}.png ({preset_name}, tries={cam_params['attempts']})")

    # Manifest
    elapsed = time.time() - start_time
    avg_attempts = total_attempts / len(results) if results else 0

    ll_count = sum(1 for r in results if r['solve_phase'] == 'll')
    f2l_count = sum(1 for r in results if r['solve_phase'] == 'f2l')

    manifest = {
        "total_renders": len(results),
        "skipped": skipped,
        "seed": args.seed,
        "mode": args.mode,
        "resolution": args.resolution,
        "samples": args.samples,
        "cube_type": "stickerless",
        "elapsed_seconds": round(elapsed, 1),
        "ll_renders": ll_count,
        "f2l_renders": f2l_count,
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
    print(f"Stickerless generation complete!")
    print(f"  Total:     {len(results)} ({ll_count} LL + {f2l_count} F2L)")
    print(f"  Skipped:   {skipped}")
    if results:
        print(f"  Time:      {elapsed:.1f}s ({elapsed / len(results):.1f}s per render)")
    print(f"  Output:    {output_dir}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()

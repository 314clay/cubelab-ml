"""
Blender script to generate randomized training data for the CV pipeline.
Run with:
    /opt/homebrew/bin/blender --background --python ml/blender/render_training_data.py -- [OPTIONS]

Generates renders with varied camera positions, lighting, and OLL/PLL states.
Each render produces a PNG image + JSON label with ground truth and camera metadata.

Options:
    --count N         Number of renders (0 = all 1218 combos, default: 0)
    --seed N          Random seed (default: 42)
    --resolution N    Image resolution in pixels (default: 480)
    --samples N       Cycles render samples (default: 64)
    --hdri-dir PATH   Directory of .exr/.hdr files for HDRI backgrounds
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

render_globals = {
    "__name__": "render_known_states",
    "__builtins__": __builtins__,
    "__file__": os.path.join(SCRIPT_DIR, "render_known_states.py"),
}
exec(open(os.path.join(SCRIPT_DIR, "render_known_states.py")).read(), render_globals)

clear_scene = render_globals['clear_scene']
create_cube_with_state = render_globals['create_cube_with_state']

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

DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "data", "training_renders")

# ---------------------------------------------------------------------------
# Cube geometry for rejection sampling
# ---------------------------------------------------------------------------
CUBE_HALF = 1.5  # Cube body is size=3.0, corners at +/-1.5


def get_cube_corners():
    """Get 8 cube corners in world coordinates."""
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
    """
    Check if all 8 cube corners project within the image frame.
    Uses a pinhole camera model ported from the exploration notebook.
    """
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
# Lighting presets
# ---------------------------------------------------------------------------

def _setup_world(bg_gray, strength, color=None):
    """Configure world background node."""
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
    """Dual sun (3.0 + 1.5) + ambient.  Current baseline from render_known_states."""
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
    """Warm area lights with orange-tinted ambient.  Simulates indoor table lighting."""
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
    """Blueish key sun + warm fill.  Simulates window/daylight."""
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
    """Single hard sun (5.0), no fill, dark ambient.  Strong directional shadows."""
    bpy.ops.object.light_add(type='SUN', location=(5, -5, 8))
    sun = bpy.context.active_object
    sun.name = "HardSun"
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(35), 0, math.radians(40))

    _setup_world(bg_gray, 0.15)


def setup_lighting_soft_diffuse(bg_gray):
    """World-only lighting (strength 2.0), no directional lights.  Overcast sky."""
    _setup_world(bg_gray, 2.0)


LIGHTING_PRESETS = {
    'standard': setup_lighting_standard,
    'warm_studio': setup_lighting_warm_studio,
    'cool_daylight': setup_lighting_cool_daylight,
    'high_contrast': setup_lighting_high_contrast,
    'soft_diffuse': setup_lighting_soft_diffuse,
}

# ---------------------------------------------------------------------------
# Randomized camera with TRACK_TO constraint
# ---------------------------------------------------------------------------

def setup_randomized_camera(rng, img_size):
    """
    Create a camera with randomized spherical position aimed via TRACK_TO
    constraint at a randomly offset look-at point.

    Uses rejection sampling (max 100 attempts) to ensure all 8 cube corners
    project inside the image frame.

    Returns camera parameter dict, or None on failure.
    """
    max_attempts = 100

    for attempt in range(max_attempts):
        distance = rng.uniform(3.0, 10.0)
        # Constrain azimuth so U, F, R faces are all visible.
        # Standard view is at azimuth=-45 deg. F face visible when Y<0
        # (sin(az)<0), R face visible when X>0 (cos(az)>0).
        # Range: -75 to -15 deg gives good visibility of all 3 faces.
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

        # Valid config found — create Blender objects
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
# OLL x PLL combinations
# ---------------------------------------------------------------------------

def build_oll_pll_combos():
    """
    Build the full cartesian product of 58 OLL states x 21 PLL states.
    Excludes alias entries (Sune, Anti-Sune) to avoid duplicates.
    """
    oll_names = ["OLL Skip"]
    for key in OLL_CASES:
        if key.startswith("OLL "):
            oll_names.append(key)
    # oll_names: OLL Skip + OLL 1..57 = 58

    pll_names = list(PLL_CASES.keys())
    # pll_names: 21 entries including "Solved"

    combos = []
    for oll in oll_names:
        for pll in pll_names:
            combos.append((oll, pll))

    return combos


# ---------------------------------------------------------------------------
# Render settings
# ---------------------------------------------------------------------------

def configure_render(resolution, samples):
    """Configure Cycles render settings."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.image_settings.file_format = 'PNG'


# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------

def parse_args():
    """Parse arguments after Blender's '--' separator."""
    argv = sys.argv
    if '--' in argv:
        argv = argv[argv.index('--') + 1:]
    else:
        argv = []

    import argparse
    parser = argparse.ArgumentParser(description="Generate randomized training renders")
    parser.add_argument('--count', type=int, default=0,
                        help='Number of renders (0 = all 1218 combos)')
    parser.add_argument('--seed', type=int, default=42,
                        help='Random seed for reproducibility')
    parser.add_argument('--resolution', type=int, default=480,
                        help='Image resolution in pixels (square)')
    parser.add_argument('--samples', type=int, default=64,
                        help='Cycles render samples')
    parser.add_argument('--hdri-dir', type=str, default=None,
                        help='Directory of .exr/.hdr files for HDRI backgrounds')
    parser.add_argument('--output-dir', type=str, default=None,
                        help='Output directory override')
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Main generation loop
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

    all_combos = build_oll_pll_combos()
    print(f"Total OLL x PLL combinations: {len(all_combos)}")

    if args.count > 0:
        combos = rng.sample(all_combos, min(args.count, len(all_combos)))
    else:
        combos = list(all_combos)
        rng.shuffle(combos)

    print(f"Rendering {len(combos)} images "
          f"(seed={args.seed}, res={args.resolution}, samples={args.samples})")

    lighting_names = list(LIGHTING_PRESETS.keys())
    start_time = time.time()
    total_attempts = 0
    skipped = 0
    results = []

    for i, (oll_name, pll_name) in enumerate(combos):
        print(f"\n[{i + 1}/{len(combos)}] {oll_name} + {pll_name}")

        # Build cube state
        cube = Cube()
        if oll_name != "OLL Skip":
            cube.apply_algorithm(OLL_CASES[oll_name])
        if pll_name != "Solved":
            cube.apply_algorithm(PLL_CASES[pll_name])

        # Clear scene and create cube geometry
        clear_scene()
        cleanup_hdri_images()
        create_cube_with_state(cube)

        # Randomized camera (with rejection sampling)
        cam_params = setup_randomized_camera(rng, args.resolution)
        if cam_params is None:
            print("  SKIP: no valid camera config found in 100 attempts")
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
        safe_oll = oll_name.lower().replace(' ', '_')
        safe_pll = (pll_name.lower()
                    .replace(' ', '_')
                    .replace('(', '')
                    .replace(')', ''))
        filename = f"{i:04d}_{safe_oll}_{safe_pll}"

        # Render image
        image_path = os.path.join(output_dir, f"{filename}.png")
        bpy.context.scene.render.filepath = image_path
        bpy.ops.render.render(write_still=True)

        # Save JSON label
        visible = cube.get_visible_stickers()
        label = {
            "image": f"{filename}.png",
            "oll_case": oll_name,
            "pll_case": pll_name,
            "visible_stickers": visible,
            "top_face": list(cube.faces['U']),
            "front_top_row": list(cube.faces['F'][0:3]),
            "right_top_row": list(cube.faces['R'][0:3]),
            "full_state": {k: list(v) for k, v in cube.faces.items()},
            "camera": cam_params,
            "lighting_preset": preset_name,
        }
        if hdri_params:
            label['hdri'] = hdri_params

        label_path = os.path.join(output_dir, f"{filename}.json")
        with open(label_path, 'w') as f:
            json.dump(label, f, indent=2)

        results.append({
            "image": f"{filename}.png",
            "oll_case": oll_name,
            "pll_case": pll_name,
            "lighting_preset": preset_name,
            "camera_distance": cam_params['distance'],
            "camera_elevation": cam_params['elevation_deg'],
            "camera_focal": cam_params['focal_length_mm'],
        })

        print(f"  Rendered: {filename}.png "
              f"({preset_name}, d={cam_params['distance']:.1f}, "
              f"el={cam_params['elevation_deg']:.0f} deg, "
              f"f={cam_params['focal_length_mm']:.0f}mm, "
              f"tries={cam_params['attempts']})")

    # -----------------------------------------------------------------------
    # Write manifest.json
    # -----------------------------------------------------------------------
    elapsed = time.time() - start_time
    avg_attempts = total_attempts / len(results) if results else 0
    rejection_rate = 1.0 - (1.0 / avg_attempts) if avg_attempts > 1 else 0.0

    manifest = {
        "total_renders": len(results),
        "total_combos": len(all_combos),
        "skipped": skipped,
        "seed": args.seed,
        "resolution": args.resolution,
        "samples": args.samples,
        "elapsed_seconds": round(elapsed, 1),
        "avg_seconds_per_render": round(elapsed / len(results), 1) if results else 0,
        "rejection_rate": round(rejection_rate, 3),
        "avg_camera_attempts": round(avg_attempts, 1),
        "oll_coverage": len(set(r['oll_case'] for r in results)),
        "pll_coverage": len(set(r['pll_case'] for r in results)),
        "lighting_distribution": {
            name: sum(1 for r in results if r['lighting_preset'] == name)
            for name in lighting_names
        },
        "parameter_ranges": {
            "distance": {"min": 3.0, "max": 10.0},
            "elevation_deg": {"min": 10, "max": 75},
            "focal_length_mm": {"min": 24, "max": 70},
            "look_at_offset_x": {"min": -1.5, "max": 1.5},
            "look_at_offset_y": {"min": -0.5, "max": 0.5},
            "look_at_offset_z": {"min": -1.0, "max": 1.0},
        },
        "renders": results,
    }

    manifest_path = os.path.join(output_dir, "manifest.json")
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"\n{'=' * 60}")
    print(f"Generation complete!")
    print(f"  Renders:        {len(results)}/{len(combos)}")
    print(f"  Skipped:        {skipped}")
    if results:
        print(f"  Time:           {elapsed:.1f}s ({elapsed / len(results):.1f}s per render)")
    print(f"  Rejection rate: {rejection_rate:.1%}")
    print(f"  OLL coverage:   {len(set(r['oll_case'] for r in results))}")
    print(f"  PLL coverage:   {len(set(r['pll_case'] for r in results))}")
    print(f"  Output:         {output_dir}")
    print(f"  Manifest:       {manifest_path}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()

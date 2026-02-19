"""
HDRI environment map utility for Blender render scripts.

Provides functions to replace monochrome gray world backgrounds with randomized
HDRI environment maps for domain-diverse training data.

Load via exec() (same pattern as render_known_states.py):
    hdri_globals = {"__name__": "hdri_env", "__builtins__": __builtins__,
                    "__file__": os.path.join(SCRIPT_DIR, "hdri_env.py")}
    exec(open(os.path.join(SCRIPT_DIR, "hdri_env.py")).read(), hdri_globals)
    setup_hdri_world = hdri_globals['setup_hdri_world']
"""

import bpy
import os
import math


def get_hdri_files(hdri_dir):
    """List all .exr and .hdr files in the given directory, sorted."""
    extensions = ('.exr', '.hdr')
    files = []
    for f in sorted(os.listdir(hdri_dir)):
        if f.lower().endswith(extensions):
            files.append(os.path.join(hdri_dir, f))
    return files


def setup_hdri_world(hdri_path, rng, strength_range=(0.8, 2.5)):
    """
    Replace the world background with an HDRI environment map.

    Rebuilds the world shader node tree:
        TexCoord → Mapping → Environment Texture → Background → World Output

    Args:
        hdri_path: Absolute path to .exr or .hdr file.
        rng: random.Random instance for randomization.
        strength_range: (min, max) for environment strength.

    Returns:
        dict with HDRI parameters for JSON label logging.
    """
    world = bpy.data.worlds.get("World")
    if world is None:
        world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True

    tree = world.node_tree
    nodes = tree.nodes
    links = tree.links

    # Preserve the World Output node, remove everything else
    output_node = None
    for node in nodes:
        if node.type == 'OUTPUT_WORLD':
            output_node = node

    for node in list(nodes):
        if node != output_node:
            nodes.remove(node)

    if output_node is None:
        output_node = nodes.new('ShaderNodeOutputWorld')

    # Build node chain
    bg_node = nodes.new('ShaderNodeBackground')
    env_tex = nodes.new('ShaderNodeTexEnvironment')
    mapping = nodes.new('ShaderNodeMapping')
    tex_coord = nodes.new('ShaderNodeTexCoord')

    # Load HDRI image (reuses existing if same file already loaded)
    img = bpy.data.images.load(hdri_path, check_existing=True)
    env_tex.image = img

    # Random Z rotation so same HDRI gives different backgrounds
    z_rotation = rng.uniform(0, 2 * math.pi)
    mapping.inputs['Rotation'].default_value = (0, 0, z_rotation)

    # Random strength
    strength = rng.uniform(*strength_range)
    bg_node.inputs['Strength'].default_value = strength

    # Wire nodes
    links.new(tex_coord.outputs['Generated'], mapping.inputs['Vector'])
    links.new(mapping.outputs['Vector'], env_tex.inputs['Vector'])
    links.new(env_tex.outputs['Color'], bg_node.inputs['Color'])
    links.new(bg_node.outputs['Background'], output_node.inputs['Surface'])

    return {
        'hdri_file': os.path.basename(hdri_path),
        'hdri_rotation_rad': round(z_rotation, 4),
        'hdri_strength': round(strength, 2),
    }


def adjust_scene_lights(rng):
    """Adjust or remove directional lights so the HDRI drives illumination.

    The HDRI provides image-based lighting that naturally matches the background.
    Directional lights from presets point in fixed directions that conflict with
    the HDRI's light sources, making the cube look composited.

    Strategy (randomized per render):
      - 60% chance: remove all directional lights (pure HDRI lighting)
      - 40% chance: keep lights but scale to 5-20% (subtle fill/accent)

    Returns:
        str describing the lighting mode for metadata.
    """
    lights = [obj for obj in bpy.data.objects if obj.type == 'LIGHT']
    if not lights:
        return 'hdri_only'

    if rng.random() < 0.6:
        # Pure HDRI — delete all directional lights
        for obj in lights:
            bpy.data.objects.remove(obj, do_unlink=True)
        return 'hdri_only'
    else:
        # HDRI-dominant — keep lights as subtle fill
        factor = rng.uniform(0.05, 0.20)
        for obj in lights:
            obj.data.energy *= factor
        return f'hdri_dominant_{factor:.2f}'


def cleanup_hdri_images():
    """Remove images with zero users to prevent memory leaks between renders."""
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)

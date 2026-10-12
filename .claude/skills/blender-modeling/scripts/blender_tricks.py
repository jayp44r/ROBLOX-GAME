# Blender modelling helpers. Run with blender-mcp's execute_python: paste this file, then call the
# functions at the bottom (or append your own calls). Works in Blender 4.x and 5.x.
#
#   lathe(name, profile)          round objects from a side outline (bottles, cups, vases, pillars, potions)
#   stairs(name, steps, ...)      a staircase in one object
#   cloud_plane(name, ...)        fluffy cloud sheet from a plane + Ocean modifier
#   rainbow(name, radius, ...)    a rainbow arch with a soft colour band
#   handheld_camera(cam, ...)     subtle shaky "filmed by hand" camera motion
#   brick_material(name, ...)     brick path / floor material with noise variation and bump
#   world_sky(...)                simple sky lighting when no HDRI file is available
import math

import bmesh
import bpy


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _replace(name):
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)


def lathe(name, profile, steps=32, subdivide=2, location=(0, 0, 0)):
    """Spin a side outline 360 degrees around the Z axis (the Spin tool trick).

    profile: list of (radius, height) from bottom to top. Start and end with radius 0 to close
    the bottom and top. Example bottle: [(0,0),(0.35,0),(0.38,0.1),(0.36,0.5),(0.38,0.9),
    (0.3,1.15),(0.14,1.3),(0.14,1.42),(0,1.42)]
    """
    _replace(name)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(
        bm,
        geom=verts + edges,
        cent=(0, 0, 0),
        axis=(0, 0, 1),
        angle=2 * math.pi,
        steps=steps,
        use_duplicate=False,
    )
    # The spin leaves a seam of duplicate verts (and points on the axis): merge them.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = _link(bpy.data.objects.new(name, mesh))
    obj.location = location
    if subdivide:
        mod = obj.modifiers.new("Subdivision", "SUBSURF")  # same as Ctrl+2
        mod.levels = mod.render_levels = subdivide
    return obj


def stairs(name, steps=8, width=2.0, depth=0.35, height=0.2, location=(0, 0, 0)):
    """Staircase going up along +Y, as one mesh."""
    _replace(name)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for i in range(steps):
        res = bmesh.ops.create_cube(bm, size=1.0)
        y0, y1 = i * depth, steps * depth
        bmesh.ops.scale(bm, vec=(width, y1 - y0, (i + 1) * height), verts=res["verts"])
        bmesh.ops.translate(bm, vec=(0, (y0 + y1) / 2, (i + 1) * height / 2), verts=res["verts"])
    bm.to_mesh(mesh)
    bm.free()
    obj = _link(bpy.data.objects.new(name, mesh))
    obj.location = location
    bevel = obj.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.01
    bevel.segments = 2
    return obj


def cloud_plane(name="Clouds", size=40.0, height=-3.0, location=(0, 0, 0)):
    """Puffy cloud sea: a subdivided plane with an Ocean modifier, white and soft."""
    _replace(name)
    bpy.ops.mesh.primitive_plane_add(size=size, location=(location[0], location[1], location[2] + height))
    obj = bpy.context.active_object
    obj.name = name
    ocean = obj.modifiers.new("Ocean", "OCEAN")
    ocean.geometry_mode = "DISPLACE"
    ocean.resolution = 10
    ocean.spatial_size = int(size)
    ocean.wave_scale = 3.0
    ocean.choppiness = 0.0  # round puffs, not sharp waves
    ocean.wind_velocity = 20
    smooth = obj.modifiers.new("Smooth", "SMOOTH")
    smooth.iterations = 10
    mat = bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    sub = bsdf.inputs.get("Subsurface Weight") or bsdf.inputs.get("Subsurface")
    if sub:
        sub.default_value = 0.3
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def rainbow(name="Rainbow", radius=12.0, band=1.6, location=(0, 20, 0), strength=2.0, opacity=0.6):
    """Half-ring arch facing -Y with a red-to-violet emission gradient across the band."""
    _replace(name)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    segs = 64
    inner, outer = [], []
    for i in range(segs + 1):
        a = math.pi * i / segs
        inner.append(bm.verts.new(((radius - band) * math.cos(a), 0, (radius - band) * math.sin(a))))
        outer.append(bm.verts.new((radius * math.cos(a), 0, radius * math.sin(a))))
    uv_rows = []
    for i in range(segs):
        f = bm.faces.new((inner[i], inner[i + 1], outer[i + 1], outer[i]))
        uv_rows.append(f)
    uv = bm.loops.layers.uv.new("UVMap")
    for f in uv_rows:
        for loop in f.loops:
            loop[uv].uv = (0.0 if loop.vert in inner else 1.0, 0.0)
    bm.to_mesh(mesh)
    bm.free()
    obj = _link(bpy.data.objects.new(name, mesh))
    obj.location = location

    mat = bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    else:
        mat.blend_method = "BLEND"
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes, nt.links.new
    coord = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    link(coord.outputs["UV"], sep.inputs[0])
    ramp = n.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    colors = [(0.55, 0.2, 1), (0.2, 0.4, 1), (0.2, 1, 0.4), (1, 1, 0.2), (1, 0.55, 0.1), (1, 0.15, 0.15)]
    els[0].color = (*colors[0], 1)
    els[1].position = 1.0
    els[1].color = (*colors[-1], 1)
    for i, c in enumerate(colors[1:-1], start=1):
        e = els.new(i / (len(colors) - 1))
        e.color = (*c, 1)
    link(sep.outputs["X"], ramp.inputs[0])
    # Soft edges: fade out near both sides of the band.
    edge = n.new("ShaderNodeMath")
    edge.operation = "PINGPONG"
    edge.inputs[1].default_value = 0.5
    link(sep.outputs["X"], edge.inputs[0])
    soft = n.new("ShaderNodeMath")
    soft.operation = "MULTIPLY"
    soft.inputs[1].default_value = 2.0 * opacity
    link(edge.outputs[0], soft.inputs[0])
    emit = n.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = strength
    link(ramp.outputs["Color"], emit.inputs["Color"])
    clear = n.new("ShaderNodeBsdfTransparent")
    mix = n.new("ShaderNodeMixShader")
    link(soft.outputs[0], mix.inputs[0])
    link(clear.outputs[0], mix.inputs[1])
    link(emit.outputs[0], mix.inputs[2])
    out = n.new("ShaderNodeOutputMaterial")
    link(mix.outputs[0], out.inputs["Surface"])
    obj.data.materials.append(mat)
    return obj


def handheld_camera(cam, strength=0.03, rot_strength=0.01, speed=18.0):
    """Add Noise F-modifiers to the camera's location and rotation for a handheld feel."""
    if isinstance(cam, str):
        cam = bpy.data.objects[cam]
    cam.keyframe_insert("location")
    cam.keyframe_insert("rotation_euler")
    action = cam.animation_data.action
    # Blender 4.4+ (slotted actions) keeps F-curves in layers; older versions on action.fcurves.
    fcurves = getattr(action, "fcurves", None)
    if fcurves is None or len(fcurves) == 0:
        fcurves = [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    for fc in fcurves:
        if fc.data_path not in ("location", "rotation_euler"):
            continue
        noise = fc.modifiers.new("NOISE")
        noise.scale = speed
        noise.strength = strength if fc.data_path == "location" else rot_strength
        noise.phase = fc.array_index * 13.7 + (0 if fc.data_path == "location" else 50)
    return cam


def brick_material(name="Bricks", color1=(0.85, 0.85, 0.82), color2=(0.7, 0.7, 0.68), scale=7.0):
    """Light brick paving with noise variation + bump, like the path in the VHS scene."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    n, link = nt.nodes, nt.links.new
    brick = n.new("ShaderNodeTexBrick")
    brick.inputs["Color1"].default_value = (*color1, 1)
    brick.inputs["Color2"].default_value = (*color2, 1)
    brick.inputs["Mortar"].default_value = (0.25, 0.25, 0.25, 1)
    brick.inputs["Scale"].default_value = scale
    brick.inputs["Mortar Size"].default_value = 0.01
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 15.0
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.35
    link(brick.outputs["Color"], mix.inputs["A"])
    link(noise.outputs["Color"], mix.inputs["B"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.3
    link(brick.outputs["Fac"], bump.inputs["Height"])
    bsdf = n.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.6
    link(mix.outputs["Result"], bsdf.inputs["Base Color"])
    link(bump.outputs["Normal"], bsdf.inputs["Normal"])
    out = n.new("ShaderNodeOutputMaterial")
    link(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def world_sky(strength=None, hdri_path=None):
    """Sky lighting. Uses an .hdr/.exr if given, otherwise Blender's built-in Sky Texture
    (which is very bright, so it gets a low default strength)."""
    if strength is None:
        strength = 1.0 if hdri_path else 0.15
    scene = bpy.context.scene
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    n, link = nt.nodes, nt.links.new
    if hdri_path:
        tex = n.new("ShaderNodeTexEnvironment")
        tex.image = bpy.data.images.load(hdri_path, check_existing=True)
    else:
        tex = n.new("ShaderNodeTexSky")
    bg = n.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    link(tex.outputs["Color"], bg.inputs["Color"])
    out = n.new("ShaderNodeOutputWorld")
    link(bg.outputs[0], out.inputs["Surface"])
    return world

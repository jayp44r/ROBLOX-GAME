# Anime burst VFX for Blender 4.x / 5.x. Run with blender-mcp's execute_python.
# Builds Burst_Dome + Burst_Ring with geometry-node animation and toon stripe materials.
import bmesh
import bpy

COLOR = (0.27, 0.9, 1.0, 1.0)  # stripe / glow colour
RISE_FRAMES = 25  # frames for the dome to finish popping up
END_FRAME = 40

scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, END_FRAME

# Clean up an earlier run.
for name in ("Burst_Dome", "Burst_Ring"):
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
for name in ("BurstAnim", "RingAnim"):
    if name in bpy.data.node_groups:
        bpy.data.node_groups.remove(bpy.data.node_groups[name])
for name in ("BurstMat", "BurstRingMat"):
    if name in bpy.data.materials:
        bpy.data.materials.remove(bpy.data.materials[name])


def make_mesh_object(name, build):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


def build_dome(bm):
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")


def build_ring(bm):
    # Flat annulus: inner radius 0.85, outer 1.0.
    segments = 64
    import math

    inner, outer = [], []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        inner.append(bm.verts.new((0.85 * math.cos(a), 0.85 * math.sin(a), 0.0)))
        outer.append(bm.verts.new((math.cos(a), math.sin(a), 0.0)))
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((inner[i], outer[i], outer[j], inner[j]))


def map_range(nodes, from_min, from_max, to_min, to_max, loc):
    n = nodes.new("ShaderNodeMapRange")
    n.clamp = True
    n.location = loc
    n.inputs[1].default_value = from_min
    n.inputs[2].default_value = from_max
    n.inputs[3].default_value = to_min
    n.inputs[4].default_value = to_max
    return n


def set_curve(node, points):
    node.mapping.use_clip = False  # let the overshoot go above 1
    curve = node.mapping.curves[0]
    while len(curve.points) > 2:
        curve.points.remove(curve.points[1])
    curve.points[0].location = points[0]
    curve.points[1].location = points[-1]
    for p in points[1:-1]:
        curve.points.new(*p)
    for p in curve.points:
        p.handle_type = "AUTO"
    node.mapping.update()


def anim_group(name, curve_points, scale_mul):
    """Scene Time -> Map Range -> Float Curve -> Transform scale, and store 'age'."""
    ng = bpy.data.node_groups.new(name, "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    n, link = ng.nodes, ng.links.new
    gin = n.new("NodeGroupInput")
    gin.location = (-600, 0)
    gout = n.new("NodeGroupOutput")
    gout.location = (600, 0)

    time = n.new("GeometryNodeInputSceneTime")
    time.location = (-600, -250)
    t = map_range(n, 1.0, RISE_FRAMES, 0.0, 1.0, (-400, -250))
    link(time.outputs["Frame"], t.inputs[0])
    curve = n.new("ShaderNodeFloatCurve")
    curve.location = (-200, -250)
    set_curve(curve, curve_points)
    link(t.outputs[0], curve.inputs["Value"])
    mul = n.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.location = (0, -250)
    mul.inputs[1].default_value = scale_mul
    link(curve.outputs[0], mul.inputs[0])

    # age: 0 at start of the burst, 1 at END_FRAME. The material uses it to dissolve.
    age = map_range(n, 1.0, END_FRAME, 0.0, 1.0, (-200, -550))
    link(time.outputs["Frame"], age.inputs[0])

    xform = n.new("GeometryNodeTransform")
    xform.location = (200, 0)
    link(gin.outputs[0], xform.inputs["Geometry"])
    link(mul.outputs[0], xform.inputs["Scale"])

    store = n.new("GeometryNodeStoreNamedAttribute")
    store.data_type = "FLOAT"
    store.domain = "POINT"
    store.location = (400, 0)
    store.inputs["Name"].default_value = "age"
    link(xform.outputs[0], store.inputs["Geometry"])
    link(age.outputs[0], store.inputs["Value"])
    link(store.outputs[0], gout.inputs[0])
    return ng


def transparent_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "DITHERED"
    else:
        mat.blend_method = "HASHED"
    mat.use_backface_culling = False
    mat.node_tree.nodes.clear()
    return mat


def burst_material():
    mat = transparent_material("BurstMat")
    nt = mat.node_tree
    n, link = nt.nodes, nt.links.new

    coord = n.new("ShaderNodeTexCoord")
    coord.location = (-1200, 0)
    sep = n.new("ShaderNodeSeparateXYZ")
    sep.location = (-1000, -250)
    link(coord.outputs["Generated"], sep.inputs[0])
    twist = n.new("ShaderNodeMath")
    twist.operation = "MULTIPLY"
    twist.inputs[1].default_value = 2.0  # more = more swirl
    twist.location = (-800, -250)
    link(sep.outputs["Z"], twist.inputs[0])
    rot = n.new("ShaderNodeCombineXYZ")
    rot.location = (-600, -250)
    link(twist.outputs[0], rot.inputs["Z"])

    mapping = n.new("ShaderNodeMapping")
    mapping.location = (-400, 0)
    link(coord.outputs["Generated"], mapping.inputs["Vector"])
    link(rot.outputs[0], mapping.inputs["Rotation"])
    # Scroll the stripes upward over time.
    drv = mapping.inputs["Location"].driver_add("default_value", 2).driver
    drv.expression = "-frame * 0.04"

    noise = n.new("ShaderNodeTexNoise")
    noise.location = (-200, 0)
    noise.noise_dimensions = "3D"
    noise.inputs["Scale"].default_value = 2.5
    noise.inputs["Detail"].default_value = 0.0
    noise.inputs["Roughness"].default_value = 0.5
    link(mapping.outputs[0], noise.inputs["Vector"])

    stripes = n.new("ShaderNodeMath")
    stripes.operation = "GREATER_THAN"
    stripes.inputs[1].default_value = 0.5  # stripe thickness
    stripes.location = (0, 100)
    link(noise.outputs["Fac"], stripes.inputs[0])

    # Dissolve: as age goes 0 -> 1 the cutoff rises and holes eat the dome.
    attr = n.new("ShaderNodeAttribute")
    attr.attribute_type = "GEOMETRY"
    attr.attribute_name = "age"
    attr.location = (-400, -400)
    cutoff = map_range(n, 0.4, 1.0, 0.1, 1.0, (-200, -400))
    link(attr.outputs["Fac"], cutoff.inputs[0])
    keep = n.new("ShaderNodeMath")
    keep.operation = "GREATER_THAN"
    keep.location = (0, -250)
    link(noise.outputs["Fac"], keep.inputs[0])
    link(cutoff.outputs[0], keep.inputs[1])

    black = n.new("ShaderNodeBsdfPrincipled")
    black.location = (200, 400)
    black.inputs["Base Color"].default_value = (0, 0, 0, 1)
    glow = n.new("ShaderNodeEmission")
    glow.location = (200, 150)
    glow.inputs["Color"].default_value = COLOR
    glow.inputs["Strength"].default_value = 3.0
    toon = n.new("ShaderNodeMixShader")
    toon.location = (400, 200)
    link(stripes.outputs[0], toon.inputs[0])
    link(black.outputs[0], toon.inputs[1])
    link(glow.outputs[0], toon.inputs[2])

    # Inside of the shell stays black so it reads as a dome.
    geo = n.new("ShaderNodeNewGeometry")
    geo.location = (400, 450)
    inside = n.new("ShaderNodeMixShader")
    inside.location = (600, 200)
    link(geo.outputs["Backfacing"], inside.inputs[0])
    link(toon.outputs[0], inside.inputs[1])
    link(black.outputs[0], inside.inputs[2])

    clear = n.new("ShaderNodeBsdfTransparent")
    clear.location = (600, -100)
    final = n.new("ShaderNodeMixShader")
    final.location = (800, 0)
    link(keep.outputs[0], final.inputs[0])
    link(clear.outputs[0], final.inputs[1])
    link(inside.outputs[0], final.inputs[2])
    out = n.new("ShaderNodeOutputMaterial")
    out.location = (1000, 0)
    link(final.outputs[0], out.inputs["Surface"])
    return mat


def ring_material():
    mat = transparent_material("BurstRingMat")
    nt = mat.node_tree
    n, link = nt.nodes, nt.links.new
    attr = n.new("ShaderNodeAttribute")
    attr.attribute_type = "GEOMETRY"
    attr.attribute_name = "age"
    attr.location = (-400, -200)
    fade = map_range(n, 0.3, 0.8, 1.0, 0.0, (-200, -200))
    link(attr.outputs["Fac"], fade.inputs[0])
    glow = n.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = COLOR
    glow.inputs["Strength"].default_value = 4.0
    clear = n.new("ShaderNodeBsdfTransparent")
    mix = n.new("ShaderNodeMixShader")
    mix.location = (200, 0)
    link(fade.outputs[0], mix.inputs[0])
    link(clear.outputs[0], mix.inputs[1])
    link(glow.outputs[0], mix.inputs[2])
    out = n.new("ShaderNodeOutputMaterial")
    out.location = (400, 0)
    link(mix.outputs[0], out.inputs["Surface"])
    return mat


def add_anim(obj, group):
    mod = obj.modifiers.new("Anim", "NODES")
    mod.node_group = group


dome = make_mesh_object("Burst_Dome", build_dome)
dome.data.materials.append(burst_material())
# Fast rise, overshoot, settle.
add_anim(dome, anim_group("BurstAnim", [(0, 0), (0.35, 1.12), (0.7, 0.97), (1, 1)], 3.0))

ring = make_mesh_object("Burst_Ring", build_ring)
ring.location.z = 0.02
ring.data.materials.append(ring_material())
# Keeps racing outward.
add_anim(ring, anim_group("RingAnim", [(0, 0.2), (0.5, 0.85), (1, 1)], 7.0))

scene.frame_set(1)
result = {"objects": ["Burst_Dome", "Burst_Ring"], "frames": [1, END_FRAME]}
print(result)

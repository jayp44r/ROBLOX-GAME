"""Blender MCP: lets Claude Code drive Blender.

Runs a small HTTP server on localhost. The blender-mcp server (which Claude Code
starts) posts commands to it; they run on Blender's main thread and the result
goes back as JSON.

Install: Edit > Preferences > Add-ons > Install from Disk, pick this file, enable
"Blender MCP". It starts automatically; see the MCP tab in the 3D view sidebar (N).
"""

bl_info = {
    "name": "Blender MCP",
    "author": "ROBLOX-GAME",
    "version": (1, 0, 0),
    "blender": (3, 6, 0),
    "location": "3D View > Sidebar (N) > MCP",
    "description": "Lets Claude Code control Blender through the blender-mcp server",
    "category": "Interface",
}

import base64
import contextlib
import io
import json
import math
import os
import queue
import tempfile
import threading
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import bpy
import bmesh
import mathutils

DEFAULT_PORT = 44756
COMMAND_TIMEOUT = 300

_server = None
_server_thread = None
_commands = queue.Queue()
_status = {"text": "Stopped", "commands": 0}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class CommandError(Exception):
    pass


def _obj(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        raise CommandError(f'No object named "{name}". Use get_scene_info to list objects.')
    return obj


def _color(value, alpha=1.0):
    """[r,g,b] 0-255, [r,g,b] 0-1 floats, or "#rrggbb" -> linear-ish RGBA tuple for Blender."""
    if isinstance(value, str):
        h = value.lstrip("#")
        if len(h) != 6:
            raise CommandError(f"Bad hex colour {value!r}")
        rgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    else:
        rgb = list(value[:3])
        if any(c > 1 for c in rgb):
            rgb = [c / 255 for c in rgb]
        if len(value) > 3:
            alpha = value[3] if value[3] <= 1 else value[3] / 255
    # Blender colour sockets are linear; convert from sRGB so colours match what the user picked.
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return (*lin, alpha)


def _vec(value, n=3):
    if value is None:
        return None
    if len(value) != n:
        raise CommandError(f"Expected {n} numbers, got {value!r}")
    return [float(v) for v in value]


def _round(values, digits=4):
    return [round(float(v), digits) for v in values]


def _apply_transform(obj, args):
    if args.get("location") is not None:
        obj.location = _vec(args["location"])
    if args.get("rotation") is not None:
        obj.rotation_mode = "XYZ" if obj.rotation_mode in ("QUATERNION", "AXIS_ANGLE") else obj.rotation_mode
        obj.rotation_euler = [math.radians(v) for v in _vec(args["rotation"])]
    if args.get("scale") is not None:
        s = args["scale"]
        obj.scale = [float(s)] * 3 if isinstance(s, (int, float)) else _vec(s)


def _link(obj, collection_name=None):
    if collection_name:
        coll = bpy.data.collections.get(collection_name)
        if coll is None:
            coll = bpy.data.collections.new(collection_name)
            bpy.context.scene.collection.children.link(coll)
    else:
        coll = bpy.context.scene.collection
    coll.objects.link(obj)


def _view3d_override():
    wm = bpy.context.window_manager
    for window in wm.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                region = next((r for r in area.regions if r.type == "WINDOW"), None)
                if region:
                    return {"window": window, "screen": window.screen, "area": area, "region": region}
    return None


def _roblox_addon():
    import addon_utils

    for mod in addon_utils.modules():
        name = getattr(mod, "bl_info", {}).get("name", "") or mod.__name__
        if "roblox" in name.lower() or "roblox" in mod.__name__.lower():
            enabled = addon_utils.check(mod.__name__)[1]
            return {"name": name, "module": mod.__name__, "enabled": bool(enabled)}
    return None


def _undo_push(message):
    try:
        bpy.ops.ed.undo_push(message=f"Claude: {message}")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Commands (all run on Blender's main thread)
# ---------------------------------------------------------------------------


def cmd_scene_info(args):
    scene = bpy.context.scene
    limit = args.get("limit", 200)
    objects = []
    for obj in list(scene.objects)[:limit]:
        objects.append(
            {
                "name": obj.name,
                "type": obj.type,
                "location": _round(obj.location),
                "parent": obj.parent.name if obj.parent else None,
                "visible": obj.visible_get() if hasattr(obj, "visible_get") else True,
            }
        )
    view_layer = bpy.context.view_layer
    return {
        "blenderVersion": bpy.app.version_string,
        "file": bpy.data.filepath or None,
        "scene": scene.name,
        "fps": scene.render.fps / scene.render.fps_base,
        "frameStart": scene.frame_start,
        "frameEnd": scene.frame_end,
        "frameCurrent": scene.frame_current,
        "unitScale": scene.unit_settings.scale_length,
        "renderEngine": scene.render.engine,
        "activeObject": view_layer.objects.active.name if view_layer.objects.active else None,
        "selected": [o.name for o in scene.objects if o.select_get()],
        "objectCount": len(scene.objects),
        "objects": objects,
        "truncated": len(scene.objects) > limit,
        "robloxAddon": _roblox_addon(),
    }


def cmd_object_info(args):
    obj = _obj(args["name"])
    info = {
        "name": obj.name,
        "type": obj.type,
        "location": _round(obj.location),
        "rotation": _round([math.degrees(a) for a in obj.rotation_euler]),
        "rotationMode": obj.rotation_mode,
        "scale": _round(obj.scale),
        "dimensions": _round(obj.dimensions),
        "parent": obj.parent.name if obj.parent else None,
        "parentBone": obj.parent_bone or None,
        "children": [c.name for c in obj.children],
        "collections": [c.name for c in obj.users_collection],
        "materials": [s.material.name for s in getattr(obj, "material_slots", []) if s.material],
        "modifiers": [{"name": m.name, "type": m.type} for m in obj.modifiers],
        "customProperties": {k: str(obj[k]) for k in obj.keys() if not k.startswith("_")},
    }
    if obj.type == "MESH":
        mesh = obj.data
        info["mesh"] = {"vertices": len(mesh.vertices), "faces": len(mesh.polygons), "uvLayers": len(mesh.uv_layers)}
        info["vertexGroups"] = [g.name for g in obj.vertex_groups][:200]
    if obj.type == "ARMATURE":
        info["boneCount"] = len(obj.data.bones)
        info["bones"] = [b.name for b in obj.data.bones][:200]
    ad = obj.animation_data
    if ad and ad.action:
        start, end = ad.action.frame_range
        info["action"] = {"name": ad.action.name, "frameRange": [start, end]}
    info["actions"] = [a.name for a in bpy.data.actions][:100]
    return info


def cmd_execute_python(args):
    code = args["code"]
    namespace = {"bpy": bpy, "bmesh": bmesh, "mathutils": mathutils, "math": math, "result": None}
    stdout = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout):
            exec(compile(code, "<execute_python>", "exec"), namespace)
    except Exception:
        out = stdout.getvalue()
        raise CommandError(traceback.format_exc(limit=8) + (f"\nOutput:\n{out}" if out else ""))
    _undo_push("Run Python")
    result = namespace.get("result")
    try:
        json.dumps(result)
    except TypeError:
        result = repr(result)
    return {"output": stdout.getvalue(), "result": result}


def _bmesh_primitive(kind, args):
    bm = bmesh.new()
    size = float(args.get("size", 2.0))
    radius = size / 2
    segments = int(args.get("segments", 32))
    if kind == "cube":
        bmesh.ops.create_cube(bm, size=size)
    elif kind == "uv_sphere":
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=max(3, segments // 2), radius=radius)
    elif kind == "ico_sphere":
        bmesh.ops.create_icosphere(bm, subdivisions=int(args.get("subdivisions", 2)), radius=radius)
    elif kind in ("cylinder", "cone"):
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            segments=segments,
            radius1=radius,
            radius2=0.0 if kind == "cone" else radius,
            depth=float(args.get("depth", size)),
        )
    elif kind == "plane":
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=radius)
    elif kind == "monkey":
        bmesh.ops.create_monkey(bm)
    else:
        bm.free()
        return None
    mesh = bpy.data.meshes.new(args.get("name") or kind.capitalize())
    bm.to_mesh(mesh)
    bm.free()
    if args.get("smooth"):
        for poly in mesh.polygons:
            poly.use_smooth = True
    return mesh


def cmd_create_object(args):
    kind = args["type"]
    name = args.get("name") or kind.replace("_", " ").title().replace(" ", "")
    data = _bmesh_primitive(kind, args)
    if data is None:
        if kind == "torus":
            bpy.ops.mesh.primitive_torus_add(
                major_radius=float(args.get("size", 2.0)) / 2, minor_radius=float(args.get("size", 2.0)) / 8
            )
            obj = bpy.context.active_object
            obj.name = name
            for coll in list(obj.users_collection):
                coll.objects.unlink(obj)
            _link(obj, args.get("collection"))
        elif kind == "empty":
            obj = bpy.data.objects.new(name, None)
            _link(obj, args.get("collection"))
        elif kind == "camera":
            obj = bpy.data.objects.new(name, bpy.data.cameras.new(name))
            _link(obj, args.get("collection"))
        elif kind in ("point_light", "sun_light", "area_light", "spot_light"):
            light = bpy.data.lights.new(name, kind.split("_")[0].upper())
            obj = bpy.data.objects.new(name, light)
            _link(obj, args.get("collection"))
        else:
            raise CommandError(f"Unknown object type {kind!r}")
    else:
        obj = bpy.data.objects.new(name, data)
        _link(obj, args.get("collection"))
    _apply_transform(obj, args)
    if args.get("color") is not None and obj.type == "MESH":
        _set_material(obj, {"color": args["color"]})
    if args.get("parent"):
        obj.parent = _obj(args["parent"])
    _undo_push(f"Create {kind}")
    return {"name": obj.name, "type": obj.type}


def cmd_transform_objects(args):
    changed = []
    for name in args["names"]:
        obj = _obj(name)
        _apply_transform(obj, args)
        changed.append(obj.name)
    _undo_push("Transform")
    return {"changed": changed}


def cmd_delete_objects(args):
    deleted = []
    for name in args["names"]:
        obj = _obj(name)
        bpy.data.objects.remove(obj, do_unlink=True)
        deleted.append(name)
    _undo_push("Delete")
    return {"deleted": deleted}


def _set_material(obj, args):
    mat_name = args.get("material") or f"{obj.name}_Mat"
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    if args.get("color") is not None:
        rgba = _color(args["color"])
        bsdf.inputs["Base Color"].default_value = rgba
        mat.diffuse_color = rgba
    for key, socket in (("metallic", "Metallic"), ("roughness", "Roughness")):
        if args.get(key) is not None:
            bsdf.inputs[socket].default_value = float(args[key])
    if args.get("emission") is not None:
        socket = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[socket].default_value = _color(args["emission"])
        bsdf.inputs["Emission Strength"].default_value = float(args.get("emissionStrength", 1.0))
    if obj.data is not None and hasattr(obj.data, "materials"):
        if args.get("append"):
            obj.data.materials.append(mat)
        elif obj.data.materials:
            obj.data.materials[0] = mat
        else:
            obj.data.materials.append(mat)
    return mat


def cmd_set_material(args):
    names = args["names"]
    mat = None
    for name in names:
        mat = _set_material(_obj(name), args)
    _undo_push("Set material")
    return {"material": mat.name if mat else None, "objects": names}


def cmd_add_modifier(args):
    obj = _obj(args["name"])
    mod = obj.modifiers.new(args.get("modifierName") or args["type"].title(), args["type"].upper())
    for key, value in (args.get("settings") or {}).items():
        if not hasattr(mod, key):
            raise CommandError(f"{mod.type} modifier has no setting {key!r}")
        if isinstance(value, str) and bpy.data.objects.get(value) and key in ("object", "target", "offset_object"):
            value = bpy.data.objects[value]
        setattr(mod, key, value)
    _undo_push(f"Add {mod.type}")
    return {"object": obj.name, "modifier": mod.name, "type": mod.type}


def cmd_animation_settings(args):
    scene = bpy.context.scene
    if args.get("fps") is not None:
        scene.render.fps = int(args["fps"])
        scene.render.fps_base = 1.0
    if args.get("frameStart") is not None:
        scene.frame_start = int(args["frameStart"])
    if args.get("frameEnd") is not None:
        scene.frame_end = int(args["frameEnd"])
    if args.get("frameCurrent") is not None:
        scene.frame_set(int(args["frameCurrent"]))
    _undo_push("Animation settings")
    return {
        "fps": scene.render.fps / scene.render.fps_base,
        "frameStart": scene.frame_start,
        "frameEnd": scene.frame_end,
        "frameCurrent": scene.frame_current,
    }


def cmd_armature_bones(args):
    obj = _obj(args["name"])
    if obj.type != "ARMATURE":
        raise CommandError(f"{obj.name} is a {obj.type}, not an ARMATURE")
    bones = []
    for bone in obj.data.bones:
        pose = obj.pose.bones.get(bone.name)
        bones.append(
            {
                "name": bone.name,
                "parent": bone.parent.name if bone.parent else None,
                "head": _round(bone.head_local),
                "tail": _round(bone.tail_local),
                "rotationMode": pose.rotation_mode if pose else None,
            }
        )
    return {"armature": obj.name, "bones": bones}


def _set_rotation(target, rotation_deg=None, quaternion=None):
    """Sets a rotation on an object or pose bone in whatever rotation mode it uses; returns the data path."""
    mode = target.rotation_mode
    if quaternion is not None:
        q = mathutils.Quaternion(_vec(quaternion, 4))
        if mode == "QUATERNION":
            target.rotation_quaternion = q
            return "rotation_quaternion"
        target.rotation_euler = q.to_euler(mode if mode != "AXIS_ANGLE" else "XYZ")
        return "rotation_euler"
    euler = mathutils.Euler([math.radians(v) for v in _vec(rotation_deg)], "XYZ")
    if mode == "QUATERNION":
        target.rotation_quaternion = euler.to_quaternion()
        return "rotation_quaternion"
    if mode == "AXIS_ANGLE":
        axis, angle = euler.to_quaternion().to_axis_angle()
        target.rotation_axis_angle = [angle, *axis]
        return "rotation_axis_angle"
    target.rotation_euler = euler.to_matrix().to_euler(mode)
    return "rotation_euler"


def cmd_insert_keyframes(args):
    obj = _obj(args["object"])
    scene = bpy.context.scene
    if args.get("action"):
        if obj.animation_data is None:
            obj.animation_data_create()
        action = bpy.data.actions.get(args["action"])
        if action is None:
            action = bpy.data.actions.new(args["action"])
            action.use_fake_user = True
        obj.animation_data.action = action
    interpolation = args.get("interpolation")
    count = 0
    for i, key in enumerate(args["keyframes"]):
        frame = float(key["frame"])
        bone_name = key.get("bone")
        if bone_name:
            if obj.type != "ARMATURE":
                raise CommandError(f"keyframes[{i}]: {obj.name} is not an armature, so it has no bone {bone_name!r}")
            target = obj.pose.bones.get(bone_name)
            if target is None:
                raise CommandError(f"keyframes[{i}]: no bone {bone_name!r}. Use get_armature_bones.")
        else:
            target = obj
        paths = []
        if key.get("location") is not None:
            target.location = _vec(key["location"])
            paths.append("location")
        if key.get("rotation") is not None or key.get("rotationQuaternion") is not None:
            paths.append(_set_rotation(target, key.get("rotation"), key.get("rotationQuaternion")))
        if key.get("scale") is not None:
            s = key["scale"]
            target.scale = [float(s)] * 3 if isinstance(s, (int, float)) else _vec(s)
            paths.append("scale")
        if not paths:
            raise CommandError(f"keyframes[{i}] sets nothing: give location, rotation, rotationQuaternion or scale")
        for path in paths:
            target.keyframe_insert(data_path=path, frame=frame)
            count += 1
    if interpolation and obj.animation_data and obj.animation_data.action:
        for fcurve in _action_fcurves(obj):
            for point in fcurve.keyframe_points:
                point.interpolation = interpolation.upper()
    scene.frame_set(scene.frame_current)
    _undo_push("Insert keyframes")
    action = obj.animation_data.action if obj.animation_data else None
    return {"object": obj.name, "keysInserted": count, "action": action.name if action else None}


def _action_fcurves(obj):
    ad = obj.animation_data
    action = ad.action if ad else None
    if action is None:
        return []
    # Blender 4.4+ layered actions keep fcurves in channelbags per slot.
    if hasattr(action, "layers") and len(action.layers) > 0:
        curves = []
        slot = getattr(ad, "action_slot", None)
        for layer in action.layers:
            for strip in layer.strips:
                if slot is not None and hasattr(strip, "channelbag"):
                    bag = strip.channelbag(slot)
                    if bag:
                        curves.extend(bag.fcurves)
                elif hasattr(strip, "channelbags"):
                    for bag in strip.channelbags:
                        curves.extend(bag.fcurves)
        return curves
    return list(getattr(action, "fcurves", []))


def cmd_clear_animation(args):
    obj = _obj(args["object"])
    obj.animation_data_clear()
    _undo_push("Clear animation")
    return {"object": obj.name, "cleared": True}


def cmd_import_file(args):
    path = os.path.abspath(os.path.expanduser(args["path"]))
    if not os.path.exists(path):
        raise CommandError(f"File not found: {path}")
    ext = os.path.splitext(path)[1].lower()
    before = set(bpy.data.objects.keys())
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        if hasattr(bpy.ops.wm, "obj_import"):
            bpy.ops.wm.obj_import(filepath=path)
        else:
            bpy.ops.import_scene.obj(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".stl":
        if hasattr(bpy.ops.wm, "stl_import"):
            bpy.ops.wm.stl_import(filepath=path)
        else:
            bpy.ops.import_mesh.stl(filepath=path)
    elif ext == ".blend":
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = src.objects
        for obj in dst.objects:
            if obj is not None:
                bpy.context.scene.collection.objects.link(obj)
    else:
        raise CommandError(f"Unsupported file type {ext}. Use .fbx, .obj, .glb/.gltf, .stl or .blend")
    new = sorted(set(bpy.data.objects.keys()) - before)
    _undo_push("Import")
    return {"imported": new}


def cmd_export_fbx(args):
    path = os.path.abspath(os.path.expanduser(args["path"]))
    if not path.lower().endswith(".fbx"):
        path += ".fbx"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    names = args.get("objects")
    if names:
        for obj in bpy.context.scene.objects:
            obj.select_set(False)
        for name in names:
            obj = _obj(name)
            obj.select_set(True)
            # Include an armature's skinned meshes with it.
            if obj.type == "ARMATURE":
                for child in obj.children:
                    child.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=bool(names),
        global_scale=float(args.get("scale", 1.0)),
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        bake_anim=bool(args.get("includeAnimation", True)),
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        bake_anim_simplify_factor=0.0,
        path_mode="COPY",
        embed_textures=True,
    )
    return {"path": path, "bytes": os.path.getsize(path)}


def cmd_screenshot(args):
    if args.get("frame") is not None:
        bpy.context.scene.frame_set(int(args["frame"]))
    path = os.path.join(tempfile.gettempdir(), "blender_mcp_screenshot.png")
    override = _view3d_override()
    source = "viewport"
    try:
        if override is None:
            raise RuntimeError("no 3D Viewport open")
        if args.get("focus"):
            obj = _obj(args["focus"])
            for o in bpy.context.scene.objects:
                o.select_set(o == obj)
            bpy.context.view_layer.objects.active = obj
            with bpy.context.temp_override(**override):
                bpy.ops.view3d.view_selected()
        with bpy.context.temp_override(**override):
            bpy.ops.screen.screenshot_area(filepath=path)
    except (RuntimeError, TypeError) as err:
        # No usable viewport (e.g. Blender running in background): render through the scene camera instead.
        _render_preview(path, err)
        source = "camera render"
    image = bpy.data.images.load(path, check_existing=False)
    try:
        max_size = int(args.get("maxSize", 1024))
        w, h = image.size
        if max(w, h) > max_size:
            scale = max_size / max(w, h)
            image.scale(max(1, int(w * scale)), max(1, int(h * scale)))
            image.filepath_raw = path
            image.file_format = "PNG"
            image.save()
        size = list(image.size)
    finally:
        bpy.data.images.remove(image)
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode("ascii")
    return {"imageBase64": data, "mimeType": "image/png", "size": size, "source": source}


def _render_preview(path, viewport_error):
    scene = bpy.context.scene
    if scene.camera is None:
        raise CommandError(f"Cannot screenshot the viewport ({viewport_error}) and the scene has no camera to render from.")
    render = scene.render
    saved = (render.engine, render.resolution_percentage, render.filepath, render.image_settings.file_format)
    try:
        render.engine = "BLENDER_WORKBENCH"
        render.resolution_percentage = 50
        render.image_settings.file_format = "PNG"
        render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        render.engine, render.resolution_percentage, render.filepath, render.image_settings.file_format = saved


def cmd_save_file(args):
    path = args.get("path")
    if path:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.expanduser(path)))
    elif bpy.data.filepath:
        bpy.ops.wm.save_mainfile()
    else:
        raise CommandError("This file has never been saved; give a path.")
    return {"path": bpy.data.filepath}


COMMANDS = {
    "scene_info": cmd_scene_info,
    "object_info": cmd_object_info,
    "execute_python": cmd_execute_python,
    "create_object": cmd_create_object,
    "transform_objects": cmd_transform_objects,
    "delete_objects": cmd_delete_objects,
    "set_material": cmd_set_material,
    "add_modifier": cmd_add_modifier,
    "animation_settings": cmd_animation_settings,
    "armature_bones": cmd_armature_bones,
    "insert_keyframes": cmd_insert_keyframes,
    "clear_animation": cmd_clear_animation,
    "import_file": cmd_import_file,
    "export_fbx": cmd_export_fbx,
    "screenshot": cmd_screenshot,
    "save_file": cmd_save_file,
}


def run_command(command):
    handler = COMMANDS.get(command.get("type"))
    if handler is None:
        return {"ok": False, "error": f"Unknown command {command.get('type')!r}"}
    try:
        return {"ok": True, "result": handler(command.get("args") or {})}
    except CommandError as err:
        return {"ok": False, "error": str(err)}
    except Exception as err:
        return {"ok": False, "error": f"{type(err).__name__}: {err}\n{traceback.format_exc(limit=5)}"}


# ---------------------------------------------------------------------------
# HTTP server (background thread) and main-thread queue pump
# ---------------------------------------------------------------------------


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ok": True, "blender": bpy.app.version_string, "file": bpy.data.filepath or None})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/command":
            self._send(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            command = json.loads(self.rfile.read(length) or b"{}")
        except Exception as err:
            self._send(400, {"ok": False, "error": f"bad request: {err}"})
            return
        done = threading.Event()
        slot = {}
        _commands.put((command, slot, done))
        if not done.wait(COMMAND_TIMEOUT):
            self._send(504, {"ok": False, "error": f"Blender did not finish within {COMMAND_TIMEOUT}s (is a modal dialog open?)"})
            return
        self._send(200, slot["response"])


def process_queue():
    """Timer callback on Blender's main thread: runs queued commands."""
    while True:
        try:
            command, slot, done = _commands.get_nowait()
        except queue.Empty:
            break
        slot["response"] = run_command(command)
        _status["commands"] += 1
        done.set()
    return 0.05


def start_server(port=None):
    global _server, _server_thread
    if _server is not None:
        return True
    port = port or _prefs_port()
    try:
        _server = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
    except OSError as err:
        _status["text"] = f"Port {port} busy: {err.strerror}"
        print(f"[Blender MCP] could not start on port {port}: {err}")
        return False
    _server.daemon_threads = True
    _server_thread = threading.Thread(target=_server.serve_forever, name="BlenderMCP", daemon=True)
    _server_thread.start()
    if not bpy.app.timers.is_registered(process_queue):
        bpy.app.timers.register(process_queue, persistent=True)
    _status["text"] = f"Running on port {port}"
    print(f"[Blender MCP] listening on http://127.0.0.1:{port}")
    return True


def stop_server():
    global _server, _server_thread
    if _server is not None:
        _server.shutdown()
        _server.server_close()
        _server = None
        _server_thread = None
    if bpy.app.timers.is_registered(process_queue):
        bpy.app.timers.unregister(process_queue)
    # Fail anything still waiting so HTTP threads do not hang.
    while not _commands.empty():
        _, slot, done = _commands.get_nowait()
        slot["response"] = {"ok": False, "error": "Blender MCP server stopped"}
        done.set()
    _status["text"] = "Stopped"


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------


def _prefs():
    addon = bpy.context.preferences.addons.get(__name__)
    return addon.preferences if addon else None


def _prefs_port():
    prefs = _prefs()
    return prefs.port if prefs else DEFAULT_PORT


class BLENDERMCP_Preferences(bpy.types.AddonPreferences):
    bl_idname = __name__

    port: bpy.props.IntProperty(name="Port", default=DEFAULT_PORT, min=1024, max=65535)
    auto_start: bpy.props.BoolProperty(name="Start automatically", default=True)

    def draw(self, context):
        self.layout.prop(self, "port")
        self.layout.prop(self, "auto_start")


class BLENDERMCP_OT_start(bpy.types.Operator):
    bl_idname = "blender_mcp.start"
    bl_label = "Start MCP Server"

    def execute(self, context):
        if not start_server():
            self.report({"ERROR"}, _status["text"])
            return {"CANCELLED"}
        return {"FINISHED"}


class BLENDERMCP_OT_stop(bpy.types.Operator):
    bl_idname = "blender_mcp.stop"
    bl_label = "Stop MCP Server"

    def execute(self, context):
        stop_server()
        return {"FINISHED"}


class BLENDERMCP_PT_panel(bpy.types.Panel):
    bl_label = "Claude MCP"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "MCP"

    def draw(self, context):
        layout = self.layout
        layout.label(text=_status["text"], icon="CHECKMARK" if _server else "X")
        layout.label(text=f"Commands run: {_status['commands']}")
        if _server:
            layout.operator("blender_mcp.stop", icon="PAUSE")
        else:
            layout.operator("blender_mcp.start", icon="PLAY")


CLASSES = (BLENDERMCP_Preferences, BLENDERMCP_OT_start, BLENDERMCP_OT_stop, BLENDERMCP_PT_panel)


def _auto_start():
    prefs = _prefs()
    if prefs is None or prefs.auto_start:
        start_server()
    return None


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.app.timers.register(_auto_start, first_interval=0.5)


def unregister():
    stop_server()
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)

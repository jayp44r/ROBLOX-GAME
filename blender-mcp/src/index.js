#!/usr/bin/env node
// MCP server for Blender. Claude Code talks to this over stdio; this forwards
// each tool call to the Blender MCP add-on's HTTP server inside Blender.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const PORT = Number(process.env.BLENDER_MCP_PORT) || 44756;
const BASE_URL = `http://127.0.0.1:${PORT}`;

async function send(type, args = {}, timeoutMs = 120_000) {
  let response;
  try {
    response = await fetch(`${BASE_URL}/command`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type, args }),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (err) {
    if (err?.name === "TimeoutError") throw new Error(`Blender did not answer "${type}" within ${timeoutMs / 1000}s.`);
    throw new Error(
      `Blender is not connected (nothing listening on ${BASE_URL}). Open Blender, enable the "Blender MCP" ` +
        `add-on, and check the MCP tab in the 3D view sidebar (press N) says "Running".`
    );
  }
  const body = await response.json();
  if (!body.ok) throw new Error(body.error || `Blender returned HTTP ${response.status}`);
  return body.result;
}

const server = new McpServer({ name: "blender-mcp", version: "1.0.0" });

function tool(name, description, shape, type, { timeoutMs, image } = {}) {
  server.registerTool(name, { description, inputSchema: shape }, async (args) => {
    try {
      const result = await send(type, args, timeoutMs);
      if (image) {
        const { imageBase64, mimeType, ...meta } = result;
        return {
          content: [
            { type: "image", data: imageBase64, mimeType },
            { type: "text", text: JSON.stringify(meta) },
          ],
        };
      }
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return { isError: true, content: [{ type: "text", text: String(err?.message || err) }] };
    }
  });
}

const vec3 = z.array(z.number()).length(3);
const color = z
  .union([z.string(), z.array(z.number()).min(3).max(4)])
  .describe('[r,g,b] 0-255 (or 0-1 floats) or "#rrggbb"');

tool(
  "get_scene_info",
  "Blender version, open file, frame range/fps, objects in the scene, selection, and whether the Roblox add-on is " +
    "installed. Call this first to check Blender is connected.",
  { limit: z.number().int().min(1).max(2000).optional().describe("Max objects to list (default 200).") },
  "scene_info"
);

tool(
  "get_object_info",
  "Details of one object: transform, dimensions, materials, modifiers, mesh stats, bones, animation action.",
  { name: z.string() },
  "object_info"
);

tool(
  "create_object",
  "Add a primitive or other object to the scene.",
  {
    type: z.enum([
      "cube", "uv_sphere", "ico_sphere", "cylinder", "cone", "plane", "torus", "monkey",
      "empty", "camera", "point_light", "sun_light", "area_light", "spot_light",
    ]),
    name: z.string().optional(),
    location: vec3.optional(),
    rotation: vec3.optional().describe("Euler XYZ in degrees."),
    scale: z.union([z.number(), vec3]).optional(),
    size: z.number().positive().optional().describe("Base size in metres (default 2)."),
    segments: z.number().int().min(3).max(256).optional().describe("For spheres, cylinders and cones."),
    smooth: z.boolean().optional().describe("Smooth shading."),
    color: color.optional().describe("Gives the mesh a simple material in this colour."),
    parent: z.string().optional(),
    collection: z.string().optional().describe("Collection to put it in (created if missing)."),
  },
  "create_object"
);

tool(
  "transform_objects",
  "Set location, rotation (degrees) and/or scale on objects.",
  {
    names: z.array(z.string()).min(1),
    location: vec3.optional(),
    rotation: vec3.optional(),
    scale: z.union([z.number(), vec3]).optional(),
  },
  "transform_objects"
);

tool("delete_objects", "Delete objects.", { names: z.array(z.string()).min(1) }, "delete_objects");

tool(
  "set_material",
  "Give objects a Principled BSDF material (colour, metallic, roughness, glow). Reuses the material if the name exists.",
  {
    names: z.array(z.string()).min(1),
    material: z.string().optional().describe("Material name (default <object>_Mat)."),
    color: color.optional(),
    metallic: z.number().min(0).max(1).optional(),
    roughness: z.number().min(0).max(1).optional(),
    emission: color.optional().describe("Glow colour, e.g. for neon pets."),
    emissionStrength: z.number().min(0).optional(),
    append: z.boolean().optional().describe("Add as an extra slot instead of replacing slot 1."),
  },
  "set_material"
);

tool(
  "add_modifier",
  "Add a modifier (BEVEL, SUBSURF, MIRROR, SOLIDIFY, ARRAY, DECIMATE, ...) with settings by attribute name.",
  {
    name: z.string().describe("Object name."),
    type: z.string().describe("Modifier type, e.g. BEVEL or SUBSURF."),
    modifierName: z.string().optional(),
    settings: z.record(z.any()).optional().describe('e.g. {"width": 0.1, "segments": 3} or {"levels": 2}'),
  },
  "add_modifier"
);

tool(
  "set_animation_settings",
  "Set scene fps and frame range, or jump to a frame. Roblox plays animations at 30 fps.",
  {
    fps: z.number().int().min(1).max(240).optional(),
    frameStart: z.number().int().optional(),
    frameEnd: z.number().int().optional(),
    frameCurrent: z.number().int().optional(),
  },
  "animation_settings"
);

tool(
  "get_armature_bones",
  "List an armature's bones with parents, rest positions and rotation modes (R6/R15 rigs).",
  { name: z.string().describe("Armature object name.") },
  "armature_bones"
);

tool(
  "insert_keyframes",
  "Keyframe an object or its bones. Each key sets any of location, rotation (Euler XYZ degrees, converted to the " +
    "bone's rotation mode) or rotationQuaternion [w,x,y,z], and scale, at a frame. Bone transforms are relative to " +
    "the rest pose.",
  {
    object: z.string().describe("Object or armature name."),
    action: z.string().optional().describe("Action to key into (created if missing), e.g. \"Wave\"."),
    interpolation: z.enum(["CONSTANT", "LINEAR", "BEZIER"]).optional(),
    keyframes: z
      .array(
        z.object({
          frame: z.number(),
          bone: z.string().optional(),
          location: vec3.optional(),
          rotation: vec3.optional(),
          rotationQuaternion: z.array(z.number()).length(4).optional(),
          scale: z.union([z.number(), vec3]).optional(),
        })
      )
      .min(1)
      .max(5000),
  },
  "insert_keyframes"
);

tool("clear_animation", "Remove all animation from an object.", { object: z.string() }, "clear_animation");

tool(
  "execute_python",
  "Run Python inside Blender with bpy, bmesh, mathutils and math imported. Printed output is returned; assign to " +
    "`result` to return a JSON value. Use for anything the other tools do not cover.",
  { code: z.string() },
  "execute_python",
  { timeoutMs: 300_000 }
);

tool(
  "import_file",
  "Import a model or rig (.fbx, .obj, .glb/.gltf, .stl, or objects from a .blend). Path is on the user's computer.",
  { path: z.string() },
  "import_file",
  { timeoutMs: 300_000 }
);

tool(
  "export_fbx",
  "Export to FBX for Roblox (Y up, no leaf bones, animation baked, textures embedded). Import it in Studio with " +
    "the 3D Importer, or for an animation use the Animation Editor's Import from FBX.",
  {
    path: z.string().describe("Output .fbx path on the user's computer."),
    objects: z.array(z.string()).optional().describe("Objects to export (an armature brings its meshes). Default: all."),
    includeAnimation: z.boolean().optional().describe("Default true."),
    scale: z.number().positive().optional().describe("Global scale (default 1)."),
  },
  "export_fbx",
  { timeoutMs: 300_000 }
);

tool(
  "get_viewport_screenshot",
  "Capture Blender's 3D viewport as an image to check what was built or posed. Optionally jump to a frame or frame " +
    "an object first.",
  {
    frame: z.number().int().optional(),
    focus: z.string().optional().describe("Object to zoom the view to."),
    maxSize: z.number().int().min(128).max(2048).optional().describe("Longest side in pixels (default 1024)."),
  },
  "screenshot",
  { image: true }
);

tool(
  "save_blend_file",
  "Save the .blend file (to its current path, or to a new path).",
  { path: z.string().optional() },
  "save_file"
);

await server.connect(new StdioServerTransport());
console.error("[blender-mcp] MCP server ready on stdio");

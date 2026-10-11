#!/usr/bin/env node
// MCP server for Roblox Studio. Claude Code talks to this over stdio; this
// forwards each tool call to the RobloxStudioMCP plugin running in Studio.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { StudioBridge } from "./bridge.js";

const PORT = Number(process.env.ROBLOX_STUDIO_MCP_PORT) || 44755;

const bridge = new StudioBridge({ port: PORT });
let bridgeError = null;
try {
  await bridge.start();
} catch (err) {
  bridgeError =
    err?.code === "EADDRINUSE"
      ? `Port ${PORT} is already in use (another roblox-studio-mcp may be running, e.g. in a second ` +
        `Claude Code window). Close it, or set ROBLOX_STUDIO_MCP_PORT to a free port here and in the plugin.`
      : `Could not start the Studio bridge: ${err?.message || err}`;
  console.error(`[roblox-studio-mcp] ${bridgeError}`);
}

const server = new McpServer({ name: "robloxstudio-mcp", version: "1.0.0" });

const instanceId = z
  .string()
  .optional()
  .describe("Studio instance to target (from get_connected_instances). Defaults to the most recently active one.");

const path = (what = "Instance") =>
  z
    .string()
    .describe(
      `${what} path, dot-separated from game, e.g. "Workspace.Map.Spawn" or "StarterGui.ShopGui.MainFrame". ` +
        `A leading "game." is optional.`
    );

const propertyValues = z
  .record(z.any())
  .describe(
    "Property name -> value. Values are converted to the property's type: Color3 as [r,g,b] 0-255 or \"#hex\"; " +
      "Vector3/Vector2 as [x,y,z]/[x,y]; UDim2 as [xScale,xOffset,yScale,yOffset]; UDim as [scale,offset]; " +
      "CFrame as [x,y,z] or [x,y,z,rx,ry,rz] (degrees) or 12 numbers; enums by item name (\"FredokaOne\"); " +
      "BrickColor by name; NumberRange as [min,max]; ColorSequence as [[r,g,b],[r,g,b]] or " +
      "[[time,[r,g,b]],...]; NumberSequence as [n,n] or [[time,value],...]; instance references as a path; " +
      "Font (FontFace) as an Enum.Font name or {family, weight, style}. Use \"Attributes\" for an object of attributes."
  );

const instanceSpec = z.object({
  className: z.string().describe("Roblox class, e.g. Part, Frame, TextLabel, UICorner"),
  parent: z.string().optional().describe("Parent path. Required for top-level objects in mass_create_objects."),
  name: z.string().optional(),
  properties: propertyValues.optional(),
});

const uiNode = z.lazy(() =>
  z.object({
    className: z.string(),
    name: z.string().optional(),
    properties: propertyValues.optional(),
    children: z.array(uiNode).optional(),
  })
);

// The plugin retries every few seconds, so give a just-opened Studio a moment to check in.
async function waitForInstances(maxMs) {
  const deadline = Date.now() + maxMs;
  while (bridge.connectedInstances().length === 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return bridge.connectedInstances();
}

function tool(name, description, shape, type, { timeoutMs } = {}) {
  server.registerTool(name, { description, inputSchema: { ...shape, instanceId } }, async (args) => {
    const { instanceId: target, ...rest } = args;
    try {
      if (bridgeError) throw new Error(bridgeError);
      const result =
        type === "__local__"
          ? await waitForInstances(8000)
          : await bridge.send(type, rest, { instanceId: target, timeoutMs });
      return { content: [{ type: "text", text: typeof result === "string" ? result : JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return { isError: true, content: [{ type: "text", text: String(err?.message || err) }] };
    }
  });
}

tool(
  "get_connected_instances",
  "List Roblox Studio windows whose RobloxStudioMCP plugin is connected. Call this first; if it is empty, ask the " +
    "user to open Studio and enable the plugin.",
  {},
  "__local__"
);

tool("get_place_info", "Get the open place's name, PlaceId, GameId, services and whether a playtest is running.", {}, "place_info");

tool(
  "get_explorer_tree",
  "Read the Explorer hierarchy (names and classes) under a path.",
  {
    path: path().optional().describe("Root path. Omit for the top-level services."),
    depth: z.number().int().min(0).max(10).optional().describe("How many levels deep (default 2)."),
    maxChildren: z.number().int().min(1).max(1000).optional().describe("Cap per parent (default 100)."),
  },
  "get_tree"
);

tool(
  "find_instances",
  "Search descendants by class and/or name.",
  {
    root: path("Root").optional().describe("Where to search (default: game)."),
    className: z.string().optional().describe("Matches with IsA, so BasePart finds Parts and MeshParts."),
    nameContains: z.string().optional().describe("Case-insensitive substring of the Name."),
    limit: z.number().int().min(1).max(2000).optional().describe("Default 200."),
  },
  "find"
);

tool(
  "get_properties",
  "Read property values (and attributes) of an instance.",
  {
    path: path(),
    properties: z
      .array(z.string())
      .optional()
      .describe("Property names to read. Omit to get a common set for the instance's class."),
  },
  "get_properties"
);

tool(
  "set_properties",
  "Set properties (and Attributes) on one or more instances. Undoable in Studio.",
  {
    paths: z.array(path()).min(1).describe("Instances to change; the same properties go on each."),
    properties: propertyValues,
  },
  "set_properties"
);

tool(
  "create_instance",
  "Create one instance. Returns its path.",
  instanceSpec.extend({ parent: path("Parent") }).shape,
  "create_instance"
);

tool(
  "mass_create_objects",
  "Create many instances in one undoable step (parts for a map, decorations, etc). Each object needs className and " +
    "parent; a parent may refer to an object created earlier in the same list.",
  { objects: z.array(instanceSpec).min(1).max(2000) },
  "mass_create",
  { timeoutMs: 120_000 }
);

tool(
  "create_ui_tree",
  "Build a nested GUI in one undoable step: a node tree of {className, name, properties, children}. Use it for " +
    "ScreenGuis, Frames, buttons, UICorner/UIStroke/UIGradient/UIAspectRatioConstraint, layouts, etc.",
  {
    parent: path("Parent").describe('Where to put the root node, e.g. "StarterGui".'),
    tree: uiNode,
  },
  "create_ui_tree",
  { timeoutMs: 120_000 }
);

tool(
  "delete_instances",
  "Delete instances (undoable with Ctrl+Z in Studio).",
  { paths: z.array(path()).min(1) },
  "delete"
);

tool(
  "clone_instance",
  "Clone an instance, optionally into a new parent with a new name.",
  { path: path(), parent: path("New parent").optional(), name: z.string().optional() },
  "clone"
);

tool("get_script_source", "Read the source of a Script, LocalScript or ModuleScript.", { path: path("Script") }, "get_source");

tool(
  "set_script_source",
  "Write a script's source. Creates the script if the path does not exist yet (className decides its type).",
  {
    path: path("Script"),
    source: z.string(),
    className: z
      .enum(["Script", "LocalScript", "ModuleScript"])
      .optional()
      .describe("Used only when creating. Default: Script."),
  },
  "set_source"
);

tool(
  "execute_luau",
  "Run Luau code in Studio's edit context (plugin security) and return printed output and return values. Use for " +
    "anything the other tools do not cover. Changes are recorded as one undo step.",
  {
    code: z.string(),
    timeoutSeconds: z.number().min(1).max(300).optional().describe("Default 60."),
  },
  "execute",
  { timeoutMs: 310_000 }
);

tool("get_selection", "Get the paths of the instances selected in Studio.", {}, "get_selection");

tool(
  "set_selection",
  "Select instances in Studio (useful to point the user at what was built).",
  { paths: z.array(path()) },
  "set_selection"
);

tool(
  "get_output_log",
  "Read recent Output window messages (prints, warnings, errors) captured since the plugin connected.",
  {
    limit: z.number().int().min(1).max(1000).optional().describe("Default 100."),
    clear: z.boolean().optional().describe("Clear the captured log after reading."),
  },
  "get_output"
);

tool(
  "focus_camera",
  "Point the Studio editor camera at an instance so the user (and a screenshot) can see it.",
  { path: path() },
  "focus_camera"
);

await server.connect(new StdioServerTransport());
console.error("[roblox-studio-mcp] MCP server ready on stdio");

--!nocheck
-- RobloxStudioMCP: lets Claude Code drive Roblox Studio.
-- It long-polls the roblox-studio-mcp server on localhost for commands, runs
-- them in the edit DataModel, and posts the results back.
--
-- Install: Studio > Plugins tab > Plugins Folder, copy this file in, restart Studio.

local PORT = 44755 -- must match ROBLOX_STUDIO_MCP_PORT on the server (default 44755)
local BASE_URL = "http://localhost:" .. PORT
local MAX_LOG = 1000

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local LogService = game:GetService("LogService")
local ScriptEditorService = game:GetService("ScriptEditorService")

-- Only the edit DataModel talks to Claude; playtest server/client copies of the plugin stay idle.
if not RunService:IsEdit() then
	return
end

local instanceId = HttpService:GenerateGUID(false)
local connected = false
local loopRunning = false

------------------------------------------------------------------------
-- Output capture
------------------------------------------------------------------------

local outputLog = {}
LogService.MessageOut:Connect(function(message, messageType)
	table.insert(outputLog, { message = message, type = messageType.Name, time = os.time() })
	if #outputLog > MAX_LOG then
		table.remove(outputLog, 1)
	end
end)

------------------------------------------------------------------------
-- Paths
------------------------------------------------------------------------

local function fullPath(inst)
	if inst == game then
		return "game"
	end
	return inst:GetFullName()
end

local function splitPath(path)
	local parts = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(parts, segment)
	end
	if parts[1] == "game" then
		table.remove(parts, 1)
	end
	return parts
end

local function resolve(path)
	if path == nil or path == "" or path == "game" then
		return game
	end
	local parts = splitPath(path)
	local current = game
	for i, segment in ipairs(parts) do
		local child = current:FindFirstChild(segment)
		if not child and i == 1 then
			local ok, service = pcall(game.GetService, game, segment)
			if ok then
				child = service
			end
		end
		if not child then
			error(string.format('"%s" not found under "%s" (path "%s")', segment, fullPath(current), path), 0)
		end
		current = child
	end
	return current
end

------------------------------------------------------------------------
-- Value conversion
------------------------------------------------------------------------

local function enumName(value)
	local s = tostring(value)
	return string.match(s, "([^%.]+)$") or s
end

local function toColor3(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		if string.sub(value, 1, 1) == "#" then
			return Color3.fromHex(value)
		end
		return BrickColor.new(value).Color
	end
	if type(value) == "table" then
		if value[1] ~= nil then
			return Color3.fromRGB(value[1], value[2], value[3])
		end
		if value.r or value.R then
			return Color3.fromRGB(value.r or value.R, value.g or value.G, value.b or value.B)
		end
	end
	error("expected a Color3 as [r,g,b] (0-255) or \"#hex\", got " .. HttpService:JSONEncode(value), 0)
end

local function toColorSequence(value)
	if type(value) ~= "table" or #value == 0 then
		return ColorSequence.new(toColor3(value))
	end
	-- [[time,[r,g,b]], ...] keypoints, or plain [[r,g,b], [r,g,b], ...] spread evenly
	if type(value[1]) == "table" and type(value[1][2]) == "table" then
		local keypoints = {}
		for _, kp in ipairs(value) do
			table.insert(keypoints, ColorSequenceKeypoint.new(kp[1], toColor3(kp[2])))
		end
		return ColorSequence.new(keypoints)
	end
	if type(value[1]) == "number" or type(value[1]) == "string" then
		return ColorSequence.new(toColor3(value))
	end
	if #value == 1 then
		return ColorSequence.new(toColor3(value[1]))
	end
	local keypoints = {}
	for i, c in ipairs(value) do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#value - 1), toColor3(c)))
	end
	return ColorSequence.new(keypoints)
end

local function toNumberSequence(value)
	if type(value) == "number" then
		return NumberSequence.new(value)
	end
	if type(value[1]) == "table" then
		local keypoints = {}
		for _, kp in ipairs(value) do
			table.insert(keypoints, NumberSequenceKeypoint.new(kp[1], kp[2], kp[3] or 0))
		end
		return NumberSequence.new(keypoints)
	end
	if #value == 1 then
		return NumberSequence.new(value[1])
	end
	local keypoints = {}
	for i, n in ipairs(value) do
		table.insert(keypoints, NumberSequenceKeypoint.new((i - 1) / (#value - 1), n))
	end
	return NumberSequence.new(keypoints)
end

local function toFont(value)
	if type(value) == "string" then
		local ok, item = pcall(function()
			return Enum.Font[enumName(value)]
		end)
		if ok and item then
			return Font.fromEnum(item)
		end
		return Font.fromName(value)
	end
	local weight = value.weight and Enum.FontWeight[enumName(value.weight)] or Enum.FontWeight.Regular
	local style = value.style and Enum.FontStyle[enumName(value.style)] or Enum.FontStyle.Normal
	local family = value.family or "SourceSansPro"
	if string.find(family, "://", 1, true) then
		return Font.new(family, weight, style)
	end
	return Font.fromName(family, weight, style)
end

local function toCFrame(value)
	local n = #value
	if n == 3 then
		return CFrame.new(value[1], value[2], value[3])
	elseif n == 6 then
		return CFrame.new(value[1], value[2], value[3])
			* CFrame.Angles(math.rad(value[4]), math.rad(value[5]), math.rad(value[6]))
	elseif n == 12 then
		return CFrame.new(table.unpack(value))
	end
	error("expected a CFrame as [x,y,z], [x,y,z,rx,ry,rz] or 12 numbers", 0)
end

-- Converts a JSON value to the type the property currently holds.
local function convert(current, value)
	local kind = typeof(current)
	if kind == "number" then
		return tonumber(value)
	elseif kind == "string" then
		return tostring(value)
	elseif kind == "boolean" then
		return value == true or value == "true"
	elseif kind == "Color3" then
		return toColor3(value)
	elseif kind == "BrickColor" then
		if type(value) == "table" or (type(value) == "string" and string.sub(value, 1, 1) == "#") then
			return BrickColor.new(toColor3(value))
		end
		return BrickColor.new(value)
	elseif kind == "Vector3" then
		return Vector3.new(value[1] or value.X or value.x, value[2] or value.Y or value.y, value[3] or value.Z or value.z)
	elseif kind == "Vector2" then
		return Vector2.new(value[1] or value.X or value.x, value[2] or value.Y or value.y)
	elseif kind == "UDim2" then
		if type(value[1]) == "table" then
			return UDim2.new(value[1][1], value[1][2], value[2][1], value[2][2])
		end
		return UDim2.new(value[1], value[2], value[3], value[4])
	elseif kind == "UDim" then
		return UDim.new(value[1], value[2])
	elseif kind == "CFrame" then
		return toCFrame(value)
	elseif kind == "EnumItem" then
		local item = current.EnumType[enumName(value)]
		return item
	elseif kind == "NumberRange" then
		if type(value) == "number" then
			return NumberRange.new(value)
		end
		return NumberRange.new(value[1], value[2] or value[1])
	elseif kind == "ColorSequence" then
		return toColorSequence(value)
	elseif kind == "NumberSequence" then
		return toNumberSequence(value)
	elseif kind == "Rect" then
		return Rect.new(value[1], value[2], value[3], value[4])
	elseif kind == "Font" then
		return toFont(value)
	elseif kind == "PhysicalProperties" then
		if value == nil or value == false or value == "default" then
			return nil
		end
		return PhysicalProperties.new(
			value.density or value[1],
			value.friction or value[2],
			value.elasticity or value[3],
			value.frictionWeight or value[4] or 1,
			value.elasticityWeight or value[5] or 1
		)
	elseif kind == "nil" and type(value) == "table" and value.density then
		-- CustomPhysicalProperties is nil until first set
		return PhysicalProperties.new(
			value.density,
			value.friction or 0.3,
			value.elasticity or 0.5,
			value.frictionWeight or 1,
			value.elasticityWeight or 1
		)
	elseif kind == "Instance" or kind == "nil" then
		if type(value) == "string" then
			local ok, inst = pcall(resolve, value)
			if ok then
				return inst
			end
			if kind == "Instance" then
				error(inst, 0)
			end
		end
		return value
	end
	return value
end

local function setAttribute(inst, name, value)
	if type(value) == "table" then
		if type(value.type) == "string" then
			local typed = {
				Color3 = function() return toColor3(value.value) end,
				Vector3 = function() return Vector3.new(table.unpack(value.value)) end,
				Vector2 = function() return Vector2.new(table.unpack(value.value)) end,
				UDim2 = function() return UDim2.new(table.unpack(value.value)) end,
				CFrame = function() return toCFrame(value.value) end,
			}
			local make = typed[value.type]
			if not make then
				error("unsupported attribute type " .. value.type, 0)
			end
			inst:SetAttribute(name, make())
			return
		end
		error(
			string.format('attribute "%s": use a number, string or boolean, or {type="Color3", value=[...]}', name),
			0
		)
	end
	inst:SetAttribute(name, value)
end

local function applyProperties(inst, properties)
	if not properties then
		return
	end
	local parentValue = nil
	for name, value in pairs(properties) do
		if name == "Attributes" then
			for attrName, attrValue in pairs(value) do
				setAttribute(inst, attrName, attrValue)
			end
		elseif name == "Parent" then
			parentValue = value
		elseif name == "Tags" then
			for _, tag in ipairs(value) do
				inst:AddTag(tag)
			end
		else
			local okRead, current = pcall(function()
				return inst[name]
			end)
			if not okRead then
				error(string.format('%s has no property "%s"', inst.ClassName, name), 0)
			end
			local okSet, err = pcall(function()
				inst[name] = convert(current, value)
			end)
			if not okSet then
				error(string.format('could not set %s.%s: %s', inst.ClassName, name, tostring(err)), 0)
			end
		end
	end
	if parentValue ~= nil then
		inst.Parent = resolve(parentValue)
	end
end

local function toJson(value, depth)
	depth = depth or 0
	local kind = typeof(value)
	if kind == "nil" then
		return "nil"
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return tostring(value)
		end
		return value
	elseif kind == "string" or kind == "boolean" then
		return value
	elseif kind == "Color3" then
		return { math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255) }
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "UDim" then
		return { value.Scale, value.Offset }
	elseif kind == "CFrame" then
		local rx, ry, rz = value:ToEulerAnglesXYZ()
		return { value.X, value.Y, value.Z, math.deg(rx), math.deg(ry), math.deg(rz) }
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "BrickColor" then
		return value.Name
	elseif kind == "Instance" then
		return fullPath(value)
	elseif kind == "Font" then
		return { family = value.Family, weight = value.Weight.Name, style = value.Style.Name }
	elseif kind == "NumberRange" then
		return { value.Min, value.Max }
	elseif kind == "ColorSequence" then
		local out = {}
		for _, kp in ipairs(value.Keypoints) do
			table.insert(out, { kp.Time, toJson(kp.Value) })
		end
		return out
	elseif kind == "NumberSequence" then
		local out = {}
		for _, kp in ipairs(value.Keypoints) do
			table.insert(out, { kp.Time, kp.Value })
		end
		return out
	elseif kind == "table" then
		if depth > 8 then
			return "<table>"
		end
		local out = {}
		for k, v in pairs(value) do
			out[type(k) == "number" and k or tostring(k)] = toJson(v, depth + 1)
		end
		return out
	end
	return tostring(value)
end

------------------------------------------------------------------------
-- Undo recording
------------------------------------------------------------------------

local function recorded(name, fn)
	local recording = ChangeHistoryService:TryBeginRecording("Claude: " .. name)
	local ok, result = pcall(fn)
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end
	if not ok then
		error(result, 0)
	end
	return result
end

local function createFromSpec(spec)
	local inst = Instance.new(spec.className)
	if spec.name then
		inst.Name = spec.name
	end
	applyProperties(inst, spec.properties)
	return inst
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------

local COMMON_PROPERTIES = {
	"Name", "ClassName", "Parent", "Archivable",
	-- parts and models
	"Position", "Orientation", "Size", "CFrame", "Color", "BrickColor", "Material", "Transparency",
	"Anchored", "CanCollide", "CanTouch", "Shape", "Reflectance", "CastShadow", "MeshId", "TextureID",
	"PrimaryPart", "WorldPivot",
	-- GUI
	"Enabled", "ResetOnSpawn", "ZIndexBehavior", "IgnoreGuiInset", "ScreenInsets", "DisplayOrder",
	"AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "Visible", "ZIndex",
	"LayoutOrder", "ClipsDescendants", "AutomaticSize", "Rotation",
	"Text", "TextColor3", "TextScaled", "TextSize", "Font", "FontFace", "TextWrapped",
	"TextXAlignment", "TextYAlignment", "TextStrokeTransparency", "RichText",
	"Image", "ImageColor3", "ImageTransparency", "ScaleType", "TileSize",
	"CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollingDirection",
	"CornerRadius", "Thickness", "ApplyStrokeMode", "LineJoinMode", "AspectRatio", "AspectType", "DominantAxis",
	"MaxSize", "MinSize", "Scale", "Offset", "CellSize", "CellPadding", "Padding", "FillDirection",
	"HorizontalAlignment", "VerticalAlignment", "SortOrder",
	-- scripts, lights, sounds, values
	"RunContext", "Disabled", "Brightness", "Range", "SoundId", "Volume", "Looped", "Playing", "Value",
}

local handlers = {}

function handlers.place_info()
	local services = {}
	for _, child in ipairs(game:GetChildren()) do
		local ok, name = pcall(function()
			return child.Name
		end)
		if ok then
			table.insert(services, name)
		end
	end
	table.sort(services)
	return {
		placeName = game.Name,
		placeId = game.PlaceId,
		gameId = game.GameId,
		isEdit = RunService:IsEdit(),
		services = services,
	}
end

function handlers.get_tree(args)
	local root = resolve(args.path)
	local maxDepth = args.depth or 2
	local maxChildren = args.maxChildren or 100

	local function node(inst, depth)
		local ok, children = pcall(inst.GetChildren, inst)
		children = ok and children or {}
		local out = { name = inst.Name, className = inst.ClassName, childCount = #children }
		if depth < maxDepth and #children > 0 then
			out.children = {}
			for i, child in ipairs(children) do
				if i > maxChildren then
					out.truncated = true
					break
				end
				local okChild, childNode = pcall(node, child, depth + 1)
				if okChild then
					table.insert(out.children, childNode)
				end
			end
		end
		return out
	end

	local tree = node(root, 0)
	tree.path = fullPath(root)
	return tree
end

function handlers.find(args)
	local root = resolve(args.root)
	local limit = args.limit or 200
	local needle = args.nameContains and string.lower(args.nameContains)
	local results = {}
	for _, inst in ipairs(root:GetDescendants()) do
		local ok, match = pcall(function()
			return (not args.className or inst:IsA(args.className))
				and (not needle or string.find(string.lower(inst.Name), needle, 1, true) ~= nil)
		end)
		if ok and match then
			table.insert(results, { path = fullPath(inst), className = inst.ClassName })
			if #results >= limit then
				break
			end
		end
	end
	return { count = #results, results = results }
end

function handlers.get_properties(args)
	local inst = resolve(args.path)
	local names = args.properties or COMMON_PROPERTIES
	local props = {}
	local missing = {}
	for _, name in ipairs(names) do
		local ok, value = pcall(function()
			return inst[name]
		end)
		if ok and typeof(value) ~= "RBXScriptSignal" and typeof(value) ~= "function" then
			props[name] = toJson(value)
		elseif args.properties then
			table.insert(missing, name)
		end
	end
	local attributes = {}
	for name, value in pairs(inst:GetAttributes()) do
		attributes[name] = toJson(value)
	end
	return {
		path = fullPath(inst),
		className = inst.ClassName,
		properties = props,
		attributes = attributes,
		tags = inst:GetTags(),
		missing = #missing > 0 and missing or nil,
	}
end

function handlers.set_properties(args)
	return recorded("Set properties", function()
		local changed = {}
		for _, path in ipairs(args.paths) do
			local inst = resolve(path)
			applyProperties(inst, args.properties)
			table.insert(changed, fullPath(inst))
		end
		return { changed = changed }
	end)
end

function handlers.create_instance(args)
	return recorded("Create " .. args.className, function()
		local inst = createFromSpec(args)
		inst.Parent = resolve(args.parent)
		return { path = fullPath(inst) }
	end)
end

function handlers.mass_create(args)
	return recorded("Create objects", function()
		local paths = {}
		for i, spec in ipairs(args.objects) do
			if not spec.parent then
				error(string.format("objects[%d] (%s) needs a parent", i, spec.className), 0)
			end
			local ok, result = pcall(function()
				local inst = createFromSpec(spec)
				inst.Parent = resolve(spec.parent)
				return fullPath(inst)
			end)
			if not ok then
				error(string.format("objects[%d] (%s): %s", i, spec.className, tostring(result)), 0)
			end
			table.insert(paths, result)
		end
		return { created = #paths, paths = paths }
	end)
end

function handlers.create_ui_tree(args)
	return recorded("Create UI", function()
		local count = 0
		local function build(node, where)
			count += 1
			local ok, inst = pcall(createFromSpec, node)
			if not ok then
				error(string.format("%s > %s (%s): %s", where, node.name or "?", node.className, tostring(inst)), 0)
			end
			for _, child in ipairs(node.children or {}) do
				build(child, where .. "." .. (node.name or node.className)).Parent = inst
			end
			return inst
		end
		local root = build(args.tree, args.parent)
		root.Parent = resolve(args.parent)
		return { path = fullPath(root), created = count }
	end)
end

function handlers.delete(args)
	return recorded("Delete", function()
		local deleted = {}
		for _, path in ipairs(args.paths) do
			local inst = resolve(path)
			if inst == game or inst.Parent == game then
				error("refusing to delete " .. fullPath(inst), 0)
			end
			table.insert(deleted, fullPath(inst))
			inst:Destroy()
		end
		return { deleted = deleted }
	end)
end

function handlers.clone(args)
	return recorded("Clone", function()
		local source = resolve(args.path)
		local wasArchivable = source.Archivable
		source.Archivable = true
		local copy = source:Clone()
		source.Archivable = wasArchivable
		if args.name then
			copy.Name = args.name
		end
		copy.Parent = args.parent and resolve(args.parent) or source.Parent
		return { path = fullPath(copy) }
	end)
end

function handlers.get_source(args)
	local inst = resolve(args.path)
	if not inst:IsA("LuaSourceContainer") then
		error(fullPath(inst) .. " is a " .. inst.ClassName .. ", not a script", 0)
	end
	return { path = fullPath(inst), className = inst.ClassName, source = inst.Source }
end

function handlers.set_source(args)
	return recorded("Edit script", function()
		local ok, inst = pcall(resolve, args.path)
		local created = false
		if not ok then
			local parts = splitPath(args.path)
			local name = table.remove(parts)
			local parent = resolve(table.concat(parts, "."))
			inst = Instance.new(args.className or "Script")
			inst.Name = name
			inst.Parent = parent
			created = true
		elseif not inst:IsA("LuaSourceContainer") then
			error(fullPath(inst) .. " is a " .. inst.ClassName .. ", not a script", 0)
		end
		local okEditor = pcall(function()
			ScriptEditorService:UpdateSourceAsync(inst, function()
				return args.source
			end)
		end)
		if not okEditor then
			inst.Source = args.source
		end
		return { path = fullPath(inst), className = inst.ClassName, created = created }
	end)
end

function handlers.execute(args)
	local fn, compileError = loadstring(args.code, "=execute_luau")
	if not fn then
		error("compile error: " .. tostring(compileError), 0)
	end

	local output = {}
	local function capture(kind)
		return function(...)
			local pieces = table.pack(...)
			for i = 1, pieces.n do
				pieces[i] = tostring(pieces[i])
			end
			local line = table.concat(pieces, "\t", 1, pieces.n)
			table.insert(output, kind == "print" and line or ("[" .. kind .. "] " .. line))
			if kind == "warn" then
				warn(line)
			else
				print(line)
			end
		end
	end
	local env = setmetatable({ print = capture("print"), warn = capture("warn") }, { __index = getfenv() })
	setfenv(fn, env)

	return recorded("Run Luau", function()
		local done, results = false, nil
		local thread = task.spawn(function()
			results = table.pack(xpcall(fn, function(err)
				return debug.traceback(tostring(err), 2)
			end))
			done = true
		end)
		local deadline = os.clock() + (args.timeoutSeconds or 60)
		while not done and os.clock() < deadline do
			task.wait(0.05)
		end
		if not done then
			pcall(task.cancel, thread)
			error("timed out after " .. (args.timeoutSeconds or 60) .. "s. Output so far:\n" .. table.concat(output, "\n"), 0)
		end
		if not results[1] then
			error(tostring(results[2]) .. (#output > 0 and ("\nOutput:\n" .. table.concat(output, "\n")) or ""), 0)
		end
		local returns = {}
		for i = 2, results.n do
			table.insert(returns, toJson(results[i]))
		end
		return { output = table.concat(output, "\n"), returns = returns }
	end)
end

function handlers.get_selection()
	local paths = {}
	for _, inst in ipairs(Selection:Get()) do
		table.insert(paths, { path = fullPath(inst), className = inst.ClassName })
	end
	return paths
end

function handlers.set_selection(args)
	local list = {}
	for _, path in ipairs(args.paths) do
		table.insert(list, resolve(path))
	end
	Selection:Set(list)
	return { selected = #list }
end

function handlers.get_output(args)
	local limit = args.limit or 100
	local from = math.max(1, #outputLog - limit + 1)
	local out = {}
	for i = from, #outputLog do
		table.insert(out, outputLog[i])
	end
	if args.clear then
		table.clear(outputLog)
	end
	return out
end

function handlers.focus_camera(args)
	local inst = resolve(args.path)
	local cframe, size
	if inst:IsA("BasePart") then
		cframe, size = inst.CFrame, inst.Size
	elseif inst:IsA("Model") then
		cframe, size = inst:GetBoundingBox()
	else
		error("focus_camera needs a BasePart or Model, got " .. inst.ClassName, 0)
	end
	local camera = workspace.CurrentCamera
	local distance = math.max(size.Magnitude * 1.2, 8)
	local target = cframe.Position
	camera.CFrame = CFrame.lookAt(target + Vector3.new(1, 0.6, 1).Unit * distance, target)
	camera.Focus = CFrame.new(target)
	Selection:Set({ inst })
	return { focused = fullPath(inst) }
end

------------------------------------------------------------------------
-- Connection loop
------------------------------------------------------------------------

local function post(payload)
	local okEncode, body = pcall(HttpService.JSONEncode, HttpService, payload)
	if not okEncode then
		body = HttpService:JSONEncode({ id = payload.id, ok = false, error = "result could not be encoded as JSON" })
	end
	local ok, err = pcall(HttpService.RequestAsync, HttpService, {
		Url = BASE_URL .. "/result",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})
	if not ok then
		warn("[MCP] could not send result: " .. tostring(err))
	end
end

local function runCommand(command)
	local handler = handlers[command.type]
	if not handler then
		post({ id = command.id, ok = false, error = "unknown command " .. tostring(command.type) })
		return
	end
	local ok, result = xpcall(handler, function(err)
		return tostring(err)
	end, command.args or {})
	if ok then
		post({ id = command.id, ok = true, result = result })
	else
		post({ id = command.id, ok = false, error = result })
	end
end

local toolbar = plugin:CreateToolbar("MCP")
local button = toolbar:CreateButton("Connect", "Connect Roblox Studio to Claude Code", "")
button.ClickableWhenViewportHidden = true

local function pollUrl()
	return string.format(
		"%s/poll?instanceId=%s&placeName=%s&placeId=%d&gameId=%d",
		BASE_URL,
		instanceId,
		HttpService:UrlEncode(game.Name),
		game.PlaceId,
		game.GameId
	)
end

local function loop()
	if loopRunning then
		return
	end
	loopRunning = true
	local reachable = nil
	local backoff = 1
	while connected do
		local ok, response = pcall(HttpService.RequestAsync, HttpService, { Url = pollUrl(), Method = "GET" })
		if ok then
			if reachable ~= true then
				print("[MCP] Connected to Claude Code (" .. BASE_URL .. ")")
				reachable = true
			end
			backoff = 1
			if response.StatusCode == 200 then
				local okDecode, command = pcall(HttpService.JSONDecode, HttpService, response.Body)
				if okDecode and type(command) == "table" then
					task.spawn(runCommand, command)
				end
			end
		else
			if reachable ~= false then
				print("[MCP] Waiting for Claude Code on " .. BASE_URL .. " (start a Claude Code session with the robloxstudio-mcp server)")
				reachable = false
			end
			task.wait(backoff)
			backoff = math.min(backoff * 2, 5)
		end
	end
	loopRunning = false
end

local function setConnected(value)
	connected = value
	button:SetActive(value)
	plugin:SetSetting("RobloxStudioMCP_Enabled", value)
	if value then
		task.spawn(loop)
	else
		print("[MCP] Disconnected from Claude Code")
	end
end

button.Click:Connect(function()
	setConnected(not connected)
end)

plugin.Unloading:Connect(function()
	connected = false
end)

-- Connect automatically unless the user switched it off last time.
setConnected(plugin:GetSetting("RobloxStudioMCP_Enabled") ~= false)

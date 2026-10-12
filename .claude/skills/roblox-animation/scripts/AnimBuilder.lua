-- AnimBuilder: make a Roblox animation (KeyframeSequence) from a list of poses, for R6 or R15 rigs.
-- Run from the Studio plugin (robloxstudio-mcp) or the command bar. It saves the animation into
-- rig.AnimSaves so it shows up in the Animation Editor, ready to tweak and publish.
--
--   local AnimBuilder = require(path.to.AnimBuilder)
--   AnimBuilder.build(workspace.Rig, "Wave", {
--       { time = 0,   poses = {} },                                        -- rest pose
--       { time = 0.2, poses = { RightUpperArm = { rot = { 0, 0, 150 } } }, ease = "Back" },
--       { time = 0.4, poses = { RightUpperArm = { rot = { 0, 0, 120 } }, RightLowerArm = { rot = { 0, 0, 30 } } } },
--   }, { loop = true, priority = Enum.AnimationPriority.Action })
--
-- rot = degrees {x, y, z} and pos = studs {x, y, z}, relative to the rest pose of that joint.
-- Joints not listed in a keyframe stay at rest for that keyframe.
-- ease = "Linear" | "Constant" | "Cubic" | "Elastic" | "Bounce" | "Back" (default "Cubic"), with dir = "In" | "Out" | "InOut".

local AnimBuilder = {}

-- Build { childPartName = parentPartName } from the rig's Motor6Ds (works for R6, R15 and custom rigs).
local function jointTree(rig: Model)
	local parentOf = {}
	for _, joint in rig:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			parentOf[joint.Part1.Name] = joint.Part0.Name
		end
	end
	return parentOf
end

local function toCFrame(spec)
	if not spec then
		return CFrame.identity
	end
	local p = spec.pos or { 0, 0, 0 }
	local r = spec.rot or { 0, 0, 0 }
	return CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

local function makePose(name: string, spec, ease: string?, dir: string?): Pose
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.CFrame = toCFrame(spec)
	pose.Weight = 1
	local okStyle, style = pcall(function()
		return Enum.PoseEasingStyle[ease or "Cubic"]
	end)
	pose.EasingStyle = okStyle and style or Enum.PoseEasingStyle.Cubic
	local okDir, direction = pcall(function()
		return Enum.PoseEasingDirection[dir or "InOut"]
	end)
	pose.EasingDirection = okDir and direction or Enum.PoseEasingDirection.InOut
	return pose
end

function AnimBuilder.build(rig: Model, name: string, keyframes, options)
	options = options or {}
	local parentOf = jointTree(rig)
	local root = rig:FindFirstChild("HumanoidRootPart")
	assert(root, "Rig needs a HumanoidRootPart")

	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = options.loop == true
	seq.Priority = options.priority or Enum.AnimationPriority.Action

	for _, key in keyframes do
		local kf = Instance.new("Keyframe")
		kf.Time = key.time
		local poses = { [root.Name] = makePose(root.Name, (key.poses or {})[root.Name], key.ease, key.dir) }
		-- Every joint gets a pose so the tree is complete; unlisted ones sit at rest.
		local function poseFor(partName: string): Pose
			if poses[partName] then
				return poses[partName]
			end
			local pose = makePose(partName, (key.poses or {})[partName], key.ease, key.dir)
			poses[partName] = pose
			local parentName = parentOf[partName]
			pose.Parent = if parentName then poseFor(parentName) else poses[root.Name]
			return pose
		end
		for partName in parentOf do
			poseFor(partName)
		end
		poses[root.Name].Parent = kf
		if key.marker then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = key.marker
			kf:AddMarker(marker)
		end
		kf.Parent = seq
	end

	local saves = rig:FindFirstChild("AnimSaves")
	if not saves then
		saves = Instance.new("ObjectValue")
		saves.Name = "AnimSaves"
		saves.Parent = rig
	end
	local old = saves:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	seq.Parent = saves
	return seq
end

-- Temporary id for testing in Studio only (not in a live game). Publish from the Animation Editor for a real id.
function AnimBuilder.previewId(seq: KeyframeSequence): string
	return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(seq)
end

return AnimBuilder

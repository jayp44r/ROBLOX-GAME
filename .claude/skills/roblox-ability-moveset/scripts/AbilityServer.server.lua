-- AbilityServer: Script in ServerScriptService. Owns cooldowns, hit detection and damage,
-- then tells every client which effect to draw.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AbilityConfig"))

local remotes = Instance.new("Folder")
remotes.Name = "AbilityRemotes"
local castRemote = Instance.new("RemoteEvent")
castRemote.Name = "Cast"
castRemote.Parent = remotes
local effectRemote = Instance.new("RemoteEvent")
effectRemote.Name = "Effect"
effectRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local byId = {}
for _, ability in Config.abilities do
	byId[ability.id] = ability
end

local readyAt: { [Player]: { [string]: number } } = {}
Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Living humanoids (players or NPCs) within radius of a point, except the caster.
local function enemiesNear(caster: Model, position: Vector3, radius: number): { Humanoid }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	local found, list = {}, {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not found[humanoid] then
			found[humanoid] = true
			table.insert(list, humanoid)
		end
	end
	return list
end

local function hit(humanoid: Humanoid, damage: number)
	local before = humanoid.Health
	humanoid:TakeDamage(damage) -- respects ForceField, so Shield blocks it
	local dealt = before - humanoid.Health
	local root = rootOf(humanoid.Parent :: Model)
	if dealt > 0 and root then
		effectRemote:FireAllClients("damage", { position = root.Position + Vector3.new(0, 3, 0), amount = math.floor(dealt + 0.5) })
	end
end

local function knockback(humanoid: Humanoid, from: Vector3, power: number)
	local root = rootOf(humanoid.Parent :: Model)
	if not root then
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
	root.AssemblyLinearVelocity = dir * power + Vector3.new(0, power * 0.5, 0)
end

local function stun(humanoid: Humanoid, seconds: number)
	if humanoid:GetAttribute("Stunned") then
		return
	end
	humanoid:SetAttribute("Stunned", true)
	local speed, jump = humanoid.WalkSpeed, humanoid.JumpPower
	humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.WalkSpeed, humanoid.JumpPower = speed, jump
			humanoid:SetAttribute("Stunned", nil)
		end
	end)
end

local function ticks(ability, caster: Model, getCenter: () -> Vector3?)
	task.spawn(function()
		for _ = 1, ability.ticks do
			local center = getCenter()
			if not center then
				return
			end
			for _, humanoid in enemiesNear(caster, center, ability.radius) do
				hit(humanoid, ability.damage)
			end
			task.wait(ability.tickTime)
		end
	end)
end

local handlers = {}

function handlers.burst(ability, caster: Model, root: BasePart)
	effectRemote:FireAllClients("burst", { origin = root.Position, radius = ability.radius, caster = caster })
	task.wait(0.15) -- let the circle appear before the hit lands
	for _, humanoid in enemiesNear(caster, root.Position, ability.radius) do
		hit(humanoid, ability.damage)
		knockback(humanoid, root.Position, ability.knockback)
	end
end

function handlers.chain(ability, caster: Model, root: BasePart, aim: Vector3)
	local best, bestDist = nil, math.huge
	for _, humanoid in enemiesNear(caster, root.Position, ability.range) do
		local targetRoot = rootOf(humanoid.Parent :: Model)
		if targetRoot then
			local d = (targetRoot.Position - aim).Magnitude
			if d < bestDist then
				best, bestDist = humanoid, d
			end
		end
	end
	effectRemote:FireAllClients("chain", { caster = caster, target = best and best.Parent, duration = ability.stun })
	if best then
		hit(best, ability.damage)
		stun(best, ability.stun)
	end
end

function handlers.aura(ability, caster: Model, root: BasePart)
	local duration = ability.ticks * ability.tickTime
	effectRemote:FireAllClients("aura", { caster = caster, radius = ability.radius, duration = duration })
	ticks(ability, caster, function()
		return root.Parent and root.Position or nil
	end)
end

function handlers.shield(ability, caster: Model)
	effectRemote:FireAllClients("shield", { caster = caster, duration = ability.duration })
	local field = Instance.new("ForceField")
	field.Visible = false
	field.Parent = caster
	task.delay(ability.duration, function()
		field:Destroy()
	end)
end

function handlers.storm(ability, caster: Model, root: BasePart)
	local center = root.Position
	local duration = ability.ticks * ability.tickTime
	effectRemote:FireAllClients("storm", { origin = center, radius = ability.radius, duration = duration, caster = caster })
	ticks(ability, caster, function()
		return center
	end)
end

function handlers.bolt(ability, caster: Model, root: BasePart, aim: Vector3)
	local start = root.Position + Vector3.new(0, 1.5, 0)
	local toAim = aim - start
	if toAim.Magnitude < 0.1 then
		toAim = root.CFrame.LookVector
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	local result = workspace:Raycast(start, toAim.Unit * ability.range, params)
	local finish = if result then result.Position else start + toAim.Unit * ability.range
	local travel = (finish - start).Magnitude / ability.speed
	effectRemote:FireAllClients("bolt", { from = start, to = finish, travel = travel, radius = ability.radius })
	task.wait(travel)
	for _, humanoid in enemiesNear(caster, finish, ability.radius) do
		hit(humanoid, ability.damage)
	end
end

castRemote.OnServerEvent:Connect(function(player, id, aim)
	local ability = byId[id]
	if type(id) ~= "string" or not ability then
		return
	end
	if typeof(aim) ~= "Vector3" then
		aim = Vector3.zero
	end
	local caster = player.Character
	local root = rootOf(caster)
	local humanoid = caster and caster:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or humanoid:GetAttribute("Stunned") then
		return
	end

	local now = os.clock()
	readyAt[player] = readyAt[player] or {}
	if (readyAt[player][id] or 0) > now + 0.1 then -- small grace for latency
		return
	end
	readyAt[player][id] = now + ability.cooldown

	local handler = handlers[ability.kind]
	if handler then
		handler(ability, caster, root, aim)
	end
end)

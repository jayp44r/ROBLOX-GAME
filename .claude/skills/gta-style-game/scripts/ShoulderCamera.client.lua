-- GTA-style over-the-shoulder aim while holding a weapon.
-- LocalScript in StarterPlayer > StarterPlayerScripts.
-- With a Tool equipped: camera shifts over the right shoulder, the character turns with the camera,
-- the mouse locks to the centre (PC) and a crosshair dot appears.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OFFSET = Vector3.new(2, 0.4, 0) -- right, up, back (studs)

local gui = Instance.new("ScreenGui")
gui.Name = "Crosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(8, 8)
dot.BackgroundTransparency = 1
dot.Visible = false
dot.Parent = gui
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
local ring = Instance.new("UIStroke")
ring.Color = Color3.new(1, 1, 1)
ring.Thickness = 1.5
ring.Parent = dot

local function wheelOpen(): boolean
	local wheelGui = player.PlayerGui:FindFirstChild("WeaponWheel")
	local wheel = wheelGui and wheelGui:FindFirstChild("Wheel")
	return wheel ~= nil and wheel.Visible
end

local aiming = false

RunService:BindToRenderStep("ShoulderCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local holding = character:FindFirstChildOfClass("Tool") ~= nil
	if holding ~= aiming then
		aiming = holding
		humanoid.AutoRotate = not aiming
		dot.Visible = aiming
		TweenService:Create(humanoid, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			CameraOffset = if aiming then OFFSET else Vector3.zero,
		}):Play()
		if not aiming then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	if aiming then
		if not wheelOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		-- Face where the camera looks (yaw only).
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
end)

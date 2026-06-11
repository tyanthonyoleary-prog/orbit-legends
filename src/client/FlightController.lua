-- FlightController
-- Arcade-style flight: the mouse steers (locked to screen center), W/S
-- throttles, Space/Ctrl strafe vertically. The client owns the ship's physics
-- (network ownership granted by the server when seated), so it drives the
-- LinearVelocity / AlignOrientation constraints directly every frame.
-- All combat-relevant numbers stay server-side; this module only moves the ship.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MOUSE_SENSITIVITY = 0.0035
local PITCH_LIMIT = math.rad(80)

local FlightController = {}

local ship, root, lv, ao
local yaw, pitch = 0, 0
local speed = 0
local throttle = 0
local verticalInput = 0
local stepConnection

local function stopFlying()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	if lv then
		lv.VectorVelocity = Vector3.zero
	end
	ship, root, lv, ao = nil, nil, nil, nil
	speed, throttle, verticalInput = 0, 0, 0
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	ClientState.setShip(nil)
end

local function step(dt: number)
	if not (ship and ship.Parent and root and root.Parent) then
		stopFlying()
		return
	end

	-- Menus need the cursor; flight wants it locked. Resolve every frame.
	UserInputService.MouseBehavior = ClientState.menuOpen and Enum.MouseBehavior.Default
		or Enum.MouseBehavior.LockCenter

	local maxSpeed = ship:GetAttribute("MaxSpeed") or 100
	local acceleration = ship:GetAttribute("Acceleration") or 50

	local targetSpeed = throttle * maxSpeed
	if speed < targetSpeed then
		speed = math.min(speed + acceleration * dt, targetSpeed)
	elseif speed > targetSpeed then
		speed = math.max(speed - acceleration * 1.5 * dt, targetSpeed)
	end

	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	ao.CFrame = rotation
	lv.VectorVelocity = rotation.LookVector * speed
		+ Vector3.new(0, verticalInput * maxSpeed * 0.35, 0)

	-- Chase camera scaled to ship size.
	local extent = root.Size.Magnitude
	local camPos = root.Position
		- rotation.LookVector * (extent * 1.6 + 12)
		+ rotation.UpVector * (extent * 0.6 + 5)
	camera.CFrame = CFrame.lookAt(camPos, root.Position + rotation.LookVector * 80)
end

local function startFlying(model: Model)
	root = model.PrimaryPart
	lv = root and root:FindFirstChild("FlightVelocity")
	ao = root and root:FindFirstChild("FlightOrientation")
	if not (root and lv and ao) then
		return
	end
	ship = model

	-- Seed aim from the ship's current heading so it doesn't snap.
	local look = root.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))
	speed = 0
	throttle = 0

	camera.CameraType = Enum.CameraType.Scriptable
	ClientState.setShip(model)
	stepConnection = RunService.RenderStepped:Connect(step)
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not ship then
		return
	end
	if input.KeyCode == Enum.KeyCode.W then
		throttle = 1
	elseif input.KeyCode == Enum.KeyCode.S then
		throttle = -0.4
	elseif input.KeyCode == Enum.KeyCode.Space then
		verticalInput = 1
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		verticalInput = -1
	end
end

local function onInputEnded(input: InputObject)
	if input.KeyCode == Enum.KeyCode.W and throttle > 0 then
		throttle = 0
	elseif input.KeyCode == Enum.KeyCode.S and throttle < 0 then
		throttle = 0
	elseif input.KeyCode == Enum.KeyCode.Space and verticalInput > 0 then
		verticalInput = 0
	elseif input.KeyCode == Enum.KeyCode.LeftControl and verticalInput < 0 then
		verticalInput = 0
	end
end

local function onInputChanged(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseMovement and ship and not ClientState.menuOpen then
		yaw -= input.Delta.X * MOUSE_SENSITIVITY
		pitch = math.clamp(pitch - input.Delta.Y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	end
end

local function watchCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local seat = humanoid.SeatPart
		local model = seat and seat.Parent
		if model and model:IsA("Model")
			and CollectionService:HasTag(model, "Ship")
			and model:GetAttribute("OwnerId") == player.UserId then
			startFlying(model)
		else
			stopFlying()
		end
	end)
	humanoid.Died:Connect(stopFlying)
end

function FlightController.init()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)

	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return FlightController

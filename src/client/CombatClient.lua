-- CombatClient
-- Sends fire requests (hold left mouse) and renders beam/hit effects for
-- everyone's shots. The server does all validation and damage; the local
-- fire-rate check here just avoids flooding the remote.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local ClientState = require(script.Parent.ClientState)

local camera = workspace.CurrentCamera

local CombatClient = {}

local firing = false
local lastFire = 0

local function tryFire()
	local ship = ClientState.ship
	if not (ship and ship.Parent) or ClientState.menuOpen then
		return
	end

	local weapon = GameConfig.Weapons[ship:GetAttribute("Weapon")] or GameConfig.Weapons.BasicLaser
	local fireRate = (ship:GetAttribute("FireRate") or 1) * weapon.fireRateMult
	local now = os.clock()
	if now - lastFire < 1 / fireRate then
		return
	end
	lastFire = now

	-- Aim straight down the camera reticle.
	local aimPoint = camera.CFrame.Position + camera.CFrame.LookVector * 3000
	Remotes.get("FireWeapon"):FireServer(aimPoint)
end

local function renderBeam(origin: Vector3, endPos: Vector3, weaponName: string)
	local weapon = GameConfig.Weapons[weaponName] or GameConfig.Weapons.BasicLaser
	local length = (endPos - origin).Magnitude
	if length < 0.5 then
		return
	end

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = weapon.beamColor
	beam.Size = Vector3.new(0.5, 0.5, length)
	beam.CFrame = CFrame.lookAt((origin + endPos) / 2, endPos)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.08)

	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = weapon.beamColor
	flash.Size = Vector3.new(3, 3, 3)
	flash.CFrame = CFrame.new(endPos)
	flash.Transparency = 0.3
	flash.Parent = workspace
	Debris:AddItem(flash, 0.12)
end

function CombatClient.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if firing then
			tryFire()
		end
	end)

	Remotes.get("BeamFX").OnClientEvent:Connect(renderBeam)
end

return CombatClient

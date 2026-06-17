-- MiningSystem
-- Automatic proximity mining: when a piloted ship is nearly stationary within
-- range of an asteroid, resources flow into cargo every tick with the
-- secured/unsecured split applied. Asteroids shrink as they deplete and
-- respawn elsewhere in their field after a delay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local ResourceSystem = require(script.Parent.ResourceSystem)
local WorldGen = require(script.Parent.WorldGen)

local MiningSystem = {}

local function isPiloted(profile, player: Player): boolean
	local ship = profile.ship
	if not (ship and ship.Parent and ship.PrimaryPart) then
		return false
	end
	local seat = ship:FindFirstChild("PilotSeat")
	local occupant = seat and seat.Occupant
	return occupant ~= nil and occupant.Parent == player.Character
end

local function nearestAsteroid(position: Vector3): BasePart?
	local best, bestDist = nil, GameConfig.Mining.Range
	for _, asteroid in ipairs(WorldGen.getAsteroidFolder():GetChildren()) do
		if asteroid:IsA("BasePart") and (asteroid:GetAttribute("Yield") or 0) > 0 then
			-- distance to the asteroid's surface, roughly
			local dist = (asteroid.Position - position).Magnitude - asteroid.Size.Magnitude / 2
			if dist < bestDist then
				best, bestDist = asteroid, dist
			end
		end
	end
	return best
end

local function setMiningState(player: Player, profile, resource: string?)
	if profile.miningResource ~= resource then
		profile.miningResource = resource
		Remotes.get("MiningState"):FireClient(player, { active = resource ~= nil, resource = resource })
	end
end

local function tick(dt: number)
	for player, profile in pairs(DataSystem.all()) do
		if not isPiloted(profile, player) then
			setMiningState(player, profile, nil)
			continue
		end

		local root = profile.ship.PrimaryPart
		if root.AssemblyLinearVelocity.Magnitude > GameConfig.Mining.MaxSpeedToMine then
			setMiningState(player, profile, nil)
			continue
		end

		local asteroid = nearestAsteroid(root.Position)
		if not asteroid then
			setMiningState(player, profile, nil)
			continue
		end

		local resType = asteroid:GetAttribute("ResourceType")
		local rate = profile.ship:GetAttribute("MiningRate") or 1
		local available = asteroid:GetAttribute("Yield") or 0
		local mined = ResourceSystem.addMined(profile, resType, math.min(rate * dt, available))

		if mined <= 0 then
			-- Cargo hold is full.
			setMiningState(player, profile, nil)
			if not profile.notifiedFull then
				profile.notifiedFull = true
				DataSystem.notify(player, "Cargo hold full — return to your base to sell.", "info")
			end
			continue
		end
		profile.notifiedFull = false
		setMiningState(player, profile, resType)

		-- Deplete and shrink the asteroid.
		local remaining = available - mined
		asteroid:SetAttribute("Yield", remaining)
		local maxYield = asteroid:GetAttribute("MaxYield") or 1
		local baseSize = asteroid:GetAttribute("BaseSize") or asteroid.Size
		asteroid.Size = baseSize * (0.35 + 0.65 * math.max(remaining, 0) / maxYield)

		if remaining <= 0.01 then
			WorldGen.scheduleRespawn(asteroid:GetAttribute("FieldIndex") or 1)
			asteroid:Destroy()
		end
	end
end

function MiningSystem.init()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= GameConfig.Mining.TickSeconds then
			local step = accumulator
			accumulator = 0
			tick(step)
		end
	end)
end

return MiningSystem

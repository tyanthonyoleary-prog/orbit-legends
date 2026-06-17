-- ShipSystem
-- Spawns, configures and destroys player ships. The server computes all stats
-- from GameConfig + the player's upgrades and writes them onto the model as
-- attributes; flight physics are client-owned (network ownership) for
-- responsiveness, while combat numbers stay server-authoritative.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local ShipStats = require(Shared.ShipStats)

local DataSystem = require(script.Parent.DataSystem)
local ResourceSystem = require(script.Parent.ResourceSystem)
local ShipBuilder = require(script.Parent.ShipBuilder)
local WorldGen = require(script.Parent.WorldGen)
local ZoneSystem = require(script.Parent.ZoneSystem)

local ShipSystem = {}


local function applyStats(ship: Model, stats)
	ship:SetAttribute("MaxSpeed", stats.maxSpeed)
	ship:SetAttribute("Acceleration", stats.acceleration)
	ship:SetAttribute("TurnSpeed", stats.turnSpeed)
	ship:SetAttribute("MaxShield", stats.maxShield)
	ship:SetAttribute("ShieldRegen", stats.shieldRegen)
	ship:SetAttribute("MaxHull", stats.maxHull)
	ship:SetAttribute("CargoCapacity", stats.cargoCapacity)
	ship:SetAttribute("MiningRate", stats.miningRate)
	ship:SetAttribute("Damage", stats.damage)
	ship:SetAttribute("FireRate", stats.fireRate)
	ship:SetAttribute("EnergyMax", stats.energyMax)
	ship:SetAttribute("EnergyRegen", stats.energyRegen)
	ship:SetAttribute("Weapon", stats.weapon)

	local root = ship.PrimaryPart
	local ao = root and root:FindFirstChild("FlightOrientation")
	if ao then
		ao.Responsiveness = stats.turnSpeed
	end
end

-- Re-apply stats after an upgrade purchase (keeps current shield/hull, clamped to new max).
function ShipSystem.applyNewStats(player: Player)
	local profile = DataSystem.get(player)
	local ship = profile and profile.ship
	if not (ship and ship.Parent) then
		return
	end
	local stats = ShipStats.compute(profile.data.selectedShip, profile.data.upgrades)
	local shield = ship:GetAttribute("Shield") or 0
	local hull = ship:GetAttribute("Hull") or 0
	applyStats(ship, stats)
	ship:SetAttribute("Shield", math.min(shield, stats.maxShield))
	ship:SetAttribute("Hull", math.min(hull, stats.maxHull))
	ResourceSystem.updateCargoAttributes(profile)
end

local function connectSeat(player: Player, ship: Model)
	local seat = ship:FindFirstChild("PilotSeat") :: Seat
	local root = ship.PrimaryPart
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if occupant then
			local occupantPlayer = Players:GetPlayerFromCharacter(occupant.Parent)
			if occupantPlayer == player then
				-- Hand physics to the pilot for lag-free flight.
				task.defer(function()
					if root.Parent then
						pcall(root.SetNetworkOwner, root, player)
					end
				end)
			else
				occupant.Jump = true -- no stealing ships
			end
		else
			-- Pilot got out: server reclaims physics and parks the ship.
			if root.Parent then
				pcall(root.SetNetworkOwner, root, nil)
				local lv = root:FindFirstChild("FlightVelocity")
				if lv then
					lv.VectorVelocity = Vector3.zero
				end
			end
		end
	end)
end

function ShipSystem.despawn(player: Player)
	local profile = DataSystem.get(player)
	if profile and profile.ship then
		profile.ship:Destroy()
		profile.ship = nil
	end
end

function ShipSystem.spawnShip(player: Player, shipClass: string)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end

	-- Ships launch from the player's own pad, nose pointing out over the rim.
	local baseModel = profile.baseModel
	local launchPoint = baseModel and baseModel:FindFirstChild("LaunchPoint", true)
	if not launchPoint then
		DataSystem.notify(player, "Your base isn't ready yet.", "bad")
		return
	end

	ShipSystem.despawn(player)

	local stats = ShipStats.compute(shipClass, profile.data.upgrades)
	local ship = ShipBuilder.build(shipClass)

	ship:SetAttribute("OwnerId", player.UserId)
	ship:SetAttribute("OwnerName", player.DisplayName)
	ship:SetAttribute("ShipClass", GameConfig.Ships[shipClass].displayName)
	applyStats(ship, stats)
	ship:SetAttribute("Shield", stats.maxShield)
	ship:SetAttribute("Hull", stats.maxHull)
	ship:SetAttribute("Energy", stats.energyMax)

	ship:PivotTo(launchPoint.CFrame)
	CollectionService:AddTag(ship, "Ship")
	ship.Parent = WorldGen.getShipsFolder()

	profile.ship = ship
	profile.lastHitAt = 0
	connectSeat(player, ship)
	ResourceSystem.updateCargoAttributes(profile)

	-- Auto-seat the pilot so launching feels instant.
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
		local seat = ship:FindFirstChild("PilotSeat") :: Seat
		seat:Sit(humanoid)
	end
end

-- Blow up a ship. killer is optional (environmental deaths pass nil).
function ShipSystem.destroyShip(player: Player, killer: Player?)
	local profile = DataSystem.get(player)
	local ship = profile and profile.ship
	if not (ship and ship.Parent) then
		return
	end

	local position = ship:GetPivot().Position
	profile.ship = nil

	-- Death rule: keep secured cargo, lose unsecured.
	local lostValue = ResourceSystem.onShipDestroyed(profile)
	profile.data.stats.deaths += 1

	-- Server-side Explosion replicates the visual to everyone for free.
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 25
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0 -- respawns at their base
	end
	ship:Destroy()

	if killer and killer ~= player then
		local reward = GameConfig.Combat.KillRewardCredits
			+ math.floor(lostValue * GameConfig.Combat.LootUnsecuredPercent)
		DataSystem.addKill(killer)
		DataSystem.addCredits(killer, reward)
		DataSystem.notify(killer, ("Destroyed %s  +%d credits"):format(player.DisplayName, reward), "good")
		DataSystem.notify(player, ("Destroyed by %s — secured cargo kept, unsecured lost."):format(killer.DisplayName), "bad")
	else
		DataSystem.notify(player, "Ship destroyed — secured cargo kept, unsecured lost.", "bad")
	end
	DataSystem.push(player)
end

local function onSelectShip(player: Player, shipClass)
	local profile = DataSystem.get(player)
	if not profile or type(shipClass) ~= "string" or not GameConfig.Ships[shipClass] then
		return
	end
	if not profile.data.shipsOwned[shipClass] then
		DataSystem.notify(player, "You don't own that ship yet.", "bad")
		return
	end
	local now = os.clock()
	if now - profile.lastSpawnAt < GameConfig.Combat.SpawnCooldown then
		return
	end
	local char = player.Character
	if not char or not ZoneSystem.isNearOwnBase(player, char:GetPivot().Position) then
		DataSystem.notify(player, "You must be at your base to launch a ship.", "bad")
		return
	end

	profile.lastSpawnAt = now
	profile.data.selectedShip = shipClass
	ShipSystem.spawnShip(player, shipClass)
	DataSystem.push(player)
end

function ShipSystem.init()
	Remotes.get("SelectShip").OnServerEvent:Connect(onSelectShip)

	Players.PlayerRemoving:Connect(function(player)
		ShipSystem.despawn(player)
	end)

	-- Destroy ships that drift below the kill floor (e.g. pilot bailed out).
	task.spawn(function()
		while true do
			task.wait(5)
			for player, profile in pairs(DataSystem.all()) do
				local ship = profile.ship
				if ship and ship.Parent and ship.PrimaryPart then
					if ship.PrimaryPart.Position.Y < GameConfig.World.KillFloorY then
						ShipSystem.destroyShip(player, nil)
					end
				end
			end
		end
	end)
end

return ShipSystem

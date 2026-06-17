-- CombatSystem
-- Server-authoritative hitscan combat. The client only sends an aim point;
-- the server validates fire rate and energy, raycasts from the ship's actual
-- muzzle, applies shield-then-hull damage, enforces safe zones, and
-- broadcasts beam visuals over an UnreliableRemoteEvent.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local ShipSystem = require(script.Parent.ShipSystem)
local ZoneSystem = require(script.Parent.ZoneSystem)

local CombatSystem = {}

local function shipFromPart(part: BasePart): Model?
	local node = part
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, "Ship") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function applyDamage(attacker: Player, victimShip: Model, damage: number, attackerPos: Vector3)
	local ownerId = victimShip:GetAttribute("OwnerId")
	local victim = ownerId and Players:GetPlayerByUserId(ownerId)
	if not victim or victim == attacker then
		return
	end

	-- Safe bubbles protect both sides: no griefing from or into a base's bubble.
	local victimPos = victimShip:GetPivot().Position
	if ZoneSystem.isSafe(victimPos) or ZoneSystem.isSafe(attackerPos) then
		local profile = DataSystem.get(attacker)
		if profile and os.clock() - (profile.lastSafeNotify or 0) > 3 then
			profile.lastSafeNotify = os.clock()
			DataSystem.notify(attacker, "No combat near home bases.", "info")
		end
		return
	end

	local victimProfile = DataSystem.get(victim)
	if not victimProfile then
		return
	end
	victimProfile.lastHitAt = os.clock()
	-- Remember who hit us so the victim's base turrets can retaliate.
	victimProfile.lastAttacker = attacker
	victimProfile.lastAttackerAt = os.clock()

	-- Shields absorb first, hull takes the remainder.
	local shield = victimShip:GetAttribute("Shield") or 0
	local absorbed = math.min(shield, damage)
	if absorbed > 0 then
		victimShip:SetAttribute("Shield", shield - absorbed)
		damage -= absorbed
	end
	if damage > 0 then
		local hull = (victimShip:GetAttribute("Hull") or 0) - damage
		victimShip:SetAttribute("Hull", hull)
		if hull <= 0 then
			ShipSystem.destroyShip(victim, attacker)
		end
	end
end

local function onFireWeapon(player: Player, aimPoint)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local profile = DataSystem.get(player)
	local ship = profile and profile.ship
	if not (ship and ship.Parent and ship.PrimaryPart) then
		return
	end
	local seat = ship:FindFirstChild("PilotSeat")
	if not (seat and seat.Occupant and seat.Occupant.Parent == player.Character) then
		return
	end

	local weapon = GameConfig.Weapons[ship:GetAttribute("Weapon")]
	if not weapon then
		return
	end

	-- Fire-rate gate (small tolerance for network jitter).
	local fireRate = (ship:GetAttribute("FireRate") or 1) * weapon.fireRateMult
	local now = os.clock()
	if now - profile.lastFire < (1 / fireRate) * 0.9 then
		return
	end

	-- Energy gate.
	local energy = ship:GetAttribute("Energy") or 0
	if energy < weapon.energyCost then
		return
	end
	profile.lastFire = now
	ship:SetAttribute("Energy", energy - weapon.energyCost)

	-- Alternate muzzles for ships with more than one.
	local root = ship.PrimaryPart
	local muzzles = {}
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Attachment") and child.Name:match("^Muzzle") then
			table.insert(muzzles, child)
		end
	end
	if #muzzles == 0 then
		return
	end
	profile.muzzleIndex = (profile.muzzleIndex % #muzzles) + 1
	local origin = muzzles[profile.muzzleIndex].WorldPosition

	local direction = aimPoint - origin
	if direction.Magnitude < 1 then
		return
	end
	direction = direction.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ship, player.Character }
	local result = workspace:Raycast(origin, direction * weapon.range, params)
	local endPos = result and result.Position or origin + direction * weapon.range

	Remotes.get("BeamFX"):FireAllClients(origin, endPos, ship:GetAttribute("Weapon"))

	if result then
		local hitShip = shipFromPart(result.Instance)
		if hitShip then
			local damage = (ship:GetAttribute("Damage") or 0) * weapon.damageMult
			applyDamage(player, hitShip, damage, ship:GetPivot().Position)
		end
	end
end

-- Shield and energy regeneration.
local function startRegenLoop()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0

		for _, profile in pairs(DataSystem.all()) do
			local ship = profile.ship
			if not (ship and ship.Parent) then
				continue
			end

			local energy = ship:GetAttribute("Energy") or 0
			local energyMax = ship:GetAttribute("EnergyMax") or 0
			if energy < energyMax then
				ship:SetAttribute("Energy", math.min(energyMax, energy + (ship:GetAttribute("EnergyRegen") or 0) * step))
			end

			if os.clock() - profile.lastHitAt >= GameConfig.Combat.ShieldRegenDelay then
				local shield = ship:GetAttribute("Shield") or 0
				local maxShield = ship:GetAttribute("MaxShield") or 0
				if shield < maxShield then
					ship:SetAttribute("Shield", math.min(maxShield, shield + (ship:GetAttribute("ShieldRegen") or 0) * step))
				end
			end
		end
	end)
end

function CombatSystem.init()
	Remotes.get("FireWeapon").OnServerEvent:Connect(onFireWeapon)
	startRegenLoop()
end

return CombatSystem

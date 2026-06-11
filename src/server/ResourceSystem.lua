-- ResourceSystem
-- Owns player cargo: the secured/unsecured split, capacity limits, the
-- death-loss rule, selling, and resource costs for upgrades.
--
-- Secured-resource rule: a configurable fraction of everything mined is
-- "secured" and can never be lost. When a ship is destroyed the player keeps
-- secured cargo and loses unsecured cargo (part of its value goes to the killer).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local ShipStats = require(Shared.ShipStats)

local DataSystem = require(script.Parent.DataSystem)

local ResourceSystem = {}

function ResourceSystem.capacity(profile): number
	if profile.ship and profile.ship.Parent then
		return profile.ship:GetAttribute("CargoCapacity") or 0
	end
	local class = profile.data.selectedShip
	if class and GameConfig.Ships[class] then
		return ShipStats.compute(class, profile.data.upgrades).cargoCapacity
	end
	return 0
end

function ResourceSystem.totalCargo(profile): number
	return ShipStats.cargoAmount(profile.cargo.secured, profile.cargo.unsecured)
end

-- Mirror cargo state onto the ship model as attributes so clients can render
-- HUD bars and nameplates without remote spam (attributes replicate automatically).
function ResourceSystem.updateCargoAttributes(profile)
	local ship = profile.ship
	if not (ship and ship.Parent) then
		return
	end
	local capacity = ship:GetAttribute("CargoCapacity") or 1
	local total = ResourceSystem.totalCargo(profile)
	ship:SetAttribute("CargoFill", math.clamp(total / math.max(capacity, 1), 0, 1))
	ship:SetAttribute("CargoValue", math.floor(ShipStats.cargoValue(profile.cargo.secured, profile.cargo.unsecured)))
	ship:SetAttribute("CargoSecured", math.floor(ShipStats.cargoAmount(profile.cargo.secured, nil)))
	ship:SetAttribute("CargoUnsecured", math.floor(ShipStats.cargoAmount(nil, profile.cargo.unsecured)))
end

-- Add mined resources, splitting into secured/unsecured. Returns the amount
-- actually stored (0 when the hold is full).
function ResourceSystem.addMined(profile, resType: string, amount: number): number
	local space = ResourceSystem.capacity(profile) - ResourceSystem.totalCargo(profile)
	amount = math.min(amount, math.max(space, 0))
	if amount <= 0 then
		return 0
	end

	local securedAmount = amount * GameConfig.Mining.SecuredPercent
	local cargo = profile.cargo
	cargo.secured[resType] = (cargo.secured[resType] or 0) + securedAmount
	cargo.unsecured[resType] = (cargo.unsecured[resType] or 0) + (amount - securedAmount)
	profile.data.stats.mined += amount

	ResourceSystem.updateCargoAttributes(profile)
	return amount
end

-- Death rule: wipe unsecured cargo, keep secured. Returns the credit value of
-- what was lost so the combat system can award loot to the killer.
function ResourceSystem.onShipDestroyed(profile): number
	local lostValue = ShipStats.cargoValue(nil, profile.cargo.unsecured)
	table.clear(profile.cargo.unsecured)
	return lostValue
end

-- Sell everything in the hold. Returns credits earned.
function ResourceSystem.sellAll(player: Player, profile): number
	local value = math.floor(ShipStats.cargoValue(profile.cargo.secured, profile.cargo.unsecured))
	if value <= 0 then
		return 0
	end
	table.clear(profile.cargo.secured)
	table.clear(profile.cargo.unsecured)
	ResourceSystem.updateCargoAttributes(profile)
	DataSystem.addCredits(player, value)
	return value
end

-- Check whether the player has the given resources across both cargo buckets.
function ResourceSystem.has(profile, costs: { [string]: number }): boolean
	for resType, needed in pairs(costs) do
		local held = (profile.cargo.secured[resType] or 0) + (profile.cargo.unsecured[resType] or 0)
		if held < needed then
			return false
		end
	end
	return true
end

-- Consume resources (unsecured first, then secured). Caller must check has() first.
function ResourceSystem.take(profile, costs: { [string]: number })
	for resType, needed in pairs(costs) do
		local fromUnsecured = math.min(profile.cargo.unsecured[resType] or 0, needed)
		if fromUnsecured > 0 then
			profile.cargo.unsecured[resType] -= fromUnsecured
			needed -= fromUnsecured
		end
		if needed > 0 then
			profile.cargo.secured[resType] = (profile.cargo.secured[resType] or 0) - needed
		end
	end
	ResourceSystem.updateCargoAttributes(profile)
end

return ResourceSystem

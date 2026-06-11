-- ShipStats
-- Pure functions for computing effective ship stats, upgrade costs and cargo value.
-- Shared so the client can display accurate numbers; the server recomputes everything itself.

local GameConfig = require(script.Parent.GameConfig)

local ShipStats = {}

-- Effective stats for a ship class with the player's upgrade levels applied.
function ShipStats.compute(shipClass: string, upgrades: { [string]: number }?)
	local base = GameConfig.Ships[shipClass]
	assert(base, "Unknown ship class: " .. tostring(shipClass))
	local stats = table.clone(base)
	for category, level in pairs(upgrades or {}) do
		local cat = GameConfig.Upgrades.Categories[category]
		if cat and level > 0 then
			for statName, perLevel in pairs(cat.bonuses) do
				if stats[statName] then
					stats[statName] = stats[statName] * (1 + perLevel * level)
				end
			end
		end
	end
	return stats
end

-- Credit cost to buy the next level of a category given the current level.
function ShipStats.upgradeCost(category: string, currentLevel: number): number?
	local cat = GameConfig.Upgrades.Categories[category]
	if not cat then
		return nil
	end
	return math.floor(cat.baseCost * cat.costGrowth ^ currentLevel + 0.5)
end

-- Resource requirements (if any) to reach targetLevel.
function ShipStats.resourceGate(targetLevel: number): { [string]: number }?
	return GameConfig.Upgrades.ResourceGates[targetLevel]
end

local function sumValue(map: { [string]: number }?): number
	local total = 0
	for resType, amount in pairs(map or {}) do
		local cfg = GameConfig.Resources[resType]
		if cfg then
			total += amount * cfg.value
		end
	end
	return total
end

-- Credit value of cargo buckets.
function ShipStats.cargoValue(secured, unsecured): number
	return sumValue(secured) + sumValue(unsecured)
end

function ShipStats.cargoAmount(secured, unsecured): number
	local total = 0
	for _, amount in pairs(secured or {}) do
		total += amount
	end
	for _, amount in pairs(unsecured or {}) do
		total += amount
	end
	return total
end

return ShipStats

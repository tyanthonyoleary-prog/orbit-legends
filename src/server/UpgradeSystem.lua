-- UpgradeSystem
-- Validates and applies upgrade purchases: credit cost grows exponentially
-- per level, and certain levels also require resources from cargo
-- (GameConfig.Upgrades.ResourceGates). Stats are re-applied to the live ship.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local ShipStats = require(Shared.ShipStats)

local DataSystem = require(script.Parent.DataSystem)
local ResourceSystem = require(script.Parent.ResourceSystem)
local ShipSystem = require(script.Parent.ShipSystem)
local ZoneSystem = require(script.Parent.ZoneSystem)

local UpgradeSystem = {}

local function gateText(gate: { [string]: number }): string
	local parts = {}
	for resType, amount in pairs(gate) do
		table.insert(parts, ("%d %s"):format(amount, resType))
	end
	return table.concat(parts, ", ")
end

local function onBuyUpgrade(player: Player, category)
	local profile = DataSystem.get(player)
	if not profile or type(category) ~= "string" or not GameConfig.Upgrades.Categories[category] then
		return
	end

	local char = player.Character
	local pos = (profile.ship and profile.ship.Parent and profile.ship:GetPivot().Position)
		or (char and char:GetPivot().Position)
	if not pos or not ZoneSystem.isNearOwnBase(player, pos) then
		DataSystem.notify(player, "You must be at your base to upgrade.", "bad")
		return
	end

	local level = profile.data.upgrades[category] or 0
	if level >= GameConfig.Upgrades.MaxLevel then
		DataSystem.notify(player, category .. " is already at max level.", "info")
		return
	end

	local cost = ShipStats.upgradeCost(category, level)
	if profile.data.credits < cost then
		DataSystem.notify(player, ("Not enough credits — %s Lv.%d costs %d."):format(category, level + 1, cost), "bad")
		return
	end

	local gate = ShipStats.resourceGate(level + 1)
	if gate and not ResourceSystem.has(profile, gate) then
		DataSystem.notify(player, ("%s Lv.%d also requires: %s (in cargo)."):format(category, level + 1, gateText(gate)), "bad")
		return
	end

	DataSystem.addCredits(player, -cost)
	if gate then
		ResourceSystem.take(profile, gate)
	end
	profile.data.upgrades[category] = level + 1
	ShipSystem.applyNewStats(player)
	DataSystem.push(player)
	DataSystem.notify(player, ("%s upgraded to Lv.%d!"):format(category, level + 1), "good")
end

function UpgradeSystem.init()
	Remotes.get("BuyUpgrade").OnServerEvent:Connect(onBuyUpgrade)
end

return UpgradeSystem

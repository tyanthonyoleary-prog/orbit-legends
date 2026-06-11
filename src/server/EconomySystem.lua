-- EconomySystem
-- Selling cargo for credits and purchasing new ships. All transactions are
-- validated server-side and require the player to be at the station.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local ResourceSystem = require(script.Parent.ResourceSystem)
local ZoneSystem = require(script.Parent.ZoneSystem)

local EconomySystem = {}

local function playerPosition(player: Player, profile): Vector3?
	if profile.ship and profile.ship.Parent then
		return profile.ship:GetPivot().Position
	end
	local char = player.Character
	return char and char:GetPivot().Position or nil
end

local function onSellAll(player: Player)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	local pos = playerPosition(player, profile)
	if not pos or not ZoneSystem.isNearStation(pos) then
		DataSystem.notify(player, "You must be at the station to sell.", "bad")
		return
	end

	local earned = ResourceSystem.sellAll(player, profile)
	if earned > 0 then
		DataSystem.notify(player, ("Sold cargo for %d credits."):format(earned), "good")
	else
		DataSystem.notify(player, "No cargo to sell.", "info")
	end
end

local function onBuyShip(player: Player, shipClass)
	local profile = DataSystem.get(player)
	if not profile or type(shipClass) ~= "string" then
		return
	end
	local shipCfg = GameConfig.Ships[shipClass]
	if not shipCfg or shipCfg.starter then
		return
	end
	if profile.data.shipsOwned[shipClass] then
		DataSystem.notify(player, "You already own that ship.", "info")
		return
	end

	local pos = playerPosition(player, profile)
	if not pos or not ZoneSystem.isNearStation(pos) then
		DataSystem.notify(player, "You must be at the station to buy ships.", "bad")
		return
	end
	if profile.data.credits < shipCfg.cost then
		DataSystem.notify(player, ("Not enough credits — %s costs %d."):format(shipCfg.displayName, shipCfg.cost), "bad")
		return
	end

	profile.data.shipsOwned[shipClass] = true
	DataSystem.addCredits(player, -shipCfg.cost)
	DataSystem.notify(player, ("%s purchased! Launch it from the hangar."):format(shipCfg.displayName), "good")
end

function EconomySystem.init()
	Remotes.get("SellAll").OnServerEvent:Connect(onSellAll)
	Remotes.get("BuyShip").OnServerEvent:Connect(onBuyShip)
end

return EconomySystem

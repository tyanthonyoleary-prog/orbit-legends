-- ZoneSystem
-- Safe zone / PvP zone queries. The station sits at the world origin;
-- everything inside SafeRadius is a no-PvP zone. More zone shapes
-- (trading hubs, faction space) can be added here later without
-- touching the combat code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local ZoneSystem = {}

function ZoneSystem.isSafe(position: Vector3): boolean
	return position.Magnitude <= GameConfig.Zones.SafeRadius
end

function ZoneSystem.isNearStation(position: Vector3): boolean
	return position.Magnitude <= GameConfig.Economy.SellRange
end

return ZoneSystem

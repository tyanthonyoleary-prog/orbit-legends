-- ZoneSystem
-- Zone queries anchored to player bases. BaseSystem registers each base's
-- position here; combat asks "is this spot inside ANY base's safe bubble?"
-- and the economy asks "is this player near THEIR OWN base?". More zone
-- shapes (faction space, events) can be added later without touching
-- the combat code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local ZoneSystem = {}

-- userId -> Vector3 of that player's base center (live bases only).
local basePositions: { [number]: Vector3 } = {}

function ZoneSystem.registerBase(userId: number, position: Vector3)
	basePositions[userId] = position
end

function ZoneSystem.unregisterBase(userId: number)
	basePositions[userId] = nil
end

function ZoneSystem.getBasePosition(userId: number): Vector3?
	return basePositions[userId]
end

-- No-PvP inside any base's bubble.
function ZoneSystem.isSafe(position: Vector3): boolean
	local radius = GameConfig.Base.SafeBubbleRadius
	for _, basePos in pairs(basePositions) do
		if (position - basePos).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- Selling / upgrading / buying / launching require being at your own base.
function ZoneSystem.isNearOwnBase(player: Player, position: Vector3): boolean
	local basePos = basePositions[player.UserId]
	if not basePos then
		return false
	end
	return (position - basePos).Magnitude <= GameConfig.Base.InteractRange
end

return ZoneSystem

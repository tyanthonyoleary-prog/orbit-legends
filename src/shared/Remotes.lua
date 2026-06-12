-- Remotes
-- Single registry for all RemoteEvents / RemoteFunctions.
-- The server creates the instances on first require; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "OrbitRemotes"

local EVENTS = {
	"SelectShip",     -- client -> server (shipClass): launch/respawn a ship at your base
	"BuyShip",        -- client -> server (shipClass)
	"FireWeapon",     -- client -> server (aimPoint: Vector3)
	"SellAll",        -- client -> server
	"BuyUpgrade",     -- client -> server (category)
	"Notify",         -- server -> client (message, kind: "info"|"good"|"bad")
	"ProfileChanged", -- server -> client (snapshot table)
	"MiningState",    -- server -> client ({ active: bool, resource: string? })

	-- Bases
	"UpgradeBase",       -- client -> server: level up the base
	"BuildModule",       -- client -> server (moduleType): build into next free slot
	"UpgradeModule",     -- client -> server (slotIndex)
	"RemoveModule",      -- client -> server (slotIndex)
	"SetBaseCosmetic",   -- client -> server (themeName)
	"WarpToBase",        -- client -> server: teleport ship home to your base
	"RepairAtBase",      -- client -> server: refill shield+hull if docked with a Ship Port
	"BuyBaseConvenience",-- client -> server (key): prompt a Robux convenience product
}

local UNRELIABLE_EVENTS = {
	"BeamFX", -- server -> all clients (origin: Vector3, endPos: Vector3, weaponName: string)
}

local FUNCTIONS = {
	"GetProfile", -- client -> server: returns profile snapshot
}

local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for _, name in ipairs(EVENTS) do
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		for _, name in ipairs(UNRELIABLE_EVENTS) do
			local ev = Instance.new("UnreliableRemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		for _, name in ipairs(FUNCTIONS) do
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {}

function Remotes.get(name: string)
	return folder:WaitForChild(name)
end

return Remotes

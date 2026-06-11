-- DataSystem
-- Owns player profiles: persisted data (DataStore) + runtime state (ship, cargo, cooldowns).
-- Other systems get profiles via DataSystem.get(player) and never touch DataStores directly.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local DataSystem = {}

local store = nil
local ok = pcall(function()
	store = DataStoreService:GetDataStore(GameConfig.Data.StoreName)
end)
if not ok then
	warn("[OrbitLegends] DataStores unavailable (Studio without API access?). Progress will not save.")
end

local profiles: { [Player]: any } = {}

local function makeTemplate()
	local upgrades = {}
	for category in pairs(GameConfig.Upgrades.Categories) do
		upgrades[category] = 0
	end
	local shipsOwned = {}
	for class, cfg in pairs(GameConfig.Ships) do
		if cfg.starter then
			shipsOwned[class] = true
		end
	end
	return {
		credits = GameConfig.Economy.StartingCredits,
		selectedShip = nil,
		shipsOwned = shipsOwned,
		upgrades = upgrades,
		securedCargo = {},
		unsecuredCargo = {},
		stats = { kills = 0, deaths = 0, mined = 0 },
		base = {
			level = GameConfig.Base.StartLevel,
			slots = {},      -- string slot index -> { type = string, level = number }
			cosmetic = "Default",
			extraSlots = 0,  -- bought with Robux (convenience)
			stored = {},     -- base resource storage (phase 2 raiding)
		},
	}
end

-- Fill any keys missing from saved data (handles template additions across versions).
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function dataKey(player: Player): string
	return "p_" .. player.UserId
end

local function loadData(player: Player)
	if not store then
		return nil, false
	end
	for _ = 1, 3 do
		local success, result = pcall(function()
			return store:GetAsync(dataKey(player))
		end)
		if success then
			return result, true
		end
		task.wait(1)
	end
	return nil, false
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	local data = profile.data
	pcall(function()
		store:UpdateAsync(dataKey(player), function()
			return data
		end)
	end)
end

function DataSystem.get(player: Player)
	return profiles[player]
end

function DataSystem.all()
	return profiles
end

local function snapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.data
	return {
		credits = data.credits,
		selectedShip = data.selectedShip,
		shipsOwned = data.shipsOwned,
		upgrades = data.upgrades,
		stats = data.stats,
		cargo = { secured = profile.cargo.secured, unsecured = profile.cargo.unsecured },
		base = data.base,
	}
end

function DataSystem.push(player: Player)
	local snap = snapshot(player)
	if snap then
		Remotes.get("ProfileChanged"):FireClient(player, snap)
	end
end

function DataSystem.addCredits(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.credits = math.max(0, math.floor(profile.data.credits + amount))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Credits") then
		leaderstats.Credits.Value = profile.data.credits
	end
	DataSystem.push(player)
end

function DataSystem.addKill(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.stats.kills += 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Kills") then
		leaderstats.Kills.Value = profile.data.stats.kills
	end
end

function DataSystem.notify(player: Player, message: string, kind: string?)
	Remotes.get("Notify"):FireClient(player, message, kind or "info")
end

local function onPlayerAdded(player: Player)
	local saved, loadedOk = loadData(player)
	local data = makeTemplate()
	if saved then
		reconcile(saved, data)
		data = saved
	end

	local profile = {
		data = data,
		-- cargo buckets reference the persisted tables directly, so saves include them automatically
		cargo = { secured = data.securedCargo, unsecured = data.unsecuredCargo },
		ship = nil,        -- current ship Model
		lastFire = 0,
		lastHitAt = 0,
		lastSpawnAt = 0,
		miningResource = nil,
		muzzleIndex = 1,
		baseModel = nil,   -- current home-base Model
		lastRepairAt = 0,
		canSave = loadedOk or not store, -- never overwrite data we failed to load
	}
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local credits = Instance.new("IntValue")
	credits.Name = "Credits"
	credits.Value = data.credits
	credits.Parent = leaderstats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = data.stats.kills
	kills.Parent = leaderstats
	leaderstats.Parent = player

	if not loadedOk and store then
		DataSystem.notify(player, "Data could not load — playing in no-save mode.", "bad")
	end

	DataSystem.push(player)
end

local function onPlayerRemoving(player: Player)
	saveProfile(player)
	profiles[player] = nil
end

function DataSystem.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Remotes.get("GetProfile").OnServerInvoke = function(player)
		-- Profile may still be loading right after join.
		local deadline = os.clock() + 10
		while not profiles[player] and os.clock() < deadline do
			task.wait(0.2)
		end
		return snapshot(player)
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(saveProfile, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1)
		end
		for player in pairs(profiles) do
			saveProfile(player)
		end
	end)
end

return DataSystem

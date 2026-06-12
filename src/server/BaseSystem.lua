-- BaseSystem
-- Owns every player's Base — their home station: places it on the base ring,
-- spawns their character there, validates all build/upgrade/cosmetic actions
-- (credits for power, Robux only for convenience), runs turret defense
-- against recent attackers, and handles warping home + repair. Raiding is
-- intentionally left for phase 2.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local ResourceSystem = require(script.Parent.ResourceSystem)
local ShipSystem = require(script.Parent.ShipSystem)
local WorldGen = require(script.Parent.WorldGen)
local ZoneSystem = require(script.Parent.ZoneSystem)
local BaseBuilder = require(script.Parent.BaseBuilder)

local BaseSystem = {}
local cfg = GameConfig.Base
local basesFolder

-- userId -> CFrame resolved for this server session (ring spot + outward facing).
local assignedCFrames: { [number]: CFrame } = {}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function slotCount(base): number
	local fromLevel = cfg.SlotsPerLevel[math.clamp(base.level, 1, cfg.MaxLevel)] or cfg.SlotsPerLevel[#cfg.SlotsPerLevel]
	return fromLevel + math.min(base.extraSlots or 0, cfg.MaxExtraSlots)
end

local function nextFreeSlot(base): number?
	local total = slotCount(base)
	for i = 1, total do
		if not base.slots[tostring(i)] then
			return i
		end
	end
	return nil
end

local function levelCost(level: number): number
	return math.floor(cfg.LevelBaseCost * cfg.LevelCostGrowth ^ (level - 1) + 0.5)
end

local function moduleBuildCost(moduleType: string): number
	return math.floor(cfg.Modules[moduleType].baseCost + 0.5)
end

local function moduleUpgradeCost(moduleType: string, currentLevel: number): number
	local m = cfg.Modules[moduleType]
	return math.floor(m.baseCost * m.costGrowth ^ currentLevel + 0.5)
end

local function defenseRating(base): number
	local rating = cfg.LevelShield[math.clamp(base.level, 1, cfg.MaxLevel)] or 0
	for _, mod in pairs(base.slots or {}) do
		if mod.type == "ShieldGen" then
			rating += cfg.Modules.ShieldGen.shieldPerLevel * mod.level
		end
	end
	return rating
end

local function hasModule(base, moduleType: string): boolean
	for _, mod in pairs(base.slots or {}) do
		if mod.type == moduleType then
			return true
		end
	end
	return false
end

-- Ring spot per player: golden-angle spread from UserId, nudged along the
-- ring until clear of every base already placed this session. The model's
-- local -Z (launch side) faces away from the world center.
local function resolvePlacement(player: Player): CFrame
	local assigned = assignedCFrames[player.UserId]
	if assigned then
		return assigned
	end

	local angle = (player.UserId * 2.3999632) % (2 * math.pi)
	local step = cfg.RingMinSeparation / cfg.RingRadius
	for _ = 1, 64 do
		local pos = Vector3.new(math.cos(angle) * cfg.RingRadius, 0, math.sin(angle) * cfg.RingRadius)
		local clear = true
		for userId, otherCf in pairs(assignedCFrames) do
			if userId ~= player.UserId and (otherCf.Position - pos).Magnitude < cfg.RingMinSeparation then
				clear = false
				break
			end
		end
		if clear then
			local outward = Vector3.new(pos.X, 0, pos.Z).Unit
			local cf = CFrame.lookAt(pos, pos + outward)
			assignedCFrames[player.UserId] = cf
			return cf
		end
		angle += step
	end
	-- Pathological fallback (ring effectively full): stack high above origin.
	local cf = CFrame.new(0, 500 + player.UserId % 100, cfg.RingRadius)
	assignedCFrames[player.UserId] = cf
	return cf
end

function BaseSystem.getBaseCFrame(player: Player): CFrame
	return resolvePlacement(player)
end

----------------------------------------------------------------
-- Spawn / rebuild
----------------------------------------------------------------
local function despawnBase(player: Player)
	local profile = DataSystem.get(player)
	if profile and profile.baseModel then
		profile.baseModel:Destroy()
		profile.baseModel = nil
	end
end

local function basePadCFrame(model: Model): CFrame?
	local spawnPart = model:FindFirstChild("BaseSpawn", true)
	return spawnPart and spawnPart.CFrame + Vector3.new(0, 6, 0) or nil
end

function BaseSystem.rebuild(player: Player)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	despawnBase(player)

	local base = profile.data.base
	local model = BaseBuilder.build(base, player.DisplayName, slotCount(base))
	local core = model.PrimaryPart
	core:SetAttribute("OwnerId", player.UserId)
	core:SetAttribute("OwnerName", player.DisplayName)
	core:SetAttribute("Level", base.level)
	core:SetAttribute("Indestructible", base.level >= cfg.MaxLevel and cfg.IndestructibleAtMax)
	core:SetAttribute("ShieldRating", defenseRating(base))
	CollectionService:AddTag(model, "Base")

	local cf = resolvePlacement(player)
	model:PivotTo(cf)
	model.Parent = basesFolder
	profile.baseModel = model

	-- Anchor the zone, the client UI, and respawning to the new model.
	ZoneSystem.registerBase(player.UserId, cf.Position)
	player:SetAttribute("BasePosition", cf.Position)
	local spawnPart = model:FindFirstChild("BaseSpawn", true)
	if spawnPart then
		player.RespawnLocation = spawnPart
	end

	-- Keep anyone standing on the old structure from falling through the
	-- rebuilt one (upgrades can change the floor under their feet).
	local maxDeck = GameConfig.Base.Geometry.DeckRadius[cfg.MaxLevel] + 10
	local deckTop = cf.Position.Y + GameConfig.Base.Geometry.DeckThickness / 2
	for _, other in ipairs(Players:GetPlayers()) do
		local char = other.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if char and humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
			local pos = char:GetPivot().Position
			local horizontal = Vector3.new(pos.X - cf.Position.X, 0, pos.Z - cf.Position.Z)
			if horizontal.Magnitude <= maxDeck then
				char:PivotTo(CFrame.new(pos.X, deckTop + 4, pos.Z))
			end
		end
	end
end

-- Wait for the profile, place + build the base, then spawn the character on
-- it. CharacterAutoLoads is off, so nobody spawns before their home exists.
local function ensureSpawned(player: Player)
	local deadline = os.clock() + 15
	while not DataSystem.get(player) and os.clock() < deadline do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	if DataSystem.get(player) then
		BaseSystem.rebuild(player)
	end
	-- Spawn even if the base failed — the neutral fallback spawn catches them.
	if not player.Character then
		player:LoadCharacter()
	end
end

----------------------------------------------------------------
-- Action handlers (all server-validated)
----------------------------------------------------------------
local function onUpgradeBase(player: Player)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	local base = profile.data.base
	if base.level >= cfg.MaxLevel then
		DataSystem.notify(player, "Your base is already at max level.", "info")
		return
	end

	local cost = levelCost(base.level)
	if profile.data.credits < cost then
		DataSystem.notify(player, ("Need %d credits to upgrade your base."):format(cost), "bad")
		return
	end
	local gate = cfg.LevelResourceGates[base.level + 1]
	if gate and not ResourceSystem.has(profile, gate) then
		local parts = {}
		for res, amount in pairs(gate) do
			table.insert(parts, ("%d %s"):format(amount, res))
		end
		DataSystem.notify(player, ("Lv.%d also needs in cargo: %s"):format(base.level + 1, table.concat(parts, ", ")), "bad")
		return
	end

	DataSystem.addCredits(player, -cost)
	if gate then
		ResourceSystem.take(profile, gate)
	end
	base.level += 1
	BaseSystem.rebuild(player)
	DataSystem.push(player)
	if base.level >= cfg.MaxLevel then
		DataSystem.notify(player, "BASE MAXED — your base is now indestructible.", "good")
	else
		DataSystem.notify(player, ("Base upgraded to Lv.%d!"):format(base.level), "good")
	end
end

local function onBuildModule(player: Player, moduleType)
	local profile = DataSystem.get(player)
	if not profile or type(moduleType) ~= "string" or not cfg.Modules[moduleType] then
		return
	end
	local base = profile.data.base
	local slot = nextFreeSlot(base)
	if not slot then
		DataSystem.notify(player, "No free build slots — upgrade your base for more.", "bad")
		return
	end
	local cost = moduleBuildCost(moduleType)
	if profile.data.credits < cost then
		DataSystem.notify(player, ("Need %d credits to build that."):format(cost), "bad")
		return
	end

	DataSystem.addCredits(player, -cost)
	base.slots[tostring(slot)] = { type = moduleType, level = 1 }
	BaseSystem.rebuild(player)
	DataSystem.push(player)
	DataSystem.notify(player, ("%s built."):format(cfg.Modules[moduleType].displayName), "good")
end

local function onUpgradeModule(player: Player, slotIndex)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	local base = profile.data.base
	local mod = base.slots[tostring(slotIndex)]
	if not mod then
		return
	end
	local m = cfg.Modules[mod.type]
	if mod.level >= m.maxLevel then
		DataSystem.notify(player, ("%s is at max level."):format(m.displayName), "info")
		return
	end
	local cost = moduleUpgradeCost(mod.type, mod.level)
	if profile.data.credits < cost then
		DataSystem.notify(player, ("Need %d credits to upgrade that."):format(cost), "bad")
		return
	end

	DataSystem.addCredits(player, -cost)
	mod.level += 1
	BaseSystem.rebuild(player)
	DataSystem.push(player)
	DataSystem.notify(player, ("%s upgraded to Lv.%d."):format(m.displayName, mod.level), "good")
end

local function onRemoveModule(player: Player, slotIndex)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	local base = profile.data.base
	if base.slots[tostring(slotIndex)] then
		base.slots[tostring(slotIndex)] = nil
		BaseSystem.rebuild(player)
		DataSystem.push(player)
		DataSystem.notify(player, "Module removed.", "info")
	end
end

local function onSetCosmetic(player: Player, theme)
	local profile = DataSystem.get(player)
	if not profile or type(theme) ~= "string" or not cfg.CosmeticThemes[theme] then
		return
	end
	-- v1: cosmetics are free to apply. TODO: gate non-Default themes behind Robux
	-- products once they exist in the Creator Dashboard.
	profile.data.base.cosmetic = theme
	BaseSystem.rebuild(player)
	DataSystem.push(player)
	DataSystem.notify(player, ("Base theme set to %s."):format(theme), "good")
end

-- Teleport the player's piloted ship, briefly reclaiming physics so it sticks.
local function teleportShip(profile, cframe: CFrame)
	local ship = profile.ship
	if not (ship and ship.Parent and ship.PrimaryPart) then
		return false
	end
	local root = ship.PrimaryPart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	ship:PivotTo(cframe)
	local lv = root:FindFirstChild("FlightVelocity")
	if lv then
		lv.VectorVelocity = Vector3.zero
	end
	root.AssemblyLinearVelocity = Vector3.zero
	task.delay(0.15, function()
		if not root.Parent then
			return
		end
		local seat = ship:FindFirstChild("PilotSeat")
		local occupant = seat and seat.Occupant
		local pilot = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if pilot then
			pcall(function()
				root:SetNetworkOwner(pilot)
			end)
		end
	end)
	return true
end

local function onWarpToBase(player: Player)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	if os.clock() - (profile.lastHitAt or 0) < cfg.WarpCombatLockSeconds then
		DataSystem.notify(player, "Can't warp home while under fire.", "bad")
		return
	end
	local basePos = resolvePlacement(player).Position
	local shipPos = basePos + (Vector3.zero - basePos).Unit * 260 + Vector3.new(0, 40, 0)
	if teleportShip(profile, CFrame.lookAt(shipPos, basePos)) then
		DataSystem.notify(player, "Warped home.", "good")
	else
		DataSystem.notify(player, "Launch a ship first, then warp.", "bad")
	end
end

local function onRepairAtBase(player: Player)
	local profile = DataSystem.get(player)
	if not profile then
		return
	end
	local base = profile.data.base
	if not hasModule(base, "ShipPort") then
		DataSystem.notify(player, "Build a Ship Port to repair at your base.", "bad")
		return
	end
	local ship = profile.ship
	if not (ship and ship.Parent and ship.PrimaryPart) then
		DataSystem.notify(player, "You need a ship to repair.", "bad")
		return
	end
	local basePos = resolvePlacement(player).Position
	if (ship.PrimaryPart.Position - basePos).Magnitude > cfg.RepairRange + 200 then
		DataSystem.notify(player, "Fly closer to your Ship Port to repair.", "bad")
		return
	end
	ship:SetAttribute("Shield", ship:GetAttribute("MaxShield") or 0)
	ship:SetAttribute("Hull", ship:GetAttribute("MaxHull") or 0)
	DataSystem.notify(player, "Ship repaired at your Ship Port.", "good")
end

----------------------------------------------------------------
-- Robux convenience (scaffolding — disabled until product IDs are set)
----------------------------------------------------------------
local function onBuyConvenience(player: Player, key)
	local conv = type(key) == "string" and cfg.Convenience[key]
	if not conv then
		return
	end
	if conv.productId == 0 then
		DataSystem.notify(player, "Premium options coming soon — not yet available.", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, conv.productId)
end

-- Map productId -> effect. Only ExtraSlot is wired for now.
local function grantProduct(player: Player, productId: number): boolean
	local profile = DataSystem.get(player)
	if not profile then
		return false
	end
	if productId == cfg.Convenience.ExtraSlot.productId and productId ~= 0 then
		local base = profile.data.base
		if (base.extraSlots or 0) >= cfg.MaxExtraSlots then
			DataSystem.notify(player, "You already have the maximum extra slots.", "info")
			return true -- consume the receipt regardless
		end
		base.extraSlots = (base.extraSlots or 0) + 1
		BaseSystem.rebuild(player)
		DataSystem.push(player)
		DataSystem.notify(player, "+1 build slot added to your base.", "good")
		return true
	end
	return false
end

----------------------------------------------------------------
-- Turret defense — retaliation only. Inside the bubble PvP is already
-- blocked, so turrets exist to chase off whoever just attacked the owner
-- (anywhere in range), never to grief passers-by.
----------------------------------------------------------------
local function applyTurretDamage(ownerPlayer: Player, ship: Model, dmg: number)
	local victim = Players:GetPlayerByUserId(ship:GetAttribute("OwnerId") or 0)
	if not victim then
		return
	end
	local vp = DataSystem.get(victim)
	if vp then
		vp.lastHitAt = os.clock()
	end
	local shield = ship:GetAttribute("Shield") or 0
	local absorbed = math.min(shield, dmg)
	if absorbed > 0 then
		ship:SetAttribute("Shield", shield - absorbed)
		dmg -= absorbed
	end
	if dmg > 0 then
		local hull = (ship:GetAttribute("Hull") or 0) - dmg
		ship:SetAttribute("Hull", hull)
		if hull <= 0 then
			ShipSystem.destroyShip(victim, ownerPlayer)
		end
	end
end

local function defenseTick(dt: number)
	for owner, profile in pairs(DataSystem.all()) do
		local model = profile.baseModel
		if not (model and model.Parent and model.PrimaryPart) then
			continue
		end
		local attacker = profile.lastAttacker
		if not (attacker and attacker.Parent)
			or os.clock() - (profile.lastAttackerAt or 0) > cfg.TurretAggroSeconds then
			continue
		end

		local base = profile.data.base
		local dps, range = 0, 0
		for _, mod in pairs(base.slots or {}) do
			if mod.type == "Turret" then
				local m = cfg.Modules.Turret
				dps += (m.damage + m.damageGrowth * (mod.level - 1)) * m.fireRate
				range = math.max(range, m.range)
			end
		end
		if dps <= 0 then
			continue
		end

		local ap = DataSystem.get(attacker)
		local target = ap and ap.ship
		if not (target and target.Parent and target.PrimaryPart) then
			continue
		end
		local basePos = model.PrimaryPart.Position
		if (target.PrimaryPart.Position - basePos).Magnitude <= range then
			applyTurretDamage(owner, target, dps * dt)
			Remotes.get("BeamFX"):FireAllClients(basePos + Vector3.new(0, 10, 0), target.PrimaryPart.Position, cfg.TurretBeam)
		end
	end
end

----------------------------------------------------------------
-- Rescue + spawn safety nets
----------------------------------------------------------------

-- Teleport characters that fell off a deck back to their own base.
local function startRescueLoop()
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if char and humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
					local pos = char:GetPivot().Position
					if pos.Y < GameConfig.World.KillFloorY then
						local profile = DataSystem.get(player)
						local home = profile and profile.baseModel and basePadCFrame(profile.baseModel)
						char:PivotTo(home or WorldGen.getFallbackSpawnCFrame() + Vector3.new(0, 6, 0))
					end
				end
			end
		end
	end)
end

-- If a character ever spawns away from its base (fallback spawn, or
-- RespawnLocation misbehaving), bring it home once the base exists.
local function watchSpawns(player: Player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		local profile = DataSystem.get(player)
		local model = profile and profile.baseModel
		if not (model and model.Parent and char.Parent) then
			return
		end
		local home = basePadCFrame(model)
		local basePos = ZoneSystem.getBasePosition(player.UserId)
		if home and basePos and (char:GetPivot().Position - basePos).Magnitude > cfg.InteractRange then
			char:PivotTo(home)
		end
	end)
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
function BaseSystem.init()
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "PlayerBases"
	basesFolder.Parent = workspace

	Remotes.get("UpgradeBase").OnServerEvent:Connect(onUpgradeBase)
	Remotes.get("BuildModule").OnServerEvent:Connect(onBuildModule)
	Remotes.get("UpgradeModule").OnServerEvent:Connect(onUpgradeModule)
	Remotes.get("RemoveModule").OnServerEvent:Connect(onRemoveModule)
	Remotes.get("SetBaseCosmetic").OnServerEvent:Connect(onSetCosmetic)
	Remotes.get("WarpToBase").OnServerEvent:Connect(onWarpToBase)
	Remotes.get("RepairAtBase").OnServerEvent:Connect(onRepairAtBase)
	Remotes.get("BuyBaseConvenience").OnServerEvent:Connect(onBuyConvenience)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if player and grantProduct(player, info.ProductId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerAdded:Connect(function(player)
		watchSpawns(player)
		task.spawn(ensureSpawned, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watchSpawns(player)
		task.spawn(ensureSpawned, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		despawnBase(player)
		ZoneSystem.unregisterBase(player.UserId)
		assignedCFrames[player.UserId] = nil
	end)

	startRescueLoop()

	task.spawn(function()
		while true do
			task.wait(cfg.DefenseTick)
			if cfg.DefenseEnabled then
				defenseTick(cfg.DefenseTick)
			end
		end
	end)
end

return BaseSystem

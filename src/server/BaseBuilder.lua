-- BaseBuilder
-- Assembles a player's Base by cloning hand-built detailed prefabs from
-- ReplicatedStorage.BaseAssets (BaseTemplate / ModuleTurret / ModuleRadar —
-- authored in Studio, committed as assets/BaseAssets.rbxm). The base IS the
-- player's station: the template already carries the walkable decks, doors,
-- glass, interior rooms, lights, and a PadMark + BaseSpawn. This module clones
-- it, scales it with level, and wires the functional anchors (LaunchPoint,
-- SafeBubble, module slots, nameplate) that the server systems expect.
--
-- Output: a Model with PrimaryPart "Core". BaseSystem orients it so the local
-- +Z (the PadMark / launch side) faces away from the world center.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local BaseBuilder = {}

local function lerp(a, b, t) return a + (b - a) * t end

local function assets(): Folder?
	return ReplicatedStorage:FindFirstChild("BaseAssets")
end

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do part[key] = value end
	return part
end

local function weld(root: BasePart, part: BasePart, canCollide: boolean?)
	part.Anchored = false
	part.CanCollide = canCollide == true
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, part
	w.Parent = part
end

-- Slot position on a ring around the base footprint (base-local, on the deck).
function BaseBuilder.slotLocalCFrame(i: number, n: number, radius: number, height: number): CFrame
	local angle = (i - 1) * (2 * math.pi / math.max(n, 1))
	local pos = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	return CFrame.lookAt(pos, pos + Vector3.new(pos.X, 0, pos.Z).Unit * 10)
end

-- Fallback platform if the prefab assets are missing (keeps the game alive).
local function buildFallback(theme): (Model, number)
	local geo = GameConfig.Base.Geometry
	local r = geo.FallbackDeckRadius
	local model = Instance.new("Model")
	local core = makePart({
		Name = "Core", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(geo.FallbackDeckThickness, r * 2, r * 2),
		Material = Enum.Material.DiamondPlate, Color = theme.armor,
		CFrame = CFrame.Angles(0, 0, math.rad(90)),
	})
	core.Parent = model
	model.PrimaryPart = core
	local pad = makePart({
		Name = "PadMark", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 36, 36), Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 180, 70),
		CFrame = CFrame.new(0, geo.FallbackDeckThickness / 2, r - 24) * CFrame.Angles(0, 0, math.rad(90)),
	})
	pad.Parent = model
	weld(core, pad, true)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaseSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, geo.FallbackDeckThickness / 2 + 0.5, r - 14)
	spawn.Anchored, spawn.Neutral = true, true
	spawn.Parent = model
	return model, r
end

----------------------------------------------------------------
-- Main build
----------------------------------------------------------------
function BaseBuilder.build(baseData, ownerName: string, slotCount: number): Model
	local cfg = GameConfig.Base
	local geo = cfg.Geometry
	local level = math.clamp(baseData.level or 1, 1, cfg.MaxLevel)
	local theme = cfg.CosmeticThemes[baseData.cosmetic] or cfg.CosmeticThemes.Default
	local progress = (level - 1) / (cfg.MaxLevel - 1)
	local indestructible = level >= cfg.MaxLevel and cfg.IndestructibleAtMax

	local bank = assets()
	local template = bank and bank:FindFirstChild("BaseTemplate")

	local model, footprint
	if template then
		model = template:Clone()
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChild("Core")
		end
		-- Grow the whole base with level.
		local scale = lerp(geo.TemplateScaleMin, geo.TemplateScaleMax, progress)
		pcall(function() model:ScaleTo(scale) end)
		local _, sz = model:GetBoundingBox()
		footprint = math.max(sz.X, sz.Z) / 2
	else
		model, footprint = buildFallback(theme)
		warn("[BaseBuilder] BaseTemplate missing — using fallback platform.")
	end

	model.Name = "Base_" .. (ownerName or "Player")
	local core = model.PrimaryPart

	-- Strip the template's static built-in nameplate ("Cygnus's Outpost") so
	-- only our dynamic per-player/tier plate shows.
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") then
			d:Destroy()
		end
	end

	-- The per-player spawn is assigned via player.RespawnLocation; don't let the
	-- template's spawn pull in random joiners.
	local spawnPart = model:FindFirstChild("BaseSpawn", true)
	if spawnPart then
		spawnPart.Enabled = false
		spawnPart.Neutral = true
	end

	-- LaunchPoint: above the PadMark, facing out over the rim (away from core).
	local pad = model:FindFirstChild("PadMark", true)
	local launchPos = pad and (pad.Position + Vector3.new(0, geo.LaunchHeight, 0))
		or (core.Position + core.CFrame.LookVector * footprint)
	local outward = pad and (pad.Position - core.Position)
	outward = outward and Vector3.new(outward.X, 0, outward.Z)
	if not outward or outward.Magnitude < 0.1 then outward = Vector3.new(0, 0, 1) end
	local launchPoint = makePart({
		Name = "LaunchPoint", Size = Vector3.new(1, 1, 1),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		CFrame = CFrame.lookAt(launchPos, launchPos + outward.Unit * 10),
	})
	launchPoint.Parent = model
	weld(core, launchPoint)

	-- Translucent safe-zone bubble (fixed world radius, independent of base scale).
	local bubble = makePart({
		Name = "SafeBubble", Size = Vector3.new(4, 4, 4),
		Material = Enum.Material.ForceField, Color = Color3.fromRGB(80, 160, 255),
		Transparency = 0.96, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, CFrame = core.CFrame,
	})
	local bmesh = Instance.new("SpecialMesh")
	bmesh.MeshType = Enum.MeshType.Sphere
	bmesh.Scale = Vector3.one * (cfg.SafeBubbleRadius * 2 / 4)
	bmesh.Parent = bubble
	bubble.Parent = model
	weld(core, bubble)

	-- Player-built module prefabs on a ring just inside the footprint.
	local turretPrefab = bank and bank:FindFirstChild("ModuleTurret")
	local radarPrefab = bank and bank:FindFirstChild("ModuleRadar")
	local moduleRadius = math.max(footprint - geo.ModuleRingPad, 12)
	for slotStr, mod in pairs(baseData.slots or {}) do
		local i = tonumber(slotStr)
		if i then
			local localCf = BaseBuilder.slotLocalCFrame(i, slotCount, moduleRadius, 0)
			local worldCf = core.CFrame * localCf
			local prefab = (mod.type == "Turret" and turretPrefab)
				or (mod.type == "Radar" and radarPrefab)
			if prefab then
				local inst = prefab:Clone()
				if not inst.PrimaryPart then
					inst.PrimaryPart = inst:FindFirstChild("Root") or inst:FindFirstChildWhichIsA("BasePart")
				end
				pcall(function() inst:ScaleTo(geo.ModuleScale) end)
				inst:PivotTo(worldCf)
				for _, p in ipairs(inst:GetDescendants()) do
					if p:IsA("BasePart") then weld(core, p, p.CanCollide) end
				end
				-- reparent children under the model so it's one assembly
				for _, child in ipairs(inst:GetChildren()) do child.Parent = model end
				inst:Destroy()
			else
				-- Compact neon marker for non-prefab modules (ShieldGen/ShipPort/Storage).
				local mk = makePart({
					Name = mod.type .. "Node", Shape = Enum.PartType.Ball,
					Size = Vector3.new(6, 6, 6), Material = Enum.Material.Neon,
					Color = theme.trim, Transparency = 0.15,
					CFrame = worldCf * CFrame.new(0, 4, 0),
				})
				local lt = Instance.new("PointLight")
				lt.Color, lt.Range, lt.Brightness = theme.trim, 18, 2
				lt.Parent = mk
				mk.Parent = model
				weld(core, mk)
			end
		end
	end

	-- Indestructible shimmer at max level.
	if indestructible then
		local field = makePart({
			Name = "Forcefield", Shape = Enum.PartType.Ball,
			Size = Vector3.one * (footprint * 2.1),
			Material = Enum.Material.ForceField, Color = theme.trim, Transparency = 0.72,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			CFrame = core.CFrame,
		})
		field.Parent = model
		weld(core, field)
	end

	-- Nameplate: "<Owner>'s Base" + tier name + level.
	local tier = cfg.TierNames[level] or "Base"
	local gui = Instance.new("BillboardGui")
	gui.Name = "BaseNameplate"
	gui.Size = UDim2.fromOffset(260, 54)
	gui.StudsOffset = Vector3.new(0, footprint + 24, 0)
	gui.MaxDistance = 4000
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 18
	title.TextColor3 = theme.trim
	title.TextStrokeTransparency = 0.5
	title.Text = ("%s's Base"):format(ownerName or "Player")
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 0, 0, 24)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Code
	sub.TextSize = 15
	sub.TextColor3 = Color3.fromRGB(220, 230, 245)
	sub.Text = indestructible
		and ("%s  Lv.%d/%d  ◈ INDESTRUCTIBLE"):format(tier, level, cfg.MaxLevel)
		or ("%s  Lv.%d/%d"):format(tier, level, cfg.MaxLevel)
	sub.Parent = gui
	gui.Adornee = core
	gui.Parent = core

	return model
end

return BaseBuilder

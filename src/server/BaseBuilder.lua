-- BaseBuilder
-- Procedurally assembles a player's home-base Model from its saved data.
-- The fortress visually evolves with level: a flat foundation at Lv.1 grows
-- into a full spherical battle-station with an equatorial trench and a focused
-- emitter dish at max level. All original geometry — evokes a planet-killer
-- fortress without copying any specific copyrighted design.
--
-- Output: a Model with PrimaryPart "Core". BaseSystem sets ownership attributes
-- and positions it; this module only builds geometry from the data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local BaseBuilder = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function weld(root: BasePart, part: BasePart, canCollide: boolean?)
	part.Anchored = false
	part.CanCollide = canCollide == true
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

-- Position for slot index i of n, on a ring of the given radius/height (base-local).
function BaseBuilder.slotLocalCFrame(i: number, n: number, radius: number, height: number): CFrame
	local angle = (i - 1) * (2 * math.pi / math.max(n, 1))
	local pos = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
	-- face outward, away from the center
	return CFrame.lookAt(pos, pos + Vector3.new(pos.X, 0, pos.Z).Unit * 10)
end

----------------------------------------------------------------
-- Module visual assemblies (welded to the Core, facing outward).
----------------------------------------------------------------
local function buildTurret(root, cf, theme, level)
	local pedestal = makePart({
		Name = "Turret", Size = Vector3.new(8, 5, 8), Material = Enum.Material.Metal,
		Color = theme.armor, CFrame = cf * CFrame.new(0, 2.5, 0),
	})
	pedestal.Parent = root.Parent
	weld(root, pedestal)
	local barrelCount = math.clamp(1 + math.floor(level / 3), 1, 3)
	for b = 1, barrelCount do
		local offset = (b - (barrelCount + 1) / 2) * 1.8
		local barrel = makePart({
			Name = "Barrel", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9, 1.4, 1.4), Material = Enum.Material.Metal, Color = theme.armor,
			CFrame = cf * CFrame.new(offset, 4, -4) * CFrame.Angles(0, math.rad(90), 0),
		})
		barrel.Parent = root.Parent
		weld(root, barrel)
		local tip = makePart({
			Name = "Muzzle", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6),
			Material = Enum.Material.Neon, Color = theme.trim,
			CFrame = cf * CFrame.new(offset, 4, -8.5),
		})
		tip.Parent = root.Parent
		weld(root, tip)
	end
end

local function buildShieldGen(root, cf, theme, level)
	local pylon = makePart({
		Name = "ShieldGen", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10 + level, 4, 4), Material = Enum.Material.Metal, Color = theme.armor,
		CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	pylon.Parent = root.Parent
	weld(root, pylon)
	local orb = makePart({
		Name = "ShieldOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5),
		Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.2,
		CFrame = cf * CFrame.new(0, 11, 0),
	})
	local light = Instance.new("PointLight")
	light.Color = theme.trim
	light.Range = 24
	light.Brightness = 2
	light.Parent = orb
	orb.Parent = root.Parent
	weld(root, orb)
end

local function buildShipPort(root, cf, theme)
	local pad = makePart({
		Name = "ShipPort", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 18, 18), Material = Enum.Material.Neon, Color = theme.trim,
		Transparency = 0.3, CFrame = cf * CFrame.new(0, 1, 2) * CFrame.Angles(0, 0, math.rad(90)),
	})
	pad.Parent = root.Parent
	weld(root, pad)
	for s = -1, 1, 2 do
		local pillar = makePart({
			Name = "PortFrame", Size = Vector3.new(1.5, 10, 1.5), Material = Enum.Material.Metal,
			Color = theme.armor, CFrame = cf * CFrame.new(7 * s, 5, 2),
		})
		pillar.Parent = root.Parent
		weld(root, pillar)
	end
end

local function buildRadar(root, cf, theme)
	local mast = makePart({
		Name = "Radar", Size = Vector3.new(1.5, 12, 1.5), Material = Enum.Material.Metal,
		Color = theme.armor, CFrame = cf * CFrame.new(0, 6, 0),
	})
	mast.Parent = root.Parent
	weld(root, mast)
	local dish = makePart({
		Name = "RadarDish", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 10, 10), Material = Enum.Material.SmoothPlastic, Color = theme.trim,
		Transparency = 0.1, CFrame = cf * CFrame.new(0, 12, 0) * CFrame.Angles(math.rad(35), 0, math.rad(90)),
	})
	dish.Parent = root.Parent
	weld(root, dish)
end

local function buildStorage(root, cf, theme)
	local silo = makePart({
		Name = "Storage", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(12, 7, 7), Material = Enum.Material.DiamondPlate, Color = theme.armor,
		CFrame = cf * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	silo.Parent = root.Parent
	weld(root, silo)
	local cap = makePart({
		Name = "StorageCap", Shape = Enum.PartType.Ball, Size = Vector3.new(7.5, 7.5, 7.5),
		Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.4,
		CFrame = cf * CFrame.new(0, 12, 0),
	})
	cap.Parent = root.Parent
	weld(root, cap)
end

local MODULE_BUILDERS = {
	Turret = buildTurret,
	ShieldGen = buildShieldGen,
	ShipPort = buildShipPort,
	Radar = buildRadar,
	Storage = buildStorage,
}

----------------------------------------------------------------
-- Main build
----------------------------------------------------------------
function BaseBuilder.build(baseData, ownerName: string, slotCount: number): Model
	local cfg = GameConfig.Base
	local level = math.clamp(baseData.level or 1, 1, cfg.MaxLevel)
	local theme = cfg.CosmeticThemes[baseData.cosmetic] or cfg.CosmeticThemes.Default
	local progress = (level - 1) / (cfg.MaxLevel - 1)

	local coreRadius = lerp(18, 70, progress)
	local foundationRadius = coreRadius + 40

	local model = Instance.new("Model")
	model.Name = "Base_" .. (ownerName or "Player")

	-- Core sphere (the growing fortress) doubles as the PrimaryPart.
	local core = makePart({
		Name = "Core", Shape = Enum.PartType.Ball,
		Size = Vector3.new(coreRadius * 2, coreRadius * 2, coreRadius * 2),
		Material = Enum.Material.Metal, Color = theme.armor,
		CFrame = CFrame.new(0, coreRadius * 0.55, 0),
	})
	core.Parent = model
	model.PrimaryPart = core

	-- Foundation disk.
	local foundation = makePart({
		Name = "Foundation", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, foundationRadius * 2, foundationRadius * 2),
		Material = Enum.Material.DiamondPlate, Color = theme.armor,
		CFrame = core.CFrame * CFrame.new(0, -coreRadius * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	foundation.Parent = model
	weld(core, foundation, true)

	-- Trim ring glow on the foundation edge.
	local ring = makePart({
		Name = "TrimRing", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, foundationRadius * 2 + 4, foundationRadius * 2 + 4),
		Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.25,
		CFrame = foundation.CFrame,
	})
	ring.Parent = model
	weld(core, ring)

	-- Equatorial trench (reads as a planet-killer groove) — appears as the sphere forms.
	if progress > 0.3 then
		local trench = makePart({
			Name = "Trench", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(coreRadius * 0.5, coreRadius * 2.04, coreRadius * 2.04),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(25, 28, 36),
			CFrame = core.CFrame * CFrame.Angles(0, 0, math.rad(90)),
		})
		trench.Parent = model
		weld(core, trench)
		local trenchGlow = makePart({
			Name = "TrenchGlow", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(coreRadius * 0.18, coreRadius * 2.05, coreRadius * 2.05),
			Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.4,
			CFrame = core.CFrame * CFrame.Angles(0, 0, math.rad(90)),
		})
		trenchGlow.Parent = model
		weld(core, trenchGlow)
	end

	-- Armor greebles (panel detail) scaled with progress.
	local greebleCount = math.floor(lerp(0, 10, progress))
	for g = 1, greebleCount do
		local angle = g * (2 * math.pi / math.max(greebleCount, 1)) + 0.4
		local dir = Vector3.new(math.cos(angle), 0.4, math.sin(angle)).Unit
		local panel = makePart({
			Name = "Panel", Size = Vector3.new(coreRadius * 0.5, coreRadius * 0.5, 2),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 78, 95),
			CFrame = CFrame.lookAt(core.Position + dir * (coreRadius - 1), core.Position),
		})
		panel.Parent = model
		weld(core, panel)
	end

	-- Max-level superweapon emitter dish + indestructible forcefield shimmer.
	local indestructible = level >= cfg.MaxLevel and cfg.IndestructibleAtMax
	if level >= cfg.MaxLevel then
		local dishDir = Vector3.new(0.4, 0.5, 0.4).Unit
		local dish = makePart({
			Name = "Emitter", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, coreRadius * 0.7, coreRadius * 0.7), Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 54),
			CFrame = CFrame.lookAt(core.Position + dishDir * (coreRadius - 2), core.Position) * CFrame.Angles(0, math.rad(90), 0),
		})
		dish.Parent = model
		weld(core, dish)
		local lens = makePart({
			Name = "EmitterLens", Shape = Enum.PartType.Ball,
			Size = Vector3.new(coreRadius * 0.45, coreRadius * 0.45, coreRadius * 0.45),
			Material = Enum.Material.Neon, Color = theme.trim,
			CFrame = CFrame.new(core.Position + dishDir * (coreRadius - 1)),
		})
		lens.Parent = model
		weld(core, lens)
	end
	if indestructible then
		local field = makePart({
			Name = "Forcefield", Shape = Enum.PartType.Ball,
			Size = Vector3.new(foundationRadius * 2.2, foundationRadius * 2.2, foundationRadius * 2.2),
			Material = Enum.Material.ForceField, Color = theme.trim, Transparency = 0.7,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			CFrame = core.CFrame,
		})
		field.Parent = model
		weld(core, field)
	end

	-- Build the installed modules onto the slot ring.
	local moduleRadius = foundationRadius - 10
	local moduleHeight = -coreRadius * 0.55 + 3 -- sit on the foundation
	for slotStr, mod in pairs(baseData.slots or {}) do
		local i = tonumber(slotStr)
		local builder = i and MODULE_BUILDERS[mod.type]
		if builder then
			local cf = core.CFrame * BaseBuilder.slotLocalCFrame(i, slotCount, moduleRadius, moduleHeight)
			builder(core, cf, theme, mod.level or 1)
		end
	end

	-- Nameplate gamertag above the fortress.
	local gui = Instance.new("BillboardGui")
	gui.Name = "BaseNameplate"
	gui.Size = UDim2.fromOffset(240, 54)
	gui.StudsOffset = Vector3.new(0, coreRadius + 24, 0)
	gui.MaxDistance = 4000
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 18
	title.TextColor3 = theme.trim
	title.TextStrokeTransparency = 0.5
	title.Text = ("%s's Fortress"):format(ownerName or "Player")
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 0, 0, 24)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Code
	sub.TextSize = 15
	sub.TextColor3 = Color3.fromRGB(220, 230, 245)
	sub.Text = indestructible
		and ("Lv.%d/%d  ◈ INDESTRUCTIBLE"):format(level, cfg.MaxLevel)
		or ("Lv.%d/%d"):format(level, cfg.MaxLevel)
	sub.Parent = gui
	gui.Adornee = core
	gui.Parent = core

	return model
end

return BaseBuilder

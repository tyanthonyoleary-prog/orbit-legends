-- BaseBuilder
-- Procedurally assembles a player's Base Model from its saved data.
-- The Base IS the player's station: every level has a walkable deck with a
-- launch pad, trade terminal, hangar console, and spawn point. It evolves
-- with level: a flat platform (Lv.1-3) grows a multi-floor tower (Lv.4-7)
-- and finally becomes a spherical, planet-like body whose equator pokes
-- through the deck as a walkable trench ring (Lv.8-10). All original
-- geometry — evokes a planet-killer station without copying any
-- copyrighted design.
--
-- Output: a Model with PrimaryPart "Core" built around the local origin,
-- with local -Z as the launch direction. BaseSystem pivots the model so
-- -Z faces away from the world center, and sets ownership attributes.

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
-- Deck fixtures (every level — this is what makes the Base the station).
----------------------------------------------------------------

local function makeKioskLabel(kiosk: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = kiosk
end

-- A walkable ramp ascending from `from` (low) to `to` (high). WedgePart
-- slopes down toward its front (-Z), so the front must face the low end.
local function makeRamp(model, root, from: Vector3, to: Vector3, width: number, color: Color3)
	local horiz = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local mid = (from + to) / 2
	local ramp = Instance.new("WedgePart")
	ramp.Anchored = true
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Name = "Ramp"
	ramp.Material = Enum.Material.Metal
	ramp.Color = color
	ramp.Size = Vector3.new(width, to.Y - from.Y, horiz.Magnitude)
	ramp.CFrame = CFrame.lookAt(mid, Vector3.new(from.X, mid.Y, from.Z))
	ramp.Parent = model
	weld(root, ramp, true)
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

	local deckRadius = geo.DeckRadius[level]
	local deckTop = geo.DeckThickness / 2
	local spherical = level >= geo.SphereStartLevel

	local model = Instance.new("Model")
	model.Name = "Base_" .. (ownerName or "Player")

	-- Core: the main walkable deck (PrimaryPart). Local -Z is the launch side.
	local core = makePart({
		Name = "Core", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(geo.DeckThickness, deckRadius * 2, deckRadius * 2),
		Material = Enum.Material.DiamondPlate, Color = theme.armor,
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	core.Parent = model
	model.PrimaryPart = core

	-- Neon trim ring on the deck edge.
	local ring = makePart({
		Name = "TrimRing", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, deckRadius * 2 + 4, deckRadius * 2 + 4),
		Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.25,
		CFrame = core.CFrame,
	})
	ring.Parent = model
	weld(core, ring)

	-- Launch pad on the front rim; ships spawn above it, nose pointing
	-- out over the rim into open space (never at the base's own structures).
	local padCenter = Vector3.new(0, deckTop, -(deckRadius - geo.PadRadius - 4))
	local pad = makePart({
		Name = "LaunchPad", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, geo.PadRadius * 2, geo.PadRadius * 2),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 70),
		CFrame = CFrame.new(padCenter) * CFrame.Angles(0, 0, math.rad(90)),
	})
	pad.Parent = model
	weld(core, pad, true)

	-- Invisible marker that ShipSystem reads for the launch CFrame.
	local launchPos = padCenter + Vector3.new(0, geo.LaunchHeight, 0)
	local launchPoint = makePart({
		Name = "LaunchPoint", Size = Vector3.new(1, 1, 1),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		CFrame = CFrame.lookAt(launchPos, launchPos + Vector3.new(0, 0, -10)),
	})
	launchPoint.Parent = model
	weld(core, launchPoint)

	-- Spawn point on the rear rim (players wake up at home).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaseSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, deckTop + 0.5, deckRadius - 14)
	spawn.Anchored = true
	spawn.Enabled = false -- assigned per-player via player.RespawnLocation
	spawn.Neutral = true
	spawn.Duration = 8
	spawn.Material = Enum.Material.Metal
	spawn.Color = Color3.fromRGB(100, 110, 130)
	spawn.Parent = model

	-- Trade terminal and hangar console kiosks on the rear arc.
	for _, kioskDef in ipairs({
		{ name = "TradeTerminal", angle = math.rad(35), text = "TRADE & UPGRADES  [T]", color = Color3.fromRGB(120, 255, 200) },
		{ name = "HangarConsole", angle = math.rad(-35), text = "HANGAR  [H]", color = Color3.fromRGB(120, 200, 255) },
	}) do
		local r = deckRadius - 10
		local pos = Vector3.new(math.sin(kioskDef.angle) * r, deckTop + 3, math.cos(kioskDef.angle) * r)
		local kiosk = makePart({
			Name = kioskDef.name, Size = Vector3.new(8, 6, 3),
			Material = Enum.Material.Neon, Color = kioskDef.color,
			CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)),
		})
		makeKioskLabel(kiosk, kioskDef.text, kioskDef.color)
		kiosk.Parent = model
		weld(core, kiosk, true)
	end

	-- Beacon pylon on the rear edge (kept clear of the launch path).
	local beacon = makePart({
		Name = "Beacon", Size = Vector3.new(4, 26, 4),
		Material = Enum.Material.Neon, Color = theme.trim,
		CFrame = CFrame.new(0, deckTop + 13, deckRadius - 4),
	})
	local beaconLight = Instance.new("PointLight")
	beaconLight.Range = 40
	beaconLight.Brightness = 2
	beaconLight.Color = theme.trim
	beaconLight.Parent = beacon
	beacon.Parent = model
	weld(core, beacon, true)

	-- Safe-zone bubble visual (mesh-scaled: the zone is wider than the max part size).
	local bubble = makePart({
		Name = "SafeBubble", Size = Vector3.new(4, 4, 4),
		Material = Enum.Material.ForceField, Color = Color3.fromRGB(80, 160, 255),
		Transparency = 0.96, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, CFrame = CFrame.new(0, 0, 0),
	})
	local bubbleMesh = Instance.new("SpecialMesh")
	bubbleMesh.MeshType = Enum.MeshType.Sphere
	bubbleMesh.Scale = Vector3.one * (cfg.SafeBubbleRadius * 2 / 4)
	bubbleMesh.Parent = bubble
	bubble.Parent = model
	weld(core, bubble)

	----------------------------------------------------------------
	-- Lv.2-3: rear balcony half-deck with access ramps.
	----------------------------------------------------------------
	if level >= 2 and not spherical then
		local balconyRadius = deckRadius * 0.4
		local balconyCenter = Vector3.new(0, 12, deckRadius * 0.52)
		local balcony = makePart({
			Name = "Balcony", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, balconyRadius * 2, balconyRadius * 2),
			Material = Enum.Material.Metal, Color = theme.armor,
			CFrame = CFrame.new(balconyCenter) * CFrame.Angles(0, 0, math.rad(90)),
		})
		balcony.Parent = model
		weld(core, balcony, true)
		for side = -1, 1, 2 do
			makeRamp(model, core,
				Vector3.new(side * (balconyRadius + 22), deckTop, balconyCenter.Z),
				Vector3.new(side * (balconyRadius - 2), balconyCenter.Y + 1.5, balconyCenter.Z),
				8, theme.armor)
		end
	end
	if level >= 3 and not spherical then
		for c = 1, 4 do
			local angle = math.rad(45 + (c - 1) * 90)
			local pylon = makePart({
				Name = "CornerPylon", Size = Vector3.new(3, 14, 3),
				Material = Enum.Material.Metal, Color = theme.armor,
				CFrame = CFrame.new(math.sin(angle) * (deckRadius - 5), deckTop + 7, math.cos(angle) * (deckRadius - 5)),
			})
			pylon.Parent = model
			weld(core, pylon, true)
		end
	end

	----------------------------------------------------------------
	-- Lv.4-7: central tower of stacked walkable floors with ramps.
	----------------------------------------------------------------
	if not spherical then
		local floors = geo.TowerFloors[level]
		local prevEdge = nil
		for f = 1, floors do
			local floorRadius = deckRadius * 0.5 - (f - 1) * 7
			local floorY = f * geo.FloorHeight
			local floorPart = makePart({
				Name = "TowerFloor" .. f, Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3, floorRadius * 2, floorRadius * 2),
				Material = Enum.Material.Metal, Color = theme.armor,
				CFrame = CFrame.new(0, floorY, 0) * CFrame.Angles(0, 0, math.rad(90)),
			})
			floorPart.Parent = model
			weld(core, floorPart, true)
			-- glow band under each floor
			local band = makePart({
				Name = "FloorBand", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, floorRadius * 2 + 2, floorRadius * 2 + 2),
				Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.4,
				CFrame = CFrame.new(0, floorY - 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			})
			band.Parent = model
			weld(core, band)
			-- ramp up from the previous level, staggered around the tower
			local rampAngle = math.rad(120 + f * 90)
			local lowY = (f == 1) and deckTop or (f - 1) * geo.FloorHeight + 1.5
			local lowRadius = (f == 1) and (floorRadius + 26) or (prevEdge - 2)
			makeRamp(model, core,
				Vector3.new(math.sin(rampAngle) * lowRadius, lowY, math.cos(rampAngle) * lowRadius),
				Vector3.new(math.sin(rampAngle) * (floorRadius - 2), floorY + 1.5, math.cos(rampAngle) * (floorRadius - 2)),
				8, theme.armor)
			prevEdge = floorRadius
		end
	end

	----------------------------------------------------------------
	-- Lv.8-10: the planet body — a sphere bisected by the deck, whose
	-- protruding rim becomes the walkable equatorial trench ring.
	----------------------------------------------------------------
	if spherical then
		local sphereRadius = geo.SphereRadius[level]
		local body = makePart({
			Name = "PlanetBody", Shape = Enum.PartType.Ball,
			Size = Vector3.one * (sphereRadius * 2),
			Material = Enum.Material.Metal, Color = theme.armor,
			CFrame = CFrame.new(0, 0, 0),
		})
		body.Parent = model
		weld(core, body, true)
		-- glowing seam where the sphere meets the deck
		local seam = makePart({
			Name = "TrenchGlow", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, sphereRadius * 2 + 6, sphereRadius * 2 + 6),
			Material = Enum.Material.Neon, Color = theme.trim, Transparency = 0.35,
			CFrame = CFrame.new(0, deckTop + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
		seam.Parent = model
		weld(core, seam)
		-- armor greeble panels curving up the sphere
		local greebleCount = math.floor(lerp(6, 12, progress))
		for g = 1, greebleCount do
			local angle = g * (2 * math.pi / greebleCount) + 0.4
			local dir = Vector3.new(math.cos(angle), 0.45, math.sin(angle)).Unit
			local panel = makePart({
				Name = "Panel", Size = Vector3.new(sphereRadius * 0.4, sphereRadius * 0.4, 2),
				Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 78, 95),
				CFrame = CFrame.lookAt(dir * (sphereRadius - 1), Vector3.zero),
			})
			panel.Parent = model
			weld(core, panel)
		end
	end

	-- Max level: emitter dish + indestructible forcefield shimmer.
	local indestructible = level >= cfg.MaxLevel and cfg.IndestructibleAtMax
	if level >= cfg.MaxLevel then
		local sphereRadius = geo.SphereRadius[level] or deckRadius
		local dishDir = Vector3.new(0.4, 0.5, -0.4).Unit
		local dish = makePart({
			Name = "Emitter", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, sphereRadius * 0.7, sphereRadius * 0.7), Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 54),
			CFrame = CFrame.lookAt(dishDir * (sphereRadius - 2), Vector3.zero) * CFrame.Angles(0, math.rad(90), 0),
		})
		dish.Parent = model
		weld(core, dish)
		local lens = makePart({
			Name = "EmitterLens", Shape = Enum.PartType.Ball,
			Size = Vector3.one * (sphereRadius * 0.45),
			Material = Enum.Material.Neon, Color = theme.trim,
			CFrame = CFrame.new(dishDir * (sphereRadius - 1)),
		})
		lens.Parent = model
		weld(core, lens)
	end
	if indestructible then
		local field = makePart({
			Name = "Forcefield", Shape = Enum.PartType.Ball,
			Size = Vector3.one * (deckRadius * 2.4),
			Material = Enum.Material.ForceField, Color = theme.trim, Transparency = 0.7,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			CFrame = core.CFrame,
		})
		field.Parent = model
		weld(core, field)
	end

	-- Build the installed modules onto the slot ring (between sphere and rim).
	local moduleRadius = deckRadius - 12
	for slotStr, mod in pairs(baseData.slots or {}) do
		local i = tonumber(slotStr)
		local builder = i and MODULE_BUILDERS[mod.type]
		if builder then
			local cf = CFrame.new(0, 0, 0) * BaseBuilder.slotLocalCFrame(i, slotCount, moduleRadius, deckTop)
			builder(core, cf, theme, mod.level or 1)
		end
	end

	-- Nameplate gamertag above the Base.
	local plateHeight
	if spherical then
		plateHeight = geo.SphereRadius[level] + 22
	else
		plateHeight = deckTop + geo.TowerFloors[level] * geo.FloorHeight + 34
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BaseNameplate"
	gui.Size = UDim2.fromOffset(240, 54)
	gui.StudsOffset = Vector3.new(0, plateHeight, 0)
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
		and ("Lv.%d/%d  ◈ INDESTRUCTIBLE"):format(level, cfg.MaxLevel)
		or ("Lv.%d/%d"):format(level, cfg.MaxLevel)
	sub.Parent = gui
	gui.Adornee = core
	gui.Parent = core

	return model
end

return BaseBuilder

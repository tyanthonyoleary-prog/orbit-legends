-- ShipBuilder
-- Procedurally assembles ship models from parts so the game needs zero
-- uploaded assets. Each model has:
--   PrimaryPart "Hull" with RootAttachment, FlightVelocity (LinearVelocity),
--   FlightOrientation (AlignOrientation), Muzzle1/Muzzle2 attachments,
--   a "PilotSeat" Seat, engine Trails, and decorative wings/pods.
-- All original silhouettes — no copyrighted designs.

local ShipBuilder = {}

type WingSpec = { size: Vector3, offset: Vector3 }

local SPECS = {
	Scout = {
		hull = Vector3.new(6, 3, 18),
		color = Color3.fromRGB(70, 170, 255), accent = Color3.fromRGB(190, 235, 255),
		wings = { { size = Vector3.new(14, 0.5, 5), offset = Vector3.new(0, 0, 3) } },
		engines = { Vector3.new(0, 0, 9.5) },
		muzzles = { Vector3.new(0, 0, -9.5) },
	},
	Fighter = {
		hull = Vector3.new(9, 4, 22),
		color = Color3.fromRGB(230, 90, 80), accent = Color3.fromRGB(255, 190, 120),
		wings = {
			{ size = Vector3.new(20, 0.6, 6), offset = Vector3.new(0, 1, 4) },
			{ size = Vector3.new(16, 0.6, 5), offset = Vector3.new(0, -1, 6) },
		},
		engines = { Vector3.new(-2.5, 0, 11.5), Vector3.new(2.5, 0, 11.5) },
		muzzles = { Vector3.new(-3.5, 0, -11.5), Vector3.new(3.5, 0, -11.5) },
	},
	Hauler = {
		hull = Vector3.new(16, 10, 34),
		color = Color3.fromRGB(210, 170, 60), accent = Color3.fromRGB(120, 120, 130),
		wings = { { size = Vector3.new(24, 2, 10), offset = Vector3.new(0, -4, 6) } },
		pods = { Vector3.new(-9.5, 0, 2), Vector3.new(9.5, 0, 2) },
		engines = { Vector3.new(-4, 0, 17.5), Vector3.new(4, 0, 17.5) },
		muzzles = { Vector3.new(0, 5.5, -14) },
	},
	Interceptor = {
		hull = Vector3.new(5, 2.5, 20),
		color = Color3.fromRGB(120, 255, 160), accent = Color3.fromRGB(220, 255, 230),
		wings = {
			{ size = Vector3.new(12, 0.4, 8), offset = Vector3.new(0, 0.8, 5) },
			{ size = Vector3.new(12, 0.4, 8), offset = Vector3.new(0, -0.8, 5) },
		},
		engines = { Vector3.new(0, 0, 10.5) },
		muzzles = { Vector3.new(-2, 0, -10.5), Vector3.new(2, 0, -10.5) },
	},
	Corvette = {
		hull = Vector3.new(11, 5, 26),
		color = Color3.fromRGB(140, 150, 200), accent = Color3.fromRGB(220, 220, 255),
		wings = { { size = Vector3.new(22, 1, 8), offset = Vector3.new(0, 0, 5) } },
		engines = { Vector3.new(-3, 0, 13.5), Vector3.new(3, 0, 13.5) },
		muzzles = { Vector3.new(-4, 1, -13.5), Vector3.new(4, 1, -13.5) },
	},
	MiningFrigate = {
		hull = Vector3.new(13, 8, 28),
		color = Color3.fromRGB(180, 130, 70), accent = Color3.fromRGB(255, 220, 120),
		pods = { Vector3.new(-8, 0, 4), Vector3.new(8, 0, 4) },
		engines = { Vector3.new(0, 0, 14.5) },
		muzzles = { Vector3.new(0, 0, -14.5) },
	},
	StealthVessel = {
		hull = Vector3.new(7, 2.5, 24),
		color = Color3.fromRGB(60, 60, 75), accent = Color3.fromRGB(170, 90, 255),
		wings = { { size = Vector3.new(18, 0.4, 12), offset = Vector3.new(0, 0, 6) } },
		engines = { Vector3.new(0, 0, 12.5) },
		muzzles = { Vector3.new(-2.5, 0, -12.5), Vector3.new(2.5, 0, -12.5) },
	},
	Battlecruiser = {
		hull = Vector3.new(18, 9, 44),
		color = Color3.fromRGB(95, 105, 125), accent = Color3.fromRGB(255, 120, 120),
		wings = { { size = Vector3.new(30, 2, 14), offset = Vector3.new(0, -2, 8) } },
		pods = { Vector3.new(-11, 2, -4), Vector3.new(11, 2, -4) },
		engines = { Vector3.new(-5, 0, 22.5), Vector3.new(5, 0, 22.5), Vector3.new(0, 3, 22.5) },
		muzzles = { Vector3.new(-6, 2, -22.5), Vector3.new(6, 2, -22.5) },
	},
}

local function makePart(props): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function weldTo(root: BasePart, part: BasePart)
	part.Massless = true
	part.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

function ShipBuilder.build(shipClass: string): Model
	local spec = SPECS[shipClass] or SPECS.Fighter

	local model = Instance.new("Model")
	model.Name = "Ship_" .. shipClass

	local root = makePart({
		Name = "Hull",
		Size = spec.hull,
		Material = Enum.Material.Metal,
		Color = spec.color,
		CanCollide = true,
		CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.5),
	})
	root.Parent = model
	model.PrimaryPart = root

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Name = "FlightVelocity"
	lv.Attachment0 = rootAttachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.MaxForce = 1e6
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Name = "FlightOrientation"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = rootAttachment
	ao.MaxTorque = 1e7
	ao.Responsiveness = 6
	ao.CFrame = CFrame.new()
	ao.Parent = root

	-- Nose cone
	local nose = makePart({
		Name = "Nose",
		Size = Vector3.new(spec.hull.X * 0.6, spec.hull.Y * 0.8, spec.hull.Z * 0.25),
		Material = Enum.Material.Metal,
		Color = spec.accent,
		CFrame = root.CFrame * CFrame.new(0, 0, -spec.hull.Z / 2 - spec.hull.Z * 0.1),
	})
	nose.Parent = model
	weldTo(root, nose)

	-- Cockpit canopy
	local cockpit = makePart({
		Name = "Cockpit",
		Size = Vector3.new(spec.hull.X * 0.45, spec.hull.Y * 0.5, spec.hull.Z * 0.3),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(150, 220, 255),
		Transparency = 0.35,
		CFrame = root.CFrame * CFrame.new(0, spec.hull.Y / 2 + spec.hull.Y * 0.2, -spec.hull.Z * 0.15),
	})
	cockpit.Parent = model
	weldTo(root, cockpit)

	for _, wing in ipairs(spec.wings or {}) do
		local part = makePart({
			Name = "Wing",
			Size = wing.size,
			Material = Enum.Material.Metal,
			Color = spec.color,
			CFrame = root.CFrame * CFrame.new(wing.offset),
		})
		part.Parent = model
		weldTo(root, part)
	end

	for _, podOffset in ipairs(spec.pods or {}) do
		local pod = makePart({
			Name = "CargoPod",
			Size = Vector3.new(spec.hull.X * 0.35, spec.hull.Y * 0.7, spec.hull.Z * 0.6),
			Material = Enum.Material.DiamondPlate,
			Color = spec.accent,
			CFrame = root.CFrame * CFrame.new(podOffset),
		})
		pod.Parent = model
		weldTo(root, pod)
	end

	for i, engineOffset in ipairs(spec.engines or {}) do
		local engine = makePart({
			Name = "Engine" .. i,
			Size = Vector3.new(2, 2, 4),
			Material = Enum.Material.Neon,
			Color = spec.accent,
			CFrame = root.CFrame * CFrame.new(engineOffset),
		})
		engine.Parent = model
		weldTo(root, engine)

		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.9, 1.8)
		a0.Parent = engine
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.9, 1.8)
		a1.Parent = engine
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(spec.accent)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.35
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.FaceCamera = true
		trail.Parent = engine
	end

	for i, muzzleOffset in ipairs(spec.muzzles or {}) do
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle" .. i
		muzzle.Position = muzzleOffset
		muzzle.Parent = root
	end

	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Material = Enum.Material.Fabric
	seat.Color = Color3.fromRGB(40, 40, 50)
	seat.CFrame = root.CFrame * CFrame.new(0, spec.hull.Y / 2 + 0.5, -spec.hull.Z * 0.15)
	seat.Parent = model
	weldTo(root, seat)
	seat.CanCollide = true -- so players can sit on it

	return model
end

return ShipBuilder

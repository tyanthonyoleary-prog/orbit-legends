-- WorldGen
-- Builds the space environment at runtime: lighting, starfield, the central
-- station (safe zone), launch pads, and the asteroid fields. Also handles
-- asteroid respawning and rescuing characters that fall into the void.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local WorldGen = {}

local rootFolder
local asteroidFolder
local shipsFolder
local spawnLocation

local function basePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(35, 35, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(45, 45, 70)
	Lighting.FogEnd = 100000
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
end

local function buildStars()
	local stars = Instance.new("Folder")
	stars.Name = "Stars"
	local radius = 13000
	for _ = 1, GameConfig.World.StarCount do
		-- random direction on a sphere
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		if dir.Magnitude < 0.01 then
			dir = Vector3.yAxis
		end
		local size = 4 + math.random() * 14
		local star = basePart({
			Name = "Star",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255 - math.random(0, 60), 255 - math.random(0, 40), 255),
			CFrame = CFrame.new(dir.Unit * radius),
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		star.Parent = stars
	end
	stars.Parent = rootFolder
end

local function padPosition(index: number): Vector3
	local angle = (index - 1) * (2 * math.pi / GameConfig.World.PadCount)
	local r = GameConfig.World.StationRadius * 0.8
	return Vector3.new(math.cos(angle) * r, 4.5, math.sin(angle) * r)
end

-- CFrame where a freshly launched ship appears: above pad, nose pointing away from the station.
function WorldGen.getLaunchCFrame(index: number): CFrame
	local pos = padPosition(((index - 1) % GameConfig.World.PadCount) + 1)
	local outward = Vector3.new(pos.X, 0, pos.Z).Unit
	local shipPos = pos + Vector3.new(0, 14, 0)
	return CFrame.lookAt(shipPos, shipPos + outward)
end

local function buildStation()
	local station = Instance.new("Folder")
	station.Name = "Station"

	local radius = GameConfig.World.StationRadius

	local platform = basePart({
		Name = "Platform",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, radius * 2, radius * 2),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 75, 90),
	})
	platform.Parent = station

	local tower = basePart({
		Name = "Beacon",
		Size = Vector3.new(6, 60, 6),
		CFrame = CFrame.new(0, 33, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(90, 200, 255),
	})
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = tower.Color
	light.Parent = tower
	tower.Parent = station

	local terminal = basePart({
		Name = "TradeTerminal",
		Size = Vector3.new(10, 8, 4),
		CFrame = CFrame.new(0, 7, -40),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(90, 255, 190),
	})
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
	label.TextColor3 = Color3.fromRGB(120, 255, 200)
	label.Text = "TRADE & UPGRADES  [T]"
	label.Parent = gui
	gui.Parent = terminal
	terminal.Parent = station

	for i = 1, GameConfig.World.PadCount do
		local pad = basePart({
			Name = "LaunchPad" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, 36, 36),
			CFrame = CFrame.new(padPosition(i)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 180, 70),
		})
		pad.Parent = station
	end

	spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "StationSpawn"
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(0, 3.6, 30)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Material = Enum.Material.Metal
	spawnLocation.Color = Color3.fromRGB(100, 110, 130)
	spawnLocation.Parent = station

	-- Translucent boundary so players can see where the safe zone ends.
	local safeR = GameConfig.Zones.SafeRadius
	local boundary = basePart({
		Name = "SafeZoneBoundary",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(safeR * 2, safeR * 2, safeR * 2),
		CFrame = CFrame.new(0, 0, 0),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(80, 160, 255),
		Transparency = 0.9,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	boundary.Parent = station

	station.Parent = rootFolder
end

local function pickWeighted(weights: { [string]: number }): string
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local roll = math.random() * total
	for resType, w in pairs(weights) do
		roll -= w
		if roll <= 0 then
			return resType
		end
	end
	return next(weights)
end

function WorldGen.spawnAsteroid(fieldIndex: number)
	local field = GameConfig.AsteroidFields[fieldIndex]
	if not field then
		return
	end
	local resType = pickWeighted(field.weights)
	local rcfg = GameConfig.Resources[resType]

	local angle = math.random() * 2 * math.pi
	local r = field.innerRadius + math.random() * (field.outerRadius - field.innerRadius)
	local pos = Vector3.new(math.cos(angle) * r, (math.random() - 0.5) * field.height, math.sin(angle) * r)

	local s = rcfg.sizeMin + math.random() * (rcfg.sizeMax - rcfg.sizeMin)
	local size = Vector3.new(s, s * (0.7 + math.random() * 0.5), s * (0.7 + math.random() * 0.5))
	local yield = rcfg.yieldMin + math.random() * (rcfg.yieldMax - rcfg.yieldMin)

	local asteroid = basePart({
		Name = resType .. "Asteroid",
		Size = size,
		CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28),
		Material = rcfg.material,
		Color = rcfg.color,
	})
	asteroid:SetAttribute("ResourceType", resType)
	asteroid:SetAttribute("Yield", yield)
	asteroid:SetAttribute("MaxYield", yield)
	asteroid:SetAttribute("FieldIndex", fieldIndex)
	asteroid:SetAttribute("BaseSize", size)
	CollectionService:AddTag(asteroid, "Asteroid")
	asteroid.Parent = asteroidFolder
	return asteroid
end

function WorldGen.scheduleRespawn(fieldIndex: number)
	task.delay(GameConfig.Mining.RespawnSeconds, function()
		WorldGen.spawnAsteroid(fieldIndex)
	end)
end

function WorldGen.getAsteroidFolder(): Folder
	return asteroidFolder
end

function WorldGen.getShipsFolder(): Folder
	return shipsFolder
end

-- Teleport characters that fell off the station / out of a ship back to safety.
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
						char:PivotTo(spawnLocation.CFrame + Vector3.new(0, 6, 0))
					end
				end
			end
		end
	end)
end

function WorldGen.init()
	rootFolder = Instance.new("Folder")
	rootFolder.Name = "OrbitLegendsWorld"
	rootFolder.Parent = workspace

	asteroidFolder = Instance.new("Folder")
	asteroidFolder.Name = "Asteroids"
	asteroidFolder.Parent = rootFolder

	shipsFolder = Instance.new("Folder")
	shipsFolder.Name = "Ships"
	shipsFolder.Parent = rootFolder

	setupLighting()
	buildStars()
	buildStation()

	for fieldIndex, field in ipairs(GameConfig.AsteroidFields) do
		for _ = 1, field.count do
			WorldGen.spawnAsteroid(fieldIndex)
		end
	end

	startRescueLoop()
end

return WorldGen

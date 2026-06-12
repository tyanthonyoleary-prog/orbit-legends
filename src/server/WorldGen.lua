-- WorldGen
-- Builds the space environment at runtime: lighting, starfield, and the
-- asteroid fields, plus asteroid respawning. There is no central station —
-- every player's home is their own Base (see BaseSystem). The world origin
-- is just the center the belts ring around.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").GameConfig)

local WorldGen = {}

local rootFolder
local asteroidFolder
local shipsFolder
local fallbackSpawn

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

-- A tiny neutral spawn high above the origin. Players normally spawn at
-- their own Base via player.RespawnLocation; this exists so the world is
-- never without a SpawnLocation (data failure, base build error).
local function buildFallbackSpawn()
	fallbackSpawn = Instance.new("SpawnLocation")
	fallbackSpawn.Name = "FallbackSpawn"
	fallbackSpawn.Size = Vector3.new(16, 1, 16)
	fallbackSpawn.CFrame = CFrame.new(0, 300, 0)
	fallbackSpawn.Anchored = true
	fallbackSpawn.Neutral = true
	fallbackSpawn.Transparency = 0.85
	fallbackSpawn.Material = Enum.Material.Metal
	fallbackSpawn.Color = Color3.fromRGB(100, 110, 130)
	fallbackSpawn.Parent = rootFolder
end

function WorldGen.getFallbackSpawnCFrame(): CFrame
	return fallbackSpawn.CFrame
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
	buildFallbackSpawn()

	for fieldIndex, field in ipairs(GameConfig.AsteroidFields) do
		for _ = 1, field.count do
			WorldGen.spawnAsteroid(fieldIndex)
		end
	end
end

return WorldGen

-- Nameplates
-- Futuristic floating gamertag above every other player's ship:
-- name, ship class, and shield / hull / cargo bars driven by the
-- ship model's replicated attributes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Nameplates = {}

local plates: { [Model]: any } = {}

local BAR_DEFS = {
	{ key = "Shield", maxKey = "MaxShield", color = Color3.fromRGB(90, 190, 255) },
	{ key = "Hull", maxKey = "MaxHull", color = Color3.fromRGB(255, 110, 90) },
	{ key = "CargoFill", maxKey = nil, color = Color3.fromRGB(130, 255, 150) },
}

local function createPlate(ship: Model)
	if plates[ship] or ship:GetAttribute("OwnerId") == player.UserId then
		return
	end
	local root = ship.PrimaryPart or ship:WaitForChild("Hull", 5)
	if not root then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(190, 64)
	gui.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 8, 0)
	gui.MaxDistance = 900
	gui.AlwaysOnTop = false

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(230, 240, 255)
	title.TextStrokeTransparency = 0.6
	title.Text = ("%s  •  %s"):format(ship:GetAttribute("OwnerName") or "?", ship:GetAttribute("ShipClass") or "?")
	title.Parent = gui

	local fills = {}
	for i, def in ipairs(BAR_DEFS) do
		local back = Instance.new("Frame")
		back.Position = UDim2.new(0, 20, 0, 22 + (i - 1) * 12)
		back.Size = UDim2.new(1, -40, 0, 7)
		back.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
		back.BackgroundTransparency = 0.3
		back.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = back

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = def.color
		fill.BorderSizePixel = 0
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = fill
		fill.Parent = back

		back.Parent = gui
		fills[def.key] = fill
	end

	gui.Parent = root
	plates[ship] = fills
end

local function removePlate(ship: Model)
	plates[ship] = nil
end

local function updatePlates()
	for ship, fills in pairs(plates) do
		if not ship.Parent then
			plates[ship] = nil
			continue
		end
		for _, def in ipairs(BAR_DEFS) do
			local fraction
			if def.maxKey then
				local max = ship:GetAttribute(def.maxKey) or 0
				fraction = max > 0 and (ship:GetAttribute(def.key) or 0) / max or 0
			else
				fraction = ship:GetAttribute(def.key) or 0
			end
			fills[def.key].Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		end
	end
end

function Nameplates.init()
	for _, ship in ipairs(CollectionService:GetTagged("Ship")) do
		task.spawn(createPlate, ship)
	end
	CollectionService:GetInstanceAddedSignal("Ship"):Connect(function(ship)
		task.spawn(createPlate, ship)
	end)
	CollectionService:GetInstanceRemovedSignal("Ship"):Connect(removePlate)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.15 then
			accumulator = 0
			updatePlates()
		end
	end)
end

return Nameplates

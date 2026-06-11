-- BaseUI
-- Home-base management panel (toggle with B). Shows fortress level + defense,
-- build slots, and lets the player upgrade the fortress, build/upgrade/remove
-- modules, swap cosmetic themes, warp to/from the base, and repair. All actions
-- are validated again on the server — this is display + intent only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local Base = GameConfig.Base

local BaseUI = {}

local snapshot = nil
local gui, panel, content, headerLabel, baseButton

local PANEL_BG = Color3.fromRGB(12, 16, 26)
local TEXT = Color3.fromRGB(220, 230, 245)
local ACCENT = Color3.fromRGB(150, 120, 255)
local GOOD = Color3.fromRGB(130, 255, 150)
local GOLD = Color3.fromRGB(255, 230, 130)
local DIM = Color3.fromRGB(90, 95, 110)

----------------------------------------------------------------
-- Client-side mirrors of the server cost/stat math (display only).
----------------------------------------------------------------
local function slotCount(base)
	local fromLevel = Base.SlotsPerLevel[math.clamp(base.level, 1, Base.MaxLevel)] or Base.SlotsPerLevel[#Base.SlotsPerLevel]
	return fromLevel + math.min(base.extraSlots or 0, Base.MaxExtraSlots)
end
local function usedSlots(base)
	local n = 0
	for _ in pairs(base.slots or {}) do n += 1 end
	return n
end
local function levelCost(level)
	return math.floor(Base.LevelBaseCost * Base.LevelCostGrowth ^ (level - 1) + 0.5)
end
local function moduleUpgradeCost(t, l)
	local m = Base.Modules[t]
	return math.floor(m.baseCost * m.costGrowth ^ l + 0.5)
end
local function defenseRating(base)
	local r = Base.LevelShield[math.clamp(base.level, 1, Base.MaxLevel)] or 0
	for _, mod in pairs(base.slots or {}) do
		if mod.type == "ShieldGen" then
			r += Base.Modules.ShieldGen.shieldPerLevel * mod.level
		end
	end
	return r
end
local function comma(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function makeButton(text, parent, props)
	local b = mk("TextButton", {
		Text = text, Font = Enum.Font.Code, TextSize = 13,
		TextColor3 = Color3.fromRGB(10, 14, 22), BackgroundColor3 = ACCENT,
		AutoButtonColor = true, BorderSizePixel = 0,
	}, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	for k, v in pairs(props or {}) do b[k] = v end
	return b
end

-- A standard row with a label on the left and an action button on the right.
local function makeRow(order, labelText, buttonText, buttonColor, onClick, enabled)
	local row = mk("Frame", {
		Size = UDim2.new(1, -4, 0, 38), BackgroundColor3 = Color3.fromRGB(22, 28, 42),
		BorderSizePixel = 0, LayoutOrder = order,
	}, content)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
	mk("TextLabel", {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT,
		TextWrapped = true, Text = labelText,
	}, row)
	if buttonText then
		local btn = makeButton(buttonText, row, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 28), BackgroundColor3 = enabled and buttonColor or DIM,
		})
		if enabled and onClick then
			btn.MouseButton1Click:Connect(onClick)
		end
	end
	return row
end

local function makeHeading(order, text)
	mk("TextLabel", {
		Size = UDim2.new(1, -4, 0, 22), BackgroundTransparency = 1, LayoutOrder = order,
		Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = ACCENT, Text = text,
	}, content)
end

----------------------------------------------------------------
-- Rebuild the whole panel body from the latest snapshot.
----------------------------------------------------------------
local function refresh()
	if not (snapshot and snapshot.base and panel.Visible) then
		return
	end
	local base = snapshot.base
	local credits = snapshot.credits or 0
	local maxed = base.level >= Base.MaxLevel

	headerLabel.Text = ("FORTRESS  Lv.%d/%d   •   Defense %s   •   Slots %d/%d%s")
		:format(base.level, Base.MaxLevel, comma(defenseRating(base)),
			usedSlots(base), slotCount(base), maxed and "   ◈ INDESTRUCTIBLE" or "")

	for _, c in ipairs(content:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end

	-- Fortress upgrade
	makeHeading(1, "— FORTRESS")
	if maxed then
		makeRow(2, "Fortress fully upgraded — base is indestructible.", "MAX", DIM, nil, false)
	else
		local cost = levelCost(base.level)
		makeRow(2, ("Upgrade to Lv.%d  (expands the station, +slots, +defense)"):format(base.level + 1),
			comma(cost) .. " CR", ACCENT, function()
				Remotes.get("UpgradeBase"):FireServer()
			end, credits >= cost)
	end

	-- Travel + repair
	makeHeading(3, "— TRAVEL")
	makeRow(4, "Warp your ship out to your fortress", "WARP TO BASE", GOOD, function()
		Remotes.get("WarpToBase"):FireServer()
	end, true)
	makeRow(5, "Warp your ship back to the station", "TO STATION", GOOD, function()
		Remotes.get("WarpToStation"):FireServer()
	end, true)
	makeRow(6, "Repair ship (needs a Ship Port, dock close)", "REPAIR", GOLD, function()
		Remotes.get("RepairAtBase"):FireServer()
	end, true)

	-- Build modules
	makeHeading(7, "— BUILD MODULES")
	local order = 8
	for _, moduleType in ipairs(Base.ModuleOrder) do
		local m = Base.Modules[moduleType]
		local cost = math.floor(m.baseCost + 0.5)
		local roomy = usedSlots(base) < slotCount(base)
		makeRow(order, ("%s  —  %d CR"):format(m.displayName, cost),
			roomy and "BUILD" or "NO SLOT", roomy and ACCENT or DIM, function()
				Remotes.get("BuildModule"):FireServer(moduleType)
			end, roomy and credits >= cost)
		order += 1
	end

	-- Installed modules (sorted by slot index)
	local slotsSorted = {}
	for slotStr, mod in pairs(base.slots or {}) do
		table.insert(slotsSorted, { i = tonumber(slotStr), mod = mod })
	end
	table.sort(slotsSorted, function(a, b) return a.i < b.i end)
	if #slotsSorted > 0 then
		makeHeading(order, "— INSTALLED")
		order += 1
		for _, entry in ipairs(slotsSorted) do
			local m = Base.Modules[entry.mod.type]
			local atMax = entry.mod.level >= m.maxLevel
			local cost = moduleUpgradeCost(entry.mod.type, entry.mod.level)
			local row = makeRow(order,
				("[%d] %s  Lv.%d/%d"):format(entry.i, m.displayName, entry.mod.level, m.maxLevel),
				atMax and "MAX" or (comma(cost) .. " CR"),
				atMax and DIM or ACCENT,
				function() Remotes.get("UpgradeModule"):FireServer(entry.i) end,
				not atMax and credits >= cost)
			-- small Remove button on the far right edge
			local rm = makeButton("✕", row, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -126, 0.5, 0),
				Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(255, 110, 90),
			})
			rm.MouseButton1Click:Connect(function()
				Remotes.get("RemoveModule"):FireServer(entry.i)
			end)
			order += 1
		end
	end

	-- Cosmetics
	makeHeading(order, "— THEME (cosmetic)")
	order += 1
	local themeRow = mk("Frame", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundTransparency = 1, LayoutOrder = order,
	}, content)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, themeRow)
	for _, theme in ipairs(Base.CosmeticOrder) do
		local selected = base.cosmetic == theme
		local tb = makeButton(theme, themeRow, {
			Size = UDim2.fromOffset(92, 28),
			BackgroundColor3 = selected and GOOD or Color3.fromRGB(60, 66, 86),
			TextColor3 = selected and Color3.fromRGB(10, 14, 22) or TEXT,
		})
		tb.MouseButton1Click:Connect(function()
			Remotes.get("SetBaseCosmetic"):FireServer(theme)
		end)
	end
	order += 1

	-- Premium convenience
	makeHeading(order, "— PREMIUM (Robux, optional)")
	order += 1
	makeRow(order, "Extra build slot (convenience — not pay-to-win)", "BUY", GOLD, function()
		Remotes.get("BuyBaseConvenience"):FireServer("ExtraSlot")
	end, true)
end

local function setOpen(open)
	panel.Visible = open
	ClientState.menuOpen = open
	if open then
		task.spawn(function()
			snapshot = Remotes.get("GetProfile"):InvokeServer()
			refresh()
		end)
	end
end

function BaseUI.init()
	gui = mk("ScreenGui", { Name = "OrbitBaseUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	baseButton = makeButton("BASE [B]", gui, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(120, 36), BackgroundColor3 = ACCENT,
	})

	panel = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 560), BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	mk("UIStroke", { Color = ACCENT, Transparency = 0.5, Thickness = 1 }, panel)

	mk("TextLabel", {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 22),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT, Text = "HOME BASE",
	}, panel)
	headerLabel = mk("TextLabel", {
		Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -60, 0, 20),
		BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT, Text = "",
	}, panel)

	local close = makeButton("X", panel, {
		Position = UDim2.new(1, -38, 0, 10), Size = UDim2.fromOffset(26, 24),
		BackgroundColor3 = Color3.fromRGB(255, 110, 90),
	})
	close.MouseButton1Click:Connect(function() setOpen(false) end)

	content = mk("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

	baseButton.MouseButton1Click:Connect(function() setOpen(not panel.Visible) end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.B then
			setOpen(not panel.Visible)
		end
	end)

	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(snap)
		snapshot = snap
		refresh()
	end)
end

return BaseUI

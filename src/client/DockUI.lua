-- DockUI
-- Hangar (launch / buy ships) and Trade (sell cargo / buy upgrades) panels.
-- Buttons appear when docked at your own base; panels refresh from
-- ProfileChanged pushes. All purchases are validated again on the server —
-- this UI is display + intent only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local ShipStats = require(Shared.ShipStats)

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local DockUI = {}

local snapshot = nil -- latest profile snapshot from the server
local gui, hangarButton, stationButton, hangarPanel, stationPanel
local nearBase = false

local PANEL_BG = Color3.fromRGB(12, 16, 26)
local TEXT = Color3.fromRGB(220, 230, 245)
local ACCENT = Color3.fromRGB(90, 200, 255)
local GOOD = Color3.fromRGB(130, 255, 150)
local GOLD = Color3.fromRGB(255, 230, 130)

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function mk(class: string, props: { [string]: any }, parent: Instance?)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function makeButton(text: string, parent: Instance, props: { [string]: any }?)
	local button = mk("TextButton", {
		Text = text,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(10, 14, 22),
		BackgroundColor3 = ACCENT,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	for key, value in pairs(props or {}) do
		button[key] = value
	end
	return button
end

local function makePanel(title: string, height: number): (Frame, Frame)
	local panel = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, height),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	mk("UIStroke", { Color = ACCENT, Transparency = 0.5, Thickness = 1 }, panel)

	mk("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -60, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = ACCENT,
		Text = title,
	}, panel)

	local close = makeButton("X", panel, {
		Position = UDim2.new(1, -38, 0, 10),
		Size = UDim2.fromOffset(26, 24),
		BackgroundColor3 = Color3.fromRGB(255, 110, 90),
	})
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
		ClientState.menuOpen = hangarPanel.Visible or stationPanel.Visible
	end)

	local content = mk("Frame", {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 1, -56),
		BackgroundTransparency = 1,
	}, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

	return panel, content
end

----------------------------------------------------------------
-- Hangar panel: one row per ship class.
----------------------------------------------------------------
local hangarRows = {}

local function buildHangar()
	local panel, content
	panel, content = makePanel("HANGAR — SELECT SHIP", 470)
	hangarPanel = panel

	for order, class in ipairs(GameConfig.ShipOrder) do
		local cfg = GameConfig.Ships[class]
		local row = mk("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Color3.fromRGB(22, 28, 42),
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, content)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)

		mk("TextLabel", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0, 200, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT,
			Text = cfg.displayName,
		}, row)
		mk("TextLabel", {
			Position = UDim2.fromOffset(10, 22),
			Size = UDim2.new(1, -120, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(150, 165, 195),
			Text = ("%s  |  Spd %d • Cargo %d • Dmg %d • Shd %d"):format(
				cfg.role, cfg.maxSpeed, cfg.cargoCapacity, cfg.damage, cfg.maxShield),
		}, row)

		local button = makeButton("LAUNCH", row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(96, 30),
		})
		button.MouseButton1Click:Connect(function()
			if snapshot and snapshot.shipsOwned[class] then
				Remotes.get("SelectShip"):FireServer(class)
				panel.Visible = false
				ClientState.menuOpen = stationPanel.Visible
			else
				Remotes.get("BuyShip"):FireServer(class)
			end
		end)
		hangarRows[class] = button
	end
end

local function refreshHangar()
	if not snapshot then
		return
	end
	for class, button in pairs(hangarRows) do
		local cfg = GameConfig.Ships[class]
		if snapshot.shipsOwned[class] then
			button.Text = "LAUNCH"
			button.BackgroundColor3 = ACCENT
		else
			button.Text = comma(cfg.cost) .. " CR"
			button.BackgroundColor3 = snapshot.credits >= cfg.cost and GOLD or Color3.fromRGB(90, 95, 110)
		end
	end
end

----------------------------------------------------------------
-- Station panel: cargo summary + sell + upgrade rows.
----------------------------------------------------------------
local cargoLabel, sellButton
local upgradeRows = {}

local function buildStation()
	local panel, content
	panel, content = makePanel("BASE — TRADE & UPGRADES", 420)
	stationPanel = panel

	local cargoRow = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(22, 28, 42),
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, content)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, cargoRow)

	cargoLabel = mk("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Text = "Cargo: empty",
	}, cargoRow)

	sellButton = makeButton("SELL ALL", cargoRow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = GOOD,
	})
	sellButton.MouseButton1Click:Connect(function()
		Remotes.get("SellAll"):FireServer()
	end)

	for order, category in ipairs(GameConfig.Upgrades.CategoryOrder) do
		local row = mk("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(22, 28, 42),
			BorderSizePixel = 0,
			LayoutOrder = order + 1,
		}, content)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, row)

		local label = mk("TextLabel", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -130, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT,
			Text = category,
		}, row)

		local button = makeButton("BUY", row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 28),
		})
		button.MouseButton1Click:Connect(function()
			Remotes.get("BuyUpgrade"):FireServer(category)
		end)
		upgradeRows[category] = { label = label, button = button }
	end
end

local function refreshStation()
	if not snapshot then
		return
	end

	local cargoValue = ShipStats.cargoValue(snapshot.cargo.secured, snapshot.cargo.unsecured)
	local pieces = {}
	local combined = {}
	for resType, amount in pairs(snapshot.cargo.secured) do
		combined[resType] = (combined[resType] or 0) + amount
	end
	for resType, amount in pairs(snapshot.cargo.unsecured) do
		combined[resType] = (combined[resType] or 0) + amount
	end
	for resType, amount in pairs(combined) do
		if amount >= 1 then
			table.insert(pieces, ("%s %d"):format(resType, math.floor(amount)))
		end
	end
	cargoLabel.Text = #pieces > 0
		and ("Cargo: %s  —  worth %s CR"):format(table.concat(pieces, ", "), comma(cargoValue))
		or "Cargo: empty"

	for category, row in pairs(upgradeRows) do
		local level = snapshot.upgrades[category] or 0
		if level >= GameConfig.Upgrades.MaxLevel then
			row.label.Text = ("%s   Lv.%d/%d"):format(category, level, GameConfig.Upgrades.MaxLevel)
			row.button.Text = "MAX"
			row.button.BackgroundColor3 = Color3.fromRGB(90, 95, 110)
		else
			local cost = ShipStats.upgradeCost(category, level)
			local gate = ShipStats.resourceGate(level + 1)
			local gateText = ""
			if gate then
				local parts = {}
				for resType, amount in pairs(gate) do
					table.insert(parts, ("+%d %s"):format(amount, resType))
				end
				gateText = "  [" .. table.concat(parts, ", ") .. "]"
			end
			row.label.Text = ("%s   Lv.%d/%d%s"):format(category, level, GameConfig.Upgrades.MaxLevel, gateText)
			row.button.Text = comma(cost) .. " CR"
			row.button.BackgroundColor3 = snapshot.credits >= cost and ACCENT or Color3.fromRGB(90, 95, 110)
		end
	end
end

----------------------------------------------------------------
-- Toggle buttons + proximity
----------------------------------------------------------------
local function togglePanel(panel: Frame)
	panel.Visible = not panel.Visible
	if panel == hangarPanel and panel.Visible then
		stationPanel.Visible = false
	elseif panel == stationPanel and panel.Visible then
		hangarPanel.Visible = false
	end
	ClientState.menuOpen = hangarPanel.Visible or stationPanel.Visible

	-- Pull a fresh snapshot on open; mining changes cargo without a server push.
	if panel.Visible then
		task.spawn(function()
			snapshot = Remotes.get("GetProfile"):InvokeServer()
			refreshHangar()
			refreshStation()
		end)
	end
end

function DockUI.init()
	gui = mk("ScreenGui", { Name = "OrbitDockUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	buildHangar()
	buildStation()

	hangarButton = makeButton("HANGAR [H]", gui, {
		Position = UDim2.new(0, 16, 1, -54),
		Size = UDim2.fromOffset(120, 36),
	})
	hangarButton.MouseButton1Click:Connect(function()
		togglePanel(hangarPanel)
	end)

	stationButton = makeButton("TRADE [T]", gui, {
		Position = UDim2.new(0, 146, 1, -54),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = GOOD,
		Visible = false,
	})
	stationButton.MouseButton1Click:Connect(function()
		togglePanel(stationPanel)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H and nearBase then
			togglePanel(hangarPanel)
		elseif input.KeyCode == Enum.KeyCode.T and nearBase then
			togglePanel(stationPanel)
		end
	end)

	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(snap)
		snapshot = snap
		refreshHangar()
		refreshStation()
	end)

	-- Initial pull (also opens the hangar for brand-new pilots).
	task.spawn(function()
		snapshot = Remotes.get("GetProfile"):InvokeServer()
		refreshHangar()
		refreshStation()
		if snapshot and not snapshot.selectedShip then
			hangarPanel.Visible = true
			ClientState.menuOpen = true
		end
	end)

	-- Show dock controls only when near your own base; hide panels when leaving.
	-- BasePosition is published by the server (BaseSystem) once the base exists.
	task.spawn(function()
		while true do
			task.wait(1)
			local char = player.Character
			local pos = ClientState.ship and ClientState.ship.Parent and ClientState.ship:GetPivot().Position
				or (char and char:GetPivot().Position)
			local basePos = player:GetAttribute("BasePosition")
			local wasNear = nearBase
			nearBase = pos ~= nil and basePos ~= nil
				and (pos - basePos).Magnitude <= GameConfig.Base.InteractRange
			hangarButton.Visible = nearBase
			stationButton.Visible = nearBase
			if wasNear and not nearBase then
				hangarPanel.Visible = false
				stationPanel.Visible = false
				ClientState.menuOpen = false
			end
		end
	end)
end

return DockUI

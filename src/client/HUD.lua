-- HUD
-- Pilot heads-up display: shield / hull / energy / cargo bars, speed readout,
-- credits, mining indicator, and toast notifications. Reads everything from
-- ship attributes (replicated automatically) and ProfileChanged pushes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local HUD = {}

local COLORS = {
	Shield = Color3.fromRGB(90, 190, 255),
	Hull = Color3.fromRGB(255, 110, 90),
	Energy = Color3.fromRGB(255, 220, 110),
	Cargo = Color3.fromRGB(130, 255, 150),
}
local KIND_COLORS = {
	info = Color3.fromRGB(200, 220, 255),
	good = Color3.fromRGB(130, 255, 150),
	bad = Color3.fromRGB(255, 120, 110),
}

local gui
local bars = {} -- name -> { fill, value }
local creditsLabel, speedLabel, miningLabel, toastContainer

local function makeBar(name: string, order: number, parent: Instance)
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, 18)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 64, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = COLORS[name]
	label.Text = name:upper()
	label.Parent = row

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 68, 0.5, -5)
	back.Size = UDim2.new(1, -140, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
	back.BorderSizePixel = 0
	back.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = COLORS[name]
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local value = Instance.new("TextLabel")
	value.Position = UDim2.new(1, -66, 0, 0)
	value.Size = UDim2.new(0, 66, 1, 0)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.Code
	value.TextSize = 13
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = Color3.fromRGB(220, 230, 245)
	value.Text = "-"
	value.Parent = row

	row.Parent = parent
	bars[name] = { fill = fill, value = value }
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "OrbitHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	creditsLabel = Instance.new("TextLabel")
	creditsLabel.AnchorPoint = Vector2.new(1, 0)
	creditsLabel.Position = UDim2.new(1, -16, 0, 12)
	creditsLabel.Size = UDim2.fromOffset(240, 26)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Font = Enum.Font.Code
	creditsLabel.TextSize = 20
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Right
	creditsLabel.TextColor3 = Color3.fromRGB(255, 230, 130)
	creditsLabel.Text = "0 CR"
	creditsLabel.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Status"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -18)
	panel.Size = UDim2.fromOffset(440, 110)
	panel.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	makeBar("Shield", 1, panel)
	makeBar("Hull", 2, panel)
	makeBar("Energy", 3, panel)
	makeBar("Cargo", 4, panel)
	panel.Parent = gui

	speedLabel = Instance.new("TextLabel")
	speedLabel.AnchorPoint = Vector2.new(0.5, 1)
	speedLabel.Position = UDim2.new(0.5, 0, 1, -134)
	speedLabel.Size = UDim2.fromOffset(200, 20)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Font = Enum.Font.Code
	speedLabel.TextSize = 16
	speedLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
	speedLabel.Text = ""
	speedLabel.Parent = gui

	miningLabel = Instance.new("TextLabel")
	miningLabel.AnchorPoint = Vector2.new(0.5, 0)
	miningLabel.Position = UDim2.new(0.5, 0, 0, 120)
	miningLabel.Size = UDim2.fromOffset(320, 26)
	miningLabel.BackgroundTransparency = 1
	miningLabel.Font = Enum.Font.Code
	miningLabel.TextSize = 18
	miningLabel.TextColor3 = Color3.fromRGB(130, 255, 150)
	miningLabel.Visible = false
	miningLabel.Parent = gui

	toastContainer = Instance.new("Frame")
	toastContainer.AnchorPoint = Vector2.new(1, 0)
	toastContainer.Position = UDim2.new(1, -16, 0, 50)
	toastContainer.Size = UDim2.fromOffset(340, 400)
	toastContainer.BackgroundTransparency = 1
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastLayout.Parent = toastContainer
	toastContainer.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return panel
end

local function setBar(name: string, current: number, max: number, valueText: string?)
	local bar = bars[name]
	local fraction = max > 0 and math.clamp(current / max, 0, 1) or 0
	bar.fill.Size = UDim2.fromScale(fraction, 1)
	bar.value.Text = valueText or ("%d/%d"):format(math.floor(current + 0.5), math.floor(max + 0.5))
end

function HUD.toast(message: string, kind: string?)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(1, 0, 0, 26)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	toast.BackgroundTransparency = 0.25
	toast.Font = Enum.Font.Code
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.TextXAlignment = Enum.TextXAlignment.Right
	toast.TextColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	toast.Text = " " .. message .. " "
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = toast
	toast.Parent = toastContainer

	task.delay(3.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function HUD.init()
	local panel = buildGui()

	-- Credits from leaderstats (covers kills/sales without extra wiring).
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 30)
		local credits = leaderstats and leaderstats:WaitForChild("Credits", 10)
		if credits then
			creditsLabel.Text = ("%d CR"):format(credits.Value)
			credits.Changed:Connect(function(value)
				creditsLabel.Text = ("%d CR"):format(value)
			end)
		end
	end)

	Remotes.get("Notify").OnClientEvent:Connect(HUD.toast)

	Remotes.get("MiningState").OnClientEvent:Connect(function(state)
		miningLabel.Visible = state.active == true
		if state.active then
			miningLabel.Text = ("⛏  MINING %s  (50%% SECURED)"):format(string.upper(state.resource or ""))
		end
	end)

	-- Refresh bars from ship attributes ~10x/sec while flying.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0

		local ship = ClientState.ship
		local flying = ship ~= nil and ship.Parent ~= nil
		panel.Visible = flying
		speedLabel.Visible = flying
		if not flying then
			return
		end

		setBar("Shield", ship:GetAttribute("Shield") or 0, ship:GetAttribute("MaxShield") or 1)
		setBar("Hull", ship:GetAttribute("Hull") or 0, ship:GetAttribute("MaxHull") or 1)
		setBar("Energy", ship:GetAttribute("Energy") or 0, ship:GetAttribute("EnergyMax") or 1)
		local fill = ship:GetAttribute("CargoFill") or 0
		setBar("Cargo", fill, 1, ("%d%%  (%d cr)"):format(math.floor(fill * 100 + 0.5), ship:GetAttribute("CargoValue") or 0))

		local root = ship.PrimaryPart
		if root then
			speedLabel.Text = ("%d studs/s"):format(math.floor(root.AssemblyLinearVelocity.Magnitude + 0.5))
		end
	end)
end

return HUD

-- Orbit Legends — client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
ReplicatedStorage:WaitForChild("Shared") -- ensure shared modules replicated

local HUD = require(script.HUD)
local Nameplates = require(script.Nameplates)
local FlightController = require(script.FlightController)
local CombatClient = require(script.CombatClient)
local DockUI = require(script.DockUI)
local BaseUI = require(script.BaseUI)

HUD.init()
Nameplates.init()
FlightController.init()
CombatClient.init()
DockUI.init()
BaseUI.init()

print("[Orbit Legends] Client initialized.")

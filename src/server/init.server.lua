-- Orbit Legends — server bootstrap.
-- Initialization order matters: remotes and data first, then the world,
-- then the gameplay systems that depend on both.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Characters load only after BaseSystem has built the player's Base
-- (it calls LoadCharacter) — so everyone wakes up at home.
Players.CharacterAutoLoads = false

require(ReplicatedStorage:WaitForChild("Shared").Remotes) -- creates remote instances

local DataSystem = require(script.DataSystem)
local WorldGen = require(script.WorldGen)
local ShipSystem = require(script.ShipSystem)
local MiningSystem = require(script.MiningSystem)
local CombatSystem = require(script.CombatSystem)
local EconomySystem = require(script.EconomySystem)
local UpgradeSystem = require(script.UpgradeSystem)
local BaseSystem = require(script.BaseSystem)

DataSystem.init()
WorldGen.init()
ShipSystem.init()
MiningSystem.init()
CombatSystem.init()
EconomySystem.init()
UpgradeSystem.init()
BaseSystem.init()

print("[Orbit Legends] Server initialized.")

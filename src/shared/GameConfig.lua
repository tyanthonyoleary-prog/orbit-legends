-- GameConfig
-- Every tunable gameplay number in Orbit Legends lives in this one module.
-- Both server and client read it; the server is always authoritative.

local GameConfig = {}

----------------------------------------------------------------
-- SHIPS
-- starter = selectable for free at your base.
-- turnSpeed is used as the AlignOrientation responsiveness (≈3 sluggish, ≈10 snappy).
----------------------------------------------------------------
GameConfig.ShipOrder = {
	"Scout", "Fighter", "Hauler",
	"Interceptor", "Corvette", "MiningFrigate", "StealthVessel", "Battlecruiser",
}

GameConfig.Ships = {
	Scout = {
		displayName = "Scout", role = "Fast resource gatherer",
		starter = true, cost = 0,
		maxSpeed = 230, acceleration = 120, turnSpeed = 9,
		cargoCapacity = 60,
		damage = 6, fireRate = 4, weapon = "BasicLaser",
		maxShield = 60, shieldRegen = 8,
		maxHull = 90,
		miningRate = 3.2,
		energyMax = 100, energyRegen = 20,
	},
	Fighter = {
		displayName = "Fighter", role = "Combat focused",
		starter = true, cost = 0,
		maxSpeed = 175, acceleration = 85, turnSpeed = 7,
		cargoCapacity = 110,
		damage = 15, fireRate = 3, weapon = "BasicLaser",
		maxShield = 120, shieldRegen = 10,
		maxHull = 160,
		miningRate = 2.2,
		energyMax = 120, energyRegen = 16,
	},
	Hauler = {
		displayName = "Heavy Hauler", role = "Tank and resource carrier",
		starter = true, cost = 0,
		maxSpeed = 115, acceleration = 45, turnSpeed = 4,
		cargoCapacity = 340,
		damage = 10, fireRate = 2, weapon = "BasicLaser",
		maxShield = 240, shieldRegen = 14,
		maxHull = 340,
		miningRate = 2.8,
		energyMax = 110, energyRegen = 12,
	},

	-- Unlockable ships (purchased with credits at your base).
	Interceptor = {
		displayName = "Interceptor", role = "Hit-and-run striker",
		starter = false, cost = 25000,
		maxSpeed = 260, acceleration = 140, turnSpeed = 10,
		cargoCapacity = 70,
		damage = 10, fireRate = 5, weapon = "BurstLaser",
		maxShield = 90, shieldRegen = 10,
		maxHull = 110,
		miningRate = 2.0,
		energyMax = 110, energyRegen = 22,
	},
	Corvette = {
		displayName = "Corvette", role = "Versatile warship",
		starter = false, cost = 45000,
		maxSpeed = 165, acceleration = 80, turnSpeed = 6,
		cargoCapacity = 150,
		damage = 20, fireRate = 2.5, weapon = "PlasmaCannon",
		maxShield = 200, shieldRegen = 12,
		maxHull = 260,
		miningRate = 2.4,
		energyMax = 140, energyRegen = 16,
	},
	MiningFrigate = {
		displayName = "Mining Frigate", role = "Industrial extractor",
		starter = false, cost = 35000,
		maxSpeed = 140, acceleration = 60, turnSpeed = 5,
		cargoCapacity = 260,
		damage = 8, fireRate = 2, weapon = "BasicLaser",
		maxShield = 160, shieldRegen = 12,
		maxHull = 240,
		miningRate = 5.5,
		energyMax = 120, energyRegen = 14,
	},
	StealthVessel = {
		displayName = "Stealth Vessel", role = "Ambush predator",
		starter = false, cost = 70000,
		maxSpeed = 240, acceleration = 120, turnSpeed = 9,
		cargoCapacity = 90,
		damage = 18, fireRate = 3.5, weapon = "BurstLaser",
		maxShield = 80, shieldRegen = 14,
		maxHull = 100,
		miningRate = 2.0,
		energyMax = 130, energyRegen = 20,
	},
	Battlecruiser = {
		displayName = "Battlecruiser", role = "Capital-class bruiser",
		starter = false, cost = 140000,
		maxSpeed = 130, acceleration = 55, turnSpeed = 3.5,
		cargoCapacity = 220,
		damage = 40, fireRate = 1.2, weapon = "Railgun",
		maxShield = 420, shieldRegen = 16,
		maxHull = 600,
		miningRate = 2.0,
		energyMax = 200, energyRegen = 18,
	},
}

----------------------------------------------------------------
-- WEAPONS
-- damageMult / fireRateMult scale the ship's base Damage / FireRate stats.
-- All weapons are hitscan beams in the MVP.
----------------------------------------------------------------
GameConfig.Weapons = {
	BasicLaser      = { damageMult = 1.0, fireRateMult = 1.0, range = 900,  energyCost = 4,  beamColor = Color3.fromRGB(255, 80, 80)  },
	BurstLaser      = { damageMult = 0.6, fireRateMult = 2.2, range = 700,  energyCost = 3,  beamColor = Color3.fromRGB(255, 170, 60) },
	PlasmaCannon    = { damageMult = 1.8, fireRateMult = 0.6, range = 750,  energyCost = 9,  beamColor = Color3.fromRGB(110, 255, 130)},
	Railgun         = { damageMult = 3.5, fireRateMult = 0.3, range = 1600, energyCost = 18, beamColor = Color3.fromRGB(120, 220, 255)},
	MissileLauncher = { damageMult = 2.5, fireRateMult = 0.5, range = 1200, energyCost = 14, beamColor = Color3.fromRGB(255, 240, 120)},
}

----------------------------------------------------------------
-- RESOURCES & ASTEROID FIELDS
----------------------------------------------------------------
GameConfig.Resources = {
	Iron       = { value = 2,  color = Color3.fromRGB(155, 155, 160), material = Enum.Material.Slate, sizeMin = 14, sizeMax = 34, yieldMin = 70, yieldMax = 150 },
	Copper     = { value = 4,  color = Color3.fromRGB(196, 116, 62),  material = Enum.Material.Slate, sizeMin = 12, sizeMax = 30, yieldMin = 55, yieldMax = 120 },
	Titanium   = { value = 10, color = Color3.fromRGB(120, 138, 168), material = Enum.Material.Metal, sizeMin = 12, sizeMax = 28, yieldMin = 45, yieldMax = 95  },
	Crystal    = { value = 25, color = Color3.fromRGB(110, 225, 255), material = Enum.Material.Neon,  sizeMin = 10, sizeMax = 22, yieldMin = 30, yieldMax = 70  },
	DarkMatter = { value = 80, color = Color3.fromRGB(140, 70, 220),  material = Enum.Material.Neon,  sizeMin = 8,  sizeMax = 18, yieldMin = 18, yieldMax = 45  },
}

-- Rarer resources spawn farther from the world center. weights are relative.
GameConfig.AsteroidFields = {
	{ name = "Starter Belt",  innerRadius = 1400, outerRadius = 2700,  height = 240, count = 60, weights = { Iron = 70, Copper = 30 } },
	{ name = "Frontier Belt", innerRadius = 4200, outerRadius = 6200,  height = 400, count = 50, weights = { Iron = 20, Copper = 30, Titanium = 35, Crystal = 15 } },
	{ name = "Deep Field",    innerRadius = 7500, outerRadius = 10500, height = 600, count = 35, weights = { Titanium = 25, Crystal = 45, DarkMatter = 30 } },
}

----------------------------------------------------------------
-- MINING
----------------------------------------------------------------
GameConfig.Mining = {
	Range = 80,              -- studs from asteroid surface-ish to mine
	MaxSpeedToMine = 14,     -- must be nearly stopped
	SecuredPercent = 0.5,    -- fraction of mined resources that can never be lost
	TickSeconds = 0.25,
	RespawnSeconds = 120,    -- depleted asteroid respawn delay
}

----------------------------------------------------------------
-- COMBAT
----------------------------------------------------------------
GameConfig.Combat = {
	ShieldRegenDelay = 5,        -- seconds after last hit before shields recharge
	KillRewardCredits = 150,     -- flat bounty for a kill
	LootUnsecuredPercent = 0.5,  -- killer receives this fraction of victim's unsecured cargo value, as credits
	SpawnCooldown = 5,           -- seconds between ship launches
}

----------------------------------------------------------------
-- UPGRADES
-- Cost for next level = baseCost * costGrowth ^ currentLevel.
-- bonuses are additive percentage per level applied to base ship stats.
-- ResourceGates: buying that level also consumes resources from cargo.
----------------------------------------------------------------
GameConfig.Upgrades = {
	MaxLevel = 10,
	Categories = {
		Engine  = { baseCost = 400, costGrowth = 1.55, bonuses = { maxSpeed = 0.08, acceleration = 0.08, turnSpeed = 0.06 } },
		Shields = { baseCost = 500, costGrowth = 1.55, bonuses = { maxShield = 0.10, shieldRegen = 0.10 } },
		Mining  = { baseCost = 450, costGrowth = 1.55, bonuses = { miningRate = 0.12 } },
		Cargo   = { baseCost = 350, costGrowth = 1.50, bonuses = { cargoCapacity = 0.15 } },
		Weapons = { baseCost = 600, costGrowth = 1.60, bonuses = { damage = 0.10, fireRate = 0.05 } },
	},
	CategoryOrder = { "Engine", "Shields", "Mining", "Cargo", "Weapons" },
	ResourceGates = {
		[4]  = { Titanium = 20 },
		[7]  = { Crystal = 20 },
		[10] = { DarkMatter = 10 },
	},
}

----------------------------------------------------------------
-- ECONOMY / WORLD / DATA
-- (Zone rules now live under GameConfig.Base — every safe zone and
-- interaction range is anchored to a player's base, not a station.)
----------------------------------------------------------------
GameConfig.Economy = {
	StartingCredits = 250,
}

GameConfig.World = {
	KillFloorY = -1500, -- characters below this are rescued back to their base
	StarCount = 300,
}

GameConfig.Data = {
	StoreName = "OrbitLegends_v1",
	AutosaveSeconds = 120,
}

----------------------------------------------------------------
-- BASES
-- Every player's Base is their home: trading, selling, ship
-- upgrades, and launching all happen there. It grows from a flat
-- platform into a spherical, planet-like station. Power/defense is
-- bought with CREDITS; Robux is convenience + cosmetics only.
----------------------------------------------------------------
GameConfig.Base = {
	MaxLevel = 10,
	StartLevel = 1,

	-- PLACEMENT: bases sit on a ring just outside the Starter Belt
	-- (outer edge 2700), angle derived from UserId, so the
	-- mine -> fly home -> sell loop stays tight.
	RingRadius = 3000,
	RingMinSeparation = 400, -- nudge along the ring if another live base is closer than this

	-- ZONES: every base projects a no-PvP bubble; selling / upgrading /
	-- buying / launching require being near YOUR OWN base.
	SafeBubbleRadius = 1200,
	InteractRange = 400,
	WarpCombatLockSeconds = 10, -- can't warp home this soon after taking damage

	-- Credits to go from level L to L+1: LevelBaseCost * LevelCostGrowth^(L-1).
	LevelBaseCost = 5000,
	LevelCostGrowth = 1.6,
	-- Some base levels also consume rare resources from your ship cargo.
	LevelResourceGates = {
		[4]  = { Titanium = 40 },
		[6]  = { Crystal = 40 },
		[8]  = { DarkMatter = 20 },
		[10] = { DarkMatter = 60 },
	},

	-- Build slots unlocked at each base level (index = level).
	SlotsPerLevel = { 2, 3, 4, 5, 6, 8, 10, 12, 14, 16 },
	MaxExtraSlots = 6, -- extra slots buyable with Robux (convenience)

	-- Base shield/defense from structural level alone (before modules).
	LevelShield = { 200, 350, 550, 800, 1100, 1500, 2000, 2700, 3600, 5000 },
	IndestructibleAtMax = true, -- a maxed base can't be raided (honored in phase 2)

	-- GEOMETRY — the base is built by cloning a detailed prefab
	-- (ReplicatedStorage.BaseAssets.BaseTemplate) and scaling it with level.
	-- Module prefabs (ModuleTurret, ModuleRadar) are cloned onto slots.
	Geometry = {
		TemplateScaleMin = 0.6,  -- model scale at Lv.1
		TemplateScaleMax = 1.0,  -- model scale at Lv.MaxLevel
		LaunchHeight = 18,       -- ships spawn this far above the pad mark
		ModuleScale = 0.8,       -- player-built module prefabs scale on the deck ring
		ModuleRingPad = 14,      -- inset from the base footprint for the slot ring
		-- Fallback platform (used only if the prefab fails to load).
		FallbackDeckRadius = 60,
		FallbackDeckThickness = 6,
	},

	-- Tier names per level (from the Base Progression reference board).
	TierNames = {
		"Outpost", "Outpost", "Stronghold", "Stronghold", "Fortress",
		"Fortress", "Citadel", "Citadel", "Bastion", "Space Fortress",
	},

	-- Modules you build into slots. Power scales with credits, never Robux.
	ModuleOrder = { "Turret", "ShieldGen", "ShipPort", "Radar", "Storage" },
	Modules = {
		Turret = {
			displayName = "Cannon Turret", functional = true,
			baseCost = 2500, costGrowth = 1.5, maxLevel = 8,
			damage = 18, damageGrowth = 9, fireRate = 1.1, range = 950, -- auto-fires at hostiles
		},
		ShieldGen = {
			displayName = "Shield Generator", functional = true,
			baseCost = 3000, costGrowth = 1.55, maxLevel = 8,
			shieldPerLevel = 600, -- adds to fortress defense rating
		},
		ShipPort = {
			displayName = "Ship Port", functional = true,
			baseCost = 4000, costGrowth = 1.6, maxLevel = 4,
			-- lets the owner repair (refill shield + hull) while docked at base
		},
		Radar = {
			displayName = "Radar Array", functional = false,
			baseCost = 2000, costGrowth = 1.5, maxLevel = 5,
		},
		Storage = {
			displayName = "Storage Silo", functional = false,
			baseCost = 1500, costGrowth = 1.5, maxLevel = 6,
			capacityPerLevel = 500, -- base resource storage (used by raiding, phase 2)
		},
	},

	DefenseEnabled = true,   -- turrets retaliate against the owner's recent attacker
	DefenseTick = 0.5,       -- seconds between turret volleys
	TurretAggroSeconds = 25, -- turrets keep firing on an attacker for this long after the last hit
	TurretBeam = "Railgun",  -- reuse this weapon's beam color for turret FX
	RepairRange = 350,       -- how close the owner must be to repair at a Ship Port

	-- Cosmetic armor themes (Robux skins; "Default" is free). Visual only.
	CosmeticThemes = {
		Default = { armor = Color3.fromRGB(95, 105, 125),  trim = Color3.fromRGB(120, 200, 255) },
		Crimson = { armor = Color3.fromRGB(120, 60, 60),   trim = Color3.fromRGB(255, 90, 80)   },
		Void    = { armor = Color3.fromRGB(45, 40, 60),    trim = Color3.fromRGB(170, 90, 255)  },
		Solar   = { armor = Color3.fromRGB(130, 95, 50),   trim = Color3.fromRGB(255, 180, 70)  },
		Glacier = { armor = Color3.fromRGB(120, 140, 160), trim = Color3.fromRGB(150, 240, 255) },
	},
	CosmeticOrder = { "Default", "Crimson", "Void", "Solar", "Glacier" },

	-- Robux convenience products. IDs stay 0 until you create them in the
	-- Creator Dashboard (Monetization ▸ Developer Products) and paste them here.
	-- Until then the in-game prompt is disabled (a friendly notice, never an error).
	Convenience = {
		ExtraSlot = { productId = 0, label = "+1 Build Slot", maxBuys = 6 },
	},
}

return GameConfig

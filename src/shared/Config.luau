-- Ember Drift — Salvage Run: shared tuning and palette.
-- One job: every number and colour the client and the server agree on lives here,
-- so a balance change is one edit, never a hunt through two scripts.

local Config = {}

-- The arena is a fixed 640x480 panel centred on the screen; every position in the
-- game is an offset inside it, so the layout is the same on any screen size.
Config.ARENA_WIDTH = 640
Config.ARENA_HEIGHT = 480
Config.SHIP_SIZE = 40
Config.SHIP_SPEED = 340 -- pixels per second

-- Palette: dusk-space salvage. Deep navy background, ember orange ship and orbs,
-- gold for rare cores, cyan for UI accents, red only for danger.
Config.COLORS = {
	Background = Color3.fromRGB(14, 18, 38),
	Arena = Color3.fromRGB(26, 33, 66),
	ArenaEdge = Color3.fromRGB(76, 201, 240),
	Ship = Color3.fromRGB(255, 159, 28),
	ShipTrim = Color3.fromRGB(255, 209, 102),
	Orb = Color3.fromRGB(255, 209, 102),
	Core = Color3.fromRGB(255, 236, 139),
	Asteroid = Color3.fromRGB(108, 117, 125),
	AsteroidEdge = Color3.fromRGB(52, 58, 64),
	Text = Color3.fromRGB(244, 241, 222),
	DimText = Color3.fromRGB(168, 178, 204),
	Danger = Color3.fromRGB(239, 71, 111),
	Good = Color3.fromRGB(76, 201, 240),
	Panel = Color3.fromRGB(20, 25, 52),
}

-- Three sectors. Each one is a real step up: faster spawns, faster falls, more
-- asteroids, a new name and accent on the banner. Collect ORBS_PER_SECTOR orbs
-- to clear a sector; clearing the third wins the run.
Config.ORBS_PER_SECTOR = 12
Config.SECTORS = {
	{ Name = "Sector 1 — Drift Field", OrbInterval = 0.95, AsteroidInterval = 1.50, FallSpeed = 55, AsteroidSpeed = 90 },
	{ Name = "Sector 2 — Meteor Belt", OrbInterval = 0.80, AsteroidInterval = 1.15, FallSpeed = 75, AsteroidSpeed = 120 },
	{ Name = "Sector 3 — Ember Storm", OrbInterval = 0.65, AsteroidInterval = 0.90, FallSpeed = 95, AsteroidSpeed = 155 },
}

Config.LIVES = 3
Config.ORB_POINTS = 10
Config.CORE_POINTS = 25
Config.CORE_CHANCE = 0.15 -- a spawned orb is a rare gold core this often
Config.MAX_COMBO = 5 -- consecutive orbs without a hit; a hit resets the streak, so the multiplier drops back to x1
Config.HIT_COOLDOWN = 1.2 -- seconds of invulnerability after an asteroid hit
Config.MAX_ORBS = 14 -- on screen at once, so the arena never floods
Config.MAX_ASTEROIDS = 10

-- Server validation caps. A client that reports faster than a human can play is
-- ignored, so a tampered client cannot mint score.
Config.MAX_COLLECTS_PER_SECOND = 12
Config.MIN_HIT_INTERVAL = 0.9

return Config

-- Ember Drift — Salvage Run: client.
-- One job: everything the player sees and touches. It builds the whole interface,
-- flies the ship, spawns and moves orbs and asteroids, detects collisions and
-- reports them to the server. It never decides a score itself: every collect and
-- hit is sent to GameServer, and the numbers on screen are the server's answer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local collectOrb = remotes:WaitForChild("CollectOrb")
local shipHit = remotes:WaitForChild("ShipHit")
local requestStart = remotes:WaitForChild("RequestStart")
local gameState = remotes:WaitForChild("GameState")

local COLORS = Config.COLORS
local ARENA_W = Config.ARENA_WIDTH
local ARENA_H = Config.ARENA_HEIGHT

-- The server's last word on the run. The HUD renders this, never a local guess.
local serverState = { phase = "menu", score = 0, best = 0, lives = Config.LIVES, sector = 1, orbs = 0, streak = 0 }

-- Ship position inside the arena, in pixels from its top-left corner.
local shipX = (ARENA_W - Config.SHIP_SIZE) / 2
local shipY = ARENA_H - Config.SHIP_SIZE - 24
local invulnerableUntil = 0
local shakeUntil = 0
local playing = false

local orbs = {} -- {frame, x, y, vy, size, kind}
local asteroids = {} -- {frame, x, y, vy, size, spin}
local orbTimer = 0
local asteroidTimer = 0

-- ---------- interface ----------

local gui = Instance.new("ScreenGui")
gui.Name = "EmberDriftGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = COLORS.Background
background.BorderSizePixel = 0
background.Parent = gui

-- A sparse starfield behind the arena, drawn once from fixed positions so the
-- background looks made instead of flat. Stars never move; the game is the arena.
local starSpots = { { 0.06, 0.12 }, { 0.16, 0.05 }, { 0.28, 0.18 }, { 0.38, 0.08 }, { 0.52, 0.14 },
	{ 0.66, 0.06 }, { 0.78, 0.16 }, { 0.88, 0.07 }, { 0.94, 0.22 }, { 0.10, 0.85 }, { 0.24, 0.92 },
	{ 0.44, 0.88 }, { 0.60, 0.94 }, { 0.74, 0.86 }, { 0.90, 0.90 }, { 0.05, 0.45 }, { 0.96, 0.55 } }
for _, spot in ipairs(starSpots) do
	local star = Instance.new("Frame")
	star.Size = UDim2.fromOffset(3, 3)
	star.Position = UDim2.fromScale(spot[1], spot[2])
	star.BackgroundColor3 = COLORS.Text
	star.BackgroundTransparency = 0.55
	star.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = star
	star.Parent = background
end

local arena = Instance.new("Frame")
arena.Name = "Arena"
arena.AnchorPoint = Vector2.new(0.5, 0.5)
arena.Position = UDim2.fromScale(0.5, 0.5)
arena.Size = UDim2.fromOffset(ARENA_W, ARENA_H)
arena.BackgroundColor3 = COLORS.Arena
arena.BorderColor3 = COLORS.ArenaEdge
arena.BorderSizePixel = 2
arena.ClipsDescendants = true
arena.Parent = background

-- HUD sits above the arena, clear of the top-left corner where Roblox puts its
-- own menu buttons: score top-right, sector top-centre.
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreLabel"
scoreLabel.AnchorPoint = Vector2.new(1, 0)
scoreLabel.Position = UDim2.new(1, -16, 0, 14)
scoreLabel.Size = UDim2.fromOffset(240, 34)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 26
scoreLabel.TextColor3 = COLORS.Text
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
scoreLabel.Text = "SCORE 0"
scoreLabel.Parent = background

local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "ComboLabel"
comboLabel.AnchorPoint = Vector2.new(1, 0)
comboLabel.Position = UDim2.new(1, -16, 0, 50)
comboLabel.Size = UDim2.fromOffset(240, 24)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBold
comboLabel.TextSize = 18
comboLabel.TextColor3 = COLORS.ShipTrim
comboLabel.TextXAlignment = Enum.TextXAlignment.Right
comboLabel.Text = ""
comboLabel.Parent = background

-- Lives as three small pips (frames, not glyphs, so they render on every client).
local livesRow = Instance.new("Frame")
livesRow.Name = "LivesRow"
livesRow.AnchorPoint = Vector2.new(1, 0)
livesRow.Position = UDim2.new(1, -16, 0, 80)
livesRow.Size = UDim2.fromOffset(84, 16)
livesRow.BackgroundTransparency = 1
livesRow.Parent = background
local lifePips = {}
for i = 1, Config.LIVES do
	local pip = Instance.new("Frame")
	pip.Size = UDim2.fromOffset(16, 16)
	pip.Position = UDim2.fromOffset((i - 1) * 26, 0)
	pip.BackgroundColor3 = COLORS.Danger
	pip.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = pip
	pip.Parent = livesRow
	lifePips[i] = pip
end

local sectorLabel = Instance.new("TextLabel")
sectorLabel.Name = "SectorLabel"
sectorLabel.AnchorPoint = Vector2.new(0.5, 0)
sectorLabel.Position = UDim2.new(0.5, 0, 0, 14)
sectorLabel.Size = UDim2.fromOffset(360, 26)
sectorLabel.BackgroundTransparency = 1
sectorLabel.Font = Enum.Font.GothamBold
sectorLabel.TextSize = 20
sectorLabel.TextColor3 = COLORS.Good
sectorLabel.Text = "SECTOR 1 — DRIFT FIELD"
sectorLabel.Parent = background

local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBar"
progressBar.AnchorPoint = Vector2.new(0.5, 0)
progressBar.Position = UDim2.new(0.5, 0, 0, 44)
progressBar.Size = UDim2.fromOffset(220, 8)
progressBar.BackgroundColor3 = COLORS.Panel
progressBar.BorderSizePixel = 0
progressBar.Parent = background
local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = COLORS.Orb
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBar

-- The ship: an orange hull with a gold cockpit and a cyan engine glow.
local ship = Instance.new("Frame")
ship.Name = "Ship"
ship.Size = UDim2.fromOffset(Config.SHIP_SIZE, Config.SHIP_SIZE)
ship.BackgroundColor3 = COLORS.Ship
ship.BorderSizePixel = 0
local shipCorner = Instance.new("UICorner")
shipCorner.CornerRadius = UDim.new(0, 10)
shipCorner.Parent = ship
local cockpit = Instance.new("Frame")
cockpit.Name = "Cockpit"
cockpit.AnchorPoint = Vector2.new(0.5, 0.5)
cockpit.Position = UDim2.fromScale(0.5, 0.42)
cockpit.Size = UDim2.fromOffset(14, 14)
cockpit.BackgroundColor3 = COLORS.ShipTrim
cockpit.BorderSizePixel = 0
local cockpitCorner = Instance.new("UICorner")
cockpitCorner.CornerRadius = UDim.new(1, 0)
cockpitCorner.Parent = cockpit
cockpit.Parent = ship
local engine = Instance.new("Frame")
engine.Name = "Engine"
engine.AnchorPoint = Vector2.new(0.5, 1)
engine.Position = UDim2.new(0.5, 0, 1, -2)
engine.Size = UDim2.fromOffset(16, 6)
engine.BackgroundColor3 = COLORS.Good
engine.BorderSizePixel = 0
engine.Parent = ship
ship.Parent = arena

-- Red flash over the whole screen on a hit.
local flash = Instance.new("Frame")
flash.Name = "DamageFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = COLORS.Danger
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 5
flash.Parent = background

-- ---------- overlays ----------

local function makeOverlay(name)
	local overlay = Instance.new("Frame")
	overlay.Name = name
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.5)
	overlay.Size = UDim2.fromOffset(ARENA_W, ARENA_H)
	overlay.BackgroundColor3 = COLORS.Panel
	overlay.BackgroundTransparency = 0.12
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = background
	return overlay
end

local function makeTitle(parent, text, y, size, color)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.fromOffset(ARENA_W - 80, size + 10)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.ZIndex = 11
	label.Parent = parent
	return label
end

local function makeBody(parent, text, y, size, color)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.fromOffset(ARENA_W - 120, size + 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = size
	label.TextColor3 = color or COLORS.Text
	label.TextWrapped = true
	label.Text = text
	label.ZIndex = 11
	label.Parent = parent
	return label
end

local function makeButton(parent, text, y)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, y)
	button.Size = UDim2.fromOffset(240, 52)
	button.BackgroundColor3 = COLORS.Ship
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.TextColor3 = COLORS.Panel
	button.Text = text
	button.ZIndex = 11
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

local startOverlay = makeOverlay("StartOverlay")
makeTitle(startOverlay, "EMBER DRIFT", 70, 52, COLORS.Ship)
makeTitle(startOverlay, "— SALVAGE RUN —", 132, 22, COLORS.Good)
makeBody(startOverlay, "Fly your skiff with WASD or the arrow keys. Grab the golden embers for points — chain them without a hit to raise your combo up to x5. Dodge the asteroids: three hits end the run. Clear 12 embers to reach the next sector; clear all three to win.", 180, 18, COLORS.Text)
local bestLabel = makeBody(startOverlay, "", 300, 18, COLORS.DimText)
local playButton = makeButton(startOverlay, "▶  PLAY", 350)

local overOverlay = makeOverlay("OverOverlay")
makeTitle(overOverlay, "RUN OVER", 80, 44, COLORS.Danger)
local overScore = makeBody(overOverlay, "", 160, 22, COLORS.Text)
local overBest = makeBody(overOverlay, "", 200, 18, COLORS.DimText)
local againButton = makeButton(overOverlay, "↻  PLAY AGAIN", 330)

local winOverlay = makeOverlay("WinOverlay")
makeTitle(winOverlay, "RUN COMPLETE!", 80, 44, COLORS.ShipTrim)
makeBody(winOverlay, "You cleared all three sectors. The drift is yours — keep flying in endless mode and chase a bigger score, or start a fresh run.", 160, 18, COLORS.Text)
local winScore = makeBody(winOverlay, "", 250, 22, COLORS.Text)
local keepButton = makeButton(winOverlay, "KEEP FLYING", 320)
local freshButton = makeButton(winOverlay, "NEW RUN", 384)

-- Sector banner: slides in, holds, slides out.
local banner = Instance.new("TextLabel")
banner.Name = "SectorBanner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.38)
banner.Size = UDim2.fromOffset(ARENA_W - 40, 44)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBold
banner.TextSize = 30
banner.TextColor3 = COLORS.Good
banner.TextTransparency = 1
banner.Text = ""
banner.ZIndex = 8
banner.Parent = background

-- ---------- feedback ----------

local function showBanner(text)
	banner.Text = text
	banner.TextTransparency = 1
	local fadeIn = TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 0 })
	local fadeOut = TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 })
	fadeIn:Play()
	task.delay(1.4, function()
		fadeOut:Play()
	end)
end

local function showFloatText(x, y, text, color)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(80, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = color
	label.Text = text
	label.ZIndex = 6
	label.Parent = arena
	local tween = TweenService:Create(label, TweenInfo.new(0.7), {
		Position = UDim2.fromOffset(x, y - 44),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

local function showPickupSparkle(x, y, size)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(x, y)
	ring.Size = UDim2.fromOffset(size, size)
	ring.BackgroundTransparency = 1
	ring.BorderColor3 = COLORS.Core
	ring.BorderSizePixel = 3
	ring.ZIndex = 6
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	ring.Parent = arena
	local tween = TweenService:Create(ring, TweenInfo.new(0.35), {
		Size = UDim2.fromOffset(size + 34, size + 34),
		BackgroundTransparency = 1,
	})
	-- BorderSizePixel cannot tween and there is nothing to fade on a border-only
	-- frame, so the ring simply grows and is destroyed when the tween finishes.
	tween:Play()
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
end

local function showHitFeedback()
	flash.BackgroundTransparency = 0.45
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	shakeUntil = os.clock() + 0.25
end

-- ---------- entities ----------

local function spawnOrb()
	if #orbs >= Config.MAX_ORBS then
		return
	end
	local isCore = math.random() < Config.CORE_CHANCE
	local size = isCore and 20 or 26
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = isCore and COLORS.Core or COLORS.Orb
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	frame.Parent = arena
	local orb = {
		frame = frame,
		x = math.random(10, ARENA_W - size - 10),
		y = -size,
		vy = Config.SECTORS[serverState.sector].FallSpeed * (0.9 + math.random() * 0.3),
		size = size,
		kind = isCore and "core" or "orb",
	}
	table.insert(orbs, orb)
end

local function spawnAsteroid()
	if #asteroids >= Config.MAX_ASTEROIDS then
		return
	end
	local size = math.random(26, 52)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = COLORS.Asteroid
	frame.BorderColor3 = COLORS.AsteroidEdge
	frame.BorderSizePixel = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	frame.Parent = arena
	local asteroid = {
		frame = frame,
		x = math.random(10, ARENA_W - size - 10),
		y = -size,
		vy = Config.SECTORS[serverState.sector].AsteroidSpeed * (0.9 + math.random() * 0.4),
		size = size,
		spin = (math.random() - 0.5) * 60,
	}
	table.insert(asteroids, asteroid)
end

local function clearEntities()
	for _, orb in ipairs(orbs) do
		orb.frame:Destroy()
	end
	for _, rock in ipairs(asteroids) do
		rock.frame:Destroy()
	end
	table.clear(orbs)
	table.clear(asteroids)
end

-- ---------- HUD and overlays ----------

local function refreshHud()
	scoreLabel.Text = "SCORE " .. Util.formatScore(serverState.score)
	if serverState.streak >= 2 then
		comboLabel.Text = "COMBO x" .. Util.comboMultiplier(serverState.streak, Config.MAX_COMBO)
	else
		comboLabel.Text = ""
	end
	for i, pip in ipairs(lifePips) do
		pip.Visible = i <= serverState.lives
	end
	sectorLabel.Text = string.upper(Config.SECTORS[serverState.sector].Name)
	local intoSector = serverState.orbs % Config.ORBS_PER_SECTOR
	progressFill.Size = UDim2.fromScale(intoSector / Config.ORBS_PER_SECTOR, 1)
end

local lastSectorShown = 1
local winDismissed = false -- KEEP FLYING hides the victory overlay for good
local function refreshOverlays()
	startOverlay.Visible = serverState.phase == "menu"
	overOverlay.Visible = serverState.phase == "over"
	winOverlay.Visible = serverState.phase == "won" and not winDismissed
	if serverState.phase == "menu" then
		if serverState.best > 0 then
			bestLabel.Text = "Best score: " .. Util.formatScore(serverState.best)
		else
			bestLabel.Text = "No runs yet — make the first one count."
		end
	elseif serverState.phase == "over" then
		overScore.Text = "Score: " .. Util.formatScore(serverState.score)
			.. "   •   Embers: " .. serverState.orbs
		overBest.Text = "Best score: " .. Util.formatScore(serverState.best)
	elseif serverState.phase == "won" then
		winScore.Text = "Score: " .. Util.formatScore(serverState.score)
	end
	if serverState.sector ~= lastSectorShown and serverState.phase == "playing" then
		lastSectorShown = serverState.sector
		showBanner(Config.SECTORS[serverState.sector].Name)
	end
	refreshHud()
end

gameState.OnClientEvent:Connect(function(state)
	serverState = state
	-- "won" keeps playing: endless mode runs on after the victory overlay.
	if serverState.phase == "playing" or serverState.phase == "won" then
		playing = true
	else
		playing = false
	end
	if serverState.phase == "menu" then
		lastSectorShown = 1
		winDismissed = false
		clearEntities()
	end
	if serverState.phase == "playing" then
		winDismissed = false
	end
	refreshOverlays()
end)

-- ---------- buttons ----------

playButton.MouseButton1Click:Connect(function()
	requestStart:FireServer()
end)

againButton.MouseButton1Click:Connect(function()
	requestStart:FireServer()
end)

freshButton.MouseButton1Click:Connect(function()
	requestStart:FireServer()
end)

-- Keep flying: dismiss the victory overlay and carry on in endless mode.
keepButton.MouseButton1Click:Connect(function()
	winDismissed = true
	winOverlay.Visible = false
end)

-- ---------- main loop ----------

local function moveShip(dt)
	local dx = 0
	local dy = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) or UserInputService:IsKeyDown(Enum.KeyCode.A) then
		dx -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
		dx += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.W) then
		dy -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Down) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
		dy += 1
	end
	if dx ~= 0 or dy ~= 0 then
		local length = math.sqrt(dx * dx + dy * dy)
		shipX += (dx / length) * Config.SHIP_SPEED * dt
		shipY += (dy / length) * Config.SHIP_SPEED * dt
	end
	shipX = Util.clamp(shipX, 0, ARENA_W - Config.SHIP_SIZE)
	shipY = Util.clamp(shipY, 0, ARENA_H - Config.SHIP_SIZE)
	ship.Position = UDim2.fromOffset(math.floor(shipX + 0.5), math.floor(shipY + 0.5))
	-- Blink while invulnerable after a hit, so the player can read the state.
	if os.clock() < invulnerableUntil then
		ship.Visible = math.floor(os.clock() * 12) % 2 == 0
	else
		ship.Visible = true
	end
end

local function stepEntities(dt)
	-- Orbs drift down; a collected one pays and sparkles, a missed one is gone.
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		orb.y += orb.vy * dt
		orb.frame.Position = UDim2.fromOffset(math.floor(orb.x + 0.5), math.floor(orb.y + 0.5))
		if orb.y > ARENA_H then
			orb.frame:Destroy()
			table.remove(orbs, i)
		elseif Util.overlaps(shipX, shipY, Config.SHIP_SIZE, Config.SHIP_SIZE, orb.x, orb.y, orb.size, orb.size) then
			collectOrb:FireServer(orb.kind)
			showPickupSparkle(orb.x + orb.size / 2, orb.y + orb.size / 2, orb.size)
			-- Show the points the server will actually award: base value times the
			-- combo this collect builds (streak + 1, capped), so the float matches
			-- the score instead of always showing the unmultiplied base value.
			local points = orb.kind == "core" and Config.CORE_POINTS or Config.ORB_POINTS
			local awarded = points * Util.comboMultiplier(serverState.streak + 1, Config.MAX_COMBO)
			showFloatText(orb.x + orb.size / 2, orb.y, "+" .. awarded, COLORS.ShipTrim)
			orb.frame:Destroy()
			table.remove(orbs, i)
		end
	end
	-- Asteroids drift down and spin; a hit costs a life and shakes the screen.
	for i = #asteroids, 1, -1 do
		local rock = asteroids[i]
		rock.y += rock.vy * dt
		rock.frame.Position = UDim2.fromOffset(math.floor(rock.x + 0.5), math.floor(rock.y + 0.5))
		rock.frame.Rotation += rock.spin * dt
		if rock.y > ARENA_H then
			rock.frame:Destroy()
			table.remove(asteroids, i)
		elseif os.clock() >= invulnerableUntil
			and Util.overlaps(shipX, shipY, Config.SHIP_SIZE, Config.SHIP_SIZE, rock.x, rock.y, rock.size, rock.size) then
			invulnerableUntil = os.clock() + Config.HIT_COOLDOWN
			shipHit:FireServer()
			showHitFeedback()
			rock.frame:Destroy()
			table.remove(asteroids, i)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not playing then
		return
	end
	-- Screen shake decays on its own; the arena sits centred again afterwards.
	if os.clock() < shakeUntil then
		arena.Position = UDim2.fromOffset(
			math.random(-6, 6),
			math.random(-6, 6)
		) + UDim2.fromScale(0.5, 0.5)
		-- UDim2 addition keeps the centre anchor; offset is the shake.
		arena.AnchorPoint = Vector2.new(0.5, 0.5)
	else
		arena.Position = UDim2.fromScale(0.5, 0.5)
	end
	moveShip(dt)
	orbTimer += dt
	asteroidTimer += dt
	local sector = Config.SECTORS[serverState.sector]
	if orbTimer >= sector.OrbInterval then
		orbTimer = 0
		spawnOrb()
	end
	if asteroidTimer >= sector.AsteroidInterval then
		asteroidTimer = 0
		spawnAsteroid()
	end
	stepEntities(dt)
end)

-- Place the ship, show the menu, and wait for the server's first state.
ship.Position = UDim2.fromOffset(math.floor(shipX + 0.5), math.floor(shipY + 0.5))
refreshOverlays()
gui.Parent = player:WaitForChild("PlayerGui")

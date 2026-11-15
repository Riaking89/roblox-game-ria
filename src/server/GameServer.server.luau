-- Ember Drift — Salvage Run: server authority.
-- One job: own the numbers. The client renders the game and reports what it sees
-- (an orb collected, an asteroid hit); this script decides whether that report
-- counts, keeps the score, lives, sector and streak, and tells the client the
-- truth after every change. A tampered client can lie about positions, but it
-- cannot mint points: every report is rate-limited and worth a fixed value.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

-- RemoteEvents, created here so the client never has to guess where they live.
local remotes = Instance.new("Folder")
remotes.Name = "GameRemotes"
remotes.Parent = ReplicatedStorage

local collectOrb = Instance.new("RemoteEvent")
collectOrb.Name = "CollectOrb"
collectOrb.Parent = remotes

local shipHit = Instance.new("RemoteEvent")
shipHit.Name = "ShipHit"
shipHit.Parent = remotes

local requestStart = Instance.new("RemoteEvent")
requestStart.Name = "RequestStart"
requestStart.Parent = remotes

local gameState = Instance.new("RemoteEvent")
gameState.Name = "GameState"
gameState.Parent = remotes

-- Per-player run state. Kept in one table, reset in one place.
local states = {}

local function freshState()
	return {
		phase = "menu", -- menu | playing | won | over
		score = 0,
		best = 0,
		lives = Config.LIVES,
		sector = 1,
		orbs = 0,
		streak = 0,
		endless = false, -- true once the run is won and the player keeps playing
	}
end

local function sendState(player)
	local state = states[player]
	if state then
		gameState:FireClient(player, state)
	end
end

-- Sector from orbs collected: 12 orbs clear a sector, 3 sectors win the run.
-- Derived from the run's total orbs, not a per-sector counter, so the sector
-- can never drift out of step with the progress bar (orbs % ORBS_PER_SECTOR).
local function sectorFor(orbs)
	return Util.clamp(math.floor(orbs / Config.ORBS_PER_SECTOR) + 1, 1, #Config.SECTORS)
end

local collectLog = {} -- player -> list of recent collect timestamps (rate limit)
local lastHitAt = {} -- player -> last accepted hit timestamp (cooldown)

collectOrb.OnServerEvent:Connect(function(player, kind)
	local state = states[player]
	-- "won" stays playable: the run is complete, but endless mode keeps scoring.
	if not state or (state.phase ~= "playing" and state.phase ~= "won") then
		return
	end

	-- Rate limit: no human collects more than 12 orbs a second.
	local now = os.clock()
	local log = collectLog[player] or {}
	local fresh = {}
	for _, t in ipairs(log) do
		if now - t < 1 then
			table.insert(fresh, t)
		end
	end
	if #fresh >= Config.MAX_COLLECTS_PER_SECOND then
		collectLog[player] = fresh
		return
	end
	table.insert(fresh, now)
	collectLog[player] = fresh

	-- Only the two kinds the client can honestly report, worth a fixed value.
	local base = Config.ORB_POINTS
	if kind == "core" then
		base = Config.CORE_POINTS
	elseif kind ~= "orb" then
		return
	end

	state.streak += 1
	local multiplier = Util.comboMultiplier(state.streak, Config.MAX_COMBO)
	state.score += base * multiplier
	state.orbs += 1
	local newSector = sectorFor(state.orbs)
	if newSector > state.sector then
		state.sector = newSector
	end
	if state.orbs >= Config.ORBS_PER_SECTOR * #Config.SECTORS and not state.endless then
		state.phase = "won"
		state.endless = true
		state.best = math.max(state.best, state.score)
	end
	sendState(player)
end)

shipHit.OnServerEvent:Connect(function(player)
	local state = states[player]
	-- "won" stays playable: an asteroid can still end an endless-mode run.
	if not state or (state.phase ~= "playing" and state.phase ~= "won") then
		return
	end

	-- Cooldown: one hit at most every ~1 second, so a burst of reports is one hit.
	local now = os.clock()
	if lastHitAt[player] and now - lastHitAt[player] < Config.MIN_HIT_INTERVAL then
		return
	end
	lastHitAt[player] = now

	state.lives -= 1
	state.streak = 0
	if state.lives <= 0 then
		state.phase = "over"
		state.best = math.max(state.best, state.score)
	end
	sendState(player)
end)

-- Start (or restart) a run: one reset, then the client may play.
requestStart.OnServerEvent:Connect(function(player)
	local state = states[player] or freshState()
	local best = state.best
	states[player] = freshState()
	states[player].best = best
	states[player].phase = "playing"
	collectLog[player] = {}
	lastHitAt[player] = nil
	sendState(player)
end)

Players.PlayerAdded:Connect(function(player)
	states[player] = freshState()
	sendState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	collectLog[player] = nil
	lastHitAt[player] = nil
end)

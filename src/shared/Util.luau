-- Ember Drift — Salvage Run: small pure helpers shared by client and server.
-- One job: arithmetic and formatting both sides need, with no game state in it.

local Util = {}

-- Clamp a number into [low, high].
function Util.clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	else
		return value
	end
end

-- Axis-aligned box overlap: true when two rectangles (x, y, w, h) intersect.
-- Used for ship-vs-orb and ship-vs-asteroid collisions inside the arena.
function Util.overlaps(aX, aY, aW, aH, bX, bY, bW, bH)
	return aX < bX + bW and aX + aW > bX and aY < bY + bH and aY + aH > bY
end

-- Linear interpolation, for smooth UI motion (banner slides, progress bar).
function Util.lerp(a, b, t)
	return a + (b - a) * t
end

-- Format a score with thousands separators: 12345 -> "12,345".
-- Scores here are never negative, so no sign handling is needed.
function Util.formatScore(score)
	local text = tostring(math.floor(score))
	local out = ""
	while #text > 3 do
		out = "," .. text:sub(-3) .. out
		text = text:sub(1, -4)
	end
	return text .. out
end

-- Combo multiplier from a streak: 1x, 2x, up to MAX_COMBO.
function Util.comboMultiplier(streak, maxCombo)
	return math.min(streak, maxCombo)
end

return Util

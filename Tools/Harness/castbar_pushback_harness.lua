-- The oUF castbar on pushback (GitHub #5, FixLog 2026-09-26).
--
-- Loads the real Libs/oUF/elements/castbar.lua and drives the player's cast through a start and two
-- pushbacks, a channel cut short, an empowered cast, another unit's cast and a client without
-- C_DurationUtil. The bar is what the element's own OnUpdate draws (SetMinMaxValues, SetValue) and the
-- timer is the last duration handed to SetTimerDuration. UnitCastingDuration and the other duration
-- getters answer with the span the cast started with, as the reporter found Forever does after a delay;
-- the re-read UnitCastingInfo/UnitChannelInfo times are the new ones, as on both clients.
--
-- No rendering, no secret values (the player's cast times are readable), no pips.
-- lua Tools/Harness/castbar_pushback_harness.lua .
-- Mutations: the "castbar" entries in mutate_client.lua.
local root = arg[1] or "."
local PATH = root .. "/Libs/oUF/elements/castbar.lua"
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local TIMER_DIRECTION = { ElapsedTime = 0, RemainingTime = 1 }

-- One element loaded fresh into its own environment, so nothing leaks between runs or harnesses.
local function Load(options)
	options = options or {}
	local W = { now = 0, cast = nil, channel = nil, timers = 0 }

	local function Duration(startTime, endTime)
		local d = { startTime = startTime, endTime = endTime }
		function d:SetTimeSpan(s, e) self.startTime, self.endTime = s, (e < s) and s or e end
		function d:GetRemainingDuration() return math.max(self.endTime - W.now, 0) end
		function d:GetTotalDuration() return self.endTime - self.startTime end
		return d
	end

	local function FontString()
		local fs = {}
		function fs:SetText(text) self.text = text end
		function fs:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
		return fs
	end

	local element = { min = 0, max = 1, value = 0, shown = true, Time = FontString(), Text = FontString() }
	function element:SetMinMaxValues(min, max) self.min, self.max = min, max end
	function element:SetValue(value) self.value = value end
	function element:SetTimerDuration(duration, smoothing, direction)
		W.timers = W.timers + 1
		self.timer, self.timerDirection = duration, direction
	end
	function element:GetTimerDuration() return self.timer end
	function element:Show() self.shown = true end
	function element:Hide() self.shown = false end
	function element:IsShown() return self.shown end
	function element:SetScript(script, fn) self[script .. "Script"] = fn end
	function element:IsObjectType() return true end
	function element:GetStatusBarTexture() return true end
	function element:GetOrientation() return "HORIZONTAL" end
	function element:GetReverseFill() return false end

	local frame = { unit = options.unit or "player", Castbar = element, events = {} }
	function frame:RegisterEvent(event, method) self.events[event] = method end
	function frame:UnregisterEvent(event) self.events[event] = nil end

	-- A cast's info as the client answers it: the stored span in milliseconds, readable.
	local function CastInfo(unit)
		local c = W.cast
		if (unit ~= frame.unit or not c) then return nil end
		return c.name, c.name, 136243, c.startTime * 1000, c.endTime * 1000, false, "Cast-1", false, 133, c.castBarID
	end
	local function ChannelInfo(unit)
		local c = W.channel
		if (unit ~= frame.unit or not c) then return nil end
		return c.name, c.name, 136243, c.startTime * 1000, c.endTime * 1000, false, false, 5143, c.empowered, 3, c.castBarID
	end
	-- The span the cast started with, whatever happened since.
	local function StartedSpan(c)
		if (not c) then return nil end
		return Duration(c.firstStart, c.firstEnd)
	end

	local env = {
		Enum = { StatusBarTimerDirection = TIMER_DIRECTION, StatusBarInterpolation = { Immediate = 0 } },
		GetTime = function() return W.now end,
		GetNetStats = function() return 0, 0, 0, 0 end,
		UnitCastingInfo = CastInfo,
		UnitChannelInfo = ChannelInfo,
		UnitCastingDuration = function() return StartedSpan(W.cast) end,
		UnitChannelDuration = function() return StartedSpan(W.channel) end,
		UnitEmpoweredChannelDuration = function() return StartedSpan(W.channel) end,
		GetUnitEmpowerHoldAtMaxTime = function() return 0 end,
		UnitEmpoweredStagePercentages = function() return nil end,
		issecretvalue = function() return false end,
		C_DurationUtil = (not options.noDurationUtil) and { CreateDuration = function() return Duration(0, 0) end } or nil,
		FAILED = "Failed", INTERRUPTED = "Interrupted",
		_G = {},
		math = math, string = string, table = table, type = type, pcall = pcall, select = select,
		next = next, tonumber = tonumber, tostring = tostring, print = print, error = error,
	}
	env._G = env

	local registered
	local ns = { oUF = { AddElement = function(_, name, update, enable, disable)
		registered = { name = name, update = update, enable = enable, disable = disable }
	end } }
	-- Through the global loadfile, so mutate_client.lua can hand this a mutated copy.
	local chunk = assert(loadfile(PATH))
	setfenv(chunk, env)
	chunk("AzeriteUI", ns)
	assert(registered and registered.name == "Castbar", "the castbar element did not register")
	assert(registered.enable(frame, frame.unit), "the castbar element did not enable")

	local function Fire(event, ...)
		local method = frame.events[event]
		assert(method, "not registered: " .. event)
		method(frame, event, frame.unit, ...)
	end
	local function Frame(elapsed)
		W.now = W.now + (elapsed or 0)
		element.OnUpdateScript(element, elapsed or 0)
	end
	return W, element, Fire, Frame
end

-- The payload of every cast event carries the cast bar ID fourth (castGUID, spellID, castBarID).
local CAST_BAR_ID = 7

--------------------------------------------------------------------------------
-- The player's cast, pushed back twice
--------------------------------------------------------------------------------
do
	local W, bar, Fire, Frame = Load()
	W.now = 100
	W.cast = { name = "Frostbolt", startTime = 100, endTime = 102.5, firstStart = 100, firstEnd = 102.5, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-1", 116, CAST_BAR_ID)
	check(bar.shown and bar.casting, "the cast shows")
	Frame(1)
	check(near(bar.value, 1) and near(bar.max, 2.5), "one second in, the bar is 1 of 2.5", bar.value)

	-- Hit: the cast is pushed back half a second.
	W.cast.startTime, W.cast.endTime = 100.5, 103
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-1", 116, CAST_BAR_ID)
	Frame(0)
	check(near(bar.value, .5) and near(bar.max, 2.5), "pushed back, the bar steps back by the pushback", bar.value)
	check(bar.timer and near(bar.timer.startTime, 100.5) and near(bar.timer.endTime, 103),
		"the timer runs on the new span, not the one the cast started with", bar.timer and bar.timer.endTime)
	check(bar.timerDirection == TIMER_DIRECTION.ElapsedTime, "a cast's timer still counts up")
	check(near(bar.delay, .5), "the delay is the pushback", bar.delay)

	-- Hit again, half a second later.
	Frame(.5)
	W.cast.startTime, W.cast.endTime = 101, 103.5
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-1", 116, CAST_BAR_ID)
	check(near(bar.delay, 1), "a second pushback adds only its own half second", bar.delay)
	Frame(0)
	check(bar.Time.text == "2.0|cffff0000+1.00|r", "the time text shows the time left and the whole delay", bar.Time.text)

	-- Just before the real end, the bar is not yet full.
	Frame(103.2 - W.now)
	check(bar.value < bar.max and near(bar.value, 2.2), "the bar is not full before the cast ends", bar.value)

	-- A delay for another cast (its castBarID) changes nothing.
	local before = bar.startTime
	W.cast.startTime = 102
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-2", 116, CAST_BAR_ID + 1)
	check(bar.startTime == before and near(bar.delay, 1), "a delay for another cast is ignored")
end

--------------------------------------------------------------------------------
-- The player's channel, cut short
--------------------------------------------------------------------------------
do
	local W, bar, Fire, Frame = Load()
	W.now = 200
	W.channel = { name = "Arcane Missiles", startTime = 200, endTime = 203, firstStart = 200, firstEnd = 203, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_CHANNEL_START", "Cast-3", 5143, CAST_BAR_ID)
	check(bar.channeling, "the channel shows")
	Frame(1)
	check(near(bar.value, 2), "one second in, two seconds of the channel are left", bar.value)

	W.channel.startTime, W.channel.endTime = 199.5, 202.5
	Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "Cast-3", 5143, CAST_BAR_ID)
	Frame(0)
	check(near(bar.value, 1.5), "cut short, the channel shows half a second less left", bar.value)
	check(bar.timer and near(bar.timer.startTime, 199.5) and near(bar.timer.endTime, 202.5)
		and bar.timerDirection == TIMER_DIRECTION.RemainingTime, "the channel's timer counts down the new span")
	check(near(bar.delay, .5), "the channel's delay is the time lost", bar.delay)
end

--------------------------------------------------------------------------------
-- An empowered cast keeps what it had
--------------------------------------------------------------------------------
do
	local W, bar, Fire = Load()
	W.now = 300
	W.channel = { name = "Fire Breath", startTime = 300, endTime = 302, firstStart = 300, firstEnd = 302,
		castBarID = CAST_BAR_ID, empowered = true }
	Fire("UNIT_SPELLCAST_EMPOWER_START", "Cast-4", 357208, CAST_BAR_ID)
	check(bar.empowering, "the empowered cast shows")
	W.channel.startTime, W.channel.endTime = 300.5, 302.5
	Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "Cast-4", 357208, CAST_BAR_ID)
	check(near(bar.startTime, 300) and near(bar.endTime, 302), "an empowered cast's times are left alone", bar.startTime)
	check(bar.timer and near(bar.timer.endTime, 302), "and its timer is the client's", bar.timer and bar.timer.endTime)
end

--------------------------------------------------------------------------------
-- Another unit's cast: its times cannot be read, so nothing is stored
--------------------------------------------------------------------------------
do
	local W, bar, Fire = Load({ unit = "focus" })
	W.now = 400
	W.cast = { name = "Shadow Bolt", startTime = 400, endTime = 402, firstStart = 400, firstEnd = 402, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-5", 686, CAST_BAR_ID)
	W.cast.startTime, W.cast.endTime = 400.5, 402.5
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-5", 686, CAST_BAR_ID)
	check(bar.startTime == nil and bar.endTime == nil, "another unit's cast stores no times", bar.startTime)
	check(bar.timer and near(bar.timer.endTime, 402) and bar.delay == 0, "its timer is the client's and no delay is counted")
end

--------------------------------------------------------------------------------
-- A client without C_DurationUtil
--------------------------------------------------------------------------------
do
	local W, bar, Fire, Frame = Load({ noDurationUtil = true })
	W.now = 500
	W.cast = { name = "Fireball", startTime = 500, endTime = 503, firstStart = 500, firstEnd = 503, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-6", 133, CAST_BAR_ID)
	Frame(1)
	W.cast.startTime, W.cast.endTime = 500.5, 503.5
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-6", 133, CAST_BAR_ID)
	Frame(0)
	check(near(bar.value, .5), "without C_DurationUtil the bar still steps back", bar.value)
	check(bar.timer and near(bar.timer.endTime, 503), "and the timer is the client's", bar.timer and bar.timer.endTime)
end

print(string.format("Castbar pushback: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("castbar pushback harness failed", 0) end

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
		if (W.rejectTimer) then error("timer rejected") end
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
	if (options.noTimer) then
		-- The engine timer cannot be read back (the player's bar is drawn by SetValue every frame).
		element.SetTimerDuration, element.GetTimerDuration = nil, nil
	end

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
		if (c.noDuration) then return nil end
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
		GetUnitEmpowerHoldAtMaxTime = function() return options.empowerHold or 0 end,
		UnitEmpoweredStagePercentages = function() return nil end,
		issecretvalue = function(value) return options.secretHold ~= nil and value == options.secretHold end,
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
	if (options.partyOverlay) then
		local f = assert(io.open(root .. "/Components/UnitFrames/Units/Party.lua", "rb"))
		local party = f:read("*a")
		f:close()
		local callback = assert(party:match("local CastOverlay_Hide = function%(element%)(.-)\nend"))
		local hide = assert(loadstring("return function(element)" .. callback .. "\nend"))()
		assert(party:find("castbar.requireCastTimer = true", 1, true))
		element.requireCastTimer = true
		element.PostCastStop, element.PostCastFail, element.PostCastInterrupted = hide, hide, hide
	end

	local function Fire(event, ...)
		local method = frame.events[event]
		assert(method, "not registered: " .. event)
		method(frame, event, frame.unit, ...)
	end
	local function Frame(elapsed)
		W.now = W.now + (elapsed or 0)
		element.OnUpdateScript(element, elapsed or 0)
	end
	return W, element, Fire, Frame, frame
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

--------------------------------------------------------------------------------
-- A cast with no castBarID ends (Dcryfm's party health bars, FixLog 2026-10-16)
--------------------------------------------------------------------------------
-- castBarID is optional in the payload and the info returns. CastStart then keeps the cast GUID,
-- but the stop events pass only castBarID (nil), so the bar used to stay up at full for good.
do
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 600
	W.cast = { name = "Healing Touch", startTime = 600, endTime = 602, firstStart = 600, firstEnd = 602 }
	Fire("UNIT_SPELLCAST_START", "Cast-1", 5185, nil)
	check(bar.shown and bar.casting, "a party cast without a cast bar ID shows")
	Frame(1)
	check(bar.shown, "and stays up while the unit is still casting")
	Fire("UNIT_SPELLCAST_FAILED", "Cast-9", 774, nil)
	check(bar.shown and bar.casting, "a failed attempt at another spell mid-cast changes nothing")
	W.cast = nil
	Fire("UNIT_SPELLCAST_STOP", "Cast-1", 5185, nil)
	Frame(0)
	check(not bar.shown, "the stop without a cast bar ID hides the bar")
end
do
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 700
	W.channel = { name = "Tranquility", startTime = 700, endTime = 708, firstStart = 700, firstEnd = 708 }
	Fire("UNIT_SPELLCAST_CHANNEL_START", "Cast-2", 740, nil)
	check(bar.shown and bar.channeling, "a party channel without a cast bar ID shows")
	W.channel = nil
	Fire("UNIT_SPELLCAST_CHANNEL_STOP", "Cast-2", 740, nil, nil)
	Frame(0)
	check(not bar.shown, "the channel stop without a cast bar ID hides the bar")
end
do
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 800
	W.cast = { name = "Wrath", startTime = 800, endTime = 801.5, firstStart = 800, firstEnd = 801.5, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-3", 5176, CAST_BAR_ID)
	Frame(.6)
	check(bar.shown, "the backstop leaves a running cast alone")
	-- The stop never arrives (lost, or the frame changed units): the backstop hides it.
	W.cast = nil
	Frame(.6)
	check(not bar.shown, "a cast that ended without a matching stop is hidden within half a second")
end

--------------------------------------------------------------------------------
-- The client still answers a cast after it ended (Dcryfm on 5.28.0, FixLog 2026-10-17)
--------------------------------------------------------------------------------
-- No stop arrives and UnitCastingInfo goes on returning the cast, so IsCastOver never fires.
-- The bar's own timer has run out; past its end on two checks in a row, it hides.
do
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 900
	W.cast = { name = "Steady Shot", startTime = 900, endTime = 901, firstStart = 900, firstEnd = 901 }
	Fire("UNIT_SPELLCAST_START", "Cast-4", 56641, nil)
	for _ = 1, 3 do Frame(.25) end -- 900.75: running
	check(bar.shown, "the timer backstop leaves a running cast alone")
	for _ = 1, 2 do Frame(.25) end -- 901.25: first check past the end
	check(bar.shown, "one check past the end is not enough (a late stop still lands)")
	for _ = 1, 4 do Frame(.25) end -- 902.25
	check(not bar.shown and not bar.casting, "a cast the client keeps answering is hidden once its timer is spent")
end
do
	-- A stop .3 s after the end, as with latency: the bar is still up when it lands.
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 1000
	W.cast = { name = "Wrath", startTime = 1000, endTime = 1001, firstStart = 1000, firstEnd = 1001 }
	Fire("UNIT_SPELLCAST_START", "Cast-5", 5176, nil)
	for _ = 1, 13 do Frame(.1) end -- 1001.3
	check(bar.shown and bar.casting, "a stop arriving shortly after the end is not pre-empted")
	W.cast = nil
	Fire("UNIT_SPELLCAST_STOP", "Cast-5", 5176, nil)
	check(not bar.casting, "and the stop itself ends the cast")
end
do
	-- Pushed back past its first end: the new timer counts, not the old one.
	local W, bar, Fire, Frame = Load({ unit = "party1" })
	W.now = 1100
	-- With a cast bar ID: without one, CastUpdate cannot match the delay and keeps the old timer.
	W.cast = { name = "Healing Touch", startTime = 1100, endTime = 1101, firstStart = 1100, firstEnd = 1101, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-6", 5185, CAST_BAR_ID)
	Frame(.5)
	W.cast.startTime, W.cast.endTime = 1101, 1102
	W.cast.firstStart, W.cast.firstEnd = 1101, 1102
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-6", 5185, CAST_BAR_ID)
	for _ = 1, 6 do Frame(.25) end -- 1102: past the first end by a second
	check(bar.shown and bar.casting, "a pushed-back cast is not hidden at its first end")
end

--------------------------------------------------------------------------------
-- The player's own party frame stays white (maintainer on 5.37.x, FixLog 2026-11-08)
--------------------------------------------------------------------------------
-- The client goes on answering the player's cast and the engine timer cannot be read, so neither
-- earlier backstop fires. The player's readable end time does: past it on two checks, it hides.
do
	local W, bar, Fire, Frame = Load({ noTimer = true })
	W.now = 1200
	W.cast = { name = "Wrath", startTime = 1200, endTime = 1201.5, firstStart = 1200, firstEnd = 1201.5 }
	Fire("UNIT_SPELLCAST_START", "Cast-7", 5176, nil)
	for _ = 1, 5 do Frame(.25) end -- 1201.25: running
	check(bar.shown and bar.casting, "the player's running cast is left alone without a timer")
	for _ = 1, 2 do Frame(.25) end -- 1201.75: first check past the end
	check(bar.shown, "one check past the player's end time is not enough")
	for _ = 1, 4 do Frame(.25) end -- 1202.75
	check(not bar.shown and not bar.casting, "a player cast the client keeps answering hides after its end time")
end
do
	-- Another unit without a readable timer is not judged by the player's times.
	local W, bar, Fire, Frame = Load({ unit = "party1", noTimer = true })
	W.now = 1300
	W.cast = { name = "Wrath", startTime = 1300, endTime = 1301, firstStart = 1300, firstEnd = 1301 }
	Fire("UNIT_SPELLCAST_START", "Cast-8", 5176, nil)
	for _ = 1, 12 do Frame(.25) end -- 1303
	check(bar.shown and bar.casting, "a party unit's cast is never cut by the player end-time check")
end
do
	-- A header button that showed the player, then a party member: the old times are dropped.
	local W, bar, Fire, Frame, frame = Load()
	W.now = 1400
	W.cast = { name = "Wrath", startTime = 1400, endTime = 1401, firstStart = 1400, firstEnd = 1401, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_START", "Cast-9", 5176, CAST_BAR_ID)
	W.cast = nil
	Fire("UNIT_SPELLCAST_STOP", "Cast-9", 5176, CAST_BAR_ID)
	Frame(0)
	frame.unit = "party1"
	W.now = 1410
	W.cast = { name = "Healing Touch", startTime = 1410, endTime = 1413, firstStart = 1410, firstEnd = 1413 }
	Fire("UNIT_SPELLCAST_START", "Cast-10", 5185, nil)
	check(bar.startTime == nil and bar.endTime == nil, "the player's old times are cleared for another unit's cast", bar.endTime)
	bar.value = 0
	Frame(.1)
	check(bar.value ~= bar.max, "another unit's cast is not drawn full from the player's old times", bar.value)
end

-- Party overlays must disappear on the event, even before another rendered frame.
for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
	local W, bar, Fire = Load({ partyOverlay = true })
	W.now = 1500
	W.cast = { name = "Wrath", startTime = 1500, endTime = 1502, firstStart = 1500, firstEnd = 1502 }
	Fire("UNIT_SPELLCAST_START", "Cast-zone", 5176, nil)
	W.cast = nil
	Fire(event, "Cast-zone", 5176, nil)
	check(not bar.shown, "party overlay hides immediately on " .. event)
end
do
	local W, bar, Fire = Load({ partyOverlay = true })
	W.now = 1600
	W.cast = { name = "Wrath", startTime = 1600, endTime = 1602, firstStart = 1600, firstEnd = 1602 }
	Fire("UNIT_SPELLCAST_START", "Cast-zone", 5176, nil)
	W.cast = nil -- cast disappears during the loading screen, no stop event
	bar:ForceUpdate()
	check(not bar.shown and not bar.casting, "post-zone ForceUpdate clears a stale player overlay")
	W.cast = { name = "Wrath", startTime = 1601, endTime = 1603, firstStart = 1601, firstEnd = 1603 }
	bar:ForceUpdate()
	check(bar.shown and bar.casting, "post-zone ForceUpdate retains a current player cast")
end

-- A missed stop followed by a different type of cast must not leak flags or progress.
do
	local W, bar, Fire, Frame = Load({ partyOverlay = true, empowerHold = 1000 })
	W.now = 1700
	W.channel = { name = "Fire Breath", startTime = 1700, endTime = 1702, firstStart = 1700, firstEnd = 1702,
		empowered = true, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_EMPOWER_START", "Cast-1", 357208, CAST_BAR_ID)
	check(bar.endTime == 1703, "the player's empower includes the hold at max")
	W.channel = nil
	W.cast = { name = "Wrath", startTime = 1700, endTime = 1702, firstStart = 1700, firstEnd = 1702 }
	Fire("UNIT_SPELLCAST_START", "Cast-1", 5176, nil)
	check(bar.casting and not bar.channeling and not bar.empowering, "a new cast replaces the previous empower flags")
	Fire("UNIT_SPELLCAST_EMPOWER_STOP", "Old-cast", 357208, true, nil, CAST_BAR_ID)
	check(bar.shown and bar.casting, "a late empower stop does not remove the new cast")
	W.cast.startTime, W.cast.endTime = 1700.5, 1702.5
	Fire("UNIT_SPELLCAST_DELAYED", "Cast-1", 5176, nil)
	check(bar.endTime == 1702.5, "a matching cast GUID supports pushback without a cast bar ID")
	for _ = 1, 5 do Frame(.5) end
	check(bar.shown, "the current cast survives its first expired check")
	Frame(.5)
	check(not bar.shown, "a missed empower stop cannot exempt the next cast from expiry")
end
do
	local W, bar, Fire, Frame, frame = Load({ unit = "party1", partyOverlay = true })
	W.now = 1800
	W.cast = { name = "Wrath", startTime = 1800, endTime = 1802, firstStart = 1800, firstEnd = 1802 }
	Fire("UNIT_SPELLCAST_START", "Cast-1", 5176, nil)
	bar:SetValue(1)
	W.cast.noDuration = true
	bar:ForceUpdate()
	check(not bar.shown and not bar.casting, "an unavailable timer cannot show the previous fill")
	W.cast.noDuration = nil
	bar:ForceUpdate()
	check(bar.shown, "a later valid timer restores the overlay")
	W.rejectTimer = true
	bar:ForceUpdate()
	check(not bar.shown, "a rejected timer cannot show the previous fill")
	W.rejectTimer = false
	bar:ForceUpdate()
	frame.unit = "party2"
	Frame(.5)
	check(not bar.shown, "a recycled frame cannot keep the previous unit's cast")
end
do
	local W, bar, Fire, Frame = Load({ partyOverlay = true, noTimer = true })
	W.now = 1900
	W.cast = { name = "Wrath", startTime = 1900, endTime = 1902, firstStart = 1900, firstEnd = 1902 }
	bar:SetValue(1)
	Fire("UNIT_SPELLCAST_START", "Cast-1", 5176, nil)
	check(bar.shown and bar.value == 0, "player fallback starts with an empty overlay")
	Frame(.5)
	check(bar.value == .5, "the readable player timer advances the overlay")
end

-- Keep a real hold, but clear the light layer if the channel API stays stale.
for _, unit in ipairs({ "player", "party1" }) do
	local W, bar, Fire, Frame = Load({ unit = unit, partyOverlay = true, empowerHold = 1000 })
	W.now = 2000
	W.channel = { name = "Fire Breath", startTime = 2000, endTime = 2002, firstStart = 2000,
		firstEnd = 2002, empowered = true, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_EMPOWER_START", "Cast-1", 357208, CAST_BAR_ID)
	for _ = 1, 4 do Frame(.5) end
	check(bar.shown, unit .. ": the overlay remains at the start of the hold")
	W.channel.endTime = 2003
	Fire("UNIT_SPELLCAST_EMPOWER_UPDATE", "Cast-1", 357208, CAST_BAR_ID)
	for _ = 1, 4 do Frame(.5) end
	check(bar.shown, unit .. ": the extended hold and first expiry check leave the overlay up")
	Frame(.5)
	check(not bar.shown and not bar.empowering, unit .. ": stale empower clears after its extended hold")
end

do
	local W, bar, Fire, Frame = Load({ unit = "party1", partyOverlay = true, empowerHold = 987, secretHold = 987 })
	W.now = 2100
	W.channel = { name = "Fire Breath", startTime = 2100, endTime = 2102, firstStart = 2100,
		firstEnd = 2102, empowered = true, castBarID = CAST_BAR_ID }
	Fire("UNIT_SPELLCAST_EMPOWER_START", "Cast-1", 357208, CAST_BAR_ID)
	for _ = 1, 8 do Frame(.5) end
	check(bar.shown, "a secret empower hold cannot expire the overlay early")
	W.channel = nil
	Frame(.5)
	check(not bar.shown, "an empower with secret hold still clears when its channel disappears")
end

print(string.format("Castbar pushback: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("castbar pushback harness failed", 0) end

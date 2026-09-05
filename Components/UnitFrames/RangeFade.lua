--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
--[[

	Range fading at a distance of the user's choosing.

	The oUF Range element asks UnitInRange, which is the game's own group check
	and always means roughly 40 yards. There is no API that reports a unit's
	distance in combat, so any shorter distance has to be measured the way every
	range addon measures it: by asking whether a spell or item of a known range
	could be used on the unit. LibRangeCheck-3.0 keeps those tables.

	That answer depends on what the player can currently cast or use, so it
	changes with spec, level, talents and bag contents, and changes again in
	combat, where interact-distance checks are forbidden. Checkers are therefore
	cached per distance and thrown away whenever either can have changed.

	Three consequences are worth knowing about:

	- Checks are polled rather than event driven, so frames using a custom
	  distance are ticked. Frames left at 40 yards keep the stock element and
	  cost nothing.
	- A class may have nothing that reaches the chosen distance, in which case
	  the frames fall back to the game's own check rather than fading the entire
	  group out.
	- The game's check only covers your own group, so enemy frames have nothing
	  to fall back on and always take the measured path, even at 40 yards. That
	  path is open to them in combat too: the restriction on item and interact
	  checks applies to units you cannot attack.

--]]
local _, ns = ...

local LibRangeCheck = LibStub("LibRangeCheck-3.0", true)

local RangeFade = {}
ns.RangeFade = RangeFade

-- Lua API
local next = next
local type = type

-- WoW API
local InCombatLockdown = InCombatLockdown
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitInRange = UnitInRange
local UnitIsConnected = UnitIsConnected
local UnitIsUnit = UnitIsUnit

-- The distance the game's own group check covers, and the value the options
-- treat as "leave it to Blizzard". Anything this far or further keeps the stock
-- element and its free, event driven updates.
local DEFAULT_RANGE = 40

-- Spell and item range checks answer only when asked, so the frames using one
-- are polled. Blizzard's compact frames poll at the same rate, which keeps the
-- two sets of group frames fading in step.
local UPDATE_INTERVAL = .2

local Frames = {} -- frames currently using a custom distance
local Checkers = {} -- [range] = { friend = checker or false, harm = checker or false }
local ticker

-- The distances available are whatever the player's spells and items happen to
-- cover, so a requested one usually falls between two of them. Take whichever
-- lands closer rather than always rounding the same way, and on a tie take the
-- longer: fading someone who is actually in range is the more visible mistake.
local PickChecker = function(under, underRange, over, overRange, range)
	if (not under) then return over end
	if (not over) then return under end
	if (range - underRange < overRange - range) then return under end
	return over
end

-- Both unit types can come back empty when the player has nothing that reaches
-- this far. That is stored as false so the miss is cached too, rather than
-- asking the library again on every single tick.
local GetCheckers = function(range)
	local checkers = Checkers[range]
	if (checkers) then return checkers end

	checkers = { friend = false, harm = false }

	if (LibRangeCheck) then
		-- Friendly checks lose their item and interact-distance entries in
		-- combat, where the game forbids them on units you cannot attack.
		-- Hostile checks keep everything, which is the only reason enemy frames
		-- can be faded at all.
		local inCombat = InCombatLockdown()

		local under, underRange = LibRangeCheck:GetFriendMaxChecker(range, inCombat)
		local over, overRange = LibRangeCheck:GetFriendMinChecker(range, inCombat)
		checkers.friend = PickChecker(under, underRange, over, overRange, range) or false

		under, underRange = LibRangeCheck:GetHarmMaxChecker(range)
		over, overRange = LibRangeCheck:GetHarmMinChecker(range)
		checkers.harm = PickChecker(under, underRange, over, overRange, range) or false
	end

	Checkers[range] = checkers

	return checkers
end

-- Alpha is written only where it changes. These frames carry a secure hook that
-- syncs the 3D portrait on every SetAlpha, and five times a second across forty
-- raid frames is a lot of work to keep arriving at the same number. The last
-- value is remembered on the element, and cleared whenever a frame joins or
-- leaves, so the first update after either always writes.
local ApplyAlpha = function(frame, element, alpha)
	if (element.__rangeAlpha ~= alpha) then
		element.__rangeAlpha = alpha
		frame:SetAlpha(alpha)
	end
end

local UpdateFrame = function(frame)
	local element = frame.Range
	if (not element) then return end

	local unit = frame.unit
	if (not unit or not UnitExists(unit)) then return end

	local insideAlpha = element.insideAlpha or 1
	local outsideAlpha = element.outsideAlpha or .55

	-- You are always within your own range, and a disconnected member has no
	-- position to measure. Both would otherwise read as permanently far away.
	if (UnitIsUnit(unit, "player") or not UnitIsConnected(unit)) then
		return ApplyAlpha(frame, element, insideAlpha)
	end

	local checkers = GetCheckers(element.checkRange or DEFAULT_RANGE)
	local checker = UnitCanAttack("player", unit) and checkers.harm or checkers.friend
	if (checker) then
		return ApplyAlpha(frame, element, checker(unit) and insideAlpha or outsideAlpha)
	end

	-- Nothing reaches the chosen distance right now. Fall back to the game's own
	-- check for group members, and leave anyone it cannot answer for visible:
	-- a frame at full opacity is a smaller lie than a group that looks gone.
	if (UnitInParty(unit) or UnitInRaid(unit)) then
		local inRange, checkedRange = UnitInRange(unit)
		return ApplyAlpha(frame, element, (inRange or not checkedRange) and insideAlpha or outsideAlpha)
	end

	ApplyAlpha(frame, element, insideAlpha)
end

-- Signature of an oUF element override, which is handed the frame and the event.
local Override = function(frame)
	UpdateFrame(frame)
end

local OnUpdate = function()
	for frame in next,Frames do
		if (frame:IsVisible()) then
			UpdateFrame(frame)
		end
	end
end

local UpdateTicker = function()
	if (next(Frames)) then
		if (not ticker) then
			ticker = C_Timer.NewTicker(UPDATE_INTERVAL, OnUpdate)
		end
	elseif (ticker) then
		ticker:Cancel()
		ticker = nil
	end
end

local Invalidate = function()
	wipe(Checkers)
	OnUpdate()
end

--[[
	Points a frame's Range element at the given distance in yards.

	Anything at or above the game's own 40 yard check, a distance we cannot
	measure, or a frame without the element at all, falls back to stock
	behavior. Callers can pass the raw setting without checking it first.

	Pass alwaysMeasure for frames holding units the group check cannot answer
	for - enemies - where stock behavior is no fading at all, and the measured
	path is the only one that does anything.
]]
RangeFade.Apply = function(frame, range, alwaysMeasure)
	local element = frame and frame.Range
	if (not element) then return end

	if (not LibRangeCheck or type(range) ~= "number") then
		return RangeFade.Release(frame)
	end

	if (range >= DEFAULT_RANGE and not alwaysMeasure) then
		return RangeFade.Release(frame)
	end

	element.checkRange = range
	element.Override = Override
	element.__rangeAlpha = nil

	Frames[frame] = true
	UpdateTicker()
	UpdateFrame(frame)
end

--[[
	Returns a frame to the stock element and stops polling it.

	Safe to call on frames that were never registered, which is what the unit
	modules do whenever their range indicator is switched off.
]]
RangeFade.Release = function(frame)
	local element = frame and frame.Range
	if (element) then
		element.checkRange = nil
		element.Override = nil
		element.__rangeAlpha = nil
	end

	if (Frames[frame]) then
		Frames[frame] = nil
		UpdateTicker()
	end
end

-- Leaving or entering combat swaps which checks are legal, and the library
-- tells us when the player's own spells and items have changed.
local Handler = CreateFrame("Frame")
Handler:RegisterEvent("PLAYER_REGEN_DISABLED")
Handler:RegisterEvent("PLAYER_REGEN_ENABLED")
Handler:SetScript("OnEvent", Invalidate)

if (LibRangeCheck and LibRangeCheck.RegisterCallback) then
	LibRangeCheck.RegisterCallback(RangeFade, LibRangeCheck.CHECKERS_CHANGED, Invalidate)
end

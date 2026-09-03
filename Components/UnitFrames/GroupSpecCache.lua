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

	Specialization lookup for group members.

	There is no API that simply reports a party member's specialization. The only
	route is the inspect system: NotifyInspect, wait for INSPECT_READY, then read
	GetInspectSpecialization before something else clears the inspect slot. That
	makes every answer here best-effort and inherently late:

	- inspect only reaches units that are connected, visible, in range and on a
	  faction we are allowed to inspect
	- only one inspect can be in flight at a time, and other addons share it
	- a member who is out of range at login stays unknown until they come close

	So callers must treat a nil result as "not known yet" rather than "no spec",
	and must render something sensible in the meantime. GroupSpecCache fires the
	"GroupSpecCache_Updated" callback whenever a unit resolves, so a frame can
	redraw itself at that point instead of polling.

	The player's own specialization never goes through inspect.

--]]
local _, ns = ...
local API = ns.API

local GroupSpecCache = {}
ns.GroupSpecCache = GroupSpecCache

-- Lua API
local next = next
local type = type

-- WoW API
-- GetSpecialization and GetSpecializationInfo are deprecated in favour of the
-- C_SpecializationInfo namespace. Shadowed as file locals so the call sites and
-- the type() guards around them keep working whichever the client still exposes.
local GetSpecialization = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecializationInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo

-- Only one inspect may be in flight at a time and the slot is shared with every
-- other addon, so requests are spaced rather than raced. This is a floor between
-- consecutive requests, not the cadence: the queue advances the moment a result
-- arrives, so a group usually resolves far faster than interval times members.
local INSPECT_INTERVAL = 0.5

-- A resolved spec is kept until the unit changes spec. A failed attempt is
-- retried, but not immediately, or an out-of-range member would keep the queue
-- busy forever.
local RETRY_INTERVAL = 15

-- INSPECT_READY is not guaranteed to arrive. Without a deadline a dropped reply
-- would leave `pending` set and stall the queue for the rest of the session.
local PENDING_TIMEOUT = 3

-- The roster event fires several times while a group forms, and units are not
-- immediately inspectable when it does. Retry briefly rather than waiting for
-- the next tick.
local ROSTER_SETTLE = 0.25

local lastRequest = 0

local specByGUID = {}
local staleGUID = {}
local lastAttempt = {}
local pending = nil
local pendingSince = 0
local ticker = nil

local GetPlayerSpecID = function()
	if (type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function") then
		return nil
	end
	local ok, index = API.TryCall(GetSpecialization)
	if (not ok or type(index) ~= "number") then
		return nil
	end
	local okInfo, specID = API.TryCall(GetSpecializationInfo, index)
	if (not okInfo or type(specID) ~= "number" or specID <= 0) then
		return nil
	end
	return specID
end

-- Inspect is pointless on a unit we cannot reach, and CanInspect alone does not
-- account for distance. Checking first keeps the queue moving.
local CanInspectUnit = function(unit)
	if (type(unit) ~= "string" or not UnitExists(unit)) then
		return false
	end
	if (UnitIsUnit(unit, "player")) then
		return false
	end
	if (not UnitIsPlayer(unit) or not UnitIsConnected(unit)) then
		return false
	end
	if (type(CanInspect) == "function") then
		local ok, canInspect = API.TryCall(CanInspect, unit, false)
		if (not ok or not canInspect) then
			return false
		end
	end
	if (type(UnitIsVisible) == "function" and not UnitIsVisible(unit)) then
		return false
	end
	if (type(CheckInteractDistance) == "function") then
		-- Distance index 1 is inspect range.
		local ok, inRange = API.TryCall(CheckInteractDistance, unit, 1)
		if (ok and inRange == false) then
			return false
		end
	end
	return true
end

local IterateGroupUnits = function(callback)
	if (IsInRaid()) then
		for index = 1, GetNumGroupMembers() do
			callback("raid" .. index)
		end
	else
		for index = 1, GetNumSubgroupMembers() do
			callback("party" .. index)
		end
	end
end

--[[
	Returns the cached specialization ID for a unit, or nil when it is not known.

	nil means "not resolved yet", never "this unit has no specialization". Callers
	must render a fallback and redraw on GroupSpecCache_Updated.
]]
GroupSpecCache.GetSpecID = function(_, unit)
	if (type(unit) ~= "string" or not UnitExists(unit)) then
		return nil
	end
	if (UnitIsUnit(unit, "player")) then
		return GetPlayerSpecID()
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string") then
		return nil
	end
	return specByGUID[guid]
end

--[[
	Returns icon, specName for a unit, or nil when the spec is not known yet.
]]
GroupSpecCache.GetSpecInfo = function(self, unit)
	local specID = self:GetSpecID(unit)
	if (not specID or type(GetSpecializationInfoByID) ~= "function") then
		return nil
	end
	local ok, _, specName, _, icon = API.TryCall(GetSpecializationInfoByID, specID)
	if (not ok or (type(icon) ~= "number" and type(icon) ~= "string")) then
		return nil
	end
	return icon, (type(specName) == "string") and specName or nil
end

local FinishPending = function()
	if (pending and type(ClearInspectPlayer) == "function") then
		API.TryCall(ClearInspectPlayer)
	end
	pending = nil
	pendingSince = 0
end

-- NotifyInspect is not a protected call and Blizzard's own inspect works in
-- combat, so there is deliberately no combat gate here. Gating on combat meant a
-- group that zoned in and pulled immediately - which is every dungeon - could go
-- a long time before any specialization resolved.
local RequestNext = function()
	local now = GetTime()

	if (pending) then
		if ((now - pendingSince) < PENDING_TIMEOUT) then
			return
		end
		-- The reply never came. Drop it and move on.
		FinishPending()
	end

	local target
	IterateGroupUnits(function(unit)
		if (target) then
			return
		end
		local guid = UnitGUID(unit)
		if (type(guid) ~= "string") then
			return
		end
		-- A cached spec is skipped unless it was carried over from an earlier
		-- group, in which case it is shown immediately and refreshed here.
		if (specByGUID[guid] and not staleGUID[guid]) then
			return
		end
		local attempted = lastAttempt[guid]
		if (attempted and (now - attempted) < RETRY_INTERVAL) then
			return
		end
		if (CanInspectUnit(unit)) then
			target = unit
		end
	end)

	if (not target) then
		return
	end

	local guid = UnitGUID(target)
	lastAttempt[guid] = now
	lastRequest = now
	pending = guid
	pendingSince = now

	if (type(NotifyInspect) == "function") then
		local ok = API.TryCall(NotifyInspect, target)
		if (not ok) then
			FinishPending()
		end
	else
		FinishPending()
	end
end

-- Advance the queue now instead of waiting for the next tick, while still
-- honouring INSPECT_INTERVAL as the floor between consecutive requests.
-- RequestNext stamps lastRequest itself, so ticker-driven and event-driven
-- requests share the same floor.
local kickScheduled = false
local Kick = function(delay)
	if (kickScheduled) then
		return
	end
	local wait = delay or 0
	local earliest = lastRequest + INSPECT_INTERVAL - GetTime()
	if (earliest > wait) then
		wait = earliest
	end
	if (wait <= 0) then
		RequestNext()
		return
	end
	kickScheduled = true
	C_Timer.After(wait, function()
		kickScheduled = false
		RequestNext()
	end)
end

local FindUnitByGUID = function(guid)
	local found
	IterateGroupUnits(function(unit)
		if (not found and UnitGUID(unit) == guid) then
			found = unit
		end
	end)
	return found
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
	if (event == "INSPECT_READY") then
		-- Deliberately not filtered on `pending`: this fires for every inspect in
		-- the session, including ones Details, RaiderIO or the inspect window
		-- requested. Harvesting those costs nothing and often resolves a member
		-- before our own queue reaches them.
		local guid = ...
		if (type(guid) == "string" and type(GetInspectSpecialization) == "function") then
			local unit = FindUnitByGUID(guid)
			if (unit) then
				local ok, specID = API.TryCall(GetInspectSpecialization, unit)
				if (ok and type(specID) == "number" and specID > 0) then
					local changed = (specByGUID[guid] ~= specID) or staleGUID[guid]
					specByGUID[guid] = specID
					staleGUID[guid] = nil
					if (changed) then
						ns:Fire("GroupSpecCache_Updated", guid, specID)
					end
				end
			end
		end
		if (pending == guid) then
			FinishPending()
		end
		Kick()

	elseif (event == "GROUP_ROSTER_UPDATE") then
		-- Drop everyone who is no longer with us, so a rejoining player is
		-- inspected again rather than showing whatever they last played.
		-- Someone who leaves keeps their cached spec, but it is marked stale so a
		-- rejoin draws instantly from cache and is re-inspected in the background.
		-- Dropping it outright made every re-form start from portraits again.
		local present = {}
		IterateGroupUnits(function(unit)
			local guid = UnitGUID(unit)
			if (type(guid) == "string") then
				present[guid] = true
			end
		end)
		for guid in next, specByGUID do
			if (not present[guid]) then
				staleGUID[guid] = true
				lastAttempt[guid] = nil
			end
		end
		ns:Fire("GroupSpecCache_Updated")
		Kick(ROSTER_SETTLE)

	elseif (event == "PLAYER_SPECIALIZATION_CHANGED") then
		local unit = ...
		if (type(unit) == "string") then
			local guid = UnitGUID(unit)
			if (type(guid) == "string") then
				specByGUID[guid] = nil
				staleGUID[guid] = nil
				lastAttempt[guid] = nil
			end
		end
		ns:Fire("GroupSpecCache_Updated")
		Kick()

	elseif (event == "PLAYER_ENTERING_WORLD") then
		FinishPending()
		ns:Fire("GroupSpecCache_Updated")
		Kick(ROSTER_SETTLE)

	elseif (event == "PLAYER_REGEN_ENABLED") then
		-- A cheap opportunity to retry members who were unreachable earlier.
		Kick()
	end
end)

--[[
	Starts the inspect loop. Safe to call repeatedly; only the first call takes.
	Nothing runs until a consumer asks for it, so a player who never turns the
	spec portraits on never pays for any of this.
]]
GroupSpecCache.Enable = function()
	if (ticker) then
		return
	end

	frame:RegisterEvent("INSPECT_READY")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")

	-- The ticker is now only a safety net for members who were unreachable when
	-- every other opportunity fired. The queue is normally driven by Kick.
	ticker = C_Timer.NewTicker(2, function() Kick() end)
	Kick()
end

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

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
local AddonName, ns = ...

if (not ns.IsRetail) then return end

--[[
	/azdebug auracost [perUnit]: what corner aura dots would cost before anyone builds
	them (roadmap option 07). Corner dots need one small aura container per corner per
	group member, matched by spell ID, so a 40-player raid at four corners is 160
	containers.

	The probe builds that many containers on every group member that exists now,
	spread over several frames, then measures frame time in six alternating windows:
	off, on, off, on, off, on. Switching the same containers on and off, rather than
	measuring "before" and "after", means a change in the scene (a pull starting, the
	camera turning) lands on both states instead of in the difference. The spread
	between windows of the same state is the noise; a difference smaller than that is
	reported as no measurable cost.

	With 32 per unit, five party members give 160 containers, so a party can measure
	raid size directly. Each aura change then reaches 32 containers instead of 4, so
	that errs high, which is the safe direction for a go/no-go.

	Blizzard's container does its matching in its own code, which addon CPU counters
	cannot see, so frame time is the measure. Nothing here reads aura data. A frame can
	never be deleted, so /reload afterwards to get the memory back.
]]

local AuraCostProbe = {}
ns.AuraCostProbe = AuraCostProbe

local WINDOW_SECONDS = 5
local SETTLE_SECONDS = .5     -- dropped after each switch, so the switch itself is not measured
local WINDOWS = { false, true, false, true, false, true }
local BUILD_PER_FRAME = 8
local DEFAULT_PER_UNIT = 4
local MAX_PER_UNIT = 32
local RAID_TARGET = 160 -- 40 players x 4 corners

-- Buffs a healer would put in a corner. The real feature would take the player's own
-- list; any small set exercises the container the same way.
local CORNER_SPELLS = {
	[774] = true,     -- Rejuvenation
	[139] = true,     -- Renew
	[61295] = true,   -- Riptide
	[17] = true,      -- Power Word: Shield
	[119611] = true,  -- Renewing Mist
	[194384] = true,  -- Atonement
	[364343] = true,  -- Echo
	[53563] = true    -- Beacon of Light
}

local state = { phase = "idle", containers = {} }

local function Now()
	return debugprofilestop and debugprofilestop() or (GetTime() * 1000)
end

-- A full collection first, so garbage freed between the two reads does not show as a
-- negative cost (the 2026-10-10 live run read -4499 KB).
local function AddonMemoryKB()
	if (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then
		collectgarbage("collect")
		UpdateAddOnMemoryUsage()
		return GetAddOnMemoryUsage(AddonName) or 0
	end
	return 0
end

-- Every group member that exists now, the way the group frames would see them.
local function GetUnits()
	local units = {}
	if (IsInRaid and IsInRaid()) then
		for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
			local unit = "raid" .. index
			if (UnitExists(unit)) then units[#units + 1] = unit end
		end
	else
		units[1] = "player"
		for index = 1, 4 do
			local unit = "party" .. index
			if (UnitExists(unit)) then units[#units + 1] = unit end
		end
	end
	return units
end

local function Average(samples)
	local count = #samples
	if (count == 0) then return 0 end
	local total = 0
	for index = 1, count do total = total + samples[index] end
	return total / count
end

local function Percentile(samples, fraction)
	local count = #samples
	if (count == 0) then return 0 end
	local sorted = {}
	for index = 1, count do sorted[index] = samples[index] end
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(count * fraction))]
end

local function StyleButton(button)
	button:SetSize(10, 10)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	button:SetIcon(icon)
end

local function GetHolder()
	local holder = state.holder or CreateFrame("Frame", nil, UIParent)
	state.holder = holder
	holder:SetSize(1, 1)
	holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	holder:SetAlpha(0)
	return holder
end

local function BuildOne(holder, unit, corner)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder,
		"CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
	if (not ok or not container) then return end
	container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	local added = pcall(function()
		container:SetUnit(unit)
		container:AddAuraGroup("AzeriteCornerProbe" .. corner, "HELPFUL", {
			initializeFrame = StyleButton,
			candidateFilters = { includeSpellIDs = CORNER_SPELLS },
			maxFrameCount = 3,
			layout = { elementWidth = 10, elementHeight = 10, layoutIndex = 1 }
		})
	end)
	if (added) then
		state.containers[#state.containers + 1] = container
	end
end

-- Switches every probe container on or off. The display switch stops a container
-- updating; the holder hides them too, for a build without that call.
local function SetEnabled(enabled)
	for _, container in ipairs(state.containers) do
		if (container.SetDisplayEnabled) then
			pcall(container.SetDisplayEnabled, container, enabled)
		end
	end
	if (state.holder) then state.holder:SetShown(enabled) end
end

local function Teardown()
	SetEnabled(false)
	if (state.driver) then state.driver:SetScript("OnUpdate", nil) end
end

local function Report(out, result)
	local off, on = result.off, result.on
	local built = result.built
	out("|cff33ff99AzeriteUI aura cost probe|r  (corner dots, roadmap option 07)")
	out(string.format("  %d containers on %d unit(s), %d per unit", built, result.units, result.perUnit))
	out(string.format("  build: %.1f ms in total, largest single frame %.1f ms; memory %+.0f KB (%.1f KB each)",
		result.buildMs, result.buildPeakMs, result.memoryKB, built > 0 and result.memoryKB / built or 0))
	out(string.format("  off: avg %.2f ms, p95 %.2f ms (%d frames, windows %s)", off.avg, off.p95, off.frames, off.windows))
	out(string.format("  on:  avg %.2f ms, p95 %.2f ms (%d frames, windows %s)", on.avg, on.p95, on.frames, on.windows))

	local delta = on.avg - off.avg
	local noise = math.max(off.spread, on.spread)
	out(string.format("  difference %+.3f ms per frame; noise (spread between windows of the same state) %.3f ms",
		delta, noise))
	out(string.format("  in combat for %d%% of the measured frames", math.floor(result.combatShare * 100 + .5)))

	local reading
	if (built == 0) then
		reading = "No containers could be built on this client."
	elseif (math.abs(delta) <= noise) then
		reading = "No measurable cost: the difference is inside the noise."
	elseif (delta < 0) then
		reading = "Faster with them on, which is noise. Run it again."
	else
		local atRaid = delta
		if (built < RAID_TARGET) then
			atRaid = delta * RAID_TARGET / built
			out(string.format("  scaled to %d containers, a guess: about %+.2f ms", RAID_TARGET, atRaid))
		end
		if (atRaid < .25) then
			reading = "Cheap: under a quarter of a millisecond per frame at raid size."
		elseif (atRaid < 1) then
			reading = "Modest. Worth building with a raid-size limit in mind."
		else
			reading = "Expensive at raid size. Corner dots would need fewer containers or raid-size limits."
		end
		if (built < RAID_TARGET) then
			reading = reading .. " Run /azdebug auracost 32 in a party to measure 160 directly."
		end
	end
	if (result.combatShare < .5) then
		reading = reading .. " Mostly out of combat; a run during a pull says more."
	end
	out("  reading: " .. reading)
	out("  The containers are switched off now. /reload to get the memory back.")
end

AuraCostProbe.IsRunning = function()
	return state.phase ~= "idle" and state.phase ~= "done"
end

-- Runs the alternating windows, then hands the summary to done.
local function Measure(done)
	local samples = { [false] = {}, [true] = {} }
	local windowAverages = { [false] = {}, [true] = {} }
	local combatFrames, totalFrames = 0, 0
	local index, elapsedInWindow, windowSamples = 1, 0, {}

	SetEnabled(WINDOWS[1])
	state.phase = "measuring 1/" .. #WINDOWS

	state.driver:SetScript("OnUpdate", function(self, elapsed)
		elapsedInWindow = elapsedInWindow + elapsed
		if (elapsedInWindow > SETTLE_SECONDS) then
			local ms = elapsed * 1000
			windowSamples[#windowSamples + 1] = ms
			local enabled = WINDOWS[index]
			samples[enabled][#samples[enabled] + 1] = ms
			totalFrames = totalFrames + 1
			if (InCombatLockdown()) then combatFrames = combatFrames + 1 end
		end
		if (elapsedInWindow < WINDOW_SECONDS) then return end

		local enabled = WINDOWS[index]
		windowAverages[enabled][#windowAverages[enabled] + 1] = Average(windowSamples)
		index, elapsedInWindow, windowSamples = index + 1, 0, {}
		if (index > #WINDOWS) then
			self:SetScript("OnUpdate", nil)
			local function Summary(enabled)
				local averages = windowAverages[enabled]
				local low, high, labels = math.huge, -math.huge, {}
				for _, value in ipairs(averages) do
					low, high = math.min(low, value), math.max(high, value)
					labels[#labels + 1] = string.format("%.2f", value)
				end
				return {
					avg = Average(samples[enabled]),
					p95 = Percentile(samples[enabled], .95),
					frames = #samples[enabled],
					spread = (#averages > 1) and (high - low) or 0,
					windows = table.concat(labels, " / ")
				}
			end
			done(Summary(false), Summary(true), totalFrames > 0 and combatFrames / totalFrames or 0)
			return
		end
		SetEnabled(WINDOWS[index])
		state.phase = "measuring " .. index .. "/" .. #WINDOWS
	end)
end

--[[
	/azdebug sated: can Sated and Exhaustion be shown on party frames?

	An aura container cannot isolate them. Blizzard skips spell-ID filters for debuffs
	on friendly units (Blizzard_AuraContainerUtil.lua, CanApplyIdentityCandidateFilters),
	so an include list lets every debuff through; the maintainer saw exactly that on
	2026-10-10. The one exception is a spell flagged NeverSecret, and the comment there
	names Exhaustion/Sated. Such an aura can be read directly:
	C_UnitAuras.GetUnitAuraBySpellID requires a non-secret aura, which these are.

	So this reports, for each lust debuff, its secrecy level, and for every group member
	whether the debuff is on them and for how long, in or out of combat. If the reads
	work in combat, Sated on party frames can be built from a plain aura read.
]]
local LUST_DEBUFFS = {
	{ 57724, "Sated" },
	{ 57723, "Exhaustion" },
	{ 80354, "Temporal Displacement" },
	{ 95809, "Insanity" },
	{ 264689, "Fatigued" },
	{ 390435, "Exhaustion (Evoker)" }
}

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function SecrecyName(spellID)
	local secrets = C_Secrets
	if (not secrets or type(secrets.GetSpellAuraSecrecy) ~= "function") then return "no secrecy API" end
	local ok, level = pcall(secrets.GetSpellAuraSecrecy, spellID)
	if (not ok or IsSecret(level)) then return "unreadable" end
	local levels = Enum and Enum.SecrecyLevel or {}
	if (level == levels.NeverSecret) then return "NeverSecret" end
	if (level == levels.AlwaysSecret) then return "AlwaysSecret" end
	if (level == levels.ContextuallySecret) then return "ContextuallySecret" end
	return tostring(level)
end

AuraCostProbe.SatedTest = function(input, out)
	out = out or print
	local auras = C_UnitAuras
	local read = auras and auras.GetUnitAuraBySpellID
	out(string.format("|cff33ff99AzeriteUI Sated test|r  (%s)", InCombatLockdown() and "in combat" or "out of combat"))

	for _, entry in ipairs(LUST_DEBUFFS) do
		out(string.format("  %s (%d): %s", entry[2], entry[1], SecrecyName(entry[1])))
	end
	if (type(read) ~= "function") then
		out("  C_UnitAuras.GetUnitAuraBySpellID is missing on this client.")
		return
	end

	local units = GetUnits()
	local found = 0
	for _, unit in ipairs(units) do
		for _, entry in ipairs(LUST_DEBUFFS) do
			local ok, aura = pcall(read, unit, entry[1])
			if (not ok) then
				out(string.format("  %s: %s raised: %s", unit, entry[2], tostring(aura)))
			elseif (aura ~= nil) then
				found = found + 1
				local name = UnitName(unit)
				local expires = aura.expirationTime
				local left = "secret"
				if (not IsSecret(expires) and type(expires) == "number") then
					left = expires > 0 and string.format("%d s left", math.floor(expires - GetTime() + .5)) or "no timer"
				end
				out(string.format("  %s (%s): %s, %s", unit, IsSecret(name) and "?" or tostring(name), entry[2], left))
			end
		end
	end
	out(string.format("  %d lust debuff(s) found on %d group member(s).", found, #units))
	out("  Run it once out of combat and once in combat, after a Bloodlust, Heroism, Time Warp or drums.")
	out("  If combat shows the same names and times, Sated on party frames can be built.")
end

-- /azdebug auracost [perUnit|status|stop]
AuraCostProbe.Run = function(input, out)
	out = out or print
	local word = input and input:match("^(%S+)")
	word = word and word:lower()

	if (word == "status") then
		out("|cff33ff99AzeriteUI aura cost probe:|r " .. state.phase)
		return
	end
	if (word == "stop") then
		if (AuraCostProbe.IsRunning()) then
			Teardown()
			state.phase = "done"
			out("|cff33ff99AzeriteUI aura cost probe:|r stopped. /reload to get the memory back.")
		else
			out("|cff33ff99AzeriteUI aura cost probe:|r not running.")
		end
		return
	end
	if (AuraCostProbe.IsRunning()) then
		out("|cff33ff99AzeriteUI aura cost probe:|r already running (" .. state.phase .. "). /azdebug auracost stop")
		return
	end
	if (state.phase == "done") then
		out("|cff33ff99AzeriteUI aura cost probe:|r already ran this session. /reload first, so the last run's containers do not count.")
		return
	end
	if (InCombatLockdown()) then
		out("|cff33ff99AzeriteUI aura cost probe:|r start it out of combat; it keeps measuring once a pull begins.")
		return
	end

	local perUnit = tonumber(word) or DEFAULT_PER_UNIT
	perUnit = math.max(1, math.min(MAX_PER_UNIT, math.floor(perUnit)))
	local units = GetUnits()
	local total = #units * perUnit

	out(string.format("|cff33ff99AzeriteUI aura cost probe:|r building %d containers (%d on each of %d unit(s)), then %d windows of %d s, off and on in turn.",
		total, perUnit, #units, #WINDOWS, WINDOW_SECONDS))

	-- The build queue, one unit and corner per entry, worked off a few per frame.
	local queue = {}
	for _, unit in ipairs(units) do
		for corner = 1, perUnit do queue[#queue + 1] = { unit, corner } end
	end

	local result = { perUnit = perUnit, units = #units, buildMs = 0, buildPeakMs = 0 }
	local holder = GetHolder()
	holder:Show()
	local memoryBefore = AddonMemoryKB()
	local driver = state.driver or CreateFrame("Frame")
	state.driver = driver
	state.phase = "building"

	local position = 1
	driver:SetScript("OnUpdate", function(self)
		local started = Now()
		for _ = 1, BUILD_PER_FRAME do
			local entry = queue[position]
			if (not entry) then break end
			BuildOne(holder, entry[1], entry[2])
			position = position + 1
		end
		local spent = Now() - started
		result.buildMs = result.buildMs + spent
		result.buildPeakMs = math.max(result.buildPeakMs, spent)
		if (queue[position]) then return end

		self:SetScript("OnUpdate", nil)
		result.built = #state.containers
		result.memoryKB = AddonMemoryKB() - memoryBefore
		Measure(function(off, on, combatShare)
			result.off, result.on, result.combatShare = off, on, combatShare
			Teardown()
			state.phase = "done"
			Report(out, result)
		end)
	end)
end

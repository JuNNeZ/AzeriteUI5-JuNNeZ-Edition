-- /azdebug auracost, offline.
--
-- Loads the real Components/UnitFrames/Auras/AuraCostProbe.lua against a fake client
-- and drives its OnUpdate scripts with chosen frame times: the build spread over
-- frames, the six alternating off/on windows, the settle time after each switch,
-- the noise verdict, and the report. It cannot say what containers cost in game.
--
-- lua Tools/Harness/auracost_harness.lua .

local root = arg and arg[1] or "."

local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and ("  (" .. tostring(detail) .. ")") or ""))
	end
end

local function Frame(kind)
	local f = { kind = kind, shown = true, scripts = {} }
	function f:SetScript(name, fn) self.scripts[name] = fn end
	function f:SetSize() end
	function f:SetPoint() end
	function f:SetAlpha() end
	function f:Show() self.shown = true end
	function f:Hide() self.shown = false end
	function f:SetShown(v) self.shown = v and true or false end
	return f
end

local containers, holder, driver
local combat = false
local env = setmetatable({}, { __index = _G })
env.CreateFrame = function(kind, name, parent)
	local f = Frame(kind)
	if (kind == "AuraContainer") then
		f.enabled = true
		function f:SetUnit(unit) self.unit = unit end
		function f:AddAuraGroup(key, filter, options) self.group = { key, filter, options } end
		function f:SetDisplayEnabled(v) self.enabled = v end
		containers[#containers + 1] = f
	elseif (parent) then
		holder = holder or f
	else
		driver = f
	end
	return f
end
env.UIParent = Frame("Frame")
env.InCombatLockdown = function() return combat end
env.IsInRaid = function() return false end
env.UnitExists = function(unit) return unit == "party1" or unit == "party2" end
local clock = 0
env.debugprofilestop = function() clock = clock + .5; return clock end
local memory = 100
env.UpdateAddOnMemoryUsage = function() end
env.GetAddOnMemoryUsage = function() return memory end

local function Load()
	containers, holder, driver = {}, nil, nil
	local ns = { IsRetail = true }
	local chunk = assert(loadfile(root .. "/Components/UnitFrames/Auras/AuraCostProbe.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	return ns.AuraCostProbe
end

-- Drives the driver frame: frame time comes from cost(), which may read the containers.
local function Run(probe, input, cost)
	local lines = {}
	probe.Run(input, function(text) lines[#lines + 1] = text end)
	local guard = 0
	while (driver and driver.scripts.OnUpdate and guard < 100000) do
		guard = guard + 1
		driver.scripts.OnUpdate(driver, cost())
	end
	return lines, guard
end

local function Find(lines, pattern)
	for _, line in ipairs(lines) do
		if (line:find(pattern)) then return line end
	end
end

local function AnyOn()
	return containers[1] and containers[1].enabled and holder and holder.shown
end

-------------------------------------------------------------------------------
-- Same frame time on and off: no measurable cost.
-------------------------------------------------------------------------------
do
	local probe = Load()
	local framesOfBuild = 0
	local lines = Run(probe, "4", function()
		if (#containers < 12) then framesOfBuild = framesOfBuild + 1 end
		return .01
	end)
	check(#containers == 12, "4 per unit on player, party1, party2", #containers)
	check(framesOfBuild == 2, "the build is spread over frames, 8 per frame", framesOfBuild)
	check(containers[1].unit == "player" and containers[12].unit == "party2", "every group unit gets containers")
	local group = containers[1].group
	check(group and group[2] == "HELPFUL" and group[3].maxFrameCount == 3 and group[3].candidateFilters.includeSpellIDs[774],
		"a spell-ID filtered helpful group, like a corner")
	check(Find(lines, "No measurable cost"), "equal frame time reads as no measurable cost")
	check(not containers[1].enabled and not holder.shown, "everything is switched off afterwards")
	check(Find(lines, "largest single frame"), "the report gives the largest single-frame build")
	check(probe.IsRunning() == false, "not running once done")

	local again = {}
	probe.Run("4", function(text) again[#again + 1] = text end)
	check(Find(again, "already ran"), "a second run asks for a /reload first")
end

-------------------------------------------------------------------------------
-- Alternation and settle time.
-------------------------------------------------------------------------------
do
	local probe = Load()
	local states, last = {}, nil
	Run(probe, "1", function()
		local on = AnyOn() and true or false
		if (#containers > 0 and on ~= last) then states[#states + 1] = on; last = on end
		return .01
	end)
	check(#states == 6 and not states[1] and states[2] and not states[3] and states[6],
		"six windows, off first, then on and off in turn", #states)
end

-------------------------------------------------------------------------------
-- The switch itself: a hitch right after turning them on is not counted.
-------------------------------------------------------------------------------
do
	local probe = Load()
	local lastOn
	local lines = Run(probe, "4", function()
		local on = AnyOn() and true or false
		local switched = (#containers > 0 and on ~= lastOn)
		lastOn = on
		if (switched and on) then return .2 end -- a 200 ms hitch as the containers refresh
		return .010
	end)
	check(Find(lines, "No measurable cost"), "the first half second after a switch is dropped", Find(lines, "difference"))
end

-------------------------------------------------------------------------------
-- Clearly slower when on: a cost, measured directly at 160.
-------------------------------------------------------------------------------
do
	local probe = Load()
	env.UnitExists = function(unit) return unit:match("^party[1-4]$") ~= nil end
	local lines = Run(probe, "32", function() return AnyOn() and .012 or .010 end)
	check(#containers == 160, "32 per unit in a party of five is 160", #containers)
	check(Find(lines, "difference %+2%.000 ms"), "the difference is on minus off", Find(lines, "difference"))
	check(Find(lines, "Expensive at raid size"), "2 ms at 160 reads as expensive")
	check(not Find(lines, "scaled to"), "no scaling when 160 were built")
	check(Find(lines, "Mostly out of combat"), "says when the run was out of combat")
end

-------------------------------------------------------------------------------
-- Noise: windows of the same state disagree more than the difference.
-------------------------------------------------------------------------------
do
	local probe = Load()
	env.UnitExists = function(unit) return unit == "party1" end
	local window, lastOn = 0, nil
	local lines = Run(probe, "4", function()
		local on = AnyOn() and true or false
		if (#containers > 0 and on ~= lastOn) then window = window + 1; lastOn = on end
		-- Off windows at 10, 14, 10 ms; on windows at 11, 11, 11 ms.
		if (on) then return .011 end
		return (window == 3) and .014 or .010
	end)
	check(Find(lines, "No measurable cost"), "a difference inside the noise is no cost", Find(lines, "reading"))
	check(Find(lines, "noise %(spread between windows of the same state%) 4%.000"), "noise is the spread", Find(lines, "noise"))
end

-------------------------------------------------------------------------------
-- A small run that costs something: scaled, labelled as a guess, and pointed at 32.
-------------------------------------------------------------------------------
do
	local probe = Load()
	env.UnitExists = function() return false end
	-- A pull starts once the probe is running.
	local lines = Run(probe, "4", function()
		if (#containers > 0) then combat = true end
		return AnyOn() and .0101 or .0100
	end)
	check(#containers == 4, "solo: four on the player")
	check(Find(lines, "scaled to 160 containers, a guess"), "fewer than 160 are scaled, as a guess")
	check(Find(lines, "auracost 32"), "and the reading points at measuring 160 directly")
	check(Find(lines, "in combat for 100%%"), "combat share reported")
	check(not Find(lines, "Mostly out of combat"), "no out-of-combat note in combat")
	combat = false
end

-------------------------------------------------------------------------------
-- Refusals and limits.
-------------------------------------------------------------------------------
do
	local probe = Load()
	combat = true
	local lines = {}
	probe.Run("4", function(text) lines[#lines + 1] = text end)
	check(Find(lines, "out of combat") and #containers == 0, "does not start in combat")
	combat = false

	env.UnitExists = function() return false end
	lines = Run(probe, "500", function() return .01 end)
	check(#containers == 32, "per unit is capped at 32", #containers)

	probe = Load()
	lines = {}
	probe.Run("4", function(text) lines[#lines + 1] = text end)
	probe.Run("stop", function(text) lines[#lines + 1] = text end)
	check(Find(lines, "stopped") and driver.scripts.OnUpdate == nil, "stop ends a run")
end

print(string.format("Aura cost probe: %d checks, %d failures", checks, failures))
if (failures > 0) then error("auracost_harness failed", 0) end

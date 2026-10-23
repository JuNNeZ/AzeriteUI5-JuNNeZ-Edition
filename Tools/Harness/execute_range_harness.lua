-- The execute threshold by client, class and what the spellbook holds (Components/UnitFrames/ExecuteRange.lua).
-- Forever's executes are learned in ranks; Retail's are not looked up. No claim of live WoW execution.
-- lua Tools/Harness/execute_range_harness.lua .
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

-- One fresh load per case: the module caches its threshold until a spell or spec event.
local function threshold(forever, class, known)
	local env = setmetatable({}, { __index = _G })
	env.UnitClassBase = function() return class end
	env.UnitClass = function() return class, class end
	env.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
	env.PlayerUtil = { GetCurrentSpecID = function() return nil end }
	local ns = { IsForever = forever, IsRetail = true, IsMainline = true, IsRetailContent = not forever, API = {
		IsSpellKnownAnywhere = function(spellID) return known[spellID] == true end
	} }
	local chunk = assert(loadfile(root .. "/Components/UnitFrames/ExecuteRange.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	return ns.API.GetExecuteThreshold()
end

-- Forever: no execute until a rank is learned; any rank will do.
check(threshold(true, "WARRIOR", {}) == 0, "Forever: a warrior without Execute has no execute")
check(threshold(true, "WARRIOR", { [5308] = true }) == .2, "Forever: Execute rank 1 gives 20%")
check(threshold(true, "WARRIOR", { [20661] = true }) == .2, "Forever: a higher Execute rank alone gives 20%")
check(threshold(true, "PALADIN", {}) == 0, "Forever: a paladin before Hammer of Wrath has no execute")
check(threshold(true, "PALADIN", { [24239] = true }) == .2, "Forever: Hammer of Wrath gives 20%")
-- Forever's own Shadow Word: Death (1309595, a trainer rank) has no health limit (wago.tools Spell, 1.60.1.70532).
check(threshold(true, "PRIEST", { [1309595] = true }) == 0, "Forever: no priest execute (its Shadow Word: Death has no health limit)")
check(threshold(true, "HUNTER", {}) == 0, "Forever: no hunter execute")

-- Retail: as before, by class, no spellbook lookup for these.
check(threshold(false, "WARRIOR", {}) == .2, "Retail: a warrior's Execute needs no lookup")
check(threshold(false, "PRIEST", {}) == .2, "Retail: Shadow Word: Death")
check(threshold(false, "DEATHKNIGHT", {}) == 0, "Retail: Soul Reaper only where talented")
check(threshold(false, "DEATHKNIGHT", { [343294] = true }) == .35, "Retail: talented Soul Reaper gives 35%")

print(string.format("Execute range: %d checks, %d failures", checks, failures))
if (failures > 0) then error("execute range harness failed") end

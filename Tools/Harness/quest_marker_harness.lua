-- Nameplate quest marker (FixLog 2026-10-20). Loads the real
-- Components/UnitFrames/NamePlates/Elements.lua and drives QuestMarker_Update: shown only
-- for nameplate units the game says belong to an active quest, hidden for a secret or
-- failed answer, on the personal, object, widgets-only and friendly name-only plates,
-- while a raid marker is shown, and when the option is off. Offline only: whether
-- UnitIsRelatedToActiveQuest also answers true for finished objectives is a live check.
-- Run: lua.exe Tools/Harness/quest_marker_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local Any
Any = setmetatable({}, { __index = function() return Any end, __call = function() return Any end })
setmetatable(_G, { __index = function(_, k) return Any end })

local secretMeta = {}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

local W = { related = true, calls = 0 }
C_QuestLog = { UnitIsRelatedToActiveQuest = function(unit)
	W.calls = W.calls + 1
	W.lastUnit = unit
	if (W.raise) then error("boom") end
	return W.related
end }

local profile = { showQuestMarker = true }
local ns = {
	API = { TryCall = function(f, ...) return pcall(f, ...) end },
	GetConfig = function() return {} end,
}
ns.NamePlatesPrivate = {
	NamePlatesMod = { db = { profile = profile } },
	IsSafeTrue = function(v) if (issecretvalue(v)) then return false end return v and true or false end,
	IsSafeFalse = function(v) if (issecretvalue(v)) then return false end return v == false end,
	ShouldUseFriendlyPlayerNameOnly = function(self) return self.nameOnly end,
}
local NP = ns.NamePlatesPrivate

local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/Elements.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local Update = NP.QuestMarker_Update
check(type(Update) == "function", "Elements exports QuestMarker_Update")

local function Marker()
	local m = { shown = nil }
	function m:SetShown(v) self.shown = v end
	return m
end
local function Plate(fields)
	local p = { unit = "nameplate4", QuestMarker = Marker(),
		RaidTargetIndicator = { shown = false, IsShown = function(self) return self.shown end } }
	for k, v in pairs(fields or {}) do p[k] = v end
	return p
end

local p = Plate()
Update(p)
check(p.QuestMarker.shown == true, "shown for a quest unit")
check(W.lastUnit == "nameplate4", "asked about the plate's own unit")

W.related = false
p = Plate(); Update(p)
check(p.QuestMarker.shown == false, "hidden when the unit is not a quest unit")

W.related = secret(true)
p = Plate(); Update(p)
check(p.QuestMarker.shown == false, "hidden for a secret answer")

W.related, W.raise = true, true
p = Plate(); Update(p)
check(p.QuestMarker.shown == false, "hidden when the call fails")
W.raise = nil

for _, case in ipairs({
	{ "personal plate", { isPRD = true } },
	{ "object plate", { isObjectPlate = true } },
	{ "widgets-only plate", { nameplateShowsWidgetsOnly = true } },
	{ "friendly name-only plate", { nameOnly = true } },
	{ "non-plate unit", { unit = "target" } },
	{ "no unit", { unit = false } },
}) do
	W.calls = 0
	p = Plate(case[2]); Update(p)
	check(p.QuestMarker.shown == false and W.calls == 0, "hidden without asking on a " .. case[1])
end

W.calls = 0
p = Plate(); p.RaidTargetIndicator.shown = true; Update(p)
check(p.QuestMarker.shown == false and W.calls == 0, "gives way to a raid marker")

profile.showQuestMarker = false
W.calls = 0
p = Plate(); Update(p)
check(p.QuestMarker.shown == false and W.calls == 0, "option off: hidden without asking")
profile.showQuestMarker = true

local saved = C_QuestLog
C_QuestLog = nil
p = Plate(); Update(p)
check(p.QuestMarker.shown == false, "hidden on a client without the API")
C_QuestLog = saved

Update(nil)
Update({ unit = "nameplate1" })
check(true, "plates without a marker are ignored")

print(("Quest marker: %d checks, %d failures (offline only)"):format(checks, failures))
if (failures > 0) then os.exit(1) end

-- Nameplate quest marker (FixLog 2026-10-20). Loads the real
-- Components/UnitFrames/NamePlates/Elements.lua and drives QuestMarker_Update: shown only
-- for nameplate units the game says belong to an active quest, hidden for a secret or
-- failed answer, on the personal, object, widgets-only and friendly name-only plates,
-- while a raid marker is shown, and when the option is off. Offline only: whether
-- UnitIsRelatedToActiveQuest also answers true for finished objectives is a live check.
-- Also quest progress (FixLog 2026-11-07): the first unfinished QuestObjective tooltip line
-- as "x/y" or "y%", secret-safe, read only while the mark shows and the option is on.
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

Enum = { TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17, UnitName = 2 } }
local T = { calls = 0 }
C_TooltipInfo = { GetUnit = function(unit)
	T.calls = T.calls + 1
	if (T.raise) then error("tooltip boom") end
	return T.data
end }

local profile = { showQuestMarker = true, showQuestProgress = true }
local ns = {
	API = { TryCall = function(f, ...) return pcall(f, ...) end },
	GetConfig = function() return {} end,
}
ns.NamePlatesPrivate = {
	NamePlatesMod = { db = { profile = profile } },
	IsSafeTrue = function(v) if (issecretvalue(v)) then return false end return v and true or false end,
	IsSafeFalse = function(v) if (issecretvalue(v)) then return false end return v == false end,
	IsSecretValue = function(v) return issecretvalue(v) end,
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

-- Quest progress (showQuestProgress): the first unfinished QuestObjective line of the tooltip.
local Parse = NP.ParseQuestProgress
check(type(Parse) == "function", "Elements exports ParseQuestProgress")
check(Parse("Wolves slain: 3/10") == "3/10", "parses x/y")
check(Parse("- Getötete Wölfe: 3 / 10") == "3/10", "parses x / y with spaces and a German prefix")
check(Parse("Wolves slain: 10/10") == false, "a full count is finished")
check(Parse("Area cleared (40%)") == "40%", "parses a percent")
check(Parse("Area cleared: 100%") == false, "100% is finished")
check(Parse("Speak to Marshal") == nil, "no number gives nothing")
check(Parse("Broken 3/0") == nil, "x/0 gives nothing")

local function Text()
	local t = { shown = false }
	function t:SetText(v) self.text = v end
	function t:Show() self.shown = true end
	function t:Hide() self.shown = false; self.text = nil end
	return t
end
local function Line(lineType, text, completed)
	return { type = lineType, leftText = text, completed = completed }
end
local function ProgressPlate(fields)
	local p = Plate(fields)
	p.QuestProgress = Text()
	return p
end

W.related = true
T.data = { lines = {
	Line(2, "Mangy Wolf"),
	Line(17, "Wolves of the Vale"),
	Line(8, "Wolves slain: 10/10", true),
	Line(8, "Wolf pelts: 2/6", false),
} }
p = ProgressPlate(); Update(p)
check(p.QuestProgress.shown and p.QuestProgress.text == "2/6", "first unfinished objective shown", p.QuestProgress.text)

T.data = { lines = { Line(8, "Torch the hut: 0/1", true), Line(8, "Pelts: 5/6") } }
p = ProgressPlate(); Update(p)
check(p.QuestProgress.text == "5/6", "a line the game marks completed is skipped even if its count is not full", p.QuestProgress.text)

T.data = { lines = { Line(8, "Wolves slain: 4/10") } }
p = ProgressPlate(); Update(p)
check(p.QuestProgress.text == "4/10", "works without a completed field (Forever may omit it)")

T.data = { lines = { Line(8, "Wolves slain: 10/10") } }
p = ProgressPlate(); Update(p)
check(not p.QuestProgress.shown, "hidden when every objective is full")

T.data = { lines = { Line(2, "3/10 Wolf") } }
p = ProgressPlate(); Update(p)
check(not p.QuestProgress.shown, "numbers on other line types are ignored")

for _, case in ipairs({
	{ "secret data", function() T.data = secret({ lines = {} }) end },
	{ "secret lines", function() T.data = { lines = secret({}) } end },
	{ "secret line", function() T.data = { lines = { secret(Line(8, "1/2")) } } end },
	{ "secret text", function() T.data = { lines = { Line(8, secret("1/2")) } } end },
	{ "secret type", function() T.data = { lines = { Line(secret(8), "1/2") } } end },
	{ "no data", function() T.data = nil end },
}) do
	case[2]()
	p = ProgressPlate(); Update(p)
	check(p.QuestMarker.shown == true and not p.QuestProgress.shown, "mark alone on " .. case[1])
end

T.data = { lines = { Line(8, secret("1/2")), Line(8, "Pelts: 1/3") } }
p = ProgressPlate(); Update(p)
check(p.QuestProgress.text == "1/3", "a secret line is skipped, not fatal")

T.data = { lines = { Line(8, "Pelts: 1/3", secret(true)) } }
p = ProgressPlate(); Update(p)
check(p.QuestProgress.text == "1/3", "a secret completed flag falls back to the count")

T.raise = true
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true and not p.QuestProgress.shown, "a failing tooltip call leaves the mark alone")
T.raise = nil

T.data = { lines = { Line(8, "Pelts: 1/3") } }
W.related = false; T.calls = 0
p = ProgressPlate(); Update(p)
check(not p.QuestProgress.shown and T.calls == 0, "no mark: tooltip never read")
W.related = true

profile.showQuestProgress = false; T.calls = 0
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true and not p.QuestProgress.shown and T.calls == 0, "option off: mark only, tooltip never read")
profile.showQuestProgress = true

p = ProgressPlate(); p.RaidTargetIndicator.shown = true; T.calls = 0; Update(p)
check(not p.QuestProgress.shown and T.calls == 0, "progress gives way to a raid marker with the mark")

-- hideFinishedQuestMarker: the mark goes only when the tooltip proves every objective finished.
profile.hideFinishedQuestMarker = true
T.data = { lines = { Line(17, "Wolves of the Vale"), Line(8, "Wolves slain: 10/10") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == false and not p.QuestProgress.shown, "hide when done: full count hides the mark")

T.data = { lines = { Line(8, "Torch the hut: 0/1", true), Line(8, "Wolves slain: 10/10") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == false, "hide when done: completed flag and full count hide the mark")

T.data = { lines = { Line(8, "Wolves slain: 10/10"), Line(8, "Pelts: 3/6") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true and p.QuestProgress.text == "3/6", "hide when done: one open objective keeps it")

T.data = { lines = { Line(8, "Wolves slain: 10/10"), Line(8, "Speak to the Marshal") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true and not p.QuestProgress.shown, "hide when done: an objective without a number keeps it")

T.data = { lines = { Line(8, "Wolves slain: 10/10"), secret(Line(8, "Pelts: 1/6")) } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true, "hide when done: a secret line keeps it")

T.data = { lines = { Line(8, "Wolves slain: 10/10"), Line(secret(8), "x") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true, "hide when done: a secret line type keeps it")

T.data = { lines = { Line(2, "Mangy Wolf") } }
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true, "hide when done: no objective lines keeps it")

T.data = secret({})
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true, "hide when done: secret tooltip keeps it")

T.data = { lines = { Line(8, "Wolves slain: 10/10") } }
profile.showQuestProgress = false; T.calls = 0
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == false and T.calls == 1, "hide when done works with progress text off")
profile.showQuestProgress = true

profile.hideFinishedQuestMarker = false
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true, "hide when done off: the mark stays")

local savedTip = C_TooltipInfo
C_TooltipInfo = nil
p = ProgressPlate(); Update(p)
check(p.QuestMarker.shown == true and not p.QuestProgress.shown, "mark alone on a client without C_TooltipInfo")
C_TooltipInfo = savedTip

print(("Quest marker: %d checks, %d failures (offline only)"):format(checks, failures))
if (failures > 0) then os.exit(1) end

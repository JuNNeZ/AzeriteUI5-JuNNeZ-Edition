-- The nameplate aura picker, step 1 (Docs/Nameplate Aura Picker Plan - 2026-11-21.md).
--
-- Part 1, Components/UnitFrames/NamePlates/AuraLists.lua under its own small stubs: the two lists keep
-- their storage format (comma-separated strings, highlights per specialization key), adding and removing
-- keep the other IDs and their order, the plates' limits refuse instead of dropping, and "Seen on your
-- targets" records only readable debuffs from players and pets on enemy plates, out of combat, newest
-- first, capped, with UNIT_AURA unregistered in combat.
-- Part 2, over the shared kit stubs: Renderer:SetStartClosed folds a section closed and RevealPath still
-- opens it, and Options/Kit/AuraPicker.lua builds, opens, lays out (empty, filled, full, in combat) and closes.
-- It cannot say how the window looks or whether the game's aura data matches these tables.
--
-- lua Tools/Harness/aura_picker_harness.lua . Tools/Harness
local root, scratch = arg[1] or ".", arg[2] or "Tools/Harness"

local checks, failures = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL " .. label .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
	return ok
end

--------------------------------------------------------------------------
-- Part 1: AuraLists
--------------------------------------------------------------------------
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local combat = false
local spec = "250"
local events = {}
local registered = {}
local watcherScript
local timers = {}
local units = {}

function InCombatLockdown() return combat end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function CreateFrame()
	local frame = {}
	function frame:RegisterEvent(event) registered[event] = true; events[#events + 1] = "+" .. event end
	function frame:UnregisterEvent(event) registered[event] = nil; events[#events + 1] = "-" .. event end
	function frame:SetScript(_, fn) watcherScript = fn end
	return frame
end
function UnitIsUnit(a, b) return a == b end
function UnitIsPlayer(unit) local u = units[unit]; return u and u.player end
function UnitClass(unit) local u = units[unit]; return u and u.className, u and u.class end
function UnitCanAttack(_, unit) local u = units[unit]; if (u and u.secretAttack) then return SECRET end; return u and u.enemy end
local auraLists = {}
C_UnitAuras = { GetAuraDataByIndex = function(unit, index) return auraLists[unit] and auraLists[unit][index] end }

local settingsUpdates = 0
local module = { db = { profile = { enabled = true, showAuras = true, auraOnceSpells = "", auraHighlights = {} }, global = {} } }
function module:UpdateSettings() settingsUpdates = settingsUpdates + 1 end
local ns = {
	NamePlatesPrivate = {
		IsSecretValue = function(value) return value == SECRET end,
		GetAuraHighlightKey = function() return spec end
	},
	PlayerAuraContainers = { NamePlateOnceSlots = 8 },
	GetModule = function(_, name) return name == "NamePlates" and module or nil end
}

local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/AuraLists.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local A = ns.NamePlatesPrivate.AuraLists
check(type(A) == "table" and A.SetListed and A.Record, "AuraLists is exported on ns.NamePlatesPrivate")

local notices = {}
A:AddListener(function(kind) notices[#notices + 1] = kind end)
local profile = module.db.profile

-- The lists, in the input fields' own format.
profile.auraOnceSpells = "55078,  999 ,abc 1001"
check(A:IsListed("once", 999) and not A:IsListed("once", 5), "an existing hand-typed list is read as the fields read it")
check(A:SetListed("once", 1002, true) and profile.auraOnceSpells == "55078, 999, 1001, 1002",
	"adding keeps every ID and its order, comma-separated", profile.auraOnceSpells)
check(settingsUpdates == 1 and notices[#notices] == "once", "a write applies the settings and tells the picker")
check(A:SetListed("once", 999, false) and profile.auraOnceSpells == "55078, 1001, 1002",
	"removing takes out only that ID", profile.auraOnceSpells)
local before = settingsUpdates
check(A:SetListed("once", 999, false) and settingsUpdates == before, "removing an absent ID writes nothing")
check(A:SetListed("once", 55078, true) and settingsUpdates == before, "adding a present ID writes nothing")
profile.auraOnceSpells = "1,2,3,4,5,6,7,8"
local ok, reason = A:SetListed("once", 9, true)
check(not ok and reason == "limit" and profile.auraOnceSpells == "1,2,3,4,5,6,7,8",
	"a full once-only list refuses the ninth instead of storing what would never show", reason)
profile.auraOnceSpells = "1,2,3,4,5,6,7,8,9,10"
check(A:SetListed("once", 10, false) and profile.auraOnceSpells == "1, 2, 3, 4, 5, 6, 7, 8, 9",
	"a list typed past the limit by hand loses nothing but the ID removed", profile.auraOnceSpells)
check(select(2, A:SetListed("once", "x", true)) == "invalid", "a non-number is refused")
check(A:SetText("once", "  ") and profile.auraOnceSpells == "", "clearing stores an empty string")

-- Highlights, per specialization.
check(A:SetListed("highlight", 55078, true) and profile.auraHighlights["250"] == "55078",
	"a highlight lands in this specialization's list", profile.auraHighlights["250"])
spec = "251"
check(not A:IsListed("highlight", 55078) and A:GetText("highlight") == "", "another specialization has its own list")
for id = 1, 16 do A:SetListed("highlight", id, true) end
ok, reason = A:SetListed("highlight", 17, true)
check(not ok and reason == "limit", "the highlight list stops at the plates' 16", reason)
check(A:SetText("highlight", "") and profile.auraHighlights["251"] == nil and profile.auraHighlights["250"] == "55078",
	"emptying a specialization's list removes only its key")
spec = "250"

-- Seen on your targets.
local function aura(id, source, extra)
	local data = { spellId = id, isHarmful = true, isFromPlayerOrPlayerPet = true, sourceUnit = source }
	for k, v in pairs(extra or {}) do data[k] = v end
	return data
end
units.player = { player = true, class = "DEATHKNIGHT", className = "Death Knight" }
units.raid2 = { player = true, class = "PRIEST", className = "Priest" }
units.nameplate1 = { enemy = true }
units.nameplate2 = { enemy = false }
units.nameplate3 = { secretAttack = true }

check(registered.PLAYER_REGEN_DISABLED and registered.PLAYER_REGEN_ENABLED and registered.NAME_PLATE_UNIT_ADDED,
	"the watcher follows combat and new plates")
watcherScript(nil, "PLAYER_ENTERING_WORLD")
check(registered.UNIT_AURA, "out of combat UNIT_AURA is listened to")

auraLists.nameplate1 = {
	aura(55078, "player"), aura(589, "raid2"),
	aura(SECRET, "player"), aura(1, "player", { isHarmful = false }),
	aura(2, "player", { isFromPlayerOrPlayerPet = false }), aura(3, SECRET),
}
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
local seen = A:GetSeen()
check(#seen == 3, "only readable debuffs from players and pets are kept", #seen)
check(seen[1].id == 3 and seen[1].class == nil and seen[2].id == 589 and seen[2].class == "PRIEST"
	and seen[3].id == 55078 and seen[3].own and seen[3].class == "DEATHKNIGHT",
	"newest first, with the source's class and your own marked")
check(module.db.global.auraSeen["250"] == seen, "kept per specialization in the namespace's global table")
check(#notices > 0 and #timers == 1, "one notice is scheduled per burst")
local count = #notices
timers[1](); timers = {}
check(notices[#notices] == "seen" and #notices == count + 1, "the burst's notice reaches the picker")

auraLists.nameplate2 = { aura(774, "player") }
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
auraLists.nameplate3 = { aura(775, "player") }
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate3")
watcherScript(nil, "UNIT_AURA", "target", { addedAuras = { aura(776, "player") } })
check(#A:GetSeen() == 3, "friends, a secret attack answer and non-plate units add nothing", #A:GetSeen())

watcherScript(nil, "UNIT_AURA", "nameplate1", { addedAuras = { aura(589, "raid2") } })
check(A:GetSeen()[1].id == 589 and #A:GetSeen() == 3, "seen again, it moves to the top without a copy")
watcherScript(nil, "UNIT_AURA", "nameplate1", { isFullUpdate = false, addedAuras = { aura(48743, "player") } })
check(A:GetSeen()[1].id == 48743, "an incremental update reads only the added auras")

-- BugSack 2026-11-22 (Forever 1.60.1, out of combat): UNIT_AURA brought a secret addedAuras and a secret
-- isFullUpdate ("bad argument #1 to 'ipairs' (table expected, got secret)"), and GetAuraDataByIndex raised
-- "Auras cannot be accessed when secret while tainted" on a plate whose auras were secret.
local ok, err = pcall(watcherScript, nil, "UNIT_AURA", "nameplate1", { isFullUpdate = SECRET, addedAuras = SECRET })
check(ok, "a secret update is skipped, not walked", err)
ok, err = pcall(watcherScript, nil, "UNIT_AURA", "nameplate1", { addedAuras = SECRET })
check(ok and A:GetSeen()[1].id == 48743, "a secret addedAuras is never handed to ipairs", err)
_G.issecrettable = function(t) return t == SECRET or (type(t) == "table" and t.__secretContents) end
ok, err = pcall(watcherScript, nil, "UNIT_AURA", "nameplate1", { addedAuras = { __secretContents = true } })
check(ok and A:GetSeen()[1].id == 48743, "a table whose reads are secret is skipped", err)
local secretIndex = {}
C_Secrets = { ShouldUnitAuraIndexBeSecret = function(unit, index) return secretIndex[unit .. index] or false end }
local realGet = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
	if (secretIndex[unit .. index]) then error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted") end
	return realGet(unit, index, filter)
end
auraLists.nameplate1 = { aura(34567, "player"), aura(34568, "player") }
secretIndex["nameplate1" .. 1] = true
ok, err = pcall(watcherScript, nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(ok and A:GetSeen()[1].id == 48743, "a secret aura index is asked about first and never read", err)
secretIndex = {}
C_Secrets.ShouldUnitAuraIndexBeSecret = function() error("unavailable") end
ok, err = pcall(watcherScript, nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(ok and A:GetSeen()[1].id == 48743, "a failing secrecy check counts as secret", err)
C_Secrets, _G.issecrettable = nil, nil
C_UnitAuras.GetAuraDataByIndex = function() error("raised anyway") end
ok, err = pcall(watcherScript, nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(ok, "without the secrecy API a raising read is still caught", err)
C_UnitAuras.GetAuraDataByIndex = realGet
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(A:GetSeen()[1].id == 34568, "readable auras are still harvested after all that")
timers = {}

combat = true
watcherScript(nil, "PLAYER_REGEN_DISABLED")
check(not registered.UNIT_AURA, "in combat UNIT_AURA is not even registered")
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
auraLists.nameplate1 = { aura(12345, "player") }
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(A:GetSeen()[1].id ~= 12345, "nothing is harvested in combat")
combat = false
watcherScript(nil, "PLAYER_REGEN_ENABLED")
check(registered.UNIT_AURA, "and listening resumes when combat ends")

profile.showAuras = false
auraLists.nameplate1 = { aura(23456, "player") }
watcherScript(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
check(A:GetSeen()[1].id ~= 23456, "nothing is harvested while plate auras are off")
profile.showAuras = true

for id = 100, 160 do A.Record(aura(id, "player")) end
check(#A:GetSeen() == A.SeenLimit and A:GetSeen()[1].id == 160, "the list is capped, newest kept", #A:GetSeen())
spec = "251"
check(#A:GetSeen() == 0, "another specialization starts empty")
spec = "250"

--------------------------------------------------------------------------
-- Part 1b: the suggestions (AuraSuggestions.lua)
--------------------------------------------------------------------------
local known = { [77575] = true }
C_SpellBook = { IsSpellKnown = function(id) return known[id] or false end }
function GetSpecialization() return 1 end
local currentSpec = 252
function GetSpecializationInfo() return currentSpec, "Spec" end
chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/AuraSuggestions.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
local Sg = ns.NamePlatesPrivate.AuraSuggestions
check(type(Sg) == "table" and Sg.Retail and Sg.Group, "AuraSuggestions is exported")

-- The table's shape: the 40 Retail specializations, real class tokens, numbers, one row per aura.
local SPECS = { [62]="MAGE",[63]="MAGE",[64]="MAGE",[65]="PALADIN",[66]="PALADIN",[70]="PALADIN",[71]="WARRIOR",
	[72]="WARRIOR",[73]="WARRIOR",[102]="DRUID",[103]="DRUID",[104]="DRUID",[105]="DRUID",[250]="DEATHKNIGHT",
	[251]="DEATHKNIGHT",[252]="DEATHKNIGHT",[253]="HUNTER",[254]="HUNTER",[255]="HUNTER",[256]="PRIEST",[257]="PRIEST",
	[258]="PRIEST",[259]="ROGUE",[260]="ROGUE",[261]="ROGUE",[262]="SHAMAN",[263]="SHAMAN",[264]="SHAMAN",
	[265]="WARLOCK",[266]="WARLOCK",[267]="WARLOCK",[268]="MONK",[269]="MONK",[270]="MONK",[577]="DEMONHUNTER",
	[581]="DEMONHUNTER",[1480]="DEMONHUNTER",[1467]="EVOKER",[1468]="EVOKER",[1473]="EVOKER" }
local specCount, rowCount, shapeOK, firstBad = 0, 0, true, nil
for specID, spec in pairs(Sg.Retail) do
	specCount = specCount + 1
	if (SPECS[specID] ~= spec.class) then shapeOK, firstBad = false, "spec " .. tostring(specID) end
	local seenHere, perList = {}, { once = 0, highlight = 0 }
	for _, row in ipairs(spec) do
		rowCount = rowCount + 1
		local aura, grant, rec = row[1], row[2], row[3]
		if (type(aura) ~= "number" or aura <= 0 or type(grant) ~= "number" or grant < 0 or seenHere[aura]
			or not (rec == nil or rec == "once" or rec == "highlight")) then
			shapeOK, firstBad = false, specID .. ":" .. tostring(aura)
		end
		seenHere[aura] = true
		if (rec) then perList[rec] = perList[rec] + 1 end
	end
	if (perList.once > 8 or perList.highlight > 16) then shapeOK, firstBad = false, "limits " .. specID end
end
check(specCount == 40, "every Retail specialization has a table", specCount)
check(shapeOK and rowCount > 80, "every row is { aura, grant, nil|once|highlight }, once per spec, within the limits", firstBad or rowCount)
check(#Sg:GetClasses() == 13, "thirteen classes", #Sg:GetClasses())
check(#Sg:GetGroup() == 3, "three group debuffs")

-- Talent gating: talented first, the rest after and not recommended.
known = {}
local unholy = Sg:GetForSpec(252)
check(unholy[#unholy].known == false and unholy[1].known == true, "untalented suggestions sort after the talented ones")
local h, o = Sg:GetRecommended(252)
local hasDread = false
for _, id in ipairs(o) do if (id == 1240996) then hasDread = true end end
check(not hasDread and #o >= 1, "an untalented pick is not recommended")
known[77575] = true
h, o = Sg:GetRecommended(252)
hasDread = false
for _, id in ipairs(o) do if (id == 1240996) then hasDread = true end end
check(hasDread and Sg:GetForSpec(252)[1].known, "once talented it is")
check(#Sg:GetForSpec(nil) == 0 and #Sg:GetForSpec(999999) == 0, "no specialization, no suggestions")

-- Use recommended's write, through the lists: the stored strings parse back to the same IDs.
A:SetText("highlight", A.Join(h))
A:SetText("once", A.Join(o))
local back = A:GetList("once")
check(#back == #o and back[1] == o[1] and (profile.auraHighlights[spec] or "") == A.Join(h),
	"the recommended lists round-trip through the stored strings (an empty one is no key)")
A:SetText("highlight", "")
A:SetText("once", "")

-- Forever (plan step 3): per class, every rank, its own group debuffs; nothing Retail.
local CLASSIC = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
	MAGE = true, WARLOCK = true, DRUID = true }
local foreverOK, foreverBad, foreverRows = true, nil, 0
for class, list in pairs(Sg.Forever) do
	if (not CLASSIC[class]) then foreverOK, foreverBad = false, class end
	for _, row in ipairs(list) do
		foreverRows = foreverRows + 1
		local ranks, grants, rec = row[1], row[2], row[3]
		if (type(ranks) ~= "table" or #ranks == 0 or not (grants == nil or type(grants) == "table")
			or not (rec == nil or rec == "once" or rec == "highlight")) then
			foreverOK, foreverBad = false, class .. ":" .. tostring(ranks and ranks[1])
		end
		for _, id in ipairs(ranks) do
			if (type(id) ~= "number" or id <= 0) then foreverOK, foreverBad = false, class end
		end
	end
end
check(foreverOK and foreverRows >= 25, "every Forever row is { ranks, grants|nil, nil|once|highlight }", foreverBad or foreverRows)
ns.IsForever = true
check(#Sg:GetForSpec(252) == 0 and Sg.GetSpecID() == nil, "Forever gets no Retail specialization suggestions")
check(#Sg:GetClasses() == 8 and #Sg:GetGroup() == #Sg.ForeverGroup, "Forever lists its own classes and group debuffs",
	#Sg:GetClasses())
units.player.class = "WARLOCK"
known = { [172] = true, [6222] = true }
local own = Sg:GetOwn()
check(own[1].id == 6222 and own[1].known and #own[1].ids == 7, "your class: the highest rank you know is the one shown", own[1].id)
check(own[#own].known == false and own[#own].id == own[#own].ids[#own[#own].ids], "an unlearned spell shows its top rank, after the learned ones")
h, o = Sg:GetRecommended()
check(#o == 1 and o[1] == 6222, "recommended on Forever: only what you have learned, at your rank", #o)
for _, entry in ipairs(Sg:GetAll()) do
	if (entry.class == "WARLOCK" and entry.ids[1] == 172) then
		check(entry.id == 25311, "All classes shows the top rank", entry.id)
	end
end
-- One spell, several ranks: on adds the rank shown, unless one is already listed; off removes them all.
profile.auraOnceSpells = "172, 999"
local ranks = { 172, 6222, 6223, 7648, 11671, 11672, 25311 }
check(A:SetListedRanks("once", ranks, true, 6222) and profile.auraOnceSpells == "172, 999", "a listed rank counts as listed")
check(A:SetListedRanks("once", ranks, false) and profile.auraOnceSpells == "999", "off removes every rank", profile.auraOnceSpells)
profile.auraOnceSpells = "6223, 999, 11672"
check(A:SetListedRanks("once", ranks, false) and profile.auraOnceSpells == "999", "including higher ranks typed by hand", profile.auraOnceSpells)
check(A:SetListedRanks("once", ranks, true, 6222) and profile.auraOnceSpells == "999, 6222", "on adds the rank shown", profile.auraOnceSpells)
A:SetText("once", "")
units.player.class = "DEATHKNIGHT"
known = { [77575] = true }
ns.IsForever = nil

--------------------------------------------------------------------------
-- Part 2: the fold and the window, over the kit stubs
--------------------------------------------------------------------------
local savedSeen = module.db.global.auraSeen
local S = dofile(scratch .. "/stubs.lua")
local kns, Addon = S.ns, S.Addon
local function load(rel)
	local fn, err = loadfile(root .. "/" .. rel)
	if (not fn) then error("could not load " .. rel .. ": " .. tostring(err)) end
	return fn(Addon, kns)
end
for _, file in ipairs({ "Options/Kit/Kit.lua", "Options/Kit/Look.lua", "Options/Kit/Config.lua", "Options/Kit/Defaults.lua",
	"Options/Kit/Combat.lua", "Options/Kit/Controls.lua", "Options/Kit/Preview.lua", "Options/Kit/Renderer.lua" }) do
	local loaded, err = pcall(load, file)
	check(loaded, file .. " loads", err)
end
local Kit = kns.OptionsKit
local Renderer = Kit.Renderer

-- A page shaped like Nameplates -> Aura filters.
local value = "55078"
local options = { type = "group", name = "Root", args = { page = { type = "group", name = "Page", args = {
	filters = { type = "group", inline = true, name = "Aura Filters", order = 1, args = {
		toggle = { type = "toggle", name = "Your debuffs", order = 1, get = function() return true end, set = function() end },
		picker = { type = "execute", name = "Choose auras", order = 2, func = function() end },
		manual = { type = "group", inline = true, name = "Spell IDs by Hand", order = 3, args = {
			ids = { type = "input", name = "Spells shown only once", order = 1,
				get = function() return value end, set = function(_, v) value = v end }
		} }
	} }
} } } }
Renderer:SetNavigation(options.args.page.args.filters, "sections")
Renderer:SetStartClosed(options.args.page.args.filters.args.manual)
local content = CreateFrame("Frame")
local page = Renderer:CreatePage(content)
page:Show(options, { "page" })
local function find(kind, label)
	for _, control in ipairs(page:GetControls()) do
		if (control.kind == kind and (not label or control.labelText == label or (control.GetLabel and control:GetLabel() == label))) then
			return control
		end
	end
end
check(find("execute") and find("toggle"), "the filters and the picker button are drawn")
check(find("input") == nil, "the spell ID fields start folded away")
check(find("header", "Spell IDs by Hand") ~= nil, "the fold's header is drawn")
check(page:RevealPath({ "page", "filters", "manual", "ids" }) and find("input") ~= nil,
	"revealing the field's path (search) opens the fold")

-- The window.
kns.NamePlatesPrivate = ns.NamePlatesPrivate
kns.GetConfig = function() return { AurasNumTotal = 6 } end
kns.Prefix = kns.Prefix or "AzeriteUI"
C_Spell = { GetSpellName = function(id) return id == 55078 and "Blood Plague" or nil end,
	GetSpellTexture = function() return 237514 end, RequestLoadSpellData = function() end }
C_ClassColor = { GetClassColor = function() return { WrapTextInColorCode = function(_, s) return s end } end }
function GetSpecialization() return 1 end
function GetSpecializationInfo() return currentSpec, "Spec" end
currentSpec = 250
module.db.global.auraSeen = savedSeen
local loaded, err = pcall(load, "Options/Kit/AuraPicker.lua")
check(loaded and Kit.AuraPicker, "AuraPicker.lua loads", err)
local picker = Kit.AuraPicker
if (picker) then
	local opened, openErr = pcall(picker.Open, picker)
	check(opened and openErr == true and picker:IsShown(), "the picker opens with seen and listed entries", openErr)
	profile.auraOnceSpells = "1,2,3,4,5,6,7,8"
	profile.auraHighlights["250"] = "55078, 99999"
	check(pcall(picker.Refresh, picker), "it lays out again with full lists and an unseen ID (Other entries)")
	combat = true
	check(pcall(picker.Refresh, picker), "and in combat")
	combat = false
	module.db.global.auraSeen = {}
	profile.auraOnceSpells, profile.auraHighlights = "", {}
	check(pcall(picker.Refresh, picker), "and with nothing at all")
	check(A:SetListed("once", 55078, true) and picker:IsShown(), "a list write while open lays it out through the listener")

	-- The suggestion sections (Unholy, spec 252).
	currentSpec = 252
	known = {}
	picker:Refresh()
	local function has(id) for _, v in ipairs(picker:GetShownIDs()) do if (v == id) then return true end end return false end
	check(has(191587) and has(1240996), "Your spec lists the specialization's suggestions, untalented ones too")
	check(has(113746) and has(1490), "Group debuffs are listed")
	-- Virulent Plague is in Your spec; listed as once-only it must not show again under Other entries.
	A:SetListed("once", 191587, true)
	local count = 0
	for _, v in ipairs(picker:GetShownIDs()) do if (v == 191587) then count = count + 1 end end
	check(count == 1, "an ID shows in one section only", count)
	A:SetListed("once", 191587, false)
	check(not has(188389), "All classes starts folded")
	picker:SetFolded("all", false)
	check(has(188389) and has(55078), "opened, All classes lists other classes' suggestions")
	picker:SetFilter("", "SHAMAN")
	check(has(188389) and not has(1079), "the class filter keeps only that class")
	picker:SetFilter("blood plague", nil)
	local bp = 0
	for _, v in ipairs(picker:GetShownIDs()) do if (v == 55078) then bp = bp + 1 end end
	check(bp == 2 and not has(188389), "the search matches spell names (Blood Plague also above, under Other entries)", bp)
	picker:SetFilter("188389", nil)
	check(has(188389), "and spell IDs")
	picker:SetFilter("", nil)
	picker:SetFolded("all", true)
	kns.IsForever = true
	ns.IsForever = true
	-- On Forever (the kit stubs' player is a Warrior): Your class shows Rend at its top rank (nothing learned),
	-- the group debuffs are Forever's, and none of Retail's show.
	known = {}
	check(pcall(picker.Refresh, picker) and has(11574) and has(11597) and not has(191587) and not has(113746),
		"on Forever the sections hold Forever's suggestions")
	-- Two priests, two ranks of Shadow Word: Pain seen: one row (maintainer's Forever screenshot).
	module.db.global.auraSeen = { [spec] = { { id = 10894, class = "PRIEST" }, { id = 10893, class = "PRIEST" } } }
	picker:Refresh()
	local swp = 0
	for _, v in ipairs(picker:GetShownIDs()) do if (v == 10893 or v == 10894) then swp = swp + 1 end end
	check(swp == 1, "seen ranks of one spell share a row", swp)
	module.db.global.auraSeen = {}
	-- A lower rank of Rend in the once list belongs to that row, not to Other entries.
	A:SetText("once", "772")
	local rend = 0
	for _, v in ipairs(picker:GetShownIDs()) do if (v == 772 or v == 11574) then rend = rend + 1 end end
	check(rend == 1, "a listed lower rank is the row's, not another row", rend)
	A:SetText("once", "")
	ns.IsForever, kns.IsForever = nil, nil
	A:SetText("once", "")
	picker:Close()
	check(not picker:IsShown(), "it closes")
end

print(string.format("Aura picker: %d checks, %d failures", checks, failures))
if (failures > 0) then error("aura picker harness failed", 0) end

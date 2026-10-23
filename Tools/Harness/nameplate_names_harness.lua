-- Real name rules, context resolver, events and options; does not prove client rendering.
-- lua Tools/Harness/nameplate_names_harness.lua .
local E = setmetatable({}, { __index = _G })
setfenv(1, E)
local root = arg[1] or "."
local forever = arg[2] ~= "Retail"
local checks = 0
local function eq(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local SECRET = {}
function issecretvalue(value) return value == SECRET end
-- WoW's UTF-8 substring, modelled for these name fixtures.
local strings = setmetatable({}, { __index = string })
strings.utf8sub = function(text, first, last)
	local chars = {}
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = char end
	return table.concat(chars, "", first, math.min(last, #chars))
end
strings.utf8lower = string.lower
E.string = strings
function GetLocale() return "enUS" end
local location = { map = 1, key = false }
local mapCalls = 0
function IsInInstance() return location.instance ~= nil, location.instance or "none" end
C_ChallengeMode = { IsChallengeModeActive = function() return location.key end }
local maps = { [1] = { parentMapID = 0 }, [2] = { parentMapID = 0 }, [3] = { parentMapID = 2 }, [4] = { parentMapID = 4 } }
C_Map = {
 GetBestMapForUnit = function() mapCalls = mapCalls + 1; return location.map end,
 IsCityMap = function(id) return id == 2 end,
 GetMapInfo = function(id) return maps[id] end
}
local units = {
	friend = { "Marshal", "Dughan", player = true },
	enemy = { "Enemy", "Surname", player = true, hostile = true },
	solo = { "Hogger", player = true },
	npc = { "Marshal Dughan", "Ignored", player = false },
	accent = { "Élodie", "Lune", player = true },
	cjk = { "明月", "星辰", player = true },
	combined = { "Marshal Dughan", player = true }
}
function UnitName(unit) local u = units[unit]; if u then return u[1], u[2] end end
function UnitIsPlayer(unit) return units[unit] and units[unit].player end
function UnitCanAttack(_, unit) return units[unit] and units[unit].hostile or false end
function UnitReaction(_, unit) return units[unit] and (units[unit].hostile and 3 or 5) end
-- Camelot NameUtil's documented space-separated input shape, including combined names.
NameUtil = { SplitPlayerNameIntoParts = function(name) return name:match("^([^ ]+) (.*)") end }
local module, generated = {}, nil
local fallbackCalls = 0
local methods = { ["test:Name"] = function(unit, realUnit, maxChars)
	fallbackCalls = fallbackCalls + 1
	eq(maxChars, 24, "fallback retains old name limit")
	return UnitName(unit) or UnitName(realUnit) or ""
end }
local optionsModule = { AddGroup = function(_, _, generate) generated = generate end }
local ns = {
	Prefix = "test", IsForever = forever, IsRetail = true, IsMainline = true, IsRetailContent = not forever, API = {},
	oUF = { Tags = { Events = {}, Methods = methods } },
	MovableModulePrototype = { defaults = {} },
	NewModule = function() return module end,
	Merge = function(_, values) return values end,
	GetModule = function(_, name) return name == "Options" and optionsModule or module end
}
local function load(relative)
	local chunk = assert(loadfile(root .. "/" .. relative))
	setfenv(chunk, E)
	return chunk("TestAddon", ns)
end
load("Core/API/Abbreviations.lua")
load("Components/UnitFrames/NamePlates/Settings.lua")
module.db = { profile = ns.NamePlatesPrivate.defaults.profile }
local profile = module.db.profile
local tag = assert(methods["test:NamePlateName"])
if forever then
eq(profile.friendlyPlayerNameFormat, "first", "friendly default")
eq(profile.enemyPlayerNameFormat, "first", "enemy default")
eq(profile.abbreviateNPCNames, false, "NPC default")
eq(tag("friend"), "Marshal", "first name")
profile.friendlyPlayerNameFormat = "full"
eq(tag("friend"), "Marshal Dughan", "surname is second UnitName result")
eq(tag("enemy"), "Enemy", "enemy preference independent")
profile.enemyPlayerNameFormat = "initial"
eq(tag("enemy"), "E. Surname", "enemy initial")
eq(tag("friend"), "Marshal Dughan", "friendly preference independent")
profile.friendlyPlayerNameFormat = "initial"
eq(tag("friend"), "M. Dughan", "friendly initial")
eq(tag("accent"), "É. Lune", "UTF-8 initial")
eq(tag("cjk"), "明. 星辰", "CJK initial")
eq(tag("solo"), "Hogger", "no surname")
eq(tag("combined"), "M. Dughan", "combined name split")
units.combined[2] = "Dughan"
profile.friendlyPlayerNameFormat = "full"
eq(tag("combined"), "Marshal Dughan", "combined name not duplicated")
profile.friendlyPlayerNameFormat = "first"
eq(tag("combined"), "Marshal", "first part of combined name")
profile.friendlyPlayerNameFormat = "invalid"
eq(tag("friend"), "Marshal", "invalid preference defaults to first")
profile.friendlyPlayerNameFormat = "full"
units.friend[2] = SECRET
eq(tag("friend"), "Marshal", "secret surname excluded")
units.friend[2] = ""
eq(tag("friend"), "Marshal", "empty surname excluded")
units.friend[2] = "Dughan"
units.friend[1] = "Changed"
eq(tag("friend"), "Changed Dughan", "name update reads fresh values")
units.friend[1] = "Marshal"
eq(tag("npc"), "Marshal Dughan", "NPC default delegates to old tag")
profile.abbreviateNPCNames = true
eq(tag("npc"), "M. Dughan", "explicit NPC abbreviation below old 24-char threshold")
eq(tag("solo"), "Hogger", "NPC setting does not abbreviate players")
units.npc[1] = "High Marshal Dughan"
eq(tag("npc"), "H. M. Dughan", "multiple NPC words")
units.npc[1] = "Hogger"
eq(tag("npc"), "Hogger", "one-word NPC")
units.npc[1] = SECRET
eq(tag("npc"), SECRET, "secret first name uses existing display fallback")
units.npc[1] = "Marshal Dughan"
local events = ns.oUF.Tags.Events["test:NamePlateName"]
eq(events:find("UNIT_NAME_UPDATE", 1, true) ~= nil, true, "name-change event")
eq(events:find("UNIT_FACTION", 1, true) ~= nil, true, "faction-change event")

end
-- Real options setter -> real settings refresh -> name tag on an already visible plate.
load("Components/UnitFrames/NamePlates/Layout.lua")
ns.NamePlatesPrivate.ApplyFriendlyNameOnlyCVars = function() end
ns.NamePlatesPrivate.ApplyNamePlateDriverSettings = function() end
load("Components/UnitFrames/NamePlates/Module.lua")
local layouts, textUpdates = 0, 0
local plate = { unit = "friend", UpdateAllElements = function() layouts = layouts + 1 end }
plate.Name = { UpdateTag = function(self) textUpdates = textUpdates + 1; self.text = tag(plate.unit) end }
ns.ActiveNamePlates[plate] = true
module.UpdateSettings = function() ns.NamePlatesPrivate.RefreshActiveNamePlates(true) end
local L = setmetatable({}, { __index = function(_, key) return key end })
function LibStub() return { GetLocale = function() return L end } end
load("Options/OptionsPages/Nameplates.lua")
local group = generated().args.names
eq(group.hidden({ "names" }), false, "common options visible")
for _, kind in ipairs({ "friendlyPlayer", "enemyPlayer", "friendlyNPC", "enemyNPC" }) do
 local opt = group.args[kind]
 eq(opt.values().inherit, nil, "default cannot inherit itself")
 eq(opt.values().first ~= nil, forever and (kind == "friendlyPlayer" or kind == "enemyPlayer"), "first-name gate")
 opt.set({}, "full")
 eq(opt.get(), "full", "persisted " .. kind)
end
eq(tag("friend"), forever and "Marshal Dughan" or "Marshal", "Retail realm never used as surname")
group.args.friendlyPlayer.set({}, "initial")
eq(tag("friend"), forever and "M. Dughan" or "Marshal", "player initial")
eq(plate.Name.text, forever and "M. Dughan" or "Marshal", "visible player name refresh")
eq(tag("combined"), "M. Dughan", "multiword player abbreviation on both clients")
group.args.friendlyNPC.set({}, "initial")
eq(tag("npc"), "M. Dughan", "explicit NPC abbreviation on both clients")
units.enemy.player, units.enemy[1] = false, "High Marshal Dughan"
eq(tag("enemy"), "High Marshal Dughan", "enemy NPC independent")
group.args.enemyNPC.set({}, "initial")
eq(tag("enemy"), "H. M. Dughan", "multiword enemy NPC")
units.enemy.player, units.enemy[1] = true, "Enemy"
eq(tag("enemy"), forever and "Enemy Surname" or "Enemy", "player rule independent of NPC")
units.enemy.hostile = false
eq(tag("enemy"), forever and "E. Surname" or "Enemy", "faction change uses friendly rule")
units.enemy.hostile = true
units.npc[1] = SECRET
eq(tag("npc"), SECRET, "secret name uses current display")
units.npc[1] = "Marshal Dughan"
units.friend.player = SECRET
eq(tag("friend"), "Marshal", "secret classification uses current display")
units.friend.player = true
eq(tag(nil), "", "missing unit")
-- Inheritance and context transitions use real module event handlers and real option callbacks.
plate.unit = "npc"
group.args.editedNameContext.set({}, "city")
eq(group.args.friendlyNPC.get(), "inherit", "new context inherits")
eq(group.args.friendlyNPC.values().inherit ~= nil, true, "inherit choice visible")
group.args.friendlyNPC.set({}, "full")
eq(tag("npc"), "M. Dughan", "inactive context does not activate when edited")
location.map = 3
local beforeLayouts = layouts
module:OnEvent("ZONE_CHANGED_INDOORS")
eq(module:GetCurrentNameContext(), "city", "city parent detected")
eq(plate.Name.text, "Marshal Dughan", "city rule immediately applies")
eq(layouts, beforeLayouts, "context change does not relayout bars")
local beforeUpdates = textUpdates
module:OnEvent("ZONE_CHANGED")
eq(textUpdates, beforeUpdates, "unchanged context does not refresh tags")
local beforeMapCalls = mapCalls
tag("npc"); tag("friend"); tag("enemy")
eq(mapCalls, beforeMapCalls, "no map queries per tag update")
group.args.friendlyNPC.set({}, "inherit")
eq(plate.Name.text, "M. Dughan", "inherit restores defaults immediately")
group.args.friendlyNPC.set({}, "current")
eq(plate.Name.text, "Marshal Dughan", "current display overrides abbreviated defaults")
group.args.editedNameContext.set({}, "dungeon")
group.args.friendlyNPC.set({}, "full")
location.instance = "party"
module:OnEvent("PLAYER_ENTERING_WORLD", false, false)
eq(module:GetCurrentNameContext(), "dungeon", "instance takes priority over city map")
eq(plate.Name.text, "Marshal Dughan", "dungeon rule after loading screen")
location.key = true
module:OnEvent("CHALLENGE_MODE_START")
eq(module:GetCurrentNameContext(), "mythicplus", "key start without zone change")
eq(plate.Name.text, "M. Dughan", "Mythic+ inherits defaults independently")
location.key = false
module:OnEvent("CHALLENGE_MODE_COMPLETED")
eq(module:GetCurrentNameContext(), "dungeon", "key completion restores dungeon context")
for _, case in ipairs({ { "raid", "raid" }, { "pvp", "battleground" }, { "arena", "arena" } }) do
 location.instance = case[1]
 module:OnEvent("PLAYER_ENTERING_WORLD", false, false)
 eq(module:GetCurrentNameContext(), case[2], "instance " .. case[2])
end
location.instance, location.map = nil, 1
module:OnEvent("ZONE_CHANGED_NEW_AREA")
eq(module:GetCurrentNameContext(), "world", "open world restored")
eq(plate.Name.text, "M. Dughan", "default restored after leaving instance/city")
location.map = 4
eq(ns.NamePlatesPrivate.ResolveNameContext(), "world", "cyclic map hierarchy bounded")
location.map = nil
eq(ns.NamePlatesPrivate.ResolveNameContext(), "world", "unknown map falls back")
location.map = SECRET
eq(ns.NamePlatesPrivate.ResolveNameContext(), "world", "secret map rejected")
local savedMap = C_Map
C_Map = false
eq(ns.NamePlatesPrivate.ResolveNameContext(), "world", "missing city API falls back")
C_Map, location.map = savedMap, 1
module:SetEditedNameContext("not-a-context")
eq(module:GetEditedNameContext(), "dungeon", "invalid context rejected")
module:SetNameFormat("friendlyNPC", "bad-mode")
eq(module:GetNameFormat("friendlyNPC"), "full", "invalid mode rejected")
local savedProfile = module.db.profile
module.db.profile = { enabled = true, nameFormats = { default = { friendlyNPC = "full" } } }
eq(tag("npc"), "Marshal Dughan", "another profile reads its own rule")
module.db.profile = savedProfile
module.nameContext, module.editedNameContext = nil, nil
eq(tag("npc"), "M. Dughan", "saved rules survive reload-style state reset")
eq(module:GetEditedNameContext(), "default", "editor returns to default rules")
profile.enabled = false
eq(group.hidden({ "names" }), true, "disabled module hides controls")
eq(fallbackCalls > 0, true, "current display fallback exercised")
print("Nameplate names (" .. (forever and "Forever" or "Retail") .. "): " .. checks .. " checks, 0 failures")

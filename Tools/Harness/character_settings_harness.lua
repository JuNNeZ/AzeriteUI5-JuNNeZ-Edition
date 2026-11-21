-- Test the normal initialization path with the real AceDB-GE and saved table.
local name, surname, realm = "Druinnez", "Tordenskjold", ""
local regionalNames, activeRule = true, nil
GetRealmName = function() return realm end
UnitName = function() return name, surname end
UnitClass = function() return "Druid", "DRUID" end
UnitRace = function() return "Night Elf", "NightElf" end
UnitFactionGroup = function() return "Alliance" end
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 3 end
RegionalUniqueNamesEnabled = function() return regionalNames end
Enum = { GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 } }
C_GameRules = { IsGameRuleActive = function(rule) return rule == activeRule end }
CreateFrame = function() return { Hide = function() end, RegisterEvent = function() end, SetScript = function() end } end
securecallfunction = function(func, ...) return func(...) end

dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
LibStub:NewLibrary("LibDeflate", 1)
LibStub:NewLibrary("AceAddon-3.0", 1).NewAddon = function(_, ns) return ns end

local Azerite = "Azerite"
local old = "Druinnez - CAMWOW EU4 Realm 1 PvE"
local blank = "Druinnez - "
local key = "Forever:PvE:Druinnez Tordenskjold"
local alt = "Jonas - CAMWOW EU4 Realm 1 PvE"
local sibling = "Druinnez - Other Realm"
local checks = 0
local function check(value, description)
	assert(value, description)
	checks = checks + 1
end

local function boot(sv, forever)
	-- Load AceDB again in this simulated login, with the current realm/name.
	LibStub.libs["AceDB-3.0-GE"], LibStub.minors["AceDB-3.0-GE"] = nil, nil
	dofile("Libs/AceDB-3.0-GE/AceDB-3.0-GE.lua")
	AzeriteUI5_DB = sv
	local ns = {
		Prefix = Azerite, IsForever = forever,
		ThemeEffects = { ApplyPendingTheme = function() end },
		GetModule = function() end,
		RegisterChatCommand = function() end
	}
	assert(loadfile("Core/CharacterSettings.lua"))("AzeriteUI", ns)
	assert(loadfile("Core/Core.lua"))("AzeriteUI", ns)
	ns:OnInitialize()
	ns:OnEnable()
	return ns, ns.db
end

local sv = {
	global = { version = 25 },
	profiles = { Legacy = { frameScale = 1.2 } },
	profileKeys = { [old] = "Legacy", [blank] = Azerite, [alt] = "Alt" },
	char = {
		[old] = { litePlus = true, offset = -9, prefs = { value = 2, enabled = true } },
		[blank] = { offset = -4, pendingTheme = "Druid", prefs = { enabled = false } },
		[alt] = { offset = 7 }
	},
	namespaces = {
		QuestItemButton = { char = { [old] = { owner = "azeriteui" } } },
		Inactive = { char = { [old] = { enabled = true } } }
	}
}
local ns, db = boot(sv, true)
check(db.keys.char == key and db:GetCurrentProfile() == "Legacy", "hidden realm restores legacy profile")
check(db.char.litePlus and db.char.offset == -4 and db.char.pendingTheme == "Druid", "backfill while retaining current choices")
check(db.char.prefs.value == 2 and db.char.prefs.enabled == false, "nested missing values and explicit false")
check(db.profile.frameScale == 1.2 and sv.profileKeys[alt] == "Alt", "existing profiles and other characters")
local quest = db:RegisterNamespace("QuestItemButton", { char = {} })
check(quest.keys.char == key and quest.char.owner == "azeriteui", "namespace inherits character key")
check(sv.namespaces.Inactive.char[key].enabled, "unloaded namespace migrated")
db.char.prefs.value = 5
quest.char.owner = "changed"
ns:SetProfile("New Profile")
check(sv.profileKeys[key] == "New Profile" and sv.profileKeys[old] == "Legacy", "profile change persists on the new key")
check(sv.char[old].prefs.value == 2 and sv.namespaces.QuestItemButton.char[old].owner == "azeriteui", "migration keeps historical entries independent")

realm = "Restored Realm"
ns, db = boot(sv, true)
quest = db:RegisterNamespace("QuestItemButton", { char = {} })
check(db.keys.char == key and db.char.prefs.value == 5 and quest.char.owner == "changed", "realm rename and reload use the same data")
check(db:GetCurrentProfile() == "New Profile", "profile stays selected after a realm rename")
ns:ResetProfile()
realm = ""
ns, db = boot(sv, true)
check(db.char.prefs == nil and sv.namespaces.Inactive.char[key] == nil, "reset does not reimport retained history")
check(db:GetCurrentProfile() == "New Profile", "character reset retains profile selection")

surname = "Dane"
_, db = boot(sv, true)
check(db.keys.char ~= key and db.char.offset == nil, "second surname cannot claim previously migrated keys")
surname, activeRule = "Tordenskjold", Enum.GameRule.PvPRuleset
_, db = boot(sv, true)
check(db.keys.char == "Forever:PvP:Druinnez Tordenskjold" and db.char.offset == nil, "rulesets are independent")
activeRule = nil

local recentProfile = {
	global = { version = 25 },
	profileKeys = { [old] = "Legacy", [blank] = "Current" },
	char = { [old] = { profile = "Legacy", offset = 8 } }
}
_, db = boot(recentProfile, true)
check(db:GetCurrentProfile() == "Current" and db.char.offset == 8, "explicit current profile beats old character profile")

local contested = {
	global = { version = 25 },
	profileKeys = { [old] = "Legacy", [sibling] = "Other" },
	char = { [old] = { offset = 8 }, [sibling] = { offset = 11 }, [blank] = { offset = 4 } }
}
_, db = boot(contested, true)
check(db.char.offset == nil and db:GetCurrentProfile() == Azerite, "ambiguous realm history is not imported")
realm = "Other Realm"
contested.profileKeys[key] = nil
_, db = boot(contested, true)
check(db.char.offset == 11 and db:GetCurrentProfile() == "Other", "visible realm chooses the exact historical key")
db:ResetDB(Azerite)
check(db.keys.char == key and contested.profileKeys[key] == Azerite, "full reset retains the stable key")

realm = nil
_, db = boot(nil, true)
check(db.keys.char == key and AzeriteUI5_DB.profileKeys[key] == Azerite, "fresh Forever database with nil realm")
realm, surname = "Retail Realm", nil
local retailKey = "Druinnez - Retail Realm"
local retail = {
	global = { version = 25 }, profileKeys = { [retailKey] = Azerite },
	char = { [retailKey] = { offset = 12 } }
}
_, db = boot(retail, false)
check(db.keys.char == retailKey and db.char.offset == 12 and retail.foreverCharacterAliases == nil, "Retail uses its existing key")
regionalNames, realm = false, "Old Forever Realm"
_, db = boot(nil, true)
check(db.keys.char == "Druinnez - Old Forever Realm", "older Forever without regional names keeps legacy keys")

-- Optional maintainer snapshot. Load data into an isolated table and do not save it.
if arg[1] then
	local data = {}
	local read = assert(loadfile(arg[1]))
	setfenv(read, data)
	read()
	regionalNames, surname, realm = true, "Tordenskjold", ""
	_, db = boot(data.AzeriteUI5_DB, true)
	quest = db:RegisterNamespace("QuestItemButton", { char = {} })
	check(db.keys.char == key and db:GetCurrentProfile() == Azerite, "snapshot selects the existing Azerite profile")
	check(db.char.themeLitePlus and db.char.druidCastEndcapScale and db.char.druidEndcapY, "snapshot restores Druid theme and endcaps")
	check(quest.char.owner == "azeriteui", "snapshot restores quest button ownership")
end

print("Character settings: " .. checks .. " checks passed")

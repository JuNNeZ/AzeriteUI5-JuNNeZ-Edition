-- Aura Sounds: registrations through C_UnitAuras.AddAuraSound, queued while restricted.
-- Loads the real Components/Auras/AuraSounds.lua against stubs. The client playing the
-- sound is not modelled; only what is registered, when, and what is removed.
-- Run: lua.exe Tools/Harness/aura_sounds_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

local secretMeta = {}
issecretvalue = function(v) return getmetatable(v) == secretMeta end

-- Restrictions and combat.
local combat, restricted = false, {}
InCombatLockdown = function() return combat end
Enum = {
	UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 },
	AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
}
C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return restricted[kind] == true end }

-- The client API, recording calls.
local added, removed, nextID = {}, {}, 100
C_UnitAuras = {
	AddAuraSound = function(trigger, info)
		if (combat) then error("AddAuraSound: restricted") end
		nextID = nextID + 1
		added[#added + 1] = { id = nextID, trigger = trigger, info = info }
		return nextID
	end,
	RemoveAuraSound = function(id) removed[#removed + 1] = id end
}
C_Spell = { GetSpellIDForSpellIdentifier = function(name) return ({ ["Power Infusion"] = 10060 })[name] end }
NONE = "None"
local played = {}
PlaySoundFile = function(file, channel) played[#played + 1] = { file, channel } end

-- LibSharedMedia with two sounds and a callback hook.
local lsmCallback
-- As LibSharedMedia itself: "None" is the number 1 (PlaySoundFile ignores it).
local media = { ["None"] = 1, ["Air Horn"] = "Interface\\AddOns\\Pack\\airhorn.ogg", ["Ding"] = 567890 }
local LSM = {
	List = function(_, kind) local list = {} for name in pairs(media) do list[#list + 1] = name end table.sort(list) return list end,
	Fetch = function(_, kind, name) return media[name] end,
	-- CallbackHandler embeds it as lib.RegisterCallback(owner, event, fn).
	RegisterCallback = function(owner, event, fn) lsmCallback = fn end
}
LibStub = function(name) if name == "LibSharedMedia-3.0" then return LSM end end

-- Namespace, module system and events.
local events = {}
local module
local ns = { API = { IsEventAvailable = function() return true end } }
ns.NewModule = function(_, name)
	module = {
		GetName = function() return name end,
		RegisterEvent = function(self, event, method) events[event] = method end,
		UnregisterEvent = function(self, event) events[event] = nil end
	}
	return module
end
ns.db = { RegisterNamespace = function(_, name, defaults)
	local profile = {}
	for k, v in pairs(defaults.profile) do profile[k] = v end
	return { profile = profile }
end }

assert(loadfile(root .. "/Components/Auras/AuraSounds.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
module:OnInitialize()
module:OnEnable()
check(module:IsAvailable(), "available where the client has the API")
check(events.PLAYER_ENTERING_WORLD, "waits for the world to load")
local db = module.db.profile

-- Nothing configured: nothing registered.
module:OnEvent("PLAYER_ENTERING_WORLD")
check(#added == 0, "empty slots register nothing")
check(events.PLAYER_ENTERING_WORLD == nil, "the login hook runs once")

-- A slot with an ID, a file path sound.
db.sound1Spell, db.sound1Unit, db.sound1Trigger, db.sound1Sound = "10060", "player", "added", "Air Horn"
module:UpdateSettings()
check(#added == 1, "one slot, one registration")
local first = added[1]
check(first.trigger == 0, "gained -> Enum.UnitAuraSoundTrigger.Added")
check(first.info.unitToken == "player" and first.info.spellID == 10060, "unit and spell")
check(first.info.soundFileName == "Interface\\AddOns\\Pack\\airhorn.ogg" and first.info.soundFileID == nil, "a path goes in soundFileName")

-- A name, a file ID sound, a stack trigger, target.
db.sound2Spell, db.sound2Unit, db.sound2Trigger, db.sound2Sound = "Power Infusion", "target", "stacks", "Ding"
module:UpdateSettings()
check(#removed == 1 and removed[1] == first.id, "reapplying removes the previous registration first")
check(#added == 3, "both slots registered again")
local second = added[3]
check(second.info.spellID == 10060 and second.info.unitToken == "target", "a spell name resolves through the client")
check(second.trigger == 1, "stacks -> ApplicationsIncreased")
check(second.info.soundFileID == 567890 and second.info.soundFileName == nil, "a file ID goes in soundFileID")

-- Incomplete slots are skipped.
db.sound3Spell, db.sound3Sound = "10060", "None"
db.sound4Spell, db.sound4Sound = "No Such Spell", "Ding"
db.sound5Spell, db.sound5Unit, db.sound5Sound = "10060", "raid1", "Ding"
local before = #added
module:UpdateSettings()
check(#added - before == 2, "None, unknown spells and units outside the list are skipped")

-- In combat: queued, nothing touched, then applied when it ends.
combat = true
local removedBefore, addedBefore = #removed, #added
db.sound1Trigger = "removed"
module:UpdateSettings()
check(#removed == removedBefore and #added == addedBefore, "in combat nothing is removed or added")
check(module.pending and events.PLAYER_REGEN_ENABLED, "the change waits for combat to end")
combat = false
module:OnEvent("PLAYER_REGEN_ENABLED")
check(not module.pending and #added > addedBefore, "applied once combat ends")
check(events.PLAYER_REGEN_ENABLED == nil and events.ADDON_RESTRICTION_STATE_CHANGED == nil, "the waiting events are dropped")
local last = added[#added - 1]
check(last.trigger == 2, "fades -> Removed")

-- An encounter or a key restricts too, without combat.
restricted[2] = true
addedBefore = #added
module:UpdateSettings()
check(#added == addedBefore and module.pending, "a key (ChallengeMode) queues the change")
module:OnEvent("ADDON_RESTRICTION_STATE_CHANGED")
check(#added == addedBefore and module.pending, "still restricted: still waiting")
restricted[2] = nil
module:OnEvent("ADDON_RESTRICTION_STATE_CHANGED")
check(#added > addedBefore and not module.pending, "the restriction lifting applies it")

-- Switched off: everything removed, nothing added.
db.enabled = false
removedBefore, addedBefore = #removed, #added
module:UpdateSettings()
check(#added == addedBefore and #removed > removedBefore, "switched off: the old ones are removed, nothing added")
check(#module.registered == 0, "switched off: no registrations left")
db.enabled = true
module:UpdateSettings()

-- A media pack registering a sound: only one a slot names re-applies.
addedBefore = #added
lsmCallback(nil, "sound", "Unrelated Bell")
check(#added == addedBefore, "an unrelated sound does not re-register")
lsmCallback(nil, "sound", "Ding")
check(#added > addedBefore, "a sound a slot waits for re-registers")

-- Test button.
module:PreviewSlot(2)
check(played[1] and played[1][1] == 567890 and played[1][2] == "Master", "Test plays the slot's sound on Master")

-- Choices.
local choices = module:GetSoundChoices()
check(choices.None and choices["Air Horn"] and choices.Ding, "the sound list is None plus LibSharedMedia's")

-- Slot status: what the options page shows under each slot.
local L = setmetatable({}, { __index = function(_, k) return k end })
C_Spell.GetSpellName = function(id) return id == 10060 and "Power Infusion" or nil end
check(module:GetSlotStatus(1, L) == "Registered: Power Infusion (10060).", "a registered slot names the spell and ID")
check(module:GetSlotStatus(3, L) == "Choose a sound.", "a slot without a sound says so")
check(module:GetSlotStatus(4, L) == "Unknown spell: No Such Spell", "a name the client does not know is named")
check(module:GetSlotStatus(6, L) == "", "an empty slot says nothing")
local realAdd = C_UnitAuras.AddAuraSound
C_UnitAuras.AddAuraSound = function() return nil end
module:UpdateSettings()
check(module:GetSlotStatus(1, L):find("returned no registration", 1, true), "no ID back from the game is reported")
C_UnitAuras.AddAuraSound = function() error("bad argument") end
module:UpdateSettings()
check(module:GetSlotStatus(1, L):find("refused it: .*bad argument"), "an error from the game is shown")
C_UnitAuras.AddAuraSound = realAdd
combat = true
module:UpdateSettings()
check(module:GetSlotStatus(1, L) == "Waiting until combat or the encounter ends.", "in combat every slot says it waits")
combat = false
module:OnEvent("PLAYER_REGEN_ENABLED")
check(module:GetSlotStatus(1, L):find("^Registered"), "after combat the status is current again")

-- Aura IDs: what is typed becomes the aura the game matches.
local auras, unknown = module:ResolveAuras("198589")
check(#auras == 1 and auras[1] == 212800 and #unknown == 0, "a known spell/aura pair translates (Blur)")
auras = module:ResolveAuras("Blessing of Freedom")
check(#auras == 1 and auras[1] == 1044, "a Common auras name resolves without the client knowing the spell")
auras, unknown = module:ResolveAuras("2825, 32182 ; 2825, Nope")
check(#auras == 2 and #unknown == 1 and unknown[1] == "Nope", "several IDs, duplicates once, unknown words reported")
-- The Cooldown Manager's links for the player's own spells.
C_CooldownViewer = {
	GetCooldownViewerCategorySet = function(category) return category == 2 and { 7 } or {} end,
	GetCooldownViewerCooldownInfo = function(id)
		return { spellID = 8921, overrideSpellID = 8922, linkedSpellIDs = { 164812 }, selfAura = false }
	end
}
module:BuildCooldownLinks()
auras = module:ResolveAuras("8921")
check(#auras == 1 and auras[1] == 164812, "Cooldown Manager links translate the player's spells")
check(module:ResolveAuras("8922")[1] == 164812, "an override spell maps to the same aura")
C_CooldownViewer = { GetCooldownViewerCategorySet = function() error("restricted") end, GetCooldownViewerCooldownInfo = function() end }
module:BuildCooldownLinks()
check(module:ResolveAuras("8921")[1] == 8921, "a failing Cooldown Manager falls back to the spell's own ID")
C_CooldownViewer = nil
-- A slot with several auras registers each one.
db.sound6Spell, db.sound6Unit, db.sound6Trigger, db.sound6Sound = module.Presets[2].spells, "player", "removed", "Ding"
local beforeSated = #added
module:UpdateSettings()
local satedCount = 0
for i = beforeSated + 1, #added do
	if (added[i].trigger == 2 and added[i].info.spellID ~= 10060) then satedCount = satedCount + 1 end
end
check(satedCount == 6, "the Sated preset registers all six debuffs on fade")
check(module:GetPreset(db.sound6Spell).key == "sated", "the dropdown recognises the preset in the field")
db.sound6Spell = ""
module:UpdateSettings()

-- 2026-10-13 retest: "Map" stays on in the open world and must not hold registration back.
restricted[4] = true
local beforeMap = #added
module:UpdateSettings()
check(not module.pending and #added > beforeMap, "a restricted map does not keep slots waiting")
restricted[4] = nil
-- A refusal the check does not foresee is retried after a zone change.
local realAddRetry = C_UnitAuras.AddAuraSound
C_UnitAuras.AddAuraSound = function() error("AddAuraSound: restricted") end
module:UpdateSettings()
check(module.retry and events.ZONE_CHANGED_NEW_AREA, "a refused registration waits for the next zone or fight")
C_UnitAuras.AddAuraSound = realAddRetry
local beforeRetry = #added
module:OnEvent("ZONE_CHANGED_NEW_AREA")
check(not module.retry and #added > beforeRetry and events.ZONE_CHANGED_NEW_AREA == nil, "the retry registers and stops listening")
-- During ADDON_RESTRICTION_STATE_CHANGED the client reports nothing restricted: look a frame later.
local deferred
C_Timer = { After = function(_, fn) deferred = fn end }
restricted[1] = true
module:UpdateSettings()
check(module.pending, "an encounter queues the change")
module:OnEvent("ADDON_RESTRICTION_STATE_CHANGED")
check(module.pending and type(deferred) == "function", "the restriction event is looked at on the next frame")
restricted[1] = nil
deferred()
check(not module.pending, "the next frame applies it")
C_Timer = nil
-- A refusal is also retried on a short timer, not only after a fight (the ping came at end of combat).
local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay, fn } end }
C_UnitAuras.AddAuraSound = function() error("AddAuraSound: restricted") end
module:UpdateSettings()
check(#timers == 1 and timers[1][1] == 5, "a refused registration retries in five seconds")
C_UnitAuras.AddAuraSound = realAddRetry
local beforeTimer = #added
timers[1][2]()
check(not module.retry and #added > beforeTimer and module.retryCount == nil, "the timed retry registers")
C_UnitAuras.AddAuraSound = function() error("AddAuraSound: restricted") end
timers = {}
for _ = 1, 14 do module:UpdateSettings() end
check(#timers == 12, "retries stop after twelve tries")
C_UnitAuras.AddAuraSound = realAddRetry
module.retryCount = nil
module:UpdateSettings()
C_Timer = nil

-- The dropdown shows the preset for a typed name.
check(module:GetPreset("Blessing of Freedom").key == "1044", "a typed name shows its Common auras entry")
check(module:GetPreset("Blessing of Freedom, 642") == nil, "several auras match no single entry")

-- Validation helper.
check(module:ResolveSpell(" 10060 ") == 10060 and module:ResolveSpell("1.5") == nil and module:ResolveSpell("") == nil,
	"spell input: IDs, no fractions, empty is nothing")

print(string.format("Aura sounds: %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

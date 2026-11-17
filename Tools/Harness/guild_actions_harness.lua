-- Offline guild-write contracts. These stubs never contact or control WoW.
local root = arg[1] or "."
local checks, combat, inGuild = 0, false, true
local guildName, actor, actorRank = "Test Guild", "Player-Self", 2
local editNote, promote, demote, assignment = true, true, true, true
local secret = {}
local writes, timers, reads = {}, {}, 0
local function check(value, label) checks = checks+1; assert(value, label) end
local function Row(name, rank, guid, note)
    local row = { name, rank, 3, 40, "Warrior", "City", note, "OFFICER PRIVATE", false, 0, "WARRIOR" }
    row[17] = guid; return row
end
local target = Row("Alt Person-TestRealm", "Member", "Player-Target", "Old public")
local own = Row("Officer-TestRealm", "Officer", "Player-Self", "Own public")
local roster = { target, own }
local orders = { ["Player-Target"] = 4, ["Player-Self"] = 2 }
local names = { "Guild Master", "Officer", "Veteran", "Member", "Initiate" }
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
IsInGuild = function() return inGuild end
GetGuildInfo = function() return guildName end
GetNormalizedRealmName = function() return "TestRealm" end
GetNumGuildMembers = function() reads = reads+1; return #roster end
GetGuildRosterInfo = function(i) reads = reads+1; return unpack(roster[i], 1, 17) end
UnitGUID = function() return actor end
CanEditPublicNote = function() return editNote end
CanGuildPromote = function() return promote end
CanGuildDemote = function() return demote end
GuildControlGetNumRanks = function() return #names end
GuildControlGetRankName = function(i) return names[i] end
time = function() return 1794744000 end
C_Timer = { After = function(_, callback) timers[#timers+1] = callback end }
C_GuildInfo = { GuildRoster = function() end,
    GetGuildRankOrder = function(guid) assert(not combat, "rank reads during combat"); return guid == actor and actorRank or orders[guid] end,
    IsGuildRankAssignmentAllowed = function() return assignment end,
    SetNote = function(guid, note, public)
        assert(not combat, "protected SetNote in combat"); writes[#writes+1] = { kind = "note", guid = guid, value = note, public = public }
    end,
    SetGuildRankOrder = function(guid, order)
        assert(not combat, "protected SetGuildRankOrder in combat"); writes[#writes+1] = { kind = "rank", guid = guid, value = order }
    end }
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end } end
local module = { UI = {}, DisableSettingsExport = function() end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults)
        return { profile = defaults.profile, global = defaults.global, RegisterCallback = function() end }
    end } }
for _, file in ipairs({ "GuildManager", "GuildManagerData", "GuildManagerHistory", "GuildManagerActions" }) do
    assert(loadfile(root .. "/Components/Misc/" .. file .. ".lua"))("Test", ns)
end
module:OnInitialize(); module:ReadRoster()
local key = module:CharacterKey("Alt Person")
local function Base() return assert(module:GetGuildActionState(key)) end
local function Note(value) return module:PrepareGuildAction("note", Base(), value) end
local base = Base()
check(base.canNote and #base.choices == 2, "offline guild character has public-note and permitted rank actions")
check(base.choices[1].order == 3 and base.choices[2].order == 5, "rank choices exclude self-rank, leader and unchanged rank")
local preview = assert(Note("Changed public"))
check(#writes == 0, "preparing a preview never calls a write")
roster[1], roster[2] = roster[2], roster[1]
check(module:ApplyGuildAction(preview) and writes[1].guid == "Player-Target" and writes[1].public == true, "roster reorder still writes public note to original GUID")
check(module.pendingGuildAction and module.guildActionStatus:find("waiting", 1, true), "request does not claim success before roster observation")
check(not module:ApplyGuildAction(preview) and #writes == 1, "confirmation is single-use")
check(not Note("Another"), "second write is blocked while awaiting observation")
module:ObserveGuildAction(); check(module.pendingGuildAction ~= nil, "unchanged roster is not treated as acknowledgement")
target[7] = "Changed public"; module:OnEvent("GUILD_ROSTER_UPDATE")
check(not module.pendingGuildAction and module.guildActionStatus:find("visible", 1, true), "fresh matching roster observes requested public note")
local second = assert(Note("Next")); check(module:ApplyGuildAction(second), "second explicit operation after observation")
timers[1](); check(module.pendingGuildAction == second, "old timeout cannot clear a newer request")
local count = #writes; timers[2]()
check(not module.pendingGuildAction and #writes == count, "timeout changes status without resending or claiming success")
preview = assert(Note("Preview stale")); target[7] = "Changed by another officer"
check(not module:ApplyGuildAction(preview) and #writes == count, "concurrent public note edit rejects approval")
base = Base(); target[7] = "Changed before preview"
check(not module:PrepareGuildAction("note", base, "New"), "stale editor rejects preview instead of overwriting newer note")
preview = assert(Note("No permission")); editNote = false
check(not module:ApplyGuildAction(preview) and #writes == count, "permission loss before approval rejects public write")
check(not Base().canNote, "ordinary member cannot edit somebody else's public note")
local ownState = assert(module:GetGuildActionState(module:CharacterKey("Officer")))
check(ownState.canNote and #ownState.choices == 0, "self-public-note exception matches native UI and never permits own rank change")
editNote = true
check(not Note(string.rep("x", 32)) and not Note("bad|markup") and not Note("line\nbreak"), "public note length and plain-text validation")
check(Note(string.rep("ø", 31)) ~= nil, "31 UTF-8 letters are accepted rather than limited to 31 bytes")
check(not Note(secret), "secret note is rejected")
preview = assert(Note("Combat guard")); local readsBefore = reads; combat = true
check(not module:ApplyGuildAction(preview) and reads == readsBefore and #writes == count, "combat rejects approval before roster/rank reads or protected write")
combat = false
check(not module:ApplyGuildAction(preview), "combat failure consumes approval rather than queueing a later write")
preview = assert(Note("Wrong guild")); guildName = "Other Guild"
check(not module:ApplyGuildAction(preview) and #writes == count, "guild switch invalidates approval")
guildName = "Test Guild"
preview = assert(Note("Wrong actor")); actor = "Player-NewActor"
check(not module:ApplyGuildAction(preview), "actor change invalidates approval")
actor = "Player-Self"
preview = assert(Note("Replaced character")); target[17] = "Player-Replacement"
check(not module:ApplyGuildAction(preview) and #writes == count, "same name with different GUID cannot receive old approval")
target[17] = "Player-Target"
base = Base(); local rank = assert(module:PrepareGuildAction("rank", base, 3))
check(#writes == count, "rank preview is read only")
check(module:ApplyGuildAction(rank) and writes[#writes].kind == "rank" and writes[#writes].value == 3, "explicit permitted rank request uses native 1-based rank order")
orders["Player-Target"], target[2] = 3, "Veteran"; module:OnEvent("GUILD_ROSTER_UPDATE")
check(not module.pendingGuildAction, "rank observed only after updated native rank order")
base = Base(); rank = assert(module:PrepareGuildAction("rank", base, 4)); actorRank = 3
count = #writes
check(not module:ApplyGuildAction(rank) and #writes == count, "actor-rank change invalidates rank approval")
actorRank = 2
base = Base(); rank = assert(module:PrepareGuildAction("rank", base, 4)); names[4] = "Renamed rank"
check(not module:ApplyGuildAction(rank), "rank rename/reorder invalidates previewed destination")
names[4] = "Member"
base = Base(); rank = assert(module:PrepareGuildAction("rank", base, 4)); assignment = false
check(not module:ApplyGuildAction(rank), "native assignment restriction rechecked at approval")
assignment, demote = true, false
check(#Base().choices == 0, "demotion permission required for lower ranks")
demote = true; orders["Player-Target"] = 4; target[2] = "Member"; promote = false
check(#Base().choices == 1 and Base().choices[1].order == 5, "promotion permission required for higher ranks")
promote = true; actorRank = 4
check(#Base().choices == 0, "same/higher ranked targets cannot be edited through rank action")
actorRank = 2; editNote, assignment = secret, secret
check(not Base().canNote and #Base().choices == 0, "secret permission/assignment values fail closed")
editNote, assignment = true, true
target[2] = secret
check(#Base().choices == 0, "unreadable current rank cannot produce a blind rank change")
target[2] = "Member"; actor = ""
check(not module:GetGuildActionState(key), "empty actor GUID blocks guild actions")
actor = "Player-Self"; guildName = ""
check(not module:GetGuildActionState(key), "unknown guild name blocks guild actions")
guildName = "Test Guild"
preview = assert(Note("Pending guild switch")); module:ApplyGuildAction(preview)
combat, inGuild = true, false; module:OnEvent("PLAYER_GUILD_UPDATE")
check(not module.pendingGuildAction and #writes == count+1, "leaving guild in combat cancels observation without extra write")
combat, inGuild = false, true
print("Guild actions: " .. checks .. " checks passed")

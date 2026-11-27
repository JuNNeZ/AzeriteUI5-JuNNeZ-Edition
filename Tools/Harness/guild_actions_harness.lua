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
    SetNote = function() error("addon may not write guild notes") end,
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
local draft = assert(Note("Changed public"))
check(draft.after == "Changed public" and #writes == 0, "draft preparation never calls a write")
roster[1], roster[2] = roster[2], roster[1]
check(Note("Changed public").guid == "Player-Target", "roster reorder still identifies the original character")
check(not module:ApplyGuildAction(draft) and #writes == 0 and not module.pendingGuildAction and #timers == 0,
    "a note draft cannot be submitted as a guild action")
base = Base(); target[7] = "Changed before copying"
check(not module:PrepareGuildAction("note", base, "New"), "stale editor rejects copying over a newer note")
base = Base(); editNote = false
check(not module:PrepareGuildAction("note", base, "No permission"), "permission loss prevents preparing a draft")
check(not Base().canNote, "ordinary member cannot edit somebody else's public note")
local ownState = assert(module:GetGuildActionState(module:CharacterKey("Officer")))
check(ownState.canNote and #ownState.choices == 0, "self-public-note exception matches native UI and never permits own rank change")
editNote = true
check(not Note(string.rep("x", 32)) and not Note("bad|markup") and not Note("line\nbreak"), "public note length and plain-text validation")
check(Note(string.rep("ø", 31)) ~= nil, "31 UTF-8 letters are accepted rather than limited to 31 bytes")
check(Note("").after == "", "empty draft supports clearing the public note in Blizzard's roster")
check(not Note(secret), "secret note is rejected")
base = Base(); local readsBefore = reads; combat = true
check(not module:PrepareGuildAction("note", base, "Combat guard") and reads == readsBefore, "combat rejects draft before roster reads")
combat = false
guildName = "Other Guild"
check(not module:PrepareGuildAction("note", base, "Wrong guild"), "guild switch invalidates draft")
guildName = "Test Guild"
actor = "Player-NewActor"
check(not module:PrepareGuildAction("note", base, "Wrong actor"), "actor change invalidates draft")
actor = "Player-Self"
target[17] = "Player-Replacement"
check(not module:PrepareGuildAction("note", base, "Replaced character"), "same name with different GUID cannot receive old draft")
target[17] = "Player-Target"
local count = #writes
base = Base(); local rank = assert(module:PrepareGuildAction("rank", base, 3))
check(#writes == count, "rank preview is read only")
check(module:ApplyGuildAction(rank) and writes[#writes].kind == "rank" and writes[#writes].value == 3, "explicit permitted rank request uses native 1-based rank order")
check(not module:ApplyGuildAction(rank) and #writes == count+1, "rank confirmation is single-use")
check(not module:PrepareGuildAction("rank", base, 5), "a second rank request waits for the first")
module:ObserveGuildAction()
check(module.pendingGuildAction == rank, "unchanged roster does not acknowledge the request")
orders["Player-Target"], target[2] = 3, "Veteran"; module:OnEvent("GUILD_ROSTER_UPDATE")
check(not module.pendingGuildAction, "rank observed only after updated native rank order")
local nextRank = assert(module:PrepareGuildAction("rank", Base(), 4))
check(module:ApplyGuildAction(nextRank), "second rank request can follow observation of the first")
timers[1](); check(module.pendingGuildAction == nextRank, "old timer cannot clear a newer request")
count = #writes; timers[2]()
check(not module.pendingGuildAction and #writes == count, "timeout releases a rank request without resending")
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
rank = assert(module:PrepareGuildAction("rank", Base(), 3))
check(module:ApplyGuildAction(rank) and module.pendingGuildAction, "rank request awaits observation")
combat, inGuild = true, false; module:OnEvent("PLAYER_GUILD_UPDATE")
check(not module.pendingGuildAction and #writes == count+1, "leaving guild in combat cancels observation without extra write")
combat, inGuild = false, true
print("Guild actions: " .. checks .. " checks passed")

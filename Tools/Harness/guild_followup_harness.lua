-- Standalone local follow-up contracts; never operates a WoW client.
local root = arg[1] or "."
dofile(root .. "/Libs/LibStub/LibStub.lua")
dofile(root .. "/Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
local serializer = LibStub("AceSerializer-3.0")
local checks, inGuild = 0, true
local function check(value, label) checks = checks+1; assert(value, label) end
local secret = {}
issecretvalue = function(value) return value == secret end
GetNormalizedRealmName = function() return "TestRealm" end
IsInGuild = function() return inGuild end
time = function() return 1794744000 end
date = function() return "2026-11-15" end
LibStub = function(name)
    if name == "AceSerializer-3.0" then return serializer end
    return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
local module = { DisableSettingsExport = function() end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults)
        return { profile = defaults.profile, global = defaults.global, RegisterCallback = function() end }
    end } }
for _, file in ipairs({ "GuildManager", "GuildManagerData", "GuildManagerHistory", "GuildManagerFollowUp" }) do
    assert(loadfile(root .. "/Components/Misc/" .. file .. ".lua"))("Test", ns)
end
module:OnInitialize()
module.guildDetails = { name = "Guild One" }
module.members = { ["main person-testrealm"] = { name = "Main Person-TestRealm", online = true },
    ["alt person-testrealm"] = { name = "Alt Person-TestRealm", online = false } }
module:SaveIdentity("Main Person", "Jonas", "")
module:SaveIdentity("Alt Person", "", "Main Person")
local personKey, personName = "main person-testrealm", "Main Person"
local function Context() local store, key = module:GetFollowUpStore(); return key, store and store.revision or 0 end
local function Values()
    return { trialStart = "2026-11-01", trialEnd = "2026-11-15", absenceStart = "2026-11-10",
        absenceEnd = "2026-11-14", absenceNote = "LOCAL_FOLLOWUP_ONLY_42" }
end
local function Save(values) local key, rev = Context(); return module:SaveFollowUpSchedule(personKey, personName, values or Values(), key, rev) end
local function Task(title, owner, due, id)
    local key, rev = Context(); return module:SaveFollowUpTask(personKey, personName, title, owner or "", due or "", key, rev, id)
end
check(module:IsFollowUpDate("2000-02-29") and module:IsFollowUpDate("2028-02-29"), "Gregorian leap dates accepted")
check(not module:IsFollowUpDate("2100-02-29") and not module:IsFollowUpDate("2026-02-29"), "non-leap February rejected")
for _, value in ipairs({ "2026-04-31", "2026-13-01", "2026-00-00", "26-11-15", "2026-1-01", "2199-12-32", secret }) do
    check(not module:IsFollowUpDate(value), "invalid or unreadable date rejected")
end
check(#module:GetFollowUpItems("", "all") == 1, "one real person for linked main and alt")
check(Save(), "trial and absence saved atomically")
local store, guildKey = module:GetFollowUpStore()
check(module:GetFollowUpPerson(select(2, module:Resolve("Alt Person"))) == store.people[personKey], "linked alts share main's follow-up")
local items, attention = module:GetFollowUpItems("", "attention")
check(#items == 2 and attention == 2, "trial review day and ended absence require attention")
check(module:GetFollowUpItems("42", "absence")[1].kind == "absence", "local absence note searchable")
local planned = Values()
planned.trialStart, planned.trialEnd, planned.absenceStart, planned.absenceEnd = "2026-11-16", "2026-11-30", "2026-11-15", "2026-11-15"
check(Save(planned), "planned trial and single-day absence accepted")
check(#module:GetFollowUpItems("", "attention") == 0 and module:GetFollowUpItems("", "trials")[1].status == "Planned trial", "future review is not overdue")
check(module:GetFollowUpItems("", "absence")[1].status == "Away", "absence end is inclusive and online status does not clear it")
Save()
local invalid = Values(); invalid.trialEnd = "2026-10-31"
local old = store.people[personKey]
check(not Save(invalid) and store.people[personKey] == old, "reversed period rejected without partial writes")
invalid = Values(); invalid.absenceEnd = ""
check(not Save(invalid), "incomplete period rejected")
invalid = Values(); invalid.absenceNote = "|cunsafe"
check(not Save(invalid), "absence markup rejected")
check(Task("Check trial performance", "Officer Steve", "2026-11-15"), "task added with owner and deadline")
local validRevision = store.revision
check(not Task("", "", "") and not Task("|cunsafe", "", ""), "blank and markup task titles rejected")
check(not Task("Invalid due", "", "2026-02-29") and not Task("Invalid owner", string.rep("x", 81), ""), "task deadline and owner validated")
check(not Task(secret, "", "") and store.revision == validRevision, "secret task title fails without mutation")
local id = store.people[personKey].tasks[1].id
check(#module:GetFollowUpItems("steve", "tasks") == 1, "owner searchable")
check(Task("Updated task", "Officer Steve", "2026-11-16", id), "existing task can be edited")
check(store.people[personKey].tasks[1].id == id and #store.people[personKey].tasks == 1, "task editing preserves identity without duplication")
check(Task("Task due", "", "2026-11-15"), "second task due today")
items, attention = module:GetFollowUpItems("", "attention")
check(#items == 3 and attention == 3, "today's deadline requires attention")
local dueId = store.people[personKey].tasks[2].id
local _, rev = Context()
check(module:ChangeFollowUpTask(personKey, dueId, false, guildKey, rev), "task completed")
check(store.people[personKey].tasks[2].completed == "2026-11-15", "completion date retained")
check(#module:GetFollowUpItems("Task due", "active") == 0 and #module:GetFollowUpItems("Task due", "all") == 1, "completed tasks hidden from active but retained in all")
check(module:UndoFollowUp() and not store.people[personKey].tasks[2].done, "undo restores task state")
check(module:UndoFollowUp() and #store.people[personKey].tasks == 1, "consecutive undo restores preceding edit")
local nextId = store.nextTaskId
check(Task("Replacement", "", "") and store.people[personKey].tasks[2].id > nextId, "task ids never reused after undo")
local staleRevision = store.revision
check(Task("Another task", "", ""), "another mutation increments revision")
check(not module:SaveFollowUpSchedule(personKey, personName, Values(), guildKey, staleRevision), "stale editor rejected")
module.guildDetails.name = "Guild Two"
check(not module:SaveFollowUpSchedule(personKey, personName, Values(), guildKey, store.revision), "guild switch rejects stale submission")
check(not module:GetFollowUpPerson(personKey), "guild data isolated")
inGuild = false
check(#module:GetFollowUpItems("", "all") == 0 and not Save(), "out-of-guild edits rejected")
inGuild = true; module.guildDetails.name = "Guild One"
check(module:GetFollowUpStore() == store, "returning guild retains schedules and tasks")
local backup = module:ExportIdentities(true)
check(not backup:find("LOCAL_FOLLOWUP", 1, true) and not backup:find("Replacement", 1, true), "follow-up data excluded even from private identity backup")
local ok, restored = serializer:Deserialize(serializer:Serialize(module.db.global.followUps))
check(ok and restored[guildKey].people[personKey].absenceNote == "LOCAL_FOLLOWUP_ONLY_42", "persistent data round trips as ordinary SavedVariables-compatible records")
module.db.global.followUps = restored; store = module:GetFollowUpStore()
check(store.people[personKey].tasks[1].title == "Updated task", "saved task contents preserved")
module:SaveIdentity("Main Person", "", "Other Main")
check(not module:GetFollowUpPerson("other main-testrealm") and module:GetFollowUpPerson(personKey), "relink never silently overwrites destination follow-up")
check(#module:GetFollowUpItems("Updated task", "all") == 1, "original main's saved follow-up remains discoverable after relink")
for i = #store.people[personKey].tasks+1, 20 do check(Task("Task " .. i, "", ""), "bounded task added") end
check(not Task("Excess", "", ""), "twenty-task limit enforced")
local key, revision = Context()
check(module:ChangeFollowUpTask(personKey, store.people[personKey].tasks[1].id, true, key, revision), "task removal available to free capacity")
check(module:UndoFollowUp() and #store.people[personKey].tasks == 20, "removal is undoable")
local blanks = { trialStart = "", trialEnd = "", absenceStart = "", absenceEnd = "", absenceNote = "" }
check(Save(blanks) and not store.people[personKey].trialStart and #store.people[personKey].tasks == 20, "clearing periods preserves tasks")
local remaining = 0; for _ in pairs(module.followUpUndo[guildKey]) do remaining = remaining+1 end
check(remaining <= 20, "session undo bounded")
local transientKey = "temporary-testrealm"
local tempGuild, tempRevision = Context()
check(module:SaveFollowUpTask(transientKey, "Temporary", "Transient task", "", "", tempGuild, tempRevision), "temporary follow-up created")
local transientId = store.people[transientKey].tasks[1].id
check(module:ChangeFollowUpTask(transientKey, transientId, true, tempGuild, store.revision) and not store.people[transientKey], "removing last item frees empty person record")
check(module:UndoFollowUp() and store.people[transientKey].tasks[1].id == transientId, "empty-record cleanup remains undoable")
check(module:UndoFollowUp() and not store.people[transientKey], "undo can remove restored original creation")
for i = 1, 9 do module.guildDetails.name = "Guild " .. i; check(Save(), "additional local guild saved") end
module.guildDetails.name = "Guild beyond limit"
check(not Save(), "guild limit rejects new data without evicting existing tasks")
module.guildDetails.name = "Guild One"
check(module:GetFollowUpStore() == store, "original guild retained at storage limit")
for i = 1, 499 do store.people["fixture" .. i .. "-testrealm"] = { name = "Fixture" .. i, tasks = {} } end
local currentKey, currentRevision = Context()
check(not module:SaveFollowUpSchedule("new person-testrealm", "New Person", Values(), currentKey, currentRevision), "person storage limit enforced before mutation")
check(not module:CommitFollowUp(nil, { tasks = {} }, currentKey, currentRevision), "missing person key fails closed")
print("Guild follow-up: " .. checks .. " checks passed")

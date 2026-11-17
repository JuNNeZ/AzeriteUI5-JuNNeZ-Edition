-- Offline observed-history contracts. No WoW client or live roster used.
local root = arg[1] or "."
local checks, now, inGuild, guildName = 0, 1794744000, true, "Test Guild"
local function check(value, label) checks = checks+1; assert(value, label) end
local secret = {}
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return false end
time = function() return now end
IsInGuild = function() return inGuild end
GetGuildInfo = function() return guildName end
GetNormalizedRealmName = function() return "TestRealm" end
local roster = { { "Main Person-TestRealm", "Officer", 1, 60, "Mage", "City", "Public", "OFFICER SECRET", true } }
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) return unpack(roster[i]) end
local motd, info = "Raid Friday", "Welcome"
C_GuildInfo = { GetMOTD = function() return motd end, GetInfoText = function() return info end }
local module = { UI = {}, DisableSettingsExport = function() end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults)
        return { global = defaults.global, profile = defaults.profile, RegisterCallback = function() end }
    end } }
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end } end
assert(loadfile(root .. "/Components/Misc/GuildManager.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerData.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerHistory.lua"))("Test", ns)
module:OnInitialize()
module:ReadGuildDetails()
check(not module:CaptureGuildHistory(true), "MOTD event cannot establish a roster baseline")
local function Capture() module:ReadRoster(); module:CaptureGuildHistory() end
Capture()
local state, firstGuildKey = module:GetGuildHistory()
check(state.baseline and #state.events == 0, "first roster is a silent baseline, not a join event")
check(not state.members["main person-testrealm"].officerNote, "officer notes are never stored")
now = now+3600; roster[1][2], roster[1][4], roster[1][7] = "Member", 61, "Public revised"
Capture()
check(#state.events == 3 and state.events[1].at == now, "rank, level and public note changes use observation time")
check(#module:GetHistoryEntries("revised", false) == 1, "history search includes changed values")
Capture(); check(#state.events == 3, "identical repeated roster does not duplicate events")
local savedNote = roster[1][7]
roster[1][2], roster[1][4], roster[1][7] = secret, secret, secret
Capture(); check(#state.events == 3 and state.members["main person-testrealm"].note == savedNote, "unreadable fields never erase a snapshot or create changes")
roster[1][2], roster[1][4], roster[1][7] = "Member", 61, savedNote
roster[2] = { "Alt Person-TestRealm", "Member", 2, 40, "Warrior", "City", "Alt" }
Capture()
check(state.events[#state.events].kind == "firstSeen", "later new character is labelled first observed, not joined")
roster[2] = nil; Capture()
check(#state.events == 4 and state.members["alt person-testrealm"], "partial/missing roster does not infer departures")
roster = {}; Capture()
check(#state.events == 4 and state.baseline, "empty roster never resets baseline")
roster = { { "Main Person-TestRealm", "Member", 1, 61, "Mage", "City", "" } }
Capture()
check(state.events[#state.events].kind == "note" and state.events[#state.events].after == "", "readable empty public note records deliberate clearing")
motd, info = "Raid Saturday", "Welcome again"; module:OnEvent("GUILD_MOTD")
check(#state.events == 7, "MOTD and information changes recorded")
roster[1][7] = "not yet a fresh roster"
module.members["main person-testrealm"].observed.note = "stale cached note"
module:OnEvent("GUILD_MOTD")
check(#state.events == 7, "metadata event does not replay stale cached member fields")
roster[1][7] = ""; module:ReadRoster()
local oldInfo = info; motd, info = secret, secret; Capture()
check(#state.events == 7 and state.details.info == oldInfo, "secret guild information preserves prior known values")
motd, info = "Raid Saturday", oldInfo
local entries, unread = module:GetHistoryEntries("", true)
check(#entries == 7 and unread == 7, "unread changes include all unreviewed observations")
module:MarkHistoryReviewed()
check(#module:GetHistoryEntries("", true) == 0 and state.reviewed == state.sequence, "review marker persists in guild data")
roster[1][4] = 62; Capture()
entries, unread = module:GetHistoryEntries("", true)
check(#entries == 1 and unread == 1 and entries[1].kind == "level", "new changes remain unread after review")
guildName = "Other Guild"; Capture()
local other = module:GetGuildHistory()
check(other ~= state and #other.events == 0, "each guild has an independent baseline")
inGuild = false; module:ReadRoster()
check(not module:GetGuildHistory() and #module:GetHistoryEntries("", false) == 0, "leaving guild does not expose previous guild history")
inGuild, guildName = true, "Test Guild"; Capture()
check(module:GetGuildHistory() == state, "returning to guild retains its history")
for i = 1, 505 do roster[1][7] = "note " .. i; Capture() end
check(#state.events == 500 and state.sequence > 500, "history retention bounded with monotonic review sequence")
check(state.events[1].sequence < state.events[#state.events].sequence, "newest retained observations preserve order")
for i = 1, 6 do now = now+1; guildName = "Guild " .. i; Capture() end
local count = 0; for _ in pairs(module.db.global.guildHistory) do count = count+1 end
check(count == 5 and not module.db.global.guildHistory[firstGuildKey], "at most five most recently observed guilds retained")
print("Guild history: " .. checks .. " checks passed")

-- Reproduce the supplied Forever GetMOTD combat restriction with failing stubs.
-- Checks our deferral; does not emulate Blizzard security or operate the client.
local root = arg[1] or "."
local checks, combat, inGuild, calls = 0, false, true, 0
local guildName, motd, info = "Test Guild", "Old MOTD", "Old information"
local function check(value, label) checks = checks+1; assert(value, label) end
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
IsInGuild = function() return inGuild end
GetGuildInfo = function() return guildName end
GetNormalizedRealmName = function() return "TestRealm" end
GetNumGuildMembers = function() return 1 end
GetGuildRosterInfo = function() return "Main Person", "Officer", 1, 60, "Mage", "City", "Public", "PRIVATE", true end
time = function() return 1794744000 end
C_GuildInfo = { GuildRoster = function() end,
    GetMOTD = function() assert(not combat, "blocked GetMOTD in combat"); calls = calls+1; return motd end,
    GetInfoText = function() assert(not combat, "blocked GetInfoText in combat"); calls = calls+1; return info end }
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end } end
local module = { UI = {}, DisableSettingsExport = function() end }
local ns = { NewModule = function() return module end, GetModule = function() return module end,
    db = { RegisterNamespace = function(_, _, defaults)
        return { global = defaults.global, profile = defaults.profile, RegisterCallback = function() end }
    end } }
for _, file in ipairs({ "GuildManager", "GuildManagerData", "GuildManagerHistory" }) do
    assert(loadfile(root .. "/Components/Misc/" .. file .. ".lua"))("Test", ns)
end
module:OnInitialize()
module:OnEvent("GUILD_ROSTER_UPDATE")
check(calls == 2 and module.guildDetails.motd == "Old MOTD", "out-of-combat metadata read")
local state = module:GetGuildHistory()
combat, motd, info = true, "New MOTD", "New information"
module:OnEvent("GUILD_ROSTER_UPDATE")
check(calls == 2 and module.guildDetailsPending, "combat roster event queues metadata without restricted calls")
check(module.guildDetails.motd == "Old MOTD" and module.members["main person-testrealm"], "known same-guild text and ordinary roster remain available")
module:OnEvent("GUILD_MOTD")
module:RequestRoster()
check(calls == 2 and #state.events == 0, "combat MOTD and manual refresh neither call getters nor fabricate metadata changes")
combat = false
module:OnEvent("PLAYER_REGEN_ENABLED")
check(calls == 4 and not module.guildDetailsPending and module.guildDetails.motd == motd and module.guildDetails.info == info, "combat end replays pending metadata once")
check(#state.events == 2, "history observes actual deferred metadata changes")
module:OnEvent("PLAYER_REGEN_ENABLED")
check(calls == 4 and #state.events == 2, "unrelated combat-end events do not duplicate refresh or history")
combat, guildName = true, "Other Guild"
module:OnEvent("PLAYER_GUILD_UPDATE")
check(module.guildDetails.name == "Other Guild" and not module.guildDetails.motd and calls == 4, "combat guild switch cannot expose old guild text")
combat = false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(calls == 6 and module.guildDetails.motd == motd and not module:GetGuildHistory(), "new guild metadata refresh does not invent a roster baseline")
module:OnEvent("GUILD_ROSTER_UPDATE")
check(module:GetGuildHistory().baseline, "new guild baseline still waits for server roster")
combat, inGuild = true, false; module:OnEvent("PLAYER_GUILD_UPDATE")
check(not next(module.guildDetails) and not module.guildDetailsPending, "leaving guild clears metadata and pending queue in combat")
combat = false; local previous = calls; module:OnEvent("PLAYER_REGEN_ENABLED")
check(calls == previous, "no metadata replay after leaving guild")

-- Forever Live Update 2 returns blank realm names and can send bare roster names.
ns.IsForever, inGuild, guildName = true, true, "Test Guild"
check(module:SaveIdentity("Main Person", "Saved main", ""), "save a nickname with the old realm")
UnitName = function() return "Main Person" end
local loggedIn = false
IsLoggedIn = function() return loggedIn end
GetRealmName = function() return "" end
GetNormalizedRealmName = GetRealmName
module.realm, module.realmAliases = nil, nil
module:RefreshRealm()
check(not module:CharacterKey("Main Person"), "waits for login before choosing a fallback realm")
loggedIn = true
module:RequestRoster()
check(module.realm == "TestRealm" and module.members["main person-testrealm"], "blank realms reuse the saved guild scope for a known player")
check(module:GetGuildHistory() == state, "realm fallback keeps existing history and character keys")
check(module:Resolve("Main Person") == "Saved main", "bare names resolve nicknames saved before the update")

module.realm, module.realmAliases = "Forever", { forever = true }
check(module:SaveIdentity("Main Person", "Current main", ""), "save the post-update identity under the local scope")
module:RequestRoster()
local rows = module:GetRows("", true)
check(#rows == 1 and rows[1].key == "main person-forever" and rows[1].nickname == "Current main",
    "the live member is listed once when both pre-layer and post-layer identities exist")
local proposals = module:BuildNoteSuggestions()
check(module:ApplyNoteSuggestions(proposals, { public = true }), "a bare pre-layer record cannot invalidate the current note scan")
check(module.db.global.characters["main person-testrealm"].nickname == "Saved main"
    and #module:GetRows("", true) == 1, "the scan retains the old nickname and the qualified historical record stays out of the roster")
check(module:SaveIdentity("Main Person-UnrelatedRealm", "Independent character", ""), "save a distinct explicitly qualified character")
check(#module:GetRows("", true) == 2, "an unrelated explicit same-name identity stays visible")

-- Merging the old realm record into the live character (Backup page, Forever).
local function records() return module.db.global.characters end
check(module:SaveIdentity("Alt Two-TestRealm", "", "Main Person-TestRealm"), "an alt linked to the old-realm main")
records()["main person-testrealm"].privateNote = "Old note"
local liveNickname = records()["main person-forever"].nickname
local duplicates = module:FindRealmDuplicates()
check(duplicates["main person-testrealm"] and duplicates["main person-testrealm"].current == "main person-forever"
    and duplicates["main person-testrealm"].hidden and not duplicates["main person-unrelatedrealm"]
    and not duplicates["alt two-testrealm"], "only the provable old-realm record is a duplicate")
local merged, count, conflicts = module:BuildRealmMerge()
check(count == 1 and conflicts == 1 and not merged["main person-testrealm"]
    and liveNickname and merged["main person-forever"].nickname == liveNickname and merged["main person-forever"].privateNote == "Old note"
    and merged["alt two-testrealm"].main == "main person-forever" and merged["main person-unrelatedrealm"],
    "the live value wins, the old record fills gaps and links follow it")
check(records()["main person-testrealm"], "building the preview changes nothing")
local revision = module.identityRevision or 0
check(not module:MergeRealmDuplicates(revision+1), "a stale preview is refused")
check(module:MergeRealmDuplicates(revision) and not records()["main person-testrealm"]
    and module:Resolve("Alt Two-TestRealm") == liveNickname and not next(module:FindRealmDuplicates()),
    "the merge commits once and leaves nothing to merge")
check(module:UndoIdentity() and records()["main person-testrealm"].nickname == "Saved main", "one undo restores the old record")
ns.IsForever = false
check(not next(module:FindRealmDuplicates()), "Retail never reports realm duplicates, even for the same saved data")
ns.IsForever = true
module:ForgetIdentity("Main Person")
merged, count, conflicts = module:BuildRealmMerge()
check(count == 1 and conflicts == 0 and merged["main person-forever"].nickname == "Saved main"
    and merged["main person-forever"].name == "Main Person", "without a live record the old identity moves to the live character")
check(#module:GetRows("", true) == 4, "an unmerged old record without a live identity stays visible")
check(module:UndoIdentity() and records()["main person-forever"].nickname == liveNickname, "undo the removal")
module:ForgetIdentity("Alt Two-TestRealm"); records()["main person-testrealm"].privateNote = nil

module.realm, module.realmAliases = nil, nil
module.db.global.guildHistory["OtherRealm:test guild"] = { members = { ["main person-otherrealm"] = {} } }
module:RequestRoster()
check(module.members["main person-forever"] and not module.members["main person-testrealm"], "ambiguous history uses a local scope instead of choosing a realm")
check(module:CharacterKey("Main Person-OtherRealm") == "main person-otherrealm", "explicit other-realm identities stay distinct")

module.realm, module.realmAliases = nil, nil
module.db.global.guildHistory, module.db.global.characters = {}, {}
module:RequestRoster()
check(module.members["main person-forever"], "a fresh Forever installation reads a bare roster without realm APIs")
check(module:SaveIdentity("Main Person", "Jonas", "") and module:Resolve("Main Person") == "Jonas", "local nickname saves and resolves for a bare Forever name")
check(module:ValidateRecords(module.db.global.characters), "realm fallback identities pass backup validation")

module.realm, module.realmAliases, ns.IsForever = nil, nil, false
module:RequestRoster()
check(not module:CharacterKey("Main Person") and not next(module.members), "blank realm does not collapse identities on Retail")
print("Guild combat: " .. checks .. " checks passed")

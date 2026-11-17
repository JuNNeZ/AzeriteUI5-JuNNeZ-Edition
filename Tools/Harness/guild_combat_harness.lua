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
print("Guild combat: " .. checks .. " checks passed")

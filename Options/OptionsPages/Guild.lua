-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Options = ns:GetModule("Options")
local function GenerateOptions()
    local module = ns:GetModule("GuildManager", true)
    if (not module or not module.db) then return end
    local options = {
        name = L["Guild & Nicknames"], type = "group",
        args = {
            help = { name = L["Local nicknames and main/alt links. Guild actions require permission and confirmation. Open with /azguild."], type = "description", order = 1 },
            open = { name = L["Open guild overview"], type = "execute", order = 2,
                func = function() module:ToggleWindow() end },
            chatNicknames = { name = L["Chat nicknames"], type = "toggle", width = "full", order = 3,
                desc = L["Replace the displayed sender name in Chattynator. Character links retain their real destination. Protected messages keep their original names."],
                get = function() return module.db.profile.chatNicknames end,
                set = function(_, value) module.db.profile.chatNicknames = value; module:UpdateSettings() end },
            nicknameLevels = { name = L["Show levels with nicknames"], type = "toggle", width = "full", order = 3.5,
                desc = L["Show the speaking character's known message-time level before their nickname, for example 60:Nickname. Unknown levels are omitted. Original-name channels keep Chattynator's own setting."],
                disabled = function() return not module.db.profile.chatNicknames end,
                get = function() return module.db.profile.nicknameLevels == true end,
                set = function(_, value) module.db.profile.nicknameLevels = value; module:UpdateSettings() end }
        }
    }
    local formats = { nickname = L["Nickname only"], both = L["Nickname (character)"], original = L["Original character name"] }
    for index, entry in ipairs({ { "guildFormat", L["Guild and officer chat"] }, { "groupFormat", L["Party and raid chat"] },
        { "whisperFormat", L["Whispers"] }, { "otherFormat", L["Other chat channels"] } }) do
        local key = entry[1]
        options.args[key] = { name = entry[2], type = "select", order = index+3, width = "full",
            values = formats, sorting = { "nickname", "both", "original" },
            get = function() return module.db.profile[key] or "nickname" end,
            set = function(_, value)
                if (not formats[value]) then return end
                module.db.profile[key] = value; module:UpdateSettings()
            end }
    end
    return options
end
Options:AddGroup("GuildManager", GenerateOptions, -3900, "interface", "GuildManager")

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
                set = function(_, value) module.db.profile.nicknameLevels = value; module:UpdateSettings() end },
            keysHeader = { name = L["Keybindings"], type = "header", order = 20 },
            blizzardGuildKey = { name = L["Open with Blizzard's guild key"], type = "toggle", width = "full", order = 21,
                desc = L["The keys bound to Blizzard's Guild & Communities window (J by default) open the guild overview instead. Your key bindings are not changed, and Blizzard's window stays available from the micro menu. Turn this off to give the keys back."],
                get = function() return module.db.profile.blizzardGuildKey == true end,
                set = function(_, value) module.db.profile.blizzardGuildKey = value == true; module:UpdateBindings() end },
            toggleKey = { name = L["Guild overview key"], type = "keybinding", width = "full", order = 22,
                desc = L["A key of your own that opens and closes the guild overview. Click, then press a key; Escape clears it. While set, it takes priority over that key's normal binding. Changes made in combat apply after combat."],
                get = function() local key = module.db.profile.toggleKey; return type(key) == "string" and key or nil end,
                set = function(_, value)
                    module.db.profile.toggleKey = type(value) == "string" and value ~= "" and value or false
                    module:UpdateBindings()
                end }
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

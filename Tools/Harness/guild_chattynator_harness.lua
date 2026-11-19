-- Exercise the real installed Chattynator API wrapper without the game.
-- Arguments: repository root, Chattynator addon directory (read only).
local root, chatty = arg[1] or ".", assert(arg[2], "Chattynator directory required")
local checks, errors = 0, 0
local function check(value, label) checks = checks+1; assert(value, label) end
local secret = {}
issecretvalue = function(value) return value == secret end
CallErrorHandler = function(message) errors = errors+1; return message end
tIndexOf = function(values, target) for i, value in ipairs(values) do if value == target then return i end end end
local module = {}
local ns = { NewModule = function() return module end, GetModule = function() return module end }
assert(loadfile(root .. "/Components/Misc/GuildManager.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerData.lua"))("Test", ns)
module.realm = "TestRealm"
module.db = { profile = { enabled = true, chatNicknames = true }, global = { characters = {
    ["main person-testrealm"] = { name = "Main Person", nickname = "Jonas" }
} } }
local live = {}
local addon = { API = {}, Messages = {
    AddLiveModifier = function(_, callback) live[#live+1] = callback end,
    RemoveLiveModifier = function(_, callback) local index = tIndexOf(live, callback); if index then table.remove(live, index) end end
} }
assert(loadfile(chatty .. "/API/Main.lua"))("Chattynator", addon)
module:UpdateSettings()
check(#live == 1, "real public API installs one wrapper")
local data = { text = "[G] |Hplayer:Main Person:27:GUILD:|h[|cff69ccf0Main Person|r]|h: hello",
    typeInfo = { type = "GUILD", player = { name = "Main Person" } } }
live[1](data)
check(data.text:find("[|cff69ccf0Jonas|r]", 1, true), "real wrapper applies nickname to realm-less Forever surname link")
check(data.text:find("|Hplayer:Main Person:27:GUILD:", 1, true), "real wrapper preserves hyperlink destination")
check(module:GetChatDiagnostic():find("guildCallbacks=1; replacements=1", 1, true), "diagnostics expose guild callback and replacement counts without message contents")
for _, message in ipairs({ {}, { text = secret, typeInfo = { player = { name = "Main Person" } } },
    { text = "hello", typeInfo = { player = secret } }, { text = "hello", typeInfo = { player = 42 } } }) do live[1](message) end
check(errors == 0 and #live == 1, "unsupported metadata and protected text cannot make provider remove modifier")
live = {} -- Simulate loss of provider registration while Azerite retains its API marker.
module:OnEvent("PLAYER_ENTERING_WORLD", false, true)
check(#live == 1, "reload world-entry repairs lost real API registration")
module:UpdateSettings(); module:UpdateSettings()
check(#live == 1, "repeated reconnect does not duplicate real API wrappers")
module.db.profile.chatNicknames = false; module:UpdateSettings()
check(#live == 0, "disabling removes real API wrapper")

-- Load the provider's actual processed-message cache, tab-selection methods and
-- renderer. Font strings/pools below are offline widgets, not client objects.
ChatTypeGroup, ChatFrameUtil = {}, {}
addon.Display = {}
addon.CallbackRegistry = { RegisterCallback = function() end }
assert(loadfile(chatty .. "/Core/Messages.lua"))("Chattynator", addon)
assert(loadfile(chatty .. "/Display/Main.lua"))("Chattynator", addon)
assert(loadfile(chatty .. "/Display/ScrollingMessages.lua"))("Chattynator", addon)
assert(loadfile(chatty .. "/Display/Tabs.lua"))("Chattynator", addon)
CopyTable = function(source)
    local copy = {}; for key, value in pairs(source) do copy[key] = type(value) == "table" and CopyTable(value) or value end
    return copy
end
GetTime = function() return 100 end
date = os.date
addon.Data = { CharacterName = "Viewer-TestRealm" }
addon.Config = { Options = { SHOW_TIMESTAMP_SEPARATOR = "separator", MESSAGE_ALIGNMENT = "alignment",
    TIMESTAMP_ON_RIGHT = "right", MESSAGE_FADE_TIME = "fadeTime", ENABLE_MESSAGE_FADE = "fade" },
    Get = function(key) return ({ separator = false, alignment = "LEFT", right = false, fadeTime = 120, fade = false })[key] end }
local monitor = setmetatable({ messages = {}, messagesProcessed = {}, liveModifiers = {}, messageCount = 0,
    GetScript = function() return nil end }, { __index = addon.MessagesMonitorMixin })
addon.Messages = monitor
monitor.font, monitor.scalingFactor, monitor.spacing, monitor.inset, monitor.timestampFormat = {}, 1, 0, 0, "%H:%M"
local fontMethods = {}
for _, method in ipairs({ "SetFontObject", "SetTextColor", "SetJustifyH", "SetPoint", "SetTextScale", "SetNonSpaceWrap", "SetIndentedWordWrap", "Show", "SetShown" }) do
    fontMethods[method] = function() end
end
fontMethods.SetText = function(self, text) self.text = text end
fontMethods.GetLineHeight = function() return 15 end
fontMethods.SetAlpha = function(self, alpha) self.alpha = alpha end
fontMethods.GetAlpha = function(self) return self.alpha or 1 end
local pool = { Acquire = function() return setmetatable({}, { __index = fontMethods }) end,
    Release = function() end, ReleaseAll = function() end }
local scroll = setmetatable({ pool = pool, barPool = pool, visibleLines = {}, scrollIndex = 1,
    currentFadeOffsetTime = 0, accumulatedTime = 0, timestampOffset = 0, GetHeight = function() return 150 end },
    { __index = addon.Display.ScrollingMessagesMixin })
local frame = setmetatable({ ScrollingMessages = scroll, GetID = function() return 1 end }, { __index = addon.Display.ChatFrameMixin })
local function Raw(kind, metadata)
    return { text = "[" .. kind .. "] |Hplayer:Main Person:27:" .. kind .. ":|h[|cff69ccf027:Main Person|r]|h: hello",
        typeInfo = { type = kind, event = "CHAT_MSG_" .. kind, player = metadata }, recordedBy = addon.Data.CharacterName,
        color = { r = 1, g = 1, b = 1 }, timestamp = 1794744000 }
end
local secondSender = Raw("GUILD", { name = "Other Member" })
secondSender.text = secondSender.text:gsub("Main Person", "Other Member"):gsub("hello$", "second guild message")
monitor.messages = { Raw("SAY", { name = "Main Person" }), Raw("GUILD", { name = "Shortened metadata" }), secondSender }
monitor.messageCount = #monitor.messages
local original = monitor.messages[2].text
module.db.profile.chatNicknames = true; module:UpdateSettings()
local tabs = {
    { invert = true, groups = {}, channels = {}, whispersTemp = {}, filters = {} },
    { groups = { GUILD = true }, channels = {}, whispersTemp = {}, filters = {} }
}
local function Tab(index, ...)
    local expected = { ... }
    local filter = addon.Display.TabsBarMixin:GetFilter(tabs[index], "1_" .. index)
    frame:SetTabSelectedAndFilter(index, filter)
    scroll:Render()
    check(#scroll.visibleLines == #expected, "actual tab renderer shows every matching message")
    for _, snippet in ipairs(expected) do
        local found = false
        for _, line in ipairs(scroll.visibleLines) do
            if line.text:find(snippet, 1, true) then found = true; break end
        end
        check(found, "actual tab renderer shows " .. snippet)
    end
end
Tab(1, "[SAY]", "|cff69ccf0Jonas|r]|h: hello", "Other Member|r]|h: second guild message")
Tab(2, "|cff69ccf0Jonas|r]|h: hello", "Other Member|r]|h: second guild message")
Tab(1, "[SAY]", "|cff69ccf0Jonas|r]|h: hello", "Other Member|r]|h: second guild message")
check(monitor.messages[2].text == original, "tab rendering does not mutate raw messages")
module.db.profile.chatNicknames = false; module:UpdateSettings()
Tab(2, "Main Person|r]|h: hello", "Other Member|r]|h: second guild message")
Tab(1, "[SAY]", "Main Person|r]|h: hello", "Other Member|r]|h: second guild message")
check(monitor:GetMessageProcessed(2).text == original, "disabling nicknames restores the original cached guild message")
module.db.profile.chatNicknames = true; module:UpdateSettings()
Tab(2, "|cff69ccf0Jonas|r]|h: hello", "Other Member|r]|h: second guild message")
module.db.global.characters["other member-testrealm"] = { name = "Other Member", nickname = "Other Nickname" }
module:UpdateSettings()
Tab(1, "[SAY]", "|cff69ccf0Jonas|r]|h: hello", "Other Nickname|r]|h: second guild message")
Tab(2, "|cff69ccf0Jonas|r]|h: hello", "Other Nickname|r]|h: second guild message")
check(errors == 0 and #monitor.liveModifiers == 1, "cache rebuild and repeated tab selection keep provider wrapper installed")
monitor.messages = { Raw("GUILD", nil) }; monitor.messageCount = 1; monitor.messagesProcessed = {}
Tab(2, "|cff69ccf0Jonas|r]|h: hello")
check(scroll.visibleLines[1].text:find("Jonas", 1, true), "ordinary guild sender link works without historical player metadata")
local system = { text = "Notice: |Hplayer:Main Person|h[Main Person]|h", typeInfo = { type = "SYSTEM", event = "CHAT_MSG_SYSTEM" } }
local systemText = system.text; module:ModifyMessage(system)
check(system.text == systemText, "body-only system link is never inferred to be a sender")
system.typeInfo.player = { name = "Main Person" }; module:ModifyMessage(system)
check(system.text == systemText, "system body links remain untouched even when metadata identifies a known player")
local remote = Raw("GUILD", { name = "Main Person" })
remote.text = remote.text:gsub("|Hplayer:Main Person:", "|Hplayer:Main Person-OtherRealm:")
local remoteText = remote.text; module:ModifyMessage(remote)
check(remote.text == remoteText, "local nickname cannot override an unsaved sender on another realm")
local protected = Raw("GUILD", { name = secret }); local protectedText = protected.text; module:ModifyMessage(protected)
check(protected.text == protectedText, "secret sender metadata cannot be bypassed through readable link")
module.db.profile.guildFormat = "original"; module:UpdateSettings()
frame:SetTabSelectedAndFilter(2, function() return true end); scroll:Render()
check(not scroll.visibleLines[1].text:find("Jonas", 1, true), "original-name preference still honored after cache invalidation")
module.db.profile.guildFormat = "nickname"; module:UpdateSettings()
GetNormalizedRealmName = function() return "TestRealm" end
GetRealmName = function() return "Test Realm" end
module.realm, module.realmAliases = nil, nil
local late = Raw("GUILD", nil); module:ModifyMessage(late)
check(late.text:find("Jonas", 1, true) and module.realm == "TestRealm", "late realm availability recovers before resolving sender")
module.realm, module.realmAliases = nil, nil
GetNormalizedRealmName = function() return nil end; GetRealmName = function() return nil end
monitor.messagesProcessed = {}; frame:SetTabSelectedAndFilter(2, function() return true end); scroll:Render()
check(not scroll.visibleLines[1].text:find("Jonas", 1, true), "unavailable realm does not guess a different server identity")
GetNormalizedRealmName = function() return "TestRealm" end; GetRealmName = function() return "Test Realm" end
local readRoster, capture = module.ReadRoster, module.CaptureGuildHistory
module.ReadRoster, module.CaptureGuildHistory = function() end, function() end
module:OnEvent("GUILD_ROSTER_UPDATE")
module.ReadRoster, module.CaptureGuildHistory = readRoster, capture
scroll:Render()
check(scroll.visibleLines[1].text:find("Jonas", 1, true), "realm-ready roster event invalidates previously unrenamed provider cache")
GetNormalizedRealmName = function() return "InternalRealm" end
module:RefreshRealm()
check(module:CharacterKey("Main Person-InternalRealm") == "main person-testrealm", "known current-server realm alias preserves saved canonical identity")
check(module:CharacterKey("Main Person-OtherRealm") == "main person-otherrealm", "unrelated explicit realm remains distinct")
-- Actual native level modifier and cache, before the nickname modifier as at
-- world entry/our settings reconnect. No provider settings or source are edited.
addon.Modifiers = {}
addon.Constants = { IsMidnightNext = true, IsForever = chatty:find("_forever_", 1, true) ~= nil }
addon.Config.Options.SHOW_LEVEL = "show_level"
local nativeLevels, levelSettingChanged = false
local configGet = addon.Config.Get
addon.Config.Get = function(key) if key == "show_level" then return nativeLevels end; return configGet(key) end
addon.CallbackRegistry = { RegisterCallback = function(_, event, callback)
    if event == "SettingChanged" then levelSettingChanged = callback end
end }
assert(loadfile(chatty .. "/Modifiers/Level.lua"))("Chattynator", addon)
addon.Modifiers.InitializeLevels()
local function RenderLevel()
    local message = Raw("GUILD", { name = "Main Person", level = 42 })
    message.text = message.text:gsub("27:Main Person", "Main Person")
    monitor.messages, monitor.messageCount, monitor.messagesProcessed = { message }, 1, {}
    frame:SetTabSelectedAndFilter(2, function() return true end); scroll:Render()
    return scroll.visibleLines[1].text
end
module.db.profile.nicknameLevels = true; module:UpdateSettings()
check(RenderLevel():find("42:Jonas", 1, true), "actual cache displays nickname levels with native level setting off")
nativeLevels = true; levelSettingChanged(nil, "show_level")
module:UpdateSettings() -- The owned toggle/public reconnect runs ours last.
local nativeAndNickname = RenderLevel()
check(nativeAndNickname:find("42:Jonas", 1, true) and not nativeAndNickname:find("42:42:", 1, true), "real native Level.lua and nickname formatting produce one level")
module.db.profile.nicknameLevels = false; module:UpdateSettings()
check(not RenderLevel():find("42:", 1, true), "owned toggle off removes native level only on replaced nickname")
module.db.profile.guildFormat = "original"; module:UpdateSettings()
check(RenderLevel():find("42:Main Person", 1, true), "original-name channel still follows native Level.lua")
module.db.profile.guildFormat = "nickname"; module.db.profile.nicknameLevels = true
nativeLevels = false; levelSettingChanged(nil, "show_level"); module:UpdateSettings()
check(RenderLevel():find("42:Jonas", 1, true) and errors == 0, "native setting removal and own cache refresh preserve wrapper")
print("Guild Chattynator: " .. checks .. " checks passed")

-- Offline contract checks; no WoW client, rendering or taint claims.
-- lua Tools/Harness/guild_manager_harness.lua .
local root = arg[1] or "."
dofile(root .. "/Libs/LibStub/LibStub.lua")
dofile(root .. "/Libs/AceSerializer-3.0/AceSerializer-3.0.lua")
local serializer = LibStub("AceSerializer-3.0")
local checks = 0
local function check(value, label)
    checks = checks+1
    assert(value, label)
end
local secret = {}
issecretvalue = function(value) return value == secret end
GetNormalizedRealmName = function() return "TestRealm" end
IsInGuild = function() return true end
local combat = false
InCombatLockdown = function() return combat end
GetGuildInfo = function() return "Test Guild" end
local roster = {
    { "Main Person-TestRealm", "Officer", 1, 60, "Mage", "City", "Junnez - H/A", "private", true, 0, "MAGE" },
    { "Alt Person-TestRealm", "Member", 2, 40, "Warrior", "Forest", "Tim - S/L", "private", false, 0, "WARRIOR" },
    { secret }
}
roster[1][17], roster[2][17] = "Player-1-Main", "Player-1-Alt"
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) return unpack(roster[i], 1, 17) end
local lastOnline = { 0, 0, 2, 4 }
GetGuildRosterLastOnline = function() return unpack(lastOnline) end
local requests = 0
time = function() return 1794744000 end
date = os.date
C_GuildInfo = { GuildRoster = function() requests = requests+1 end,
    GetMOTD = function() return "Raid Friday at 20:00" end,
    GetInfoText = function() return "Welcome to the guild.\nBring consumables." end }
local module = { GetName = function() return "GuildManager" end,
    DisableSettingsExport = function(self) self.noExport = true end,
    RegisterChatCommand = function() end, RegisterEvent = function() end }
local ns = { NewModule = function() return module end, Prefix = "AzTest",
    GetModule = function() return module end, API = { GetMedia = function(name) return "Interface\\AddOns\\Test\\Assets\\" .. name .. ".tga" end },
    db = { RegisterNamespace = function(_, _, defaults)
        return { profile = defaults.profile, global = defaults.global, RegisterCallback = function() end }
    end } }
assert(loadfile(root .. "/Components/Misc/GuildManager.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerData.lua"))("Test", ns)
module:OnInitialize()
module:OnEnable()
check(module.noExport, "identities excluded from UI exports")
check(requests == 1, "roster requested")
check(module:CharacterKey("Alt Person-Test Realm") == "alt person-testrealm", "Forever surname preserved, realm normalized")
check(not module:CharacterKey(secret), "secret character skipped")
check(not module:CharacterKey("|Hplayer:fake|h"), "markup rejected as name")
check(#module:GetRows("", true) == 2, "readable roster only")
check(module.guildDetails.motd == "Raid Friday at 20:00", "MOTD read from Blizzard")
check(module.members["alt person-testrealm"].lastOnline.days == 2, "relative last-online retained")
lastOnline = { 0, 0, secret, 0 }
check(not module:ReadLastOnline(1), "secret last-online rejected before arithmetic")
lastOnline = { 0, 0, 0, -1 }
check(not module:ReadLastOnline(1), "invalid duration rejected")
lastOnline = { 0, 0, 2, 4 }
local getMOTD = C_GuildInfo.GetMOTD
C_GuildInfo.GetMOTD = function() return secret end; module:ReadGuildDetails()
check(not module.guildDetails.motd, "secret guild text hidden")
C_GuildInfo.GetMOTD = getMOTD; module:ReadGuildDetails()
check(#module:GetPeople("40-45", {}) == 1, "level range selects matching character")
check(#module:GetPeople("45-40", {}) == 0, "reversed level range matches nothing")
check(#module:GetRows("", false) == 1, "offline filtering")
check(#module:GetRows("Officer", true) == 1, "rank search")
check(#module:GetRows("Forest", true) == 1, "zone search")
check(#module:GetRows("S/L", true) == 1, "public note search")
check(#module:GetRows("private", true) == 0, "officer notes neither retained nor searched")
check(module:NoteCandidate("Tim - S/L") == "Tim", "suffix removed from suggestion")
check(module:NoteCandidate("Jador - H/A") == "Jador", "second screenshot example")
check(module:NoteCandidate("Junnez") == "Junnez", "plain note")
check(module:NoteCandidate("Nady (real) (fake)") == "Nady", "parenthetical note")
check(not module:NoteCandidate("?"), "unknown note ignored")
check(not module:NoteCandidate(secret), "secret note ignored")
check(not module:Resolve("Main Person"), "notes never imported automatically")
check(module:SaveIdentity("Main Person", "Jonas", ""), "nickname saved")
check(module:SaveIdentity("Alt Person", "", "Main Person"), "alt saved")
check(module:Resolve("Alt Person") == "Jonas", "alt inherits nickname")
check(#module:GetRows("Jonas", true) == 2, "nickname search groups main and alt")
check(not module:SaveIdentity("Main Person", "", "Alt Person"), "cycle rejected atomically")
check(module:Resolve("Main Person") == "Jonas", "rejected save retains main")
check(not module:SaveIdentity("Main Person", "|cff00ff00fake", ""), "nickname markup rejected")
check(not module:SaveIdentity("Main Person", "line\nbreak", ""), "control characters rejected")
check(not module:SaveIdentity("Main Person", string.rep("a", 49), ""), "nickname bound")
check(not module:SaveIdentity("Alt Person", "", "Alt Person"), "self-link rejected")
check(module:SaveIdentity("Other Alt", "", "Other Main"), "main outside guild supported")
check(module:Resolve("Other Alt") == "Other Main", "unaliased main uses full character name")

local function Message(name, label, body)
    return { text = "[G] |Hplayer:" .. name .. ":27:GUILD:|h[" .. label .. "]|h: " .. (body or "hello"),
        typeInfo = { player = { name = name } } }
end
local data = Message("Alt Person-TestRealm", "Alt Person-TestRealm")
local raw = data.text
module:ModifyMessage(data)
check(data.text == raw, "off by default")
local active, adds, removes = nil, 0, 0
Chattynator = { API = {
    AddModifier = function(func) active = func; adds = adds+1 end,
    RemoveModifier = function(func) check(func == active, "same callback removed"); active = nil; removes = removes+1 end
} }
module.db.profile.chatNicknames = true
module:UpdateSettings()
check(type(active) == "function", "public API registration")
active(data)
check(data.text == "[G] |Hplayer:Alt Person-TestRealm:27:GUILD:|h[Jonas]|h: hello", "whole label replaced, full click target retained")
check(module.db.profile.nicknameLevels == false, "nickname levels default off")
module.db.profile.nicknameLevels = true
local levelled = Message("Alt Person-TestRealm", "|cff00ff0040:Alt Person|r", "body 99 |Hplayer:Main Person|h[60:Main Person]|h")
levelled.typeInfo.player.level = 40
active(levelled)
check(levelled.text:find("|h[|cff00ff0040:Jonas|r]|h", 1, true), "level and class color retained exactly once on inherited nickname")
check(levelled.text:find("body 99 |Hplayer:Main Person|h[60:Main Person]|h", 1, true), "level toggle leaves body links untouched")
check(levelled.text:find("|Hplayer:Alt Person-TestRealm:27:GUILD:", 1, true), "level toggle retains speaking alt's link destination")
local function LevelMessage(value, label, metadata)
    local message = Message("Alt Person-TestRealm", label or "Alt Person")
    message.typeInfo.type = "GUILD"
    message.typeInfo.player = metadata or { name = "Alt Person-TestRealm", level = value }
    active(message); return message.text
end
check(LevelMessage(40):find("[40:Jonas]", 1, true), "metadata can add a level when Chattynator's level display is off")
check(LevelMessage(nil, "40:Alt Person", "Alt Person-TestRealm"):find("[40:Jonas]", 1, true), "legacy metadata retains an existing readable level prefix")
for _, value in ipairs({ secret, 0, -1, 1.5, math.huge, "40", 1000 }) do
    check(LevelMessage(value):find("[Jonas]", 1, true), "unknown or invalid message level omitted safely")
end
check(LevelMessage(60, "Alt Person", { name = "Main Person-TestRealm", level = 60 }):find("[Jonas]", 1, true), "mismatched metadata cannot attach the main's level to its alt")
module.db.profile.guildFormat = "both"
local combined = Message("Alt Person-TestRealm", "|cff00ff0040:Alt Person|r")
combined.typeInfo.type, combined.typeInfo.player.level = "GUILD", 40; active(combined)
check(combined.text:find("40:Jonas (Alt Person)", 1, true), "combined nickname/character mode carries one speaking-character level")
module.db.profile.guildFormat = "original"
local unchanged = Message("Alt Person-TestRealm", "40:Alt Person"); unchanged.typeInfo.type = "GUILD"
local unchangedText = unchanged.text; active(unchanged)
check(unchanged.text == unchangedText, "original-name format retains provider level preference")
module.db.profile.guildFormat, module.db.profile.nicknameLevels = "nickname", false
check(LevelMessage(40, "40:Alt Person"):find("[Jonas]", 1, true), "level toggle off removes prefix only from substituted names")
local registered = active
active = nil -- A provider restart or rejected modifier can lose registration.
local remove = Chattynator.API.RemoveModifier
Chattynator.API.RemoveModifier = function() removes = removes+1 end
module:OnEvent("PLAYER_ENTERING_WORLD", false, true)
check(active == registered, "reload world-entry reconnects chat modifier")
Chattynator.API.RemoveModifier = remove
adds, removes = adds-1, removes-1
active({ text = "plain text" })
active({ text = "plain text", typeInfo = { player = 17 } })
local legacy = Message("Alt Person-TestRealm", "Alt Person")
legacy.typeInfo.player = "Alt Person-TestRealm"; active(legacy)
check(legacy.text:find("[Jonas]", 1, true), "legacy string sender metadata remains supported")
data = Message("Alt Person-TestRealm", "|cff00ff00Alt Person|r", "Alt Person |Hplayer:Alt Person-TestRealm:99|h[Alt Person]|h")
active(data)
check(data.text:find("|h[|cff00ff00Jonas|r]|h", 1, true), "class colour kept")
check(data.text:find(": Alt Person |Hplayer:Alt Person-TestRealm:99|h[Alt Person]|h", 1, true), "body and its links unchanged")
data = { text = secret, typeInfo = { player = { name = "Alt Person" } } }
active(data)
check(data.text == secret, "secret text skipped")
data = { text = "hello", typeInfo = { player = { name = secret } } }
active(data)
check(data.text == "hello", "secret sender skipped")
data = Message("Stranger-TestRealm", "Stranger")
raw = data.text; active(data)
check(data.text == raw, "unknown sender unchanged")
data = { text = "|HBNplayer:Friend:1|h[Friend]|h", typeInfo = {} }
raw = data.text; active(data)
check(data.text == raw, "Battle.net untouched")
module:SaveIdentity("Main Person", "New Nick", "")
check(adds == 2 and removes == 1, "identity change refreshes Chattynator cache via API")
check(module:Resolve("Alt Person") == "New Nick", "main rename reaches alt")
module:ForgetIdentity("Main Person")
check(not module:Resolve("Alt Person"), "removed identity no longer renames")
module.db.profile.chatNicknames = false; module:UpdateSettings()
check(not active, "toggle unregisters")
module.db.profile.chatNicknames = true; module:UpdateSettings(); module:OnDisable()
check(not active, "module disable unregisters")

-- Extended person model, transactional edits, import review and channel rules.
module.db.global.characters, module.undoStack = {}, {}
check(module:SaveIdentity("Main Person", "Jonas", ""), "main initialized for person view")
check(module:SaveIdentity("Alt Person", "", "Main Person"), "person alt initialized")
check(module:SetPersonDetails("Alt Person", true, "Raid friend"), "person details saved through alt")
local people = module:GetPeople("", {})
check(#people == 1 and #people[1].rows == 2 and people[1].online == 1, "one person aggregates both characters and online count")
check(people[1].favorite and people[1].privateNote == "Raid friend", "person metadata resides on main")
check(#module:GetPeople("Raid friend", {}) == 1, "private notes searchable locally")
check(#module:GetPeople("", { class = "WARRIOR", rank = "Officer", online = true, favorite = true }) == 1, "filters include a whole matching person")
check(#module:GetPeople("", { class = "DRUID" }) == 0, "class filter excludes nonmatching person")
check(#module:GetPeople("", { missing = true }) == 0, "missing nickname filter")
check(#module:GetPeople("", { unlinked = true }) == 0, "linked person excluded by unlinked filter")
local display = module:GetDisplayRows("", {}, { [module:CharacterKey("Main Person")] = true })
check(#display == 3 and display[1].kind == "person" and display[2].kind == "character", "expanded person includes its character children")
check(module:SaveIdentity("Main Person", "Renamed", ""), "rename person")
check(module:GetPeople("", {})[1].privateNote == "Raid friend", "nickname changes preserve private notes")
module.undoStack = {}
check(module:SavePersonCard("Main Person", "Card Nick", "", false, "New note"), "card saved atomically")
check(#module.undoStack == 1, "card changes are a single undo step")
check(module:UndoIdentity() and module:Resolve("Main Person") == "Renamed", "undo restores nickname")
check(module:GetPeople("", {})[1].favorite and module:GetPeople("", {})[1].privateNote == "Raid friend", "undo restores notes and favorite too")
local before = module.db.global.characters
check(not module:SavePersonCard("Main Person", "No", "Alt Person", false, "bad"), "invalid card cycle rejected")
check(before == module.db.global.characters, "invalid card does not partially mutate")
check(module:SaveIdentity("Separate", "Separate", ""), "separate person created")
check(module:SavePersonCard("Separate", "", "Main Person", false, ""), "card can relink a person")
check(module:GetPeople("Renamed", {})[1].privateNote == "Raid friend", "relinking preserves destination main's private details")
module:ForgetIdentity("Separate")
check(not module:SetPersonDetails("Main Person", true, "|cunsafe"), "private note markup rejected")
for i = 1, 25 do module:SaveIdentity("Main Person", "Person " .. i, "") end
check(#module.undoStack == 20, "undo history bounded to twenty operations")
module:SaveIdentity("Main Person", "Jonas", "")
module:SetPersonDetails("Main Person", true, "Hidden secret note")
local shared = assert(module:ExportIdentities(false))
local full = assert(module:ExportIdentities(true))
check(not shared:find("Hidden", 1, true), "share export omits private note")
local decoded, recordCount = module:DecodeIdentityBackup(full)
check(recordCount == 2 and decoded[module:CharacterKey("Main Person")].privateNote == "Hidden secret note", "full backup round trips metadata through actual AceSerializer")
check(decoded[module:CharacterKey("Main Person")].name == "Main Person-testrealm", "old realm-less names are made explicit in exports")
check(not module:DecodeIdentityBackup("AZGUILD:9:invalid"), "unknown backup version rejected")
check(not module:DecodeIdentityBackup("AZGUILD:1:loadstring('oops')"), "nonserialized code rejected without evaluation")
check(not module:DecodeIdentityBackup("AZGUILD:1:^1" .. string.rep("^T", 1000) .. string.rep("^t", 1000) .. "^^"), "deeply nested backup rejected before recursive parsing")
check(not module:DecodeIdentityBackup(string.rep("a", 1500010)), "oversized backup rejected before parsing")
check(not module:ValidateRecords({ ["x-testrealm"] = { name = "x", extra = true } }), "unknown imported fields rejected")
check(not module:ValidateRecords({ ["x-testrealm"] = { name = "x", privateNote = {} } }), "nontext private note rejected")
check(not module:ValidateRecords({ ["x-testrealm"] = { name = "x", main = "y-testrealm" }, ["y-testrealm"] = { name = "y", main = "x-testrealm" } }), "import cycles rejected")
module:SaveIdentity("Main Person", "Changed", "")
local preview = module:PreviewIdentityImport(shared)
check(preview and preview.count == 2 and preview.conflicts == 1, "backup preview reports replacement count")
check(module:Resolve("Main Person") == "Changed", "preview has no mutation")
check(not module:ImportIdentities(shared, preview.revision-1), "stale backup confirmation rejected")
check(module:ImportIdentities(shared) and module:Resolve("Alt Person") == "Jonas", "merge imports nickname and alt links")
check(module:GetPeople("", {})[1].privateNote == "Hidden secret note", "share import preserves an existing private note")
check(module:UndoIdentity() and module:Resolve("Alt Person") == "Changed", "whole import is undoable")
module.db.profile.guildFormat, module.db.profile.groupFormat = "original", "both"
check(module:GetChatFormat({ type = "OFFICER" }) == "original", "officer uses guild format")
check(module:GetChatFormat({ event = "CHAT_MSG_RAID_WARNING" }) == "both", "event fallback classifies raid warning")
check(module:GetChatFormat({ type = "INSTANCE_CHAT_LEADER" }) == "both", "instance leader uses group format")
module.db.profile.whisperFormat = "both"
check(module:GetChatFormat({ type = "WHISPER_INFORM" }) == "both", "outgoing whisper uses whisper format")
data = Message("Alt Person-TestRealm", "Alt Person"); data.typeInfo.type = "GUILD"
raw = data.text; module:ModifyMessage(data)
check(data.text == raw, "original format leaves the label untouched")
data.typeInfo.type = "PARTY"; module:ModifyMessage(data)
check(data.text:find("Changed (Alt Person)", 1, true), "combined chat format includes full character without realm")
check(data.text:find("|Hplayer:Alt Person-TestRealm:27:GUILD:", 1, true), "combined format preserves original click payload")
module.db.profile.guildFormat, module.db.profile.groupFormat, module.db.profile.whisperFormat = "nickname", "nickname", "nickname"

local oldMembers = module.members
module.members = {
    ["first-testrealm"] = { name = "First-TestRealm", rank = "Member", note = "Shared - H/A", online = true },
    ["second-testrealm"] = { name = "Second-TestRealm", rank = "Member", note = "Shared", online = false },
    ["third-testrealm"] = { name = "Third-TestRealm", rank = "Member", note = "being scammed...", online = false },
    ["fourth-testrealm"] = { name = "Fourth-TestRealm", rank = "Member", note = "?", online = false }
}
local proposals, skipped = module:BuildNoteSuggestions()
check(#proposals == 2 and skipped == 1, "full note scan groups matching names and counts unresolved notes")
local selected = {}
for _, proposal in ipairs(proposals) do
    if proposal.id == "shared" then selected.shared = true; proposal.main = "second-testrealm"
    else check(proposal.ambiguous, "prose note explicitly marked ambiguous") end
end
check(not module:Resolve("First"), "note scan never imports by itself")
local undoCount = #module.undoStack
check(module:ApplyNoteSuggestions(proposals, selected), "reviewed note groups imported")
check(module:Resolve("First") == "Shared" and module.db.global.characters["first-testrealm"].main == "second-testrealm", "reviewer selected main honored")
check(not module:Resolve("Third"), "unchecked proposal remains untouched")
check(#module.undoStack == math.min(20, undoCount+1), "batch creates one undo snapshot")
local remaining, _, matching = module:BuildNoteSuggestions()
check(#remaining == 1 and remaining[1].id == "being" and matching == 1, "a rescan omits groups that already match")
module.members["second-testrealm"].note = "Different"
module.members["third-testrealm"].note = "Being - free prose"
module.members["fourth-testrealm"].note = "shared - S/L"
local overlapping = {}
for _, candidate in ipairs(module:BuildNoteSuggestions()) do overlapping[candidate.id] = candidate end
check(overlapping.shared.conflict and overlapping.different.conflict, "groups with an overlapping main both require review")
check(overlapping.being.ambiguous, "a dash before prose does not make the note a clear suggestion")
module.members["second-testrealm"].note = "Shared"
local additions = module:BuildNoteSuggestions()
check(additions[1].id == "shared" and not additions[1].conflict and additions[1].nickname == "Shared",
    "adding a new alt keeps existing nickname capitalization and sorts clear suggestions first")
module.members["first-testrealm"].note = "shared - H/A"
local lowered = module:BuildNoteSuggestions()
check(lowered[1].id == "shared" and lowered[1].nickname == "Shared",
    "the saved nickname wins over a differently capitalized note on the first-sorted member")
module.members["first-testrealm"].note = "Shared - H/A"
-- An alt linked through another alt keeps its own link when the group is applied.
local function chars() return module.db.global.characters end
chars()["fourth-testrealm"] = { name = "Fourth-TestRealm", main = "first-testrealm" }
module.members["fifth-testrealm"] = { name = "Fifth-TestRealm", rank = "Member", note = "Shared", online = false }
local chained, chainedPick = module:BuildNoteSuggestions(), {}
for _, candidate in ipairs(chained) do if (candidate.id == "shared") then chainedPick.shared = true end end
check(chainedPick.shared and module:ApplyNoteSuggestions(chained, chainedPick), "a group with an indirect alt link applies")
check(chars()["fourth-testrealm"].main == "first-testrealm" and chars()["fifth-testrealm"].main == "second-testrealm",
    "applying keeps the established alt-of-alt link and attaches the new alt to the main")
check(module:UndoIdentity(), "undo the chained application")
chars()["fourth-testrealm"], module.members["fifth-testrealm"] = nil, nil
-- A main link to a forgotten record is never treated as a clear group.
chars()["third-testrealm"] = { name = "Third-TestRealm", main = "ghost-testrealm" }
module.members["third-testrealm"].note = "Ghost"
local orphan
for _, candidate in ipairs(module:BuildNoteSuggestions()) do if (candidate.id == "ghost") then orphan = candidate end end
check(orphan and orphan.conflict, "a member whose saved main no longer exists requires review")
chars()["third-testrealm"] = nil
module.members["third-testrealm"].note = "being scammed..."
module.members["fourth-testrealm"].note = "?"
check(module:UndoIdentity() and not module:Resolve("First"), "one undo removes complete batch")
module.members["first-testrealm"].note = "Different"
check(not module:ApplyNoteSuggestions(proposals, selected), "stale note review rejected atomically")
check(not module:Resolve("Second"), "stale rejection preserves all records")
module.members["first-testrealm"].note = "Shared - H/A"
module:SaveIdentity("First", "Manual Name", "")
proposals = module:BuildNoteSuggestions()
for _, proposal in ipairs(proposals) do if proposal.id == "shared" then check(proposal.conflict, "manual identity conflict prominently flagged") end end
module:ForgetIdentity("First")
module.members = oldMembers
local mainMember, altMember = module.members["main person-testrealm"], module.members["alt person-testrealm"]
local onlineBefore, seenBefore = mainMember.online, mainMember.lastOnline
mainMember.online = false
mainMember.lastOnline = { years = 0, months = 0, days = 8, hours = 0, order = 192 }
local offlinePerson = module:GetPeople("40-45", {})[1]
check(#offlinePerson.rows == 2 and offlinePerson.lastOnline.days == 2, "level search retains whole person and offline activity uses most recent known alt")
altMember.lastOnline = nil; mainMember.lastOnline = nil
check(not module:GetPeople("", {})[1].lastOnline, "missing durations never imply recent activity")
mainMember.online, mainMember.lastOnline = onlineBefore, seenBefore
altMember.lastOnline = module:ReadLastOnline(2)

-- Build the real window and drive selection/paging using a strict minimal widget contract.
local methods = {}
local mt = { __index = methods }
local frames = {}
local frontWindow
local function widget(name, parent, kind)
    local w = setmetatable({ text = "", shown = true, scripts = {}, name = name, parent = parent, kind = kind }, mt)
    frames[#frames+1] = w
    w.id = #frames
    return w
end
for _, name in ipairs({ "SetFontObject", "SetPoint", "SetWidth", "SetJustifyH", "SetMaxLines", "SetTextColor",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetVertexColor", "SetAutoFocus", "SetMaxBytes",
    "SetTextInsets", "ClearFocus", "SetScale", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetAllPoints", "SetColorTexture", "EnableMouseWheel",
    "SetTexture", "SetAtlas", "SetTexCoord", "SetMultiLine", "SetJustifyV", "SetFocus", "HighlightText", "SetScrollChild", "SetHeight", "SetClipsChildren", "ClearAllPoints" }) do
    methods[name] = function() end
end
methods.SetSize = function(self, w, h) self.w, self.h = w, h end
methods.SetWidth = function(self, w) self.w = w end
methods.SetHeight = function(self, h) self.h = h end
methods.SetPoint = function(self, point, a, b, c, d)
    if type(a) == "number" then self.point, self.relative, self.relativePoint, self.x, self.y = point, self.parent, point, a, b
    else self.point, self.relative, self.relativePoint, self.x, self.y = point, a or self.parent, b or point, c or 0, d or 0 end
end
methods.SetAllPoints = function(self, target) self.fill = target or self.parent end
methods.SetFontObject = function(self, font) self.fontSize = font.size or 12 end
methods.SetMaxLines = function(self, value) self.lines = value end
methods.SetJustifyH = function(self, value) self.justifyH = value end
methods.SetTextColor = function(self, ...) self.textColor = { ... } end
methods.SetVertexColor = function(self, ...) self.vertexColor = { ... } end
methods.SetDesaturated = function(self, value) self.desaturated = value end
methods.SetMaxLetters = function(self, value) self.maxLetters = value end
methods.SetBackdrop = function(self, value) self.backdrop = value end
methods.SetBackdropColor = function(self, ...) self.bgColor = { ... } end
methods.SetBackdropBorderColor = function(self, ...) self.borderColor = { ... } end
methods.SetTexture = function(self, value) self.texture = value end
methods.SetAtlas = function(self, value) self.atlas = value end
methods.SetTexCoord = function(self, ...) self.uv = { ... } end
methods.SetColorTexture = function(self, ...) self.color = { ... } end
methods.SetTextInsets = function(self, left, right, top, bottom) self.insets = { left, right, top, bottom } end
methods.GetWidth = function(self) return self.w or 1920 end
methods.GetHeight = function(self) return self.h or 1080 end
methods.GetScale = function(self) return self.scale or 1 end
methods.SetScale = function(self, value) self.scale = value end
methods.SetClampRectInsets = function(self, ...) self.clampInsets = { ... } end
methods.SetToplevel = function(self, value) self.toplevel = value end
methods.Raise = function(self) frontWindow = self; self.raises = (self.raises or 0)+1 end
methods.GetStringHeight = function(self) return math.max(15, math.ceil(#self.text/65)*16) end
methods.GetName = function(self) return self.name end
methods.SetText = function(self, text)
    local changed = self.text ~= text
    self.text = text
    if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
methods.GetText = function(self) return self.text end
methods.IsTruncated = function(self) return self.truncated == true end
methods.SetMotionScriptsWhileDisabled = function(self, enabled) self.disabledMotion = enabled end
methods.SetScript = function(self, event, callback) self.scripts[event] = callback end
methods.HookScript = function(self, event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
methods.SetShown = function(self, value)
    if self.shown ~= value then
        self.shown = value
        local callback = value and self.scripts.OnShow or self.scripts.OnHide
        if callback then callback(self) end
    end
end
methods.Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
methods.Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
methods.IsShown = function(self) return self.shown end
methods.IsEnabled = function(self) return self.enabled ~= false end
methods.SetEnabled = function(self, value)
    local changed = self:IsEnabled() ~= value
    self.enabled = value
    local callback = value and self.scripts.OnEnable or self.scripts.OnDisable
    if changed and callback then callback(self) end
end
methods.GetNumLines = function(self) return math.max(1, math.ceil(#self.text/100)) end
methods.GetVerticalScroll = function(self) return self.scroll or 0 end
methods.GetVerticalScrollRange = function(self)
    return self.child and math.max(0, self.child:GetHeight()-self:GetHeight()) or 100
end
methods.SetScrollChild = function(self, child)
    self.child, child.scrollOwner = child, self
    child:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
end
methods.SetClipsChildren = function(self, value) self.clips = value end
methods.SetVerticalScroll = function(self, value) self.scroll = value end
methods.CreateFontString = function(self) return widget(nil, self, "Text") end
methods.CreateTexture = function(self) return widget(nil, self, "Texture") end
methods.SetHighlightTexture = function(self) self.highlight = widget(nil, self, "Highlight") end
methods.GetHighlightTexture = function(self) return self.highlight end
CreateFrame = function(kind, name, parent) return widget(name, parent or UIParent, kind) end
UIParent = widget("UIParent", nil, "Frame")
UISpecialFrames, tinsert = {}, table.insert
GameTooltip = {
    IsForbidden = function() return false end,
    SetOwner = function(self, owner) self.owner, self.body = owner, nil end,
    IsOwned = function(self, owner) return self.owner == owner end,
    SetText = function(self, text) self.title = text end,
    AddLine = function(self, text) self.body = text end,
    Show = function() end,
    Hide = function(self) self.owner = nil end
}
LibStub = function(name)
    if (name == "AceSerializer-3.0") then return serializer end
    return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
ns.OptionsKit = { GetFont = function(size) return { size = size } end }
ns.OptionsKit.GetMedia = ns.API.GetMedia
ns.OptionsKit.GetTheme = function() return "light" end
ns.OptionsKit.SetGlyph = function(texture, name)
    check(name == "search", "member search uses the shared search glyph")
    texture:SetTexture(ns.API.GetMedia("options-glyphs"))
end
assert(loadfile(root .. "/Options/Kit/Look.lua"))("Test", ns)
-- Minimal factory stand-in; the actual shared scrollbar is covered by kit_harness.
ns.OptionsKit.Controls = { CreateScrollBar = function(scroll, parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(12, 596)
    bar.Update = function(self) self:SetShown(scroll:GetVerticalScrollRange() > 0) end
    bar:Update()
    return bar
end }
-- Factory contract only; actual shared dropdown/pullout tests run separately.
local dropdownOpen
ns.OptionsKit.Controls.CloseDropdown = function() dropdownOpen = nil end
ns.OptionsKit.Controls.IsDropdownOpen = function() return dropdownOpen ~= nil end
ns.OptionsKit.Controls.CreateDropdown = function(parent)
    local control = { frame = CreateFrame("Frame", nil, parent) }
    for _, name in ipairs({ "label", "help", "rule", "textArea", "area", "box" }) do control[name] = widget(nil, control.frame, "Frame") end
    control.text = control.box:CreateFontString()
    control.box.kind = "Button"
    control.box:SetBackdropColor(.065, .072, .085, 1); control.box:SetBackdropBorderColor(.32, .29, .23, 1)
    control.text:SetPoint("TOPLEFT", 8, -7)
    control.SetList = function(self, list, order) self.list, self.order = list, order; self.listUpdates = (self.listUpdates or 0)+1 end
    control.SetValue = function(self, value)
        self.value = value; self.text:SetWidth(self.frame:GetWidth()-28); self.text:SetText(self.list[value] or "")
    end
    control.GetValue = function(self) return self.value end
    control.SetCallback = function(self, callback) self.callback = callback end
    control.Fire = function(self, value) self.callback(self, value) end
    control.Activate = function(self) dropdownOpen = self; return true end
    return control
end
ns.OptionsKit.Confirm = function(_, callback) callback() end
RAID_CLASS_COLORS = { MAGE = { r = .41, g = .8, b = .94 }, WARRIOR = { r = .78, g = .61, b = .43 } }
assert(loadfile(root .. "/Components/Misc/GuildManagerWindow.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerHome.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerHistory.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerFollowUp.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerFollowUpWindow.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerActions.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerActionsWindow.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerDialogs.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerSharing.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerSharingWindow.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerCrafting.lua"))("Test", ns)
assert(loadfile(root .. "/Components/Misc/GuildManagerCraftingWindow.lua"))("Test", ns)

-- Tooltip nicknames: one post-call, readable players only, never twice.
do
    local postCalls = {}
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback) postCalls[#postCalls+1] = { kind, callback } end }
    Enum = Enum or {}; Enum.TooltipDataType = { Unit = 2 }
    assert(loadfile(root .. "/Components/Misc/GuildManagerTooltip.lua"))("Test", ns)
    module:HookTooltips(); module:HookTooltips()
    check(#postCalls == 1 and postCalls[1][1] == 2, "tooltip nickname post-call registers once for unit tooltips")
    local units = { mouseover = { true, "Tip Main" }, other = { true, "Tip Main", "OtherRealm" },
        npc = { false, "Tip Main" }, hidden = { secret, "Tip Main" }, masked = { true, secret } }
    UnitIsPlayer = function(unit) return units[unit][1] end
    UnitName = function(unit) return units[unit][2], units[unit][3] end
    local function Tip(unit)
        local tip = { lines = 0, shown = 0 }
        tip.GetName = function() return "AzTestTip" end
        tip.NumLines = function(self) return self.lines end
        tip.IsForbidden = function() return false end
        tip.GetUnit = function() return "Name", unit end
        tip.Show = function(self) self.shown = self.shown+1 end
        tip.AddLine = function(self, text)
            self.lines = self.lines+1
            _G["AzTestTipTextLeft" .. self.lines] = { GetText = function() return text end }
        end
        tip:AddLine("Tip Main")
        return tip
    end
    local function Run(unit) local tip = Tip(unit); postCalls[1][2](tip); return tip end
    local wasSuspended = module.suspended; module.suspended = nil
    check(module:SaveIdentity("Tip Main", "Tippy", ""), "save a tooltip test identity")
    local tip = Run("mouseover")
    check(tip.lines == 2 and _G.AzTestTipTextLeft2:GetText() == "Nickname: Tippy" and tip.shown == 1,
        "a known player's tooltip gains one nickname line and is resized")
    postCalls[1][2](tip)
    check(tip.lines == 2, "a repeated post-call does not add the line twice")
    check(Run("other").lines == 1, "a same-named player from another realm gets no nickname")
    check(Run("npc").lines == 1 and Run("hidden").lines == 1 and Run("masked").lines == 1,
        "NPCs, secret player flags and secret names are skipped")
    module.db.profile.tooltipNicknames = false
    check(Run("mouseover").lines == 1, "the setting turns the line off without unhooking")
    module.db.profile.tooltipNicknames = true
    module:SaveIdentity("Tip Main", "Tip Main", "")
    check(Run("mouseover").lines == 1, "a nickname identical to the shown name adds nothing")
    module:ForgetIdentity("Tip Main")
    check(Run("mouseover").lines == 1, "an unknown player gets no line")
    module:SaveIdentity("Tip Main", "Tippy", ""); module.suspended = true
    check(Run("mouseover").lines == 1, "a disabled module adds nothing")
    module.suspended = wasSuspended; module:ForgetIdentity("Tip Main")
    TooltipDataProcessor, UnitIsPlayer, UnitName = nil, nil, nil
    for index = 1, 2 do _G["AzTestTipTextLeft" .. index] = nil end
end
module.suspended = nil
module:ToggleWindow()
check(module.frame:IsShown(), "window opens")
check(frontWindow == module.frame and module.frame.toplevel, "main window opens as a raised top-level root")
check(module.frame.opaqueFill.color[4] == 1 and module.frame.opaqueFill.fill == module.frame, "main window has independent fully opaque fill")
check(module.frame.casing.backdrop == ns.OptionsKit.Look.CasingBackdrop and module.frame.clampInsets[1] == -10,
    "main shell uses real rounded options casing with matching screen clamp")
check(module.memberPage.parent == module.frame and module.memberPage.x == 200
    and module.memberPage.x+module.memberPage.w == module.frame.w, "member page fits beside navigation inside the shell")
check(module.navigation.members.selected and not module.navigation.members.check:IsShown(), "navigation marks members without a toggle check")
do
    local remove, box = module.removeIdentity, module.rankFilter.box
    remove:SetEnabled(false)
    remove.scripts.OnEnter(remove)
    check(remove.disabledMotion and GameTooltip:IsOwned(remove) and GameTooltip.title == "Remove"
        and GameTooltip.body == "Remove local identity", "disabled Remove explains its action without enabling it")
    local text = module.rankFilter.text
    text:SetText("Rank: A long guild rank"); text.truncated = true
    box.scripts.OnEnter(box)
    check(GameTooltip:IsOwned(box) and GameTooltip.title == text:GetText(), "truncated dropdown uses the full current value")
    remove.scripts.OnLeave(remove)
    check(GameTooltip:IsOwned(box), "old button leave preserves a newer tooltip")
    box.scripts.OnHide(box)
    text.truncated = false; box.scripts.OnEnter(box)
    check(not GameTooltip.owner, "hidden controls release their tooltip and fitting labels stay quiet")
    module.rankFilter:SetValue(false)
    check(remove.label.w == remove.w-16 and remove.label.fontSize == 11, "narrow flat button uses a compact font and inset")
end
local followUpIcon = module.navigation.followup.icon
local notesIcon = module.navigation.notes.icon
ns.OptionsKit.Look.RefreshIcons()
check(followUpIcon:IsShown() and notesIcon:IsShown()
    and followUpIcon.texture == ns.API.GetMedia("options-sections") and notesIcon.texture == followUpIcon.texture
    and table.concat(followUpIcon.uv, ",") ~= table.concat(notesIcon.uv, ","),
    "follow-up and notes have distinct motifs on the dark sheet even with Light options")
local searchGlyph
for _, region in ipairs(frames) do
    if (region.parent == module.search and region.texture == ns.API.GetMedia("options-glyphs")) then searchGlyph = region end
end
check(searchGlyph and searchGlyph.x + searchGlyph.w < module.search.insets[1], "search text clears the search glyph")
for _, key in ipairs({ "online", "favorite" }) do
    local button = module.filterButtons[key]
    check(button.filterIcon.texture and button.label.x >= button.filterIcon.x + button.filterIcon.w
        and button.label.x + button.label.w <= button.w + button.check.x - button.check.w,
        "filter icon, label and selected check fit " .. key)
end
module.navigation.members.scripts.OnEnter(module.navigation.members)
check(not module.navigation.members.check:IsShown(), "hovering active navigation cannot put a check over its page icon")
module.navigation.members.scripts.OnLeave(module.navigation.members)
local diagnostic
module.Print = function(_, text) diagnostic = text end
module:ToggleWindow("status")
check(diagnostic:find("guildFormat=nickname", 1, true) and module.frame:IsShown(), "status command reports channel setting without toggling window")
check(#module.rows == 15 and #UISpecialFrames == 1, "bounded row pool and Escape registration")
local mainKey, altKey = module:CharacterKey("Main Person"), module:CharacterKey("Alt Person")
module.expanded[mainKey] = true; module:RefreshWindow()
local function FindGuildRow(key, kind)
    for _, row in ipairs(module.rows) do if row.data and row.data.key == key and row.data.kind == kind then return row end end
end
local offline = FindGuildRow(altKey, "character")
check(offline.name.x > FindGuildRow(mainKey, "person").name.x, "character children are indented beneath their person")
check(offline.name.textColor[1] == .52 and offline.name.textColor[2] == .52 and offline.icon.desaturated, "visible offline alt has gray text and desaturated icon")
check(not FindGuildRow(mainKey, "person").icon.desaturated, "person stays online-colored when any known character is online")
module.members[altKey].online = true; module:RefreshWindow()
check(not offline.icon.desaturated and offline.name.textColor[1] == .78, "reused offline row restores class color when online")
module.members[altKey].online = false; module.members[mainKey].online = false; module:RefreshWindow()
check(FindGuildRow(mainKey, "person").icon.desaturated and FindGuildRow(mainKey, "person").name.textColor[1] == .52, "fully offline person becomes gray")
module.members[mainKey].online = true; module.expanded[mainKey] = nil; module:RefreshWindow()
check(module:LastOnlineText(false, nil) == "Unknown", "unknown last-online stays unknown")
check(module:LastOnlineText(true, nil) == "Online", "online takes precedence over duration")
check(module:LastOnlineText(false, { years = 0, months = 0, days = 2, hours = 4 }) == "2 days ago", "server duration formatted without false timestamp")
module:OpenHome()
check(module.homeWindow:IsShown() and module.homeWindow.motd.text:GetText() == "Raid Friday at 20:00", "home opens with actual MOTD")
check(module.homeWindow.opaqueFill.color[4] == 1, "home window has fully opaque fill")
check(module.homeWindow.info.text:GetText():find("consumables", 1, true), "home displays guild information")
check(module.homeWindow.ranks.text:GetText():sub(1, 7) == "Officer", "rank overview follows roster rank order")
check(not module.homeWindow.emblem:IsShown(), "missing tabard helper leaves safe fallback")
local tabards = 0
C_GuildInfo.GetGuildTabardInfo = function() return {} end
SetLargeGuildTabardTextures = function(unit, texture) check(unit == "player" and texture == module.homeWindow.emblem, "native tabard receives owned texture"); tabards = tabards+1 end
module:RefreshHome()
check(tabards == 1 and module.homeWindow.emblem:IsShown(), "native guild emblem helper used")
SetLargeGuildTabardTextures = nil
module:ShowPage("members")
local filter = module.filterButtons.online
check(filter.label:GetText() == "Online people" and not filter.check:IsShown(), "filters use a graphic check instead of text markup")
filter.scripts.OnEnter(filter)
check(filter.visualState == 1, "button hover uses the highlighted painting")
module.UI.Check(filter, true, "Online people")
check(filter.visualState == 5 and filter.check:IsShown(), "selected hover retains the active gold state")
filter.scripts.OnMouseDown(filter)
check(filter.visualState == 3, "press shows the recessed state")
filter.scripts.OnMouseUp(filter); filter.scripts.OnLeave(filter)
check(filter.visualState == 2, "release and leave restore selection")
filter:SetEnabled(false)
check(filter.visualState == 4 and not filter.check:IsShown(), "disabled state dims the painting and mark")
filter:SetEnabled(true)
check(filter.visualState == 2, "re-enabling preserves selected state")
module.UI.Check(filter, false, "Online people")
module.search.scripts.OnEditFocusGained(module.search)
check(module.search.borderColor[1] == 1, "text entry focus uses a gold border")
module.search.scripts.OnEditFocusLost(module.search)
check(module.search.borderColor[1] == .62, "unfocused input restores the metal border")
module:SelectCharacter(module.rows[1].data.person.rows[1], module.rows[1].data.person)
check(module.character:GetText() == "Main Person-TestRealm", "guild row selects real character")
local whispered, invited
ChatFrameUtil = { SendTell = function(name) whispered = name end }
C_PartyInfo = { InviteUnit = function(name) invited = name end }
module:RefreshWindow()
check(module.whisper:IsEnabled() and module.invite:IsEnabled(), "online roster member enables available contact APIs")
check(module.cardLastOnline:GetText() == "Person last online: Online", "person activity refreshes in member card")
module.character:SetText("Unsaved Stranger")
module.whisper.scripts.OnClick(); module.invite.scripts.OnClick()
check(whispered == "Main Person-TestRealm" and invited == whispered, "contact uses real selection rather than unsaved edit")
module.character:SetText("Main Person-TestRealm")
combat = true; module:OnEvent("PLAYER_REGEN_DISABLED")
check(not module.whisper:IsEnabled() and not module.invite:IsEnabled(), "combat disables contact controls")
whispered, invited = nil, nil; module:ContactSelected(false); module:ContactSelected(true)
check(not whispered and not invited, "contact callbacks independently guard combat")
combat = false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(module.whisper:IsEnabled(), "contact controls recover after combat")
module.members[module.selected].online = false; module:RefreshWindow()
check(not module.whisper:IsEnabled() and not module.invite:IsEnabled(), "offline member disables contact actions")
module.members[module.selected].online = true; module:RefreshWindow()
local alt = module:GetRows("Alt Person", true)[1]
module:LinkToSelectedMain(alt)
local record = module.db.global.characters[alt.key]
check(record.main == module:CharacterKey("Main Person"), "right click links a searched alt to selected main")
module.search:SetText("Officer"); module.search.scripts.OnTextChanged()
check(module.rows[1].shown and not module.rows[2].shown, "search redraws bounded rows")
module.search:SetText(""); module.search.scripts.OnTextChanged()
module.offset = 9999; module:RefreshWindow()
check(module.offset == 0, "offset clamped")
module:OpenNoteReview()
check(module.noteReview:IsShown() and #module.noteReview.rows == 6, "note review opens with bounded rows")
check(module.noteReview.opaqueFill.color[4] == 1, "note review has fully opaque fill")
check(not module.noteReview.apply.enabled, "note review selects no groups implicitly")
local first = module.noteReview.proposals[1]
module.noteReview.selected[first.id] = true; module:RefreshNoteReview()
check(module.noteReview.apply.enabled, "explicit note selection enables apply")
module.noteReview.apply.scripts.OnClick()
check(module.noteReview.feedback:GetText():find("imported", 1, true), "review apply runs actual batch and confirmation callback")
module:UndoIdentity(); module:ReloadCard()
module:OpenBackup()
check(module.backupWindow:IsShown() and not module.backupWindow.apply.enabled, "backup window requires preview before apply")
check(module.backupWindow.opaqueFill.color[4] == 1, "backup window has fully opaque fill")
local function Click(text)
    for _, frame in ipairs(frames) do
        if frame.label and frame.label.text == text then frame.scripts.OnClick(); return end
    end
    error("missing button " .. text)
end
Click("Generate export")
check(module.backupWindow.edit:GetText():sub(1,10) == "AZGUILD:1:", "export button populates copyable serialized data")
Click("Preview import")
check(module.backupWindow.apply.enabled, "backup preview enables import")
module.backupWindow.edit:SetText("invalid")
check(not module.backupWindow.apply.enabled, "editing pasted backup clears preview authorization")
module.backupWindow.edit:SetText(full); Click("Preview import")
module.backupWindow.apply.scripts.OnClick()
check(module.backupWindow.feedback:GetText():find("imported", 1, true), "backup import runs through UI confirmation and validation")
module:OpenHome()
module:OnEvent("GUILD_ROSTER_UPDATE") -- First fresh roster establishes history.
roster[1][7] = "Changed public note"
module:OnEvent("GUILD_ROSTER_UPDATE")
module:OpenHistory()
check(module.historyWindow:IsShown() and #module.historyWindow.rows == 9, "bounded history window opens")
check(module.historyWindow.opaqueFill.color[4] == 1 and module.historyWindow.rows[1].title:GetText():find("Public note changed", 1, true), "history displays observed note change on opaque window")
module.historyWindow.search:SetText("not present")
check(not module.historyWindow.rows[1]:IsShown(), "history search redraws rows")
module.historyWindow.search:SetText("")
module.historyWindow.review.scripts.OnClick()
check(not module.historyWindow.review:IsEnabled(), "mark read updates persisted review marker")
check(not module.historyWindow.rows[1]:IsShown(), "reviewed entries disappear from default unread view")
module.historyWindow.filter.scripts.OnClick()
check(module.historyWindow.rows[1]:IsShown(), "turning off unread filter restores reviewed history")
module.historyWindow.filter.scripts.OnClick()
roster[1][7] = "Junnez - H/A"
module:OpenFollowUp()
local follow = module.followUpWindow
check(follow:IsShown() and follow.opaqueFill.color[4] == 1 and #follow.rows == 9, "opaque bounded follow-up window opens")
check(follow.root == module.selectedRoot and follow.saveSchedule:IsEnabled(), "current main/alt person preselected for follow-up")
follow.trialStart:SetText("2026-11-01"); follow.trialEnd:SetText("2026-11-15")
follow.saveSchedule.scripts.OnClick()
check(module:GetFollowUpPerson(follow.root).trialEnd == "2026-11-15", "schedule saved through actual window callback")
follow.taskTitle:SetText("Talk to recruit"); follow.owner:SetText("Junnez"); follow.due:SetText("2026-11-15")
follow.trialStart:SetText("2026-10-31") -- Unsaved independent form.
follow.saveTask.scripts.OnClick()
check(#module:GetFollowUpPerson(follow.root).tasks == 1, "task created through window callback")
check(follow.trialStart:GetText() == "2026-10-31" and module:GetFollowUpPerson(follow.root).trialStart == "2026-11-01", "task save preserves unsaved dates without committing them")
follow.filterIndex = 6; module:RefreshFollowUp()
follow.rows[1].scripts.OnClick()
check(follow.taskId and follow.toggleTask:IsEnabled() and follow.saveTask.label:GetText() == "Save task", "task selection loads task editor")
follow.taskTitle:SetText("Talk to recruit again"); follow.saveTask.scripts.OnClick()
check(module:GetFollowUpPerson(follow.root).tasks[1].title == "Talk to recruit again", "task edited without duplication")
follow.rows[1].scripts.OnClick(); follow.toggleTask.scripts.OnClick()
check(module:GetFollowUpPerson(follow.root).tasks[1].done, "task completion callback persists")
follow.rows[1].scripts.OnClick(); follow.removeTask.scripts.OnClick()
check(#module:GetFollowUpPerson(follow.root).tasks == 0, "task removed through callback")
follow.undo.scripts.OnClick()
check(#module:GetFollowUpPerson(follow.root).tasks == 1, "follow-up undo restores removed task")
follow.clear.scripts.OnClick()
check(follow.trialEnd:GetText() == "" and module:GetFollowUpPerson(follow.root).trialEnd, "clear dates requires save before persistence")
follow.taskTitle:SetText("Unfinished task draft")
follow.saveSchedule.scripts.OnClick()
check(not module:GetFollowUpPerson(follow.root).trialEnd and #module:GetFollowUpPerson(follow.root).tasks == 1, "date clearing preserves tasks")
check(follow.taskTitle:GetText() == "Unfinished task draft", "schedule save preserves unsaved task draft")
follow.search:SetText("no matching task")
check(not follow.rows[1]:IsShown(), "follow-up search redraws list")
follow.search:SetText("")
-- Guild writes use explicit confirmation and fake native APIs, including offline targets.
local approval, approvalText, guildWrites, actionTimers = nil, nil, {}, {}
local confirm = ns.OptionsKit.Confirm
local function QueueApproval(question, callback) approvalText, approval = question, callback; return true end
ns.OptionsKit.Confirm = QueueApproval
UnitGUID = function() return "Player-1-Main" end
CanEditPublicNote, CanGuildPromote, CanGuildDemote = function() return true end, function() return true end, function() return true end
local actionRank = 4
local actionRankNames = { "Guild Master", "Officer", "Veteran", "Member", "Initiate" }
GuildControlGetNumRanks = function() return #actionRankNames end
GuildControlGetRankName = function(index) return actionRankNames[index] end
C_GuildInfo.GetGuildRankOrder = function(guid) return guid == "Player-1-Main" and 2 or actionRank end
C_GuildInfo.IsGuildRankAssignmentAllowed = function() return true end
C_GuildInfo.SetNote = function(guid, value, public) guildWrites[#guildWrites+1] = { guid, value, public } end
C_GuildInfo.SetGuildRankOrder = function(guid, value) guildWrites[#guildWrites+1] = { guid, value } end
C_Timer = { After = function(_, callback) actionTimers[#actionTimers+1] = callback end }
local altRow = module:GetRows("Alt Person", true)[1]
module:ShowPage("members")
module.expanded[mainKey] = true; module:RefreshWindow()
local offlineNoteRow = FindGuildRow(altKey, "character")
offlineNoteRow.scripts.OnClick(offlineNoteRow, "LeftButton")
check(module.selected == altKey and not altRow.member.online and module.note:GetText() == altRow.member.note,
    "clicking a live offline roster row selects its public note")
check(module.note.parent == module.character.parent and module.publicNoteAction:IsEnabled(),
    "public note and edit shortcut are available under Character for an offline member")
module.publicNoteAction.scripts.OnClick()
check(module.guildActionsWindow.baseline.target.guid == "Player-1-Alt" and module.guildActionsWindow.noteApply:IsEnabled(),
    "the Character shortcut opens the permitted offline member note editor")
module:ShowPage("members")
module:SelectCharacter(altRow, module:GetPeople("", {})[1])
module.character:SetText("Unsaved Different Person")
module:OpenGuildActions()
local actions = module.guildActionsWindow
check(actions.baseline.target.guid == "Player-1-Alt" and actions.characterName:GetText() == "Alt Person-TestRealm", "guild actions bind actual selection rather than unsaved name edit")
check(actions.noteApply:IsEnabled() and actions.note.maxLetters == 31, "offline member can use permitted note editor with native character limit")
actions.note:SetText("Combat proposal"); actions.noteApply.scripts.OnClick()
check(type(approval) == "function" and #guildWrites == 0, "guild note preview requires explicit confirmation callback")
check(approvalText:find("Alt Person-TestRealm", 1, true) and approvalText:find("Before:", 1, true) and approvalText:find("After:", 1, true), "confirmation identifies actual character and before/after values")
combat = true; module:OnEvent("PLAYER_REGEN_DISABLED")
check(not actions.noteApply:IsEnabled() and not actions.rankCycle:IsEnabled(), "combat disables guild change controls")
approval()
check(#guildWrites == 0, "approval arriving in combat cannot call native write")
combat = false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(#guildWrites == 0, "combat end never auto-executes a proposed write")
module:OpenGuildActions(); actions.note:SetText("Unavailable confirmation")
ns.OptionsKit.Confirm = function() return false end
actions.noteApply.scripts.OnClick()
check(#guildWrites == 0 and actions.feedback:GetText():find("No guild change was sent", 1, true), "unavailable confirmation never becomes automatic consent")
ns.OptionsKit.Confirm = QueueApproval
module:OpenGuildActions(); actions.note:SetText("Stale window"); actions.noteApply.scripts.OnClick()
local staleApproval = approval; module:OpenGuildActions(); staleApproval()
check(#guildWrites == 0, "reopening tool invalidates old confirmation")
actions.note:SetText("Changed selection"); actions.noteApply.scripts.OnClick()
local selectedKey = module.selected; module.selected = mainKey; approval(); module.selected = selectedKey
check(#guildWrites == 0, "main selection change invalidates approval")
local localUndoCount = #module.undoStack
module:OpenGuildActions(); actions.note:SetText("UI public note"); actions.noteApply.scripts.OnClick(); approval()
check(#guildWrites == 1 and guildWrites[1][1] == "Player-1-Alt" and guildWrites[1][3], "confirmed note request uses target GUID and public flag")
check(not actions.noteApply:IsEnabled() and actions.feedback:GetText():find("waiting", 1, true), "write waits for observation instead of claiming immediate success")
roster[2][7] = "UI public note"; module:OnEvent("GUILD_ROSTER_UPDATE")
check(not module.pendingGuildAction and module.note:GetText() == "UI public note", "fresh roster observes note and updates main read-only note")
module:OpenGuildActions(); actions.rankCycle.scripts.OnClick()
check(actions.rankOrder == 3 and actions.rankApply:IsEnabled(), "rank cycle offers permitted destination")
actions.rankApply.scripts.OnClick()
check(#guildWrites == 1, "rank preview does not write")
approval()
check(#guildWrites == 2 and guildWrites[2][1] == "Player-1-Alt" and guildWrites[2][2] == 3, "rank write follows confirmation")
actionRank, roster[2][2] = 3, "Veteran"; module:OnEvent("GUILD_ROSTER_UPDATE")
check(not module.pendingGuildAction and actions.currentRank:GetText():find("Veteran", 1, true), "rank observation updates current-rank label")
check(#module.undoStack == localUndoCount, "external guild writes never enter local identity Undo")
module:OpenGuildActions(); actions.note:SetText("Do not send after closing"); actions.noteApply.scripts.OnClick()
local closedApproval = approval
for _, page in pairs(module.pages) do
    check(page == module.memberPage or page.viewport and page.host.parent == module.frame,
        "every tool is a child page of the single root")
end
check(module.frame.parent == UIParent and module.frame.toplevel and #UISpecialFrames == 1,
    "pages do not register independent top-level Escape windows")
module:OpenBackup()
check(frontWindow == module.frame and module.activePage == "backup" and not actions:IsShown(), "backup replaces actions in the shared root")
module:OpenHistory()
check(module.activePage == "history" and not module.backupWindow:IsShown(), "history replaces backup")
module:OpenNoteReview()
check(module.activePage == "notes" and not module.historyWindow:IsShown(), "note review replaces history")
module:OpenHome()
check(module.activePage == "home" and not module.noteReview:IsShown(), "home replaces note review")
module:OpenFollowUp()
check(module.activePage == "followup" and not module.homeWindow:IsShown(), "follow-up replaces home")
local originalWidth, originalHeight = UIParent.w, UIParent.h
UIParent:SetSize(900, 650)
local small = module.UI.Shell("AzTestGuildLayerFixture", module.frame, 940, 700)
check(math.abs(small:GetScale()-600/700) < .0001, "tool screen fit is absolute rather than multiplied by main window scale")
module.UI.FitToScreen(module.frame)
check(math.abs(module.frame:GetScale()-850/1320) < .0001, "existing shared root refits after a viewport change")
small:Hide()
UIParent.w, UIParent.h = originalWidth, originalHeight
module.UI.FitToScreen(module.frame)
local isInGuild = IsInGuild; IsInGuild = function() return false end
module:RequestRoster()
check(not next(module.members) and not module.guildDetails.motd, "leaving guild clears roster and guild text")
check(not module.whisper:IsEnabled() and not module.invite:IsEnabled(), "saved identities do not enable guild member actions after leaving")
module:OpenHome()
check(module.homeWindow.motd.text:GetText() == "No guild data available." and not module.homeWindow.emblem:IsShown(), "open home clears stale guild content")
module:OpenHistory()
check(not module.historyWindow.rows[1]:IsShown(), "history page clears current guild on reopening after leaving")
module:OpenFollowUp()
check(not follow.saveSchedule:IsEnabled() and not follow.saveTask:IsEnabled() and follow.trialStart:GetText() == "", "guild leave clears follow-up editor and disables writes")
IsInGuild = isInGuild; module:RequestRoster()
module:ToggleWindow()
check(not module.frame:IsShown(), "window closes")
check(not module.noteReview:IsShown() and not module.backupWindow:IsShown() and not module.homeWindow:IsShown() and not module.historyWindow:IsShown() and not follow:IsShown() and not actions:IsShown(), "closing main window hides its tools")
closedApproval()
check(#guildWrites == 2, "closing main window invalidates pending guild approval")
-- Explicit sharing uses captured transport; no external addon messages.
local shareWrites = {}
GetTime = function() return 10 end
C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end, SendAddonMessage = function() end }
ChatThrottleLib = { SendAddonMessage = function(_, _, prefix, text, channel, target)
    shareWrites[#shareWrites+1] = { prefix, text, channel, target }
end }
roster[2][9] = true
module:ToggleWindow(); module:OpenBackup(); Click("Guild sharing")
local sharing = module.sharingWindow
check(sharing:IsShown() and frontWindow == module.frame and module.activePage == "sharing" and sharing.host.parent == module.frame,
    "sharing opens as a raised independent root through backup")
check(sharing.opaqueFill.color[4] == 1 and not sharing.request:IsEnabled(), "sharing has opaque fill and initially no partner")
sharing.partner:SetText("Alt Person-TestRealm")
check(sharing.request:IsEnabled(), "online selected guild partner enables explicit request")
sharing.request.scripts.OnClick()
check(#shareWrites == 1 and module.sharingReceive and not sharing.apply:IsEnabled(), "request sends only protocol request and arms reception")
sharing.partner:SetText("Main Person")
check(not module.sharingReceive and not sharing.request:IsEnabled(), "changing partner cancels receive and self cannot be selected")
sharing.partner:SetText("Alt Person-TestRealm")
local function FixtureIncoming()
    return { context = assert(module:GetSharingContext("Alt Person-TestRealm")), text = "AZGUILD:1:" .. serializer:Serialize({ format = "AzGuild", version = 1,
        characters = { [mainKey] = { name = mainKey, nickname = "Shared Junnez" }, [altKey] = { name = altKey, main = mainKey } } }) }
end
module.sharingIncoming = FixtureIncoming(); module:RefreshSharing()
check(sharing.apply:IsEnabled() and sharing.preview.conflicts > 0 and sharing.rows[1].after:GetText() ~= "", "incoming records show before/after and conflicts")
sharing.apply.scripts.OnClick()
check(approvalText:find("Alt Person-TestRealm", 1, true) and module:Resolve("Main Person") ~= "Shared Junnez", "import preview identifies sender without changing identities")
local hiddenApproval = approval
sharing:Hide(); module:OpenSharing(); hiddenApproval()
check(module:Resolve("Main Person") ~= "Shared Junnez" and not sharing.apply:IsEnabled(), "closing sharing invalidates confirmation even after reopen")
module.sharingIncoming = FixtureIncoming(); module:RefreshSharing(); sharing.apply.scripts.OnClick(); approval()
check(module:Resolve("Main Person") == "Shared Junnez" and not sharing.apply:IsEnabled(), "confirmed shared import changes nicknames and clears preview")
check(module:UndoIdentity() and module:Resolve("Main Person") ~= "Shared Junnez", "shared UI import can be undone")
module.sharingIncoming = FixtureIncoming(); module:RefreshSharing()
module:ToggleWindow()
check(not sharing:IsShown() and not module.sharingIncoming, "closing main cancels sharing and closes independent root")
-- Crafting window uses owned data and native API spies only.
UnitFullName = function() return "Main Person", "TestRealm" end
local recipeIDs = {}; for index = 1, 12 do recipeIDs[index] = index end
C_TradeSkillUI = { IsTradeSkillReady = function() return true end, IsTradeSkillLinked = function() return false end,
    IsTradeSkillGuild = function() return false end, IsTradeSkillGuildMember = function() return false end,
    GetBaseProfessionInfo = function() return { professionID = 171, professionName = "Alchemy" } end,
    GetAllRecipeIDs = function() return recipeIDs end,
    GetRecipeInfo = function(id) return { name = string.format("Potion %02d", id), learned = true } end,
    GetRecipeItemLink = function(id) return "|Hitem:" .. (1000+id) .. "|h[Healing Draught]|h" end }
module:ToggleWindow(); module:OpenHome(); Click("Guild crafting")
local crafting = module.craftingWindow
check(crafting:IsShown() and frontWindow == module.frame and module.activePage == "crafting" and crafting.host.parent == module.frame
    and crafting.opaqueFill.color[4] == 1, "crafting uses opaque independent root and guild-home entry")
check(not crafting.rows[1]:IsShown() and not crafting.whisper:IsEnabled(), "empty crafting directory does not invent crafters")
crafting.scan.scripts.OnClick()
check(crafting.rows[1]:IsShown() and crafting.next:IsEnabled() and #crafting.rows == 9, "scan callback populates bounded paged recipe pool")
crafting.rows[1].scripts.OnClick()
check(crafting.export:IsEnabled() and crafting.source:GetText():find("Scanned on this account", 1, true), "own recipe card enables voluntary export and shows provenance")
crafting.next.scripts.OnClick(); check(crafting.offset > 0, "crafting pagination moves to remaining recipes")
crafting.search:SetText("1001")
check(crafting.rows[1]:IsShown() and not crafting.rows[2]:IsShown() and crafting.rows[1].data.id == 1, "item ID search filters actual recipe rows")
crafting.rows[1].scripts.OnClick(); crafting.export.scripts.OnClick()
local transfer = module.craftingTransfer
check(transfer:IsShown() and frontWindow == transfer and transfer.edit:GetText():sub(1, 10) == "AZCRAFT:1:", "share callback exports only current character's scanned profession")
Click("Preview recipe list")
check(transfer.apply:IsEnabled() and transfer.preview.count == 12 and transfer.feedback:GetText():find("removed", 1, true), "recipe import preview includes owner, count and replacement differences")
transfer.apply.scripts.OnClick(); local staleCraftApproval = approval
transfer:Hide(); module:OpenCraftingTransfer(); staleCraftApproval()
check(module.db.global.crafting[mainKey][171].source == "own", "closed/reopened transfer rejects old import approval")
module:OpenCraftingTransfer(crafting.selected); Click("Preview recipe list"); transfer.apply.scripts.OnClick(); approval()
check(module.db.global.crafting[mainKey][171].source == "import" and not crafting.export:IsEnabled(), "manual import is labeled unverified and cannot be re-exported as own scan")
crafting.undo.scripts.OnClick()
check(module.db.global.crafting[mainKey][171].source == "own" and crafting.export:IsEnabled(), "crafting Undo restores scan provenance")
local queryCalls, tells = 0, {}
C_GuildInfo.QueryGuildMembersForRecipe = function(_, id) queryCalls = queryCalls+1; return id end
GetGuildRecipeInfoPostQuery = function() return 171, 1, 1 end
GetGuildRecipeMember = function() return "Alt Person", "Alt Person-TestRealm", "WARRIOR", true end
ChatFrameUtil.SendTell = function(name) tells[#tells+1] = name end
module:RefreshCrafting(); crafting.query.scripts.OnClick()
check(queryCalls == 1 and module.craftingPending, "guild lookup is explicitly requested through selected recipe")
module:OnCraftingQuery()
local function CraftingRow(owner)
    for _, button in ipairs(crafting.rows) do if (button.data and button.data.owner == owner) then return button end end
end
CraftingRow(altKey).scripts.OnClick()
check(crafting.selected.owner == altKey and crafting.source:GetText():find("Blizzard guild response", 1, true), "native lookup adds source-labeled actual crafter")
crafting.whisper.scripts.OnClick()
check(tells[1] == "Alt Person-TestRealm", "crafting whisper uses actual character, not nickname")
roster[2][9] = false; module:RequestRoster()
check(not crafting.whisper:IsEnabled() and CraftingRow(altKey).title.textColor[1] == .52, "offline crafter is gray and cannot be whispered")
roster[2][9] = true; module:RequestRoster()
local chatMessages = #shareWrites
module:ToggleWindow()
check(not crafting:IsShown() and not transfer:IsShown() and not module.craftingPending and #shareWrites == chatMessages,
    "main close hides crafting tools without sending data")
ns.OptionsKit.Confirm = confirm

-- Unified navigation: real page builders, one active page, stable drafts and
-- invalidated proposals. All native calls above remain captured test spies.
module:ToggleWindow(); module:ShowPage("members")
local nicknameDraft = module.nickname:GetText()
module.nickname:SetText("Unsaved member draft")
for key, button in pairs(module.navigation) do
    button.scripts.OnClick()
    check(module.activePage == key and module.pages[key]:IsShown() and button.selected,
        "navigation opens and selects " .. key)
    local shown, selectedCount = 0, 0
    for _, page in pairs(module.pages) do if page:IsShown() then shown = shown+1 end end
    for _, nav in pairs(module.navigation) do if nav.selected then selectedCount = selectedCount+1 end end
    check(shown == 1 and selectedCount == 1 and frontWindow == module.frame, "only one page is visible for " .. key)
end
module.navigation.members.scripts.OnClick()
check(module.nickname:GetText() == "Unsaved member draft", "ordinary page changes preserve unsaved member input")
module.nickname:SetText(nicknameDraft)
module:OpenFollowUp()
local draftDate, draftTask = follow.trialStart:GetText(), follow.taskTitle:GetText()
follow.trialStart:SetText("2026-11-17"); follow.taskTitle:SetText("Unsaved follow-up draft")
module:OpenHistory(); module:OpenFollowUp()
check(follow.trialStart:GetText() == "2026-11-17" and follow.taskTitle:GetText() == "Unsaved follow-up draft",
    "follow-up dates and task draft survive leaving and returning to the same person")
follow.trialStart:SetText(draftDate); follow.taskTitle:SetText(draftTask)
local followHeight = follow.viewport.child:GetHeight()
follow.viewport.child:SetHeight(1000) -- Exercise future/long content too.
follow.viewport.scripts.OnMouseWheel(follow.viewport, -10000)
check(follow.viewport:GetVerticalScrollRange() > 0 and follow.viewport:GetVerticalScroll() == follow.viewport:GetVerticalScrollRange()
    and follow.scrollBar.parent == follow.host, "long page reaches its footer and scrollbar is outside the clipping viewport")
local keptScroll = follow.viewport:GetVerticalScroll()
module:OpenHome(); module:OpenFollowUp()
check(follow.viewport:GetVerticalScroll() == keptScroll, "each page retains its own scroll position")
follow.viewport.child:SetHeight(followHeight); follow.viewport:SetVerticalScroll(0)

ns.OptionsKit.Confirm = QueueApproval
module:SaveIdentity("Main Person", "Backup sentinel", "")
module:OpenBackup(); module.backupWindow.edit:SetText(full); Click("Preview import")
module.backupWindow.apply.scripts.OnClick(); local oldBackupApproval = approval
module:ShowPage("members"); module:OpenBackup(); oldBackupApproval()
check(module:Resolve("Main Person") == "Backup sentinel" and module.backupWindow.edit:GetText() == full
    and not module.backupWindow.apply:IsEnabled(), "backup text survives a page change but old import approval does not")
module:OpenNoteReview(true)
local proposal = assert(module.noteReview.proposals[1])
module.noteReview.selected[proposal.id] = true; module:RefreshNoteReview()
module.noteReview.apply.scripts.OnClick(); local oldNoteApproval = approval
local noteRevision = module.identityRevision
module:OpenHome(); module:OpenNoteReview(); oldNoteApproval()
check(module.identityRevision == noteRevision and module.noteReview.selected[proposal.id],
    "note selections survive a page change but the pending note approval is invalidated")
local delayedIndex = #roster+1
roster[delayedIndex] = { "Delayed-TestRealm", "Member", 1, 24, "Mage", "City", "Delayed - S/L", "", false, nil, "MAGE" }
module:OnEvent("GUILD_ROSTER_UPDATE")
local foundDelayed
for _, current in ipairs(module.noteReview.proposals) do if (current.id == "delayed") then foundDelayed = current end end
check(foundDelayed and not foundDelayed.ambiguous and module.noteReview.selected[proposal.id],
    "delayed roster response adds the new proposal and retains unchanged selections")
roster[delayedIndex] = nil; module:RequestRoster()
module.noteReview.apply.scripts.OnClick(); local oldGuildNoteApproval = approval
local originalGuildInfo = GetGuildInfo
GetGuildInfo = function() return "Different Guild" end
module:RequestRoster(); oldGuildNoteApproval()
check(module.identityRevision == noteRevision and not next(module.noteReview.selected), "guild change clears cached note choices and invalidates their approval")
GetGuildInfo = originalGuildInfo; module:RequestRoster()
module:OpenGuildActions(); actions.note:SetText("Cancelled by page change"); actions.noteApply.scripts.OnClick()
local oldActionApproval, writesBeforeSwitch = approval, #guildWrites
module:OpenHome(); module:OpenGuildActions(); oldActionApproval()
check(#guildWrites == writesBeforeSwitch, "leaving and reopening actions invalidates pending guild writes")
module:OpenSharing(); sharing.partner:SetText("Alt Person-TestRealm")
sharing.request.scripts.OnClick()
check(module.sharingReceive, "sharing fixture starts a captured receive session")
module:OpenHome()
check(not module.sharingReceive and not module.sharingIncoming and not sharing:IsShown(), "leaving sharing cancels its active session")
module:OpenCrafting(); crafting.search:SetText("")
crafting.rows[1].scripts.OnClick(); crafting.query.scripts.OnClick()
check(module.craftingPending, "crafting fixture starts a captured native query")
module:OpenHome()
check(not module.craftingPending, "leaving crafting cancels the pending query")
for _, page in pairs(module.pages) do
    if (page.viewport) then page.viewport:SetVerticalScroll(0) end
end
module:ToggleWindow()
check(not module.frame:IsShown(), "unified navigation checks leave the whole window closed")
module:ToggleWindow()
check(module.activePage == "home" and module.homeWindow:IsShown() and not module.memberPage:IsShown(), "reopening restores exactly the last page")
module:ToggleWindow()
ns.OptionsKit.Confirm = confirm

-- Optional snapshot records the real window's widget calls for an offline art/
-- layout preview. Native atlases are schematic in the Python renderer.
local getModule, pageGenerator = ns.GetModule
ns.GetModule = function(_, name)
    if (name == "Options") then return { AddGroup = function(_, _, generate) pageGenerator = generate end } end
    return module
end
assert(loadfile(root .. "/Options/OptionsPages/Guild.lua"))("Test", ns)
ns.GetModule = getModule
local guildOptions = pageGenerator()
local oldChatSetting = module.db.profile.chatNicknames
module:ToggleWindow(); module:ShowPage("members")
module.db.profile.chatNicknames = false
check(guildOptions.args.nicknameLevels.disabled(), "level option explains its dependency through disabled chat setting")
module.db.profile.chatNicknames = true
guildOptions.args.nicknameLevels.set(nil, true)
check(guildOptions.args.nicknameLevels.get() and module.nicknameLevels.check:IsShown(), "real options setter and guild toggle share profile state")
module.nicknameLevels.scripts.OnClick()
check(not guildOptions.args.nicknameLevels.get(), "guild level button updates the same options value")
module.db.profile.chatNicknames = oldChatSetting; module:UpdateSettings()
module:ToggleWindow()
-- Workflow controls: exercise actual callbacks, not a duplicate save model.
module:ToggleWindow(); module:ShowPage("members")
module.filters, module.memberSort = {}, nil; module.search:SetText("")
module:RefreshWindow()
module.classFilter:Fire("WARRIOR")
check(module.filters.class == "WARRIOR" and module.classFilter:GetValue() == "WARRIOR", "dropdown selects class directly without cycling")
module.rankFilter:Fire("Veteran")
check(module.filters.rank == "Veteran" and module.rankFilter:GetValue() == "Veteran", "rank dropdown retains a chosen rank")
local listUpdates = module.classFilter.listUpdates
module:RefreshWindow()
check(module.classFilter.listUpdates == listUpdates, "ordinary refresh does not rebuild or close an open unchanged dropdown")
module.classFilter:Activate(); module:OpenHome()
check(not ns.OptionsKit.Controls.IsDropdownOpen(), "leaving members closes the shared dropdown")
module:ShowPage("members"); module.classFilter:Fire(false); module.rankFilter:Fire(false)
check(not module.filters.class and not module.filters.rank, "All clears the filter instead of becoming a character class")
module.filters.rank = "Removed rank"; module:RefreshWindow()
check(not module.filters.rank and module.rankFilter:GetValue() == false, "roster changes clear a vanished filter before computing rows")

local savedMembers, savedCharacters = module.members, module.db.global.characters
local function SortMember(name, level, rankIndex, online, order)
    return { name = name .. "-TestRealm", rank = "Member", level = level, rankIndex = rankIndex,
        online = online, note = "", lastOnline = order and { order = order, years = 0, months = 0,
            days = math.floor(order/24), hours = order%24 } }
end
module.members = { ["alpha-testrealm"] = SortMember("Alpha", 40, 1, false, 192),
    ["alt-testrealm"] = SortMember("Alt", 10, 2, false, 2),
    ["beta-testrealm"] = SortMember("Beta", 60, 0, true),
    ["delta-testrealm"] = SortMember("Delta", 20, 2, false, 24),
    ["gamma-testrealm"] = SortMember("Gamma", nil, nil, false) }
module.db.global.characters = { ["alpha-testrealm"] = { name = "Alpha-TestRealm", nickname = "Zulu", favorite = true },
    ["alt-testrealm"] = { name = "Alt-TestRealm", main = "alpha-testrealm" } }
local function Sorted(field, descending)
    local rows = module:GetDisplayRows("", {}, {}, { field = field, descending = descending })
    local keys = {}; for _, row in ipairs(rows) do keys[#keys+1] = row.key end
    return table.concat(keys, ",")
end
check(Sorted("level", true) == "beta-testrealm,alpha-testrealm,delta-testrealm,gamma-testrealm", "level sort uses the main's displayed level and keeps unknown last")
check(Sorted("level", false) == "delta-testrealm,alpha-testrealm,beta-testrealm,gamma-testrealm", "ascending level sort still keeps unknown last")
check(Sorted("rank", false) == "beta-testrealm,alpha-testrealm,delta-testrealm,gamma-testrealm", "rank sort follows native zero-based rank order")
check(Sorted("name", false) == "beta-testrealm,delta-testrealm,gamma-testrealm,alpha-testrealm", "name sort follows visible person nicknames rather than hidden character names")
check(Sorted("lastOnline", false) == "beta-testrealm,alpha-testrealm,delta-testrealm,gamma-testrealm", "activity uses the most recent known alt and puts online people first")
check(Sorted("lastOnline", true) == "delta-testrealm,alpha-testrealm,beta-testrealm,gamma-testrealm", "reverse activity still keeps unknown durations last")
check(module:GetMemberSortValue({ level = secret }, "level") == nil
    and module:GetMemberSortValue({ level = 0/0 }, "level") == nil, "secret/nonfinite level sort values stay unknown")
local expandedSort = module:GetDisplayRows("", {}, { ["alpha-testrealm"] = true }, { field = "level", descending = false })
check(expandedSort[2].kind == "person" and expandedSort[3].key == "alpha-testrealm" and expandedSort[4].key == "alt-testrealm", "expanded characters stay together and main stays first")
module.members, module.db.global.characters = savedMembers, savedCharacters
module:RefreshWindow()
module.sortButtons.level.scripts.OnClick()
check(module.memberSort.field == "level" and module.memberSort.descending, "level heading starts highest-first")
module.sortButtons.level.scripts.OnClick()
check(not module.memberSort.descending, "clicking the same heading reverses sorting")
Click("Reset sort"); check(not module.memberSort, "reset restores favorites/online default order")

local workflowMain
for _, row in ipairs(module:GetRows("", true)) do if row.key == mainKey then workflowMain = row end end
module:SelectCharacter(assert(workflowMain), module:GetPeople("", {})[1])
do
    module.character:SetText("Valstad Hammerdin")
    module.nickname:SetText("Adam")
    module.main:SetText("Valstad Hammerdin")
    Click(NOTES or "Private note (only you)")
    module.privateNote:SetText("Officer draft")
    Click("Character")
    check(module:HasCardChanges() and module.nickname:GetText() == "Adam"
        and module.privateNote:GetText() == "Officer draft", "member tabs preserve the whole draft")
    module.saveIdentity.scripts.OnClick()
    local key = module:CharacterKey("Valstad Hammerdin")
    local saved = module.db.global.characters[key]
    check(saved and not saved.main and saved.nickname == "Adam" and saved.privateNote == "Officer draft",
        "entering Valstad Hammerdin as his own main saves Adam without a self-link")
    module:ReloadCard()
    check(module.main:GetText() == "Valstad Hammerdin" and not module:HasCardChanges(),
        "reopened main card displays its own name and is clean")
    check(module:UndoIdentity() and not module.db.global.characters[key], "self-main save is one undo step")
    module:SelectCharacter(workflowMain, module:GetPeople("", {})[1])
end
local savedNickname, savedRevision = module.nickname:GetText(), module.identityRevision
check(not module:HasCardChanges() and not module.saveIdentity:IsEnabled(), "fresh card has clean state and no redundant save")
module.nickname:SetText("Unsaved card edit")
check(module:HasCardChanges() and module.cardState:GetText() == "Unsaved changes" and module.saveIdentity:IsEnabled()
    and module.discardIdentity:IsEnabled() and not module.undo:IsEnabled(), "typing marks draft and separates discard from saved-data Undo")
module.expanded[mainKey] = true; module:RefreshWindow()
local otherRow = FindGuildRow(altKey, "character")
otherRow.scripts.OnClick(otherRow, "LeftButton")
check(module.selected == mainKey and module.nickname:GetText() == "Unsaved card edit", "another row cannot silently overwrite an unsaved card")
module:OpenHome(); module:ShowPage("members")
check(module:HasCardChanges() and module.nickname:GetText() == "Unsaved card edit", "page navigation retains draft and dirty state")
module.discardIdentity.scripts.OnClick()
check(not module:HasCardChanges() and module.nickname:GetText() == savedNickname and module.identityRevision == savedRevision,
    "discard restores saved fields without committing or adding Undo entries")
module.favorite.scripts.OnClick()
check(module:HasCardChanges(), "favorite belongs to the unsaved card state")
module.discardIdentity.scripts.OnClick()
module.privateNote:SetText("Uncommitted private draft")
check(module:HasCardChanges() and module.privateNote:GetHeight() >= 55, "dirty tracking retains the existing multiline sizing hook")
module.discardIdentity.scripts.OnClick()
module.expanded[mainKey] = true; module:RefreshWindow()
local altCard = FindGuildRow(altKey, "character")
module:SelectCharacter(altCard.data.row, altCard.data.person)
module.privateNote:SetText("Alt card draft")
local personHeading = FindGuildRow(mainKey, "person")
personHeading.scripts.OnClick(personHeading, "LeftButton")
check(module.selected == altKey and module.privateNote:GetText() == "Alt card draft", "folding an alt's person preserves its selected dirty card")
module.discardIdentity.scripts.OnClick()
module:SelectCharacter(workflowMain, module:GetPeople("", {})[1])
module.nickname:SetText("Saved workflow nickname"); module.saveIdentity.scripts.OnClick()
check(module:Resolve("Main Person") == "Saved workflow nickname" and not module:HasCardChanges(), "save commits the draft and clears its status")
module.undo.scripts.OnClick()
check(module.nickname:GetText() == savedNickname and not module:HasCardChanges(), "saved-data Undo remains distinct from discarding an editor draft")
local lostMembers, lostRecords = module.members, module.db.global.characters
module.members, module.db.global.characters = {}, {}
module.nickname:SetText("Draft for a removed selection"); module.discardIdentity.scripts.OnClick()
check(not module.selected and module.character:GetText() == "" and not module:HasCardChanges(),
    "discard can clear a vanished selection without trapping the editor in dirty state")
module.members, module.db.global.characters = lostMembers, lostRecords
module:SelectCharacter(workflowMain, module:GetPeople("", {})[1])

roster[#roster+1] = { "Workflow Unnamed-TestRealm", "Initiate", 4, 20, "Mage", "City", "", "", false, 0, "MAGE" }
module:RequestRoster()
local store, scope = module:GetFollowUpStore()
check(module:SaveFollowUpTask(mainKey, module.members[mainKey].name, "Dashboard due task", "", date("%Y-%m-%d"), scope, store.revision),
    "overview fixture creates an actual locally due task")
module:OpenHome()
local missingPeople = module:GetPeople("", { inGuild = true, missing = true })
local _, attentionCount = module:GetFollowUpItems("", "attention")
check(#missingPeople > 0 and module.homeWindow.missing.count:GetText() == tostring(#missingPeople)
    and attentionCount > 0 and module.homeWindow.attention.count:GetText() == tostring(attentionCount),
    "overview counters use actual missing people and due follow-up items")
do
    local display, group = module.GetDisplayRows, module.GetPeople
    local listCalls, groupCalls = 0, 0
    module.GetDisplayRows = function(...) listCalls = listCalls+1; return display(...) end
    module.GetPeople = function(...) groupCalls = groupCalls+1; return group(...) end
    module:RefreshWindow()
    check(listCalls == 0 and groupCalls == 1, "home refresh groups once and never builds hidden member rows")
    module:OpenHistory()
    check(listCalls == 0 and groupCalls == 1, "history refresh uses guild totals without building or sorting member lists")
    module.GetDisplayRows, module.GetPeople = display, group
    module:OpenHome()
    local favorites = module:GetPeople("", { inGuild = true, favorite = true })
    check(module.homeWindow.favorites.count:GetText() == tostring(#favorites), "favorites tile counts current guild people")
    module.homeWindow.favorites.scripts.OnClick()
    check(module.activePage == "members" and module.filters.inGuild and module.filters.favorite, "favorites tile opens its roster filter")
    module:OpenHome()
end
module.homeWindow.online.scripts.OnClick()
check(module.activePage == "members" and module.filters.online and module.filters.inGuild and module.search:GetText() == "", "online overview count opens a clean current-guild filter")
module:OpenHome(); module.homeWindow.missing.scripts.OnClick()
check(module.filters.missing and not module.filters.online and module.filters.inGuild, "missing-nickname count replaces prior filter rather than combining invisibly")
module:OpenHome(); module.homeWindow.attention.scripts.OnClick()
check(module.activePage == "followup" and follow.filterIndex == 1 and follow.search:GetText() == "", "attention overview count opens the due follow-up view")
module:UndoFollowUp(); table.remove(roster); module:RequestRoster()
module:ShowPage("members"); Click("Clear filters")
check(not next(module.filters) and module.search:GetText() == "", "clear filters restores saved-character visibility as well as class/rank/search")
do
    module:OpenHome()
    for index, target in ipairs({ "home", "history", "backup" }) do
        local tab = module.guildTabs[index]
        if index > 1 then module.navigation[target].open() end
        check(tab.selected and module.navigation[target]:IsShown(), "direct page opens its section " .. target)
        for _, button in pairs(module.navigation) do
            check(button:IsShown() == (button.group == tab), "rail shows only active section pages")
        end
    end
    local guildTab = module.guildTabs[1]
    guildTab.scripts.OnClick(guildTab)
    check(module.activePage == "home", "returning to a section restores its last page")
    module:ShowPage("members")
end

-- Inactive people, favorite arrivals, row tooltips and the public-note suggestion.
do
    local savedMembers, savedRecords, savedProfile = module.members, module.db.global.characters, module.db.profile.inactiveDays
    local savedPrint, savedSuspended, savedGuild = module.Print, module.suspended, module.rosterGuild
    module.suspended = nil
    local printed = {}
    module.Print = function(_, text) printed[#printed+1] = text end
    local function Member(name, online, days, note)
        return { name = name, rank = "Member", note = note or "", online = online, onlineKnown = true, class = "MAGE", level = 60,
            lastOnline = days and { years = 0, months = 0, days = days, hours = 0, order = days*24 } or nil }
    end
    local function Fixture()
        module.db.global.characters = {
            ["old main-testrealm"] = { name = "Old Main-TestRealm", nickname = "Sleeper" },
            ["old alt-testrealm"] = { name = "Old Alt-TestRealm", main = "old main-testrealm" },
            ["half-testrealm"] = { name = "Half-TestRealm", nickname = "Half" },
            ["half alt-testrealm"] = { name = "Half Alt-TestRealm", main = "half-testrealm" },
            ["fav main-testrealm"] = { name = "Fav Main-TestRealm", nickname = "Buddy", favorite = true, privateNote = string.rep("\195\169", 80) },
            ["fav alt-testrealm"] = { name = "Fav Alt-TestRealm", main = "fav main-testrealm" },
        }
        module.members = {
            ["old main-testrealm"] = Member("Old Main-TestRealm", false, 40),
            ["old alt-testrealm"] = Member("Old Alt-TestRealm", false, 31),
            ["half-testrealm"] = Member("Half-TestRealm", false, 50),
            ["half alt-testrealm"] = Member("Half Alt-TestRealm", false, nil),
            ["recent-testrealm"] = Member("Recent-TestRealm", false, 3),
            ["unknown-testrealm"] = Member("Unknown-TestRealm", false, nil),
            ["fav main-testrealm"] = Member("Fav Main-TestRealm", false, 1, "Buddy"),
            ["fav alt-testrealm"] = Member("Fav Alt-TestRealm", false, 1, "Buddy - alt"),
        }
    end
    Fixture()
    module.db.profile.inactiveDays = 30
    local inactive = module:GetPeople("", { inGuild = true, inactive = true })
    check(#inactive == 1 and inactive[1].key == "old main-testrealm",
        "only people whose every character is known offline 30+ days are inactive; an unknown alt keeps a person out")
    module.db.profile.inactiveDays = 35
    check(#module:GetPeople("", { inactive = true }) == 0, "the most recent character decides against a higher threshold")
    module.db.profile.inactiveDays = "bad"
    check(module:GetInactiveDays() == 30, "an invalid saved threshold falls back to 30 days")
    module.db.profile.inactiveDays = 30

    local function Snapshot()
        local copy = {}
        for key, member in pairs(module.members) do
            copy[key] = {}; for field, value in pairs(member) do copy[key][field] = value end
        end
        return copy
    end
    local previous = Snapshot()
    module.members["fav alt-testrealm"].online = true
    module:AnnounceFavorites(previous)
    check(#printed == 1 and printed[1] == "Buddy is online (Fav Alt).", "a favorite arriving on an alt is announced with that character")
    printed = {}
    module.members["fav main-testrealm"].online = true
    module:AnnounceFavorites(previous)
    check(#printed == 1, "two characters of one favorite arriving together give one line")
    printed = {}
    previous = Snapshot(); previous["fav alt-testrealm"].online = false
    module:AnnounceFavorites(previous)
    check(#printed == 0, "a favorite already online on another character is not announced again")
    previous["fav main-testrealm"].onlineKnown, previous["fav alt-testrealm"].onlineKnown = false, false
    module:AnnounceFavorites(previous)
    check(#printed == 0, "an unreadable earlier online state never announces")
    previous = Snapshot(); previous["fav main-testrealm"].online, previous["fav alt-testrealm"].online = false, false
    previous["fav alt-testrealm"] = nil
    module.members["fav main-testrealm"].online = false
    module:AnnounceFavorites(previous)
    check(#printed == 0, "a character missing from the earlier roster is not an arrival")
    module.members["old main-testrealm"].online = true
    previous = Snapshot(); previous["old main-testrealm"].online = false
    module:AnnounceFavorites(previous)
    check(#printed == 0, "people who are not favorites are not announced")
    module.members["fav main-testrealm"].online = true
    previous["fav main-testrealm"].online = false; previous["fav alt-testrealm"].online = false
    module.db.profile.favoriteAlerts = false
    module:AnnounceFavorites(previous)
    check(#printed == 0, "the setting turns announcements off")
    module.db.profile.favoriteAlerts = true
    -- Through ReadRoster: the real roster stub has Main Person online.
    module.db.global.characters["main person-testrealm"] = { name = "Main Person-TestRealm", nickname = "M", favorite = true }
    module.members, module.rosterGuild = { ["main person-testrealm"] = Member("Main Person-TestRealm", false, 1) }, "Test Guild"
    module:ReadRoster()
    check(#printed == 1 and printed[1] == "M is online (Main Person).", "a roster read announces a favorite who came online")
    printed = {}
    module.members, module.rosterGuild = { ["main person-testrealm"] = Member("Main Person-TestRealm", false, 1) }, "Other Guild"
    module:ReadRoster()
    check(#printed == 0, "the first roster of another guild announces nobody")
    module.members = nil; module:ReadRoster()
    check(#printed == 0, "the first roster after login announces nobody")

    Fixture()
    local lines = {}
    local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
    GameTooltip.AddLine = function(self, text) lines[#lines+1] = text; addLine(self, text) end
    GameTooltip.AddDoubleLine = function(_, left, right) lines[#lines+1] = left .. " | " .. right end
    local buddy
    for _, person in ipairs(module:GetPeople("", {})) do if (person.key == "fav main-testrealm") then buddy = person end end
    module:ShowRowTooltip({}, { kind = "person", key = buddy.key, person = buddy })
    local text, privateLine = table.concat(lines, "\n")
    for _, line in ipairs(lines) do if (line:find("^Private note")) then privateLine = line end end
    check(text:find("Buddy", 1, true) and text:find("Main character: Fav Main-TestRealm", 1, true)
        and text:find("Fav Alt-TestRealm | Level 60", 1, true) and text:find("Fav Main-TestRealm (Main) |", 1, true)
        and text:find("Guild note: Buddy", 1, true), "a person row lists nickname, main, each character and the guild note")
    check(privateLine and privateLine:find("\195\169%.%.%.$"), "a long private note is shortened without splitting a character")
    lines = {}
    module:ShowRowTooltip({}, { kind = "character", key = "fav alt-testrealm", person = buddy, row = buddy.rows[2] })
    check(table.concat(lines, "\n"):find("Alt: Buddy", 1, true), "a character row names the person it belongs to")
    GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble

    check(module:SuggestPublicNote("fav main-testrealm") == "Buddy" and module:SuggestPublicNote("fav alt-testrealm") == "Buddy - alt"
        and not module:SuggestPublicNote("recent-testrealm") and not module:SuggestPublicNote("missing-testrealm"),
        "the suggested note is the nickname for a main and nickname - alt for an alt")
    local _, _, matching = module:BuildNoteSuggestions()
    local proposals = module:BuildNoteSuggestions()
    local buddyProposal
    for _, proposal in ipairs(proposals) do if (proposal.id == "buddy") then buddyProposal = proposal end end
    check(matching >= 1 and not buddyProposal, "suggested notes read back as an already matching group")
    module.db.global.characters["fav main-testrealm"].nickname = string.rep("a", 28)
    check(module:SuggestPublicNote("fav alt-testrealm") == string.rep("a", 28), "a suggestion over 31 letters falls back to the nickname")

    module.members, module.db.global.characters, module.db.profile.inactiveDays = savedMembers, savedRecords, savedProfile
    module.Print, module.suspended, module.rosterGuild = savedPrint, savedSuspended, savedGuild
end
module:ToggleWindow()
if arg[2] then
    module:ToggleWindow()
    module:SaveIdentity("Main Person", "Junnez", "")
    module:SetPersonDetails("Main Person", true, "Main tank. Alts samlet under samme navn.")
    for i, entry in ipairs({ {"Steve", "MAGE", "Officer"}, {"Jador", "PALADIN", "Officer"}, {"Guimert", "WARRIOR", "Veteran"},
        {"Andre", "HUNTER", "Member"}, {"Saky", "PRIEST", "Initiate"}, {"Shin", "WARLOCK", "Officer"}, {"Lew", "ROGUE", "Member"} }) do
        local name = entry[1] .. " Example-TestRealm"; local key = module:CharacterKey(name)
        module.members[key] = { name = name, class = entry[2], rank = entry[3], level = 60-i*3,
            zone = "Tanaris", note = entry[1] .. " - S/L", online = i < 4 }
        module:SaveIdentity(name, entry[1], "")
    end
    module.expanded[module:CharacterKey("Main Person")] = true
    module:ReloadCard(); module:RefreshWindow()
    module:ShowPage("members")
    if arg[3] == "dirty" then module.nickname:SetText("Junnez - draft")
    elseif arg[3] == "member-notes" then Click(NOTES or "Private note (only you)")
    elseif arg[3] == "level-sort" then module:SetMemberSort("level")
    elseif arg[3] == "notes" then
        -- Keep this fixture's sample roster rather than requesting the stub's
        -- original two-member roster when opening the review.
        local request = module.RequestRoster; module.RequestRoster = function() end
        module:OpenNoteReview(); module.RequestRoster = request
    elseif arg[3] == "backup" then module:OpenBackup(); Click("Generate export")
    elseif arg[3] == "home" then module:ShowPage("home"); module:RefreshHome()
    elseif arg[3] == "history" then module:OpenHistory(); module.historyWindow.unreadOnly = false; module:RefreshHistory()
    elseif arg[3] == "followup" then
        module:OpenFollowUp()
        local w = module.followUpWindow
        w.trialStart:SetText("2026-11-01"); w.trialEnd:SetText("2026-11-15"); w.saveSchedule.scripts.OnClick()
        w.newTask.scripts.OnClick(); w.taskTitle:SetText("Review raid role and welcome the new member")
        w.owner:SetText("Officer Steve"); w.due:SetText("2026-11-16"); w.saveTask.scripts.OnClick()
        w.filterIndex = 3; module:RefreshFollowUp()
    elseif arg[3] == "actions" then module:OpenGuildActions()
    elseif arg[3] == "sharing" then
        module:OpenSharing(); sharing.partner:SetText("Alt Person-TestRealm")
        module.sharingIncoming = FixtureIncoming(); module:SharingStatus("Transfer received. Review every page before importing.")
    elseif arg[3] == "crafting" then
        module:OpenCrafting(); crafting.search:SetText(""); crafting.rows[1].scripts.OnClick()
    elseif arg[3] == "crafting-transfer" then
        module:OpenCrafting(); crafting.search:SetText(""); crafting.rows[1].scripts.OnClick()
        module:OpenCraftingTransfer(crafting.selected); Click("Preview recipe list")
    end
    if (arg[4] == "bottom") then
        local page = module.pages[module.activePage]
        if (page.viewport) then page.viewport:SetVerticalScroll(page.viewport:GetVerticalScrollRange()) end
    end
    local function quote(value)
        return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    end
    local function array(values)
        if not values then return "null" end
        local out = {}; for _, value in ipairs(values) do out[#out+1] = tostring(value) end
        return "[" .. table.concat(out, ",") .. "]"
    end
    local output = assert(io.open(arg[2], "w"))
    output:write("[")
    for i, w in ipairs(frames) do
        if i > 1 then output:write(",") end
        output:write('{"id":' .. w.id .. ',"parent":' .. (w.parent and w.parent.id or 0)
            .. ',"relative":' .. (w.relative and w.relative.id or 0) .. ',"fill":' .. (w.fill and w.fill.id or 0)
            .. ',"kind":' .. quote(w.kind or "") .. ',"name":' .. quote(w.name or "")
            .. ',"text":' .. quote(w.text) .. ',"point":' .. quote(w.point or "TOPLEFT")
            .. ',"relativePoint":' .. quote(w.relativePoint or w.point or "TOPLEFT")
            .. ',"x":' .. (w.x or 0) .. ',"y":' .. (w.y or 0) .. ',"w":' .. (w.w or 0) .. ',"h":' .. (w.h or 0)
            .. ',"font":' .. (w.fontSize or 12) .. ',"lines":' .. (w.lines or 1) .. ',"shown":' .. tostring(w.shown)
            .. ',"texture":' .. quote(w.texture or "") .. ',"atlas":' .. quote(w.atlas or "")
            .. ',"color":' .. array(w.color) .. ',"textColor":' .. array(w.textColor)
            .. ',"bgColor":' .. array(w.bgColor) .. ',"borderColor":' .. array(w.borderColor) .. ',"uv":' .. array(w.uv)
            .. ',"insets":' .. array(w.insets) .. ',"vertexColor":' .. array(w.vertexColor) .. ',"desaturated":' .. tostring(w.desaturated or false)
            .. ',"backdropTexture":' .. quote(w.backdrop and w.backdrop.bgFile or "")
            .. ',"clips":' .. tostring(w.clips or false) .. ',"scroll":' .. (w.scroll or 0)
            .. ',"scrollOwner":' .. (w.scrollOwner and w.scrollOwner.id or 0)
            .. ',"justifyH":' .. quote(w.justifyH or "LEFT") .. '}')
    end
    output:write("]"); output:close()
end
print("Guild manager: " .. checks .. " checks passed")

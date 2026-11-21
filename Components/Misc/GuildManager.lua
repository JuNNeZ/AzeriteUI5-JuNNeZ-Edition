-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:NewModule("GuildManager", "LibMoreEvents-1.0", "AceConsole-3.0")
local defaults = { profile = { enabled = true, chatNicknames = false, nicknameLevels = false, tooltipNicknames = true, favoriteAlerts = true, inactiveDays = 30,
    blizzardGuildKey = false, toggleKey = false,
    guildFormat = "nickname", groupFormat = "nickname", whisperFormat = "nickname", otherFormat = "nickname"
}, global = { characters = {}, guildHistory = {}, followUps = {}, crafting = {} } }

-- Names may contain spaces on Forever. Only the realm loses spaces/hyphens.
local function Text(value)
    if (issecretvalue and issecretvalue(value)) then return end
    if (type(value) == "string") then return value end
end
Guild.ReadText = Text
local PLAYER_CHAT = { GUILD = true, OFFICER = true, SAY = true, YELL = true, EMOTE = true, TEXT_EMOTE = true,
    WHISPER = true, WHISPER_INFORM = true, PARTY = true, PARTY_LEADER = true, RAID = true, RAID_LEADER = true,
    RAID_WARNING = true, INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true, CHANNEL = true }
local function RealmKey(value)
    value = Text(value)
    return value and string.lower((value:gsub("[%s%-]", "")))
end
local function SavedGuildRealm(self, guildName)
    local playerName = UnitName and Text(UnitName("player"))
    if (not guildName or not playerName or playerName == "") then return end
    guildName, playerName = string.lower(guildName), string.lower(playerName)
    local realm
    for key, history in pairs(self.db.global.guildHistory) do
        local scope, guild = key:match("^([^:]+):(.+)$")
        if (guild == guildName and history.members and history.members[playerName .. "-" .. RealmKey(scope)]) then
            if (realm and realm ~= scope) then return end
            realm = scope
        end
    end
    return realm
end
Guild.RefreshRealm = function(self)
    local previous, changed = self.realm, false
    local normalized = GetNormalizedRealmName and Text(GetNormalizedRealmName())
    local display = GetRealmName and Text(GetRealmName())
    -- Keep the first usable canonical realm stable for saved identities, while
    -- learning the current server's explicit normalized/display aliases.
    if (not self.realm or self.realm == "") then
        if (normalized and normalized ~= "") then self.realm = normalized
        elseif (display and display ~= "") then self.realm = display
        elseif (ns.IsForever and self.db and (normalized == "" or display == "") and (not IsLoggedIn or IsLoggedIn())) then
            -- Local identity scope for clients that no longer expose realm names.
            local inGuild = IsInGuild()
            local guildName = inGuild and Text(GetGuildInfo("player"))
            if (not inGuild or guildName and guildName ~= "") then
                self.realm = SavedGuildRealm(self, guildName) or "Forever"
            end
        end
    end
    self.realmAliases = self.realmAliases or {}
    for _, value in ipairs({ normalized or "", display or "", self.realm or "" }) do
        local key = RealmKey(value)
        if (key and key ~= "" and not self.realmAliases[key]) then self.realmAliases[key], changed = true, true end
    end
    return changed or previous ~= self.realm
end
local function Number(value)
    if (issecretvalue and issecretvalue(value)) then return end
    if (type(value) == "number" and value == value and value >= 0 and value < math.huge) then return value end
end

Guild.ReadLastOnline = function(self, index)
    if (not GetGuildRosterLastOnline) then return end
    local years, months, days, hours = GetGuildRosterLastOnline(index)
    years, months, days, hours = Number(years), Number(months), Number(days), Number(hours)
    if (years and months and days and hours) then
        -- Relative, rounded server data; this is not an exact login timestamp.
        return { years = years, months = months, days = days, hours = hours,
            order = ((years*12+months)*31+days)*24+hours }
    end
end

Guild.ReadGuildDetails = function(self)
    if (not IsInGuild()) then self.guildDetails, self.guildDetailsPending = {}, nil; return end
    local name = Text(GetGuildInfo("player"))
    -- Forever blocks these restricted metadata getters in combat. Preserve the
    -- last known text only for this same guild, then retry after combat.
    if (not self.guildDetails or self.guildDetails.name ~= name) then self.guildDetails = { name = name } end
    if (InCombatLockdown()) then self.guildDetailsPending = true; return end
    self.guildDetails, self.guildDetailsPending = { name = name }, nil
    if (not C_GuildInfo) then return end
    self.guildDetails.motd = C_GuildInfo.GetMOTD and Text(C_GuildInfo.GetMOTD())
    self.guildDetails.info = C_GuildInfo.GetInfoText and Text(C_GuildInfo.GetInfoText())
end

Guild.CharacterKey = function(self, name)
    name = Text(name)
    if (not name) then return end
    name = name:match("^%s*(.-)%s*$")
    if (name == "" or #name > 160 or name:find("[|:%c%[%]]")) then return end
    local character, realm = name:match("^([^-]+)%-(.+)$")
    if (name:find("-", 1, true) and not character) then return end
    character, realm = character or name, realm or self.realm
    if (not realm or realm == "" or character:find("^%s*$")) then return end
    character, realm = character:match("^%s*(.-)%s*$"), realm:gsub("[%s%-]", "")
    if (realm == "") then return end
    if (self.realmAliases and self.realmAliases[string.lower(realm)] and self.realm) then
        realm = self.realm:gsub("[%s%-]", "")
    end
    return string.lower(character .. "-" .. realm)
end

Guild.QualifiedRecordName = function(self, key, name)
    if (not Text(name) or name:find("-", 1, true)) then return name end
    local realm = key:match("%-([^-]+)$")
    return realm and name .. "-" .. realm or name
end

Guild.Resolve = function(self, name)
    local key = self:CharacterKey(name)
    if (not key) then return end
    local records, seen, linked = self.db.global.characters, {}, false
    while (key and not seen[key]) do
        seen[key] = true
        local record = records[key]
        if (not record) then return nil, key end
        if (record.main) then
            linked = true
            key = record.main
        else
            local nickname = Text(record.nickname)
            if (not nickname and linked) then
                local name = Text(record.name)
                nickname = name and name:match("^([^-]+)")
            end
            return nickname, key
        end
    end
    -- Corrupt/cyclic saved data never substitutes an arbitrary name.
end

Guild.SaveIdentity = function(self, name, nickname, main, defer)
    local key = self:CharacterKey(name)
    nickname, main = Text(nickname), Text(main)
    if (not key or not nickname or not main) then return false end
    nickname, main = nickname:match("^%s*(.-)%s*$"), main:match("^%s*(.-)%s*$")
    if (#nickname > 48 or nickname:find("[|%c]")) then return false end
    local target = main ~= "" and self:CharacterKey(main) or nil
    if (main ~= "" and not target) then return false end
    local records, seen = self:CopyRecords(), { [key] = true }
    local cursor = target
    while (cursor) do
        if (seen[cursor]) then return false end
        seen[cursor] = true
        cursor = records[cursor] and records[cursor].main
    end
    -- Alt rows inherit the main's nickname; an empty main removes that link.
    if (target and not records[target]) then records[target] = { name = main } end
    local record = records[key] or {}
    record.name, record.nickname, record.main = name, not target and nickname ~= "" and nickname or nil, target
    records[key] = record
    if (defer) then return records end
    self:CommitRecords(records, "identity")
    return true
end

Guild.ForgetIdentity = function(self, name)
    local key = self:CharacterKey(name)
    if (key) then
        local records = self:CopyRecords()
        records[key] = nil
        self:CommitRecords(records, "remove")
    end
end

-- Suggestions only: free-form notes must never silently become identities.
Guild.NoteCandidate = function(self, note)
    note = Text(note)
    if (not note) then return end
    local candidate = note:match("^%s*([^%s,;:/%(%)%-]+)")
    if (candidate and #candidate >= 2 and #candidate <= 48
        and not candidate:find("[%d%p%c]") and candidate:find("[%a\128-\255]")) then
        return candidate
    end
end

Guild.ReadRoster = function(self)
    local previous, previousGuild = self.members, self.rosterGuild
    self.members = {}
    self:ReadGuildDetails()
    self.rosterGuild = IsInGuild() and Text(GetGuildInfo("player")) or nil
    if (not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo) then return end
    local count = GetNumGuildMembers()
    if ((issecretvalue and issecretvalue(count)) or type(count) ~= "number") then return end
    for index = 1, count do
        local name, rank, rankIndex, level, className, zone, note, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(index)
        local key = self:CharacterKey(name)
        if (key) then
            self.members[key] = {
                name = name, guid = Text(guid), rank = Text(rank) or "", rankIndex = Number(rankIndex), note = Text(note) or "",
                zone = Text(zone) or "", class = Text(class), className = Text(className) or "",
                level = not (issecretvalue and issecretvalue(level)) and type(level) == "number" and level or 0,
                online = not (issecretvalue and issecretvalue(online)) and online == true,
                onlineKnown = not (issecretvalue and issecretvalue(online)) and type(online) == "boolean",
                observed = { rank = Text(rank), note = Text(note), level = Number(level) },
                lastOnline = self:ReadLastOnline(index)
            }
        end
    end
    if (previous and next(previous) and self.rosterGuild and self.rosterGuild == previousGuild) then
        self:AnnounceFavorites(previous)
    end
end

-- A favorite person coming online, on any of their characters. Only a readable
-- offline -> online change of a character present in both rosters counts, so
-- the first roster, partial rosters and guild changes never announce anyone.
Guild.AnnounceFavorites = function(self, previous)
    local profile = self.db.profile
    if (self.suspended or not profile.enabled or not profile.favoriteAlerts) then return end
    local records, wasOnline, arrivals = self.db.global.characters, {}, {}
    for key, member in pairs(previous) do
        if (member.online) then
            local _, root = self:Resolve(member.name)
            wasOnline[root or key] = true
        end
    end
    for key, member in pairs(self.members) do
        local before = previous[key]
        if (member.online and member.onlineKnown and before and before.onlineKnown and not before.online) then
            local nickname, root = self:Resolve(member.name)
            root = root or key
            local record = records[root]
            if (record and record.favorite and not wasOnline[root] and not arrivals[root]) then
                arrivals[root] = true
                local character = member.name:match("^([^-]+)") or member.name
                local label = nickname or (Text(record.name) or character):match("^([^-]+)")
                local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
                self:Print(label == character and string.format(L["%s is online."], label)
                    or string.format(L["%s is online (%s)."], label, character))
            end
        end
    end
end

-- Blank realms on Forever led to a second identity for bare names. Returns
-- { [oldKey] = { current = liveKey, hidden = bool } } for saved records that
-- are provably the same character as a live roster member: saved with the bare
-- name, or listed under that key in this guild's earlier history. `hidden`
-- (the roster shows only the live row) also needs a saved live identity.
Guild.FindRealmDuplicates = function(self)
    local found = {}
    if (not ns.IsForever) then return found end
    local members, records = self.members or {}, self.db.global.characters
    local guildName = self.guildDetails and self.guildDetails.name
    local previousMembers = {}
    if (guildName and self.realm) then
        guildName = string.lower(guildName)
        for scope, history in pairs(self.db.global.guildHistory) do
            local realm, guild = scope:match("^([^:]+):(.+)$")
            if (guild == guildName and history.members and (RealmKey(realm) == "forever" or RealmKey(self.realm) == "forever")) then
                previousMembers[#previousMembers+1] = history.members
            end
        end
    end
    for key, record in pairs(records) do
        local name = Text(record.name)
        if (not members[key] and name) then
            local bareName = name:match("^([^-]+)")
            local bareKey = self:CharacterKey(bareName)
            local current = bareKey and members[bareKey]
            if (current and bareKey ~= key and not current.name:find("-", 1, true)
                and (key:match("%-forever$") or bareKey:match("%-forever$"))) then
                local evidence = bareName == name
                for _, history in ipairs(previousMembers) do
                    if (history[key]) then evidence = true; break end
                end
                if (evidence) then found[key] = { current = bareKey, hidden = records[bareKey] ~= nil } end
            end
        end
    end
    return found
end

Guild.GetRows = function(self, search, offline)
    local rows, included = {}, {}
    search = string.lower(search or "")
    local function Add(key, member)
        if (not offline and not member.online) then return end
        local nickname, root = self:Resolve(member.name)
        local record = self.db.global.characters[root or key]
        local main = record and record.name or root or ""
        local haystack = table.concat({ member.name, member.rank or "", member.note or "", member.zone or "",
            member.className or "", nickname or "", main }, " ")
        if (search ~= "" and not string.lower(haystack):find(search, 1, true)) then return end
        rows[#rows+1] = { key = key, member = member, nickname = nickname, main = main }
    end
    local members, records = self.members or {}, self.db.global.characters
    for key, member in pairs(members) do included[key] = true; Add(key, member) end
    local duplicates = self:FindRealmDuplicates()
    -- Keep manually entered non-guild characters editable too.
    for key, record in pairs(records) do
        if (not included[key] and Text(record.name)) then
            local currentKey = self:CharacterKey(record.name)
            -- Keep the saved record, but use the live row when it has its own identity.
            local duplicate = duplicates[key]
            if (not (duplicate and duplicate.hidden)) then
                local name = currentKey == key and record.name or self:QualifiedRecordName(key, record.name)
                Add(key, { name = name, saved = true })
            end
        end
    end
    table.sort(rows, function(a, b)
        local aOnline, bOnline = a.member.online == true, b.member.online == true
        if (aOnline ~= bOnline) then return aOnline end
        return a.key < b.key
    end)
    return rows
end

Guild.ModifyMessage = function(self, data)
    if (not self.db.profile.enabled or not self.db.profile.chatNicknames) then return end
    self.chatStats = self.chatStats or { calls = 0, guildCalls = 0, replacements = 0, links = 0, known = 0 }
    local stats = self.chatStats
    stats.calls = stats.calls+1
    if (type(data) ~= "table" or type(data.typeInfo) ~= "table") then return end
    local info = data.typeInfo
    if (Text(info.type) == "GUILD" or Text(info.event) == "CHAT_MSG_GUILD") then stats.guildCalls = stats.guildCalls+1 end
    local text = Text(data.text)
    local player = data.typeInfo.player
    if (issecretvalue and (issecretvalue(player) or type(player) == "table" and issecretvalue(player.name))) then return end
    if (not self.realm or self.realm == "") then self:RefreshRealm() end
    local name = type(player) == "table" and Text(player.name) or Text(player)
    local sender = self:CharacterKey(name)
    local kind, event = Text(info.type), Text(info.event)
    local ordinaryChat = event and PLAYER_CHAT[event:match("^CHAT_MSG_(.+)$")] or not event and PLAYER_CHAT[kind]
    if (not ordinaryChat and (kind and kind ~= "" or event and event ~= "")) then return end
    if (not text or not sender and not ordinaryChat) then return end
    local mode = self:GetChatFormat(data.typeInfo)
    if (mode == "original") then return end
    -- Only the first player hyperlink (the sender), never names in the body.
    -- Preserve its destination and any leading class colour, replace its label.
    data.text = text:gsub("(|Hplayer:)([^:|]+)([^|]*|h)(.-)(|h)", function(prefix, name, payload, label, closing)
        local original = prefix .. name .. payload .. label .. closing
        local linkKey = self:CharacterKey(name)
        if (not linkKey or not ordinaryChat and linkKey ~= sender) then return original end
        stats.links = (stats.links or 0)+1
        -- Chattynator metadata is for filtering and may be shortened/decorated.
        -- Its ordinary player-chat formatter puts the actual sender link first.
        local nickname = self:Resolve(name)
        if (not nickname or nickname == "" or nickname:find("[|%c]")) then return original end
        stats.known = (stats.known or 0)+1
        local color = label:match("|c%x%x%x%x%x%x%x%x")
        local brackets = label:find("[", 1, true)
        local character = name:match("^([^-]+)") or name
        local displayName = mode == "both" and (nickname .. " (" .. character .. ")") or nickname
        if (self.db.profile.nicknameLevels) then
            -- Message-time metadata is for the speaking character, never its
            -- linked main. Older/provider-decorated metadata may only leave a
            -- readable level prefix in the existing sender label.
            local level = sender == linkKey and type(player) == "table" and Number(player.level) or nil
            if (not level) then
                local plain = label:gsub("^%[", ""):gsub("^|c%x%x%x%x%x%x%x%x", "")
                level = Number(tonumber(plain:match("^(%d%d?%d?):")))
            end
            -- Bounded display input, not a claim about either client's cap.
            if (level and level >= 1 and level < 1000 and level%1 == 0) then
                displayName = string.format("%d:", level) .. displayName
            end
        end
        local display = (brackets and "[" or "") .. (color or "") .. displayName
            .. (color and "|r" or "") .. (brackets and "]" or "")
        return prefix .. name .. payload .. display .. closing
    end, 1)
    if (data.text ~= text) then stats.replacements = stats.replacements+1 end
end

Guild.GetChatDiagnostic = function(self)
    local stats = self.chatStats or {}
    local records = 0; for _ in pairs(self.db.global.characters) do records = records+1 end
    return string.format("Nicknames=%s; guildFormat=%s; API attached=%s; callbacks=%d; guildCallbacks=%d; replacements=%d; senderLinks=%d; known=%d; records=%d; realm=%s; liveRealm=%s",
        tostring(self.db.profile.enabled and self.db.profile.chatNicknames and not self.suspended or false),
        self:GetChatFormat({ type = "GUILD" }), tostring(self.chatAPI ~= nil),
        stats.calls or 0, stats.guildCalls or 0, stats.replacements or 0, stats.links or 0, stats.known or 0, records,
        self.realm or "unknown", GetNormalizedRealmName and Text(GetNormalizedRealmName()) or "unknown")
end

Guild.UpdateSettings = function(self)
    if (self.CancelSharing) then self:CancelSharing() end
    if (self.CancelCraftingQuery) then self:CancelCraftingQuery() end
    local api = _G.Chattynator and _G.Chattynator.API
    -- Remove/add through the public API also clears Chattynator's display cache.
    if (self.chatAPI and self.modifier) then self.chatAPI.RemoveModifier(self.modifier); self.chatAPI = nil end
    if (not self.suspended and self.db.profile.enabled and self.db.profile.chatNicknames
        and api and type(api.AddModifier) == "function" and type(api.RemoveModifier) == "function") then
        self.modifier = self.modifier or function(data) self:ModifyMessage(data) end
        api.AddModifier(self.modifier)
        self.chatAPI = api
    end
    self:UpdateBindings()
    if (self.RefreshWindow) then self:RefreshWindow() end
end

-- Keys open the overview through override bindings owned by a plain button.
-- Nothing here calls SetBinding: the player's saved bindings never change, and
-- clearing the overrides hands Blizzard's guild key straight back.
local function ValidKey(value)
    value = Text(value)
    if (value and value ~= "" and #value <= 64 and not value:find("[%s|%c]")) then return value end
end
Guild.UpdateBindings = function(self)
    if (not CreateFrame or not ClearOverrideBindings or not SetOverrideBindingClick or not GetBindingKey) then return end
    if (self.applyingBindings) then return end
    -- Override bindings are protected in combat; apply when it ends.
    if (InCombatLockdown()) then self.bindingsPending = true; return end
    self.bindingsPending = nil
    if (not self.toggleButton) then
        if (not self.db or not (self.db.profile.blizzardGuildKey or ValidKey(self.db.profile.toggleKey))) then return end
        self.toggleButtonName = (Addon or "AzeriteUI") .. "GuildManagerToggle"
        self.toggleButton = CreateFrame("Button", self.toggleButtonName, UIParent)
        self.toggleButton:SetScript("OnClick", function() self:ToggleWindow() end)
    end
    self.applyingBindings = true
    local owner, name = self.toggleButton, self.toggleButtonName
    ClearOverrideBindings(owner)
    local profile = self.db and self.db.profile
    if (profile and profile.enabled and not self.suspended) then
        if (profile.blizzardGuildKey) then
            -- Read after clearing, so these are the player's own keys.
            local keys = { GetBindingKey("TOGGLEGUILDTAB") }
            for _, key in ipairs(keys) do
                key = ValidKey(key)
                if (key) then SetOverrideBindingClick(owner, false, key, name) end
            end
        end
        local key = ValidKey(profile.toggleKey)
        if (key) then SetOverrideBindingClick(owner, false, key, name) end
    end
    self.applyingBindings = nil
end

Guild.RequestRoster = function(self)
    local realmChanged = self:RefreshRealm()
    if (IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster) then C_GuildInfo.GuildRoster() end
    self:ReadRoster()
    if (realmChanged) then self:UpdateSettings()
    elseif (self.RefreshWindow) then self:RefreshWindow() end
end

Guild.OnEvent = function(self, event, addon, reloading)
    if (event == "ADDON_LOADED") then
        if (addon == "Chattynator") then self:UpdateSettings() end
    elseif (event == "PLAYER_LOGIN" or event == "PLAYER_GUILD_UPDATE") then
        if (self.CancelSharing) then self:CancelSharing() end
        self:RefreshRealm()
        self:RequestRoster()
        if (self.ObserveGuildAction) then self:ObserveGuildAction() end
        self:UpdateSettings()
    elseif (event == "GUILD_ROSTER_UPDATE") then
        local realmChanged = self:RefreshRealm()
        self:ReadRoster()
        self:CaptureGuildHistory()
        if (self.noteReview and self.noteReview.awaitingRoster) then
            self.noteReview.awaitingRoster = nil
            self:ScanNoteReview(true)
        end
        if (self.ObserveGuildAction) then self:ObserveGuildAction() end
        if (realmChanged) then self:UpdateSettings()
        elseif (self.RefreshWindow) then self:RefreshWindow() end
    elseif (event == "PLAYER_ENTERING_WORLD" and (addon or reloading)) then
        self:RefreshRealm()
        -- Reattach after all addons have finished their login initialization.
        self:UpdateSettings()
    elseif (event == "GUILD_MOTD") then
        self:ReadGuildDetails()
        self:CaptureGuildHistory(true)
        if (self.RefreshWindow) then self:RefreshWindow() end
    elseif (event == "GUILD_RANKS_UPDATE") then
        if (self.RefreshWindow) then self:RefreshWindow() end
    elseif (event == "UPDATE_BINDINGS") then
        -- The player may have moved Blizzard's guild key.
        self:UpdateBindings()
    elseif (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED") then
        if (event == "PLAYER_REGEN_ENABLED" and self.bindingsPending) then self:UpdateBindings() end
        if (event == "PLAYER_REGEN_DISABLED" and self.CancelSharing) then self:CancelSharing() end
        if (event == "PLAYER_REGEN_DISABLED" and self.CancelCraftingQuery) then self:CancelCraftingQuery() end
        if (event == "PLAYER_REGEN_ENABLED" and self.guildDetailsPending) then
            self:ReadGuildDetails()
            self:CaptureGuildHistory(true)
        end
        if (event == "PLAYER_REGEN_ENABLED" and self.pendingGuildAction) then self:RequestRoster() end
        if (self.RefreshWindow) then self:RefreshWindow() end
    end
end

Guild.OnInitialize = function(self)
    self.db = ns.db:RegisterNamespace("GuildManager", defaults)
    self:RefreshRealm()
    -- Personal names never travel with exported UI profiles.
    self:DisableSettingsExport()
    self.db.RegisterCallback(self, "OnProfileChanged", "UpdateSettings")
    self.db.RegisterCallback(self, "OnProfileCopied", "UpdateSettings")
    self.db.RegisterCallback(self, "OnProfileReset", "UpdateSettings")
end

Guild.OnEnable = function(self)
    self.suspended = nil
    if (self.InitializeSharing) then self:InitializeSharing() end
    if (self.OnCraftingQuery) then self:RegisterEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS", "OnCraftingQuery") end
    self:RegisterChatCommand("azguild", "ToggleWindow")
    if (self.HookTooltips) then self:HookTooltips() end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "GUILD_RANKS_UPDATE", "GUILD_MOTD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_BINDINGS" }) do
        self:RegisterEvent(event, "OnEvent")
    end
    self:RequestRoster()
    self:UpdateSettings()
end

Guild.OnDisable = function(self)
    self.suspended = true
    self:UpdateSettings()
    if (self.frame) then self.frame:Hide() end
end

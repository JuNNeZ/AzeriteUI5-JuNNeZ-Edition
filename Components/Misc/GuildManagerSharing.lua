-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local PREFIX, CHUNK, MAX_PARTS, TTL = "AZGuildShare1", 200, 320, 300

-- One explicitly selected partner and one bounded transfer per open window.
-- Use CTL for throttling, but own the bounded reassembler rather than AceComm's
-- unlimited multipart spool. Nothing received here writes saved data.
Guild.GetSharingContext = function(self, name)
    if (self.suspended or not self.db.profile.enabled or InCombatLockdown() or not IsInGuild()) then return end
    local guild, key = self.ReadText(GetGuildInfo("player")), self:CharacterKey(name)
    local actor = self.ReadText(UnitGUID("player"))
    if (not guild or guild == "" or not key or not self.realm or not actor or actor == "") then return end
    local count = GetNumGuildMembers()
    if (issecretvalue and issecretvalue(count) or type(count) ~= "number" or count < 1 or count > 2000) then return end
    local members, peer = {}
    for index = 1, count do
        local character, _, _, _, _, _, _, _, online, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(index)
        local id = self:CharacterKey(character)
        guid = self.ReadText(guid)
        if (id and guid and guid ~= "") then
            local member = { name = character, guid = guid, online = not (issecretvalue and issecretvalue(online)) and online == true }
            members[id] = member
            if (id == key) then peer = member end
        end
    end
    if (not peer or not peer.online or peer.guid == actor) then return end
    return { guild = self.realm .. ":" .. guild, key = key, guid = peer.guid, name = peer.name,
        actor = actor, members = members, profile = self.db.profile, expires = GetTime()+TTL }
end

Guild.SharingContextMatches = function(self, context)
    if (not context or GetTime() >= context.expires or context.profile ~= self.db.profile) then return end
    local live = self:GetSharingContext(context.name)
    if (live and live.guild == context.guild and live.key == context.key and live.guid == context.guid and live.actor == context.actor) then return live end
end

Guild.SharingStatus = function(self, message)
    self.sharingStatus = message
    if (self.RefreshSharing) then self:RefreshSharing() end
end

Guild.CancelSharing = function(self)
    self.sharingReceive, self.sharingRequest, self.sharingSend, self.sharingIncoming = nil, nil, nil, nil
    self.sharingStatus = nil
    if (self.RefreshSharing) then self:RefreshSharing() end
end

Guild.InitializeSharing = function(self)
    if (self.sharingRegistered or not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix
        or not C_ChatInfo.SendAddonMessage or not ChatThrottleLib or not C_Timer or not C_Timer.After) then return end
    local result = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    local results = Enum and Enum.RegisterAddonMessagePrefixResult
    if (results and result ~= results.Success and result ~= results.DuplicatePrefix) then return end
    self.sharingRegistered = true
    self:RegisterEvent("CHAT_MSG_ADDON", "OnGuildShareMessage")
end

Guild.ExportGuildSharing = function(self, context)
    local live = self:SharingContextMatches(context)
    if (not live) then return end
    local source, public, count = self.db.global.characters, {}, 0
    for key, record in pairs(source) do
        if (live.members[key] and (record.nickname or record.main)) then
            local chain, seen, cursor, valid = {}, {}, key, true
            while (cursor) do
                if (seen[cursor] or not live.members[cursor] or not source[cursor]) then valid = false; break end
                seen[cursor], chain[#chain+1] = true, cursor
                cursor = source[cursor].main
            end
            if (valid) then
                for _, id in ipairs(chain) do
                    if (not public[id]) then
                        local item = source[id]
                        public[id] = { name = id, nickname = item.nickname, main = item.main }
                        count = count+1
                    end
                end
            end
        end
    end
    if (count == 0 or not self:ValidateRecords(public)) then return end
    local text = "AZGUILD:1:" .. LibStub("AceSerializer-3.0"):Serialize({ format = "AzGuild", version = 1, characters = public })
    if (#text > CHUNK*MAX_PARTS) then return end
    return text, count
end

Guild.PreviewGuildSharing = function(self, incoming)
    local live = incoming and self:SharingContextMatches(incoming.context)
    if (not live or #incoming.text > CHUNK*MAX_PARTS) then return end
    local public, count = self:DecodeIdentityBackup(incoming.text)
    if (not public or count == 0) then return end
    local merged, rows, conflicts, added = self:CopyRecords(), {}, 0, 0
    for key, record in pairs(public) do
        -- Network data has a narrower schema than a local backup.
        if (not live.members[key] or record.privateNote ~= nil or record.favorite ~= nil
            or record.main and (not public[record.main] or not live.members[record.main])) then return end
        local old = merged[key]
        if (not old) then added = added+1
        elseif (old.nickname ~= record.nickname or old.main ~= record.main) then conflicts = conflicts+1 end
        local function Description(item)
            return item and (item.main or item.nickname) or "-"
        end
        rows[#rows+1] = { name = live.members[key].name, before = Description(old), after = Description(record) }
        merged[key] = { name = live.members[key].name, nickname = record.nickname, main = record.main,
            privateNote = old and old.privateNote, favorite = old and old.favorite }
    end
    if (not self:ValidateRecords(merged)) then return end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return { records = merged, rows = rows, count = count, conflicts = conflicts, added = added,
        revision = self.identityRevision or 0 }
end

Guild.ImportGuildSharing = function(self, incoming, revision)
    if (self.sharingIncoming ~= incoming or revision ~= (self.identityRevision or 0)) then return false end
    local preview = self:PreviewGuildSharing(incoming)
    if (not preview) then return false end
    self.sharingIncoming = nil
    self:CommitRecords(preview.records, "guild-sharing")
    return true
end

local function Timeout(self, field, state)
    C_Timer.After(math.max(0, state.context.expires-GetTime()), function()
        if (self[field] == state) then
            self[field] = nil
            self:SharingStatus("Sharing expired. Request a new transfer.")
        end
    end)
end

Guild.RequestGuildSharing = function(self, name)
    self:InitializeSharing()
    local context = self.sharingRegistered and self:GetSharingContext(name)
    if (not context) then return false end
    self:CancelSharing()
    self.sharingSequence = (self.sharingSequence or 0)+1
    local token = string.format("%d-%d", math.floor(GetTime()*1000), self.sharingSequence)
    local state = { context = context, token = token, parts = {}, received = 0 }
    self.sharingReceive = state
    Timeout(self, "sharingReceive", state)
    self:SharingStatus("Request queued. Your partner must open Guild sharing and choose you before you request.")
    ChatThrottleLib:SendAddonMessage("BULK", PREFIX, "R:" .. token, "WHISPER", context.name, PREFIX, function(_, sent)
        if (self.sharingReceive == state and not sent) then
            self.sharingReceive = nil; self:SharingStatus("Sharing failed. Request a new transfer.")
        end
    end)
    return true
end

Guild.SendGuildSharing = function(self)
    local request = self.sharingRequest
    local text = request and self:ExportGuildSharing(request.context)
    if (not text or self.sharingSend) then return false end
    self.sharingRequest = nil
    local state = { context = request.context, token = request.token, index = 0, total = math.ceil(#text/CHUNK) }
    self.sharingSend = state
    Timeout(self, "sharingSend", state)
    local function NextChunk()
        if (self.sharingSend ~= state) then return end
        if (not self:SharingContextMatches(state.context)) then
            self.sharingSend = nil; self:SharingStatus("Sharing stopped. Check combat, guild and partner, then request again."); return
        end
        state.index = state.index+1
        if (state.index > state.total) then
            self.sharingSend = nil; self:SharingStatus("Transfer sent. Your partner must review and import it."); return
        end
        self:SharingStatus("Sending nickname transfer...")
        local message = table.concat({ "D", state.token, state.index, state.total }, ":") .. ":" .. text:sub((state.index-1)*CHUNK+1, state.index*CHUNK)
        ChatThrottleLib:SendAddonMessage("BULK", PREFIX, message, "WHISPER", state.context.name, PREFIX, function(_, sent)
            if (self.sharingSend ~= state) then return end
            if (not sent) then self.sharingSend = nil; self:SharingStatus("Sharing failed. Request a new transfer.")
            else C_Timer.After(.05, NextChunk) end
        end)
    end
    NextChunk()
    return true
end

Guild.OnGuildShareMessage = function(self, _, prefix, message, channel, sender)
    prefix, message, channel, sender = self.ReadText(prefix), self.ReadText(message), self.ReadText(channel), self.ReadText(sender)
    local window = self.sharingWindow
    if (prefix ~= PREFIX or channel ~= "WHISPER" or not message or #message > 255 or not sender
        or not window or not window:IsShown()) then return end
    local key = self:CharacterKey(sender)
    if (not key or key ~= self:CharacterKey(window.partner:GetText())) then return end
    local token = message:match("^R:([%d%-]+)$")
    if (token and #token <= 32) then
        if (self.sharingRequest or self.sharingSend or self.sharingReceive or self.sharingIncoming) then return end
        local context = self:GetSharingContext(sender)
        if (not context) then return end
        self.sharingRequest = { context = context, token = token }
        Timeout(self, "sharingRequest", self.sharingRequest)
        self:SharingStatus("Your partner requested nicknames. Review the outgoing count, then choose Send.")
        return
    end
    local state = self.sharingReceive
    if (not state or key ~= state.context.key or not self:SharingContextMatches(state.context)) then return end
    local id, index, total, payload = message:match("^D:([%d%-]+):(%d+):(%d+):(.*)$")
    index, total = tonumber(index), tonumber(total)
    if (id ~= state.token or not index or not total or total < 1 or total > MAX_PARTS or index < 1 or index > total
        or not payload or #payload == 0 or #payload > CHUNK or index < total and #payload ~= CHUNK
        or state.total and total ~= state.total) then return end
    if (state.parts[index]) then return end
    state.total, state.parts[index], state.received = total, payload, state.received+1
    if (state.received ~= total) then self:SharingStatus("Receiving nickname transfer..."); return end
    self.sharingReceive = nil
    local incoming = { context = state.context, text = table.concat(state.parts) }
    if (not self:PreviewGuildSharing(incoming)) then self:SharingStatus("Invalid nickname transfer. Nothing was imported."); return end
    self.sharingIncoming = incoming
    Timeout(self, "sharingIncoming", incoming)
    self:SharingStatus("Transfer received. Review every page before importing.")
end

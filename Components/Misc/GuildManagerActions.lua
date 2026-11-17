-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Integer(value)
    if (not Secret(value) and type(value) == "number" and value >= 1 and value <= 10000 and value%1 == 0) then return value end
end
local function Allowed(fn, ...)
    if (type(fn) ~= "function") then return false end
    local value = fn(...)
    return not Secret(value) and (value == true or value == 1)
end
local function Fail(self, text) self.guildActionStatus = text; return nil, text end

Guild.ReadGuildActionTarget = function(self, key)
    key = self.ReadText(key)
    if (not key) then return end
    if (InCombatLockdown() or not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo) then return end
    local count = Integer(GetNumGuildMembers())
    if (not count) then return end
    local found
    for index = 1, count do
        local name, rank, _, _, _, _, note, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(index)
        if (self:CharacterKey(name) == key) then
            guid = self.ReadText(guid)
            if (not guid or guid == "" or found) then return end
            found = { key = key, guid = guid, name = self.ReadText(name), rank = self.ReadText(rank), note = self.ReadText(note) }
        end
    end
    return found
end

Guild.GetGuildActionState = function(self, key)
    if (InCombatLockdown()) then return nil, "Guild actions are unavailable in combat." end
    local guildName = IsInGuild() and self.ReadText(GetGuildInfo("player"))
    local target = guildName and guildName ~= "" and self:ReadGuildActionTarget(key)
    local actor = UnitGUID and self.ReadText(UnitGUID("player"))
    if (not target or not actor or actor == "" or not self.realm or self.realm == "" or not C_GuildInfo) then
        return nil, "Select a current guild character with a readable GUID."
    end
    local state = { target = target, actor = actor, guildKey = self.realm .. ":" .. string.lower(guildName), choices = {} }
    state.canNote = type(C_GuildInfo.SetNote) == "function" and target.note ~= nil
        and (target.guid == actor or Allowed(CanEditPublicNote))
    if (C_GuildInfo.GetGuildRankOrder and C_GuildInfo.SetGuildRankOrder and GuildControlGetNumRanks and GuildControlGetRankName) then
        state.actorRank = Integer(C_GuildInfo.GetGuildRankOrder(actor))
        state.targetRank = Integer(C_GuildInfo.GetGuildRankOrder(target.guid))
        local count = Integer(GuildControlGetNumRanks())
        if (count and count <= 50 and state.actorRank and state.targetRank and target.rank and target.rank ~= ""
            and target.guid ~= actor and state.targetRank > state.actorRank) then
            local promote, demote = Allowed(CanGuildPromote), Allowed(CanGuildDemote)
            for order = state.actorRank+1, count do
                local directionAllowed = order < state.targetRank and promote or order > state.targetRank and demote
                local label = self.ReadText(GuildControlGetRankName(order))
                if (directionAllowed and label and label ~= "" and Allowed(C_GuildInfo.IsGuildRankAssignmentAllowed, target.guid, order)) then
                    state.choices[#state.choices+1] = { order = order, name = label }
                end
            end
        end
    end
    return state
end

local function SameContext(base, current)
    return base and current and base.guildKey == current.guildKey and base.actor == current.actor
        and base.target.key == current.target.key and base.target.guid == current.target.guid
end
local function RankChoice(state, order)
    for _, choice in ipairs(state.choices) do if (choice.order == order) then return choice end end
end
local function ValidNote(self, text)
    text = self.ReadText(text)
    if (not text or #text > 124 or text:find("[|%c]")) then return false end
    -- Native EditBox supplies UTF-8; match Blizzard's 31-letter public-note cap.
    local _, letters = text:gsub("[^\128-\191]", "")
    return letters <= 31
end

Guild.PrepareGuildAction = function(self, kind, base, value)
    if (self.pendingGuildAction) then return Fail(self, "Another guild change is awaiting a roster update.") end
    if (type(base) ~= "table" or not base.target) then return Fail(self, "Reload this character before preparing a guild change.") end
    local current, reason = self:GetGuildActionState(base.target.key)
    if (not current) then return Fail(self, reason) end
    if (not SameContext(base, current)) then return Fail(self, "The guild or character changed. Reload the character.") end
    local action = { kind = kind, key = current.target.key, guid = current.target.guid, name = current.target.name,
        guildKey = current.guildKey, actor = current.actor }
    if (kind == "note") then
        if (not current.canNote) then return Fail(self, "Your guild permissions do not allow this change.") end
        if (current.target.note ~= base.target.note) then return Fail(self, "The public note changed. Reload the character.") end
        if (not ValidNote(self, value)) then return Fail(self, "Use plain text with at most 31 characters for the public note.") end
        action.before, action.after = current.target.note, value
    elseif (kind == "rank") then
        value = Integer(value)
        local choice = RankChoice(current, value)
        local oldChoice = RankChoice(base, value)
        if (not choice or not oldChoice) then return Fail(self, "Choose an allowed rank different from the current rank.") end
        if (base.actorRank ~= current.actorRank or base.targetRank ~= current.targetRank
            or oldChoice.name ~= choice.name or base.target.rank ~= current.target.rank) then
            return Fail(self, "Ranks changed. Reload the character.")
        end
        action.before, action.after, action.actorRank = current.targetRank, value, current.actorRank
        action.beforeName, action.afterName = current.target.rank or "", choice.name
    else return Fail(self, "Unknown guild action.") end
    if (action.before == action.after) then return Fail(self, "There is no change to request.") end
    return action
end

Guild.ApplyGuildAction = function(self, action)
    if (type(action) ~= "table" or action.used) then return Fail(self, "This confirmation is no longer valid.") end
    action.used = true -- An attempted approval is single-use, including failures.
    if (self.pendingGuildAction) then return Fail(self, "Another guild change is awaiting a roster update.") end
    local current, reason = self:GetGuildActionState(action.key)
    if (not current) then return Fail(self, reason) end
    if (current.guildKey ~= action.guildKey or current.actor ~= action.actor or current.target.guid ~= action.guid) then
        return Fail(self, "The guild or character changed. Reload the character.")
    end
    if (action.kind == "note") then
        if (not current.canNote or current.target.note ~= action.before or not ValidNote(self, action.after)) then
            return Fail(self, "The note or your permissions changed. Reload the character.")
        end
        C_GuildInfo.SetNote(action.guid, action.after, true)
    elseif (action.kind == "rank") then
        local choice = RankChoice(current, action.after)
        if (not choice or current.targetRank ~= action.before or current.actorRank ~= action.actorRank
            or choice.name ~= action.afterName or current.target.rank ~= action.beforeName) then
            return Fail(self, "Ranks or your permissions changed. Reload the character.")
        end
        C_GuildInfo.SetGuildRankOrder(action.guid, action.after)
    else return Fail(self, "Unknown guild action.") end
    self.pendingGuildAction = action
    self.guildActionTarget = action.name
    self.guildActionStatus = "Request sent; waiting to observe the guild roster."
    if (C_Timer and C_Timer.After) then
        C_Timer.After(10, function()
            if (self.pendingGuildAction ~= action) then return end
            self.pendingGuildAction = nil
            self.guildActionStatus = "The request was not observed within 10 seconds. Reload the character to check."
            if (self.RefreshGuildActions) then self:RefreshGuildActions() end
        end)
    end
    self:RequestRoster()
    return true
end

Guild.ObserveGuildAction = function(self)
    local action = self.pendingGuildAction
    if (not action) then return end
    local guildName = self.guildDetails and self.ReadText(self.guildDetails.name)
    if (not IsInGuild() or not guildName or self.realm .. ":" .. string.lower(guildName) ~= action.guildKey) then
        self.pendingGuildAction = nil; self.guildActionStatus = "The guild or character changed. Reload the character."; return
    end
    if (InCombatLockdown()) then return end
    local current = self:GetGuildActionState(action.key)
    if (not current or current.guildKey ~= action.guildKey or current.target.guid ~= action.guid) then
        self.pendingGuildAction = nil; self.guildActionStatus = "The guild or character changed. Reload the character."; return
    end
    local value = action.kind == "note" and current.target.note or current.targetRank
    if (value == action.after) then
        self.pendingGuildAction = nil; self.guildActionStatus = "The requested change is visible in the guild roster."
    end
end

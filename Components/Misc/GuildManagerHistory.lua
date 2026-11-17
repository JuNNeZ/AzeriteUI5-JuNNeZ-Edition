-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local UI = Guild.UI
local ROWS, LIMIT = 9, 500
local FIELDS = { "rank", "note", "level" }
local LABELS = { rank = "Rank changed", note = "Public note changed", level = "Level changed",
    firstSeen = "Newly observed character", motd = "Guild message changed", info = "Guild information changed" }

Guild.GetGuildHistory = function(self)
    local name = self.guildDetails and self.ReadText(self.guildDetails.name)
    if (not IsInGuild() or not name or name == "" or not self.realm) then return end
    local key = self.realm .. ":" .. string.lower(name)
    return self.db.global.guildHistory and self.db.global.guildHistory[key], key
end

Guild.CaptureGuildHistory = function(self, metadataOnly)
    local state, key = self:GetGuildHistory()
    if (not key or (metadataOnly and (not state or not state.baseline))
        or (not metadataOnly and not next(self.members or {}))) then return false end
    local histories = self.db.global.guildHistory or {}
    self.db.global.guildHistory = histories
    local now = time()
    if (not state) then
        -- Bound account storage independently of nickname records/exports.
        local count, oldest, oldestTime = 0, nil, math.huge
        for id, history in pairs(histories) do
            count = count+1
            if ((history.updated or 0) < oldestTime) then oldest, oldestTime = id, history.updated or 0 end
        end
        if (count >= 5 and oldest) then histories[oldest] = nil end
        state = { members = {}, details = {}, events = {}, sequence = 0, reviewed = 0 }
        histories[key] = state
    end
    local function Append(kind, name, before, after)
        state.sequence = state.sequence+1
        state.events[#state.events+1] = { sequence = state.sequence, at = now, kind = kind,
            name = name, before = before, after = after }
        if (#state.events > LIMIT) then table.remove(state.events, 1) end
    end
    local memberCount = 0
    for _ in pairs(state.members) do memberCount = memberCount+1 end
    for id, member in pairs(metadataOnly and {} or self.members) do
        local old = state.members[id]
        if (not old and memberCount < 2000) then
            old = { name = member.name }; state.members[id] = old; memberCount = memberCount+1
            if (state.baseline) then Append("firstSeen", member.name) end
        end
        if (old) then
            local observed = member.observed or {}
            for _, field in ipairs(FIELDS) do
                local value = observed[field]
                if (field == "level" and value == 0) then value = nil end
                if (value ~= nil) then
                    if (type(value) == "string") then value = value:sub(1, field == "note" and 512 or 128) end
                    if (state.baseline and old[field] ~= nil and old[field] ~= value) then
                        Append(field, member.name, old[field], value)
                    end
                    old[field] = value
                end
            end
        end
    end
    for _, field in ipairs({ "motd", "info" }) do
        local value = self.ReadText(self.guildDetails[field])
        if (value) then
            value = value:sub(1, 4096)
            if (state.baseline and state.details[field] ~= nil and state.details[field] ~= value) then
                Append(field, self.guildDetails.name, state.details[field], value)
            end
            state.details[field] = value
        end
    end
    -- Missing members are retained, never interpreted as departures. The first
    -- fresh roster is a baseline; firstSeen is an observation, not a join date.
    state.baseline, state.updated = true, now
    return true
end

Guild.GetHistoryEntries = function(self, search, unreadOnly)
    local state = self:GetGuildHistory()
    local entries, unread = {}, 0
    search = string.lower(search or "")
    if (not state) then return entries, unread end
    for index = #state.events, 1, -1 do
        local entry = state.events[index]
        local isUnread = entry.sequence > (state.reviewed or 0)
        if (isUnread) then unread = unread+1 end
        local text = table.concat({ entry.name or "", L[LABELS[entry.kind]], tostring(entry.before or ""), tostring(entry.after or "") }, " ")
        if ((not unreadOnly or isUnread) and (search == "" or string.lower(text):find(search, 1, true))) then
            entries[#entries+1] = entry
        end
    end
    return entries, unread
end

Guild.MarkHistoryReviewed = function(self)
    local state = self:GetGuildHistory()
    if (state) then state.reviewed = state.sequence end
    self:RefreshHistory()
end

Guild.RefreshHistory = function(self)
    local window = self.historyWindow
    if (not window or not window:IsShown()) then return end
    local entries, unread = self:GetHistoryEntries(window.search:GetText(), window.unreadOnly)
    window.offset = math.max(0, math.min(window.offset or 0, math.max(0, #entries-ROWS)))
    window.summary:SetText(string.format(L["%d changes shown / %d unread / latest %d retained"], #entries, unread, LIMIT))
    window.empty:SetText(#entries == 0 and L["No observed changes. The first roster establishes a baseline."] or "")
    UI.Check(window.filter, window.unreadOnly, L["Unread only"])
    window.review:SetEnabled(unread > 0)
    window.previous:SetEnabled(window.offset > 0); window.next:SetEnabled(window.offset+ROWS < #entries)
    for index, row in ipairs(window.rows) do
        local entry = entries[window.offset+index]
        row:SetShown(entry ~= nil)
        if (entry) then
            row.title:SetText(date("%d/%m %H:%M", entry.at) .. "  |  " .. L[LABELS[entry.kind]] .. "  |  " .. entry.name, true)
            row.detail:SetText(entry.kind == "firstSeen" and L["First observed in a later roster; actual join time is unknown."]
                or tostring(entry.before or "") .. "  ->  " .. tostring(entry.after or ""), true)
            row.entry = entry
        else row.entry = nil end
    end
end

Guild.OpenHistory = function(self)
    if (not self.historyWindow) then
        local window = UI.Page(ns.Prefix .. "GuildHistory", "history", L["Guild history"], 940, 696, 100, L["Observed locally. Times show when changes were detected; authors and join/leave times are unknown."])
        self.historyWindow = window
        window.unreadOnly = true
        UI.Label(window, L["Guild history"], 24, -25, 820, 19)
        UI.Label(window, L["Observed locally. Times show when changes were detected; authors and join/leave times are unknown."], 24, -62, 890, 12, 2)
        window.search = UI.Input(window, L["Search history"], 24, -103, 430)
        window.search:SetScript("OnTextChanged", function() window.offset = 0; self:RefreshHistory() end)
        window.filter = UI.QuietButton(window, "", 474, -122, 180, function()
            window.unreadOnly = not window.unreadOnly; window.offset = 0; self:RefreshHistory()
        end)
        window.review = UI.QuietButton(window, L["Mark all as read"], 674, -122, 242, function() self:MarkHistoryReviewed() end)
        window.rows = {}
        for index = 1, ROWS do
            local row = CreateFrame("Frame", nil, window)
            row:SetPoint("TOPLEFT", 24, -174-(index-1)*50); row:SetSize(892, 46)
            row.title = UI.Label(row, "", 0, 0, 890, 12)
            row.detail = UI.Label(row, "", 0, -19, 890, 11, 2)
            row:EnableMouse(true)
            row:SetScript("OnEnter", function()
                if (not row.entry or GameTooltip:IsForbidden()) then return end
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                -- Neutralize markup in external guild text displayed as tooltip lines.
                GameTooltip:AddLine(row.entry.name:gsub("|", "||"), 1, .85, .5)
                for _, field in ipairs({ "before", "after" }) do
                    local value = row.entry[field]
                    if (value ~= nil) then GameTooltip:AddLine((L[field == "before" and "Before" or "After"] .. ": " .. tostring(value)):gsub("|", "||"), 1, 1, 1, true) end
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end end)
            window.rows[index] = row
        end
        window.empty = UI.Label(window, "", 24, -180, 890, 13, 2)
        window.previous = UI.QuietButton(window, "<", 24, -634, 32, function() window.offset = window.offset-ROWS; self:RefreshHistory() end)
        window.next = UI.QuietButton(window, ">", 66, -634, 32, function() window.offset = window.offset+ROWS; self:RefreshHistory() end)
        window.summary = UI.Label(window, "", 120, -642, 600, 11)
        UI.QuietButton(window, L["Refresh"], 778, -634, 138, function() self:RequestRoster() end)
        window:SetScript("OnHide", function() window.search:ClearFocus() end)
    end
    UI.Show(self.historyWindow); self:RefreshHistory(); self:RequestRoster()
end

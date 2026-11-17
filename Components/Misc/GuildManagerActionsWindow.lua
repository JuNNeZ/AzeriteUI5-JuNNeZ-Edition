-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local UI, Kit = Guild.UI, ns.OptionsKit
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local function Literal(value)
    return tostring(value or ""):gsub("|", "||")
end

Guild.RefreshGuildActions = function(self)
    local window = self.guildActionsWindow
    if (not window or not window:IsShown() or self.buildingGuildActions) then return end
    local current, reason = self:GetGuildActionState(window.key)
    local ready = current and window.baseline and not self.pendingGuildAction or false
    window.noteApply:SetEnabled(ready and current.canNote or false)
    window.rankCycle:SetEnabled(ready and #current.choices > 0 or false)
    local rankAllowed = false
    for _, choice in ipairs(current and current.choices or {}) do if (choice.order == window.rankOrder) then rankAllowed = true end end
    window.rankApply:SetEnabled(ready and rankAllowed or false)
    if (current) then window.currentRank:SetText(L["Current rank"] .. ": " .. (current.target.rank or L["Unknown"]), true) end
    window.access:SetText(not window.baseline and L["Reload this character before preparing a guild change."] or reason and L[reason] or current and not current.canNote and #current.choices == 0
        and L["Your guild permissions do not allow this change."] or L["Permissions are checked again when you confirm."])
    if (self.guildActionStatus) then
        window.feedback:SetText((self.guildActionTarget and self.guildActionTarget .. ": " or "") .. L[self.guildActionStatus], true)
    end
end

Guild.PreviewGuildAction = function(self, kind)
    local window = self.guildActionsWindow
    if (not self.pendingGuildAction) then self.guildActionTarget = nil end
    local value = kind == "note" and window.note:GetText() or window.rankOrder
    local action, reason = self:PrepareGuildAction(kind, window.baseline, value)
    if (not action) then window.feedback:SetText(L[reason]); self:RefreshGuildActions(); return end
    local before = kind == "note" and action.before or action.beforeName
    local after = kind == "note" and action.after or action.afterName
    if (before == "") then before = L["(empty)"] end
    if (after == "") then after = L["(empty)"] end
    local question = string.format(L["Change %s for %s?\nBefore: %s\nAfter: %s\nThis changes guild data and cannot be undone with local Undo."],
        kind == "note" and L["public guild note"] or L["guild rank"], Literal(action.name), Literal(before), Literal(after))
    local session, selected = window.session, self.selected
    local shown = Kit.Confirm(question, function()
        if (not window:IsShown() or window.session ~= session or window.key ~= action.key or self.selected ~= selected) then
            self.guildActionStatus = "This confirmation is no longer valid."
        else self:ApplyGuildAction(action) end
        self:RefreshGuildActions()
    end)
    if (shown == false) then
        window.feedback:SetText(L["Confirmation could not be opened. No guild change was sent."])
    end
end

Guild.OpenGuildActions = function(self, key)
    key = key or self.selected
    if (not self.guildActionsWindow) then
        self.buildingGuildActions = true
        local window = UI.Page(ns.Prefix .. "GuildActions", "actions", L["Guild actions"], 720, 550)
        self.guildActionsWindow = window
        UI.Rule(window, 24, -130, 660); UI.Rule(window, 24, -260, 660); UI.Rule(window, 24, -360, 660)
        UI.Label(window, L["Guild actions"], 24, -25, 620, 22)
        window.characterName = UI.Label(window, "", 24, -66, 660, 17)
        window.currentRank = UI.Label(window, "", 24, -97, 660, 13)
        window.note = UI.Input(window, L["Public guild note (31 characters)"], 24, -141, 660, 30, 124)
        window.note:SetMaxLetters(31)
        window.noteApply = UI.QuietButton(window, L["Review note change"], 24, -209, 230, function() self:PreviewGuildAction("note") end, true)
        window.rankCycle = UI.QuietButton(window, L["Choose rank"], 24, -278, 388, function()
            local current = self:GetGuildActionState(window.key)
            local choices = current and current.choices or {}
            if (#choices == 0) then return end
            local index = 0
            for i, choice in ipairs(choices) do if (choice.order == window.rankOrder) then index = i; break end end
            local choice = choices[index%#choices+1]
            window.rankOrder = choice.order; window.rankCycle.label:SetText(choice.name)
            self:RefreshGuildActions()
        end)
        window.rankApply = UI.QuietButton(window, L["Review rank change"], 430, -278, 254, function() self:PreviewGuildAction("rank") end, true)
        UI.Label(window, L["Only this character is changed. Alts and local nicknames are not edited."], 24, -328, 660, 12, 2)
        window.access = UI.Label(window, "", 24, -375, 660, 12, 2)
        window.feedback = UI.Label(window, "", 24, -425, 660, 12, 3)
        UI.QuietButton(window, L["Reload character"], 24, -493, 220, function() self:OpenGuildActions(window.key); self:RequestRoster() end)
        window:SetScript("OnHide", function()
            window.note:ClearFocus(); window.session = (window.session or 0)+1; window.baseline = nil
        end)
        self.buildingGuildActions = nil
    end
    local window = self.guildActionsWindow
    window.key, window.rankOrder, window.session = key, nil, (window.session or 0)+1
    window.baseline = self:GetGuildActionState(key)
    window.rankCycle.label:SetText(L["Choose rank"])
    window.characterName:SetText(window.baseline and window.baseline.target.name or L["Select a person"], true)
    window.note:SetText(window.baseline and window.baseline.target.note or "")
    window.currentRank:SetText(L["Current rank"] .. ": " .. (window.baseline and window.baseline.target.rank or L["Unknown"]), true)
    if (not self.pendingGuildAction) then self.guildActionStatus, self.guildActionTarget = nil, nil end
    window.feedback:SetText("")
    UI.Show(window); self:RefreshGuildActions()
end

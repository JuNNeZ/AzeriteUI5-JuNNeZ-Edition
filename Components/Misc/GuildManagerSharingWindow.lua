-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local UI, Kit, PAGE = Guild.UI, ns.OptionsKit, 4

Guild.RefreshSharing = function(self)
    local window = self.sharingWindow
    if (not window or not window:IsShown()) then return end
    local context = self:GetSharingContext(window.partner:GetText())
    local busy = self.sharingReceive or self.sharingSend or self.sharingIncoming or self.sharingRequest
    window.request:SetEnabled(self.sharingRegistered and context ~= nil and not busy or false)
    local outgoing, count
    if (self.sharingRequest) then outgoing, count = self:ExportGuildSharing(self.sharingRequest.context) end
    window.send:SetEnabled(outgoing ~= nil and not self.sharingSend)
    window.outgoing:SetText(count and string.format(L["%d public identity records ready to send."], count) or "")
    local preview = self.sharingIncoming and self:PreviewGuildSharing(self.sharingIncoming)
    window.preview = preview
    window.offset = math.max(0, math.min(window.offset or 0, math.max(0, preview and #preview.rows-PAGE or 0)))
    window.apply:SetEnabled(preview ~= nil)
    window.previous:SetEnabled(window.offset > 0)
    window.next:SetEnabled(preview and window.offset+PAGE < #preview.rows or false)
    window.summary:SetText(preview and string.format(L["From %s: %d records, %d new, %d replacements."],
        self.sharingIncoming.context.name, preview.count, preview.added, preview.conflicts) or "")
    for index, row in ipairs(window.rows) do
        local item = preview and preview.rows[window.offset+index]
        row.name:SetText(item and item.name or "")
        row.before:SetText(item and item.before or "")
        row.after:SetText(item and item.after or "")
    end
    window.feedback:SetText(self.sharingStatus and L[self.sharingStatus] or L["Choose an online guild partner. Both players must open this window and choose each other."])
end

Guild.OpenSharing = function(self)
    self:InitializeSharing()
    self:RequestRoster()
    if (not self.sharingWindow) then
        local window = UI.Page(ns.Prefix .. "GuildSharing", "sharing", L["Guild sharing"], 940, 696, 100, L["Share nicknames and main/alt links with one guild partner. Private notes, favorites and officer follow-up stay local."])
        self.sharingWindow = window
        UI.Label(window, L["Guild sharing"], 24, -25, 820, 19)
        UI.Label(window, L["Share nicknames and main/alt links with one guild partner. Private notes, favorites and officer follow-up stay local."], 24, -65, 892, 12, 2)
        window.partner = UI.Input(window, L["Guild partner (character-realm)"], 24, -112, 510)
        window.partner:SetScript("OnTextChanged", function()
            self:CancelSharing(); window.offset = 0
        end)
        window.request = UI.QuietButton(window, L["Request nicknames"], 552, -131, 172, function()
            if (not self:RequestGuildSharing(window.partner:GetText())) then
                self:SharingStatus("Sharing unavailable. Choose an online guild partner outside combat.")
            end
        end)
        window.send = UI.QuietButton(window, L["Send nicknames"], 736, -131, 180, function()
            if (not self:SendGuildSharing()) then self:SharingStatus("Unable to send. Check your partner and request again.") end
        end)
        window.outgoing = UI.Label(window, "", 24, -180, 892)
        UI.Label(window, L["Incoming changes: current nickname or main -> incoming"], 24, -220, 892, 12)
        window.summary = UI.Label(window, "", 24, -247, 892)
        window.rows = {}
        for index = 1, PAGE do
            local y = -287-(index-1)*66
            window.rows[index] = { name = UI.Label(window, "", 24, y, 892, 11),
                before = UI.Label(window, "", 24, y-18, 430, 11, 3),
                after = UI.Label(window, "", 486, y-18, 430, 11, 3) }
        end
        window.previous = UI.QuietButton(window, "<", 24, -554, 32, function()
            window.offset = window.offset-PAGE; self:RefreshSharing()
        end)
        window.next = UI.QuietButton(window, ">", 66, -554, 32, function()
            window.offset = window.offset+PAGE; self:RefreshSharing()
        end)
        UI.QuietButton(window, L["Cancel transfer"], 110, -554, 190, function() self:CancelSharing() end)
        window.apply = UI.QuietButton(window, L["Import nicknames"], 710, -554, 206, function()
            local incoming, preview = self.sharingIncoming, window.preview
            if (not incoming or not preview) then return end
            Kit.Confirm(string.format(L["Import %d records from %s and replace %d identities? You can undo this operation."],
                preview.count, incoming.context.name, preview.conflicts), function()
                if (not window:IsShown()) then return end
                local ok = self:ImportGuildSharing(incoming, preview.revision)
                self:SharingStatus(ok and "Nicknames imported. Undo is available." or "Transfer changed or expired. Request a new transfer.")
                self:ReloadCard()
            end)
        end, true)
        window.feedback = UI.Label(window, "", 24, -605, 892, 12, 3)
        window:SetScript("OnHide", function() self:CancelSharing(); window.partner:ClearFocus() end)
    end
    UI.Show(self.sharingWindow)
    self:RefreshSharing()
end

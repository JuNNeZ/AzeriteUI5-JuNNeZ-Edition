-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local UI, Kit, PAGE = Guild.UI, ns.OptionsKit, 9
local SOURCE = { own = "Scanned on this account", import = "Imported text; owner unverified", blizzard = "Blizzard guild response" }
local function Timestamp(value) return date("%Y-%m-%d %H:%M", value) end

Guild.RefreshCrafting = function(self)
    local window = self.craftingWindow
    if (not window or not window:IsShown()) then return end
    local rows = self:GetCraftingRows(window.search:GetText(), window.onlineOnly)
    window.offset = math.max(0, math.min(window.offset or 0, math.max(0, #rows-PAGE)))
    window.count:SetText(string.format(L["%d to %d of %d rows"], #rows > 0 and window.offset+1 or 0, math.min(#rows, window.offset+PAGE), #rows))
    window.previous:SetEnabled(window.offset > 0); window.next:SetEnabled(window.offset+PAGE < #rows)
    UI.Check(window.online, window.onlineOnly, L["Online crafters"])
    local selected
    for _, row in ipairs(rows) do
        if (window.selected and row.owner == window.selected.owner and row.professionID == window.selected.professionID
            and row.id == window.selected.id) then selected = row; break end
    end
    window.selected = selected
    for index, button in ipairs(window.rows) do
        local row = rows[window.offset+index]
        button.data = row; button:SetShown(row ~= nil)
        if (row) then
            button.title:SetText(row.recipe.name)
            button.detail:SetText(row.snapshot.profession .. " / " .. row.nickname)
            local online = row.member.online
            button.title:SetTextColor(online and .95 or .52, online and .9 or .52, online and .76 or .52)
            button.detail:SetTextColor(online and .8 or .48, online and .76 or .48, online and .65 or .48)
            button.highlight:SetColorTexture(.9, .7, .3, row == selected and .18 or .025)
        end
    end
    local member = selected and selected.member
    window.recipe:SetText(selected and selected.recipe.name or L["Select a recipe"])
    window.crafter:SetText(member and (selected.nickname .. "\n" .. member.name) or "")
    window.profession:SetText(selected and selected.snapshot.profession or "")
    window.item:SetText(selected and ((selected.recipe.itemName or "") .. (selected.recipe.itemID and ("  #" .. selected.recipe.itemID) or "")) or "")
    window.source:SetText(selected and (L[SOURCE[selected.source]] .. "\n" .. L[selected.source == "blizzard" and "Observed" or "Reported scan"] .. ": " .. Timestamp(selected.snapshot.scanned)
        .. "\n" .. L["Received locally"] .. ": " .. Timestamp(selected.received)) or "")
    window.state:SetText(member and (member.online and L["Online"] or L["Offline"]) or "")
    local available = member and member.online and not InCombatLockdown() and not self.suspended and self.db.profile.enabled
    window.whisper:SetEnabled(available and ChatFrameUtil and ChatFrameUtil.SendTell ~= nil or false)
    window.query:SetEnabled(selected ~= nil and not self.craftingPending and not InCombatLockdown()
        and C_GuildInfo and C_GuildInfo.QueryGuildMembersForRecipe ~= nil or false)
    window.scan:SetEnabled(not InCombatLockdown() and self.db.profile.enabled and not self.suspended)
    window.export:SetEnabled(self:CanExportCrafting(selected))
    window.undo:SetEnabled(self.craftingUndo and #self.craftingUndo > 0 or false)
    window.feedback:SetText(self.craftingStatus and L[self.craftingStatus]
        or L["Open your own profession and scan it. Missing recipes mean unknown, not unlearned."])
end

Guild.OpenCrafting = function(self)
    if (not self.craftingWindow) then
        local window = UI.Page(ns.Prefix .. "GuildCrafting", "crafting", L["Guild crafting"], 1080, 727, 131, L["Who can craft it? Known recipes with a source and date."])
        self.craftingWindow = window
        UI.Label(window, L["Guild crafting"], 24, -25, 680, 22)
        UI.Label(window, L["Who can craft it? Known recipes with a source and date."], 24, -62, 730, 12)
        window.search = UI.Input(window, L["Search profession, recipe, item or crafter"], 24, -132, 380)
        window.search:SetScript("OnTextChanged", function() window.offset = 0; self:RefreshCrafting() end)
        window.online = UI.QuietButton(window, L["Online crafters"], 420, -151, 236, function()
            window.onlineOnly = not window.onlineOnly; window.offset = 0; self:RefreshCrafting()
        end)
        window.scan = UI.QuietButton(window, L["Scan my open profession"], 24, -198, 306, function()
            self:CraftingStatus(self:ScanOwnCrafting() and "Profession scanned. Only learned recipes were saved."
                or "Scan unavailable or incomplete. Open your own profession outside combat and try again.")
        end)
        UI.QuietButton(window, L["Import recipe list"], 344, -198, 312, function() self:OpenCraftingTransfer() end)
        window.rows = {}
        for index = 1, PAGE do
            local row = CreateFrame("Button", nil, window)
            row:SetPoint("TOPLEFT", 24, -249-(index-1)*44); row:SetSize(632, 42)
            row.highlight = row:CreateTexture(nil, "BACKGROUND"); row.highlight:SetAllPoints()
            row.title = UI.Label(row, "", 10, -5, 610, 12)
            row.detail = UI.Label(row, "", 10, -24, 610, 11)
            row:SetScript("OnClick", function() window.selected = row.data; self:RefreshCrafting() end)
            window.rows[index] = row
        end
        window.previous = UI.QuietButton(window, "<", 24, -660, 32, function() window.offset = window.offset-PAGE; self:RefreshCrafting() end)
        window.next = UI.QuietButton(window, ">", 66, -660, 32, function() window.offset = window.offset+PAGE; self:RefreshCrafting() end)
        window.count = UI.Label(window, "", 110, -669, 325)
        window.undo = UI.QuietButton(window, L["Undo crafting change"], 442, -660, 214, function() self:UndoCrafting(); self:RefreshCrafting() end)
        local card = CreateFrame("Frame", nil, window, ns.BackdropTemplate)
        card:SetPoint("TOPLEFT", 680, -132); card:SetSize(376, 556)
        card:SetBackdrop(Kit.Look and Kit.Look.InsetBackdrop or Kit.InsetBackdrop); card:SetBackdropBorderColor(.52, .43, .29, 1); UI.Opaque(card)
        UI.Rule(card, 18, -111, 340); UI.Rule(card, 18, -269, 340)
        window.recipe = UI.Label(card, "", 18, -18, 340, 17, 3)
        window.profession = UI.Label(card, "", 18, -88, 340, 13)
        window.crafter = UI.Label(card, "", 18, -123, 340, 12, 3)
        window.state = UI.Label(card, "", 18, -184, 340)
        window.item = UI.Label(card, "", 18, -217, 340, 12, 3)
        window.source = UI.Label(card, "", 18, -285, 340, 11, 6)
        window.whisper = UI.QuietButton(card, L["Whisper crafter"], 18, -400, 340, function()
            local row = window.selected
            local member = row and self:LiveCraftingMember(row.owner, row.snapshot.guid)
            if (member and member.online and ChatFrameUtil and ChatFrameUtil.SendTell) then ChatFrameUtil.SendTell(member.name) end
        end)
        window.query = UI.QuietButton(card, L["Ask Blizzard for guild crafters"], 18, -448, 340, function()
            self:CraftingStatus(self:QueryCrafting(window.selected) and "Waiting for Blizzard guild recipe data..."
                or "Guild recipe lookup is unavailable. Availability is unknown.")
        end)
        window.export = UI.QuietButton(card, L["Share my profession"], 18, -496, 340, function() self:OpenCraftingTransfer(window.selected) end)
        window.feedback = UI.Label(window, "", 24, -704, 1032, 11, 2)
        window:SetScript("OnHide", function()
            self:CancelCraftingQuery(); window.search:ClearFocus()
            if (self.craftingTransfer) then self.craftingTransfer:Hide() end
        end)
    end
    UI.Show(self.craftingWindow); self:RequestRoster(); self:RefreshCrafting()
end

Guild.OpenCraftingTransfer = function(self, row)
    local exported = row and self:ExportCrafting(row)
    if (row and not exported) then self:CraftingStatus("Profession list is too large or unavailable to export."); return end
    if (not self.craftingTransfer) then
        local window = UI.Shell(ns.Prefix .. "GuildCraftingTransfer", self.frame, 880, 590, true)
        self.craftingTransfer = window
        UI.Label(window, L["Share a profession list"], 24, -25, 760, 19)
        UI.Label(window, L["Copy your scanned profession or paste a guild member's list. Pasted ownership is unverified; review before replacing a snapshot."], 24, -65, 832, 12, 3)
        local scroll = CreateFrame("ScrollFrame", nil, window)
        scroll:SetPoint("TOPLEFT", 24, -140); scroll:SetSize(832, 270); scroll:SetClipsChildren(true)
        window.edit = UI.Input(scroll, "", 0, 19, 832, 270, 500010)
        local edit = window.edit
        edit:SetMultiLine(true); edit:SetJustifyV("TOP"); edit:SetScript("OnEnterPressed", nil)
        scroll:SetScrollChild(edit); scroll:EnableMouseWheel(true)
        UI.ScrollBar(scroll, window)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScroll()-delta*36, scroll:GetVerticalScrollRange())))
        end)
        edit:SetScript("OnTextChanged", function()
            edit:SetHeight(math.max(270, edit:GetNumLines()*15+16))
            window.preview = nil; window.apply:SetEnabled(false); window.feedback:SetText("")
        end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local offset = scroll:GetVerticalScroll()
            if (-y < offset) then scroll:SetVerticalScroll(-y)
            elseif (-y+height > offset+scroll:GetHeight()) then scroll:SetVerticalScroll(-y+height-scroll:GetHeight()) end
        end)
        UI.QuietButton(window, L["Preview recipe list"], 24, -438, 250, function()
            local preview = self:PreviewCraftingImport(edit:GetText())
            window.preview = preview; window.apply:SetEnabled(preview ~= nil)
            window.feedback:SetText(preview and string.format(L["%s / %s: %d recipes. Existing list: %s. Ownership is unverified."],
                preview.name, preview.snapshot.profession, preview.count, preview.replacing and L["Yes"] or L["No"])
                .. "\n" .. string.format(L["%d added, %d changed, %d removed. Reported scan: %s."],
                    preview.added, preview.changed, preview.removed, Timestamp(preview.snapshot.scanned))
                or L["Invalid list, wrong guild/GUID, combat or unavailable data."])
        end)
        window.apply = UI.QuietButton(window, L["Import profession list"], 578, -438, 278, function()
            local preview, text, session = window.preview, edit:GetText(), window.session
            if (not preview or preview.text ~= text) then return end
            Kit.Confirm(string.format(L["Replace the saved %s list for %s with %d reported recipes? Crafting Undo is available."],
                preview.snapshot.profession, preview.name, preview.count), function()
                if (not window:IsShown() or window.session ~= session or window.preview ~= preview or edit:GetText() ~= text) then return end
                local ok = self:ImportCrafting(text, preview)
                window.preview = nil; window.apply:SetEnabled(false)
                window.feedback:SetText(ok and L["Profession list imported. Crafting Undo is available."] or L["The list or guild changed. Preview again."])
                self:RefreshCrafting()
            end)
        end, true)
        window.feedback = UI.Label(window, "", 24, -490, 832, 12, 4)
        window:SetScript("OnHide", function() window.session = (window.session or 0)+1; window.preview = nil; edit:ClearFocus() end)
    end
    local window = self.craftingTransfer
    window.session = (window.session or 0)+1
    window.edit:SetText(exported or "")
    window.preview = nil; window.apply:SetEnabled(false)
    UI.Show(window)
    if (row) then window.edit:SetFocus(); window.edit:HighlightText() end
end

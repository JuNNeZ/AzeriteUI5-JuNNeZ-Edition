-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local _, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local UI, Kit = Guild.UI, ns.OptionsKit
local REVIEW_ROWS = 6

Guild.RefreshNoteReview = function(self)
    local review = self.noteReview
    local _, guildKey = self:GetGuildHistory()
    if (review.guildKey ~= guildKey) then
        review.guildKey = guildKey; review.session = (review.session or 0)+1
        review.proposals, review.skipped = self:BuildNoteSuggestions()
        review.selected, review.offset = {}, 0
    end
    local proposals = review.proposals
    review.offset = math.max(0, math.min(review.offset or 0, math.max(0, #proposals-REVIEW_ROWS)))
    local chosen, conflicts = 0, 0
    for _, proposal in ipairs(proposals) do
        if (review.selected[proposal.id]) then chosen = chosen+1; if (proposal.conflict) then conflicts = conflicts+1 end end
    end
    review.summary:SetText(string.format(L["%d suggestions, %d selected, %d conflicts, %d notes skipped"], #proposals, chosen, conflicts, review.skipped))
    review.apply:SetEnabled(chosen > 0)
    for index, row in ipairs(review.rows) do
        local proposal = proposals[review.offset+index]
        row.proposal = proposal; row:SetShown(proposal ~= nil)
        if (proposal) then
            UI.Check(row.pick, review.selected[proposal.id], proposal.nickname .. "  (" .. #proposal.members .. ")")
            local target = self.db.global.characters[proposal.main] or (self.members or {})[proposal.main]
            row.main.label:SetText(L["Main character"] .. ": " .. (target and target.name or proposal.main))
            local names = {}
            for _, member in ipairs(proposal.members) do names[#names+1] = member.name end
            row.names:SetText(table.concat(names, ", "))
            row.warning:SetText(proposal.conflict and L["Existing identity: review before replacing"]
                or proposal.ambiguous and L["Free-form note: review this suggestion"] or L["Matching public notes"])
            row.warning:SetTextColor(proposal.conflict and 1 or .75, proposal.conflict and .5 or .7, .4)
        end
    end
    review.previous:SetEnabled(review.offset > 0); review.next:SetEnabled(review.offset+REVIEW_ROWS < #proposals)
end

Guild.OpenNoteReview = function(self, rescan)
    self:RequestRoster()
    if (not self.noteReview) then
        local review = UI.Page(ns.Prefix .. "GuildNoteReview", "notes", L["Review guild notes"], 940, 680, 100, L["Choose people to import. Click Main to choose their main character. Existing identities may be replaced."])
        self.noteReview = review
        UI.Label(review, L["Review guild notes"], 24, -25, 820, 19)
        UI.Label(review, L["Choose people to import. Click Main to choose their main character. Existing identities may be replaced."], 24, -62, 888, 12, 2)
        review.rows = {}
        for index = 1, REVIEW_ROWS do
            local row = CreateFrame("Frame", nil, review)
            row:SetSize(892, 76); row:SetPoint("TOPLEFT", 24, -105-(index-1)*78)
            row.pick = UI.QuietButton(row, "", 0, 0, 246, function()
                local proposal = row.proposal
                if (proposal) then review.selected[proposal.id] = not review.selected[proposal.id]; self:RefreshNoteReview() end
            end)
            row.main = UI.QuietButton(row, "", 260, 0, 630, function()
                local proposal = row.proposal
                if (not proposal) then return end
                for i, key in ipairs(proposal.targets) do
                    if (key == proposal.main) then proposal.main = proposal.targets[i%#proposal.targets+1]; break end
                end
                self:RefreshNoteReview()
            end)
            row.names = UI.Label(row, "", 8, -35, 882, 11)
            row.warning = UI.Label(row, "", 8, -55, 882, 11)
            row:EnableMouse(true)
            row:SetScript("OnEnter", function()
                if (not row.proposal or GameTooltip:IsForbidden()) then return end
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                for _, member in ipairs(row.proposal.members) do
                    GameTooltip:AddLine(member.name, 1, .85, .5)
                    GameTooltip:AddLine(member.note, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end end)
            review.rows[index] = row
        end
        review.previous = UI.QuietButton(review, "<", 24, -580, 32, function() review.offset = review.offset-REVIEW_ROWS; self:RefreshNoteReview() end)
        review.next = UI.QuietButton(review, ">", 66, -580, 32, function() review.offset = review.offset+REVIEW_ROWS; self:RefreshNoteReview() end)
        UI.QuietButton(review, L["Select clear suggestions"], 110, -580, 214, function()
            for _, proposal in ipairs(review.proposals) do
                if (not proposal.conflict and not proposal.ambiguous) then review.selected[proposal.id] = true end
            end
            self:RefreshNoteReview()
        end)
        UI.QuietButton(review, L["Scan again"], 334, -580, 150, function() self:OpenNoteReview(true) end)
        review.apply = UI.QuietButton(review, L["Apply selected"], 696, -580, 220, function()
            local selected, proposals, count, conflicts = {}, {}, 0, 0
            for _, proposal in ipairs(review.proposals) do
                if (review.selected[proposal.id]) then
                    selected[proposal.id] = true; count = count+1; if (proposal.conflict) then conflicts = conflicts+1 end
                    proposals[#proposals+1] = { id = proposal.id, nickname = proposal.nickname, main = proposal.main, signature = proposal.signature }
                end
            end
            local session = review.session
            Kit.Confirm(string.format(L["Apply %d note groups, including %d conflicting groups? You can undo this operation."], count, conflicts), function()
                local _, guildKey = self:GetGuildHistory()
                if (not review:IsShown() or review.session ~= session or review.guildKey ~= guildKey) then return end
                local ok = self:ApplyNoteSuggestions(proposals, selected)
                review.feedback:SetText(ok and L["Selected identities imported. Undo is available."] or L["Selected groups overlap or have changed. Review and scan again."])
                if (ok) then
                    review.proposals, review.skipped = self:BuildNoteSuggestions(); review.selected = {}
                    self:ReloadCard(); self:RefreshNoteReview()
                end
            end)
        end)
        review.apply.primary = true; review.apply:RefreshArt()
        review.summary = UI.Label(review, "", 24, -625, 892)
        review.feedback = UI.Label(review, "", 24, -648, 892, 11)
        review:SetScript("OnHide", function() review.session = (review.session or 0)+1 end)
    end
    local review = self.noteReview
    local _, guildKey = self:GetGuildHistory()
    if (rescan or not review.proposals or review.guildKey ~= guildKey) then
        review.guildKey = guildKey
        review.session = (review.session or 0)+1
        review.proposals, review.skipped = self:BuildNoteSuggestions(); review.selected = {}; review.offset = 0
        review.feedback:SetText("")
    end
    UI.Show(review); self:RefreshNoteReview()
end

Guild.OpenBackup = function(self)
    if (not self.backupWindow) then
        local window = UI.Page(ns.Prefix .. "GuildBackup", "backup", L["Backup / Share"], 880, 580, 100, L["Export local identities or paste a backup. Preview shows additions and replacements; import merges into your current data."])
        self.backupWindow = window
        UI.Label(window, L["Nickname backup and sharing"], 24, -25, 760, 19)
        UI.Label(window, L["Export local identities or paste a backup. Preview shows additions and replacements; import merges into your current data."], 24, -65, 832, 12, 2)
        window.include = UI.QuietButton(window, "", 24, -116, 296, function()
            window.includePrivate = not window.includePrivate
            UI.Check(window.include, window.includePrivate, L["Include private notes"])
        end)
        UI.QuietButton(window, L["Guild sharing"], 646, -116, 210, function() self:OpenSharing() end)
        local scroll = CreateFrame("ScrollFrame", nil, window)
        scroll:SetPoint("TOPLEFT", 24, -162); scroll:SetSize(832, 270)
        scroll:SetClipsChildren(true)
        local edit = UI.Input(scroll, "", 0, 19, 832, 270, 1500010)
        window.edit = edit
        edit:SetMultiLine(true); edit:SetJustifyV("TOP"); edit:SetScript("OnEnterPressed", nil)
        scroll:SetScrollChild(edit)
        UI.ScrollBar(scroll, window)
        scroll:EnableMouseWheel(true)
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
        UI.QuietButton(window, L["Generate export"], 24, -454, 186, function()
            local text = self:ExportIdentities(window.includePrivate)
            edit:SetText(text or ""); edit:SetFocus(); edit:HighlightText()
            window.feedback:SetText(text and L["Copy with Ctrl+C. Private notes are excluded unless selected."] or L["Unable to export these identities."])
        end)
        UI.QuietButton(window, L["Preview import"], 224, -454, 186, function()
            local preview = self:PreviewIdentityImport(edit:GetText())
            window.preview = preview and edit:GetText() or nil; window.apply:SetEnabled(preview ~= nil)
            window.feedback:SetText(preview and string.format(L["%d records: %d new, %d replacements. Review before importing."], preview.count, preview.added, preview.conflicts)
                or L["Invalid or oversized nickname backup."])
        end)
        window.apply = UI.QuietButton(window, L["Import backup"], 670, -454, 186, function()
            local text = window.preview
            if (not text or text ~= edit:GetText()) then return end
            local preview = self:PreviewIdentityImport(text)
            if (not preview) then return end
            local session = window.session
            Kit.Confirm(string.format(L["Merge %d records and replace %d existing identities? You can undo this operation."], preview.count, preview.conflicts), function()
                if (not window:IsShown() or window.session ~= session or window.preview ~= text or edit:GetText() ~= text) then return end
                local ok = self:ImportIdentities(text, preview.revision)
                window.feedback:SetText(ok and L["Backup imported. Undo is available."] or L["Invalid or oversized nickname backup."])
                window.preview = nil; window.apply:SetEnabled(false); self:ReloadCard()
            end)
        end)
        window.apply.primary = true
        window.apply:SetEnabled(false)
        window.feedback = UI.Label(window, "", 24, -505, 832, 12, 3)
        window:SetScript("OnHide", function()
            window.session = (window.session or 0)+1
            window.preview = nil; window.apply:SetEnabled(false); edit:ClearFocus()
        end)
        UI.Check(window.include, false, L["Include private notes"])
    end
    UI.Show(self.backupWindow)
end

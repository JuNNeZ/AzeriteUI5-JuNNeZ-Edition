-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Kit = ns.OptionsKit
local PAGE_SIZE = 15
local MEDIA = "Interface\\AddOns\\" .. Addon .. "\\Assets\\Guild\\"
local UI = {}
Guild.UI = UI
---@class AzeriteGuildButtonTexture: Texture
---@field sliceLeft number
---@field sliceRight number

-- A color texture provides a solid fill even if a client cannot resolve the
-- tooltip background used by the shared options backdrop.
UI.Opaque = function(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(); fill:SetColorTexture(.022, .025, .03, 1)
    frame.opaqueFill = fill
end

UI.Label = function(parent, text, x, y, width, size, lines)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(Kit.GetFont(size or 12, true))
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT")
    label:SetMaxLines(lines or 1); label:SetTextColor(.92, .88, .76); label:SetText(text)
    return label
end
UI.Button = function(parent, text, x, y, width, callback, primary)
    local button = CreateFrame("Button", nil, parent, ns.BackdropTemplate)
    button:SetSize(width, 28); button:SetPoint("TOPLEFT", x, y)
    button.parts, button.compact, button.closeGlyph = {}, width <= 32, text == "X"
    button.primary = primary
    if (button.compact) then
        local texture = button:CreateTexture(nil, "BACKGROUND")
        texture:SetSize(60, 60); texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.parts[1] = texture
    else
        -- The painting carries top/bottom shadow. A 34px draw centred on the
        -- existing 28px hit area leaves room inside the rim for 12px text.
        -- Fixed 17px caps preserve its points on the 630px Main buttons too.
        for index, slice in ipairs({ { 0, 17, 0, 32/256 }, { 17, width-34, 32/256, 224/256 }, { width-17, 17, 224/256, 1 } }) do
            local texture = button:CreateTexture(nil, "BACKGROUND")
            ---@cast texture AzeriteGuildButtonTexture
            texture:SetSize(slice[2], 34); texture:SetPoint("TOPLEFT", slice[1], 3)
            texture:SetTexture(MEDIA .. "button-states.tga")
            texture.sliceLeft, texture.sliceRight = slice[3], slice[4]
            button.parts[index] = texture
        end
    end
    local inset = button.compact and 2 or 20
    button.label = UI.Label(button, text, inset, -7, width-inset*2); button.label:SetJustifyH("CENTER")
    if (button.closeGlyph) then button.label:Hide() end
    button.check = button:CreateTexture(nil, "ARTWORK")
    button.check:SetTexture(ns.API.GetMedia("options-check")); button.check:SetSize(14, 14)
    button.check:SetPoint("TOPLEFT", 18, -7); button.check:SetVertexColor(1, .84, .4); button.check:Hide()
    button.RefreshArt = function(self)
        local enabled = self:IsEnabled()
        local gold = self.selected or self.primary
        local state = not enabled and 4 or self.pressed and 3 or self.hover and gold and 5 or self.hover and 1 or gold and 2 or 0
        self.visualState = state
        for _, texture in ipairs(self.parts) do
            if (self.compact) then
                texture:SetTexture(ns.API.GetMedia(self.closeGlyph and (self.hover and enabled and "options-close-bright" or "options-close") or "point_plate"))
                local tint = not enabled and .4 or self.pressed and .6 or self.hover and 1 or .85
                texture:SetVertexColor(tint, tint, tint)
            else
                texture:SetTexCoord(texture.sliceLeft, texture.sliceRight, state*64/512, (state+1)*64/512)
            end
        end
        self.label:SetTextColor(not enabled and .45 or 1, not enabled and .44 or gold and .85 or .93, not enabled and .42 or gold and .48 or .78)
        self.check:SetShown(self.selected and enabled or false)
    end
    button:SetScript("OnEnter", function(self) self.hover = true; self:RefreshArt() end)
    button:SetScript("OnLeave", function(self) self.hover, self.pressed = nil, nil; self:RefreshArt() end)
    button:SetScript("OnMouseDown", function(self) if (self:IsEnabled()) then self.pressed = true; self:RefreshArt() end end)
    button:SetScript("OnMouseUp", function(self) self.pressed = nil; self:RefreshArt() end)
    button:SetScript("OnDisable", function(self) self.hover, self.pressed = nil, nil; self:RefreshArt() end)
    button:SetScript("OnEnable", function(self) self:RefreshArt() end)
    button:SetScript("OnHide", function(self) self.hover, self.pressed = nil, nil; self:RefreshArt() end)
    button:SetScript("OnClick", callback)
    button:RefreshArt()
    return button
end
-- Quiet actions share the options well instead of repeating a painted gold
-- frame around every filter. Keep the same press/selection contract as Button.
UI.QuietButton = function(parent, text, x, y, width, callback, primary)
    local button = UI.Button(parent, text, x, y, width, callback, primary)
    if (button.compact) then return button end
    for _, texture in ipairs(button.parts) do texture:Hide() end
    button:SetBackdrop(Kit.Look and Kit.Look.InsetBackdrop or Kit.InsetBackdrop)
    local refresh = button.RefreshArt
    button.RefreshArt = function(self)
        refresh(self)
        local enabled, active = self:IsEnabled(), self.selected or self.primary
        self:SetBackdropColor(active and .18 or .065, active and .14 or .072, active and .065 or .085, 1)
        local edge = not enabled and .22 or self.pressed and .42 or self.hover and .8 or active and .65 or .32
        self:SetBackdropBorderColor(edge, edge*.9, edge*.7, 1)
        if (self.navigation) then self.check:Hide() end
    end
    button:RefreshArt()
    return button
end
UI.Rule = function(parent, x, y, width)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(ns.API.GetMedia("bar-small")); rule:SetSize(width, 3); rule:SetPoint("TOPLEFT", x, y)
    rule:SetVertexColor(.55, .48, .33, .65)
    return rule
end
UI.ScrollBar = function(scroll, parent)
    if (not Kit.Controls or not Kit.Controls.CreateScrollBar) then return end
    local bar = Kit.Controls.CreateScrollBar(scroll, parent)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)
    return bar
end
UI.Input = function(parent, text, x, y, width, height, limit)
    UI.Label(parent, text, x, y, width)
    local input = CreateFrame("EditBox", nil, parent, ns.BackdropTemplate)
    input:SetSize(width, height or 28); input:SetPoint("TOPLEFT", x, y-19)
    input:SetFontObject(Kit.GetFont(12, true)); input:SetTextColor(.95, .92, .85)
    input:SetAutoFocus(false); input:SetMaxBytes(limit or 160); input:SetTextInsets(8, 8, 5, 5)
    input:SetBackdrop({ bgFile = MEDIA .. "input-well.tga", edgeFile = ns.API.GetMedia("border-aura"), edgeSize = 12,
        tile = true, tileSize = 64, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    input:SetBackdropColor(1, 1, 1, 1); input:SetBackdropBorderColor(.62, .6, .53, 1)
    input:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(1, .81, .39, 1) end)
    input:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(.62, .6, .53, 1) end)
    input:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    input:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    return input
end
UI.FitToScreen = function(frame)
    frame:SetScale(math.min(1, (UIParent:GetWidth()-50)/frame:GetWidth(), (UIParent:GetHeight()-50)/frame:GetHeight()))
end
UI.Shell = function(name, parent, width, height, modern)
    -- Independent top-level roots keep one tool's child controls from sharing
    -- frame levels with another tool. Logical closing stays with GuildManager.
    local frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
    frame:SetSize(width, height); frame:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0)
    UI.FitToScreen(frame)
    frame:SetScript("OnShow", function() UI.FitToScreen(frame) end)
    frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true)
    frame:SetClampedToScreen(true); frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(window) window:StartMoving() end)
    frame:SetScript("OnDragStop", function(window) window:StopMovingOrSizing() end)
    frame:SetBackdrop(Kit.WindowBackdrop); frame:SetBackdropColor(.022, .025, .03, 1)
    frame:SetBackdropBorderColor(.95, .83, .58, 1)
    UI.Opaque(frame)
    if (modern) then
        local look = Kit.Look
        local outset = Kit.WindowOutset or { left = 10, right = 10, top = 18, bottom = 18 }
        local casing = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
        casing:SetPoint("TOPLEFT", -outset.left, outset.top)
        casing:SetSize(width+outset.left+outset.right, height+outset.top+outset.bottom)
        casing:SetBackdrop(look and look.IsRounded() and look.CasingBackdrop or Kit.WindowCasing)
        casing:SetBackdropBorderColor(1, 1, 1, 1); casing:EnableMouse(false)
        -- Casing is drawn below the controls, outside the opaque body.
        frame.casing = casing
        frame:SetBackdrop(nil)
        frame:SetClampRectInsets(-outset.left, outset.right, outset.top, -outset.bottom)
    end
    tinsert(UISpecialFrames, name)
    UI.Button(frame, "X", width-48, -16, 28, function() frame:Hide() end)
    return frame
end
UI.Show = function(frame)
    if (frame.pageKey) then Guild:ShowPage(frame.pageKey); return end
    frame:Show()
    frame:Raise()
end
-- Owned pages share one root and one scale. Explicitly hide the content as
-- well as its viewport: IsShown guards and OnHide cancellation remain valid.
UI.Page = function(name, key, title, width, height, trim, help)
    if (not Guild.frame) then Guild:CreateWindow() end
    local host = CreateFrame("Frame", nil, Guild.frame)
    host:SetPoint("TOPLEFT", 200, -131); host:SetSize(1112, 596)
    local view = CreateFrame("ScrollFrame", nil, host)
    view:SetPoint("TOPLEFT", 0, 0); view:SetSize(1096, 596); view:SetClipsChildren(true)
    local holder = CreateFrame("Frame", nil, view)
    trim = trim or 0
    holder:SetSize(1096, math.max(596, height-trim)); view:SetScrollChild(holder)
    local page = CreateFrame("Frame", name, holder)
    page:SetSize(width, height); page:SetPoint("TOPLEFT", math.max(0, (1096-width)/2), trim)
    page.pageKey, page.pageTitle, page.viewport, page.host = key, title, view, host
    page.help = help
    UI.Opaque(page)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(_, delta)
        view:SetVerticalScroll(math.max(0, math.min(view:GetVerticalScroll()-delta*36, view:GetVerticalScrollRange())))
    end)
    page.scrollBar = UI.ScrollBar(view, host)
    Guild.pages[key] = page
    page:Hide(); view:Hide(); host:Hide()
    return page
end
Guild.ShowPage = function(self, key)
    local page = self.pages and self.pages[key]
    if (not page) then return end
    if (self.activePage ~= key) then
        local previous = self.pages[self.activePage]
        if (previous) then
            previous:Hide()
            if (previous.viewport) then previous.viewport:Hide() end
            if (previous.host) then previous.host:Hide() end
        end
    end
    self.activePage = key
    for id, button in pairs(self.navigation) do
        button.selected = id == key; button:RefreshArt()
    end
    self.pageTitle:SetText(page.pageTitle)
    self.pageHelp:SetText(page.help or "")
    -- Set the active page before showing the root; its OnShow refresh reads it.
    self.frame:Show(); self.frame:Raise()
    if (page.host) then page.host:Show() end
    if (page.viewport) then page.viewport:Show() end
    page:Show()
    if (page.scrollBar) then page.scrollBar:Update() end
    self:RefreshWindow()
end
UI.Check = function(button, value, text)
    button.selected = value and true or false
    button.label:ClearAllPoints(); button.label:SetPoint("TOPLEFT", 34, -7)
    button.label:SetWidth(button:GetWidth()-52); button.label:SetText(text)
    button:RefreshArt()
end
UI.Icon = function(texture, class)
    if (class) then texture:SetAtlas("classicon-" .. class, false); texture:Show() else texture:Hide() end
end

Guild.SelectCharacter = function(self, row, person)
    self.selected = row.key
    self.selectedRoot = person and person.key or select(2, self:Resolve(row.member.name)) or row.key
    local record = self.db.global.characters[row.key]
    local details = self.db.global.characters[self.selectedRoot] or {}
    self.character:SetText(row.member.name); self.nickname:SetText(record and record.nickname or "")
    local mainRecord = record and record.main and self.db.global.characters[record.main]
    self.main:SetText(mainRecord and mainRecord.name or record and record.main or "")
    self.privateNote:SetText(details.privateNote or ""); self.favoriteValue = details.favorite == true
    UI.Check(self.favorite, self.favoriteValue, L["Favorite person"])
    self.cardTitle:SetText(person and person.label or row.nickname or row.member.name)
    self.cardSummary:SetText(person and string.format(L["%d characters, %d online"], #person.rows, person.online) or "")
    self.cardRank:SetText((row.member.rank or L["Saved character"]) .. "  |  " .. (row.member.zone or ""))
    self.cardLastOnline:SetText(L["Person last online"] .. ": " .. self:LastOnlineText(person and person.online > 0 or row.member.online, person and person.lastOnline or row.member.lastOnline))
    UI.Icon(self.cardIcon, row.member.class)
    self.note:SetText(row.member.note or ""); self.noteValue = row.member.note; self.feedback:SetText("")
    self:RefreshWindow()
end
Guild.LinkToSelectedMain = function(self, row)
    if (not self.selected or row.key == self.selected) then return end
    local _, root = self:Resolve(self.selected)
    local target = self.db.global.characters[root or self.selected] or (self.members or {})[root or self.selected]
    if (not target) then return end
    local valid = self:SaveIdentity(row.member.name, "", target.name)
    self.feedback:SetText(valid and L["Alt linked to the selected main."] or L["Invalid name, nickname or main/alt cycle."])
end
Guild.RefreshWindow = function(self)
    if (not self.frame or not self.frame:IsShown() or self.buildingWindow) then return end
    local rows, people, online, characters = self:GetDisplayRows(self.search:GetText(), self.filters, self.expanded)
    self.offset = math.max(0, math.min(self.offset or 0, math.max(0, #rows-PAGE_SIZE)))
    self.heading:SetText(self.ReadText(GetGuildInfo("player")) or L["Guild & Nicknames"])
    self.summary:SetText(string.format(L["%d people  /  %d characters  /  %d online"], people, characters, online))
    self.pageSummary:SetText(self.activePage == "followup" and self.followUpWindow and self.followUpWindow.summary:GetText() or "")
    self.count:SetText(string.format(L["%d to %d of %d rows"], #rows > 0 and self.offset+1 or 0, math.min(#rows, self.offset+PAGE_SIZE), #rows))
    for key, button in pairs(self.filterButtons) do UI.Check(button, self.filters[key], button.caption) end
    self.classFilter.label:SetText(L["Class"] .. ": " .. (self.filters.class or L["All"]))
    self.rankFilter.label:SetText(L["Rank"] .. ": " .. (self.filters.rank or L["All"]))
    UI.Check(self.chat, self.db.profile.chatNicknames, L["Chat nicknames"])
    UI.Check(self.nicknameLevels, self.db.profile.nicknameLevels, L["Show levels with nicknames"])
    self.nicknameLevels:SetEnabled(self.db.profile.chatNicknames == true)
    self.undo:SetEnabled(self.undoStack and #self.undoStack > 0 or false)
    local provider = rawget(_G, "Chattynator")
    local api = type(provider) == "table" and provider.API
    self.status:SetText(self.chatAPI and L["Chattynator connected"] or api and L["Chat nicknames are off."] or L["Chat nicknames require Chattynator"])
    for index, button in ipairs(self.rows) do
        local item = rows[self.offset+index]
        button.data = item; button:SetShown(item ~= nil)
        if (item) then
            local person, member = item.person, item.row and item.row.member or item.person.rows[1].member
            local isPerson = item.kind == "person"
            button.icon:ClearAllPoints(); button.icon:SetPoint("TOPLEFT", isPerson and 24 or 40, -3)
            button.name:ClearAllPoints(); button.name:SetPoint("TOPLEFT", isPerson and 63 or 79, -6)
            button.name:SetWidth(isPerson and 305 or 289)
            button.arrow:SetText(isPerson and (self.expanded[person.key] and "-" or "+") or "")
            UI.Icon(button.icon, member.class)
            button.name:SetText(isPerson and person.label or member.name)
            button.favorite:SetShown(isPerson and person.favorite)
            button.detail:SetText(isPerson and string.format(L["%d chars"], #person.rows)
                or (item.key == person.key and L["Main"] or L["Alt"]) .. " / " .. (member.rank or ""))
            local onlineNow = isPerson and person.online > 0 or member.online
            button.status:SetText(isPerson and string.format(L["%d online"], person.online) or (member.online and L["Online"] or L["Offline"]))
            button.dot:SetTexCoord(onlineNow and 0 or .5, onlineNow and .5 or 1, 0, 1)
            button.background:SetColorTexture(onlineNow and .85 or .4, onlineNow and .65 or .4, onlineNow and .25 or .4,
                self.selected == item.key and .18 or isPerson and .075 or .025)
            local color = member.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
            if (onlineNow) then button.name:SetTextColor(color and color.r or .92, color and color.g or .88, color and color.b or .76)
            else button.name:SetTextColor(.52, .52, .52) end
            for _, label in ipairs({ button.detail, button.status, button.arrow }) do
                label:SetTextColor(onlineNow and .92 or .48, onlineNow and .88 or .48, onlineNow and .76 or .48)
            end
            button.icon:SetDesaturated(not onlineNow); button.favorite:SetDesaturated(not onlineNow)
            local tint = onlineNow and 1 or .6
            button.icon:SetVertexColor(tint, tint, tint); button.favorite:SetVertexColor(tint, tint, tint)
        end
    end
    self.previous:SetEnabled(self.offset > 0); self.next:SetEnabled(self.offset+PAGE_SIZE < #rows)
    local selected = self.selected and (self.members or {})[self.selected]
    if (selected) then
        self.note:SetText(selected.note or ""); self.noteValue = selected.note
        self.cardRank:SetText((selected.rank or "") .. "  |  " .. (selected.zone or ""))
        self.cardIcon:SetDesaturated(not selected.online)
        local tint = selected.online and 1 or .6
        self.cardIcon:SetVertexColor(tint, tint, tint)
    end
    if (self.selected) then
        for _, person in ipairs(self:GetPeople("", {})) do
            for _, row in ipairs(person.rows) do
                if (row.key == self.selected) then
                    local online = person.online > 0
                    self.cardTitle:SetTextColor(online and .92 or .52, online and .88 or .52, online and .76 or .52)
                    self.cardSummary:SetText(string.format(L["%d characters, %d online"], #person.rows, person.online)
                        .. "  |  " .. self:LastOnlineText(row.member.online, row.member.lastOnline))
                    self.cardLastOnline:SetText(L["Person last online"] .. ": " .. self:LastOnlineText(person.online > 0, person.lastOnline))
                end
            end
        end
    end
    local available = selected and selected.online and not InCombatLockdown() or false
    self.guildActions:SetEnabled(selected and selected.guid and not InCombatLockdown() or false)
    self.whisper:SetEnabled(available and ChatFrameUtil and type(ChatFrameUtil.SendTell) == "function" or false)
    self.invite:SetEnabled(available and C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" or false)
    self:RefreshHome()
    self:RefreshHistory()
    self:RefreshFollowUp()
    self:RefreshGuildActions()
    if (self.RefreshSharing) then self:RefreshSharing() end
    if (self.RefreshCrafting) then self:RefreshCrafting() end
    if (self.noteReview and self.noteReview:IsShown()) then self:RefreshNoteReview() end
end
Guild.CycleFilter = function(self, field)
    local choices, nextValue = self:GetFilterChoices(field)
    if (not self.filters[field]) then nextValue = choices[1]
    else for i, value in ipairs(choices) do if (value == self.filters[field]) then nextValue = choices[i+1]; break end end end
    self.filters[field], self.offset = nextValue, 0; self:RefreshWindow()
end

Guild.CreateWindow = function(self)
    if (self.frame) then return end
    self.buildingWindow = true
    local shell = UI.Shell(ns.Prefix .. "GuildManager", UIParent, 1320, 760, true)
    self.frame, self.filters, self.expanded = shell, {}, {}
    local art = shell:CreateTexture(nil, "BACKGROUND")
    art:SetPoint("TOPLEFT", 14, -12); art:SetSize(1292, 108)
    art:SetTexture(MEDIA .. "header.tga")
    self.heading = UI.Label(shell, "AzeriteUI", 142, -36, 850, 22)
    self.summary = UI.Label(shell, "", 144, -72, 710, 13)
    self.pageTitle = UI.Label(shell, L["Guild members"], 1020, -43, 250, 17, 2)
    self.pageSummary = UI.Label(shell, "", 1020, -72, 260, 11, 1)
    self.pageHelp = UI.Label(shell, "", 224, -98, 1072, 11, 1)
    UI.Rule(shell, 20, -117, 1280)
    local rail = CreateFrame("Frame", nil, shell, ns.BackdropTemplate)
    rail:SetPoint("TOPLEFT", 18, -131); rail:SetSize(174, 596)
    rail:SetBackdrop(Kit.Look and Kit.Look.InsetBackdrop or Kit.InsetBackdrop)
    rail:SetBackdropColor(.035, .04, .05, 1); rail:SetBackdropBorderColor(.32, .29, .23, 1)
    self.navigation, self.pages = {}, {}
    for index, entry in ipairs({
        { "home", L["Guild home"], L["Group Frames"], function() self:OpenHome() end },
        { "members", L["Guild members"], L["Unit Frames"], function() self:ShowPage("members") end },
        { "crafting", L["Guild crafting"], L["Bags"], function() self:OpenCrafting() end },
        { "history", L["Guild history"], "changelog", function() self:OpenHistory() end },
        { "followup", L["Officer follow-up"], "Objectives Tracker", function() self:OpenFollowUp() end },
        { "notes", L["Review guild notes"], "Objectives Tracker", function() self:OpenNoteReview() end },
        { "backup", L["Backup / Share"], "profiles", function() self:OpenBackup() end },
        { "sharing", L["Guild sharing"], "sharing", function() self:OpenSharing() end },
        { "actions", L["Guild actions"], L["Debug tools"], function() self:OpenGuildActions() end }
    }) do
        local button = UI.QuietButton(rail, entry[2], 8, -14-(index-1)*44, 158, entry[4])
        button.label:ClearAllPoints(); button.label:SetPoint("TOPLEFT", 34, -7)
        button.label:SetWidth(116); button.label:SetJustifyH("LEFT")
        button.navigation, button.selected = true, entry[1] == "members"; button:RefreshArt()
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20); icon:SetPoint("TOPLEFT", 8, -4)
        local look = Kit.Look
        -- Guild owns an opaque dark palette, including when options use Light.
        if (look and look.GetPageIconCoords) then
            icon:SetTexture(ns.API.GetMedia("options-pages")); icon:SetTexCoord(look.GetPageIconCoords(entry[3]))
        end
        self.navigation[entry[1]] = button
    end
    self.guildActions = self.navigation.actions
    local frame = CreateFrame("Frame", nil, shell)
    frame:SetPoint("TOPLEFT", 200, 0); frame:SetSize(1120, 760)
    self.memberPage = frame
    frame.pageKey, frame.pageTitle = "members", L["Guild members"]
    self.pages.members, self.activePage = frame, "members"
    frame:SetScript("OnHide", function()
        for _, box in ipairs({ self.search, self.character, self.nickname, self.main, self.privateNote }) do box:ClearFocus() end
    end)
    local Button = UI.QuietButton
    self.search = UI.Input(frame, L["Search names, notes or levels (40-60)"], 24, -131, 310)
    self.search:SetScript("OnTextChanged", function() self.offset = 0; self:RefreshWindow() end)
    self.filterButtons = {}
    local function Filter(key, text, x, y, width)
        local button = Button(frame, text, x, y, width, function()
            self.filters[key] = not self.filters[key]; self.offset = 0; self:RefreshWindow()
        end)
        button.caption = text; self.filterButtons[key] = button
    end
    Filter("online", L["Online people"], 346, -150, 144); Filter("favorite", L["Favorites"], 500, -150, 156)
    Filter("missing", L["No nickname"], 24, -190, 148); Filter("unlinked", L["Without main/alt"], 182, -190, 154)
    self.classFilter = Button(frame, "", 346, -190, 144, function() self:CycleFilter("class") end)
    self.rankFilter = Button(frame, "", 500, -190, 156, function() self:CycleFilter("rank") end)
    UI.Label(frame, L["Person / Character"], 72, -233, 300); UI.Label(frame, L["Characters / Rank"], 406, -233, 135)
    self.rows = {}
    for index = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(632, 25); row:SetPoint("TOPLEFT", 24, -254-(index-1)*26)
        row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
        row.arrow = UI.Label(row, "", 5, -6, 15, 14)
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(18, 18); row.icon:SetPoint("TOPLEFT", 24, -3)
        row.favorite = row:CreateTexture(nil, "ARTWORK"); row.favorite:SetTexture(MEDIA .. "favorite.tga")
        row.favorite:SetSize(12, 12); row.favorite:SetPoint("TOPLEFT", 47, -6)
        row.name = UI.Label(row, "", 63, -6, 305); row.detail = UI.Label(row, "", 382, -6, 125, 11)
        row.dot = row:CreateTexture(nil, "ARTWORK"); row.dot:SetSize(20, 20); row.dot:SetPoint("TOPLEFT", 509, -2)
        row.dot:SetTexture(MEDIA .. "status.tga")
        row.status = UI.Label(row, "", 532, -6, 98, 11)
        row:SetHighlightTexture(ns.API.GetMedia("plain")); row:GetHighlightTexture():SetVertexColor(1, .85, .5, .1)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(button, mouse)
            local item = button.data
            if (not item) then return end
            local data = item.row or item.person.rows[1]
            if (mouse == "RightButton") then self:LinkToSelectedMain(data)
            else
                if (item.kind == "person") then self.expanded[item.person.key] = not self.expanded[item.person.key] end
                self:SelectCharacter(data, item.person)
            end
        end)
        row:SetScript("OnEnter", function(button)
            if (not button.data or GameTooltip:IsForbidden()) then return end
            local item = button.data; local data = item.row or item.person.rows[1]
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT"); GameTooltip:AddLine(data.member.name)
            GameTooltip:AddLine(data.member.zone or "", 1, 1, 1)
            GameTooltip:AddLine(L["Last online"] .. ": " .. self:LastOnlineText(data.member.online, data.member.lastOnline), 1, 1, 1)
            GameTooltip:AddLine(L["Main character"] .. ": " .. item.person.name, 1, .85, .5, true)
            GameTooltip:AddLine(data.member.note or "", 1, 1, 1, true)
            GameTooltip:AddLine(L["Right-click: link this alt to the selected main."], .8, .8, .8, true); GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end end)
        self.rows[index] = row
    end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) self.offset = (self.offset or 0)-delta*3; self:RefreshWindow() end)
    self.previous = Button(frame, "<", 24, -652, 30, function() self.offset = (self.offset or 0)-PAGE_SIZE; self:RefreshWindow() end)
    self.next = Button(frame, ">", 62, -652, 30, function() self.offset = (self.offset or 0)+PAGE_SIZE; self:RefreshWindow() end)
    self.count = UI.Label(frame, "", 106, -661, 380)
    Button(frame, L["Refresh"], 546, -652, 110, function() self:RequestRoster() end)
    self.undo = Button(frame, L["Undo"], 24, -696, 92, function() self:UndoIdentity(); self:ReloadCard() end)
    self.chat = Button(frame, "", 134, -696, 178, function()
        self.db.profile.chatNicknames = not self.db.profile.chatNicknames; self:UpdateSettings()
    end)
    self.nicknameLevels = Button(frame, "", 322, -696, 334, function()
        self.db.profile.nicknameLevels = not self.db.profile.nicknameLevels; self:UpdateSettings()
    end)
    self.status = UI.Label(frame, "", 24, -735, 630, 11)
    local card = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
    card:SetPoint("TOPLEFT", 682, -131); card:SetSize(414, 596)
    card:SetBackdrop(Kit.Look and Kit.Look.InsetBackdrop or Kit.InsetBackdrop); card:SetBackdropColor(.03, .033, .038, 1); card:SetBackdropBorderColor(.32, .29, .23, 1)
    UI.Opaque(card)
    UI.Rule(card, 18, -116, 376); UI.Rule(card, 18, -292, 376); UI.Rule(card, 18, -362, 376)
    self.cardIcon = card:CreateTexture(nil, "ARTWORK"); self.cardIcon:SetSize(32, 32); self.cardIcon:SetPoint("TOPLEFT", 18, -18); self.cardIcon:Hide()
    self.cardTitle = UI.Label(card, L["Select a person"], 60, -21, 332, 17)
    self.cardSummary = UI.Label(card, "", 18, -65, 376); self.cardRank = UI.Label(card, "", 18, -88, 376)
    self.cardLastOnline = UI.Label(card, "", 18, -107, 376, 11)
    self.character = UI.Input(card, L["Character (Name-Realm)"], 18, -124, 376)
    self.nickname = UI.Input(card, L["Nickname"], 18, -182, 376, 28, 48)
    self.main = UI.Input(card, L["Main character (optional)"], 18, -240, 376)
    UI.Label(card, L["Guild note"], 18, -301, 376); self.note = UI.Label(card, "", 18, -323, 376, 12, 2)
    UI.Label(card, L["Private note (only you)"], 18, -371, 376)
    local privateScroll = CreateFrame("ScrollFrame", nil, card)
    privateScroll:SetPoint("TOPLEFT", 18, -390); privateScroll:SetSize(376, 55); privateScroll:SetClipsChildren(true)
    self.privateNote = UI.Input(privateScroll, "", 0, 19, 376, 55, 512)
    self.privateNote:SetMultiLine(true); self.privateNote:SetJustifyV("TOP"); self.privateNote:SetScript("OnEnterPressed", nil)
    privateScroll:SetScrollChild(self.privateNote); privateScroll:EnableMouseWheel(true)
    UI.ScrollBar(privateScroll, card)
    privateScroll:SetScript("OnMouseWheel", function(_, delta)
        privateScroll:SetVerticalScroll(math.max(0, math.min(privateScroll:GetVerticalScroll()-delta*24, privateScroll:GetVerticalScrollRange())))
    end)
    self.privateNote:SetScript("OnTextChanged", function(box) box:SetHeight(math.max(55, box:GetNumLines()*15+10)) end)
    self.privateNote:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset = privateScroll:GetVerticalScroll()
        if (-y < offset) then privateScroll:SetVerticalScroll(-y)
        elseif (-y+height > offset+privateScroll:GetHeight()) then privateScroll:SetVerticalScroll(-y+height-privateScroll:GetHeight()) end
    end)
    self.favorite = Button(card, L["Favorite person"], 18, -456, 186, function()
        self.favoriteValue = not self.favoriteValue; UI.Check(self.favorite, self.favoriteValue, L["Favorite person"])
    end)
    Button(card, L["Use note suggestion"], 214, -456, 180, function()
        local candidate = self:NoteCandidate(self.noteValue)
        if (candidate) then self.nickname:SetText(candidate); self.main:SetText("") end
        self.feedback:SetText(candidate and L["Review the nickname, then save."] or L["No name suggestion in this note."])
    end)
    Button(card, L["Save identity"], 18, -498, 180, function() self:SaveCard() end, true)
    Button(card, L["Remove local identity"], 208, -498, 186, function()
        self:ForgetIdentity(self.character:GetText()); self:ReloadCard(); self.feedback:SetText(L["Local identity removed."])
    end)
    self.feedback = UI.Label(card, "", 18, -539, 376, 11, 2)
    self.whisper = Button(card, L["Whisper"], 18, -563, 180, function() self:ContactSelected(false) end)
    self.invite = Button(card, L["Invite to group"], 208, -563, 186, function() self:ContactSelected(true) end)
    shell:SetScript("OnShow", function()
        UI.FitToScreen(shell)
        local page = self.pages[self.activePage]
        if (page) then
            if (page.host) then page.host:Show() end
            if (page.viewport) then page.viewport:Show() end
            page:Show()
        end
        self:RefreshWindow()
    end)
    shell:SetScript("OnHide", function()
        for _, page in pairs(self.pages) do
            page:Hide()
            if (page.viewport) then page.viewport:Hide() end
            if (page.host) then page.host:Hide() end
        end
        if (self.craftingTransfer) then self.craftingTransfer:Hide() end
        if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end
    end)
    self.buildingWindow = nil
end
Guild.ReloadCard = function(self)
    if (not self.selected) then return end
    for _, person in ipairs(self:GetPeople("", {})) do
        for _, row in ipairs(person.rows) do if (row.key == self.selected) then self:SelectCharacter(row, person); return end end
    end
    self:RefreshWindow()
end
Guild.SaveCard = function(self)
    local name, nickname, main, note = self.character:GetText(), self.nickname:GetText(), self.main:GetText(), self.privateNote:GetText()
    if (#note > 512 or note:find("[|%z\1-\8\11-\31]")) then self.feedback:SetText(L["Invalid private note."]); return end
    if (not self:SavePersonCard(name, nickname, main, self.favoriteValue == true, note)) then
        self.feedback:SetText(L["Invalid name, nickname or main/alt cycle."]); return
    end
    self.selected = self:CharacterKey(name); self:ReloadCard(); self.feedback:SetText(L["Saved locally."])
end
Guild.ToggleWindow = function(self, input)
    if (self.ReadText(input) and input:match("^%s*status%s*$")) then self:Print(self:GetChatDiagnostic()); return end
    if (not self.frame) then self:CreateWindow(); UI.Show(self.frame); self:RequestRoster(); self:UpdateSettings(); return end
    self.frame:SetShown(not self.frame:IsShown())
    if (self.frame:IsShown()) then self.frame:Raise(); self:RequestRoster(); self:UpdateSettings() end
end

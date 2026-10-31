-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
local Addon, ns = ...
if (not ns.IsMainline) then return end
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Tools = ns:NewModule("RaidTools", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceConsole-3.0")
local MEDIA = "Interface\\AddOns\\" .. Addon .. "\\Assets\\RaidTools\\"
local GROUND = { 5, 6, 3, 2, 7, 1, 4, 8 }
local defaults = { profile = ns:Merge({
    enabled = true, collapsed = false, markerMode = "target", hideGroups = false,
    groups = { true, true, true, true, true, true, true, true }
}, ns.MovableModulePrototype.defaults) }

Tools.GenerateDefaults = function(self)
    local scale = ns.API.GetEffectiveScale()
    defaults.profile.savedPosition = { scale = scale, "LEFT", 8 * scale, 0 }
    return defaults
end

Tools.ReadNumber = function(value)
    if (issecretvalue and issecretvalue(value)) then return end
    if (type(value) == "number") then return value end
end

local Leave = function()
    if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end
end
local Enter = function(button)
    if (GameTooltip:IsForbidden()) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(button.tooltip or L["Raid / Party panel"], 1, .82, .3, true)
    if (button.markerIndex) then
        GameTooltip:AddLine(L["Left-click: set. Right-click: clear. Shift: switch marker type."], 1, 1, 1, true)
    end
    GameTooltip:Show()
end
local Text = function(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(ns.API.GetFont(size, true))
    text:SetTextColor(.9, .87, .78)
    return text
end
local Label = function(parent, label, y)
    local text = Text(parent, 12)
    text:SetPoint("TOPLEFT", 18, y)
    text:SetText(label)
    return text
end
local Button = function(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", x, y)
    button:SetNormalTexture(MEDIA .. "button.tga")
    button:SetHighlightTexture(MEDIA .. "button-highlight.tga", "ADD")
    local text = Text(button, 11)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("CENTER")
    text:SetMaxLines(1)
    text:SetText(label)
    button.label, button.tooltip = text, label
    button:SetScript("OnClick", callback)
    button:SetScript("OnEnter", Enter)
    button:SetScript("OnLeave", Leave)
    return button
end
local Enable = function(button, enabled, selected)
    button:SetEnabled(enabled and true or false)
    button.label:SetTextColor(enabled and .94 or .45, enabled and .89 or .44, enabled and .74 or .42)
    button:GetNormalTexture():SetVertexColor(selected and 1 or .7, selected and .85 or .7, selected and .5 or .7)
end

Tools.ConfigureMarker = function(self, button, index)
    if (InCombatLockdown()) then return end
    local world = self.db.profile.markerMode == "world"
    local mainType, otherType = world and "worldmarker" or "raidtarget", world and "raidtarget" or "worldmarker"
    button:SetAttribute("type1", mainType)
    button:SetAttribute("type2", mainType)
    button:SetAttribute("shift-type1", otherType)
    button:SetAttribute("shift-type2", otherType)
    -- Native secure dispatch rejects a missing unit before it checks the action type.
    -- World markers and clear-all have no unit; "none" explicitly bypasses that gate.
    local mainUnit = (mainType == "worldmarker" or index == 9) and "none" or "target"
    local otherUnit = (otherType == "worldmarker" or index == 9) and "none" or "target"
    button:SetAttribute("unit1", mainUnit)
    button:SetAttribute("unit2", mainUnit)
    button:SetAttribute("shift-unit1", otherUnit)
    button:SetAttribute("shift-unit2", otherUnit)
    if (index <= 8) then
        button:SetAttribute("marker1", world and GROUND[index] or index)
        button:SetAttribute("marker2", world and GROUND[index] or nil)
        button:SetAttribute("shift-marker1", world and index or GROUND[index])
        button:SetAttribute("shift-marker2", not world and GROUND[index] or nil)
        button:SetAttribute("action1", "set")
        button:SetAttribute("action2", "clear")
        button:SetAttribute("shift-action1", "set")
        button:SetAttribute("shift-action2", "clear")
    else
        for _, key in ipairs({ "marker1", "marker2", "shift-marker1", "shift-marker2" }) do button:SetAttribute(key, nil) end
        button:SetAttribute("action1", world and "clear" or "clear-all")
        button:SetAttribute("action2", world and "clear" or "clear-all")
        button:SetAttribute("shift-action1", world and "clear-all" or "clear")
        button:SetAttribute("shift-action2", world and "clear-all" or "clear")
    end
end

Tools.PrepareFrames = function(self)
    if (InCombatLockdown() or self.frame) then return end
    local frame = CreateFrame("Frame", ns.Prefix .. "RaidTools", UIParent)
    frame:SetSize(274, 500)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()
    self.frame = frame
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetSize(252, 500)
    panel:SetPoint("LEFT", 22, 0)
    panel:EnableMouse(true)
    local art = panel:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(MEDIA .. "full-panel.tga")
    self.panel = panel
    self.heading = Label(panel, _G.PARTY or L["Raid / Party panel"], -30)
    self.heading:ClearAllPoints()
    self.heading:SetPoint("TOP", panel, "TOP", 0, -30)
    self.memberCount = Text(panel, 12)
    self.memberCount:SetPoint("LEFT", self.heading, "RIGHT", 8, 0)
    self.roleCounts = {}
    for i, data in ipairs({ {"TANK", "tank"}, {"HEALER", "heal"}, {"DAMAGER", "dps"} }) do
        local icon = panel:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(ns.API.GetMedia("grouprole-icons-" .. data[2]))
        icon:SetSize(20, 20)
        icon:SetTexCoord(12/64, 54/64, 12/64, 56/64)
        icon:SetPoint("CENTER", panel, "TOP", (i-2)*72, -61)
        local count = Text(panel, 12)
        count:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        count.roleIcon, count.columnOffset = icon, (i-2)*72
        self.roleCounts[data[1]] = count
    end
    Label(panel, L["Raid groups"], -83)
    self.groupButtons = {}
    for i = 1, 8 do
        local index = i
        local button = Button(panel, tostring(i), 18 + ((i-1)%4)*55, -102-math.floor((i-1)/4)*31, 49, function()
            if (self.preview) then return end
            self.db.profile.groups = self.db.profile.groups or {}
            self.db.profile.groups[index] = self.db.profile.groups[index] == false
            self:UpdateSettings()
        end)
        button.tooltip = L["Filter AzeriteUI's large raid frames. Changes made in combat apply afterward."]
        self.groupButtons[i] = button
    end
    Label(panel, L["Markers"], -174)
    self.targetTab = Button(panel, _G.TARGET or L["Target"], 18, -192, 104, function() self:SetMarkerMode("target") end)
    self.worldTab = Button(panel, _G.WORLD or L["Ground"], 130, -192, 104, function() self:SetMarkerMode("world") end)
    self.buttons = {}
    for index = 1, 9 do
        local button = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate")
        button:SetSize(30, 28)
        local row, column = math.floor((index-1)/4), (index-1)%4
        if (index == 9) then row, column = 0, 4 end
        button:SetPoint("TOPLEFT", 18+column*44, -226-row*31)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button.markerIndex = index
        button.tooltip = index <= 8 and _G["RAID_TARGET_" .. index] or L["Clear all markers"]
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("CENTER")
        if (index <= 8) then
            icon:SetTexture(ns.API.GetMedia("raid_target_icons_small"))
            local col, r = (index-1)%4, math.floor((index-1)/4)
            icon:SetTexCoord(col/4, (col+1)/4, r/4, (r+1)/4)
        else
            icon:SetTexture(MEDIA .. "clear.tga")
        end
        button:SetHighlightTexture(MEDIA .. "highlight.tga", "ADD")
        button:SetScript("OnEnter", Enter)
        button:SetScript("OnLeave", Leave)
        self.buttons[index] = button
    end
    self.controls = {}
    local specs = {
        { "ready", _G.READY_CHECK or L["Ready check"], 18, -290, 104 },
        { "roles", _G.ROLE_POLL or L["Role check"], 130, -290, 104 },
        { "countdown", L["Countdown: 10s"], 18, -320, 104 },
        { "assist", L["All assist"], 130, -320, 104 },
        { "convert", L["Party / Raid"], 18, -350, 104 },
        { "difficulty", _G.CRF_DIFFICULTY or L["Difficulty"], 130, -350, 104 },
        { "pings", L["Ping permissions"], 18, -380, 216 },
        { "visibility", L["Hide raid frames"], 18, -410, 104 },
        { "settings", L["Settings"], 130, -410, 104 },
        { "leave", L["Leave group"], 18, -440, 104 },
        { "instance", L["Leave instance"], 130, -440, 104 }
    }
    for _, spec in ipairs(specs) do
        local key = spec[1]
        self.controls[key] = Button(panel, spec[2], spec[3], spec[4], spec[5], function(button) self:PerformAction(key, button) end)
    end
    -- Compact face labels stay inside the pointed button ends; tooltips retain full actions.
    self.controls.countdown.label:SetText("10s")
    self.controls.instance.tooltip = _G.INSTANCE_PARTY_LEAVE or L["Leave instance group"]
    local toggle = CreateFrame("Button", nil, frame)
    toggle:SetSize(22, 44)
    toggle:SetPoint("LEFT", 0, 0)
    toggle:SetNormalTexture(MEDIA .. "toggle.tga")
    toggle:SetHighlightTexture(MEDIA .. "toggle.tga", "ADD")
    toggle:GetHighlightTexture():SetAlpha(.3)
    toggle.tooltip = L["Click to fold or unfold. Move with /lock. Folding waits until combat ends."]
    toggle:SetScript("OnClick", function()
        self.db.profile.collapsed = not self.db.profile.collapsed
        self:UpdateSettings()
    end)
    toggle:SetScript("OnEnter", Enter)
    toggle:SetScript("OnLeave", Leave)
    self.toggle = toggle
end

Tools.SetMarkerMode = function(self, mode)
    if (mode ~= "target" and mode ~= "world") then return end
    self.db.profile.markerMode = mode
    self:UpdateSettings()
end

Tools.UpdateSummary = function(self)
    local raid = IsInRaid()
    local count = self.ReadNumber(GetNumGroupMembers())
    if (count) then count = math.min(40, math.max(0, math.floor(count))) end
    self.heading:SetText(raid and (_G.RAID or L["Raid"]) or (_G.PARTY or L["Party / Raid"]))
    self.memberCount:SetText(self.preview and L["Preview"] or (count and tostring(count) or "-"))
    -- Centre the complete title/count pair, including multi-digit counts and Preview.
    local headingWidth = self.heading:GetStringWidth()
    local countWidth = self.memberCount:GetStringWidth()
    self.heading:ClearAllPoints()
    self.heading:SetPoint("TOPLEFT", self.panel, "TOP", -(headingWidth + 8 + countWidth)/2, -30)
    local roles = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local groups, known = {}, true
    if (count) then
        for i = 1, count do
            local unit = raid and ("raid" .. i) or (i == 1 and "player" or "party" .. (i-1))
            local role = UnitGroupRolesAssigned(unit)
            if (issecretvalue and issecretvalue(role)) then known = false
            elseif (roles[role] ~= nil) then roles[role] = roles[role] + 1 end
            if (raid) then
                local _, _, group = GetRaidRosterInfo(i)
                group = self.ReadNumber(group)
                if (group and group >= 1 and group <= 8) then groups[group] = (groups[group] or 0) + 1 end
            end
        end
    else known = false end
    for role, text in pairs(self.roleCounts) do
        text:SetText(known and tostring(roles[role]) or "-")
        -- Icon (20), gap (6) and actual count width share the column's centre.
        local icon = text.roleIcon
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", self.panel, "TOP", text.columnOffset - (6 + text:GetStringWidth())/2, -61)
    end
    for i, button in ipairs(self.groupButtons) do
        button.label:SetText(tostring(i) .. ((groups[i] or 0) > 0 and " (" .. groups[i] .. ")" or ""))
        Enable(button, raid and not self.preview, not self.db.profile.groups or self.db.profile.groups[i] ~= false)
    end
end

Tools.UpdateSettings = function(self)
    if (InCombatLockdown()) then self.pending = true; return end
    self.pending = nil
    self:PrepareFrames()
    if (not self.frame) then return end
    local show = not self.suspended and self.db.profile.enabled and (IsInGroup() or self.preview)
    self.frame:SetShown(show and true or false)
    self.panel:SetShown(self.preview or not self.db.profile.collapsed)
    local allowed = self:HasPermission() and not self.preview and not self.suspended and self.db.profile.enabled
    for index, button in ipairs(self.buttons) do
        self:ConfigureMarker(button, index)
        button:SetEnabled(allowed and true or false)
    end
    Enable(self.targetTab, true, self.db.profile.markerMode ~= "world")
    Enable(self.worldTab, true, self.db.profile.markerMode == "world")
    self:UpdateSummary()
    for key, button in pairs(self.controls) do
        local selected = key == "assist" and IsEveryoneAssistant and IsEveryoneAssistant()
        if (issecretvalue and issecretvalue(selected)) then selected = false end
        Enable(button, self:CanPerformAction(key), selected)
    end
    self.controls.convert.label:SetText(IsInRaid() and (_G.PARTY or L["Party / Raid"]) or (_G.RAID or L["Raid"]))
    self.controls.visibility.label:SetText(self.db.profile.hideGroups and L["Show frames"] or L["Hide frames"])
    self.controls.visibility.tooltip = self.db.profile.hideGroups and L["Show raid frames"] or L["Hide raid frames"]
    local left, right = 0, 1
    if (self.preview or not self.db.profile.collapsed) then left, right = 1, 0 end
    self.toggle:GetNormalTexture():SetTexCoord(left, right, 0, 1)
    self.toggle:GetHighlightTexture():SetTexCoord(left, right, 0, 1)
    self:ApplyRaidFilters()
end

Tools.TogglePreview = function(self)
    if (InCombatLockdown()) then return end
    self.preview = not self.preview
    self:UpdateSettings()
end
Tools.OnEvent = function(self, event)
    if (event == "GROUP_ROSTER_UPDATE") then self.rosterSerial = (self.rosterSerial or 0) + 1 end
    if (event == "PLAYER_REGEN_DISABLED") then
        self.preview = nil
        self.pending = true
        return
    end
    if (not self.anchor and not InCombatLockdown()) then
        self:PrepareFrames()
        self:CreateAnchor(L["Raid / Party panel"])
        ns.MovableModulePrototype.OnEnable(self)
    end
    self:UpdateSettings()
end
Tools.OnEnable = function(self)
    self.suspended = nil
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_DIFFICULTY_CHANGED" }) do
        self:RegisterEvent(event, "OnEvent")
    end
    self:RegisterChatCommand("azmarkers", "TogglePreview")
    self:RegisterChatCommand("azraidtools", "TogglePreview")
    self:OnEvent("Enable")
end
Tools.OnDisable = function(self)
    self.preview = nil
    self.suspended = true
    self:UpdateSettings()
end

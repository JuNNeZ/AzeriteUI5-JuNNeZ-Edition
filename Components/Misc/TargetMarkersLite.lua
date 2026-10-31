-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
-- Independent marker toolbar: no Blizzard panel or RaidTools dependency.
local Addon, ns = ...
if (not ns.IsMainline) then return end
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Lite = ns:NewModule("TargetMarkersLite", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceConsole-3.0")
local MEDIA = "Interface\\AddOns\\" .. Addon .. "\\Assets\\RaidTools\\"
local GROUND = { 5, 6, 3, 2, 7, 1, 4, 8 }
local defaults = { profile = ns:Merge({
    enabled = false, layout = "horizontal",
    marker1 = 1, marker2 = 2, marker3 = 3, marker4 = 4,
    marker5 = 5, marker6 = 6, marker7 = 7, marker8 = 8
}, ns.MovableModulePrototype.defaults) }

Lite.GenerateDefaults = function(self)
    local scale = ns.API.GetEffectiveScale()
    defaults.profile.savedPosition = { scale = scale, "TOP", 0, -100 * scale }
    return defaults
end
local Leave = function()
    if (not GameTooltip:IsForbidden()) then GameTooltip:Hide() end
end
local Enter = function(button)
    if (GameTooltip:IsForbidden()) then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(button.markerName or L["Target markers lite"], 1, .82, .3)
    GameTooltip:AddLine(button.isClear and L["Click: clear all target markers. Shift-click: clear all ground markers."]
        or L["Left-click: target marker. Right-click: clear. Shift: ground markers."], 1, 1, 1, true)
    GameTooltip:Show()
end
Lite.HasPermission = function(self)
    return IsInGroup() and (not IsInRaid() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end
-- Flat profile keys keep options defaults, search and per-setting reset independent.
Lite.GetMarkerSlots = function(self)
    local slots, used = {}, {}
    for i = 1, 8 do
        local value = self.db.profile["marker" .. i]
        if (type(value) ~= "number" or value < 0 or value > 8 or value % 1 ~= 0) then value = i end
        if (value > 0 and used[value]) then value = 0 end
        slots[i] = value
        if (value > 0) then used[value] = true end
    end
    return slots
end
Lite.SetMarkerSlot = function(self, slot, value)
    if (type(slot) ~= "number" or slot < 1 or slot > 8 or slot % 1 ~= 0
        or type(value) ~= "number" or value < 0 or value > 8 or value % 1 ~= 0) then return end
    local slots = self:GetMarkerSlots()
    if (value > 0) then
        for other = 1, 8 do
            if (other ~= slot and slots[other] == value) then
                self.db.profile["marker" .. other] = slots[slot]
                break
            end
        end
    end
    self.db.profile["marker" .. slot] = value
    self:UpdateSettings()
end
Lite.GetLayoutData = function(self)
    local order = {}
    for _, value in ipairs(self:GetMarkerSlots()) do
        if (value > 0) then order[#order+1] = value end
    end
    order[#order+1] = 9 -- Clear-all is always last; Shift selects ground markers.
    local layout = self.db.profile.layout
    if (layout ~= "vertical" and layout ~= "twoRows") then layout = "horizontal" end
    local columns = layout == "twoRows" and math.ceil(#order/2) or #order
    local rows = math.ceil(#order/columns)
    local width, height = columns*29+63, (rows-1)*29+56
    if (layout == "vertical") then width, height = height, width end
    return order, layout, width, height, columns
end
Lite.UpdateLayout = function(self)
    if (InCombatLockdown()) then self.pending = true; return end
    local order, layout, width, height, columns = self:GetLayoutData()
    self.frame:SetSize(width, height)
    local vertical = layout == "vertical"
    local logicalWidth, logicalHeight = width, height
    if (vertical) then logicalWidth, logicalHeight = height, width end
    -- Nine slices preserve the painted rails/endcaps as the centre grows for two rows.
    local xs, ys = { 0, 32, logicalWidth-32, logicalWidth }, { 0, 14, logicalHeight-14, logicalHeight }
    local us, vs = { 0, .1, .9, 1 }, { 0, .25, .75, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            local texture = self.art[(row-1)*3+col]
            local w, h = xs[col+1]-xs[col], ys[row+1]-ys[row]
            texture:ClearAllPoints()
            if (vertical) then
                texture:SetSize(h, w)
                texture:SetPoint("TOPLEFT", self.frame, "TOPLEFT", logicalHeight-ys[row+1], -xs[col])
                texture:SetTexCoord(us[col], vs[row+1], us[col+1], vs[row+1], us[col], vs[row], us[col+1], vs[row])
            else
                texture:SetSize(w, h)
                texture:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xs[col], -ys[row])
                texture:SetTexCoord(us[col], us[col+1], vs[row], vs[row+1])
            end
        end
    end
    local positions = {}
    for position, index in ipairs(order) do positions[index] = position end
    self.visibleMarkers = positions
    for index, button in ipairs(self.buttons) do
        local position = positions[index]
        button:SetShown(position ~= nil)
        if (position) then
            local col, row = (position-1)%columns, math.floor((position-1)/columns)
            button:ClearAllPoints()
            if (vertical) then button:SetPoint("CENTER", self.frame, "TOPLEFT", 28, -(50+(position-1)*29))
            else button:SetPoint("CENTER", self.frame, "TOPLEFT", 50+col*29, -(28+row*29)) end
        end
    end
    if (self.anchor and self.UpdateAnchor) then self:UpdateAnchor() end
end

Lite.PrepareFrames = function(self)
    if (InCombatLockdown() or self.frame) then return end
    local frame = CreateFrame("Frame", ns.Prefix .. "TargetMarkersLite", UIParent)
    frame:SetSize(324, 56)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()
    self.frame, self.buttons, self.art = frame, {}, {}
    for index = 1, 9 do
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetTexture(MEDIA .. "panel.tga")
        self.art[index] = texture
    end
    for index = 1, 9 do
        local button = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
        button:SetSize(26, 28)
        button:SetPoint("LEFT", frame, "LEFT", 37 + (index-1)*29, 0)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        -- World markers and clear-all must bypass native dispatch's missing-unit gate.
        button:SetAttribute("unit1", index <= 8 and "target" or "none")
        button:SetAttribute("unit2", index <= 8 and "target" or "none")
        button:SetAttribute("shift-unit1", "none")
        button:SetAttribute("shift-unit2", "none")
        button:SetAttribute("type1", "raidtarget")
        button:SetAttribute("type2", "raidtarget")
        button:SetAttribute("shift-type1", "worldmarker")
        button:SetAttribute("shift-type2", "worldmarker")
        if (index <= 8) then
            button:SetAttribute("marker1", index)
            button:SetAttribute("action1", "set")
            button:SetAttribute("action2", "clear")
            button:SetAttribute("shift-marker1", GROUND[index])
            button:SetAttribute("shift-marker2", GROUND[index])
            button:SetAttribute("shift-action1", "set")
            button:SetAttribute("shift-action2", "clear")
            button.markerName = _G["RAID_TARGET_" .. index]
        else
            button:SetAttribute("action1", "clear-all")
            button:SetAttribute("action2", "clear-all")
            button:SetAttribute("shift-action1", "clear")
            button:SetAttribute("shift-action2", "clear")
            button.isClear = true
            button.markerName = L["Clear all markers"]
        end
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("CENTER")
        if (index <= 8) then
            icon:SetTexture(ns.API.GetMedia("raid_target_icons_small"))
            local column, row = (index-1)%4, math.floor((index-1)/4)
            icon:SetTexCoord(column/4, (column+1)/4, row/4, (row+1)/4)
        else icon:SetTexture(MEDIA .. "clear.tga") end
        button:SetHighlightTexture(MEDIA .. "highlight.tga", "ADD")
        button:SetScript("OnEnter", Enter)
        button:SetScript("OnLeave", Leave)
        self.buttons[index] = button
    end
end
Lite.UpdateSettings = function(self)
    if (InCombatLockdown()) then self.pending = true; return end
    self.pending = nil
    self:PrepareFrames()
    if (not self.frame) then return end
    self:UpdateLayout()
    local active = not self.suspended and self.db.profile.enabled
    local allowed = active and self:HasPermission() and not self.preview
    self.frame:SetShown(active and (self:HasPermission() or self.preview) and true or false)
    for index, button in ipairs(self.buttons) do button:SetEnabled(allowed and self.visibleMarkers[index] ~= nil and true or false) end
end
Lite.TogglePreview = function(self)
    if (InCombatLockdown() or not self.db.profile.enabled) then return end
    self.preview = not self.preview
    self:UpdateSettings()
end
Lite.OnEvent = function(self, event)
    if (event == "PLAYER_REGEN_DISABLED") then
        self.preview = nil
        self.pending = true
        return
    end
    if (not self.anchor and not InCombatLockdown()) then
        self:PrepareFrames()
        self:CreateAnchor(L["Target markers lite"])
        ns.MovableModulePrototype.OnEnable(self)
    end
    self:UpdateSettings()
end
Lite.OnEnable = function(self)
    self.suspended = nil
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        self:RegisterEvent(event, "OnEvent")
    end
    self:RegisterChatCommand("azmarkerlite", "TogglePreview")
    self:OnEvent("Enable")
end
Lite.OnDisable = function(self)
    self.preview = nil
    self.suspended = true
    self:UpdateSettings()
end

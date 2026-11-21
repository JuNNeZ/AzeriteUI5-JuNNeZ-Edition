-- MIT License. Copyright (c) 2026 Jonas "JuNNeZ" Andersen.
-- Adds the saved nickname to a player's unit tooltip. Read-only: it never
-- changes the name line Blizzard (or AzeriteUI's tooltip module) drew.
local Addon, ns = ...
local Guild = ns:GetModule("GuildManager")
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Text(value) if (not Secret(value) and type(value) == "string") then return value end end

-- The nickname for a readable player unit, or nil. Protected names (WoW 12
-- secret values, typically in instanced combat) are skipped, never guessed.
Guild.GetTooltipNickname = function(self, unit)
    if (type(unit) ~= "string" or Secret(unit) or not UnitIsPlayer or not UnitName) then return end
    local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
    if (not okPlayer or Secret(isPlayer) or not isPlayer) then return end
    local okName, name, realm = pcall(UnitName, unit)
    if (not okName) then return end
    name, realm = Text(name), Text(realm)
    if (not name or name == "") then return end
    local nickname = Text(self:Resolve(realm and realm ~= "" and (name .. "-" .. realm) or name))
    -- A nickname equal to the shown name adds nothing.
    if (not nickname or nickname == "" or nickname == name or nickname:find("[|%c]")) then return end
    return nickname
end

local function HasLine(tooltip, text)
    local name = tooltip.GetName and tooltip:GetName()
    local count = tooltip.NumLines and tooltip:NumLines()
    if (not name or Secret(name) or type(count) ~= "number" or Secret(count)) then return false end
    for index = 1, count do
        local region = _G[name .. "TextLeft" .. index]
        if (region and region.GetText and Text(region:GetText()) == text) then return true end
    end
    return false
end

Guild.OnTooltipUnit = function(self, tooltip)
    local profile = self.db and self.db.profile
    if (self.suspended or not profile or not profile.enabled or not profile.tooltipNicknames) then return end
    if (not tooltip or not tooltip.GetUnit or not tooltip.AddLine) then return end
    if (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if (not ok) then return end
    local nickname = self:GetTooltipNickname(unit)
    if (not nickname) then return end
    local line = L["Nickname"] .. ": " .. nickname
    if (HasLine(tooltip, line)) then return end
    tooltip:AddLine(line, 1, 0.82, 0)
    tooltip:Show()
end

-- Post-calls cannot be removed, so this registers once and the callback checks
-- the setting each time.
Guild.HookTooltips = function(self)
    if (self.tooltipHooked) then return end
    local callback = function(tooltip)
        local ok, err = pcall(self.OnTooltipUnit, self, tooltip)
        if (not ok and ns.API and ns.API.ReportError) then ns.API.ReportError("GuildManager.OnTooltipUnit", err) end
    end
    if (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit) then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, callback)
        self.tooltipHooked = true
    elseif (GameTooltip and GameTooltip.HookScript) then
        GameTooltip:HookScript("OnTooltipSetUnit", callback)
        self.tooltipHooked = true
    end
end

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
--[[

  SanityBarFix – native alternate-power event restoration
  ------------------------------------------------
  • Disables oUF’s “AlternativePower” element so no layout hides
    Blizzard’s PlayerPowerBarAlt.
  • Restores Blizzard’s own events once the bar is created.
  • Leaves initialization and power updates to Blizzard’s native events.
  • No styling, no repositioning – the bar remains exactly like
    the default UI.

--]]

local _, ns = ...
local API = ns.API
if (not ns or not ns.WoW11) then return end -- Retail only

-- Local print with optional debug flag
local DEBUG = false
local function SBFPrint(msg)
    if DEBUG and msg then
        print("|cff00ff00[SanityBarFix]|r " .. tostring(msg))
    end
end

local function ShouldSkipBlizzardAltPowerBar()
    return ns.GetActiveConfigVariant and ns:GetActiveConfigVariant() == "SaiyaRatt"
end

-- Slash to toggle debug
SLASH_SANITYBARFIX1 = "/sanitybarfix"
SlashCmdList["SANITYBARFIX"] = function(msg)
    if (not (ns and (ns.IsDevelopment or (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)))) then
        print("|cff00ff00[SanityBarFix]|r Debug command requires dev mode")
        return
    end
    if msg == "debug" then
        DEBUG = not DEBUG
        print("|cff00ff00[SanityBarFix]|r Debug: " .. tostring(DEBUG))
    else
        print("|cff00ff00[SanityBarFix]|r Usage: /sanitybarfix debug")
    end
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function DisableOUFAlternativePower()
    local oUF = ns.oUF or _G.oUF
    if type(oUF) ~= "table" or type(oUF.objects) ~= "table" then
        SBFPrint("oUF not ready; skip disable")
        return
    end
    for _, obj in ipairs(oUF.objects) do
        if type(obj.DisableElement) == "function" then
            local ok, err = API.TryCall(obj.DisableElement, obj, "AlternativePower")
            if not ok then SBFPrint("DisableElement error: " .. tostring(err)) end
        end
    end
    SBFPrint("oUF AlternativePower disabled on existing objects")
end

local function RestorePlayerPowerBarAltEvents()
    if ShouldSkipBlizzardAltPowerBar() then
        local alt = _G and _G.PlayerPowerBarAlt
        if alt then
            alt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
            alt:UnregisterEvent("UNIT_POWER_BAR_HIDE")
            alt:UnregisterEvent("PLAYER_ENTERING_WORLD")
            alt:UnregisterEvent("UNIT_POWER_UPDATE")
            alt:UnregisterEvent("UNIT_MAXPOWER")
            alt:Hide()
        end
        SBFPrint("SaiyaRatt active; skip Blizzard alt power bar restore")
        return false
    end

    local alt = _G and _G.PlayerPowerBarAlt
    if not alt then
        SBFPrint("PlayerPowerBarAlt missing")
        return false
    end

    -- Ensure Blizzard drives it fully
    -- Only the three events Blizzard's own XML registers. UNIT_POWER_UPDATE and
    -- UNIT_MAXPOWER belong to UnitPowerBarAlt_SetUp/TearDown; registering them
    -- here fired the counter-bar update before CounterBar_SetUp had run
    -- (UnitPowerBarAlt.lua:710 "bad argument #2 to 'min'").
    alt:RegisterEvent("UNIT_POWER_BAR_SHOW")
    alt:RegisterEvent("UNIT_POWER_BAR_HIDE")
    alt:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Let the native event dispatch initialize and update the bar. Calling its
    -- OnEvent here taints value/displayedValue, then the smooth OnUpdate
    -- compares secret power values from that tainted state every frame.
    SBFPrint("PlayerPowerBarAlt events restored")
    return true
end

-----------------------------------------------------------------------
-- Event driver
-----------------------------------------------------------------------
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
    if ShouldSkipBlizzardAltPowerBar() then
        RestorePlayerPowerBarAltEvents()
        return
    end

    if event == "PLAYER_LOGIN" then
        DisableOUFAlternativePower()
        -- Keep an eye out for late-created oUF objects
        if C_Timer and C_Timer.NewTicker then
            local left = 12 -- ~6s
            C_Timer.NewTicker(.5, function()
                DisableOUFAlternativePower()
                left = left - 1
            end, left)
        end
        self:RegisterEvent("UNIT_POWER_BAR_SHOW")
        self:RegisterEvent("PLAYER_ENTERING_WORLD") -- alt may appear on zoning

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Try once on zone load
        RestorePlayerPowerBarAltEvents()

    elseif event == "UNIT_POWER_BAR_SHOW" then
        local unit = ...
        if unit == "player" then
            RestorePlayerPowerBarAltEvents()
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")

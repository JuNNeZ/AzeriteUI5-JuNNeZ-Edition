--[[

  SanityBarFix – minimal, safe, and improved
  ------------------------------------------------
  • Disables oUF’s “AlternativePower” element so no layout hides
    Blizzard’s PlayerPowerBarAlt.
  • Restores Blizzard’s own events once the bar is created.
  • Immediately invokes Blizzard’s show-handler so barInfo is set.
  • No styling, no repositioning – the bar remains exactly like
    the default UI.

--]]

local _, ns = ...
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
            local ok, err = pcall(obj.DisableElement, obj, "AlternativePower")
            if not ok then SBFPrint("DisableElement error: " .. tostring(err)) end
        end
    end
    SBFPrint("oUF AlternativePower disabled on existing objects")
end

local function RestoreAndInitPlayerPowerBarAlt()
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
    alt:RegisterEvent("UNIT_POWER_BAR_SHOW")
    alt:RegisterEvent("UNIT_POWER_BAR_HIDE")
    alt:RegisterEvent("PLAYER_ENTERING_WORLD")
    alt:RegisterEvent("UNIT_POWER_UPDATE")
    alt:RegisterEvent("UNIT_MAXPOWER")

    -- Invoke Blizzard handler defensively to initialize barInfo
    local onEvent = alt:GetScript("OnEvent")
    if type(onEvent) == "function" then
        local ok, err = pcall(onEvent, alt, "UNIT_POWER_BAR_SHOW", "player")
        if not ok then SBFPrint("OnEvent error: " .. tostring(err)) end
    end

    SBFPrint("PlayerPowerBarAlt events restored & initialized")
    return true
end

-----------------------------------------------------------------------
-- Event driver
-----------------------------------------------------------------------
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
    if ShouldSkipBlizzardAltPowerBar() then
        RestoreAndInitPlayerPowerBarAlt()
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
        RestoreAndInitPlayerPowerBarAlt()

    elseif event == "UNIT_POWER_BAR_SHOW" then
        local unit = ...
        if unit == "player" then
            RestoreAndInitPlayerPowerBarAlt()
        end
    end
end)

f:RegisterEvent("PLAYER_LOGIN")

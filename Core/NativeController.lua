-- Follow Blizzard's selected interface before any replacement module can
-- register events, create secure buttons or suppress native controls.
local Addon, ns = ...
local API = ns.API
local function IsAvailable()
	return ns.IsForever == true
		and type(C_GamepadUI) == "table"
		and type(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex) == "function"
		and type(C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex) == "function"
		and type(C_InputInterfaceStyle) == "table"
		and type(C_InputInterfaceStyle.GetCurrentStyle) == "function"
		and type(Enum) == "table" and type(Enum.InputDeviceInterfaceType) == "table"
		and Enum.InputDeviceInterfaceType.Gamepad ~= nil
end
local function GetConflict()
	-- Core ConsolePort supports native Forever bars. Its optional bar module
	-- hides those bars and clears their keys; Bartender likewise owns the bars.
	for _, name in ipairs({ "ConsolePort_Bar", "Bartender4" }) do
		if API.IsAddOnEnabled(name) then return name end
	end
end
local available = IsAvailable()
local function GamepadStyle()
	return available and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad or false
end
-- Native navigation remains native even if another addon replaces its bars.
-- Legacy nativeControllerBars values are deliberately ignored, not rewritten.
local active = GamepadStyle()

-- Blizzard's own switch between direct party targeting (D-pad = party1..4,
-- unit tokens only) and raid-style SmartNavigation, which walks the actual
-- CompactPartyFrame. Blizzard reads it the same way at OnLoad and follows it
-- live (FriendlyTargetingActionBar.lua OnLoad, RefreshGroupTargeting). In a
-- raid both modes use CompactRaidFrameContainer. Read only, never written.
local PARTY_TARGETING_CVAR = "GamepadUsePartyTargeting"
local function PartyTargeting()
	return C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool(PARTY_TARGETING_CVAR) and true or false
end
local partyTargeting = active and PartyTargeting() or false

local controller = {}
ns.NativeController = controller
controller.IsActive = function() return active end
controller.IsAvailable = IsAvailable
controller.GetConflict = GetConflict
-- Party frames stay AzeriteUI's when the D-pad targets party members
-- directly; raid-style party navigation needs Blizzard's party frames.
controller.UsesNativePartyFrames = function() return active and not partyTargeting end
controller.UsesNativeRaidFrames = function() return active end
controller.UsesPartyTargeting = function() return partyTargeting end

local key = "AZERITEUI_NATIVE_CONTROLLER_RELOAD"
controller.PromptReload = function(message)
	local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
	API.PopupDialogs[key] = {
		text = message or L["Controller action bar ownership changes after a reload. Reload now?"],
		button1 = L["Reload UI"], button2 = CANCEL or "Cancel",
		hideOnEscape = true, whileDead = true, timeout = 0,
		OnAccept = function() if not InCombatLockdown() then ReloadUI() end end
	}
	API.ShowPopup(key)
end

local transitionEvent = "INPUT_DEVICE_INTERFACE_TRANSITION"
if available and API.IsEventAvailable(transitionEvent) then
	local events = CreateFrame("Frame")
	events:RegisterEvent(transitionEvent)
	if (API.IsEventAvailable("CVAR_UPDATE")) then events:RegisterEvent("CVAR_UPDATE") end
	events:SetScript("OnEvent", function(_, event, newMode, value)
		if (event == "CVAR_UPDATE") then
			-- Party frame ownership is frozen for the session like the bars.
			if (not active or newMode ~= PARTY_TARGETING_CVAR) then return end
			-- Same test as Blizzard's CVar callback (FriendlyTargetingActionBar OnLoad).
			local now = tonumber(value) ~= 0
			if (now ~= partyTargeting) then
				local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
				controller.PromptReload(L["Party frame ownership changes after a reload. Reload now?"])
			else
				API.HidePopup(key)
			end
			return
		end
		local gamepad = newMode == Enum.InputDeviceInterfaceType.Gamepad
		-- No protected mutation on a mode transition, even outside combat.
		-- The popup service queues its own prompt if combat is in progress.
		if gamepad ~= active then controller.PromptReload()
		else API.HidePopup(key) end
	end)
end

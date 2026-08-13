--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...
if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local BlizzardABDisabler = ns:NewModule("BlizzardABDisabler", "LibMoreEvents-1.0", "AceHook-3.0")
local quarantinedFrames = setmetatable({}, { __mode = "k" })
local hiddenBagControls = setmetatable({}, { __mode = "k" })
local applyingAlpha = setmetatable({}, { __mode = "k" })
local applyingMouse = setmetatable({}, { __mode = "k" })
local applyingVisibility = setmetatable({}, { __mode = "k" })

local HIDDEN_FRAME_NAMES = {
	"MainMenuBar",
	"MainActionBar",
	"MultiBarBottomLeft",
	"MultiBarBottomRight",
	"MultiBarLeft",
	"MultiBarRight",
	"MultiBar5",
	"MultiBar6",
	"MultiBar7",
	"BagsBar",
	"MicroMenu",
	"MicroMenuContainer",
	"MicroButtonAndBagsBar",
	"StanceBar",
	"PossessActionBar",
	"MultiCastActionBarFrame",
	"PetActionBar",
	"StatusTrackingBarManager",
	"OverrideActionBar"
}

local MICRO_BUTTON_NAMES = {
	"CharacterMicroButton",
	"ProfessionMicroButton",
	"PlayerSpellsMicroButton",
	"QuestLogMicroButton",
	"HousingMicroButton",
	"QuickJoinToastButton",
	"GuildMicroButton",
	"LFDMicroButton",
	"AchievementMicroButton",
	"EJMicroButton",
	"CollectionsMicroButton",
	"MainMenuMicroButton",
	"StoreMicroButton"
}

local BAG_BUTTON_NAMES = {
	"MainMenuBarBackpackButton",
	"BagBarExpandToggle"
}

local BLIZZARD_ACTION_BAR_ADDONS = {
	Blizzard_ActionBar = true,
	Blizzard_MainMenuBarBagButtons = true,
	Blizzard_MicroMenu = true,
	Blizzard_NewPlayerExperience = true
}

local disableMouseInput = function(frame)
	if (not frame or applyingMouse[frame]) then return end

	applyingMouse[frame] = true
	if (frame.EnableMouse) then frame:EnableMouse(false) end
	if (frame.SetMouseClickEnabled) then frame:SetMouseClickEnabled(false) end
	if (frame.SetMouseMotionEnabled) then frame:SetMouseMotionEnabled(false) end
	applyingMouse[frame] = nil
end

local quarantineFrame = function(frame)
	if (not frame) then return end

	frame:SetAlpha(0)
	disableMouseInput(frame)

	if (not quarantinedFrames[frame]) then
		quarantinedFrames[frame] = true
		hooksecurefunc(frame, "SetAlpha", function(self)
			if (applyingAlpha[self]) then return end
			applyingAlpha[self] = true
			self:SetAlpha(0)
			applyingAlpha[self] = nil
		end)
		for _, method in ipairs({ "EnableMouse", "SetMouseClickEnabled", "SetMouseMotionEnabled" }) do
			if (frame[method]) then
				hooksecurefunc(frame, method, disableMouseInput)
			end
		end
	end
end

local quarantineNamedFrames = function(frameNames)
	for _, frameName in ipairs(frameNames) do
		quarantineFrame(_G[frameName])
	end
end

local suppressBagControl = function(frame)
	if (not frame) then return end

	quarantineFrame(frame)
	if (not InCombatLockdown()) then
		frame:Hide()
	end

	if (hiddenBagControls[frame]) then return end
	hiddenBagControls[frame] = true
	for _, method in ipairs({ "Show", "SetShown" }) do
		hooksecurefunc(frame, method, function(self, shown)
			if (applyingVisibility[self] or shown == false or InCombatLockdown()) then return end
			applyingVisibility[self] = true
			self:Hide()
			applyingVisibility[self] = nil
		end)
	end
end

local suppressNamedBagControls = function()
	for _, frameName in ipairs(BAG_BUTTON_NAMES) do
		suppressBagControl(_G[frameName])
	end
end

BlizzardABDisabler.NPE_LoadUI = function(self)
	local Tutorials = _G.Tutorials
	if not (Tutorials and Tutorials.AddSpellToActionBar) then return end

	-- Action Bar drag tutorials
	Tutorials.AddSpellToActionBar:Disable()
	Tutorials.AddClassSpellToActionBar:Disable()

	-- these tutorials rely on finding valid action bar buttons, and error otherwise
	Tutorials.Intro_CombatTactics:Disable()

	-- enable spell pushing because the drag tutorial is turned off
	Tutorials.AutoPushSpellWatcher:Complete()
end

BlizzardABDisabler.HideBlizzard = function(self)

	quarantineNamedFrames(HIDDEN_FRAME_NAMES)

	-- In TWW 11.0+, hide the gryphons (EndCaps) on MainActionBar
	local MainActionBar = _G.MainActionBar
	if (MainActionBar and MainActionBar.EndCaps) then
		if (MainActionBar.EndCaps.LeftEndCap) then
			MainActionBar.EndCaps.LeftEndCap:Hide()
		end
		if (MainActionBar.EndCaps.RightEndCap) then
			MainActionBar.EndCaps.RightEndCap:Hide()
		end
	end

	-- Keep Blizzard's secure buttons and event machinery alive, but make the
	-- invisible buttons unable to intercept the AzeriteUI bars.
	for i=1,12 do
		quarantineFrame(_G["ActionButton" .. i])
		quarantineFrame(_G["MultiBarBottomLeftButton" .. i])
		quarantineFrame(_G["MultiBarBottomRightButton" .. i])
		quarantineFrame(_G["MultiBarRightButton" .. i])
		quarantineFrame(_G["MultiBarLeftButton" .. i])
		quarantineFrame(_G["MultiBar5Button" .. i])
		quarantineFrame(_G["MultiBar6Button" .. i])
		quarantineFrame(_G["MultiBar7Button" .. i])
	end

	-- Retail's stance, micro-menu and bag buttons can render independently of
	-- their layout containers. Quarantine the actual click targets as well.
	for i=1,10 do
		quarantineFrame(_G["StanceButton" .. i])
		quarantineFrame(_G["PetActionButton" .. i])
	end
	for i=1,2 do
		quarantineFrame(_G["PossessButton" .. i])
	end
	quarantineNamedFrames(MICRO_BUTTON_NAMES)
	suppressNamedBagControls()

	if C_AddOns.IsAddOnLoaded("Blizzard_NewPlayerExperience") then
		self:NPE_LoadUI()
	elseif _G.NPE_LoadUI ~= nil and not self.npeHooked then
		self:SecureHook("NPE_LoadUI")
		self.npeHooked = true
	end

	if (not self.microAlertHooked and _G.MainMenuMicroButton_ShowAlert) then
		local HideAlerts = function()
			local HelpTip = _G.HelpTip
			if (HelpTip) then
				HelpTip:HideAllSystem("MicroButtons")
			end
		end
		_G.hooksecurefunc("MainMenuMicroButton_ShowAlert", HideAlerts)
		self.microAlertHooked = true
	end

end

BlizzardABDisabler.QueueHideBlizzard = function(self)
	if (self.hideBlizzardQueued) then return end
	self.hideBlizzardQueued = true
	C_Timer.After(0, function()
		self.hideBlizzardQueued = nil
		if (self:IsEnabled()) then
			self:HideBlizzard()
		end
	end)
end

BlizzardABDisabler.OnBlizzardUIReady = function(self, event, addon)
	if (event == "ADDON_LOADED" and not BLIZZARD_ACTION_BAR_ADDONS[addon]) then
		return
	end
	self:HideBlizzard()
	self:QueueHideBlizzard()
end

BlizzardABDisabler.OnInitialize = function(self)
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end
end

BlizzardABDisabler.OnEnable = function(self)
	self:HideBlizzard()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnBlizzardUIReady")
	self:RegisterEvent("ADDON_LOADED", "OnBlizzardUIReady")
	ns.RegisterCallback(self, "Bartender_Handled", "OnBlizzardUIReady")
end

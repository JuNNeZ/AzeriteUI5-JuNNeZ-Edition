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
if (ns.IsClassic) then return end

if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local BlizzardABDisabler = ns:NewModule("BlizzardABDisabler", "LibMoreEvents-1.0", "AceHook-3.0")

local purgeKey = function(t, k)
	t[k] = nil
	local c = 42
	repeat
		if t[c] == nil then
			t[c] = nil
		end
		c = c + 1
	until issecurevariable(t, k)
end

local hideActionBarFrame = function(frame, clearEvents)
	if (frame) then
		if (clearEvents) then
			frame:UnregisterAllEvents()
		end

		-- Remove some EditMode hooks
		if (frame.system) then
			-- Purge the show state to avoid any taint concerns
			purgeKey(frame, "isShownExternal")
		end

		-- EditMode overrides the Hide function, avoid calling it as it can taint
		if (frame.HideBase) then
			frame:HideBase()
		else
			frame:Hide()
		end
		frame:SetParent(ns.Hider)
	end
end

local hideActionButton = function(button)
	if (not button) then return end

	if (button.HideBase) then
		button:HideBase()
	else
		button:Hide()
	end
	button:SetParent(ns.Hider)
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

	hideActionBarFrame(_G.MainMenuBar, false)
	hideActionBarFrame(_G.MainActionBar, false) -- TWW 11.0+ replacement for MainMenuBar
	hideActionBarFrame(_G.MultiBarBottomLeft, true)
	hideActionBarFrame(_G.MultiBarBottomRight, true)
	hideActionBarFrame(_G.MultiBarLeft, true)
	hideActionBarFrame(_G.MultiBarRight, true)
	hideActionBarFrame(_G.MultiBar5, true)
	hideActionBarFrame(_G.MultiBar6, true)
	hideActionBarFrame(_G.MultiBar7, true)

	-- In TWW 11.0+, hide the gryphons (EndCaps) on MainActionBar
	local MainActionBar = _G.MainActionBar
	if (MainActionBar and MainActionBar.EndCaps) then
		if (MainActionBar.EndCaps.LeftEndCap) then
			MainActionBar.EndCaps.LeftEndCap:Hide()
			MainActionBar.EndCaps.LeftEndCap:SetParent(ns.Hider)
		end
		if (MainActionBar.EndCaps.RightEndCap) then
			MainActionBar.EndCaps.RightEndCap:Hide()
			MainActionBar.EndCaps.RightEndCap:SetParent(ns.Hider)
		end
	end

	-- Hide MultiBar Buttons, but keep the bars alive
	for i=1,12 do
		hideActionButton(_G["ActionButton" .. i])
		hideActionButton(_G["MultiBarBottomLeftButton" .. i])
		hideActionButton(_G["MultiBarBottomRightButton" .. i])
		hideActionButton(_G["MultiBarRightButton" .. i])
		hideActionButton(_G["MultiBarLeftButton" .. i])
		hideActionButton(_G["MultiBar5Button" .. i])
		hideActionButton(_G["MultiBar6Button" .. i])
		hideActionButton(_G["MultiBar7Button" .. i])
	end

	hideActionBarFrame(_G.BagsBar, false) -- 10.0.5
	hideActionBarFrame(_G.MicroMenu, false) -- 10.0.5
	hideActionBarFrame(_G.MicroButtonAndBagsBar, false)
	hideActionBarFrame(_G.StanceBar, true)
	hideActionBarFrame(_G.PossessActionBar, true)
	hideActionBarFrame(_G.MultiCastActionBarFrame, false)
	hideActionBarFrame(_G.PetActionBar, true)
	hideActionBarFrame(_G.StatusTrackingBarManager, false)
	hideActionBarFrame(_G.OverrideActionBar, true)

	-- these events drive visibility, we want the MainMenuBar to remain invisible
	local MainMenuBar = _G.MainMenuBar
	if MainMenuBar then
		MainMenuBar:UnregisterEvent("PLAYER_REGEN_ENABLED")
		MainMenuBar:UnregisterEvent("PLAYER_REGEN_DISABLED")
		MainMenuBar:UnregisterEvent("ACTIONBAR_SHOWGRID")
		MainMenuBar:UnregisterEvent("ACTIONBAR_HIDEGRID")
	end

	local ActionBarController = _G.ActionBarController
	if ActionBarController then
		ActionBarController:UnregisterAllEvents()
		if (ns.WoW10) then
			ActionBarController:RegisterEvent("SETTINGS_LOADED") -- needed to update paging
		end
		if (ns.IsRetail) then
			ActionBarController:RegisterEvent("UPDATE_EXTRA_ACTIONBAR") -- needed to update extrabuttons
		end
	end

	if _G.IsAddOnLoaded("Blizzard_NewPlayerExperience") then
		self:NPE_LoadUI()
	elseif _G.NPE_LoadUI ~= nil then
		self:SecureHook("NPE_LoadUI")
	end

	local HideAlerts = function()
		local HelpTip = _G.HelpTip
		if (HelpTip) then
			HelpTip:HideAllSystem("MicroButtons")
		end
	end
	_G.hooksecurefunc("MainMenuMicroButton_ShowAlert", HideAlerts)

end

BlizzardABDisabler.OnInitialize = function(self)
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end
end

BlizzardABDisabler.OnEnable = function(self)
	self:HideBlizzard()
end

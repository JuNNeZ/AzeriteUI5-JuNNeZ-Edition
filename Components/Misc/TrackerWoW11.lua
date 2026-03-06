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

if (not ns.WoW11) then return end

local Tracker = ns:NewModule("Tracker", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0", "AceConsole-3.0")

-- GLOBALS: IsAddOnLoaded, SetOverrideBindingClick

-- Addon API
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

local defaults = { profile = ns:Merge({

	theme = "Azerite",
	disableBlizzardTracker = false

	-- user toggles for quick hiding
	,hideAddonText = false
	,hideClockText = false

}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
Tracker.GenerateDefaults = function(self)
	return defaults
end

Tracker.PrepareFrames = function(self)

	ObjectiveTrackerFrame.autoHider = CreateFrame("Frame", nil, ObjectiveTrackerFrame, "SecureHandlerStateTemplate")
	ObjectiveTrackerFrame.autoHider:SetAttribute("_onstate-vis", [[ if (newstate == "hide") then self:Hide() else self:Show() end ]])
	-- Secure attribute handler to allow insecure code to request a forced visibility change
	-- Use SetAttribute("forcevis", "hide"/"show") from insecure code to trigger.
	ObjectiveTrackerFrame.autoHider:SetAttribute("_onattributechanged", [[
		if (name == "forcevis") then
			if (value == "hide") then
				self:Hide()
			elseif (value == "show") then
				self:Show()
			end
		end
	]])
 	ObjectiveTrackerFrame.autoHider:SetScript("OnHide", function() ObjectiveTrackerFrame:SetAlpha(0) end)
 	ObjectiveTrackerFrame.autoHider:SetScript("OnShow", function() ObjectiveTrackerFrame:SetAlpha(.9) end)

	local driver = "hide;show"
	driver = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]" .. driver
	driver = "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists]" .. driver
	--driver = "[@target,exists]" .. driver -- For testing purposes

	RegisterStateDriver(ObjectiveTrackerFrame.autoHider, "vis", driver)

	ObjectiveTrackerUIWidgetContainer:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameLevel(50)
	ObjectiveTrackerFrame:SetClampedToScreen(false)
	ObjectiveTrackerFrame:SetAlpha(.9)

	self.GetFrame = function() return ObjectiveTrackerFrame end

end

Tracker.UpdateSettings = function(self)

	if (issecretvalue) then
		if ObjectiveTrackerFrame.autoHider then
			ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", self.db.profile.disableBlizzardTracker and "hide" or "show")
		end
		return
	end

	if (self.db.profile.disableBlizzardTracker) then

		if (not self:IsHooked(ObjectiveTrackerFrame, "Show")) then
			self:SecureHook(ObjectiveTrackerFrame, "Show", function(this)
				if (self.db.profile.disableBlizzardTracker and ObjectiveTrackerFrame.autoHider) then
					ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", "hide")
				end
			end)
		end

		if (not self:IsHooked(ObjectiveTrackerFrame, "SetShown")) then
			self:SecureHook(ObjectiveTrackerFrame, "SetShown", function(this, show)
				if (self.db.profile.disableBlizzardTracker and show and ObjectiveTrackerFrame.autoHider) then
					ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", "hide")
				end
			end)
		end

		-- Request secure handler to hide the tracker rather than calling :Hide()
		if ObjectiveTrackerFrame.autoHider then
			ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", "hide")
		end
	else

		-- Request secure handler to show the tracker
		if ObjectiveTrackerFrame.autoHider then
			ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", "show")
		end
	end
end

Tracker.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD" or event == "SETTINGS_LOADED") then
		ObjectiveTrackerFrame:SetAlpha(.9)
		self:UpdateSettings()

		-- Ensure EncounterBar isn't suppressed by parenting/alpha side-effects
		local eb = _G and (_G.EncounterBar or _G.UIWidgetPowerBarContainerFrame)
		if (eb) then
			if (eb:GetParent() == ns.Hider) then
				eb:SetParent(UIParent)
			end
			if (eb.SetAlpha) then eb:SetAlpha(1) end
			eb:Show()
			-- In case something toggles it right after load, do a short delayed nudge
			if (C_Timer and C_Timer.After) then
				C_Timer.After(.2, function()
					if (eb:GetParent() == ns.Hider) then eb:SetParent(UIParent) end
					if (eb.SetAlpha) then eb:SetAlpha(1) end
					eb:Show()
				end)
			end
		end
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			-- During initial login, EncounterBar may be created later by Blizzard.
			-- Start a short-lived watcher to ensure it's visible once it exists.
			if (C_Timer and C_Timer.NewTicker and not self._ebTicker) then
				local iterations = 24 -- ~12s at 0.5s interval
				self._ebTicker = C_Timer.NewTicker(.5, function()
					local eb = _G and (_G.EncounterBar or _G.UIWidgetPowerBarContainerFrame)
					if (eb) then
						if (eb:GetParent() == ns.Hider) then eb:SetParent(UIParent) end
						if (eb.SetAlpha) then eb:SetAlpha(1) end
						eb:Show()
						-- Stop early if it's clearly visible and not parented to hider
						if (eb:IsShown() and eb:GetAlpha() > 0 and eb:GetParent() ~= ns.Hider) then
							if (self._ebTicker and self._ebTicker.Cancel) then
								self._ebTicker:Cancel()
								self._ebTicker = nil
							end
						end
					end
					-- Decrement manual iteration counter and stop after limit regardless
					iterations = iterations - 1
					if (iterations <= 0) then
						if (self._ebTicker and self._ebTicker.Cancel) then
							self._ebTicker:Cancel()
							self._ebTicker = nil
						end
					end
				end)
			end
			if (ImmersionFrame) then
				if (not self:IsHooked(ImmersionFrame, "OnShow")) then
					self:SecureHookScript(ImmersionFrame, "OnShow", function() ObjectiveTrackerFrame:SetAlpha(0) end)
				end
				if (not self:IsHooked(ImmersionFrame, "OnHide")) then
					self:SecureHookScript(ImmersionFrame, "OnHide", function() ObjectiveTrackerFrame:SetAlpha(.9) end)
				end
			end
		end
	end
end

Tracker.OnEnable = function(self)

	LoadAddOn("Blizzard_ObjectiveTracker")

	self:PrepareFrames()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("SETTINGS_LOADED", "OnEvent")

	-- Register slash commands for quick hiding of addon/clock text
	if (self.RegisterChatCommand) then
		self:RegisterChatCommand("az", "ToggleAZSlash")
	end

	-- Simple Slash handlers via AceConsole fallback
	if (self.db) then
		-- apply persisted choices
		if (self.db.profile.hideAddonText) then
			local mm = ns:GetModule("Minimap")
			if (mm and mm.addonCompartment and mm.addonCompartment.text) then
				mm.addonCompartment.text:Hide()
			end
		end
		if (self.db.profile.hideClockText) then
			local info = ns:GetModule("Info")
			if (info and info.time) then
				info.time:Hide()
			end
		end
	end
end


-- Slash command implementation (very small wrapper)
Tracker.ToggleAZSlash = function(self, input)
	if (not input or input == "") then
		print("AzeriteUI: Usage: /az remove addontext  OR  /az remove clocktext")
		return
	end

	local cmd, arg = strsplit(" ", input, 2)
	cmd = cmd and strlower(cmd) or ""
	arg = arg and strlower(arg) or ""

	if (cmd == "remove") then
		if (arg == "addontext") then
			self.db.profile.hideAddonText = true
			local mm = ns:GetModule("Minimap")
			if (mm and mm.addonCompartment and mm.addonCompartment.text) then
				mm.addonCompartment.text:Hide()
			end
			print("AzeriteUI: addon text hidden (persisted)")
			return
		elseif (arg == "clocktext") then
			self.db.profile.hideClockText = true
			local info = ns:GetModule("Info")
			if (info and info.time) then
				info.time:Hide()
			end
			print("AzeriteUI: clock text hidden (persisted)")
			return
		end
	end

	print("AzeriteUI: unknown command. Usage: /az remove addontext  OR  /az remove clocktext")
end

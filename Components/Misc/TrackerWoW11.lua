--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

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

-- Whether secure handler snippets compile on this client; see Core/Client.lua.
local hasSecureSnippets = ns.HasSecureSnippets ~= false

-- Hide while a boss or arena frame exists, show otherwise.
local GetAutoHideDriver = function()
	local driver = "hide;show"
	driver = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]" .. driver
	driver = "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists]" .. driver
	--driver = "[@target,exists]" .. driver -- For testing purposes

	return driver
end

-- The tracker is hidden by alpha rather than Hide(), leaving Blizzard's frame alone.
-- The alpha follows the auto-hider's shown state, and Immersion's while that is open.
-- OnShow/OnHide only fire on a change, so anything restoring the alpha must ask here
-- rather than assume the tracker should be showing.
local UpdateTrackerAlpha = function()
	local autoHider = ObjectiveTrackerFrame.autoHider
	local hidden = (autoHider and not autoHider:IsShown()) or (ImmersionFrame and ImmersionFrame:IsShown())
	ObjectiveTrackerFrame:SetAlpha(hidden and 0 or .9)
end

local defaults = { profile = ns:Merge({

	theme = "Azerite",
	disableBlizzardTracker = false

}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
Tracker.GenerateDefaults = function(self)
	return defaults
end

Tracker.QueueCombatRefresh = function(self)
	self.combatRefreshPending = true
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
end

Tracker.PrepareFrames = function(self)
	if (InCombatLockdown()) then
		self:QueueCombatRefresh()
		return false
	end
	if (ObjectiveTrackerFrame.autoHider) then
		return true
	end

	ObjectiveTrackerFrame.autoHider = CreateFrame("Frame", nil, ObjectiveTrackerFrame, "SecureHandlerStateTemplate")

	if (hasSecureSnippets) then
		ObjectiveTrackerFrame.autoHider:SetAttribute("_onstate-vis", [[ if (newstate == "hide") then self:Hide() else self:Show() end ]])
	end

	ObjectiveTrackerFrame.autoHider:SetScript("OnHide", UpdateTrackerAlpha)
	ObjectiveTrackerFrame.autoHider:SetScript("OnShow", UpdateTrackerAlpha)

	self:UpdateAutoHideDriver()

	ObjectiveTrackerUIWidgetContainer:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameLevel(50)
	ObjectiveTrackerFrame:SetClampedToScreen(false)
	UpdateTrackerAlpha()

	self.GetFrame = function() return ObjectiveTrackerFrame end

	return true
end

-- The tracker's own on/off setting and the boss/arena auto-hide are two answers to
-- the same question, so they are one driver string: "hide" while the tracker is
-- switched off, the boss/arena conditionals otherwise. Where snippets compile,
-- `_onstate-vis` shows and hides the hider; where they do not, Blizzard's native
-- visibility state does the same job without one.
--
-- Do not bring back a `forcevis` attribute for this. The hider is a
-- SecureHandlerStateTemplate, which only dispatches `state-*` attributes
-- (SecureHandlers.lua:107), so an `_onattributechanged` snippet on it never runs.
-- That is how the switch did nothing on Retail through 5.9.0.
Tracker.UpdateAutoHideDriver = function(self)
	local autoHider = ObjectiveTrackerFrame and ObjectiveTrackerFrame.autoHider
	if (not autoHider) then return end
	if (InCombatLockdown()) then
		self:QueueCombatRefresh()
		return false
	end

	local disabled = self.db and self.db.profile and self.db.profile.disableBlizzardTracker
	local driver = disabled and "hide" or GetAutoHideDriver()

	if (hasSecureSnippets) then
		RegisterStateDriver(autoHider, "vis", driver)
		return true
	end

	return ns.API.RegisterVisibilityDriver(autoHider, driver)
end

Tracker.UpdateSettings = function(self)
	-- Defers itself past combat. The alpha is not protected and is re-derived either
	-- way, so nothing here can assert the tracker back to visible.
	self:UpdateAutoHideDriver()
	UpdateTrackerAlpha()
end

Tracker.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_ENABLED") then
		if (InCombatLockdown()) then return end
		if (self.combatRefreshPending) then
			self.combatRefreshPending = nil
			self:PrepareFrames()
			self:UpdateSettings()
		end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	if (event == "PLAYER_ENTERING_WORLD" or event == "SETTINGS_LOADED") then
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
					self:SecureHookScript(ImmersionFrame, "OnShow", UpdateTrackerAlpha)
				end
				if (not self:IsHooked(ImmersionFrame, "OnHide")) then
					self:SecureHookScript(ImmersionFrame, "OnHide", UpdateTrackerAlpha)
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
end

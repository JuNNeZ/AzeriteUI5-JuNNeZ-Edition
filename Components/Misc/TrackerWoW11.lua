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
	end

 	ObjectiveTrackerFrame.autoHider:SetScript("OnHide", function() ObjectiveTrackerFrame:SetAlpha(0) end)
 	ObjectiveTrackerFrame.autoHider:SetScript("OnShow", function() ObjectiveTrackerFrame:SetAlpha(.9) end)

	if (hasSecureSnippets) then
		RegisterStateDriver(ObjectiveTrackerFrame.autoHider, "vis", GetAutoHideDriver())
	else
		-- Neither snippet can be compiled here, so both jobs move onto the one state
		-- Blizzard resolves itself. `_onstate-vis` becomes the native visibility state
		-- and `forcevis` folds into the same driver string: the whole answer is "hide"
		-- while the tracker is switched off, and the boss/arena conditionals otherwise.
		-- Registering a driver needs to be out of combat, which UpdateSettings honours.
		self:UpdateAutoHideDriver()
	end

	ObjectiveTrackerUIWidgetContainer:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameStrata("BACKGROUND")
	ObjectiveTrackerFrame:SetFrameLevel(50)
	ObjectiveTrackerFrame:SetClampedToScreen(false)
	ObjectiveTrackerFrame:SetAlpha(.9)

	self.GetFrame = function() return ObjectiveTrackerFrame end

	return true
end

-- The tracker's own on/off setting and the boss/arena auto-hide are two answers to
-- the same question, so where there is no snippet to combine them they are combined
-- into the driver string instead.
Tracker.UpdateAutoHideDriver = function(self)
	local autoHider = ObjectiveTrackerFrame and ObjectiveTrackerFrame.autoHider
	if (not autoHider) then return end
	if (InCombatLockdown()) then
		self:QueueCombatRefresh()
		return false
	end

	local disabled = self.db and self.db.profile and self.db.profile.disableBlizzardTracker

	return ns.API.RegisterVisibilityDriver(autoHider, disabled and "hide" or GetAutoHideDriver())
end

Tracker.UpdateSettings = function(self)
	if (InCombatLockdown()) then
		self:QueueCombatRefresh()
		return
	end

	-- Checked before the secret-value branch below, which returns early and would
	-- otherwise make this unreachable: `issecretvalue` exists on Forever too, so the
	-- client this is for never got here.
	if (not hasSecureSnippets) then
		self:UpdateAutoHideDriver()
		return
	end

	if (issecretvalue) then
		if ObjectiveTrackerFrame.autoHider then
			ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", self.db.profile.disableBlizzardTracker and "hide" or "show")
		end
		return
	end

	if (self.db.profile.disableBlizzardTracker) then

		if (not self:IsHooked(ObjectiveTrackerFrame, "Show")) then
			self:SecureHook(ObjectiveTrackerFrame, "Show", function(this)
				if (InCombatLockdown()) then
					self:QueueCombatRefresh()
					return
				end
				if (self.db.profile.disableBlizzardTracker and ObjectiveTrackerFrame.autoHider) then
					ObjectiveTrackerFrame.autoHider:SetAttribute("forcevis", "hide")
				end
			end)
		end

		if (not self:IsHooked(ObjectiveTrackerFrame, "SetShown")) then
			self:SecureHook(ObjectiveTrackerFrame, "SetShown", function(this, show)
				if (InCombatLockdown()) then
					self:QueueCombatRefresh()
					return
				end
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
end

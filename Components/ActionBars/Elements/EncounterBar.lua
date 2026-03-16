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

if (not ns.WoW10) then return end

if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local EncounterBar = ns:NewModule("EncounterBar", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

local defaults = { profile = ns:Merge({}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
EncounterBar.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "CENTER",
		[2] = 0,
		[3] = -200 * ns.API.GetEffectiveScale()
	}
	return defaults
end

EncounterBar.UpdateAnchor = function(self)
	if (not self.anchor) then return end

	-- Frame may not exist yet at login; bail out safely
	if (not self.frame) then return end

	if (self.PreUpdateAnchor) then
		if (self:PreUpdateAnchor()) then return end
	end

	local config = self.db.profile.savedPosition
	if (config) then

		local w,h = self.frame:GetSize()
		if (w < 10 or h < 10) then
			w, h = 250/config.scale, 30/config.scale
		end

		self.anchor:SetSize(w,h)
		self.anchor:SetScale(config.scale)
		self.anchor:ClearAllPoints()
		self.anchor:SetPoint(config[1], UIParent, config[1], config[2], config[3])
	end

	if (self.PostUpdateAnchor) then
		self:PostUpdateAnchor()
	end
end

EncounterBar.UpdatePositionAndScale = function(self)
	if (not self.frame) then return end

	if (InCombatLockdown()) then
		self.updateneeded = true
		return
	end

	if (self.PreUpdatePositionAndScale) then
		if (self:PreUpdatePositionAndScale()) then return end
	end

	self.updateneeded = nil

	local config = self.db.profile.savedPosition
	if (config) then
		-- Prevent our SetPoint from re-triggering the hook
		self._inPositionUpdate = true
		-- Apply position and scale
		self.frame:SetScale(config.scale)
		self.frame:ClearAllPoints()
		self.frame:SetPoint(config[1], UIParent, config[1], config[2]/config.scale, config[3]/config.scale)
		self._inPositionUpdate = nil
	end

	if (self.PostUpdatePositionAndScale) then
		self:PostUpdatePositionAndScale()
	end
end

-- Note: Do not override UpdatePositionAndScale with non-existent SetScaleBase/SetPointBase.
-- The base movable prototype uses SetScale and ClearAllPoints/SetPoint safely.

EncounterBar.OnPositionAndScaleChange = function(self)
	if (self._inPositionUpdate) then return end
	if ((MovieFrame and MovieFrame:IsShown()) or (CinematicFrame and CinematicFrame:IsShown())) then
		return
	end
	self:UpdatePositionAndScale()
end

EncounterBar.PrepareFrames = function(self)
	if (self.prepared) then return end

	self.frame = _G.EncounterBar -- UIWidgetPowerBarContainerFrame
	if (not self.frame) then return end

	if (not ns.ClientVersion or ns.ClientVersion < 120000) then
		_G.EncounterBar.HighlightSystem = ns.Noop
		_G.EncounterBar.ClearHighlight = ns.Noop
	end

	-- Do not hook SetPoint to avoid recursion during loading; we'll update on demand.
	self.prepared = true
end

-- No event handler needed; we position once when enabled and when the frame exists.

EncounterBar.OnInitialize = function(self)
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end

	ns.MovableModulePrototype.OnInitialize(self)
end

EncounterBar.OnEnable = function(self)

	self:PrepareFrames()
	self:CreateAnchor(HUD_EDIT_MODE_ENCOUNTER_BAR_LABEL or "Encounter Bar", true)

	ns.MovableModulePrototype.OnEnable(self)

	if (self.prepared) then
		-- If some module reparented it to our hider, restore it.
		local parent = self.frame:GetParent()
		if (parent == ns.Hider) then
			self.frame:SetParent(UIParent)
		end
		-- Ensure it’s not alpha-hidden
		self.frame:SetAlpha(1)
		-- Let Blizzard drive visibility, but make sure it’s not stuck hidden
		self.frame:Show()
		self:UpdatePositionAndScale()
	end
end






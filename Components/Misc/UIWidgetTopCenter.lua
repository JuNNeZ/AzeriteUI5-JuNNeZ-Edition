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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local UIWidgetTopCenter = ns:NewModule("UIWidgetTopCenter", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

-- GLOBALS: CreateFrame, UnitExists, UIParent, UIWidgetTopCenterContainerFrame

local defaults = { profile = ns:Merge({
	hideWithTarget = true,   -- original behavior
	alwaysShow = false       -- new: keep visible even with target
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
UIWidgetTopCenter.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = 14/12 * ns.API.GetEffectiveScale(),
		[1] = "TOP",
		[2] = 0,
		[3] = -10 * ns.API.GetEffectiveScale()
	}
	return defaults
end

UIWidgetTopCenter.UpdateContentPosition = function(self)
	local _,anchor = self.frame.contents:GetPoint()
	if (anchor ~= self.frame) then
		self:Unhook(self.frame.contents, "SetPoint")
		self.frame.contents:SetParent(self.frame)
		self.frame.contents:ClearAllPoints()
		self.frame.contents:SetPoint("TOP", self.frame)
		self:SecureHook(self.frame.contents, "SetPoint", "UpdateContentPosition")
	end
end

UIWidgetTopCenter.PrepareFrames = function(self)
	if (not UIWidgetTopCenterContainerFrame) then
		return -- Not yet available (can happen very early). We'll retry later.
	end

	local frame = CreateFrame("Frame", ns.Prefix.."TopCenterWidgets", UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetFrameLevel(10)
	frame:SetSize(58,58)

	local contents = UIWidgetTopCenterContainerFrame
	contents:ClearAllPoints()
	contents:SetParent(UIParent)
	contents:SetFrameStrata("BACKGROUND")

	-- This will prevent UIParent_ManageFramePositions() from being executed
	-- *for some reason it's not working? Why not?
	--contents.IsShown = function() return false end

	self.frame = frame
	self.frame.contents = contents

	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:SecureHook(self.frame.contents, "SetPoint", "UpdateContentPosition")
end

UIWidgetTopCenter.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED") then
		if (self.db.profile.alwaysShow) then
			self.frame:Show()
			self:UpdateContentPosition()
		else
			if (self.db.profile.hideWithTarget and UnitExists("target")) then
				self.frame:Hide()
			else
				self.frame:Show()
				self:UpdateContentPosition()
			end
		end
	end
end

UIWidgetTopCenter.OnEnable = function(self)
	self:PrepareFrames()
	if (self.frame) then
		self:CreateAnchor(L["Widgets: Top"])
		ns.MovableModulePrototype.OnEnable(self)
	else
		-- Retry once the world has loaded (container should exist by then)
		local function TryInit()
			if (self.frame) then return end
			self:PrepareFrames()
			if (self.frame) then
				self:CreateAnchor(L["Widgets: Top"])
				ns.MovableModulePrototype.OnEnable(self)
				self:OnEvent("PLAYER_TARGET_CHANGED") -- Apply initial visibility
			end
		end
		self:RegisterEvent("PLAYER_ENTERING_WORLD", function() TryInit() end)
	end
end

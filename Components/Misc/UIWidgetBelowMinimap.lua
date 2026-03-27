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

if (not UIWidgetBelowMinimapContainerFrame) then return end

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local UIWidgetBelowMinimap = ns:NewModule("UIWidgetBelowMinimap", ns.MovableModulePrototype, "LibMoreEvents-1.0", "AceHook-3.0")

-- GLOBALS: CreateFrame, UIParent, UIWidgetBelowMinimapContainerFrame

local defaults = { profile = ns:Merge({}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
UIWidgetBelowMinimap.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOMRIGHT",
		[2] = -40 * ns.API.GetEffectiveScale(),
		[3] = (40 + 200 + 40) * ns.API.GetEffectiveScale()
	}
	return defaults
end

UIWidgetBelowMinimap.UpdateContentPosition = function(self)
	local _,anchor = self.frame.contents:GetPoint()
	if (anchor ~= self.frame) then
		self:Unhook(self.frame.contents, "SetPoint")
		self.frame.contents:SetParent(self.frame)
		self.frame.contents:ClearAllPoints()
		self.frame.contents:SetPoint("TOP", self.frame)
		self:SecureHook(self.frame.contents, "SetPoint", "UpdateContentPosition")
	end
end

UIWidgetBelowMinimap.PrepareFrames = function(self)

	local frame = CreateFrame("Frame", ns.Prefix.."BelowMinimapWidgets", UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetFrameLevel(10)
	frame:SetSize(128,40)

	local contents = UIWidgetBelowMinimapContainerFrame
	contents:ClearAllPoints()
	contents:SetParent(UIParent)
	contents:SetFrameStrata("BACKGROUND")

	-- Do NOT override GetNumWidgetsShowing on the Blizzard container frame.
	-- Writing an addon closure onto a Blizzard UIWidget container taints it in WoW12,
	-- causing "attempt to perform arithmetic on a secret number value" in
	-- Blizzard_UIWidgetTemplateBase:Setup when widgetWidth/widgetHeight are read back.
	-- Instead, the SetPoint SecureHook below re-anchors the container whenever
	-- UIParent_ManageFramePositions (UIParent.lua) moves it.
	contents:SetFrameStrata("BACKGROUND")

	self.frame = frame
	self.frame.contents = contents

	self:SecureHook(self.frame.contents, "SetPoint", "UpdateContentPosition")

	-- Might want to reposition this based on boss visibility
	--local driver = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	--driver.EnableBoss = function() end
	--driver.DisableBoss = function() end
	--driver:SetAttribute("_onattributechanged", [=[
	--	if (name == "state-pos") then
	--		if (value == "boss") then
	--			self:CallMethod("EnableBoss");
	--		elseif (value == "normal") then
	--			self:CallMethod("DisableBoss");
	--		end
	--	end
	--]=])
	--RegisterAttributeDriver(driver, "state-pos", "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists]boss;normal")

end

UIWidgetBelowMinimap.OnEnable = function(self)

	self:PrepareFrames()
	self:CreateAnchor(L["Widgets: Minimap"])

	ns.MovableModulePrototype.OnEnable(self)
end

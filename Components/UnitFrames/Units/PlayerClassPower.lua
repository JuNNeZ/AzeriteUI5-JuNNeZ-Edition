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
local oUF = ns.oUF

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local ClassPowerMod = ns:NewModule("PlayerClassPowerFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local next = next
local type = type
local unpack = unpack

-- Addon API
local IsAddOnEnabled = ns.API.IsAddOnEnabled
local noop = ns.Noop

-- Constants
local playerClass = ns.PlayerClass

local defaults = { profile = ns:Merge({
	showComboPoints = true,
	showArcaneCharges = ns.IsRetail or nil,
	showChi = ns.IsRetail or nil,
	showHolyPower = ns.IsRetail or nil,
	showSoulFragments = ns.IsRetail or nil,
	soulFragmentsDisplayMode = "gradient",
	showRunes = ns.IsCata or ns.IsRetail or nil,
	showSoulShards = ns.IsRetail or nil,
	showStagger = ns.IsRetail or nil,
	clickThrough = true,
	classPointOffsets = {
		[1] = { 0, 0 }, [2] = { 0, 0 }, [3] = { 0, 0 }, [4] = { 0, 0 }, [5] = { 0, 0 },
		[6] = { 0, 0 }, [7] = { 0, 0 }, [8] = { 0, 0 }, [9] = { 0, 0 }, [10] = { 0, 0 }
	}
}, ns.MovableModulePrototype.defaults) }

local ApplyClassPowerClickThrough = function(self)
	if (not self or not self.frame) then
		return
	end

	local classpower = self.frame.ClassPower
	if (not classpower) then
		return
	end

	if (not classpower.ClickBlocker) then
		local blocker = CreateFrame("Frame", nil, classpower)
		blocker:SetAllPoints(classpower)
		blocker:EnableMouse(false)
		blocker:SetFrameStrata(classpower:GetFrameStrata())
		blocker:SetFrameLevel(classpower:GetFrameLevel() + 20)
		blocker:SetScript("OnMouseDown", noop)
		blocker:SetScript("OnMouseUp", noop)
		classpower.ClickBlocker = blocker
	end

	local clickThrough = (self.db and self.db.profile and self.db.profile.clickThrough) and true or false
	classpower.ClickBlocker:EnableMouse(not clickThrough)
end

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
ClassPowerMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "CENTER",
		[2] = -223 * ns.API.GetEffectiveScale(),
		[3] = -84 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Element Callbacks
--------------------------------------------
-- Create a point used for classpowers, stagger and runes.
local ClassPower_CreatePoint = function(element, index)
	local db = ns.GetConfig("PlayerClassPower")

	local point = element:GetParent():CreateBar(nil, element)
	point:SetOrientation(db.ClassPowerPointOrientation)
	point:SetSparkTexture(db.ClassPowerSparkTexture)
	point:SetMinMaxValues(0, 1)
	point:SetValue(1)
	
	-- Move the status bar texture to BACKGROUND layer so text can overlay it
	local statusBarTexture = point:GetStatusBarTexture()
	if (statusBarTexture) then
		statusBarTexture:SetDrawLayer("BACKGROUND", 1)
	end

	local case = point:CreateTexture(nil, "BACKGROUND", nil, -2)
	case:SetPoint("CENTER")
	case:SetVertexColor(unpack(db.ClassPowerCaseColor))
	case:SetDrawLayer("BACKGROUND", 0)

	point.case = case

	local slot = point:CreateTexture(nil, "BACKGROUND", nil, -1)
	slot:SetPoint("TOPLEFT", -db.ClassPowerSlotOffset, db.ClassPowerSlotOffset)
	slot:SetPoint("BOTTOMRIGHT", db.ClassPowerSlotOffset, -db.ClassPowerSlotOffset)
	slot:SetVertexColor(unpack(db.ClassPowerSlotColor))
	slot:SetDrawLayer("BACKGROUND", 0)

	point.slot = slot

	-- Store reference for styling to add labels later
	point.index = index

	return point
end

local ClassPower_PostUpdateColor = function(element, r, g, b)
	-- oUF callback for color updates (not actively used for SoulFragmentsPoints)
end

-- Update classpower layout and textures.
-- *also used for one-time setup of stagger and runes.
local ClassPower_PostUpdate = function(element, cur, max, hasMaxChanged, powerType)
	if (not cur or not max) then
		return
	end


	-- Paladins should never display above 5 holy power points in this layout.
	if (playerClass == "PALADIN") then
		max = 5
		if cur > max then cur = max end
	end

	-- Store original soul fragments value before conversion for display logic.
	local origCur = cur

	-- Requested behavior: only show class power while at least one point is active.
	if (type(cur) ~= "number" or cur <= 0) then
		return element:Hide()
	end

	-- Soul Fragments special handling: convert normalized value (0-1 = 0-50 stacks) to 1-10 point display (every 5 stacks = 1 point)
	if (powerType == "SOUL_FRAGMENTS" and max == 1) then
		origCur = math.floor(cur * 50)  -- Store actual soul fragment count (0-50)
		cur = math.ceil(cur * 10)  -- Normalized 0-1 value maps to 0-10 points (1 point = 5 stacks)
		max = 10
	end

	local style
	if (powerType == "RUNES") then
		-- Death Knight runes (always use Runes layout)
		style = "Runes"
	elseif (powerType == "SOUL_FRAGMENTS") then
		-- Devourer DH soul fragments (10-point system with numbered indicators)
		style = "SoulFragmentsPoints"
	elseif (max >= 6) then
		-- Combo points with Deeper Stratagem or similar (6-7 points)
		-- Use ComboPoints layout which now supports up to 7
		style = "ComboPoints"
	elseif (max == 5) then
		style = playerClass == "MONK" and "Chi" or playerClass == "WARLOCK" and "SoulShards" or "ComboPoints"
	elseif (max == 4) then
		style = "ArcaneCharges"
	elseif (max == 3) then
		style = "Stagger"
	end

	if (not style) then
		return element:Hide()
	end

	local db = ClassPowerMod.db.profile

	if (ns.IsRetail) then
		if (playerClass == "MAGE" and powerType == "ARCANE_CHARGES" and not db.showArcaneCharges)
		or (playerClass == "MONK" and powerType == "CHI" and not db.showChi)
		or (playerClass == "PALADIN" and powerType == "HOLY_POWER" and not db.showHolyPower)
		or (playerClass == "DEMONHUNTER" and powerType == "SOUL_FRAGMENTS" and not db.showSoulFragments)
		or (playerClass == "WARLOCK" and powerType == "SOUL_SHARDS" and not db.showSoulShards)
		or (powerType == "COMBO_POINTS" and not db.showComboPoints) then
			return element:Hide()
		end
	end
	if (not element:IsShown()) then
		element:Show()
	end

	local visiblePointCap = (style == "SoulFragmentsPoints") and 5 or max
	if (type(visiblePointCap) ~= "number") then
		visiblePointCap = 0
	end
	for i = 1, #element do
		local point = element[i]
		if (point) then
			if (i <= visiblePointCap) then
				point:Show()
			else
				point:Hide()
			end
		end
	end

	for i = 1, #element do
		local point = element[i]
		if (point:IsShown()) then
			local value = point:GetValue()
			local _, pmax = point:GetMinMaxValues()
			-- Soul Fragments Points with configurable display modes.
			if (style == "SoulFragmentsPoints") then
				local displayMode = db.soulFragmentsDisplayMode or "gradient"

				-- Backward compatibility with old saved values.
				if (displayMode == "brightness") then
					displayMode = "alpha"
				elseif (displayMode == "color") then
					displayMode = "gradient"
				end

				local lightPurple = {220/255, 180/255, 255/255}
				local darkPurple = {100/255, 60/255, 180/255}
				local basePurple = {156/255, 116/255, 255/255}

				if (point.case) then
					point.case:SetAlpha(1)
				end
				if (point.slot) then
					point.slot:SetAlpha(1)
				end

				if (displayMode == "alpha") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					point:SetStatusBarColor(unpack(basePurple))
					if (cur <= 5) then
						point:SetValue((i <= cur) and 1 or 0)
						point:SetAlpha((i <= cur) and 0.5 or 0.3)
					else
						point:SetValue((i <= (cur - 5)) and 1 or 0)
						point:SetAlpha((i <= (cur - 5)) and 1.0 or 0.3)
					end

				elseif (displayMode == "recolor") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					if (origCur <= 25) then
						local activePoints = math.min(math.ceil(origCur / 5), 5)
						point:SetStatusBarColor(unpack(lightPurple))
						point:SetValue((i <= activePoints) and 1 or 0)
						point:SetAlpha((i <= activePoints) and 1.0 or 0.3)
					else
						local darkPoints = math.min(math.floor((origCur - 25) / 5), 5)
						point:SetValue(1)
						point:SetAlpha(1.0)
						if (i <= darkPoints) then
							point:SetStatusBarColor(unpack(darkPurple))
						else
							point:SetStatusBarColor(unpack(lightPurple))
						end
					end

				elseif (displayMode == "stacked") then
					if (element.goldenGlow and element.goldenGlow:IsShown()) then
						element.goldenGlow:Hide()
					end

					point:SetStatusBarColor(unpack(basePurple))

					if (cur < 5) then
						local activePoints = math.max(0, math.min(cur, 5))
						local isActive = (i <= activePoints)
						point:SetValue(isActive and 1 or 0)
						point:SetAlpha(isActive and 1.0 or 0)
						if (point.case) then
							point.case:SetAlpha(isActive and 1.0 or 0)
						end
						if (point.slot) then
							point.slot:SetAlpha(isActive and 1.0 or 0)
						end
					else
						local overflow = math.max(0, math.min(cur - 5, 5))
						local isOverflowActive = (i <= overflow)
						point:SetValue(1)
						point:SetAlpha(isOverflowActive and 1.0 or 0.45)
						if (point.case) then
							point.case:SetAlpha(1.0)
						end
						if (point.slot) then
							point.slot:SetAlpha(1.0)
						end
					end

				else -- "gradient"
					local hasVoidMeta = (AuraUtil.FindAuraByName("Void Metamorphosis", "player", "HELPFUL") ~= nil)

					if (element.goldenGlow) then
						if (origCur >= 50 or hasVoidMeta) then
							if (not element.goldenGlow:IsShown()) then
								element.goldenGlow:Show()
							end
							element.goldenGlow:SetAlpha(0.4 + (math.sin(GetTime() * 3) * 0.3))
						elseif (element.goldenGlow:IsShown()) then
							element.goldenGlow:Hide()
						end
					end

					local gradientFactor = (i - 1) / 9
					local r = lightPurple[1] * (1 - gradientFactor) + darkPurple[1] * gradientFactor
					local g = lightPurple[2] * (1 - gradientFactor) + darkPurple[2] * gradientFactor
					local b = lightPurple[3] * (1 - gradientFactor) + darkPurple[3] * gradientFactor

					point:SetStatusBarColor(r, g, b)
					if (cur <= 5) then
						point:SetValue((i <= cur) and 1 or 0)
						point:SetAlpha((i <= cur) and 1.0 or 0.3)
					else
						point:SetValue((i <= (cur - 5)) and 1 or 0)
						point:SetAlpha((i <= (cur - 5)) and 1.0 or 0.3)
					end
				end
			elseif (element.inCombat) then
				point:SetAlpha((cur == max) and 1 or (value < pmax) and .5 or 1)
			else
				point:SetAlpha((cur == max) and 0 or (value < pmax) and .5 or 1)
			end
		end
	end

	if (style ~= element.style) then

		local layoutdb = ns.GetConfig("PlayerClassPower").ClassPowerLayouts[style]
		if (layoutdb) then

			local offsets = db.classPointOffsets or {}
			-- Iterate through layout explicitly by index to ensure all points are processed in order
			local maxPoints = (style == "SoulFragmentsPoints") and 5 or 10
			for i = 1, maxPoints do
				local info = layoutdb[i]
				local point = element[i]
				if (point and info) then
					local rotation = info.PointRotation or 0
					local barSize = { unpack(info.Size) }
					local backdropSize = { unpack(info.BackdropSize) }
					local barPos = { unpack(info.Position) }

					-- Apply combo point offsets
					local offset = offsets[i] or { 0, 0 }
					local adjustedPos = { barPos[1], barPos[2] + (offset[1] or 0), barPos[3] + (offset[2] or 0) }

					point:ClearAllPoints()
					point:SetPoint(unpack(adjustedPos))
					point:SetSize(unpack(barSize))
					point:SetStatusBarTexture(info.Texture)

					-- Apply custom orientation for soul fragments (left-to-right fill)
					if (info.Orientation) then
						point:SetOrientation(info.Orientation)
					end

					-- Apply default purple fill for soul fragments points.
					if (style == "SoulFragmentsPoints") then
						-- Note: actual color is set dynamically in PostUpdate based on displayMode setting
						-- This is just the default fallback (will be overridden)
						point:SetStatusBarColor(156/255, 116/255, 255/255) -- Default purple fill
					end

					point.case:SetSize(unpack(backdropSize))
					point.case:SetTexture(info.BackdropTexture)
					point.case:SetRotation(rotation)

					point.slot:SetTexture(info.Texture)
					point.slot:SetRotation(rotation)

					-- Keep cap enforcement even on style changes (e.g. Paladin should stay at 5).
					if (i <= visiblePointCap) then
						point:Show()
					else
						point:Hide()
					end
				end
			end

			-- Should be handled by the element,
			-- no idea why I'm adding it here.
			for i = maxPoints + 1, #element do
				element[i]:Hide()
			end
		end

		element.style = style
	end


end

local Runes_PostUpdate = function(element, runemap, hasVehicle, allReady)
	for i = 1, #element do
		local rune = element[i]
		if (rune:IsShown()) then
			local value = rune:GetValue()
			local _, max = rune:GetMinMaxValues()
			if (element.inCombat) then
				rune:SetAlpha(allReady and 1 or (value < max) and .5 or 1)
			else
				rune:SetAlpha(allReady and 0 or (value < max) and .5 or 1)
			end
		end
	end
end

local Runes_PostUpdateColor = function(element, r, g, b, color, rune)
	if (rune) then
		rune:SetStatusBarColor(r, g, b)
	else
		if (not ns.IsCata) then
			color = element.__owner.colors.power.RUNES
			r, g, b = color[1], color[2], color[3]
		end
		for i = 1, #element do
			local rune = element[i]
			if (ns.IsCata) then
				color = element.__owner.colors.runes[rune.runeType]
				r, g, b = color[1], color[2], color[3]
			end
			rune:SetStatusBarColor(r, g, b)
		end
	end
end

local Stagger_SetStatusBarColor = function(element, r, g, b)
	for i = 1, 3 do
		local point = element[i]
		point:SetStatusBarColor(r, g, b)
	end
end

local Stagger_PostUpdate = function(element, cur, max)

	element[1].min = 0
	element[1].max = max * .3
	element[2].min = element[1].max
	element[2].max = max * .6
	element[3].min = element[2].max
	element[3].max = max

	for i = 1, 3 do
		local point = element[i]
		local value = (cur > point.max) and point.max or (cur < point.min) and point.min or cur

		point:SetMinMaxValues(point.min, point.max)
		point:SetValue(value)

		if (element.inCombat) then
			point:SetAlpha((cur == max) and 1 or (value < point.max) and .5 or 1)
		else
			point:SetAlpha((cur == 0) and 0 or (value < point.max) and .5 or 1)
		end
	end
end

-- Frame Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_DISABLED") then
		local runes = self.Runes
		if (runes and not runes.inCombat) then
			runes.inCombat = true
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and not stagger.inCombat) then
			stagger.inCombat = true
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower and not classpower.inCombat) then
			classpower.inCombat = true
			classpower:ForceUpdate()
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		local runes = self.Runes
		if (runes and runes.inCombat) then
			runes.inCombat = false
			runes:ForceUpdate()
		end
		local stagger = self.Stagger
		if (stagger and stagger.inCombat) then
			stagger.inCombat = false
			stagger:ForceUpdate()
		end
		local classpower = self.ClassPower
		if (classpower and classpower.inCombat) then
			classpower.inCombat = false
			classpower:ForceUpdate()
		end
	end
end

local UnitFrame_OnHide = function(self)
	self.inCombat = nil
end

local style = function(self, unit)

	local db = ns.GetConfig("PlayerClassPower")

	self:SetSize(unpack(db.ClassPowerFrameSize))

	local SCP = IsAddOnEnabled("SimpleClassPower")
	if (not SCP) then

		-- Class Power
		--------------------------------------------
		-- 	Supported class powers:
		-- 	- All     - Combo Points
		-- 	- Mage    - Arcane Charges
		-- 	- Monk    - Chi Orbs
		-- 	- Paladin - Holy Power
		-- 	- Warlock - Soul Shards
		--------------------------------------------
		local classpower = CreateFrame("Frame", nil, self)
		classpower:SetAllPoints(self)

		local maxPoints = 10 -- for fuck's sake
		for i = 1,maxPoints do
			classpower[i] = ClassPower_CreatePoint(classpower)
		end

		-- Create golden glow texture behind all soul fragments points
		local goldenGlow = classpower:CreateTexture(nil, "BACKGROUND")
		goldenGlow:SetSize(160, 160)
		goldenGlow:SetPoint("CENTER", classpower, "TOPLEFT", 82, -74)  -- Center on middle of 5-point arc
		goldenGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
		goldenGlow:SetBlendMode("ADD")
		goldenGlow:SetVertexColor(1, 0.84, 0, 0.8)  -- Golden color
		goldenGlow:SetAlpha(0)  -- Hidden by default
		goldenGlow:Hide()
		classpower.goldenGlow = goldenGlow
		
		self.ClassPower = classpower
		self.ClassPower.PostUpdate = ClassPower_PostUpdate
		self.ClassPower.PostUpdateColor = ClassPower_PostUpdateColor

		-- Monk Stagger
		--------------------------------------------
		if (playerClass == "MONK") then

			local stagger = CreateFrame("Frame", nil, self)
			stagger:SetAllPoints(self)

			stagger.SetValue = noop
			stagger.SetMinMaxValues = noop
			stagger.SetStatusBarColor = Stagger_SetStatusBarColor

			for i = 1,3 do
				stagger[i] = ClassPower_CreatePoint(stagger)
			end

			ClassPower_PostUpdate(stagger, 0, 3)

			self.Stagger = stagger
			self.Stagger.PostUpdate = Stagger_PostUpdate
		end

	end

	-- Death Knight Runes
	--------------------------------------------
	if (playerClass == "DEATHKNIGHT") then

		local runes = CreateFrame("Frame", nil, self)
		runes:SetAllPoints(self)

		runes.sortOrder = "ASC"
		for i = 1,6 do
			runes[i] = ClassPower_CreatePoint(runes)
		end

		ClassPower_PostUpdate(runes, 6, 6)

		self.Runes = runes
		self.Runes.PostUpdate = Runes_PostUpdate
		self.Runes.PostUpdateColor = Runes_PostUpdateColor
	end

	-- Scripts & Events
	--------------------------------------------
	self.OnEvent = UnitFrame_OnEvent
	self.OnHide = UnitFrame_OnHide

	self:RegisterEvent("PLAYER_REGEN_ENABLED", self.OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", self.OnEvent, true)

end

ClassPowerMod.CreateUnitFrames = function(self)

	local unit, name = "player", "PlayerClassPower"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
	self.frame:EnableMouse(false)
end

ClassPowerMod.GetLabel = function(self)
	return ns.IsClassic and L["Combo Points"] or L["Class Power"]
end

ClassPowerMod.PostUpdateAnchor = function(self)
	if (not self.anchor) then return end

	self.anchor:SetTitle(self:GetLabel())
end

ClassPowerMod.Update = function(self)

	if (ns.IsCata or ns.IsRetail) and (playerClass == "DEATHKNIGHT") then
		if (self.db.profile.showRunes) then
			self.frame:EnableElement("Runes")
			self.frame.Runes:ForceUpdate()
		else
			self.frame:DisableElement("Runes")
		end
	end

	if (ns.IsRetail and playerClass == "MONK") then
		if (self.db.profile.showStagger) then
			self.frame:EnableElement("Stagger")
			self.frame.Stagger:ForceUpdate()
		else
			self.frame:DisableElement("Stagger")
		end
	end

	ApplyClassPowerClickThrough(self)
	self.frame.ClassPower:ForceUpdate()

end

ClassPowerMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(self:GetLabel())
	ApplyClassPowerClickThrough(self)

	ns.MovableModulePrototype.OnEnable(self)
end

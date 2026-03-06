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

local ToTFrameMod = ns:NewModule("ToTFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local unpack = unpack
local string_gsub = string.gsub

local defaults = { profile = ns:Merge({
	hideWhenTargetingPlayer = true,
	hideWhenTargetingSelf = true
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
ToTFrameMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPRIGHT",
		[2] = -492 * ns.API.GetEffectiveScale(),
		[3] = -67 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview and g) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

local HideToTAbsorbBarVisual = function(absorbBar)
	if (not absorbBar) then
		return
	end
	if (absorbBar.SetStatusBarColor) then
		absorbBar:SetStatusBarColor(0, 0, 0, 0)
	end
	if (absorbBar.SetAlpha) then
		absorbBar:SetAlpha(0)
	end
	if (absorbBar.Hide) then
		absorbBar:Hide()
	end
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	if (myIncomingHeal == nil and element and element.values and element.values.GetIncomingHeals) then
		local _, playerHeal, otherHeal = element.values:GetIncomingHeals()
		local healAbsorbAmount = 0
		if (element.values.GetHealAbsorbs) then
			healAbsorbAmount = select(1, element.values:GetHealAbsorbs()) or 0
		end
		myIncomingHeal = playerHeal
		otherIncomingHeal = otherHeal
		healAbsorb = healAbsorbAmount
		curHealth = UnitHealth(unit)
		maxHealth = UnitHealthMax(unit)
	end
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0
	curHealth = tonumber(curHealth) or 0
	maxHealth = tonumber(maxHealth) or 1	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	local safeCur, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if (not safeCur or not safeMax) then
		ns.API.HidePrediction(element)
		return
	end
	curHealth, maxHealth = safeCur, safeMax

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local allNegativeHeals = healAbsorb
	local showPrediction, change

	if ((allIncomingHeal > 0) or (allNegativeHeals > 0)) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Dev switch to test absorbs with normal healing
		--allIncomingHeal, allNegativeHeals = allNegativeHeals, allIncomingHeal

		-- Hide predictions if the change is very small, or if the unit is at max health.
		change = (allIncomingHeal - allNegativeHeals)/maxHealth
		if ((curHealth < maxHealth) and (change > (element.health.predictThreshold or .05))) then
			local endPoint = startPoint + change

			-- Crop heal prediction overflows
			if (endPoint > 1) then
				endPoint = 1
				change = endPoint - startPoint
			end

			-- Crop heal absorb overflows
			if (endPoint < 0) then
				endPoint = 0
				change = -startPoint
			end

			-- This shouldn't happen, but let's do it anyway.
			if (startPoint ~= endPoint) then
				showPrediction = true
			end
		end
	end

	if (showPrediction) then

		local preview = element.preview
		local growth = preview:GetGrowth()
		local _,max = preview:GetMinMaxValues()
		local value = preview:GetValue() / max
		local previewTexture = preview:GetStatusBarTexture()
		local previewWidth, previewHeight = preview:GetSize()
		local left, right, top, bottom = preview:GetTexCoord()
		local isFlipped = preview:IsFlippedHorizontally()

		if (growth == "RIGHT") then

			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end

		elseif (growth == "LEFT") then
			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end
		end
	else
		element:Hide()
	end

	if (element.absorbBar) then
		element.absorbBar:SetValue(0)
		HideToTAbsorbBarVisual(element.absorbBar)
	end

end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight
	unit = unit or self.unit

	if (UnitIsUnit(unit, "focus")) then
		element:SetVertexColor(unpack(element.colorFocus))
		element:Show()
	else
		element:Hide()
	end

end

local Unitframe_PostUpdateAlpha = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit

	local shouldHide = ((event == "UnitFrame_Target_Updated") and (... == "Critter"))
		or (ToTFrameMod.db.profile.hideWhenTargetingPlayer and UnitIsUnit(unit, "player"))
		or (ToTFrameMod.db.profile.hideWhenTargetingSelf and UnitIsUnit(unit, unit.."target"))

	-- WoW 12 secret-value safety: UnitIsUnit can return secret booleans
	if (issecretvalue(shouldHide)) then
		shouldHide = false -- Conservative fallback: don't hide on secret
	end

	if (shouldHide == self.shouldHide) then
		return
	end

	self.shouldHide = shouldHide
	self:SetAlpha(shouldHide and 0 or 1)

	ns:Fire("UnitFrame_ToT_Updated", unit)
end

local UnitFrame_PostUpdate = function(self, event, unit, ...)
	if (event == "UnitFrame_Target_Updated") then unit = nil end
	if (unit and unit ~= self.unit) then return end

	Unitframe_PostUpdateAlpha(self, event, unit, ...)
	TargetHighlight_Update(self, event, unit, ...)
end

local UnitFrame_OnEvent = function(self, event, unit, ...)
	UnitFrame_PostUpdate(self, event, ...)
end

local style = function(self, unit)

	local db = ns.GetConfig("ToTFrame")

	self:SetSize(unpack(db.Size))
	self:SetHitRectInsets(unpack(db.HitRectInsets))
	self:SetFrameLevel(self:GetFrameLevel() + 10)

	-- Overlay for icons and text
	--------------------------------------------
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 7)
	overlay:SetAllPoints()

	self.Overlay = overlay

	-- Health
	--------------------------------------------
	local health = self:CreateBar()
	if (health.SetForceNative) then health:SetForceNative(true) end
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	if (health.DisableSmoothing) then
		health:DisableSmoothing(true) -- WoW 12.0: Disable smoothing to prevent proxy flickering
	end
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	-- WoW 12.0: Only set texture if it changed to prevent flickering
	if (health._cachedTexture ~= db.HealthBarTexture) then
		health:SetStatusBarTexture(db.HealthBarTexture)
		health._cachedTexture = db.HealthBarTexture
	end
	health:SetOrientation(db.HealthBarOrientation)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorThreat = true
	health.colorClass = true
	--health.colorClassPet = true
	health.colorHappiness = true
	health.colorReaction = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))

	self.Health.Backdrop = healthBackdrop

	local healthPreview = self:CreateBar(nil, health)
	if (healthPreview.SetForceNative) then healthPreview:SetForceNative(true) end
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	if (healthPreview._cachedTexture ~= db.HealthBarTexture) then
		healthPreview:SetStatusBarTexture(db.HealthBarTexture)
		healthPreview._cachedTexture = db.HealthBarTexture
	end
	healthPreview:SetOrientation(db.HealthBarOrientation)
	healthPreview:SetSparkTexture("")
	-- Keep preview as an internal prediction helper, but hide its own visual layer
	-- to avoid a permanent "ghost" duplicate of the health bar.
	healthPreview:SetAlpha(0)
	healthPreview:Hide()
	if (healthPreview.DisableSmoothing) then
		healthPreview:DisableSmoothing(true)
	end

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict:SetTexture(db.HealthBarTexture)
	healPredict.health = health
	healPredict.preview = healthPreview
	healPredict.maxOverflow = 1

	self.HealthPrediction = healPredict
	self.HealthPrediction.PostUpdate = HealPredict_PostUpdate

	-- Cast Overlay (plain StatusBar)
	local castbar = CreateFrame("StatusBar", nil, self)
	castbar:SetAllPoints(health)
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetStatusBarTexture(db.HealthBarTexture)
	castbar:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	castbar:Hide()

	self.Castbar = castbar

	-- Health Value
	--------------------------------------------
	local healthValue = health:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:HealthCurrent]"))

	self.Health.Value = healthValue

	-- Health Percentage (disabled for ToT)

	-- Unit Name
	--------------------------------------------
	local name = self:CreateFontString(nil, "OVERLAY", nil, 1)
	name:SetPoint(unpack(db.NamePosition))
	name:SetFontObject(db.NameFont)
	name:SetTextColor(unpack(db.NameColor))
	name:SetJustifyH(db.NameJustifyH)
	name:SetJustifyV(db.NameJustifyV)
	--self:Tag(name, prefix("[*:Name(16,true,nil,true)]"))
	self:Tag(name, prefix("[*:Name(16,true,nil,nil)]")) -- maxChars, showLevel, showLevelLast, showFull

	self.Name = name

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		if (absorb.SetForceNative) then absorb:SetForceNative(true) end
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		if (absorb._cachedTexture ~= db.HealthBarTexture) then
			absorb:SetStatusBarTexture(db.HealthBarTexture)
			absorb._cachedTexture = db.HealthBarTexture
		end
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetSparkMap(db.HealthBarSparkMap)

		local orientation
		if (db.HealthBarOrientation == "UP") then
			orientation = "DOWN"
		elseif (db.HealthBarOrientation == "DOWN") then
			orientation = "UP"
		elseif (db.HealthBarOrientation == "LEFT") then
			orientation = "RIGHT"
		else
			orientation = "LEFT"
		end
		absorb:SetOrientation(orientation)
		HideToTAbsorbBarVisual(absorb)
		if (absorb.HookScript) then
			absorb:HookScript("OnShow", function(source)
				HideToTAbsorbBarVisual(source)
			end)
		end

		self.HealthPrediction.absorbBar = absorb
		self.HealthPrediction.__AzeriteUI_HideAbsorbWithPrediction = true
	end

	-- Target Highlight
	--------------------------------------------
	local targetHighlight = overlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor

	self.TargetHighlight = targetHighlight

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UnitFrame_OnEvent, true)

	-- Notify the environment about the texture change.
	ns.RegisterCallback(self, "UnitFrame_Target_Updated", "PostUpdate")

end

ToTFrameMod.CreateUnitFrames = function(self)

	local unit, name = "targettarget", "ToT"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
end

ToTFrameMod.Update = function(self)
	Unitframe_PostUpdateAlpha(self.frame, "RefreshConfig", self.frame.unit)
end

ToTFrameMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(SHOW_TARGET_OF_TARGET_TEXT)

	ns.MovableModulePrototype.OnEnable(self)
end


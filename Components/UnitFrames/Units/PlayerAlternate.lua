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

--if (not ns.IsDevelopment) then return end

local PlayerFrameAltMod = ns:NewModule("PlayerFrameAlternate", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local next = next
local string_gsub = string.gsub
local type = type
local unpack = unpack
local UnitGUID = _G.UnitGUID

-- Addon API
local Colors = ns.Colors

-- Constants
local playerClass = ns.PlayerClass
local playerLevel = UnitLevel("player")

local defaults = { profile = ns:Merge({
	enabled = false,
	useClassColor = false,
	showAuras = true,
	showCastbar = true,
	showName = true,
	aurasBelowFrame = false
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
PlayerFrameAltMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "CENTER",
		[2] = 38 * ns.API.GetEffectiveScale(),
		[3] = 42 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local ApplyPlayerAlternatePowerValueAlpha = function(frame)
	if (ns.UnitFrame and ns.UnitFrame.ApplyPowerValueAlpha) then
		ns.UnitFrame.ApplyPowerValueAlpha(frame)
	end
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
local Health_PostUpdateColor = function(element, unit, colorOrR, g, b)
	local preview = element.Preview
	if (not preview) then
		return
	end

	local r = colorOrR
	if (type(colorOrR) == "table" and colorOrR.GetRGB) then
		r, g, b = colorOrR:GetRGB()
	end

	if (type(r) == "number" and type(g) == "number" and type(b) == "number") then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

local IsSafeNumericAbsorb = function(value)
	return (type(value) == "number") and (not issecretvalue or not issecretvalue(value))
end

local ResolveAbsorbPayloadFromCandidate = function(value)
	if (type(value) ~= "number") then
		return nil, false, nil
	end
	if (issecretvalue and issecretvalue(value)) then
		return value, false, nil
	end
	if (value > 0) then
		return value, false, value
	end
	if (value == 0) then
		return nil, true, nil
	end
	return nil, false, nil
end

local GetPlayerAlternateAbsorbFromPredictionValues = function(element)
	if (not element or not element.values) then
		return nil, false, nil
	end

	local values = element.values
	local maxClampMode = Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if (maxClampMode ~= nil and values.SetDamageAbsorbClampMode and not element.__AzeriteUI_PredictionValuesClampModeApplied) then
		pcall(values.SetDamageAbsorbClampMode, values, maxClampMode)
		element.__AzeriteUI_PredictionValuesClampModeApplied = true
	end

	if (values.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(values.GetPredictedValues, values)
		if (okPredicted and type(predictedValues) == "table") then
			local payload, knownZero, safeNumericAbsorb = ResolveAbsorbPayloadFromCandidate(predictedValues.totalDamageAbsorbs)
			if (payload or knownZero) then
				return payload, knownZero, safeNumericAbsorb
			end
		end
	end

	if (values.GetDamageAbsorbs) then
		local okAbsorb, valuesAbsorb = pcall(values.GetDamageAbsorbs, values)
		if (okAbsorb) then
			local payload, knownZero, safeNumericAbsorb = ResolveAbsorbPayloadFromCandidate(valuesAbsorb)
			if (payload or knownZero) then
				return payload, knownZero, safeNumericAbsorb
			end
		end
	end

	return nil, false, nil
end

local GetPlayerAlternateAbsorbFromCalculator = function(element, unit)
	if (not element or type(unit) ~= "string") then
		return nil, false, nil
	end
	if (not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction) then
		return nil, false, nil
	end

	if (not element.__AzeriteUI_AbsorbCalculator) then
		element.__AzeriteUI_AbsorbCalculator = CreateUnitHealPredictionCalculator()
	end
	local calculator = element.__AzeriteUI_AbsorbCalculator
	if (not calculator) then
		return nil, false, nil
	end

	local maxClampMode = Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if (maxClampMode ~= nil and calculator.SetDamageAbsorbClampMode and not element.__AzeriteUI_AbsorbCalculatorClampModeApplied) then
		pcall(calculator.SetDamageAbsorbClampMode, calculator, maxClampMode)
		element.__AzeriteUI_AbsorbCalculatorClampModeApplied = true
	end

	local okUpdate = pcall(UnitGetDetailedHealPrediction, unit, nil, calculator)
	if (not okUpdate) then
		okUpdate = pcall(UnitGetDetailedHealPrediction, unit, "player", calculator)
	end
	if (not okUpdate) then
		return nil, false, nil
	end

	local knownZero = false
	local safeNumericAbsorb = nil
	if (calculator.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(calculator.GetPredictedValues, calculator)
		if (okPredicted and type(predictedValues) == "table") then
			local payload, isKnownZero, safeNumeric = ResolveAbsorbPayloadFromCandidate(predictedValues.totalDamageAbsorbs)
			if (payload) then
				return payload, false, safeNumeric
			end
			if (isKnownZero) then
				knownZero = true
				safeNumericAbsorb = safeNumericAbsorb or safeNumeric
			end
		end
	end

	if (calculator.GetDamageAbsorbs) then
		local okAbsorb, calcAbsorb = pcall(calculator.GetDamageAbsorbs, calculator)
		if (okAbsorb) then
			local payload, isKnownZero, safeNumeric = ResolveAbsorbPayloadFromCandidate(calcAbsorb)
			if (payload) then
				return payload, false, safeNumeric
			end
			if (isKnownZero) then
				knownZero = true
				safeNumericAbsorb = safeNumericAbsorb or safeNumeric
			end
		end
	end

	return nil, knownZero, safeNumericAbsorb
end

local ResolvePlayerAlternateAbsorb = function(element, unit, callbackAbsorb)
	local knownZero = false
	local safeNumericAbsorb = nil
	local secretPayload = nil
	local CaptureCandidate = function(payload, isKnownZero, safeNumeric)
		if (isKnownZero) then
			knownZero = true
		end
		if (IsSafeNumericAbsorb(safeNumeric) and safeNumeric > 0 and safeNumericAbsorb == nil) then
			safeNumericAbsorb = safeNumeric
		end
		if (payload == nil) then
			return
		end
		if (IsSafeNumericAbsorb(payload)) then
			if (payload > 0 and safeNumericAbsorb == nil) then
				safeNumericAbsorb = payload
			elseif (payload == 0) then
				knownZero = true
			end
			return
		end
		if (secretPayload == nil) then
			secretPayload = payload
		end
	end

	local valuesAbsorb, valuesKnownZero, valuesSafeNumeric = GetPlayerAlternateAbsorbFromPredictionValues(element)
	CaptureCandidate(valuesAbsorb, valuesKnownZero, valuesSafeNumeric)

	local calcAbsorb, calcKnownZero, calcSafeNumeric = GetPlayerAlternateAbsorbFromCalculator(element, unit)
	CaptureCandidate(calcAbsorb, calcKnownZero, calcSafeNumeric)

	local callbackPayload, callbackKnownZero, callbackSafeNumeric = ResolveAbsorbPayloadFromCandidate(callbackAbsorb)
	CaptureCandidate(callbackPayload, callbackKnownZero, callbackSafeNumeric)

	if (UnitGetTotalAbsorbs) then
		local apiTotalAbsorb = UnitGetTotalAbsorbs(unit)
		local apiPayload, apiKnownZero, apiSafeNumeric = ResolveAbsorbPayloadFromCandidate(apiTotalAbsorb)
		CaptureCandidate(apiPayload, apiKnownZero, apiSafeNumeric)
	end

	if (IsSafeNumericAbsorb(safeNumericAbsorb) and safeNumericAbsorb > 0) then
		return safeNumericAbsorb, false, safeNumericAbsorb, false
	end
	if (knownZero) then
		return nil, true, nil, false
	end
	if (secretPayload ~= nil) then
		return secretPayload, false, nil, true
	end
	return nil, false, nil, false
end

local UpdatePlayerAlternateAbsorbState = function(element, unit, callbackAbsorb, curHealth, maxHealth)
	if (not element) then
		return
	end

	local absorbBar = element.absorbBar
	local owner = element.__owner
	local ownerHealth = owner and owner.Health
	local absorbPayload, knownZero, safeNumericAbsorb, secretOnlyPayload = ResolvePlayerAlternateAbsorb(element, unit, callbackAbsorb)

	if (ownerHealth) then
		if (IsSafeNumericAbsorb(safeNumericAbsorb) and safeNumericAbsorb > 0) then
			ownerHealth.safeAbsorb = safeNumericAbsorb
		else
			ownerHealth.safeAbsorb = nil
		end
	end

	if (not absorbBar) then
		return
	end

	local _, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if ((not IsSafeNumericAbsorb(safeMax) or safeMax <= 0) and ownerHealth) then
		if (IsSafeNumericAbsorb(ownerHealth.safeMax)) then
			safeMax = ownerHealth.safeMax
		end
	end

	if (not IsSafeNumericAbsorb(safeMax) or safeMax <= 0) then
		pcall(absorbBar.SetValue, absorbBar, 0)
		absorbBar:Hide()
		return
	end

	local visualCap = safeMax * .4
	if (visualCap <= 0) then
		pcall(absorbBar.SetValue, absorbBar, 0)
		absorbBar:Hide()
		return
	end

	pcall(absorbBar.SetMinMaxValues, absorbBar, 0, visualCap)

	if (absorbPayload ~= nil) then
		if (IsSafeNumericAbsorb(absorbPayload)) then
			local fallbackValue = absorbPayload
			if (fallbackValue > visualCap) then
				fallbackValue = visualCap
			elseif (fallbackValue < 0) then
				fallbackValue = 0
			end
			local okSet = pcall(absorbBar.SetValue, absorbBar, fallbackValue)
			if (okSet and fallbackValue > 0) then
				absorbBar:Show()
			else
				pcall(absorbBar.SetValue, absorbBar, 0)
				absorbBar:Hide()
			end
		else
			local okSet = pcall(absorbBar.SetValue, absorbBar, absorbPayload)
			if (not okSet) then
				pcall(absorbBar.SetValue, absorbBar, 0)
				absorbBar:Hide()
				return
			end
			if (secretOnlyPayload) then
				-- Secret payloads can be zero or positive; use rendered fill size as visibility signal.
				absorbBar:Show()
				local texture = absorbBar.GetStatusBarTexture and absorbBar:GetStatusBarTexture()
				local orientation = absorbBar.GetOrientation and absorbBar:GetOrientation() or "HORIZONTAL"
				local fillSize = nil
				if (texture) then
					if (orientation == "VERTICAL") then
						fillSize = texture:GetHeight()
					else
						fillSize = texture:GetWidth()
					end
				end
				local fillSizeSafe = (type(fillSize) == "number") and (not issecretvalue or not issecretvalue(fillSize))
				if ((not fillSizeSafe) or fillSize <= 0.5) then
					absorbBar:Hide()
				end
			else
				absorbBar:Hide()
			end
		end
	else
		if (knownZero) then
			pcall(absorbBar.SetValue, absorbBar, 0)
		end
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
	UpdatePlayerAlternateAbsorbState(element, unit, absorb, curHealth, maxHealth)
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0
	curHealth = tonumber(curHealth) or 0
	maxHealth = tonumber(maxHealth) or 1
	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	local safeCur, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if (not safeCur or not safeMax) then
		ns.API.HidePrediction(element)
		return
	end
	curHealth, maxHealth = safeCur, safeMax

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local showPrediction, change

	if (allIncomingHeal > 0) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Keep prediction strictly positive to avoid reverse/negative overlay jitter.
		change = allIncomingHeal/maxHealth
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

		if (growth == "RIGHT") then

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				element:SetTexCoord(curHealth/maxHealth, curHealth/maxHealth + change, 0, 1)
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:Hide()

			else
				element:Hide()
			end

		elseif (growth == "LEFT") then

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("TOPRIGHT", previewTexture, "TOPLEFT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				element:SetTexCoord(1 - (1 - (curHealth/maxHealth + change)), 1 - (1 - curHealth/maxHealth), 0, 1)
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:Hide()

			else
				element:Hide()
			end
		end
	else
		element:Hide()
	end

end

-- Use custom colors for our power crystal. Does not apply to the Wrath crystal.
local Power_PostUpdateColor = function(element, unit, r, g, b)
	local config = ns.GetConfig("PlayerFrameAlternate")

	local _, pToken = UnitPowerType(unit)
	local color = pToken and config.PowerBarColors[pToken]
	if (color) then
		element:SetStatusBarColor(color[1], color[2], color[3])
	end
end

-- Hide power crystal when no power exists.
local Power_UpdateVisibility = function(element, unit, cur, min, max)
	-- Check if values are secret before comparison
	if (issecretvalue and (issecretvalue(cur) or issecretvalue(max))) then
		-- Can't determine visibility with secret values - assume visible
		element:Show()
		element.Backdrop:Show()
		element.Value:Show()
	elseif (UnitIsDeadOrGhost(unit) or max == 0 or cur == 0) then
		element:Hide()
		element.Backdrop:Hide()
		element.Value:Hide()
	else
		element:Show()
		element.Backdrop:Show()
		element.Value:Show()
	end
end

-- Make the portrait look better for offline or invisible units.
local Portrait_PostUpdate = function(element, unit, hasStateChanged)
	if (not element.state) then
		element:ClearModel()
		if (not element.fallback2DTexture) then
			element.fallback2DTexture = element:CreateTexture()
			element.fallback2DTexture:SetDrawLayer("ARTWORK")
			element.fallback2DTexture:SetAllPoints()
			element.fallback2DTexture:SetTexCoord(.1, .9, .1, .9)
		end
		SetPortraitTexture(element.fallback2DTexture, unit)
		element.fallback2DTexture:Show()
	else
		if (element.fallback2DTexture) then
			element.fallback2DTexture:Hide()
		end
		element:SetCamDistanceScale(element.distanceScale or 1)
		element:SetPortraitZoom(1)
		element:SetPosition(element.positionX or 0, element.positionY or 0, element.positionZ or 0)
		element:SetRotation(element.rotation and math.rad(element.rotation) or 0)
		element:ClearModel()
		element:SetUnit(unit)
		element.guid = UnitGUID(unit)
	end
end

-- Toggle cast text color on protected casts.
local Cast_PostCastInterruptible = function(element, unit)
	if (element.notInterruptible) then
		element.Text:SetTextColor(unpack(element.Text.colorProtected))
	else
		element.Text:SetTextColor(unpack(element.Text.color))
	end
end

-- Toggle cast info and health info when castbar is visible.
local Cast_UpdateTexts = function(element)
	local health = element.__owner.Health
	local currentStyle = element.__owner.currentStyle

	if (currentStyle == "Critter") then
		element.Text:Hide()
		element.Time:Hide()
		health.Value:Hide()
		health.Percent:Hide()
	elseif (element:IsShown()) then
		element.Text:Show()
		element.Time:Show()
		health.Value:Hide()
		health.Percent:Hide()
	else
		element.Text:Hide()
		element.Time:Hide()
		health.Value:Show()
		health.Percent:Show()
	end
end

-- Only show Horde/Alliance badges,
local PvPIndicator_Override = function(self, event, unit)
	if (unit and unit ~= self.unit) then return end

	local element = self.PvPIndicator
	unit = unit or self.unit

	local l = UnitEffectiveLevel(unit)

	local status
	local factionGroup = UnitFactionGroup(unit) or "Neutral"
	if (factionGroup ~= "Neutral") then
		if (UnitIsPVPFreeForAll(unit)) then
		elseif (UnitIsPVP(unit)) then
			if (ns.IsRetail and UnitIsMercenary(unit)) then
				if (factionGroup == "Horde") then
					factionGroup = "Alliance"
				elseif (factionGroup == "Alliance") then
					factionGroup = "Horde"
				end
			end
			status = factionGroup
		end
	end

	if (status) then
		element:SetTexture(element[status])
		element:Show()
	else
		element:Hide()
	end
end

-- Update player frame based on player level.
local UnitFrame_UpdateTextures = function(self)
	local playerLevel = playerLevel or UnitLevel("player")
	local key = (playerXPDisabled or IsLevelAtEffectiveMaxLevel(playerLevel)) and "Seasoned" or playerLevel < 10 and "Novice" or "Hardened"
	local config = ns.GetConfig("PlayerFrameAlternate")
	local db = config[key]

	local health = self.Health
	health:ClearAllPoints()
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	health:SetStatusBarTexture(db.HealthBarTexture)
	health.colorClass = PlayerFrameAltMod.db.profile.useClassColor
	health.colorHealth = true

	health:SetOrientation(db.HealthBarOrientation)
	health:SetSparkMap(db.HealthBarSparkMap)

	local healthPreview = self.Health.Preview
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview:SetOrientation(db.HealthBarOrientation)

	local healthBackdrop = self.Health.Backdrop
	healthBackdrop:ClearAllPoints()
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))

	local healPredict = self.HealthPrediction
	healPredict:SetTexture(db.HealthBarTexture)

	local absorb = self.HealthPrediction.absorbBar
	if (absorb) then
		absorb:SetStatusBarTexture(db.HealthBarTexture)
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetOrientation(db.HealthBarOrientation)
		absorb:SetSparkMap(db.HealthBarSparkMap)
	end

	local cast = self.Castbar
	cast:ClearAllPoints()
	cast:SetPoint(unpack(db.HealthBarPosition))
	cast:SetSize(unpack(db.HealthBarSize))
	cast:SetStatusBarTexture(db.HealthBarTexture)
	cast:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	cast:SetOrientation(db.HealthBarOrientation)
	cast:SetSparkMap(db.HealthBarSparkMap)

	local threat = self.ThreatIndicator
	if (threat) then
		for key,texture in next,threat.textures do
			texture:ClearAllPoints()
			texture:SetPoint(unpack(db[key.."ThreatPosition"]))
			texture:SetSize(unpack(db[key.."ThreatSize"]))
			texture:SetTexture(db[key.."ThreatTexture"])
		end
	end

	local portraitBorder = self.Portrait.Border
	portraitBorder:SetTexture(db.PortraitBorderTexture)
	portraitBorder:SetVertexColor(unpack(db.PortraitBorderColor))

	ns:Fire("UnitFrame_Target_Updated", unit, key)
end

local UnitFrame_UpdateAuraPosition = function(self)
	local config = PlayerFrameAltMod.db.profile
	local db = ns.GetConfig("PlayerFrameAlternate")

	local auras = self.Auras
	auras:ClearAllPoints()

	if (config.aurasBelowFrame) then
		auras:SetSize(unpack(db.AurasSize))
		auras:SetPoint(unpack(db.AurasPosition))
		auras.size = db.AuraSize
		auras.spacing = db.AuraSpacing
		auras.numTotal = db.AurasNumTotal
		auras.disableMouse = db.AurasDisableMouse
		auras.disableCooldown = db.AurasDisableCooldown
		auras.onlyShowPlayer = db.AurasOnlyShowPlayer
		auras.showStealableBuffs = db.AurasShowStealableBuffs
		auras.initialAnchor = db.AurasInitialAnchor
		auras["spacing-x"] = db.AurasSpacingX
		auras["spacing-y"] = db.AurasSpacingY
		auras["growth-x"] = db.AurasGrowthX
		auras["growth-y"] = db.AurasGrowthY
		auras.tooltipAnchor = db.AurasTooltipAnchor
		auras.sortMethod = db.AurasSortMethod
		auras.sortDirection = db.AurasSortDirection

	else
		auras:SetSize(unpack(db.AurasSizeAlternate))
		auras:SetPoint(unpack(db.AurasPositionAlternate))
		auras.size = db.AuraSizeAlternate
		auras.spacing = db.AuraSpacingAlternate
		auras.numTotal = db.AurasNumTotalAlternate
		auras.disableMouse = db.AurasDisableMouseAlternate
		auras.disableCooldown = db.AurasDisableCooldownAlternate
		auras.onlyShowPlayer = db.AurasOnlyShowPlayerAlternate
		auras.showStealableBuffs = db.AurasShowStealableBuffsAlternate
		auras.initialAnchor = db.AurasInitialAnchorAlternate
		auras["spacing-x"] = db.AurasSpacingXAlternate
		auras["spacing-y"] = db.AurasSpacingYAlternate
		auras["growth-x"] = db.AurasGrowthXAlternate
		auras["growth-y"] = db.AurasGrowthYAlternate
		auras.tooltipAnchor = db.AurasTooltipAnchorAlternate
		auras.sortMethod = db.AurasSortMethodAlternate
		auras.sortDirection = db.AurasSortDirectionAlternate

	end

end

local UnitFrame_PostUpdate = function(self)
	UnitFrame_UpdateTextures(self)
	UnitFrame_UpdateAuraPosition(self)
end

-- Frame Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		playerLevel = UnitLevel("player")

	elseif (event == "UNIT_ABSORB_AMOUNT_CHANGED") then
		if (unit == self.unit) then
			local eventAbsorb = select(1, ...)
			if (self.HealthPrediction) then
				UpdatePlayerAlternateAbsorbState(self.HealthPrediction, unit, eventAbsorb, self.Health and self.Health.safeCur or nil, self.Health and self.Health.safeMax or nil)
			end
			if (self.Health and self.Health.ForceUpdate) then
				self.Health:ForceUpdate()
			end
			if (self.Health and self.Health.Value and self.Health.Value.UpdateTag) then
				self.Health.Value:UpdateTag()
			end
		end

	elseif (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED") then
		self.Auras:ForceUpdate()

	elseif (event == "PLAYER_LEVEL_UP") then
		playerLevel = UnitLevel("player")
	end
	UnitFrame_PostUpdate(self)
end

local style = function(self, unit, id)

	local db = ns.GetConfig("PlayerFrameAlternate")

	self:SetSize(unpack(db.Size))
	self:SetHitRectInsets(unpack(db.HitRectInsets))
	self:SetFrameLevel(self:GetFrameLevel() + 2)

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
	health.colorClass = PlayerFrameAltMod.db.profile.useClassColor
	health.colorHealth = true
	health.predictThreshold = .01

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor
	ns.API.BindStatusBarValueMirror(self.Health)

	local healthBackdrop = self:CreateTexture(nil, "BACKGROUND", nil, -1)

	self.Health.Backdrop = healthBackdrop

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel())
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	local healthPreview = self:CreateBar(nil, health)
	if (healthPreview.SetForceNative) then healthPreview:SetForceNative(true) end
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:DisableSmoothing(true)
	healthPreview:SetSparkTexture("")
	healthPreview:SetAlpha(0)

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict.health = health
	healPredict.preview = healthPreview
	healPredict.maxOverflow = 1

	self.HealthPrediction = healPredict
	if (Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth) then
		self.HealthPrediction.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
	end
	self.HealthPrediction.PostUpdate = HealPredict_PostUpdate

	-- Cast Overlay
	--------------------------------------------
	local castbar = self:CreateBar()
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:DisableSmoothing(true)

	self.Castbar = castbar

	-- Cast Name
	--------------------------------------------
	local castText = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	castText:SetPoint(unpack(db.HealthValuePosition))
	castText:SetFontObject(db.HealthValueFont)
	castText:SetTextColor(unpack(db.CastBarTextColor))
	castText:SetJustifyH(db.HealthValueJustifyH)
	castText:SetJustifyV(db.HealthValueJustifyV)
	castText:Hide()
	castText.color = db.CastBarTextColor
	castText.colorProtected = db.CastBarTextProtectedColor

	self.Castbar.Text = castText
	self.Castbar.PostCastInterruptible = Cast_PostCastInterruptible

	-- Cast Time
	--------------------------------------------
	local castTime = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	castTime:SetPoint(unpack(db.CastBarValuePosition))
	castTime:SetFontObject(db.CastBarValueFont)
	castTime:SetTextColor(unpack(db.CastBarTextColor))
	castTime:SetJustifyH(db.CastBarValueJustifyH)
	castTime:SetJustifyV(db.CastBarValueJustifyV)
	castTime:Hide()

	self.Castbar.Time = castTime

	self.Castbar:HookScript("OnShow", Cast_UpdateTexts)
	self.Castbar:HookScript("OnHide", Cast_UpdateTexts)

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	if (ns.IsRetail) then
		-- Keep stock-like inline composition; absorb tag handles wrapped visuals.
		self:Tag(healthValue, prefix("[*:HealthCurrent]  [*:Absorb]"))
	else
		self:Tag(healthValue, prefix("[*:Health]"))
	end

	self.Health.Value = healthValue

	-- Health Percentage
	--------------------------------------------
	local healthPerc = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthPerc:SetPoint(unpack(db.HealthPercentagePosition))
	healthPerc:SetFontObject(db.HealthPercentageFont)
	healthPerc:SetTextColor(unpack(db.HealthPercentageColor))
	healthPerc:SetJustifyH(db.HealthPercentageJustifyH)
	healthPerc:SetJustifyV(db.HealthPercentageJustifyV)
	self:Tag(healthPerc, prefix("[*:HealthPercent]"))
	healthPerc:Hide()  -- Hidden by default

	self.Health.Percent = healthPerc

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)

		self.HealthPrediction.absorbBar = absorb
	end

	-- Portrait
	--------------------------------------------
	local portraitFrame = CreateFrame("Frame", nil, self)
	portraitFrame:SetFrameLevel(self:GetFrameLevel() - 2)
	portraitFrame:SetAllPoints()

	local portrait = CreateFrame("PlayerModel", nil, portraitFrame)
	portrait:SetFrameLevel(portraitFrame:GetFrameLevel())
	portrait:SetPoint(unpack(db.PortraitPosition))
	portrait:SetSize(unpack(db.PortraitSize))
	portrait:SetAlpha(db.PortraitAlpha)
	portrait.distanceScale = db.PortraitDistanceScale
	portrait.positionX = db.PortraitPositionX
	portrait.positionY = db.PortraitPositionY
	portrait.positionZ = db.PortraitPositionZ
	portrait.rotation = db.PortraitRotation
	portrait.showFallback2D = db.PortraitShowFallback2D

	self.Portrait = portrait
	self.Portrait.PostUpdate = Portrait_PostUpdate

	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBg:SetPoint(unpack(db.PortraitBackgroundPosition))
	portraitBg:SetSize(unpack(db.PortraitBackgroundSize))
	portraitBg:SetTexture(db.PortraitBackgroundTexture)
	portraitBg:SetVertexColor(unpack(db.PortraitBackgroundColor))

	self.Portrait.Bg = portraitBg

	local portraitOverlayFrame = CreateFrame("Frame", nil, self)
	portraitOverlayFrame:SetFrameLevel(self:GetFrameLevel() - 1)
	portraitOverlayFrame:SetAllPoints()

	local portraitShade = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
	portraitShade:SetPoint(unpack(db.PortraitShadePosition))
	portraitShade:SetSize(unpack(db.PortraitShadeSize))
	portraitShade:SetTexture(db.PortraitShadeTexture)

	self.Portrait.Shade = portraitShade

	local portraitBorder = portraitOverlayFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	portraitBorder:SetPoint(unpack(db.PortraitBorderPosition))
	portraitBorder:SetSize(unpack(db.PortraitBorderSize))

	self.Portrait.Border = portraitBorder

	-- Power Crystal
	--------------------------------------------
	local power = self:CreateBar()
	power:SetFrameLevel(self:GetFrameLevel() + 5)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetSparkTexture(db.PowerBarSparkTexture)
	power:SetOrientation(db.PowerBarOrientation)
	power:SetStatusBarTexture(db.PowerBarTexture)
	power:SetAlpha(db.PowerBarAlpha or 1)
	power.frequentUpdates = true
	power.displayAltPower = true
	--power.colorPower = true

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	ns.API.BindStatusBarValueMirror(self.Power)
	self.Power.PostUpdate = Power_UpdateVisibility
	self.Power.PostUpdateColor = Power_PostUpdateColor

	local powerBackdropGroup = CreateFrame("Frame", nil, self)
	powerBackdropGroup:SetAllPoints(power)
	powerBackdropGroup:SetFrameLevel(power:GetFrameLevel())

	local powerBackdrop = powerBackdropGroup:CreateTexture(nil, "BACKGROUND", nil, -2)
	powerBackdrop:SetPoint(unpack(db.PowerBackdropPosition))
	powerBackdrop:SetSize(unpack(db.PowerBackdropSize))
	powerBackdrop:SetTexture(db.PowerBackdropTexture)
	powerBackdrop:SetVertexColor(unpack(db.PowerBackdropColor))

	self.Power.Backdrop = powerBackdrop

	-- Power Value Text
	--------------------------------------------
	local powerOverlayGroup = CreateFrame("Frame", nil, self)
	powerOverlayGroup:SetAllPoints(power)
	powerOverlayGroup:SetFrameLevel(power:GetFrameLevel() + 1)

	local powerValue = powerOverlayGroup:CreateFontString(nil, "OVERLAY", nil, 1)
	powerValue:SetPoint(unpack(db.PowerValuePosition))
	powerValue:SetJustifyH(db.PowerValueJustifyH)
	powerValue:SetJustifyV(db.PowerValueJustifyV)
	powerValue:SetFontObject(db.PowerValueFont)
	powerValue:SetTextColor(unpack(db.PowerValueColor))
	self:Tag(powerValue, prefix("[*:Power]"))

	self.Power.Value = powerValue

	-- Power Percentage
	--------------------------------------------
	local powerPerc = powerOverlayGroup:CreateFontString(nil, "OVERLAY", nil, 1)
	if (db.PowerPercentagePosition) then
		powerPerc:SetPoint(unpack(db.PowerPercentagePosition))
	else
		powerPerc:SetPoint("TOP", powerValue, "BOTTOM", 0, -2)
	end
	powerPerc:SetFontObject(db.PowerPercentageFont or db.PowerValueFont)
	local powerPercColor = db.PowerPercentageColor or db.PowerValueColor or { 1, 1, 1, 1 }
	powerPerc:SetTextColor(powerPercColor[1], powerPercColor[2], powerPercColor[3], powerPercColor[4] or 1)
	powerPerc:SetJustifyH(db.PowerPercentageJustifyH or "CENTER")
	powerPerc:SetJustifyV(db.PowerPercentageJustifyV or "TOP")
	self:Tag(powerPerc, prefix("[*:PowerPercent]"))

	self.Power.Percent = powerPerc
	ApplyPlayerAlternatePowerValueAlpha(self)

	-- CombatFeedback Text
	--------------------------------------------
	local feedbackText = overlay:CreateFontString(nil, "OVERLAY")
	feedbackText:SetPoint(db.CombatFeedbackPosition[1], self[db.CombatFeedbackAnchorElement], unpack(db.CombatFeedbackPosition))
	feedbackText:SetFontObject(db.CombatFeedbackFont)
	feedbackText.feedbackFont = db.CombatFeedbackFont
	feedbackText.feedbackFontLarge = db.CombatFeedbackFontLarge
	feedbackText.feedbackFontSmall = db.CombatFeedbackFontSmall

	self.CombatFeedback = feedbackText

	-- PvP Indicator
	--------------------------------------------
	local PvPIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, -2)
	PvPIndicator:SetSize(unpack(db.PvPIndicatorSize))
	PvPIndicator:SetPoint(unpack(db.PvPIndicatorPosition))
	PvPIndicator.Alliance = db.PvPIndicatorAllianceTexture
	PvPIndicator.Horde = db.PvPIndicatorHordeTexture

	self.PvPIndicator = PvPIndicator
	self.PvPIndicator.Override = PvPIndicator_Override

	-- Threat Indicator
	--------------------------------------------
	local threatIndicator = CreateFrame("Frame", nil, self)
	threatIndicator:SetFrameLevel(self:GetFrameLevel() - 2)
	threatIndicator:SetAllPoints()
	threatIndicator.feedbackUnit = "player"

	threatIndicator.textures = {
		Health = threatIndicator:CreateTexture(nil, "BACKGROUND", nil, -3),
		Portrait = portrait:CreateTexture(nil, "BACKGROUND", nil, -1)
	}
	threatIndicator.Show = function(self)
		self.isShown = true
		for key,texture in next,self.textures do
			texture:Show()
		end
	end
	threatIndicator.Hide = function(self)
		self.isShown = nil
		for key,texture in next,self.textures do
			texture:Hide()
		end
	end
	threatIndicator.PostUpdate = function(self, unit, status, r, g, b)
		if (self.isShown) then
			local safeR = (type(r) == "number" and (not issecretvalue or not issecretvalue(r))) and r or 1
			local safeG = (type(g) == "number" and (not issecretvalue or not issecretvalue(g))) and g or 0
			local safeB = (type(b) == "number" and (not issecretvalue or not issecretvalue(b))) and b or 0
			for key,texture in next,self.textures do
				texture:SetVertexColor(safeR, safeG, safeB)
			end
		end
	end

	self.ThreatIndicator = threatIndicator

	-- Unit Name
	--------------------------------------------
	local name = self:CreateFontString(nil, "OVERLAY", nil, 1)
	name:SetPoint(unpack(db.NamePosition))
	name:SetFontObject(db.NameFont)
	name:SetTextColor(unpack(db.NameColor))
	name:SetJustifyH(db.NameJustifyH)
	name:SetJustifyV(db.NameJustifyV)
	name.tag = prefix("[*:Name(64,true,nil,true)]")
	self:Tag(name, name.tag)

	self.Name = name

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras.reanchorIfVisibleChanged = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.PlayerPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.PlayerAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.PlayerAuraFilter -- retail
	auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
	auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Auras = auras

	-- Seasonal Flavors
	--------------------------------------------
	-- Love is in the Air
	if (ns.API.IsLoveFestival()) then


	end

	-- Register events to handle texture updates.
	self:RegisterEvent("PLAYER_ALIVE", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("DISABLE_XP_GAIN", UnitFrame_OnEvent, true)
	self:RegisterEvent("ENABLE_XP_GAIN", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_LEVEL_UP", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_XP_UPDATE", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", UnitFrame_OnEvent, true)

	if (ns.IsRetail) then
		--self:RegisterEvent("UNIT_HEALTH", UnitFrame_OnEvent)
		--self:RegisterEvent("UNIT_MAXHEALTH", UnitFrame_OnEvent)
		--self:RegisterEvent("UNIT_HEAL_PREDICTION", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", UnitFrame_OnEvent)
		--self:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UnitFrame_OnEvent)

		if (playerClass == "PALADIN") then
			self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", UnitFrame_OnEvent)
		end
	end

	-- Fix unresponsive alpha on 3D Portrait.
	hooksecurefunc(UIParent, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)

	-- this won't work with the explorer mode, need a different solution
	--hooksecurefunc(self, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)


	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

end

PlayerFrameAltMod.CreateUnitFrames = function(self)

	local unit, name = "player", "PlayerAlternate"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)

	local enabled = true

	self.frame.Enable = function(self)
		enabled = true
		RegisterAttributeDriver(self, "unit", "[vehicleui]vehicle; player")
		self:Show()
	end

	self.frame.Disable = function(self)
		enabled = false
		UnregisterAttributeDriver(self, "unit")
		self:Hide()
	end

	self.frame.IsEnabled = function(self)
		return enabled
	end

	UnregisterUnitWatch(self.frame)
	self.frame:SetAttribute("toggleForVehicle", false)
end

PlayerFrameAltMod.Update = function(self)

	self.frame.Health.colorClass = self.db.profile.useClassColor
	self.frame.Health.colorHealth = true
	self.frame.Health:ForceUpdate()

	if (self.db.profile.showAuras) then
		self.frame:EnableElement("Auras")
		self.frame.Auras:ForceUpdate()
	else
		self.frame:DisableElement("Auras")
	end

	if (self.db.profile.showCastbar) then
		self.frame:EnableElement("Castbar")
		self.frame.Castbar:ForceUpdate()
	else
		self.frame:DisableElement("Castbar")
	end

	self.frame.Name:SetShown(self.db.profile.showName)
	ApplyPlayerAlternatePowerValueAlpha(self.frame)
	self.frame:PostUpdate()
end

PlayerFrameAltMod.PreInitialize = function(self)
	if (not ns.db.global.enableDevelopmentMode) then
		return self:Disable()
	end
end

PlayerFrameAltMod.PostInitialize = function(self)

	-- Forcedisable this unitframe
	-- if the standard playerframe is enabled.
	local PlayerFrame = ns:GetModule("PlayerFrame", true)
	if (PlayerFrame and PlayerFrame.db and PlayerFrame.db.profile.enabled) then
		self.db.profile.enabled = false
	end
end

PlayerFrameAltMod.OnEnable = function(self)

	-- Disable Blizzard player alternate power bar only on WoW10; in WoW11 allow it.
	if (ns.WoW10 and PlayerPowerBarAlt) then
		PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
		PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_HIDE")
		PlayerPowerBarAlt:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end

	self:CreateUnitFrames()
	self:CreateAnchor("PlayerFrame (Alternate)")

	ns.MovableModulePrototype.OnEnable(self)
end


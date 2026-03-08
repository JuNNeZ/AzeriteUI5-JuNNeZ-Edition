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
local PlayerPowerBarAlt = _G and _G.PlayerPowerBarAlt or PlayerPowerBarAlt
local oUF = ns.oUF

local PlayerFrameMod = ns:NewModule("PlayerFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local AbbreviateNumbers = AbbreviateNumbers
local BreakUpLargeNumbers = BreakUpLargeNumbers
local math_floor = math.floor
local math_max = math.max
local next = next
local string_gsub = string.gsub
local tonumber = tonumber
local type = type
local unpack = unpack

-- GLOBALS: Enum, PlayerPowerBarAlt
-- GLOBALS: CreateFrame, GetSpecialization, IsXPUserDisabled, IsLevelAtEffectiveMaxLevel
-- GLOBALS: UnitFactionGroup, UnitLevel, UnitPowerType, UnitHasVehicleUI, UnitIsMercenary, UnitIsPVP, UnitIsPVPFreeForAll

-- Addon API
local Colors = ns.Colors

-- Constants
local playerClass = ns.PlayerClass
local playerLevel = UnitLevel("player")
local playerXPDisabled = IsXPUserDisabled()
local SPEC_PALADIN_RETRIBUTION = SPEC_PALADIN_RETRIBUTION or 3
local SPEC_SHAMAN_ELEMENTAL = _G.SPEC_SHAMAN_ELEMENTAL or 1
local POWER_TYPE_MANA = (ns.IsRetail and Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local playerIsRetribution = playerClass == "PALADIN" and (ns.IsRetail and GetSpecialization() == SPEC_PALADIN_RETRIBUTION)
local ORB_DYNAMIC_CLASS_ALLOW = {
	DRUID = true,
	EVOKER = true,
	MAGE = true,
	MONK = true,
	PALADIN = true,
	PRIEST = true,
	SHAMAN = true,
	WARLOCK = true
}
local HidePlayerNativePowerVisuals
local ShowPlayerNativePowerVisuals
local UpdatePlayerFakePowerFill
local UpdatePlayerPowerSpark
local ShouldShowPlayerPowerValue

local POWER_CRYSTAL_BASELINE_OFFSET_X = -37
local POWER_CRYSTAL_BASELINE_OFFSET_Y = -28

local defaults = { profile = ns:Merge({
	useClassColor = false,
	showAuras = true,
	showCastbar = true,
	showPowerValue = true,
	powerValueCombatDriven = false,
	PowerValueFormat = "short",
	powerValueTextScale = 100,
	powerOrbMode = "orbV2",
	crystalOrbColorMode = "default",
	aurasBelowFrame = false,
	useWrathCrystal = ns.IsCata,
	powerBarScale = 1,
	powerBarScaleX = 1,
	powerBarScaleY = 1,
	powerBackdropScaleX = 1,
	powerBackdropScaleY = 1,
	powerCaseScaleX = 1,
	powerCaseScaleY = 1,
	powerThreatBarScaleX = 1,
	powerThreatBarScaleY = 1,
	powerThreatCaseScaleX = 1,
	powerThreatCaseScaleY = 1,
	powerBarArtLayer = 0,
	powerBarOffsetX = 0,
	powerBarOffsetY = 0,
	powerCaseOffsetX = 0,
	powerCaseOffsetY = 0,
	powerThreatBarOffsetX = 0,
	powerThreatBarOffsetY = 0,
	powerThreatCaseOffsetX = 0,
	powerThreatCaseOffsetY = 0,
	powerBarAnchorFrame = "FRAME",
	powerCaseAnchorFrame = "POWER",
	powerThreatBarAnchorFrame = "POWER",
	powerThreatCaseAnchorFrame = "POWER",
	powerBarBaseScaleX = 1,
	powerBarBaseScaleY = 1,
	powerBarBaseOffsetX = POWER_CRYSTAL_BASELINE_OFFSET_X,
	powerBarBaseOffsetY = POWER_CRYSTAL_BASELINE_OFFSET_Y,
	powerCaseBaseOffsetX = 0,
	powerCaseBaseOffsetY = 0,
	powerOffsetZeroMigrated = true,
	powerCrystalBaselineApplied = true
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
PlayerFrameMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOMLEFT",
		[2] = 46 * ns.API.GetEffectiveScale(),
		[3] = 100 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local STOCK_POWER_CRYSTAL_LAYOUT = {
	frameLevelOffset = -2,
	barPointKey = "PowerBarPosition",
	barSizeKey = "PowerBarSize",
	barTexCoordKey = "PowerBarTexCoord",
	barOrientationKey = "PowerBarOrientation",
	backdropSizeKey = "PowerBackdropSize"
}

local CURRENT_POWER_CRYSTAL_LAYOUT = {
	frameLevelOffset = -2,
	barPointKey = "PowerBarPosition",
	barSizeKey = "PowerBackdropSize",
	barTexCoordKey = "PowerBarTexCoord",
	barOrientationKey = "PowerBarOrientation",
	backdropPoint = { "CENTER", 0, 0 },
	backdropSizeKey = "PowerBackdropSize"
}

local ShouldDebugAbsorbUnit = function(unit)
	if (not ns.API or not ns.API.DEBUG_HEALTH_CHAT) then
		return false
	end
	if (type(unit) ~= "string" or unit == "") then
		return false
	end
	if (unit ~= "player" and unit ~= "target") then
		return false
	end
	local filter = ns.API.DEBUG_HEALTH_FILTER
	if (type(filter) ~= "string" or filter == "") then
		return true
	end
	filter = filter:lower()
	if (unit:lower():find(filter, 1, true) ~= nil) then
		return true
	end
	local compact = filter:gsub("[^%a%d_]", "")
	if (compact ~= "" and unit:lower():find(compact, 1, true) ~= nil) then
		return true
	end
	return false
end

local EmitAbsorbStateDebug = function(owner, unit, fmt, ...)
	if (not owner or not ShouldDebugAbsorbUnit(unit)) then
		return
	end
	local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
	local key = "__AzeriteUI_LastAbsorbStateDebug"
	local last = owner[key] or 0
	if ((now - last) < 0.2) then
		return
	end
	owner[key] = now
	ns.API.DebugPrintf("Absorb", 4, fmt, ...)
end

-- Element Callbacks
--------------------------------------------
local ClampSparkPercent = function(value)
	if (type(value) ~= "number") or (issecretvalue and issecretvalue(value)) then
		return nil
	end
	if (value > 1 and value <= 100) then
		value = value / 100
	end
	if (value < 0) then
		value = 0
	elseif (value > 1) then
		value = 1
	end
	return value
end

local GetBarSparkPercent = function(element)
	if (not element) then
		return nil
	end
	local percent = ClampSparkPercent(element.safePercent)
	if (percent ~= nil) then
		return percent
	end
	if (element.GetSecretPercent) then
		local ok, value = pcall(element.GetSecretPercent, element)
		if (ok) then
			percent = ClampSparkPercent(value)
			if (percent ~= nil) then
				return percent
			end
		end
	end
	return ClampSparkPercent(element.__AzeriteUI_MirrorPercent) or ClampSparkPercent(element.__AzeriteUI_TexturePercent)
end

local UpdateBarSparkSize = function(element)
	local spark = element and element.Spark
	if (not spark) then
		return
	end
	local growth = (element.GetGrowth and element:GetGrowth()) or element.__AzeriteUI_Growth or "RIGHT"
	local width = element.GetWidth and element:GetWidth() or 0
	local height = element.GetHeight and element:GetHeight() or 0
	if (type(width) ~= "number" or type(height) ~= "number"
		or width <= 0 or height <= 0
		or (issecretvalue and (issecretvalue(width) or issecretvalue(height)))) then
		spark:Hide()
		return
	end
	if (growth == "UP" or growth == "DOWN") then
		spark:SetSize(math_max(8, width - 4), 12)
	else
		spark:SetSize(12, math_max(8, height - 2))
	end
end

local UpdateBarSpark = function(element, percentOverride)
	local spark = element and element.Spark
	if (not spark) then
		return
	end
	local percent = ClampSparkPercent(percentOverride)
	if (percent == nil) then
		percent = GetBarSparkPercent(element)
	end
	if (type(percent) ~= "number" or percent <= 0 or percent >= 1 or not element:IsShown()) then
		spark:Hide()
		return
	end
	local growth = (element.GetGrowth and element:GetGrowth()) or element.__AzeriteUI_Growth or "RIGHT"
	local reverseFill = element.GetReverseFill and element:GetReverseFill()
	if (reverseFill) then
		if (growth == "RIGHT") then
			growth = "LEFT"
		elseif (growth == "LEFT") then
			growth = "RIGHT"
		elseif (growth == "UP") then
			growth = "DOWN"
		elseif (growth == "DOWN") then
			growth = "UP"
		end
	end
	local width = element:GetWidth()
	local height = element:GetHeight()
	if (type(width) ~= "number" or type(height) ~= "number"
		or width <= 0 or height <= 0
		or (issecretvalue and (issecretvalue(width) or issecretvalue(height)))) then
		spark:Hide()
		return
	end
	spark:ClearAllPoints()
	if (growth == "UP" or growth == "DOWN") then
		local y = height * ((growth == "DOWN") and (1 - percent) or percent)
		spark:SetPoint("CENTER", element, "BOTTOM", 0, y)
	else
		local x = width * ((growth == "LEFT") and (1 - percent) or percent)
		spark:SetPoint("CENTER", element, "LEFT", x, 0)
	end
	spark:Show()
end

-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
	UpdateBarSpark(element)
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
		preview:SetStatusBarColor(r * .9, g * .9, b * .9)
	end
	UpdateBarSpark(element)
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local GetSafeDamageAbsorbFromCalculator = function(element, unit)
	if (not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction) then
		return nil
	end
	local maxClampMode = Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if (not element.__AzeriteUI_AbsorbCalculator) then
		element.__AzeriteUI_AbsorbCalculator = CreateUnitHealPredictionCalculator()
	end
	local calculator = element.__AzeriteUI_AbsorbCalculator
	if (not calculator) then
		return nil
	end
	if (maxClampMode ~= nil and calculator.SetDamageAbsorbClampMode and not element.__AzeriteUI_AbsorbCalculatorClampModeApplied) then
		pcall(calculator.SetDamageAbsorbClampMode, calculator, maxClampMode)
		element.__AzeriteUI_AbsorbCalculatorClampModeApplied = true
	end
	local okUpdate = pcall(UnitGetDetailedHealPrediction, unit, nil, calculator)
	if (not okUpdate) then
		okUpdate = pcall(UnitGetDetailedHealPrediction, unit, "player", calculator)
	end
	if (not okUpdate) then
		return nil
	end
	if (calculator.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(calculator.GetPredictedValues, calculator)
		if (okPredicted and type(predictedValues) == "table") then
			local totalDamageAbsorbs = predictedValues.totalDamageAbsorbs
			if (type(totalDamageAbsorbs) == "number" and (not issecretvalue or not issecretvalue(totalDamageAbsorbs))) then
				return totalDamageAbsorbs
			end
		end
	end
	if (not calculator.GetDamageAbsorbs) then
		return nil
	end
	local okAbsorb, absorb = pcall(calculator.GetDamageAbsorbs, calculator)
	if (not okAbsorb or type(absorb) ~= "number" or (issecretvalue and issecretvalue(absorb))) then
		return nil
	end
	return absorb
end

local GetAbsorbFromPredictionValues = function(element)
	if (not element or not element.values) then
		return nil
	end
	local maxClampMode = Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if (maxClampMode ~= nil and element.values.SetDamageAbsorbClampMode and not element.__AzeriteUI_PredictionValuesClampModeApplied) then
		pcall(element.values.SetDamageAbsorbClampMode, element.values, maxClampMode)
		element.__AzeriteUI_PredictionValuesClampModeApplied = true
	end
	if (element.values.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(element.values.GetPredictedValues, element.values)
		if (okPredicted and type(predictedValues) == "table") then
			local totalDamageAbsorbs = predictedValues.totalDamageAbsorbs
			if (type(totalDamageAbsorbs) == "number" and (not issecretvalue or not issecretvalue(totalDamageAbsorbs))) then
				return totalDamageAbsorbs
			end
		end
	end
	if (not element.values.GetDamageAbsorbs) then
		return nil
	end
	local okAbsorb, absorb = pcall(element.values.GetDamageAbsorbs, element.values)
	if (not okAbsorb or type(absorb) ~= "number" or (issecretvalue and issecretvalue(absorb))) then
		return nil
	end
	return absorb
end

local HidePlayerAbsorbBarVisual = function(absorbBar)
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

local GetSafeStatusBarValue = function(bar)
	if (not bar) then
		return nil, false
	end
	local value
	if (bar.GetValue) then
		pcall(function()
			value = bar:GetValue()
		end)
	end
	if (type(value) ~= "number" or (issecretvalue and issecretvalue(value))) then
		value = bar.safeCur or bar.cur or bar.safeBarValue
	end
	if (type(value) ~= "number" or (issecretvalue and issecretvalue(value))) then
		return nil, false
	end
	return value, true
end

local UpdatePlayerAbsorbState = function(element, unit, absorb, maxHealth)
	if (not element) then
		return
	end
	if (element.absorbBar) then
		HidePlayerAbsorbBarVisual(element.absorbBar)
	end
	local SetOwnerSafeAbsorb = function(value)
		local ownerHealth = element.__owner and element.__owner.Health
		if (ownerHealth) then
			ownerHealth.safeAbsorb = value
			ownerHealth.safeAbsorbKnownZero = false
		end
	end
	local SetOwnerSafeAbsorbKnownZero = function()
		local ownerHealth = element.__owner and element.__owner.Health
		if (ownerHealth) then
			ownerHealth.safeAbsorb = nil
			ownerHealth.safeAbsorbKnownZero = true
		end
	end
	local resolvedAbsorb = nil
	local hasKnownZero = false
	local barAbsorb = nil
	local hasBarAbsorb = false
	local apiTotalAbsorb = nil
	local calcAbsorb = nil
	if (element.absorbBar) then
		barAbsorb, hasBarAbsorb = GetSafeStatusBarValue(element.absorbBar)
		if (hasBarAbsorb) then
			if (barAbsorb > 0) then
				resolvedAbsorb = barAbsorb
			else
				-- Hidden absorb visuals are forced to zero; don't let that block
				-- calculator/API fallbacks used for tag display.
				hasBarAbsorb = false
				hasKnownZero = true
			end
		end
	end
	if (not hasBarAbsorb) then
		calcAbsorb = GetAbsorbFromPredictionValues(element)
		if (calcAbsorb == nil) then
			calcAbsorb = GetSafeDamageAbsorbFromCalculator(element, unit)
		end
		if (type(calcAbsorb) == "number" and (not issecretvalue or not issecretvalue(calcAbsorb))) then
			if (calcAbsorb > 0) then
				resolvedAbsorb = calcAbsorb
			else
				hasKnownZero = true
			end
		elseif (absorb ~= nil) then
			if (type(absorb) == "number" and (not issecretvalue or not issecretvalue(absorb))) then
				if (absorb > 0) then
					resolvedAbsorb = absorb
				else
					hasKnownZero = true
				end
			end
		end
		if (resolvedAbsorb == nil and UnitGetTotalAbsorbs) then
			apiTotalAbsorb = UnitGetTotalAbsorbs(unit)
			if (type(apiTotalAbsorb) == "number" and (not issecretvalue or not issecretvalue(apiTotalAbsorb))) then
				if (apiTotalAbsorb > 0) then
					resolvedAbsorb = apiTotalAbsorb
				else
					hasKnownZero = true
				end
			end
		end
	end
	if (type(resolvedAbsorb) == "number" and (not issecretvalue or not issecretvalue(resolvedAbsorb))) then
		if (resolvedAbsorb > 0) then
			SetOwnerSafeAbsorb(resolvedAbsorb)
		else
			SetOwnerSafeAbsorb(nil)
		end
	elseif (hasKnownZero) then
		SetOwnerSafeAbsorbKnownZero()
	else
		-- No reliable source for this update, clear to avoid stale values.
		SetOwnerSafeAbsorb(nil)
	end
	local owner = element.__owner
	local ownerHealth = owner and owner.Health
	EmitAbsorbStateDebug(owner, unit,
		"State(Player) unit=%s bar=%s barSample=%s calc=%s callback=%s apiTotal=%s resolved=%s knownZero=%s finalSafe=%s",
		unit,
		barAbsorb,
		hasBarAbsorb and true or false,
		calcAbsorb,
		absorb,
		apiTotalAbsorb,
		resolvedAbsorb,
		hasKnownZero and true or false,
		ownerHealth and ownerHealth.safeAbsorb or nil)
end

local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	UpdatePlayerAbsorbState(element, unit, absorb, maxHealth)
	if (_G and _G.__AzeriteUI_DISABLE_HEALTH_PREDICTION) then
		ns.API.HidePrediction(element)
		return
	end
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

	if (ns.API.DEBUG_HEALTH_CHAT) then
		local owner = element and element.__owner
		local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
		local last = owner and owner.__AzeriteUI_LastPredictionDebug or 0
		if ((now - last) > 0.2) then
			if (owner) then
				owner.__AzeriteUI_LastPredictionDebug = now
			end
			ns.API.DebugPrintf("Health", 3, "Predict(Player) unit=%s show=%s change=%s cur=%s max=%s incoming=%s absorb=%s",
				tostring(unit),
				tostring(showPrediction and true or false),
				tostring(change),
				tostring(curHealth),
				tostring(maxHealth),
				tostring(allIncomingHeal),
				tostring(healAbsorb))
		end
	end

end

-- Show mana orb when mana is the primary resource, or when always show mana orb is enabled.
local GetPlayerPowerOrbMode = function()
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	if (not profile) then
		return "orbV2"
	end
	local mode = profile.powerOrbMode
	if (mode == "legacyCrystal" or mode == "orbV2" or mode == "orbV2Always") then
		return mode
	end
	if (profile.alwaysUseCrystal) then
		return "legacyCrystal"
	end
	if (profile.alwaysShowManaOrb) then
		return "orbV2Always"
	end
	return "orbV2"
end

local ResolvePlayerPowerWidgetVisibility = function(frame, unit)
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	if (not profile) then
		return true, false
	end
	local hasPlayerUnit = UnitExists("player") and not UnitHasVehicleUI("player")
	local mode = GetPlayerPowerOrbMode()
	local wantsOrb = false
	local wantsCrystal = hasPlayerUnit and true or false

	if (hasPlayerUnit) then
		if (mode == "legacyCrystal") then
			wantsOrb = false
			wantsCrystal = true
		elseif (mode == "orbV2Always") then
			wantsOrb = true
			wantsCrystal = false
		else
			-- Dynamic mode is class-based for predictable behavior.
			wantsOrb = ORB_DYNAMIC_CLASS_ALLOW[playerClass] and true or false
			wantsCrystal = not wantsOrb
		end
	end

	return wantsCrystal, wantsOrb
end

local GetElementalMaelstromDisplayMode = function()
	if (not ns.IsRetail or playerClass ~= "SHAMAN") then
		return "crystal_spec"
	end
	local classPowerMod = ns:GetModule("PlayerClassPowerFrame", true)
	local profile = classPowerMod and classPowerMod.db and classPowerMod.db.profile
	if (not profile) then
		return "crystal_spec"
	end
	local mode = profile.elementalMaelstromDisplayMode
	if (mode == "crystal_mana" or mode == "classpower") then
		return "crystal_mana"
	end
	return "crystal_spec"
end

local IsPlayerPowerUnit = function(unit)
	return (unit == "player" or unit == "vehicle")
end

local GetPlayerPowerUnit = function(frame)
	local unit = frame and frame.unit
	if (IsPlayerPowerUnit(unit)) then
		return unit
	end
	if (UnitHasVehicleUI("player") and UnitExists("vehicle")) then
		return "vehicle"
	end
	return "player"
end

local GetPlayerPowerValueFormat = function(profile)
	local formatMode = profile and profile.PowerValueFormat
	if (formatMode == "percent" or formatMode == "full" or formatMode == "shortpercent" or formatMode == "short") then
		return formatMode
	end
	if (profile and profile.powerValueUsePercent) then
		return "percent"
	end
	if (profile and profile.powerValueUseFull) then
		return "full"
	end
	return "short"
end

local FormatPlayerPowerShortText = function(value)
	if (type(value) ~= "number") then
		return nil
	end
	if (type(AbbreviateNumbers) == "function") then
		local ok, formatted = pcall(AbbreviateNumbers, value)
		if (ok and formatted ~= nil) then
			return tostring(formatted)
		end
	end
	return tostring(math_floor(value + .5))
end

local FormatPlayerPowerFullText = function(value)
	if (type(value) ~= "number") then
		return nil
	end
	return tostring(math_floor(value + .5))
end

local ParseDisplayNumber = function(text)
	if (type(text) ~= "string") then
		return nil
	end
	local ok, parsed = pcall(function()
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", "")
		if (text == "") then
			return nil
		end

		local multiplier = 1
		local suffix = text:sub(-1):lower()
		if (suffix == "k") then
			multiplier = 1000
			text = text:sub(1, -2)
		elseif (suffix == "m") then
			multiplier = 1000000
			text = text:sub(1, -2)
		elseif (suffix == "b") then
			multiplier = 1000000000
			text = text:sub(1, -2)
		elseif (suffix == "t") then
			multiplier = 1000000000000
			text = text:sub(1, -2)
		end

		text = text:gsub(",", "")
		local numeric = tonumber(text)
		if (type(numeric) ~= "number") then
			return nil
		end
		return numeric * multiplier
	end)
	if (ok and type(parsed) == "number") then
		return parsed
	end
	return nil
end

local GetPlayerRawPowerPercent = function(unit, displayType)
	local percent = nil
	pcall(function()
		if (UnitPowerPercent) then
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitPowerPercent(unit, displayType, true, CurveConstants.ScaleTo100)
			else
				percent = UnitPowerPercent(unit, displayType)
			end
		end
	end)
	return percent
end

local GetFormattedPlayerPowerValue = function(element, useFull)
	if (not element) then
		return nil, nil
	end
	local owner = element.__owner
	local unit = GetPlayerPowerUnit(owner)
	local displayType = element.displayType
	if (type(displayType) ~= "number") then
		displayType = UnitPowerType(unit)
	end

	local rawCur = UnitPower(unit, displayType)
	local formatter = useFull and BreakUpLargeNumbers or AbbreviateNumbers
	if (type(formatter) == "function") then
		local ok, formatted = pcall(formatter, rawCur)
		if (ok and formatted ~= nil) then
			local text = tostring(formatted)
			local parsed = ParseDisplayNumber(text)
			if (type(parsed) == "number") then
				return text, parsed
			end
			if (type(rawCur) == "number" and (not issecretvalue or not issecretvalue(rawCur))) then
				return text, rawCur
			end
			return text, nil
		end
	end

	return nil, nil
end

local TrySetPlayerElementValueTextFromRaw = function(element, formatMode)
	if (not element or not element.Value or not element.Value.SetFormattedText) then
		return false
	end

	local owner = element.__owner
	local unit = GetPlayerPowerUnit(owner)
	local displayType = element.displayType
	if (type(displayType) ~= "number") then
		displayType = UnitPowerType(unit)
	end

	local shortText = select(1, GetFormattedPlayerPowerValue(element, false))
	local fullText, fullValue = GetFormattedPlayerPowerValue(element, true)
	local rawPercent = GetPlayerRawPowerPercent(unit, displayType)
	local safePercent = (type(rawPercent) == "number" and (not issecretvalue or not issecretvalue(rawPercent))) and rawPercent or nil
	local safeValue = (type(fullValue) == "number" and (not issecretvalue or not issecretvalue(fullValue))) and fullValue or nil
	local safeMax = (type(element.safeMax) == "number" and element.safeMax > 0) and element.safeMax or nil
	if (type(safePercent) ~= "number" and type(safeValue) == "number" and type(safeMax) == "number") then
		safePercent = (safeValue / safeMax) * 100
	end
	element.__AzeriteUI_DisplayPercent = safePercent
	element.__AzeriteUI_DisplayCur = safeValue

	if (formatMode == "percent") then
		if (rawPercent ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%d%%", rawPercent)
		end
	elseif (formatMode == "full") then
		if (fullText ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%s", fullText)
		end
	elseif (formatMode == "shortpercent") then
		if (shortText ~= nil and rawPercent ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%s |cff888888(|r%d%%|cff888888)|r", shortText, rawPercent)
		elseif (shortText ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%s", shortText)
		elseif (rawPercent ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%d%%", rawPercent)
		end
	else
		if (shortText ~= nil) then
			return pcall(element.Value.SetFormattedText, element.Value, "%s", shortText)
		end
	end

	return false
end

local GetPlayerPowerPercentFromRawText = function(element)
	if (not element) then
		return nil
	end
	local _, parsedCur = GetFormattedPlayerPowerValue(element, true)
	if (type(parsedCur) ~= "number") then
		local _, approxCur = GetFormattedPlayerPowerValue(element, false)
		parsedCur = approxCur
	end
	local maxValue = element.safeMax or element.max
	if (type(parsedCur) == "number" and type(maxValue) == "number" and maxValue > 0) then
		local percent = (parsedCur / maxValue) * 100
		if (percent < 0) then
			percent = 0
		elseif (percent > 100) then
			percent = 100
		end
		return percent
	end
	return nil
end

local GetPlayerElementVisualPercent = function(element)
	if (not element or not element.GetStatusBarTexture) then
		return nil
	end
	local texture = element:GetStatusBarTexture()
	if (not texture) then
		return nil
	end

	local orientation = (element.GetOrientation and element:GetOrientation()) or "HORIZONTAL"
	local barSize
	local texSize

	if (orientation == "VERTICAL") then
		local okBar, value = pcall(element.GetHeight, element)
		local okTex, texValue = pcall(texture.GetHeight, texture)
		if (not okBar or not okTex) then
			return nil
		end
		barSize = value
		texSize = texValue
	else
		local okBar, value = pcall(element.GetWidth, element)
		local okTex, texValue = pcall(texture.GetWidth, texture)
		if (not okBar or not okTex) then
			return nil
		end
		barSize = value
		texSize = texValue
	end

	if (type(barSize) ~= "number" or type(texSize) ~= "number") then
		return nil
	end
	if ((issecretvalue and (issecretvalue(barSize) or issecretvalue(texSize))) or barSize <= 0) then
		return nil
	end

	local percent = (texSize / barSize) * 100
	if (percent < 0) then
		percent = 0
	elseif (percent > 100) then
		percent = 100
	end
	return percent
end

local GetPlayerElementDisplayValue = function(element)
	if (not element) then
		return nil
	end
	local minValue = element.safeMin or element.min or 0
	local maxValue = element.safeMax or element.max
	local percent = GetPlayerElementVisualPercent(element)
	if (type(percent) == "number" and type(minValue) == "number" and type(maxValue) == "number" and maxValue >= minValue) then
		return minValue + ((maxValue - minValue) * (percent / 100))
	end
	return element.safeCur or element.cur
end

local FormatPlayerPowerPercentText = function(element)
	if (not element) then
		return nil
	end
	local percent = GetPlayerPowerPercentFromRawText(element)
	if (type(percent) ~= "number") then
		percent = GetPlayerElementVisualPercent(element)
	end
	if (type(percent) ~= "number") then
		percent = element.safePercent
	end
	if (type(percent) ~= "number") then
		local cur = element.safeCur or element.cur
		local minValue = element.safeMin or element.min or 0
		local maxValue = element.safeMax or element.max
		if (type(cur) == "number" and type(minValue) == "number" and type(maxValue) == "number" and maxValue > minValue) then
			percent = ((cur - minValue) / (maxValue - minValue)) * 100
		end
	end
	if (type(percent) ~= "number") then
		return nil
	end
	if (percent < 0) then
		percent = 0
	elseif (percent > 100) then
		percent = 100
	end
	return string.format("%d%%", math_floor(percent + .5))
end

local UpdatePlayerElementValueText = function(element)
	if (not element or not element.Value or not element.Value.SetText) then
		return
	end

	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	local formatMode = GetPlayerPowerValueFormat(profile)
	if (TrySetPlayerElementValueTextFromRaw(element, formatMode)) then
		return
	end
	local cur = GetPlayerElementDisplayValue(element)
	local shortRawText = select(1, GetFormattedPlayerPowerValue(element, false))
	local fullRawText = select(1, GetFormattedPlayerPowerValue(element, true))
	local valueText

	if (formatMode == "percent") then
		valueText = FormatPlayerPowerPercentText(element)
	elseif (formatMode == "full") then
		valueText = fullRawText or FormatPlayerPowerFullText(cur)
	elseif (formatMode == "shortpercent") then
		local shortText = shortRawText or FormatPlayerPowerShortText(cur)
		local percentText = FormatPlayerPowerPercentText(element)
		if (shortText and percentText) then
			valueText = shortText .. " |cff888888(|r" .. percentText .. "|cff888888)|r"
		else
			valueText = shortText or percentText
		end
	else
		valueText = shortRawText or FormatPlayerPowerShortText(cur)
	end

	if (element.Value.SetFormattedText) then
		element.Value:SetFormattedText("%s", valueText or "")
	else
		element.Value:SetText(valueText or "")
	end
	if (element.Value.SetAlpha) then
		local hasValue = (valueText ~= nil and valueText ~= "")
		element.Value:SetAlpha(hasValue and 1 or 0)
	end
end

local UpdateManaOrbVisibility = function(frame, unit)
	local element = frame and frame.ManaOrb
	if (not element) then
		return false
	end
	local _, shouldShowOrb = ResolvePlayerPowerWidgetVisibility(frame, unit or GetPlayerPowerUnit(frame))
	if (shouldShowOrb) then
		element:Show()
		ShowPlayerNativePowerVisuals(element)
	else
		element:Hide()
	end
	local showPowerValue = shouldShowOrb and ShouldShowPlayerPowerValue()
	element.__AzeriteUI_KeepValueVisible = showPowerValue
	if (element.Value) then
		if (showPowerValue) then
			element.Value:Show()
		else
			element.Value:Hide()
		end
	end
	if (element.Percent) then
		element.Percent:Hide()
	end
	if (frame and frame.Power and frame.ManaOrb) then
		local baseLevel = frame:GetFrameLevel() - 2
		frame.Power:SetFrameLevel(baseLevel + 1)
		frame.ManaOrb:SetFrameLevel(baseLevel)
	end
	UpdatePlayerElementValueText(element)
	return shouldShowOrb
end

-- Hide power crystal when mana is the primary resource or when always show mana orb is enabled.
ShouldShowPlayerPowerValue = function()
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	if (not profile) then
		return true
	end
	if (profile.showPowerValue == false) then
		return false
	end
	if (profile.powerValueCombatDriven) then
		local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
		return inCombat
	end
	return true
end

local ClampPowerValueTextScale = function(scale)
	scale = tonumber(scale)
	if (not scale) then
		return 100
	end
	if (scale < 50) then
		return 50
	end
	if (scale > 200) then
		return 200
	end
	return math_floor(scale + .5)
end

local ApplyScaledValueFont = function(fontString, scale, resetBase)
	if (not fontString or not fontString.GetFont or not fontString.SetFont) then
		return
	end

	local fontPath, fontSize, fontFlags = fontString:GetFont()
	if (not fontPath or type(fontSize) ~= "number" or fontSize <= 0) then
		return
	end

	if (resetBase or not fontString.__AzeriteUI_BaseFontPath or not fontString.__AzeriteUI_BaseFontSize) then
		fontString.__AzeriteUI_BaseFontPath = fontPath
		fontString.__AzeriteUI_BaseFontSize = fontSize
		fontString.__AzeriteUI_BaseFontFlags = fontFlags
	end

	local basePath = fontString.__AzeriteUI_BaseFontPath or fontPath
	local baseSize = fontString.__AzeriteUI_BaseFontSize or fontSize
	local baseFlags = fontString.__AzeriteUI_BaseFontFlags
	local scaledSize = math_floor((baseSize * scale / 100) + .5)
	if (scaledSize < 6) then
		scaledSize = 6
	end

	fontString:SetFont(basePath, scaledSize, baseFlags)
end

local ApplyPlayerPowerValueTextScale = function(frame)
	if (not frame) then
		return
	end

	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	local scale = ClampPowerValueTextScale(profile and profile.powerValueTextScale)

	if (frame.Power and frame.Power.Value) then
		ApplyScaledValueFont(frame.Power.Value, scale)
	end

	if (frame.ManaOrb and frame.ManaOrb.Value) then
		ApplyScaledValueFont(frame.ManaOrb.Value, scale)
	end
end

local ApplyPlayerPowerValueAlpha = function(frame)
	if (ns.UnitFrame and ns.UnitFrame.ApplyPowerValueAlpha) then
		ns.UnitFrame.ApplyPowerValueAlpha(frame)
	end
end

local UpdatePlayerPowerValueTag = function(frame)
	if (not frame or not frame.Power or not frame.Power.Value) then
		return
	end
	local powerValue = frame.Power.Value
	if (powerValue.__AzeriteUI_PowerValueTag and frame.Untag) then
		frame:Untag(powerValue)
		powerValue.__AzeriteUI_PowerValueTag = nil
	end
	UpdatePlayerElementValueText(frame.Power)
end

local UpdatePlayerManaValueTag = function(frame)
	if (not frame or not frame.ManaOrb or not frame.ManaOrb.Value) then
		return
	end
	local manaValue = frame.ManaOrb.Value
	if (manaValue.__AzeriteUI_PowerValueTag and frame.Untag) then
		frame:Untag(manaValue)
		manaValue.__AzeriteUI_PowerValueTag = nil
	end
	UpdatePlayerElementValueText(frame.ManaOrb)
end

local Power_UpdateVisibility = function(element, unit, cur, min, max)
	local owner = element and element.__owner
	local shouldShowCrystal = ResolvePlayerPowerWidgetVisibility(owner, unit)
	if (shouldShowCrystal) then
		element:Show()
	else
		element:Hide()
	end
	if (element:IsShown()) then
		ShowPlayerNativePowerVisuals(element)
		if (element.Display) then
			element.Display:Hide()
		end
		if (element.FakeFill) then
			element.FakeFill:Hide()
		end
	else
		if (element.Display) then
			element.Display:Hide()
		end
		if (element.FakeFill) then
			element.FakeFill:Hide()
		end
	end
	local showPowerValue = element:IsShown() and ShouldShowPlayerPowerValue()
	element.__AzeriteUI_KeepValueVisible = showPowerValue
	if (element.Value) then
		if (showPowerValue) then
			element.Value:Show()
		else
			element.Value:Hide()
		end
	end
	UpdatePlayerElementValueText(element)
	UpdateManaOrbVisibility(owner, unit)
end

-- Keep colors power-token driven so class widgets (like Paladin Holy Power pips)
-- remain visually distinct from the main power crystal.
local POWER_CRYSTAL_TOKEN_ALIASES = {
	HOLY_POWER = "MANA",
	ARCANE_CHARGES = "MANA",
	ESSENCE = "MANA",
	COMBO_POINTS = "ENERGY",
	CHI = "ENERGY",
	PAIN = "FURY",
	SOUL_SHARDS = "FURY",
	RUNES = "RUNIC_POWER"
}
local POWER_CRYSTAL_ENHANCED_COLORS = {
	ENERGY = {  36/255, 214/255, 176/255 },
	FOCUS = { 118/255, 172/255, 255/255 },
	LUNAR_POWER = { 118/255, 172/255, 255/255 },
	MAELSTROM = { 102/255, 191/255, 255/255 },
	RUNIC_POWER = { 112/255, 172/255, 255/255 },
	FURY = { 172/255, 118/255, 255/255 },
	INSANITY = { 172/255, 118/255, 255/255 },
	PAIN = { 172/255, 118/255, 255/255 },
	RAGE = { 214/255, 120/255, 84/255 },
	MANA = {  96/255, 140/255, 255/255 }
}

local POWER_CRYSTAL_DEFAULT_COLOR = {116/255, 156/255, 255/255}

local ResolvePlayerPowerToken = function(element, unit)
	if (type(unit) ~= "string" or unit == "") then
		local owner = element and element.__owner
		local ownerUnit = owner and owner.unit
		if (IsPlayerPowerUnit(ownerUnit)) then
			unit = ownerUnit
		else
			unit = "player"
		end
	end
	local _, token = UnitPowerType(unit, element and element.displayType)
	if (type(token) ~= "string" or token == "") then
		token = "MANA"
	end
	return POWER_CRYSTAL_TOKEN_ALIASES[token] or token
end

local ResolvePlayerPowerColorFromTable = function(colorTable, token, fallbackColor)
	if (type(colorTable) ~= "table") then
		return fallbackColor or POWER_CRYSTAL_DEFAULT_COLOR
	end
	local color = colorTable[token] or colorTable.MANA or colorTable.FOCUS
	if (type(color) ~= "table"
		or type(color[1]) ~= "number"
		or type(color[2]) ~= "number"
		or type(color[3]) ~= "number") then
		return fallbackColor or POWER_CRYSTAL_DEFAULT_COLOR
	end
	return color
end

local ResolvePlayerPowerDefaultColor = function(config, token)
	return ResolvePlayerPowerColorFromTable(config and config.PowerBarColors, token, POWER_CRYSTAL_DEFAULT_COLOR)
end

local ResolvePlayerPowerBaseColor = function(config, profile, token)
	local defaultColor = ResolvePlayerPowerDefaultColor(config, token)
	local colorMode = profile and profile.crystalOrbColorMode or "default"
	if (colorMode == "enhanced" or colorMode == "new" or colorMode == "class") then
		return ResolvePlayerPowerColorFromTable(POWER_CRYSTAL_ENHANCED_COLORS, token, defaultColor)
	end
	return defaultColor
end

UpdatePlayerPowerSpark = function(power)
	local spark = power and power.Spark
	if (not spark) then
		return
	end
	local percent = ClampSparkPercent(power.__AzeriteUI_PowerFakePercent)
	if (percent == nil) then
		percent = ClampSparkPercent(power.safePercent)
	end
	if (type(percent) ~= "number" or percent <= 0 or percent >= 1 or not power:IsShown()) then
		spark:Hide()
		return
	end
	local width = power.GetWidth and power:GetWidth() or 0
	local height = power.GetHeight and power:GetHeight() or 0
	if (type(width) ~= "number" or type(height) ~= "number"
		or width <= 0 or height <= 0
		or (issecretvalue and (issecretvalue(width) or issecretvalue(height)))) then
		spark:Hide()
		return
	end
	local orientation = power.__AzeriteUI_PowerFakeOrientation or "UP"
	local reverseFill = power.__AzeriteUI_PowerFakeReverse and true or false
	spark:ClearAllPoints()
	if (orientation == "LEFT" or orientation == "RIGHT") then
		local fillFromRight = ((orientation == "LEFT") and (not reverseFill)) or ((orientation ~= "LEFT") and reverseFill)
		local x = width * (fillFromRight and (1 - percent) or percent)
		spark:SetPoint("CENTER", power, "LEFT", x, 0)
	else
		local fillFromTop = ((orientation == "DOWN") and (not reverseFill)) or ((orientation ~= "DOWN") and reverseFill)
		local y = height * (fillFromTop and (1 - percent) or percent)
		spark:SetPoint("CENTER", power, "BOTTOM", 0, y)
	end
	spark:Show()
end

local Power_PostUpdateColor = function(element, unit, r, g, b)
	local config = ns.GetConfig("PlayerFrame")
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	local token = ResolvePlayerPowerToken(element, unit)
	local color = ResolvePlayerPowerBaseColor(config, profile, token)
	if (color) then
		element:SetStatusBarColor(color[1], color[2], color[3])
	end
	local fakeFill = element and element.FakeFill
	if (fakeFill and fakeFill.SetVertexColor and element.GetStatusBarColor) then
		local fr, fg, fb, fa = element:GetStatusBarColor()
		if (type(fr) == "number" and type(fg) == "number" and type(fb) == "number") then
			fakeFill:SetVertexColor(fr, fg, fb, (type(fa) == "number" and fa or 1))
		end
	end
end

HidePlayerNativePowerVisuals = function(power)
	if (not power) then
		return
	end
	if (not power.GetStatusBarTexture) then
		return
	end
	local tex1, tex2, tex3, tex4 = power:GetStatusBarTexture()
	for _, nativeTexture in next, { tex1, tex2, tex3, tex4 } do
		if (nativeTexture) then
			if (nativeTexture.SetAlpha) then
				nativeTexture:SetAlpha(0)
			end
			if (nativeTexture.Hide) then
				nativeTexture:Hide()
			end
		end
	end
end

ShowPlayerNativePowerVisuals = function(power)
	if (not power) then
		return
	end
	if (not power.GetStatusBarTexture) then
		return
	end
	local tex1, tex2, tex3, tex4 = power:GetStatusBarTexture()
	for _, nativeTexture in next, { tex1, tex2, tex3, tex4 } do
		if (nativeTexture) then
			if (nativeTexture.SetAlpha) then
				nativeTexture:SetAlpha(1)
			end
			if (nativeTexture.Show) then
				nativeTexture:Show()
			end
		end
	end
end


UpdatePlayerFakePowerFill = function(power, value)
	if (not power) then
		return false
	end
	local fakeFill = power.FakeFill
	if (not fakeFill) then
		return false
	end
	local IsSafeNumber = function(num)
		return type(num) == "number" and ((not issecretvalue) or (not issecretvalue(num)))
	end

	local minValue = power.__AzeriteUI_PowerFakeMin
	local maxValue = power.__AzeriteUI_PowerFakeMax
	local currentValue = value
	if (type(currentValue) ~= "number") then
		currentValue = power.__AzeriteUI_PowerFakeValue
	end
	if (not IsSafeNumber(minValue)) then
		minValue = power.safeMin
	end
	if (not IsSafeNumber(maxValue)) then
		maxValue = power.safeMax
	end
	if (not IsSafeNumber(currentValue)) then
		currentValue = power.safeCur
	end
	if (not IsSafeNumber(minValue) or not IsSafeNumber(maxValue) or maxValue <= minValue or not IsSafeNumber(currentValue)) then
		power.__AzeriteUI_PowerFakePercent = nil
		fakeFill:Hide()
		return false
	end

	local percent = (currentValue - minValue) / (maxValue - minValue)
	if (percent < 0) then
		percent = 0
	elseif (percent > 1) then
		percent = 1
	end
	if (percent <= 0) then
		power.__AzeriteUI_PowerFakePercent = 0
		fakeFill:Hide()
		return false
	end
	power.__AzeriteUI_PowerFakePercent = percent

	-- Match the native power crystal base color.
	local config = ns.GetConfig("PlayerFrame")
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile
	local token = ResolvePlayerPowerToken(power)
	local baseColor = ResolvePlayerPowerBaseColor(config, profile, token)
	fakeFill:SetVertexColor(baseColor[1], baseColor[2], baseColor[3], 1)

	local nativeTexture = power.GetStatusBarTexture and power:GetStatusBarTexture()
	if (nativeTexture and nativeTexture.GetTexture and fakeFill.SetTexture) then
		local texturePath = nativeTexture:GetTexture()
		if (texturePath) then
			fakeFill:SetTexture(texturePath)
		end
	end

	fakeFill:ClearAllPoints()
	fakeFill:SetTexCoord(power.__AzeriteUI_PowerFakeTexLeft or 0, power.__AzeriteUI_PowerFakeTexRight or 1, power.__AzeriteUI_PowerFakeTexTop or 0, power.__AzeriteUI_PowerFakeTexBottom or 1)
	local orientation = power.__AzeriteUI_PowerFakeOrientation or "UP"
	local reverseFill = power.__AzeriteUI_PowerFakeReverse and true or false
	local width = power.__AzeriteUI_PowerFakeWidth
	local height = power.__AzeriteUI_PowerFakeHeight
	if (not IsSafeNumber(width)) then
		width = power.GetWidth and power:GetWidth() or 0
	end
	if (not IsSafeNumber(height)) then
		height = power.GetHeight and power:GetHeight() or 0
	end
	if (not IsSafeNumber(width) or not IsSafeNumber(height) or width <= 0 or height <= 0) then
		power.__AzeriteUI_PowerFakePercent = nil
		fakeFill:Hide()
		return false
	end
	if (orientation == "LEFT" or orientation == "RIGHT") then
		local fillFromRight = ((orientation == "LEFT") and (not reverseFill)) or ((orientation ~= "LEFT") and reverseFill)
		local inset = (1 - percent) * width
		if (fillFromRight) then
			fakeFill:SetPoint("TOPLEFT", power, "TOPLEFT", inset, 0)
			fakeFill:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
		else
			fakeFill:SetPoint("TOPLEFT", power, "TOPLEFT", 0, 0)
			fakeFill:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", -inset, 0)
		end
	else
		local fillFromTop = ((orientation == "DOWN") and (not reverseFill)) or ((orientation ~= "DOWN") and reverseFill)
		local inset = (1 - percent) * height
		if (fillFromTop) then
			fakeFill:SetPoint("TOPLEFT", power, "TOPLEFT", 0, inset)
			fakeFill:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
		else
			fakeFill:SetPoint("TOPLEFT", power, "TOPLEFT", 0, 0)
			fakeFill:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, -inset)
		end
	end
	fakeFill:Show()
	return true
end

-- Keep orb behavior deterministic and token-aware (Diabolic parity),
-- while retaining AzeriteUI's configured orb palette.
local Power_OnEnter = function(element)
	local OnEnter = element.__owner and element.__owner.GetScript and element.__owner:GetScript("OnEnter")
	if (OnEnter) then
		OnEnter(element)
	end
end

local Power_OnLeave = function(element)
	local OnLeave = element.__owner and element.__owner.GetScript and element.__owner:GetScript("OnLeave")
	if (OnLeave) then
		OnLeave(element)
	end
end

local Power_OnMouseOver = function(element)
	if (element.__owner and element.__owner.OnMouseOver) then
		element.__owner:OnMouseOver()
	end
end

local Mana_PostUpdate = function(element, unit, cur, min, max)
	local config = ns.GetConfig("PlayerFrame")
	local token = "MANA"
	if (unit) then
		local _, powerToken = UnitPowerType(unit, element.displayType)
		if (type(powerToken) == "string" and powerToken ~= "") then
			token = powerToken
		end
	end

	local color = config and config.PowerOrbColors and config.PowerOrbColors[token]
	if (type(color) ~= "table") then
		color = config and config.PowerOrbColors and config.PowerOrbColors.MANA
	end
	if (type(color) == "table" and type(color[1]) == "number" and type(color[2]) == "number" and type(color[3]) == "number") then
		element.colorPower = false
		element:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
	end
	UpdatePlayerElementValueText(element)
	local displayPercent = element.__AzeriteUI_DisplayPercent
	local displayCur = element.__AzeriteUI_DisplayCur
	local safeMin = (type(element.safeMin) == "number") and element.safeMin or 0
	local safeMax = (type(element.safeMax) == "number" and element.safeMax > safeMin) and element.safeMax or ((type(max) == "number" and max > safeMin) and max or nil)
	local visualPercent = GetPlayerElementVisualPercent(element)
	if (type(displayPercent) ~= "number") then
		displayPercent = visualPercent
	end
	if (type(displayCur) ~= "number") then
		displayCur = GetPlayerElementDisplayValue(element)
	end
	if (type(displayCur) ~= "number" or (issecretvalue and issecretvalue(displayCur))) then
		displayCur = nil
	end
	if (type(displayPercent) ~= "number" or (issecretvalue and issecretvalue(displayPercent))) then
		displayPercent = nil
	end
	if (type(displayPercent) == "number" and type(safeMax) == "number") then
		element.safePercent = displayPercent
		if (type(displayCur) ~= "number") then
			displayCur = safeMin + ((safeMax - safeMin) * (displayPercent / 100))
		end
	end
	if (type(displayCur) == "number" and type(safeMax) == "number") then
		element.safeCur = displayCur
		element.safeMin = safeMin
		element.safeMax = safeMax
	end
end

local ApplyDiabolicManaOrbArt = function(mana, db)
	if (not mana or not db) then
		return
	end

	local manaBackdrop = mana.Backdrop
	local manaShade = mana.Shade
	local manaCase = mana.Case
	local manaGlass = mana.Glass
	local manaArtwork = mana.Artwork

	if (manaBackdrop) then
		manaBackdrop:ClearAllPoints()
		manaBackdrop:SetPoint(unpack(db.ManaOrbBackdropPosition))
		manaBackdrop:SetSize(unpack(db.ManaOrbBackdropSize))
		manaBackdrop:SetTexture(db.ManaOrbBackdropTexture)
		manaBackdrop:SetVertexColor(unpack(db.ManaOrbBackdropColor))
	end

	if (manaShade) then
		manaShade:ClearAllPoints()
		manaShade:SetPoint(unpack(db.ManaOrbShadePosition))
		manaShade:SetSize(unpack(db.ManaOrbShadeSize))
		manaShade:SetTexture(db.ManaOrbShadeTexture)
		manaShade:SetVertexColor(unpack(db.ManaOrbShadeColor))
	end

	if (manaCase) then
		manaCase:ClearAllPoints()
		manaCase:SetPoint(unpack(db.ManaOrbForegroundPosition))
		manaCase:SetSize(unpack(db.ManaOrbForegroundSize))
		manaCase:SetTexture(db.ManaOrbForegroundTexture)
		manaCase:SetVertexColor(unpack(db.ManaOrbForegroundColor))
	end

	if (manaGlass) then
		manaGlass:Hide()
	end

	if (manaArtwork) then
		manaArtwork:Hide()
	end
end

local RefreshManaOrb = function(frame, event, unit)
	if (not frame or not frame.ManaOrb) then
		return
	end
	unit = unit or GetPlayerPowerUnit(frame)
	UpdateManaOrbVisibility(frame, unit)
	return ns.API.UpdateManaOrb(frame, event or "ForceUpdate", unit)
end

-- Toggle cast text color on protected casts.
local Cast_PostCastInterruptible = function(element, unit)
	if (element.notInterruptible) then
		element.Text:SetTextColor(unpack(element.Text.colorProtected))
	else
		element.Text:SetTextColor(unpack(element.Text.color))
	end
	UpdateBarSpark(element)
end

-- Toggle cast info and health info when castbar is visible.
local Cast_UpdateTexts = function(element)
	local health = element.__owner.Health
	if (not health or not health.Value) then
		return
	end

	if (element:IsShown()) then
		element.Text:Show()
		element.Time:Show()
		health.Value:Hide()
	else
		element.Text:Hide()
		element.Time:Hide()
		health.Value:Show()
	end
	UpdateBarSpark(element)
end

-- Trigger PvPIndicator post update when combat status is toggled.
local CombatIndicator_PostUpdate = function(element, inCombat)
	element.__owner.PvPIndicator:ForceUpdate()
end

-- Only show Horde/Alliance badges, and hide them in combat.
local PvPIndicator_Override = function(self, event, unit)
	if (unit and unit ~= self.unit) then return end

	local element = self.PvPIndicator
	unit = unit or self.unit

	local status
	local factionGroup = UnitFactionGroup(unit) or "Neutral"

	if (factionGroup ~= "Neutral") then
		if (UnitIsPVPFreeForAll(unit)) then
		elseif (UnitIsPVP(unit)) then
			if (ns.IsRetail and unit == "player" and UnitIsMercenary(unit)) then
				if (factionGroup == "Horde") then
					factionGroup = "Alliance"
				elseif (factionGroup == "Alliance") then
					factionGroup = "Horde"
				end
			end
			status = factionGroup
		end
	end

	if (status and not self.CombatIndicator:IsShown()) then
		element:SetTexture(element[status])
		element:Show()
	else
		element:Hide()
	end

end

-- Helper to adjust TexCoord based on profile setting
local GetAdjustedTexCoord = function(baseTexCoord, adjustment)
	if (not baseTexCoord or not adjustment or adjustment == 0) then
		return baseTexCoord
	end
	-- baseTexCoord is {left, right, top, bottom} in normalized 0-1 coords
	-- Convert to pixel space (0-255) for easier math
	local left = math.floor(baseTexCoord[1] * 255 + 0.5)
	local right = math.floor(baseTexCoord[2] * 255 + 0.5)
	local top = math.floor(baseTexCoord[3] * 255 + 0.5)
	local bottom = math.floor(baseTexCoord[4] * 255 + 0.5)
	-- Apply adjustment to margins
	left = math.max(0, left + adjustment)
	right = math.min(255, right - adjustment)
	top = math.max(0, top + adjustment)
	bottom = math.min(255, bottom - adjustment)
	-- Convert back to 0-1 range
	return { left / 255, right / 255, top / 255, bottom / 255 }
end

-- Update player frame based on player level.
local UnitFrame_UpdateTextures = function(self)
	local playerLevel = playerLevel or UnitLevel("player")
	local key = (playerXPDisabled or IsLevelAtEffectiveMaxLevel(playerLevel)) and "Seasoned" or playerLevel < 10 and "Novice" or "Hardened"
	local config = ns.GetConfig("PlayerFrame")
	local db = config[key]
	local profile = PlayerFrameMod and PlayerFrameMod.db and PlayerFrameMod.db.profile or nil

	local ResolvePowerAnchorFrame = function(frameKey, power)
		if (frameKey == "POWER") then
			return power
		elseif (frameKey == "POWER_BACKDROP") then
			return power and power.Backdrop
		elseif (frameKey == "POWER_CASE") then
			return power and power.Case
		elseif (frameKey == "HEALTH") then
			return self.Health
		end
		return self
	end
	local powerBarOffsetX = ((profile and tonumber(profile.powerBarBaseOffsetX)) or 0) + ((profile and tonumber(profile.powerBarOffsetX)) or 0)
	local powerBarOffsetY = ((profile and tonumber(profile.powerBarBaseOffsetY)) or 0) + ((profile and tonumber(profile.powerBarOffsetY)) or 0)
	local powerCaseOffsetX = ((profile and tonumber(profile.powerCaseBaseOffsetX)) or 0) + ((profile and tonumber(profile.powerCaseOffsetX)) or 0)
	local powerCaseOffsetY = ((profile and tonumber(profile.powerCaseBaseOffsetY)) or 0) + ((profile and tonumber(profile.powerCaseOffsetY)) or 0)
	local powerThreatBarOffsetX = (profile and tonumber(profile.powerThreatBarOffsetX)) or 0
	local powerThreatBarOffsetY = (profile and tonumber(profile.powerThreatBarOffsetY)) or 0
	local powerThreatCaseOffsetX = (profile and tonumber(profile.powerThreatCaseOffsetX)) or 0
	local powerThreatCaseOffsetY = (profile and tonumber(profile.powerThreatCaseOffsetY)) or 0
	local powerBarScaleLegacy = (profile and tonumber(profile.powerBarScale)) or 1
	local powerBarScaleX = (((profile and tonumber(profile.powerBarBaseScaleX)) or 1) * ((profile and tonumber(profile.powerBarScaleX)) or powerBarScaleLegacy))
	local powerBarScaleY = (((profile and tonumber(profile.powerBarBaseScaleY)) or 1) * ((profile and tonumber(profile.powerBarScaleY)) or powerBarScaleLegacy))
	local powerBackdropScaleX = (profile and tonumber(profile.powerBackdropScaleX)) or 1
	local powerBackdropScaleY = (profile and tonumber(profile.powerBackdropScaleY)) or 1
	local powerCaseScaleX = (profile and tonumber(profile.powerCaseScaleX)) or 1
	local powerCaseScaleY = (profile and tonumber(profile.powerCaseScaleY)) or 1
	local powerThreatBarScaleX = (profile and tonumber(profile.powerThreatBarScaleX)) or 1
	local powerThreatBarScaleY = (profile and tonumber(profile.powerThreatBarScaleY)) or 1
	local powerThreatCaseScaleX = (profile and tonumber(profile.powerThreatCaseScaleX)) or 1
	local powerThreatCaseScaleY = (profile and tonumber(profile.powerThreatCaseScaleY)) or 1
	local powerBarAnchorFrameKey = (profile and profile.powerBarAnchorFrame) or "FRAME"
	local powerCaseAnchorFrameKey = (profile and profile.powerCaseAnchorFrame) or "POWER"
	local powerThreatBarAnchorFrameKey = (profile and profile.powerThreatBarAnchorFrame) or "POWER"
	local powerThreatCaseAnchorFrameKey = (profile and profile.powerThreatCaseAnchorFrame) or "POWER"
	local powerBarArtLayer = (profile and tonumber(profile.powerBarArtLayer)) or 0
	local useIceCrystal = PlayerFrameMod.db.profile.useWrathCrystal or ns.API.IsWinterVeil()
	local ClampLayer = function(value, defaultValue)
		local numeric = tonumber(value)
		if (type(numeric) ~= "number") then
			numeric = defaultValue or 0
		end
		numeric = math_floor(numeric)
		if (numeric < -8) then
			numeric = -8
		elseif (numeric > 7) then
			numeric = 7
		end
		return numeric
	end
	local SafeSetDrawLayer = function(texture, layerName, subLevel, defaultSubLevel)
		if (not texture or not texture.SetDrawLayer) then
			return
		end
		local safeSubLevel = ClampLayer(subLevel, defaultSubLevel)
		pcall(texture.SetDrawLayer, texture, layerName, safeSubLevel)
	end
	if (powerBarScaleX <= 0) then
		powerBarScaleX = 1
	end
	if (powerBarScaleY <= 0) then
		powerBarScaleY = 1
	end
	local NormalizeScale = function(value)
		value = tonumber(value)
		if (type(value) ~= "number" or value <= 0) then
			return 1
		end
		return value
	end
	powerBackdropScaleX = NormalizeScale(powerBackdropScaleX)
	powerBackdropScaleY = NormalizeScale(powerBackdropScaleY)
	powerCaseScaleX = NormalizeScale(powerCaseScaleX)
	powerCaseScaleY = NormalizeScale(powerCaseScaleY)
	powerThreatBarScaleX = NormalizeScale(powerThreatBarScaleX)
	powerThreatBarScaleY = NormalizeScale(powerThreatBarScaleY)
	powerThreatCaseScaleX = NormalizeScale(powerThreatCaseScaleX)
	powerThreatCaseScaleY = NormalizeScale(powerThreatCaseScaleY)

	local SetPointWithOffset = function(frame, pointData, offsetX, offsetY, anchorFrame)
		if (not frame or not pointData or not pointData[1]) then
			return
		end
		if (anchorFrame == frame) then
			anchorFrame = nil
		end
		local x = (offsetX or 0)
		local y = (offsetY or 0)
		if (type(pointData[2]) == "number" or pointData[2] == nil) then
			if (anchorFrame) then
				frame:SetPoint(pointData[1], anchorFrame, pointData[1], (pointData[2] or 0) + x, (pointData[3] or 0) + y)
			else
				frame:SetPoint(pointData[1], (pointData[2] or 0) + x, (pointData[3] or 0) + y)
			end
		else
			local relativeFrame = pointData[2]
			if (relativeFrame == frame) then
				relativeFrame = nil
			end
			if (relativeFrame) then
				frame:SetPoint(pointData[1], relativeFrame, pointData[3], (pointData[4] or 0) + x, (pointData[5] or 0) + y)
			else
				frame:SetPoint(pointData[1], (pointData[4] or 0) + x, (pointData[5] or 0) + y)
			end
		end
	end
	local ScaleSize = function(sizeData, scaleX, scaleY)
		if (not sizeData) then
			return 0, 0
		end
		return (sizeData[1] or 0) * (scaleX or 1), (sizeData[2] or 0) * (scaleY or 1)
	end
	local GetAnchorPointToken = function(pointData)
		if (not pointData) then
			return "CENTER"
		end
		if (type(pointData[2]) == "number" or pointData[2] == nil) then
			return pointData[1] or "CENTER"
		end
		return pointData[3] or pointData[1] or "CENTER"
	end
	local GetPointFactors = function(pointToken)
		local token = tostring(pointToken or "CENTER")
		local horizontal = 0
		local vertical = 0
		if (token:find("LEFT", 1, true)) then
			horizontal = -1
		elseif (token:find("RIGHT", 1, true)) then
			horizontal = 1
		end
		if (token:find("BOTTOM", 1, true)) then
			vertical = -1
		elseif (token:find("TOP", 1, true)) then
			vertical = 1
		end
		return horizontal, vertical
	end
	local GetAdjustedTexCoord = function(baseTexCoord, adjustment)
		if (not baseTexCoord or not adjustment or adjustment == 0) then
			return baseTexCoord
		end
		-- baseTexCoord is {left, right, top, bottom} in normalized 0-1 coords
		-- Convert to pixel space (0-255) for easier math
		local left = math.floor(baseTexCoord[1] * 255 + 0.5)
		local right = math.floor(baseTexCoord[2] * 255 + 0.5)
		local top = math.floor(baseTexCoord[3] * 255 + 0.5)
		local bottom = math.floor(baseTexCoord[4] * 255 + 0.5)
		-- Apply adjustment to margins
		left = math.max(0, left + adjustment)
		right = math.min(255, right - adjustment)
		top = math.max(0, top + adjustment)
		bottom = math.min(255, bottom - adjustment)
		-- Convert back to 0-1 range
		return { left / 255, right / 255, top / 255, bottom / 255 }
	end

	local health = self.Health
	health:ClearAllPoints()
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	-- WoW 12.0: Only set texture if it changed to prevent flickering
	if (health._cachedTexture ~= db.HealthBarTexture) then
		health:SetStatusBarTexture(db.HealthBarTexture)
		health._cachedTexture = db.HealthBarTexture
	end
	health.colorSmooth = false
	health.colorClass = PlayerFrameMod.db.profile.useClassColor
	health.colorHealth = true

	health:SetOrientation(db.HealthBarOrientation)
	health:SetSparkMap(db.HealthBarSparkMap)
	UpdateBarSparkSize(health)
	UpdateBarSpark(health)

	local healthPreview = self.Health.Preview
	if (healthPreview._cachedTexture ~= db.HealthBarTexture) then
		healthPreview:SetStatusBarTexture(db.HealthBarTexture)
		healthPreview._cachedTexture = db.HealthBarTexture
	end
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
		if (absorb._cachedTexture ~= db.HealthBarTexture) then
			absorb:SetStatusBarTexture(db.HealthBarTexture)
			absorb._cachedTexture = db.HealthBarTexture
		end
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
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
		absorb:SetSparkMap(db.HealthBarSparkMap)
		HidePlayerAbsorbBarVisual(absorb)
	end

	local power = self.Power
	local shouldShowCrystal = ResolvePlayerPowerWidgetVisibility(self, "player")
	power:ClearAllPoints()
	local ptex
	local powerAnchorFrame = ResolvePowerAnchorFrame(powerBarAnchorFrameKey, power)
	local powerBarPoint = db[CURRENT_POWER_CRYSTAL_LAYOUT.barPointKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barPointKey]
	local legacyPowerSize = db[STOCK_POWER_CRYSTAL_LAYOUT.barSizeKey] or db.PowerBarSize
	local legacyPowerWidth, legacyPowerHeight = ScaleSize(legacyPowerSize, powerBarScaleX, powerBarScaleY)
	legacyPowerWidth = math_floor(legacyPowerWidth + .5)
	legacyPowerHeight = math_floor(legacyPowerHeight + .5)
	local powerBackdropSize = db[CURRENT_POWER_CRYSTAL_LAYOUT.backdropSizeKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.backdropSizeKey]
	local powerBackdropWidth, powerBackdropHeight = ScaleSize(powerBackdropSize, powerBackdropScaleX, powerBackdropScaleY)
	powerBackdropWidth = math_floor(powerBackdropWidth + .5)
	powerBackdropHeight = math_floor(powerBackdropHeight + .5)
	local powerDeltaWidth = powerBackdropWidth - legacyPowerWidth
	local powerDeltaHeight = powerBackdropHeight - legacyPowerHeight
	-- Keep crystal fill and backdrop perfectly locked: power bar follows backdrop anchor/size.
	SetPointWithOffset(power, powerBarPoint, powerBarOffsetX, powerBarOffsetY, powerAnchorFrame)
	power:SetSize(powerBackdropWidth, powerBackdropHeight)
	-- WoW 12.0: Cache texture to prevent flickering
	local powerTexture = (PlayerFrameMod.db.profile.useWrathCrystal or ns.API.IsWinterVeil()) and db.PowerBarTextureWrath or db.PowerBarTexture
	if (power._cachedTexture ~= powerTexture) then
		power:SetStatusBarTexture(powerTexture)
		power._cachedTexture = powerTexture
	end
	if (useIceCrystal) then
		power.colorPower = false
		power:SetStatusBarColor(1, 1, 1, 1)
	else
		power.colorPower = true
	end
	-- StatusBar itself has no SetTexCoord; apply to its texture if present.
	ptex = power:GetStatusBarTexture()
	local powerTexCoord = db[CURRENT_POWER_CRYSTAL_LAYOUT.barTexCoordKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barTexCoordKey]
	local adjustedCoord = powerTexCoord
	if (powerTexCoord) then
		local texCoordAdjust = (profile and tonumber(profile.powerBarTexCoordAdjust)) or 0
		adjustedCoord = GetAdjustedTexCoord(powerTexCoord, texCoordAdjust)
	end
	if (ptex and ptex.SetTexCoord and adjustedCoord) then
		ptex:SetTexCoord(unpack(adjustedCoord))
	end
	if (type(adjustedCoord) == "table") then
		power.__AzeriteUI_PowerFakeTexLeft = adjustedCoord[1]
		power.__AzeriteUI_PowerFakeTexRight = adjustedCoord[2]
		power.__AzeriteUI_PowerFakeTexTop = adjustedCoord[3]
		power.__AzeriteUI_PowerFakeTexBottom = adjustedCoord[4]
	elseif (ptex and ptex.GetTexCoord) then
		local left, right, top, bottom = ptex:GetTexCoord()
		power.__AzeriteUI_PowerFakeTexLeft = left
		power.__AzeriteUI_PowerFakeTexRight = right
		power.__AzeriteUI_PowerFakeTexTop = top
		power.__AzeriteUI_PowerFakeTexBottom = bottom
	end
	power.__AzeriteUI_PowerFakeOrientation = db[CURRENT_POWER_CRYSTAL_LAYOUT.barOrientationKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barOrientationKey] or "UP"
	power.__AzeriteUI_PowerFakeReverse = false
	power.__AzeriteUI_PowerFakeWidth = powerBackdropWidth
	power.__AzeriteUI_PowerFakeHeight = powerBackdropHeight
	power.__AzeriteUI_PowerFakeMin = power.safeMin
	power.__AzeriteUI_PowerFakeMax = power.safeMax
	power.__AzeriteUI_PowerFakeValue = power.safeCur
	if (ptex and ptex.SetDrawLayer) then
		SafeSetDrawLayer(ptex, "ARTWORK", 0 + powerBarArtLayer, 0)
	end
	if (not shouldShowCrystal) then
		power:Hide()
	else
		power:Show()
	end
	power:SetOrientation("VERTICAL")
	if (power.SetSparkMap and db.PowerBarSparkMap) then
		power:SetSparkMap(db.PowerBarSparkMap)
	end
	ShowPlayerNativePowerVisuals(power)
	local powerFakeFill = power.FakeFill
	if (powerFakeFill) then
		powerFakeFill:Hide()
	end

	local powerBackdrop = self.Power.Backdrop
	powerBackdrop:ClearAllPoints()
	local powerBackdropAnchorFrame = power
	SetPointWithOffset(powerBackdrop, CURRENT_POWER_CRYSTAL_LAYOUT.backdropPoint, 0, 0, powerBackdropAnchorFrame)
	powerBackdrop:SetSize(powerBackdropWidth, powerBackdropHeight)
	powerBackdrop:SetTexture((PlayerFrameMod.db.profile.useWrathCrystal or ns.API.IsWinterVeil()) and db.PowerBackdropTextureWrath or db.PowerBackdropTexture)
	powerBackdrop:SetVertexColor(1, 1, 1, 1)
	SafeSetDrawLayer(powerBackdrop, "BACKGROUND", -2 + powerBarArtLayer, -2)

	local powerCase = self.Power.Case
	powerCase:ClearAllPoints()
	local powerCaseAnchorFrame = ResolvePowerAnchorFrame(powerCaseAnchorFrameKey, power)
	local powerCaseAnchorPoint = GetAnchorPointToken(db.PowerBarForegroundPosition)
	local powerCaseHorizontal, powerCaseVertical = GetPointFactors(powerCaseAnchorPoint)
	local powerCaseShiftX = powerCaseHorizontal * (powerDeltaWidth * .5)
	local powerCaseShiftY = powerCaseVertical * (powerDeltaHeight * .5)
	SetPointWithOffset(powerCase, db.PowerBarForegroundPosition, powerCaseOffsetX - powerCaseShiftX, powerCaseOffsetY - powerCaseShiftY, powerCaseAnchorFrame)
	local powerCaseWidth, powerCaseHeight = ScaleSize(db.PowerBarForegroundSize, powerCaseScaleX, powerCaseScaleY)
	powerCaseWidth = math_floor(powerCaseWidth + .5)
	powerCaseHeight = math_floor(powerCaseHeight + .5)
	powerCase:SetSize(powerCaseWidth, powerCaseHeight)
	powerCase:SetTexture(db.PowerBarForegroundTexture)
	powerCase:SetVertexColor(unpack(db.PowerBarForegroundColor))
	SafeSetDrawLayer(powerCase, "ARTWORK", 2 + powerBarArtLayer, 2)

	local powerValue = self.Power.Value
	if (powerValue) then
		powerValue:ClearAllPoints()
		powerValue:SetPoint(unpack(config.PowerValuePosition))
		powerValue:SetFontObject(config.PowerValueFont)
		ApplyScaledValueFont(powerValue, ClampPowerValueTextScale(PlayerFrameMod.db.profile.powerValueTextScale), true)
		powerValue:SetTextColor(unpack(config.PowerValueColor))
		powerValue:SetJustifyH(config.PowerValueJustifyH)
		powerValue:SetJustifyV(config.PowerValueJustifyV)
	end

	local powerPercent = self.Power.Percent
	if (powerPercent) then
		powerPercent:ClearAllPoints()
		if (config.PowerPercentagePosition) then
			powerPercent:SetPoint(unpack(config.PowerPercentagePosition))
		else
			powerPercent:SetPoint("TOP", powerValue or self.Power, "BOTTOM", 0, -2)
		end
		powerPercent:SetFontObject(config.PowerPercentageFont or config.PowerValueFont)
		local powerPercColor = config.PowerPercentageColor or config.PowerValueColor or { 1, 1, 1, 1 }
		powerPercent:SetTextColor(powerPercColor[1], powerPercColor[2], powerPercColor[3], powerPercColor[4] or 1)
		powerPercent:SetJustifyH(config.PowerPercentageJustifyH or "CENTER")
		powerPercent:SetJustifyV(config.PowerPercentageJustifyV or "TOP")
	end
	ApplyPlayerPowerValueAlpha(self)

	local mana = self.ManaOrb
	mana:ClearAllPoints()
	mana:SetPoint(unpack(db.ManaOrbPosition))
	mana:SetSize(unpack(db.ManaOrbSize))
	mana.colorPower = false
	if (type(db.ManaOrbTexture) == "table") then
		mana:SetStatusBarTexture(unpack(db.ManaOrbTexture))
	else
		mana:SetStatusBarTexture(db.ManaOrbTexture)
	end
	mana:SetStatusBarColor(unpack(config.PowerOrbColors.MANA))
	do
		local tex1, tex2 = mana:GetStatusBarTexture()
		if (tex2 and tex2.SetTexCoord) then
			tex2:SetTexCoord(1, 0, 1, 0)
		end
		if (tex1 and tex1.SetTexCoord) then
			tex1:SetTexCoord(0, 1, 0, 1)
		end
	end
	ApplyDiabolicManaOrbArt(mana, db)
	ShowPlayerNativePowerVisuals(mana)

	local cast = self.Castbar
	cast:ClearAllPoints()
	cast:SetPoint(unpack(db.HealthBarPosition))
	cast:SetSize(unpack(db.HealthBarSize))
	cast:SetStatusBarTexture(db.HealthBarTexture)
	cast:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	cast:SetOrientation(db.HealthBarOrientation)
	cast:SetSparkMap(db.HealthBarSparkMap)
	UpdateBarSparkSize(cast)
	UpdateBarSpark(cast)

	local threat = self.ThreatIndicator
	if (threat) then
		for key,texture in next,threat.textures do
			local point = db[key.."ThreatPosition"]
			local size = db[key.."ThreatSize"]
			texture:ClearAllPoints()
			if (point) then
				if (key == "PowerBar") then
					local threatBarAnchorFrame = ResolvePowerAnchorFrame(powerThreatBarAnchorFrameKey, power)
					local threatPoint = GetAnchorPointToken(point)
					local h, v = GetPointFactors(threatPoint)
					local shiftX = h * (powerDeltaWidth * .5)
					local shiftY = v * (powerDeltaHeight * .5)
					SetPointWithOffset(texture, point, powerThreatBarOffsetX - shiftX, powerThreatBarOffsetY - shiftY, threatBarAnchorFrame)
				elseif (key == "PowerBackdrop") then
					local threatCaseAnchorFrame = ResolvePowerAnchorFrame(powerThreatCaseAnchorFrameKey, power)
					local threatPoint = GetAnchorPointToken(point)
					local h, v = GetPointFactors(threatPoint)
					local shiftX = h * (powerDeltaWidth * .5)
					local shiftY = v * (powerDeltaHeight * .5)
					SetPointWithOffset(texture, point, powerThreatCaseOffsetX - shiftX, powerThreatCaseOffsetY - shiftY, threatCaseAnchorFrame)
				else
					texture:SetPoint(unpack(point))
				end
			end
			if (size) then
				if (key == "PowerBar") then
					texture:SetSize(powerBackdropWidth, powerBackdropHeight)
				elseif (key == "PowerBackdrop") then
					local sx = powerCaseScaleX * powerThreatCaseScaleX
					local sy = powerCaseScaleY * powerThreatCaseScaleY
					texture:SetSize((size[1] or 0) * sx, (size[2] or 0) * sy)
				else
					texture:SetSize(unpack(size))
				end
			end
			texture:SetTexture(db[key.."ThreatTexture"])
		end
	end

	local auras = self.Auras
	if (auras) then
		auras:ClearAllPoints()
		auras:SetSize(unpack(config.AurasSize))
		auras:SetPoint(unpack(config.AurasPosition))
	end

end

local NormalizePowerOffsetBaseline = function(self)
	local profile = self and self.db and self.db.profile
	if (not profile) then
		return
	end
	-- Legacy crystal tuning was introduced for oversized assets.
	-- Normalize those exact legacy defaults back to current baseline offsets.
	if ((tonumber(profile.powerBarOffsetX) or 0) == -76
		and (tonumber(profile.powerBarOffsetY) or 0) == -49
		and (tonumber(profile.powerCaseOffsetX) or 0) == 0
		and (tonumber(profile.powerCaseOffsetY) or 0) == 50
		and (tonumber(profile.powerThreatBarOffsetX) or 0) == 76
		and (tonumber(profile.powerThreatBarOffsetY) or 0) == 52
		and (tonumber(profile.powerThreatCaseOffsetX) or 0) == 0
		and (tonumber(profile.powerThreatCaseOffsetY) or 0) == -34
		and (tonumber(profile.powerBarBaseOffsetX) or 0) == 0
		and (tonumber(profile.powerBarBaseOffsetY) or 0) == 0
		and (tonumber(profile.powerCaseBaseOffsetX) or 0) == 0
		and (tonumber(profile.powerCaseBaseOffsetY) or 0) == 0) then
		profile.powerBarOffsetX = 0
		profile.powerBarOffsetY = 0
		profile.powerCaseOffsetX = 0
		profile.powerCaseOffsetY = 0
		profile.powerThreatBarOffsetX = 0
		profile.powerThreatBarOffsetY = 0
		profile.powerThreatCaseOffsetX = 0
		profile.powerThreatCaseOffsetY = 0
		profile.powerBarBaseOffsetX = POWER_CRYSTAL_BASELINE_OFFSET_X
		profile.powerBarBaseOffsetY = POWER_CRYSTAL_BASELINE_OFFSET_Y
	end
	if (profile.powerCaseAnchorFrame == nil) then
		profile.powerCaseAnchorFrame = "POWER"
	end
	if (profile.powerThreatBarAnchorFrame == nil) then
		profile.powerThreatBarAnchorFrame = "POWER"
	end
	if (profile.powerThreatCaseAnchorFrame == nil) then
		profile.powerThreatCaseAnchorFrame = "POWER"
	end
	if (not profile.powerAnchorsRestoredToStock) then
		if (profile.powerCaseAnchorFrame == "FRAME") then
			profile.powerCaseAnchorFrame = "POWER"
		end
		if (profile.powerThreatBarAnchorFrame == "FRAME") then
			profile.powerThreatBarAnchorFrame = "POWER"
		end
		if (profile.powerThreatCaseAnchorFrame == "FRAME") then
			profile.powerThreatCaseAnchorFrame = "POWER"
		end
		profile.powerAnchorsRestoredToStock = true
	end
	if (profile.powerOffsetZeroMigrated == nil) then
		profile.powerBarBaseOffsetX = (tonumber(profile.powerBarBaseOffsetX) or 0) + (tonumber(profile.powerBarOffsetX) or 0)
		profile.powerBarBaseOffsetY = (tonumber(profile.powerBarBaseOffsetY) or 0) + (tonumber(profile.powerBarOffsetY) or 0)
		profile.powerCaseBaseOffsetX = (tonumber(profile.powerCaseBaseOffsetX) or 0) + (tonumber(profile.powerCaseOffsetX) or 0)
		profile.powerCaseBaseOffsetY = (tonumber(profile.powerCaseBaseOffsetY) or 0) + (tonumber(profile.powerCaseOffsetY) or 0)
		profile.powerBarOffsetX = 0
		profile.powerBarOffsetY = 0
		profile.powerCaseOffsetX = 0
		profile.powerCaseOffsetY = 0
		profile.powerOffsetZeroMigrated = true
	end
	if (not profile.powerCrystalBaselineApplied) then
		local baseX = tonumber(profile.powerBarBaseOffsetX) or 0
		local baseY = tonumber(profile.powerBarBaseOffsetY) or 0
		local offX = tonumber(profile.powerBarOffsetX) or 0
		local offY = tonumber(profile.powerBarOffsetY) or 0
		if (baseX == 0 and baseY == 0 and offX == 0 and offY == 0) then
			profile.powerBarBaseOffsetX = POWER_CRYSTAL_BASELINE_OFFSET_X
			profile.powerBarBaseOffsetY = POWER_CRYSTAL_BASELINE_OFFSET_Y
		end
		profile.powerCrystalBaselineApplied = true
	end
end

local UnitFrame_PostUpdate = function(self)
	UnitFrame_UpdateTextures(self)
end

-- Frame Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		playerXPDisabled = IsXPUserDisabled()
		playerLevel = UnitLevel("player")
		playerIsRetribution = playerClass == "PALADIN" and (ns.IsRetail and GetSpecialization() == SPEC_PALADIN_RETRIBUTION)

		self.Power:ForceUpdate()
		RefreshManaOrb(self, event, GetPlayerPowerUnit(self))

	elseif (event == "PLAYER_SPECIALIZATION_CHANGED") then
		playerIsRetribution = playerClass == "PALADIN" and (ns.IsRetail and GetSpecialization() == SPEC_PALADIN_RETRIBUTION)

		self.Power:ForceUpdate()
		RefreshManaOrb(self, event, GetPlayerPowerUnit(self))

	elseif (event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") then
		if (IsPlayerPowerUnit(unit) or IsPlayerPowerUnit(self.unit)) then
			if (self.Power and self.Power.ForceUpdate) then
				self.Power:ForceUpdate()
			end
			RefreshManaOrb(self, event, unit or GetPlayerPowerUnit(self))
		end

	elseif (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED") then
		self.Auras:ForceUpdate()
		if (self.Power and self.Power.ForceUpdate) then
			self.Power:ForceUpdate()
		end
		RefreshManaOrb(self, event, GetPlayerPowerUnit(self))

	elseif (event == "UNIT_ABSORB_AMOUNT_CHANGED") then
		if (unit == self.unit) then
			local eventAbsorb = select(1, ...)
			if (self.HealthPrediction) then
				-- Use event callback absorb as an extra numeric fallback source.
				UpdatePlayerAbsorbState(self.HealthPrediction, unit, eventAbsorb, self.Health and self.Health.safeMax or nil)
			end
			if (self.Health and self.Health.ForceUpdate) then
				self.Health:ForceUpdate()
			end
			if (self.Health and self.Health.Value and self.Health.Value.UpdateTag) then
				self.Health.Value:UpdateTag()
			end
			local apiTotalAbsorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or nil
			EmitAbsorbStateDebug(self, unit,
				"Event(Player) unit=%s callback=%s apiTotal=%s healthSafeAbsorb=%s",
				unit,
				eventAbsorb,
				apiTotalAbsorb,
				self.Health and self.Health.safeAbsorb or nil)
		end

	   elseif (event == "ENABLE_XP_GAIN") then
		   playerXPDisabled = false

	elseif (event == "DISABLE_XP_GAIN") then
		playerXPDisabled = true

	elseif (event == "PLAYER_LEVEL_UP") then
		playerLevel = UnitLevel("player")
	end

	UnitFrame_PostUpdate(self)
end

local style = function(self, unit)

	local config = ns.GetConfig("PlayerFrame")
	-- Pick the same profile key used by UnitFrame_UpdateTextures so we have
	-- non-nil sizing/texture data before the first PostUpdate runs.
	local key = (playerXPDisabled or IsLevelAtEffectiveMaxLevel(playerLevel)) and "Seasoned"
		or (playerLevel < 10 and "Novice")
		or "Hardened"
	local db = config[key] or config.Seasoned or config.Hardened or config.Novice or config

	self:SetSize(unpack(config.Size))
	self:SetHitRectInsets(unpack(config.HitRectInsets))
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
	health:DisableSmoothing(false) -- Re-enable linear smoothing for less stepped health motion
	-- WoW12 safe: no gradients, use oUF color paths.
	health.colorSmooth = false
	health.colorClass = PlayerFrameMod.db.profile.useClassColor
	health.colorHealth = true
	health.predictThreshold = .01

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor
	ns.API.BindStatusBarValueMirror(self.Health)

	self.Health.Spark = nil

	-- DEBUG: Show what's happening with secret values (toggle with /azdebughealth)
	local debugText = self:CreateFontString(nil, "OVERLAY")
	debugText:SetFontObject(GameFontNormal)
	debugText:SetPoint("BOTTOM", UIParent, "CENTER", 0, 200)
	debugText:SetWidth(800)
	debugText:SetJustifyH("LEFT")
	debugText:SetWordWrap(false)
	debugText:SetText("DEBUG")
	debugText:SetTextColor(1, 1, 0, 1)
	self.HealthDebug = debugText
	if (not ns.API.DEBUG_HEALTH) then
		debugText:Hide()
	end

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

	self.HealthPrediction = healPredict

	-- Cast Overlay
	--------------------------------------------
	local castbar = self:CreateBar()
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:DisableSmoothing(true)

	self.Castbar = castbar

	local castSpark = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	castSpark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	castSpark:SetBlendMode("ADD")
	castSpark:SetVertexColor(1, .95, .8, .85)
	castSpark:Hide()
	self.Castbar.Spark = castSpark

	-- Cast Name
	--------------------------------------------
	local castText = healthOverlay:CreateFontString(nil, "OVERLAY")
	castText:SetPoint(unpack(config.HealthValuePosition))
	castText:SetFontObject(config.CastBarTextFont)
	castText:SetTextColor(unpack(config.CastBarTextColor))
	castText:SetJustifyH(config.HealthValueJustifyH)
	castText:SetJustifyV(config.HealthValueJustifyV)
	castText:Hide()
	castText.color = config.CastBarTextColor or { 1, 1, 1, 1 }
	castText.colorProtected = config.CastBarTextProtectedColor or castText.color

	self.Castbar.Text = castText
	self.Castbar.PostCastInterruptible = Cast_PostCastInterruptible
	self.Castbar.PostCastStart = UpdateBarSpark
	self.Castbar.PostCastUpdate = UpdateBarSpark
	self.Castbar.PostCastStop = UpdateBarSpark
	self.Castbar.PostCastFail = UpdateBarSpark
	self.Castbar.PostCastInterrupted = UpdateBarSpark

	-- Cast Time
	--------------------------------------------
	local castTime = healthOverlay:CreateFontString(nil, "OVERLAY")
	castTime:SetPoint(unpack(config.CastBarValuePosition))
	castTime:SetFontObject(config.CastBarValueFont)
	castTime:SetTextColor(unpack(config.CastBarTextColor))
	castTime:SetJustifyH(config.CastBarValueJustifyH)
	castTime:SetJustifyV(config.CastBarValueJustifyV)
	castTime:Hide()

	self.Castbar.Time = castTime

	self.Castbar:HookScript("OnShow", Cast_UpdateTexts)
	self.Castbar:HookScript("OnHide", Cast_UpdateTexts)
	ns.API.AttachScriptSafe(self.Castbar, "OnValueChanged", function(source)
		UpdateBarSpark(source)
	end)
	ns.API.AttachScriptSafe(self.Castbar, "OnMinMaxChanged", function(source)
		UpdateBarSpark(source)
	end)

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY")
	healthValue:SetPoint(unpack(config.HealthValuePosition))
	healthValue:SetFontObject(config.HealthValueFont)
	healthValue:SetTextColor(unpack(config.HealthValueColor))
	healthValue:SetJustifyH(config.HealthValueJustifyH)
	healthValue:SetJustifyV(config.HealthValueJustifyV)
	if (ns.IsRetail) then
		-- Keep stock-like inline composition; absorb tag handles wrapped visuals.
		self:Tag(healthValue, prefix("[*:HealthCurrent]  [*:Absorb]"))
	else
		self:Tag(healthValue, prefix("[*:Health]"))
	end

	self.Health.Value = healthValue

	-- Health Percentage
	--------------------------------------------
	local healthPerc = healthValue:GetParent():CreateFontString(nil, "OVERLAY")
	if (config.HealthPercentagePosition) then
		healthPerc:SetPoint(unpack(config.HealthPercentagePosition))
	else
		healthPerc:SetPoint("LEFT", healthValue, "RIGHT", 18, 0)
	end
	healthPerc:SetFontObject(config.HealthPercentageFont or config.HealthValueFont)
	local healthPercColor = config.HealthPercentageColor or config.HealthValueColor or { 1, 1, 1, 1 }
	healthPerc:SetTextColor(healthPercColor[1], healthPercColor[2], healthPercColor[3], healthPercColor[4] or 1)
	healthPerc:SetJustifyH(config.HealthPercentageJustifyH or "LEFT")
	healthPerc:SetJustifyV(config.HealthPercentageJustifyV or "MIDDLE")
	self:Tag(healthPerc, prefix("[*:HealthPercent]"))
	healthPerc:Hide()  -- Hidden by default

	self.Health.Percent = healthPerc

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		if (absorb.SetForceNative) then absorb:SetForceNative(true) end
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		HidePlayerAbsorbBarVisual(absorb)
		if (absorb.HookScript) then
			absorb:HookScript("OnShow", function(source)
				HidePlayerAbsorbBarVisual(source)
			end)
		end

		--self.Health.absorbBar = absorb
	end

	-- Power Crystal
	local power = self:CreateBar()
	if (power.SetForceNative) then
		power:SetForceNative(true)
	end
	power:SetFrameLevel(self:GetFrameLevel() + CURRENT_POWER_CRYSTAL_LAYOUT.frameLevelOffset)
	local powerPos = db[CURRENT_POWER_CRYSTAL_LAYOUT.barPointKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barPointKey] or { "CENTER", 0, 0 }
	local powerSize = db[CURRENT_POWER_CRYSTAL_LAYOUT.barSizeKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barSizeKey] or { 80, 80 }
	power:SetPoint(unpack(powerPos))
	power:SetSize(unpack(powerSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	local ptex = power:GetStatusBarTexture()
	local powerTexCoord = db[CURRENT_POWER_CRYSTAL_LAYOUT.barTexCoordKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barTexCoordKey]
	if ptex and ptex.SetTexCoord and powerTexCoord then
		local texCoordAdjust = (PlayerFrameMod.db.profile and tonumber(PlayerFrameMod.db.profile.powerBarTexCoordAdjust)) or 0
		local adjustedCoord = GetAdjustedTexCoord(powerTexCoord, texCoordAdjust)
		ptex:SetTexCoord(unpack(adjustedCoord))
	end
	power:SetOrientation(db[CURRENT_POWER_CRYSTAL_LAYOUT.barOrientationKey] or db[STOCK_POWER_CRYSTAL_LAYOUT.barOrientationKey] or "UP")
	power:SetAlpha(db.PowerBarAlpha or 1)
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true
	power.GetDisplayPower = function(element)
		local owner = element and element.__owner
		local unitToken = GetPlayerPowerUnit(owner)
		if (ns.IsRetail and playerClass == "SHAMAN" and GetSpecialization and GetSpecialization() == SPEC_SHAMAN_ELEMENTAL) then
			if (GetElementalMaelstromDisplayMode() == "crystal_mana") then
				return POWER_TYPE_MANA, 0
			end
		end
		return UnitPowerType(unitToken)
	end
	power.smoothing = nil
	power.__AzeriteUI_DisableTexturePercentMirror = true
	power.__AzeriteUI_KeepMirrorPercentOnNoSample = true
	-- Seed safe numeric values
	power.safeBarMin = 0
	power.safeBarMax = 1
	power.safeBarValue = 1
	if (ptex and ptex.GetTexCoord) then
		local left, right, top, bottom = ptex:GetTexCoord()
		power.__AzeriteUI_BaseTexCoordLeft = left
		power.__AzeriteUI_BaseTexCoordRight = right
		power.__AzeriteUI_BaseTexCoordTop = top
		power.__AzeriteUI_BaseTexCoordBottom = bottom
	end

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	ns.API.BindStatusBarValueMirror(self.Power)
	self.Power.PostUpdate = Power_UpdateVisibility
	self.Power.PostUpdateColor = not (PlayerFrameMod.db.profile.useWrathCrystal or ns.API.IsWinterVeil()) and Power_PostUpdateColor

	local powerFakeFill = power:CreateTexture(nil, "ARTWORK", nil, 1)
	powerFakeFill:SetAllPoints(power)
	powerFakeFill:SetBlendMode("BLEND")
	powerFakeFill:SetAlpha(1)
	powerFakeFill:Hide()
	self.Power.FakeFill = powerFakeFill

	local powerSpark = power:CreateTexture(nil, "OVERLAY", nil, 3)
	powerSpark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	powerSpark:SetBlendMode("ADD")
	powerSpark:SetVertexColor(1, .9, .7, .9)
	powerSpark:SetSize(60, 12)
	powerSpark:Hide()
	self.Power.Spark = powerSpark

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -2)
	local powerCase = power:CreateTexture(nil, "ARTWORK", nil, 2)

	self.Power.Backdrop = powerBackdrop
	self.Power.Case = powerCase

	-- Power Value
	--------------------------------------------
	local powerValue = power:CreateFontString(nil, "OVERLAY")
	powerValue:SetPoint(unpack(config.PowerValuePosition))
	powerValue:SetFontObject(config.PowerValueFont)
	powerValue:SetTextColor(unpack(config.PowerValueColor))
	powerValue:SetJustifyH(config.PowerValueJustifyH)
	powerValue:SetJustifyV(config.PowerValueJustifyV)

	self.Power.Value = powerValue
	UpdatePlayerPowerValueTag(self)

	-- Power Percentage
	--------------------------------------------
	local powerPerc = power:CreateFontString(nil, "OVERLAY")
	if (config.PowerPercentagePosition) then
		powerPerc:SetPoint(unpack(config.PowerPercentagePosition))
	else
		powerPerc:SetPoint("TOP", powerValue, "BOTTOM", 0, -2)
	end
	powerPerc:SetFontObject(config.PowerPercentageFont or config.PowerValueFont)
	local powerPercColor = config.PowerPercentageColor or config.PowerValueColor or { 1, 1, 1, 1 }
	powerPerc:SetTextColor(powerPercColor[1], powerPercColor[2], powerPercColor[3], powerPercColor[4] or 1)
	powerPerc:SetJustifyH(config.PowerPercentageJustifyH or "CENTER")
	powerPerc:SetJustifyV(config.PowerPercentageJustifyV or "TOP")
	self:Tag(powerPerc, prefix("[*:PowerPercent]"))
	powerPerc:Hide() -- Hide power percentage

	self.Power.Percent = powerPerc

	-- ManaText Value
	-- *when mana isn't primary resource
	--------------------------------------------
	local manaText = power:CreateFontString(nil, "OVERLAY")
	manaText:SetPoint(unpack(config.ManaTextPosition))
	manaText:SetFontObject(config.ManaTextFont)
	manaText:SetTextColor(unpack(config.ManaTextColor))
	manaText:SetJustifyH(config.ManaTextJustifyH)
	manaText:SetJustifyV(config.ManaTextJustifyV)
	self:Tag(manaText, prefix("[*:ManaText:Low]"))

	self.Power.ManaText = manaText

	-- Mana Orb
	--------------------------------------------
	local mana = self:CreateOrb(self:GetName().."ManaOrb")
	mana:SetFrameLevel(self:GetFrameLevel() - 2)
	mana.frequentUpdates = true
	mana.smoothing = nil
	mana.displayAltPower = true
	mana.colorPower = false
	mana.__owner = self
	if (type(db.ManaOrbTexture) == "table") then
		mana:SetStatusBarTexture(unpack(db.ManaOrbTexture))
	else
		mana:SetStatusBarTexture(db.ManaOrbTexture)
	end
	mana:SetStatusBarColor(unpack(config.PowerOrbColors.MANA))
	do
		local tex1, tex2 = mana:GetStatusBarTexture()
		if (tex2 and tex2.SetTexCoord) then
			tex2:SetTexCoord(1, 0, 1, 0)
		end
		if (tex1 and tex1.SetTexCoord) then
			tex1:SetTexCoord(0, 1, 0, 1)
		end
	end
	mana:EnableMouse(true)
	if (mana.SetMouseClickEnabled) then
		mana:SetMouseClickEnabled(false)
	end
	mana:SetScript("OnEnter", Power_OnEnter)
	mana:SetScript("OnLeave", Power_OnLeave)
	mana.OnEnter = Power_OnMouseOver
	mana.OnLeave = Power_OnMouseOver

	self.ManaOrb = mana
	self.ManaOrb.Override = ns.API.UpdateManaOrb
	self.ManaOrb.PostUpdate = Mana_PostUpdate
	self.ManaOrb.ForceUpdate = function(element)
		local owner = element and element.__owner
		if (owner) then
			return ns.API.UpdateManaOrb(owner, "ForceUpdate", GetPlayerPowerUnit(owner))
		end
	end

	local manaCaseFrame = CreateFrame("Frame", nil, mana)
	manaCaseFrame:SetFrameLevel(mana:GetFrameLevel() + 4)
	manaCaseFrame:SetAllPoints()

	local manaBackdrop = mana:CreateTexture(nil, "BACKGROUND", nil, -2)
	local manaShade = manaCaseFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	local manaCase = manaCaseFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	local manaGlass = manaCaseFrame:CreateTexture(nil, "BORDER")
	local manaArtwork = manaCaseFrame:CreateTexture(nil, "OVERLAY", nil, 1)

	self.ManaOrb.Backdrop = manaBackdrop
	self.ManaOrb.Shade = manaShade
	self.ManaOrb.Case = manaCase
	self.ManaOrb.Glass = manaGlass
	self.ManaOrb.Artwork = manaArtwork

	-- Mana Orb Value
	--------------------------------------------
	local manaValue = manaCaseFrame:CreateFontString(nil, "OVERLAY")
	manaValue:SetPoint(unpack(config.ManaValuePosition))
	manaValue:SetFontObject(config.ManaValueFont)
	ApplyScaledValueFont(manaValue, ClampPowerValueTextScale(PlayerFrameMod.db.profile.powerValueTextScale), true)
	manaValue:SetTextColor(unpack(config.ManaValueColor))
	manaValue:SetJustifyH(config.ManaValueJustifyH)
	manaValue:SetJustifyV(config.ManaValueJustifyV)

	self.ManaOrb.Value = manaValue
	UpdatePlayerManaValueTag(self)

	-- Mana Percentage
	--------------------------------------------
	local manaPerc = manaCaseFrame:CreateFontString(nil, "OVERLAY")
	if (config.ManaPercentagePosition) then
		manaPerc:SetPoint(unpack(config.ManaPercentagePosition))
	else
		manaPerc:SetPoint("TOP", manaValue, "BOTTOM", 0, -2)
	end
	manaPerc:SetFontObject(config.ManaPercentageFont or config.ManaValueFont)
	local manaPercColor = config.ManaPercentageColor or config.ManaValueColor or { 1, 1, 1, 1 }
	manaPerc:SetTextColor(manaPercColor[1], manaPercColor[2], manaPercColor[3], manaPercColor[4] or 1)
	manaPerc:SetJustifyH(config.ManaPercentageJustifyH or "CENTER")
	manaPerc:SetJustifyV(config.ManaPercentageJustifyV or "TOP")
	self:Tag(manaPerc, prefix("[*:ManaPercent]"))
	manaPerc:Hide() -- Hide mana percentage

	self.ManaOrb.Percent = manaPerc
	ApplyPlayerPowerValueAlpha(self)
	RefreshManaOrb(self, "StyleInit", GetPlayerPowerUnit(self))

	-- CombatFeedback Text
	--------------------------------------------
	local feedbackText = overlay:CreateFontString(nil, "OVERLAY")
	feedbackText:SetPoint(config.CombatFeedbackPosition[1], self[config.CombatFeedbackAnchorElement], unpack(config.CombatFeedbackPosition))
	feedbackText:SetFontObject(config.CombatFeedbackFont)

	self.CombatFeedback = feedbackText

	-- Combat Indicator
	--------------------------------------------
	local combatIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, -2)
	combatIndicator:SetSize(unpack(config.CombatIndicatorSize))
	combatIndicator:SetPoint(unpack(config.CombatIndicatorPosition))
	combatIndicator:SetTexture(config.CombatIndicatorTexture)
	combatIndicator:SetVertexColor(unpack(config.CombatIndicatorColor))

	self.CombatIndicator = combatIndicator

	-- PvP Indicator
	--------------------------------------------
	local PvPIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, -2)
	PvPIndicator:SetSize(unpack(config.PvPIndicatorSize))
	PvPIndicator:SetPoint(unpack(config.PvPIndicatorPosition))

	self.PvPIndicator = PvPIndicator

	-- Threat Indicator
	--------------------------------------------
	local threatIndicator = CreateFrame("Frame", nil, self)
	threatIndicator:SetFrameLevel(self:GetFrameLevel() - 2)
	threatIndicator:SetAllPoints()

	threatIndicator.textures = {
		Health = threatIndicator:CreateTexture(nil, "BACKGROUND", nil, -3),
		PowerBar = power:CreateTexture(nil, "BACKGROUND", nil, -3),
		PowerBackdrop = power:CreateTexture(nil, "ARTWORK", nil, 1),
		ManaOrb = mana:CreateTexture(nil, "BACKGROUND", nil, -3),
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

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(unpack(config.AurasSize))
	auras:SetPoint(unpack(config.AurasPosition))
	auras.size = config.AuraSize
	auras.spacing = config.AuraSpacing
	auras.numTotal = config.AurasNumTotal
	auras.disableMouse = config.AurasDisableMouse
	auras.disableCooldown = config.AurasDisableCooldown
	auras.onlyShowPlayer = config.AurasOnlyShowPlayer
	auras.showStealableBuffs = config.AurasShowStealableBuffs
	auras.showBuffType = false
	auras.showDebuffType = true
	auras.initialAnchor = config.AurasInitialAnchor
	auras["spacing-x"] = config.AurasSpacingX
	auras["spacing-y"] = config.AurasSpacingY
	auras["growth-x"] = config.AurasGrowthX
	auras["growth-y"] = config.AurasGrowthY
	auras.tooltipAnchor = config.AurasTooltipAnchor
	auras.sortMethod = config.AurasSortMethod
	auras.sortDirection = config.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.allowCombatUpdates = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.PlayerPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.PlayerAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.PlayerAuraFilter -- retail
	auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
	auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Auras = auras

	-- Seasonal Flavors
	--------------------------------------------
	-- Feast of Winter Veil
	if (ns.API.IsWinterVeil()) then
		local winterVeilPower = power:CreateTexture(nil, "OVERLAY", nil, 0)
		winterVeilPower:SetSize(unpack(config.Seasonal.WinterVeilPowerSize))
		winterVeilPower:SetPoint(unpack(config.Seasonal.WinterVeilPowerPlace))
		winterVeilPower:SetTexture(config.Seasonal.WinterVeilPowerTexture)

		self.Power.WinterVeil = winterVeilPower

		local winterVeilMana = manaCaseFrame:CreateTexture(nil, "OVERLAY", nil, 0)
		winterVeilMana:SetSize(unpack(config.Seasonal.WinterVeilManaSize))
		winterVeilMana:SetPoint(unpack(config.Seasonal.WinterVeilManaPlace))
		winterVeilMana:SetTexture(config.Seasonal.WinterVeilManaTexture)

		self.ManaOrb.WinterVeil = winterVeilMana
	end

	-- Love is in the Air
	if (ns.API.IsLoveFestival()) then
		combatIndicator:SetSize(unpack(config.Seasonal.LoveFestivalCombatIndicatorSize))
		combatIndicator:ClearAllPoints()
		combatIndicator:SetPoint(unpack(config.Seasonal.LoveFestivalCombatIndicatorPosition))
		combatIndicator:SetTexture(config.Seasonal.LoveFestivalCombatIndicatorTexture)
		combatIndicator:SetVertexColor(unpack(config.Seasonal.LoveFestivalCombatIndicatorColor))
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
		self:RegisterEvent("UNIT_POWER_UPDATE", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_POWER_FREQUENT", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_MAXPOWER", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_DISPLAYPOWER", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", UnitFrame_OnEvent)
		self:RegisterEvent("UNIT_EXITED_VEHICLE", UnitFrame_OnEvent)
		--self:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", UnitFrame_OnEvent)

		if (playerClass == "PALADIN") then
			self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", UnitFrame_OnEvent)
		end
	end

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate

end

PlayerFrameMod.CreateUnitFrames = function(self)

	local unit, name = "player", "Player"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)

	local enabled = true

	self.frame.Enable = function(self)
		enabled = true
		local ok = pcall(RegisterAttributeDriver, self, "unit", "[vehicleui]vehicle; player")
		if (not ok) then
			-- Taint/lockdown fallback: keep the frame visible on player unit
			-- and retry secure driver registration when combat ends.
			pcall(self.SetAttribute, self, "unit", "player")
			PlayerFrameMod:RegisterEvent("PLAYER_REGEN_ENABLED", "RetryEnableDriver")
		end
		self:Show()
	end

	self.frame.Disable = function(self)
		enabled = false
		pcall(UnregisterAttributeDriver, self, "unit")
		self:Hide()
	end

	self.frame.IsEnabled = function(self)
		return enabled
	end

	UnregisterUnitWatch(self.frame)
	self.frame:SetAttribute("toggleForVehicle", false)

end

PlayerFrameMod.RetryEnableDriver = function(self)
	if (InCombatLockdown()) then
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "RetryEnableDriver")
	if (not self.frame or not self.frame.IsEnabled or not self.frame:IsEnabled()) then
		return
	end
	pcall(UnregisterAttributeDriver, self.frame, "unit")
	pcall(RegisterAttributeDriver, self.frame, "unit", "[vehicleui]vehicle; player")
end

PlayerFrameMod.Update = function(self)
	UpdatePlayerPowerValueTag(self.frame)
	UpdatePlayerManaValueTag(self.frame)
	ApplyPlayerPowerValueTextScale(self.frame)
	ApplyPlayerPowerValueAlpha(self.frame)

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

	if (self.db.profile.useWrathCrystal or ns.API.IsWinterVeil()) then
		self.frame.Power.colorPower = false
		self.frame.Power.PostUpdateColor = nil
		self.frame.Power:SetStatusBarColor(1,1,1,1)
	else
		self.frame.Power.colorPower = true
		self.frame.Power.PostUpdateColor = Power_PostUpdateColor
	end

	UpdateManaOrbVisibility(self.frame, GetPlayerPowerUnit(self.frame))

	if (self.frame:IsElementEnabled("Power")) then
		self.frame.Power:ForceUpdate()
	end
	RefreshManaOrb(self.frame, "Update", GetPlayerPowerUnit(self.frame))

	self.frame:PostUpdate()
end

PlayerFrameMod.OnEnable = function(self)
	NormalizePowerOffsetBaseline(self)

	-- Disable Blizzard player alternate power bar only on WoW10,
	-- in WoW11 let Blizzard show it (some encounters/tutorials rely on it).
	if (ns.WoW10 and PlayerPowerBarAlt) then
		PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
		PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_HIDE")
		PlayerPowerBarAlt:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end

	self:CreateUnitFrames()
	self:CreateAnchor(HUD_EDIT_MODE_PLAYER_FRAME_LABEL or PLAYER)

	ns.MovableModulePrototype.OnEnable(self)
end






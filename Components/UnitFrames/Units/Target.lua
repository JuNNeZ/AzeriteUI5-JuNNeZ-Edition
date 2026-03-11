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

local TargetFrameMod = ns:NewModule("TargetFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local AbbreviateNumbers = AbbreviateNumbers
local BreakUpLargeNumbers = BreakUpLargeNumbers
local next = next
local string_gsub = string.gsub
local type = type
local unpack = unpack
local math_floor = math.floor
local math_max = math.max
local Mixin = _G.Mixin
local Enum = _G.Enum
local UnitGUID = _G.UnitGUID

-- Addon API
local Colors = ns.Colors

-- Constants
local playerLevel = UnitLevel("player")

local defaults = { profile = ns:Merge({
	showAuras = true,
	showCastbar = true,
	showName = true,
	showPowerValue = true,
	PowerValueFormat = "short",
	aurasBelowFrame = false,
	useStandardBossTexture = false,
	useStandardCritterTexture = false,
	AurasMaxCols = 0,
	AuraSize = 36,
	AurasSpacingX = 4,
	AurasSpacingY = 4,
	AurasGrowthX = "LEFT",
	AurasGrowthY = "DOWN",
	AurasInitialAnchor = "TOPRIGHT",
	healthLabCastUseHealthFillRules = true,
	healthBarOffsetX = 0,
	healthBarOffsetY = 0,
	healthBarScaleX = 100,
	healthBarScaleY = 100,
	bossHealthBarOffsetX = 0,
	bossHealthBarOffsetY = 0,
	bossHealthBarScaleX = 100,
	bossHealthBarScaleY = 100,
	critterHealthBarOffsetX = 0,
	critterHealthBarOffsetY = 0,
	critterHealthBarScaleX = 100,
	critterHealthBarScaleY = 100,
	castBarOffsetX = 0,
	castBarOffsetY = 0,
	castBarScaleX = 100,
	castBarScaleY = 100,
	castBarFollowHealth = false,
	healthLabCastOffsetX = 0,
	healthLabCastOffsetY = 0,
	healthLabCastWidthScale = 100,
	healthLabCastHeightScale = 100,
	healthLabCastAnchorFrame = "HEALTH",
	powerBarAnchorFrame = "FRAME",
	powerBackdropAnchorFrame = "POWER",
	powerValueAnchorFrame = "POWER",
	powerBarOffsetX = 0,
	powerBarOffsetY = 0,
	powerBackdropOffsetX = 0,
	powerBackdropOffsetY = 0,
	powerValueOffsetX = 0,
	powerValueOffsetY = 0,
	powerBarScaleX = 100,
	powerBarScaleY = 100,
	powerBackdropScaleX = 100,
	powerBackdropScaleY = 100,
	powerBarArtLayer = 0
}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
TargetFrameMod.GenerateDefaults = function(self)
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "TOPRIGHT",
		[2] = -40 * ns.API.GetEffectiveScale(),
		[3] = -40 * ns.API.GetEffectiveScale()
	}
	return defaults
end

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

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

local GetOppositeOrientation = function(orientation)
	if (orientation == "UP") then
		return "DOWN"
	elseif (orientation == "DOWN") then
		return "UP"
	elseif (orientation == "LEFT") then
		return "RIGHT"
	end
	return "LEFT"
end

local GetTargetHealthLabSettings = function(styleData, isFlipped)
	local profile = TargetFrameMod and TargetFrameMod.db and TargetFrameMod.db.profile or {}
	local settings = {}
	settings.orientation = styleData.HealthBarOrientation

	settings.absorbOrientation = GetOppositeOrientation(settings.orientation)
	if (type(profile.castBarOffsetX) == "number") then
		settings.castOffsetX = profile.castBarOffsetX
	else
		settings.castOffsetX = (type(profile.healthLabCastOffsetX) == "number") and profile.healthLabCastOffsetX or 0
	end
	if (type(profile.castBarOffsetY) == "number") then
		settings.castOffsetY = profile.castBarOffsetY
	else
		settings.castOffsetY = (type(profile.healthLabCastOffsetY) == "number") and profile.healthLabCastOffsetY or 0
	end
	if (type(profile.castBarScaleX) == "number") then
		settings.castWidthScale = profile.castBarScaleX
	else
		settings.castWidthScale = (type(profile.healthLabCastWidthScale) == "number") and profile.healthLabCastWidthScale or 100
	end
	if (type(profile.castBarScaleY) == "number") then
		settings.castHeightScale = profile.castBarScaleY
	else
		settings.castHeightScale = (type(profile.healthLabCastHeightScale) == "number") and profile.healthLabCastHeightScale or 100
	end
	settings.castAnchorFrame = (type(profile.healthLabCastAnchorFrame) == "string") and profile.healthLabCastAnchorFrame or "HEALTH"
	settings.castFollowsHealth = (type(profile.castBarFollowHealth) == "boolean") and profile.castBarFollowHealth or false

	return settings
end

local GetTargetFillTexCoords = function(percent)
	if (type(percent) ~= "number") then
		return 1, 0, 0, 1
	end
	if (percent < 0) then
		percent = 0
	elseif (percent > 1) then
		percent = 1
	end
	return percent, 0, 0, 1
end

local IsTargetBossUnit = function(unit, level, classification)
	if (not unit or not UnitExists(unit)) then
		return false
	end
	if (type(UnitIsBossMob) == "function") then
		local ok, isBoss = pcall(UnitIsBossMob, unit)
		if (ok and isBoss == true) then
			return true
		end
	end
	if (classification == "boss" or classification == "worldboss") then
		return true
	end
	return type(level) == "number" and level < 1
end

local ResolveTargetAnchorFrame = function(frame, key)
	if (not frame) then
		return nil
	end
	if (key == "HEALTH") then
		return frame.Health
	elseif (key == "HEALTH_OVERLAY") then
		return frame.Health and frame.Health.Overlay
	elseif (key == "HEALTH_BACKDROP") then
		return frame.Health and frame.Health.Backdrop
	end
	return frame
end

local ResolveTargetPowerAnchorFrame = function(frame, key)
	if (not frame) then
		return nil
	end
	if (key == "POWER") then
		return frame.Power
	elseif (key == "POWER_BACKDROP") then
		return frame.Power and frame.Power.Backdrop
	elseif (key == "HEALTH") then
		return frame.Health
	elseif (key == "FRAME") then
		return frame
	end
	return frame
end

local ResolveTargetCastFakeAnchorFrame = function(frame, key)
	if (not frame) then
		return nil
	end
	if (key == "CAST") then
		return frame.Castbar
	end
	return ResolveTargetAnchorFrame(frame, key)
end

local ClampTargetPowerLayer = function(value, defaultValue)
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

local CanAccessTargetValue = function(value)
	if (not issecretvalue or not issecretvalue(value)) then
		return true
	end
	if (canaccessvalue) then
		local ok, readable = pcall(canaccessvalue, value)
		if (ok and readable) then
			return true
		end
	end
	return false
end

local IsSafeNumber = function(value)
	return (type(value) == "number") and CanAccessTargetValue(value)
end

local TargetAuraAnchorValues = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true
}

local TargetAuraGrowthXValues = {
	LEFT = true,
	RIGHT = true
}

local TargetAuraGrowthYValues = {
	UP = true,
	DOWN = true
}

local GetTargetAuraNumber = function(value, fallback, minimum)
	local numeric = tonumber(value)
	if (type(numeric) ~= "number" or (issecretvalue and issecretvalue(numeric))) then
		numeric = fallback
	end
	if (type(numeric) ~= "number") then
		return nil
	end
	if (type(minimum) == "number" and numeric < minimum) then
		numeric = minimum
	end
	return numeric
end

local NormalizeTargetAuraValue = function(value, allowed, fallback)
	if (type(value) == "string") then
		local upper = value:upper()
		if (allowed[upper]) then
			return upper
		end
	end
	return fallback
end

local ApplyTargetAuraLayout = function(frame, styleKey)
	if (not frame or not frame.Auras) then
		return
	end

	local config = ns.GetConfig("TargetFrame")
	local profile = TargetFrameMod and TargetFrameMod.db and TargetFrameMod.db.profile or {}
	local auras = frame.Auras
	local isBossStyle = (styleKey == "Boss")
	local auraFrameSize = isBossStyle and config.AurasSizeBoss or config.AurasSize
	local auraNumTotal = isBossStyle and config.AurasNumTotalBoss or config.AurasNumTotal
	local auraSizeDefault = config.AuraSize or 16
	local auraSpacingDefault = config.AuraSpacing or 0
	local auraSpacingXDefault = config.AurasSpacingX or auraSpacingDefault
	local auraSpacingYDefault = config.AurasSpacingY or auraSpacingDefault
	local auraGrowthXDefault = NormalizeTargetAuraValue(config.AurasGrowthX, TargetAuraGrowthXValues, "LEFT")
	local auraGrowthYDefault = NormalizeTargetAuraValue(config.AurasGrowthY, TargetAuraGrowthYValues, "DOWN")
	local auraAnchorDefault = NormalizeTargetAuraValue(config.AurasInitialAnchor, TargetAuraAnchorValues, "TOPRIGHT")

	local auraSize = GetTargetAuraNumber(profile.AuraSize, auraSizeDefault, 1)
	local auraSpacingX = GetTargetAuraNumber(profile.AurasSpacingX, auraSpacingXDefault)
	local auraSpacingY = GetTargetAuraNumber(profile.AurasSpacingY, auraSpacingYDefault)
	local auraMaxCols = GetTargetAuraNumber(profile.AurasMaxCols, 0)
	if (type(auraMaxCols) == "number") then
		auraMaxCols = math_floor(auraMaxCols + 0.5)
	end
	if (type(auraMaxCols) ~= "number" or auraMaxCols <= 0) then
		auraMaxCols = nil
	end

	local auraGrowthX = NormalizeTargetAuraValue(profile.AurasGrowthX, TargetAuraGrowthXValues, auraGrowthXDefault)
	local auraGrowthY = NormalizeTargetAuraValue(profile.AurasGrowthY, TargetAuraGrowthYValues, auraGrowthYDefault)
	local auraAnchor = NormalizeTargetAuraValue(profile.AurasInitialAnchor, TargetAuraAnchorValues, auraAnchorDefault)

	if (auraFrameSize and auraFrameSize[1] and auraFrameSize[2]) then
		auras:SetSize(unpack(auraFrameSize))
	end
	auras.numTotal = auraNumTotal
	auras.size = auraSize
	auras.spacing = auraSpacingDefault
	auras.spacingX = auraSpacingX
	auras.spacingY = auraSpacingY
	auras.growthX = auraGrowthX
	auras.growthY = auraGrowthY
	auras.initialAnchor = auraAnchor
	auras.maxCols = auraMaxCols
	auras["spacing-x"] = auraSpacingX
	auras["spacing-y"] = auraSpacingY
	auras["growth-x"] = auraGrowthX
	auras["growth-y"] = auraGrowthY
	auras["max-cols"] = auraMaxCols
end

local SetPointWithAnchorAndOffset = function(frame, pointData, offsetX, offsetY, anchorFrame)
	if (not frame or not pointData or not pointData[1]) then
		return
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
		frame:SetPoint(pointData[1], pointData[2], pointData[3], (pointData[4] or 0) + x, (pointData[5] or 0) + y)
	end
end

local ApplyTargetSimpleHealthFakeFillByPercent

local HideTargetNativeHealthVisuals

local ClampTargetSparkPercent = function(value)
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

local NormalizeTargetDisplayPercent = function(value)
	if (type(value) ~= "number") or (issecretvalue and issecretvalue(value)) then
		return nil
	end
	if (value <= 1) then
		value = value * 100
	end
	if (value < 0) then
		value = 0
	elseif (value > 100) then
		value = 100
	end
	return value
end

local GetTargetBarSparkPercent = function(element, percentOverride)
	local percent = ClampTargetSparkPercent(percentOverride)
	if (percent ~= nil) then
		return percent
	end
	if (not element) then
		return nil
	end
	percent = ClampTargetSparkPercent(element.__AzeriteUI_TargetSparkPercent)
		or ClampTargetSparkPercent(element.__AzeriteUI_CastFakePercent)
	if (percent ~= nil) then
		return percent
	end
	if (element.GetSecretPercent) then
		local ok, value = pcall(element.GetSecretPercent, element)
		if (ok) then
			percent = ClampTargetSparkPercent(value)
			if (percent ~= nil) then
				return percent
			end
		end
	end
	return ClampTargetSparkPercent(element.__AzeriteUI_MirrorPercent)
		or ClampTargetSparkPercent(element.__AzeriteUI_TexturePercent)
end

local UpdateTargetBarSparkSize = function(element)
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

local UpdateTargetBarSpark = function(element, percentOverride)
	local spark = element and element.Spark
	if (not spark) then
		return
	end
	if (spark.requiresConfigKey) then
		local config = ns.GetConfig("TargetFrame")
		if (not config[spark.requiresConfigKey]) then
			spark:Hide()
			return
		end
	end
	local percent = GetTargetBarSparkPercent(element, percentOverride)
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

ApplyTargetSimpleHealthFakeFillByPercent = function(health, percent)
	if (not health) then
		return false
	end

	local fakeFill = health.FakeFill
	if (not fakeFill) then
		return false
	end

	local nativeTexture = health.GetStatusBarTexture and health:GetStatusBarTexture()

	fakeFill:ClearAllPoints()
	if (nativeTexture) then
		fakeFill:SetAllPoints(nativeTexture)
	else
		fakeFill:SetAllPoints(health)
	end
	if (percent == nil) then
		fakeFill:SetTexCoord(1, 0, 0, 1)
	else
		fakeFill:SetTexCoord(percent, 0, 0, 1)
	end
	if (fakeFill.SetVertexColor) then
		local r, g, b = health:GetStatusBarColor()
		if (type(r) == "number" and type(g) == "number" and type(b) == "number") then
			fakeFill:SetVertexColor(r, g, b, 1)
		else
			fakeFill:SetVertexColor(1, 1, 1, 1)
		end
	end
	if (fakeFill.SetAlpha) then
		fakeFill:SetAlpha(1)
	end
	fakeFill:Show()
	return true
end

local UpdateTargetHealthFakeFillFromBar = function(health)
	if (not health) then
		return false
	end
	local fakeFill = health.FakeFill
	if (not fakeFill) then
		return false
	end
	local owner = health.__owner
	local unit = health.unit or (owner and owner.unit) or "target"
	local percent, source
	if (type(UnitHealthPercent) == "function") then
		local ok, value = pcall(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ZeroToOne or nil)
		if (ok) then
			percent = value
			source = "api"
		end
	end
	local applied = false
	if (source == "api") then
		applied = pcall(ApplyTargetSimpleHealthFakeFillByPercent, health, percent)
	elseif (percent == nil) then
		applied = ApplyTargetSimpleHealthFakeFillByPercent(health, nil)
	end
	if (applied) then
		local displayPercent = NormalizeTargetDisplayPercent(percent)
		if (type(displayPercent) == "number") then
			health.safePercent = displayPercent
		end
		health.__AzeriteUI_TargetFakeSource = source
		health.__AzeriteUI_TargetSparkPercent = ClampTargetSparkPercent(percent)
		UpdateTargetBarSpark(health, percent)
		return true
	end

	health.__AzeriteUI_TargetFakeSource = "none"
	health.__AzeriteUI_TargetSparkPercent = nil
	fakeFill:SetTexCoord(1, 0, 0, 1)
	fakeFill:Show()
	UpdateTargetBarSpark(health, nil)
	return false
end

local SyncTargetHealthVisualState = function(health)
	if (not health) then
		return false
	end
	HideTargetNativeHealthVisuals(health)
	local updated = UpdateTargetHealthFakeFillFromBar(health)
	UpdateTargetBarSpark(health, nil)
	return updated
end

HideTargetNativeHealthVisuals = function(health)
	if (not health) then
		return
	end
	local nativeTexture = health.GetStatusBarTexture and health:GetStatusBarTexture()
	if (nativeTexture) then
		if (nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(0)
		end
	end
	local preview = health.Preview
	if (preview) then
		if (preview.SetAlpha) then
			preview:SetAlpha(0)
		end
		if (preview.Hide) then
			preview:Hide()
		end
		local previewTexture = preview.GetStatusBarTexture and preview:GetStatusBarTexture()
		if (previewTexture) then
			if (previewTexture.SetAlpha) then
				previewTexture:SetAlpha(0)
			end
			if (previewTexture.Hide) then
				previewTexture:Hide()
			end
		end
	end
end

local HideTargetNativeCastVisuals = function(cast)
	if (not cast) then
		return
	end
	if (cast.__AzeriteUI_UseNativeCastVisual) then
		return
	end
	local nativeTexture = cast.GetStatusBarTexture and cast:GetStatusBarTexture()
	if (nativeTexture) then
		if (nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(0)
		end
		-- Keep it shown at alpha 0 so native geometry still updates,
		-- which our fallback fake-fill sampling depends on.
		if (nativeTexture.Show) then
			nativeTexture:Show()
		end
	end
end

local ApplyTargetSimpleCastFakeFillByPercent = function(cast, percent)
	if (not cast) then
		return false
	end
	local fakeFill = cast.FakeFill
	if (not fakeFill) then
		return false
	end
	local nativeTexture = cast.GetStatusBarTexture and cast:GetStatusBarTexture()
	fakeFill:ClearAllPoints()
	if (nativeTexture) then
		fakeFill:SetAllPoints(nativeTexture)
	else
		fakeFill:SetAllPoints(cast)
	end
	if (percent == nil) then
		fakeFill:SetTexCoord(1, 0, 0, 1)
		fakeFill:Show()
		return true
	end
	if (percent < 0) then
		percent = 0
	elseif (percent > 1) then
		percent = 1
	end
	if (percent <= 0) then
		fakeFill:Hide()
		return true
	end
	fakeFill:SetTexCoord(percent, 0, 0, 1)
	fakeFill:Show()
	return true
end

local ApplyTargetFakeCastVertexColor
local GetTargetCastTimerPayload

local GetTargetCastFakeAlpha = function(cast)
	if (not cast) then
		return 1
	end
	local configuredAlpha = cast.__AzeriteUI_FakeConfiguredAlpha
	if (type(configuredAlpha) ~= "number" or (issecretvalue and issecretvalue(configuredAlpha))) then
		return 1
	end
	if (configuredAlpha < 0) then
		return 0
	elseif (configuredAlpha > 1) then
		return 1
	end
	return configuredAlpha
end

ApplyTargetFakeCastVertexColor = function(cast)
	if (not cast) then
		return
	end
	local fakeFill = cast.FakeFill
	if (not fakeFill or not fakeFill.SetVertexColor) then
		return
	end
	local alpha = GetTargetCastFakeAlpha(cast)
	if (cast.GetStatusBarColor) then
		local r, g, b = cast:GetStatusBarColor()
		if (type(r) == "number" and type(g) == "number" and type(b) == "number") then
			fakeFill:SetVertexColor(r, g, b, alpha)
			return
		end
	end
	fakeFill:SetVertexColor(1, 1, 1, alpha)
end

local ApplyTargetNativeCastVisualFromTimer = function(cast, durationPayload, sourceTag)
	if (not cast or not cast.SetTimerDuration) then
		return false
	end
	if (durationPayload == nil) then
		durationPayload = GetTargetCastTimerPayload(cast)
	end
	if (durationPayload == nil) then
		return false
	end
	local direction = (cast.channeling and Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime)
		or (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime)
	local ok = pcall(cast.SetTimerDuration, cast, durationPayload, cast.smoothing, direction)
	if (not ok) then
		return false
	end
	local nativeTexture = cast.GetStatusBarTexture and cast:GetStatusBarTexture()
	if (nativeTexture and nativeTexture.SetAlpha) then
		nativeTexture:SetAlpha(1)
	end
	if (nativeTexture and nativeTexture.Show) then
		nativeTexture:Show()
	end
	local alpha = GetTargetCastFakeAlpha(cast)
	cast:SetStatusBarColor(1, 1, 1, alpha)
	if (cast.FakeFill and cast.FakeFill.Hide) then
		cast.FakeFill:Hide()
	end
	cast.__AzeriteUI_UseNativeCastVisual = true
	cast.__AzeriteUI_CastFakePath = "timer_native"
	cast.__AzeriteUI_CastFakePercent = nil
	cast.__AzeriteUI_CastCropSource = sourceTag or "timer_native"
	cast.__AzeriteUI_CastLastExplicitPercent = nil
	cast.__AzeriteUI_CastGenericSyncReason = nil
	UpdateTargetBarSpark(cast, nil)
	return true
end

local ShouldPreferTimerDriverForTargetCast = function(cast)
	if (not cast or not cast.__owner) then
		return true
	end
	local unit = cast.__owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return true
	end
	-- Self target historically behaved best on explicit/duration percent path.
	if (UnitIsUnit(unit, "player")) then
		return false
	end
	return true
end

local NormalizeTargetCastPercent = function(value)
	if (not IsSafeNumber(value)) then
		return nil
	end
	-- Accept either 0..1 or 0..100 input from different percent providers.
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

local GetTargetCastPercentFromDurationObject = function(cast, durationObject)
	if (not cast or not durationObject) then
		return nil
	end

	local curve = CurveConstants and CurveConstants.ZeroToOne or nil
	if (cast.channeling and type(durationObject.EvaluateRemainingPercent) == "function") then
		local okPercent, percent = pcall(durationObject.EvaluateRemainingPercent, durationObject, curve)
		percent = okPercent and NormalizeTargetCastPercent(percent) or nil
		if (type(percent) == "number") then
			return percent
		end
	end

	if ((not cast.channeling) and type(durationObject.EvaluateElapsedPercent) == "function") then
		local okPercent, percent = pcall(durationObject.EvaluateElapsedPercent, durationObject, curve)
		percent = okPercent and NormalizeTargetCastPercent(percent) or nil
		if (type(percent) == "number") then
			return percent
		end
	end

	if (cast.channeling and type(durationObject.GetRemainingPercent) == "function") then
		local okPercent, percent = pcall(durationObject.GetRemainingPercent, durationObject)
		percent = okPercent and NormalizeTargetCastPercent(percent) or nil
		if (type(percent) == "number") then
			return percent
		end
	end

	if ((not cast.channeling) and type(durationObject.GetElapsedPercent) == "function") then
		local okPercent, percent = pcall(durationObject.GetElapsedPercent, durationObject)
		percent = okPercent and NormalizeTargetCastPercent(percent) or nil
		if (type(percent) == "number") then
			return percent
		end
	end

	return nil
end

local GetTargetCastPercentFromDurationPayload = function(cast, durationPayload)
	if (not cast or durationPayload == nil) then
		return nil
	end
	if (type(durationPayload) == "number") then
		-- oUF can pass either normalized percent-like values (0..1),
		-- or fallback remaining-duration numbers (seconds).
		if (durationPayload >= 0 and durationPayload <= 1) then
			return NormalizeTargetCastPercent(durationPayload)
		end
		if (durationPayload > 1) then
			local minValue, maxValue = cast.GetMinMaxValues and cast:GetMinMaxValues()
			local value = cast.GetValue and cast:GetValue()
			if (IsSafeNumber(minValue) and IsSafeNumber(maxValue) and IsSafeNumber(value)) then
				local range = maxValue - minValue
				if (range > 0) then
					if (cast.channeling) then
						-- Channel payload is remaining duration, so map directly.
						return NormalizeTargetCastPercent(durationPayload / range)
					end
					-- Cast payload is remaining duration; convert to elapsed percent.
					local elapsed = range - durationPayload
					return NormalizeTargetCastPercent(elapsed / range)
				end
			end
		end
		return nil
	end

	local percent = GetTargetCastPercentFromDurationObject(cast, durationPayload)
	if (type(percent) == "number") then
		return percent
	end

	-- Some duration payloads expose progress without curve evaluators.
	if (durationPayload.GetProgress) then
		local okProgress, progress = pcall(durationPayload.GetProgress, durationPayload)
		if (okProgress) then
			return NormalizeTargetCastPercent(progress)
		end
	end
	return nil
end

local GetTargetCastPercentFromUnitDuration = function(cast)
	if (not cast or not cast.__owner) then
		return nil
	end
	if (not cast.casting and not cast.channeling and not cast.empowering) then
		return nil
	end

	local unit = cast.__owner.unit
	if (type(unit) ~= "string" or unit == "") then
		return nil
	end

	local durationPayload
	if (cast.empowering and UnitEmpoweredChannelDuration) then
		durationPayload = UnitEmpoweredChannelDuration(unit)
	end
	if (durationPayload == nil and cast.channeling and UnitChannelDuration) then
		durationPayload = UnitChannelDuration(unit)
	end
	if (durationPayload == nil and UnitCastingDuration) then
		durationPayload = UnitCastingDuration(unit)
	end
	if (durationPayload == nil) then
		return nil
	end

	return GetTargetCastPercentFromDurationPayload(cast, durationPayload)
end

local GetTargetCastPercentFromMirror = function(cast)
	if (not cast) then
		return nil, nil
	end
	local mirrorPercent = cast.__AzeriteUI_MirrorPercent
	if (type(mirrorPercent) == "number") then
		return NormalizeTargetCastPercent(mirrorPercent), "mirror_percent"
	end
	local texturePercent = cast.__AzeriteUI_TexturePercent
	if (type(texturePercent) == "number") then
		return NormalizeTargetCastPercent(texturePercent), "texture_percent"
	end
	return nil, nil
end

local ResolveTargetCastPercent = function(cast, explicitPercent, durationPayload)
	local percent = NormalizeTargetCastPercent(explicitPercent)
	if (type(percent) == "number") then
		return percent, "explicit"
	end
	if (durationPayload ~= nil) then
		percent = GetTargetCastPercentFromDurationPayload(cast, durationPayload)
		if (type(percent) == "number") then
			return percent, "duration_callback"
		end
	end
	percent = GetTargetCastPercentFromUnitDuration(cast)
	if (type(percent) == "number") then
		return percent, "unit_duration"
	end
	local source
	percent, source = GetTargetCastPercentFromMirror(cast)
	if (type(percent) == "number") then
		return percent, source or "mirror_percent"
	end
	return nil, "pending"
end

local UpdateTargetFakeCastFill = function(cast, explicitPercent, sourceTag)
	if (not cast) then
		return false
	end
	local fakeFill = cast.FakeFill
	if (not fakeFill) then
		return false
	end
	local percent = NormalizeTargetCastPercent(explicitPercent)
	if (type(percent) ~= "number") then
		return false
	end
	local applied = ApplyTargetSimpleCastFakeFillByPercent(cast, percent)
	if (applied) then
		cast.__AzeriteUI_UseNativeCastVisual = nil
		HideTargetNativeCastVisuals(cast)
		ApplyTargetFakeCastVertexColor(cast)
		cast.__AzeriteUI_CastFakePath = "live"
		cast.__AzeriteUI_CastFakePercent = percent
		cast.__AzeriteUI_LastFakePercent = percent
		cast.__AzeriteUI_CastCropSource = sourceTag or "duration_callback"
		cast.__AzeriteUI_CastLastExplicitPercent = percent
		cast.__AzeriteUI_CastGenericSyncReason = nil
		if (GetTime) then
			cast.__AzeriteUI_LastLivePercentTime = GetTime()
		end
		UpdateTargetBarSpark(cast, percent)
		return true
	end
	return false
end

local ShowTargetIdleCastFakeFill = function(cast, reason)
	if (not cast) then
		return false
	end
	local applied = ApplyTargetSimpleCastFakeFillByPercent(cast, nil)
	if (applied) then
		cast.__AzeriteUI_UseNativeCastVisual = nil
		HideTargetNativeCastVisuals(cast)
		ApplyTargetFakeCastVertexColor(cast)
		cast.__AzeriteUI_CastFakePath = "idle"
		cast.__AzeriteUI_CastFakePercent = nil
		cast.__AzeriteUI_CastCropSource = reason or "pending"
		cast.__AzeriteUI_CastLastExplicitPercent = nil
		cast.__AzeriteUI_CastGenericSyncReason = reason
		UpdateTargetBarSpark(cast, 0)
	end
	return applied
end

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	if (type(cur) == "number" and type(max) == "number" and max > 0
		and (not issecretvalue or (not issecretvalue(cur) and not issecretvalue(max)))) then
		element.safePercent = NormalizeTargetDisplayPercent((cur / max) * 100)
	end
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
	SyncTargetHealthVisualState(element)
	UpdateTargetBarSpark(element, nil)
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
		local fakeFill = element.FakeFill
		if (fakeFill and fakeFill.SetVertexColor) then
			fakeFill:SetVertexColor(r, g, b, 1)
		end
	end
	UpdateTargetBarSpark(element, nil)
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

local HideTargetAbsorbBarVisual = function(absorbBar)
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

local GetTargetFrameConfig = function()
	return ns.GetConfig("TargetFrame")
end

local ResolveTargetTextAnchorFrame = function(self, key)
	if (not self or type(key) ~= "string" or key == "") then
		return nil
	end
	if (key == "HEALTHBACKDROP") then
		return self.Health and self.Health.Backdrop
	elseif (key == "HEALTH") then
		return self.Health
	elseif (key == "FRAME") then
		return self
	end
end

local ShouldHideTargetHealthValue = function()
	local config = GetTargetFrameConfig()
	return config and config.HideHealthValue
end

local ShouldHideTargetHealthAbsorb = function()
	local config = GetTargetFrameConfig()
	return config and config.HideHealthAbsorb
end

local ShouldKeepTargetHealthPercentVisible = function()
	local config = GetTargetFrameConfig()
	return config and config.KeepHealthPercentVisible
end

local UpdateTargetAbsorbState = function(element, unit, absorb, maxHealth)
	if (not element) then
		return
	end
	if (element.absorbBar) then
		HideTargetAbsorbBarVisual(element.absorbBar)
	end
	local SetOwnerSafeAbsorb = function(value)
		local ownerHealth = element.__owner and element.__owner.Health
		if (ownerHealth) then
			ownerHealth.safeAbsorb = value
		end
	end
	if (ShouldHideTargetHealthAbsorb()) then
		SetOwnerSafeAbsorb(nil)
		return
	end
	local resolvedAbsorb = nil
	local hasKnownZero = false
	local apiTotalAbsorb = nil
	local calcAbsorb = GetAbsorbFromPredictionValues(element)
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
	if (type(resolvedAbsorb) == "number" and (not issecretvalue or not issecretvalue(resolvedAbsorb))) then
		if (resolvedAbsorb > 0) then
			SetOwnerSafeAbsorb(resolvedAbsorb)
		else
			SetOwnerSafeAbsorb(nil)
		end
	elseif (hasKnownZero) then
		SetOwnerSafeAbsorb(nil)
	else
		-- No reliable source for this update, clear to avoid stale values.
		SetOwnerSafeAbsorb(nil)
	end
	local owner = element.__owner
	local ownerHealth = owner and owner.Health
	EmitAbsorbStateDebug(owner, unit,
		"State(Target) unit=%s calc=%s callback=%s apiTotal=%s resolved=%s knownZero=%s finalSafe=%s",
		unit,
		calcAbsorb,
		absorb,
		apiTotalAbsorb,
		resolvedAbsorb,
		hasKnownZero and true or false,
		ownerHealth and ownerHealth.safeAbsorb or nil)
end

local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	UpdateTargetAbsorbState(element, unit, absorb, maxHealth)
	-- Target fake health-fill mode:
	-- disable prediction overlays to avoid ghost/light duplicate bar rendering.
	if (true) then
		ns.API.HidePrediction(element)
		return
	end

	if (_G.__AzeriteUI_DISABLE_HEALTH_PREDICTION) then
		ns.API.HidePrediction(element)
		return
	end
	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	-- WoW 12.0: Sanitize secret values first
	if issecretvalue(myIncomingHeal) then myIncomingHeal = 0 end
	if issecretvalue(otherIncomingHeal) then otherIncomingHeal = 0 end
	if issecretvalue(absorb) then absorb = 0 end
	if issecretvalue(healAbsorb) then healAbsorb = 0 end
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0

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

		if (growth == "RIGHT") then

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				element:SetTexCoord(curHealth/maxHealth, curHealth/maxHealth + change, 0, 1)
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				element:SetTexCoord(curHealth/maxHealth, curHealth/maxHealth + change, 0, 1)
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

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
				element:ClearAllPoints()
				element:SetPoint("TOPLEFT", previewTexture, "TOPLEFT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				element:SetTexCoord(1 - (1 - (curHealth/maxHealth + change)), 1 - (1 - curHealth/maxHealth), 0, 1)
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

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
			ns.API.DebugPrintf("Health", 3, "Predict(Target) unit=%s show=%s change=%s cur=%s max=%s incoming=%s absorb=%s",
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

-- Use custom colors for our power crystal. Does not apply to Wrath.
local Power_UpdateColor = function(self, event, unit)
	if (self.unit ~= unit) then return end

	local element = self.Power
	local _, pToken = UnitPowerType(unit)
	if (pToken) then
		local db = ns.GetConfig("TargetFrame")
		local color = db.PowerBarColors[pToken] or Colors.power[pToken]
		if (color) then
			element:SetStatusBarColor(unpack(color))
		end
	end
end

-- Hide power crystal when no power exists.
local ShouldShowTargetPowerValue = function()
	local profile = TargetFrameMod and TargetFrameMod.db and TargetFrameMod.db.profile
	if (not profile) then
		return true
	end
	return profile.showPowerValue ~= false
end

local GetTargetPowerValueFormat = function(profile)
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

local GetTargetPowerUnit = function(frame)
	if (frame and type(frame.unit) == "string" and frame.unit ~= "") then
		return frame.unit
	end
	return "target"
end

local GetFormattedTargetPowerValue = function(element, useFull)
	if (not element or not element.Value) then
		return nil
	end
	local owner = element.__owner
	local unit = GetTargetPowerUnit(owner)
	local displayType = element.displayType
	if (type(displayType) ~= "number") then
		displayType = UnitPowerType(unit)
	end

	local rawCur = UnitPower(unit, displayType)
	if (type(rawCur) ~= "number" or (issecretvalue and issecretvalue(rawCur))) then
		rawCur = element.safeCur or element.cur
	end
	if (type(rawCur) ~= "number" or (issecretvalue and issecretvalue(rawCur))) then
		return nil
	end
	if (rawCur < 0) then
		rawCur = 0
	end
	local formatter = useFull and BreakUpLargeNumbers or AbbreviateNumbers
	if (type(formatter) == "function") then
		local ok, formatted = pcall(formatter, rawCur)
		if (ok and formatted ~= nil) then
			return tostring(formatted)
		end
	end
	return nil
end

local GetTargetRawPowerPercent = function(element)
	if (not element) then
		return nil
	end
	local owner = element.__owner
	local unit = GetTargetPowerUnit(owner)
	local displayType = element.displayType
	if (type(displayType) ~= "number") then
		displayType = UnitPowerType(unit)
	end
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
	if (type(percent) == "number" and issecretvalue and issecretvalue(percent)) then
		percent = nil
	end
	if (type(percent) ~= "number") then
		local cur = element.safeCur or element.cur
		local max = element.safeMax or element.max
		if (type(cur) == "number" and type(max) == "number" and max > 0
			and (not issecretvalue or (not issecretvalue(cur) and not issecretvalue(max)))) then
			percent = math_floor(((cur / max) * 100) + 0.5)
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
	return percent
end

local GetTargetPowerValueAlpha = function()
	local config = ns.GetConfig("TargetFrame")
	local alpha = config and config.PowerValueAlpha
	if (type(alpha) == "number") then
		if (alpha > 1) then
			alpha = alpha / 100
		end
		if (alpha < 0) then
			return 0
		elseif (alpha > 1) then
			return 1
		end
		return alpha
	end
	if (ns.UnitFrame and ns.UnitFrame.GetPowerValueAlpha) then
		return ns.UnitFrame.GetPowerValueAlpha()
	end
	return .75
end

local UpdateTargetPowerValueText = function(frame)
	if (not frame or not frame.Power or not frame.Power.Value) then
		return
	end
	local element = frame.Power
	local powerValue = element.Value
	local profile = TargetFrameMod and TargetFrameMod.db and TargetFrameMod.db.profile
	local formatMode = GetTargetPowerValueFormat(profile)
	if (frame.Untag and powerValue.__AzeriteUI_PowerValueTag) then
		frame:Untag(powerValue)
		powerValue.__AzeriteUI_PowerValueTag = nil
	end

	local shortText = GetFormattedTargetPowerValue(element, false)
	local fullText = GetFormattedTargetPowerValue(element, true)
	local rawPercent = GetTargetRawPowerPercent(element)
	local hasValue = false

	if (formatMode == "percent") then
		if (rawPercent ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%d%%", rawPercent)
			hasValue = true
		end
	elseif (formatMode == "full") then
		if (fullText ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%s", fullText)
			hasValue = true
		end
	elseif (formatMode == "shortpercent") then
		if (shortText ~= nil and rawPercent ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%s |cff888888(|r%d%%|cff888888)|r", shortText, rawPercent)
			hasValue = true
		elseif (shortText ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%s", shortText)
			hasValue = true
		elseif (rawPercent ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%d%%", rawPercent)
			hasValue = true
		end
	else
		if (shortText ~= nil and powerValue.SetFormattedText) then
			pcall(powerValue.SetFormattedText, powerValue, "%s", shortText)
			hasValue = true
		end
	end
	if (not hasValue and powerValue.SetText) then
		pcall(powerValue.SetText, powerValue, "")
	end
	if (powerValue.SetAlpha) then
		powerValue:SetAlpha(hasValue and GetTargetPowerValueAlpha() or 0)
	end
end

local Power_UpdateVisibility = function(element, unit, cur, min, max)
	element.__AzeriteUI_KeepValueVisible = false

	-- WoW 12.0: Sanitize secret values before comparison
	local curIsSecret = (issecretvalue and issecretvalue(cur)) and true or false
	local maxIsSecret = (issecretvalue and issecretvalue(max)) and true or false
	if (curIsSecret) then
		if (type(element.safeCur) ~= "number") then
			element.safeCur = 0
		end
		cur = element.safeCur
	else
		element.safeCur = cur
	end
	if (maxIsSecret) then
		if (type(element.safeMax) ~= "number" or element.safeMax == 0) then
			element.safeMax = 1
		end
		max = element.safeMax
	else
		element.safeMax = max
	end
	
	local noUsablePool = (not curIsSecret and not maxIsSecret)
		and ((type(max) ~= "number") or (max <= 0) or (type(cur) ~= "number"))
	local config = ns.GetConfig("TargetFrame")
	local hideZeroPower = config and config.HideZeroPower
	local zeroPower = (not curIsSecret and not maxIsSecret)
		and (type(max) == "number") and (type(cur) == "number")
		and (max > 0) and (cur <= 0)
	if (UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) or noUsablePool or (hideZeroPower and zeroPower)) then
		element:Hide()
		if (element.Backdrop) then
			element.Backdrop:Hide()
		end
		if (element.Value) then
			element.Value:Hide()
		end
	else
		element:Show()
		if (element.Backdrop) then
			element.Backdrop:Show()
		end
		local showPowerValue = ShouldShowTargetPowerValue()
		element.__AzeriteUI_KeepValueVisible = showPowerValue
		if (element.Value) then
			if (showPowerValue) then
				element.Value:Show()
			else
				element.Value:Hide()
			end
		end
	end
	if (element.Value and element.__owner) then
		UpdateTargetPowerValueText(element.__owner)
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
		element:SetRotation(element.rotation and element.rotation*degToRad or 0)
		element:ClearModel()
		element:SetUnit(unit)
		element.guid = guid
	end
end

-- Toggle cast text color on protected casts.
local SyncTargetCastVisualState

local Cast_PostCastInterruptible = function(element, unit)
	if (element.notInterruptible) then
		element.Text:SetTextColor(unpack(element.Text.colorProtected))
	else
		element.Text:SetTextColor(unpack(element.Text.color))
	end
	SyncTargetCastVisualState(element)
end

GetTargetCastTimerPayload = function(cast)
	if (not cast or not cast.GetTimerDuration) then
		return nil
	end
	local okPayload, payload = pcall(cast.GetTimerDuration, cast)
	if (not okPayload) then
		return nil
	end
	return payload
end

SyncTargetCastVisualState = function(cast, explicitPercent)
	if (not cast) then
		return false
	end
	HideTargetNativeCastVisuals(cast)
	local timerPayload = GetTargetCastTimerPayload(cast)
	local preferTimerDriver = ShouldPreferTimerDriverForTargetCast(cast)
	if (preferTimerDriver and ApplyTargetNativeCastVisualFromTimer(cast, timerPayload, "sync_timer_native")) then
		UpdateTargetBarSpark(cast, nil)
		return true
	end
	local resolvedPercent, resolvedSource = ResolveTargetCastPercent(cast, explicitPercent, timerPayload)
	local updated = UpdateTargetFakeCastFill(cast, resolvedPercent, resolvedSource)
	if (not updated) then
		ShowTargetIdleCastFakeFill(cast, resolvedSource)
	end
	UpdateTargetBarSpark(cast, resolvedPercent)
	return updated
end

local Cast_PostUpdateVisual = function(element, unit)
	HideTargetNativeCastVisuals(element)
	UpdateTargetBarSpark(element, nil)
end

local GetTargetCastRemainingFromPayload = function(durationPayload)
	if (type(durationPayload) == "number") then
		if (IsSafeNumber(durationPayload)) then
			return durationPayload
		end
	elseif (durationPayload and durationPayload.GetRemainingDuration) then
		local okRemaining, value = pcall(durationPayload.GetRemainingDuration, durationPayload)
		if (okRemaining and IsSafeNumber(value)) then
			return value
		end
	end
	return nil
end

local UpdateTargetLiveCastFakeFill = function(element, durationPayload)
	if (durationPayload == nil) then
		durationPayload = GetTargetCastTimerPayload(element)
	end
	local preferTimerDriver = ShouldPreferTimerDriverForTargetCast(element)
	if (preferTimerDriver and ApplyTargetNativeCastVisualFromTimer(element, durationPayload, "live_update_timer_native")) then
		return
	end
	local resolvedPercent, resolvedSource = ResolveTargetCastPercent(element, nil, durationPayload)
	if (type(resolvedPercent) == "number") then
		UpdateTargetFakeCastFill(element, resolvedPercent, resolvedSource)
		return
	end

	-- Avoid wiping a valid live crop on transient pending ticks.
	if (element
		and element.__AzeriteUI_CastFakePath == "live"
		and type(element.__AzeriteUI_CastFakePercent) == "number") then
		element.__AzeriteUI_CastCropSource = resolvedSource or "pending_keep_live"
		return
	end

	ShowTargetIdleCastFakeFill(element, resolvedSource or "duration_callback_pending")
end

local Cast_CustomTimeText = function(element, durationPayload)
	UpdateTargetLiveCastFakeFill(element, durationPayload)
	if (not element.Time) then
		return
	end
	local remaining = GetTargetCastRemainingFromPayload(durationPayload)
	if (type(remaining) == "number") then
		element.Time:SetFormattedText('%.1f', remaining)
	else
		element.Time:SetText("")
	end
end

local Cast_CustomDelayText = function(element, durationPayload)
	UpdateTargetLiveCastFakeFill(element, durationPayload)
	if (not element.Time) then
		return
	end
	local remaining = GetTargetCastRemainingFromPayload(durationPayload)
	if (type(remaining) == "number") then
		element.Time:SetFormattedText('%.1f|cffff0000%s%.2f|r', remaining, element.channeling and '-' or '+', element.delay or 0)
	else
		element.Time:SetText("")
	end
end

-- Toggle cast info and health info when castbar is visible.
local Cast_UpdateTexts = function(element)
	local health = element.__owner.Health
	local currentStyle = element.__owner.currentStyle
	local healthValue = health and health.Value
	local healthPercent = health and health.Percent
	local hideHealthValue = ShouldHideTargetHealthValue()
	local keepHealthPercentVisible = ShouldKeepTargetHealthPercentVisible()

	if (hideHealthValue or keepHealthPercentVisible) then
		if (element:IsShown()) then
			element.Text:Show()
			element.Time:Show()
			if (healthPercent) then
				healthPercent:Hide()
			end
		else
			element.Text:Hide()
			element.Time:Hide()
			if (healthPercent) then
				if (keepHealthPercentVisible) then
					healthPercent:Show()
				else
					healthPercent:Hide()
				end
			end
		end
		if (healthValue) then
			healthValue:Hide()
		end
		return
	end

	if (currentStyle == "Critter") then
		element.Text:Hide()
		element.Time:Hide()
		if (healthValue) then
			healthValue:Hide()
		end
		if (healthPercent) then
			healthPercent:Hide()
		end
	elseif (element:IsShown()) then
		element.Text:Show()
		element.Time:Show()
		if (healthValue) then
			healthValue:Hide()
		end
		if (healthPercent) then
			healthPercent:Hide()
		end
	else
		element.Text:Hide()
		element.Time:Hide()
		if (healthValue) then
			healthValue:Show()
		end
		if (healthPercent) then
			healthPercent:Show()
		end
	end
end

-- Update NPC classification badge for rares, elites and bosses.
local Classification_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.Classification
	unit = unit or self.unit

	if (UnitIsPlayer(unit)) then
		return element:Hide()
	end
	local l = UnitEffectiveLevel(unit)
	local c = (l and l < 1) and "worldboss" or UnitClassification(unit)
	if (c == "boss" or c == "worldboss") then
		element:SetTexture(element.bossTexture)
		element:Show()

	elseif (c == "elite") then
		element:SetTexture(element.eliteTexture)
		element:Show()

	elseif (c == "rare" or c == "rareelite") then
		element:SetTexture(element.rareTexture)
		element:Show()
	else
		element:Hide()
	end
end

-- Toggle name size based on ToT visibility
local Name_PostUpdate = function(self)
	local name = self.Name
	if (not name) then return end

	if (UnitExists("targettarget") and not UnitIsUnit("targettarget", "target") and not UnitIsUnit("targettarget","player")) then
		if (not name.usingSmallWidth) then
			name.usingSmallWidth = true
			self:Untag(name)
			--self:Tag(name, prefix("[*:Name(30,true,nil,true)]"))
			self:Tag(name, prefix("[*:Name(30,true,nil,nil)]")) -- maxChars, showLevel, showLevelLast, showFull
		end
	else
		if (name.usingSmallWidth) then
			name.usingSmallWidth = nil
			self:Untag(name)
			self:Tag(name, prefix("[*:Name(64,true,nil,true)]"))
		end
	end
end

-- Update target indicator texture.
local TargetIndicator_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetIndicator
	unit = unit or self.unit

	local target = unit .. "target"
	-- Guard UnitExists/UnitIsUnit against secret returns
	local targetExists = UnitExists(target)
	if (issecretvalue and issecretvalue(targetExists)) then targetExists = true end
	local isPlayerUnit = UnitIsUnit(unit, "player")
	if (issecretvalue and issecretvalue(isPlayerUnit)) then isPlayerUnit = false end
	if (not targetExists or isPlayerUnit) then
		return element:Hide()
	end

	local canAttack = UnitCanAttack("player", unit)
	if (issecretvalue and issecretvalue(canAttack)) then
		-- Fallback: use UnitReaction to determine hostility
		local reaction = UnitReaction("player", unit)
		if (type(reaction) == "number" and reaction <= 4) then
			canAttack = true
		else
			canAttack = false
		end
	end

	if (canAttack) then
		local targetsPlayer = UnitIsUnit(target, "player")
		if (issecretvalue and issecretvalue(targetsPlayer)) then targetsPlayer = false end
		local targetsPet = UnitIsUnit(target, "pet")
		if (issecretvalue and issecretvalue(targetsPet)) then targetsPet = false end
		if (targetsPlayer) then
			element:SetTexture(element.enemyTexture)
		elseif (targetsPet) then
			element:SetTexture(element.petTexture)
		else
			return element:Hide()
		end
	else
		local targetsPlayer = UnitIsUnit(target, "player")
		if (issecretvalue and issecretvalue(targetsPlayer)) then targetsPlayer = false end
		if (targetsPlayer) then
			element:SetTexture(element.friendTexture)
		else
			return element:Hide()
		end
	end

	element:Show()
end

local TargetIndicator_Start = function(self)
	local targetIndicator = self.TargetIndicator
	if (not targetIndicator.Ticker) then
		targetIndicator.Ticker = C_Timer.NewTicker(.1, function() TargetIndicator_Update(self) end)
	end
end

local TargetIndicator_Stop = function(self)
	local targetIndicator = self.TargetIndicator
	if (targetIndicator.Ticker) then
		targetIndicator.Ticker:Cancel()
		targetIndicator.Ticker = nil
		targetIndicator:Hide()
	end
end

-- Only show Horde/Alliance badges,
-- keep this hidding for rare-, elite- and boss NPCs.
local PvPIndicator_Override = function(self, event, unit)
	if (unit and unit ~= self.unit) then return end

	local element = self.PvPIndicator
	unit = unit or self.unit

	local l = UnitEffectiveLevel(unit)
	local c = (l and l < 1) and "worldboss" or UnitClassification(unit)
	if (c == "boss" or c == "worldboss" or c == "elite" or c == "rare") then
		return element:Hide()
	end

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
	local unit = self.unit
	if (not unit or not UnitExists(unit)) then
		return
	end

	local currentStyle = self.currentStyle
	local level = UnitIsUnit(unit, "player") and playerLevel or UnitEffectiveLevel(unit)
	local unitGUID = UnitGUID(unit)
	local cachedGUID = self.__AzeriteUI_TargetGUID
	local guidIsSecret = false
	if (type(issecretvalue) == "function") then
		if ((type(unitGUID) == "string" and issecretvalue(unitGUID)) or (type(cachedGUID) == "string" and issecretvalue(cachedGUID))) then
			guidIsSecret = true
		end
	end

	local key
	if (UnitIsPlayer(unit)) then
		key = IsLevelAtEffectiveMaxLevel(level) and "Seasoned" or level < 10 and "Novice" or "Hardened"
	else
		local unitLevel = UnitLevel(unit)
		if ((type(issecretvalue) == "function") and issecretvalue(unitLevel)) then
			unitLevel = nil
		end
		local classification = UnitClassification(unit)
		if ((type(issecretvalue) == "function") and issecretvalue(classification)) then
			classification = nil
		end
		if (type(unitLevel) == "number" and unitLevel < 1 and not classification) then
			classification = "worldboss"
		end
		local creatureType = UnitCreatureType(unit)
		if ((type(issecretvalue) == "function") and issecretvalue(creatureType)) then
			creatureType = nil
		end
		local unitHealthMax = UnitHealthMax(unit)
		if ((type(issecretvalue) == "function") and issecretvalue(unitHealthMax)) then
			unitHealthMax = nil
		end
		local lowHealthCritterLike = (type(unitHealthMax) == "number" and unitHealthMax > 0 and unitHealthMax <= 40 and type(level) == "number" and level <= 2)

		if (not TargetFrameMod.db.profile.useStandardBossTexture) and IsTargetBossUnit(unit, unitLevel, classification) then
			key = "Boss"
		elseif (not TargetFrameMod.db.profile.useStandardCritterTexture) and ((creatureType == "Critter") or (lowHealthCritterLike and UnitCanAttack("player", unit)) or ((not ns.IsRetail) and (level == 1) and (type(unitHealthMax) == "number") and (unitHealthMax < 30))) then
			key = "Critter"
		else
			key = (level < 1 or IsLevelAtEffectiveMaxLevel(level)) and "Seasoned" or level < 10 and "Novice" or "Hardened"
		end
	end

	self.currentStyle = key

	local rootConfig = ns.GetConfig("TargetFrame")
	local isFlipped = rootConfig.IsFlippedHorizontally
	local db = rootConfig[key]
	local profile = TargetFrameMod and TargetFrameMod.db and TargetFrameMod.db.profile or nil
	local healthLab = GetTargetHealthLabSettings(db, isFlipped)
	local powerBarPosition = db.PowerBarPosition or rootConfig.PowerBarPosition
	local powerBarSize = db.PowerBarSize or rootConfig.PowerBarSize
	local powerBackdropPosition = db.PowerBackdropPosition or rootConfig.PowerBackdropPosition
	local powerBackdropSize = db.PowerBackdropSize or rootConfig.PowerBackdropSize
	local powerValuePosition = db.PowerValuePosition or rootConfig.PowerValuePosition
	local powerBarAnchorFrameKey = (profile and profile.powerBarAnchorFrame) or "FRAME"
	local powerBackdropAnchorFrameKey = (profile and profile.powerBackdropAnchorFrame) or "POWER"
	local powerValueAnchorFrameKey = (profile and profile.powerValueAnchorFrame) or "POWER"
	local powerBarOffsetX = (profile and tonumber(profile.powerBarOffsetX)) or 0
	local powerBarOffsetY = (profile and tonumber(profile.powerBarOffsetY)) or 0
	local powerBackdropOffsetX = (profile and tonumber(profile.powerBackdropOffsetX)) or 0
	local powerBackdropOffsetY = (profile and tonumber(profile.powerBackdropOffsetY)) or 0
	local powerValueOffsetX = (profile and tonumber(profile.powerValueOffsetX)) or 0
	local powerValueOffsetY = (profile and tonumber(profile.powerValueOffsetY)) or 0
	local powerBarScaleX = ((profile and tonumber(profile.powerBarScaleX)) or 100) / 100
	local powerBarScaleY = ((profile and tonumber(profile.powerBarScaleY)) or 100) / 100
	local powerBackdropScaleX = ((profile and tonumber(profile.powerBackdropScaleX)) or 100) / 100
	local powerBackdropScaleY = ((profile and tonumber(profile.powerBackdropScaleY)) or 100) / 100
	local powerBarArtLayer = (profile and tonumber(profile.powerBarArtLayer)) or 0
	if (powerBarScaleX <= 0) then powerBarScaleX = 1 end
	if (powerBarScaleY <= 0) then powerBarScaleY = 1 end
	if (powerBackdropScaleX <= 0) then powerBackdropScaleX = 1 end
	if (powerBackdropScaleY <= 0) then powerBackdropScaleY = 1 end
	local healthLabSignature = table.concat({
		tostring(healthLab.orientation),
		tostring(healthLab.absorbOrientation),
		tostring(healthLab.castOffsetX), tostring(healthLab.castOffsetY), tostring(healthLab.castWidthScale), tostring(healthLab.castHeightScale), tostring(healthLab.castFollowsHealth),
		tostring(healthLab.castAnchorFrame),
		tostring((profile and tonumber(profile.healthBarOffsetX)) or 0),
		tostring((profile and tonumber(profile.healthBarOffsetY)) or 0),
		tostring((profile and tonumber(profile.healthBarScaleX)) or 100),
		tostring((profile and tonumber(profile.healthBarScaleY)) or 100),
		tostring((profile and tonumber(profile.bossHealthBarOffsetX)) or 0),
		tostring((profile and tonumber(profile.bossHealthBarOffsetY)) or 0),
		tostring((profile and tonumber(profile.bossHealthBarScaleX)) or 100),
		tostring((profile and tonumber(profile.bossHealthBarScaleY)) or 100),
		tostring((profile and tonumber(profile.critterHealthBarOffsetX)) or 0),
		tostring((profile and tonumber(profile.critterHealthBarOffsetY)) or 0),
		tostring((profile and tonumber(profile.critterHealthBarScaleX)) or 100),
		tostring((profile and tonumber(profile.critterHealthBarScaleY)) or 100),
		tostring((profile and tonumber(profile.castBarOffsetX)) or 0),
		tostring((profile and tonumber(profile.castBarOffsetY)) or 0),
		tostring((profile and tonumber(profile.castBarScaleX)) or 100),
		tostring((profile and tonumber(profile.castBarScaleY)) or 100),
		tostring((profile and profile.castBarFollowHealth) and true or false),
		tostring(powerBarAnchorFrameKey), tostring(powerBackdropAnchorFrameKey), tostring(powerValueAnchorFrameKey),
		tostring(powerBarOffsetX), tostring(powerBarOffsetY),
		tostring(powerBackdropOffsetX), tostring(powerBackdropOffsetY),
		tostring(powerValueOffsetX), tostring(powerValueOffsetY),
		tostring(powerBarScaleX), tostring(powerBarScaleY),
		tostring(powerBackdropScaleX), tostring(powerBackdropScaleY),
		tostring(powerBarArtLayer)
	}, "|")
	-- Cache fast-path must include the current target GUID.
	-- Different units can share style/signature but still require
	-- per-target castbar/aura refresh when switching targets.
	if (key == currentStyle and self.__AzeriteUI_HealthLabSignature == healthLabSignature and (not guidIsSecret) and cachedGUID == unitGUID) then
		return
	end
	self.__AzeriteUI_HealthLabSignature = healthLabSignature
	if (guidIsSecret) then
		self.__AzeriteUI_TargetGUID = nil
	else
		self.__AzeriteUI_TargetGUID = unitGUID
	end

	local health = self.Health
	local healthBarOffsetX = (profile and tonumber(profile.healthBarOffsetX)) or 0
	local healthBarOffsetY = (profile and tonumber(profile.healthBarOffsetY)) or 0
	local healthBarScaleX = ((profile and tonumber(profile.healthBarScaleX)) or 100) / 100
	local healthBarScaleY = ((profile and tonumber(profile.healthBarScaleY)) or 100) / 100
	if (key == "Boss") then
		healthBarOffsetX = (profile and tonumber(profile.bossHealthBarOffsetX)) or 0
		healthBarOffsetY = (profile and tonumber(profile.bossHealthBarOffsetY)) or 0
		healthBarScaleX = ((profile and tonumber(profile.bossHealthBarScaleX)) or 100) / 100
		healthBarScaleY = ((profile and tonumber(profile.bossHealthBarScaleY)) or 100) / 100
	elseif (key == "Critter") then
		healthBarOffsetX = (profile and tonumber(profile.critterHealthBarOffsetX)) or 0
		healthBarOffsetY = (profile and tonumber(profile.critterHealthBarOffsetY)) or 0
		healthBarScaleX = ((profile and tonumber(profile.critterHealthBarScaleX)) or 100) / 100
		healthBarScaleY = ((profile and tonumber(profile.critterHealthBarScaleY)) or 100) / 100
	end
	if (healthBarScaleX <= 0) then healthBarScaleX = 1 end
	if (healthBarScaleY <= 0) then healthBarScaleY = 1 end
	health:ClearAllPoints()
	health:SetPoint(db.HealthBarPosition[1], (db.HealthBarPosition[2] or 0) + healthBarOffsetX, (db.HealthBarPosition[3] or 0) + healthBarOffsetY)
	health:SetSize(db.HealthBarSize[1] * healthBarScaleX, db.HealthBarSize[2] * healthBarScaleY)
	-- WoW 12.0: Only update if properties changed to prevent proxy flickering
	if (health._cachedTexture ~= db.HealthBarTexture) then
		health:SetStatusBarTexture(db.HealthBarTexture)
		health._cachedTexture = db.HealthBarTexture
	end
	health.__AzeriteUI_UseProductionNativeFill = true
	health.__AzeriteUI_KeepMirrorPercentOnNoSample = false
	health.__AzeriteUI_UseValueMirrorTexCoord = false
	local fakeFill = health.FakeFill
	if (fakeFill) then
		fakeFill:ClearAllPoints()
		local nativeTexture = health.GetStatusBarTexture and health:GetStatusBarTexture()
		if (nativeTexture) then
			fakeFill:SetAllPoints(nativeTexture)
		else
			fakeFill:SetAllPoints(health)
		end
		fakeFill:SetTexture(db.HealthBarTexture)
		fakeFill:SetTexCoord(GetTargetFillTexCoords(nil))
		fakeFill:SetAlpha(1)
		fakeFill:SetDrawLayer("ARTWORK", 1)
		local r, g, b, a = health:GetStatusBarColor()
		if (type(r) == "number" and type(g) == "number" and type(b) == "number") then
			fakeFill:SetVertexColor(r, g, b, 1)
		else
			fakeFill:SetVertexColor(1, 1, 1, 1)
		end
		HideTargetNativeHealthVisuals(health)
		SyncTargetHealthVisualState(health)
	end
	if (health._cachedOrientation ~= "HORIZONTAL") then
		health:SetOrientation("HORIZONTAL")
		health._cachedOrientation = "HORIZONTAL"
	end
	if (health._cachedReverseFill ~= true) then
		-- Keep the hidden native bar reversed so the fake texture inherits
		-- the correct right-to-left texture region from the statusbar.
		health:SetReverseFill(true)
		health._cachedReverseFill = true
	end
	if (health._cachedSparkMap ~= db.HealthBarSparkMap) then
		health:SetSparkMap(db.HealthBarSparkMap)
		health._cachedSparkMap = db.HealthBarSparkMap
	end
	UpdateTargetBarSparkSize(health)
	UpdateTargetBarSpark(health, nil)
	if (health._cachedFlipped ~= false) then
		health:SetFlippedHorizontally(false)
		health._cachedFlipped = false
		health.__AzeriteUI_BaseTexCoordLeft = nil
		health.__AzeriteUI_BaseTexCoordRight = nil
		health.__AzeriteUI_BaseTexCoordTop = nil
		health.__AzeriteUI_BaseTexCoordBottom = nil
	end
	local nativeTexture = health.GetStatusBarTexture and health:GetStatusBarTexture()
	if (nativeTexture and nativeTexture.SetAlpha) then
		nativeTexture:SetAlpha(0)
	end

	local healthPreview = self.Health.Preview
	if (healthPreview._cachedTexture ~= db.HealthBarTexture) then
		healthPreview:SetStatusBarTexture(db.HealthBarTexture)
		healthPreview._cachedTexture = db.HealthBarTexture
	end
	healthPreview.__AzeriteUI_UseValueMirrorTexCoord = false
	healthPreview:SetTexCoord(GetTargetFillTexCoords(nil))
	healthPreview:SetOrientation("HORIZONTAL")
	healthPreview:SetReverseFill(true)
	healthPreview:SetFlippedHorizontally(false)
	healthPreview:Hide()

	local healthBackdrop = self.Health.Backdrop
	healthBackdrop:ClearAllPoints()
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)
	healthBackdrop:SetVertexColor(unpack(db.HealthBackdropColor))
	healthBackdrop:SetTexCoord(GetTargetFillTexCoords(nil))

	local healPredict = self.HealthPrediction
	healPredict:SetTexture(db.HealthBarTexture)

	local absorb = self.HealthPrediction.absorbBar
	if (absorb) then
		if (absorb._cachedTexture ~= db.HealthBarTexture) then
			absorb:SetStatusBarTexture(db.HealthBarTexture)
			absorb._cachedTexture = db.HealthBarTexture
		end
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetOrientation(healthLab.absorbOrientation)
		if (absorb.SetReverseFill) then
			absorb:SetReverseFill(false)
		end
		absorb:SetSparkMap(db.HealthBarSparkMap)
		absorb:SetTexCoord(1, 0, 0, 1)
		absorb:SetFlippedHorizontally(false)
		HideTargetAbsorbBarVisual(absorb)
	end

	local cast = self.Castbar
	local castBarOffsetX = (profile and tonumber(profile.castBarOffsetX))
	if (type(castBarOffsetX) ~= "number") then
		castBarOffsetX = healthLab.castOffsetX or 0
	end
	local castBarOffsetY = (profile and tonumber(profile.castBarOffsetY))
	if (type(castBarOffsetY) ~= "number") then
		castBarOffsetY = healthLab.castOffsetY or 0
	end
	local castBarScaleX = (profile and tonumber(profile.castBarScaleX))
	if (type(castBarScaleX) ~= "number") then
		castBarScaleX = healthLab.castWidthScale or 100
	end
	local castBarScaleY = (profile and tonumber(profile.castBarScaleY))
	if (type(castBarScaleY) ~= "number") then
		castBarScaleY = healthLab.castHeightScale or 100
	end
	local castBarFollowHealth = (type(profile and profile.castBarFollowHealth) == "boolean") and profile.castBarFollowHealth or false
	cast:ClearAllPoints()
	local castWidthScale = (tonumber(castBarScaleX) or 100) / 100
	local castHeightScale = (tonumber(castBarScaleY) or 100) / 100
	if (castWidthScale <= 0) then castWidthScale = 1 end
	if (castHeightScale <= 0) then castHeightScale = 1 end
	local castAnchorKey = castBarFollowHealth and "HEALTH" or (healthLab.castAnchorFrame or "HEALTH")
	local castAnchorFrame = ResolveTargetAnchorFrame(self, castAnchorKey) or self
	local castWidth = (db.HealthBarSize[1] * healthBarScaleX) * castWidthScale
	local castHeight = (db.HealthBarSize[2] * healthBarScaleY) * castHeightScale
	if (castBarFollowHealth) then
		castWidthScale = 1
		castHeightScale = 1
	end
	if (castAnchorKey == "FRAME") then
		cast:SetPoint(db.HealthBarPosition[1], castAnchorFrame, db.HealthBarPosition[1], (db.HealthBarPosition[2] or 0) + castBarOffsetX, (db.HealthBarPosition[3] or 0) + castBarOffsetY)
	else
		local anchorWidth = (castAnchorFrame.GetWidth and castAnchorFrame:GetWidth()) or db.HealthBarSize[1]
		local anchorHeight = (castAnchorFrame.GetHeight and castAnchorFrame:GetHeight()) or db.HealthBarSize[2]
		if (type(anchorWidth) == "number" and anchorWidth > 0) then
			castWidth = anchorWidth * castWidthScale
		end
		if (type(anchorHeight) == "number" and anchorHeight > 0) then
			castHeight = anchorHeight * castHeightScale
		end
		cast:SetPoint("CENTER", castAnchorFrame, "CENTER", castBarOffsetX, castBarOffsetY)
	end
	cast:SetSize(castWidth, castHeight)
	if (cast.GetFrameLevel and health.GetFrameLevel and cast:GetFrameLevel() <= health:GetFrameLevel()) then
		cast:SetFrameLevel(health:GetFrameLevel() + 2)
	end
	local isSelfTarget = UnitIsUnit(unit, "player")
	local castBarTexture = db.HealthBarTexture
	if (not isSelfTarget and ns.API and ns.API.GetMedia) then
		local mirroredTexture = ns.API.GetMedia("hp_cap_bar_mirror")
		if (type(mirroredTexture) == "string" and mirroredTexture ~= "") then
			castBarTexture = mirroredTexture
		end
	end
	if (cast._cachedTexture ~= castBarTexture) then
		cast:SetStatusBarTexture(castBarTexture)
		cast._cachedTexture = castBarTexture
	end
	local castFakeFill = cast.FakeFill
	if (castFakeFill) then
		castFakeFill:ClearAllPoints()
		local castNativeTexture = cast.GetStatusBarTexture and cast:GetStatusBarTexture()
		if (castNativeTexture) then
			castFakeFill:SetAllPoints(castNativeTexture)
		else
			castFakeFill:SetAllPoints(cast)
		end
		castFakeFill:SetTexture(castBarTexture)
		castFakeFill:SetBlendMode("BLEND")
		castFakeFill:SetDrawLayer("ARTWORK", 1)
		castFakeFill:SetTexCoord(1, 0, 0, 1)
		castFakeFill:SetAlpha(1)
	end
	cast:SetStatusBarColor(unpack(db.HealthCastOverlayColor))
	cast:SetOrientation("HORIZONTAL")
	local shouldReverseTargetCastFill = isSelfTarget and true or false
	if (cast.SetReverseFill) then
		cast:SetReverseFill(shouldReverseTargetCastFill)
	end
	cast:SetSparkMap(db.HealthBarSparkMap)
	UpdateTargetBarSparkSize(cast)
	UpdateTargetBarSpark(cast, nil)
	cast:SetFlippedHorizontally(false)
	cast:SetTexCoord(GetTargetFillTexCoords(nil))
	if (castFakeFill and castFakeFill.SetTexCoord) then
		castFakeFill:SetTexCoord(1, 0, 0, 1)
	end
	local castColorAlpha = db.HealthCastOverlayColor and db.HealthCastOverlayColor[4]
	if (type(castColorAlpha) ~= "number" or (issecretvalue and issecretvalue(castColorAlpha))) then
		castColorAlpha = 1
	end
	if (castColorAlpha < 0) then
		castColorAlpha = 0
	elseif (castColorAlpha > 1) then
		castColorAlpha = 1
	end
	cast.__AzeriteUI_FakeConfiguredAlpha = castColorAlpha
	cast.__AzeriteUI_KeepMirrorPercentOnNoSample = false
	cast.__AzeriteUI_CastFakePath = nil
	cast.__AzeriteUI_CastFakePercent = nil
	SyncTargetCastVisualState(cast)

	local power = self.Power
	if (power) then
		power:ClearAllPoints()
		local powerAnchorFrame = ResolveTargetPowerAnchorFrame(self, powerBarAnchorFrameKey) or self
		SetPointWithAnchorAndOffset(power, powerBarPosition, powerBarOffsetX, powerBarOffsetY, powerAnchorFrame)
		power:SetSize((powerBarSize and powerBarSize[1] or 0) * powerBarScaleX, (powerBarSize and powerBarSize[2] or 0) * powerBarScaleY)
		local powerTexture = power:GetStatusBarTexture()
		if (powerTexture and powerTexture.SetDrawLayer) then
			powerTexture:SetDrawLayer("ARTWORK", ClampTargetPowerLayer(powerBarArtLayer, 0))
		end
	end

	local powerBackdrop = self.Power and self.Power.Backdrop
	if (powerBackdrop) then
		powerBackdrop:ClearAllPoints()
		local powerBackdropAnchorFrame = ResolveTargetPowerAnchorFrame(self, powerBackdropAnchorFrameKey) or power
		SetPointWithAnchorAndOffset(powerBackdrop, powerBackdropPosition, powerBackdropOffsetX, powerBackdropOffsetY, powerBackdropAnchorFrame)
		powerBackdrop:SetSize((powerBackdropSize and powerBackdropSize[1] or 0) * powerBackdropScaleX, (powerBackdropSize and powerBackdropSize[2] or 0) * powerBackdropScaleY)
		powerBackdrop:SetDrawLayer("BACKGROUND", ClampTargetPowerLayer(-2 + powerBarArtLayer, -2))
	end

	local powerValue = self.Power and self.Power.Value
	if (powerValue) then
		powerValue:ClearAllPoints()
		local powerValueAnchorFrame = ResolveTargetPowerAnchorFrame(self, powerValueAnchorFrameKey) or power
		SetPointWithAnchorAndOffset(powerValue, powerValuePosition, powerValueOffsetX, powerValueOffsetY, powerValueAnchorFrame)
	end

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

	local hideHealthValue = ShouldHideTargetHealthValue()
	local keepHealthPercentVisible = ShouldKeepTargetHealthPercentVisible()
	if (key == "Critter" or hideHealthValue or keepHealthPercentVisible) then
		if (hideHealthValue) then
			health.Value:Hide()
		else
			health.Value:Show()
		end
		if (keepHealthPercentVisible) then
			health.Percent:Show()
		else
			health.Percent:Hide()
		end
		if (ShouldHideTargetHealthAbsorb() and self.HealthPrediction and self.HealthPrediction.absorbBar) then
			HideTargetAbsorbBarVisual(self.HealthPrediction.absorbBar)
		end
		if (self:IsElementEnabled("Castbar")) then
			cast:ForceUpdate()
			Cast_UpdateTexts(cast)
		end
		if (key == "Critter") then
			self:DisableElement("Auras")
		end
	else
		health.Value:Show()
		health.Percent:Show()
		if (self:IsElementEnabled("Castbar")) then
			cast:ForceUpdate()
			Cast_UpdateTexts(cast)
		end
		if (TargetFrameMod.db.profile.showAuras) then
			self:EnableElement("Auras")
		end
	end

	if (self.Auras) then
		ApplyTargetAuraLayout(self, key)
		if (self:IsElementEnabled("Auras")) then
			self.Auras:ForceUpdate()
		end
	end

	ns:Fire("UnitFrame_Target_Updated", unit, key)
end

local UnitFrame_PostUpdate = function(self)
	UnitFrame_UpdateTextures(self)
	if (self.Health and self.Health.ForceUpdate) then
		self.Health:ForceUpdate()
	end
	Classification_Update(self)
	TargetIndicator_Update(self)
	TargetIndicator_Start(self)
end

-- Frame Script Handlers
--------------------------------------------
local UnitFrame_OnEvent = function(self, event, unit, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		playerLevel = UnitLevel("player")

	elseif (event == "PLAYER_TARGET_CHANGED") then
		self.__AzeriteUI_HealthLabSignature = nil
		self.__AzeriteUI_TargetGUID = nil
		if (self.Health) then
			self.Health.__AzeriteUI_LastFakePercent = nil
			self.Health.__AzeriteUI_TargetFakeSource = nil
			self.Health.__AzeriteUI_MirrorPercent = nil
			self.Health.__AzeriteUI_TexturePercent = nil
			if (self.Health.FakeFill and self.Health.FakeFill.Hide) then
				self.Health.FakeFill:Hide()
			end
		end
		if (self.Castbar) then
			self.Castbar.__AzeriteUI_LastFakePercent = nil
			self.Castbar.__AzeriteUI_LastLivePercentTime = nil
			self.Castbar.__AzeriteUI_CastFakePath = nil
			self.Castbar.__AzeriteUI_CastFakePercent = nil
			self.Castbar.__AzeriteUI_UseNativeCastVisual = nil
			self.Castbar.__AzeriteUI_MirrorPercent = nil
			self.Castbar.__AzeriteUI_TexturePercent = nil
		end
		if (self.Name and self.Name.UpdateTag) then
			-- pcall: tag may return a secret, which can propagate through oUF wrapper
			pcall(self.Name.UpdateTag, self.Name)
		end
		-- Fallback: if the tag returned empty (secret value filtered out),
		-- try setting the name directly via SetText which handles secrets.
		-- GetText() returns a secret if the fontstring has a secret text aspect,
		-- so we must use issecretvalue() before comparing with == to avoid errors.
		if (self.Name and self.unit) then
			local nameText = self.Name:GetText()
			local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
			if (nameIsEmpty) then
				local rawName = UnitName(self.unit)
				if (type(rawName) == "string") then
					self.Name:SetText(rawName)
				end
			end
		end
		if (self.Health and self.Health.Value and self.Health.Value.UpdateTag) then
			self.Health.Value:UpdateTag()
		end
		if (self.Health and self.Health.Percent and self.Health.Percent.UpdateTag) then
			self.Health.Percent:UpdateTag()
		end
		Name_PostUpdate(self)

	elseif (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED") then
		self.Auras:ForceUpdate()

	elseif (event == "UNIT_ABSORB_AMOUNT_CHANGED") then
		if (unit == self.unit) then
			local eventAbsorb = select(1, ...)
			if (self.HealthPrediction) then
				-- Use event callback absorb as an extra numeric fallback source.
				UpdateTargetAbsorbState(self.HealthPrediction, unit, eventAbsorb, self.Health and self.Health.safeMax or nil)
			end
			if (self.Health and self.Health.ForceUpdate) then
				self.Health:ForceUpdate()
			end
			if (self.Health and self.Health.Value and self.Health.Value.UpdateTag) then
				self.Health.Value:UpdateTag()
			end
			local apiTotalAbsorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or nil
			EmitAbsorbStateDebug(self, unit,
				"Event(Target) unit=%s callback=%s apiTotal=%s healthSafeAbsorb=%s",
				unit,
				eventAbsorb,
				apiTotalAbsorb,
				self.Health and self.Health.safeAbsorb or nil)
		end

	elseif (event == "PLAYER_LEVEL_UP") then
		playerLevel = UnitLevel("player")
	end
	UnitFrame_PostUpdate(self)
end

local style = function(self, unit, id)

	local db = ns.GetConfig("TargetFrame")

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
	if (health.SetForceNative) then health:SetForceNative(false) end
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:DisableSmoothing(true) -- Keep native region immediate for fake-fill crop parity
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorThreat = true
	health.colorClass = true
	--health.colorClassPet = true
	health.colorHappiness = true
	health.colorReaction = true

	self.Health = health
	self.Health.__AzeriteUI_DebugLabel = "Target.Health"
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	self.Health.__AzeriteUI_KeepMirrorPercentOnNoSample = false

	local healthSpark = health:CreateTexture(nil, "OVERLAY", nil, 3)
	healthSpark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	healthSpark:SetBlendMode("ADD")
	healthSpark:SetVertexColor(1, .95, .8, .85)
	healthSpark.requiresConfigKey = "UseHealthSpark"
	healthSpark:Hide()
	self.Health.Spark = healthSpark

	local healthFakeFill = health:CreateTexture(nil, "ARTWORK", nil, 1)
	healthFakeFill:SetAllPoints(health)
	healthFakeFill:SetBlendMode("BLEND")
	healthFakeFill:SetAlpha(1)
	self.Health.FakeFill = healthFakeFill

	ns.API.AttachScriptSafe(health, "OnMinMaxChanged", function(source, minValue, maxValue)
		SyncTargetHealthVisualState(source)
	end)
	ns.API.AttachScriptSafe(health, "OnValueChanged", function(source, value)
		SyncTargetHealthVisualState(source)
	end)

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
	self.Health.Preview.__AzeriteUI_DebugLabel = "Target.Health.Preview"

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
	if (castbar.SetForceNative) then castbar:SetForceNative(false) end
	castbar:SetFrameLevel(self:GetFrameLevel() + 8)
	castbar:DisableSmoothing(true)

	self.Castbar = castbar
	self.Castbar.__AzeriteUI_DebugLabel = "Target.Castbar"
	self.Castbar.__AzeriteUI_KeepMirrorPercentOnNoSample = false
	ns.API.BindStatusBarValueMirror(self.Castbar)

	local castSpark = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	castSpark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	castSpark:SetBlendMode("ADD")
	castSpark:SetVertexColor(1, .95, .8, .85)
	castSpark:Hide()
	self.Castbar.Spark = castSpark

	local castFakeFill = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
	castFakeFill:SetAllPoints(castbar)
	castFakeFill:SetBlendMode("BLEND")
	castFakeFill:SetAlpha(1)
	self.Castbar.FakeFill = castFakeFill

	ns.API.AttachScriptSafe(castbar, "OnMinMaxChanged", function(source, minValue, maxValue)
		HideTargetNativeCastVisuals(source)
		source.__AzeriteUI_CastGenericSyncReason = "OnMinMaxChanged"
		UpdateTargetBarSpark(source, nil)
	end)
	ns.API.AttachScriptSafe(castbar, "OnValueChanged", function(source, value)
		HideTargetNativeCastVisuals(source)
		source.__AzeriteUI_CastGenericSyncReason = "OnValueChanged"
		local timerPayload = GetTargetCastTimerPayload(source)
		UpdateTargetLiveCastFakeFill(source, timerPayload)
		UpdateTargetBarSpark(source, nil)
	end)
	ns.API.AttachScriptSafe(castbar, "OnShow", function(source)
		source.__AzeriteUI_LastFakePercent = nil
		source.__AzeriteUI_LastLivePercentTime = nil
		source.__AzeriteUI_MirrorPercent = nil
		source.__AzeriteUI_TexturePercent = nil
		source.__AzeriteUI_CastGenericSyncReason = "OnShow"
		HideTargetNativeCastVisuals(source)
		SyncTargetCastVisualState(source)
		UpdateTargetBarSpark(source, nil)
	end)
	ns.API.AttachScriptSafe(castbar, "OnUpdate", function(source, elapsed)
		if (not source:IsShown()) then
			return
		end
		if (not source.casting and not source.channeling and not source.empowering) then
			return
		end
		local timerPayload = GetTargetCastTimerPayload(source)
		UpdateTargetLiveCastFakeFill(source, timerPayload)
	end)
	ns.API.AttachScriptSafe(castbar, "OnHide", function(source)
		source.__AzeriteUI_LastFakePercent = nil
		source.__AzeriteUI_LastLivePercentTime = nil
		source.__AzeriteUI_MirrorPercent = nil
		source.__AzeriteUI_TexturePercent = nil
		source.__AzeriteUI_CastCropSource = nil
		source.__AzeriteUI_CastLastExplicitPercent = nil
		source.__AzeriteUI_UseNativeCastVisual = nil
		source.__AzeriteUI_CastGenericSyncReason = "OnHide"
		HideTargetNativeCastVisuals(source)
		if (source.FakeFill and source.FakeFill.Hide) then
			source.FakeFill:Hide()
		end
		if (source.Spark and source.Spark.Hide) then
			source.Spark:Hide()
		end
	end)

	-- Cast Name
	--------------------------------------------
	local castText = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	castText:SetPoint(unpack(db.CastBarTextPosition))
	castText:SetFontObject(db.CastBarTextFont)
	castText:SetTextColor(unpack(db.CastBarTextColor))
	castText:SetJustifyH(db.HealthValueJustifyH)
	castText:SetJustifyV(db.HealthValueJustifyV)
	castText:Hide()
	castText.color = db.CastBarTextColor
	castText.colorProtected = db.CastBarTextProtectedColor

	self.Castbar.Text = castText
	self.Castbar.PostCastInterruptible = Cast_PostCastInterruptible
	self.Castbar.PostCastStart = Cast_PostUpdateVisual
	self.Castbar.PostCastUpdate = Cast_PostUpdateVisual
	self.Castbar.PostCastStop = Cast_PostUpdateVisual
	self.Castbar.PostCastFail = Cast_PostUpdateVisual
	self.Castbar.PostCastInterrupted = Cast_PostUpdateVisual
	self.Castbar.CustomTimeText = Cast_CustomTimeText
	self.Castbar.CustomDelayText = Cast_CustomDelayText

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
	local healthPercParent = healthOverlay
	local healthPercAnchor = health
	do
		local targetConfig = GetTargetFrameConfig()
		local anchorFrameKey = db.HealthPercentageAnchorFrame or (targetConfig and targetConfig.HealthPercentageAnchorFrame) or "HEALTH"
		local anchorFrame = ResolveTargetTextAnchorFrame(self, anchorFrameKey) or health
		if (anchorFrameKey == "HEALTHBACKDROP" and anchorFrame and anchorFrame ~= healthOverlay) then
			local percentOverlay = CreateFrame("Frame", nil, self)
			percentOverlay:SetAllPoints(anchorFrame)
			percentOverlay:SetFrameLevel((health:GetFrameLevel() or self:GetFrameLevel()) + 4)
			self.Health.PercentOverlay = percentOverlay
			healthPercParent = percentOverlay
			healthPercAnchor = nil
		else
			healthPercAnchor = anchorFrame
		end
	end
	local healthPerc = healthPercParent:CreateFontString(nil, "OVERLAY", nil, 1)
	do
		local point = db.HealthPercentagePosition
		if (healthPercAnchor) then
			healthPerc:SetPoint(point[1], healthPercAnchor, point[1], point[2], point[3])
		else
			healthPerc:SetPoint(unpack(point))
		end
	end
	healthPerc:SetFontObject(db.HealthPercentageFont)
	healthPerc:SetTextColor(unpack(db.HealthPercentageColor))
	healthPerc:SetJustifyH(db.HealthPercentageJustifyH)
	healthPerc:SetJustifyV(db.HealthPercentageJustifyV)
	self:Tag(healthPerc, prefix("[*:HealthPercent]"))

	self.Health.Percent = healthPerc

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		HideTargetAbsorbBarVisual(absorb)
		if (absorb.HookScript) then
			absorb:HookScript("OnShow", function(source)
				HideTargetAbsorbBarVisual(source)
			end)
		end

		self.HealthPrediction.absorbBar = absorb
		self.HealthPrediction.__AzeriteUI_HideAbsorbWithPrediction = true
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

	local portraitOverlayFrame = nil
	if (ns.IsRetail) then
		portraitOverlayFrame = CreateFrame("Frame", nil, self, "PingReceiverAttributeTemplate")

		Mixin(portraitOverlayFrame, PingableTypeMixin)

		portraitOverlayFrame.GetContextualPingType = function(self)
			return PingUtil:GetContextualPingTypeForUnit(self:GetTargetPingGUID())
		end

		portraitOverlayFrame.GetTargetPingGUID = function(self)
			return UnitGUID(unit)
		end
	else
		portraitOverlayFrame = CreateFrame("Frame", nil, self)
	end

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
	-- Power Crystal (plain StatusBar)
	local power = CreateFrame("StatusBar", nil, self)
	power:SetFrameLevel(self:GetFrameLevel() + 5)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	local tex = power:GetStatusBarTexture()
	if tex and tex.SetTexCoord and db.PowerBarTexCoord then
		tex:SetTexCoord(unpack(db.PowerBarTexCoord))
	end
	-- Use vertical fill; flip texcoords for DOWN
	if (db.PowerBarOrientation == "DOWN") then
		power:SetOrientation("VERTICAL")
		if tex and tex.SetTexCoord then tex:SetTexCoord(0,1,1,0) end
	else
		power:SetOrientation("VERTICAL")
	end
	power:SetAlpha(db.PowerBarAlpha or 1)
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true
	power.smoothing = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Linear) or nil
	power.safeBarMin = 0
	power.safeBarMax = 1
	power.safeBarValue = 1
	if (tex and tex.GetTexCoord) then
		local left, right, top, bottom = tex:GetTexCoord()
		power.__AzeriteUI_BaseTexCoordLeft = left
		power.__AzeriteUI_BaseTexCoordRight = right
		power.__AzeriteUI_BaseTexCoordTop = top
		power.__AzeriteUI_BaseTexCoordBottom = bottom
	end

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	ns.API.BindStatusBarValueMirror(self.Power)
	self.Power.PostUpdate = Power_UpdateVisibility
	self.Power.UpdateColor = Power_UpdateColor

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
	powerValue:SetAlpha(GetTargetPowerValueAlpha())

	self.Power.Value = powerValue
	UpdateTargetPowerValueText(self)

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
	threatIndicator.textures.Health:SetTexCoord(1, 0, 0, 1) -- target is flipped
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

	-- Classification Badge
	--------------------------------------------
	local classification = overlay:CreateTexture(nil, "OVERLAY", nil, -2)
	classification:SetSize(unpack(db.ClassificationSize))
	classification:SetPoint(unpack(db.ClassificationPosition))
	classification.bossTexture = db.ClassificationBossTexture
	classification.eliteTexture = db.ClassificationEliteTexture
	classification.rareTexture = db.ClassificationRareTexture

	self.Classification = classification

	-- Target Indicator
	--------------------------------------------
	local targetIndicator = overlay:CreateTexture(nil, "OVERLAY", nil, -2)
	targetIndicator:SetPoint(unpack(db.TargetIndicatorPosition))
	targetIndicator:SetSize(unpack(db.TargetIndicatorSize))
	targetIndicator:SetVertexColor(unpack(db.TargetIndicatorColor))
	targetIndicator.petTexture = db.TargetIndicatorPetByEnemyTexture
	targetIndicator.enemyTexture = db.TargetIndicatorYouByEnemyTexture
	targetIndicator.friendTexture = db.TargetIndicatorYouByFriendTexture

	self.TargetIndicator = targetIndicator

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
	auras:SetSize(unpack(db.AurasSize))
	auras:SetPoint(unpack(db.AurasPosition))
	auras.size = db.AuraSize
	auras.spacing = db.AuraSpacing
	auras.numTotal = db.AurasNumTotal
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.showBuffType = false
	auras.showDebuffType = true
	auras.initialAnchor = db.AurasInitialAnchor
	auras["spacing-x"] = db.AurasSpacingX
	auras["spacing-y"] = db.AurasSpacingY
	auras["growth-x"] = db.AurasGrowthX
	auras["growth-y"] = db.AurasGrowthY
	auras.tooltipAnchor = db.AurasTooltipAnchor
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.allowCombatUpdates = true
	auras.CreateButton = ns.AuraStyles.CreateButton
	auras.PostUpdateButton = ns.AuraStyles.TargetPostUpdateButton
	auras.CustomFilter = ns.AuraFilters.TargetAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.TargetAuraFilter -- retail
	auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
	auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail

	self.Auras = auras
	ApplyTargetAuraLayout(self, self.currentStyle)

	-- Seasonal Flavors
	--------------------------------------------
	-- Love is in the Air
	if (ns.API.IsLoveFestival()) then

		-- Target Indicator
		targetIndicator:ClearAllPoints()
		targetIndicator:SetPoint(unpack(db.Seasonal.LoveFestivalCombatIndicatorPosition))
		targetIndicator:SetSize(unpack(db.Seasonal.LoveFestivalTargetIndicatorSize))
		targetIndicator.petTexture = db.Seasonal.LoveFestivalTargetIndicatorPetByEnemyTexture
		targetIndicator.enemyTexture = db.Seasonal.LoveFestivalTargetIndicatorYouByEnemyTexture
		targetIndicator.friendTexture = db.Seasonal.LoveFestivalTargetIndicatorYouByFriendTexture
	end

	-- Textures need an update when frame is displayed.
	self.PostUpdate = UnitFrame_PostUpdate
	self.OnHide = TargetIndicator_Stop

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_LEVEL_UP", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UnitFrame_OnEvent, true)
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UnitFrame_OnEvent)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", UnitFrame_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", UnitFrame_OnEvent, true)
	self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", UnitFrame_OnEvent)

	-- Toggle name size based on ToT frame.
	ns.RegisterCallback(self, "UnitFrame_ToT_Updated", Name_PostUpdate)

	-- Fix unresponsive alpha on 3D Portrait.
	hooksecurefunc(UIParent, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)
	hooksecurefunc(self, "SetAlpha", function() self.Portrait:SetAlpha(self:GetEffectiveAlpha()) end)

end

TargetFrameMod.CreateUnitFrames = function(self)

	local unit, name = "target", "Target"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
end

TargetFrameMod.Update = function(self)
	UpdateTargetPowerValueText(self.frame)

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

	if (self.frame.Power and self.frame.Power.PostUpdate) then
		local currentPower = self.frame.Power.safeCur or self.frame.Power.cur or 0
		local maxPower = self.frame.Power.safeMax or self.frame.Power.max or 1
		self.frame.Power.PostUpdate(self.frame.Power, "target", currentPower, 0, maxPower)
	end

	self.frame.Name:SetShown(self.db.profile.showName)
	self.frame:PostUpdate()
end

TargetFrameMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(HUD_EDIT_MODE_TARGET_FRAME_LABEL or TARGET)

	ns.MovableModulePrototype.OnEnable(self)
end

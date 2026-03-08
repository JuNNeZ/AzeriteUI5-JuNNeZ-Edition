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
local Events = oUF.Tags.Events
local Methods = oUF.Tags.Methods

-- Lua API
local ipairs = ipairs
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_len = string.len
local tonumber = tonumber
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local AbbreviateName = ns.API.AbbreviateName
local AbbreviateNumber = ns.API.AbbreviateNumber
local AbbreviateNumbers = AbbreviateNumbers
local GetDifficultyColorByLevel = ns.API.GetDifficultyColorByLevel

-- Colors
local c_gray = Colors.gray.colorCode
local c_normal = Colors.normal.colorCode
local c_rare = Colors.quality.Rare.colorCode
local c_red = Colors.red.colorCode
local c_brightblue = Colors.brightblue.colorCode
local c_brightred = Colors.brightred.colorCode
local r = "|r"

-- Strings
local L_AFK = AFK
local L_DEAD = DEAD
local L_OFFLINE = PLAYER_OFFLINE
local L_RARE = ITEM_QUALITY3_DESC

-- Textures
local T_BOSS = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14:14:-2:1|t"

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local SafePercent

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

local EmitAbsorbTagDebug = function(frame, unit, fmt, ...)
	if (not ShouldDebugAbsorbUnit(unit)) then
		return
	end
	local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
	local key = "__AzeriteUI_LastAbsorbTagDebug"
	local last = frame and frame[key] or 0
	if ((now - last) < 0.2) then
		return
	end
	if (frame) then
		frame[key] = now
	end
	ns.API.DebugPrintf("Absorb", 4, fmt, ...)
end

local getargs = function(...)
	local args = {}
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		local num = tonumber(arg)
		if (num) then
			args[i] = num
		elseif (arg == "true" or arg == true) then
			args[i] = true
		elseif (arg == "nil" or arg == "false" or not arg) then
			args[i] = false
		else
			args[i] = arg
		end
	end
	return unpack(args)
end

local utf8sub = function(str, i, dots)
	if not str then return end
	local bytes = str:len()
	if bytes <= i then
		return str
	else
		local len, pos = 0, 1
		while pos <= bytes do
			len = len + 1
			local c = str:byte(pos)
			if c > 0 and c <= 127 then
				pos = pos + 1
			elseif c >= 192 and c <= 223 then
				pos = pos + 2
			elseif c >= 224 and c <= 239 then
				pos = pos + 3
			elseif c >= 240 and c <= 247 then
				pos = pos + 4
			end
			if len == i then break end
		end
		if len == i and pos <= bytes then
			return str:sub(1, pos - 1)..(dots and "..." or "")
		else
			return str
		end
	end
end

local SafeUnitName = function(unit)
	if (type(unit) ~= "string") then
		return nil
	end
	if (issecretvalue and issecretvalue(unit)) then
		return nil
	end
	local name = UnitName(unit)
	-- Reject secret values; these must never be used in addon logic (only pass to Blizzard widgets)
	if (issecretvalue and issecretvalue(name)) then
		return nil
	end
	if (type(name) == "string" and name ~= "") then
		return name
	end
	if (_G.GetUnitName) then
		local ok, altName = pcall(_G.GetUnitName, unit, false)
		-- Reject secret values; these must never be used in addon logic
		if (ok and issecretvalue and issecretvalue(altName)) then
			altName = nil
		end
		if (ok and type(altName) == "string" and altName ~= "") then
			return altName
		end
		ok, altName = pcall(_G.GetUnitName, unit, true)
		if (ok and issecretvalue and issecretvalue(altName)) then
			altName = nil
		end
		if (ok and type(altName) == "string" and altName ~= "") then
			return altName
		end
	end
	if (_G.UnitNameUnmodified) then
		local ok, altName = pcall(_G.UnitNameUnmodified, unit)
		if (ok and issecretvalue and issecretvalue(altName)) then
			altName = nil
		end
		if (ok and type(altName) == "string" and altName ~= "") then
			return altName
		end
	end
	return nil
end

local SafeUnitGUID = function(unit)
	if (type(unit) ~= "string") then
		return nil
	end
	if (issecretvalue and issecretvalue(unit)) then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) == "string" and (not issecretvalue or not issecretvalue(guid)) and guid ~= "") then
		return guid
	end
	return nil
end

local SafeUnitTokenEquals = function(left, right)
	if (type(left) ~= "string" or type(right) ~= "string") then
		return false
	end
	if (issecretvalue and (issecretvalue(left) or issecretvalue(right))) then
		return false
	end
	return left == right
end

local SafeBoolean = function(value, defaultValue)
	if (type(value) == "boolean" and (not issecretvalue or not issecretvalue(value))) then
		return value
	end
	return defaultValue and true or false
end

-- WoW 12.0.0: Safe value formatting that avoids arithmetic on secret values
local SafeNonEmptyString = function(value)
	if (type(value) ~= "string") then
		return false
	end
	-- Secret-string values can still error on operations/comparisons.
	-- Only treat it as safe if we can measure its length.
	local ok, len = pcall(string.len, value)
	return ok and len and len > 0
end

local FormatPercent = function(value)
	if (type(value) == "number") then
		local percent = value
		if (percent >= 0 and percent <= 1) then
			percent = percent * 100
		end
		if (percent < 0) then
			percent = 0
		elseif (percent > 100) then
			percent = 100
		end
		return string_format("%.0f%%", percent)
	end
	if (SafeNonEmptyString(value)) then
		return value .. "%"
	end
	return nil
end

local SafeValueToText = function(value)
	if not value then return "" end
	
	-- AbbreviateNumber can handle secret values internally
	local success, result = pcall(AbbreviateNumber, value)
	if success and SafeNonEmptyString(result) then
		return result
	end
	
	-- If it failed, try tostring as last resort
	local success2, str = pcall(tostring, value)
	if success2 and SafeNonEmptyString(str) then
		return str
	end
	
	return "?"
end

local HasDisplayValue = function(value)
	if (value == nil) then
		return false
	end
	if (issecretvalue and issecretvalue(value)) then
		return true
	end
	local valueType = type(value)
	if (valueType == "number") then
		return true
	end
	if (valueType == "string") then
		return SafeNonEmptyString(value)
	end
	return false
end

local IsZeroLikeText = function(value)
	if (type(value) ~= "string") then
		return false
	end
	if (issecretvalue) then
		local okSecret, isSecret = pcall(issecretvalue, value)
		if (okSecret and isSecret) then
			return false
		end
		if (not okSecret) then
			return false
		end
	end
	local okPlain, plain = pcall(string_gsub, value, "|c%x%x%x%x%x%x%x%x", "")
	if (not okPlain or type(plain) ~= "string") then
		return false
	end
	local okUnwrap, unwrapped = pcall(string_gsub, plain, "|r", "")
	if (okUnwrap and type(unwrapped) == "string") then
		plain = unwrapped
	end
	local okTrim, trimmed = pcall(string.gsub, plain, "%s+", "")
	if (not okTrim or type(trimmed) ~= "string") then
		return false
	end
	local okParen, noParen = pcall(string_gsub, trimmed, "[%(%)]", "")
	if (okParen and type(noParen) == "string") then
		trimmed = noParen
	end
	local okLower, lowered = pcall(string.lower, trimmed)
	if (not okLower or type(lowered) ~= "string") then
		return false
	end
	if (lowered == "<secret>" or lowered == "secret" or lowered == "?" or lowered == "nil") then
		return true
	end
	if (trimmed == "" or trimmed == "0" or trimmed == "0.0" or trimmed == "0K" or trimmed == "0M" or trimmed == "0B") then
		return true
	end
	local numeric = tonumber(trimmed)
	return (type(numeric) == "number" and numeric == 0)
end

local GetAbsorbFromCalculator = function(frame, unit)
	if (not frame or type(unit) ~= "string") then
		return nil, "no-frame-or-unit"
	end
	local prediction = frame.HealthPrediction
	if (not prediction) then
		return nil, "no-prediction"
	end
	local maxClampMode = Enum and Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MaximumHealth
	-- Prefer the same calculator instance updated by oUF for this frame.
	if (prediction.values) then
		if (maxClampMode ~= nil and prediction.values.SetDamageAbsorbClampMode and not prediction.__AzeriteUI_PredictionValuesClampModeApplied) then
			pcall(prediction.values.SetDamageAbsorbClampMode, prediction.values, maxClampMode)
			prediction.__AzeriteUI_PredictionValuesClampModeApplied = true
		end
	if (prediction.values.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(prediction.values.GetPredictedValues, prediction.values)
		if (okPredicted and type(predictedValues) == "table") then
			local totalDamageAbsorbs = predictedValues.totalDamageAbsorbs
			if (totalDamageAbsorbs ~= nil) then
				return totalDamageAbsorbs, "values.totalDamageAbsorbs"
			end
		end
	end
	if (prediction.values.GetDamageAbsorbs) then
		local okValues, valuesAbsorb = pcall(prediction.values.GetDamageAbsorbs, prediction.values)
		if (okValues and valuesAbsorb ~= nil) then
			return valuesAbsorb, "values.GetDamageAbsorbs"
		end
	end
	end
	if (not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction) then
		return nil, "no-calculator-api"
	end
	if (not prediction.__AzeriteUI_AbsorbCalculator) then
		prediction.__AzeriteUI_AbsorbCalculator = CreateUnitHealPredictionCalculator()
	end
	local calculator = prediction.__AzeriteUI_AbsorbCalculator
	if (not calculator) then
		return nil, "no-calculator"
	end
	if (maxClampMode ~= nil and calculator.SetDamageAbsorbClampMode and not prediction.__AzeriteUI_AbsorbCalculatorClampModeApplied) then
		pcall(calculator.SetDamageAbsorbClampMode, calculator, maxClampMode)
		prediction.__AzeriteUI_AbsorbCalculatorClampModeApplied = true
	end
	local okUpdate = pcall(UnitGetDetailedHealPrediction, unit, nil, calculator)
	if (not okUpdate) then
		okUpdate = pcall(UnitGetDetailedHealPrediction, unit, "player", calculator)
	end
	if (not okUpdate) then
		return nil, "calc.update-failed"
	end
	if (calculator.GetPredictedValues) then
		local okPredicted, predictedValues = pcall(calculator.GetPredictedValues, calculator)
		if (okPredicted and type(predictedValues) == "table") then
			local totalDamageAbsorbs = predictedValues.totalDamageAbsorbs
			if (totalDamageAbsorbs ~= nil) then
				return totalDamageAbsorbs, "calc.totalDamageAbsorbs"
			end
		end
	end
	local okAbsorb, absorb = pcall(calculator.GetDamageAbsorbs, calculator)
	if (not okAbsorb or absorb == nil) then
		return nil, "calc.GetDamageAbsorbs"
	end
	return absorb, "calc.GetDamageAbsorbs"
end

local ToAbsorbDisplayValue = function(value)
	if (issecretvalue and issecretvalue(value)) then
		return value, true
	end
	if (value == nil) then
		return nil, false
	end
	if (type(value) == "number") then
		if (value > 0) then
			return value, true
		end
		return nil, false
	end
	if (SafeNonEmptyString(value) and not IsZeroLikeText(value)) then
		return value, true
	end
	return nil, false
end

local SafeAbsorbValueText = function(absorb)
	if (issecretvalue and issecretvalue(absorb)) then
		if (type(AbbreviateNumbers) == "function") then
			local okFormat, formatted = pcall(AbbreviateNumbers, absorb)
			if (okFormat) then
				local safeFormatted, hasSafeFormatted = ToAbsorbDisplayValue(formatted)
				if (hasSafeFormatted) then
					return safeFormatted, true
				end
			end
		end
		-- Fallback to direct secret payload; oUF tag rendering can pass this safely.
		return absorb, true
	end
	if (absorb == nil) then
		return nil, false
	end
	if (type(AbbreviateNumbers) == "function") then
		local okFormat, formatted = pcall(AbbreviateNumbers, absorb)
		if (okFormat) then
			local safeFormatted, hasSafeFormatted = ToAbsorbDisplayValue(formatted)
			if (hasSafeFormatted) then
				if (type(safeFormatted) == "number") then
					local text = SafeValueToText(safeFormatted)
					if (text ~= "" and text ~= "0" and text ~= "?") then
						return text, true
					end
				else
					return safeFormatted, true
				end
			end
		end
	end
	if (type(absorb) ~= "number" or absorb <= 0) then
		return nil, false
	end
	local absorbText = SafeValueToText(absorb)
	if (absorbText ~= "" and absorbText ~= "0" and absorbText ~= "?") then
		return absorbText, true
	end
	return nil, false
end

local SafeHealthCurrentText = function(unit)
	local current = UnitHealth(unit)
	if (current == nil) then
		return nil
	end

	-- Prefer Blizzard formatter path for WoW12 secret-value compatibility.
	if (type(AbbreviateNumbers) == "function") then
		local ok, formatted = pcall(AbbreviateNumbers, current)
		if (ok and formatted ~= nil) then
			local valueType = type(formatted)
			if (valueType == "string" or valueType == "number") then
				return formatted
			end
			if (issecretvalue and issecretvalue(formatted)) then
				return formatted
			end
		end
	end

	return nil
end

local SafeHealthMaxText = function(unit)
	local maxHealth = UnitHealthMax(unit)
	if (maxHealth == nil) then
		return nil
	end

	if (type(AbbreviateNumbers) == "function") then
		local ok, formatted = pcall(AbbreviateNumbers, maxHealth)
		if (ok and formatted ~= nil) then
			local valueType = type(formatted)
			if (valueType == "string" or valueType == "number") then
				return formatted
			end
			if (issecretvalue and issecretvalue(formatted)) then
				return formatted
			end
		end
	end

	return nil
end

local SafePowerValueText = function(value)
	if (value == nil) then
		return nil
	end
	if (issecretvalue and issecretvalue(value)) then
		return nil
	end
	if (type(value) == "number") then
		if (value <= 0) then
			return nil
		end
	elseif (type(value) == "string") then
		local numeric = tonumber(value)
		if (numeric and numeric <= 0) then
			return nil
		end
	end
	if (type(AbbreviateNumbers) == "function") then
		local ok, formatted = pcall(AbbreviateNumbers, value)
		if (ok and formatted ~= nil) then
			local valueType = type(formatted)
			if (valueType == "string" or valueType == "number") then
				return formatted
			end
			if (issecretvalue and issecretvalue(formatted)) then
				return formatted
			end
		end
	end
	local fallback = SafeValueToText(value)
	if (fallback ~= "" and fallback ~= "?") then
		return fallback
	end
	return nil
end

local SafePowerValueFullText = function(value)
	if (value == nil) then
		return nil
	end
	if (type(value) == "number") then
		if (issecretvalue and issecretvalue(value)) then
			return nil
		end
		if (value <= 0) then
			return nil
		end
		return tostring(value)
	end
	if (type(value) == "string" and value ~= "") then
		if (issecretvalue and issecretvalue(value)) then
			return nil
		end
		local numeric = tonumber(value)
		if (numeric and numeric <= 0) then
			return nil
		end
		return value
	end
	return nil
end

local GetFrameManaElement = function(frame)
	if (not frame) then
		return nil
	end
	return frame.ManaOrb
end

local GetActiveFramePowerElement = function(frame, powerType)
	if (not frame) then
		return nil
	end
	local manaElement = GetFrameManaElement(frame)
	if (powerType == Enum.PowerType.Mana and manaElement and manaElement.IsShown and manaElement:IsShown()) then
		return manaElement
	end
	return frame.Power
end

local GetElementLiveValueRange = function(element)
	if (not element) then
		return nil, nil, nil
	end

	local value = nil
	local minValue = nil
	local maxValue = nil

	if (element.GetValue) then
		pcall(function()
			value = element:GetValue()
		end)
	end
	if (element.GetMinMaxValues) then
		pcall(function()
			minValue, maxValue = element:GetMinMaxValues()
		end)
	end

	if (type(value) ~= "number" or (issecretvalue and issecretvalue(value))) then
		value = element.safeCur or element.cur
	end
	if (type(minValue) ~= "number" or (issecretvalue and issecretvalue(minValue))) then
		minValue = element.safeMin or element.min or 0
	end
	if (type(maxValue) ~= "number" or (issecretvalue and issecretvalue(maxValue))) then
		maxValue = element.safeMax or element.max
	end

	return value, minValue, maxValue
end

local GetElementSafeValueRange = function(element)
	if (not element) then
		return nil, nil, nil
	end

	local value = element.safeCur or element.cur
	local minValue = element.safeMin or element.min or 0
	local maxValue = element.safeMax or element.max

	if (type(value) ~= "number" or (issecretvalue and issecretvalue(value))) then
		value = nil
	end
	if (type(minValue) ~= "number" or (issecretvalue and issecretvalue(minValue))) then
		minValue = nil
	end
	if (type(maxValue) ~= "number" or (issecretvalue and issecretvalue(maxValue))) then
		maxValue = nil
	end

	return value, minValue, maxValue
end

local GetFramePowerContext = function(frame, unit)
	local powerType = UnitPowerType(unit)
	local powerElement = GetActiveFramePowerElement(frame, powerType)
	if (powerElement and type(powerElement.displayType) == "number") then
		powerType = powerElement.displayType
	end
	return powerElement, powerType
end

local GetElementLivePercent = function(element, isPower)
	if (not element) then
		return nil
	end

	local value, minValue, maxValue = nil, nil, nil
	if (isPower) then
		value, minValue, maxValue = GetElementSafeValueRange(element)
	end
	if (type(value) ~= "number" or type(minValue) ~= "number" or type(maxValue) ~= "number") then
		value, minValue, maxValue = GetElementLiveValueRange(element)
	end
	local percent = nil
	local valueSafe = (type(value) == "number") and (not (issecretvalue and issecretvalue(value)))
	local minSafe = (type(minValue) == "number") and (not (issecretvalue and issecretvalue(minValue)))
	local maxSafe = (type(maxValue) == "number") and (not (issecretvalue and issecretvalue(maxValue)))
	if (valueSafe and minSafe and maxSafe) then
		if (isPower) then
			percent = SafePercent and SafePercent(value - minValue, maxValue - minValue)
		else
			percent = SafePercent and SafePercent(value, maxValue)
		end
	end
	if (type(percent) == "number") then
		return percent
	end

	local cachedPercent = element.safePercent
	if (type(cachedPercent) == "number" and not (issecretvalue and issecretvalue(cachedPercent))) then
		return cachedPercent
	end

	if (isPower) then
		local mirrorPercent = element.__AzeriteUI_MirrorPercent
		if (type(mirrorPercent) == "number" and not (issecretvalue and issecretvalue(mirrorPercent))) then
			return mirrorPercent
		end

		local texturePercent = element.__AzeriteUI_TexturePercent
		if (type(texturePercent) == "number" and not (issecretvalue and issecretvalue(texturePercent))) then
			return texturePercent
		end
	end

	return nil
end

-- WoW 12.0.0: If UnitHealth/UnitHealthMax are secret values, fall back to oUF frame bar values.
local SafeUnitPercent = function(unit, isPower, powerType)
	-- Prefer frame-authoritative values first so tag text follows rendered bars.
	local frame = _FRAME
	if (frame and SafeUnitTokenEquals(frame.unit, unit)) then
		local element
		if (isPower) then
			element, powerType = GetFramePowerContext(frame, unit)
		else
			element = frame.Health
		end
		if (element) then
			local percentFromBar = GetElementLivePercent(element, isPower)
			if (percentFromBar) then
				return percentFromBar
			end
		end
	end

	if (isPower) then
		local directCur = UnitPower(unit, powerType)
		local directMax = UnitPowerMax(unit, powerType)
		local directPercent = SafePercent(directCur, directMax)
		if (type(directPercent) == "number") then
			return directPercent
		end
	end

	local percent
	if (isPower and UnitPowerPercent) then
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitPowerPercent(unit, powerType, true, CurveConstants.ScaleTo100)
			else
				percent = UnitPowerPercent(unit, powerType)
			end
		end)
	elseif (not isPower and UnitHealthPercent) then
		pcall(function()
			if (CurveConstants and CurveConstants.ScaleTo100) then
				percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
			else
				percent = UnitHealthPercent(unit)
			end
		end)
	end
	if (type(percent) == "number") then
		if (issecretvalue and issecretvalue(percent)) then
			return nil
		end
		return percent
	end
	return nil
end

local SafeUnitHealth = function(unit)
	local cur = UnitHealth(unit)
	local max = UnitHealthMax(unit)
	local frame = _FRAME
	local GetHealthPercentHint = function()
		if (frame and SafeUnitTokenEquals(frame.unit, unit) and frame.Health and type(frame.Health.safePercent) == "number") then
			return frame.Health.safePercent
		end
		return SafeUnitPercent(unit, false)
	end

	local useFrameValues = false
	if (issecretvalue and (issecretvalue(cur) or issecretvalue(max))) then
		useFrameValues = true
	elseif (type(cur) ~= "number" or type(max) ~= "number") then
		useFrameValues = true
	end

	if (useFrameValues) then
		if (frame and SafeUnitTokenEquals(frame.unit, unit) and frame.Health) then
			pcall(function()
				local health = frame.Health
				local barVal = health.safeCur or health.cur
				local barMax = health.safeMax or health.max
				if (type(barVal) ~= "number") then
					barVal = health:GetValue()
				end
				if (type(barMax) ~= "number") then
					local _, m = health:GetMinMaxValues()
					barMax = m
				end
				if (type(barVal) == "number") then
					cur = barVal
				end
				if (type(barMax) == "number") then
					max = barMax
				end
			end)
		end
	end

	local maxIsSafeNumber = (type(max) == "number" and (not issecretvalue or not issecretvalue(max)))

	-- If current is secret but max is safe, derive current from percent API
	if (maxIsSafeNumber and (issecretvalue and issecretvalue(cur))) then
		local percent = GetHealthPercentHint()
		if (percent and not (issecretvalue and issecretvalue(percent))) then
			cur = max * (percent / 100)
		end
	end

	-- Correct stale numeric current values by using a safe percent hint.
	if (maxIsSafeNumber and type(cur) == "number" and (not issecretvalue or not issecretvalue(cur))) then
		local percent = GetHealthPercentHint()
		if (type(percent) == "number" and not (issecretvalue and issecretvalue(percent))) then
			if (percent < 0) then
				percent = 0
			elseif (percent > 100) then
				percent = 100
			end
			if (cur > max or (cur >= max and percent < 99.5) or (cur <= 0 and percent > 0.5)) then
				cur = max * (percent / 100)
			end
		end
	end

	-- If current is still secret or invalid, fall back to max
	if ((issecretvalue and issecretvalue(cur)) or type(cur) ~= "number") then
		local percent = GetHealthPercentHint()
		if (type(percent) == "number" and maxIsSafeNumber) then
			cur = max * (percent / 100)
		elseif (frame and SafeUnitTokenEquals(frame.unit, unit) and frame.Health) then
			local health = frame.Health
			local cachedCur = health.safeCur or health.cur
			if (type(cachedCur) == "number" and (not issecretvalue or not issecretvalue(cachedCur))) then
				cur = cachedCur
			elseif (type(health.safePercent) == "number" and type(max) == "number" and (not issecretvalue or not issecretvalue(max))) then
				cur = max * (health.safePercent / 100)
			end
		end
		if (((issecretvalue and issecretvalue(cur)) or type(cur) ~= "number") and maxIsSafeNumber) then
			cur = max
		end
	end

	return cur, max
end

-- WoW 12.0.0: Safe power values based on frame bar values when available

local SafeUnitPower = function(unit, powerType)
	local cur = UnitPower(unit, powerType)
	local max = UnitPowerMax(unit, powerType)
	local frame = _FRAME
	local powerElement = nil
	if (frame and SafeUnitTokenEquals(frame.unit, unit)) then
		powerElement, powerType = GetFramePowerContext(frame, unit)
		if (powerElement) then
			local safeCur, _, safeMax = GetElementSafeValueRange(powerElement)
			if (type(safeCur) == "number" and (not issecretvalue or not issecretvalue(safeCur))) then
				cur = safeCur
			else
				cur = UnitPower(unit, powerType)
			end
			if (type(safeMax) == "number" and (not issecretvalue or not issecretvalue(safeMax))) then
				max = safeMax
			else
				max = UnitPowerMax(unit, powerType)
			end
		else
			cur = UnitPower(unit, powerType)
			max = UnitPowerMax(unit, powerType)
		end
	end

	local useFrameValues = false
	if (issecretvalue and (issecretvalue(cur) or issecretvalue(max))) then
		useFrameValues = true
	elseif (type(cur) ~= "number" or type(max) ~= "number") then
		useFrameValues = true
	end

	if (useFrameValues) then
		if (powerElement) then
			pcall(function()
				local barVal, _, barMax = GetElementSafeValueRange(powerElement)
				if (type(barVal) ~= "number" or type(barMax) ~= "number") then
					barVal, _, barMax = GetElementLiveValueRange(powerElement)
				end
				if (type(barVal) == "number") then
					cur = barVal
				end
				if (type(barMax) == "number") then
					max = barMax
				end
			end)
		end
	end

	local maxIsSafeNumber = (type(max) == "number" and (not issecretvalue or not issecretvalue(max)) and max > 0)

	-- If current is secret but max is safe, derive current from percent API
	if (maxIsSafeNumber
		and (issecretvalue and issecretvalue(cur))) then
		local percent = SafeUnitPercent(unit, true, powerType)
		if (percent and not (issecretvalue and issecretvalue(percent))) then
			cur = max * (percent / 100)
		end
	end

	-- Correct stale numeric current values by using a safe percent hint.
	if (maxIsSafeNumber and type(cur) == "number" and (not issecretvalue or not issecretvalue(cur))) then
		local percent = nil
		if (powerElement) then
			percent = GetElementLivePercent(powerElement, true)
		end
		if (type(percent) ~= "number") then
			percent = SafeUnitPercent(unit, true, powerType)
		end
		if (type(percent) == "number" and not (issecretvalue and issecretvalue(percent))) then
			if (percent < 0) then
				percent = 0
			elseif (percent > 100) then
				percent = 100
			end
			if (cur > max or (cur >= max and percent < 99.5) or (cur <= 0 and percent > 0.5)) then
				cur = max * (percent / 100)
			end
		end
	end

	-- If current is still secret or invalid, fall back to max
	if ((issecretvalue and issecretvalue(cur)) or type(cur) ~= "number") then
		if (powerElement) then
			local cachedCur = powerElement.safeCur or powerElement.cur
			if (type(cachedCur) == "number" and (not issecretvalue or not issecretvalue(cachedCur))) then
				cur = cachedCur
			end
		end
		if (((issecretvalue and issecretvalue(cur)) or type(cur) ~= "number") and maxIsSafeNumber) then
			cur = max
		end
	end

	return cur, max
end

-- WoW 12.0.0: Safe percentage calculation - ONLY for non-secret values
SafePercent = function(cur, max)
	if not cur or not max then return nil end
	
	-- Secret values can't be used in arithmetic - skip them
	if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then
		return nil
	end
	
	if type(cur) ~= "number" or type(max) ~= "number" then return nil end
	if max == 0 then return nil end
	
	-- Try calculation in pcall
	local success, percent = pcall(function()
		return (cur / max * 100) + 0.5
	end)
	
	if success and type(percent) == "number" then
		return percent - (percent % 1)
	end
	
	return nil
end

-- Tags
---------------------------------------------------------------------
if (ns.IsRetail) then
	Events[prefix("*:Absorb")] = "UNIT_ABSORB_AMOUNT_CHANGED UNIT_HEAL_PREDICTION PLAYER_TARGET_CHANGED UNIT_AURA UNIT_HEALTH UNIT_MAXHEALTH PLAYER_ENTERING_WORLD"
	Methods[prefix("*:Absorb")] = function(unit)
		if (UnitIsDeadOrGhost(unit)) then
			return
		else
			local frame = _FRAME
			local frameHealth = (frame and SafeUnitTokenEquals(frame.unit, unit)) and frame.Health or nil
			local absorbValue = nil
			local hasAbsorbValue = false
			local sourceUsed = nil
			local cacheAbsorb = frameHealth and frameHealth.safeAbsorb or nil
			local cacheKnownZero = frameHealth and frameHealth.safeAbsorbKnownZero or false
			local calcAbsorb = nil
			local calcSource = nil
			local totalAbsorb = nil
			local ResolveAbsorbValue = function(value)
				return SafeAbsorbValueText(value)
			end
			if (frameHealth) then
				absorbValue, hasAbsorbValue = ResolveAbsorbValue(cacheAbsorb)
				if (hasAbsorbValue) then
					sourceUsed = "cache"
				elseif (cacheKnownZero) then
					sourceUsed = "cache-zero"
				end
			end
			if ((not hasAbsorbValue) and frame and (not cacheKnownZero)) then
				calcAbsorb, calcSource = GetAbsorbFromCalculator(frame, unit)
				absorbValue, hasAbsorbValue = ResolveAbsorbValue(calcAbsorb)
				if (hasAbsorbValue) then
					sourceUsed = calcSource or "calculator"
				end
			end
			if ((not hasAbsorbValue) and UnitGetTotalAbsorbs and (not cacheKnownZero)) then
				totalAbsorb = UnitGetTotalAbsorbs(unit)
				absorbValue, hasAbsorbValue = ResolveAbsorbValue(totalAbsorb)
				if (hasAbsorbValue) then
					sourceUsed = "UnitGetTotalAbsorbs"
				end
			end
			if (not sourceUsed) then
				sourceUsed = "none"
			end
			EmitAbsorbTagDebug(frame, unit,
				"Tag unit=%s frameUnit=%s cache=%s calc=%s calcSource=%s total=%s out=%s source=%s",
				unit,
				frame and frame.unit or nil,
				cacheAbsorb,
				calcAbsorb,
				calcSource,
				totalAbsorb,
				absorbValue,
				sourceUsed)
			-- Stable behavior:
			-- do not force fallback "0" when absorb is unresolved/secret.
			-- Returning nil hides absorb text until a usable payload arrives.
			if (hasAbsorbValue) then
				if (type(absorbValue) == "number" and (not (issecretvalue and issecretvalue(absorbValue))) and absorbValue <= 0) then
					return nil
				end
				if (type(absorbValue) == "string" and IsZeroLikeText(absorbValue)) then
					return nil
				end
				local wrapPrefix = c_gray.." ("..r..c_normal
				local wrapSuffix = r..c_gray..")"..r
				if (C_StringUtil and C_StringUtil.WrapString) then
					-- Match stock visuals while keeping secret payload handling safe.
					return C_StringUtil.WrapString(absorbValue, wrapPrefix, wrapSuffix)
				end
				if (issecretvalue and issecretvalue(absorbValue)) then
					return absorbValue
				end
				return wrapPrefix..tostring(absorbValue)..wrapSuffix
			end
			return nil
		end
	end
end

Events[prefix("*:Classification")] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"
if (oUF.isClassic or oUF.isTBC or oUF.isWrath or oUF.isCata) then
	Methods[prefix("*:Classification")] = function(unit)
		local l = UnitEffectiveLevel(unit)
		local c = UnitClassification(unit)
		if (c == "worldboss" or (not l) or (l < 1)) then
			return
		end
		if (c == "elite" or c == "rareelite") then
			return c_red.."+"..r.." "
		end
		return " "
	end
else
	Methods[prefix("*:Classification")] = function(unit)
		local l = UnitEffectiveLevel(unit)
		if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
			l = UnitBattlePetLevel(unit)
		end
		local c = UnitClassification(unit)
		if (c == "worldboss" or (not l) or (l < 1)) then
			return
		end
		if (c == "elite" or c == "rareelite") then
			return c_red.."+"..r.." "
		end
		return " "
	end
end

Events[prefix("*:Health")] = "UNIT_HEALTH UNIT_MAXHEALTH PLAYER_FLAGS_CHANGED UNIT_CONNECTION GROUP_ROSTER_UPDATE"
Methods[prefix("*:Health")] = function(unit, realUnit, ...)
	local useSmart, useFull, hideStatus, showAFK = getargs(...)
	local isDead = SafeBoolean(UnitIsDeadOrGhost(unit), false)
	local isConnected = SafeBoolean(UnitIsConnected(realUnit or unit), true)
	local isAFK = SafeBoolean(UnitIsAFK(realUnit or unit), false)
	if (isDead) then
		return not hideStatus and L_DEAD
	elseif (not isConnected) then
		return not hideStatus and L_OFFLINE
	elseif (showAFK and isAFK) then
		return L_AFK
	else
		local health, maxHealth = SafeUnitHealth(unit)
		
		if (useSmart) then
			-- Try percent first
			local percent = SafePercent(health, maxHealth)
			if percent and percent < 100 then
				return percent
			end
			-- Fall back to direct formatted current health (secret-safe).
			local healthText = SafeHealthCurrentText(unit)
			if (HasDisplayValue(healthText)) then
				return healthText
			end
			healthText = SafeValueToText(health)
			if (HasDisplayValue(healthText) and healthText ~= "?") then
				return healthText
			end
			return ""
			
		elseif (useFull) then
			local healthText = SafeHealthCurrentText(unit)
			if (not HasDisplayValue(healthText)) then
				healthText = SafeValueToText(health)
			end
			local maxHealthText = SafeHealthMaxText(unit)
			if (not HasDisplayValue(maxHealthText)) then
				maxHealthText = SafeValueToText(maxHealth)
			end
			if (HasDisplayValue(healthText) and HasDisplayValue(maxHealthText) and healthText ~= "?" and maxHealthText ~= "?") then
				return healthText..c_gray.."/"..r..maxHealthText
			end
			return ""
			
		else
			local healthText = SafeValueToText(health)
			if healthText ~= "" then return healthText end
		end
	end
end

Events[prefix("*:HealthCurrent")] = "UNIT_HEALTH UNIT_MAXHEALTH PLAYER_FLAGS_CHANGED UNIT_CONNECTION GROUP_ROSTER_UPDATE"
Methods[prefix("*:HealthCurrent")] = function(unit, realUnit, ...)
	local _, _, hideStatus, showAFK = getargs(...)
	local isDead = SafeBoolean(UnitIsDeadOrGhost(unit), false)
	local isConnected = SafeBoolean(UnitIsConnected(realUnit or unit), true)
	local isAFK = SafeBoolean(UnitIsAFK(realUnit or unit), false)
	if (isDead) then
		return not hideStatus and L_DEAD
	elseif (not isConnected) then
		return not hideStatus and L_OFFLINE
	elseif (showAFK and isAFK) then
		return L_AFK
	else
		local directText = SafeHealthCurrentText(unit)
		if (directText ~= nil) then
			return directText
		end

		local health = SafeUnitHealth(unit)
		local fallbackText = SafeValueToText(health)
		if (fallbackText ~= "") then
			return fallbackText
		end
	end
end

Events[prefix("*:HealthPercent")] = "UNIT_HEALTH UNIT_MAXHEALTH PLAYER_FLAGS_CHANGED UNIT_CONNECTION"
Methods[prefix("*:HealthPercent")] = function(unit)
	if (UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit)) then
		return
	else
		local frame = _FRAME
		if (frame and frame.Health) then
			local healthCur = frame.Health.safeCur or frame.Health.cur
			local healthMax = frame.Health.safeMax or frame.Health.max
			local framePercent = SafePercent(healthCur, healthMax)
			if (type(framePercent) == "number") then
				frame.Health.safePercent = framePercent
				return FormatPercent(framePercent)
			end
			if (type(frame.Health.safePercent) == "number") then
				return FormatPercent(frame.Health.safePercent)
			end
		end

		local health, maxHealth = SafeUnitHealth(unit)
		local fallback = SafePercent(health, maxHealth)
		if (type(fallback) == "number") then
			return FormatPercent(fallback)
		end

		local percent = SafeUnitPercent(unit, false)
		if (type(percent) == "number") then
			return FormatPercent(percent)
		end

		return ""
	end
end

Events[prefix("*:PowerPercent")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:PowerPercent")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local powerElement, powerType = GetFramePowerContext(frame, unit)
		if (powerElement) then
			local framePercent = GetElementLivePercent(powerElement, true)
			if (type(framePercent) == "number") then
				powerElement.safePercent = framePercent
				return FormatPercent(framePercent)
			end
		end
		local power, powerMax = SafeUnitPower(unit, powerType)
		local fallback = SafePercent(power, powerMax)
		if (type(fallback) == "number") then
			return FormatPercent(fallback)
		end
		local percent = SafeUnitPercent(unit, true, powerType)
		if (type(percent) == "number") then
			return FormatPercent(percent)
		end
		local rawCur = UnitPower(unit, powerType)
		local rawMax = UnitPowerMax(unit, powerType)
		local rawPercent = SafePercent(rawCur, rawMax)
		if (type(rawPercent) == "number") then
			return FormatPercent(rawPercent)
		end
		if (powerElement and type(powerElement.safePercent) == "number") then
			return FormatPercent(powerElement.safePercent)
		end
		return ""
	end
end

Events[prefix("*:ManaPercent")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:ManaPercent")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local manaElement = GetFrameManaElement(frame)
		if (frame and manaElement) then
			local framePercent = GetElementLivePercent(manaElement, true)
			if (type(framePercent) == "number") then
				manaElement.safePercent = framePercent
				return FormatPercent(framePercent)
			end
		end
		local mana, manaMax = SafeUnitPower(unit, Enum.PowerType.Mana)
		local fallback = SafePercent(mana, manaMax)
		if (type(fallback) == "number") then
			return FormatPercent(fallback)
		end
		local percent = SafeUnitPercent(unit, true, Enum.PowerType.Mana)
		if (type(percent) == "number") then
			return FormatPercent(percent)
		end
		local rawMana = UnitPower(unit, Enum.PowerType.Mana)
		local rawManaMax = UnitPowerMax(unit, Enum.PowerType.Mana)
		local rawPercent = SafePercent(rawMana, rawManaMax)
		if (type(rawPercent) == "number") then
			return FormatPercent(rawPercent)
		end
		if (frame and manaElement and type(manaElement.safePercent) == "number") then
			return FormatPercent(manaElement.safePercent)
		end
		return ""
	end
end

Events[prefix("*:Mana")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Mana")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local manaElement = GetFrameManaElement(frame)
		if (frame and manaElement) then
			local cachedCur = manaElement.safeCur or manaElement.cur
			local cachedText = SafePowerValueText(cachedCur)
			if (cachedText ~= nil) then
				return cachedText
			end
		end
		local mana = SafeUnitPower(unit, Enum.PowerType.Mana)
		local manaText = SafeValueToText(mana)
		if manaText ~= "" then return manaText end
	end
end

Events[prefix("*:Mana:Full")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Mana:Full")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	end
	local frame = _FRAME
	local manaElement = GetFrameManaElement(frame)
	if (frame and manaElement) then
		local safeCurText = SafePowerValueText(manaElement.safeCur or manaElement.cur)
		local safeMaxText = SafePowerValueText(manaElement.safeMax or manaElement.max)
		if (safeCurText ~= nil and safeMaxText ~= nil) then
			return safeCurText..c_gray.."/"..r..safeMaxText
		end
	end
	local mana, manaMax = SafeUnitPower(unit, Enum.PowerType.Mana)
	local manaText = SafePowerValueText(mana)
	local manaMaxText = SafePowerValueText(manaMax)
	if (manaText ~= nil and manaMaxText ~= nil) then
		return manaText..c_gray.."/"..r..manaMaxText
	end
end

Events[prefix("*:Mana:FullNumber")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Mana:FullNumber")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	end
	local frame = _FRAME
	local manaElement = GetFrameManaElement(frame)
	if (frame and manaElement) then
		local safeCurText = SafePowerValueFullText(manaElement.safeCur or manaElement.cur)
		if (safeCurText ~= nil) then
			return safeCurText
		end
	end
	local mana = SafeUnitPower(unit, Enum.PowerType.Mana)
	return SafePowerValueFullText(mana)
end

Events[prefix("*:Mana:ShortPercent")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Mana:ShortPercent")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	end
	local short = Methods[prefix("*:Mana")](unit)
	local percent = Methods[prefix("*:ManaPercent")](unit)
	if (short and percent) then
		return tostring(short) .. c_gray .. " (" .. r .. tostring(percent) .. c_gray .. ")" .. r
	end
	if (short) then
		return short
	end
	return percent
end

Events[prefix("*:ManaText:Low")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:ManaText:Low")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local mana, maxMana = SafeUnitPower(unit, Enum.PowerType.Mana)
		local percent = SafePercent(mana, maxMana)
		
		if percent then
			if percent < 35 then
				return c_brightred .. percent .. r
			elseif percent < 85 then
				return c_brightblue .. percent .. r
			end
		end
	end
end

Events[prefix("*:Name")] = "UNIT_NAME_UPDATE UNIT_LEVEL PLAYER_LEVEL_UP GROUP_ROSTER_UPDATE"
Methods[prefix("*:Name")] = function(unit, realUnit, ...)
	local frame = _FRAME
	local unitName = SafeUnitName(unit)
	local realUnitName = SafeUnitName(realUnit)
	local name = unitName or realUnitName
	local unitGUID = SafeUnitGUID(unit)
	local realUnitGUID = SafeUnitGUID(realUnit)
	local guid = unitGUID or realUnitGUID
	local levelUnit = unitName and unit or realUnit or unit

	-- If no non-secret name was found, try raw UnitName.
	-- Secret strings can be passed directly to widget SetFormattedText/SetText.
	-- oUF's tag wrapper (issecretvalue check) will handle secret returns.
	if (not name) then
		local rawUnit = (type(unit) == "string") and unit or nil
		local rawRealUnit = (type(realUnit) == "string") and realUnit or nil
		if (rawUnit) then
			local rawName = UnitName(rawUnit)
			if (type(rawName) == "string") then
				-- Cache what we can for future lookups
				if (frame and guid and not issecretvalue(rawName)) then
					frame.__AzeriteUI_LastSafeName = rawName
					frame.__AzeriteUI_LastSafeNameGUID = guid
				end
				return rawName
			end
		end
		if (rawRealUnit) then
			local rawName = UnitName(rawRealUnit)
			if (type(rawName) == "string") then
				if (frame and guid and not issecretvalue(rawName)) then
					frame.__AzeriteUI_LastSafeName = rawName
					frame.__AzeriteUI_LastSafeNameGUID = guid
				end
				return rawName
			end
		end
		-- Last resort: use cached name if GUID matches
		if (frame and frame.__AzeriteUI_LastSafeName and guid and frame.__AzeriteUI_LastSafeNameGUID == guid) then
			name = frame.__AzeriteUI_LastSafeName
		else
			return ""
		end
	end

	if (name and frame and guid) then
		frame.__AzeriteUI_LastSafeName = name
		frame.__AzeriteUI_LastSafeNameGUID = guid
	elseif (frame and frame.__AzeriteUI_LastSafeName and (not guid)) then
		frame.__AzeriteUI_LastSafeName = nil
		frame.__AzeriteUI_LastSafeNameGUID = nil
	end
	if (not name) then
		return ""
	end

	local maxChars, showLevel, showLevelLast, showFull = getargs(...)
	local levelTextLength, levelText, shouldShowLevel = 0, nil, nil
	local fullName, fullLength = name, string_len(name) + (shouldShowLevel and levelTextLength or 0)
	local abbreviatedLength

	-- Create level text if requested.
	if (showLevel) then
		local level = UnitEffectiveLevel(levelUnit)
		if (level and level > 0) then
			local _,_,_,colorCode = GetDifficultyColorByLevel(level)
			levelText = colorCode .. level .. "|r"
			levelTextLength = level >= 100 and 5 or level >= 10 and 4 or 3
			shouldShowLevel = true
		end
	end

	-- Abbreviate when needed, but not when we have space.
	if (not showFull) and (not maxChars or fullLength > maxChars) then
		name = AbbreviateName(name)
		abbreviatedLength = string_len(name) + (shouldShowLevel and levelTextLength or 0)
	end

	-- Truncate when needed. Messy.
	if (maxChars) and (showFull and fullLength > maxChars) or (abbreviatedLength and abbreviatedLength > maxChars) then
		name = utf8sub(name, showLevel and (maxChars - levelTextLength) or maxChars)
	end

	if (shouldShowLevel) then
		if (showLevelLast) then
			name = name .. " |cff888888:|r" .. levelText
		else
			name = levelText .. "|cff888888:|r " .. name
		end
	end

	return name
end

Events[prefix("*:Power")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Power")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local powerElement, powerType = GetFramePowerContext(frame, unit)
		if (powerElement) then
			local cachedCur = (select(1, GetElementSafeValueRange(powerElement)))
			local safeCurText = SafePowerValueText(cachedCur)
			if (safeCurText ~= nil) then
				return safeCurText
			end
		end
		local power = SafeUnitPower(unit, powerType)
		local powerText = SafePowerValueText(power)
		if (powerText ~= nil) then
			return powerText
		end
		local rawCur = UnitPower(unit, powerType)
		local rawText = SafePowerValueText(rawCur)
		if (rawText ~= nil) then
			return rawText
		end
	end
end

Events[prefix("*:Power:Full")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Power:Full")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local powerElement, powerType = GetFramePowerContext(frame, unit)
		if (powerElement) then
			local safeCur, _, safeMax = GetElementSafeValueRange(powerElement)
			local safeCurText = SafePowerValueText(safeCur)
			local safeMaxText = SafePowerValueText(safeMax)
			if (safeCurText ~= nil and safeMaxText ~= nil) then
				return safeCurText..c_gray.."/"..r..safeMaxText
			end
		end
		local power, powerMax = SafeUnitPower(unit, powerType)
		local powerText = SafePowerValueText(power)
		local powerMaxText = SafePowerValueText(powerMax)
		if (powerText ~= nil and powerMaxText ~= nil) then
			return powerText..c_gray.."/"..r..powerMaxText
		end
		local rawCur = UnitPower(unit, powerType)
		local rawMax = UnitPowerMax(unit, powerType)
		local rawCurText = SafePowerValueText(rawCur)
		local rawMaxText = SafePowerValueText(rawMax)
		if (rawCurText ~= nil and rawMaxText ~= nil) then
			return rawCurText..c_gray.."/"..r..rawMaxText
		end
	end
end

Events[prefix("*:Power:FullNumber")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Power:FullNumber")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	else
		local frame = _FRAME
		local powerElement, powerType = GetFramePowerContext(frame, unit)
		if (powerElement) then
			local safeCurText = SafePowerValueFullText(select(1, GetElementSafeValueRange(powerElement)))
			if (safeCurText ~= nil) then
				return safeCurText
			end
		end
		local power = SafeUnitPower(unit, powerType)
		local powerText = SafePowerValueFullText(power)
		if (powerText ~= nil) then
			return powerText
		end
		local rawCur = UnitPower(unit, powerType)
		local rawCurText = SafePowerValueFullText(rawCur)
		if (rawCurText ~= nil) then
			return rawCurText
		end
	end
end

Events[prefix("*:Power:ShortPercent")] = "UNIT_POWER_FREQUENT UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE"
Methods[prefix("*:Power:ShortPercent")] = function(unit)
	if (UnitIsDeadOrGhost(unit)) then
		return
	end
	local short = Methods[prefix("*:Power")](unit)
	local percent = Methods[prefix("*:PowerPercent")](unit)
	if (short and percent) then
		return tostring(short) .. c_gray .. " (" .. r .. tostring(percent) .. c_gray .. ")" .. r
	end
	if (short) then
		return short
	end
	return percent
end

Events[prefix("*:Rare")] = "UNIT_CLASSIFICATION_CHANGED"
Methods[prefix("*:Rare")] = function(unit)
	local classification = UnitClassification(unit)
	local rare = classification == "rare" or classification == "rareelite"
	if (rare) then
		return c_rare.."("..L_RARE..")"..r
	end
end

Events[prefix("*:Rare:Suffix")] = "UNIT_CLASSIFICATION_CHANGED"
Methods[prefix("*:Rare:Suffix")] = function(unit)
	local r = Methods[prefix("*:Rare")](unit)
	return r and " "..r
end

Events[prefix("*:Dead")] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
Methods[prefix("*:Dead")] = function(unit)
	return UnitIsConnected(unit) and UnitIsDeadOrGhost(unit) and L_DEAD
end

Events[prefix("*:Offline")] = "UNIT_CONNECTION"
Methods[prefix("*:Offline")] = function(unit)
	return not UnitIsConnected(unit) and L_OFFLINE
end

Events[prefix("*:DeadOrOffline")] = "UNIT_CONNECTION UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
Methods[prefix("*:DeadOrOffline")] = function(unit)
	return not UnitIsConnected(unit) and L_OFFLINE or UnitIsDeadOrGhost(unit) and L_DEAD
end

Events[prefix("*:Level")] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"
if (oUF.isClassic or oUF.isTBC or oUF.isWrath or oUF.isCata) then
	Methods[prefix("*:Level")] = function(unit, asPrefix)
		local l = UnitEffectiveLevel(unit)
		local c = UnitClassification(unit)
		if (c == "worldboss" or (not l) or (l < 1)) then
			return T_BOSS
		end
		local _,_,_,colorCode = GetDifficultyColorByLevel(l)
		if (c == "elite" or c == "rareelite") then
			return colorCode..l..r..c_red.."+"..r
		end
		if (asPrefix) then
			return colorCode..l..r..c_gray..":"..r
		else
			return colorCode..l..r
		end
	end
else
	Methods[prefix("*:Level")] = function(unit, realUnit, asPrefix)
		local l = UnitEffectiveLevel(unit)
		if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
			l = UnitBattlePetLevel(unit)
		end
		local c = UnitClassification(unit)
		if (c == "worldboss" or (not l) or (l < 1)) then
			return T_BOSS
		end
		local _,_,_,colorCode = GetDifficultyColorByLevel(l)
		if (c == "elite" or c == "rareelite") then
			return colorCode..l..r..c_red.."+"..r
		end
		if (asPrefix) then
			return colorCode..l..r..c_gray..":"..r
		else
			return colorCode..l..r
		end
	end
end

Events[prefix("*:Level:Prefix")] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"
Methods[prefix("*:Level:Prefix")] = function(unit, realUnit)
	local l = Methods[prefix("*:Level")](unit, realUnit, true)
	return (l and l ~= T_BOSS) and l.." " or l
end

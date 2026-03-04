--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

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
local API = ns.API
local string_format = string.format
local math_abs = math.abs
local POWER_TYPE_MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

-- Debug toggles (off by default)
API.DEBUG_HEALTH = API.DEBUG_HEALTH or false
API.DEBUG_HEALTH_CHAT = API.DEBUG_HEALTH_CHAT or false

local SanitizeDebugValue = function(value)
	if (issecretvalue and issecretvalue(value)) then
		return "<secret>"
	end
	local valueType = type(value)
	if (valueType == "string" or valueType == "number" or valueType == "boolean") then
		return value
	end
	if (value == nil) then
		return "nil"
	end
	return tostring(value)
end

API.DebugPrintf = API.DebugPrintf or function(category, verbosity, fmt, ...)
	local count = select("#", ...)
	local args = {}
	for index = 1, count do
		args[index] = SanitizeDebugValue(select(index, ...))
	end
	local ok, message = pcall(string_format, fmt, unpack(args, 1, count))
	if (not ok or type(message) ~= "string") then
		return
	end
	if (issecretvalue and issecretvalue(message)) then
		message = "<secret>"
	end
	local prefix = ""
	if (type(category) == "string" and category ~= "") then
		prefix = prefix .. category .. "~"
	end
	if (type(verbosity) == "number") then
		prefix = prefix .. tostring(verbosity) .. "~"
	end
	local payload = prefix .. SanitizeDebugValue(message)
	if (DLAPI and DLAPI.DebugLog) then
		local writeOK = pcall(DLAPI.DebugLog, "AzeriteUI", payload)
		if (writeOK) then
			return
		end
	end
	if (API.DEBUG_HEALTH_CHAT) then
		local chatFrame = DEFAULT_CHAT_FRAME
		if (chatFrame and chatFrame.AddMessage) then
			chatFrame:AddMessage(payload)
		end
	end
end

local ShouldDebugUnit = function(unit)
	if (not API.DEBUG_HEALTH_CHAT) then
		return false
	end
	if (type(unit) ~= "string" or unit == "") then
		return false
	end
	local filter = API.DEBUG_HEALTH_FILTER
	if (type(filter) ~= "string" or filter == "") then
		return true
	end
	filter = filter:lower()
	if (unit:lower():find(filter, 1, true) ~= nil) then
		return true
	end
	-- Debug UI historically used defaults like "Target."; make it unit-token friendly.
	local compact = filter:gsub("[^%a%d_]", "")
	if (compact ~= "" and unit:lower():find(compact, 1, true) ~= nil) then
		return true
	end
	return false
end

local ShouldEmitTick = function(element, field, interval)
	local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
	local last = element and element[field] or 0
	if ((now - last) < (interval or 0.25)) then
		return false
	end
	if (element) then
		element[field] = now
	end
	return true
end

local IsSecretValue = function(value)
	return issecretvalue and issecretvalue(value)
end

local CanAccessValue = function(value)
	-- WoW12 safeguard: avoid canaccessvalue recursion/stack overflows.
	-- For addon-side numeric logic, only treat non-secret values as safe.
	return not IsSecretValue(value)
end

local IsSafeNumeric = function(value)
	return (type(value) == "number") and CanAccessValue(value)
end

local IsSafeGreaterThan = function(left, right)
	if (not IsSafeNumeric(left) or not IsSafeNumeric(right)) then
		return false
	end
	local ok, result = pcall(function()
		return left > right
	end)
	return ok and result and true or false
end

local HasSafeNumericRange = function(minValue, maxValue)
	return IsSafeGreaterThan(maxValue, minValue)
end

local SetStatusBarValuesCompat = function(element, minValue, maxValue, value, forced)
	if (not element) then
		return
	end
	local smoothing = element.smoothing
	local okNative = pcall(function()
		element:SetMinMaxValues(minValue, maxValue)
		if (smoothing ~= nil) then
			element:SetValue(value, smoothing)
		else
			element:SetValue(value)
		end
	end)
	if (not okNative) then
		pcall(function()
			element:SetMinMaxValues(minValue, maxValue, forced)
			element:SetValue(value, forced)
		end)
	end
end

local SafePercentFromValues = function(cur, max)
	if (type(cur) ~= "number" or type(max) ~= "number" or max <= 0) then
		return nil
	end
	local success, result = pcall(function()
		return (cur / max * 100) + 0.5
	end)
	if (success and type(result) == "number") then
		return result - (result % 1)
	end
	return nil
end

local SafeUnitPercentNumber = function(unit, isPower, powerType)
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
	if (IsSafeNumeric(percent)) then
		return percent
	end
	return nil
end

local NormalizePercent100 = function(percent)
	if (type(percent) ~= "number") then
		return nil
	end
	if (percent >= 0 and percent <= 1) then
		percent = percent * 100
	end
	if (percent < 0) then
		return 0
	elseif (percent > 100) then
		return 100
	end
	return percent
end

local ProbeSafePercentAPI = function(unit, isPower, powerType)
	local candidates = {}
	local InsertCandidate = function(value)
		if (IsSafeNumeric(value)) then
			local normalized = NormalizePercent100(value)
			if (type(normalized) == "number") then
				candidates[#candidates + 1] = normalized
			end
		end
	end
	if (isPower) then
		if (not UnitPowerPercent) then
			return nil
		end
		pcall(function() InsertCandidate(UnitPowerPercent(unit, powerType)) end)
		pcall(function() InsertCandidate(UnitPowerPercent(unit, nil)) end)
		pcall(function() InsertCandidate(UnitPowerPercent(unit, powerType, true)) end)
		pcall(function() InsertCandidate(UnitPowerPercent(unit, nil, true)) end)
		if (CurveConstants and CurveConstants.ScaleTo100) then
			pcall(function() InsertCandidate(UnitPowerPercent(unit, powerType, true, CurveConstants.ScaleTo100)) end)
			pcall(function() InsertCandidate(UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100)) end)
		end
	else
		if (not UnitHealthPercent) then
			return nil
		end
		pcall(function() InsertCandidate(UnitHealthPercent(unit)) end)
		pcall(function() InsertCandidate(UnitHealthPercent(unit, false)) end)
		pcall(function() InsertCandidate(UnitHealthPercent(unit, true)) end)
		if (CurveConstants and CurveConstants.ScaleTo100) then
			pcall(function() InsertCandidate(UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)) end)
			pcall(function() InsertCandidate(UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)) end)
		end
	end
	return candidates[1]
end

local CanReadGeometryNumber = function(value)
	if (type(value) ~= "number") then
		return false
	end
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

local GetTexturePercentFromBar = function(element)
	if (not element) then
		return nil
	end
	local texture = element.GetStatusBarTexture and element:GetStatusBarTexture()
	if (not texture) then
		return nil
	end
	local orientation = (element.GetOrientation and element:GetOrientation()) or "HORIZONTAL"
	local baseLeft = element.__AzeriteUI_BaseTexCoordLeft
	local baseRight = element.__AzeriteUI_BaseTexCoordRight
	local baseTop = element.__AzeriteUI_BaseTexCoordTop
	local baseBottom = element.__AzeriteUI_BaseTexCoordBottom
	if (type(baseLeft) == "number" and type(baseRight) == "number" and type(baseTop) == "number" and type(baseBottom) == "number"
		and CanReadGeometryNumber(baseLeft) and CanReadGeometryNumber(baseRight) and CanReadGeometryNumber(baseTop) and CanReadGeometryNumber(baseBottom)) then
		local okTex, left, right, top, bottom = pcall(texture.GetTexCoord, texture)
		if (okTex and type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number"
			and CanReadGeometryNumber(left) and CanReadGeometryNumber(right) and CanReadGeometryNumber(top) and CanReadGeometryNumber(bottom)) then
			local spanX = baseRight - baseLeft
			local spanY = baseBottom - baseTop
			local curSpan = (orientation == "VERTICAL") and (bottom - top) or (right - left)
			local baseSpan = (orientation == "VERTICAL") and spanY or spanX
			local texCoordsChanged = (math_abs(left - baseLeft) > 0.0001)
				or (math_abs(right - baseRight) > 0.0001)
				or (math_abs(top - baseTop) > 0.0001)
				or (math_abs(bottom - baseBottom) > 0.0001)
			if (texCoordsChanged and type(baseSpan) == "number" and baseSpan ~= 0) then
				local ratio = math_abs(curSpan / baseSpan)
				if (type(ratio) == "number") then
					if (ratio < 0) then
						ratio = 0
					elseif (ratio > 1) then
						ratio = 1
					end
					return ratio * 100
				end
			end
		end
	end
	local okBarW, barWidth = pcall(element.GetWidth, element)
	local okBarH, barHeight = pcall(element.GetHeight, element)
	if (not okBarW or not okBarH or (not CanReadGeometryNumber(barWidth)) or (not CanReadGeometryNumber(barHeight))) then
		return nil
	end
	if (barWidth <= 0 or barHeight <= 0) then
		return nil
	end
	local texSize
	if (orientation == "VERTICAL") then
		local okTexH, texHeight = pcall(texture.GetHeight, texture)
		if (not okTexH or (not CanReadGeometryNumber(texHeight))) then
			return nil
		end
		local okDiv, divided = pcall(function()
			return texHeight / barHeight
		end)
		if (not okDiv or (not CanReadGeometryNumber(divided))) then
			return nil
		end
		texSize = divided
	else
		local okTexW, texWidth = pcall(texture.GetWidth, texture)
		if (not okTexW or (not CanReadGeometryNumber(texWidth))) then
			return nil
		end
		local okDiv, divided = pcall(function()
			return texWidth / barWidth
		end)
		if (not okDiv or (not CanReadGeometryNumber(divided))) then
			return nil
		end
		texSize = divided
	end
	if (not CanReadGeometryNumber(texSize)) then
		return nil
	end
	if (texSize < 0) then
		texSize = 0
	elseif (texSize > 1) then
		texSize = 1
	end
	return texSize * 100
end

local GetSecretPercentFromBar = function(element)
	if (element and (not element.__AzeriteUI_IgnoreMirrorPercent) and type(element.__AzeriteUI_MirrorPercent) == "number") then
		return element.__AzeriteUI_MirrorPercent
	end
	if (element and element.GetSecretPercent) then
		local ok, percent = pcall(element.GetSecretPercent, element)
		if (ok and type(percent) == "number") then
			return percent
		end
	end
	-- Production health path should rely on mirrored statusbar values only.
	-- Texture-size derived fallback is reserved for debug/legacy experiments.
	if (element and element.__AzeriteUI_UseProductionNativeFill) then
		return nil
	end
	local texturePercent = GetTexturePercentFromBar(element)
	if (type(texturePercent) == "number") then
		if (element) then
			element.__AzeriteUI_TexturePercent = texturePercent
		end
		return texturePercent
	end
	return nil
end

API.AttachScriptSafe = function(frame, scriptName, handler)
	if (not frame or type(scriptName) ~= "string" or type(handler) ~= "function") then
		return false
	end
	if (frame.HookScript) then
		local okHook = pcall(frame.HookScript, frame, scriptName, handler)
		if (okHook) then
			return true
		end
	end
	if (not frame.GetScript or not frame.SetScript) then
		return false
	end
	local previous
	local okGet = pcall(function()
		previous = frame:GetScript(scriptName)
	end)
	if (not okGet) then
		previous = nil
	end
	local okSet = pcall(frame.SetScript, frame, scriptName, function(self, ...)
		if (type(previous) == "function") then
			previous(self, ...)
		end
		handler(self, ...)
	end)
	return okSet and true or false
end

API.BindStatusBarValueMirror = function(bar)
	if (not bar or bar.__AzeriteUI_ValueMirrorBound) then
		return
	end
	if (not bar.GetObjectType or bar:GetObjectType() ~= "StatusBar") then
		return
	end
	bar.__AzeriteUI_ValueMirrorBound = true
	local AttachScript = function(scriptName, handler)
		return API.AttachScriptSafe(bar, scriptName, handler)
	end

	AttachScript("OnMinMaxChanged", function(self, minValue, maxValue)
		if (HasSafeNumericRange(minValue, maxValue)) then
			self.__AzeriteUI_MinValue = minValue
			self.__AzeriteUI_MaxValue = maxValue
			self.__AzeriteUI_MirrorMin = minValue
			self.__AzeriteUI_MirrorMax = maxValue
		else
			-- Avoid reusing stale numeric ranges when incoming bounds are secret/unsafe.
			self.__AzeriteUI_MinValue = nil
			self.__AzeriteUI_MaxValue = nil
			self.__AzeriteUI_MirrorMin = nil
			self.__AzeriteUI_MirrorMax = nil
		end
	end)

	AttachScript("OnValueChanged", function(self, value)
		local texture = self.GetStatusBarTexture and self:GetStatusBarTexture()
		if (not texture) then
			return
		end

		self.__AzeriteUI_LastValue = value
		self.__AzeriteUI_MirrorValue = value
		local valueIsSafe = IsSafeNumeric(value)
		local mirrorMin = self.__AzeriteUI_MirrorMin
		local mirrorMax = self.__AzeriteUI_MirrorMax
		local didUpdateMirrorPercent = false
		if (valueIsSafe and HasSafeNumericRange(mirrorMin, mirrorMax)) then
			local okMirror, computedMirrorPercent = pcall(function()
				local p = ((value - mirrorMin) / (mirrorMax - mirrorMin)) * 100
				if (p < 0) then
					return 0
				elseif (p > 100) then
					return 100
				end
				return p
			end)
			if (okMirror and type(computedMirrorPercent) == "number") then
				self.__AzeriteUI_MirrorPercent = computedMirrorPercent
				didUpdateMirrorPercent = true
			end
		end
		local texturePercent = GetTexturePercentFromBar(self)
		if (type(texturePercent) == "number") then
			self.__AzeriteUI_MirrorPercent = texturePercent
			self.__AzeriteUI_TexturePercent = texturePercent
			didUpdateMirrorPercent = true
		end
		if (not didUpdateMirrorPercent) then
			if (self.__AzeriteUI_KeepMirrorPercentOnNoSample) then
				-- Keep prior mirror percent for deterministic fake-fill continuity.
			else
				-- Prevent stale percent reuse when neither math nor texture sampling can update this tick.
				self.__AzeriteUI_MirrorPercent = nil
			end
		end
		if (not self.__AzeriteUI_UseValueMirrorTexCoord) then
			return
		end

		local minValue = self.__AzeriteUI_MinValue
		local maxValue = self.__AzeriteUI_MaxValue
		if (not valueIsSafe or not HasSafeNumericRange(minValue, maxValue)) then
			return
		end

		local percent = (value - minValue) / (maxValue - minValue)
		if (percent < 0) then
			percent = 0
		elseif (percent > 1) then
			percent = 1
		end

		local left, right, top, bottom
		if (self.__AzeriteUI_BaseTexCoordLeft) then
			left = self.__AzeriteUI_BaseTexCoordLeft
			right = self.__AzeriteUI_BaseTexCoordRight
			top = self.__AzeriteUI_BaseTexCoordTop
			bottom = self.__AzeriteUI_BaseTexCoordBottom
		else
			left, right, top, bottom = texture:GetTexCoord()
			self.__AzeriteUI_BaseTexCoordLeft = left
			self.__AzeriteUI_BaseTexCoordRight = right
			self.__AzeriteUI_BaseTexCoordTop = top
			self.__AzeriteUI_BaseTexCoordBottom = bottom
		end
		local spanX = right - left
		local spanY = bottom - top
		local reverseFill = self.GetReverseFill and self:GetReverseFill()
		local orientation = self.GetOrientation and self:GetOrientation() or "HORIZONTAL"

		if (orientation == "VERTICAL") then
			if (reverseFill) then
				texture:SetTexCoord(left, right, bottom - spanY * percent, bottom)
			else
				texture:SetTexCoord(left, right, top, top + spanY * percent)
			end
		else
			if (reverseFill) then
				texture:SetTexCoord(right - spanX * percent, right, top, bottom)
			else
				texture:SetTexCoord(left, left + spanX * percent, top, bottom)
			end
		end
	end)
end

API.HidePrediction = function(element)
	if (element) then
		element:Hide()
		-- Keep absorb bars independent from prediction visibility.
		-- Several unit styles hide prediction overlays continuously.
		if (element.absorbBar and element.__AzeriteUI_HideAbsorbWithPrediction) then
			element.absorbBar:Hide()
		end
	end
end

local HidePowerTexts = function(element)
	if (not element) then
		return
	end
	if ((not element.__AzeriteUI_KeepValueVisible) and element.Value and element.Value.Hide) then
		element.Value:Hide()
	end
	if (element.Percent and element.Percent.Hide) then
		element.Percent:Hide()
	end
	if (element.ManaText and element.ManaText.Hide) then
		element.ManaText:Hide()
	end
end

API.ShouldSkipPrediction = function(element, ...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if IsSecretValue(value) then
			API.HidePrediction(element)
			return true
		end
	end
	return false
end

API.GetSafeHealthForPrediction = function(element, curHealth, maxHealth)
	local safeCur
	local safeMax
	if (type(curHealth) == "number" and not IsSecretValue(curHealth)) then
		safeCur = curHealth
	end
	if (type(maxHealth) == "number" and not IsSecretValue(maxHealth)) then
		safeMax = maxHealth
	end
	if (element and element.health) then
		local health = element.health
		if (not safeCur and type(health.safeCur) == "number" and not IsSecretValue(health.safeCur)) then
			safeCur = health.safeCur
		end
		if (not safeMax and type(health.safeMax) == "number" and not IsSecretValue(health.safeMax)) then
			safeMax = health.safeMax
		end
		if (not safeCur or not safeMax) then
			pcall(function()
				if (not safeCur) then
					local value = health:GetValue()
					if (type(value) == "number" and not IsSecretValue(value)) then
						safeCur = value
					end
				end
				if (not safeMax) then
					local _, m = health:GetMinMaxValues()
					if (type(m) == "number" and not IsSecretValue(m)) then
						safeMax = m
					end
				end
			end)
		end
	end
	if (type(safeMax) ~= "number" or IsSecretValue(safeMax) or safeMax <= 0) then
		return nil, nil
	end
	if (type(safeCur) ~= "number" or IsSecretValue(safeCur)) then
		safeCur = safeMax
	end
	return safeCur, safeMax
end

API.UpdateHealth = function(self, event, unit)
	if (not unit or self.unit ~= unit) then 
		return 
	end
	local element = self.Health

	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local connected = UnitIsConnected(unit)
	local forced = (event == "ForceUpdate") or (event == "RefreshUnit") or (event == "GROUP_ROSTER_UPDATE")
	if (not forced) then
		local guid = UnitGUID(unit)
		local previousGuid = element.guid
		local guidIsSecret = (type(guid) == "string") and IsSecretValue(guid)
		local previousGuidIsSecret = (type(previousGuid) == "string") and IsSecretValue(previousGuid)
		if (guidIsSecret or previousGuidIsSecret) then
			forced = true
			element.guid = nil
			element.safeCur = nil
			element.safeMax = nil
			element.safePercent = nil
		elseif (guid ~= previousGuid) then
			forced = true
			element.guid = guid
			element.safeCur = nil
			element.safeMax = nil
			element.safePercent = nil
		end
	end

	local rawCur = UnitHealth(unit)
	local rawMax = UnitHealthMax(unit)
	local rawCurNum = (type(rawCur) == "number")
	local rawMaxNum = (type(rawMax) == "number")
	local rawCurSecret = rawCurNum and IsSecretValue(rawCur)
	local rawMaxSecret = rawMaxNum and IsSecretValue(rawMax)
	local rawCurSafe = rawCurNum and IsSafeNumeric(rawCur)
	local rawMaxSafe = rawMaxNum and IsSafeNumeric(rawMax) and rawMax > 0
	element.__AzeriteUI_RawCurSafe = rawCurSafe and true or false
	element.__AzeriteUI_RawMaxSafe = rawMaxSafe and true or false
	element.__AzeriteUI_RawCurSecret = rawCurSecret and true or false
	element.__AzeriteUI_RawMaxSecret = rawMaxSecret and true or false
	local barCur, barMin, barMax
	pcall(function()
		barCur = element:GetValue()
		barMin, barMax = element:GetMinMaxValues()
	end)
	local barMaxSafe = (IsSafeNumeric(barMax) and barMax > 0) and barMax or nil

	local previousSafePercent = NormalizePercent100(element.safePercent)
	local safePercent = NormalizePercent100(SafeUnitPercentNumber(unit, false))
	local targetPercent = nil
	if (unit == "target") then
		-- UnitHealthPercent can be stale/frozen for secret target updates.
		-- Keep target health driven by mirror/native geometry unless raw values are readable.
		if ((not rawCurSafe) or (not rawMaxSafe)) then
			safePercent = nil
		end
		targetPercent = NormalizePercent100(ProbeSafePercentAPI(unit, false))
		-- Target secret paths are bar-authoritative post-write.
		-- Only trust probed API percent when raw values are fully safe.
		if (rawCurSafe and rawMaxSafe and type(targetPercent) == "number") then
			safePercent = targetPercent
		end
	end
	if (safePercent == nil and (not rawCurSafe)) then
		safePercent = NormalizePercent100(GetSecretPercentFromBar(element))
	end

	local safeMax = rawMaxSafe and rawMax
		or barMaxSafe
		or ((type(element.safeMax) == "number" and element.safeMax > 0) and element.safeMax or 100)
	local safeCur = rawCurSafe and rawCur
		or (type(element.safeCur) == "number" and element.safeCur or safeMax)
	local staleRawCur = false
	if (type(safePercent) == "number" and rawCurSafe) then
		if (rawCur > safeMax or (rawCur >= safeMax and safePercent < 99.5) or (rawCur <= 0 and safePercent > 0.5)) then
			staleRawCur = true
		end
	end
	if (type(safePercent) == "number" and ((not rawCurSafe) or staleRawCur)) then
		safeCur = safeMax * (safePercent / 100)
	end
	if (safeCur < 0) then
		safeCur = 0
	elseif (safeCur > safeMax) then
		safeCur = safeMax
	end

	local writeMin = 0
	local writeMax = rawMaxNum and rawMax or safeMax
	local writeCur = (rawCurNum and (not staleRawCur)) and rawCur or safeCur
	if (not connected) then
		writeCur = writeMax
	end

	SetStatusBarValuesCompat(element, 0, writeMax, writeCur, forced)
	local display = element.Display
	local managedDisplay = (element.__AzeriteUI_ManageDisplayInOverride == true)
	if (display and (not managedDisplay)) then
		SetStatusBarValuesCompat(display, 0, writeMax, writeCur, forced)
		if (display.GetParent and display:GetParent() ~= element) then
			display:SetParent(element)
		end
		if (display.SetAllPoints) then
			display:SetAllPoints(element)
		end
		if (display.GetFrameLevel and element.GetFrameLevel and display:GetFrameLevel() <= element:GetFrameLevel()) then
			display:SetFrameLevel(element:GetFrameLevel() + 1)
		end
		display:SetAlpha(1)
		display:Show()
		local displayTexture = display.GetStatusBarTexture and display:GetStatusBarTexture()
		if (displayTexture and displayTexture.SetAlpha) then
			displayTexture:SetAlpha(1)
		end
	elseif (display and managedDisplay) then
		-- Some unit styles (target flip-lab) manage display geometry/visibility locally.
		-- Keep values synced here, but do not force parent/points/show state each update.
		SetStatusBarValuesCompat(display, 0, writeMax, writeCur, forced)
	end

	-- WoW12 secret-value path:
	-- after writing to the statusbar, re-read mirrored/bar percent so
	-- text values follow what the bar actually renders.
	if (unit == "target" and connected) then
		local targetPercentSource = "none"
		local targetResolvedPercent = NormalizePercent100(GetSecretPercentFromBar(element))
		if (type(targetResolvedPercent) == "number") then
			safePercent = targetResolvedPercent
			safeCur = safeMax * (targetResolvedPercent / 100)
			targetPercentSource = "mirror"
		else
			if (type(targetPercent) == "number") then
				safePercent = targetPercent
				safeCur = safeMax * (targetPercent / 100)
				targetPercentSource = "api"
			end
			local targetRecomputed = SafePercentFromValues(safeCur, safeMax)
			if (targetPercentSource == "none" and rawCurSafe and rawMaxSafe and type(targetRecomputed) == "number") then
				safePercent = targetRecomputed
				targetPercentSource = "minmax"
			elseif (targetPercentSource == "none" and rawCurSafe and rawMaxSafe and type(previousSafePercent) == "number") then
				safePercent = previousSafePercent
				targetPercentSource = "cached"
			end
		end
		element.__AzeriteUI_TargetPercentSource = targetPercentSource
	elseif ((not rawCurSafe) and connected) then
		local postMirrorPercent = NormalizePercent100(GetSecretPercentFromBar(element))
		if (type(postMirrorPercent) == "number") then
			safePercent = postMirrorPercent
			safeCur = safeMax * (postMirrorPercent / 100)
		end
		if (unit == "target") then
			element.__AzeriteUI_TargetPercentSource = nil
		end
	else
		if (unit == "target") then
			element.__AzeriteUI_TargetPercentSource = nil
		end
	end

	element.cur = safeCur
	element.max = safeMax
	element.safeCur = safeCur
	element.safeMax = safeMax
	local safeAbsorb = element.safeAbsorb
	local rawTotalAbsorb = nil
	if (UnitGetTotalAbsorbs) then
		rawTotalAbsorb = UnitGetTotalAbsorbs(unit)
		if (type(rawTotalAbsorb) == "number" and not IsSecretValue(rawTotalAbsorb)) then
			if (rawTotalAbsorb > 0) then
				safeAbsorb = rawTotalAbsorb
			else
				-- Known zero: clear cached absorb immediately.
				safeAbsorb = nil
			end
		end
	end
	element.safeAbsorb = safeAbsorb
	element.approxValue = safeCur
	element.approxMax = safeMax
	element.approxInitialized = true

	-- Cache a safe percent for tag text.
	if (unit == "target" and type(safePercent) == "number") then
		element.safePercent = NormalizePercent100(safePercent)
	else
		element.safePercent = SafePercentFromValues(safeCur, safeMax) or NormalizePercent100(safePercent)
	end
	if (element.Percent and element.Percent.UpdateTag) then
		pcall(function() element.Percent:UpdateTag() end)
	end
	if (element.Value and element.Value.UpdateTag) then
		pcall(function() element.Value:UpdateTag() end)
	end

	local preview = element.Preview
	if (preview) then
		SetStatusBarValuesCompat(preview, writeMin, writeMax, connected and writeCur or writeMax, forced)
	end

	--[[ Callback: Health:PostUpdate(unit, cur, max)
	Called after the element has been updated.

	* self - the Health element
	* unit - the unit for which the update has been triggered (string)
	* cur  - the unit's current health value (number)
	* max  - the unit's maximum possible health value (number)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit, safeCur, safeMax)
	end

	if (ShouldDebugUnit(unit) and ShouldEmitTick(element, "__AzeriteUI_LastHealthDebug", 0.25)) then
		API.DebugPrintf("Health", 4,
			"Update unit=%s conn=%s rawCur=%s rawMax=%s safeCur=%s safeMax=%s writeCur=%s writeMax=%s safePct=%s mirrorPct=%s texPct=%s barSafeMax=%s rawCurSecret=%s rawMaxSecret=%s rawAbsorb=%s safeAbsorb=%s rawAbsorbSecret=%s",
			tostring(unit),
			tostring(connected and true or false),
			tostring(rawCur),
			tostring(rawMax),
			tostring(safeCur),
			tostring(safeMax),
			tostring(writeCur),
			tostring(writeMax),
			tostring(element.safePercent),
			tostring(element.__AzeriteUI_MirrorPercent),
			tostring(element.__AzeriteUI_TexturePercent),
			tostring(barMaxSafe),
			tostring(rawCurSecret and true or false),
			tostring(rawMaxSecret and true or false),
			tostring(rawTotalAbsorb),
			tostring(safeAbsorb),
			tostring(rawTotalAbsorb ~= nil and IsSecretValue(rawTotalAbsorb) and true or false))
	end

	if (unit == "target" and ShouldDebugUnit(unit) and ShouldEmitTick(element, "__AzeriteUI_LastTargetBarDebug", 0.35)) then
		local barVal, barMin, barMax = nil, nil, nil
		local orient, reverse = nil, nil
		pcall(function()
			barVal = element:GetValue()
			barMin, barMax = element:GetMinMaxValues()
			orient = element.GetOrientation and element:GetOrientation() or nil
			reverse = element.GetReverseFill and element:GetReverseFill() or nil
		end)
		API.DebugPrintf("TargetBar", 4,
			"HealthBar orient=%s reverse=%s barValue=%s barMin=%s barMax=%s safeCur=%s safeMax=%s safePct=%s pctSource=%s fakeSource=%s",
			tostring(orient),
			tostring(reverse),
			tostring(barVal),
			tostring(barMin),
			tostring(barMax),
			tostring(safeCur),
			tostring(safeMax),
			tostring(element.safePercent),
			tostring(element.__AzeriteUI_TargetPercentSource),
			tostring(element.__AzeriteUI_TargetFakeSource))
	end
end

API.UpdatePower = function(self, event, unit)
	if(self.unit ~= unit) then return end
	local element = self.Power

	--[[ Callback: Power:PreUpdate(unit)
	Called before the element has been updated.

	* self - the Power element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local guid = UnitGUID(unit)
	local forced = (event == "ForceUpdate") or (event == "RefreshUnit") or (event == "GROUP_ROSTER_UPDATE")
	if (not forced) then
		local previousGuid = element.guid
		local guidIsSecret = (type(guid) == "string") and IsSecretValue(guid)
		local previousGuidIsSecret = (type(previousGuid) == "string") and IsSecretValue(previousGuid)
		if (guidIsSecret or previousGuidIsSecret) then
			forced = true
			guid = nil
		elseif (guid ~= previousGuid) then
			forced = true
		end
	end
	element.guid = guid
	if (forced) then
		element.safeCur = nil
		element.safeMin = nil
		element.safeMax = nil
		element.safePercent = nil
	end

	local displayType, min
	if (element.displayAltPower and oUF.isRetail and element.GetDisplayPower) then
		displayType, min = element:GetDisplayPower()
	end

	local rawCur, rawMax = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	local rawCurNum = (type(rawCur) == "number")
	local rawMaxNum = (type(rawMax) == "number")
	local rawCurSecret = rawCurNum and IsSecretValue(rawCur)
	local rawMaxSecret = rawMaxNum and IsSecretValue(rawMax)
	local rawCurSafe = rawCurNum and (not rawCurSecret)
	local rawMaxSafe = rawMaxNum and (not rawMaxSecret) and rawMax > 0

	local safePercent = NormalizePercent100(SafeUnitPercentNumber(unit, true, displayType))
	if (safePercent == nil and (not rawCurSafe)) then
		safePercent = NormalizePercent100(GetSecretPercentFromBar(element))
	end

	local safeMin = (type(min) == "number" and (not issecretvalue or not issecretvalue(min))) and min or 0
	local safeMax = rawMaxSafe and rawMax or ((type(element.safeMax) == "number" and element.safeMax > 0) and element.safeMax or 100)
	local safeCur = rawCurSafe and rawCur or (type(element.safeCur) == "number" and element.safeCur or safeMax)
	if ((not rawCurSafe) and type(safePercent) == "number") then
		safeCur = safeMin + ((safeMax - safeMin) * (safePercent / 100))
	end
	if (safeCur < safeMin) then
		safeCur = safeMin
	elseif (safeCur > safeMax) then
		safeCur = safeMax
	end

	local writeMin = safeMin
	local writeMax = rawMaxSafe and rawMax or safeMax
	local writeCur = rawCurNum and rawCur or safeCur
	if (not UnitIsConnected(unit)) then
		writeCur = writeMax
	end

	SetStatusBarValuesCompat(element, writeMin, writeMax, writeCur, forced)

	if ((not rawCurSafe) and UnitIsConnected(unit)) then
		local postMirrorPercent = NormalizePercent100(GetSecretPercentFromBar(element))
		if (type(postMirrorPercent) == "number") then
			safePercent = postMirrorPercent
			local safeRange = safeMax - safeMin
			if (safeRange > 0) then
				safeCur = safeMin + ((safeRange) * (postMirrorPercent / 100))
			else
				safeCur = safeMin
			end
			if (safeCur < safeMin) then
				safeCur = safeMin
			elseif (safeCur > safeMax) then
				safeCur = safeMax
			end
		end
	end

	element.cur = safeCur
	element.min = safeMin
	element.max = safeMax
	element.safeCur = safeCur
	element.safeMin = safeMin
	element.safeMax = safeMax
	element.displayType = displayType

	element.safePercent = safePercent or SafePercentFromValues(safeCur - safeMin, safeMax - safeMin)
	if (element.Percent and element.Percent.UpdateTag) then
		pcall(function() element.Percent:UpdateTag() end)
	end
	if (element.Value and element.Value.UpdateTag) then
		pcall(function() element.Value:UpdateTag() end)
	end
	--[[ Callback: Power:PostUpdate(unit, cur, min, max)
	Called after the element has been updated.

	* self - the Power element
	* unit - the unit for which the update has been triggered (string)
	* cur  - the unit's current power value (number)
	* min  - the unit's minimum possible power value (number)
	* max  - the unit's maximum possible power value (number)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit, safeCur, safeMin, safeMax)
	end
	HidePowerTexts(element)

	if (ShouldDebugUnit(unit) and ShouldEmitTick(element, "__AzeriteUI_LastPowerDebug", 0.25)) then
		API.DebugPrintf("Power", 4,
			"Update unit=%s displayType=%s rawCur=%s rawMax=%s safeCur=%s safeMin=%s safeMax=%s writeCur=%s writeMin=%s writeMax=%s safePct=%s rawCurSecret=%s rawMaxSecret=%s",
			tostring(unit),
			tostring(displayType),
			tostring(rawCur),
			tostring(rawMax),
			tostring(safeCur),
			tostring(safeMin),
			tostring(safeMax),
			tostring(writeCur),
			tostring(writeMin),
			tostring(writeMax),
			tostring(element.safePercent),
			tostring(rawCurSecret and true or false),
			tostring(rawMaxSecret and true or false))
	end
end

API.UpdateManaOrb = function(self, event, unit)
	local element = self.ManaOrb
	if (not element) then
		return
	end
	unit = unit or self.unit or "player"
	if (unit ~= "player" and unit ~= "vehicle" and unit ~= self.unit) then
		return
	end

	--[[ Callback: Power:PreUpdate(unit)
	Called before the element has been updated.

	* self - the Power element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local guid = UnitGUID(unit)
	local guidChanged = false
	if (guid) then
		local success, result = pcall(function()
			return guid ~= element.guid
		end)
		guidChanged = success and result and true or false
	end
	local forced = guidChanged or (guid and not element.guid) or (UnitIsDeadOrGhost(unit))
	if (event == "ForceUpdate" or event == "RefreshUnit" or event == "GROUP_ROSTER_UPDATE") then
		forced = true
	end
	element.guid = guid

	local displayType, min = POWER_TYPE_MANA, 0
	local cur, max = UnitPower(unit, displayType), UnitPowerMax(unit, displayType)
	local rawCurSafe = (type(cur) == "number") and (not issecretvalue or not issecretvalue(cur))
	local rawMaxSafe = (type(max) == "number") and (not issecretvalue or not issecretvalue(max)) and max > min
	local safeMin = min
	local safeMax = rawMaxSafe and max or ((type(element.safeMax) == "number" and element.safeMax > safeMin) and element.safeMax or 100)
	local safeCur = (type(element.__AzeriteUI_DisplayCur) == "number" and (not issecretvalue or not issecretvalue(element.__AzeriteUI_DisplayCur))) and element.__AzeriteUI_DisplayCur
		or ((type(element.safeCur) == "number" and (not issecretvalue or not issecretvalue(element.safeCur))) and element.safeCur)
		or (rawCurSafe and cur)
		or safeMax
	local safePercent = (type(element.__AzeriteUI_DisplayPercent) == "number" and (not issecretvalue or not issecretvalue(element.__AzeriteUI_DisplayPercent))) and element.__AzeriteUI_DisplayPercent
		or ((type(element.safePercent) == "number" and (not issecretvalue or not issecretvalue(element.safePercent))) and element.safePercent)
		or NormalizePercent100(SafeUnitPercentNumber(unit, true, displayType))

	if (type(safePercent) == "number" and (type(safeCur) ~= "number" or (safeCur == safeMax and not rawCurSafe))) then
		safeCur = safeMin + ((safeMax - safeMin) * (safePercent / 100))
	end
	if (type(safeCur) ~= "number" or (issecretvalue and issecretvalue(safeCur))) then
		safeCur = safeMax
	end
	if (safeCur < safeMin) then
		safeCur = safeMin
	elseif (safeCur > safeMax) then
		safeCur = safeMax
	end

	element:SetMinMaxValues(min, max, true)
	if (UnitIsConnected(unit)) then
		element:SetValue(cur, true)
	else
		element:SetValue(max, true)
	end


	element.cur = cur
	element.min = safeMin
	element.max = safeMax
	element.displayType = displayType
	if (type(safePercent) == "number") then
		element.safePercent = safePercent
	end
	element.safeMin = safeMin
	element.safeMax = safeMax
	element.safeCur = safeCur
	if (element.Percent and element.Percent.UpdateTag) then
		pcall(function() element.Percent:UpdateTag() end)
	end
	if (element.Value and element.Value.UpdateTag) then
		pcall(function() element.Value:UpdateTag() end)
	end

	--[[ Callback: Power:PostUpdate(unit, cur, min, max)
	Called after the element has been updated.

	* self - the Power element
	* unit - the unit for which the update has been triggered (string)
	* cur  - the unit's current power value (number)
	* min  - the unit's minimum possible power value (number)
	* max  - the unit's maximum possible power value (number)
	--]]
	if (element.PostUpdate) then
		element:PostUpdate(unit, safeCur, safeMin, safeMax)
	end
	HidePowerTexts(element)
end

API.UpdateAdditionalPower = API.UpdateManaOrb




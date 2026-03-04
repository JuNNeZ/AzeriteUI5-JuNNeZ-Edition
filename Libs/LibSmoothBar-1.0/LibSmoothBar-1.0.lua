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
local MAJOR_VERSION = "LibSmoothBar-1.0"
local MINOR_VERSION = 3

if (not LibStub) then
	error(MAJOR_VERSION .. " requires LibStub.")
end

local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if (not lib) then
	return
end

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- WoW API
local CreateFrame = CreateFrame
local GetTime = GetTime

-- Library registries
lib.bars = lib.bars or {}
lib.textures = lib.textures or {}
lib.embeds = lib.embeds or {}

-- Speed shortcuts
local Bars = lib.bars
local Textures = lib.textures

local ShouldDebugBar = function(bar)
	local AUI = _G.AzeriteUI
	if (not (AUI and AUI.API and AUI.API.DEBUG_HEALTH)) then
		return false
	end
	local filter = AUI.API.DEBUG_HEALTH_FILTER
	local label = bar and bar.__AzeriteUI_DebugLabel
	if (not label) then
		local data = Bars[bar]
		label = data and data.statusbar and data.statusbar.__AzeriteUI_DebugLabel
	end
	if (type(label) ~= "string") then
		return false
	end
	if (not filter or filter == "") then
		filter = "Target."
	end
	if (filter == "*" or filter == "all") then
		return true
	end
	return label:find(filter, 1, true) ~= nil
end

----------------------------------------------------------------
-- Statusbar template
----------------------------------------------------------------
local StatusBar = CreateFrame("StatusBar")
local StatusBar_MT = { __index = StatusBar }

-- Grab some of the original methods before we change them
local Orig_GetScript = getmetatable(StatusBar).__index.GetScript
local Orig_SetScript = getmetatable(StatusBar).__index.SetScript

-- Noop out the old blizzard methods.
local noop = function() end
StatusBar.GetFillStyle = noop
StatusBar.GetMinMaxValues = noop
StatusBar.GetOrientation = noop
StatusBar.GetReverseFill = noop
StatusBar.GetRotatesTexture = noop
StatusBar.GetStatusBarAtlas = noop
StatusBar.GetStatusBarColor = noop
StatusBar.GetStatusBarTexture = noop
StatusBar.GetValue = noop
StatusBar.SetFillStyle = noop
StatusBar.SetMinMaxValues = noop
StatusBar.SetOrientation = noop
StatusBar.SetReverseFill = noop
StatusBar.SetValue = noop
StatusBar.SetRotatesTexture = noop
StatusBar.SetStatusBarAtlas = noop
StatusBar.SetStatusBarColor = noop
StatusBar.SetStatusBarTexture = noop

-- Need to borrow some methods here
local Texture = StatusBar:CreateTexture()
local Texture_MT = { __index = Texture }

-- Grab some of the original methods before we change them
local Orig_SetTexCoord = getmetatable(Texture).__index.SetTexCoord
local Orig_GetTexCoord = getmetatable(Texture).__index.GetTexCoord

-- Mad scientist stuff.
-- What we basically do is to apply texcoords to texcoords,
-- to get an inner fraction of the already cropped texture. Awesome! :)
local SetTexCoord = function(self, ...)

	-- The displayed fraction of the full texture
	local fractionLeft, fractionRight, fractionTop, fractionBottom = ...

	local fullCoords = Textures[self] -- "full" / original texcoords
	local fullWidth = fullCoords[2] - fullCoords[1] -- full width of the original texcoord area
	local fullHeight = fullCoords[4] - fullCoords[3] -- full height of the original texcoord area

	local displayedLeft = fullCoords[1] + fractionLeft*fullWidth
	local displayedRight = fullCoords[2] - (1-fractionRight)*fullWidth
	local displayedTop = fullCoords[3] + fractionTop*fullHeight
	local displayedBottom = fullCoords[4] - (1-fractionBottom)*fullHeight

	-- Store the real coords (re-use old table, as this is called very often)
	local texCoords = Bars[self].texCoords
	texCoords[1] = displayedLeft
	texCoords[2] = displayedRight
	texCoords[3] = displayedTop
	texCoords[4] = displayedBottom

	-- Calculate the new area and apply it with the real blizzard method
	Orig_SetTexCoord(self, displayedLeft, displayedRight, displayedTop, displayedBottom)

	-- Keep proxy statusbar texture in sync
	local proxy = Bars[self] and Bars[self].proxy
	if (proxy) then
		local proxyTex = proxy:GetStatusBarTexture()
		if (proxyTex and proxyTex.SetTexCoord) then
			proxyTex:SetTexCoord(displayedLeft, displayedRight, displayedTop, displayedBottom)
		end
	end

	-- Allow modules to hook into this
	local onTexCoordChanged = Bars[self].OnTexCoordChanged
	if (onTexCoordChanged) then
		onTexCoordChanged(self, displayedLeft, displayedRight, displayedTop, displayedBottom)
	end
end

local Update = function(self, elapsed)
	local data = Bars[self]

	local value = data.disableSmoothing and data.barValue or data.barDisplayValue
	local min, max = data.barMin, data.barMax

	-- Ensure barMin/barMax are numeric to avoid nil comparisons
	if (type(min) ~= "number" or (issecretvalue and issecretvalue(min))) then
		min = data.safeBarMin or 0
		data.barMin = min
	end
	if (type(max) ~= "number" or (issecretvalue and issecretvalue(max))) then
		max = data.safeBarMax or 1
		data.barMax = max
	end
	if (max <= min) then
		max = min + 1
		data.barMax = max
	end

	local width, height = data.statusbar:GetSize()
	local orientation = data.barOrientation
	local label = (self and self.__AzeriteUI_DebugLabel) or (data.statusbar and data.statusbar.__AzeriteUI_DebugLabel)
	local bar = data.bar
	local spark = data.spark

	-- If forced native, coerce secret/missing values to safe numbers and never swap to proxy
	if (data.forceNative) then
		local function PickSafe(v, fallback)
			if (type(v) == "number" and (not issecretvalue or not issecretvalue(v))) then
				return v
			end
			if (type(fallback) == "number" and (not issecretvalue or not issecretvalue(fallback))) then
				return fallback
			end
			return nil
		end

		local newValue = PickSafe(value, data.safeBarValue or data.barValue)
		local newMin   = PickSafe(min,   data.safeBarMin or data.barMin or 0)
		local newMax   = PickSafe(max,   data.safeBarMax or data.barMax)

		-- If we can’t get safe numbers, leave bar as-is to avoid scaling jitter.
		if (not newValue or not newMin or not newMax) then
			return
		end
		-- Ensure sane range
		if (newMax <= newMin) then
			newMax = newMin + 1
		end

		value = newValue
		min   = newMin
		max   = newMax

		-- Cache safe fallbacks for later secret frames
		data.safeBarValue = value
		data.safeBarMin   = min
		data.safeBarMax   = max
	else
		-- If values are missing or secret, fall back to a proxy StatusBar to render safely
		local valueIsSecret = issecretvalue and issecretvalue(value)
		local minIsSecret = issecretvalue and issecretvalue(min)
		local maxIsSecret = issecretvalue and issecretvalue(max)
		if (not value or not min or not max or valueIsSecret or minIsSecret or maxIsSecret) then
			local proxy = data.proxy
			if (proxy) then
				if (ShouldDebugBar(data.statusbar) and not data.__AzeriteUI_ProxyShown) then
					data.__AzeriteUI_ProxyShown = true
					print("|cff33ff99", "AzeriteUI", "LibSmoothBar proxy ON", tostring(data.statusbar and data.statusbar.__AzeriteUI_DebugLabel))
				end
				-- Sync proxy orientation to match bar (flip handled via texcoords)
				if (data.barBlizzardOrientation) then
					proxy:SetOrientation(data.barBlizzardOrientation)
				end
				local proxyReverse = data.barBlizzardReverseFill
				proxy:SetReverseFill(proxyReverse and true or false)
				proxy:SetMinMaxValues(min or 0, max or 1)
				proxy:SetValue(value or 0)
				-- Match texture coordinates to custom bar rendering (flip via texcoords only)
				local proxyTex = proxy:GetStatusBarTexture()
				if (proxyTex and proxyTex.SetTexCoord) then
					if (data.reversedH and (orientation == "LEFT" or orientation == "RIGHT")) then
						-- Avoid double-reversing when proxy is already reverse-filled.
						if (data.barBlizzardReverseFill) then
							proxyTex:SetTexCoord(0, 1, 0, 1)
						else
							proxyTex:SetTexCoord(1, 0, 0, 1)
						end
					else
						proxyTex:SetTexCoord(0, 1, 0, 1)
					end
				end
				proxy:Show()
			end
			bar:Hide()
			if (spark and spark:IsShown()) then
				spark:Hide()
			end
			return
		else
			if (data.__AzeriteUI_ProxyShown) then
				data.__AzeriteUI_ProxyShown = nil
				if (ShouldDebugBar(data.statusbar)) then
					print("|cff33ff99", "AzeriteUI", "LibSmoothBar proxy OFF", tostring(data.statusbar and data.statusbar.__AzeriteUI_DebugLabel))
				end
			end
			if (data.proxy and data.proxy:IsShown()) then
				data.proxy:Hide()
			end
		end
	end
	
	-- Now safe to do comparisons since values are not nil and not secret
	if (value > max) then
		value = max
	elseif (value < min) then
		value = min
	end
	
	if (value == min) or (max == min) then
		bar:Hide()
		return
	end

	if false then
		bar:Hide()
	else

		-- Ok, here's the problem:
		-- Textures sizes can't be displayed accurately as fractions of a pixel.
		-- This causes the bar to "wobbble" when attempting to size it
		-- according to its much more accurate tex coords.
		-- Only solid workaround is to keep the textures at integer values,
		-- And fake the movement by moving the blurry spark at subpixels instead.
		local displaySize, mult
		if (value > min) then
			mult = (value-min)/(max-min)
			local fullSize = (orientation == "RIGHT" or orientation == "LEFT") and width or height
			displaySize = math_floor(mult * fullSize)
			if (displaySize < .01) then
				displaySize = .01
			end
			mult = displaySize/fullSize
		else
			mult = .01
			displaySize = .01
		end

		-- if there's a sparkmap, let's apply it!
		local sparkBefore, sparkAfter = 0,0
		local sparkMap = data.sparkMap
		if sparkMap then
			local sparkPercentage = mult
			if data.reversedH and ((orientation == "LEFT") or (orientation == "RIGHT")) then
				sparkPercentage = 1 - mult
			end
			if data.reversedV and ((orientation == "UP") or (orientation == "DOWN")) then
				sparkPercentage = 1 - mult
			end
			if (sparkMap.top and sparkMap.bottom) then

				-- Iterate through the map to figure out what points we are between
				-- *There's gotta be a more elegant way to do this...
				local topBefore, topAfter = 1, #sparkMap.top
				local bottomBefore, bottomAfter = 1, #sparkMap.bottom

				-- Iterate backwards to find the first top point before our current bar value
				for i = topAfter,topBefore,-1 do
					if sparkMap.top[i].keyPercent > sparkPercentage then
						topAfter = i
					end
					if sparkMap.top[i].keyPercent < sparkPercentage then
						topBefore = i
						break
					end
				end
				-- Iterate backwards to find the first bottom point before our current bar value
				for i = bottomAfter,bottomBefore,-1 do
					if sparkMap.bottom[i].keyPercent > sparkPercentage then
						bottomAfter = i
					end
					if sparkMap.bottom[i].keyPercent < sparkPercentage then
						bottomBefore = i
						break
					end
				end

				-- figure out the offset at our current position
				-- between our upper and lover points
				local belowPercentTop = sparkMap.top[topBefore].keyPercent
				local abovePercentTop = sparkMap.top[topAfter].keyPercent

				local belowPercentBottom = sparkMap.bottom[bottomBefore].keyPercent
				local abovePercentBottom = sparkMap.bottom[bottomAfter].keyPercent

				local currentPercentTop = (sparkPercentage - belowPercentTop)/(abovePercentTop-belowPercentTop)
				local currentPercentBottom = (sparkPercentage - belowPercentBottom)/(abovePercentBottom-belowPercentBottom)

				-- difference between the points
				local diffTop = sparkMap.top[topAfter].offset - sparkMap.top[topBefore].offset
				local diffBottom = sparkMap.bottom[bottomAfter].offset - sparkMap.bottom[bottomBefore].offset

				sparkBefore = (sparkMap.top[topBefore].offset + diffTop*currentPercentTop) --* height
				sparkAfter = (sparkMap.bottom[bottomBefore].offset + diffBottom*currentPercentBottom) --* height
			else
				-- iterate through the map to figure out what points we are between
				-- gotta be a more elegant way to do this
				local below, above = 1,#sparkMap
				for i = above,below,-1 do
					if sparkMap[i].keyPercent > sparkPercentage then
						above = i
					end
					if sparkMap[i].keyPercent < sparkPercentage then
						below = i
						break
					end
				end

				-- figure out the offset at our current position
				-- between our upper and lover points
				local belowPercent = sparkMap[below].keyPercent
				local abovePercent = sparkMap[above].keyPercent
				local currentPercent = (sparkPercentage - belowPercent)/(abovePercent-belowPercent)

				-- difference between the points
				local diffTop = sparkMap[above].topOffset - sparkMap[below].topOffset
				local diffBottom = sparkMap[above].bottomOffset - sparkMap[below].bottomOffset

				sparkBefore = (sparkMap[below].topOffset + diffTop*currentPercent) --* height
				sparkAfter = (sparkMap[below].bottomOffset + diffBottom*currentPercent) --* height
			end
		end

		if (orientation == "RIGHT") then
			if data.reversedH then
				-- bar grows from the left to right
				-- and the bar is also flipped horizontally
				-- (e.g. target absorbbar)
				SetTexCoord(bar, 1, 1-mult, 0, 1)
			else
				-- bar grows from the left to right
				-- (e.g. player healthbar)
			SetTexCoord(bar, 0, mult, 0, 1)
			end

			bar:ClearAllPoints()
			bar:SetPoint("TOP")
			bar:SetPoint("BOTTOM")
			bar:SetPoint("LEFT")
			bar:SetSize(displaySize, height)

			spark:ClearAllPoints()
			spark:SetPoint("TOP", bar, "TOPRIGHT", 0, sparkBefore*height)
			spark:SetPoint("BOTTOM", bar, "BOTTOMRIGHT", 0, -sparkAfter*height)
			spark:SetSize(data.sparkThickness, height - (sparkBefore + sparkAfter)*height)

		elseif (orientation == "LEFT") then
			if data.reversedH then
				-- bar grows from the right to left
				-- and the bar is also flipped horizontally
				-- (e.g. target healthbar)
				SetTexCoord(bar, mult, 0, 0, 1)
			else
				-- bar grows from the right to left
				-- (e.g. player absorbbar)
				SetTexCoord(bar, 1-mult, 1, 0, 1)
			end
			bar:SetPoint("TOP")
			bar:SetPoint("BOTTOM")
			bar:SetPoint("RIGHT")
			bar:SetSize(displaySize, height)

			spark:ClearAllPoints()
			spark:SetPoint("TOP", bar, "TOPLEFT", 0, sparkBefore*height)
			spark:SetPoint("BOTTOM", bar, "BOTTOMLEFT", 0, -sparkAfter*height)
			spark:SetSize(data.sparkThickness, height - (sparkBefore + sparkAfter)*height)

		elseif (orientation == "UP") then
			if data.reversed then
				SetTexCoord(bar, 1, 0, 1-mult, 1)
				sparkBefore, sparkAfter = sparkAfter, sparkBefore
			else
				SetTexCoord(bar, 0, 1, 1-mult, 1)
			end

			bar:ClearAllPoints()
			bar:SetPoint("LEFT")
			bar:SetPoint("RIGHT")
			bar:SetPoint("BOTTOM")
			bar:SetSize(width, displaySize)

			spark:ClearAllPoints()
			spark:SetPoint("LEFT", bar, "TOPLEFT", -sparkBefore*width, 0)
			spark:SetPoint("RIGHT", bar, "TOPRIGHT", sparkAfter*width, 0)
			spark:SetSize(width - (sparkBefore + sparkAfter)*width, data.sparkThickness)

		elseif (orientation == "DOWN") then
			if data.reversed then
				SetTexCoord(bar, 1, 0, 0, mult)
				sparkBefore, sparkAfter = sparkAfter, sparkBefore
			else
				SetTexCoord(bar, 0, 1, 0, mult)
			end

			bar:ClearAllPoints()
			bar:SetPoint("LEFT")
			bar:SetPoint("RIGHT")
			bar:SetPoint("TOP")
			bar:SetSize(width, displaySize)

			spark:ClearAllPoints()
			spark:SetPoint("LEFT", bar, "BOTTOMLEFT", -sparkBefore*width, 0)
			spark:SetPoint("RIGHT", bar, "BOTTOMRIGHT", sparkAfter*width, 0)
			spark:SetSize(width - (sparkBefore + sparkAfter*width), data.sparkThickness)
		end
		if (not bar:IsShown()) then
			bar:Show()
		end
		if (data.OnDisplayValueChanged) then
			data.OnDisplayValueChanged(self, value)
		end
	end

	-- Spark alpha animation
	if ((value == max) or (value == min) or (value/max >= data.sparkMaxPercent) or (value/max <= data.sparkMinPercent)) then
		if spark:IsShown() then
			spark:Hide()
			spark:SetAlpha(data.sparkMinAlpha)
			data.sparkDirection = "IN"
		end
	else
		if (tonumber(elapsed)) then
			local currentAlpha = spark:GetAlpha()
			local targetAlpha = data.sparkDirection == "IN" and data.sparkMaxAlpha or data.sparkMinAlpha
			local range = data.sparkMaxAlpha - data.sparkMinAlpha
			local alphaChange = elapsed/(data.sparkDirection == "IN" and data.sparkDurationIn or data.sparkDurationOut) * range
			if data.sparkDirection == "IN" then
				if currentAlpha + alphaChange < targetAlpha then
					currentAlpha = currentAlpha + alphaChange
				else
					currentAlpha = targetAlpha
					data.sparkDirection = "OUT"
				end
			elseif data.sparkDirection == "OUT" then
				if currentAlpha - alphaChange > targetAlpha then
					currentAlpha = currentAlpha - alphaChange
				else
					currentAlpha = targetAlpha
					data.sparkDirection = "IN"
				end
			end
			spark:SetAlpha(currentAlpha)
		end
		if (not spark:IsShown()) then
			spark:Show()
		end
	end
end

local smoothingMinValue = .3 -- if a value is lower than this, we won't smoothe
local smoothingFrequency = .5 -- default duration of smooth transitions
local smartSmoothingDownFrequency = .15 -- duration of smooth reductions in smart mode
local smartSmoothingUpFrequency = .75 -- duration of smooth increases in smart mode
local smoothingLimit = 1/120 -- max updates per second

local OnUpdate = function(self, elapsed)
	local data = Bars[self]
	data.elapsed = (data.elapsed or 0) + elapsed
	if (data.elapsed < smoothingLimit) then
		return
	end

	if (data.updatesRunning) then
		-- Check if values are secret - if so, disable smoothing
		local valueIsSecret = issecretvalue and (issecretvalue(data.barValue) or issecretvalue(data.barDisplayValue) or issecretvalue(data.barMin) or issecretvalue(data.barMax))
		
		-- Coerce missing numbers before any comparisons to avoid nil errors
		if (type(data.barMin) ~= "number") then data.barMin = data.safeBarMin or 0 end
		if (type(data.barMax) ~= "number") then data.barMax = data.safeBarMax or 1 end
		if (type(data.barValue) ~= "number") then data.barValue = data.barMin end
		if (data.barMax <= data.barMin) then data.barMax = data.barMin + 1 end

		if (valueIsSecret) then
			-- Secret values can't be compared - just set display to target value
			data.barDisplayValue = data.barValue
			data.updatesRunning = nil
			data.smoothing = nil
		elseif (data.disableSmoothing) then
			if (data.barValue <= data.barMin) or (data.barValue >= data.barMax) then
				data.updatesRunning = nil
			end
		elseif (data.smoothing) then
			if (math_abs(data.barDisplayValue - data.barValue) < smoothingMinValue) then
				data.barDisplayValue = data.barValue
				data.smoothing = nil
			else
				-- The fraction of the total bar this total animation should cover
				local animsize = (data.barValue - data.smoothingInitialValue)/(data.barMax - data.barMin)

				local smoothSpeed
				if data.barValue > data.barDisplayValue then
					smoothSpeed = smartSmoothingUpFrequency
				elseif data.barValue < data.barDisplayValue then
					smoothSpeed = smartSmoothingDownFrequency
				else
					smoothSpeed = data.smoothingFrequency or smoothingFrequency
				end

				-- Points per second on average for the whole bar
				local pps = (data.barMax - data.barMin)/smoothSpeed

				-- Position in time relative to the length of the animation, scaled from 0 to 1
				local position = (GetTime() - data.smoothingStart)/smoothSpeed
				if (position < 1) then
					-- The change needed when using average speed
					local average = pps * animsize * data.elapsed -- can and should be negative

					-- Tha change relative to point in time and distance passed
					local change = 2*(3 * ( 1 - position )^2 * position) * average*2 --  y = 3 * (1 − t)^2 * t  -- quad bezier fast ascend + slow descend

					-- If there's room for a change in the intended direction, apply it, otherwise finish the animation
					if ( (data.barValue > data.barDisplayValue) and (data.barValue > data.barDisplayValue + change) )
					or ( (data.barValue < data.barDisplayValue) and (data.barValue < data.barDisplayValue + change) ) then
						data.barDisplayValue = data.barDisplayValue + change
					else
						data.barDisplayValue = data.barValue
						data.smoothing = nil
					end
				else
					data.barDisplayValue = data.barValue
					data.smoothing = nil
				end
			end
		else
			if (data.barDisplayValue <= data.barMin) or (data.barDisplayValue >= data.barMax) or (not data.smoothing) then
				data.updatesRunning = nil
			end
		end

		Update(self, data.elapsed)
	end

	-- call module OnUpdate handler
	if data.OnUpdate then
		data.OnUpdate(data.statusbar, data.elapsed)
	end

	-- only reset this at the very end, as calculations above need it
	data.elapsed = 0
end

Texture.SetTexCoord = function(self, ...)
	local tex = Textures[self]
	tex[1], tex[2], tex[3], tex[4] = ...
	Update(tex._owner)
end

Texture.GetTexCoord = function(self)
	local tex = Textures[self]
	return tex[1], tex[2], tex[3], tex[4]
end

StatusBar.SetTexCoord = function(self, ...)
	local tex = Textures[self]
	tex[1], tex[2], tex[3], tex[4] = ...
	Update(self, true)
end

StatusBar.GetTexCoord = function(self)
	local tex = Textures[self]
	return tex[1], tex[2], tex[3], tex[4]
end

StatusBar.GetRealTexCoord = function(self)
	local texCoords = Bars[self].texCoords
	return texCoords[1], texCoords[2], texCoords[3], texCoords[4]
end

StatusBar.GetSparkTexture = function(self)
	return Bars[self].spark:GetTexture()
end

StatusBar.DisableSmoothing = function(self, disableSmoothing)
	Bars[self].disableSmoothing = disableSmoothing
end

StatusBar.SetValue = function(self, value, overrideSmoothing)
	local data = Bars[self]
	local min, max = data.barMin, data.barMax
	local label = self.__AzeriteUI_DebugLabel or (self.DebugName and self.DebugName(self)) or "(bar)"

	-- Safe secret-value probe (issecretvalue may be absent in some clients)
	local function IsSecret(v)
		local checker = issecretvalue
		if (not checker) then
			return false
		end
		local ok, res = pcall(checker, v)
		if (not ok) then
			return false
		end
		return res and true or false
	end

	local isSecret = IsSecret(value)
	local minIsSecret = IsSecret(min)
	local maxIsSecret = IsSecret(max)
	
	-- Debug logging removed; orientation changes are logged in SetGrowth/SetReverseFill
	
	-- Skip clamping for secret values - they can't be compared but can be set directly
	if (not isSecret and type(value) == "number" and not minIsSecret and not maxIsSecret and type(min) == "number" and type(max) == "number") then
		if (value > max) then
			value = max
		elseif (value < min) then
			value = min
		end
		-- Store safe numeric fallback
		data.safeBarValue = value
		if (overrideSmoothing) then
			data.safeBarDisplayValue = value
		end
	end
	data.barValue = value
	-- Sync proxy for secret values
	if (isSecret or minIsSecret or maxIsSecret) and data.proxy then
		data.proxy:SetMinMaxValues(min or 0, max or 1)
		data.proxy:SetValue(value or 0)
		data.proxy:Show()
	end
	if overrideSmoothing then
		data.barDisplayValue = value
	end
	if (not data.disableSmoothing) then
		-- Check if values are secret before comparisons
		local displayIsSecret = IsSecret(data.barDisplayValue)
		local minSecretForClamp = minIsSecret
		local maxSecretForClamp = maxIsSecret
		if (not displayIsSecret and not minSecretForClamp and not maxSecretForClamp
			and type(data.barDisplayValue) == "number" and type(min) == "number" and type(max) == "number") then
			if (data.barDisplayValue > max) then
				data.barDisplayValue = max
			elseif (data.barDisplayValue < min) then
				data.barDisplayValue = min
			end
		end
		data.smoothingInitialValue = data.barDisplayValue
		data.smoothingStart = GetTime()
	end
	-- Skip comparison if values are secret
	local displayIsSecret = IsSecret(data.barDisplayValue)
	if (not isSecret and not displayIsSecret and type(value) == "number" and type(data.barDisplayValue) == "number") then
		if (value ~= data.barDisplayValue) then
			data.smoothing = true
		end
	else
		-- For secret or non-numeric values, always enable smoothing/updates
		data.smoothing = true
	end
	if (data.smoothing) then
		data.updatesRunning = true
		return
	end
	Update(self)
end

StatusBar.Clear = function(self)
	local data = Bars[self]
	data.barValue = data.barMin
	data.barDisplayValue = data.barMin
	Update(self)
end

StatusBar.SetMinMaxValues = function(self, min, max, overrideSmoothing)
	local data = Bars[self]

	-- Coerce nil/secret inputs to sane numbers before any comparisons
	local function Coerce(v, fallback, default)
		if (type(v) == "number" and (not issecretvalue or not issecretvalue(v))) then
			return v
		end
		if (type(fallback) == "number" and (not issecretvalue or not issecretvalue(fallback))) then
			return fallback
		end
		return default
	end
	min = Coerce(min, data.safeBarMin or data.barMin or 0, 0)
	max = Coerce(max, data.safeBarMax or data.barMax or 1, 1)
	if (max <= min) then
		max = min + 1
	end
	if (type(data.barValue) ~= "number" or (issecretvalue and issecretvalue(data.barValue))) then
		data.barValue = min
	end
	if (type(data.barDisplayValue) ~= "number" or (issecretvalue and issecretvalue(data.barDisplayValue))) then
		data.barDisplayValue = data.barValue
	end
	-- Check if values are secret before any comparisons
	local minIsSecret = issecretvalue and issecretvalue(min)
	local maxIsSecret = issecretvalue and issecretvalue(max)
	local valueIsSecret = issecretvalue and issecretvalue(data.barValue)
	local displayValueIsSecret = issecretvalue and issecretvalue(data.barDisplayValue)
	local dataMinIsSecret = issecretvalue and issecretvalue(data.barMin)
	local dataMaxIsSecret = issecretvalue and issecretvalue(data.barMax)
	
	-- Only compare if not secret
	if (not minIsSecret and not maxIsSecret and not dataMinIsSecret and not dataMaxIsSecret) then
		if (data.barMin == min) and (data.barMax == max) then
			return
		end
	end
	
	-- Only clamp values if they're not secret
	if (not valueIsSecret and not maxIsSecret and not minIsSecret) then
		if (data.barValue > max) then
			data.barValue = max
		elseif (data.barValue < min) then
			data.barValue = min
		end
	end
	
	if (overrideSmoothing) then
		data.barDisplayValue = data.barValue
	else
		if (not displayValueIsSecret and not maxIsSecret and not minIsSecret) then
			if (data.barDisplayValue > max) then
				data.barDisplayValue = max
			elseif (data.barDisplayValue < min) then
				data.barDisplayValue = min
			end
		end
	end
	data.barMin = min
	data.barMax = max
	-- Sync proxy for secret values
	if (data.proxy) then
		local minIsSecret = issecretvalue and issecretvalue(min)
		local maxIsSecret = issecretvalue and issecretvalue(max)
		if (minIsSecret or maxIsSecret) then
			data.proxy:SetMinMaxValues(min or 0, max or 1)
			data.proxy:Show()
		end
	end
	-- Store safe numeric fallbacks
	if (not minIsSecret and type(min) == "number") then
		data.safeBarMin = min
	end
	if (not maxIsSecret and type(max) == "number") then
		data.safeBarMax = max
	end
	Update(self)
end

-- Safe fallbacks for secret values (numbers only)
StatusBar.SetSafeValue = function(self, value)
	local data = Bars[self]
	if (type(value) == "number") then
		data.safeBarValue = value
		data.safeBarDisplayValue = value
		Update(self)
	end
end

StatusBar.SetSafeMinMaxValues = function(self, min, max)
	local data = Bars[self]
	if (type(min) == "number") then
		data.safeBarMin = min
	end
	if (type(max) == "number") then
		data.safeBarMax = max
	end
	Update(self)
end

StatusBar.SetStatusBarColor = function(self, ...)
	local data = Bars[self]
	data.bar:SetVertexColor(...)
	data.spark:SetVertexColor(...)
	if (data.proxy) then
		data.proxy:SetStatusBarColor(...)
	end
end

StatusBar.SetStatusBarTexture = function(self, ...)
	local arg = ...
	if (type(arg) == "number") then
		Bars[self].bar:SetColorTexture(...)
		if (Bars[self].proxy) then
			Bars[self].proxy:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
			Bars[self].proxy:GetStatusBarTexture():SetColorTexture(...)
		end
	else
		Bars[self].bar:SetTexture(...)
		if (Bars[self].proxy) then
			Bars[self].proxy:SetStatusBarTexture(...)
		end
	end
	Update(self, true)
end

StatusBar.SetFlippedHorizontally = function(self, reversed)
	Bars[self].reversedH = reversed
	if (ShouldDebugBar(self)) then
		print("|cff33ff99", "AzeriteUI", "SetFlippedHorizontally", tostring(reversed), tostring(self.__AzeriteUI_DebugLabel))
	end
end

StatusBar.SetFlippedVertically = function(self, reversed)
	Bars[self].reversedV = reversed
end

StatusBar.IsFlippedHorizontally = function(self)
	return Bars[self].reversedH
end

StatusBar.IsFlippedVertically = function(self)
	return Bars[self].reversedV
end

StatusBar.SetSparkMap = function(self, sparkMap)
	Bars[self].sparkMap = sparkMap
end

StatusBar.SetForceNative = function(self, enabled)
	Bars[self].forceNative = enabled and true or false
end

StatusBar.SetSparkTexture = function(self, ...)
	local arg = ...
	if (type(arg) == "number") then
		Bars[self].spark:SetColorTexture(...)
	else
		Bars[self].spark:SetTexture(...)
	end
end

StatusBar.SetSparkColor = function(self, ...)
	Bars[self].spark:SetVertexColor(...)
end

StatusBar.SetSparkMinMaxPercent = function(self, min, max)
	local data = Bars[self]
	data.sparkMinPercent = min
	data.sparkMinPercent = max
end

StatusBar.SetSparkBlendMode = function(self, blendMode)
	Bars[self].spark:SetBlendMode(blendMode)
end

StatusBar.SetSparkFlash = function(self, durationIn, durationOut, minAlpha, maxAlpha)
	local data = Bars[self]
	data.sparkDurationIn = durationIn
	data.sparkDurationOut = durationOut
	data.sparkMinAlpha = minAlpha
	data.sparkMaxAlpha = maxAlpha
	data.sparkDirection = "IN"
	data.spark:SetAlpha(minAlpha)
end

StatusBar.SetOrientation = function(self, orientation)
	local data = Bars[self]
	if (orientation == "HORIZONTAL") then
		if (data.barBlizzardReverseFill) then
			return self:SetGrowth("LEFT")
		else
			return self:SetGrowth("RIGHT")
		end

	elseif (orientation == "VERTICAL") then
		if (data.barBlizzardReverseFill) then
			return self:SetGrowth("DOWN")
		else
			return self:SetGrowth("UP")
		end

	elseif (orientation == "LEFT") or (orientation == "RIGHT") or (orientation == "UP") or (orientation == "DOWN") then
		return self:SetGrowth(orientation)
	end
end

StatusBar.SetGrowth = function(self, orientation)
	local data = Bars[self]
	local prev = data.barOrientation
	if (orientation == "LEFT") then
		data.spark:SetTexCoord(0, 1, 3/32, 28/32)
		data.barOrientation = "LEFT"
		data.barBlizzardOrientation = "HORIZONTAL"
		data.barBlizzardReverseFill = true
		if (data.proxy) then
			data.proxy:SetOrientation("HORIZONTAL")
			data.proxy:SetReverseFill(true)
		end

	elseif (orientation == "RIGHT") then
		data.spark:SetTexCoord(0, 1, 3/32, 28/32)
		data.barOrientation = "RIGHT"
		data.barBlizzardOrientation = "HORIZONTAL"
		data.barBlizzardReverseFill = false
		if (data.proxy) then
			data.proxy:SetOrientation("HORIZONTAL")
			data.proxy:SetReverseFill(false)
		end

	elseif (orientation == "UP") then
		data.spark:SetTexCoord(1,11/32,0,11/32,1,19/32,0,19/32)
		data.barOrientation = "UP"
		data.barBlizzardOrientation = "VERTICAL"
		data.barBlizzardReverseFill = false
		if (data.proxy) then
			data.proxy:SetOrientation("VERTICAL")
			data.proxy:SetReverseFill(false)
		end

	elseif (orientation == "DOWN") then
		data.spark:SetTexCoord(1,11/32,0,11/32,1,19/32,0,19/32)
		data.barOrientation = "DOWN"
		data.barBlizzardOrientation = "VERTICAL"
		data.barBlizzardReverseFill = true
		if (data.proxy) then
			data.proxy:SetOrientation("VERTICAL")
			data.proxy:SetReverseFill(true)
		end
	end
	if (ShouldDebugBar(self)) then
		print("|cff33ff99", "AzeriteUI", "SetGrowth", tostring(prev), "->", tostring(data.barOrientation), tostring(self.__AzeriteUI_DebugLabel))
	end
end

StatusBar.GetGrowth = function(self, direction)
	return Bars[self].barOrientation
end

StatusBar.GetOrientation = function(self)
	return Bars[self].barBlizzardOrientation
end

StatusBar.SetReverseFill = function(self, state)
	local data = Bars[self]
	data.barBlizzardReverseFill = state and true or false
	if (data.proxy) then
		data.proxy:SetReverseFill(state and true or false)
	end
	if (ShouldDebugBar(self)) then
		print("|cff33ff99", "AzeriteUI", "SetReverseFill", tostring(state), tostring(self.__AzeriteUI_DebugLabel))
	end
end

StatusBar.GetReverseFill = function(self, state)
	return Bars[self].barBlizzardReverseFill
end

-- We can not allow the bar to get its scripts overwritten
StatusBar.SetScript = function(self, ...)
	local scriptHandler, func = ...
	if (scriptHandler == "OnUpdate") then
		Bars[self].OnUpdate = func
	elseif (scriptHandler == "OnTexCoordChanged") then
		Bars[self].OnTexCoordChanged = func
	elseif (scriptHandler == "OnDisplayValueChanged") then
		Bars[self].OnDisplayValueChanged = func
	else
		Orig_SetScript(self, ...)
	end
end

StatusBar.GetScript = function(self, ...)
	local scriptHandler, func = ...
	if (scriptHandler == "OnUpdate") then
		return Bars[self].OnUpdate
	elseif (scriptHandler == "OnTexCoordChanged") then
		return Bars[self].OnTexCoordChanged
	elseif (scriptHandler == "OnDisplayValueChanged") then
		return Bars[self].OnDisplayValueChanged
	else
		return Orig_GetScript(self, ...)
	end
end

StatusBar.GetValue = function(self)
	return Bars[self].barValue
end

StatusBar.GetDisplayValue = function(self)
	return Bars[self].barDisplayValue
end

StatusBar.GetMinMaxValues = function(self)
	return Bars[self].barMin, Bars[self].barMax
end

StatusBar.GetStatusBarColor = function(self)
	return Bars[self].bar:GetVertexColor()
end

StatusBar.GetStatusBarTexture = function(self)
	return Bars[self].bar
end

-- Percent based on proxy texture size when secret values are used
StatusBar.GetSecretPercent = function(self)
	local data = Bars[self]
	local proxy = data and data.proxy
	if (not proxy or not proxy:IsShown()) then
		return nil
	end
	local tex = proxy:GetStatusBarTexture()
	if (not tex) then
		return nil
	end
	local width, height = proxy:GetSize()
	if (data.barBlizzardOrientation == "VERTICAL") then
		local ok, th = pcall(tex.GetHeight, tex)
		if (not ok or type(th) ~= "number" or (issecretvalue and issecretvalue(th))) then
			return nil
		end
		if (height and height > 0) then
			return th / height
		end
	else
		local ok, tw = pcall(tex.GetWidth, tex)
		if (not ok or type(tw) ~= "number" or (issecretvalue and issecretvalue(tw))) then
			return nil
		end
		if (width and width > 0) then
			return tw / width
		end
	end
	return nil
end

-- Debug helper for external tools (/azdebug dump)
StatusBar.GetDebugData = function(self)
	local data = Bars[self]
	if (not data) then
		return nil
	end
	local proxy = data.proxy
	local proxyShown = proxy and proxy.IsShown and proxy:IsShown() or false
	local proxyTex = proxy and proxy.GetStatusBarTexture and proxy:GetStatusBarTexture()
	local proxyTexCoord = nil
	local proxyTexSize = nil
	if (proxyTex and proxyTex.GetTexCoord) then
		local ok, a, b, c, d = pcall(proxyTex.GetTexCoord, proxyTex)
		if (ok) then
			proxyTexCoord = { a, b, c, d }
		end
	end
	if (proxy and proxy.GetSize) then
		local ok, w, h = pcall(proxy.GetSize, proxy)
		if (ok) then
			proxyTexSize = { w, h }
		end
	end
	return {
		reversedH = data.reversedH,
		reversedV = data.reversedV,
		barOrientation = data.barOrientation,
		barBlizzardOrientation = data.barBlizzardOrientation,
		barBlizzardReverseFill = data.barBlizzardReverseFill,
		proxyShown = proxyShown,
		proxyTexCoord = proxyTexCoord,
		proxySize = proxyTexSize
	}
end

StatusBar.GetAnchor = function(self) return Bars[self].bar end
StatusBar.GetObjectType = function(self) return "StatusBar" end
StatusBar.IsObjectType = function(self, type) return type == "SmartBar" or type == "StatusBar" or type == "Frame" end
StatusBar.IsForbidden = function(self) return true end

lib.CreateSmoothBar = function(self, name, parent, template)

	local statusbar = setmetatable(CreateFrame("Frame", name, parent, template), StatusBar_MT)
	statusbar:SetSize(1,1)

	local bar = setmetatable(statusbar:CreateTexture(), Texture_MT)
	bar:SetDrawLayer("BORDER", 0)
	bar:SetPoint("TOP")
	bar:SetPoint("BOTTOM")
	bar:SetPoint("LEFT")
	bar:SetWidth(statusbar:GetWidth())

	-- rare gem of a texture, works nicely on bars smaller than 256px in effective width
	bar:SetTexture([[Interface\FontStyles\FontStyleMetal]])

	-- the spark texture
	local spark = statusbar:CreateTexture()
	spark:SetDrawLayer("BORDER", 1)
	spark:SetPoint("CENTER", bar, "RIGHT", 0, 0)
	spark:SetSize(1,1)
	spark:SetAlpha(.6)
	spark:SetBlendMode("ADD")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]]) -- 32x32, centered vertical spark being 32x9px, from 0,11px to 32,19px
	spark:SetTexCoord(0, 1, 25/80, 55/80)

	local data = {}
	data.bar = bar
	data.spark = spark
	data.statusbar = statusbar

	-- Proxy StatusBar for secret values
	local proxy = CreateFrame("StatusBar", nil, statusbar)
	proxy:SetAllPoints(statusbar)
	proxy:SetStatusBarTexture([[Interface\FontStyles\FontStyleMetal]])
	proxy:SetFrameLevel(statusbar:GetFrameLevel())
	proxy:SetOrientation("HORIZONTAL")
	proxy:SetReverseFill(false)
	proxy:Hide()

	data.proxy = proxy

	data.barMin = 0 -- min value
	data.barMax = 1 -- max value
	data.barValue = 0 -- real value
	data.barDisplayValue = 0 -- displayed value while smoothing
	data.barOrientation = "RIGHT" -- direction the bar is growing in

	-- API compatibility
	data.barBlizzardOrientation = "HORIZONTAL"
	data.barBlizzardReverseFill = false

	data.sparkThickness = 8
	data.sparkOffset = 1/32
	data.sparkDirection = "IN"
	data.sparkDurationIn = .75
	data.sparkDurationOut = .55
	data.sparkMinAlpha = .25
	data.sparkMaxAlpha = .95
	data.sparkMinPercent = 1/100
	data.sparkMaxPercent = 99/100

	-- The real texcoords of the bar texture
	data.texCoords = {0, 1, 0, 1}

	-- Give multiple objects access using their 'self' as key
	Bars[statusbar] = data
	Bars[bar] = data

	-- Virtual texcoord handling
	local texCoords = { 0, 1, 0, 1 }
	texCoords._owner = statusbar

	-- Give both the bar texture and the virtual bar direct access
	Textures[bar] = texCoords
	Textures[statusbar] = texCoords

	Update(statusbar)

	-- Apply our custom handler
	Orig_SetScript(statusbar, "OnUpdate", OnUpdate)

	return statusbar
end

local mixins = {
	CreateSmoothBar = true
}

lib.Embed = function(self, target)
	for method in pairs(mixins) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

for target in pairs(lib.embeds) do
	lib:Embed(target)
end

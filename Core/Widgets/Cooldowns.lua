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
local Widgets = ns.Private.Widgets or {}
ns.Private.Widgets = Widgets

-- Lua API
local next, pairs, pcall, select, type = next, pairs, pcall, select, type

-- GLOBALS: CreateFrame, GetTime, hooksecurefunc

-- Addon API
local AbbreviateTime = ns.API.AbbreviateTime

-- Local Caches
local Cooldowns, Active = {}, {}

local IsSafeNumber = function(value)
	return type(value) == "number" and (not issecretvalue or not issecretvalue(value))
end

-- Local Timer Frame
local Timer = CreateFrame("Frame"); Timer:Hide()
Timer:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) - elapsed
	if (self.elapsed > 0) then
		return
	end
	self.elapsed = .01

	local timeLeft
	local now = GetTime()

	-- Parse and update the active cooldowns.
	for cooldown,info in next,Active do
		local duration = info.duration
		timeLeft = nil
		if (info.durationObject and info.durationObject.EvaluateRemainingTime) then
			local ok, remaining = pcall(info.durationObject.EvaluateRemainingTime, info.durationObject)
			if (ok and IsSafeNumber(remaining)) then
				timeLeft = remaining
				info.remaining = remaining
				info.lastTick = now
			else
				local isZero = false
				if (info.durationObject.IsZero) then
					local okZero, zero = pcall(info.durationObject.IsZero, info.durationObject)
					if (okZero and type(zero) == "boolean" and zero) then
						isZero = true
					end
				end
				if (isZero) then
					timeLeft = 0
					info.remaining = 0
				elseif (IsSafeNumber(info.remaining)) then
					local lastTick = IsSafeNumber(info.lastTick) and info.lastTick or now
					local delta = now - lastTick
					if (delta < 0) then
						delta = 0
					end
					timeLeft = info.remaining - delta
					if (timeLeft < 0) then
						timeLeft = 0
					end
					info.remaining = timeLeft
					info.lastTick = now
				elseif (IsSafeNumber(info.expiration)) then
					timeLeft = info.expiration - now
					if (IsSafeNumber(timeLeft) and timeLeft > 0) then
						info.remaining = timeLeft
						info.lastTick = now
					end
				end
			end
		elseif (IsSafeNumber(info.expiration)) then
			timeLeft = info.expiration - now
		end

		-- Don't show bars and texts for cooldowns
		-- shorter than the global cooldown. Their spirals is enough.
		if (IsSafeNumber(timeLeft) and timeLeft > 0) and ((IsSafeNumber(duration) and duration > 1.5) or info.durationObject) then
			if (info.Bar) and (info.Bar:IsVisible()) then
				if (IsSafeNumber(duration) and duration > 0) then
					info.Bar:SetValue(timeLeft)
				end
			end
			if (info.Time) then
				info.Time:SetFormattedText(AbbreviateTime(timeLeft))
			end
		elseif (timeLeft == nil and info.durationObject) then
			-- Keep the previous visual state when remaining time is temporarily
			-- inaccessible due secret-value reads in combat.
		else
			if (info.Bar) then
				info.Bar:Hide()
				info.Bar:SetMinMaxValues(0, 1, true)
				info.Bar:SetValue(1, true)
			end
			if (info.Time) then
				info.Time:SetText("")
			end
			Active[cooldown] = nil
		end
	end

	if (not next(Active)) then
		self:Hide()
	end
end)

-- Callbacks
---------------------------------------------------------
local AttachToCooldown = function(cooldown, ...)
	local info = Cooldowns[cooldown]
	if (not info) then
		return
	end
	for i,v in pairs({...}) do
		if (v) and (v.IsObjectType) and (v ~= cooldown) then
			if (not info.Bar) and (v:IsObjectType("StatusBar")) then
				info.Bar = v
			end
			if (not info.Time) and (v:IsObjectType("FontString")) then
				info.Time = v
			end
		end
	end
end

-- Virtual Cooldown Template
---------------------------------------------------------
-- This is meant as a way for bars and texts to
-- piggyback on the normal cooldown API,
-- without using a normal cooldown frame.
-- We're only adding methods we or our libraries use.
local Cooldown = {}
local Cooldown_MT = { __index = Cooldown }

Cooldown.SetCooldown = function(self, start, duration)
	local info = Cooldowns[self]
	local safeStart = IsSafeNumber(start) and start or 0
	local safeDuration = IsSafeNumber(duration) and duration or 0
	info.start = safeStart
	info.expiration = safeStart + safeDuration
	info.duration = safeDuration
	info.durationObject = nil
	info.shown = true
	self._isshown = true

	local now = GetTime()
	local timeLeft = info.expiration - now
	info.remaining = (IsSafeNumber(timeLeft) and timeLeft > 0) and timeLeft or nil
	info.lastTick = now

	if (info.Bar) then
		if (safeDuration > 0 and IsSafeNumber(timeLeft) and timeLeft > 0) then
			info.Bar:SetMinMaxValues(0, info.duration, true)
			info.Bar:SetValue(timeLeft, true)
		else
			info.Bar:SetMinMaxValues(0, 1, true)
			info.Bar:SetValue(1, true)
		end
	end
	if (info.Time) then
		if (safeDuration > 0 and IsSafeNumber(timeLeft) and timeLeft > 0) then
			info.Time:SetFormattedText(AbbreviateTime(timeLeft))
		else
			info.Time:SetText("")
		end
	end

	Active[self] = info

	if (not Timer:IsShown()) then
		Timer:Show()
	end
end

Cooldown.SetCooldownFromDurationObject = function(self, durationObject)
	local info = Cooldowns[self]
	info.durationObject = durationObject
	if (IsSafeNumber(info.fallbackStart) and IsSafeNumber(info.fallbackDuration) and info.fallbackDuration > 0) then
		info.start = info.fallbackStart
		info.duration = info.fallbackDuration
		info.expiration = info.start + info.duration
	else
		info.start = 0
		info.expiration = 0
		info.duration = 0
	end
	info.shown = true
	self._isshown = true

	local remaining = nil
	if (durationObject and durationObject.EvaluateRemainingTime) then
		local ok, value = pcall(durationObject.EvaluateRemainingTime, durationObject)
		if (ok and IsSafeNumber(value)) then
			remaining = value
		end
	end
	if ((not IsSafeNumber(remaining)) and IsSafeNumber(info.expiration) and IsSafeNumber(info.duration) and info.duration > 0) then
		remaining = info.expiration - GetTime()
	end
	info.remaining = (IsSafeNumber(remaining) and remaining > 0) and remaining or nil
	info.lastTick = GetTime()

	if (info.Bar) then
		info.Bar:SetMinMaxValues(0, 1, true)
		info.Bar:SetValue(1, true)
	end
	if (info.Time) then
		if (remaining and remaining > 0) then
			info.Time:SetFormattedText(AbbreviateTime(remaining))
		elseif (not info.durationObject) then
			info.Time:SetText("")
		end
	end

	Active[self] = info
	if (not Timer:IsShown()) then
		Timer:Show()
	end
end

Cooldown.SetAuraFallbackData = function(self, expiration, duration)
	local info = Cooldowns[self]
	if (not info) then
		return
	end
	if (IsSafeNumber(expiration) and IsSafeNumber(duration) and duration > 0) then
		info.fallbackDuration = duration
		info.fallbackExpiration = expiration
		info.fallbackStart = expiration - duration
		if (info.durationObject and not IsSafeNumber(info.remaining)) then
			local remaining = expiration - GetTime()
			if (IsSafeNumber(remaining) and remaining > 0) then
				info.remaining = remaining
				info.lastTick = GetTime()
			end
			info.start = info.fallbackStart
			info.duration = duration
			info.expiration = expiration
		end
	end
end

Cooldown.Clear = function(self)
	if (Active[self]) then
		local info = Cooldowns[self]
		info.start = 0
		info.expiration = 0
		info.duration = 0
		info.durationObject = nil
		info.remaining = nil
		info.lastTick = nil
		info.fallbackStart = nil
		info.fallbackDuration = nil
		info.fallbackExpiration = nil
	end
end

Cooldown.Show = function(self)
	local info = Cooldowns[self]
	if info.Bar then
		if (not info.Bar:IsShown()) then
			info.Bar:Show()
		end
	end
	info.shown = true
	self._isshown = true
end

Cooldown.Hide = function(self)
	local info = Cooldowns[self]
	if info.Bar then
		info.Bar:Hide()
		info.Bar:SetMinMaxValues(0, 1, true)
		info.Bar:SetValue(1, true)
	end
	if info.Time then
		info.Time:SetText("")
	end
	info.shown = nil
	self._isshown = nil
	self:Clear()
end

Cooldown.IsShown = function(self)
	local info = Cooldowns[self]
	if (info and info.shown ~= nil) then
		return info.shown
	end
	return self._isshown
end

Cooldown.IsObjectType = function(self, objectType)
	return objectType == "Cooldown"
end

-- Global API
---------------------------------------------------------
Widgets.RegisterCooldown = function(...)
	-- Check if an actual element is passed,
	-- and hook its relevant methods if so.
	local cooldown
	for i,v in pairs({...}) do
		if (v) and (v.IsObjectType) and (v:IsObjectType("Cooldown")) then
			cooldown = v
			break
		end
	end
	if (cooldown) then
		if (not Cooldowns[cooldown]) then
			Cooldowns[cooldown] = {}
			hooksecurefunc(cooldown, "SetCooldown", Cooldown.SetCooldown)
			if (cooldown.SetCooldownFromDurationObject) then
				hooksecurefunc(cooldown, "SetCooldownFromDurationObject", Cooldown.SetCooldownFromDurationObject)
			end
			hooksecurefunc(cooldown, "Clear", Cooldown.Clear)
			hooksecurefunc(cooldown, "Hide", Cooldown.Hide)
			if (cooldown.Show) then
				hooksecurefunc(cooldown, "Show", Cooldown.Show)
			end
		end
		AttachToCooldown(cooldown, ...)
		return cooldown
	else
		-- Only subelements were passed,
		-- so we need a virtual cooldown element.
		local cooldown = setmetatable({}, Cooldown_MT)
		Cooldowns[cooldown] = { shown = nil }
		cooldown._isshown = nil
		AttachToCooldown(cooldown, ...)
		return cooldown
	end
end

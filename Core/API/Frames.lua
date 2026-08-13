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
local API = ns.API or {}
ns.API = API

-- Lua API
local CreateFrame = CreateFrame
local pcall = pcall
local type = type

local CreateFrameUnscaled = function(...)
	local frame = CreateFrame(...)
	frame:SetIgnoreParentScale(true)
	return frame
end

local IsHouseEditorActive = function()
	local isActive = C_HouseEditor and C_HouseEditor.IsHouseEditorActive
	if (not isActive) then
		return false
	end
	local ok, active = pcall(isActive)
	return ok and active == true
end

local IsPlayerAtEffectiveMaxLevel = function()
	return GameRulesUtil.IsPlayerAtEffectiveMaxLevel()
end

local IsLevelAtEffectiveMaxLevel = function(level)
	if (type(level) ~= "number") or (issecretvalue and issecretvalue(level)) then
		return false
	end
	return level >= GameRulesUtil.GetEffectiveMaxLevelForPlayer()
end

-- Global API
---------------------------------------------------------
API.CreateFrameUnscaled = CreateFrameUnscaled
API.IsHouseEditorActive = IsHouseEditorActive
API.IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
API.IsLevelAtEffectiveMaxLevel = IsLevelAtEffectiveMaxLevel

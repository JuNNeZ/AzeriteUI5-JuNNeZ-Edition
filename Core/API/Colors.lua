--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

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

-- GLOBALS: UnitIsConnected, UnitIsDeadOrGhost, UnitIsPlayer, UnitIsTapDenied
-- GLOBALS: UnitClass, UnitReaction, UnitCanAttack, UnitPlayerControlled
-- GLOBALS: UnitLevel, UnitEffectiveLevel, UnitQuestTrivialLevelRange, UnitQuestTrivialLevelRangeScaling
-- GLOBALS: GetScalingQuestGreenRange, GetQuestGreenRange
-- GLOBALS: issecretvalue

local Colors = ns.Colors

local IsSafeUnitToken = function(unit)
	if (type(unit) ~= "string") then
		return
	end
	if (type(issecretvalue) == "function") and issecretvalue(unit) then
		return
	end
	return true
end

-- Retrieve a unit's color
local GetUnitColor = function(unit)
	local color
	if (IsSafeUnitToken(unit) and UnitExists(unit)) then
		if ((not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit) and UnitCanAttack("player", unit)) then
			color = Colors.tapped
		elseif (not UnitIsConnected(unit)) then
			color = Colors.disconnected
		elseif (UnitIsDeadOrGhost(unit)) then
			color = Colors.dead
		elseif (UnitIsPlayer(unit)) then
			local _, class = UnitClass(unit)
			if class then
				color = Colors.class[class]
			else
				color = Colors.disconnected
			end
		else
			local reaction = UnitReaction(unit, "player")
			if (reaction) then
				color = Colors.reaction[reaction]
			else
				color = Colors.offwhite
			end
		end
	end
	return color
end

-- Unit difficulty coloring, as Blizzard's DifficultyUtil.GetRelativeDifficultyColor
-- and GetScalingQuestDifficultyColor. The green test used to compare against the
-- negated trivial range, which can never pass, so every unit more than four levels
-- below the player read grey instead of green; most visible on Forever, which levels
-- without scaling.
local GetTrivialRange = function(fn, fallback)
	local range = (type(fn) == "function") and fn("player")
	if (type(range) == "number") then return range end
	return fallback
end

local GetDifficultyColor = function(level, isScaling)
	local colors = Colors.quest
	local playerLevel = (UnitEffectiveLevel or UnitLevel)("player")
	local levelDiff = level - playerLevel
	local color
	if (levelDiff >= 5) then
		color = colors.red
	elseif (levelDiff >= 3) then
		color = colors.orange
	elseif (levelDiff >= (isScaling and 0 or -4)) then
		color = colors.yellow
	elseif (-levelDiff <= (isScaling and GetTrivialRange(UnitQuestTrivialLevelRangeScaling, 8) or GetTrivialRange(UnitQuestTrivialLevelRange, 8))) then
		color = colors.green
	else
		color = colors.gray
	end
	return color[1], color[2], color[3], color.colorCode
end

-- Global API
---------------------------------------------------------
API.GetUnitColor = GetUnitColor
API.GetDifficultyColorByLevel = GetDifficultyColor

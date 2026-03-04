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

if (not ns.IsRetail) then return end

ns.AuraSorts = ns.AuraSorts or {}

-- Lua API
local math_huge = math.huge
local table_sort = table.sort

-- Data
local Spells = ns.AuraData.Spells
local Hidden = ns.AuraData.Hidden
local Priority = ns.AuraData.Priority

-- https://wowpedia.fandom.com/wiki/API_C_UnitAuras.GetAuraDataByAuraInstanceID
local SafeBool = function(value)
	if (issecretvalue and issecretvalue(value)) then
		return false
	end
	return value and true or false
end

local SafeNumber = function(value, fallback)
	if (issecretvalue and issecretvalue(value)) then
		return fallback
	end
	if (type(value) == "number") then
		return value
	end
	return fallback
end

local Aura_Sort = function(a, b)

	-- Debuffs first
	local aHarm = SafeBool(a.isHarmful)
	local bHarm = SafeBool(b.isHarmful)
	if (aHarm ~= bHarm) then
		return aHarm
	end

	-- Show priority auras first
	local aSpell = SafeNumber(a.spellId, nil)
	local bSpell = SafeNumber(b.spellId, nil)
	local aPrio = aSpell and Priority[aSpell]
	local bPrio = bSpell and Priority[bSpell]
	if (aPrio ~= bPrio) then
		return aPrio and true or false
	end

	-- Player applied HoTs that we would display on nameplates
	local aHoT = (not SafeBool(a.isHarmful)) and SafeBool(a.isPlayerAura) and SafeBool(a.canApplyAura)
	local bHoT = (not SafeBool(b.isHarmful)) and SafeBool(b.isPlayerAura) and SafeBool(b.canApplyAura)
	if (aHoT ~= bHoT) then
		return aHoT
	end

	-- Playered applied debuffs that would display by default on nameplates
	local aPlate = SafeBool(a.nameplateShowAll) or (SafeBool(a.nameplateShowPersonal) and SafeBool(a.isPlayerAura))
	local bPlate = SafeBool(b.nameplateShowAll) or (SafeBool(b.nameplateShowPersonal) and SafeBool(b.isPlayerAura))
	if (aPlate ~= bPlate) then
		return aPlate
	end

	-- Player first, includes procs and zone buffs.
	local aPlayer = SafeBool(a.isPlayerAura)
	local bPlayer = SafeBool(b.isPlayerAura)
	if (aPlayer ~= bPlayer) then
		return aPlayer
	end

	-- No duration last, short times first.
	local aDuration = SafeNumber(a.duration, 0)
	local bDuration = SafeNumber(b.duration, 0)
	local aTime = (aDuration == 0) and math_huge or SafeNumber(a.expirationTime, math_huge)
	local bTime = (bDuration == 0) and math_huge or SafeNumber(b.expirationTime, math_huge)

	if (aTime ~= bTime) then
		return aTime < bTime
	end

	local aId = SafeNumber(a.auraInstanceID, 0)
	local bId = SafeNumber(b.auraInstanceID, 0)
	if (aId == bId) then
		return false
	end
	return aId < bId
end

-- The alternate function is meant to mimic Blizzard sorting.
local Aura_Sort_Alternate = function(a, b)

	-- Player applied HoTs that we would display on nameplates
	local aHoT = (not SafeBool(a.isHarmful)) and SafeBool(a.isPlayerAura) and SafeBool(a.canApplyAura)
	local bHoT = (not SafeBool(b.isHarmful)) and SafeBool(b.isPlayerAura) and SafeBool(b.canApplyAura)
	if (aHoT ~= bHoT) then
		return aHoT
	end

	-- Playered applied debuffs that would display by default on nameplates
	local aPlate = SafeBool(a.nameplateShowAll) or (SafeBool(a.nameplateShowPersonal) and SafeBool(a.isPlayerAura))
	local bPlate = SafeBool(b.nameplateShowAll) or (SafeBool(b.nameplateShowPersonal) and SafeBool(b.isPlayerAura))
	if (aPlate ~= bPlate) then
		return aPlate
	end

	-- Player first, includes procs and zone buffs.
	local aPlayer = SafeBool(a.isPlayerAura)
	local bPlayer = SafeBool(b.isPlayerAura)
	if (aPlayer ~= bPlayer) then
		return aPlayer
	end

	-- No duration last, short times first.
	--local aTime = (not a.duration or a.duration == 0) and math_huge or a.expirationTime or -1
	--local bTime = (not b.duration or b.duration == 0) and math_huge or b.expirationTime or -1

	--if (aTime ~= bTime) then
	--	return aTime < bTime
	--end

	local aId = SafeNumber(a.auraInstanceID, 0)
	local bId = SafeNumber(b.auraInstanceID, 0)
	if (aId == bId) then
		return false
	end
	return aId < bId
end

ns.AuraSorts.AlternateFuncton = Aura_Sort_Alternate
ns.AuraSorts.Alternate = function(element, max)
	table_sort(element, ns.AuraSorts.AlternateFuncton)
	return 1, #element
end

ns.AuraSorts.DefaultFunction = Aura_Sort
ns.AuraSorts.Default = function(element, max)
	table_sort(element, ns.AuraSorts.DefaultFunction)
	return 1, #element
end

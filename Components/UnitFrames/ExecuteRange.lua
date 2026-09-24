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
--[[
	The player's execute threshold: the share of an enemy's health below which their execute
	works, 0 for a class or specialization without one. For the nameplates' execute marker
	(Docs/Nameplates Overhaul Plan.md, Phase 8).

	Worked out from class and specialization when they change, never from anything combat can
	make secret. Where a talent grants the execute the talent's spell has to be known; where a
	talent changes the threshold (Massacre, for one) the option to set it by hand is the answer,
	since talents move between patches faster than a table here would follow.
]]
local _, ns = ...

local API = ns.API

-- Lua API
local ipairs = ipairs
local type = type

local RETAIL_EXECUTES = {
	WARRIOR = { { threshold = .2 } }, -- Execute
	PALADIN = { { threshold = .2 } }, -- Hammer of Wrath
	HUNTER = { { threshold = .2 } }, -- Kill Shot
	PRIEST = { { threshold = .2 } }, -- Shadow Word: Death
	MONK = { { threshold = .15 } }, -- Touch of Death on elites and bosses (weaker ones: below your own health)
	DEATHKNIGHT = { { threshold = .35, spell = 343294 } }, -- Soul Reaper, where talented
	WARLOCK = {
		{ spec = 265, threshold = .2, spell = 198590 }, -- Drain Soul, Affliction
		{ spec = 267, threshold = .2, spell = 17877 } -- Shadowburn, Destruction
	}
}

-- Forever: classic content. Unverified in game.
local FOREVER_EXECUTES = {
	WARRIOR = { { threshold = .2 } }, -- Execute
	PALADIN = { { threshold = .2 } } -- Hammer of Wrath
}

local GetClassFile = function()
	local classFile = UnitClassBase and UnitClassBase("player")
	if (type(classFile) ~= "string" or classFile == "") then
		local _, fallbackClass = UnitClass("player")
		classFile = fallbackClass
	end
	return classFile
end

local Resolve = function()
	local entries = (ns.IsForever and FOREVER_EXECUTES or RETAIL_EXECUTES)[GetClassFile()]
	if (type(entries) ~= "table") then
		return 0
	end
	local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
	local isKnown = API.IsSpellKnownAnywhere
	for _, entry in ipairs(entries) do
		if ((not entry.spec or entry.spec == specID) and (not entry.spell or (isKnown and isKnown(entry.spell)))) then
			return entry.threshold
		end
	end
	return 0
end

local threshold
local callbacks = {}

local Refresh = function()
	local previous = threshold
	threshold = Resolve()
	if (previous ~= nil and previous ~= threshold) then
		for _, callback in ipairs(callbacks) do
			callback(threshold)
		end
	end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:RegisterEvent("SPELLS_CHANGED")
listener:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
listener:RegisterEvent("TRAIT_CONFIG_UPDATED")
listener:SetScript("OnEvent", Refresh)

--[[
	API.GetExecuteThreshold()

	The player's execute threshold as a share of health (.2 for 20%), 0 without an execute.
]]
API.GetExecuteThreshold = function()
	if (threshold == nil) then
		threshold = Resolve()
	end
	return threshold
end

--[[
	API.RegisterExecuteThresholdCallback(callback)

	Calls callback(threshold) whenever a spec, talent or spell change moves the threshold.
]]
API.RegisterExecuteThresholdCallback = function(callback)
	if (type(callback) == "function") then
		callbacks[#callbacks + 1] = callback
	end
end

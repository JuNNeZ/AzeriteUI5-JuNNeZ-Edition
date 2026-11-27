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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- Lua API
local string_format = string.format

local getmodule = function()
	local module = ns:GetModule("Info", true)
	if (module and module:IsEnabled() and module.db and module.db.profile) then
		return module
	end
end

local setter = function(info,val)
	local module = getmodule()
	if (not module) then return end
	module.db.profile[info[#info]] = val
	module:UpdateSettings()
end

local getter = function(info)
	local module = getmodule()
	if (module) then return module.db.profile[info[#info]] end
end

-- The two clock switches show the opposite of what they store. The panel is
-- told, so it compares and reverts their defaults the way they read
-- (Options/Kit/Defaults.lua SetInverted; Options Navigation Review 2026-11-22, B3).
local getterReverse = function(info)
	local module = getmodule()
	return module and not module.db.profile[info[#info]] or false
end
local setterReverse = function(info, val)
	setter(info, not val)
end
if (ns.OptionsKit and ns.OptionsKit.Defaults and ns.OptionsKit.Defaults.SetInverted) then
	ns.OptionsKit.Defaults.SetInverted(getterReverse)
end

local ishidden = function()
	local module = getmodule()
	return not module or not module.db.profile.enabled
end

local GenerateOptions = function()
	-- This table survives live stops and starts from Interface Parts.
	if (not ns:GetModule("Info", true)) then return end

	local options = {
		name = L["Info Bar"],
		type = "group",
		hidden = function() return not getmodule() end,
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["These settings control the info text and clock shown in AzeriteUI's top information area."],
				fontSize = "medium"
			},
			header = {
				order = 10,
				type = "header",
				name = L["Clock Settings"]
			},
			useHalfClock = {
				name = L["24 hour mode"],
				desc = string_format(L["Enable to use a 24 hour clock, disable to show a 12 hour clock with %s/%s suffixes."], TIMEMANAGER_AM, TIMEMANAGER_PM),
				order = 20,
				type = "toggle", width = "full",
				hidden = ishidden,
				set = setterReverse,
				get = getterReverse
			},
			useServerTime = {
				name = L["Use local time"],
				desc = L["Set the clock to your computer's local time, disable to show the server time instead."],
				order = 21,
				type = "toggle", width = "full",
				hidden = ishidden,
				set = setterReverse,
				get = getterReverse
			},
			enableGreatVault = {
				name = L["Show Great Vault progress"],
				desc = L["How many Great Vault slots you have unlocked this week, left of the latency. Hover it for each row and what the next slot needs."],
				order = 30,
				type = "toggle", width = "full",
				-- Forever has no Great Vault.
				hidden = function() return not ns.IsRetailContent or ishidden() end,
				set = setter,
				get = getter
			},
			showFlightTimer = {
				name = L["Show flight timer"],
				desc = L["Show the flight master destination and elapsed time, or estimated time remaining on a route you have flown before."],
				order = 31,
				type = "toggle", width = "full",
				hidden = function()
					local module = getmodule()
					return ishidden() or not (module.CanShowFlightTimer and module:CanShowFlightTimer())
				end,
				set = setter,
				get = getter
			}
			-- TODO:
			-- Information block settings:
			-- - Text alignment
			-- - Visible elements
		}
	}

	return options
end

Options:AddGroup("Info Bar", GenerateOptions, -2950, "world", "Info")

--[[

	The MIT License (MIT)

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

-- Components/Misc/MythicPlus.lua. The module only exists on Retail, so this page
-- builds nothing on Forever.
local getmodule = function()
	local module = ns:GetModule("MythicPlus", true)
	if (module and module:IsEnabled()) then
		return module
	end
end

local setter = function(info,val)
	getmodule().db.profile[info[#info]] = val
	getmodule():UpdateSettings()
end

local getter = function(info)
	return getmodule().db.profile[info[#info]]
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Mythic+"],
		type = "group",
		args = {
			description = {
				name = L["These settings control AzeriteUI's Mythic+ timer, the card shown when a key ends, and the Font of Power."],
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			showTimer = {
				name = L["Show the key timer"],
				desc = L["A timer for the running key, with marks where the +3 and +2 upgrades run out, the time left to the next one, and your deaths."],
				order = 10,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			showForces = {
				name = L["Show enemy forces"],
				desc = L["A bar for the enemy forces counted so far."],
				order = 11,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			showCompletionCard = {
				name = L["Show the end-of-run card"],
				desc = L["When a key ends: your time, how many levels the keystone went up, your new rating, and whether it was your best time. Click it to close it."],
				order = 12,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			autoSlotKeystone = {
				name = L["Slot your keystone automatically"],
				desc = L["When you open the Font of Power, your keystone goes in by itself."],
				order = 13,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			}
		}
	}

	return options
end

Options:AddGroup("MythicPlus", GenerateOptions, -2750, "world", "MythicPlus")

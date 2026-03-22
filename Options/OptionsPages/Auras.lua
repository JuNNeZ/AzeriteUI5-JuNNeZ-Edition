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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- Lua API
local tonumber = tonumber
local tostring = tostring

local getmodule = function()
	local module = ns:GetModule("Auras", true)
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

local isdisabled = function(info)
	return info[#info] ~= "enabled" and not getmodule().db.profile.enabled
end

local getoption = function(info,option)
	return getmodule().db.profile[option]
end

local hasLegacyBlizzardAuraToggle = function()
	return not (issecretvalue or (ns.ClientVersion and ns.ClientVersion >= 120000))
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = "Aura Header Settings",
		type = "group",
		args = {
			description = {
				name = "These settings control the top-right aura header. They do not affect aura rows on unit frames like Player, Target or Party.",
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			enabled = {
				name = L["Enable"],
				desc = L["Toggle whether to show the player aura buttons or not."],
				order = 2,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			visibilityHeader = {
				name = "Show / Hide",
				order = 3,
				type = "header",
				hidden = isdisabled
			},
			visibilityDesc = {
				name = "Control when the top-right aura header is visible.",
				order = 4,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			enableAuraFading = {
				name = "Fade When Idle",
				desc = "Fade the top-right aura header when you are not interacting with it.",
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			enableModifier = {
				name = "Only Show With Modifier Key",
				desc = "Require a modifier key to reveal the top-right aura header.",
				order = 20,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			modifier = {
				name = "Required Modifier Key",
				desc = "Choose which key reveals the top-right aura header.",
				order = 21,
				hidden = isdisabled,
				disabled = function(info) return isdisabled(info) or not getoption(info, "enableModifier") end,
				type = "select", style = "dropdown",
				values = {
					["ALT"] = ALT_KEY_TEXT,
					["SHIFT"] = SHIFT_KEY_TEXT,
					["CTRL"] = CTRL_KEY_TEXT
				},
				set = setter,
				get = getter
			},
			ignoreTarget = {
				name = "Keep Visible While Targeting",
				desc = "Keep the AzeriteUI top-right aura header visible even when you have a target. Turn this off if you want the target frame to take over that screen space.",
				order = 22,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			hideBlizzardAurasOnTarget = {
				name = L["Legacy: Hide Blizzard Auras While Targeting"],
				desc = L["Older-client compatibility option for Blizzard BuffFrame visibility while targeting. This is not used on WoW 12, where Blizzard aura frames are already disabled for secure compatibility."],
				order = 23,
				type = "toggle", width = "full",
				hidden = function(info)
					return isdisabled(info) or not hasLegacyBlizzardAuraToggle()
				end,
				set = setter,
				get = getter
			},
			layoutHeader = {
				name = "Layout & Direction",
				order = 30,
				type = "header",
				hidden = isdisabled
			},
			layoutDesc = {
				name = "Adjust the anchor, growth direction and spacing of the top-right aura header.",
				order = 31,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			anchorPoint = {
				name = L["Anchor Point"],
				desc = L["Sets the anchor point."],
				order = 32,
				hidden = isdisabled,
				type = "select", style = "dropdown",
				values = {
					["TOPLEFT"] = L["Top-Left Corner"],
					["TOP"] = L["Top Center"],
					["TOPRIGHT"] = L["Top-Right Corner"],
					["RIGHT"] = L["Middle Right Side"],
					["BOTTOMRIGHT"] = L["Bottom-Right Corner"],
					["BOTTOM"] = L["Bottom Center"],
					["BOTTOMLEFT"] = L["Bottom-Left Corner"],
					["LEFT"] = L["Middle Left Side"],
					["CENTER"] = L["Center"]
				},
				set = setter,
				get = getter
			},
			anchorPointSpace = {
				name = "", order = 33, type = "description",
				hidden = isdisabled
			},
			growthX = {
				name = L["Horizontal Growth"],
				desc = L["Choose which horizontal direction the aura buttons should expand in."],
				order = 41,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["RIGHT"] = L["Right"],
					["LEFT"] = L["Left"],
				},
				set = setter,
				get = getter
			},
			growthY = {
				name = L["Vertical Growth"],
				desc = L["Choose which vertical direction the aura buttons should expand in."],
				order = 42,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["DOWN"] = L["Down"],
					["UP"] = L["Up"],
				},
				set = setter,
				get = getter
			},
			growthSpace = {
				name = "", order = 50, type = "description", hidden = isdisabled
			},
			paddingX = {
				name = L["Horizontal Padding"],
				desc = L["Sets the horizontal padding between your aura buttons."],
				order = 51,
				type = "range", width = "full", min = 0, max = 12, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			paddingY = {
				name = L["Vertical Padding"],
				desc = L["Sets the vertical padding between your aura buttons."],
				order = 52,
				type = "range", width = "full", min = 6, max = 18, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			wrapAfter = {
				name = L["Buttons Per Row"],
				desc = L["Sets the maximum number of aura buttons per row."],
				order = 53,
				type = "range", width = "full", min = 1, max = 16, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			}
		}
	}

	return options
end

Options:AddGroup("Auras", GenerateOptions, -6000)

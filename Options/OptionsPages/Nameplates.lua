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
local FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = 2.5
local FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = 0.5
local NAMEPLATE_SCALE_DEFAULT = 2
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = 1
local ENEMY_NAMEPLATE_SCALE_DEFAULT = 1
local FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = 1
local ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0.5
local MULTIPLIER_SLIDER_MIN = 50
local MULTIPLIER_SLIDER_MAX = 150
local ADDITIVE_SLIDER_MIN = 0
local ADDITIVE_SLIDER_MAX = 200

local getmodule = function()
	return ns:GetModule("NamePlates", true)
end

local setter = function(info,val)
	local module = getmodule()
	if (not module or not module.db) then return end
	module.db.profile[info[#info]] = val
	module:UpdateSettings()
end

local getter = function(info)
	local module = getmodule()
	if (not module or not module.db) then return end
	return module.db.profile[info[#info]]
end

local isdisabled = function(info)
	local module = getmodule()
	if (not module or not module.db) then return true end
	return info[#info] ~= "enabled" and not module.db.profile.enabled
end

local getoption = function(info,option)
	local module = getmodule()
	if (not module or not module.db) then return end
	return module.db.profile[option]
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Nameplate Settings"],
		type = "group",
		args = {
			enabled = {
				name = L["Enable Azerite Nameplates"],
				desc = L["Toggle whether to use Azerite nameplates or Blizzard's default nameplates."],
				order = 0,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			spacer1 = {
				name = "\n ",
				type = "description",
				fontSize = "medium",
				hidden = isdisabled,
				order = 0.5
			},
			showAuras = {
				name = L["Show Auras"],
				order = 1,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			showAurasOnTargetOnly = {
				name = L["Show Auras only on current target."],
				order = 10,
				type = "toggle", width = "full",
				hidden = function(info) return isdisabled(info) or not getoption(info,"showAuras") end,
				set = setter,
				get = getter
			},
			showNameAlways = {
				name = L["Always show unit names."],
				order = 11,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			hideFriendlyPlayerHealthBar = {
				name = "Hide friendly player healthbars (name only)",
				desc = "Friendly player nameplates only show class-colored names and hide the healthbar.",
				order = 11.5,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			friendlyNameOnlyFontScale = {
				name = "Friendly name-only font scale",
				desc = "Scale for friendly player names when name-only mode is enabled.",
				order = 11.6,
				type = "range", width = "full",
				min = MULTIPLIER_SLIDER_MIN, max = MULTIPLIER_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				disabled = function(info) return not getoption(info, "hideFriendlyPlayerHealthBar") end,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.friendlyNameOnlyFontScale = FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.friendlyNameOnlyFontScale
					if (type(scale) ~= "number") then
						scale = FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT
					end
					return math.floor((scale / FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT) * 100 + .5)
				end
			},
			friendlyNameOnlyTargetScale = {
				name = "Friendly target scale (%)",
				desc = "Additional target scale for friendly name-only plates.",
				order = 11.7,
				type = "range", width = "full",
				min = ADDITIVE_SLIDER_MIN, max = ADDITIVE_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				disabled = function(info) return not getoption(info, "hideFriendlyPlayerHealthBar") end,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.friendlyNameOnlyTargetScale = FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.friendlyNameOnlyTargetScale
					if (type(scale) ~= "number") then
						scale = FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT
					end
					return math.floor((scale / FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT) * 100 + .5)
				end
			},
			nameplateScale = {
				name = "Nameplate Scale (%)",
				desc = "Global readable scale for AzeriteUI nameplates.",
				order = 12,
				type = "range", width = "full",
				min = MULTIPLIER_SLIDER_MIN, max = MULTIPLIER_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.scale = NAMEPLATE_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.scale
					if (type(scale) ~= "number") then
						scale = NAMEPLATE_SCALE_DEFAULT
					end
					return math.floor((scale / NAMEPLATE_SCALE_DEFAULT) * 100 + .5)
				end
			},
			friendlyScale = {
				name = "Friendly/player scale (%)",
				desc = "Scale multiplier for friendly/player nameplates.",
				order = 12.05,
				type = "range", width = "full",
				min = MULTIPLIER_SLIDER_MIN, max = MULTIPLIER_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.friendlyScale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.friendlyScale
					if (type(scale) ~= "number") then
						scale = FRIENDLY_NAMEPLATE_SCALE_DEFAULT
					end
					return math.floor((scale / FRIENDLY_NAMEPLATE_SCALE_DEFAULT) * 100 + .5)
				end
			},
			enemyScale = {
				name = "Enemy scale (%)",
				desc = "Scale multiplier for hostile nameplates.",
				order = 12.06,
				type = "range", width = "full",
				min = MULTIPLIER_SLIDER_MIN, max = MULTIPLIER_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.enemyScale = ENEMY_NAMEPLATE_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.enemyScale
					if (type(scale) ~= "number") then
						scale = ENEMY_NAMEPLATE_SCALE_DEFAULT
					end
					return math.floor((scale / ENEMY_NAMEPLATE_SCALE_DEFAULT) * 100 + .5)
				end
			},
			friendlyTargetScale = {
				name = "Friendly/player target scale (%)",
				desc = "Additional target scale for friendly/player nameplates.",
				order = 12.1,
				type = "range", width = "full",
				min = ADDITIVE_SLIDER_MIN, max = ADDITIVE_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.friendlyTargetScale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT * (val / 100)
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.friendlyTargetScale
					if (type(scale) ~= "number") then
						scale = FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT
					end
					return math.floor((scale / FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT) * 100 + .5)
				end
			},
			nameplateTargetScale = {
				name = "Enemy target scale (%)",
				desc = "Additional target scale for hostile nameplates.",
				order = 12.11,
				type = "range", width = "full",
				min = ADDITIVE_SLIDER_MIN, max = ADDITIVE_SLIDER_MAX, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					local scale = ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT * (val / 100)
					module.db.profile.enemyTargetScale = scale
					module.db.profile.nameplateTargetScale = scale
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.enemyTargetScale
					if (type(scale) ~= "number") then
						scale = module.db.profile.nameplateTargetScale
					end
					if (type(scale) ~= "number") then
						scale = ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT
					end
					return math.floor((scale / ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT) * 100 + .5)
				end
			},
		}
	}

	if (ns.IsRetail) then
		options.args.showBlizzardWidgets = {
			name = L["Show Blizzard widgets"],
			order = 99,
			type = "toggle", width = "full",
			hidden = isdisabled,
			set = setter,
			get = getter
		}
	end

	return options
end

Options:AddGroup(L["Nameplates"], GenerateOptions, -7000)

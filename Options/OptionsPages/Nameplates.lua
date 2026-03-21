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
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = 1.95
local FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT = 1
local ENEMY_NAMEPLATE_SCALE_DEFAULT = .66
local FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local SCALE_SLIDER_MIN = 1
local SCALE_SLIDER_MAX = 500
local TARGET_SLIDER_MIN = 1
local TARGET_SLIDER_MAX = 500

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

local NormalizeAdditiveTargetScaleToSlider = function(scale, default)
	if (type(scale) ~= "number") then
		scale = default
	end
	return math.floor((scale - default) * 100 + 100 + .5)
end

local NormalizeSliderToAdditiveTargetScale = function(val, default)
	return default + ((val - 100) / 100)
end

local SetScaledOption = function(key, baseDefault)
	return function(info, val)
		local module = getmodule()
		if (not module or not module.db) then return end
		module.db.profile[key] = baseDefault * (val / 100)
		module:UpdateSettings()
	end
end

local GetScaledOption = function(key, baseDefault)
	return function(info)
		local module = getmodule()
		if (not module or not module.db) then return 100 end
		local scale = module.db.profile[key]
		if (type(scale) ~= "number") then
			scale = baseDefault
		end
		return math.floor((scale / baseDefault) * 100 + .5)
	end
end

local SetAdditiveTargetOption = function(key, baseDefault, compatKey)
	return function(info, val)
		local module = getmodule()
		if (not module or not module.db) then return end
		local scale = NormalizeSliderToAdditiveTargetScale(val, baseDefault)
		module.db.profile[key] = scale
		if (compatKey) then
			module.db.profile[compatKey] = scale
		end
		module:UpdateSettings()
	end
end

local GetAdditiveTargetOption = function(key, baseDefault, compatKey)
	return function(info)
		local module = getmodule()
		if (not module or not module.db) then return 100 end
		local scale = module.db.profile[key]
		if (type(scale) ~= "number" and compatKey) then
			scale = module.db.profile[compatKey]
		end
		return NormalizeAdditiveTargetScaleToSlider(scale, baseDefault)
	end
end

local GetFriendlyNameOnlyTargetOption = function()
	return function(info)
		local module = getmodule()
		if (not module or not module.db) then return 100 end
		local scale = module.db.profile.friendlyNameOnlyTargetScale
		if (type(scale) ~= "number") then
			scale = module.db.profile.friendlyTargetScale
		end
		return NormalizeAdditiveTargetScaleToSlider(scale, FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT)
	end
end

local SetFriendlyNameOnlyTargetOption = function()
	return function(info, val)
		local module = getmodule()
		if (not module or not module.db) then return end
		if (val == 100) then
			module.db.profile.friendlyNameOnlyTargetScale = false
		else
			module.db.profile.friendlyNameOnlyTargetScale = NormalizeSliderToAdditiveTargetScale(val, FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT)
		end
		module:UpdateSettings()
	end
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
			visibility = {
				name = "Visibility",
				order = 1,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					showNameAlways = {
						name = "Always show names",
						desc = "Keep unit names visible even when the plate is not hovered or targeted.",
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					showAuras = {
						name = "Show auras",
						desc = "Show buffs and debuffs on nameplates.",
						order = 2,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					showAurasOnTargetOnly = {
						name = "Only show auras on your target",
						desc = "Reduce clutter by only showing nameplate auras on your current target.",
						order = 3,
						type = "toggle", width = "full",
						disabled = function(info) return not getoption(info, "showAuras") end,
						set = setter,
						get = getter
					}
				}
			},
			size = {
				name = "Size",
				order = 2,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					useBlizzardGlobalScale = {
						name = "Use Blizzard overall scale",
						desc = "Follow Blizzard's live overall nameplate scale instead of AzeriteUI's own overall size slider.",
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					nameplateScale = {
						name = "Overall size (%)",
						desc = "The base size for AzeriteUI nameplates. `100%` is the intended default.",
						order = 2,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						disabled = function(info) return getoption(info, "useBlizzardGlobalScale") end,
						set = SetScaledOption("scale", NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("scale", NAMEPLATE_SCALE_DEFAULT)
					},
					friendlyScale = {
						name = "Friendly/player size (%)",
						desc = "The default size for friendly player nameplates. `100%` is the intended default.",
						order = 3,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("friendlyScale", FRIENDLY_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("friendlyScale", FRIENDLY_NAMEPLATE_SCALE_DEFAULT)
					},
					friendlyNPCScale = {
						name = "Friendly NPC size (%)",
						desc = "The default size for friendly NPC nameplates. `100%` is the intended default.",
						order = 4,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("friendlyNPCScale", FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("friendlyNPCScale", FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT)
					},
					enemyScale = {
						name = "Enemy size (%)",
						desc = "The default size for enemy nameplates. `100%` is the intended default.",
						order = 5,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("enemyScale", ENEMY_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("enemyScale", ENEMY_NAMEPLATE_SCALE_DEFAULT)
					},
					friendlyTargetScale = {
						name = "Friendly/player target size (%)",
						desc = "How much larger friendly NPC plates become when targeted. Friendly player name-only plates use this too unless you set a separate override below.",
						order = 6,
						type = "range", width = "full",
						min = TARGET_SLIDER_MIN, max = TARGET_SLIDER_MAX, step = 1,
						set = SetAdditiveTargetOption("friendlyTargetScale", FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT),
						get = GetAdditiveTargetOption("friendlyTargetScale", FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT)
					},
					nameplateTargetScale = {
						name = "Enemy target size (%)",
						desc = "How much larger enemy plates become when targeted. `100%` is the intended default.",
						order = 7,
						type = "range", width = "full",
						min = TARGET_SLIDER_MIN, max = TARGET_SLIDER_MAX, step = 1,
						set = SetAdditiveTargetOption("enemyTargetScale", ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT, "nameplateTargetScale"),
						get = GetAdditiveTargetOption("enemyTargetScale", ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT, "nameplateTargetScale")
					}
				}
			},
			friendlyPlayers = {
				name = "Friendly Players",
				order = 3,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					hideFriendlyPlayerHealthBar = {
						name = "Use names only for friendly players",
						desc = "Friendly player nameplates show class-colored names and hide the health bar.",
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					friendlyNameOnlyFontScale = {
						name = "Friendly name size (%)",
						desc = "Text size for friendly player name-only plates. `100%` is the intended default.",
						order = 2,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						disabled = function(info) return not getoption(info, "hideFriendlyPlayerHealthBar") end,
						set = SetScaledOption("friendlyNameOnlyFontScale", FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT),
						get = GetScaledOption("friendlyNameOnlyFontScale", FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT)
					},
					friendlyNameOnlyTargetScale = {
						name = "Friendly name target size (%)",
						desc = "Optional override for friendly player name-only plates when targeted. Set this to `100%` to follow Friendly/player target size again.",
						order = 3,
						type = "range", width = "full",
						min = TARGET_SLIDER_MIN, max = TARGET_SLIDER_MAX, step = 1,
						disabled = function(info) return not getoption(info, "hideFriendlyPlayerHealthBar") end,
						set = SetFriendlyNameOnlyTargetOption(),
						get = GetFriendlyNameOnlyTargetOption()
					}
				}
			},
			advanced = {
				name = "Advanced",
				order = 4,
				type = "group",
				inline = true,
				hidden = function(info) return isdisabled(info) or not ns.IsRetail end,
				args = {
					interruptLegend = {
						name = "Enemy castbar interrupt colors:\nGreen = primary interrupt ready\nPurple = primary unavailable, secondary ready\nRed = no tracked interrupt ready\nGray = cast cannot be interrupted",
						order = 0,
						type = "description",
						width = "full"
					}
				}
			}
		}
	}

	if (ns.IsRetail) then
		options.args.advanced.args.showBlizzardWidgets = {
			name = "Show Blizzard widgets",
			desc = "Show Blizzard's encounter and objective widgets when a plate supports them.",
			order = 1,
			type = "toggle", width = "full",
			set = setter,
			get = getter
		}
	end

	return options
end

Options:AddGroup(L["Nameplates"], GenerateOptions, -7000)

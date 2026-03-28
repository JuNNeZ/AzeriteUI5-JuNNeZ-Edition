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
local NAMEPLATE_MAX_DISTANCE_DEFAULT = 40
local FRIENDLY_NAMEPLATE_SCALE_DEFAULT = .8
local FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT = 1
local ENEMY_NAMEPLATE_SCALE_DEFAULT = .66
local FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT = 0
local ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT = .5
local SCALE_SLIDER_MIN = 1
local SCALE_SLIDER_MAX = 500
local DISTANCE_SLIDER_MIN = 20
local DISTANCE_SLIDER_MAX = 60
local CASTBAR_OFFSET_SLIDER_MIN = -30
local CASTBAR_OFFSET_SLIDER_MAX = 30
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
			credit = {
				name = L["Optimization made by Rui"],
				order = 100,
				type = "description",
				width = "full"
			},
			visibility = {
				name = L["Visibility"],
				order = 1,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					showNameAlways = {
						name = L["Always show names"],
						desc = L["Keep unit names visible even when the plate is not hovered or targeted."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					healthValuePlacement = {
						name = L["Health text placement"],
						desc = L["Choose whether nameplate health text sits below the bar, inside the bar, or only moves inside while you are in combat."],
						order = 1.5,
						type = "select", width = "full",
						values = {
							["below"] = L["Below the bar"],
							["inside"] = L["Inside the bar"],
							["inside-combat"] = L["Inside in combat"]
						},
						set = setter,
						get = function(info)
							local value = getter(info)
							if (value ~= "inside" and value ~= "inside-combat") then
								return "below"
							end
							return value
						end
					},
					showAuras = {
						name = L["Show auras"],
						desc = L["Show buffs and debuffs on nameplates."],
						order = 2,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					showAurasOnTargetOnly = {
						name = L["Only show auras on your target"],
						desc = L["Reduce clutter by only showing nameplate auras on your current target."],
						order = 3,
						type = "toggle", width = "full",
						disabled = function(info) return not getoption(info, "showAuras") end,
						set = setter,
						get = getter
					}
				}
			},
			size = {
				name = L["Size"],
				order = 2,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					useBlizzardGlobalScale = {
						name = L["Use Blizzard overall scale"],
						desc = L["Follow Blizzard's live overall nameplate scale instead of AzeriteUI's own overall size slider."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					nameplateScale = {
						name = L["Overall size (%)"],
						desc = L["The base size for AzeriteUI nameplates. `100%` is the intended default."],
						order = 2,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						disabled = function(info) return getoption(info, "useBlizzardGlobalScale") end,
						set = SetScaledOption("scale", NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("scale", NAMEPLATE_SCALE_DEFAULT)
					},
					maxDistance = {
						name = L["Maximum distance"],
						desc = L["How far away nameplates can appear. `40` matches the current Rui retail baseline."],
						order = 3,
						type = "range", width = "full",
						min = DISTANCE_SLIDER_MIN, max = DISTANCE_SLIDER_MAX, step = 1,
						set = setter,
						get = function(info)
							local module = getmodule()
							if (not module or not module.db) then return NAMEPLATE_MAX_DISTANCE_DEFAULT end
							local value = module.db.profile.maxDistance
							if (type(value) ~= "number") then
								value = NAMEPLATE_MAX_DISTANCE_DEFAULT
							end
							return value
						end
					},
					castBarOffsetY = {
						name = L["Castbar vertical offset"],
						desc = L["Moves the normal nameplate castbar up or down relative to the health bar. Positive values pull it closer."],
						order = 3.5,
						type = "range", width = "full",
						min = CASTBAR_OFFSET_SLIDER_MIN, max = CASTBAR_OFFSET_SLIDER_MAX, step = 1,
						set = setter,
						get = getter
					},
					friendlyScale = {
						name = L["Friendly/player size (%)"],
						desc = L["The default size for friendly player nameplates. `100%` is the intended default."],
						order = 4,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("friendlyScale", FRIENDLY_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("friendlyScale", FRIENDLY_NAMEPLATE_SCALE_DEFAULT)
					},
					friendlyNPCScale = {
						name = L["Friendly NPC size (%)"],
						desc = L["The default size for friendly NPC nameplates. `100%` is the intended default."],
						order = 5,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("friendlyNPCScale", FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("friendlyNPCScale", FRIENDLY_NPC_NAMEPLATE_SCALE_DEFAULT)
					},
					enemyScale = {
						name = L["Enemy size (%)"],
						desc = L["The default size for enemy nameplates. `100%` is the intended default."],
						order = 6,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						set = SetScaledOption("enemyScale", ENEMY_NAMEPLATE_SCALE_DEFAULT),
						get = GetScaledOption("enemyScale", ENEMY_NAMEPLATE_SCALE_DEFAULT)
					},
					friendlyTargetScale = {
						name = L["Friendly/player target size (%)"],
						desc = L["How much larger friendly NPC plates become when targeted. Friendly player name-only plates use this too unless you set a separate override below."],
						order = 7,
						type = "range", width = "full",
						min = TARGET_SLIDER_MIN, max = TARGET_SLIDER_MAX, step = 1,
						set = SetAdditiveTargetOption("friendlyTargetScale", FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT),
						get = GetAdditiveTargetOption("friendlyTargetScale", FRIENDLY_NAMEPLATE_TARGET_SCALE_DEFAULT)
					},
					nameplateTargetScale = {
						name = L["Enemy target size (%)"],
						desc = L["How much larger enemy plates become when targeted. `100%` is the intended default."],
						order = 8,
						type = "range", width = "full",
						min = TARGET_SLIDER_MIN, max = TARGET_SLIDER_MAX, step = 1,
						set = SetAdditiveTargetOption("enemyTargetScale", ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT, "nameplateTargetScale"),
						get = GetAdditiveTargetOption("enemyTargetScale", ENEMY_NAMEPLATE_TARGET_SCALE_DEFAULT, "nameplateTargetScale")
					}
				}
			},
			friendlyPlayers = {
				name = L["Friendly Players"],
				order = 3,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					hideFriendlyPlayerHealthBar = {
						name = L["Use names only for friendly players"],
						desc = L["Friendly player nameplates show class-colored names and hide the health bar."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					friendlyNameOnlyFontScale = {
						name = L["Friendly name size (%)"],
						desc = L["Text size for friendly player name-only plates. `100%` is the intended default."],
						order = 2,
						type = "range", width = "full",
						min = SCALE_SLIDER_MIN, max = SCALE_SLIDER_MAX, step = 1,
						disabled = function(info) return not getoption(info, "hideFriendlyPlayerHealthBar") end,
						set = SetScaledOption("friendlyNameOnlyFontScale", FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT),
						get = GetScaledOption("friendlyNameOnlyFontScale", FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT)
					},
					friendlyNameOnlyTargetScale = {
						name = L["Friendly name target size (%)"],
						desc = L["Optional override for friendly player name-only plates when targeted. Set this to `100%` to follow Friendly/player target size again."],
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
				name = L["Advanced"],
				order = 4,
				type = "group",
				inline = true,
				hidden = function(info) return isdisabled(info) or not ns.IsRetail end,
				args = {
					interruptLegend = {
						name = L["Enemy castbar interrupt colors:\nYellow = primary interrupt ready\nRed = primary interrupt unavailable\nGray = cast cannot be interrupted"],
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
			name = L["Show Blizzard widgets"],
			desc = L["Show Blizzard's encounter and objective widgets when a plate supports them."],
			order = 1,
			type = "toggle", width = "full",
			set = setter,
			get = getter
		}
	end

	return options
end

Options:AddGroup(L["Nameplates"], GenerateOptions, -7000)

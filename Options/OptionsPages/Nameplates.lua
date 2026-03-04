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

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

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
			nameplateScale = {
				name = "Nameplate Scale (%)",
				desc = "Scale AzeriteUI nameplates.",
				order = 12,
				type = "range", width = "full",
				min = 50, max = 200, step = 1,
				hidden = isdisabled,
				set = function(info, val)
					local module = getmodule()
					if (not module or not module.db) then return end
					module.db.profile.scale = val / 100
					module:UpdateSettings()
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db) then return 100 end
					local scale = module.db.profile.scale
					if (type(scale) ~= "number") then
						scale = 1
					end
					return math.floor(scale * 100 + .5)
				end
			},
			healthFlipLabHeader = {
				name = "Health Flip Lab",
				order = 20,
				type = "header",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end
			},
			healthFlipLabEnabled = {
				name = "Enable Health Flip Lab",
				order = 21,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				set = setter,
				get = getter
			},
			healthLabOrientation = {
				name = "Health Orientation Override",
				order = 22,
				type = "select",
				width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				values = {
					DEFAULT = "Default",
					RIGHT = "RIGHT",
					LEFT = "LEFT",
					UP = "UP",
					DOWN = "DOWN"
				},
				set = setter,
				get = getter
			},
			healthLabReverseFill = {
				name = "Health Reverse Fill",
				order = 23,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabFlipTexX = {
				name = "Health Flip TexCoord X",
				order = 24,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabFlipTexY = {
				name = "Health Flip TexCoord Y",
				order = 25,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabSetFlippedHorizontally = {
				name = "Health SetFlippedHorizontally",
				order = 26,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabPreviewReverseFill = {
				name = "Preview Reverse Fill",
				order = 27,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabPreviewSetFlippedHorizontally = {
				name = "Preview SetFlippedHorizontally",
				order = 28,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabAbsorbUseOppositeOrientation = {
				name = "Absorb Uses Opposite Orientation",
				order = 29,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabAbsorbReverseFill = {
				name = "Absorb Reverse Fill",
				order = 30,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabAbsorbSetFlippedHorizontally = {
				name = "Absorb SetFlippedHorizontally",
				order = 31,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabCastReverseFill = {
				name = "Cast Reverse Fill",
				order = 32,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			},
			healthLabCastSetFlippedHorizontally = {
				name = "Cast SetFlippedHorizontally",
				order = 33,
				type = "toggle", width = "full",
				hidden = function(info)
					if (isdisabled(info)) then
						return true
					end
					return not (ns and ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
				end,
				disabled = function(info) return not getoption(info, "healthFlipLabEnabled") end,
				set = setter,
				get = getter
			}
		}
	}

	if (ns.IsRetail) then
		options.args.showBlizzardWidgets = {
			name = L["Show Blizzard widgets"],
			order = 12,
			type = "toggle", width = "full",
			hidden = isdisabled,
			set = setter,
			get = getter
		}
	end

	return options
end

Options:AddGroup(L["Nameplates"], GenerateOptions, -7000)

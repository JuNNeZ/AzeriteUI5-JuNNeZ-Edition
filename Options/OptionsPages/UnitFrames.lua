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
local HasColorPicker = ns.API.IsAddOnEnabled("AzUI_Color_Picker")

local GenerateSubOptions = function(moduleName)
	local module = ns:GetModule(moduleName, true)
	if (not module or not module.db or not module.db.profile) then
		local noop = function() end
		local getnil = function() return nil end
		local alwaysDisabled = function() return true end
		return {
			type = "group",
			args = {
				enabled = {
					name = L["Enable"],
					desc = L["Toggle whether to enable this element or not."],
					order = 1,
					type = "toggle",
					width = "full",
					set = noop,
					get = getnil,
					disabled = alwaysDisabled
				}
			}
		}, nil, noop, getnil, noop, getnil, alwaysDisabled
	end

	local setter = function(info,val,noRefresh)
		if (not module or not module.db or not module.db.profile) then return end
		module.db.profile[info[#info]] = val
		if (not noRefresh) then
			module:UpdateSettings()
		end
	end
	local getter = function(info)
		if (not module or not module.db or not module.db.profile) then return end
		return module.db.profile[info[#info]]
	end
	local setoption = function(info,option,val,noRefresh)
		if (not module or not module.db or not module.db.profile) then return end
		module.db.profile[option] = val
		if (not noRefresh) then
			module:UpdateSettings()
		end
	end
	local getoption = function(info,option)
		if (not module or not module.db or not module.db.profile) then return end
		return module.db.profile[option]
	end
	local isdisabled = function(info)
		if (not module or not module.db or not module.db.profile) then return true end
		return info[#info] ~= "enabled" and not module.db.profile.enabled
	end

	local options = {
		type = "group",
		args = {
			enabled = {
				name = L["Enable"],
				desc = L["Toggle whether to enable this element or not."],
				order = 1,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			}
		}
	}

	return options, module, setter, getter, setoption, getoption, isdisabled
end

local GenerateOptions = function()
	local getmodule = function(name)
		local module = ns:GetModule(name or "UnitFrames", true)
		if (module and module.db and module.db.profile and module:IsEnabled()) then
			return module
		end
	end

	if (not getmodule()) then return end

	local setter = function(info,val) getmodule().db.profile[info[#info]] = val; getmodule():UpdateSettings() end
	local getter = function(info) return getmodule().db.profile[info[#info]] end
	local setoption = function(info,option,val) getmodule().db.profile[option] = val; getmodule():UpdateSettings() end
	local getoption = function(info,option) return getmodule().db.profile[option] end
	local isdisabled = function(info) return info[#info] ~= "enabled" and not getmodule().db.profile.enabled end

	local options = {
		name = L["UnitFrame Settings"],
		type = "group",
		childGroups = "tree",
		args = {
			disableAuraSorting = {
				name = L["Enable Aura Sorting"],
				desc = L["When enabled, unitframe auras will be sorted depending on time left and who cast the aura. When disabled, unitframe auras will appear in the order they were applied, like in the default user interface."],
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info,val) setter(info, not val) end,
				get = function(info) return not getter(info) end
			}
		}
	}

	-- Player
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerFrame")
		suboptions.hidden = function(info)
			-- If devmode isn't enabled, this doesn't apply.
			if (not ns.db.global.enableDevelopmentMode) then return end

			-- Not hidden if self is enabled.
			local playerFrame = ns:GetModule("PlayerFrame", true)
			if (playerFrame and playerFrame.db and playerFrame.db.profile and playerFrame.db.profile.enabled) then
				return
			end

			-- Hidden if self is disabled and alternate frame is enabled.
			local playerFrameAlt = ns:GetModule("PlayerFrameAlternate", true)
			if playerFrameAlt then
				if (playerFrameAlt:IsEnabled() and playerFrameAlt.db and playerFrameAlt.db.profile and playerFrameAlt.db.profile.enabled) then
					return  true
				end
			end

		end

		suboptions.args.enabled.set = function(info, val)
			if (val) then
				local playerFrameAlt = ns:GetModule("PlayerFrameAlternate", true)
				if (playerFrameAlt and playerFrameAlt.db and playerFrameAlt.db.profile) then
					playerFrameAlt.db.profile.enabled = false
					playerFrameAlt:Disable()
				end
			end
			setter(info, val)
		end

		suboptions.name = L["Player"]
		suboptions.order = 100

		if (not HasColorPicker) then
			suboptions.args.colorHeader = {
				name = L["Coloring"], order = 10, type = "header", hidden = isdisabled
			}
			suboptions.args.useClassColor = {
				name = L["Color by Class"],
				desc = L["Toggle whether to color health by player class."],
				order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
		end

		suboptions.args.elementHeader = {
			name = L["Elements"], order = 100, type = "header", hidden = isdisabled
		}
		suboptions.args.showAuras = {
			name = L["Show Auras"],
			desc = L["Toggle whether to show auras on this unit frame."],
			order = 200, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showCastbar = {
			name = L["Show Castbar"],
			desc = L["Toggle whether to show overlay castbars on this unit frame."],
			order = 300, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPowerValue = {
			name = "Show Power Text",
			desc = "Show current power text on the player power widget.",
			order = 350, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.powerValueCombatDriven = {
			name = "Show In Combat Only",
			desc = "Only show power text while you are in combat.",
			order = 350.05, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.powerValueTextScale = {
			name = "Power Text Size %",
			desc = "Resize power value text shown inside the Power Crystal and Mana Orb.",
			order = 350.075, type = "range", width = "full", min = 50, max = 200, step = 1, hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerValueTextScale", val)
			end,
			get = function(info)
				local value = getoption(info, "powerValueTextScale")
				if (type(value) ~= "number") then
					return 100
				end
				if (value < 50) then
					return 50
				end
				if (value > 200) then
					return 200
				end
				return math.floor(value + .5)
			end,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.PowerValueFormat = {
			name = "Power Text Style",
			desc = "Choose how power text is displayed.",
			order = 350.1, type = "select", width = "full", hidden = isdisabled,
			values = {
				short = "Short Number",
				full = "Full Number",
				percent = "Percent",
				shortpercent = "Short + Percent"
			},
			set = function(info, val)
				setoption(info, "PowerValueFormat", val, true)
				module:UpdateSettings()
			end,
			get = function(info)
				local value = getoption(info, "PowerValueFormat")
				if (value == nil or value == "") then
					return "short"
				end
				return value
			end,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.powerOrbMode = {
			name = "Player Power Style",
			desc = "Choose how your player power widget is shown.",
			order = 430, type = "select", width = "full", hidden = isdisabled,
			values = {
				orbV2 = "Automatic (By Class)",
				orbV2Always = "Mana Orb Only",
				legacyCrystal = "Power Crystal Only"
			},
			set = function(info, val)
				setoption(info, "powerOrbMode", val, true)
				module:UpdateSettings()
			end,
			get = function(info)
				local value = getoption(info, "powerOrbMode")
				if (value == "legacyCrystal" or value == "orbV2" or value == "orbV2Always") then
					return value
				end
				if (getoption(info, "alwaysUseCrystal")) then
					return "legacyCrystal"
				end
				if (getoption(info, "alwaysShowManaOrb")) then
					return "orbV2Always"
				end
				return "orbV2"
			end
		}
		suboptions.args.useWrathCrystal = {
			name = "Use Ice Crystal Art",
			desc = "Use the Ice Crystal artwork when Power Crystal style is active.",
			order = 450, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		local playerPowerAnchorValues = {
			FRAME = "Player Frame",
			POWER = "Power Bar",
			POWER_BACKDROP = "Power Backdrop",
			POWER_CASE = "Power Case",
			HEALTH = "Health Bar"
		}
		suboptions.args.powerPositionHeader = {
			name = "Power Widget Layout",
			order = 500,
			type = "header",
			hidden = isdisabled
		}
		suboptions.args.powerBarAnchorFrame = {
			name = "Widget Anchor",
			desc = "Choose what element the power widget is anchored to.",
			order = 501, type = "select", width = "full",
			values = playerPowerAnchorValues,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerBarAnchorFrame") or "FRAME" end
		}
		suboptions.args.powerBackdropAnchorFrame = {
			name = "Backdrop Anchor",
			desc = "Choose what element the power backdrop is anchored to.",
			order = 502, type = "select", width = "full",
			values = playerPowerAnchorValues,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerBackdropAnchorFrame") or "POWER" end
		}
		suboptions.args.powerCaseAnchorFrame = {
			name = "Frame Anchor",
			desc = "Choose what element the power frame art is anchored to.",
			order = 503, type = "select", width = "full",
			values = playerPowerAnchorValues,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerCaseAnchorFrame") or "POWER" end
		}
		suboptions.args.powerBarScaleX = {
			name = "Widget Width (%)",
			desc = "Adjust power widget width.",
			order = 505,
			type = "range",
			width = "full",
			min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerBarScaleX", val / 100)
			end,
			get = function(info)
				local scale = getoption(info, "powerBarScaleX")
				if (type(scale) ~= "number") then
					scale = getoption(info, "powerBarScale")
				end
				if (type(scale) ~= "number") then
					scale = 1
				end
				return math.floor(scale * 100 + .5)
			end
		}
		suboptions.args.powerBarScaleY = {
			name = "Widget Height (%)",
			desc = "Adjust power widget height.",
			order = 506,
			type = "range",
			width = "full",
			min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerBarScaleY", val / 100)
			end,
			get = function(info)
				local scale = getoption(info, "powerBarScaleY")
				if (type(scale) ~= "number") then
					scale = getoption(info, "powerBarScale")
				end
				if (type(scale) ~= "number") then
					scale = 1
				end
				return math.floor(scale * 100 + .5)
			end
		}
		suboptions.args.powerBarArtLayer = {
			name = "Widget Art Layer",
			desc = "Move power widget art forward/backward. Default is 0.",
			order = 507,
			type = "range",
			width = "full",
			min = -8, max = 7, step = 1,
			hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerBarArtLayer", val)
			end,
			get = function(info) return getoption(info, "powerBarArtLayer") or 0 end
		}
		suboptions.args.powerBarTexCoordAdjust = {
			name = "Crystal Crop Adjust",
			desc = "Fine-tune crystal appearance. Negative = bigger, Positive = smaller. Default is 0.",
			order = 508,
			type = "range",
			width = "full",
			min = -50, max = 50, step = 1,
			hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerBarTexCoordAdjust", val)
			end,
			get = function(info) return getoption(info, "powerBarTexCoordAdjust") or 0 end
		}
		suboptions.args.powerBackdropScaleX = {
			name = "Backdrop Width (%)",
			desc = "Adjust power backdrop width.",
			order = 508,
			type = "range",
			width = "full",
			min = 50, max = 250, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerBackdropScaleX", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerBackdropScaleX") or 1) * 100) + .5) end
		}
		suboptions.args.powerBackdropScaleY = {
			name = "Backdrop Height (%)",
			desc = "Adjust power backdrop height.",
			order = 509,
			type = "range",
			width = "full",
			min = 50, max = 250, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerBackdropScaleY", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerBackdropScaleY") or 1) * 100) + .5) end
		}
		suboptions.args.powerCaseScaleX = {
			name = "Frame Width (%)",
			desc = "Adjust power frame art width.",
			order = 509.1,
			type = "range",
			width = "full",
			min = 50, max = 250, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerCaseScaleX", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerCaseScaleX") or 1) * 100) + .5) end
		}
		suboptions.args.powerCaseScaleY = {
			name = "Frame Height (%)",
			desc = "Adjust power frame art height.",
			order = 509.2,
			type = "range",
			width = "full",
			min = 50, max = 250, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerCaseScaleY", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerCaseScaleY") or 1) * 100) + .5) end
		}
		suboptions.args.powerBarOffsetX = {
			name = "Widget X Offset",
			desc = "Move the inner power bar left or right.",
			order = 510,
			type = "range",
			width = "full",
			min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = function(info, val)
				setoption(info, "powerBarOffsetX", val)
			end,
			get = function(info) return getoption(info, "powerBarOffsetX") or 0 end
		}
		suboptions.args.powerBarOffsetY = {
			name = "Widget Y Offset",
			desc = "Move the inner power bar up or down.",
			order = 520,
			type = "range",
			width = "full",
			min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = setter,
			get = function(info) return getoption(info, "powerBarOffsetY") or 0 end
		}
		suboptions.args.powerCaseOffsetX = {
			name = "Frame X Offset",
			desc = "Move the power crystal case left or right.",
			order = 530,
			type = "range",
			width = "full",
			min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = setter,
			get = function(info) return getoption(info, "powerCaseOffsetX") or 0 end
		}
		suboptions.args.powerCaseOffsetY = {
			name = "Frame Y Offset",
			desc = "Move the power crystal case up or down.",
			order = 540,
			type = "range",
			width = "full",
			min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = setter,
			get = function(info) return getoption(info, "powerCaseOffsetY") or 0 end
		}
		suboptions.args.powerBackdropOffsetX = {
			name = "Backdrop X Offset",
			desc = "Move the power backdrop left or right.",
			order = 541,
			type = "range",
			width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled,
			set = setter,
			get = function(info) return getoption(info, "powerBackdropOffsetX") or 0 end
		}
		suboptions.args.powerBackdropOffsetY = {
			name = "Backdrop Y Offset",
			desc = "Move the power backdrop up or down.",
			order = 542,
			type = "range",
			width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled,
			set = setter,
			get = function(info) return getoption(info, "powerBackdropOffsetY") or 0 end
		}
		suboptions.args.powerThreatHeader = {
			name = "Power Threat/Glow",
			order = 545,
			type = "header",
			hidden = isdisabled
		}
		suboptions.args.powerThreatBarAnchorFrame = {
			name = "Threat Bar Anchor",
			order = 546, type = "select", width = "full",
			values = playerPowerAnchorValues,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatBarAnchorFrame") or "POWER" end
		}
		suboptions.args.powerThreatCaseAnchorFrame = {
			name = "Threat Case Anchor",
			order = 547, type = "select", width = "full",
			values = playerPowerAnchorValues,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatCaseAnchorFrame") or "POWER" end
		}
		suboptions.args.powerThreatBarOffsetX = {
			name = "Threat Bar X Offset",
			order = 548, type = "range", width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatBarOffsetX") or 0 end
		}
		suboptions.args.powerThreatBarOffsetY = {
			name = "Threat Bar Y Offset",
			order = 549, type = "range", width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatBarOffsetY") or 0 end
		}
		suboptions.args.powerThreatCaseOffsetX = {
			name = "Threat Case X Offset",
			order = 549.1, type = "range", width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatCaseOffsetX") or 0 end
		}
		suboptions.args.powerThreatCaseOffsetY = {
			name = "Threat Case Y Offset",
			order = 549.2, type = "range", width = "full",
			min = -300, max = 300, step = 1,
			hidden = isdisabled, set = setter, get = function(info) return getoption(info, "powerThreatCaseOffsetY") or 0 end
		}
		suboptions.args.powerThreatBarScaleX = {
			name = "Threat Bar Scale X (%)",
			order = 549.3, type = "range", width = "full",
			min = 50, max = 300, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerThreatBarScaleX", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerThreatBarScaleX") or 1) * 100) + .5) end
		}
		suboptions.args.powerThreatBarScaleY = {
			name = "Threat Bar Scale Y (%)",
			order = 549.4, type = "range", width = "full",
			min = 50, max = 300, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerThreatBarScaleY", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerThreatBarScaleY") or 1) * 100) + .5) end
		}
		suboptions.args.powerThreatCaseScaleX = {
			name = "Threat Case Scale X (%)",
			order = 549.5, type = "range", width = "full",
			min = 50, max = 300, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerThreatCaseScaleX", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerThreatCaseScaleX") or 1) * 100) + .5) end
		}
		suboptions.args.powerThreatCaseScaleY = {
			name = "Threat Case Scale Y (%)",
			order = 549.6, type = "range", width = "full",
			min = 50, max = 300, step = 1,
			hidden = isdisabled,
			set = function(info, val) setoption(info, "powerThreatCaseScaleY", val / 100) end,
			get = function(info) return math.floor(((getoption(info, "powerThreatCaseScaleY") or 1) * 100) + .5) end
		}
		suboptions.args.powerOffsetsReset = {
			name = "Reset Power Offsets",
			desc = "Reset player power bar/case offsets to true layout defaults.",
			order = 550,
			type = "execute",
			width = "full",
			hidden = isdisabled,
			func = function(info)
				setoption(info, "powerBarOffsetX", -76, true)
				setoption(info, "powerBarOffsetY", -49, true)
				setoption(info, "powerBackdropOffsetX", 0, true)
				setoption(info, "powerBackdropOffsetY", 0, true)
				setoption(info, "powerCaseOffsetX", 0, true)
				setoption(info, "powerCaseOffsetY", 50, true)
				setoption(info, "powerThreatBarOffsetX", 76, true)
				setoption(info, "powerThreatBarOffsetY", 52, true)
				setoption(info, "powerThreatCaseOffsetX", 0, true)
				setoption(info, "powerThreatCaseOffsetY", -34, true)
				setoption(info, "powerBarBaseOffsetX", 0, true)
				setoption(info, "powerBarBaseOffsetY", 0, true)
				setoption(info, "powerCaseBaseOffsetX", 0, true)
				setoption(info, "powerCaseBaseOffsetY", 0, true)
				setoption(info, "powerBarScale", 1, true)
				setoption(info, "powerBarScaleX", 1, true)
				setoption(info, "powerBarScaleY", 1, true)
				setoption(info, "powerBackdropScaleX", 1, true)
				setoption(info, "powerBackdropScaleY", 1, true)
				setoption(info, "powerCaseScaleX", 1, true)
				setoption(info, "powerCaseScaleY", 1, true)
				setoption(info, "powerThreatBarScaleX", 1, true)
				setoption(info, "powerThreatBarScaleY", 1, true)
				setoption(info, "powerThreatCaseScaleX", 1, true)
				setoption(info, "powerThreatCaseScaleY", 1, true)
				setoption(info, "powerBarArtLayer", 0, true)
				setoption(info, "powerBarAnchorFrame", "FRAME", true)
				setoption(info, "powerBackdropAnchorFrame", "POWER", true)
				setoption(info, "powerCaseAnchorFrame", "POWER", true)
				setoption(info, "powerThreatBarAnchorFrame", "POWER", true)
				setoption(info, "powerThreatCaseAnchorFrame", "POWER", true)
				setoption(info, "powerBarBaseScaleX", 1, true)
				setoption(info, "powerBarBaseScaleY", 1, true)
				setoption(info, "powerOffsetZeroMigrated", true, true)
				module:UpdateSettings()
			end
		}
		suboptions.args.powerOffsetsRebase = {
			name = "Save Current Position/Size as Default",
			desc = "Keep current crystal and case look, then reset position sliders to 0 and size sliders to 100%.",
			order = 560,
			type = "execute",
			width = "full",
			hidden = isdisabled,
			func = function(info)
				local barX = getoption(info, "powerBarOffsetX") or 0
				local barY = getoption(info, "powerBarOffsetY") or 0
				local caseX = getoption(info, "powerCaseOffsetX") or 0
				local caseY = getoption(info, "powerCaseOffsetY") or 0
				local scaleX = getoption(info, "powerBarScaleX")
				if (type(scaleX) ~= "number") then
					scaleX = getoption(info, "powerBarScale")
				end
				if (type(scaleX) ~= "number") then
					scaleX = 1
				end
				local scaleY = getoption(info, "powerBarScaleY")
				if (type(scaleY) ~= "number") then
					scaleY = getoption(info, "powerBarScale")
				end
				if (type(scaleY) ~= "number") then
					scaleY = 1
				end
				setoption(info, "powerBarBaseOffsetX", (getoption(info, "powerBarBaseOffsetX") or 0) + barX, true)
				setoption(info, "powerBarBaseOffsetY", (getoption(info, "powerBarBaseOffsetY") or 0) + barY, true)
				setoption(info, "powerCaseBaseOffsetX", (getoption(info, "powerCaseBaseOffsetX") or 0) + caseX, true)
				setoption(info, "powerCaseBaseOffsetY", (getoption(info, "powerCaseBaseOffsetY") or 0) + caseY, true)
				setoption(info, "powerBarBaseScaleX", (getoption(info, "powerBarBaseScaleX") or 1) * scaleX, true)
				setoption(info, "powerBarBaseScaleY", (getoption(info, "powerBarBaseScaleY") or 1) * scaleY, true)
				setoption(info, "powerBarOffsetX", 0, true)
				setoption(info, "powerBarOffsetY", 0, true)
				setoption(info, "powerCaseOffsetX", 0, true)
				setoption(info, "powerCaseOffsetY", 0, true)
				setoption(info, "powerBackdropOffsetX", 0, true)
				setoption(info, "powerBackdropOffsetY", 0, true)
				setoption(info, "powerBarOffsetX", -76, true)
				setoption(info, "powerBarOffsetY", -49, true)
				setoption(info, "powerCaseOffsetY", 50, true)
				setoption(info, "powerThreatBarOffsetX", 76, true)
				setoption(info, "powerThreatBarOffsetY", 52, true)
				setoption(info, "powerThreatCaseOffsetX", 0, true)
				setoption(info, "powerThreatCaseOffsetY", -34, true)
				setoption(info, "powerBarScale", 1, true)
				setoption(info, "powerBarScaleX", 1, true)
				setoption(info, "powerBarScaleY", 1, true)
				setoption(info, "powerBackdropScaleX", 1, true)
				setoption(info, "powerBackdropScaleY", 1, true)
				setoption(info, "powerCaseScaleX", 1, true)
				setoption(info, "powerCaseScaleY", 1, true)
				setoption(info, "powerThreatBarScaleX", 1, true)
				setoption(info, "powerThreatBarScaleY", 1, true)
				setoption(info, "powerThreatCaseScaleX", 1, true)
				setoption(info, "powerThreatCaseScaleY", 1, true)
				setoption(info, "powerOffsetZeroMigrated", true, true)
				module:UpdateSettings()
			end
		}
		options.args.player = suboptions
	end

	-- Player Alternate Version (mirrored Target)
	do
		-- This isn't always here, check for it to avoid breaking the whole addon!
		local PlayerFrameAlternate = ns:GetModule("PlayerFrameAlternate", true)
		if (PlayerFrameAlternate) then

			local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerFrameAlternate")
			if (suboptions and suboptions.args) then
			suboptions.hidden = function(info)

				-- Hidden if devmode isn't enabled.
				if (not ns.db.global.enableDevelopmentMode) then return true end

				-- Hidden if the main playerframe is enabled.
				local module = ns:GetModule("PlayerFrame", true)
				if (not module) then return end

				return module.db.profile.enabled
			end

			suboptions.args.enabled.set = function(info, val)
				if (val) then
					local playerFrame = ns:GetModule("PlayerFrame", true)
					if (playerFrame) then
						playerFrame.db.profile.enabled = false
						playerFrame:Disable()
					end
				end
				setter(info, val)
			end

			suboptions.name = "Player Alternate"
			suboptions.order = 105

			if (not HasColorPicker) then
				suboptions.args.colorHeader = {
				name = L["Coloring"], order = 10, type = "header", hidden = isdisabled
				}
				suboptions.args.useClassColor = {
					name = L["Color by Class"],
					desc = L["Toggle whether to color health by player class."],
					order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
				}
			end

			suboptions.args.elementHeader = {
				name = L["Elements"], order = 100, type = "header", hidden = isdisabled
			}
			suboptions.args.showAuras = {
				name = L["Show Auras"],
				desc = L["Toggle whether to show auras on this unit frame."],
				order = 200, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.aurasBelowFrame = {
				name = "Auras below frame",
				desc = "Toggle whether to show auras below or above the unit frame.",
				order = 210, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
				disabled = function(info) return not getoption(info, "showAuras") end
			}
			suboptions.args.showCastbar = {
				name = L["Show Castbar"],
				desc = L["Toggle whether to show overlay castbars on this unit frame."],
				order = 250, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.showName = {
				name = L["Show Unit Name"],
				desc = L["Toggle whether to show the name of the unit."],
				order = 300, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}

			options.args.playerAlternate = suboptions
			end
		end
	end

	-- Pet
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PetFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = L["Pet"]
			suboptions.order = 110
			options.args.pet = suboptions
		end
	end

	-- Target
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("TargetFrame")
		suboptions.name = L["Target"]
		suboptions.order = 120
		suboptions.args.elementHeader = {
			name = L["Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.showAuras = {
			name = L["Show Auras"],
			desc = L["Toggle whether to show auras on this unit frame."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showCastbar = {
			name = L["Show Castbar"],
			desc = L["Toggle whether to show overlay castbars on this unit frame."],
			order = 25, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showName = {
			name = L["Show Unit Name"],
			desc = L["Toggle whether to show the name of the unit."],
			order = 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPowerValue = {
			name = "Show Power Value",
			desc = "Toggle whether to show current power text on the target power bar.",
			order = 32, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.PowerValueFormat = {
			name = "Power Text Format",
			desc = "Choose how target power text is formatted.",
			order = 32.1, type = "select", width = "full", hidden = isdisabled,
			values = {
				short = "Short Number",
				full = "Full Number",
				percent = "Percent",
				shortpercent = "Short + Percent"
			},
			set = function(info, val)
				setoption(info, "PowerValueFormat", val, true)
				module:UpdateSettings()
			end,
			get = function(info)
				local value = getoption(info, "PowerValueFormat")
				if (value == nil or value == "") then
					return "short"
				end
				return value
			end,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.textureHeader = {
			name = L["Texture Variations"], order = 40, type = "header", hidden = isdisabled
		}
		suboptions.args.useStandardBossTexture = {
			name = L["Use Large Boss Texture"],
			desc = L["Toggle whether to show a larger texture for bosses."],
			order = 50, type = "toggle", width = "full", hidden = isdisabled,
			set = function(info,val) setter(info, not val) end,
			get = function(info) return not getter(info) end
		}
		suboptions.args.useStandardCritterTexture = {
			name = L["Use Small Critter Texture"],
			desc = L["Toggle whether to show a smaller texture for critters."],
			order = 60, type = "toggle", width = "full", hidden = isdisabled,
			set = function(info,val) setter(info, not val) end,
			get = function(info) return not getter(info) end
		}
		local targetPowerAnchorValues = {
			FRAME = "Unit Frame",
			POWER = "Power Bar",
			POWER_BACKDROP = "Power Backdrop",
			HEALTH = "Health Bar"
		}
		suboptions.args.powerLabHeader = {
			name = "Power Crystal Lab",
			order = 61, type = "header", hidden = isdisabled
		}
		suboptions.args.powerBarAnchorFrame = {
			name = "Power Bar Anchor",
			order = 62, type = "select", width = "full", hidden = isdisabled,
			values = targetPowerAnchorValues, set = setter, get = function(info) return getoption(info, "powerBarAnchorFrame") or "FRAME" end
		}
		suboptions.args.powerBackdropAnchorFrame = {
			name = "Power Backdrop Anchor",
			order = 63, type = "select", width = "full", hidden = isdisabled,
			values = targetPowerAnchorValues, set = setter, get = function(info) return getoption(info, "powerBackdropAnchorFrame") or "POWER" end
		}
		suboptions.args.powerValueAnchorFrame = {
			name = "Power Text Anchor",
			order = 64, type = "select", width = "full", hidden = isdisabled,
			values = targetPowerAnchorValues, set = setter, get = function(info) return getoption(info, "powerValueAnchorFrame") or "POWER" end
		}
		suboptions.args.powerBarOffsetX = {
			name = "Power Bar X Offset",
			order = 65, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBarOffsetX") or 0 end
		}
		suboptions.args.powerBarOffsetY = {
			name = "Power Bar Y Offset",
			order = 66, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBarOffsetY") or 0 end
		}
		suboptions.args.powerBackdropOffsetX = {
			name = "Power Backdrop X Offset",
			order = 67, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBackdropOffsetX") or 0 end
		}
		suboptions.args.powerBackdropOffsetY = {
			name = "Power Backdrop Y Offset",
			order = 68, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBackdropOffsetY") or 0 end
		}
		suboptions.args.powerValueOffsetX = {
			name = "Power Text X Offset",
			order = 69, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerValueOffsetX") or 0 end
		}
		suboptions.args.powerValueOffsetY = {
			name = "Power Text Y Offset",
			order = 69.1, type = "range", width = "full", min = -300, max = 300, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerValueOffsetY") or 0 end
		}
		suboptions.args.powerBarScaleX = {
			name = "Power Bar Scale X (%)",
			order = 69.2, type = "range", width = "full", min = 50, max = 250, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBarScaleX") or 100 end
		}
		suboptions.args.powerBarScaleY = {
			name = "Power Bar Scale Y (%)",
			order = 69.3, type = "range", width = "full", min = 50, max = 250, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBarScaleY") or 100 end
		}
		suboptions.args.powerBackdropScaleX = {
			name = "Power Backdrop Scale X (%)",
			order = 69.4, type = "range", width = "full", min = 50, max = 250, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBackdropScaleX") or 100 end
		}
		suboptions.args.powerBackdropScaleY = {
			name = "Power Backdrop Scale Y (%)",
			order = 69.5, type = "range", width = "full", min = 50, max = 250, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBackdropScaleY") or 100 end
		}
		suboptions.args.powerBarArtLayer = {
			name = "Power Art Layer",
			order = 69.6, type = "range", width = "full", min = -8, max = 7, step = 1, hidden = isdisabled,
			set = setter, get = function(info) return getoption(info, "powerBarArtLayer") or 0 end
		}
		local targetFakeFillHidden = function(info)
			return isdisabled(info)
		end
		local targetFakeFillDisabled = function(info)
			return isdisabled(info)
		end
		local targetLiveRefresh = function()
			module:UpdateSettings()
			local frame = module and module.frame
			if (not frame) then
				return
			end
			frame.__AzeriteUI_HealthLabSignature = nil
			if (frame.PostUpdate) then
				frame:PostUpdate()
			end
			if (frame.Health and frame.Health.ForceUpdate) then
				frame.Health:ForceUpdate()
			end
			if (frame.Castbar and frame.Castbar.ForceUpdate and frame.IsElementEnabled and frame:IsElementEnabled("Castbar")) then
				frame.Castbar:ForceUpdate()
			end
		end
		local targetLabSetter = function(info, val)
			module.db.profile[info[#info]] = val
			targetLiveRefresh()
		end
		local targetAuraConfig = ns.GetConfig("TargetFrame")
		local targetAuraSetter = function(info, val)
			module.db.profile[info[#info]] = val
			targetLiveRefresh()
		end
		local targetAuraDisabled = function(info)
			if (isdisabled(info)) then
				return true
			end
			return not getoption(info, "showAuras")
		end
		local targetAuraGrowthXValues = {
			LEFT = "LEFT",
			RIGHT = "RIGHT"
		}
		local targetAuraGrowthYValues = {
			UP = "UP",
			DOWN = "DOWN"
		}
		local targetAuraAnchorValues = {
			TOPLEFT = "TOPLEFT",
			TOP = "TOP",
			TOPRIGHT = "TOPRIGHT",
			LEFT = "LEFT",
			CENTER = "CENTER",
			RIGHT = "RIGHT",
			BOTTOMLEFT = "BOTTOMLEFT",
			BOTTOM = "BOTTOM",
			BOTTOMRIGHT = "BOTTOMRIGHT"
		}
		suboptions.args.auraLayoutHeader = {
			name = "Aura Layout",
			order = 35, type = "header", hidden = isdisabled
		}
		suboptions.args.AurasMaxCols = {
			name = "Auras Per Row",
			desc = "How many aura icons are shown on each row. Set to 0 for automatic wrapping from frame width.",
			order = 35.1, type = "range", width = "full", min = 0, max = 20, step = 1,
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			set = targetAuraSetter,
			get = function(info)
				local value = getoption(info, "AurasMaxCols")
				if (type(value) ~= "number") then
					return 0
				end
				return value
			end
		}
		suboptions.args.AuraSize = {
			name = "Aura Size",
			order = 35.2, type = "range", width = "full", min = 12, max = 80, step = 1,
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			set = targetAuraSetter,
			get = function(info)
				local value = getoption(info, "AuraSize")
				if (type(value) ~= "number") then
					return targetAuraConfig.AuraSize or 36
				end
				return value
			end
		}
		suboptions.args.AurasSpacingX = {
			name = "Aura Padding X",
			order = 35.3, type = "range", width = "full", min = -20, max = 40, step = 1,
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			set = targetAuraSetter,
			get = function(info)
				local value = getoption(info, "AurasSpacingX")
				if (type(value) ~= "number") then
					return targetAuraConfig.AurasSpacingX or targetAuraConfig.AuraSpacing or 0
				end
				return value
			end
		}
		suboptions.args.AurasSpacingY = {
			name = "Aura Padding Y",
			order = 35.4, type = "range", width = "full", min = -20, max = 40, step = 1,
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			set = targetAuraSetter,
			get = function(info)
				local value = getoption(info, "AurasSpacingY")
				if (type(value) ~= "number") then
					return targetAuraConfig.AurasSpacingY or targetAuraConfig.AuraSpacing or 0
				end
				return value
			end
		}
		suboptions.args.AurasGrowthX = {
			name = "Aura Growth X",
			order = 35.5, type = "select", width = "full",
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			values = targetAuraGrowthXValues,
			set = targetAuraSetter,
			get = function(info)
				return getoption(info, "AurasGrowthX") or targetAuraConfig.AurasGrowthX or "LEFT"
			end
		}
		suboptions.args.AurasGrowthY = {
			name = "Aura Growth Y",
			order = 35.6, type = "select", width = "full",
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			values = targetAuraGrowthYValues,
			set = targetAuraSetter,
			get = function(info)
				return getoption(info, "AurasGrowthY") or targetAuraConfig.AurasGrowthY or "DOWN"
			end
		}
		suboptions.args.AurasInitialAnchor = {
			name = "Aura Initial Anchor",
			order = 35.7, type = "select", width = "full",
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			values = targetAuraAnchorValues,
			set = targetAuraSetter,
			get = function(info)
				return getoption(info, "AurasInitialAnchor") or targetAuraConfig.AurasInitialAnchor or "TOPRIGHT"
			end
		}
		local targetAnchorValues = {
			FRAME = "Unit Frame",
			HEALTH = "Health Bar",
			HEALTH_OVERLAY = "Health Overlay",
			HEALTH_BACKDROP = "Health Backdrop Art"
		}
		suboptions.args.targetBarOffsetHeader = {
			name = "Bar Offsets",
			order = 80,
			type = "header",
			hidden = isdisabled
		}
		suboptions.args.healthBarOffsetX = {
			name = "Health X Offset",
			order = 80.1, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.healthBarOffsetY = {
			name = "Health Y Offset",
			order = 80.2, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.healthBarScaleX = {
			name = "Health Width %",
			order = 80.25, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "healthBarScaleX") or 100
			end
		}
		suboptions.args.healthBarScaleY = {
			name = "Health Height %",
			order = 80.26, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "healthBarScaleY") or 100
			end
		}
		suboptions.args.bossHealthBarOffsetX = {
			name = "Boss Health X Offset",
			order = 80.27, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.bossHealthBarOffsetY = {
			name = "Boss Health Y Offset",
			order = 80.28, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.bossHealthBarScaleX = {
			name = "Boss Health Width %",
			order = 80.29, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "bossHealthBarScaleX") or 100
			end
		}
		suboptions.args.bossHealthBarScaleY = {
			name = "Boss Health Height %",
			order = 80.295, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "bossHealthBarScaleY") or 100
			end
		}
		suboptions.args.critterHealthBarOffsetX = {
			name = "Critter Health X Offset",
			order = 80.296, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.critterHealthBarOffsetY = {
			name = "Critter Health Y Offset",
			order = 80.297, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter, get = getter
		}
		suboptions.args.critterHealthBarScaleX = {
			name = "Critter Health Width %",
			order = 80.298, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "critterHealthBarScaleX") or 100
			end
		}
		suboptions.args.critterHealthBarScaleY = {
			name = "Critter Health Height %",
			order = 80.299, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "critterHealthBarScaleY") or 100
			end
		}
		suboptions.args.castBarOffsetX = {
			name = "Cast X Offset",
			order = 80.3, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				local value = getoption(info, "castBarOffsetX")
				if (type(value) == "number") then
					return value
				end
				return getoption(info, "healthLabCastOffsetX") or 0
			end
		}
		suboptions.args.castBarOffsetY = {
			name = "Cast Y Offset",
			order = 80.4, type = "range", min = -200, max = 200, step = 1,
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				local value = getoption(info, "castBarOffsetY")
				if (type(value) == "number") then
					return value
				end
				return getoption(info, "healthLabCastOffsetY") or 0
			end
		}
		suboptions.args.castBarScaleX = {
			name = "Cast Width %",
			order = 80.35, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			disabled = function(info)
				return getoption(info, "castBarFollowHealth") and true or false
			end,
			set = targetLabSetter,
			get = function(info)
				local value = getoption(info, "castBarScaleX")
				if (type(value) == "number") then
					return value
				end
				return getoption(info, "healthLabCastWidthScale") or 100
			end
		}
		suboptions.args.castBarScaleY = {
			name = "Cast Height %",
			order = 80.36, type = "range", min = 50, max = 200, step = 1,
			hidden = isdisabled,
			disabled = function(info)
				return getoption(info, "castBarFollowHealth") and true or false
			end,
			set = targetLabSetter,
			get = function(info)
				local value = getoption(info, "castBarScaleY")
				if (type(value) == "number") then
					return value
				end
				return getoption(info, "healthLabCastHeightScale") or 100
			end
		}
		suboptions.args.castBarFollowHealth = {
			name = "Cast Follows Health",
			desc = "Make target castbar follow target health size and position, using only the cast X/Y offsets above.",
			order = 80.37, type = "toggle", width = "full",
			hidden = isdisabled,
			set = targetLabSetter,
			get = function(info)
				return getoption(info, "castBarFollowHealth") and true or false
			end
		}
		local TargetCastUsesHealthFillRules = function(info)
			local value = getoption(info, "healthLabCastUseHealthFillRules")
			if (value == nil) then
				return true
			end
			return value and true or false
		end
		suboptions.args.healthLabCastUseHealthFillRules = {
			name = "Cast Uses Health Fill Rules",
			desc = "When enabled, castbar fill direction/flip/texcoord mirrors healthbar behavior exactly.",
			order = 81.5, type = "toggle", width = "full",
			hidden = targetFakeFillHidden,
			disabled = targetFakeFillDisabled,
			set = targetLabSetter,
			get = function(info) return TargetCastUsesHealthFillRules(info) end
		}
		suboptions.args.healthLabCastAnchorFrame = {
			name = "Cast Anchor Frame",
			desc = "Choose which frame/art the castbar is anchored to for live alignment tuning.",
			order = 86,
			type = "select",
			width = "full",
			hidden = targetFakeFillHidden,
			disabled = function(info)
				if (targetFakeFillDisabled(info)) then
					return true
				end
				return getoption(info, "castBarFollowHealth") and true or false
			end,
			values = targetAnchorValues,
			set = targetLabSetter,
			get = getter
		}
		options.args.target = suboptions
	end

	-- Target of Target
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("ToTFrame")
		suboptions.name = L["Target of Target"]
		suboptions.order = 130
		suboptions.args.visibilityHeader = {
			name = L["Visibility"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.hideWhenTargetingPlayer = {
			name = L["Hide when targeting player."],
			desc = L["Makes the ToT frame transparent when its target is you."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.hideWhenTargetingSelf = {
			name = L["Hide when targeting self."],
			desc = L["Makes the ToT frame transparent when its target is itself."],
			order = 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.tot = suboptions
	end

	-- Focus Target
	if (not ns.IsClassic) then
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("FocusFrame")
		suboptions.name = L["Focus"]
		suboptions.order = 140
		options.args.focus = suboptions
	end

	-- Utility function to create group frame visibility options
	local GenerateGroupVisibilityOptions = function(offset, ...)
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = ...

		offset = offset or 50

		suboptions.args.visibilityHeader = {
			name = L["Visibility"], order = offset, type = "header", hidden = isdisabled
		}
		suboptions.args.useInParties = {
			name = "Show in Party (2-5)",
			desc = "Toggle whether to show while in a non-raid group of 2-6 members.",
			order = offset + 1, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid5 = {
			name = "Show in Raid (1-5)",
			desc = "Toggle whether to show while in a raid group of 1-5 members.",
			order = offset + 2, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid10 = {
			name = "Show in Raid (6-10)",
			desc = "Toggle whether to show while in a raid group of 1-5 members.",
			order = offset + 3, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid25 = {
			name = "Show in Raid (11-25)",
			desc = "Toggle whether to show while in a raid group of 1-5 members.",
			order = offset + 4, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid40 = {
			name = "Show in Raid (26-40)",
			desc = "Toggle whether to show while in a raid group of 1-5 members.",
			order = offset + 5, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}

		return suboptions, module, setter, getter, setoption, getoption, isdisabled
	end

	-- Party Frames
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("PartyFrames"))
		suboptions.name = L["Party Frames"]
		suboptions.order = 150
		suboptions.args.elementHeader = {
			name = L["Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.showAuras = {
			name = L["Show Auras"],
			desc = L["Toggle whether to show auras on this unit frame."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPlayer = {
			name = L["Show player"],
			desc = L["Toggle whether to show the player while in a party."],
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.party = suboptions
	end

	-- Raid Frames (5)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("RaidFrame5"))
		suboptions.name = L["Raid Frames"] .. " (5)"
		suboptions.order = 160
		suboptions.hidden = function(info)
			local party = getmodule("PartyFrames").db.profile
			return party.enabled and (party.useInRaid5 or party.useInRaid10 or party.useInRaid25 or party.useInRaid40)
		end
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid5 = suboptions
	end

	-- Raid Frames (25)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("RaidFrame25"))
		suboptions.name = L["Raid Frames"] .. " (25)"
		suboptions.order = 161
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid25 = suboptions
	end

	-- Raid Frames (40)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("RaidFrame40"))
		suboptions.name = L["Raid Frames"] .. " (40)"
		suboptions.order = 162
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid40 = suboptions
	end

	-- Boss Frames
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("BossFrames")
		suboptions.name = L["Boss Frames"]
		suboptions.order = 170
		options.args.boss = suboptions
	end

	-- Arena Enemy Frames
	if (not ns.IsClassic) then
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("ArenaFrames")
		suboptions.name = L["Arena Enemy Frames"]
		suboptions.order = 180
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.visibilityHeader = {
			name = L["Visibility"], order = 19, type = "header", hidden = isdisabled
		}
		suboptions.args.showInBattlegrounds = {
			name = L["Show in Battlegrounds"],
			desc = L["Toggle whether to show flag carrier frames in Battlegrounds."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.arena = suboptions
	end

	-- Player CastBar
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerCastBarFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = L["Cast Bar"]
			suboptions.order = 200
			options.args.castbar = suboptions
		end
	end

	-- Player ClassPower
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerClassPowerFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = function(info) 
				local mod = ns:GetModule("PlayerClassPowerFrame", true)
				return mod and mod:GetLabel() or "Class Power"
			end
			suboptions.order = 210
			suboptions.args.showComboPoints = {
				name = L["Show Combo Points"],
				desc = L["Toggle whether to show Combo Points."],
				order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			if (ns.IsCata or ns.IsRetail) then
				suboptions.args.showRunes = {
					name = L["Show Runes (Death Knight)"],
					desc = L["Toggle whether to show Death Knight Runes."],
					order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
				}
				if (ns.IsRetail) then
					suboptions.args.showSoulFragments = {
						name = L["Show Soul Fragments (Demon Hunter Devourer)"],
						desc = L["Toggle whether to show Demon Hunter Devourer Soul Fragments."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					suboptions.args.showSoulFragmentsValue = {
						name = L["Show Soul Fragments Count"],
						desc = L["Toggle whether to show the soul fragment counter (0-50) display on the 5th point. Points now display a smooth color gradient from light to dark purple, with a golden glow at 50 stacks or during Void Metamorphosis."],
						order = 11.1, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							-- Only show this option if player is Demon Hunter with Devourer spec
							if (ns.PlayerClass ~= "DEMONHUNTER") then return true end
							return false
						end
					}
					suboptions.args.soulFragmentsDisplayMode = {
						name = L["Soul Fragments Display Mode"],
						desc = L["Choose how Soul Fragments points are displayed."],
						order = 11.2, type = "select", width = "full", set = setter, get = getter,
						values = {
							["alpha"] = L["Alpha Mode (Dim 0-5, Bright 6-10)"],
							["gradient"] = L["Smooth Gradient (Light to Dark + Glow)"],
							["recolor"] = L["Two-Phase Recolor (Keep First 5, Recolor After 25)"],
							["stacked"] = L["Stacked 5-Point (Hide Empty, Bright Overflow from Bottom)"]
						},
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "DEMONHUNTER") then return true end
							return false
						end
					}
					suboptions.args.showArcaneCharges = {
						name = L["Show Arcane Charges (Mage)"],
						desc = L["Toggle whether to show Mage Arcane Charges."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					suboptions.args.showChi = {
						name = L["Show Chi (Monk)"],
						desc = L["Toggle whether to show Monk Chi."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					suboptions.args.showHolyPower = {
						name = L["Show Holy Power (Paladin)"],
						desc = L["Toggle whether to show Paladin Holy Power."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					suboptions.args.showSoulShards = {
						name = L["Show Soul Shards (Warlock)"],
						desc = L["Toggle whether to show Warlock Soul Shards."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					suboptions.args.showStagger = {
						name = L["Show Stagger (Monk)"],
						desc = L["Toggle whether to show Monk Stagger."],
						order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
					}
					-- Soul Fragments Bar Customization
					suboptions.args.soulFragmentsHeader = {
						name = "Soul Fragments Bar Adjustment (DH Devourer)",
						type = "header", order = 600
					}
					suboptions.args.soulFragmentsBarOffsetX = {
						name = "Bar Position X",
						desc = "Horizontal offset for the soul fragments bar.",
						order = 601, type = "range", min = -200, max = 200, step = 1,
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarOffsetX = val
								if mod.frame and mod.frame.ClassPower then
									mod.frame.ClassPower:ForceUpdate()
								end
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarOffsetX or 0
						end
					}
					suboptions.args.soulFragmentsBarOffsetY = {
						name = "Bar Position Y",
						desc = "Vertical offset for the soul fragments bar.",
						order = 602, type = "range", min = -200, max = 200, step = 1,
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarOffsetY = val
								if mod.frame and mod.frame.ClassPower then
									mod.frame.ClassPower:ForceUpdate()
								end
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarOffsetY or 0
						end
					}
					suboptions.args.soulFragmentsBarSizeX = {
						name = "Bar Width",
						desc = "Width of the soul fragments bar.",
						order = 603, type = "range", min = 50, max = 600, step = 1,
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarSizeX = val
								if mod.frame and mod.frame.ClassPower then
									mod.frame.ClassPower:ForceUpdate()
								end
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarSizeX or 385
						end
					}
					suboptions.args.soulFragmentsBarSizeY = {
						name = "Bar Height",
						desc = "Height of the soul fragments bar.",
						order = 604, type = "range", min = 5, max = 100, step = 1,
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarSizeY = val
								if mod.frame and mod.frame.ClassPower then
									mod.frame.ClassPower:ForceUpdate()
								end
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarSizeY or 37
						end
					}
					suboptions.args.soulFragmentsBarRotation = {
						name = "Rotation",
						desc = "Rotate the soul fragments bar texture (degrees).",
						order = 610, type = "select", values = { [0] = "0°", [90] = "90°", [180] = "180°", [270] = "270°" },
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarRotation = val
								mod:ApplyTextureCustomization()
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarRotation or 0
						end
					}
					suboptions.args.soulFragmentsBarFlipHorizontal = {
						name = "Flip Horizontal",
						desc = "Mirror the soul fragments bar texture left-to-right.",
						order = 611, type = "toggle",
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarFlipHorizontal = val
								mod:ApplyTextureCustomization()
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarFlipHorizontal or false
						end
					}
					suboptions.args.soulFragmentsBarFlipVertical = {
						name = "Flip Vertical",
						desc = "Mirror the soul fragments bar texture top-to-bottom.",
						order = 612, type = "toggle",
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarFlipVertical = val
								mod:ApplyTextureCustomization()
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarFlipVertical or false
						end
					}
					suboptions.args.soulFragmentsBarTileHorizontal = {
						name = "Tile Horizontal",
						desc = "Tile the soul fragments bar texture horizontally.",
						order = 613, type = "toggle",
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarTileHorizontal = val
								mod:ApplyTextureCustomization()
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarTileHorizontal or false
						end
					}
					suboptions.args.soulFragmentsBarTileVertical = {
						name = "Tile Vertical",
						desc = "Tile the soul fragments bar texture vertically.",
						order = 614, type = "toggle",
						set = function(info, val)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							if mod then
								mod.db.profile.soulFragmentsBarTileVertical = val
								mod:ApplyTextureCustomization()
							end
						end,
						get = function(info)
							local mod = ns:GetModule("PlayerClassPowerFrame", true)
							return mod and mod.db.profile.soulFragmentsBarTileVertical or false
						end
					}
					-- Soul Fragments Point Offsets (for 5-point system: dim for 0-5 stacks, bright for 6-10 stacks)
					for point = 1, 5 do
						local order = 700 + (point - 1) * 2
						suboptions.args["soulFragmentsPointOffsetX"..point] = {
							name = string.format("Point %d Offset X", point),
							desc = string.format("Horizontal offset for soul fragments point %d.", point),
							order = order, type = "range", min = -50, max = 50, step = 1,
							set = function(info, val)
								local mod = ns:GetModule("PlayerClassPowerFrame", true)
								if mod then
									mod.db.profile.soulFragmentsPointOffsetX[point] = val
									if mod.frame and mod.frame.ClassPower then
										mod.frame.ClassPower:ForceUpdate()
									end
								end
							end,
							get = function(info)
								local mod = ns:GetModule("PlayerClassPowerFrame", true)
								return mod and mod.db.profile.soulFragmentsPointOffsetX[point] or 0
							end
						}
						suboptions.args["soulFragmentsPointOffsetY"..point] = {
							name = string.format("Point %d Offset Y", point),
							desc = string.format("Vertical offset for soul fragments point %d.", point),
							order = order + 1, type = "range", min = -50, max = 50, step = 1,
							set = function(info, val)
								local mod = ns:GetModule("PlayerClassPowerFrame", true)
								if mod then
									mod.db.profile.soulFragmentsPointOffsetY[point] = val
									if mod.frame and mod.frame.ClassPower then
										mod.frame.ClassPower:ForceUpdate()
									end
								end
							end,
							get = function(info)
								local mod = ns:GetModule("PlayerClassPowerFrame", true)
								return mod and mod.db.profile.soulFragmentsPointOffsetY[point] or 0
							end
						}
					end
				end
			end
			options.args.classpower = suboptions
		end
	end

	return options
end

Options:AddGroup(L["Unit Frames"], GenerateOptions, -8000)


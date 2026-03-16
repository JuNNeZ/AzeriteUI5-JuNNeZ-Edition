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
			},
			powerValueAlpha = {
				name = "Power Value Alpha %",
				desc = "Set alpha for all power value text (player, mana orb, target, and alternate player frame).",
				order = 11,
				type = "range", width = "full", min = 0, max = 100, step = 1,
				hidden = isdisabled,
				set = setter,
				get = function(info)
					local value = getter(info)
					if (type(value) ~= "number") then
						return 75
					end
					if (value < 0) then
						return 0
					elseif (value > 100) then
						return 100
					end
					return math.floor(value + .5)
				end
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
					playerFrameAlt:UpdateSettings()
				end
			end
			if (val and module and module.Enable and (not module:IsEnabled())) then
				module:Enable()
			end
			setter(info, val)
		end

		suboptions.name = L["Player"]
		suboptions.order = 100


		suboptions.args.colorHeader = {
			name = L["Crystal/Orb Color"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.crystalOrbColorMode = {
			name = "Crystal/Orb Color Source",
			desc = "Choose stock AzeriteUI power colors or enhanced token-based power colors.",
			order = 20, type = "select", width = "full", hidden = isdisabled,
			values = {
				default = "Default",
				enhanced = "Enhanced Colors"
			},
			set = setter,
			get = function(info)
				local mode = getter(info)
				if (mode == "enhanced" or mode == "new" or mode == "class") then
					return "enhanced"
				end
				-- Migrate old modes (preset/custom/mana/etc) to default behavior.
				return "default"
			end
		}

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
		suboptions.args.pvpIndicatorHeader = {
			name = "PvP Badge",
			order = 500, type = "header", hidden = isdisabled
		}
		suboptions.args.pvpIndicatorOffsetX = {
			name = "PvP Badge X Offset",
			desc = "Move the player PvP badge left or right within the player frame.",
			order = 510, type = "range", width = "full", min = -300, max = 300, step = 1,
			set = setter,
			get = function(info)
				local value = getoption(info, "pvpIndicatorOffsetX")
				if (type(value) ~= "number") then
					return 0
				end
				return math.floor(value + .5)
			end,
			hidden = isdisabled
		}
		suboptions.args.pvpIndicatorOffsetY = {
			name = "PvP Badge Y Offset",
			desc = "Move the player PvP badge up or down within the player frame.",
			order = 520, type = "range", width = "full", min = -200, max = 200, step = 1,
			set = setter,
			get = function(info)
				local value = getoption(info, "pvpIndicatorOffsetY")
				if (type(value) ~= "number") then
					return 0
				end
				return math.floor(value + .5)
			end,
			hidden = isdisabled
		}
		suboptions.args.pvpIndicatorReset = {
			name = "Reset PvP Badge Position",
			desc = "Restore the player PvP badge to its centered default anchor within the player frame.",
			order = 530, type = "execute", hidden = isdisabled,
			func = function(info)
				setoption(info, "pvpIndicatorOffsetX", 0, true)
				setoption(info, "pvpIndicatorOffsetY", 0, true)
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
			end

			suboptions.args.enabled.set = function(info, val)
				if (val) then
					local playerFrame = ns:GetModule("PlayerFrame", true)
					if (playerFrame and playerFrame.db and playerFrame.db.profile) then
						playerFrame.db.profile.enabled = false
						playerFrame:UpdateSettings()
					end
				else
					local playerFrame = ns:GetModule("PlayerFrame", true)
					if (playerFrame and playerFrame.db and playerFrame.db.profile) then
						playerFrame.db.profile.enabled = true
						if (playerFrame.Enable and (not playerFrame:IsEnabled())) then
							playerFrame:Enable()
						end
						playerFrame:UpdateSettings()
					end
				end
				if (val and module and module.Enable and (not module:IsEnabled())) then
					module:Enable()
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
		suboptions.args.reverseEnemyCastChannelVisuals = {
			name = "Swap Enemy Castbar Growth",
			desc = "Swap whether hostile target castbars grow from the left or right side while keeping the same art orientation.",
			order = 27, type = "toggle", width = "full", hidden = isdisabled,
			set = setter,
			get = getter,
			disabled = function(info)
				if (isdisabled(info)) then
					return true
				end
				return not getoption(info, "showCastbar")
			end
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
		local targetAuraConfig = ns.GetConfig("TargetFrame")
		local targetAuraSetter = function(info, val)
			module.db.profile[info[#info]] = val
			module:UpdateSettings()
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
		suboptions.args.showPriorityDebuff = {
			name = "Show Big Debuff",
			desc = "Toggle whether to show the large priority debuff icon on 11-25 raid frames.",
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = "Big Debuff Size %",
			desc = "Resize the large priority debuff icon on 11-25 raid frames.",
			order = 13, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "priorityDebuffScale")
				if (type(value) ~= "number") then
					return 100
				end
				if (value < 25) then
					return 25
				elseif (value > 100) then
					return 100
				end
				return math.floor(value + .5)
			end,
			disabled = function(info) return not getoption(info, "showPriorityDebuff") end
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
		suboptions.args.showPriorityDebuff = {
			name = "Show Big Debuff",
			desc = "Toggle whether to show the large priority debuff icon on 26-40 raid frames.",
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = "Big Debuff Size %",
			desc = "Resize the large priority debuff icon on 26-40 raid frames.",
			order = 13, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "priorityDebuffScale")
				if (type(value) ~= "number") then
					return 100
				end
				if (value < 25) then
					return 25
				elseif (value > 100) then
					return 100
				end
				return math.floor(value + .5)
			end,
			disabled = function(info) return not getoption(info, "showPriorityDebuff") end
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
			local SPEC_ARCANE = _G.SPEC_MAGE_ARCANE or 1
			local SPEC_WINDWALKER = _G.SPEC_MONK_WINDWALKER or 3
			local SPEC_BREWMASTER = _G.SPEC_MONK_BREWMASTER or 1
			local SPEC_FERAL = _G.SPEC_DRUID_FERAL or 2
			local SPEC_ENHANCEMENT = _G.SPEC_SHAMAN_ENCHANCEMENT or 2
			local SPEC_ELEMENTAL = _G.SPEC_SHAMAN_ELEMENTAL or 1
			local SPEC_VENGEANCE = _G.SPEC_DEMONHUNTER_VENGEANCE or 2

			local IsSpecMatch = function(...)
				local wanted = select("#", ...)
				if (wanted == 0 or not ns.IsRetail) then
					return true
				end
				local currentSpec = (GetSpecialization and GetSpecialization()) or nil
				if (type(currentSpec) ~= "number") then
					return false
				end
				for i = 1, wanted do
					if (currentSpec == select(i, ...)) then
						return true
					end
				end
				return false
			end

			suboptions.name = function(info) 
				local mod = ns:GetModule("PlayerClassPowerFrame", true)
				return mod and mod:GetLabel() or "Class Power"
			end
			suboptions.order = 210
			suboptions.args.clickThrough = {
				name = "Class Power Click-Through",
				desc = "ON (default): clicks pass through class power to frames behind it.\nOFF: class power blocks mouse clicks in this area to prevent accidental right-click opening the player unit menu.",
				order = 120, type = "toggle", width = "full", set = setter,
				get = function(info)
					local value = getter(info)
					if (value == nil) then
						return true
					end
					return value and true or false
				end,
				hidden = isdisabled
			}
			suboptions.args.showComboPoints = {
				name = L["Show Combo Points"],
				desc = L["Toggle whether to show Combo Points."],
				order = 96, type = "toggle", width = "full", set = setter, get = getter,
				hidden = function(info)
					if (isdisabled(info)) then return true end
					if (ns.PlayerClass == "ROGUE") then
						return false
					end
					if (ns.PlayerClass == "DRUID") then
						return not IsSpecMatch(SPEC_FERAL)
					end
					return true
				end
			}
			if (ns.IsCata or ns.IsRetail) then
				suboptions.args.showRunes = {
					name = L["Show Runes (Death Knight)"],
					desc = L["Toggle whether to show Death Knight Runes."],
					order = 97, type = "toggle", width = "full", set = setter, get = getter,
					hidden = function(info)
						if (isdisabled(info)) then return true end
						return ns.PlayerClass ~= "DEATHKNIGHT"
					end
				}
				if (ns.IsRetail) then
					suboptions.args.soulFragmentsDisplayMode = {
						name = function()
							if (ns.PlayerClass == "SHAMAN") then
								return "10-Point Resource Display Mode"
							end
							return L["Soul Fragments Display Mode"]
						end,
						desc = function()
							if (ns.PlayerClass == "SHAMAN") then
								return "Choose how Maelstrom Weapon points are displayed (same model as DH 10-point behavior)."
							end
							return L["Choose how Soul Fragments points are displayed."]
						end,
						order = 95, type = "select", width = "full", set = setter, get = getter,
						values = {
							["alpha"] = L["Alpha Mode (Dim 0-5, Bright 6-10)"],
							["gradient"] = L["Smooth Gradient (Light to Dark + Glow)"],
							["recolor"] = L["Two-Phase Recolor (Keep First 5, Recolor Overflow)"],
							["stacked"] = L["Stacked 5-Point (Hide Empty, Bright Overflow from Bottom)"]
						},
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass == "DEMONHUNTER") then
								return false
							end
							if (ns.PlayerClass == "SHAMAN") then
								return not IsSpecMatch(SPEC_ENHANCEMENT)
							end
							return true
						end
					}
					suboptions.args.showArcaneCharges = {
						name = L["Show Arcane Charges (Mage)"],
						desc = L["Toggle whether to show Mage Arcane Charges."],
						order = 98, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "MAGE") then return true end
							return not IsSpecMatch(SPEC_ARCANE)
						end
					}
					suboptions.args.showChi = {
						name = L["Show Chi (Monk)"],
						desc = L["Toggle whether to show Monk Chi."],
						order = 99, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "MONK") then return true end
							return not IsSpecMatch(SPEC_WINDWALKER)
						end
					}
					suboptions.args.showHolyPower = {
						name = L["Show Holy Power (Paladin)"],
						desc = L["Toggle whether to show Paladin Holy Power."],
						order = 100, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							return ns.PlayerClass ~= "PALADIN"
						end
					}
					suboptions.args.showMaelstrom = {
						name = "Show Maelstrom Weapon (Shaman)",
						desc = "Toggle whether to show Enhancement Shaman Maelstrom Weapon class power.",
						order = 101, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "SHAMAN") then return true end
							return not IsSpecMatch(SPEC_ENHANCEMENT)
						end
					}
					suboptions.args.elementalMaelstromDisplayMode = {
						name = "Elemental Crystal/Bar Resource Split",
						desc = "Choose which resource is shown in the Power Crystal; the other is shown in the secondary bar.",
						order = 102, type = "select", width = "full", set = setter,
						values = {
							["crystal_spec"] = "Crystal: Maelstrom | Bar: Mana",
							["crystal_mana"] = "Crystal: Mana | Bar: Maelstrom"
						},
						get = function(info)
							local value = getoption(info, "elementalMaelstromDisplayMode")
							if (value == "crystal_mana" or value == "classpower") then
								return "crystal_mana"
							end
							return "crystal_spec"
						end,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "SHAMAN") then return true end
							return not IsSpecMatch(SPEC_ELEMENTAL)
						end
					}
					suboptions.args.showSoulShards = {
						name = L["Show Soul Shards (Warlock)"],
						desc = L["Toggle whether to show Warlock Soul Shards."],
						order = 103, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							return ns.PlayerClass ~= "WARLOCK"
						end
					}
					suboptions.args.showStagger = {
						name = L["Show Stagger (Monk)"],
						desc = L["Toggle whether to show Monk Stagger."],
						order = 104, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "MONK") then return true end
							return not IsSpecMatch(SPEC_BREWMASTER)
						end
					}
				end
			end
			options.args.classpower = suboptions
		end
	end

	return options
end

Options:AddGroup(L["Unit Frames"], GenerateOptions, -8000)


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
		name = L["Unit Frame Settings"],
		type = "group",
		childGroups = "tree",
		args = {
			disableAuraSorting = {
				name = L["Prioritize Unit Frame Auras"],
				desc = L["When enabled, unit-frame auras are grouped by relevance and readable timing when possible. When disabled, they stay closer to application order, like the default UI."],
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info,val) setter(info, not val) end,
				get = function(info) return not getter(info) end
			},
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
			name = L["Style"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.crystalOrbColorMode = {
			name = L["Crystal/Orb Color Source"],
			desc = L["Choose stock AzeriteUI power colors or enhanced token-based power colors."],
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
			name = L["Frame Elements"], order = 100, type = "header", hidden = isdisabled
		}
		suboptions.args.showAuras = {
			name = L["Show Auras"],
			desc = L["Toggle whether to show auras on this unit frame."],
			order = 200, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		local playerAuraSettingsDisabled = function(info)
			return isdisabled(info) or not getoption(info, "showAuras")
		end
		local playerAuraCustomSettingsDisabled = function(info)
			return playerAuraSettingsDisabled(info) or getoption(info, "playerAuraUseStockBehavior")
		end
		local playerAuraAdvancedHidden = function(info)
			return isdisabled(info) or playerAuraCustomSettingsDisabled(info) or not getoption(info, "playerAuraShowAdvancedCategories")
		end
		local playerAuraImportantChildrenDisabled = function(info)
			return playerAuraCustomSettingsDisabled(info) or not getoption(info, "playerAuraShowImportantAuras")
		end
		local playerAuraRaidChildrenDisabled = function(info)
			return playerAuraCustomSettingsDisabled(info) or not getoption(info, "playerAuraShowRaidAuras")
		end
		local playerAuraShortCombatChildrenDisabled = function(info)
			return playerAuraCustomSettingsDisabled(info) or not getoption(info, "playerAuraShowShortBuffsInCombat")
		end
		local playerAuraShortUtilityChildrenDisabled = function(info)
			return playerAuraCustomSettingsDisabled(info) or not getoption(info, "playerAuraShowShortBuffsOutOfCombat")
		end
		suboptions.args.playerAuraSettingsHeader = {
			name = L["Player Aura Row"],
			order = 210, type = "header", hidden = isdisabled
		}
		suboptions.args.playerAuraSettingsDescription = {
			name = L["These settings control the small aura row attached to the player frame. They do not affect the main top-right aura header."],
			order = 211, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.playerAuraUseStockBehavior = {
			name = L["Use AzeriteUI Stock Behavior"],
			desc = L["Use the original AzeriteUI player-frame aura behavior. Turn this off if you want to build your own filter from the custom categories below."],
			order = 211.5, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled
		}
		suboptions.args.playerAuraWhatToShowHeader = {
			name = L["What To Show"],
			order = 211.6, type = "header", hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowAdvancedCategories = {
			name = L["Show Advanced Aura Categories"],
			desc = L["Reveal the deeper sub-category toggles for custom player-frame aura filtering."],
			order = 211.7, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowDebuffs = {
			name = L["Always Show Debuffs"],
			desc = L["Show harmful effects on you. Examples: magic, poison, bleed and boss debuffs."],
			order = 212, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowImportantAuras = {
			name = L["Show Important Buffs"],
			desc = L["Show Blizzard-marked important, defensive or control-related buffs. Examples: Ice Block, Barkskin, Blessing of Sacrifice and similar externals."],
			order = 213, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowImportantDefensives = {
			name = L["Defensive Cooldowns"],
			desc = L["Examples: Ice Block, Barkskin, Survival Instincts, Shield Wall."],
			order = 213.1, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraImportantChildrenDisabled
		}
		suboptions.args.playerAuraShowImportantExternals = {
			name = L["External Defensives"],
			desc = L["Examples: Blessing of Sacrifice, Pain Suppression, Ironbark, Life Cocoon."],
			order = 213.2, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraImportantChildrenDisabled
		}
		suboptions.args.playerAuraShowImportantCrowdControl = {
			name = L["Control / Immunity-Type Auras"],
			desc = L["Examples: crowd-control immunity, anti-CC effects, and Blizzard-tagged control-related buffs."],
			order = 213.3, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraImportantChildrenDisabled
		}
		suboptions.args.playerAuraShowImportantStealable = {
			name = L["Stealable / Priority Auras"],
			desc = L["Examples: special priority buffs Blizzard marks as stealable or high-value."],
			order = 213.4, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraImportantChildrenDisabled
		}
		suboptions.args.playerAuraShowRaidAuras = {
			name = L["Show Raid-Relevant Buffs"],
			desc = L["Show raid and encounter buffs Blizzard flags as relevant. Examples: Bloodlust, Power Infusion and encounter mechanic buffs."],
			order = 214, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowRaidGeneral = {
			name = L["General Raid Buffs"],
			desc = L["Examples: Bloodlust, Power Infusion, encounter-assigned raid buffs."],
			order = 214.1, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraRaidChildrenDisabled
		}
		suboptions.args.playerAuraShowRaidCombat = {
			name = L["Raid-In-Combat Flags"],
			desc = L["Encounter or support buffs Blizzard specifically marks as relevant during combat."],
			order = 214.2, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraRaidChildrenDisabled
		}
		suboptions.args.playerAuraShowStackingAuras = {
			name = L["Show Stacking Buffs"],
			desc = L["Show buffs with visible stacks. Examples: Maelstrom Weapon, Arcane Harmony and similar stack-driven buffs."],
			order = 215, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowShortBuffsInCombat = {
			name = L["Show Short Buffs In Combat"],
			desc = L["Show short temporary combat buffs while fighting. Examples: Clearcasting, Enrage, trinket procs and short class procs."],
			order = 216, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowShortCombatPlayerBuffs = {
			name = L["Player / Self Combat Buffs"],
			desc = L["Examples: your own procs, self-applied maintenance buffs, can-apply class effects."],
			order = 216.1, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraShortCombatChildrenDisabled
		}
		suboptions.args.playerAuraShowShortCombatNonCancelable = {
			name = L["Non-Cancelable Combat Buffs"],
			desc = L["Examples: combat-relevant temporary buffs that are not simple cancelable utility effects."],
			order = 216.2, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraShortCombatChildrenDisabled
		}
		suboptions.args.playerAuraShowShortBuffsOutOfCombat = {
			name = L["Show Short Buffs Out Of Combat"],
			desc = L["Keep short temporary buffs visible before combat too. Examples: pre-pull procs and brief preparation buffs."],
			order = 217, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowShortUtilityPlayerBuffs = {
			name = L["Player / Self Temporary Buffs"],
			desc = L["Examples: self buffs with duration that matter during prep or upkeep."],
			order = 217.1, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraShortUtilityChildrenDisabled
		}
		suboptions.args.playerAuraShowShortUtilityNonCancelable = {
			name = L["Non-Cancelable Temporary Buffs"],
			desc = L["Examples: short non-cancelable buffs that should stay visible outside combat too."],
			order = 217.2, type = "toggle", width = "full", set = setter, get = getter, hidden = playerAuraAdvancedHidden,
			disabled = playerAuraShortUtilityChildrenDisabled
		}
		suboptions.args.playerAuraShowLongUtilityBuffs = {
			name = L["Show Long Utility Buffs"],
			desc = L["Also allow long-duration utility buffs in the player row. Examples: Sign of Battle, guild tabard reputation buffs and mounts. Usually leave this off so these stay in the main aura header only."],
			order = 218, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraLayoutHeader = {
			name = L["Display & Feedback"],
			order = 299, type = "header", hidden = isdisabled
		}
		suboptions.args.showCastbar = {
			name = L["Show Castbar"],
			desc = L["Toggle whether to show overlay castbars on this unit frame."],
			order = 300, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPowerValue = {
			name = L["Show Power Text"],
			desc = L["Show current power text on the player power widget."],
			order = 350, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.powerValueCombatDriven = {
			name = L["Show In Combat Only"],
			desc = L["Only show power text while you are in combat."],
			order = 350.05, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.powerValueTextScale = {
			name = L["Power Text Size %"],
			desc = L["Resize power value text shown inside the Power Crystal and Mana Orb."],
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
		suboptions.args.playerPowerValueAlpha = {
			name = L["Power Value Alpha %"],
			desc = L["Set alpha for player-side power value text, including the player frame, mana orb, and alternate player frame."],
			order = 350.08, type = "range", width = "full", min = 0, max = 100, step = 1, hidden = isdisabled,
			set = function(info, val)
				local unitFrameModule = ns:GetModule("UnitFrames", true)
				if (unitFrameModule and unitFrameModule.db and unitFrameModule.db.profile) then
					unitFrameModule.db.profile.playerPowerValueAlpha = val
				end
				module:UpdateSettings()
			end,
			get = function(info)
				local unitFrameModule = ns:GetModule("UnitFrames", true)
				local profile = unitFrameModule and unitFrameModule.db and unitFrameModule.db.profile
				local value = profile and profile.playerPowerValueAlpha
				if (type(value) ~= "number") then
					value = profile and profile.powerValueAlpha
				end
				if (type(value) ~= "number") then
					return 75
				end
				if (value < 0) then
					return 0
				elseif (value > 100) then
					return 100
				end
				return math.floor(value + .5)
			end,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.PowerValueFormat = {
			name = L["Power Text Style"],
			desc = L["Choose how power text is displayed."],
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
			name = L["Player Power Style"],
			desc = L["Choose how your player power widget is shown."],
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
			name = L["Use Ice Crystal Art"],
			desc = L["Use the Ice Crystal artwork when Power Crystal style is active."],
			order = 450, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.pvpIndicatorHeader = {
			name = L["PvP Badge"],
			order = 500, type = "header", hidden = isdisabled
		}
		suboptions.args.pvpIndicatorOffsetX = {
			name = L["PvP Badge X Offset"],
			desc = L["Move the player PvP badge left or right within the player frame."],
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
			name = L["PvP Badge Y Offset"],
			desc = L["Move the player PvP badge up or down within the player frame."],
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
			name = L["Reset PvP Badge Position"],
			desc = L["Restore the player PvP badge to its centered default anchor within the player frame."],
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

			suboptions.name = L["Player Alternate"]
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
				name = L["Auras below frame"],
				desc = L["Toggle whether to show auras below or above the unit frame."],
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
			name = L["Swap Enemy Castbar Growth"],
			desc = L["Swap whether hostile target castbars grow from the left or right side while keeping the same art orientation."],
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
			name = L["Show Power Value"],
			desc = L["Toggle whether to show current power text on the target power bar."],
			order = 32, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.PowerValueFormat = {
			name = L["Power Text Format"],
			desc = L["Choose how target power text is formatted."],
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
		suboptions.args.targetPowerValueAlpha = {
			name = L["Power Value Alpha %"],
			desc = L["Set alpha for target power value text."],
			order = 32.15, type = "range", width = "full", min = 0, max = 100, step = 1, hidden = isdisabled,
			set = function(info, val)
				local unitFrameModule = ns:GetModule("UnitFrames", true)
				if (unitFrameModule and unitFrameModule.db and unitFrameModule.db.profile) then
					unitFrameModule.db.profile.targetPowerValueAlpha = val
				end
				module:UpdateSettings()
			end,
			get = function(info)
				local unitFrameModule = ns:GetModule("UnitFrames", true)
				local profile = unitFrameModule and unitFrameModule.db and unitFrameModule.db.profile
				local value = profile and profile.targetPowerValueAlpha
				if (type(value) ~= "number") then
					value = profile and profile.powerValueAlpha
				end
				if (type(value) ~= "number") then
					return 75
				end
				if (value < 0) then
					return 0
				elseif (value > 100) then
					return 100
				end
				return math.floor(value + .5)
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
			name = L["Aura Layout"],
			order = 35, type = "header", hidden = isdisabled
		}
		suboptions.args.AurasMaxCols = {
			name = L["Auras Per Row"],
			desc = L["How many aura icons are shown on each row. Set to 0 for automatic wrapping from frame width."],
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
			name = L["Aura Size"],
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
			name = L["Aura Padding X"],
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
			name = L["Aura Padding Y"],
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
			name = L["Aura Growth X"],
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
			name = L["Aura Growth Y"],
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
			name = L["Aura Initial Anchor"],
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
		suboptions.args.visibilityDescription = {
			name = L["These toggles decide which group sizes this frame family is allowed to appear in. You can enable more than one range if you want the same frame style reused across multiple group sizes."],
			order = offset + 1, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.useInParties = {
			name = L["Show in Party (2-5)"],
			desc = L["Toggle whether to show while in a non-raid group of 2-5 members."],
			order = offset + 10, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid5 = {
			name = L["Show in Raid (1-5)"],
			desc = L["Toggle whether to show while in a raid group of 1-5 members."],
			order = offset + 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid10 = {
			name = L["Show in Raid (6-10)"],
			desc = L["Toggle whether to show while in a raid group of 6-10 members."],
			order = offset + 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid25 = {
			name = L["Show in Raid (11-25)"],
			desc = L["Toggle whether to show while in a raid group of 11-25 members."],
			order = offset + 40, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid40 = {
			name = L["Show in Raid (26-40)"],
			desc = L["Toggle whether to show while in a raid group of 26-40 members."],
			order = offset + 50, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}

		return suboptions, module, setter, getter, setoption, getoption, isdisabled
	end

	local AddHealthColorOptions = function(suboptions, setter, getter, getoption, isdisabled, config)
		local disabled = function(info)
			return isdisabled(info) or getoption(info, "useClassColors") == false
		end
		local order = config.order or 100
		local scope = config.scope or "group"
		local useClassColorsDesc
		local useBlizzardDesc
		local mouseoverDesc
		local summaryDesc

		if (scope == "party") then
			useClassColorsdesc = L["Use class and reaction colors on party health bars. Turn this off to keep them flat health green."]
			useBlizzarddesc = L["Use Blizzard's default class and reaction palette on party health bars instead of AzeriteUI's custom colors."]
			mouseoverdesc = L["Keep party health bars on flat health green until you mouse over them, then show class and reaction colors."]
			summarydesc = L["Choose whether party bars stay health green, use AzeriteUI class colors, use Blizzard class colors, or only reveal class colors on mouseover."]
		else
			local label = config.countLabel or "raid"
			useClassColorsdesc = L["Use class and reaction colors on "] .. label .. " health bars. Turn this off to keep them flat health green."
			useBlizzarddesc = L["Use Blizzard's default class and reaction colors on "] .. label .. " health bars instead of AzeriteUI's custom colors."
			mouseoverdesc = L["Keep "] .. label .. " health bars on flat health green until you mouse over them, then show class and reaction colors."
			summarydesc = L["Keep raid bars health green, switch to AzeriteUI class colors, switch to Blizzard class colors, or only reveal class colors on mouseover."]
		end

		suboptions.args.healthColorsHeader = {
			name = L["Health Colors"], order = order, type = "header", hidden = isdisabled
		}
		suboptions.args.healthColorsDescription = {
			name = summaryDesc, order = order + 1, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.useClassColors = {
			name = L["Use Class Colors"],
			desc = useClassColorsDesc,
			order = order + 10, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useBlizzardHealthColors = {
			name = L["Use Blizzard Class Colors"],
			desc = useBlizzardDesc,
			order = order + 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = disabled
		}
		suboptions.args.useClassColorOnMouseoverOnly = {
			name = L["Only Show Class Color on Mouseover"],
			desc = mouseoverDesc,
			order = order + 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = disabled
		}
	end

	-- Party Frames
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("PartyFrames"))
		local partyAuraConfig = ns.GetConfig("PartyFrames") or {}
		local partyAuraGrowthXValues = {
			LEFT = "Left",
			RIGHT = "Right"
		}
		local partyAuraGrowthYValues = {
			UP = "Up",
			DOWN = "Down"
		}
		suboptions.name = L["Party Frames"]
		suboptions.order = 150
		suboptions.args.showPlayer = {
			name = L["Show player"],
			desc = L["Toggle whether to show the player while in a party."],
			order = 2, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.elementHeader = {
			name = L["Frame Elements"], order = 10, type = "header", hidden = isdisabled
		}
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 20, scope = "party" })
		suboptions.args.showAuras = {
			name = L["Show Auras"],
			desc = L["Toggle whether to show auras on this unit frame."],
			order = 40, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		local partyAuraSettingsDisabled = function(info)
			return isdisabled(info) or not getoption(info, "showAuras")
		end
		local partyAuraCustomSettingsDisabled = function(info)
			return partyAuraSettingsDisabled(info) or getoption(info, "partyAuraUseStockBehavior")
		end
		local partyAuraLayoutDisabled = function(info)
			return partyAuraSettingsDisabled(info)
		end
		suboptions.args.partyAuraHeader = {
			name = L["Party Aura Row"],
			order = 50, type = "header", hidden = isdisabled
		}
		suboptions.args.partyAuraDescription = {
			name = L["Control which auras appear on party frames, when they appear, how they grow, and how dispellable debuffs are emphasized."],
			order = 51, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.partyAuraUseStockBehavior = {
			name = L["Use AzeriteUI Stock Behavior"],
			desc = L["Use the original AzeriteUI party-frame aura behavior. Turn this off if you want to build your own filter from the custom categories below."],
			order = 60, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraSettingsDisabled
		}
		suboptions.args.partyAuraWhatToShowHeader = {
			name = L["What To Show"],
			order = 61, type = "header", hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowDispellableDebuffs = {
			name = L["Show Dispellable Debuffs"],
			desc = L["Show debuffs you can remove from party members. Examples: Magic, Curse, Disease and Poison effects your class/spec can dispel."],
			order = 110, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraOnlyDispellableDebuffs = {
			name = L["Only Show Dispellable Debuffs"],
			desc = L["Hide non-dispellable harmful auras from the party aura row unless they are boss or important mechanics."],
			order = 120, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowBossAndImportantDebuffs = {
			name = L["Show Boss and Important Debuffs"],
			desc = L["Keep encounter-critical or Blizzard-marked important debuffs visible even if they are not dispellable."],
			order = 130, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowOtherDebuffs = {
			name = L["Show Other Short Debuffs"],
			desc = L["Show other short harmful effects that are likely relevant in combat, even if they are not dispellable."],
			order = 140, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowHelpfulExternals = {
			name = L["Show Helpful Externals"],
			desc = L["Show helpful externals and defensive cooldowns on party members. Examples: Blessing of Sacrifice, Ironbark and Pain Suppression."],
			order = 150, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowHelpfulRaidBuffs = {
			name = L["Show Helpful Raid Buffs"],
			desc = L["Show raid-relevant or Blizzard-flagged helpful buffs on party members."],
			order = 160, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowHelpfulShortBuffs = {
			name = L["Show Short Helpful Buffs"],
			desc = L["Show short player-applied buffs with duration or stacks. Examples: Renewing Mist, Earth Shield-style maintenance buffs, and similar short upkeep effects."],
			order = 170, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraLayoutHeader = {
			name = L["Layout & Highlighting"],
			order = 180, type = "header", hidden = isdisabled
		}
		suboptions.args.partyAuraLayoutDescription = {
			name = L["Adjust the size and growth of party-frame auras, and how removable debuffs are emphasized."],
			order = 181, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.AuraSize = {
			name = L["Aura Size"],
			desc = L["Resize party aura buttons."],
			order = 190, type = "range", width = "full", min = 18, max = 42, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "AuraSize")
				if (type(value) ~= "number") then
					return partyAuraConfig.AuraSize or 30
				end
				return math.floor(value + .5)
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.partyAuraDebuffScale = {
			name = L["Debuff Size %"],
			desc = L["Scale harmful party auras relative to normal buffs. Use this if you want dispellable debuffs to stand out more."],
			order = 200, type = "range", width = "full", min = 75, max = 150, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "partyAuraDebuffScale")
				if (type(value) ~= "number") then
					return 100
				end
				if (value < 75) then
					return 75
				elseif (value > 150) then
					return 150
				end
				return math.floor(value + .5)
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.AurasGrowthX = {
			name = L["Aura Growth X"],
			desc = L["Choose whether party auras grow left or right."],
			order = 210, type = "select", width = "full", hidden = isdisabled,
			values = partyAuraGrowthXValues,
			set = setter,
			get = function(info)
				return getoption(info, "AurasGrowthX") or partyAuraConfig.AurasGrowthX or "RIGHT"
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.AurasGrowthY = {
			name = L["Aura Growth Y"],
			desc = L["Choose whether party auras grow up or down."],
			order = 220, type = "select", width = "full", hidden = isdisabled,
			values = partyAuraGrowthYValues,
			set = setter,
			get = function(info)
				return getoption(info, "AurasGrowthY") or partyAuraConfig.AurasGrowthY or "DOWN"
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.partyAuraGlowDispellableDebuffs = {
			name = L["Glow Frame For Dispellable Debuffs"],
			desc = L["Highlight the affected party frame using the debuff type color when a removable debuff is active."],
			order = 230, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraLayoutDisabled
		}
		options.args.party = suboptions
	end

	-- Raid Frames (5)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("RaidFrame5"))
		suboptions.name = L["Raid Frames"] .. " (5)"
		suboptions.order = 160
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 10, scope = "raid", countLabel = "1-5 raid health bars" })
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 50, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid5 = suboptions
	end

	-- Raid Frames (25)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(50, GenerateSubOptions("RaidFrame25"))
		suboptions.name = L["Raid Frames"] .. " (25)"
		suboptions.order = 161
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 10, scope = "raid", countLabel = "6-25 raid health bars" })
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 50, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPriorityDebuff = {
			name = L["Show Big Debuff"],
			desc = L["Toggle whether to show the large priority debuff icon on 11-25 raid frames."],
			order = 60, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = L["Big Debuff Size %"],
			desc = L["Resize the large priority debuff icon on 11-25 raid frames."],
			order = 70, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
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
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 10, scope = "raid", countLabel = "26-40 raid health bars" })
		suboptions.args.useRangeIndicator = {
			name = L["Use Range Indicator"],
			desc = L["Toggle whether to fade unit frames of units that are out of range."],
			order = 50, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPriorityDebuff = {
			name = L["Show Big Debuff"],
			desc = L["Toggle whether to show the large priority debuff icon on 26-40 raid frames."],
			order = 60, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = L["Big Debuff Size %"],
			desc = L["Resize the large priority debuff icon on 26-40 raid frames."],
			order = 70, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
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
				name = L["Class Power Click-Through"],
				desc = L["ON (default): clicks pass through class power to frames behind it.\nOFF: class power blocks mouse clicks in this area to prevent accidental right-click opening the player unit menu."],
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
						name = L["Show Maelstrom Weapon (Shaman)"],
						desc = L["Toggle whether to show Enhancement Shaman Maelstrom Weapon class power."],
						order = 101, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "SHAMAN") then return true end
							return not IsSpecMatch(SPEC_ENHANCEMENT)
						end
					}
					suboptions.args.elementalMaelstromDisplayMode = {
						name = L["Elemental Crystal/Bar Resource Split"],
						desc = L["Choose which resource is shown in the Power Crystal; the other is shown in the secondary bar."],
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


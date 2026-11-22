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

-- Settings that may change in combat skip the options queue (Options/Kit/Combat.lua).
local Immediate = function(option)
	local Kit = ns.OptionsKit
	if (Kit and Kit.Combat) then Kit.Combat:AllowImmediate(option) end
	return option
end

-- Why a greyed-out row is greyed out: a string, or function(info) returning one.
-- Kept beside the option like Immediate, because AceConfigRegistry refuses
-- unknown keys (Options/Kit/Config.lua SetDisabledDesc). FixLog 2026-11-13.
local DisabledDesc = function(option, reason)
	local Kit = ns.OptionsKit
	if (option and Kit and Kit.Config and Kit.Config.SetDisabledDesc) then
		Kit.Config.SetDisabledDesc(option, reason)
	end
	return option
end
-- A switch that shows the opposite of what it stores: the panel then compares
-- and reverts its default the way it reads (Options/Kit/Defaults.lua
-- SetInverted). Without it the default showed as changed, and Revert saved the
-- opposite (Docs/Options Navigation Review - 2026-11-22.md, B3).
local Inverted = function(get)
	local Kit = ns.OptionsKit
	if (Kit and Kit.Defaults and Kit.Defaults.SetInverted) then Kit.Defaults.SetInverted(get) end
	return get
end
local IsOnReason = function(name) return string.format(L["Unavailable while \"%s\" is on."], name) end
local IsOffReason = function(name) return string.format(L["Unavailable while \"%s\" is off."], name) end

local Options = ns:GetModule("Options")
local HasColorPicker = ns.API.IsAddOnEnabled("AzUI_Color_Picker")

-- The Legacy HUD (Core/LegacyHUD.lua) draws the player power as a flat bar and the
-- player frames without portraits, so settings that only reach the orb, the crystal
-- art or the portrait do nothing there. Same check as ActionBars.lua's ShapeOption.
local IsLegacyHUD = function()
	return (ns.LegacyHUD and ns.LegacyHUD:IsActive()) and true or false
end

-- Player, Player Alternate and Player (Party Style) take the same place: one at a time.
-- All three pages stay listed; an inactive one shows only its switch (isdisabled).
local PLAYER_FRAME_MODULES = { "PlayerFrame", "PlayerFrameAlternate", "PlayerFrameParty" }
local UsePlayerFrame = function(chosen)
	for _, name in ipairs(PLAYER_FRAME_MODULES) do
		local module = ns:GetModule(name, true)
		if (module and module.db and module.db.profile) then
			local on = (name == chosen)
			module.db.profile.enabled = on
			if (on and module.Enable and not module:IsEnabled()) then
				module:Enable()
			end
			if (module.frame) then
				module:UpdateSettings()
			end
		end
	end
end

-- WoW API
-- GetSpecialization is deprecated in favour of C_SpecializationInfo.GetSpecialization.
-- Shadowed as a file local so every call site below, and the type() guards around
-- them, keep working whichever of the two the client still exposes.
local GetSpecialization = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization

local GenerateSubOptions = function(moduleName)
	local module = ns:GetModule(moduleName, true)
	if (not module or not module.db or not module.db.profile) then
		local noop = function() end
		local getnil = function() return nil end
		local alwaysDisabled = function() return true end
		return {
			type = "group",
			hidden = true, -- The module is unavailable on this client.
			args = {
				enabled = {
					name = L["Enable"],
					desc = L["Turn this part of AzeriteUI on or off."],
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
				desc = L["Turn this part of AzeriteUI on or off."],
				order = 1,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			}
		}
	}


	-- Every setting in this group reads and writes that module's profile, which
	-- is what lets the panel mark the ones that differ from their defaults.
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, moduleName)
	end
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
		name = L["Unit Frames"],
		type = "group",
		childGroups = "tree",
		args = {
			disableAuraSorting = {
				name = L["Prioritize unit frame auras"],
				desc = L["When enabled, unit-frame auras are grouped by relevance and readable timing when possible. When disabled, they stay closer to application order, like the default UI."],
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info,val) setter(info, not val) end,
				get = Inverted(function(info) return not getter(info) end)
			},
			showBlizzardRaidBar = {
				name = L["Show Blizzard raid bar"],
				desc = L["Show the Blizzard raid utility bar with ready check and ground/world marker buttons. If the bar was already hidden earlier this session, use /reload after enabling it."],
				order = 20,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info, val)
					getmodule().db.profile.showBlizzardRaidBar = val
					getmodule():UpdateSettings()
					if ns and ns.WoW12BlizzardQuarantine and ns.WoW12BlizzardQuarantine.SetBlizzardRaidBarVisible and ns.WoW12BlizzardQuarantine.ShouldShowBlizzardRaidBar then
						if val then
							ns.WoW12BlizzardQuarantine.SetBlizzardRaidBarVisible(ns.WoW12BlizzardQuarantine.ShouldShowBlizzardRaidBar())
						else
							ns.WoW12BlizzardQuarantine.SetBlizzardRaidBarVisible(false)
						end
					end
				end,
				get = function(info)
					return getmodule().db.profile.showBlizzardRaidBar
				end
			},
			colorCastSpellTextByState = {
				name = L["Color cast spell text by state"],
				desc = L["Tint supported cast spell names by interrupt/protected state. Disable to keep spell names on their normal text color."],
				order = 30,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			-- Built into each native aura button when it is created, so the change asks
			-- for a reload. Both clients: Forever has the native aura rows too (ns.IsRetail is the engine,
			-- true there; Blizzard_AuraContainer's SetDurationText and C_CurveUtil exist on Forever).
			auraTimerColors = {
				name = L["Color aura timers"],
				desc = L["Aura countdowns on unit frames and nameplates turn yellow, orange and red as they run out. Turn this off to keep them white."],
				order = 40,
				type = "toggle", width = "full",
				hidden = function(info) return (not ns.IsRetail) or isdisabled(info) end,
				confirm = function() return L["Changing this reloads the interface."] end,
				set = function(info, val)
					getmodule().db.profile.auraTimerColors = val and true or false
					ReloadUI()
				end,
				get = function(info) return getmodule().db.profile.auraTimerColors ~= false end
			},
			showCombatFeedback = {
				name = L["Show combat text"],
				desc = L["Hits, heals and misses flash as numbers on the player, target, group, arena and boss frames."],
				-- The page's own rows stay above every section (healthPrediction is 50, units 100+);
				-- after one they read as part of it (Options Navigation Review 2026-11-22, B7).
				order = 41,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = function(info) return getmodule().db.profile.showCombatFeedback ~= false end
			},
			-- Engine-eased bars (UnitFrame.lua ns.UnitFrame.SetSmoothingEnabled). Only the
			-- interpolation argument changes, so both apply at once, in combat too.
			smoothBars = Immediate({
				name = L["Smooth health and power"],
				desc = L["Health and power bars glide to each new value instead of jumping. A new target or group member still shows at once."],
				order = 42,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info, val) if (ns.UnitFrame) then ns.UnitFrame.SetSmoothingEnabled("bars", val) end end,
				get = function(info) return ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled("bars") or false end
			}),
			smoothCastbars = Immediate({
				name = L["Smooth castbar pushback"],
				desc = L["When a cast is pushed back, the bar slides to its new place instead of jumping. A new cast always starts at once."],
				order = 43,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info, val) if (ns.UnitFrame) then ns.UnitFrame.SetSmoothingEnabled("castbars", val) end end,
				get = function(info) return ns.UnitFrame and ns.UnitFrame.IsSmoothingEnabled("castbars") or false end
			})
		}
	}

	-- Player
	options.args.healthPrediction = Options:GenerateHealthPredictionOptions()
	options.args.groupIndicators = Options:GenerateGroupIndicatorsOptions()

	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerFrame")

		-- On turns the other two player frames off; off leaves no player frame.
		suboptions.args.enabled.set = function(info, val)
			if (val) then
				UsePlayerFrame("PlayerFrame")
			else
				setter(info, val)
			end
		end

		suboptions.name = L["Player"]
		suboptions.order = 100

		-- Legacy shows neither the orb (LegacyHUD.lua sets its alpha to 0) nor the Ice
		-- Crystal (Player.lua UsePlayerIceCrystal), and its power widget ignores the
		-- style choice (Player.lua ResolvePlayerPowerWidgetVisibility).
		local hiddenUnderLegacy = function(info)
			return IsLegacyHUD() or isdisabled(info)
		end

		suboptions.args.colorHeader = {
			name = L["Crystal & Mana Orb"], order = 100, type = "header", hidden = isdisabled
		}
		suboptions.args.crystalOrbColorMode = {
			name = L["Crystal/orb color source"],
			desc = function()
				if (ns.PaladinTheme and ns.PaladinTheme:IsActive()) then
					return L["Choose the color of the power crystal and mana orb. Light colored uses golden Light."]
				end
				return L["Choose stock AzeriteUI power colors, enhanced token-based power colors, or your class color."]
			end,
			order = 120, type = "select", width = "full", hidden = isdisabled,
			values = function()
				local values = {
					default = L["Default"],
					enhanced = L["Enhanced colors"],
					classColor = L["Class color"]
				}
				if (ns.PaladinTheme and ns.PaladinTheme:IsActive()) then values.light = L["Light colored"] end
				return values
			end,
			set = setter,
			get = function(info)
				local mode = getter(info)
				if (mode == "light" and ns.PaladinTheme and ns.PaladinTheme:IsActive()) then return "light" end
				if (mode == "classColor" or mode == "class") then
					return "classColor"
				end
				if (mode == "enhanced" or mode == "new") then
					return "enhanced"
				end
				-- Migrate old modes (preset/custom/mana/etc) to default behavior.
				return "default"
			end
		}
		suboptions.args.flowingMana = {
			name = L["Flowing mana"],
			desc = L["Add gentle waves to the selected orb material and theme or Lite+ effects while the orb shows mana. Keeps your selected resource color."],
			order = 145, type = "toggle", width = "full", set = setter, get = getter, hidden = hiddenUnderLegacy
		}
		suboptions.args.legacyCenterWithoutTarget = {
			name = L["Center without a target"],
			desc = L["Legacy HUD: move the player frame to the middle of the screen while you have no target, and back beside the target frame when you pick one. It slides out of combat and jumps in combat."],
			order = 30, type = "toggle", width = "full", set = setter, get = getter,
			hidden = function(info)
				return isdisabled(info) or not (ns.LegacyHUD and ns.LegacyHUD:IsActive())
			end
		}

		suboptions.args.elementHeader = {
			name = L["General"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.showAuras = {
			name = L["Show auras"],
			desc = L["Show buffs and debuffs on this unit frame."],
			order = 302, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		local playerAuraSettingsDisabled = function(info)
			return isdisabled(info) or not getoption(info, "showAuras")
		end
		local playerAuraCustomSettingsDisabled = function(info)
			return playerAuraSettingsDisabled(info)
				or getoption(info, "playerAuraUseStockBehavior")
				or getoption(info, "playerAuraDebuffsOnly")
		end
		suboptions.args.playerAuraSettingsHeader = {
			name = L["Player Aura Row"],
			order = 300, type = "header", hidden = isdisabled
		}
		suboptions.args.playerAuraSettingsDescription = {
			name = L["These settings control the Blizzard-managed Retail aura row attached to the player frame. Custom categories use only native Retail 12.1 filters that remain safe in combat; the main top-right aura header is unaffected."],
			order = 301, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.playerAuraUseStockBehavior = {
			name = L["Use AzeriteUI stock behavior"],
			desc = L["Use AzeriteUI's default player-row filtering and mixed bright/dim aura styling. Turn this off if you want to build your own filter from the custom categories below."],
			order = 303, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled
		}
		suboptions.args.playerAuraDebuffsOnly = {
			name = L["Show debuffs only"],
			desc = L["Hide helpful effects from the attached player aura row and show only harmful effects on you."],
			order = 304, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled
		}
		suboptions.args.playerAuraAlwaysBright = {
			name = L["Always show full brightness"],
			desc = L["Render all visible player-row aura icons at full brightness. Use this if you prefer no dimmed aura icons."],
			order = 362, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled
		}
		-- Weapon enchants are not auras, so none of the buff categories below can include them.
		suboptions.args.playerAuraShowWeaponEnchants = {
			name = L["Show weapon enchants"],
			desc = L["Show temporary weapon enchants, such as Shaman imbues, poisons and oils, in the attached player aura row."],
			order = 321, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info)
				return playerAuraSettingsDisabled(info) or getoption(info, "playerAuraDebuffsOnly")
			end
		}
		suboptions.args.playerAuraWhatToShowHeader = {
			name = L["Buffs"],
			order = 320, type = "header", hidden = isdisabled
		}
		suboptions.args.playerAuraDebuffsHeader = {
			name = L["Debuffs"], order = 340, type = "header", hidden = isdisabled
		}
		suboptions.args.playerAuraShowDebuffs = {
			name = L["Show debuffs"],
			desc = L["Include harmful effects in the attached row when Show Debuffs Only and Separate Player Debuff Row are disabled."],
			order = 341, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info)
				return playerAuraSettingsDisabled(info) or getoption(info, "playerAuraDebuffsOnly") or getoption(info, "playerAuraSeparateDebuffs")
			end
		}
		suboptions.args.playerAuraShowImportantAuras = {
			name = L["Show important buffs"],
			desc = L["Show buffs from AzeriteUI's maintained priority spell list."],
			order = 322, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowRaidAuras = {
			name = L["Show raid-relevant buffs"],
			desc = L["Show buffs Blizzard marks as boss or role auras."],
			order = 323, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowImportantStealable = {
			name = L["Stealable buffs"],
			desc = L["Show helpful effects Blizzard marks as stealable."],
			order = 324, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowShortCombatPlayerBuffs = {
			name = L["Player / self buffs"],
			desc = L["Show personal combat auras and remaining temporary buffs cast by you or your pet."],
			order = 325, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowNameplateAuras = {
			name = L["Nameplate-highlighted buffs"],
			desc = L["Show helpful effects Blizzard also marks for nameplate display."],
			order = 326, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraShowShortBuffsInCombat = {
			name = L["Other temporary buffs"],
			desc = L["Show remaining temporary buffs from other sources. This native duration filter stays consistent in and out of combat."],
			order = 327, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraCustomSettingsDisabled
		}
		suboptions.args.playerAuraMaxDuration = {
			name = L["Maximum temporary duration"],
			desc = L["Set the maximum original duration for the remaining temporary-buff group."],
			order = 329, type = "range", width = "full", min = 30, max = 3600, step = 30, hidden = isdisabled,
			disabled = function(info)
				return playerAuraCustomSettingsDisabled(info)
					or getoption(info, "playerAuraShowLongUtilityBuffs")
					or (not getoption(info, "playerAuraShowShortCombatPlayerBuffs") and not getoption(info, "playerAuraShowShortBuffsInCombat"))
			end,
			set = function(info, val)
				setoption(info, "playerAuraMaxDuration", val)
			end,
			get = function(info)
				local value = getoption(info, "playerAuraMaxDuration")
				if (type(value) ~= "number") then
					return 300
				end
				if (value < 30) then
					return 30
				elseif (value > 3600) then
					return 3600
				end
				return math.floor(value / 30 + .5) * 30
			end
		}
		suboptions.args.playerAuraShowLongUtilityBuffs = {
			name = L["Show long utility buffs"],
			desc = L["Extend the temporary-buff group to include long-duration and permanent utility buffs. Usually leave this off so those remain in the main aura header only."],
			order = 328, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info)
				return playerAuraCustomSettingsDisabled(info)
					or (not getoption(info, "playerAuraShowShortCombatPlayerBuffs") and not getoption(info, "playerAuraShowShortBuffsInCombat"))
			end
		}
		suboptions.args.playerAuraLayoutHeader = {
			name = L["Aura Layout"],
			order = 360, type = "header", hidden = isdisabled
		}
		suboptions.args.playerAuraMaxShown = {
			name = L["Auras shown"],
			desc = L["Set the maximum number of slots in the attached player aura row. When buffs and debuffs share the row, Retail-safe group budgets divide these slots between them; use the separate debuff row to devote every attached slot to buffs."],
			order = 361, type = "range", width = "full", min = 1, max = 32, step = 1, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled,
			set = function(info, val)
				setoption(info, "playerAuraMaxShown", val)
			end,
			get = function(info)
				local value = getoption(info, "playerAuraMaxShown")
				if (type(value) ~= "number") then
					return 16
				end
				if (value < 1) then
					return 1
				end
				if (value > 32) then
					return 32
				end
				return math.floor(value + .5)
			end
		}
		suboptions.args.playerAuraSeparateDebuffs = {
			name = L["Separate player debuff row"],
			desc = L["Keep the normal player aura row attached to the frame. When enabled, harmful auras are filtered out of that row and shown in a separate movable debuff layer instead. When disabled, the debuff layer stays hidden but can still be positioned with /lock."],
			order = 342, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = playerAuraSettingsDisabled
		}
		suboptions.args.playerAuraSeparateDebuffsMax = {
			name = L["Separate debuffs shown"],
			desc = L["Set how many debuffs can appear on the separate player debuff row."],
			order = 343, type = "range", width = "full", min = 1, max = 20, step = 1, hidden = isdisabled,
			disabled = function(info)
				return playerAuraSettingsDisabled(info) or not getoption(info, "playerAuraSeparateDebuffs")
			end,
			set = function(info, val)
				setoption(info, "playerAuraSeparateDebuffsMax", val)
			end,
			get = function(info)
				local value = getoption(info, "playerAuraSeparateDebuffsMax")
				if (type(value) ~= "number") then
					return 8
				end
				if (value < 1) then
					return 1
				end
				if (value > 20) then
					return 20
				end
				return math.floor(value + .5)
			end
		}
		suboptions.args.showCastbar = {
			name = L["Show castbar"],
			desc = L["Show casts as a bar drawn over this frame."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.textHeader = {
			name = L["Text"], order = 200, type = "header", hidden = isdisabled
		}
		suboptions.args.showHealthPercent = {
			name = L["Show health percent"],
			desc = L["Show current health percent next to player health value text."],
			order = 210, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPowerValue = {
			name = L["Show power text"],
			desc = L["Show current power text on the player power widget."],
			order = 220, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.powerValueCombatDriven = {
			name = L["Show in combat only"],
			desc = L["Only show power text while you are in combat."],
			order = 240, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = function(info) return not getoption(info, "showPowerValue") end
		}
		suboptions.args.powerValueTextScale = {
			name = L["Power Text Size %"],
			desc = L["Resize power value text shown inside the Power Crystal and Mana Orb."],
			order = 250, type = "range", width = "full", min = 50, max = 200, step = 1, hidden = isdisabled,
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
			order = 260, type = "range", width = "full", min = 0, max = 100, step = 1, hidden = isdisabled,
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
			name = L["Power text style"],
			desc = L["Choose how power text is displayed."],
			order = 230, type = "select", width = "full", hidden = isdisabled,
			values = {
				short = L["Short number"],
				full = L["Full number"],
				percent = L["Percent"],
				shortpercent = L["Short + percent"]
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
			name = L["Player power style"],
			desc = L["Choose how your player power widget is shown."],
			order = 110, type = "select", width = "full", hidden = hiddenUnderLegacy,
			values = {
				orbV2 = "Automatic (By Resource)",
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
			name = L["Use ice crystal art"],
			desc = L["Use the Ice Crystal artwork when Power Crystal style is active."],
			order = 130, type = "toggle", width = "full", set = setter, get = getter, hidden = hiddenUnderLegacy
		}
		-- The orb ships four interchangeable fill textures and three decorative
		-- layers. Only the clouds fill and the case were ever wired up; the glass
		-- and pedestal textures were created on every login and hidden again.
		-- Values are plain strings here, matching powerOrbMode above.
		suboptions.args.manaOrbTexture = {
			name = L["Mana orb texture"],
			desc = L["Choose which artwork fills the Mana Orb."],
			order = 140, type = "select", width = "full", hidden = hiddenUnderLegacy,
			values = {
				clouds = "Clouds",
				galaxy = "Galaxy",
				moon = "Moon",
				sphere = "Sphere"
			},
			set = function(info, val)
				setoption(info, "manaOrbTexture", val, true)
				module:UpdateSettings()
			end,
			get = function(info)
				local value = getoption(info, "manaOrbTexture")
				if (value == "galaxy" or value == "moon" or value == "sphere") then
					return value
				end
				return "clouds"
			end
		}
		suboptions.args.manaOrbGlass = {
			name = L["Mana orb glass"],
			desc = L["Draw the glass dome over the Mana Orb."],
			order = 150, type = "toggle", width = "full", set = setter, get = getter, hidden = hiddenUnderLegacy
		}
		suboptions.args.manaOrbRim = {
			name = L["Mana orb rim"],
			desc = L["Draw a heavy ring around the edge of the Mana Orb."],
			order = 160, type = "toggle", width = "full", set = setter, get = getter, hidden = hiddenUnderLegacy
		}
		suboptions.args.manaOrbPedestal = {
			name = L["Mana orb pedestal"],
			desc = L["Draw the sculpted plinth beneath the Mana Orb."],
			order = 170, type = "toggle", width = "full", set = setter, get = getter, hidden = hiddenUnderLegacy
		}
		suboptions.args.pvpIndicatorHeader = {
			name = L["PvP Badge"],
			order = 500, type = "header", hidden = isdisabled
		}
		suboptions.args.pvpIndicatorOffsetX = {
			name = L["PvP badge X offset"],
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
			name = L["PvP badge Y offset"],
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
			name = L["Reset PvP badge position"],
			desc = L["Restore the player PvP badge to its centered default anchor within the player frame."],
			order = 530, type = "execute", hidden = isdisabled,
			func = function(info)
				setoption(info, "pvpIndicatorOffsetX", 0, true)
				setoption(info, "pvpIndicatorOffsetY", 0, true)
				module:UpdateSettings()
			end
		}
		-- Flat option keys keep search links, defaults and preview policies stable.
		local renderer = ns.OptionsKit and ns.OptionsKit.Renderer
		if (renderer and renderer.SetNavigation) then renderer:SetNavigation(suboptions, "sections") end
		options.args.player = suboptions
	end

	-- Player Alternate Version (mirrored Target)
	do
		-- This isn't always here, check for it to avoid breaking the whole addon!
		local PlayerFrameAlternate = ns:GetModule("PlayerFrameAlternate", true)
		if (PlayerFrameAlternate) then

			local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerFrameAlternate")
			if (suboptions and suboptions.args) then
			-- Always listed (it used to show only once Player was off). On turns the
			-- other two player frames off; off brings the standard Player back.
			suboptions.args.enabled.set = function(info, val)
				UsePlayerFrame(val and "PlayerFrameAlternate" or "PlayerFrame")
			end

			suboptions.name = L["Player Alternate"]
			suboptions.order = 105

			if (not HasColorPicker) then
				suboptions.args.colorHeader = {
				name = L["Coloring"], order = 10, type = "header", hidden = isdisabled
				}
				suboptions.args.useClassColor = {
					name = L["Color by class"],
					desc = L["Color the health bar by the player's class."],
					order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
				}
			end

			suboptions.args.elementHeader = {
				name = L["Elements"], order = 100, type = "header", hidden = isdisabled
			}
			suboptions.args.showAuras = {
				name = L["Show auras"],
				desc = L["Show buffs and debuffs on this unit frame."],
				order = 200, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.aurasBelowFrame = {
				name = L["Auras below frame"],
				desc = L["Place the auras below the frame instead of above it."],
				order = 210, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
				disabled = function(info) return not getoption(info, "showAuras") end
			}
			suboptions.args.showCastbar = {
				name = L["Show castbar"],
				desc = L["Show casts as a bar drawn over this frame."],
				order = 250, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.showHealthPercent = {
				name = L["Show health percent"],
				desc = L["Show current health percent next to player alternate health value text."],
				order = 275, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.showName = {
				name = L["Show unit name"],
				desc = L["Show the unit's name on the frame."],
				order = 300, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}

			options.args.playerAlternate = suboptions
			end
		end
	end

	-- Player (Party Style): the party frame as the player frame (PlayerParty.lua)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerFrameParty")
		if (module and suboptions and suboptions.args) then
			suboptions.name = L["Player (Party Style)"]
			suboptions.order = 106

			suboptions.args.enabled.name = L["Use party frame as player frame"]
			suboptions.args.enabled.desc = L["Show yourself as a small party frame: the party health bar with a thin power line and the cast overlay. Turns off Player and Player Alternate, and with them the mana orb, the power crystal and the auras by the player frame."]
			-- Off brings the standard Player back.
			suboptions.args.enabled.set = function(info, val)
				UsePlayerFrame(val and "PlayerFrameParty" or "PlayerFrame")
			end

			suboptions.args.elementHeader = {
				name = L["Elements"], order = 100, type = "header", hidden = isdisabled
			}
			suboptions.args.showPortrait = {
				name = L["Show portrait"],
				desc = L["Show the round portrait above the health bar. Without it the frame is just the bar."],
				order = 110, type = "toggle", width = "full", set = setter, get = getter,
				-- Legacy keeps the full party layout and hides the portrait itself (PlayerParty.lua UpdateLayout).
				hidden = function(info) return IsLegacyHUD() or isdisabled(info) end
			}
			suboptions.args.useClassColor = {
				name = L["Color by class"],
				desc = L["Color the health bar by the player's class."],
				order = 120, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}

			options.args.playerParty = suboptions
		end
	end

	-- Pet
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PetFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = L["Pet"]
			suboptions.order = 110
			-- Forever hunters only: Pet.lua builds the bar for nobody else.
			suboptions.args.showPetExperience = {
				name = L["Show pet experience"],
				desc = L["Shows your hunter pet's experience as a thin bar under the pet frame while it can still gain levels."],
				order = 10, type = "toggle", width = "full", set = setter, get = getter,
				hidden = function(info) return not (ns.IsForever and ns.PlayerClass == "HUNTER") or isdisabled(info) end
			}
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
			name = L["Show auras"],
			desc = L["Show buffs and debuffs on this unit frame."],
			order = 31, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showCastbar = {
			name = L["Show castbar"],
			desc = L["Show casts as a bar drawn over this frame."],
			order = 11, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.colorCastBarByInterruptState = {
			name = L["Color entire target castbar by state"],
			desc = L["Tint the full target castbar by interrupt/protected state. Disable to keep the bar on its normal cast color while spell text follows the shared Unit Frames setting."],
			order = 12, type = "toggle", width = "full",
			hidden = isdisabled,
			set = setter,
			get = getter,
			disabled = function(info)
				if (isdisabled(info)) then
					return true
				end
				return not getoption(info, "showCastbar")
			end
		}
		suboptions.args.textHeader = {
			name = L["Text"], order = 20, type = "header", hidden = isdisabled
		}
		suboptions.args.showName = {
			name = L["Show unit name"],
			desc = L["Show the unit's name on the frame."],
			order = 21, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showRaidTargetIcons = {
			name = L["Show target markers"],
			desc = L["Show the raid target icon - skull, cross, star and so on - on this unit frame."],
			order = 13, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showHealthPercent = {
			name = L["Show health percent"],
			desc = L["Show current target health percent next to target health value text."],
			order = 22, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		-- Target.lua, ThreatPercent_Update.
		suboptions.args.showThreatPercent = {
			name = L["Show threat percent"],
			desc = L["In a group, show your threat on the target beside its name: 100% while you are tanking it, otherwise your share of the tank's threat. You pull it at 110% in melee range and 130% at range."],
			order = 22.5, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPowerValue = {
			name = L["Show power value"],
			desc = L["Show the current power as text on the target's power bar."],
			order = 23, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.PowerValueFormat = {
			name = L["Power text format"],
			desc = L["Choose how target power text is formatted."],
			order = 24, type = "select", width = "full", hidden = isdisabled,
			values = {
				short = L["Short number"],
				full = L["Full number"],
				percent = L["Percent"],
				shortpercent = L["Short + percent"]
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
			order = 25, type = "range", width = "full", min = 0, max = 100, step = 1, hidden = isdisabled,
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
			name = L["Use large boss texture"],
			desc = L["Bosses get the larger unit frame art."],
			order = 50, type = "toggle", width = "full", hidden = isdisabled,
			set = function(info,val) setter(info, not val) end,
			get = Inverted(function(info) return not getter(info) end)
		}
		suboptions.args.useStandardCritterTexture = {
			name = L["Use small critter texture"],
			desc = L["Critters get the smaller unit frame art."],
			order = 60, type = "toggle", width = "full", hidden = isdisabled,
			set = function(info,val) setter(info, not val) end,
			get = Inverted(function(info) return not getter(info) end)
		}
		suboptions.args.showExtendedClassification = {
			name = L["Extended classification badges"],
			desc = L["Also badge ordinary, level-?? and dead targets, using the rest of the badge set. Off by default, since it puts a badge on units that normally have none."],
			order = 70, type = "toggle", width = "full", hidden = isdisabled,
			set = function(info, val)
				setoption(info, "showExtendedClassification", val, true)
				module:UpdateSettings()
			end,
			get = getter
		}
		-- The execute marker has its own page (OptionsPages/ExecuteRange.lua).
		suboptions.args.executeRangeMoved = {
			name = L["The execute marker has its own page: Execute Range."],
			order = 75, type = "description", hidden = isdisabled
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
			order = 30, type = "header", hidden = isdisabled
		}
		suboptions.args.AurasMaxCols = {
			name = L["Auras per row"],
			desc = L["How many aura icons are shown on each row. Set to 0 for automatic wrapping from frame width."],
			order = 32, type = "range", width = "full", min = 0, max = 20, step = 1,
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
			name = L["Aura size"],
			order = 33, type = "range", width = "full", min = 12, max = 80, step = 1,
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
			name = L["Aura padding X"],
			order = 34, type = "range", width = "full", min = -20, max = 40, step = 1,
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
			name = L["Aura padding Y"],
			order = 35, type = "range", width = "full", min = -20, max = 40, step = 1,
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
			name = L["Aura growth X"],
			order = 36, type = "select", width = "full",
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			values = targetAuraGrowthXValues,
			set = targetAuraSetter,
			get = function(info)
				return getoption(info, "AurasGrowthX") or targetAuraConfig.AurasGrowthX or "LEFT"
			end
		}
		suboptions.args.AurasGrowthY = {
			name = L["Aura growth Y"],
			order = 37, type = "select", width = "full",
			hidden = isdisabled,
			disabled = targetAuraDisabled,
			values = targetAuraGrowthYValues,
			set = targetAuraSetter,
			get = function(info)
				return getoption(info, "AurasGrowthY") or targetAuraConfig.AurasGrowthY or "DOWN"
			end
		}
		suboptions.args.AurasInitialAnchor = {
			name = L["Aura initial anchor"],
			order = 38, type = "select", width = "full",
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
			name = L["Hide when its target is you"],
			desc = L["Makes the ToT frame transparent when its target is you."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.hideWhenTargetingSelf = {
			name = L["Hide when it targets itself"],
			desc = L["Makes the ToT frame transparent when its target is itself."],
			order = 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.tot = suboptions
	end

	-- Focus Target
	do
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
			name = L["Show in party (2-5)"],
			desc = L["Show these frames in a party of 2-5 players that is not a raid."],
			order = offset + 10, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid5 = {
			name = L["Show in raid (1-5)"],
			desc = L["Show these frames in a raid of 1-5 players."],
			order = offset + 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid10 = {
			name = L["Show in raid (6-10)"],
			desc = L["Show these frames in a raid of 6-10 players."],
			order = offset + 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid25 = {
			name = L["Show in raid (11-25)"],
			desc = L["Show these frames in a raid of 11-25 players."],
			order = offset + 40, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useInRaid40 = {
			name = L["Show in raid (26-40)"],
			desc = L["Show these frames in a raid of 26-40 players."],
			order = offset + 50, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}

		return suboptions, module, setter, getter, setoption, getoption, isdisabled
	end

	-- Sorting reads the same on every group frame family, so the option block is
	-- built once. What each mode does is settled in Components/UnitFrames/GroupSorting.lua.
	local sortByValues = {
		GROUP = L["Group"],
		ROLE = L["Role"],
		CLASS = L["Class"],
		NAME = L["Name"]
	}
	local sortBySorting = { "GROUP", "ROLE", "CLASS", "NAME" }
	local sortDirValues = {
		ASC = L["Ascending"],
		DESC = L["Descending"]
	}
	local sortDirSorting = { "ASC", "DESC" }

	local AddGroupSortingOptions = function(suboptions, setter, getter, isdisabled, order)
		suboptions.args.sortingHeader = {
			name = L["Sorting"], order = order, type = "header", hidden = isdisabled
		}
		suboptions.args.sortBy = {
			name = L["Sort by"],
			desc = L["Choose how group members are ordered on these frames."],
			order = order + 1, type = "select", width = "full", hidden = isdisabled,
			values = sortByValues, sorting = sortBySorting, set = setter, get = getter
		}
		suboptions.args.sortDir = {
			name = L["Sort direction"],
			desc = L["Reverse the order group members are listed in."],
			order = order + 2, type = "select", width = "full", hidden = isdisabled,
			values = sortDirValues, sorting = sortDirSorting, set = setter, get = getter
		}
	end

	-- The distance is meaningless without the toggle, so the two are built
	-- together wherever a group menu offers range fading.
	local AddRangeIndicatorOptions = function(suboptions, setter, getter, getoption, isdisabled, order, hostile)
		suboptions.args.useRangeIndicator = {
			name = L["Use range indicator"],
			desc = L["Fade the frames of units that are out of range."],
			order = order, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.rangeIndicatorRange = {
			name = L["Fade distance (yards)"],
			-- Enemy frames have no group range check behind them, so the wording
			-- that leans on it would be describing something that never happens.
			desc = hostile
				and L["Choose how far away an enemy has to be before its frame fades. Enemies are never in your group, so the game has no range check to offer here: the distance is measured with the spells and items your class currently has, and the fade lands on the nearest range one of them covers."]
				or L["Choose how far away a unit has to be before its frame fades. 40 yards is the game's own group range check. Shorter distances are measured with the spells and items your class currently has, so the fade lands on the nearest range one of them covers, and falls back to 40 yards when nothing reaches that far."],
			order = order + 1, type = "range", width = "full", min = 5, max = 40, step = 5, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "rangeIndicatorRange")
				if (type(value) ~= "number") then
					return 40
				end
				if (value < 5) then
					return 5
				elseif (value > 40) then
					return 40
				end
				return value
			end,
			disabled = function(info) return not getoption(info, "useRangeIndicator") end
		}
		DisabledDesc(suboptions.args.rangeIndicatorRange, IsOffReason(L["Use range indicator"]))
	end

	local AddPlayerVisibilityOptions = function(suboptions, setter, getter, isdisabled, order)
		suboptions.args.showPlayerInParty = {
			name = L["Show player in party"],
			desc = L["Include your own frame among these frames in a party that is not a raid."],
			order = order, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showPlayerInRaid = {
			name = L["Show player in raid"],
			desc = L["Include your own frame among these frames in a raid. Arenas and battlegrounds count as raids."],
			order = order + 1, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
	end

	local AddHealthColorOptions = function(suboptions, setter, getter, getoption, isdisabled, config)
		local GetLocalizedText = function(text)
			return rawget(L, text) or text
		end
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
			useClassColorsDesc = GetLocalizedText("Use class and reaction colors on party health bars. Turn this off to keep them flat health green.")
			useBlizzardDesc = GetLocalizedText("Use Blizzard's default class and reaction palette on party health bars instead of AzeriteUI's custom colors.")
			mouseoverDesc = GetLocalizedText("Keep party health bars on flat health green until you mouse over them, then show class and reaction colors.")
			summaryDesc = GetLocalizedText("Choose whether party bars stay health green, use AzeriteUI class colors, use Blizzard class colors, or only reveal class colors on mouseover.")
		else
			local label = config.countLabel or "raid"
			useClassColorsDesc = GetLocalizedText("Use class and reaction colors on ") .. label .. " health bars. Turn this off to keep them flat health green."
			useBlizzardDesc = GetLocalizedText("Use Blizzard's default class and reaction colors on ") .. label .. " health bars instead of AzeriteUI's custom colors."
			mouseoverDesc = GetLocalizedText("Keep ") .. label .. " health bars on flat health green until you mouse over them, then show class and reaction colors."
			summaryDesc = GetLocalizedText("Keep raid bars health green, switch to AzeriteUI class colors, switch to Blizzard class colors, or only reveal class colors on mouseover.")
		end

		suboptions.args.healthColorsHeader = {
			name = L["Health Colors"], order = order, type = "header", hidden = isdisabled
		}
		suboptions.args.healthColorsDescription = {
			name = summaryDesc, order = order + 1, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.useClassColors = {
			name = L["Use class colors"],
			desc = useClassColorsDesc,
			order = order + 10, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.useBlizzardHealthColors = {
			name = L["Use Blizzard class colors"],
			desc = useBlizzardDesc,
			order = order + 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = disabled
		}
		suboptions.args.useClassColorOnMouseoverOnly = {
			name = L["Only show class color on mouseover"],
			desc = mouseoverDesc,
			order = order + 30, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = disabled
		}
		local classColorsOff = IsOffReason(L["Use class colors"])
		DisabledDesc(suboptions.args.useBlizzardHealthColors, classColorsOff)
		DisabledDesc(suboptions.args.useClassColorOnMouseoverOnly, classColorsOff)
	end

	-- Keep each group-frame section in its own order range so aura, colour and
	-- visibility controls cannot interleave when rendered as foldable sections.
	-- Party Frames
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(200, GenerateSubOptions("PartyFrames"))
		local partyAuraConfig = ns.GetConfig("PartyFrames") or {}
		local InitialPartyDebuffSize = function(info)
			local scale = getoption(info, "partyAuraDebuffScale")
			local size = getoption(info, "AuraSize")
			if (type(scale) ~= "number") then scale = 100 end
			if (type(size) ~= "number") then
				size = type(partyAuraConfig.AuraSize) == "number" and partyAuraConfig.AuraSize or 30
			end
			return math.floor(math.max(9, math.min(84, size * math.max(.5, math.min(2, scale / 100)))) + .5)
		end
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
		AddPlayerVisibilityOptions(suboptions, setter, getter, isdisabled, 2)
		AddGroupSortingOptions(suboptions, setter, getter, isdisabled, 30)
		suboptions.args.elementHeader = {
			name = L["Frame Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.args.usePortraitSpecIcons = {
			name = L["Show specialization icons"],
			desc = L["Show each party member's specialization icon in place of their portrait. A member's specialization can only be read by inspecting them, so it stays a portrait until they are close enough and visible."],
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = function(info) return ns.IsForever or isdisabled(info) end
		}
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 50, scope = "party" })
		suboptions.args.showAuras = {
			name = L["Show auras"],
			desc = L["Show buffs and debuffs on this unit frame."],
			order = 102, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showRaidTargetIcons = {
			name = L["Show target markers"],
			desc = L["Show the raid target icon - skull, cross, star and so on - on this unit frame."],
			order = 14, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		-- Retail only: Forever has no Mythic+ rating.
		suboptions.args.showMythicPlusRating = {
			name = L["Show Mythic+ rating"],
			desc = L["Show each party member's Mythic+ rating for this season in the top right corner of their frame."],
			order = 15, type = "toggle", width = "full", set = setter, get = getter,
			hidden = function(info) return (not ns.IsRetailContent) or isdisabled(info) end
		}
		AddRangeIndicatorOptions(suboptions, setter, getter, getoption, isdisabled, 17)
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
			order = 100, type = "header", hidden = isdisabled
		}
		suboptions.args.partyAuraDescription = {
			name = L["Control which auras appear on party frames, when they appear, how they grow, and how dispellable debuffs are emphasized."],
			order = 101, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.partyAuraUseStockBehavior = {
			name = L["Use AzeriteUI stock behavior"],
			desc = L["Use the original AzeriteUI party-frame aura behavior. Turn this off if you want to build your own filter from the custom categories below."],
			order = 103, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraSettingsDisabled
		}
		suboptions.args.partyAuraWhatToShowHeader = {
			name = L["What to Show"],
			order = 110, type = "header", hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowDispellableDebuffs = {
			name = L["Show dispellable debuffs"],
			desc = L["Show debuffs you can remove from party members. Examples: Magic, Curse, Disease and Poison effects your class/spec can dispel."],
			order = 111, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraOnlyDispellableDebuffs = {
			name = L["Only show dispellable debuffs"],
			desc = L["Hide non-dispellable harmful auras from the party aura row unless they are boss or important mechanics."],
			order = 112, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowBossAndImportantDebuffs = {
			name = L["Show boss and important debuffs"],
			desc = L["Keep encounter-critical or Blizzard-marked important debuffs visible even if they are not dispellable."],
			order = 113, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowOtherDebuffs = {
			name = L["Show other short debuffs"],
			desc = L["Show other short harmful effects that are likely relevant in combat, even if they are not dispellable."],
			order = 114, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			-- Blizzard's dispellable-only mode drops other debuffs itself; the dispellable
			-- switch governs that group then (Party.lua GetPartyNativeAuraOptions).
			disabled = function(info)
				return partyAuraCustomSettingsDisabled(info) or getoption(info, "partyAuraOnlyDispellableDebuffs")
			end
		}
		suboptions.args.partyAuraShowHelpfulExternals = {
			name = L["Show helpful externals"],
			desc = L["Show helpful externals and defensive cooldowns on party members. Examples: Blessing of Sacrifice, Ironbark and Pain Suppression."],
			order = 115, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowHelpfulRaidBuffs = {
			name = L["Show helpful raid buffs"],
			desc = L["Show raid-relevant or Blizzard-flagged helpful buffs on party members."],
			order = 116, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraShowHelpfulShortBuffs = {
			name = L["Show short helpful buffs"],
			desc = L["Show short player-applied buffs with duration or stacks. Examples: Renewing Mist, Earth Shield-style maintenance buffs, and similar short upkeep effects."],
			order = 117, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			disabled = partyAuraCustomSettingsDisabled
		}
		suboptions.args.partyAuraLayoutHeader = {
			name = L["Layout & Highlighting"],
			order = 130, type = "header", hidden = isdisabled
		}
		suboptions.args.partyAuraLayoutDescription = {
			name = L["Adjust the size and growth of party-frame auras, and how removable debuffs are emphasized."],
			order = 131, type = "description", width = "full", hidden = isdisabled
		}
		suboptions.args.showPriorityDebuff = {
			name = L["Show portrait debuff icon"],
			desc = L["Show the priority debuff icon over the party portrait health bar. The dispellable debuff highlight is controlled separately."],
			order = 138, type = "toggle", width = "full", set = setter, get = getter,
			hidden = isdisabled
		}
		suboptions.args.AuraSize = {
			name = L["Buff size"],
			desc = L["Resize helpful party auras. Buffs and debuffs occupy separate rows."],
			order = 132, type = "range", width = "full", min = 18, max = 42, step = 1, hidden = isdisabled,
			set = function(info, value)
				-- Preserve the old effective debuff size before changing only buffs.
				if (type(getoption(info, "partyAuraDebuffSize")) ~= "number") then
					setoption(info, "partyAuraDebuffSize", InitialPartyDebuffSize(info), true)
				end
				setter(info, value)
			end,
			get = function(info)
				local value = getoption(info, "AuraSize")
				if (type(value) ~= "number") then
					return partyAuraConfig.AuraSize or 30
				end
				return math.floor(value + .5)
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.AurasMaxCols = {
			name = L["Auras per row"],
			desc = L["How many aura icons are shown on each row. Set to 0 for automatic wrapping from frame width."],
			order = 133, type = "range", width = "full", min = 0, max = 6, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "AurasMaxCols")
				if (type(value) ~= "number") then
					return 0
				end
				return math.floor(value + .5)
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.partyAuraDebuffSize = {
			name = L["Debuff size"],
			desc = L["Resize harmful party auras independently of buffs."],
			order = 134, type = "range", width = "full", min = 9, max = 84, step = 1, hidden = isdisabled,
			set = setter,
			get = function(info)
				local value = getoption(info, "partyAuraDebuffSize")
				if (type(value) ~= "number") then
					value = InitialPartyDebuffSize(info)
				end
				return math.floor(math.max(9, math.min(84, value)) + .5)
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.partyAuraRowGap = {
			name = L["Buff/debuff spacing"],
			desc = L["Space between the first buff row and the debuff row. Increase this if buffs wrap onto more rows."],
			order = 134.5, type = "range", width = "full", min = 0, max = 160, step = 1,
			hidden = isdisabled, disabled = partyAuraLayoutDisabled, set = setter,
			get = function(info)
				local value = getoption(info, "partyAuraRowGap")
				return type(value) == "number" and math.max(0, math.min(160, value)) or 6
			end
		}
		suboptions.args.AurasGrowthX = {
			name = L["Aura growth X"],
			desc = L["Choose whether party auras grow left or right."],
			order = 135, type = "select", width = "full", hidden = isdisabled,
			values = partyAuraGrowthXValues,
			set = setter,
			get = function(info)
				return getoption(info, "AurasGrowthX") or partyAuraConfig.AurasGrowthX or "RIGHT"
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.AurasGrowthY = {
			name = L["Aura growth Y"],
			desc = L["Choose whether party auras grow up or down."],
			order = 136, type = "select", width = "full", hidden = isdisabled,
			values = partyAuraGrowthYValues,
			set = setter,
			get = function(info)
				return getoption(info, "AurasGrowthY") or partyAuraConfig.AurasGrowthY or "DOWN"
			end,
			disabled = partyAuraLayoutDisabled
		}
		suboptions.args.partyAuraGlowDispellableDebuffs = {
			name = L["Glow frame for dispellable debuffs"],
			desc = L["Highlight the affected party frame using the debuff type color when a removable debuff is active."],
			order = 137, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled,
			-- The glow runs whether the aura row is shown or not (Party.lua AuraHighlight_Update),
			-- so it must stay switchable with Show Auras off.
			disabled = isdisabled
		}

		-- Why each party aura row is greyed out, in the order its `disabled` asks:
		-- the row off, then stock behaviour, then dispellable-only, which greys
		-- only "Show Other Short Debuffs". A row disabled by none of these (the
		-- module off) is hidden, not greyed. FixLog 2026-11-13.
		local partyAuraReason = function(info)
			if (not getoption(info, "showAuras")) then
				return IsOffReason(L["Show auras"])
			end
			if (getoption(info, "partyAuraUseStockBehavior")) then
				return IsOnReason(L["Use AzeriteUI stock behavior"])
			end
			if (getoption(info, "partyAuraOnlyDispellableDebuffs")) then
				return IsOnReason(L["Only show dispellable debuffs"])
			end
		end
		for _, key in ipairs({
			"partyAuraUseStockBehavior", "partyAuraShowDispellableDebuffs", "partyAuraOnlyDispellableDebuffs",
			"partyAuraShowBossAndImportantDebuffs", "partyAuraShowOtherDebuffs", "partyAuraShowHelpfulExternals",
			"partyAuraShowHelpfulRaidBuffs", "partyAuraShowHelpfulShortBuffs",
			"AuraSize", "AurasMaxCols", "partyAuraDebuffSize", "partyAuraRowGap", "AurasGrowthX", "AurasGrowthY"
		}) do
			DisabledDesc(suboptions.args[key], partyAuraReason)
		end
		options.args.party = suboptions
	end

	-- Raid Frames (5)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(200, GenerateSubOptions("RaidFrame5"))
		suboptions.name = L["Raid Frames"] .. " (5)"
		suboptions.args.elementHeader = {
			name = L["Frame Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.order = 160
		AddPlayerVisibilityOptions(suboptions, setter, getter, isdisabled, 2)
		AddGroupSortingOptions(suboptions, setter, getter, isdisabled, 30)
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 50, scope = "raid", countLabel = "1-5 raid health bars" })
		suboptions.args.usePortraitSpecIcons = {
			name = L["Show specialization icons"],
			desc = L["Show each raid member's specialization icon in place of their portrait. A member's specialization can only be read by inspecting them, so it stays a portrait until they are close enough and visible."],
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = function(info) return ns.IsForever or isdisabled(info) end
		}
		AddRangeIndicatorOptions(suboptions, setter, getter, getoption, isdisabled, 17)
		suboptions.args.showAuras = {
			name = L["Show auras"],
			desc = L["Show buffs and debuffs on this unit frame."],
			order = 13, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.showRaidTargetIcons = {
			name = L["Show target markers"],
			desc = L["Show the raid target icon - skull, cross, star and so on - on this unit frame."],
			order = 14, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid5 = suboptions
	end

	-- Raid Frames (25)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(200, GenerateSubOptions("RaidFrame25"))
		suboptions.name = L["Raid Frames"] .. " (25)"
		suboptions.args.elementHeader = {
			name = L["Frame Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.order = 161
		AddGroupSortingOptions(suboptions, setter, getter, isdisabled, 30)
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 50, scope = "raid", countLabel = "6-25 raid health bars" })
		suboptions.args.useSpecIcons = {
			name = L["Show specialization icons"],
			desc = L["Show each raid member's specialization icon on the role badge beside their health bar, including damage dealers, who normally have no badge. A member's specialization can only be read by inspecting them, so it stays the plain role icon until they are close enough and visible."],
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = function(info) return ns.IsForever or isdisabled(info) end
		}
		AddRangeIndicatorOptions(suboptions, setter, getter, getoption, isdisabled, 17)
		suboptions.args.showPriorityDebuff = {
			name = L["Show big debuff"],
			desc = L["Show the large priority debuff icon on raid frames for 11-25 players."],
			order = 13, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = L["Big Debuff Size %"],
			desc = L["Resize the large priority debuff icon on 11-25 raid frames."],
			order = 14, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
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
		suboptions.args.glowDispellableDebuffs = {
			name = L["Glow frame for dispellable debuffs"],
			desc = L["Highlight the affected raid frame using the debuff type color while it has a debuff you can remove."],
			order = 15, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.raid25 = suboptions
	end

	-- Raid Frames (40)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateGroupVisibilityOptions(200, GenerateSubOptions("RaidFrame40"))
		suboptions.name = L["Raid Frames"] .. " (40)"
		suboptions.args.elementHeader = {
			name = L["Frame Elements"], order = 10, type = "header", hidden = isdisabled
		}
		suboptions.order = 162
		AddGroupSortingOptions(suboptions, setter, getter, isdisabled, 30)
		AddHealthColorOptions(suboptions, setter, getter, getoption, isdisabled, { order = 50, scope = "raid", countLabel = "26-40 raid health bars" })
		suboptions.args.useSpecIcons = {
			name = L["Show specialization icons"],
			desc = L["Show each raid member's specialization icon on the role badge beside their health bar, including damage dealers, who normally have no badge. A member's specialization can only be read by inspecting them, so it stays the plain role icon until they are close enough and visible."],
			order = 12, type = "toggle", width = "full", set = setter, get = getter, hidden = function(info) return ns.IsForever or isdisabled(info) end
		}
		AddRangeIndicatorOptions(suboptions, setter, getter, getoption, isdisabled, 17)
		suboptions.args.showPriorityDebuff = {
			name = L["Show big debuff"],
			desc = L["Show the large priority debuff icon on raid frames for 26-40 players."],
			order = 13, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		suboptions.args.priorityDebuffScale = {
			name = L["Big Debuff Size %"],
			desc = L["Resize the large priority debuff icon on 26-40 raid frames."],
			order = 14, type = "range", width = "full", min = 25, max = 100, step = 1, hidden = isdisabled,
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
		suboptions.args.glowDispellableDebuffs = {
			name = L["Glow frame for dispellable debuffs"],
			desc = L["Highlight the affected raid frame using the debuff type color while it has a debuff you can remove."],
			order = 15, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
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
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("ArenaFrames")
		suboptions.name = L["Arena Enemy Frames"]
		suboptions.order = 180
		AddRangeIndicatorOptions(suboptions, setter, getter, getoption, isdisabled, 11, true)
		suboptions.args.visibilityHeader = {
			name = L["Visibility"], order = 19, type = "header", hidden = isdisabled
		}
		suboptions.args.showInBattlegrounds = {
			name = L["Show in battlegrounds"],
			desc = L["Show the flag carriers' frames in battlegrounds."],
			order = 20, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
		}
		options.args.arena = suboptions
	end

	-- Player CastBar
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerCastBarFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = L["Castbar"]
			suboptions.order = 200
			suboptions.args.showDelay = {
				name = L["Show pushback time"],
				desc = L["Shows the red +time right of the castbar when taking damage pushes your cast back."],
				order = 10, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			-- Forever ships its own swing timer (Blizzard_SwingTimer, AllowLoadGameType camelot), shown by
			-- the showSwingTimer CVar like Blizzard's Options -> Combat checkbox. Its three bars are Edit Mode
			-- systems laid out by Blizzard's bottom-frame manager, so AzeriteUI only switches them on and
			-- leaves placement to Edit Mode: moving them from addon code would mean writing Edit Mode state.
			local HasSwingTimerCVar = function()
				return ns.IsForever and C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showSwingTimer") ~= nil
			end
			suboptions.args.showSwingTimer = {
				name = L["Show the game's swing timer"],
				desc = L["Turns on WoW Forever's own main hand, off hand and ranged swing timers, the same switch as Options -> Combat -> Enable Swing Timer. Place them in Edit Mode. Cannot be changed in combat."],
				order = 20, type = "toggle", width = "full",
				hidden = function() return not HasSwingTimerCVar() end,
				disabled = function() return InCombatLockdown() end,
				set = function(info, val)
					if (InCombatLockdown() or not HasSwingTimerCVar()) then return end
					C_CVar.SetCVar("showSwingTimer", val and "1" or "0")
				end,
				get = function(info)
					return HasSwingTimerCVar() and C_CVar.GetCVarBool("showSwingTimer") or false
				end
			}
			options.args.castbar = suboptions
		end
	end

	-- Player Totems (Retail and Forever; the module does not exist elsewhere, so the group stays hidden)
	do
		local suboptions, module, setter, getter, setoption, getoption, isdisabled = GenerateSubOptions("PlayerTotemsFrame")
		if (suboptions and suboptions.args) then
			suboptions.name = L["Totems"]
			suboptions.order = 205
			suboptions.args.enabled.desc = L["Shows your totems, statues, ghoul and other totem-slot summons with their time left. Move them with /lock."]
			options.args.totems = suboptions
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
				if (wanted == 0 or not ns.IsRetailContent) then
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
			suboptions.args.showFullOutOfCombat = {
				name = L["Show full class power out of combat"],
				desc = L["Prevent full class-power displays from fading out of combat. Zero-resource hiding and special resource presentation remain unchanged."],
				order = 94, type = "toggle", width = "full", set = setter, get = getter, hidden = isdisabled
			}
			suboptions.args.clickThrough = {
				name = L["Class power click-through"],
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
				name = L["Show combo points"],
				desc = L["Show your combo points."],
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
			do
				suboptions.args.showRunes = {
					name = L["Show Runes (Death Knight)"],
					desc = L["Show your Death Knight runes."],
					order = 97, type = "toggle", width = "full", set = setter, get = getter,
					hidden = function(info)
						if (isdisabled(info)) then return true end
						return ns.PlayerClass ~= "DEATHKNIGHT"
					end
				}
				if (ns.IsRetailContent) then
					suboptions.args.soulFragmentsDisplayMode = {
						name = function()
							if (ns.PlayerClass == "SHAMAN") then
								return "10-Point Resource Display Mode"
							end
							return L["Soul fragments display mode"]
						end,
						desc = function()
							if (ns.PlayerClass == "SHAMAN") then
								return "Choose how Maelstrom Weapon points are displayed (same model as DH 10-point behavior)."
							end
							return L["Choose how Soul Fragments points are displayed."]
						end,
						order = 95, type = "select", width = "full", set = setter, get = getter,
						values = {
							["alpha"] = L["Alpha mode (dim 0-5, bright 6-10)"],
							["gradient"] = L["Smooth gradient (light to dark + glow)"],
							["recolor"] = L["Two-phase recolor (keep first 5, recolor overflow)"],
							["stacked"] = L["Stacked 5-point (hide empty, bright overflow from bottom)"]
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
						desc = L["Show your Mage Arcane Charges."],
						order = 98, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "MAGE") then return true end
							return not IsSpecMatch(SPEC_ARCANE)
						end
					}
					suboptions.args.showChi = {
						name = L["Show Chi (Monk)"],
						desc = L["Show your Monk Chi."],
						order = 99, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "MONK") then return true end
							return not IsSpecMatch(SPEC_WINDWALKER)
						end
					}
					suboptions.args.showHolyPower = {
						name = L["Show Holy Power (Paladin)"],
						desc = L["Show your Paladin Holy Power."],
						order = 100, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							return ns.PlayerClass ~= "PALADIN"
						end
					}
					suboptions.args.showMaelstrom = {
						name = L["Show Maelstrom Weapon (Shaman)"],
						desc = L["Show Enhancement Shaman Maelstrom Weapon stacks as class power."],
						order = 101, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							if (ns.PlayerClass ~= "SHAMAN") then return true end
							return not IsSpecMatch(SPEC_ENHANCEMENT)
						end
					}
					-- Stays under the Legacy HUD: it drops the swap bar (PlayerClassPower.lua
					-- ShouldUseElementalSwapBar), but its power bar is the crystal element, whose
					-- GetDisplayPower (Player.lua) still picks Maelstrom or Mana from this.
					suboptions.args.elementalMaelstromDisplayMode = {
						name = L["Elemental crystal/bar resource split"],
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
						desc = L["Show your Warlock Soul Shards."],
						order = 103, type = "toggle", width = "full", set = setter, get = getter,
						hidden = function(info)
							if (isdisabled(info)) then return true end
							return ns.PlayerClass ~= "WARLOCK"
						end
					}
					suboptions.args.showStagger = {
						name = L["Show Stagger (Monk)"],
						desc = L["Show your Monk Stagger."],
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


	-- The page's own settings, the ones not inside a unit's sub-group, live on
	-- the UnitFrames module itself.
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, "UnitFrames")
	end
	return options
end

-- One table is built and split in two pages: the panel draws a page's sub-groups
-- as sections down one scrolling column, and all of them on Unit Frames made a
-- page of fifteen sections and over two hundred settings. Party and raid frames,
-- what is drawn on them and Blizzard's raid bar go to Group Frames. The sub-groups
-- move as they are, so each keeps its module binding and preview policy.
local GROUP_KEYS = { "showBlizzardRaidBar", "party", "raid5", "raid25", "raid40", "groupIndicators" }

local built
local Build = function()
	if (built ~= nil) then return built end
	built = false

	local options = GenerateOptions()
	if (not options) then return built end

	local group = {
		name = L["Group Frames"],
		type = "group",
		childGroups = "tree",
		args = {}
	}
	local controller = ns.NativeController
	local native = controller and controller.IsActive()
	-- Direct D-pad party targeting needs no frames, so the party frames (and
	-- what is drawn on them) stay ours then; raids always keep Blizzard's.
	local nativeParty = native and (controller.UsesNativePartyFrames or controller.IsActive)()
	local ownInNative = { party = true, groupIndicators = true }
	for _, key in ipairs(GROUP_KEYS) do
		if not native or (ownInNative[key] and not nativeParty) then group.args[key] = options.args[key] end
		options.args[key] = nil
	end
	if native then
		local text = L["AzeriteUI automatically follows Blizzard's selected controller interface. Native mode keeps Blizzard's bars, party and raid targeting, menus and bag controls. Switch the game's interface mode and reload to return to your saved AzeriteUI layouts."]
		if nativeParty then
			text = text .. "\n\n" .. L["To keep AzeriteUI party frames, turn on party targeting in Blizzard's controller settings and reload. The D-pad then targets party members directly."]
		else
			text = text .. "\n\n" .. L["Party targeting is on in Blizzard's controller settings, so the D-pad targets party members directly and your AzeriteUI party frames stay. Raids keep Blizzard's frames for raid navigation."]
		end
		group.args.description = { type = "description", fontSize = "medium", order = 0, name = text }
	end
	-- The frames first, then what is drawn on all of them.
	if (group.args.groupIndicators) then group.args.groupIndicators.order = 200 end
	if (Options.GenerateRaidToolsOptions) then group.args.raidTools = Options:GenerateRaidToolsOptions() end
	if (Options.GenerateTargetMarkersLiteOptions) then group.args.targetMarkersLite = Options:GenerateTargetMarkersLiteOptions() end
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(group, "UnitFrames")
	end

	built = { unitFrames = options, groupFrames = group }
	return built
end

Options:AddGroup("Unit Frames", function() return Build() and built.unitFrames end, -8000, "frames", "UnitFrames")
Options:AddGroup("Group Frames", function() return Build() and built.groupFrames end, -7500, "frames", "UnitFrames")

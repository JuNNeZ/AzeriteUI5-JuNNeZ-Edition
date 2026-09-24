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

local Options = ns:GetModule("Options")
local FRIENDLY_NAME_ONLY_FONT_SCALE_DEFAULT = 2.5
local FRIENDLY_NAME_ONLY_TARGET_SCALE_DEFAULT = 0.5
local NAMEPLATE_SCALE_DEFAULT = 2
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
local RAID_TARGET_SIZE_DEFAULT = 28
local RAID_TARGET_SIZE_SLIDER_MIN = 12
local RAID_TARGET_SIZE_SLIDER_MAX = 64
local TARGET_SLIDER_MIN = 1
local TARGET_SLIDER_MAX = 500
local EXECUTE_THRESHOLD_SLIDER_MIN = .05
local EXECUTE_THRESHOLD_SLIDER_MAX = .5
local EXECUTE_THRESHOLD_FALLBACK = .2

local getmodule = function()
	return ns:GetModule("NamePlates", true)
end

-- The nameplate addon the module stood down for at login, or nil.
local GetConflictingAddOn = function()
	local module = getmodule()
	local addon = module and module.conflictingAddOn
	return (type(addon) == "string") and addon or nil
end

-- The class's execute threshold (Components/UnitFrames/ExecuteRange.lua), or 20% for a class without
-- one, which is where a threshold set by hand starts.
local GetAutomaticExecuteThreshold = function()
	local threshold = ns.API.GetExecuteThreshold and ns.API.GetExecuteThreshold() or 0
	if (type(threshold) ~= "number" or threshold < EXECUTE_THRESHOLD_SLIDER_MIN) then
		return EXECUTE_THRESHOLD_FALLBACK
	end
	return threshold
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
				confirm = true,
				confirmText = L["Switching AzeriteUI nameplates on or off reloads the interface."],
				set = setter,
				get = getter
			},
			-- Another nameplate addon is enabled, so the module stood down at login (CheckForConflicts).
			conflictInfo = {
				name = function()
					local addon = GetConflictingAddOn()
					if (addon) then
						return string.format(L["%s is enabled, so AzeriteUI's nameplates stand down. These settings apply once it is disabled."], addon)
					end
					return ""
				end,
				order = .5,
				type = "description",
				width = "full",
				hidden = function() return not GetConflictingAddOn() end
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
			-- The kinds of aura a plate shows: groups of the native aura display, see
			-- PlayerAuraContainers.lua, CreateForNamePlate. The keys are the module's profile keys.
			auraFilters = {
				name = L["Aura filters"],
				order = 1.2,
				type = "group",
				inline = true,
				hidden = isdisabled,
				disabled = function(info) return not getoption(info, "showAuras") end,
				args = {
					auraFiltersDescription = {
						name = L["Which kinds of aura a nameplate shows, in combat too. They fill the aura rows in this order."],
						order = 0,
						type = "description",
						width = "full"
					},
					auraCrowdControl = {
						name = L["Crowd control"],
						desc = L["Stuns, fears, roots and other crowd control on the unit, from anyone."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					auraOwnDebuffs = {
						name = L["Your debuffs"],
						desc = L["Damage over time and other debuffs you or your pet put on the unit."],
						order = 2,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					auraOwnDebuffsBlizzardOnly = {
						name = L["Only the ones Blizzard highlights"],
						desc = L["Of your debuffs, show only those Blizzard's own nameplates would show."],
						order = 3,
						type = "toggle", width = "full",
						disabled = function(info) return not getoption(info, "showAuras") or not getoption(info, "auraOwnDebuffs") end,
						set = setter,
						get = getter
					},
					auraOtherDebuffs = {
						name = L["Important debuffs from others"],
						desc = L["Debuffs from other players that Blizzard flags to show on every nameplate."],
						order = 4,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					auraDispellableBuffs = {
						name = L["Buffs you can dispel"],
						desc = L["Enemy buffs your group can purge, spellsteal or soothe."],
						order = 5,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					auraImportantBuffs = {
						name = L["Important enemy buffs"],
						desc = L["Buffs Blizzard marks as important on enemy nameplates, such as big defensive cooldowns."],
						order = 6,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					auraOwnBuffs = {
						name = L["Your short buffs"],
						desc = L["Buffs you cast that last 30 seconds or less, on friendly nameplates."],
						order = 7,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					}
				}
			},
			-- Blizzard's own setting, read and written straight through: AzeriteUI stores nothing.
			-- Shown even with Azerite nameplates off, since it moves Blizzard's plates as well.
			stacking = {
				name = L["Stacking"],
				order = 1.4,
				type = "group",
				inline = true,
				hidden = function(info)
					local module = getmodule()
					return not (module and module.IsStackingSupported and module:IsStackingSupported())
				end,
				args = {
					stackingDescription = {
						name = L["These are the game's own nameplate settings, the same ones Blizzard's Options change. A change made in combat applies when it ends."],
						order = 0,
						type = "description",
						width = "full"
					},
					stackEnemyPlates = {
						name = L["Stack enemy nameplates"],
						desc = L["Enemy nameplates move apart so they do not overlap."],
						order = 1,
						type = "toggle", width = "full",
						set = function(info, val) getmodule():SetStacking("enemy", val) end,
						get = function(info) return getmodule():GetStacking("enemy") end
					},
					stackFriendlyPlates = {
						name = L["Stack friendly nameplates"],
						desc = L["Friendly nameplates move apart so they do not overlap."],
						order = 2,
						type = "toggle", width = "full",
						set = function(info, val) getmodule():SetStacking("friendly", val) end,
						get = function(info) return getmodule():GetStacking("friendly") end
					}
				}
			},
			-- How far plates reach and how faint they get, per kind of content. The selector is the
			-- page's own state; the three settings below edit the kind it shows. The distance keeps
			-- its old key, so its preview and default follow it.
			contentSettings = {
				name = L["Content settings"],
				order = 1.6,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					contentDescription = {
						name = L["Each kind of content keeps its own values, and the one you are in is used. Pick a kind to change it."],
						order = 0,
						type = "description",
						width = "full"
					},
					editedContent = {
						name = L["Content"],
						desc = L["Which kind of content the settings below change. Opens on the one you are in."],
						order = 1,
						type = "select", width = "full",
						values = function()
							return {
								world = L["Open world"],
								dungeon = L["Dungeon"],
								mythicplus = L["Mythic+"],
								raid = L["Raid"],
								battleground = L["Battleground"],
								arena = L["Arena"]
							}
						end,
						sorting = function()
							return getmodule():GetContentTypes()
						end,
						set = function(info, val) getmodule():SetEditedContent(val) end,
						get = function(info) return getmodule():GetEditedContent() end
					},
					maxDistance = {
						name = L["Maximum distance"],
						desc = L["How far away nameplates can appear. `40` matches the current Rui retail baseline."],
						order = 2,
						type = "range", width = "full",
						min = DISTANCE_SLIDER_MIN, max = DISTANCE_SLIDER_MAX, step = 1,
						set = function(info, val) getmodule():SetContentValue("maxDistance", val) end,
						get = function(info) return getmodule():GetContentValue("maxDistance") end
					},
					contentMinAlpha = {
						name = L["Faintest alpha"],
						desc = L["How faint the nameplates of units other than your target get with distance."],
						order = 3,
						type = "range", width = "full",
						min = 0, max = 1, step = .05, isPercent = true,
						set = function(info, val) getmodule():SetContentValue("minAlpha", val) end,
						get = function(info) return getmodule():GetContentValue("minAlpha") end
					},
					contentOccludedAlpha = {
						name = L["Alpha behind walls"],
						desc = L["How faint nameplates get while walls or other objects hide their unit."],
						order = 4,
						type = "range", width = "full",
						min = 0, max = 1, step = .05, isPercent = true,
						set = function(info, val) getmodule():SetContentValue("occludedAlpha", val) end,
						get = function(info) return getmodule():GetContentValue("occludedAlpha") end
					}
				}
			},
			-- The combat filter: enemies nobody in your group is fighting fade.
			otherFights = {
				name = L["Other fights"],
				order = 1.7,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					combatFilter = {
						name = L["Fade enemies fighting someone else"],
						desc = L["Enemies in combat with no one in your group fade, so the pull you are in stands out. Your target, focus and the plate under your cursor never fade."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					combatFilterAlpha = {
						name = L["Faded alpha"],
						desc = L["How faint those enemies' nameplates get."],
						order = 2,
						type = "range", width = "full",
						min = 0, max = 1, step = .05, isPercent = true,
						disabled = function(info) return not getoption(info, "combatFilter") end,
						set = setter,
						get = getter
					}
				}
			},
			-- The execute marker. One profile key holds the threshold: 0 follows the class, anything
			-- else was set by hand, so the Automatic / By hand choice has no key of its own.
			executeRange = {
				name = L["Execute range"],
				order = 1.8,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					executeMarker = {
						name = L["Show the execute marker"],
						desc = L["A line across enemy health bars at your execute threshold. Once an enemy's health falls below it, the part of the bar below the line is tinted."],
						order = 1,
						type = "toggle", width = "full",
						set = setter,
						get = getter
					},
					executeThresholdMode = {
						name = L["Threshold"],
						desc = L["Automatic follows your class and specialization, and classes without an execute get no marker. Set it by hand where a talent moves it, as Massacre does."],
						order = 2,
						type = "select", width = "full",
						values = function()
							return { auto = L["Automatic"], custom = L["By hand"] }
						end,
						sorting = function()
							return { "auto", "custom" }
						end,
						disabled = function(info) return not getoption(info, "executeMarker") end,
						set = function(info, val)
							local module = getmodule()
							if (not module or not module.db) then return end
							if (val == "custom") then
								module.db.profile.executeThreshold = GetAutomaticExecuteThreshold()
							else
								module.db.profile.executeThreshold = 0
							end
							module:UpdateSettings()
						end,
						get = function(info)
							local value = getoption(info, "executeThreshold")
							return (type(value) == "number" and value > 0) and "custom" or "auto"
						end
					},
					executeThreshold = {
						name = L["Threshold by hand"],
						desc = L["Where the marker sits when the threshold is set by hand."],
						order = 3,
						type = "range", width = "full",
						min = EXECUTE_THRESHOLD_SLIDER_MIN, max = EXECUTE_THRESHOLD_SLIDER_MAX, step = .01, isPercent = true,
						disabled = function(info)
							local value = getoption(info, "executeThreshold")
							return not getoption(info, "executeMarker") or not (type(value) == "number" and value > 0)
						end,
						set = setter,
						-- While automatic, the class's threshold, which is where By hand starts from.
						get = function(info)
							local value = getter(info)
							if (type(value) ~= "number" or value <= 0) then
								return GetAutomaticExecuteThreshold()
							end
							return value
						end
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
					},
					raidTargetSize = {
						name = L["Target marker size"],
						desc = L["Size of the raid target icon - skull, cross, star and so on - beside the nameplate's health bar. `28` is the intended default."],
						order = 9,
						type = "range", width = "full",
						min = RAID_TARGET_SIZE_SLIDER_MIN, max = RAID_TARGET_SIZE_SLIDER_MAX, step = 1,
						set = setter,
						get = function(info)
							local value = getter(info)
							if (type(value) ~= "number") then
								return RAID_TARGET_SIZE_DEFAULT
							end
							return value
						end
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
			colors = {
				name = L["Colors"],
				order = 4,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					threatColorPreset = {
						name = L["Enemy Threat Colors"],
						desc = L["Choose a color-blind friendly preset for enemy nameplate threat colors."],
						order = 1,
						type = "select", width = "full",
						values = {
							azerite = L["AzeriteUI Classic"],
							deepYellow = L["AzeriteUI deep yellow"],
							blueOrange = L["Blue / Orange"],
							tealPurple = L["Teal / Purple"],
							highContrast = L["High Contrast"]
						},
						set = setter,
						get = function(info)
							local value = getter(info)
							if (value == "deepYellow" or value == "blueOrange" or value == "tealPurple" or value == "highContrast") then
								return value
							end
							return "azerite"
						end
					},
					threatColorDescription = {
						name = L["Enemy health threat colors are separate from castbar interrupt colors. AzeriteUI deep yellow keeps the non-target combat health yellow darker than the castbar ready-interrupt yellow."],
						order = 2,
						type = "description",
						width = "full"
					}
				}
			},
			advanced = {
				name = L["Advanced"],
				order = 5,
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

Options:AddGroup(L["Nameplates"], GenerateOptions, -7000, "frames", "NamePlates")

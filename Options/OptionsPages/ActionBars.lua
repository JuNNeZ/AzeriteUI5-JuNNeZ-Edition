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

-- Lua API
local math_min = math.min
local next = next
local string_format = string.format
local string_match = string.match
local tonumber = tonumber
local tostring = tostring

local getmodule = function()
	local module = ns:GetModule("ActionBars", true)
	if (module and module:IsEnabled()) then
		return module
	end
end

local setter = function(info,val)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	db[info[#info]] = val
	getmodule():UpdateSettings()
	-- This is needed to put actionbars that were exempt from Explorer Mode fading
	-- back into it when their own full fading has been disabled.
	ns:Fire("ActionBarSettings_Changed")
end

local getter = function(info)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	return db[info[#info]]
end

local isdisabled = function(info)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	return info[#info] ~= "enabled" and not db.enabled
end

local getsetting = function(info, setting)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	return db[setting]
end

local setoption = function(info,option,val)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	db[option] = val
	getmodule():UpdateSettings()
	-- This is needed to put actionbars that were exempt from Explorer Mode fading
	-- back into it when their own full fading has been disabled.
	ns:Fire("ActionBarSettings_Changed")
end

local getoption = function(info,option)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	return db[option]
end

-- The visibility conditions live in a sub-table, so they cannot go through the
-- flat setter above. Option keys are named for the option, not the condition,
-- which is why the condition is passed in rather than read off info.
local setvisibility = function(info,condition,val)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	db.visibility[condition] = val
	getmodule():UpdateSettings()
	ns:Fire("ActionBarSettings_Changed")
end

local getvisibility = function(info,condition)
	local id = tonumber((string_match(info[#info - 1],"(%d+)")))
	local db = getmodule().db.profile.bars[id]
	return db.visibility[condition]
end

-- Button shape dropdown, shared by the action, pet, stance and extra buttons.
-- Shapes apply on reload, so a change offers one. Hidden under the Legacy HUD,
-- which draws its own rounded buttons and ignores the choice.
local ShapeOption = function(name, desc, order, hidden, get, set)
	return {
		name = name,
		desc = desc,
		order = order,
		type = "select", style = "dropdown",
		hidden = function(info)
			return (ns.LegacyHUD and ns.LegacyHUD:IsActive()) or (hidden and hidden(info)) or false
		end,
		values = {
			["circle"] = L["Circle (intended design)"],
			["rounded"] = L["Rounded"],
			["square"] = L["Square"],
			["hex"] = "Hex",
		},
		sorting = { "circle", "rounded", "square", "hex" },
		set = function(info, val)
			if (get(info) == val) then return end
			set(info, val)
			local key = "AZERITEUI_ACTIONBAR_SHAPE_RELOAD"
			if (ns.API.PopupDialogs and not ns.API.PopupDialogs[key]) then
				ns.API.PopupDialogs[key] = {
					text = L["Button shapes apply when the interface loads. Reload now?"],
					button1 = L["Reload UI"],
					button2 = _G.CANCEL or "Cancel",
					OnAccept = function() ReloadUI() end,
					timeout = 0,
					whileDead = true,
					hideOnEscape = true,
					preferredIndex = 3
				}
			end
			if (ns.API.ShowPopup) then ns.API.ShowPopup(key) end
		end,
		get = get
	}
end

local GenerateIndexedBarOptions = function(moduleName, displayName, order)
	local getmodule = function()
		local module = ns:GetModule(moduleName, true)
		if (module and module:IsEnabled()) then
			return module
		end
	end
	if (not getmodule(moduleName)) then return end
	local options = {
		name = displayName,
		order = order,
		type = "group",
		args = {
			enabled = {
				name = L["Enable"],
				desc = L["Show this action bar."],
				order = 1,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			visibilityHeader = {
				name = L["Visibility"],
				order = 2,
				type = "header",
				hidden = isdisabled
			},
			visibilityDesc = {
				name = L["Choose when your bars will be visible."],
				order = 3,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			showWhileMounted = {
				name = L["Show while mounted"],
				desc = L["Keep this bar available while riding a ground mount or using steady flight. This does not control skyriding. Normal bar fading still applies; bar 1 always switches to riding abilities during skyriding."],
				order = 4,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = function(info, val) setvisibility(info, "mounted", val) end,
				get = function(info) return getvisibility(info, "mounted") end
			},
			showWhileSkyriding = {
				name = L["Show while skyriding"],
				desc = L["Keep this secondary bar available while skyriding, when bar 1 switches to riding abilities. Independent of Show while mounted; normal bar fading still applies. Does not change vehicle or possession visibility."],
				order = 5,
				type = "toggle", width = "full",
				hidden = function(info)
					-- Retail content: ns.IsRetail is also true on Forever, which has no skyriding.
					return not ns.IsRetailContent or isdisabled(info) or tonumber(string_match(info[#info - 1], "(%d+)")) == 1
				end,
				set = function(info, val) setvisibility(info, "dragon", val) end,
				get = function(info) return getvisibility(info, "dragon") end
			},
			buttonShape = ShapeOption(L["Button shape"],
				L["Choose the shape of this bar's buttons. Circle is the intended AzeriteUI design. Square and Rounded are alternatives that keep the same spacing. Changing this asks you to reload."],
				14, isdisabled, getter, setter),
			showRangeIndicator = {
				name = L["Show range indicator"],
				desc = L["Color buttons on this bar when their action is out of range. Unusable actions and low resource colors still apply."],
				order = 15, type = "toggle", width = "full", hidden = isdisabled,
				set = setter, get = function(info) return getter(info) ~= false end
			},
			showButtonCount = {
				name = L["Show item and charge counts"],
				desc = L["Show item quantities and spell charge counts on this bar. Cooldown timers are unaffected."],
				order = 16, type = "toggle", width = "full", hidden = isdisabled,
				set = setter, get = function(info) return getter(info) ~= false end
			},
			enableBarFading = {
				name = L["Enable bar fading"],
				desc = L["Let this bar's buttons fade out. The settings below choose when."],
				order = 9,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			fadeAlone = {
				name = L["Don't fade in other bars"],
				desc = L["Only show buttons from this specific bar when hovering it."],
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			fadeInCombat = {
				name = L["Only show on mouseover"],
				desc = L["Enable this to only show faded bars on mouseover, and not force them visible in combat."],
				order = 11,
				type = "toggle", width = "full",
				hidden = function(info) return isdisabled(info) or not getsetting(info, "enableBarFading") end,
				set = setter,
				get = getter
			},
			fadeFrom = {
				name = L["Start fading from"],
				desc = L["Choose which button to start the fading from."],
				order = 12,
				type = "range", width = "full", min = 1, max = 12, step = 1,
				hidden = function(info) return isdisabled(info) or not getsetting(info, "enableBarFading") end,
				set = setter,
				get = getter
			},
			blockFadedClicks = {
				name = L["Ignore clicks while faded"],
				desc = L["Stop faded out buttons from casting when you click them. Faded buttons are invisible but still live, so clicking where one sits will use it. With this on, the click is ignored until you hover the bar and the buttons come back into view."],
				order = 13,
				type = "toggle", width = "full",
				hidden = function(info) return isdisabled(info) or not getsetting(info, "enableBarFading") end,
				set = setter,
				get = getter
			},
			layoutHeader = {
				name = L["Layout"],
				order = 18,
				type = "header",
				hidden = isdisabled
			},
			layoutDesc = {
				name = L["Choose how your bar is displayed."],
				order = 19,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			layout = {
				name = L["Bar layout"],
				desc = L["Choose the action bar layout type."],
				order = 20,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["grid"] = L["Grid layout"],
					["zigzag"] = L["Zigzag layout"],
				},
				set = setter,
				get = getter
			},
			startAt = {
				name = L["First zigzag button"],
				desc = L["Sets which button the zigzag pattern should begin at."],
				order = 21,
				type = "range", width = "full", min = 1, max = 12, step = 1,
				hidden = function(info) return isdisabled(info) or getsetting(info, "layout") ~= "zigzag" end,
				set = setter,
				get = getter
			},
			numbuttons = {
				name = L["Number of buttons"],
				desc = L["Sets the number of action buttons on the action bar."],
				order = 30,
				type = "range", width = "full", min = 0, max = 12, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			padding = {
				name = L["Button padding"],
				desc = L["Sets the padding between buttons on the same line."],
				order = 31,
				type = "range", width = "full", min = 0, max = 16, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			breakpadding = {
				name = L["Line padding"],
				desc = L["Sets the padding between multiple lines of buttons."],
				order = 32,
				type = "range", width = "full", min = 0, max = 16, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			breakpoint = {
				name = L["Line break"],
				desc = L["Sets when a new line of buttons should begin."],
				order = 40,
				type = "range", width = "full", min = 1, max = 12, step = 1,
				hidden = function(info) return isdisabled(info) or getsetting(info, "layout") ~= "grid" end,
				set = setter,
				get = getter
			},
			growth = {
				name = L["Initial growth"],
				desc = L["Choose whether the bar initially should expand horizontally or vertically."],
				order = 50,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["horizontal"] = L["Horizontal layout"],
					["vertical"] = L["Vertical layout"],
				},
				set = setter,
				get = getter
			},
			growthSpace = {
				name = "", order = 51, type = "description",
				hidden = isdisabled
			},
			growthHorizontal = {
				name = L["Horizontal growth"],
				desc = L["Choose which horizontal direction the bar should expand in."],
				order = 52,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["RIGHT"] = L["Right"],
					["LEFT"] = L["Left"],
				},
				set = setter,
				get = getter
			},
			growthVertical = {
				name = L["Vertical growth"],
				desc = L["Choose which vertical direction the bar should expand in."],
				order = 53,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["DOWN"] = L["Down"],
					["UP"] = L["Up"],
				},
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
	return options
end

local GenerateBarOptions = function(moduleName, displayName, order, maxButtons)
	local getmodule = function()
		local module = ns:GetModule(moduleName, true)
		if (module and module:IsEnabled()) then
			return module
		end
	end
	if (not getmodule(moduleName)) then return end

	local setter = function(info,val)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		db[info[#info]] = val
		getmodule():UpdateSettings()
	end

	local getter = function(info)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[info[#info]]
	end

	local isdisabled = function(info)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return info[#info] ~= "enabled" and not db.enabled
	end

	local getsetting = function(info, setting)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[setting]
	end

	local setoption = function(info,option,val)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		db[option] = val
		getmodule():UpdateSettings()
	end

	local getoption = function(info,option)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[option]
	end

	local options = {
		name = displayName,
		order = order,
		type = "group",
		args = {
			enabled = {
				name = L["Enable"],
				desc = L["Show this action bar."],
				order = 1,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			visibilityHeader = {
				name = L["Visibility"],
				order = 2,
				type = "header",
				hidden = isdisabled
			},
			visibilityDesc = {
				name = L["Choose when your bars will be visible."],
				order = 3,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			buttonShape = ShapeOption(L["Button shape"],
				L["Choose the shape of this bar's buttons. Circle is the intended AzeriteUI design. Square and Rounded are alternatives that keep the same spacing. Changing this asks you to reload."],
				14, isdisabled, getter, function(info, val)
					getmodule().db.profile.buttonShape = val
				end),
			enableBarFading = {
				name = L["Enable bar fading"],
				desc = L["Let this bar's buttons fade out. The settings below choose when."],
				order = 9,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			fadeAlone = {
				name = L["Don't fade in other bars"],
				desc = L["Only show buttons from this specific bar when hovering it."],
				order = 10,
				type = "toggle", width = "full",
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			fadeInCombat = {
				name = L["Only show on mouseover"],
				desc = L["Enable this to only show faded bars on mouseover, and not force them visible in combat."],
				-- 11, matching GenerateBarOptions above. This read 10, the same order
				-- as fadeAlone, so their positions were being settled by an alphabetical
				-- tiebreak on the option key rather than by intent.
				order = 11,
				type = "toggle", width = "full",
				hidden = function(info) return isdisabled(info) or not getsetting(info, "enableBarFading") end,
				set = setter,
				get = getter
			},
			fadeFrom = {
				name = L["Start fading from"],
				desc = L["Choose which button to start the fading from."],
				order = 12,
				type = "range", width = "full", min = 1, max = maxButtons or 12, step = 1,
				hidden = function(info) return isdisabled(info) or not getsetting(info, "enableBarFading") end,
				set = setter,
				get = getter
			},
			layoutHeader = {
				name = L["Layout"],
				order = 18,
				type = "header",
				hidden = isdisabled
			},
			layoutDesc = {
				name = L["Choose how your bar is displayed."],
				order = 19,
				type = "description",
				fontSize = "medium",
				hidden = isdisabled
			},
			layout = {
				name = L["Bar layout"],
				desc = L["Choose the action bar layout type."],
				order = 20,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["grid"] = L["Grid layout"],
					["zigzag"] = L["Zigzag layout"],
				},
				set = setter,
				get = getter
			},
			startAt = {
				name = L["First zigzag button"],
				desc = L["Sets which button the zigzag pattern should begin at."],
				order = 21,
				type = "range", width = "full", min = 1, max = maxButtons or 12, step = 1,
				hidden = function(info) return isdisabled(info) or getsetting(info, "layout") ~= "zigzag" end,
				set = setter,
				get = getter
			},
			numbuttons = {
				name = L["Number of buttons"],
				desc = L["Sets the number of action buttons on the action bar."],
				order = 30,
				type = "range", width = "full", min = 0, max = maxButtons or 12, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			padding = {
				name = L["Button padding"],
				desc = L["Sets the padding between buttons on the same line."],
				order = 31,
				type = "range", width = "full", min = 0, max = 16, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			breakpadding = {
				name = L["Line padding"],
				desc = L["Sets the padding between multiple lines of buttons."],
				order = 32,
				type = "range", width = "full", min = 0, max = 16, step = 1,
				hidden = isdisabled,
				set = setter,
				get = getter
			},
			breakpoint = {
				name = L["Line break"],
				desc = L["Sets when a new line of buttons should begin."],
				order = 40,
				type = "range", width = "full", min = 1, max = maxButtons or 12, step = 1,
				hidden = function(info) return isdisabled(info) or getsetting(info, "layout") ~= "grid" end,
				set = setter,
				get = getter
			},
			growth = {
				name = L["Initial growth"],
				desc = L["Choose whether the bar initially should expand horizontally or vertically."],
				order = 50,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["horizontal"] = L["Horizontal layout"],
					["vertical"] = L["Vertical layout"],
				},
				set = setter,
				get = getter
			},
			growthSpace = {
				name = "", order = 51, type = "description",
				hidden = isdisabled
			},
			growthHorizontal = {
				name = L["Horizontal growth"],
				desc = L["Choose which horizontal direction the bar should expand in."],
				order = 52,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["RIGHT"] = L["Right"],
					["LEFT"] = L["Left"],
				},
				set = setter,
				get = getter
			},
			growthVertical = {
				name = L["Vertical growth"],
				desc = L["Choose which vertical direction the bar should expand in."],
				order = 53,
				type = "select", style = "dropdown",
				hidden = isdisabled,
				values = {
					["DOWN"] = L["Down"],
					["UP"] = L["Up"],
				},
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
	return options
end

local GenerateKeybindModeOption = function()
	return {
		name = L["Keybind mode"],
		desc = L["Hover any action button and press a key to bind it. Press Escape to clear the binding, and Enter or Escape outside a button to finish."],
		order = 3,
		type = "execute",
		hidden = function(info) return not LibStub("LibKeyBound-1.0", true) end,
		disabled = function(info) return InCombatLockdown() end,
		func = function(info)
			if InCombatLockdown() then return end
			local KeyBound = LibStub("LibKeyBound-1.0", true)
			if (not KeyBound) then return end
			-- The options window sits on top of the bars, so it has to
			-- go away before there is anything to hover.
			local options = ns:GetModule("Options", true)
			if (options and options.CloseOptionsMenu) then
				options:CloseOptionsMenu()
			end
			KeyBound:Toggle()
		end
	}
end

-- Independent quest settings remain available when native bars own the action bars.
local GenerateQuestItemButtonOptions = function()
	local quest = ns:GetModule("QuestItemButton", true)
	if (quest and quest.db) then
		local qget = function(info) return quest.db.profile[info[#info]] end
		local qset = function(info, val) quest.db.profile[info[#info]] = val; quest:UpdateSettings() end
		local qoff = function() return not quest.db.profile.enabled or quest:IsStandingDown() end
		local nativeBars = function() return ns.NativeController and ns.NativeController.IsActive() end
		local group = {
			name = L["Quest Item Button"], order = 72, type = "group",
			args = {
				description = {
					name = function()
						if nativeBars() then
							return L["Native controller bars keep the Extra Action Button key. Assign this button its own key with Keybind Mode."]
						end
						return L["One button for the usable item of your nearest quest, styled as the extra action button. Move it with /lock. Bind it with Keybind Mode on this page, or leave it unbound to use your Extra Action Button key while no extra action is up."]
					end,
					type = "description", fontSize = "medium", order = 0
				},
				rival = {
					name = function() return string_format(L["%s is enabled, so this button stays off until you choose which of the two to use."], ns.API.GetAddOnTitle("ExtraQuestButton")) end,
					type = "description", fontSize = "medium", order = 0.5,
					hidden = function() return not quest:IsStandingDown() end
				},
				chooseAgain = {
					name = L["Choose again"], type = "execute", order = 0.6,
					hidden = function() return not quest:HasRival() end,
					func = function() quest:PromptRivalChoice() end
				},
				enabled = {
					name = L["Enable"], type = "toggle", order = 1, width = "full",
					disabled = function() return quest:IsStandingDown() end,
					get = qget, set = qset
				},
				trackedOnly = {
					name = L["Only tracked quests"],
					desc = L["Only offer items for quests you track, world quests and bonus objectives. Off, any quest in your log with an objective on this map counts."],
					type = "toggle", order = 2, width = "full", disabled = qoff, get = qget, set = qset
				},
				zoneOnly = {
					name = L["Only quests in this zone"], type = "toggle", order = 3, width = "full",
					disabled = qoff, get = qget, set = qset
				},
				maxDistance = {
					name = L["Maximum distance (yards)"], type = "range", order = 4, width = "full",
					min = 25, max = 5000, softMax = 2000, step = 25,
					disabled = qoff, get = qget, set = qset
				},
				useExtraActionKey = {
					name = L["Use the extra action button key"],
					desc = L["While the button has no key of its own, it borrows the key bound to the Extra Action Button. A Blizzard extra action takes the key back for as long as it is up."],
					type = "toggle", order = 5, width = "full", get = qget,
					disabled = function() return qoff() or nativeBars() end,
					set = function(info, val) if not nativeBars() then qset(info, val) end end
				},
				showQuestInTooltip = {
					name = L["Show the quest in the tooltip"], type = "toggle", order = 6, width = "full",
					disabled = qoff, get = qget, set = qset
				},
				onlyShowOnMouseover = {
					name = L["Only show on mouseover"], type = "toggle", order = 7, width = "full",
					disabled = qoff, get = qget, set = qset
				}
			}
		}
		if (ns.OptionsKit and ns.OptionsKit.Defaults) then
			ns.OptionsKit.Defaults.Bind(group, "QuestItemButton")
		end
		return group
	end
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local setter = function(info,val)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		db[info[#info]] = val
		getmodule():UpdateSettings()
	end

	local getter = function(info)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[info[#info]]
	end

	local isdisabled = function(info)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return info[#info] ~= "enabled" and not db.enabled
	end

	local getsetting = function(info, setting)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[setting]
	end

	local setoption = function(info,option,val)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		db[option] = val
		getmodule():UpdateSettings()
	end

	local getoption = function(info,option)
		local id = tonumber((string_match(info[#info - 1],"(%d+)")))
		local db = getmodule().db.profile
		return db[option]
	end

	local options = {
		name = L["Action Bars"],
		type = "group", childGroups = "tree",
		args = {
			description = {
				name = L["ActionBars are banks of hotkeys that allow you to quickly access abilities and inventory items. Here you can activate additional ActionBars and control their behaviors."],
				type = "description",
				fontSize = "medium",
				order = 0
			},
			hideElementsHotkey = {
				name = L["Hide hotkeys"],
				desc = L["Hides Hotkeys from the actionbuttons."],
				order = 1,
				type = "toggle", width = "full",
				set = function(info, val)
					getmodule().db.profile.hideElements.hotkey = val
					getmodule():UpdateSettings()
					local pet = ns:GetModule("PetBar", true)
					if (pet) then
						pet:UpdateSettings()
					end
					local stance = ns:GetModule("StanceBar", true)
					if (stance) then
						stance:UpdateSettings()
					end
				end,
				get = function(info) return getmodule().db.profile.hideElements.hotkey end
			},
			clickOnDown = {
				name = L["Cast action keybinds on key down"],
				desc = L["Cast action keybinds on key down"],
				order = 2,
				type = "toggle", width = "full",
				set = function(info, val)
					if (ns.WoW10 and not InCombatLockdown()) then
						if (C_CVar and C_CVar.SetCVar) then
							C_CVar.SetCVar("ActionButtonUseKeyDown", val and "1" or "0")
						elseif SetCVar then
							SetCVar("ActionButtonUseKeyDown", val and "1" or "0")
						end
					end
					setter(info,val)
					local pet = ns:GetModule("PetBar", true)
					if (pet) then
						pet:UpdateSettings()
					end
					local stance = ns:GetModule("StanceBar", true)
					if (stance) then
						stance:UpdateSettings()
					end
				end,
				get = function(info)
					if (ns.WoW10) then
						if (C_CVar and C_CVar.GetCVarBool) then
							return C_CVar.GetCVarBool("ActionButtonUseKeyDown")
						elseif GetCVarBool then
							return GetCVarBool("ActionButtonUseKeyDown")
						end
					end
					return getter(info)
				end
			},
			useCommandBindingsForHoldCast = {
				name = L["Use command bindings for hold cast"],
				desc = L["Route keybinds through Blizzard action commands first, with click-binding fallback. Recommended for press-and-hold behavior."],
				order = 2.1,
				type = "toggle", width = "full",
				hidden = function() return not ns.WoW10 end,
				set = function(info, val)
					setoption(info, "UseCommandBindingsForHoldCast", val)
					local pet = ns:GetModule("PetBar", true)
					if (pet) then
						pet:UpdateSettings()
					end
					local stance = ns:GetModule("StanceBar", true)
					if (stance) then
						stance:UpdateSettings()
					end
				end,
				get = function(info)
					local module = getmodule()
					if (not module or not module.db or not module.db.profile) then
						return ns.WoW10 and true or false
					end
					local value = module.db.profile.UseCommandBindingsForHoldCast
					if (value == nil) then
						return ns.WoW10 and true or false
					end
					return value and true or false
				end
			},
			-- The bars have carried LibKeyBound targets on every button for as
			-- long as they have existed, and the library registers /kb itself,
			-- so this button only surfaces behaviour that already shipped.
			keybindMode = GenerateKeybindModeOption(),
			showEmptyButtons = {
				name = L["Show empty buttons"],
				desc = L["Show the empty slots on your action bars as blank buttons. Turn this off to show only the buttons you have actually put something on. Empty buttons fade with the rest of the bar when bar fading is enabled."],
				order = 4,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			dimWhenInactive = {
				name = L["Dim the actionbuttons when inactive"],
				desc = L["Dim down and desaturate your action buttons when not engaged in combat and not currently targeting anything."],
				order = 5,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			dimWhenResting = {
				name = L["Only dim the actionbuttons when resting"],
				desc = L["This restricts the dimming to when the player is resting."],
				order = 6,
				type = "toggle", width = "full",
				hidden = function(info) return not getsetting(info, "dimWhenInactive") end,
				set = setter,
				get = getter
			},
			extraButtonShape = ShapeOption(L["Extra button shape"],
				L["Choose the shape of the extra action and zone ability buttons. Circle is the intended AzeriteUI design. Changing this asks you to reload."],
				7, nil, getter, function(info, val)
					getmodule().db.profile.extraButtonShape = val
				end),
			-- Components/ActionBars/Compatibility/Masque.lua. Listed only while Masque is
			-- loaded; read once per session, so a change offers a reload.
			masque = {
				name = L["Let Masque skin the buttons"],
				desc = L["Hand the action, pet and stance buttons to Masque, so its skins replace AzeriteUI's own button art. Pick the skin in Masque's settings under AzeriteUI. Button shapes do not apply while this is on. Changing this asks you to reload."],
				order = 8,
				type = "toggle", width = "full",
				hidden = function(info)
					return not (ns.ActionBarMasque and ns.ActionBarMasque.IsAvailable())
				end,
				set = function(info, val)
					if ((getter(info) and true or false) == (val and true or false)) then return end
					getmodule().db.profile.masque = val and true or false
					local key = "AZERITEUI_ACTIONBAR_MASQUE_RELOAD"
					if (ns.API.PopupDialogs and not ns.API.PopupDialogs[key]) then
						ns.API.PopupDialogs[key] = {
							text = L["Masque takes over the buttons, or hands them back, when the interface loads. Reload now?"],
							button1 = L["Reload UI"],
							button2 = _G.CANCEL or "Cancel",
							OnAccept = function() ReloadUI() end,
							timeout = 0,
							whileDead = true,
							hideOnEscape = true,
							preferredIndex = 3
						}
					end
					if (ns.API.ShowPopup) then ns.API.ShowPopup(key) end
				end,
				get = getter
			},
		}
	}

	for id = 1,ns.IsRetail and 8 or 5 do
		if (getmodule().bars and getmodule().bars[id]) then
			options.args["bar"..id] = GenerateIndexedBarOptions("ActionBars", string_format(L["Action Bar %d"], id), 100 + id*10)
		end
	end

	options.args["petbar"] = GenerateBarOptions("PetBar", L["Pet Bar"], 200, NUM_PET_ACTION_SLOTS)

	local procDisabled = function() return getmodule().db.profile.procHighlightStyle == "off" end
	options.args.procHighlight = {
		name = L["Proc Highlight"], order = 70, type = "group",
		args = {
			description = {
				name = L["Style ability proc alerts on all AzeriteUI action bars. Assisted combat suggestions use their own highlight. Changes apply without reloading."],
				type = "description", fontSize = "medium", order = 0
			},
			procHighlightStyle = {
				name = L["Highlight style"], type = "select", order = 1,
				values = { current = L["Current ring"], outline = L["Solid outline"], glow = L["Soft glow"], both = L["Outline + glow"], off = L["Off"] },
				sorting = { "current", "outline", "glow", "both", "off" },
				set = setter, get = getter
			},
			procHighlightThickness = {
				name = L["Thickness"], type = "select", order = 2,
				values = { thin = L["Thin"], medium = L["Medium"], thick = L["Thick"] },
				sorting = { "thin", "medium", "thick" },
				disabled = function() return procDisabled() or getmodule().db.profile.procHighlightStyle == "current" end,
				set = setter, get = getter
			},
			procHighlightColorSource = {
				name = L["Color source"], type = "select", order = 3,
				values = { gold = L["Default gold"], class = L["Class color"], custom = L["Custom color"] },
				sorting = { "gold", "class", "custom" },
				disabled = procDisabled, set = setter, get = getter
			},
			procHighlightColor = {
				name = L["Custom color"], type = "color", order = 4,
				hidden = function() return getmodule().db.profile.procHighlightColorSource ~= "custom" end,
				disabled = procDisabled,
				get = function()
					return ns.ActionBarProcHighlight.GetCustomColor(getmodule().db.profile)
				end,
				set = function(info, r, g, b)
					-- Per-setting revert supplies its default as one table.
					if (type(r) == "table") then r, g, b = r[1], r[2], r[3] end
					getmodule().db.profile.procHighlightColor = { r, g, b }
					getmodule():UpdateSettings()
				end
			},
			procHighlightOpacity = {
				name = L["Opacity"], type = "range", order = 5,
				min = 0, max = 1, step = .05, isPercent = true,
				disabled = procDisabled, set = setter, get = getter
			},
			preview = {
				name = L["Preview proc highlight"], type = "execute", order = 6,
				func = function() ns.ActionBarProcHighlight.Preview(getmodule().db.profile) end
			},
			reset = {
				name = L["Reset proc highlight"], type = "execute", order = 7,
				func = function()
					for key, value in pairs(ns.ActionBarProcHighlight.defaults) do
						getmodule().db.profile[key] = type(value) == "table" and ns:Copy(value) or value
					end
					getmodule():UpdateSettings()
				end
			}
		}
	}
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options.args.procHighlight, "ActionBars")
	end

	-- The assisted combat suggestion, styled the same way as the proc glow but with
	-- settings of its own, so the two stay told apart. Its "current" look is the
	-- neutral glow it has always had, so any colour reads true on it.
	local Assisted = ns.ActionBarAssistedHighlight
	local assistedDisabled = function() return getmodule().db.profile.assistedHighlightStyle == "off" end
	options.args.assistedHighlight = {
		name = L["Assisted Combat Highlight"], order = 71, type = "group",
		args = {
			description = {
				name = L["Style the glow on the ability Blizzard's assisted combat suggests next, on all AzeriteUI action bars. It keeps its own settings, so a suggestion and a proc can still be told apart. Changes apply without reloading."],
				type = "description", fontSize = "medium", order = 0
			},
			assistedHighlightStyle = {
				name = L["Highlight style"], type = "select", order = 1,
				values = { current = L["Current glow"], outline = L["Solid outline"], glow = L["Soft glow"], both = L["Outline + glow"], off = L["Off"] },
				sorting = { "current", "outline", "glow", "both", "off" },
				set = setter, get = getter
			},
			assistedHighlightThickness = {
				name = L["Thickness"], type = "select", order = 2,
				values = { thin = L["Thin"], medium = L["Medium"], thick = L["Thick"] },
				sorting = { "thin", "medium", "thick" },
				disabled = function() return assistedDisabled() or getmodule().db.profile.assistedHighlightStyle == "current" end,
				set = setter, get = getter
			},
			assistedHighlightColorSource = {
				name = L["Color source"], type = "select", order = 3,
				values = { default = L["Default blue"], class = L["Class color"], custom = L["Custom color"] },
				sorting = { "default", "class", "custom" },
				disabled = assistedDisabled, set = setter, get = getter
			},
			assistedHighlightColor = {
				name = L["Custom color"], type = "color", order = 4,
				hidden = function() return getmodule().db.profile.assistedHighlightColorSource ~= "custom" end,
				disabled = assistedDisabled,
				get = function()
					return Assisted.GetCustomColor(getmodule().db.profile)
				end,
				set = function(info, r, g, b)
					-- Per-setting revert supplies its default as one table.
					if (type(r) == "table") then r, g, b = r[1], r[2], r[3] end
					getmodule().db.profile.assistedHighlightColor = { r, g, b }
					getmodule():UpdateSettings()
				end
			},
			assistedHighlightOpacity = {
				name = L["Opacity"], type = "range", order = 5,
				min = 0, max = 1, step = .05, isPercent = true,
				disabled = assistedDisabled, set = setter, get = getter
			},
			preview = {
				name = L["Preview assisted highlight"], type = "execute", order = 6,
				func = function() Assisted.Preview(getmodule().db.profile) end
			},
			reset = {
				name = L["Reset assisted highlight"], type = "execute", order = 7,
				func = function()
					for key, value in pairs(Assisted.defaults) do
						getmodule().db.profile[key] = type(value) == "table" and ns:Copy(value) or value
					end
					getmodule():UpdateSettings()
				end
			}
		}
	}
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options.args.assistedHighlight, "ActionBars")
	end

	local stanceBarOptions = GenerateBarOptions("StanceBar", L["Stance Bar"], 210, GetNumShapeshiftForms())

	-- Only configure StanceBar options if the module exists and is not disabled
	if stanceBarOptions then
		for _,opt in next,{ "fadeFrom", "startAt", "numbuttons", "breakpoint" } do
			local getter = stanceBarOptions.args[opt].get
			stanceBarOptions.args[opt].get = function(info)
				return math_min(getter(info), stanceBarOptions.args[opt].max)
			end
		end

		for i,v in next,stanceBarOptions.args do
			if (i ~= "enabled") then
				local ishidden = v.hidden
				v.hidden = function(info)
					return (GetNumShapeshiftForms() == 0) or ishidden(info)
				end
			end
		end
	end

	local updater = CreateFrame("Frame")
	updater:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	updater:RegisterEvent("PLAYER_ENTERING_WORLD")
	updater:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	updater:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	updater:SetScript("OnEvent", function()
		if stanceBarOptions then
			local numStances = GetNumShapeshiftForms()
			stanceBarOptions.args.fadeFrom.max = numStances
			stanceBarOptions.args.startAt.max = numStances
			stanceBarOptions.args.numbuttons.max = numStances
			stanceBarOptions.args.breakpoint.max = numStances
		end
	end)

	options.args["stancebar"] = stanceBarOptions

	-- The micro menu has its own page (OptionsPages/MicroMenu.lua) and the dismount
	-- button, which follows the minimap, sits on the Minimap page.

	return options
end

Options:AddGroup("Action Bars", function()
	local options = GenerateOptions()
	local quest = GenerateQuestItemButtonOptions()
	if quest then
		options = options or { name = L["Action Bars"], type = "group", args = {} }
		options.args.questItemButton = quest
		options.args.keybindMode = options.args.keybindMode or GenerateKeybindModeOption()
	end
	if ns.IsForever then
		options = options or { name = L["Action Bars"], type = "group", args = {} }
		-- First on the page, so the page's own rows after it need a heading of their own, or
		-- they read as part of it (Options Navigation Review 2026-11-22, B7).
		options.args.generalHeader = { name = L["General"], type = "header", order = .2 }
		options.args.nativeController = {
			name = L["Native Controller"], type = "group", order = .1,
			args = {
				description = {
					type = "description", fontSize = "medium", order = 1,
					name = function()
						if not ns.NativeController.IsAvailable() then
							return L["Native controller bars are unavailable on this client."]
						end
						local text = L["AzeriteUI automatically follows Blizzard's selected controller interface. Native mode keeps Blizzard's bars, party and raid targeting, menus and bag controls. Switch the game's interface mode and reload to return to your saved AzeriteUI layouts."]
						local conflict = ns.NativeController.GetConflict()
						if conflict then
							return text .. "\n\n" .. string_format(L["%s controls the action bars. Disable it and reload to use Blizzard's controller bars."], ns.API.GetAddOnTitle(conflict))
						end
						return text
					end
				},
				reload = {
					name = L["Reload UI"], type = "execute", order = 2,
					disabled = function() return InCombatLockdown() end,
					func = function() if not InCombatLockdown() then ReloadUI() end end
				}
			}
		}
		-- Only exists in a native session with Blizzard's bars in charge
		-- (Components/ActionBars/Elements/NativeGamepadSkin.lua). Textures and
		-- alpha only, so it switches live, in or out of combat.
		local skin = ns:GetModule("NativeGamepadSkin", true)
		if skin and skin.db then
			local args = options.args.nativeController.args
			args.skinDescription = {
				name = L["Draws AzeriteUI's backdrop and metal rings on Blizzard's controller buttons. Blizzard keeps their layout, pages and functions; move and scale the bars in Edit Mode."],
				type = "description", fontSize = "medium", order = 3
			}
			args.skinEnabled = {
				name = L["AzeriteUI button art"], type = "toggle", width = "full", order = 4,
				get = function() return skin.db.profile.enabled end,
				set = function(_, val) skin.db.profile.enabled = val; skin:UpdateSettings() end
			}
		end
	end
	return options
end, -9000, "bars", "ActionBars")

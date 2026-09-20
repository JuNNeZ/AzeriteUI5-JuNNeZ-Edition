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

local getmodule = function()
	local module = ns:GetModule("Minimap", true)
	return module
end

local isdisabled = function(info)
	return info[#info] ~= "enabled" and not getmodule().db.profile.enabled
end

-- The situation toggles only mean anything once auto-hide itself is on,
-- so grey them out rather than hide them. The list stays readable that way.
local isautohidedisabled = function(info)
	local profile = getmodule().db.profile
	return not profile.enabled or not profile.autoHideEnabled
end

local setAutoHide = function(key, value)
	local module = getmodule()
	module.db.profile[key] = value
	module:UpdateAutoHide()
end

local autoHideToggle = function(name, desc, order, key)
	return {
		name = name,
		desc = desc,
		order = order,
		type = "toggle",
		disabled = isautohidedisabled,
		hidden = key == "autoHideInArenas" and ns.IsForever or nil,
		set = function(info, val)
			setAutoHide(key, val)
		end,
		get = function(info)
			return getmodule().db.profile[key]
		end
	}
end

local setTextVisibility = function(key, value)
	local module = getmodule()
	module.db.profile[key] = value
	if (key == "hideAddonText") then
		module:UpdateAddonCompartmentVisibility()
	elseif (key == "hideClockText") then
		module:UpdateClockVisibility()
	end
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Minimap"],
		type = "group",
		args = {
			enabled = {
				name = L["Enable"],
				desc = L["Toggle whether to enable the Minimap or not."],
				order = 1,
				type = "toggle",
				width = "full",
				set = function(info, val)
					getmodule().db.profile.enabled = val
					getmodule():UpdateSettings()
				end,
				get = function(info)
					return getmodule().db.profile.enabled
				end
			},
			space1 = {
				name = "",
				order = 2,
				type = "description"
			},
			description = {
				name = L["When disabled, the Minimap will not be modified by AzeriteUI. When enabled, the Minimap will use the selected theme and positioning."],
				order = 3,
				type = "description",
				hidden = isdisabled
			},
			space2 = {
				name = "",
				order = 4,
				type = "description",
				hidden = isdisabled
			},
			hideAddonText = {
				name = L["Hide AddOn Text"],
				desc = L["Hide the custom AddOns label text next to the minimap button."],
				order = 5,
				type = "toggle",
				width = "full",
				hidden = isdisabled,
				set = function(info, val)
					setTextVisibility("hideAddonText", val)
				end,
				get = function(info)
					return getmodule().db.profile.hideAddonText
				end
			},
			hideClockText = {
				name = L["Hide Clock Text"],
				desc = L["Hide the AzeriteUI clock text displayed near the minimap/info area."],
				order = 6,
				type = "toggle",
				width = "full",
				hidden = isdisabled,
				set = function(info, val)
					setTextVisibility("hideClockText", val)
				end,
				get = function(info)
					return getmodule().db.profile.hideClockText
				end
			},
			dielEnabled = {
				name = L["Day and Night Indicator"],
				desc = L["Show Forever's day and night cycle on the edge of the minimap, where you can drag it around the ring and right-click it to set its distance from the map. When disabled, Blizzard's own indicator on the minimap cluster is shown instead."],
				order = 7,
				type = "toggle",
				width = "full",
				-- Only Forever has a day and night cycle to indicate.
				hidden = function(info)
					return isdisabled(info) or not ns.IsForever
				end,
				set = function(info, val)
					getmodule().db.profile.dielEnabled = val
					getmodule():UpdateDiel()
				end,
				get = function(info)
					return getmodule().db.profile.dielEnabled
				end
			},
			autoHide = {
				name = L["Auto-Hide"],
				order = 8,
				type = "group",
				inline = true,
				hidden = isdisabled,
				args = {
					autoHideEnabled = {
						name = L["Hide the Minimap Automatically"],
						desc = L["Hide the minimap while you are in the content selected below, and bring it back as soon as you leave it."],
						order = 1,
						type = "toggle",
						width = "full",
						set = function(info, val)
							setAutoHide("autoHideEnabled", val)
						end,
						get = function(info)
							return getmodule().db.profile.autoHideEnabled
						end
					},
					space1 = {
						name = "",
						order = 2,
						type = "description"
					},
					autoHideInArenas = autoHideToggle(
						L["Arenas"],
						L["Hide the minimap while you are in an arena match."],
						3, "autoHideInArenas"),
					autoHideInBattlegrounds = autoHideToggle(
						L["Battlegrounds"],
						L["Hide the minimap while you are in a battleground."],
						4, "autoHideInBattlegrounds"),
					autoHideInDungeons = autoHideToggle(
						L["Dungeons"],
						L["Hide the minimap while you are in a dungeon."],
						5, "autoHideInDungeons"),
					autoHideInRaids = autoHideToggle(
						L["Raid Instances"],
						L["Hide the minimap while you are in a raid instance."],
						6, "autoHideInRaids")
				}
			},
			space3 = {
				name = "",
				order = 9,
				type = "description",
				hidden = isdisabled
			},
			restoreBlizzard = {
				name = L["Restore Blizzard Default"],
				desc = L["Restore the default Blizzard minimap theme and positioning."],
				order = 10,
				type = "execute",
				hidden = isdisabled,
				func = function(info)
					getmodule().db.profile.enabled = true
					getmodule().db.profile.theme = "Blizzard"
					-- Reset to top-right corner (Blizzard default)
					local effectiveScale = ns.API.GetEffectiveScale()
					getmodule().db.profile.savedPosition = {
						scale = effectiveScale,
						[1] = "TOPRIGHT",
						[2] = 0,
						[3] = 0
					}
					getmodule():SetTheme("Blizzard")
					getmodule():UpdatePositionAndScale()
					getmodule():UpdateAnchor()
					getmodule():UpdateSettings()
				end
			}
		}
	}

	return options
end

Options:AddGroup(L["Minimap"], GenerateOptions, -3000, "world", "Minimap")

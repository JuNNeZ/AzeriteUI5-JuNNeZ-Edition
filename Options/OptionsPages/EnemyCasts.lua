--[[

	The MIT License (MIT)

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

-- Components/Misc/EnemyCasts.lua: the movable list of enemy casts. Off by default.
local getmodule = function()
	local module = ns:GetModule("EnemyCasts", true)
	if (module and module:IsEnabled() and module.db and module.db.profile) then
		return module
	end
end

local setter = function(info, val)
	getmodule().db.profile[info[#info]] = val
	getmodule():UpdateSettings()
end

local getter = function(info)
	return getmodule().db.profile[info[#info]]
end

local isoff = function()
	return not getmodule().db.profile.enabled
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Enemy Casts"],
		type = "group",
		args = {
			description = {
				name = L["A list you can move of the spells enemies are casting: the spell and its time, the caster with its raid marker, and who the spell is aimed at. Your target's cast is marked in gold. Out of combat, click a cast to target its caster. Move it with /lock."],
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			enabled = {
				name = L["Enable"],
				desc = L["Turn this part of AzeriteUI on or off."],
				order = 10,
				type = "toggle", width = "full",
				set = setter,
				get = getter
			},
			-- Not a saved setting: shows example casts on the list's spot while you change things.
			preview = {
				name = L["Preview"],
				desc = L["Shows example casts where the list sits, so every change shows at once. It turns off in combat and when this window closes."],
				order = 15,
				type = "toggle", width = "full",
				disabled = function() return isoff() or InCombatLockdown() end,
				set = function(info, val) getmodule():SetPreviewShown(val) end,
				get = function(info) return getmodule():IsPreviewShown() end
			},
			mode = {
				name = L["Show casts from"],
				desc = L["All enemies lists every enemy with a nameplate, plus your target, focus, bosses and arena opponents. My target only shows just your target's cast."],
				order = 20,
				type = "select", width = "full",
				values = {
					all = L["All enemies"],
					target = L["My target only"]
				},
				disabled = isoff,
				set = setter,
				get = getter
			},
			showSpellTarget = {
				name = L["Show who the spell is aimed at"],
				desc = L["The name of the spell's target beside the caster, in its class color. A red edge still marks spells aimed at you."],
				order = 30,
				type = "toggle", width = "full",
				disabled = isoff,
				set = setter,
				get = getter
			},
			maxRows = {
				name = L["Most casts shown"],
				desc = L["How many casts the list shows at once. The oldest casts come first."],
				order = 40,
				type = "range", width = "full", min = 1, max = 15, step = 1,
				disabled = function() return isoff() or getmodule().db.profile.mode == "target" end,
				set = setter,
				get = getter
			},
			previewCasts = {
				name = L["Preview casts"],
				desc = L["How many example casts the preview shows in /lock and Edit Mode while no enemy is casting, so you can see where a full list sits."],
				order = 45,
				type = "range", width = "full", min = 1, max = 15, step = 1,
				disabled = isoff,
				set = setter,
				get = getter
			},
			width = {
				name = L["Width"],
				desc = L["How wide the list is."],
				order = 50,
				type = "range", width = "full", min = 160, max = 500, step = 10,
				disabled = isoff,
				set = setter,
				get = getter
			},
			growUp = {
				name = L["Grow upwards"],
				desc = L["New casts are added above the first one instead of below."],
				order = 60,
				type = "toggle", width = "full",
				disabled = isoff,
				set = setter,
				get = getter
			}
		}
	}

	-- Lets the panel mark settings that differ from their defaults.
	if (ns.OptionsKit and ns.OptionsKit.Defaults) then
		ns.OptionsKit.Defaults.Bind(options, "EnemyCasts")
	end
	return options
end

Options:AddGroup("Enemy Casts", GenerateOptions, -6900, "frames", "EnemyCasts")

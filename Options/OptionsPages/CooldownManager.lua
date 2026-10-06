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

-- Components/ActionBars/Elements/CooldownManager.lua. Fading lives on the
-- Explorer Mode page with every other faded element.
local getmodule = function()
	local module = ns:GetModule("CooldownManager", true)
	if (module and module:IsEnabled()) then
		return module
	end
end

local setter = function(info,val)
	getmodule().db.profile[info[#info]] = val
	getmodule():UpdateSettings()
end

local getter = function(info)
	return getmodule().db.profile[info[#info]]
end

-- The folder name of an addon styling the Cooldown Manager instead, if any.
local getrival = function()
	local rival = getmodule():GetRival()
	return type(rival) == "string" and rival or nil
end

-- The folder name of an addon AzeriteUI styles alongside, as the player chose, if any.
local getshared = function()
	local shared = getmodule():GetSharedWith()
	return type(shared) == "string" and shared or nil
end

local isunstyled = function(info)
	return not getmodule().db.profile.styleIcons or getrival() ~= nil
end

-- Theme names as the Themes page writes them: the class name, marked while the
-- theme is still a work in progress.
local CLASS_TOKENS = { mage = "MAGE", hunter = "HUNTER", paladin = "PALADIN" }
local SkinLabel = function(key)
	if (key == "theme") then return L["Follow the interface theme"] end
	if (key == "azerite") then return "AzeriteUI" end
	local token = CLASS_TOKENS[key]
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local name = (names and token and names[token]) or key
	return name .. " (WIP)"
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = L["Cooldown Manager"],
		type = "group",
		args = {
			description = {
				name = L["AzeriteUI styles Blizzard's Cooldown Manager in place. Its position, size, padding and opacity stay in Edit Mode, and Explorer Mode can fade it with the rest of the interface."],
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			rival = {
				name = function()
					return string.format(L["%s is styling the Cooldown Manager, so AzeriteUI leaves it alone."], getrival() or "")
				end,
				order = 2,
				type = "description",
				fontSize = "medium",
				hidden = function() return getrival() == nil end
			},
			shared = {
				name = function()
					return string.format(L["AzeriteUI and %s both style the Cooldown Manager, as you chose. This combination is not supported."], getshared() or "")
				end,
				order = 3,
				type = "description",
				fontSize = "medium",
				hidden = function() return getshared() == nil end
			},
			choose = {
				name = L["Choose again"],
				desc = L["Ask again which addon styles the Cooldown Manager."],
				order = 4,
				type = "execute",
				func = function() getmodule():PromptRivalChoice() end,
				hidden = function() return getrival() == nil and getshared() == nil end
			},
			styleIcons = {
				name = L["Style the Cooldown Manager"],
				desc = L["AzeriteUI borders, masks and fonts on the icons and bars Blizzard draws. Turn it off for Blizzard's own look."],
				order = 10,
				type = "toggle", width = "full",
				disabled = function() return getrival() ~= nil end,
				set = setter,
				get = getter
			},
			iconStyle = {
				name = L["Icon style"],
				desc = L["Square and rounded wear AzeriteUI's square metal border. Circular wears the action bar ring."],
				order = 11,
				type = "select", style = "dropdown",
				values = {
					square = L["Square"],
					rounded = L["Rounded"],
					circular = L["Circular"]
				},
				sorting = { "square", "rounded", "circular" },
				disabled = isunstyled,
				set = setter,
				get = getter
			},
			skin = {
				name = L["Skin"],
				desc = L["Give the Cooldown Manager a theme of its own, whatever the rest of the interface wears. It changes the circular ring; square and rounded wear AzeriteUI art in every skin until themes have square art."],
				order = 11.5,
				type = "select", style = "dropdown",
				values = function()
					local values = {}
					for _, key in ipairs(getmodule():GetSkinChoices()) do
						values[key] = SkinLabel(key)
					end
					return values
				end,
				sorting = function()
					return getmodule():GetSkinChoices()
				end,
				disabled = isunstyled,
				set = setter,
				get = function(info)
					return getmodule():GetSkin()
				end
			},
			showKeybinds = {
				name = L["Show keybinds"],
				desc = L["The key bound to each ability on your AzeriteUI action bars, in the corner of its icon. Abilities not on a bar show none."],
				order = 12,
				type = "toggle", width = "full",
				disabled = isunstyled,
				set = setter,
				get = getter
			}
		}
	}

	return options
end

Options:AddGroup(L["Cooldown Manager"], GenerateOptions, -8900, "bars", "CooldownManager")

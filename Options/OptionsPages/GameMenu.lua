--[[

	The MIT License (MIT)

	Copyright (c) 2026

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))
local Options = ns:GetModule("Options")

-- GLOBALS: MAINMENU_BUTTON

local GAME_MENU = MAINMENU_BUTTON or "Game Menu"

local getmodule = function()
	return ns:GetModule("GameMenuSkin", true)
end

local GenerateOptions = function()
	if (not getmodule()) then return end

	local options = {
		name = GAME_MENU,
		type = "group",
		args = {
			description = {
				name = L["AzeriteUI restyles the game menu you open with Escape. If another addon restyles it too, AzeriteUI asks which one you want to keep when you open the menu."],
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			style = {
				name = L["Game Menu Style"],
				desc = L["Choose which addon styles the game menu. Changing this reloads the interface."],
				order = 2,
				type = "select", style = "dropdown",
				values = function(info)
					return getmodule():GetStyleChoices()
				end,
				-- Nothing is saved here. The module asks for a reload first, and the
				-- dropdown keeps showing the current style until the player accepts.
				set = function(info, val)
					getmodule():PromptStyleChange(val)
				end,
				get = function(info)
					return getmodule():GetStyle()
				end
			}
		}
	}

	return options
end

Options:AddGroup(GAME_MENU, GenerateOptions, -2400)

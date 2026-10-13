--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- /az -> Micro Menu, in the Interface band (Components/ActionBars/Elements/MicroMenu.lua).
-- It sat under Action Bars until the 2026-10-13 options cleanup; the cog, Blizzard's
-- strip and the bag button are menus, not action bars.
local getmicromenu = function()
	return ns:GetModule("MicroMenu", true)
end

local micromenusetting = function(key, fallback)
	local module = getmicromenu()
	local profile = module and module.db and module.db.profile
	if (not profile or profile[key] == nil) then
		return fallback
	end
	return profile[key] and true or false
end

local GenerateMicroMenuOptions = function()
	return {
		name = L["Micro Menu"],
		type = "group",
		args = {
			description = {
				name = L["The micro menu holds the buttons for your character sheet, spellbook, collections, group finder and the game menu. AzeriteUI replaces Blizzard's strip along the bottom of the screen with a cog wheel in the bottom right corner."],
				order = 0,
				type = "description",
				fontSize = "medium"
			},
			enabled = {
				name = L["Show AzeriteUI Cog Wheel"],
				desc = L["Show the AzeriteUI cog wheel in the bottom right corner. Clicking it opens the micro menu."],
				order = 1,
				type = "toggle", width = "full",
				set = function(info, val)
					local module = getmicromenu()
					if (not module or not module.db) then return end
					module.db.profile.enabled = val
					module:UpdateSettings()
				end,
				get = function(info) return micromenusetting("enabled", true) end
			},
			showBlizzardMicroMenu = {
				name = L["Show Blizzard's Micro Menu"],
				desc = L["Restore Blizzard's own micro menu along the bottom of the screen. This is independent of the cog wheel above, so you can use either or both."],
				order = 2,
				type = "toggle", width = "full",
				set = function(info, val)
					local module = getmicromenu()
					if (not module or not module.db) then return end
					module.db.profile.showBlizzardMicroMenu = val
					module:UpdateSettings()
				end,
				get = function(info) return micromenusetting("showBlizzardMicroMenu", false) end
			},
			reloadNote = {
				name = L["Both settings apply when the interface loads, so changing either one will ask you to reload."],
				order = 3,
				type = "description",
				fontSize = "medium"
			},
			showBagButton = {
				name = L["Show Bag Button"],
				desc = L["Show a bag button beside the cog wheel. Clicking it opens your bags, and the number on it is how many bag slots are free. This one applies at once."],
				order = 4,
				type = "toggle", width = "full",
				set = function(info, val)
					local module = getmicromenu()
					if (not module or not module.db) then return end
					module.db.profile.showBagButton = val
					module:UpdateSettings()
				end,
				get = function(info) return micromenusetting("showBagButton", true) end
			}
		}
	}
end

Options:AddGroup(L["Micro Menu"], function() return GenerateMicroMenuOptions() end, -5100, "interface", "MicroMenu")

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- What's New: the short notes shown in a popup after an update.
--
-- Written by hand, separately from CHANGELOG.md. The changelog is for reading;
-- this is three to five lines a player can act on, each with a button that
-- takes them to what changed. Options/Kit/WhatsNew.lua draws it.
--
-- Newest release first. The popup shows only the entry whose version matches
-- the installed "## Version:", so a release without an entry shows no popup at
-- all: leave small fixes out and nobody is interrupted for them.
--
-- Each item:
--   text    = one short line, plain English (the changelog is English too)
--   page    = the options page to open, as the key passed to Options:AddGroup
--             (most are localized: L["Action Bars"]; some are plain: "Auras")
--   section = optional, a section heading on that page, as it is drawn
--   run     = optional, a function to call instead of opening a page
--   label   = optional, the button text; defaults to "Show me"
-- An item with neither page nor run gets no button.
local Addon, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

local LegacyCommand = function(input)
	return function()
		local hud = ns:GetModule("LegacyHUD", true)
		if (hud and hud.Command) then hud:Command(input) end
	end
end

local OpenMovers = function()
	local manager = ns:GetModule("MovableFramesManager", true)
	if (manager and manager.OpenMFMFrame) then manager:OpenMFMFrame() end
end

ns.WhatsNew = {
	{
		version = "5.25.0-JuNNeZ",
		items = {
			{
				text = "Execute range has its own page: only enemies you fight, a lead before your execute, your own colours.",
				page = L["Execute range"]
			},
			{
				text = "Group frames can show who is Sated, and your buffs as dots in each frame's corners.",
				page = L["Group Frames"],
				section = L["Group Indicators"]
			},
			{
				text = "Aura Sounds: hear a sound when a buff or debuff is gained, stacks or fades (Retail).",
				page = L["Aura Sounds"]
			},
			{
				text = "Combat text works in dungeons again. The options window has scroll bars and section icons."
			}
		}
	},
	{
		version = "5.24.0-JuNNeZ",
		items = {
			{
				text = "Style the Assisted Highlight again: style, thickness, colour and opacity, with a preview.",
				page = L["Action Bars"],
				section = L["Assisted Combat Highlight"]
			},
			{
				text = "Party frames: choose how many auras per row, and party mana no longer looks full while a healer drinks.",
				page = L["Group Frames"],
				section = L["Party Frames"]
			},
			{
				text = "The options window has a rounded look with page icons. The old look is under Settings -> Appearance."
			},
			{
				text = "Legacy: the player frame can move to the centre while you have no target (Unit Frames -> Player).",
				page = L["Unit Frames"],
				section = L["Player"]
			}
		}
	},
	{
		version = "5.23.0-JuNNeZ",
		items = {
			{
				text = "Resize all of AzeriteUI at once: AzeriteUI Scale in the /lock window keeps your layout's proportions.",
				run = OpenMovers,
				label = "Open /lock"
			},
			{
				text = "Friendly players' names are no longer cut to one letter in dungeons and raids."
			},
			{
				text = "Legacy: raid role icons sit inside each frame, and spell highlights show on the buttons again."
			}
		}
	},
	{
		version = "5.22.0-JuNNeZ",
		items = {
			{
				text = "AzeriteUI's frames now show in Blizzard's Edit Mode and snap to edges, the grid and each other. /lock still works."
			},
			{
				text = "Square and Rounded buttons wear the Mage or Hunter border with those themes.",
				page = L["Action Bars"]
			},
			{
				text = "Mythic+: battle rez charges under the timer, and Blizzard's end banner can be hidden.",
				page = "MythicPlus"
			},
			{
				text = "Show each party member's Mythic+ rating on their frame (off by default).",
				page = L["Group Frames"],
				section = L["Party Frames"]
			}
		}
	},
	{
		version = "5.21.0-JuNNeZ",
		items = {
			{
				text = "This window now appears once after each update. Turn it off on the Changelog page."
			},
			{
				text = "Target auras no longer get cut off when they wrap onto more rows.",
				page = L["Unit Frames"],
				section = L["Target"]
			},
			{
				text = "Aura rows everywhere have even gaps, so every row lines up.",
				page = "Auras"
			},
			{
				text = "Legacy no longer draws an empty class power box for classes without one."
			}
		}
	},
	{
		version = "5.20.1-JuNNeZ",
		items = {
			{
				text = "Keybinds, stack counts and procs are visible again on Legacy action buttons.",
				run = LegacyCommand("legacy"),
				label = "/go legacy"
			},
			{
				text = "Proc Highlight style and colour now work under the Legacy HUD.",
				page = L["Action Bars"],
				section = L["Proc Highlight"]
			}
		}
	}
}

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

ns.WhatsNew = {
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

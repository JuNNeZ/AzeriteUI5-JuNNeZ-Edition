--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The options panel's own settings, and the changelog.
--
-- These are not settings for the interface. They are settings for the window
-- you are reading them in: what it is coloured with, how solid it is drawn,
-- where it sits. So they do not belong on a page among the unit frames and the
-- action bars, and they are not part of a profile either - they live in the
-- global section and never travel in an export string.
--
-- The table below is shaped exactly like an AceConfig options table, because
-- that is what the renderer draws. Nothing registers it with AceConfigRegistry:
-- it is ours, the panel reads it directly, and it never reaches the classic
-- dialog.
local Addon, ns = ...

-- Lua API
local ipairs = ipairs
local string_format = string.format
local type = type

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Kit = ns.OptionsKit

local PanelOptions = {}
Kit.PanelOptions = PanelOptions

--------------------------------------------------------------------------
-- Which band of the rail each page sits under
--------------------------------------------------------------------------
-- The pages on this tab carry no module, so there is nothing to ask. Two bands,
-- because a changelog is not a setting and should not be filed as one.
local sections = {
	appearance = "panel",
	changelog = "about"
}

PanelOptions.Section = function(key)
	return sections[key] or "panel"
end

PanelOptions.Bands = {
	{ key = "panel", label = L["Options Panel"] },
	{ key = "about", label = L["About"] }
}

--------------------------------------------------------------------------
-- Appearance
--------------------------------------------------------------------------
-- Both windows read the same kit, so both are re-skinned. Once Window.lua is
-- gone the second call goes with it.
local Reskin = function()
	if (Kit.Panel) then Kit.Panel:ApplyTheme() end
	if (Kit.Window) then Kit.Window:ApplyTheme() end
end

local appearance = {
	name = L["Appearance"],
	desc = L["How this window is drawn. These are kept outside your settings profiles, so switching profile never changes them and exporting one never carries them."],
	type = "group",
	order = 1,
	args = {
		theme = {
			name = L["Theme"],
			desc = L["Choose the colors the AzeriteUI options window is drawn with. Class Color follows the class of the character you are logged in on."],
			type = "select", style = "dropdown",
			order = 1,
			values = function()
				return (Kit.GetThemeChoices())
			end,
			sorting = function()
				local _, order = Kit.GetThemeChoices()
				return order
			end,
			get = function()
				return Kit.GetTheme()
			end,
			set = function(info, val)
				if (Kit.Panel and Kit.Panel.SetTheme) then
					Kit.Panel:SetTheme(val)
				else
					Kit.SetTheme(val)
					Reskin()
				end
			end
		},
		opacity = {
			name = L["Background Opacity"],
			desc = L["How solid the options window is drawn. This scales the opacity the chosen theme asks for; the borders keep their own, so the window never loses its edges."],
			type = "range",
			order = 2,
			isPercent = true,

			-- A percent slider that moves in twentieths reads as notched rather
			-- than smooth, and this one is dragged while watching the window
			-- behind it. One percent per step.
			min = 0.2, max = 1, step = 0.01,
			get = function()
				return Kit.GetOpacity()
			end,
			set = function(info, val)
				Kit.SetOpacity(val)

				if (ns.db and ns.db.global) then
					ns.db.global.optionsOpacity = Kit.GetOpacity()
				end

				Reskin()
			end
		},
		windowHeader = {
			name = L["Window"],
			type = "header",
			order = 10
		},
		scale = {
			name = L["Panel Scale"],
			desc = L["How large the options window is drawn, independently of the rest of the interface. Useful on a very high resolution display, where the window can otherwise be smaller than everything around it."],
			type = "range",
			order = 11,
			isPercent = true,
			min = 0.7, max = 1.4, step = 0.01,

			-- Written on release, not while dragging. Applying a scale rescales
			-- the window, which moves this very slider out from under the
			-- cursor; the knob then chases the cursor and the value runs away.
			commitOnRelease = true,
			get = function()
				return Kit.Panel and Kit.Panel:GetPanelScale() or 1
			end,
			set = function(info, val)
				if (Kit.Panel) then Kit.Panel:SetPanelScale(val) end
			end
		},
		reset = {
			name = L["Reset Position and Size"],
			desc = L["Puts the window back in the middle of the screen at its original size. Useful if it has been dragged somewhere you cannot reach."],
			type = "execute",
			order = 11,
			func = function()
				if (Kit.Panel and Kit.Panel.ResetGeometry) then
					Kit.Panel:ResetGeometry()
				end
			end
		}
	}
}

--------------------------------------------------------------------------
-- Changelog
--------------------------------------------------------------------------
-- One group per release, so each version becomes a heading on the page and an
-- entry in the rail beneath Changelog. The notes themselves are descriptions:
-- there is nothing to set, only something to read.
--
-- Built once, on the first request. The data is generated from CHANGELOG.md by
-- Tools/BuildChangelog.lua and does not change while the game is running.
local BuildChangelog = function()
	local args = {}

	if (type(ns.Changelog) ~= "table" or #ns.Changelog == 0) then
		args.missing = {
			name = L["The release notes are not available in this build."],
			type = "description",
			order = 1
		}
		return args
	end

	for index, release in ipairs(ns.Changelog) do
		local entries = {}
		local order = 0

		for _, group in ipairs(release.groups or {}) do
			if (group.kind and group.kind ~= "") then
				order = order + 1
				entries["kind" .. order] = {
					name = group.kind,
					type = "header",
					order = order
				}
			end

			for _, text in ipairs(group.items or {}) do
				order = order + 1
				entries["note" .. order] = {
					name = "- " .. text,
					type = "description",
					order = order
				}
			end
		end

		-- A release with a title reads better as "5.4.13 - What It Did".
		local name = release.version
		if (release.title and release.title ~= "") then
			name = string_format("%s - %s", release.version, release.title)
		end

		args["release" .. index] = {
			name = name,
			desc = release.date,
			type = "group",
			order = index,
			args = entries
		}
	end

	return args
end

local changelog
local Changelog = function()
	if (not changelog) then
		changelog = {
			name = L["Changelog"],
			type = "group",
			order = 2,
			args = BuildChangelog()
		}

		local total = ns.ChangelogTotal
		local shown = type(ns.Changelog) == "table" and #ns.Changelog or 0

		if (total and total > shown) then
			changelog.desc = string_format(
				L["The %d most recent releases. Everything older is in CHANGELOG.md."], shown)
		end
	end
	return changelog
end

--------------------------------------------------------------------------
-- The table
--------------------------------------------------------------------------
local table_
PanelOptions.GetTable = function()
	if (not table_) then
		table_ = {
			type = "group",
			childGroups = "tree",
			args = {
				appearance = appearance,
				changelog = Changelog()
			}
		}
	end
	return table_
end

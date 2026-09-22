--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- Pages that are not in the option table.
--
-- The rail lists the addon's own option pages. These two are gathered from the
-- settings on those pages instead: Quick Start, a short list of the settings
-- that change the most, and Changed, every setting that differs from its
-- default. Each row is drawn from the setting's real path with its own control,
-- gem and revert, so a setting behaves the same wherever it is shown.
--
-- No frames here. This decides which rows a view holds, and Renderer draws them.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config, Defaults, Renderer = Kit.Config, Kit.Defaults, Kit.Renderer
if (not Config or not Defaults or not Renderer) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local pcall = pcall
local type = type

local Views = {}
Kit.Views = Views

local APP = Addon

-- Keys an option table cannot produce, so a view never collides with a page.
Views.QUICKSTART = "@quickstart"
Views.CHANGED = "@changed"

-- What Quick Start shows, in order: the decisions that change the most about
-- how the interface looks and behaves, for someone opening this for the first
-- time. Named by the module whose profile holds the setting and the setting's
-- key, because a page's own key is its localized name and differs by client
-- language. `group` picks one sub-group where a module repeats a key, as every
-- action bar does with `enabled`; without it the shallowest match wins.
--
-- A setting hidden on this client, class or character is left out, not faked.
Views.QuickStart = {
	{ module = "ExplorerMode", key = "enabled" },
	{ module = "PlayerFrame", key = "powerOrbMode" },
	{ module = "ActionBars", group = "bar1", key = "layout" },
	{ module = "ActionBars", group = "bar2", key = "enabled" },
	{ module = "ActionBars", key = "dimWhenInactive" },
	{ module = "PartyFrames", key = "enabled" },
	{ module = "UnitFrames", key = "showIncomingHeals" },
	{ module = "NamePlates", key = "enabled" },
	{ module = "NamePlates", key = "nameplateScale" },
	{ module = "ChatFrames", key = "fadeOnInActivity" }
}

local HasKey = function(path, key)
	for _, value in ipairs(path) do
		if (value == key) then return true end
	end
	return false
end

-- The name a sub-group shows as its heading, for the trail.
local SectionName = function(group, options, pageKey, sectionKey)
	local section = Config.GetSubOption(group, sectionKey)
	if (type(section) ~= "table" or section.type ~= "group") then return end

	local ok, name = pcall(Config.GetName, section, options, { pageKey, sectionKey }, APP)
	return (ok and type(name) == "string" and name ~= "") and name or nil
end

-- Every value setting the panel can draw, page by page, with the trail a
-- search result would show for it: "Action Bars > Action Bar 2". `pages` is
-- the rail's own list, so a view never reaches into a page the rail hides.
-- The trail comes from the setting's path rather than from the order headings
-- are met in, so a page-level setting sorted after a section is still filed
-- under its page.
local EachSetting = function(options, pages, callback)
	for _, entry in ipairs(pages or {}) do
		local pageKey = entry.key
		local group = Config.GetGroup(options, { pageKey })

		if (type(group) == "table") then
			local names = {}
			for _, item in ipairs(Renderer:Collect(group, options, { pageKey })) do
				if (item.option and item.kind ~= "execute") then
					local trail = entry.name
					local sectionKey = #item.path > 2 and item.path[2] or nil
					if (sectionKey) then
						if (names[sectionKey] == nil) then
							names[sectionKey] = SectionName(group, options, pageKey, sectionKey) or false
						end
						if (names[sectionKey]) then
							trail = entry.name .. " > " .. names[sectionKey]
						end
					end
					callback(item, trail)
				end
			end
		end
	end
end

Views.EachSetting = EachSetting

-- Rows for a list of settings, with a heading wherever the trail changes.
local WithHeadings = function(hits, major)
	local out, lastTrail = {}, nil
	for _, hit in ipairs(hits) do
		if (hit.trail ~= lastTrail) then
			out[#out + 1] = { kind = "header", major = major, label = hit.trail }
			lastTrail = hit.trail
		end
		out[#out + 1] = hit.item
	end
	return out
end

Views.CollectQuickStart = function(options, pages)
	local found = {}

	EachSetting(options, pages, function(item, trail)
		local moduleName = Defaults.ModuleNameFor(options, item.path)
		local key = item.path[#item.path]

		for index, wanted in ipairs(Views.QuickStart) do
			if (wanted.module == moduleName and wanted.key == key
				and (not wanted.group or HasKey(item.path, wanted.group))) then
				local best = found[index]
				if (not best or #item.path < #best.item.path) then
					found[index] = { item = item, trail = trail }
				end
			end
		end
	end)

	local hits = {}
	for index = 1, #Views.QuickStart do
		if (found[index]) then hits[#hits + 1] = found[index] end
	end

	-- Minor headings: a page this short needs no list of sections in the rail.
	return WithHeadings(hits, false)
end

-- Every setting that differs from its default. Asked again on every refresh,
-- so putting one back removes its row. Counted the same way the rail counts
-- (Defaults.IsModified over the settings the panel can draw), which the panel
-- harness holds it to.
Views.CollectChanged = function(options, pages)
	local hits = {}

	EachSetting(options, pages, function(item, trail)
		local ok, value = pcall(Config.GetValue, item.option, options, item.path, APP)
		if (ok and Defaults.IsModified(options, item.path, value) == true) then
			hits[#hits + 1] = { item = item, trail = trail }
		end
	end)

	local out = WithHeadings(hits, true)
	if (#out == 0) then
		out[1] = { kind = "description", label = L["Nothing here differs from its default."] }
	end
	return out, #hits
end

-- What each view looks like at the top of the page and in the rail. Changed is
-- not `listed`: it is reached from the count in the header, where the number
-- of changed settings already is.
local definitions = {
	[Views.QUICKSTART] = {
		key = Views.QUICKSTART,
		listed = true,
		band = "setup",
		name = L["Quick Start"],
		desc = L["The settings that change the most, gathered from every page. Each one is still on its own page as well."],
		collect = Views.CollectQuickStart
	},
	[Views.CHANGED] = {
		key = Views.CHANGED,
		listed = false,
		name = L["Changed from default"],
		crumb = L["Changed"],
		collect = Views.CollectChanged
	}
}

Views.Get = function(key)
	return definitions[key]
end

-- The views the rail lists, in order.
Views.Listed = function()
	return { definitions[Views.QUICKSTART] }
end

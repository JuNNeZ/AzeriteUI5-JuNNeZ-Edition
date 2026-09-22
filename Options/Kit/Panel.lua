--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The options window.
--
-- AzeriteUI draws all of this. AceConfigDialog is not involved: the option
-- tables are read by Config.lua, turned into rows by Renderer.lua out of the
-- controls in Controls.lua, and stacked inside the frame built here.
--
-- Laid out as the roadmap artifact draws it. A rail down the left, grouped into
-- bands rather than listed flat, because fifteen entries in one column is a list
-- you scan where five groups of three is a map you remember. Search across the
-- whole tree above it, with each result showing the page it lives on. The page
-- itself fills the rest.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Config = Kit.Config
local Renderer = Kit.Renderer
if (not Config or not Renderer) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

-- Lua API
local ipairs = ipairs
local max, min = math.max, math.min
local pcall = pcall
local string_find, string_lower = string.find, string.lower
local string_format = string.format
local table_insert = table.insert
local table_wipe = table.wipe or wipe
local tonumber, tostring, type = tonumber, tostring, type
local unpack = unpack

-- GLOBALS: CreateFrame, GameTooltip, InCombatLockdown, UIParent, UISpecialFrames
-- GLOBALS: C_AddOns

local Panel = {}
Kit.Panel = Panel

-- Which half of the window is showing. See TABS below.
Panel.tab = "options"

local APP = Addon

local DEFAULT_W, DEFAULT_H = 940, 720
local MIN_W, MIN_H = 800, 560
local RAIL_W = 196
local HEADER_H = 46
local SEARCH_H = 36
local FOOTER_H = 26
local PAGE_HEAD_H = 54

local TABSTRIP_H = 30

-- The footer's preview line runs from just left of the footer's centre to
-- near its right edge, on one line that does not wrap. At the smallest window
-- this is all the room an explanation gets, so the harness measures against it.
local FOOTER_INSET = 12
local PREVIEW_LEFT, PREVIEW_RIGHT = -80, -22
Panel.PreviewMinWidth = (MIN_W - FOOTER_INSET * 2) / 2 - PREVIEW_LEFT + PREVIEW_RIGHT

-- The two halves of the window, chosen at the bottom of the rail.
--
-- "Options" is everything the addon does. "Settings" is the window itself -
-- what it is coloured with, how solid it is drawn - plus the changelog. They
-- are different kinds of thing that happen to be reached the same way, and
-- putting the second among the first is how the theme picker ended up filed
-- under Profiles.
local TABS = {
	{ key = "options", label = L["Options"] },
	{ key = "settings", label = L["Settings"] }
}

-- The bands each tab's rail is grouped into, in the order they are shown.
local SECTIONS = {
	{ key = "setup", label = L["Setup"] },
	{ key = "frames", label = L["Frames"] },
	{ key = "bars", label = L["Bars"] },
	{ key = "world", label = L["World"] },
	{ key = "interface", label = L["Interface"] },
	{ key = "other", label = L["General"] }
}

local frame, rail, railScroll, railContent, contentScroll, pageContent, searchBox
local page
local railRows = {}

-- Results live on the page, not in the rail, so they get the full width.
local resultRows = {}

--------------------------------------------------------------------------
-- Option table access
--------------------------------------------------------------------------
-- The table the rail and the page are currently reading, and the module behind
-- it. The Settings tab has no module: its pages are the window's own, they
-- belong to no addon module, and nothing about them is part of a profile.
local GetOptions = function()
	if (Panel.tab == "settings") then
		return Kit.PanelOptions and Kit.PanelOptions.GetTable(), nil
	end

	if (not AceConfigRegistry or not AceConfigRegistry:GetOptionsTable(APP)) then return end

	local module = ns:GetModule("Options", true)
	return module and module:GetOptionsObject(), module
end

-- The bands of the current tab's rail.
local GetBands = function()
	if (Panel.tab == "settings") then
		return (Kit.PanelOptions and Kit.PanelOptions.Bands) or SECTIONS
	end
	return SECTIONS
end

local GetBand = function(key, module)
	if (Panel.tab == "settings") then
		return Kit.PanelOptions and Kit.PanelOptions.Section(key) or "panel"
	end
	return (module and module:GetSection(key)) or "other"
end

-- A page the option table does not have: Quick Start, or Changed. Only the
-- Options tab has them, since they are built from the addon's settings.
local GetView = function(key)
	if (Panel.tab ~= "options" or not Kit.Views) then return end
	return Kit.Views.Get(key)
end

local Resolve = function(value, fallback)
	if (type(value) == "function") then
		local ok, result = pcall(value)
		if (ok and result ~= nil) then return result end
		return fallback
	end
	if (value ~= nil) then return value end
	return fallback
end

--------------------------------------------------------------------------
-- Search
--------------------------------------------------------------------------
local searchIndex = {}

local IndexGroup
IndexGroup = function(group, options, path, trail)
	Config.ForEachChild(group, options, path, APP, function(key, option, childPath)
		local name = Resolve(option.name, key)
		if (type(name) ~= "string") then name = key end

		if (option.type == "group") then
			local nested = {}
			for i = 1, #childPath do nested[i] = childPath[i] end
			IndexGroup(option, options, nested, trail .. " > " .. name)
			return
		end

		if (option.type == "description") then return end

		local desc = Resolve(option.desc, nil)
		if (type(desc) ~= "string") then desc = nil end

		local stored = {}
		for i = 1, #childPath do stored[i] = childPath[i] end

		searchIndex[#searchIndex + 1] = {
			name = name,
			trail = trail,
			page = childPath[1],
			path = stored,
			haystack = string_lower(name .. " " .. (desc or ""))
		}
	end)
end

local BuildIndex = function(options)
	table_wipe(searchIndex)
	if (type(options) ~= "table") then return end

	Config.ForEachChild(options, options, {}, APP, function(key, option, childPath)
		if (option.type ~= "group") then return end

		local name = Resolve(option.name, key)
		if (type(name) ~= "string") then name = key end
		IndexGroup(option, options, { key }, name)
	end)
end

--------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------
local GetGeometry = function()
	local db = ns.db
	if (not db or not db.global) then return end

	if (type(db.global.optionsPanel) ~= "table") then
		db.global.optionsPanel = {}
	end
	return db.global.optionsPanel
end

local SavePosition = function()
	local geometry = GetGeometry()
	if (not geometry or not frame) then return end

	local point, _, relativePoint, x, y = frame:GetPoint()
	geometry.point, geometry.relativePoint = point, relativePoint
	geometry.x, geometry.y = x, y
	geometry.width, geometry.height = frame:GetWidth(), frame:GetHeight()
end

--------------------------------------------------------------------------
-- Rail
--------------------------------------------------------------------------
local Row_OnEnter = function(row)
	row.highlight:Show()
	if (not row.selected) then
		row.text:SetTextColor(unpack(Kit.TextHighlight))
	end

	-- A gem on a page is only useful if it says what it is counting.
	if (row.changed and row.changed > 0) then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:AddLine(row.text:GetText(), unpack(Kit.TextHighlight))
		GameTooltip:AddLine(string_format(L["%d settings here differ from their defaults."], row.changed),
			Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3], true)
		GameTooltip:Show()
	end
end

local Row_OnLeave = function(row)
	row.highlight:SetShown(row.selected and true or false)
	row.text:SetTextColor(unpack(row.selected and Kit.TextSelected or Kit.TextNormal))
	GameTooltip:Hide()
end

local CreateRailRow = function(index, list, height, onClick, withTrail)
	local row = list[index]
	if (row) then return row end

	row = CreateFrame("Button", nil, railContent)
	row:SetHeight(height)
	row:SetPoint("LEFT", railContent, "LEFT", 0, 0)
	row:SetPoint("RIGHT", railContent, "RIGHT", 0, 0)
	row:SetScript("OnClick", onClick)
	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", Row_OnLeave)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(Kit.GetMedia("plain"))
	highlight:SetAllPoints()
	highlight:Hide()
	row.highlight = highlight

	-- The selected page carries a bar down its left edge, as the artifact does
	-- with `border-left: 2px solid`.
	local edge = row:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(Kit.GetMedia("plain"))
	edge:SetWidth(2)
	edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	edge:Hide()
	row.edge = edge

	-- A gem on a page holding settings that differ from their defaults.
	local dot = row:CreateTexture(nil, "OVERLAY")
	dot:SetSize(9, 9)
	dot:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	Kit.SetGlyph(dot, "gem")
	dot:Hide()
	row.dot = dot

	local text = row:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(13))
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	row.text = text

	if (withTrail) then
		text:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -2)
		text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -2)
		text:SetHeight(14)

		local trail = row:CreateFontString(nil, "OVERLAY")
		trail:SetFontObject(Kit.GetFont(11))
		trail:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -17)
		trail:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -17)
		trail:SetHeight(13)
		trail:SetJustifyH("LEFT")
		trail:SetWordWrap(false)
		row.trail = trail
	else
		text:SetPoint("LEFT", row, "LEFT", 12, 0)
		text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.trail = false
	end

	list[index] = row
	return row
end

local CreateSectionHeading = function(index)
	local heading = Panel.headings[index]
	if (heading) then return heading end

	heading = railContent:CreateFontString(nil, "OVERLAY")
	heading:SetFontObject(Kit.GetFont(11, true))
	heading:SetJustifyH("LEFT")
	heading:SetWordWrap(false)
	Panel.headings[index] = heading
	return heading
end

-- A result carries the setting's name, the path it lives on, and enough room
-- for both. Clicking one leaves the search and opens the page it is on.
local Result_Row = function(index)
	local row = resultRows[index]
	if (row) then return row end

	row = CreateFrame("Button", nil, pageContent)
	row:SetHeight(40)
	row:SetPoint("LEFT", pageContent, "LEFT", 0, 0)
	row:SetPoint("RIGHT", pageContent, "RIGHT", 0, 0)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(Kit.GetMedia("plain"))
	highlight:SetAllPoints()
	highlight:Hide()
	row.highlight = highlight

	local rule = row:CreateTexture(nil, "BACKGROUND")
	rule:SetTexture(Kit.GetMedia("plain"))
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 14, 0)
	rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 0)
	row.rule = rule

	local name = row:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(Kit.GetFont(13))
	name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -5)
	name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -90, -5)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	row.name = name

	local trail = row:CreateFontString(nil, "OVERLAY")
	trail:SetFontObject(Kit.GetFont(11))
	trail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	trail:SetPoint("RIGHT", row, "RIGHT", -90, 0)
	trail:SetJustifyH("LEFT")
	trail:SetWordWrap(false)
	row.trail = trail

	local go = row:CreateFontString(nil, "OVERLAY")
	go:SetFontObject(Kit.GetFont(11))
	go:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	go:SetJustifyH("RIGHT")
	go:SetWordWrap(false)
	go:SetText(L["Go to page"])
	go:Hide()
	row.go = go

	row:SetScript("OnClick", function(self) Panel:OpenResult(self) end)
	row:SetScript("OnEnter", function(self)
		self.highlight:Show()
		self.go:Show()
		self.name:SetTextColor(unpack(Kit.TextHighlight))
	end)
	row:SetScript("OnLeave", function(self)
		self.highlight:Hide()
		self.go:Hide()
		self.name:SetTextColor(unpack(Kit.TextNormal))
	end)

	resultRows[index] = row
	return row
end

-- A section of the open page. Indented, quieter than a page, and it scrolls
-- rather than navigates: you are already on the page it belongs to.
local Section_Row = function(index)
	local row = Panel.sectionRows[index]
	if (row) then return row end

	row = CreateFrame("Button", nil, railContent)
	row:SetHeight(19)
	row:SetPoint("LEFT", railContent, "LEFT", 0, 0)
	row:SetPoint("RIGHT", railContent, "RIGHT", 0, 0)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(Kit.GetMedia("plain"))
	highlight:SetAllPoints()
	highlight:Hide()
	row.highlight = highlight

	-- The same bar a selected page carries, so the section you are reading is
	-- marked the same way as the page you are on.
	local edge = row:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(Kit.GetMedia("plain"))
	edge:SetWidth(2)
	edge:SetPoint("TOPLEFT", row, "TOPLEFT", 12, 0)
	edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 0)
	edge:Hide()
	row.edge = edge

	local text = row:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(11))
	text:SetPoint("LEFT", row, "LEFT", 26, 0)
	text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	row.text = text

	row:SetScript("OnClick", function(self)
		if (contentScroll and self.offset) then
			-- Remembered before the scroll, because the scroll fires the update
			-- that reads it. A page stops at the end of its content, so the last
			-- sections cannot be brought to the top and the mark has no way to
			-- tell them apart; asking for one is the only signal there is.
			Panel.requestedSection = index

			local range = contentScroll:GetVerticalScrollRange() or 0
			contentScroll:SetVerticalScroll(min(range, max(0, self.offset)))

			-- Asking for a section the page is already showing moves the scroll
			-- by nothing, and a scroll that does not move fires no handler. The
			-- mark still has to change, so it is asked for directly.
			Panel:UpdateActiveSection()
		end
	end)
	row:SetScript("OnEnter", function(self)
		self.highlight:Show()
		self.text:SetTextColor(unpack(Kit.TextHighlight))
	end)
	row:SetScript("OnLeave", function(self)
		self.highlight:SetShown(self.active and true or false)
		self.text:SetTextColor(unpack(self.active and Kit.TextSelected or Kit.TextNormal))
	end)

	Panel.sectionRows[index] = row
	return row
end

local Rail_OnClick = function(row)
	-- Clicking the page you already have open shuts its drawer of sections.
	-- Opening a different page should not be the only way to close one, and a
	-- rail with a twelve-entry list wedged into the middle of it is hard to read
	-- past.
	if (row.key == Panel.selected) then
		Panel.railClosed = not Panel.railClosed
		Panel:BuildRail()
		Panel:UpdateActiveSection()
		return
	end

	Panel:SelectPage(row.key)
end


--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
Panel.BuildRail = function(self)
	local options, module = GetOptions()
	if (not options) then return end

	-- Pages, in the order Ace3 itself would draw them.
	local keys = Config.SortedKeys(options, options, {}, APP)
	local bySection = {}

	for _, key in ipairs(keys) do
		local option = Config.GetSubOption(options, key)
		if (type(option) == "table" and option.type == "group") then
			local hidden = Config.IsHidden(option, options, { key }, APP)
			if (not hidden) then
				local section = GetBand(key, module)
				bySection[section] = bySection[section] or {}

				local name = Resolve(option.name, key)
				if (type(name) ~= "string") then name = key end

				bySection[section][#bySection[section] + 1] = { key = key, name = name }
			end
		end
	end

	-- Views are listed first in their band: Quick Start leads Setup, so it is
	-- the page a first visit lands on.
	if (self.tab == "options" and Kit.Views) then
		local listed = Kit.Views.Listed()
		for i = #listed, 1, -1 do
			local view = listed[i]
			bySection[view.band] = bySection[view.band] or {}
			table_insert(bySection[view.band], 1, { key = view.key, name = view.name, view = true })
		end
	end

	self.pages = {}

	self.sectionRows = self.sectionRows or {}
	self.changedByPage = self.changedByPage or {}

	-- What went where, in order. Frame positions cannot be read back outside
	-- the game, so the rail writes its own layout down and the harness checks
	-- it for overlap: rows drawn on top of one another passed every check.
	self.railLayout = {}

	local rowIndex, headingIndex, offset = 0, 0, 0
	local sectionIndex, totalChanged = 0, 0

	for _, section in ipairs(GetBands()) do
		local entries = bySection[section.key]
		if (entries and #entries > 0) then
			headingIndex = headingIndex + 1
			local heading = CreateSectionHeading(headingIndex)
			heading:ClearAllPoints()
			heading:SetPoint("TOPLEFT", railContent, "TOPLEFT", 12, -(offset + 8))
			heading:SetPoint("RIGHT", railContent, "RIGHT", -8, 0)
			heading:SetText(section.label:upper())
			heading:Show()

			self.railLayout[#self.railLayout + 1] = {
				kind = "band", label = section.label, offset = offset, height = 24
			}
			offset = offset + 24

			for _, entry in ipairs(entries) do
				rowIndex = rowIndex + 1
				local row = CreateRailRow(rowIndex, railRows, 22, Rail_OnClick)
				row:SetPoint("TOP", railContent, "TOP", 0, -offset)
				row.key = entry.key
				row.text:SetText(entry.name)

				-- Counting reads every setting on the page, so it is done when the
				-- panel opens or refreshes and cached for the redraws in between.
				--
				-- Only on the Options tab. The window's own settings have no
				-- module defaults to differ from, and a gem beside Changelog
				-- would be nonsense.
				local changed = 0
				if (self.tab == "options" and not entry.view) then
					changed = self.changedByPage[entry.key]
					if (changed == nil) then
						changed = Kit.Defaults
							and Kit.Defaults.CountModified(options, { entry.key }) or 0
						self.changedByPage[entry.key] = changed
					end
				end

				row.changed = changed
				row.dot:SetShown(changed > 0)
				totalChanged = totalChanged + changed

				row:Show()

				self.railLayout[#self.railLayout + 1] = {
					kind = "page", label = entry.name, offset = offset, height = 22
				}

				-- The page's own height is taken here, before its sections are
				-- placed. Adding it afterwards put the first section on top of
				-- the page row and left the page's worth of empty space at the
				-- end of the list.
				offset = offset + 22

				-- The open page lists its sections under itself, unless you have
				-- clicked it again to shut them away.
				if (entry.key == self.selected and page and not self.railClosed) then
					for _, section in ipairs(page:GetSections()) do
						if (section.label and section.label ~= "") then
							sectionIndex = sectionIndex + 1

							local sub = Section_Row(sectionIndex)
							sub:ClearAllPoints()
							sub:SetPoint("TOPLEFT", railContent, "TOPLEFT", 0, -offset)
							sub:SetPoint("TOPRIGHT", railContent, "TOPRIGHT", 0, -offset)
							-- Two offsets, and they are not the same thing:
							-- `offset` is how far down the page this section
							-- starts, `railOffset` is where its row sits in
							-- the rail.
							sub.offset = section.offset
							sub.railOffset = offset
							sub.label = section.label
							sub.text:SetText(section.label)
							sub:Show()

							self.railLayout[#self.railLayout + 1] = {
								kind = "section", label = section.label,
								offset = offset, height = 19
							}
							offset = offset + 19
						end
					end
				end

				self.pages[#self.pages + 1] = entry
			end
		end
	end

	for i = rowIndex + 1, #railRows do railRows[i]:Hide() end
	for i = headingIndex + 1, #self.headings do self.headings[i]:Hide() end
	for i = sectionIndex + 1, #self.sectionRows do self.sectionRows[i]:Hide() end

	self.railHeight = offset + 8
	railContent:SetHeight(max(1, self.railHeight))
	railScroll:SetVerticalScroll(0)

	BuildIndex(options)

	self.totalChanged = totalChanged
	self:ShowCount()
	self:UpdateTabs()
	self:ApplyTheme()
end

-- The tally in the header. With something changed on the Options tab it is
-- also the way into the Changed view, and it says so by being drawn as a link.
Panel.ShowCount = function(self)
	local total = self.totalChanged or 0
	local onChanged = (self.selected == (Kit.Views and Kit.Views.CHANGED))

	self.countActive = (self.tab == "options" and not self.searching
		and (total > 0 or onChanged)) and true or false
	if (self.countButton) then self.countButton:SetShown(self.countActive) end

	if (self.searching) then return end
	if (total > 0) then
		self:SetCount(string_format(L["%d settings, %d changed"], #searchIndex, total))
	else
		self:SetCount(string_format(L["%d settings"], #searchIndex))
	end
	if (self.count) then
		self.count:SetTextColor(unpack(self.countActive and Kit.TextSelected or Kit.TextDisabled))
	end
end

-- Brings the gems and the tally up to date after one setting changed. Only
-- that setting's own page is counted again: counting reads every setting on a
-- page, and a slider being dragged changes one setting many times a second.
Panel.OnSettingChanged = function(self, path)
	if (self.tab ~= "options" or type(path) ~= "table" or type(path[1]) ~= "string") then return end

	local options = GetOptions()
	if (not options or not Kit.Defaults) then return end

	self.changedByPage = self.changedByPage or {}
	self.changedByPage[path[1]] = Kit.Defaults.CountModified(options, { path[1] })

	local total = 0
	for _, entry in ipairs(self.pages or {}) do
		if (not entry.view) then total = total + (self.changedByPage[entry.key] or 0) end
	end
	self.totalChanged = total

	for i = 1, #railRows do
		local row = railRows[i]
		if (row:IsShown() and row.key == path[1]) then
			row.changed = self.changedByPage[path[1]]
			row.dot:SetShown(row.changed > 0)
		end
	end

	if (self.selected == (Kit.Views and Kit.Views.CHANGED) and self.pageDesc) then
		self.pageDesc:SetText(string_format(L["%d settings here differ from their defaults."], total))
	end
	self:ShowCount()
end

-- The count's own click: into the Changed view, or back to where you were.
Panel.ToggleChanged = function(self)
	local changed = Kit.Views and Kit.Views.CHANGED
	if (not changed or self.tab ~= "options") then return end

	if (self.selected == changed) then
		local back = self.beforeChanged
		if (not back or back == changed) then back = self.pages and self.pages[1] and self.pages[1].key end
		self:SelectPage(back)
		return
	end

	self.beforeChanged = self.selected
	if (searchBox and searchBox:GetText() ~= "") then
		searchBox:SetText("")
		searchBox:ClearFocus()
		if (searchBox.placeholder) then searchBox.placeholder:Show() end
		self:HideResults()
	end
	self:SelectPage(changed)
end

--------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------
Panel.UpdateTabs = function(self)
	for i = 1, #(self.tabs or {}) do
		local button = self.tabs[i]
		button.selected = (button.key == self.tab)
		button.highlight:SetShown(button.selected)
		button.edge:SetShown(button.selected)
		button.text:SetTextColor(unpack(button.selected and Kit.TextSelected or Kit.TextNormal))
	end
end

-- Switches halves of the window. Each tab remembers the page you were last on,
-- because coming back to Options and landing somewhere you did not choose is
-- the kind of thing that makes a window feel like it is arguing with you.
Panel.SetTab = function(self, key)
	if (self.tab == key) then return end

	self.lastPage = self.lastPage or {}
	self.lastPage[self.tab] = self.selected

	self.tab = key
	self.selected = nil
	self.railClosed = nil
	self.requestedSection = nil

	-- HideResults rather than ClearSearch, because ClearSearch rebuilds the rail
	-- and reopens the page you were on, which is the tab we are leaving.
	self:HideResults()
	if (self.empty) then self.empty:Hide() end
	if (searchBox) then
		searchBox:SetText("")
		searchBox:ClearFocus()
		if (searchBox.placeholder) then searchBox.placeholder:Show() end
	end

	self:BuildRail()

	-- Back to where you were on this tab, or its first page.
	local wanted = self.lastPage[key]
	local found
	for _, entry in ipairs(self.pages or {}) do
		if (entry.key == wanted) then found = wanted end
	end

	self:SelectPage(found or (self.pages[1] and self.pages[1].key))
end

-- Marks the section the page is currently showing. The one in view is the
-- last whose heading has passed the top of the page, which is what a reader
-- takes to be the section they are in.
Panel.UpdateActiveSection = function(self)
	local rows = self.sectionRows
	if (not rows or not contentScroll) then return end

	local active
	if (not self.searching) then
		local scroll = contentScroll:GetVerticalScroll() or 0

		for i = 1, #rows do
			local row = rows[i]
			if (row:IsShown() and row.offset and row.offset <= scroll + 12) then
				active = i
			end
		end

		-- Above the first heading you are still in the first section.
		if (not active and rows[1] and rows[1]:IsShown()) then
			active = 1
		end

		-- At the end of the page the rule above runs out of road. A scroll frame
		-- stops when its content does, so the last few headings never pass the
		-- top of the view however far you scroll: on Unit Frame Settings you can
		-- be looking straight at Arena Enemy Frames while the last heading to
		-- have passed the top is still Boss Frames.
		--
		-- Nothing about the scroll position can separate those sections, because
		-- the scroll position is identical for all of them. The only thing that
		-- can is which one you asked for, so at the limit the rail keeps the
		-- section you chose, as long as it is genuinely on screen. Scroll away
		-- from the end and the ordinary rule takes back over.
		-- A page too short to scroll at all is the same problem in its extreme
		-- form: every section is on screen, none of their headings will ever
		-- pass the top, and the ordinary rule can only ever answer "the first
		-- one". So it counts as being at the end too.
		local range = contentScroll:GetVerticalScrollRange() or 0
		local atTheEnd = (range <= 0) or (scroll >= range - 1)

		if (not atTheEnd) then
			self.requestedSection = nil
		elseif (self.requestedSection) then
			local row = rows[self.requestedSection]
			local height = contentScroll:GetHeight() or 0
			local top = row and row.offset and (row.offset - scroll)

			if (row and row:IsShown() and top and top >= 0 and top < height) then
				active = self.requestedSection
			else
				self.requestedSection = nil
			end
		end
	end

	local accent = Kit.TextSelected
	for i = 1, #rows do
		local row = rows[i]
		row.active = (i == active)
		row.edge:SetShown(row.active)
		row.highlight:SetShown(row.active)
		row.text:SetTextColor(unpack(row.active and accent or Kit.TextNormal))
	end

	-- The rail is on the far left and long pages are read on the right, so the
	-- crumb says it again where the eye already is: BARS > Action Bar 3. The
	-- separator is the one the search results use for their paths.
	if (not self.searching and self.crumbBase and self.crumb) then
		local here = active and rows[active] and rows[active].label
		self.crumb:SetText(here and (self.crumbBase .. " > " .. here) or self.crumbBase)
	end

	-- A mark you have to scroll the rail to find is not telling you anything,
	-- so the rail follows the page far enough to bring the row into view.
	if (active and railScroll) then
		local row = rows[active]
		local top = (row and row.railOffset) or 0
		local height = railScroll:GetHeight() or 0
		local at = railScroll:GetVerticalScroll() or 0
		local range = railScroll:GetVerticalScrollRange() or 0

		local want = at
		if (top < at) then
			want = top
		elseif (height > 0 and top + 19 > at + height) then
			want = top + 19 - height
		end

		want = min(range, max(0, want))
		if (want ~= at) then
			railScroll:SetVerticalScroll(want)
		end
	end
end

Panel.SetCount = function(self, text)
	if (self.count) then self.count:SetText(text or "") end
end

-- Brief confirmation for live previews. The outline carries the setting's name
-- in the world; this line also explains when there was no usable live frame to
-- outline, which is more truthful than drawing a generic mock-up.
-- `hold` is how long the line stays up; an explanation needs longer than a
-- frame name does.
Panel.SetPreviewStatus = function(self, text, found, hold)
	if (not self.previewStatus or not self.previewText) then return end

	self.previewFound = found and true or false
	self.previewText:SetText(text or "")
	self.previewText:SetTextColor(unpack(self.previewFound and Kit.TextSelected or Kit.TextDisabled))
	self.previewStatus.remaining = tonumber(hold) or 2.6
	self.previewStatus:SetAlpha(1)
	self.previewStatus:Show()
end

Panel.SelectPage = function(self, key)
	local options = GetOptions()
	if (not options or not key) then return end
	if (self.selecting) then return end
	self.selecting = true

	-- A page and a set of results cannot both own the content area.
	self:HideResults()

	-- A page you are arriving at opens its drawer. Closing one is a thing you
	-- do to the page you are on, and it should not follow you to the next.
	self.selected = key
	self.railClosed = nil
	self.requestedSection = nil

	for i = 1, #railRows do
		local row = railRows[i]
		row.selected = (row.key == key)
		row.highlight:SetShown(row.selected)
		row.edge:SetShown(row.selected)
		row.text:SetTextColor(unpack(row.selected and Kit.TextSelected or Kit.TextNormal))
	end

	if (Kit.Controls and Kit.Controls.CloseDropdown) then
		Kit.Controls.CloseDropdown()
	end

	-- The heading, before the rows, so the page names itself.
	local view = GetView(key)
	local option = (not view) and Config.GetSubOption(options, key) or nil
	local _, module = GetOptions()

	if (view) then
		self.pageTitle:SetText(view.name)
		self.pageDesc:SetText(view.desc or "")

		local label = view.crumb
		if (not label) then
			for _, entry in ipairs(SECTIONS) do
				if (entry.key == view.band) then label = entry.label end
			end
		end
		self.crumbBase = (label or view.name):upper()
		self.crumb:SetText(self.crumbBase)

		-- The rail's list is read on every refresh, not captured here: the rail
		-- is rebuilt just below, and again whenever the panel refreshes.
		page:ShowList(options, function() return view.collect(options, Panel.pages) end)

	elseif (option) then
		local name = Resolve(option.name, key)
		self.pageTitle:SetText(type(name) == "string" and name or key)

		local desc = Config.GetDesc(option, options, { key }, APP)
		self.pageDesc:SetText(type(desc) == "string" and desc or "")

		local sectionKey = (module and module:GetSection(key)) or "other"
		local label = sectionKey
		for _, entry in ipairs(SECTIONS) do
			if (entry.key == sectionKey) then label = entry.label end
		end

		-- The crumb grows a third step as the page scrolls, so keep the first
		-- two where UpdateActiveSection can find them.
		self.crumbBase = label:upper()
		self.crumb:SetText(self.crumbBase)
	end

	if (not view) then page:Show(options, { key }) end
	contentScroll:SetVerticalScroll(0)

	-- The rail is redrawn now that the page knows its sections. Counts come
	-- from the cache, so this costs a layout rather than a read of every
	-- setting in the addon.
	self:BuildRail()
	self:UpdateActiveSection()
	self:ApplyTheme()

	if (key == (Kit.Views and Kit.Views.CHANGED)) then
		self.pageDesc:SetText(string_format(L["%d settings here differ from their defaults."],
			self.totalChanged or 0))
	end

	self.selecting = nil
end

-- Opens the page a search result sits on. There is no tab strip to select any
-- more, because sub-groups are drawn down the page as sections.
Panel.GoTo = function(self, path)
	if (type(path) ~= "table" or #path == 0) then return end
	self:SelectPage(path[1])
end

-- Replaces the page with the matches, and leaves the rail alone. That is what
-- the artifact does: searching changes what you are reading, not where you can
-- go, and a result gets the width to show its name and its path.
Panel.ShowResults = function(self, query)
	local options = GetOptions()
	if (not options) then return end

	-- The heading shows what was searched for, taken from the argument rather
	-- than read back out of the box, so this works however it was called.
	local typed = query or ""
	query = string_lower(typed)

	-- The page's own controls stand down while results are shown.
	page:Clear()
	page:Layout()

	local matches = {}
	for i = 1, #searchIndex do
		local entry = searchIndex[i]
		if (string_find(entry.haystack, query, 1, true)) then
			matches[#matches + 1] = entry
			if (#matches >= 200) then break end
		end
	end

	local accent = Kit.TextSelected
	local hex = string_format("|cff%02x%02x%02x",
		accent[1] * 255, accent[2] * 255, accent[3] * 255)

	local offset = 0
	for i, entry in ipairs(matches) do
		local row = Result_Row(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", pageContent, "TOPLEFT", 0, -offset)
		row:SetPoint("TOPRIGHT", pageContent, "TOPRIGHT", 0, -offset)
		row.path = entry.path

		-- The matched run is coloured in place, so a result says why it matched.
		local shown = entry.name
		local from, to = string_find(string_lower(shown), query, 1, true)
		if (from) then
			shown = shown:sub(1, from - 1) .. hex .. shown:sub(from, to) .. "|r"
				.. shown:sub(to + 1)
		end
		row.name:SetText(shown)
		row.trail:SetText(entry.trail)
		row.go:Hide()
		row.highlight:Hide()
		row:Show()

		offset = offset + 40
	end

	for i = #matches + 1, #resultRows do resultRows[i]:Hide() end

	self.searching = true
	pageContent:SetHeight(max(1, offset))
	contentScroll:SetVerticalScroll(0)

	-- The heading says what is being shown instead of the page.
	self.crumb:SetText(L["SEARCH"])
	self.pageTitle:SetText(typed)
	self.pageDesc:SetText(#matches == 0
		and L["Nothing matches that."]
		or string_format(L["%d of %d settings"], #matches, #searchIndex))

	-- Nothing is the current page while a search is up.
	for i = 1, #railRows do
		railRows[i].selected = false
		railRows[i].highlight:Hide()
		railRows[i].edge:Hide()
	end

	self:SetCount(string_format(L["%d of %d settings"], #matches, #searchIndex))
	self:ShowCount()
	self:ApplyTheme()
end

-- Leaves the search and opens the page a result lives on.
Panel.OpenResult = function(self, row)
	if (not row or type(row.path) ~= "table" or #row.path == 0) then return end

	if (searchBox) then
		searchBox:SetText("")
		searchBox:ClearFocus()
		if (searchBox.placeholder) then searchBox.placeholder:Show() end
	end

	self:HideResults()
	self:SelectPage(row.path[1])
end

Panel.HideResults = function(self)
	for i = 1, #resultRows do resultRows[i]:Hide() end
	self.searching = false
end
Panel.ClearSearch = function(self)
	self:HideResults()
	self.empty:Hide()
	self:BuildRail()

	if (self.selected) then
		self:SelectPage(self.selected)
	end
end

Panel.Refresh = function(self)
	if (not frame or not frame:IsShown()) then return end

	-- Something changed, so the cached counts are no longer to be trusted.
	self.changedByPage = {}
	self:BuildRail()
	if (searchBox:GetText() ~= "") then
		self:ShowResults(searchBox:GetText())
	elseif (self.selected) then
		self:SelectPage(self.selected)
	end
end

Panel.ApplyTheme = function(self)
	if (not frame) then return end

	frame:SetBackdropColor(unpack(Kit.WindowColor))
	frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))

	if (self.searchBackdrop) then
		self.searchBackdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(self.searchBackdrop, Kit.BorderIdle)
	end
	if (self.searchGlyph) then self.searchGlyph:SetVertexColor(unpack(Kit.TextSelected)) end
	if (self.placeholder) then self.placeholder:SetTextColor(unpack(Kit.TextDisabled)) end
	if (searchBox) then searchBox:SetTextColor(unpack(Kit.TextHighlight)) end
	if (self.version) then self.version:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.empty) then self.empty:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.combatText) then self.combatText:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.previewText) then
		self.previewText:SetTextColor(unpack(self.previewFound and Kit.TextSelected or Kit.TextDisabled))
	end
	if (self.count) then
		self.count:SetTextColor(unpack(self.countActive and Kit.TextSelected or Kit.TextDisabled))
	end
	if (self.crumb) then self.crumb:SetTextColor(unpack(Kit.TextSelected)) end
	if (self.pageTitle) then self.pageTitle:SetTextColor(unpack(Kit.TextHighlight)) end
	if (self.pageDesc) then self.pageDesc:SetTextColor(unpack(Kit.TextDisabled)) end

	if (self.headRule) then
		local border = Kit.BorderIdle
		self.headRule:SetVertexColor(border[1], border[2], border[3], .6)
	end

	if (self.railEdge) then
		local border = Kit.BorderIdle
		self.railEdge:SetVertexColor(border[1], border[2], border[3], .8)
	end

	local accent = Kit.TextSelected
	for i = 1, #self.headings do
		self.headings[i]:SetTextColor(accent[1], accent[2], accent[3])
	end

	-- Rail rows only. A result row is a different shape entirely now, and is
	-- coloured on its own below.
	for i = 1, #railRows do
		local row = railRows[i]
		row.highlight:SetVertexColor(accent[1], accent[2], accent[3], .16)
		row.edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
		row.dot:SetVertexColor(accent[1], accent[2], accent[3])
		row.text:SetTextColor(unpack(row.selected and accent or Kit.TextNormal))
	end

	for i = 1, #(self.sectionRows or {}) do
		local row = self.sectionRows[i]
		row.highlight:SetVertexColor(accent[1], accent[2], accent[3], .12)
		row.edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
		row.text:SetTextColor(unpack(row.active and accent or Kit.TextNormal))
	end

	for i = 1, #(self.tabs or {}) do
		local button = self.tabs[i]
		button.highlight:SetVertexColor(accent[1], accent[2], accent[3], .16)
		button.edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
		button.text:SetTextColor(unpack(button.selected and accent or Kit.TextNormal))
	end

	if (self.tabRule) then
		local border = Kit.BorderIdle
		self.tabRule:SetVertexColor(border[1], border[2], border[3], .5)
	end

	for i = 1, #resultRows do
		local row = resultRows[i]
		if (row:IsShown()) then
			row.highlight:SetVertexColor(accent[1], accent[2], accent[3], .16)
			row.name:SetTextColor(unpack(Kit.TextNormal))
			row.trail:SetTextColor(unpack(Kit.TextDisabled))
			row.go:SetTextColor(unpack(Kit.TextSelected))

			local border = Kit.BorderIdle
			row.rule:SetVertexColor(border[1], border[2], border[3], .35)
		end
	end

	if (page) then page:Restyle() end
	if (Kit.Preview) then Kit.Preview:Restyle() end
end

Panel.LoadTheme = function(self)
	local db = ns.db
	Kit.SetTheme((db and db.global and db.global.optionsTheme) or "azerite")

	-- After the theme, because opacity scales whatever alpha it just set.
	if (db and db.global and db.global.optionsOpacity) then
		Kit.SetOpacity(db.global.optionsOpacity)
	end

	self:SetPanelScale(db and db.global and db.global.optionsScale)
end

--------------------------------------------------------------------------
-- Scale
--------------------------------------------------------------------------
Panel.MinScale, Panel.MaxScale = 0.7, 1.4

Panel.GetPanelScale = function(self)
	local db = ns.db
	local scale = db and db.global and db.global.optionsScale
	return (type(scale) == "number") and scale or 1
end

-- The whole window, chrome and all. A scaled frame keeps its anchor point, so
-- it grows around wherever it is rather than jumping to the middle.
Panel.SetPanelScale = function(self, value)
	if (type(value) ~= "number") then value = 1 end
	value = min(self.MaxScale, max(self.MinScale, value))

	local db = ns.db
	if (db and db.global) then
		db.global.optionsScale = value
	end

	if (frame) then
		frame:SetScale(value)
	end
	return value
end

-- Until now the theme dropdown called Window:SetTheme, which repainted the old
-- window. Picking a theme in this one changed the saved value and left the
-- window you were looking at the colour it already was.
Panel.SetTheme = function(self, key)
	Kit.SetTheme(key)

	local db = ns.db
	if (db and db.global) then
		db.global.optionsTheme = Kit.GetTheme()
	end

	-- ApplyTheme restyles every control on the page as well as the chrome, so
	-- unlike the AceGUI window this does not need the page re-fed to pick the
	-- colours up.
	self:ApplyTheme()

	if (Kit.Window) then Kit.Window:ApplyTheme() end
end

-- Puts the window back where it started. A window dragged mostly off screen is
-- hard to drag back, and clamping only stops it leaving entirely.
Panel.ResetGeometry = function(self)
	local geometry = GetGeometry()
	if (geometry) then
		geometry.point, geometry.relativePoint = nil, nil
		geometry.x, geometry.y = nil, nil
		geometry.width, geometry.height = nil, nil
	end

	if (not frame) then return end

	frame:ClearAllPoints()
	frame:SetSize(DEFAULT_W, DEFAULT_H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------
local Search_OnTextChanged = function(editbox, userInput)
	local text = editbox:GetText()
	editbox.placeholder:SetShown(text == "")

	if (not userInput) then return end

	if (text == "") then
		Panel:ClearSearch()
	else
		Panel:ShowResults(text)
	end
end

local Build = function()
	local name = ns.Prefix .. "OptionsPanel"

	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetSize(DEFAULT_W, DEFAULT_H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetBackdrop(Kit.WindowBackdrop)
	if (frame.SetResizeBounds) then frame:SetResizeBounds(MIN_W, MIN_H) end

	UISpecialFrames[#UISpecialFrames + 1] = name

	frame:SetScript("OnHide", function()
		if (Kit.Controls and Kit.Controls.CloseDropdown) then Kit.Controls.CloseDropdown() end
		SavePosition()
	end)

	Panel.headings = {}

	----------------------------------------------------------------
	-- Header
	----------------------------------------------------------------
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(HEADER_H)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition()
	end)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(Kit.GetMedia("power-crystal-ice-icon"))
	logo:SetSize(34, 34)
	logo:SetPoint("LEFT", header, "LEFT", 6, 0)

	local version = header:CreateFontString(nil, "OVERLAY")
	version:SetFontObject(Kit.GetFont(12))
	version:SetPoint("RIGHT", header, "RIGHT", -36, -1)
	version:SetJustifyH("RIGHT")
	version:SetWordWrap(false)
	version:SetText(C_AddOns.GetAddOnMetadata(Addon, "Version") or "")
	Panel.version = version

	local title = header:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Kit.GetFont(18, true))
	title:SetPoint("LEFT", logo, "RIGHT", 8, 1)
	title:SetPoint("RIGHT", version, "LEFT", -10, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText("|cff4488bbAzerite|r|cfffafafaUI|r  |cff00ff00"
		.. (L["JuNNeZ Edition"] or "JuNNeZ Edition") .. "|r")

	local close = CreateFrame("Button", nil, header)
	close:SetSize(26, 26)
	close:SetPoint("RIGHT", header, "RIGHT", -4, 0)
	close:SetScript("OnClick", function() frame:Hide() end)

	local closeSize = Kit.DrawSize(26, "options_close")
	local closeTexture = close:CreateTexture(nil, "ARTWORK")
	closeTexture:SetTexture(Kit.GetMedia("options-close"))
	closeTexture:SetSize(closeSize, closeSize)
	closeTexture:SetPoint("CENTER")

	local closeBright = close:CreateTexture(nil, "OVERLAY")
	closeBright:SetTexture(Kit.GetMedia("options-close-bright"))
	closeBright:SetSize(closeSize, closeSize)
	closeBright:SetPoint("CENTER")
	closeBright:Hide()

	close:SetScript("OnEnter", function() closeBright:Show() end)
	close:SetScript("OnLeave", function() closeBright:Hide() end)

	----------------------------------------------------------------
	-- Search
	----------------------------------------------------------------
	-- A row of its own across the whole panel, as the artifact draws it,
	-- rather than a box tucked over the rail.
	local searchRow = CreateFrame("Frame", nil, frame)
	searchRow:SetHeight(SEARCH_H)
	searchRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	searchRow:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

	local count = searchRow:CreateFontString(nil, "OVERLAY")
	count:SetFontObject(Kit.GetFont(11))
	count:SetPoint("RIGHT", searchRow, "RIGHT", -4, 0)
	count:SetJustifyH("RIGHT")
	count:SetWordWrap(false)
	Panel.count = count

	local countButton = CreateFrame("Button", nil, searchRow)
	countButton:SetPoint("TOPLEFT", count, "TOPLEFT", -4, 3)
	countButton:SetPoint("BOTTOMRIGHT", count, "BOTTOMRIGHT", 4, -3)
	countButton:SetScript("OnClick", function() Panel:ToggleChanged() end)
	countButton:SetScript("OnEnter", function(self)
		count:SetTextColor(unpack(Kit.TextHighlight))
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		local changed = Kit.Views and Kit.Views.CHANGED
		GameTooltip:AddLine((Panel.selected == changed)
			and L["Back to the page you were on."]
			or L["Show only the settings that differ from their defaults."],
			Kit.TextHighlight[1], Kit.TextHighlight[2], Kit.TextHighlight[3], true)
		GameTooltip:Show()
	end)
	countButton:SetScript("OnLeave", function()
		count:SetTextColor(unpack(Panel.countActive and Kit.TextSelected or Kit.TextDisabled))
		GameTooltip:Hide()
	end)
	countButton:Hide()
	Panel.countButton = countButton

	local search = CreateFrame("EditBox", nil, searchRow)
	search:SetHeight(24)
	search:SetPoint("LEFT", searchRow, "LEFT", 6, 0)
	search:SetWidth(RAIL_W + 90)
	search:SetAutoFocus(false)
	search:SetFontObject(Kit.GetFont(12))
	search:SetTextInsets(22, 6, 0, 0)
	searchBox = search
	Panel.searchBox = search

	local searchBackdrop = Kit.CreateBackdrop(search, Kit.InsetBackdrop, 2)
	Panel.searchBackdrop = searchBackdrop

	local searchGlyph = search:CreateTexture(nil, "OVERLAY")
	searchGlyph:SetSize(14, 14)
	searchGlyph:SetPoint("LEFT", search, "LEFT", 5, 0)
	Kit.SetGlyph(searchGlyph, "search")
	Panel.searchGlyph = searchGlyph

	local placeholder = search:CreateFontString(nil, "ARTWORK")
	placeholder:SetFontObject(Kit.GetFont(12))
	placeholder:SetPoint("LEFT", search, "LEFT", 22, 0)
	placeholder:SetText(L["Search settings"])
	search.placeholder = placeholder
	Panel.placeholder = placeholder

	search:SetScript("OnTextChanged", Search_OnTextChanged)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		Panel:ClearSearch()
	end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEditFocusGained", function()
		Kit.SetBorderColor(searchBackdrop, Kit.BorderFocus)
	end)
	search:SetScript("OnEditFocusLost", function()
		Kit.SetBorderColor(searchBackdrop, Kit.BorderIdle)
	end)

	----------------------------------------------------------------
	-- Rail
	----------------------------------------------------------------
	rail = CreateFrame("Frame", nil, frame)
	rail:SetWidth(RAIL_W)
	rail:SetPoint("TOPLEFT", searchRow, "BOTTOMLEFT", 8, -6)
	rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, FOOTER_H + 8 + TABSTRIP_H)

	local railEdge = rail:CreateTexture(nil, "ARTWORK")
	railEdge:SetTexture(Kit.GetMedia("plain"))
	railEdge:SetWidth(1)
	railEdge:SetPoint("TOPRIGHT", rail, "TOPRIGHT", 0, 0)
	railEdge:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 0, 0)
	Panel.railEdge = railEdge

	railScroll = CreateFrame("ScrollFrame", nil, rail)
	railScroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, 0)
	railScroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -6, 0)
	railScroll:SetClipsChildren(true)

	railContent = CreateFrame("Frame", nil, railScroll)
	railContent:SetSize(RAIL_W - 10, 1)
	railScroll:SetScrollChild(railContent)

	railScroll:EnableMouseWheel(true)
	railScroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * 40)))
	end)
	railScroll:SetScript("OnSizeChanged", function(self, width)
		if (width and width > 0) then railContent:SetWidth(width) end
	end)

	local empty = rail:CreateFontString(nil, "OVERLAY")
	empty:SetFontObject(Kit.GetFont(12))
	empty:SetPoint("TOPLEFT", rail, "TOPLEFT", 12, -10)
	empty:SetPoint("RIGHT", rail, "RIGHT", -10, 0)
	empty:SetJustifyH("LEFT")
	empty:Hide()
	Panel.empty = empty

	----------------------------------------------------------------
	-- Tabs
	----------------------------------------------------------------
	-- Under the rail, because they choose what the rail lists. The window's own
	-- settings are not one more page of the addon's settings, and the rail is
	-- already long.
	local tabStrip = CreateFrame("Frame", nil, frame)
	tabStrip:SetHeight(TABSTRIP_H)
	tabStrip:SetPoint("TOPLEFT", rail, "BOTTOMLEFT", 0, 0)
	tabStrip:SetPoint("TOPRIGHT", rail, "BOTTOMRIGHT", 0, 0)

	local tabRule = tabStrip:CreateTexture(nil, "ARTWORK")
	tabRule:SetTexture(Kit.GetMedia("plain"))
	tabRule:SetHeight(1)
	tabRule:SetPoint("TOPLEFT", tabStrip, "TOPLEFT", 4, 0)
	tabRule:SetPoint("TOPRIGHT", tabStrip, "TOPRIGHT", -6, 0)
	Panel.tabRule = tabRule

	Panel.tabs = {}

	local tabWidth = (RAIL_W - 10) / #TABS

	for index, info in ipairs(TABS) do
		local button = CreateFrame("Button", nil, tabStrip)
		button:SetSize(tabWidth, TABSTRIP_H - 6)
		button:SetPoint("TOPLEFT", tabStrip, "TOPLEFT", 4 + (index - 1) * tabWidth, -4)
		button.key = info.key

		local highlight = button:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture(Kit.GetMedia("plain"))
		highlight:SetAllPoints()
		highlight:Hide()
		button.highlight = highlight

		-- Under the selected tab rather than beside it, because these sit at the
		-- bottom of the rail and a bar along the left would read as one more row.
		local edge = button:CreateTexture(nil, "ARTWORK")
		edge:SetTexture(Kit.GetMedia("plain"))
		edge:SetHeight(2)
		edge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 0)
		edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 0)
		edge:Hide()
		button.edge = edge

		local text = button:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(Kit.GetFont(12, true))
		text:SetPoint("CENTER", button, "CENTER", 0, 0)
		text:SetText(info.label)
		button.text = text

		button:SetScript("OnClick", function(self)
			Panel:SetTab(self.key)
		end)
		button:SetScript("OnEnter", function(self)
			self.highlight:Show()
			self.text:SetTextColor(unpack(Kit.TextHighlight))
		end)
		button:SetScript("OnLeave", function(self)
			self.highlight:SetShown(self.selected and true or false)
			self.text:SetTextColor(unpack(self.selected and Kit.TextSelected or Kit.TextNormal))
		end)

		Panel.tabs[index] = button
	end

	----------------------------------------------------------------
	-- Page
	----------------------------------------------------------------
	-- Where you are, what this page is, and what it is for. The artifact opens
	-- every page with these three before the first row.
	local pageHead = CreateFrame("Frame", nil, frame)
	pageHead:SetHeight(PAGE_HEAD_H)
	pageHead:SetPoint("TOPLEFT", rail, "TOPRIGHT", 12, 0)
	pageHead:SetPoint("RIGHT", frame, "RIGHT", -14, 0)

	local crumb = pageHead:CreateFontString(nil, "OVERLAY")
	crumb:SetFontObject(Kit.GetFont(11, true))
	crumb:SetPoint("TOPLEFT", pageHead, "TOPLEFT", 2, -2)
	crumb:SetJustifyH("LEFT")
	crumb:SetWordWrap(false)
	Panel.crumb = crumb

	local pageTitle = pageHead:CreateFontString(nil, "OVERLAY")
	pageTitle:SetFontObject(Kit.GetFont(18, true))
	pageTitle:SetPoint("TOPLEFT", crumb, "BOTTOMLEFT", 0, -3)
	pageTitle:SetPoint("RIGHT", pageHead, "RIGHT", 0, 0)
	pageTitle:SetJustifyH("LEFT")
	pageTitle:SetWordWrap(false)
	Panel.pageTitle = pageTitle

	local pageDesc = pageHead:CreateFontString(nil, "OVERLAY")
	pageDesc:SetFontObject(Kit.GetFont(12))
	pageDesc:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -3)
	pageDesc:SetPoint("RIGHT", pageHead, "RIGHT", 0, 0)
	pageDesc:SetJustifyH("LEFT")
	pageDesc:SetWordWrap(false)
	Panel.pageDesc = pageDesc

	local headRule = pageHead:CreateTexture(nil, "ARTWORK")
	headRule:SetTexture(Kit.GetMedia("plain"))
	headRule:SetHeight(1)
	headRule:SetPoint("BOTTOMLEFT", pageHead, "BOTTOMLEFT", 0, 2)
	headRule:SetPoint("BOTTOMRIGHT", pageHead, "BOTTOMRIGHT", 0, 2)
	Panel.headRule = headRule

	contentScroll = CreateFrame("ScrollFrame", nil, frame)
	contentScroll:SetPoint("TOPLEFT", pageHead, "BOTTOMLEFT", 0, -4)
	contentScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, FOOTER_H + 8)
	contentScroll:SetClipsChildren(true)

	pageContent = CreateFrame("Frame", nil, contentScroll)
	pageContent:SetSize(600, 1)
	contentScroll:SetScrollChild(pageContent)

	contentScroll:EnableMouseWheel(true)
	contentScroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * 50)))
	end)
	contentScroll:SetScript("OnSizeChanged", function(self, width)
		if (not width or width <= 0) then return end

		pageContent:SetWidth(width)

		-- Wrapped text is measured against the page width, so a narrower window
		-- needs the page laid out again. Until now nothing did that: resizing
		-- re-wrapped every help line and left every row the height it had.
		if (page and page.width ~= width) then
			page:Layout()
			Panel:UpdateActiveSection()
		end
	end)

	contentScroll:SetScript("OnVerticalScroll", function()
		Panel:UpdateActiveSection()
	end)

	page = Renderer:CreatePage(pageContent)
	page.OnChanged = function(_, path) Panel:OnSettingChanged(path) end
	Panel.page = page

	-- Both scroll frames are on the panel as well as in these upvalues, so the
	-- harness can move them the way a mouse wheel would, the rail's rows so it
	-- can click one, and the window itself so it can read back what was painted
	-- on it.
	Panel.contentScroll = contentScroll
	Panel.railScroll = railScroll
	Panel.railRows = railRows
	Panel.frame = frame

	----------------------------------------------------------------
	-- Footer
	----------------------------------------------------------------
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(FOOTER_H)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FOOTER_INSET, 8)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FOOTER_INSET, 8)

	local combatIcon = footer:CreateTexture(nil, "ARTWORK")
	combatIcon:SetTexture(Kit.GetMedia("icon-combat"))
	local combatSize = Kit.DrawSize(16, "icon_combat")
	combatIcon:SetSize(combatSize, combatSize)
	combatIcon:SetPoint("LEFT", footer, "LEFT", 0, 0)
	combatIcon:Hide()

	local combatText = footer:CreateFontString(nil, "OVERLAY")
	combatText:SetFontObject(Kit.GetFont(12))
	combatText:SetPoint("LEFT", combatIcon, "RIGHT", 4, 0)
	combatText:SetJustifyH("LEFT")
	combatText:SetText(L["Settings that move or rebuild frames wait until you leave combat."])
	combatText:Hide()
	Panel.combatText = combatText

	local previewStatus = CreateFrame("Frame", nil, footer)
	previewStatus:SetPoint("LEFT", footer, "CENTER", PREVIEW_LEFT, 0)
	previewStatus:SetPoint("RIGHT", footer, "RIGHT", PREVIEW_RIGHT, 0)
	previewStatus:SetHeight(FOOTER_H)
	previewStatus:Hide()

	local previewText = previewStatus:CreateFontString(nil, "OVERLAY")
	previewText:SetFontObject(Kit.GetFont(12, true))
	previewText:SetAllPoints()
	previewText:SetJustifyH("RIGHT")
	previewText:SetWordWrap(false)
	Panel.previewStatus = previewStatus
	Panel.previewText = previewText

	previewStatus:SetScript("OnUpdate", function(self, elapsed)
		self.remaining = (self.remaining or 0) - elapsed
		if (self.remaining <= 0) then
			self:Hide()
			self:SetAlpha(1)
		elseif (self.remaining < .5) then
			self:SetAlpha(self.remaining / .5)
		end
	end)

	local resizer = CreateFrame("Button", nil, frame)
	resizer:SetSize(16, 16)
	resizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	resizer:RegisterForDrag("LeftButton")
	resizer:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
	resizer:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition()
	end)

	local grip = resizer:CreateTexture(nil, "OVERLAY")
	grip:SetAllPoints()
	grip:SetVertexColor(.5, .5, .5)
	Kit.SetGlyph(grip, "grip")
	resizer:SetScript("OnEnter", function() grip:SetVertexColor(unpack(Kit.TextSelected)) end)
	resizer:SetScript("OnLeave", function() grip:SetVertexColor(.5, .5, .5) end)

	local watcher = CreateFrame("Frame", nil, frame)
	watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:SetScript("OnEvent", function()
		local inCombat = InCombatLockdown()
		combatIcon:SetShown(inCombat)
		combatText:SetShown(inCombat)
	end)

	frame:SetScript("OnShow", function()
		local inCombat = InCombatLockdown()
		combatIcon:SetShown(inCombat)
		combatText:SetShown(inCombat)
	end)

	-- Position last, so nothing above depends on the size it lands at.
	local geometry = GetGeometry()
	if (geometry) then
		frame:SetSize(max(MIN_W, geometry.width or DEFAULT_W),
			max(MIN_H, geometry.height or DEFAULT_H))
		if (geometry.point and geometry.x and geometry.y) then
			frame:ClearAllPoints()
			frame:SetPoint(geometry.point, UIParent,
				geometry.relativePoint or geometry.point, geometry.x, geometry.y)
		end
	end

	return frame
end

--------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------
Panel.Open = function(self, key)
	local options = GetOptions()
	if (not options) then return false end

	self:LoadTheme()

	if (not frame) then
		local ok, err = pcall(Build)
		if (not ok) then
			frame = nil
			ns:Print("The options panel could not be built:", tostring(err))
			return false
		end
	end

	self.changedByPage = {}
	self:BuildRail()

	frame:Show()
	frame:Raise()

	key = key or self.selected
	if (not key or not (GetView(key) or Config.GetSubOption(options, key))) then
		key = self.pages and self.pages[1] and self.pages[1].key
	end
	self:SelectPage(key)

	return true
end

Panel.Close = function(self)
	if (frame) then frame:Hide() end
	if (Kit.Preview) then Kit.Preview:Hide() end
end

Panel.IsShown = function(self)
	return frame and frame:IsShown()
end

Panel.Toggle = function(self)
	if (self:IsShown()) then
		self:Close()
		return true
	end
	return self:Open()
end

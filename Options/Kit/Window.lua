--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The options window.
--
-- AzeriteUI owns the window, the page rail and the search. AceConfigDialog
-- still builds every page, fed into our own container through
-- AceConfigDialog:Open(appName, container, path). The stock TreeGroup is
-- hard-coded (AceConfigDialog-3.0.lua:1722), which is why the page list here
-- is ours rather than a restyled tree.
local Addon, ns = ...

local AceGUI = LibStub("AceGUI-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
if (not AceGUI or not AceConfigDialog or not AceConfigRegistry) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)
local Kit = ns.OptionsKit
local GetFont, GetMedia = Kit.GetFont, Kit.GetMedia

-- Lua API
local ipairs, pairs = ipairs, pairs
local max, min = math.max, math.min
local pcall = pcall
local string_find, string_lower = string.find, string.lower
local table_sort = table.sort
local table_wipe = table.wipe or wipe
local tostring, type = tostring, type
local unpack = unpack

-- GLOBALS: CreateFrame, GameTooltip, InCombatLockdown, UIParent, UISpecialFrames
-- GLOBALS: C_AddOns, SEARCH

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 920, 700
local MIN_WIDTH, MIN_HEIGHT = 760, 520
local RAIL_WIDTH = 196
local HEADER_HEIGHT = 46
local FOOTER_HEIGHT = 26

local Window = {}
Kit.Window = Window

--------------------------------------------------------------------------
-- Option table helpers
--------------------------------------------------------------------------
-- Names and hidden flags may be functions. AceConfigDialog calls them with a
-- fully built info table; we have no such table outside a feed, so these are
-- attempted and quietly fall back. Every top-level page name is a plain
-- string already, because Options.GenerateOptionsMenu sorts on it directly.
local Resolve = function(value, fallback)
	if (type(value) == "function") then
		local ok, result = pcall(value)
		if (ok and result ~= nil) then return result end
		return fallback
	end
	if (value ~= nil) then return value end
	return fallback
end

local IsHidden = function(v)
	return Resolve(v.hidden, false) and true or false
end

--------------------------------------------------------------------------
-- dialogControl
--------------------------------------------------------------------------
-- Rather than repeating a dialogControl line across five thousand lines of
-- option definitions, the whole table is walked once after it is generated.
-- Anything that already names a control of its own is left alone.
local ControlFor = function(v)
	local t = v.type

	if (t == "toggle") then
		return Kit.Types.CheckBox

	elseif (t == "range") then
		return Kit.Types.Slider

	elseif (t == "header") then
		return Kit.Types.Heading

	elseif (t == "select") then
		-- Radio styles are built by AceConfigDialog out of stock checkboxes
		-- and never consult dialogControl.
		if (v.style ~= "radio") then
			return Kit.Types.Dropdown
		end

	elseif (t == "input") then
		-- Multiline inputs need the stock MultiLineEditBox.
		if (not v.multiline) then
			return Kit.Types.EditBox
		end

	elseif (t == "execute") then
		-- An execute carrying an image is built as an Icon, not a Button.
		if (v.image == nil) then
			return Kit.Types.Button
		end
	end
end

-- Every option we point at one of our widgets is remembered, so the injection
-- can be undone exactly, touching nothing that named a control of its own.
local injected = {}

local ApplyDialogControls
ApplyDialogControls = function(group)
	if (type(group) ~= "table" or type(group.args) ~= "table") then return end

	for key, v in pairs(group.args) do
		if (type(v) == "table") then
			if (v.type == "group") then
				ApplyDialogControls(v)
			elseif (not v.dialogControl and not v.control) then
				local control = ControlFor(v)
				if (control) then
					v.dialogControl = control
					injected[#injected + 1] = v
				end
			end
		end
	end
end

Window.ApplyDialogControls = function(self, options)
	table_wipe(injected)
	ApplyDialogControls(options)
end

-- Hands every option back to its stock AceGUI widget.
--
-- `/az classic` has to produce a window built entirely from stock parts. While
-- the injected controls stayed on the table, a broken widget of ours took the
-- fallback down with it, which is precisely what happened on the first run in
-- game: a bad font object threw from our checkbox, the window failed to build,
-- and the classic window it fell back to then threw the same error nineteen
-- times over.
Window.RemoveDialogControls = function(self)
	for i = 1, #injected do
		injected[i].dialogControl = nil
	end
	table_wipe(injected)
end

--------------------------------------------------------------------------
-- Search index
--------------------------------------------------------------------------
local searchIndex = {}

local IndexGroup
IndexGroup = function(group, path, trail)
	if (type(group.args) ~= "table") then return end

	for key, v in pairs(group.args) do
		if (type(v) == "table" and not IsHidden(v)) then
			local name = Resolve(v.name, key)
			if (type(name) ~= "string") then name = key end

			if (v.type == "group") then
				local childPath, childTrail = {}, trail .. (trail == "" and "" or " > ") .. name
				for i, step in ipairs(path) do childPath[i] = step end
				childPath[#childPath + 1] = key
				IndexGroup(v, childPath, childTrail)

			elseif (v.type ~= "description") then
				local desc = Resolve(v.desc, nil)
				if (type(desc) ~= "string") then desc = nil end

				local entry = {
					path = path,
					trail = trail,
					name = name,
					haystack = string_lower(name .. " " .. (desc or ""))
				}
				searchIndex[#searchIndex + 1] = entry
			end
		end
	end
end

local BuildSearchIndex = function(options)
	table_wipe(searchIndex)
	if (type(options) ~= "table") then return end

	for key, v in pairs(options.args or {}) do
		if (type(v) == "table" and v.type == "group" and not IsHidden(v)) then
			local name = Resolve(v.name, key)
			if (type(name) ~= "string") then name = key end
			IndexGroup(v, { key }, name)
		end
	end
end

--------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------
-- Window size and position are a convenience, not a setting, so they live in
-- the global section and stay out of profiles and export strings.
local GetGeometry = function()
	local db = ns.db
	if (not db or not db.global) then return end

	if (type(db.global.optionsWindow) ~= "table") then
		db.global.optionsWindow = {}
	end
	return db.global.optionsWindow
end

--------------------------------------------------------------------------
-- The frame
--------------------------------------------------------------------------
local frame, rail, railScroll, railContent, content, searchBox, page
local railButtons, resultButtons = {}, {}

local SavePosition = function()
	local geometry = GetGeometry()
	if (not geometry or not frame) then return end

	local point, _, relativePoint, x, y = frame:GetPoint()
	geometry.point, geometry.relativePoint = point, relativePoint
	geometry.x, geometry.y = x, y
	geometry.width, geometry.height = frame:GetWidth(), frame:GetHeight()
end

local RestorePosition = function()
	local geometry = GetGeometry()
	if (not geometry or not frame) then return end

	frame:SetSize(
		max(MIN_WIDTH, geometry.width or DEFAULT_WIDTH),
		max(MIN_HEIGHT, geometry.height or DEFAULT_HEIGHT)
	)
	frame:ClearAllPoints()
	if (geometry.point and geometry.x and geometry.y) then
		frame:SetPoint(geometry.point, UIParent, geometry.relativePoint or geometry.point, geometry.x, geometry.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- A rail button, reused between rebuilds.
local Rail_OnClick = function(button)
	Window:SelectPage(button.key)
end

local Rail_OnEnter = function(button)
	if (not button.selected) then
		button.text:SetTextColor(unpack(Kit.TextHighlight))
	end
	button.highlight:Show()

	if (button.desc) then
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine(button.text:GetText(), unpack(Kit.TextSelected))
		GameTooltip:AddLine(button.desc, unpack(Kit.TextNormal), true)
		GameTooltip:Show()
	end
end

local Rail_OnLeave = function(button)
	button.text:SetTextColor(unpack(button.selected and Kit.TextSelected or Kit.TextNormal))
	button.highlight:SetShown(button.selected)
	GameTooltip:Hide()
end

-- Page buttons carry a single line. Search results carry two: the option's
-- own name, and the trail of groups it was found under.
local CreateRailButton = function(index, list, height, onClick, withTrail)
	local button = list[index]
	if (button) then return button end

	button = CreateFrame("Button", nil, railContent)
	button:SetHeight(height)
	button:SetPoint("LEFT", railContent, "LEFT", 0, 0)
	button:SetPoint("RIGHT", railContent, "RIGHT", 0, 0)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", Rail_OnEnter)
	button:SetScript("OnLeave", Rail_OnLeave)

	local highlight = button:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(GetMedia("bar-small"))
	highlight:SetAllPoints()
	highlight:SetVertexColor(Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3], .2)
	highlight:Hide()

	local text = button:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GetFont(14, true))
	text:SetJustifyH("LEFT")
	text:SetTextColor(unpack(Kit.TextNormal))

	-- Both lines are held to one line each and clipped to the rail. Long
	-- option names used to wrap and spill across the page beside them.
	if (withTrail) then
		text:SetFontObject(GetFont(13))
		text:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -2)
		text:SetPoint("TOPRIGHT", button, "TOPRIGHT", -8, -2)
		text:SetHeight(15)
		text:SetWordWrap(false)

		local trail = button:CreateFontString(nil, "OVERLAY")
		trail:SetFontObject(GetFont(11))
		trail:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -18)
		trail:SetPoint("TOPRIGHT", button, "TOPRIGHT", -8, -18)
		trail:SetHeight(13)
		trail:SetJustifyH("LEFT")
		trail:SetWordWrap(false)
		trail:SetTextColor(unpack(Kit.TextDisabled))
		button.trail = trail
	else
		text:SetPoint("LEFT", button, "LEFT", 10, 0)
		text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
		text:SetWordWrap(false)

		-- Set explicitly rather than left unset, so that reading it back is
		-- answered by the button itself and never falls through to whatever
		-- a frame might one day answer for an unknown key.
		button.trail = false
	end

	button.highlight = highlight
	button.text = text

	list[index] = button
	return button
end

local Result_OnClick = function(button)
	Window:NavigateTo(button.path)
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
Window.GetOptions = function(self)
	if (not AceConfigRegistry:GetOptionsTable(Addon)) then return end

	local module = ns:GetModule("Options", true)
	return module and module:GetOptionsObject()
end

-- Rebuilds the page list out of the registered options table.
Window.BuildRail = function(self)
	local options = self:GetOptions()
	if (not options) then return end

	local pages = {}
	for key, v in pairs(options.args or {}) do
		if (type(v) == "table" and v.type == "group" and not IsHidden(v)) then
			local name = Resolve(v.name, key)
			if (type(name) ~= "string") then name = key end
			pages[#pages + 1] = { key = key, name = name, order = v.order or 0, desc = Resolve(v.desc, nil) }
		end
	end

	table_sort(pages, function(a, b)
		if (a.order == b.order) then return a.name < b.name end
		return a.order < b.order
	end)

	self.pages = pages

	local offset = 0
	for i, entry in ipairs(pages) do
		local button = CreateRailButton(i, railButtons, 24, Rail_OnClick)
		button:SetPoint("TOP", railContent, "TOP", 0, -offset)
		button.key = entry.key
		button.desc = type(entry.desc) == "string" and entry.desc or nil
		button.text:SetText(entry.name)
		button.selected = (entry.key == self.selected)
		button.text:SetTextColor(unpack(button.selected and Kit.TextSelected or Kit.TextNormal))
		button.highlight:SetShown(button.selected)
		button:Show()
		offset = offset + 24
	end

	for i = #pages + 1, #railButtons do
		railButtons[i]:Hide()
	end

	railContent:SetHeight(max(1, offset))
	railScroll:SetVerticalScroll(0)

	-- The index is rebuilt with the rail, so search never points at a page
	-- that no longer exists.
	BuildSearchIndex(options)
end

Window.ShowResults = function(self, query)
	for i = 1, #railButtons do railButtons[i]:Hide() end

	query = string_lower(query or "")

	local matches = {}
	for i, entry in ipairs(searchIndex) do
		if (string_find(entry.haystack, query, 1, true)) then
			matches[#matches + 1] = entry
			if (#matches >= 60) then break end
		end
	end

	local offset = 0
	for i, entry in ipairs(matches) do
		local button = CreateRailButton(i, resultButtons, 32, Result_OnClick, true)
		button:SetPoint("TOP", railContent, "TOP", 0, -offset)
		button.path = entry.path
		button.key = nil
		button.desc = nil
		button.selected = false
		button.text:SetText(entry.name)
		button.text:SetTextColor(unpack(Kit.TextNormal))
		button.trail:SetText(entry.trail)
		button.highlight:Hide()
		button:Show()

		offset = offset + 32
	end

	for i = #matches + 1, #resultButtons do
		resultButtons[i]:Hide()
	end

	railContent:SetHeight(max(1, offset))
	railScroll:SetVerticalScroll(0)

	self.empty:SetShown(#matches == 0)
	if (#matches == 0) then
		self.empty:SetFormattedText(L["Nothing matches '%s'."], query)
	end
end

Window.ClearSearch = function(self)
	for i = 1, #resultButtons do resultButtons[i]:Hide() end
	self.empty:Hide()
	self:BuildRail()
end

-- Opens a page by its top-level key.
Window.SelectPage = function(self, key)
	if (not key) then return end

	self.selected = key
	self.path = { key }

	for i = 1, #railButtons do
		local button = railButtons[i]
		button.selected = (button.key == key)
		button.text:SetTextColor(unpack(button.selected and Kit.TextSelected or Kit.TextNormal))
		button.highlight:SetShown(button.selected)
	end

	Kit.CloseDropdown()
	AceConfigDialog:Open(Addon, page, key)
end

-- Opens the page holding a deeper path, with each tab along the way already
-- selected, so a search result lands on the option it named.
Window.NavigateTo = function(self, path)
	if (type(path) ~= "table" or #path == 0) then return end

	for i = 1, #path - 1 do
		local ancestor = {}
		for j = 1, i do ancestor[j] = path[j] end

		local status = AceConfigDialog:GetStatusTable(Addon, ancestor)
		status.groups = status.groups or {}
		status.groups.selected = path[i + 1]
	end

	self:SelectPage(path[1])
end

Window.Refresh = function(self)
	if (not frame or not frame:IsShown()) then return end

	self:BuildRail()
	if (searchBox:GetText() ~= "") then
		self:ShowResults(searchBox:GetText())
	end
	if (self.selected) then
		AceConfigDialog:Open(Addon, page, self.selected)
	end
end

Window.IsShown = function(self)
	return frame and frame:IsShown()
end

Window.Close = function(self)
	if (frame) then
		frame:Hide()
	end
end

--------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------
local Search_OnTextChanged = function(editbox, userInput)
	local text = editbox:GetText()
	editbox.placeholder:SetShown(text == "")

	if (not userInput) then return end

	if (text == "") then
		Window:ClearSearch()
	else
		Window:ShowResults(text)
	end
end

local CreateWindow = function()
	local name = ns.Prefix .. "OptionsFrame"

	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetBackdrop(Kit.WindowBackdrop)
	frame:SetBackdropColor(unpack(Kit.WindowColor))
	frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))

	if (frame.SetResizeBounds) then
		frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
	end

	-- Escape closes the window, the same as every other panel in the game.
	UISpecialFrames[#UISpecialFrames + 1] = name

	frame:SetScript("OnHide", function()
		Kit.CloseDropdown()
		SavePosition()
	end)

	----------------------------------------------------------------
	-- Header
	----------------------------------------------------------------
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(HEADER_HEIGHT)
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
	logo:SetTexture(GetMedia("power-crystal-ice-icon"))
	logo:SetSize(34, 34)
	logo:SetPoint("LEFT", header, "LEFT", 6, 0)

	-- The version is anchored to the right of the header and the title stops
	-- short of it. Hanging the version off the end of the title instead pushed
	-- it straight off the window edge, where it read as a truncated "5.4.".
	local version = header:CreateFontString(nil, "OVERLAY")
	version:SetFontObject(GetFont(12))
	version:SetPoint("RIGHT", header, "RIGHT", -36, -1)
	version:SetJustifyH("RIGHT")
	version:SetWordWrap(false)
	version:SetTextColor(unpack(Kit.TextDisabled))
	version:SetText(C_AddOns.GetAddOnMetadata(Addon, "Version") or "")
	Window.version = version

	local title = header:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(GetFont(18, true))
	title:SetPoint("LEFT", logo, "RIGHT", 8, 1)
	title:SetPoint("RIGHT", version, "LEFT", -10, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText(
		"|cff4488bbAzerite|r|cfffafafaUI|r  |cff00ff00" .. (L["JuNNeZ Edition"] or "JuNNeZ Edition") .. "|r"
	)

	-- The close button follows the cog in Components/Misc/MicroMenu.lua: two
	-- same-size textures, the lit one swapped in on enter.
	local close = CreateFrame("Button", nil, header)
	close:SetSize(26, 26)
	close:SetPoint("RIGHT", header, "RIGHT", -4, 0)
	close:SetScript("OnClick", function() frame:Hide() end)

	local closeSize = Kit.DrawSize(26, "options_close")

	local closeTexture = close:CreateTexture(nil, "ARTWORK")
	closeTexture:SetTexture(GetMedia("options-close"))
	closeTexture:SetSize(closeSize, closeSize)
	closeTexture:SetPoint("CENTER")

	local closeBright = close:CreateTexture(nil, "OVERLAY")
	closeBright:SetTexture(GetMedia("options-close-bright"))
	closeBright:SetSize(closeSize, closeSize)
	closeBright:SetPoint("CENTER")
	closeBright:Hide()

	close:SetScript("OnEnter", function() closeBright:Show() end)
	close:SetScript("OnLeave", function() closeBright:Hide() end)

	----------------------------------------------------------------
	-- Search
	----------------------------------------------------------------
	local search = CreateFrame("EditBox", nil, frame)
	search:SetHeight(24)
	search:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -8)
	search:SetWidth(RAIL_WIDTH - 12)
	search:SetAutoFocus(false)
	search:SetFontObject(GetFont(12))
	search:SetTextInsets(22, 6, 0, 0)
	search:SetTextColor(unpack(Kit.TextHighlight))

	local searchBackdrop = Kit.CreateBackdrop(search, Kit.InsetBackdrop, 2)
	searchBackdrop:SetBackdropColor(unpack(Kit.InsetColor))
	Window.searchBackdrop = searchBackdrop

	local searchGlyph = search:CreateTexture(nil, "OVERLAY")
	searchGlyph:SetSize(14, 14)
	searchGlyph:SetPoint("LEFT", search, "LEFT", 5, 0)
	searchGlyph:SetVertexColor(unpack(Kit.TextSelected))
	Kit.SetGlyph(searchGlyph, "search")

	local placeholder = search:CreateFontString(nil, "ARTWORK")
	placeholder:SetFontObject(GetFont(12))
	placeholder:SetPoint("LEFT", search, "LEFT", 22, 0)
	placeholder:SetTextColor(unpack(Kit.TextDisabled))
	placeholder:SetText(L["Search settings"])

	search.placeholder = placeholder
	Window.searchGlyph = searchGlyph
	Window.placeholder = placeholder
	Window.searchBox = search
	search:SetScript("OnTextChanged", Search_OnTextChanged)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		Window:ClearSearch()
	end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEditFocusGained", function()
		Kit.SetBorderColor(searchBackdrop, Kit.BorderFocus)
	end)
	search:SetScript("OnEditFocusLost", function()
		Kit.SetBorderColor(searchBackdrop, Kit.BorderIdle)
	end)

	searchBox = search

	----------------------------------------------------------------
	-- Rail
	----------------------------------------------------------------
	-- Both points fix the left edge, and to the same place: the search box sits
	-- 6 in from the header, which sits 8 in from the window. Anchoring the
	-- bottom by "BOTTOM" instead would fix the horizontal centre as well, and
	-- fight the left edge the top point already set.
	rail = CreateFrame("Frame", nil, frame)
	rail:SetWidth(RAIL_WIDTH)
	rail:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -8)
	rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, FOOTER_HEIGHT + 8)

	local railEdge = rail:CreateTexture(nil, "ARTWORK")
	railEdge:SetTexture(GetMedia("bar-small"))
	railEdge:SetWidth(2)
	railEdge:SetPoint("TOPRIGHT", rail, "TOPRIGHT", 0, 0)
	railEdge:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 0, 0)
	railEdge:SetVertexColor(.3, .3, .3, .6)
	Window.railEdge = railEdge

	-- The page list and the search results both live on this scroll frame. A
	-- search across every page can return far more rows than the window is
	-- tall, and without a scroll frame they simply drew on past the bottom
	-- edge and out over the page beside them.
	railScroll = CreateFrame("ScrollFrame", nil, rail)
	railScroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, 0)
	railScroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -6, 0)
	railScroll:SetClipsChildren(true)

	railContent = CreateFrame("Frame", nil, railScroll)
	railContent:SetSize(RAIL_WIDTH - 10, 1)
	railScroll:SetScrollChild(railContent)

	railScroll:EnableMouseWheel(true)
	railScroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end

		local value = self:GetVerticalScroll() - delta * 40
		self:SetVerticalScroll(min(range, max(0, value)))
	end)

	-- Keeps the scroll child as wide as the visible area, so rows anchored to
	-- its edges never reach past the rail.
	railScroll:SetScript("OnSizeChanged", function(self, width)
		if (width and width > 0) then
			railContent:SetWidth(width)
		end
	end)

	local empty = rail:CreateFontString(nil, "OVERLAY")
	empty:SetFontObject(GetFont(12))
	empty:SetPoint("TOPLEFT", rail, "TOPLEFT", 10, -10)
	empty:SetPoint("RIGHT", rail, "RIGHT", -10, 0)
	empty:SetJustifyH("LEFT")
	empty:SetTextColor(unpack(Kit.TextDisabled))
	empty:Hide()
	Window.empty = empty

	----------------------------------------------------------------
	-- Content
	----------------------------------------------------------------
	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 10, 0)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, FOOTER_HEIGHT + 8)

	page = AceGUI:Create(Kit.Types.Page)
	page.frame:SetParent(content)
	page.frame:ClearAllPoints()
	page.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	page.frame:Show()

	local SizePage = function()
		page:SetWidth(content:GetWidth())
		page:SetHeight(content:GetHeight())
	end
	content:SetScript("OnSizeChanged", SizePage)

	----------------------------------------------------------------
	-- Footer
	----------------------------------------------------------------
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(FOOTER_HEIGHT)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)

	local combatIcon = footer:CreateTexture(nil, "ARTWORK")
	combatIcon:SetTexture(GetMedia("icon-combat"))
	local combatSize = Kit.DrawSize(16, "icon_combat")
	combatIcon:SetSize(combatSize, combatSize)
	combatIcon:SetPoint("LEFT", footer, "LEFT", 0, 0)
	combatIcon:Hide()

	local combatText = footer:CreateFontString(nil, "OVERLAY")
	combatText:SetFontObject(GetFont(12))
	combatText:SetPoint("LEFT", combatIcon, "RIGHT", 4, 0)
	combatText:SetJustifyH("LEFT")
	combatText:SetTextColor(unpack(Kit.TextDisabled))
	combatText:SetText(L["Settings that move or rebuild frames wait until you leave combat."])
	Window.combatText = combatText
	combatText:Hide()

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

	-- The combat notice is driven by events rather than polled.
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
		SizePage()
	end)

	RestorePosition()
	SizePage()

	return frame
end

-- Widgets re-read the theme when AceGUI hands them out again, but the window
-- chrome is built once and never pooled, so it is recoloured explicitly.
Window.ApplyTheme = function(self)
	if (not frame) then return end

	frame:SetBackdropColor(unpack(Kit.WindowColor))
	frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))

	if (self.searchBackdrop) then
		self.searchBackdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(self.searchBackdrop, Kit.BorderIdle)
	end

	if (self.searchGlyph) then self.searchGlyph:SetVertexColor(unpack(Kit.TextSelected)) end
	if (self.placeholder) then self.placeholder:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.searchBox) then self.searchBox:SetTextColor(unpack(Kit.TextHighlight)) end
	if (self.version) then self.version:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.empty) then self.empty:SetTextColor(unpack(Kit.TextDisabled)) end
	if (self.combatText) then self.combatText:SetTextColor(unpack(Kit.TextDisabled)) end

	if (self.railEdge) then
		local border = Kit.BorderIdle
		self.railEdge:SetVertexColor(border[1], border[2], border[3], .8)
	end

	for _, list in ipairs({ railButtons, resultButtons }) do
		for i = 1, #list do
			local button = list[i]
			local accent = Kit.TextSelected
			button.highlight:SetVertexColor(accent[1], accent[2], accent[3], .2)
			button.text:SetTextColor(unpack(button.selected and accent or Kit.TextNormal))
			if (button.trail) then button.trail:SetTextColor(unpack(Kit.TextDisabled)) end
		end
	end
end

-- The chosen theme is a convenience like the window geometry, so it lives
-- in the global section rather than in a settings profile.
Window.LoadTheme = function(self)
	local db = ns.db
	Kit.SetTheme((db and db.global and db.global.optionsTheme) or "azerite")

	-- After the theme, because opacity scales whatever alpha it just set.
	if (db and db.global and db.global.optionsOpacity) then
		Kit.SetOpacity(db.global.optionsOpacity)
	end
end

Window.SetTheme = function(self, key)
	Kit.SetTheme(key)

	local db = ns.db
	if (db and db.global) then
		db.global.optionsTheme = Kit.GetTheme()
	end

	self:ApplyTheme()

	-- Re-feed the page so every pooled widget is acquired again and picks
	-- up the new colours.
	if (frame and frame:IsShown() and self.selected) then
		AceConfigDialog:Open(Addon, page, self.selected)
	end
end

Window.Open = function(self, ...)
	local options = self:GetOptions()
	if (not options) then return false end

	-- `/az classic` strips these on its way out, so put them back.
	self:ApplyDialogControls(options)

	-- Applied before the frame is built, so the chrome is created in the
	-- right colours rather than flashing the default ones first.
	self:LoadTheme()

	if (not frame) then
		local ok, err = pcall(CreateWindow)
		if (not ok) then
			frame = nil
			ns:Print("The options window could not be built, falling back to the classic window:", tostring(err))
			return false
		end
	end

	self:BuildRail()
	self:ApplyTheme()

	frame:Show()
	frame:Raise()

	local key = ...
	if (not key) then
		key = self.selected
		if (not key or not options.args[key]) then
			key = self.pages and self.pages[1] and self.pages[1].key
		end
	end

	self:SelectPage(key)

	return true
end

Window.Toggle = function(self)
	if (self:IsShown()) then
		self:Close()
		return true
	end
	return self:Open()
end

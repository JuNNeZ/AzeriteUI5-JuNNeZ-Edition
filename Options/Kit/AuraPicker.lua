--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The nameplate aura picker: /az -> Nameplates -> Aura filters -> Choose auras.
--
-- One row per debuff, with its icon and name, and two boxes: Gold (a gold border, kept per specialization)
-- and Only once (shown at most once on a plate, for the whole profile). It edits the same two lists the
-- spell ID fields hold, through NamePlates/AuraLists.lua, so nothing about how they are stored changes and
-- nothing is written without a click. Docs/Nameplate Aura Picker Plan - 2026-11-21.md, steps 1 and 2:
-- * Your spec: NamePlates/AuraSuggestions.lua's checked table, talented first, untalented greyed, and
--   "Use recommended", which replaces both lists after asking.
-- * Seen on your targets: what AuraLists has read off enemy plates out of combat, for this specialization.
-- * Group debuffs: the few that help everyone.
-- * All classes (folded): every specialization's suggestions, with a search and a class filter.
-- * Other entries: IDs in the lists that no section above shows, so they can be seen and removed.
-- * Spell IDs by hand: the two fields, folded closed.
-- Each ID appears once, in the first section that has it.
-- Built the way the frame settings panel is (FramePanel.lua): the options window's fill and casing, the
-- theme's colours, Escape closes it. Writes wait out combat: the boxes are off while it lasts.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Controls = Kit and Kit.Controls
if (not Kit or not Controls) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local max = math.max
local pcall = pcall
local string_format = string.format
local tostring = tostring
local type = type
local unpack = unpack

-- GLOBALS: C_ClassColor, C_Spell, CreateFrame, GameTooltip, GetSpecialization, GetSpecializationInfo
-- GLOBALS: InCombatLockdown, LOCALIZED_CLASS_NAMES_MALE, PlaySound, RAID_CLASS_COLORS, UIParent
-- GLOBALS: UISpecialFrames, UnitClass

local WIDTH, HEIGHT = 500, 660
local PAD = 18
local ROW_H = 30
local HEADER_H = 28
local BOX = 18
-- The two boxes' centres, in from the content's right edge.
local ONCE_X, GOLD_X = 22, 78
local SOUND_ON, SOUND_OFF = 856, 857

local AuraPicker = {}
Kit.AuraPicker = AuraPicker

local frame, scroll, content, scrollBar
local headers, rows, inputs = {}, {}, {}
local folded = { spec = false, seen = false, group = false, all = true, other = false, manual = true }
-- "All classes": the search text (lower case) and the class token, or nil for every class.
local filter = { text = "", class = nil }
local allControls = {}
local recommendButton

local GetLists = function()
	local NP = ns.NamePlatesPrivate
	return NP and NP.AuraLists
end

local GetSuggestions = function()
	local NP = ns.NamePlatesPrivate
	return NP and NP.AuraSuggestions
end

--------------------------------------------------------------------------
-- What a row shows
--------------------------------------------------------------------------
local GetSpellInfo = function(spellID)
	local name, icon
	if (C_Spell and C_Spell.GetSpellName) then name = C_Spell.GetSpellName(spellID) end
	if (C_Spell and C_Spell.GetSpellTexture) then icon = C_Spell.GetSpellTexture(spellID) end
	if (not name and C_Spell and C_Spell.RequestLoadSpellData) then
		-- SPELL_DATA_LOAD_RESULT brings the name; the row says the ID until then.
		pcall(C_Spell.RequestLoadSpellData, spellID)
	end
	return name, icon
end

local GetClassText = function(class)
	if (type(class) ~= "string") then return end
	local label = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
	local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
		or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if (color and color.WrapTextInColorCode) then return color:WrapTextInColorCode(label) end
	return label
end

local GetSpecText = function()
	if (type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function") then
		local index = GetSpecialization()
		if (index) then
			local _, name = GetSpecializationInfo(index)
			if (type(name) == "string" and name ~= "") then return name end
		end
	end
	local name = UnitClass and UnitClass("player")
	return type(name) == "string" and name or ""
end

local GetMaxAuras = function()
	local db = ns.GetConfig and ns.GetConfig("NamePlates")
	return db and db.AurasNumTotal or 6
end

--------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------
local CreateButton = function(parent, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(22)
	local backdrop = Kit.CreateBackdrop(button, Kit.InsetBackdrop, 1)
	local text = button:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(11))
	text:SetPoint("LEFT", button, "LEFT", 6, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	text:SetText(label)
	button.Restyle = function(self)
		local hover = self:IsEnabled() and self:IsMouseOver()
		backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(backdrop, hover and Kit.BorderHover or Kit.BorderIdle)
		text:SetTextColor(unpack((not self:IsEnabled()) and Kit.TextDisabled
			or hover and Kit.TextHighlight or Kit.TextNormal))
	end
	button:SetScript("OnEnter", button.Restyle)
	button:SetScript("OnLeave", button.Restyle)
	return button
end

local ShowTip = function(owner, title, text, note)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(title, unpack(Kit.TextHighlight))
	GameTooltip:AddLine(text, Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true)
	if (note) then
		GameTooltip:AddLine(note, Kit.TextWarning[1], Kit.TextWarning[2], Kit.TextWarning[3], true)
	end
	GameTooltip:Show()
end

local Layout

-- A box for one list. Its state is read from the list on every layout; a click only asks for the change.
local CreateBox = function(row, kind)
	local box = CreateFrame("Button", nil, row)
	box:SetSize(BOX, BOX)
	box.kind = kind
	-- A plain square with a 1px edge: the inputs' aura border has 10px corners, which at this size met in
	-- the middle and read as a faint mark in an empty box (maintainer's Forever screenshot, 2026-11-22).
	local fill = box:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(Kit.GetMedia("plain"))
	fill:SetAllPoints()
	box.fill = fill
	box.edges = {}
	for index, points in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
		local edge = box:CreateTexture(nil, "BORDER")
		edge:SetTexture(Kit.GetMedia("plain"))
		edge:SetPoint(points[1], box, points[1], 0, 0)
		edge:SetPoint(points[2], box, points[2], 0, 0)
		if (points[3]) then edge:SetWidth(points[3]) end
		if (points[4]) then edge:SetHeight(points[4]) end
		box.edges[index] = edge
	end
	local check = box:CreateTexture(nil, "OVERLAY")
	check:SetPoint("CENTER")
	check:SetSize(BOX + 2, BOX + 2)
	Kit.SetGlyph(check, "check")
	box.check = check
	box.Restyle = function(self)
		local enabled = self:IsEnabled()
		local inset = Kit.InsetColor
		self.fill:SetVertexColor(inset[1] or 0, inset[2] or 0, inset[3] or 0, 1)
		local edge = (enabled and self:IsMouseOver()) and Kit.BorderHover
			or self.checked and Kit.TextSelected or Kit.BorderIdle
		for _, texture in ipairs(self.edges) do
			texture:SetVertexColor(edge[1], edge[2], edge[3], enabled and 1 or .4)
		end
		local color = (kind == "highlight") and { 1, .82, .1 } or Kit.TextSelected
		if (not enabled) then color = Kit.TextDisabled end
		self.check:SetVertexColor(color[1], color[2], color[3], 1)
		self.check:SetShown(self.checked and true or false)
	end
	box:SetScript("OnClick", function(self)
		local lists = GetLists()
		if (not lists or not row.spellID) then return end
		-- On adds the rank shown; off takes out every rank of it.
		local ok = lists:SetListedRanks(kind, row.spellIDs or { row.spellID }, not self.checked, row.spellID)
		if (ok and PlaySound) then PlaySound(self.checked and SOUND_OFF or SOUND_ON) end
		-- AuraLists' listener lays the window out again.
	end)
	box:SetScript("OnEnter", function(self)
		self:Restyle()
		local note
		if (self.reason == "combat") then
			note = L["Changes wait until combat ends."]
		elseif (self.reason == "limit") then
			note = L["This list is full. Remove one first."]
		end
		if (kind == "highlight") then
			local perClass = ns.IsForever or ns.IsRetailContent == false
			ShowTip(self, L["Gold"], perClass and L["A gold border on this aura's icon. Kept for this class."]
				or L["A gold border on this aura's icon. Kept for this specialization."], note)
		else
			ShowTip(self, L["Only once"], L["Shown at most once on a nameplate, even when several players put it there. For the whole profile."], note)
		end
	end)
	box:SetScript("OnLeave", function(self)
		self:Restyle()
		GameTooltip:Hide()
	end)
	-- Disabled buttons take no OnEnter, so the reason a box is off would go unexplained without this.
	if (box.SetMotionScriptsWhileDisabled) then box:SetMotionScriptsWhileDisabled(true) end
	return box
end

local GetRow = function(index)
	local row = rows[index]
	if (row) then return row end
	row = CreateFrame("Frame", nil, content)
	row:SetHeight(ROW_H)
	row:EnableMouse(true)

	local hover = row:CreateTexture(nil, "BACKGROUND")
	hover:SetTexture(Kit.GetMedia("plain"))
	hover:SetAllPoints()
	hover:SetVertexColor(1, 1, 1, .035)
	hover:Hide()

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	icon:SetTexCoord(.08, .92, .08, .92)
	row.icon = icon

	local name = row:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(Kit.GetFont(12))
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1)
	name:SetPoint("RIGHT", row, "RIGHT", -(GOLD_X + 24), 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	row.name = name

	local detail = row:CreateFontString(nil, "OVERLAY")
	detail:SetFontObject(Kit.GetFont(10))
	detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, -1)
	detail:SetPoint("RIGHT", row, "RIGHT", -(GOLD_X + 24), 0)
	detail:SetJustifyH("LEFT")
	detail:SetWordWrap(false)
	row.detail = detail

	row.gold = CreateBox(row, "highlight")
	row.gold:SetPoint("CENTER", row, "RIGHT", -GOLD_X, 0)
	row.once = CreateBox(row, "once")
	row.once:SetPoint("CENTER", row, "RIGHT", -ONCE_X, 0)

	row:SetScript("OnEnter", function(self)
		hover:Show()
		if (not self.spellID) then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if (not GameTooltip:SetSpellByID(self.spellID)) then
			GameTooltip:AddLine(self.name:GetText() or "", unpack(Kit.TextHighlight))
		end
		GameTooltip:AddLine(string_format(L["Spell ID: %d"], self.spellID), unpack(Kit.TextDisabled))
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		hover:Hide()
		GameTooltip:Hide()
	end)

	rows[index] = row
	return row
end

local GetHeader = function(key)
	local header = headers[key]
	if (header) then return header end
	header = CreateFrame("Button", nil, content)
	header:SetHeight(HEADER_H)
	local sign = header:CreateFontString(nil, "OVERLAY")
	sign:SetFontObject(Kit.GetFont(13, true))
	sign:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 6, 7)
	sign:SetWidth(12)
	header.sign = sign
	local label = header:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(Kit.GetFont(12, true))
	label:SetPoint("LEFT", sign, "RIGHT", 4, 0)
	label:SetJustifyH("LEFT")
	header.label = label
	local rule = header:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(Kit.GetMedia("bar-small"))
	rule:SetHeight(3)
	rule:SetPoint("LEFT", label, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	header.rule = rule
	local empty = content:CreateFontString(nil, "OVERLAY")
	empty:SetFontObject(Kit.GetFont(11))
	empty:SetJustifyH("LEFT")
	empty:SetJustifyV("TOP")
	empty:SetWordWrap(true)
	header.empty = empty
	header:SetScript("OnClick", function()
		folded[key] = not folded[key]
		Layout()
	end)
	headers[key] = header
	return header
end

local CreateManualInput = function(kind, label, help)
	local control = Controls.CreateInput(content)
	-- Label and help over the whole width, the field on its own line (as the frame settings panel).
	control:SetStacked(true)
	control:SetLabel(label)
	control:SetHelp(help)
	control:SetCallback(function(_, value)
		local lists = GetLists()
		if (lists and not InCombatLockdown()) then lists:SetText(kind, value) end
	end)
	control.listKind = kind
	inputs[#inputs + 1] = control
	return control
end

local Build = function()
	local name = ns.Prefix .. "NamePlateAuraPicker"
	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	-- HIGH, over the options window (raised): the confirmation popup is DIALOG and must come above it.
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	-- The options window's fill and casing, as FramePanel.lua draws them.
	local Look = Kit.Look
	local rounded = (Look and Look.IsRounded and Look.IsRounded()) and true or false
	frame:SetBackdrop(rounded and Look.WindowFill or Kit.WindowFill)
	local outset = Kit.WindowOutset
	frame:SetClampRectInsets(-outset.left, outset.right, outset.top, -outset.bottom)
	local casing = CreateFrame("Frame", nil, frame, ns.BackdropTemplate)
	casing:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset.left, outset.top)
	casing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset.right, -outset.bottom)
	casing:SetBackdrop(rounded and Look.CasingBackdrop or Kit.WindowCasing)
	casing:EnableMouse(false)
	frame.casing = casing
	UISpecialFrames[#UISpecialFrames + 1] = name

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Kit.GetFont(16, true))
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	title:SetText(L["Nameplate auras"])
	frame.title = title

	local subtitle = frame:CreateFontString(nil, "OVERLAY")
	subtitle:SetFontObject(Kit.GetFont(11))
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	subtitle:SetJustifyH("LEFT")
	frame.subtitle = subtitle

	local counts = frame:CreateFontString(nil, "OVERLAY")
	counts:SetFontObject(Kit.GetFont(12))
	counts:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
	counts:SetJustifyH("LEFT")
	frame.counts = counts

	-- What the two boxes do, in plain words (maintainer's request, 2026-11-22). The order is
	-- PlayerAuraContainers.lua's GetNamePlateGroups: gold groups first, once-only groups right after crowd
	-- control; both match the spell ID whoever cast it, in combat too.
	local explain = frame:CreateFontString(nil, "OVERLAY")
	explain:SetFontObject(Kit.GetFont(11))
	explain:SetPoint("TOPLEFT", counts, "BOTTOMLEFT", 0, -6)
	explain:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	explain:SetJustifyH("LEFT")
	explain:SetWordWrap(true)
	explain:SetText(L["Gold gives the aura's icon a gold border and puts it first on the nameplate. Only once shows the aura a single time, however many players put it on the enemy (four Death Knights, one Blood Plague). Both work whoever cast the aura, in combat too."])
	frame.explain = explain

	local warning = frame:CreateFontString(nil, "OVERLAY")
	warning:SetFontObject(Kit.GetFont(11))
	warning:SetPoint("TOPLEFT", explain, "BOTTOMLEFT", 0, -4)
	warning:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	warning:SetJustifyH("LEFT")
	warning:SetWordWrap(true)
	frame.warning = warning

	local close = CreateButton(frame, "x")
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
	close:SetScript("OnClick", function() AuraPicker:Close() end)
	frame.close = close

	-- The column names, over the boxes.
	local goldLabel = frame:CreateFontString(nil, "OVERLAY")
	goldLabel:SetFontObject(Kit.GetFont(11, true))
	goldLabel:SetText(L["Gold"])
	frame.goldLabel = goldLabel
	local onceLabel = frame:CreateFontString(nil, "OVERLAY")
	onceLabel:SetFontObject(Kit.GetFont(11, true))
	onceLabel:SetText(L["Only once"])
	frame.onceLabel = onceLabel

	scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 6, -132)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - 10, PAD)
	scroll:SetClipsChildren(true)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - PAD * 2 - 4, 1)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end
		self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40)))
	end)
	scroll:SetScript("OnSizeChanged", function(self, width)
		if (width and width > 0) then content:SetWidth(width) end
	end)
	scrollBar = Controls.CreateScrollBar(scroll, frame)
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)

	goldLabel:SetPoint("BOTTOM", scroll, "TOPRIGHT", -GOLD_X, 6)
	onceLabel:SetPoint("BOTTOM", scroll, "TOPRIGHT", -ONCE_X, 6)
	-- The column names explain themselves on hover, the same words as the boxes.
	for _, label in ipairs({ goldLabel, onceLabel }) do
		local hit = CreateFrame("Frame", nil, frame)
		hit:SetPoint("TOPLEFT", label, "TOPLEFT", -4, 4)
		hit:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 4, -4)
		hit:EnableMouse(true)
		hit:SetScript("OnEnter", function(self)
			local perClass = ns.IsForever or ns.IsRetailContent == false
			if (label == goldLabel) then
				ShowTip(self, L["Gold"], perClass and L["A gold border on this aura's icon. Kept for this class."]
					or L["A gold border on this aura's icon. Kept for this specialization."])
			else
				ShowTip(self, L["Only once"], L["Shown at most once on a nameplate, even when several players put it there. For the whole profile."])
			end
		end)
		hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	CreateManualInput("once", L["Spells shown only once"],
		L["Spell IDs, separated by commas. Each is shown at most once on a nameplate, even when the unit has it more than once, such as 55078 for a Death Knight."])
	CreateManualInput("highlight", L["Highlighted auras for this specialization"],
		L["Spell IDs, separated by commas. Their icons get a gold border. Each specialization keeps its own list."])

	-- "Use recommended": replaces both lists with this specialization's talented picks, after asking.
	recommendButton = CreateButton(content, L["Use recommended"])
	recommendButton:SetWidth(150)
	recommendButton:SetScript("OnClick", function()
		local lists, suggestions = GetLists(), GetSuggestions()
		if (not lists or not suggestions or InCombatLockdown()) then return end
		local highlight, once = suggestions:GetRecommended(suggestions.GetSpecID())
		local perClass = ns.IsForever or ns.IsRetailContent == false
		Kit.Confirm(perClass and L["Replace this class's Gold list and the profile's Only once list with the recommended picks? Everything now in both lists is removed."]
			or L["Replace this specialization's Gold list and the profile's Only once list with the recommended picks? Everything now in both lists is removed, and Only once is shared by every specialization."], function()
			if (InCombatLockdown()) then return end
			lists:SetText("highlight", lists.Join(highlight))
			lists:SetText("once", lists.Join(once))
		end)
	end)
	recommendButton:SetScript("OnEnter", function(self)
		self:Restyle()
		ShowTip(self, L["Use recommended"], L["Sets the suggested picks you have talented. Asks first, because it replaces both lists."],
			InCombatLockdown() and L["Changes wait until combat ends."] or nil)
	end)
	recommendButton:SetScript("OnLeave", function(self)
		self:Restyle()
		GameTooltip:Hide()
	end)
	if (recommendButton.SetMotionScriptsWhileDisabled) then recommendButton:SetMotionScriptsWhileDisabled(true) end

	-- "All classes": a search over names and IDs, and a class filter.
	local search = Controls.CreateInput(content)
	search:SetStacked(true)
	search:SetLabel(L["Search"])
	search:SetHelp(L["A spell name or ID."])
	search.box:HookScript("OnTextChanged", function(self)
		filter.text = (self:GetText() or ""):lower()
		Layout()
	end)
	allControls.search = search
	local classes = Controls.CreateDropdown(content)
	classes:SetStacked(true)
	classes:SetLabel(L["Class"])
	local values, order = { all = L["All classes"] }, { "all" }
	local suggestions = GetSuggestions()
	for _, class in ipairs(suggestions and suggestions:GetClasses() or {}) do
		values[class] = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
		order[#order + 1] = class
	end
	classes:SetList(values, order)
	classes:SetValue("all")
	classes:SetCallback(function(_, key)
		filter.class = (key ~= "all") and key or nil
		Layout()
	end)
	allControls.class = classes
	local none = content:CreateFontString(nil, "OVERLAY")
	none:SetFontObject(Kit.GetFont(11))
	none:SetText(L["Nothing matches."])
	allControls.none = none

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("SPELL_DATA_LOAD_RESULT")
	-- Talents learned or swapped: "Your spec" sorts what is talented again.
	frame:RegisterEvent("SPELLS_CHANGED")
	frame:SetScript("OnEvent", function(self, event, unit)
		if (event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player") then return end
		if (self:IsShown()) then Layout() end
	end)
	-- The options window's fields show the lists as they now are.
	frame:SetScript("OnHide", function()
		local panel = Kit.Panel
		-- Values only, where the page stands: Refresh would select the page again and scroll it to the top.
		if (panel and panel.IsShown and panel:IsShown() and panel.RefreshValues) then panel:RefreshValues() end
	end)

	local lists = GetLists()
	if (lists) then
		lists:AddListener(function()
			if (frame:IsShown()) then Layout() end
		end)
	end
end

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------
-- A row's second line.
local GetSpecName = function(specID)
	if (type(GetSpecializationInfoByID) ~= "function" or not specID) then return end
	local _, name = GetSpecializationInfoByID(specID)
	return type(name) == "string" and name or nil
end

local Join = function(a, b)
	if (a and b) then return a .. "  -  " .. b end
	return a or b
end

-- The sections' entries, each ID in the first section that has it: { id, detail, muted }. "All classes"
-- is a browser and lists whatever matches the filter; the rest decides what "Other entries" holds.
local Collect = function(lists, suggestions)
	local shown = {}
	local sections = { spec = {}, seen = {}, group = {}, all = {}, other = {} }
	-- An entry stands for all its rank IDs (Forever), so a listed lower rank does not show again below.
	local Add = function(key, entry)
		entry.ids = entry.ids or { entry.id }
		for _, id in ipairs(entry.ids) do
			if (shown[id]) then return end
		end
		for _, id in ipairs(entry.ids) do shown[id] = true end
		local list = sections[key]
		list[#list + 1] = entry
	end
	local specID = suggestions and suggestions.GetSpecID()
	local forever = ns.IsForever or ns.IsRetailContent == false
	if (suggestions) then
		for _, entry in ipairs(suggestions:GetOwn()) do
			local detail
			if (not entry.known) then
				detail = forever and L["Not learned"] or L["Not talented"]
			elseif (entry.recommend == "highlight") then
				detail = L["Suggested: Gold"]
			elseif (entry.recommend == "once") then
				detail = L["Suggested: Only once"]
			end
			Add("spec", { id = entry.id, ids = entry.ids, detail = detail, muted = not entry.known })
		end
	end
	-- A seen rank of a known spell (Forever: two priests, two Shadow Word: Pain ranks) is one row holding
	-- every rank, as the suggestion rows are.
	local ranksOf = {}
	if (suggestions) then
		for _, source in ipairs({ suggestions:GetAll(), suggestions:GetGroup() }) do
			for _, entry in ipairs(source) do
				if (entry.ids and #entry.ids > 1) then
					for _, id in ipairs(entry.ids) do ranksOf[id] = entry.ids end
				end
			end
		end
	end
	for _, entry in ipairs(lists:GetSeen()) do
		if (type(entry) == "table" and type(entry.id) == "number") then
			Add("seen", { id = entry.id, ids = ranksOf[entry.id], detail = Join(GetClassText(entry.class), entry.own and L["Yours"] or nil) })
		end
	end
	if (suggestions) then
		for _, entry in ipairs(suggestions:GetGroup()) do
			Add("group", { id = entry.id, ids = entry.ids, detail = GetClassText(entry.class) })
		end
		for _, entry in ipairs(suggestions:GetAll()) do
			if (not filter.class or filter.class == entry.class) then
				local name = (GetSpellInfo(entry.id) or ""):lower()
				if (filter.text == "" or name:find(filter.text, 1, true) or tostring(entry.id):find(filter.text, 1, true)) then
					local list = sections.all
					list[#list + 1] = { id = entry.id, ids = entry.ids, detail = Join(GetClassText(entry.class), GetSpecName(entry.specID)) }
				end
			end
		end
		table.sort(sections.all, function(a, b)
			local an, bn = GetSpellInfo(a.id) or "", GetSpellInfo(b.id) or ""
			if (an ~= bn) then return an < bn end
			return a.detail and b.detail and a.detail < b.detail or false
		end)
	end
	for _, kind in ipairs({ "highlight", "once" }) do
		for _, id in ipairs((lists:GetList(kind))) do
			Add("other", { id = id })
		end
	end
	return sections, specID
end

local PlaceRow = function(row, entry, offset, width, state)
	row.spellID = entry.id
	row.spellIDs = entry.ids or { entry.id }
	local name, icon = GetSpellInfo(entry.id)
	row.icon:SetTexture(icon or 134400)
	row.icon:SetDesaturated(entry.muted and true or false)
	row.name:SetText(name or string_format(L["Spell %d"], entry.id))
	row.detail:SetText(entry.detail or string_format(L["Spell ID: %d"], entry.id))
	for _, box in ipairs({ row.gold, row.once }) do
		local kind = box.kind
		-- Ticked when any of the entry's ranks is listed.
		box.checked = false
		for _, id in ipairs(row.spellIDs) do
			if (state[kind].set[id]) then box.checked = true break end
		end
		box.reason = nil
		if (state.combat) then
			box.reason = "combat"
		elseif (not box.checked and #state[kind].list >= state[kind].limit) then
			box.reason = "limit"
		end
		box:SetEnabled(box.reason == nil)
		box:Restyle()
	end
	row.name:SetTextColor(unpack(entry.muted and Kit.TextDisabled or Kit.TextNormal))
	row.detail:SetTextColor(unpack(Kit.TextDisabled))
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
	row:SetWidth(width)
	row:Show()
	return offset + ROW_H
end

local PlaceHeader = function(key, label, count, offset, width, emptyText)
	local header = GetHeader(key)
	header.sign:SetText(folded[key] and "+" or "-")
	header.label:SetText(count and string_format("%s (%d)", label:upper(), count) or label:upper())
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
	header:SetWidth(width)
	header:Show()
	local accent = Kit.TextSelected
	header.sign:SetTextColor(unpack(accent))
	header.label:SetTextColor(unpack(accent))
	header.rule:SetVertexColor(accent[1], accent[2], accent[3], .35)
	offset = offset + HEADER_H
	header.empty:SetShown(emptyText ~= nil and not folded[key])
	if (emptyText and not folded[key]) then
		header.empty:SetText(emptyText)
		header.empty:SetTextColor(unpack(Kit.TextDisabled))
		header.empty:ClearAllPoints()
		header.empty:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -offset - 4)
		header.empty:SetWidth(width - 20)
		offset = offset + max(20, (header.empty:GetStringHeight() or 12) + 10)
	end
	return offset
end

local HideHeader = function(key)
	local header = headers[key]
	if (header) then
		header:Hide()
		header.empty:Hide()
	end
end

-- A stacked kit control (the fields and the class filter) at the offset, or hidden.
local PlaceControl = function(control, shown, offset, width)
	control.frame:SetShown(shown)
	if (not shown) then return offset end
	control:Restyle()
	control.frame:ClearAllPoints()
	control.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
	control.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -offset)
	return offset + control:Measure(width)
end

Layout = function()
	if (not frame) then return end
	local lists = GetLists()
	if (not lists) then return end
	-- The suggestions exist for this client only where there is a table (Retail until plan step 3).
	local suggestions = GetSuggestions()
	if (suggestions and #suggestions:GetClasses() == 0) then suggestions = nil end

	local combat = InCombatLockdown() and true or false
	local state = { combat = combat }
	for _, kind in ipairs({ "highlight", "once" }) do
		local list, set = lists:GetList(kind)
		state[kind] = { list = list, set = set, limit = lists:GetLimit(kind) }
	end

	-- Forever has no specializations: its gold lists are per class (Visibility.lua, GetAuraHighlightKey).
	local perClass = ns.IsForever or ns.IsRetailContent == false
	frame.subtitle:SetText(string_format(perClass and L["%s: gold borders are kept per class, Only once for the whole profile."]
		or L["%s: gold borders are kept per specialization, Only once for the whole profile."], GetSpecText()))
	frame.counts:SetText(string_format(L["Highlighted: %d/%d    Only once: %d/%d"],
		#state.highlight.list, state.highlight.limit, #state.once.list, state.once.limit))
	-- Both lists take the plate's icon slots before your other debuffs do.
	local slots = GetMaxAuras()
	local warning
	if (combat) then
		warning = L["Changes wait until combat ends."]
	elseif (#state.highlight.list + #state.once.list >= slots) then
		warning = string_format(L["Together these can fill all %d icon slots on a nameplate and push your other debuffs out."], slots)
	end
	frame.warning:SetText(warning or "")
	-- The list starts under the warning when there is one, right under the counts when not.
	local top = 104 + ((frame.explain:GetStringHeight() or 12) + 6)
		+ (warning and ((frame.warning:GetStringHeight() or 12) + 6) or 0)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 6, -top)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - 10, PAD)

	local width = content:GetWidth() or (WIDTH - PAD * 2)
	local sections, specID = Collect(lists, suggestions)
	local offset, used = 0, 0
	local PlaceRows = function(key)
		if (folded[key]) then return end
		for _, entry in ipairs(sections[key]) do
			used = used + 1
			offset = PlaceRow(GetRow(used), entry, offset, width, state)
		end
	end

	-- Your spec, with "Use recommended" under its header.
	if (suggestions) then
		offset = PlaceHeader("spec", perClass and L["Your class"] or L["Your spec"], #sections.spec, offset, width,
			(#sections.spec == 0) and (perClass and L["No suggestions for this class. Seen on your targets and All classes still list what you can pick."]
				or L["No suggestions for this specialization. Seen on your targets and All classes still list what you can pick."]) or nil)
		local highlight, once = suggestions:GetRecommended(specID)
		recommendButton:SetShown(not folded.spec and #sections.spec > 0)
		if (recommendButton:IsShown()) then
			recommendButton:ClearAllPoints()
			recommendButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -offset - 2)
			recommendButton:SetEnabled(not combat and (#highlight + #once) > 0)
			recommendButton:Restyle()
			offset = offset + 30
		end
		PlaceRows("spec")
		offset = offset + 6
	else
		HideHeader("spec")
		recommendButton:Hide()
	end

	offset = PlaceHeader("seen", L["Seen on your targets"], #sections.seen, offset, width,
		(#sections.seen == 0) and L["Nothing yet. Debuffs that players and pets put on enemies are collected from their nameplates, out of combat."] or nil)
	PlaceRows("seen")
	offset = offset + 6

	if (suggestions) then
		offset = PlaceHeader("group", L["Group debuffs"], #sections.group, offset, width)
		PlaceRows("group")
		offset = offset + 6
		offset = PlaceHeader("all", L["All classes"], nil, offset, width)
		offset = PlaceControl(allControls.search, not folded.all, offset, width)
		offset = PlaceControl(allControls.class, not folded.all, offset, width)
		if (not folded.all and #sections.all == 0) then
			allControls.none:ClearAllPoints()
			allControls.none:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -offset - 4)
			allControls.none:SetTextColor(unpack(Kit.TextDisabled))
			allControls.none:Show()
			offset = offset + 24
		else
			allControls.none:Hide()
		end
		PlaceRows("all")
		offset = offset + 6
	else
		HideHeader("group")
		HideHeader("all")
		PlaceControl(allControls.search, false)
		PlaceControl(allControls.class, false)
		allControls.none:Hide()
	end

	offset = PlaceHeader("other", L["Other entries"], #sections.other, offset, width,
		(#sections.other == 0) and L["None. Spells in the lists that no section above shows appear here."] or nil)
	PlaceRows("other")
	for index = used + 1, #rows do
		rows[index]:Hide()
		rows[index].spellID = nil
	end

	offset = offset + 6
	offset = PlaceHeader("manual", L["Spell IDs by Hand"], nil, offset, width)
	for _, control in ipairs(inputs) do
		if (not folded.manual) then
			-- Not under the caret: a list arriving while you type would throw the typing away.
			if (not control.box:HasFocus()) then control:SetValue(lists:GetText(control.listKind)) end
			control:SetDisabled(combat)
		end
		offset = PlaceControl(control, not folded.manual, offset, width)
	end

	content:SetHeight(max(1, offset + 8))
	if (scrollBar) then scrollBar:Update() end
end

local Restyle = function()
	local c = Kit.WindowColor
	frame:SetBackdropColor(c[1] or 0, c[2] or 0, c[3] or 0, 1)
	frame.casing:SetBackdropBorderColor(unpack(Kit.WindowCasingColor))
	frame.casing:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.title:SetTextColor(unpack(Kit.TextSelected))
	frame.subtitle:SetTextColor(unpack(Kit.TextDisabled))
	frame.counts:SetTextColor(unpack(Kit.TextNormal))
	frame.explain:SetTextColor(unpack(Kit.TextDisabled))
	frame.warning:SetTextColor(unpack(Kit.TextWarning))
	frame.goldLabel:SetTextColor(1, .82, .1)
	frame.onceLabel:SetTextColor(unpack(Kit.TextSelected))
	frame.close:Restyle()
	if (recommendButton) then recommendButton:Restyle() end
	if (scrollBar) then scrollBar:Restyle() end
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
--- Opens the picker. Returns true when it is shown.
AuraPicker.Open = function(self)
	if (not GetLists()) then return false end
	if (not frame) then
		local ok, err = pcall(Build)
		if (not ok) then
			frame = nil
			ns:Print("The aura picker could not be built:", tostring(err))
			return false
		end
	end
	if (Kit.Panel and Kit.Panel.LoadTheme) then Kit.Panel:LoadTheme() end
	frame:Show()
	frame:Raise()
	Restyle()
	Layout()
	return true
end

AuraPicker.Close = function(self)
	if (frame) then frame:Hide() end
end

AuraPicker.IsShown = function(self)
	return frame and frame:IsShown() and true or false
end

AuraPicker.Toggle = function(self)
	if (self:IsShown()) then
		self:Close()
		return true
	end
	return self:Open()
end

--- For tooling: folds or opens a section ("spec", "seen", "group", "all", "other", "manual").
AuraPicker.SetFolded = function(self, key, value)
	if (folded[key] == nil) then return end
	folded[key] = value and true or false
	self:Refresh()
end

--- For tooling: the "All classes" filter, as the search box and class list set it.
AuraPicker.SetFilter = function(self, text, class)
	filter.text = type(text) == "string" and text:lower() or ""
	filter.class = class
	self:Refresh()
end

--- For tooling: the spell IDs on shown rows, in order.
AuraPicker.GetShownIDs = function(self)
	local out = {}
	for _, row in ipairs(rows) do
		if (row.spellID and row:IsShown()) then out[#out + 1] = row.spellID end
	end
	return out
end

--- For tooling: lays the window out again.
AuraPicker.Refresh = function(self)
	if (self:IsShown()) then Layout() end
end

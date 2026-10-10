--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The What's New popup.
--
-- Eight seconds after the first login on a new version, a small window lists
-- that version's notes from Options/WhatsNew.lua, each with a button that opens
-- what changed. "Got it" hides it until the next version; "Remind me later" or
-- Escape only closes it, so it comes back on the next login.
--
-- It never opens in combat: a login in combat waits for combat to end. It never
-- opens on a fresh install either, because a first login has nothing to compare
-- against and a popup is a poor first impression; that login only records the
-- version. A version with no entry in WhatsNew.lua shows nothing.
--
-- Account wide, in db.global: whatsNewSeen (the last version dismissed with
-- "Got it") and whatsNewDisabled (the switch on the Changelog page).
local Addon, ns = ...

local Kit = ns.OptionsKit
if (not Kit) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local max = math.max
local pcall = pcall
local tostring = tostring
local type = type
local unpack = unpack

-- GLOBALS: C_Timer, CreateFrame, InCombatLockdown, UIParent, UISpecialFrames

local DELAY = 8
local WIDTH = 420
local BUTTON_WIDTH = 104
local PAD = 18

local WhatsNew = {}
Kit.WhatsNew = WhatsNew

local frame, rows, footer

--------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------
local GetGlobal = function()
	return ns.db and ns.db.global
end

-- The entry for a version, or nil.
local FindEntry = function(version)
	if (type(ns.WhatsNew) ~= "table") then return end
	for _, entry in ipairs(ns.WhatsNew) do
		if (type(entry) == "table" and entry.version == version) then return entry end
	end
end

-- The changelog's title for a version, used as the subtitle when present.
local FindTitle = function(version)
	if (type(ns.Changelog) ~= "table") then return end
	for _, release in ipairs(ns.Changelog) do
		if (release.version == version) then return release.title end
	end
end

--------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------
local OpenNotes = function()
	local panel = Kit.Panel
	if (not panel) then return end
	panel:SetTab("settings")
	panel:Open("changelog")
end

-- Moves the popup to the left edge, so the options window opening in the middle
-- of the screen does not land on top of it, and the next button stays in reach.
local StepAside = function()
	if (not frame) then return end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -140)
end

local Run = function(item)
	if (InCombatLockdown()) then return end

	if (type(item.run) == "function") then
		local ok, err = pcall(item.run)
		if (not ok) then ns:Print("What's New:", tostring(err)) end
		return
	end

	local panel = Kit.Panel
	if (item.page and panel) then
		panel:SetTab("options")
		if (panel:OpenSection(item.page, item.section)) then StepAside() end
	end
end

--------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------
local CreateButton = function(parent, label)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(24)

	local backdrop = Kit.CreateBackdrop(button, Kit.InsetBackdrop, 1)
	local text = button:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(11))
	text:SetPoint("LEFT", button, "LEFT", 6, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	text:SetText(label)
	button.text = text

	button.Restyle = function(self)
		local hover = self:IsEnabled() and self:IsMouseOver()
		backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(backdrop, hover and Kit.BorderHover or Kit.BorderIdle)
		text:SetTextColor(unpack((not self:IsEnabled()) and Kit.TextDisabled
			or hover and Kit.TextHighlight or Kit.TextNormal))
	end
	button:SetScript("OnEnter", button.Restyle)
	button:SetScript("OnLeave", button.Restyle)
	button:SetScript("OnEnable", button.Restyle)
	button:SetScript("OnDisable", button.Restyle)
	return button
end

local Restyle = function()
	if (not frame) then return end
	frame:SetBackdropColor(unpack(Kit.WindowColor))
	frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))
	frame.title:SetTextColor(unpack(Kit.TextSelected))
	frame.subtitle:SetTextColor(unpack(Kit.TextDisabled))
	for _, row in ipairs(rows) do
		row.text:SetTextColor(unpack(Kit.TextNormal))
		if (row.button) then row.button:Restyle() end
	end
	for _, button in ipairs(footer) do button:Restyle() end
end

local Build = function()
	local name = ns.Prefix .. "WhatsNew"

	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetWidth(WIDTH)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:SetBackdrop(Kit.WindowBackdrop)

	-- Escape closes it, the same as "Remind me later".
	UISpecialFrames[#UISpecialFrames + 1] = name

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Kit.GetFont(16, true))
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	title:SetText(L["What's New"])
	frame.title = title

	local subtitle = frame:CreateFontString(nil, "OVERLAY")
	subtitle:SetFontObject(Kit.GetFont(11))
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
	subtitle:SetJustifyH("LEFT")
	frame.subtitle = subtitle

	local close = CreateButton(frame, "x")
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
	close:SetScript("OnClick", function() WhatsNew:Close() end)

	rows = {}

	local later = CreateButton(frame, L["Remind me later"])
	later:SetWidth(120)
	later:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
	later:SetScript("OnClick", function() WhatsNew:Close() end)

	local gotIt = CreateButton(frame, L["Got it"])
	gotIt:SetWidth(BUTTON_WIDTH)
	gotIt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	gotIt:SetScript("OnClick", function() WhatsNew:Dismiss() end)

	local notes = CreateButton(frame, L["All release notes"])
	notes:SetWidth(130)
	notes:SetPoint("RIGHT", gotIt, "LEFT", -8, 0)
	notes:SetScript("OnClick", function()
		OpenNotes()
		StepAside()
	end)

	footer = { close, later, gotIt, notes }

	-- Buttons that open a page wait out combat; the options window queues
	-- writes made in combat, but nothing here should start one there.
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(self, event)
		local enabled = (event == "PLAYER_REGEN_ENABLED")
		for _, row in ipairs(rows) do
			if (row.button) then row.button:SetEnabled(enabled) end
		end
		notes:SetEnabled(enabled)
	end)
end

local GetRow = function(index)
	local row = rows[index]
	if (row) then return row end

	row = CreateFrame("Frame", nil, frame)

	local text = row:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(Kit.GetFont(12))
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetWordWrap(true)
	row.text = text

	rows[index] = row
	return row
end

-- Fills the window with one release's items and sizes it to fit.
local Fill = function(entry)
	local subtitle = entry.version
	local title = FindTitle(entry.version)
	if (title and title ~= "") then subtitle = subtitle .. "  -  " .. title end
	frame.subtitle:SetText(subtitle)

	local inner = WIDTH - PAD * 2
	local offset = PAD + 16 + 4 + 14 + 14
	local items = type(entry.items) == "table" and entry.items or {}

	for index, item in ipairs(items) do
		local row = GetRow(index)
		local hasAction = (type(item.run) == "function") or (item.page ~= nil)

		if (hasAction and not row.button) then
			row.button = CreateButton(row, "")
		end
		if (row.button) then
			row.button:SetShown(hasAction)
			row.button.text:SetText(item.label or L["Show me"])
			row.button:SetWidth(BUTTON_WIDTH)
			row.button:ClearAllPoints()
			row.button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
			row.button:SetScript("OnClick", function() Run(item) end)
			row.button:SetEnabled(not InCombatLockdown())
		end

		local textWidth = inner - (hasAction and (BUTTON_WIDTH + 10) or 0) - 10
		row.text:ClearAllPoints()
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
		row.text:SetWidth(textWidth)
		row.text:SetText("- " .. tostring(item.text or ""))

		local height = max(24, (row.text:GetStringHeight() or 12) + 8)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -offset)
		row:SetSize(inner, height)
		row:Show()

		offset = offset + height + 6
	end

	for index = #items + 1, #rows do rows[index]:Hide() end

	frame:SetHeight(offset + 10 + 24 + PAD)
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
-- Opens the popup for a version, or the newest entry when none is given.
WhatsNew.Open = function(self, version)
	local entry
	if (version) then
		entry = FindEntry(version)
	elseif (type(ns.WhatsNew) == "table") then
		entry = ns.WhatsNew[1]
	end
	if (not entry) then return false end

	if (not frame) then
		local ok, err = pcall(Build)
		if (not ok) then
			frame = nil
			ns:Print("The What's New window could not be built:", tostring(err))
			return false
		end
	end

	if (Kit.Panel and Kit.Panel.LoadTheme) then Kit.Panel:LoadTheme() end

	frame.entry = entry
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	Fill(entry)
	Restyle()
	frame:Show()
	frame:Raise()
	return true
end

WhatsNew.Close = function(self)
	if (frame) then frame:Hide() end
end

-- Hides it until the next version.
WhatsNew.Dismiss = function(self)
	local db = GetGlobal()
	if (db and frame and frame.entry) then
		db.whatsNewSeen = frame.entry.version
	end
	self:Close()
end

WhatsNew.IsShown = function(self)
	return frame and frame:IsShown()
end

WhatsNew.IsEnabled = function(self)
	local db = GetGlobal()
	return not (db and db.whatsNewDisabled)
end

WhatsNew.SetEnabled = function(self, enabled)
	local db = GetGlobal()
	if (db) then db.whatsNewDisabled = (not enabled) or nil end
end

-- Whether this login should show the popup for the installed version.
WhatsNew.ShouldShow = function(self)
	local db = GetGlobal()
	local version = ns.Version
	if (not db or ns.IsDevelopment or type(version) ~= "string") then return false end
	if (db.whatsNewDisabled or db.whatsNewSeen == version) then return false end
	return FindEntry(version) ~= nil
end

--------------------------------------------------------------------------
-- Login
--------------------------------------------------------------------------
local watcher = CreateFrame("Frame")

local ShowNow = function()
	if (not WhatsNew:ShouldShow()) then return end
	if (InCombatLockdown()) then
		watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	WhatsNew:Open(ns.Version)
end

watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(self, event, isInitialLogin)
	if (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		ShowNow()
		return
	end

	-- Only the first login of a session; a /reload or a loading screen is not
	-- a new start, and "Remind me later" would otherwise come back on each.
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if (not isInitialLogin) then return end

	-- A fresh install records the version and stays quiet.
	local db = GetGlobal()
	if (db and ns.IsFreshInstall and type(ns.Version) == "string") then
		db.whatsNewSeen = ns.Version
		return
	end

	C_Timer.After(DELAY, ShowNow)
end)

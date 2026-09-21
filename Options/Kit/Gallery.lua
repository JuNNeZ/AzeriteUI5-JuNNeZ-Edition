--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- A gallery of the new panel's controls, opened with `/az gallery`.
--
-- Phase 2 of the options rewrite produces controls but no window to put them
-- in, which would leave nothing to look at until phase 3. This is that missing
-- window: one of every control, in every state that matters, with the theme
-- switchable on the spot.
--
-- It exists to be judged by eye. Sliders in particular have been wrong twice
-- now in ways no offline render caught, and this is the shortest path between
-- changing a number and seeing it in the client.
--
-- It is retained scaffolding for inspecting every control state in one place.
local Addon, ns = ...

local Kit = ns.OptionsKit
local Controls = Kit.Controls
if (not Controls) then return end

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs = ipairs
local max = math.max
local unpack = unpack

-- GLOBALS: CreateFrame, UIParent, UISpecialFrames

local Gallery = {}
Kit.Gallery = Gallery

local frame, content, rows

--------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------
local Add = function(kind, label, help, setup)
	local control

	if (kind == "header") then
		control = Controls.CreateHeader(content)
	elseif (kind == "paragraph") then
		control = Controls.CreateParagraph(content)
	elseif (kind == "segmented") then
		control = Controls.CreateSegmented(content)
	else
		control = Controls.Create(content, kind)
	end

	if (not control) then return end

	control:SetLabel(label)
	control:SetHelp(help)

	if (setup) then setup(control) end

	rows[#rows + 1] = control
	return control
end

local Layout = function()
	local offset = 0
	for i, control in ipairs(rows) do
		control.frame:ClearAllPoints()
		control.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
		control.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -offset)
		control.frame:SetHeight(control:GetHeight())
		offset = offset + control:GetHeight()
	end
	content:SetHeight(max(1, offset))
	return offset
end

local Restyle = function()
	if (frame) then
		frame:SetBackdropColor(unpack(Kit.WindowColor))
		frame:SetBackdropBorderColor(unpack(Kit.BorderIdle))
	end
	if (Gallery.title) then
		Gallery.title:SetTextColor(unpack(Kit.TextSelected))
	end
	if (Gallery.hint) then
		Gallery.hint:SetTextColor(unpack(Kit.TextDisabled))
	end
	for i, control in ipairs(rows or {}) do
		control:Restyle()
	end
	for i, button in ipairs(Gallery.themeButtons or {}) do
		button:Restyle()
	end
end
Gallery.Restyle = Restyle

local Build = function()
	local name = ns.Prefix .. "OptionsGallery"

	frame = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetSize(660, 720)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	frame:SetBackdrop(Kit.WindowBackdrop)

	UISpecialFrames[#UISpecialFrames + 1] = name

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Kit.GetFont(16, true))
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
	title:SetText("Control gallery")
	Gallery.title = title

	local hint = frame:CreateFontString(nil, "OVERLAY")
	hint:SetFontObject(Kit.GetFont(11))
	hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -19)
	hint:SetText("/az gallery   |   control scaffolding")
	Gallery.hint = hint

	-- Theme switcher, so all four can be compared without leaving the frame.
	Gallery.themeButtons = {}
	local values, order = Kit.GetThemeChoices()
	local previous

	for i, key in ipairs(order) do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(96, 22)
		if (previous) then
			button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -44)
		end
		previous = button

		local backdrop = Kit.CreateBackdrop(button, Kit.InsetBackdrop, 1)
		local text = button:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(Kit.GetFont(11))
		text:SetAllPoints()
		text:SetJustifyH("CENTER")
		text:SetText(values[key])

		button.themeKey = key
		button.Restyle = function(self)
			local selected = (Kit.GetTheme() == self.themeKey)
			backdrop:SetBackdropColor(unpack(selected and Kit.BackdropColor or Kit.InsetColor))
			Kit.SetBorderColor(backdrop, selected and Kit.BorderFocus or Kit.BorderIdle)
			text:SetTextColor(unpack(selected and Kit.TextSelected or Kit.TextNormal))
		end

		button:SetScript("OnClick", function(self)
			Kit.SetTheme(self.themeKey)
			if (ns.db and ns.db.global) then
				ns.db.global.optionsTheme = Kit.GetTheme()
			end
			Restyle()
		end)

		Gallery.themeButtons[#Gallery.themeButtons + 1] = button
	end

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -78)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 16)
	scroll:SetClipsChildren(true)

	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(620, 1)
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

	rows = {}

	----------------------------------------------------------------
	Add("header", "Toggles")

	Add("toggle", "A setting that is on", nil, function(c)
		c:SetValue(true)
	end)
	Add("toggle", "A setting that is off", nil, function(c)
		c:SetValue(false)
	end)
	Add("toggle", "With a line of help", "This is the plain line that replaces a tooltip you had to hover to find.", function(c)
		c:SetValue(true)
	end)
	Add("toggle", "Changed from its default", "The gem marks it, and the arrow puts it back.", function(c)
		c:SetValue(false)
		c:SetOnRevert(function(self) self:SetValue(true) self:SetModified(false) end)
		c:SetModified(true)
	end)
	Add("toggle", "Disabled", nil, function(c)
		c:SetValue(true)
		c:SetDisabled(true)
	end)

	----------------------------------------------------------------
	Add("header", "Sliders")

	Add("range", "At its minimum  (0)", nil, function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(0)
	end)
	Add("range", "Barely moved  (4)", "The chamfered ends should be the same size here as at the far end.", function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(4)
	end)
	Add("range", "Half way  (50)", nil, function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(50)
	end)
	Add("range", "Nearly full  (97)", nil, function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(97)
	end)
	Add("range", "Full  (100)", nil, function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(100)
	end)
	Add("range", "As a percentage  (65%)", nil, function(c)
		c:SetSliderValues(0, 1, .01) c:SetIsPercent(true) c:SetValue(.65)
	end)
	Add("range", "Disabled", nil, function(c)
		c:SetSliderValues(0, 100, 1) c:SetValue(35) c:SetDisabled(true)
	end)

	----------------------------------------------------------------
	Add("header", "Choices")

	Add("select", "A dropdown", "Opens a list. Used when there are more choices than fit in a row.", function(c)
		c:SetList({
			azerite = "Azerite", blizzard = "Blizzard", minimal = "Minimal",
			classic = "Classic", modern = "Modern", compact = "Compact",
			wide = "Wide", tall = "Tall"
		}, { "azerite", "blizzard", "minimal", "classic", "modern", "compact", "wide", "tall" })
		c:SetValue("azerite")
	end)
	Add("segmented", "A few choices", "Short lists read better as a strip than hidden behind a click.", function(c)
		c:SetList({ left = "Left", centre = "Centre", right = "Right" },
			{ "left", "centre", "right" })
		c:SetValue("centre")
	end)
	Add("segmented", "Two choices, disabled", nil, function(c)
		c:SetList({ on = "On", off = "Off" }, { "on", "off" })
		c:SetValue("on")
		c:SetDisabled(true)
	end)

	----------------------------------------------------------------
	Add("header", "Text and actions")

	Add("input", "A text field", "Type something, then press Enter or click the tick.", function(c)
		c:SetValue("Azerite")
	end)
	Add("execute", "An action", "The button carries the verb, the label carries the subject.", function(c)
		c:SetText("Reset this page")
	end)
	Add("execute", "An action, disabled", nil, function(c)
		c:SetText("Not available")
		c:SetDisabled(true)
	end)

	Add("paragraph", "A paragraph belongs to no single setting, so unlike the help line under a row it wraps as far as it needs to. This is what the description entries in the option tables become.")

	Layout()
	Restyle()

	return frame
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
Gallery.Open = function(self)
	if (not frame) then
		local ok, err = pcall(Build)
		if (not ok) then
			frame = nil
			ns:Print("The control gallery could not be built:", tostring(err))
			return false
		end
	end

	Kit.SetTheme((ns.db and ns.db.global and ns.db.global.optionsTheme) or Kit.GetTheme())
	Restyle()
	Layout()

	frame:Show()
	frame:Raise()
	return true
end

Gallery.Close = function(self)
	if (frame) then frame:Hide() end
end

Gallery.IsShown = function(self)
	return frame and frame:IsShown()
end

Gallery.Toggle = function(self)
	if (self:IsShown()) then
		self:Close()
		return true
	end
	return self:Open()
end

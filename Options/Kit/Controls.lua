--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- The options panel's controls.
--
-- These are ours outright. They are not AceGUI widget types, they are not
-- registered anywhere global, and nothing else on the machine can be handed one
-- by mistake. That is the point: AceGUI's registry and its object pools are
-- shared by every Ace3 addon on the client, and the first in-game run proved it
-- by loading AdvancedHotkeyOverlaySystem's copy of the library rather than ours.
--
-- Every control is a full-width row: label on the left with an optional line of
-- help beneath it, and the control itself right-aligned. That is the shape the
-- roadmap artifact draws, and it is the reason AceConfigDialog had to go - its
-- flow layout stacks a label above its control and offers no say in the matter.
--
-- Shared contract, so the renderer can treat them alike:
--
--   control.frame                  the row, full width, anchored by the caller
--   control.kind                   "toggle", "range", "select", ...
--   control:SetLabel(text)
--   control:SetHelp(text or nil)   nil removes the line and shrinks the row
--   control:SetDisabled(bool)
--   control:SetModified(bool)      shows the gem and the revert button
--   control:SetCallback(fn)        fn(control, value)
--   control:SetOnRevert(fn)        fn(control)
--   control:Restyle()              re-read the theme
--   control:GetHeight()
--
-- and per kind, SetValue/GetValue, plus SetList for the ones that take one.
local Addon, ns = ...

local Kit = ns.OptionsKit
local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- Lua API
local ipairs, pairs = ipairs, pairs
local floor = math.floor
local max, min = math.max, math.min
local string_format = string.format
local table_sort = table.sort
local tonumber, tostring = tonumber, tostring
local type = type
local unpack = unpack

-- GLOBALS: CreateFrame, UIParent, PlaySound, GameTooltip, GetCursorPosition

local Controls = {}
Kit.Controls = Controls

local GetFont, GetMedia = Kit.GetFont, Kit.GetMedia

--------------------------------------------------------------------------
-- Metrics
--------------------------------------------------------------------------
local ROW_HEIGHT = 34
local ROW_HELP_EXTRA = 15
local PAD_LEFT, PAD_RIGHT = 14, 12
local CONTROL_WIDTH = 216
local LABEL_GAP = 18
local HELP_MAX_LINES = 2
local HELP_LINE = 13

-- What a row assumes its text column is, until a page measures it. Anything
-- narrower than this and there is no room for a control beside it anyway.
local MIN_TEXT_WIDTH = 120

local TRACK_HEIGHT = 18
local SOUND_ON, SOUND_OFF, SOUND_CLICK = 856, 857, 852

--------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------
local SetTextColor = function(fontstring, color)
	fontstring:SetTextColor(color[1], color[2], color[3])
end

--------------------------------------------------------------------------
-- Measuring wrapped text
--------------------------------------------------------------------------
-- How tall a piece of text will be at a given width, asked before it is drawn.
--
-- A FontString anchored to both sides of its row only knows its width once the
-- row knows its own, and the row is being measured in the same pass that places
-- it. So the first layout of a page measured every wrapped line as one line, and
-- the changelog - where a note is four or five - drew its releases on top of one
-- another.
--
-- These rulers have an explicit width and no anchors, so they answer straight
-- away and the answer does not depend on when anything else was laid out. One
-- per font, hidden, never drawn.
local rulers = {}

local MeasureText = function(font, text, width)
	if (not text or text == "" or not width or width <= 0) then return 0 end

	local ruler = rulers[font]
	if (not ruler) then
		ruler = UIParent:CreateFontString(nil, "ARTWORK")
		ruler:Hide()
		ruler:SetJustifyH("LEFT")
		ruler:SetWordWrap(true)
		if (font) then ruler:SetFontObject(font) end
		rulers[font] = ruler
	end

	ruler:SetWidth(width)
	ruler:SetText(text)

	return ruler:GetStringHeight() or 0
end

Controls.MeasureText = MeasureText

-- Every control shares this frame: the hover wash, the label, the help line,
-- the modified gem, the revert button, and an empty area on the right for
-- whatever the control itself puts there.
local CreateRow = function(parent, kind)
	local control = { kind = kind }

	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(ROW_HEIGHT)
	control.frame = frame

	local hover = frame:CreateTexture(nil, "BACKGROUND")
	hover:SetTexture(GetMedia("plain"))
	hover:SetAllPoints()
	hover:SetVertexColor(1, 1, 1, .025)
	hover:Hide()
	control.hover = hover

	local rule = frame:CreateTexture(nil, "BACKGROUND")
	rule:SetTexture(GetMedia("plain"))
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD_LEFT, 0)
	rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD_RIGHT, 0)
	control.rule = rule

	-- The gem marks a setting that differs from its default.
	local gem = frame:CreateTexture(nil, "OVERLAY")
	gem:SetSize(9, 9)
	gem:SetPoint("LEFT", frame, "LEFT", 4, 0)
	Kit.SetGlyph(gem, "gem")
	gem:Hide()
	control.gem = gem

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GetFont(13))
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_LEFT, -9)
	label:SetJustifyH("LEFT")
	label:SetHeight(14)
	label:SetWordWrap(false)
	control.label = label

	-- Wraps, up to two lines. A single clipped line ending in an ellipsis is the
	-- one thing a help line must not do: the part it drops is the part that
	-- explains what the setting is for. Anything past two lines is on the
	-- tooltip, which carries the whole thing whatever happens here.
	local help = frame:CreateFontString(nil, "OVERLAY")
	help:SetFontObject(GetFont(11))
	help:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
	help:SetJustifyH("LEFT")
	help:SetJustifyV("TOP")
	help:SetWordWrap(true)
	if (help.SetMaxLines) then help:SetMaxLines(HELP_MAX_LINES) end
	help:Hide()
	control.help = help

	-- The area a control draws itself into.
	local area = CreateFrame("Frame", nil, frame)
	area:SetWidth(CONTROL_WIDTH)
	area:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD_RIGHT, 0)
	area:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
	control.area = area

	-- Labels stop short of the control, and of the revert button beside it.
	label:SetPoint("RIGHT", area, "LEFT", -LABEL_GAP, 0)
	help:SetPoint("RIGHT", area, "LEFT", -LABEL_GAP, 0)

	local revert = CreateFrame("Button", nil, frame)
	revert:SetSize(18, 18)
	revert:SetPoint("RIGHT", area, "LEFT", -2, 0)
	revert:Hide()
	control.revert = revert

	local revertIcon = revert:CreateTexture(nil, "OVERLAY")
	revertIcon:SetAllPoints()
	Kit.SetGlyph(revertIcon, "revert")
	control.revertIcon = revertIcon

	revert:SetScript("OnClick", function()
		if (control.onRevert) then
			PlaySound(SOUND_CLICK)
			control.onRevert(control)
		end
	end)
	-- The gem is a texture and cannot take the mouse, so the arrow beside it
	-- carries the explanation. Without it the gem is a mark nobody can read.
	revert:SetScript("OnEnter", function(self)
		revertIcon:SetVertexColor(unpack(Kit.TextHighlight))

		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Changed from default"], unpack(Kit.TextSelected))
		GameTooltip:AddLine(L["This setting no longer matches the value it ships with. Click to put this one setting back, without touching the rest of the profile."],
			Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true)
		GameTooltip:Show()
	end)
	revert:SetScript("OnLeave", function()
		revertIcon:SetVertexColor(unpack(Kit.TextSelected))
		GameTooltip:Hide()
	end)

	--------------------------------------------------------------
	-- Shared methods
	--------------------------------------------------------------
	control.SetLabel = function(self, text)
		self.labelText = text or ""
		self.label:SetText(self.labelText)
	end

	control.SetHelp = function(self, text)
		self.helpText = (text and text ~= "") and text or nil

		if (self.helpText) then
			self.help:SetText(self.helpText)
			self.help:Show()
			self.hasHelp = true
		else
			self.help:SetText("")
			self.help:Hide()
			self.hasHelp = false
		end
		self.frame:SetHeight(self:GetHeight())
	end

	-- Told how wide the page is, so the help line can be measured before it is
	-- drawn. Called by the page on every layout, including after a resize.
	control.Measure = function(self, width)
		self.textWidth = max(MIN_TEXT_WIDTH,
			(width or 0) - PAD_LEFT - PAD_RIGHT - CONTROL_WIDTH - LABEL_GAP)

		if (self.hasHelp) then
			local lines = MeasureText(GetFont(11), self.helpText, self.textWidth)
			self.helpHeight = min(HELP_MAX_LINES * HELP_LINE, max(HELP_LINE, lines))
		else
			self.helpHeight = 0
		end

		self.frame:SetHeight(self:GetHeight())
		return self:GetHeight()
	end

	control.GetHeight = function(self)
		if (not self.hasHelp) then return ROW_HEIGHT end

		-- Before a page has measured it, one line, which is what it always was.
		return ROW_HEIGHT + max(ROW_HELP_EXTRA, (self.helpHeight or 0) + 4)
	end

	-- The whole of the label and the help, however much of it fits on the row.
	-- The row itself takes no mouse, so this sits over the text column only and
	-- cannot come between you and the control on the right.
	local textArea = CreateFrame("Frame", nil, frame)
	textArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	textArea:SetPoint("BOTTOMRIGHT", area, "BOTTOMLEFT", -2, 0)
	textArea:EnableMouse(true)
	control.textArea = textArea

	textArea:SetScript("OnEnter", function()
		hover:Show()

		if (not control.labelText or control.labelText == "") then return end

		GameTooltip:SetOwner(control.frame, "ANCHOR_RIGHT")
		GameTooltip:AddLine(control.labelText, unpack(Kit.TextHighlight))
		if (control.helpText) then
			GameTooltip:AddLine(control.helpText,
				Kit.TextNormal[1], Kit.TextNormal[2], Kit.TextNormal[3], true)
		end
		GameTooltip:Show()
	end)
	textArea:SetScript("OnLeave", function()
		hover:Hide()
		GameTooltip:Hide()
	end)

	control.SetCallback = function(self, fn)
		self.callback = fn
	end

	control.SetOnRevert = function(self, fn)
		self.onRevert = fn
	end

	control.SetModified = function(self, modified)
		self.modified = modified and true or false
		self.gem:SetShown(self.modified)
		self.revert:SetShown(self.modified and self.onRevert ~= nil)
	end

	control.Fire = function(self, value)
		if (self.callback) then
			self.callback(self, value)
		end
	end

	-- Re-reads the theme. Controls add their own bits by wrapping this.
	control.Restyle = function(self)
		SetTextColor(self.label, self.disabled and Kit.TextDisabled or Kit.TextNormal)
		SetTextColor(self.help, Kit.TextDisabled)

		local border = Kit.BorderIdle
		self.rule:SetVertexColor(border[1], border[2], border[3], .35)
		self.gem:SetVertexColor(unpack(Kit.TextSelected))
		self.revertIcon:SetVertexColor(unpack(Kit.TextSelected))
	end

	frame:SetScript("OnEnter", function() hover:Show() end)
	frame:SetScript("OnLeave", function() hover:Hide() end)
	frame:EnableMouse(false)

	return control
end

-- Puts a themed backdrop behind a control's box.
local Inset = function(box)
	local backdrop = Kit.CreateBackdrop(box, Kit.InsetBackdrop, 2)
	backdrop:SetBackdropColor(unpack(Kit.InsetColor))
	return backdrop
end

--------------------------------------------------------------------------
-- Group header
--------------------------------------------------------------------------
-- Not a row: a band above a run of rows, with the addon's own rule beneath it.
Controls.CreateHeader = function(parent)
	local control = { kind = "header" }

	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(30)
	control.frame = frame

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GetFont(12, true))
	label:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD_LEFT, 8)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	control.label = label

	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(GetMedia("bar-small"))
	rule:SetHeight(3)
	rule:SetPoint("LEFT", label, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT", frame, "RIGHT", -PAD_RIGHT, 0)
	control.rule = rule

	-- Drawn uppercase, remembered as written: the rail lists these as
	-- navigation and SHOUTING AT SOMEBODY is not navigation.
	control.SetLabel = function(self, text)
		self.labelText = text or ""
		self.label:SetText(self.labelText:upper())
	end

	control.GetLabel = function(self)
		return self.labelText or ""
	end

	control.SetHelp = function() end
	control.SetDisabled = function() end
	control.SetModified = function() end
	control.SetCallback = function() end
	control.SetOnRevert = function() end
	control.GetHeight = function() return 30 end

	control.Restyle = function(self)
		local accent = Kit.TextSelected
		SetTextColor(self.label, accent)
		self.rule:SetVertexColor(accent[1], accent[2], accent[3], .35)
	end

	control:Restyle()
	return control
end

--------------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------------
-- A switch, per the artifact: the cast bar in miniature. A three-sliced
-- cast_back trough, a three-sliced cast_bar fill that appears when on, and
-- point_diamond as the knob sliding between the two ends.
Controls.CreateToggle = function(parent)
	local control = CreateRow(parent, "toggle")

	-- The artifact's switch at its own size: 54 by 24, a knob a quarter
	-- larger than the track, and its centre 6px in from either end.
	local SWITCH_W, SWITCH_H = 54, 24
	local KNOB_INSET = 6
	local fillH, fillTop, fillBottom = Kit.FillMetrics(SWITCH_H)

	local box = CreateFrame("Button", nil, control.area)
	box:SetSize(SWITCH_W, SWITCH_H)
	box:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	control.box = box

	local trough = Kit.CreateSliceBar(box, "BACKGROUND", Kit.Trough, SWITCH_H)
	control.trough = trough

	-- Between the trough's chamfered caps, lapping a pixel over each.
	local fillInset = Kit.FillInset(SWITCH_H)

	local fillHost = CreateFrame("Frame", nil, box)
	fillHost:SetPoint("TOPLEFT", box, "TOPLEFT", fillInset, -fillTop)
	fillHost:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -fillInset, fillBottom)
	local fill = Kit.CreateSliceBar(fillHost, "ARTWORK", Kit.Fill, fillH)
	control.fill = fill

	-- The knob needs a frame of its own, above the fill's. A child frame
	-- draws above its parent's regions whatever draw layer they are on, so a
	-- knob put straight on the box sat behind the fill below it.
	local knobHost = CreateFrame("Frame", nil, box)
	knobHost:SetAllPoints(box)
	knobHost:SetFrameLevel(fillHost:GetFrameLevel() + 2)
	control.knobHost = knobHost

	local knob = knobHost:CreateTexture(nil, "OVERLAY")
	knob:SetTexture(GetMedia("point_diamond"))
	local knobDraw = Kit.DrawSize(SWITCH_H * 1.25, "point_diamond")
	knob:SetSize(knobDraw, knobDraw)
	control.knob = knob

	local gem = knobHost:CreateTexture(nil, "OVERLAY", nil, 2)
	gem:SetTexture(GetMedia("point_crystal"))
	gem:SetSize(8, 8)
	gem:SetPoint("CENTER", knob, "CENTER", 0, 0)
	gem:Hide()
	control.gemOn = gem

	local Reposition = function(self)
		self.knob:ClearAllPoints()
		if (self.value) then
			self.knob:SetPoint("CENTER", self.box, "RIGHT", -KNOB_INSET, 0)
		else
			self.knob:SetPoint("CENTER", self.box, "LEFT", KNOB_INSET, 0)
		end
		self.fill:SetShown(self.value and true or false)
		self.gemOn:SetShown(self.value and true or false)
	end

	control.SetValue = function(self, value)
		self.value = value and true or false
		Reposition(self)
		self:Restyle()
	end

	control.GetValue = function(self)
		return self.value
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		if (self.disabled) then box:Disable() else box:Enable() end
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.trough:SetColor(Kit.TrackColor)

		local fillColor = self.disabled and Kit.TextDisabled or Kit.TextSelected
		self.fill:SetVertexColor(fillColor[1], fillColor[2], fillColor[3], Kit.FillAlpha)

		self.knob:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
		self.gemOn:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextSelected))
	end

	box:SetScript("OnClick", function()
		if (control.disabled) then return end
		control:SetValue(not control.value)
		PlaySound(control.value and SOUND_ON or SOUND_OFF)
		control:Fire(control.value)
	end)
	box:SetScript("OnEnter", function() control.hover:Show() end)
	box:SetScript("OnLeave", function() control.hover:Hide() end)

	control:SetValue(false)
	return control
end

--------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------
-- The trough is three-sliced, and so is the fill. A StatusBar still drives the
-- geometry, because the engine keeps its texture sized correctly and never
-- hands back a zero width mid-refresh, but its own texture is invisible: the
-- visible fill is three textures anchored to it, so the chamfered ends keep
-- their shape at every value instead of stretching with the bar.
Controls.CreateSlider = function(parent)
	local control = CreateRow(parent, "range")

	local VALUE_W = 52

	local valuebox = CreateFrame("EditBox", nil, control.area)
	valuebox:SetSize(VALUE_W, 18)
	valuebox:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	valuebox:SetAutoFocus(false)
	valuebox:SetFontObject(GetFont(12))
	valuebox:SetJustifyH("RIGHT")
	control.valuebox = valuebox

	local track = CreateFrame("Frame", nil, control.area)
	track:SetHeight(TRACK_HEIGHT)
	track:SetPoint("LEFT", control.area, "LEFT", 0, 0)
	track:SetPoint("RIGHT", valuebox, "LEFT", -10, 0)
	track:SetPoint("CENTER", control.area, "CENTER", 0, 0)
	control.track = track

	local trough = Kit.CreateSliceBar(track, "BACKGROUND", Kit.Trough, TRACK_HEIGHT)
	control.trough = trough

	-- The fill lives between the trough's chamfered caps, lapping a pixel over
	-- each. Spanning the whole track instead put the fill's chamfer on top of
	-- the trough's at full value, which is what read as clipping.
	local fillH, fillTop, fillBottom = Kit.FillMetrics(TRACK_HEIGHT)
	local fillInset = Kit.FillInset(TRACK_HEIGHT)

	-- A StatusBar is kept purely to size the fill: the engine keeps its texture
	-- correct at every value and never hands back a zero width mid-refresh.
	local driverHost = CreateFrame("StatusBar", nil, track)
	driverHost:SetPoint("TOPLEFT", track, "TOPLEFT", fillInset, -fillTop)
	driverHost:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -fillInset, fillBottom)
	driverHost:SetStatusBarTexture(GetMedia("plain"))
	driverHost:SetMinMaxValues(0, 100)
	driverHost:SetValue(0)
	control.driver = driverHost

	local driver = driverHost:GetStatusBarTexture()
	driver:SetAlpha(0)

	local fill = Kit.CreateSliceBar(driverHost, "ARTWORK", Kit.Fill, fillH, driver)
	control.fill = fill

	-- The knob has to sit on a frame of its own, above the fill's. A child frame
	-- draws above its parent's regions whatever draw layer they are on, so a knob
	-- put straight on the track disappeared behind the fill that lives on the
	-- status bar below it.
	local knobHost = CreateFrame("Frame", nil, track)
	knobHost:SetAllPoints(track)
	knobHost:SetFrameLevel(driverHost:GetFrameLevel() + 2)
	control.knobHost = knobHost

	-- Anchored to the leading edge of the fill, which is what the artifact does
	-- with `left: calc(var(--p) * 100%)`. At the minimum the fill has no width,
	-- so the knob sits exactly where the fill begins.
	local knob = knobHost:CreateTexture(nil, "OVERLAY")
	knob:SetTexture(GetMedia("point_diamond"))
	local knobDraw = Kit.DrawSize(TRACK_HEIGHT * 1.35, "point_diamond")
	knob:SetSize(knobDraw, knobDraw)
	knob:SetPoint("CENTER", driver, "RIGHT", 0, 0)
	control.knob = knob

	-- Input only. There is deliberately no WoW Slider here any more.
	--
	-- A Slider insets its thumb by half the thumb texture's width at each end,
	-- and point_diamond is a 54px texture for a 24px diamond, so the knob could
	-- never reach either end. Worse, a Slider re-fires OnValueChanged when it is
	-- resized, remapping the old thumb position into the new width: a slider laid
	-- out at zero width had its thumb at the far right, so the first real layout
	-- reported the maximum and overwrote the value. That is why a slider set to
	-- 97 kept reading 100, and why guarding the handler did not hold - the bogus
	-- change arrived before anything could re-assert.
	--
	-- The value is ours now, start to finish.
	local input = CreateFrame("Frame", nil, track)
	input:SetPoint("TOPLEFT", track, "TOPLEFT", fillInset, 0)
	input:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -fillInset, 0)
	input:SetFrameLevel(knobHost:GetFrameLevel() + 1)
	input:SetHitRectInsets(-fillInset, -fillInset, -8, -8)
	input:EnableMouse(true)
	input:EnableMouseWheel(true)
	control.input = input
	control.slider = input

	local Clamp = function(self, value)
		local lo, hi = self.min or 0, self.max or 100
		if (hi <= lo) then hi = lo + 1 end

		if (self.step and self.step > 0) then
			value = floor((value - lo) / self.step + 0.5) * self.step + lo
		end
		return min(hi, max(lo, value))
	end

	local UpdateFill = function(self)
		local lo, hi = self.min or 0, self.max or 100
		if (hi <= lo) then hi = lo + 1 end

		self.driver:SetMinMaxValues(lo, hi)
		self.driver:SetValue(min(hi, max(lo, self.value or lo)))
		self.fill:SetShown((self.value or lo) > lo)
	end

	local UpdateText = function(self)
		local value = self.value or 0
		if (self.isPercent) then
			self.valuebox:SetText(string_format("%s%%", floor(value * 1000 + 0.5) / 10))
		else
			self.valuebox:SetText(tostring(floor(value * 100 + 0.5) / 100))
		end
	end

	control.SetSliderValues = function(self, lo, hi, step)
		self.min, self.max, self.step = lo, hi, step
		if (self.value ~= nil) then
			self.value = Clamp(self, self.value)
		end
		UpdateText(self)
		UpdateFill(self)
	end

	control.SetIsPercent = function(self, isPercent)
		self.isPercent = isPercent
		UpdateText(self)
	end

	-- `fromUser` is what separates the renderer setting a value from somebody
	-- dragging it. Only the latter calls back.
	control.SetValue = function(self, value, fromUser)
		local clamped = Clamp(self, value or 0)
		local changed = (clamped ~= self.value)

		self.value = clamped
		UpdateText(self)
		UpdateFill(self)

		if (changed and fromUser and not self.disabled) then
			self:Fire(clamped)
		end
	end

	control.GetValue = function(self)
		return self.value
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		input:EnableMouse(not self.disabled)
		input:EnableMouseWheel(not self.disabled)
		valuebox:EnableMouse(not self.disabled)
		if (self.disabled) then
			valuebox:ClearFocus()
			input:SetScript("OnUpdate", nil)
		end
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.trough:SetColor(Kit.TrackColor)

		local fillColor = self.disabled and Kit.TextDisabled or Kit.TextSelected
		self.fill:SetVertexColor(fillColor[1], fillColor[2], fillColor[3], Kit.FillAlpha)

		self.knob:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
		self.valuebox:SetTextColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
	end

	----------------------------------------------------------------
	-- Input
	----------------------------------------------------------------
	local ValueFromCursor = function()
		local x = GetCursorPosition()
		local scale = input:GetEffectiveScale()
		local left, width = input:GetLeft(), input:GetWidth()

		if (not x or not left or not width or width <= 0) then return end
		if (not scale or scale <= 0) then return end

		local fraction = ((x / scale) - left) / width
		fraction = min(1, max(0, fraction))

		local lo, hi = control.min or 0, control.max or 100
		return lo + fraction * (hi - lo)
	end

	local Track = function()
		local value = ValueFromCursor()
		if (value) then
			control:SetValue(value, true)
		end
	end

	local StopTracking = function()
		input:SetScript("OnUpdate", nil)
	end

	input:SetScript("OnMouseDown", function()
		if (control.disabled) then return end
		Track()
		input:SetScript("OnUpdate", Track)
	end)
	input:SetScript("OnMouseUp", StopTracking)
	input:SetScript("OnHide", StopTracking)

	input:SetScript("OnMouseWheel", function(_, delta)
		if (control.disabled) then return end
		local step = (control.step and control.step > 0) and control.step or 1
		control:SetValue((control.value or 0) + delta * step, true)
	end)

	input:SetScript("OnEnter", function() control.hover:Show() end)
	input:SetScript("OnLeave", function() control.hover:Hide() end)

	valuebox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		local value = control.isPercent and tonumber((text:gsub("%%", ""))) or tonumber(text)
		if (control.isPercent and value) then value = value / 100 end

		if (value) then
			control:SetValue(value, true)
		else
			UpdateText(control)
		end
		self:ClearFocus()
	end)
	valuebox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		UpdateText(control)
	end)

	control:SetSliderValues(0, 100, 1)
	control:SetValue(0)
	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------
-- One pullout serves every dropdown, because only one can be open at a time.
local pullout, pulloutRows, pulloutOwner

local ClosePullout = function()
	if (pullout) then
		pullout:Hide()
		pulloutOwner = nil
	end
end
Controls.CloseDropdown = ClosePullout

Controls.IsDropdownOpen = function()
	return pullout and pullout:IsShown()
end

local ROW_H, MAX_ROWS = 20, 16

local CreatePullout = function()
	local frame = CreateFrame("Frame", nil, UIParent, ns.BackdropTemplate)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetBackdrop(Kit.ButtonBackdrop)
	frame:EnableMouse(true)
	frame:Hide()

	-- A sibling, not a child: raising the pullout must never lift the catcher
	-- above the rows it sits behind.
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetAllPoints(UIParent)
	catcher:RegisterForClicks("AnyUp")
	catcher:SetScript("OnClick", ClosePullout)
	catcher:Hide()

	frame:SetScript("OnShow", function(self)
		catcher:SetFrameLevel(max(0, self:GetFrameLevel() - 1))
		catcher:Show()
	end)
	frame:SetScript("OnHide", function() catcher:Hide() end)

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	scroll:SetClipsChildren(true)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * ROW_H * 2)))
	end)

	frame.scroll, frame.child = scroll, child
	return frame
end

local GetPulloutRow = function(index)
	local row = pulloutRows[index]
	if (row) then return row end

	row = CreateFrame("Button", nil, pullout.child)
	row:SetHeight(ROW_H)
	row:SetPoint("LEFT", pullout.child, "LEFT", 0, 0)
	row:SetPoint("RIGHT", pullout.child, "RIGHT", 0, 0)
	row:SetPoint("TOP", pullout.child, "TOP", 0, -(index - 1) * ROW_H)

	local highlight = row:CreateTexture(nil, "BACKGROUND")
	highlight:SetTexture(GetMedia("plain"))
	highlight:SetAllPoints()
	highlight:Hide()
	row.highlight = highlight

	local check = row:CreateTexture(nil, "OVERLAY")
	check:SetSize(11, 11)
	check:SetPoint("LEFT", row, "LEFT", 5, 0)
	Kit.SetGlyph(check, "check")
	check:Hide()
	row.check = check

	local text = row:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GetFont(12))
	text:SetPoint("LEFT", row, "LEFT", 20, 0)
	text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	row.text = text

	row:SetScript("OnClick", function(self)
		local owner = pulloutOwner
		ClosePullout()
		if (owner) then
			PlaySound(SOUND_ON)
			owner:SetValue(self.key)
			owner:Fire(self.key)
		end
	end)
	row:SetScript("OnEnter", function(self)
		self.highlight:Show()
		SetTextColor(self.text, Kit.TextHighlight)
	end)
	row:SetScript("OnLeave", function(self)
		self.highlight:Hide()
		SetTextColor(self.text, self.selected and Kit.TextSelected or Kit.TextNormal)
	end)

	pulloutRows[index] = row
	return row
end

local OpenPullout = function(control)
	if (not pullout) then
		pullout = CreatePullout()
		pulloutRows = {}
	end

	if (pulloutOwner == control and pullout:IsShown()) then
		ClosePullout()
		return
	end
	pulloutOwner = control

	pullout:SetBackdropColor(unpack(Kit.InsetColor))
	pullout:SetBackdropBorderColor(unpack(Kit.BorderFocus))

	local order, list = control.order or {}, control.list or {}
	local accent = Kit.TextSelected
	local count = 0

	for i, key in ipairs(order) do
		local row = GetPulloutRow(i)
		row.key = key
		row.text:SetText(tostring(list[key]))
		row.selected = (key == control.value)
		row.check:SetShown(row.selected)
		row.check:SetVertexColor(unpack(accent))
		row.highlight:SetVertexColor(accent[1], accent[2], accent[3], .22)
		SetTextColor(row.text, row.selected and accent or Kit.TextNormal)
		row:Show()
		count = i
	end
	for i = count + 1, #pulloutRows do
		pulloutRows[i]:Hide()
	end

	local shown = min(count, MAX_ROWS)
	local width = max(control.box:GetWidth(), 150)

	pullout.child:SetSize(width - 12, max(1, count * ROW_H))
	pullout.scroll:SetVerticalScroll(0)
	pullout:SetSize(width, shown * ROW_H + 12)
	pullout:ClearAllPoints()
	pullout:SetPoint("TOPRIGHT", control.box, "BOTTOMRIGHT", 0, -2)
	pullout:Show()
	pullout:Raise()
end

Controls.CreateDropdown = function(parent)
	local control = CreateRow(parent, "select")

	local box = CreateFrame("Button", nil, control.area)
	box:SetHeight(22)
	box:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	box:SetWidth(CONTROL_WIDTH)
	box:SetPoint("CENTER", control.area, "CENTER", 0, 0)
	control.box = box

	local backdrop = Inset(box)
	control.backdrop = backdrop

	local chevron = box:CreateTexture(nil, "OVERLAY")
	chevron:SetSize(12, 12)
	chevron:SetPoint("RIGHT", box, "RIGHT", -6, 0)
	Kit.SetGlyph(chevron, "chevron")
	control.chevron = chevron

	local text = box:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GetFont(12))
	text:SetPoint("LEFT", box, "LEFT", 8, 0)
	text:SetPoint("RIGHT", chevron, "LEFT", -4, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	control.text = text

	control.SetList = function(self, list, order)
		self.list = list or {}
		self.order = {}

		if (order) then
			for i, key in ipairs(order) do self.order[i] = key end
		else
			for key in pairs(self.list) do self.order[#self.order + 1] = key end
			table_sort(self.order, function(a, b)
				return tostring(self.list[a]) < tostring(self.list[b])
			end)
		end

		self:SetValue(self.value)
	end

	control.SetValue = function(self, value)
		self.value = value

		-- A control with no value yet asks its list for nothing, rather than
		-- looking up nil and relying on that being harmless.
		local shown = (value ~= nil) and self.list and self.list[value] or nil
		self.text:SetText(shown ~= nil and tostring(shown) or "")
		if (pulloutOwner == self and pullout and pullout:IsShown()) then
			OpenPullout(self)
		end
		self:Restyle()
	end

	control.GetValue = function(self)
		return self.value
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		if (self.disabled) then
			box:Disable()
			if (pulloutOwner == self) then ClosePullout() end
		else
			box:Enable()
		end
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
		SetTextColor(self.text, self.disabled and Kit.TextDisabled or Kit.TextHighlight)
		self.chevron:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextSelected))
	end

	box:SetScript("OnClick", function()
		if (control.disabled) then return end
		PlaySound(SOUND_CLICK)
		OpenPullout(control)
	end)
	box:SetScript("OnEnter", function()
		control.hover:Show()
		if (not control.disabled) then
			Kit.SetBorderColor(control.backdrop, Kit.BorderHover)
		end
	end)
	box:SetScript("OnLeave", function()
		control.hover:Hide()
		Kit.SetBorderColor(control.backdrop, Kit.BorderIdle)
	end)

	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Segmented control
--------------------------------------------------------------------------
-- For a select with only a handful of values, where a dropdown hides the
-- choices behind a click for no reason.
Controls.CreateSegmented = function(parent)
	local control = CreateRow(parent, "select")
	control.segmented = true

	local strip = CreateFrame("Frame", nil, control.area)
	strip:SetHeight(22)
	strip:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	strip:SetPoint("LEFT", control.area, "LEFT", 0, 0)
	strip:SetPoint("CENTER", control.area, "CENTER", 0, 0)
	control.strip = strip

	control.buttons = {}

	local Build = function(self)
		local order, list = self.order or {}, self.list or {}
		local count = #order

		for i, button in ipairs(self.buttons) do
			button:Hide()
		end
		if (count == 0) then return end

		local width = strip:GetWidth() / count

		for i = 1, count do
			local button = self.buttons[i]
			if (not button) then
				button = CreateFrame("Button", nil, strip)
				button:SetHeight(22)

				local backdrop = Kit.CreateBackdrop(button, Kit.InsetBackdrop, 1)
				button.backdrop = backdrop

				local text = button:CreateFontString(nil, "OVERLAY")
				text:SetFontObject(GetFont(11))
				text:SetPoint("LEFT", button, "LEFT", 4, 0)
				text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
				text:SetJustifyH("CENTER")
				text:SetWordWrap(false)
				button.text = text

				button:SetScript("OnClick", function(self)
					if (control.disabled) then return end
					PlaySound(SOUND_CLICK)
					control:SetValue(self.key)
					control:Fire(self.key)
				end)
				button:SetScript("OnEnter", function() control.hover:Show() end)
				button:SetScript("OnLeave", function() control.hover:Hide() end)

				self.buttons[i] = button
			end

			button:ClearAllPoints()
			button:SetPoint("LEFT", strip, "LEFT", (i - 1) * width, 0)
			button:SetWidth(width)
			button.key = order[i]
			button.text:SetText(tostring(list[order[i]]))
			button:Show()
		end
	end

	control.SetList = function(self, list, order)
		self.list = list or {}
		self.order = {}
		if (order) then
			for i, key in ipairs(order) do self.order[i] = key end
		else
			for key in pairs(self.list) do self.order[#self.order + 1] = key end
			table_sort(self.order, function(a, b)
				return tostring(self.list[a]) < tostring(self.list[b])
			end)
		end
		Build(self)
		self:Restyle()
	end

	control.SetValue = function(self, value)
		self.value = value
		self:Restyle()
	end

	control.GetValue = function(self)
		return self.value
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		for i, button in ipairs(self.buttons) do
			if (button:IsShown()) then
				local selected = (button.key == self.value)
				local color = self.disabled and Kit.TextDisabled
					or (selected and Kit.TextSelected or Kit.TextNormal)
				SetTextColor(button.text, color)
				button.backdrop:SetBackdropColor(unpack(selected and Kit.BackdropColor or Kit.InsetColor))
				Kit.SetBorderColor(button.backdrop, selected and Kit.BorderFocus or Kit.BorderIdle)
			end
		end
	end

	strip:SetScript("OnSizeChanged", function() Build(control) control:Restyle() end)

	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Text input
--------------------------------------------------------------------------
Controls.CreateInput = function(parent)
	local control = CreateRow(parent, "input")

	local box = CreateFrame("EditBox", nil, control.area)
	box:SetHeight(22)
	box:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	box:SetWidth(CONTROL_WIDTH)
	box:SetPoint("CENTER", control.area, "CENTER", 0, 0)
	box:SetAutoFocus(false)
	box:SetFontObject(GetFont(12))
	box:SetTextInsets(8, 24, 0, 0)
	control.box = box

	local backdrop = Inset(box)
	control.backdrop = backdrop

	local accept = CreateFrame("Button", nil, control.area)
	accept:SetSize(16, 16)
	accept:SetPoint("RIGHT", box, "RIGHT", -5, 0)
	accept:Hide()
	control.accept = accept

	local acceptIcon = accept:CreateTexture(nil, "OVERLAY")
	acceptIcon:SetAllPoints()
	Kit.SetGlyph(acceptIcon, "check")
	control.acceptIcon = acceptIcon

	local Commit = function()
		control.committed = box:GetText()
		control.accept:Hide()
		box:ClearFocus()
		control:Fire(control.committed)
	end

	control.SetValue = function(self, text)
		self.committed = text or ""
		box:SetText(self.committed)
		box:SetCursorPosition(0)
		self.accept:Hide()
	end

	control.GetValue = function(self)
		return box:GetText()
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		box:EnableMouse(not self.disabled)
		if (self.disabled) then box:ClearFocus() end
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(self.backdrop, box:HasFocus() and Kit.BorderFocus or Kit.BorderIdle)
		box:SetTextColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
		self.acceptIcon:SetVertexColor(unpack(Kit.TextSelected))
	end

	box:SetScript("OnEnterPressed", Commit)
	accept:SetScript("OnClick", Commit)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(control.committed or "")
		self:ClearFocus()
		control.accept:Hide()
	end)
	box:SetScript("OnTextChanged", function(self, userInput)
		if (userInput) then
			control.accept:SetShown(self:GetText() ~= (control.committed or ""))
		end
	end)
	box:SetScript("OnEditFocusGained", function() control:Restyle() end)
	box:SetScript("OnEditFocusLost", function() control:Restyle() end)

	control:SetValue("")
	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------
-- On the addon's own tooltip border, so a button matches the rest of the
-- interface rather than the lighter aura edge the input fields use.
Controls.CreateButton = function(parent)
	local control = CreateRow(parent, "execute")

	local box = CreateFrame("Button", nil, control.area)
	box:SetHeight(26)
	box:SetPoint("RIGHT", control.area, "RIGHT", 0, 0)
	box:SetWidth(CONTROL_WIDTH)
	box:SetPoint("CENTER", control.area, "CENTER", 0, 0)
	control.box = box

	local backdrop = Kit.CreateBackdrop(box, Kit.ButtonBackdrop)
	backdrop:SetBackdropColor(unpack(Kit.BackdropColor))
	control.backdrop = backdrop

	local text = box:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GetFont(12))
	text:SetPoint("LEFT", box, "LEFT", 10, 0)
	text:SetPoint("RIGHT", box, "RIGHT", -10, 0)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	control.text = text

	control.SetText = function(self, value)
		self.text:SetText(value or "")
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		if (self.disabled) then box:Disable() else box:Enable() end
		self:Restyle()
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.backdrop:SetBackdropColor(unpack(Kit.BackdropColor))
		Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
		SetTextColor(self.text, self.disabled and Kit.TextDisabled or Kit.TextNormal)
	end

	box:SetScript("OnClick", function()
		if (control.disabled) then return end
		PlaySound(SOUND_CLICK)
		control:Fire(true)
	end)
	box:SetScript("OnEnter", function()
		control.hover:Show()
		if (not control.disabled) then
			Kit.SetBorderColor(control.backdrop, Kit.BorderHover)
			SetTextColor(control.text, Kit.TextHighlight)
		end
	end)
	box:SetScript("OnLeave", function()
		control.hover:Hide()
		Kit.SetBorderColor(control.backdrop, Kit.BorderIdle)
		SetTextColor(control.text, control.disabled and Kit.TextDisabled or Kit.TextNormal)
	end)

	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Paragraph
--------------------------------------------------------------------------
-- A description that belongs to no single setting. Unlike the help line under a
-- row, this one wraps.
Controls.CreateParagraph = function(parent)
	local control = { kind = "description" }

	local frame = CreateFrame("Frame", nil, parent)
	control.frame = frame

	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(GetFont(12))
	text:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_LEFT, -6)
	text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD_RIGHT, -6)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	control.text = text

	control.SetLabel = function(self, value)
		self.labelText = value or ""
		self.text:SetText(self.labelText)
		self.frame:SetHeight(self:GetHeight())
	end

	-- A paragraph is nothing but wrapped text, so its height is entirely a
	-- question of how wide the page is. Measured rather than read back off the
	-- FontString, which does not know its own width yet on a page's first
	-- layout: that is what drew the changelog releases on top of one another.
	control.Measure = function(self, width)
		self.textWidth = max(MIN_TEXT_WIDTH, (width or 0) - PAD_LEFT - PAD_RIGHT)
		self.textHeight = MeasureText(GetFont(12), self.labelText, self.textWidth)

		self.frame:SetHeight(self:GetHeight())
		return self:GetHeight()
	end

	control.GetHeight = function(self)
		return max(18, (self.textHeight or self.text:GetStringHeight() or 0) + 14)
	end

	control.SetHelp = function() end
	control.SetDisabled = function() end
	control.SetModified = function() end
	control.SetCallback = function() end
	control.SetOnRevert = function() end

	control.Restyle = function(self)
		SetTextColor(self.text, Kit.TextNormal)
	end

	control:Restyle()
	return control
end

--------------------------------------------------------------------------
-- Multiline text
--------------------------------------------------------------------------
-- The one control that cannot be a label beside a box: an export string is a
-- wall of text and an import needs somewhere to paste one. So this row puts its
-- label on top and gives the whole width to the field beneath.
--
-- Without it the Export and Import page renders its headings and buttons and
-- none of the boxes that make it work.
Controls.CreateMultiline = function(parent)
	local control = CreateRow(parent, "input")
	control.multiline = true

	local LINE = 14
	local TOP = 24

	-- The label spans the row instead of stopping short of a control area.
	control.label:ClearAllPoints()
	control.label:SetPoint("TOPLEFT", control.frame, "TOPLEFT", PAD_LEFT, -6)
	control.label:SetPoint("TOPRIGHT", control.frame, "TOPRIGHT", -PAD_RIGHT, -6)
	control.area:Hide()

	local box = CreateFrame("Frame", nil, control.frame)
	box:SetPoint("TOPLEFT", control.frame, "TOPLEFT", PAD_LEFT, -TOP)
	box:SetPoint("BOTTOMRIGHT", control.frame, "BOTTOMRIGHT", -PAD_RIGHT, 8)
	control.box = box

	local backdrop = Kit.CreateBackdrop(box, Kit.InsetBackdrop, 2)
	backdrop:SetBackdropColor(unpack(Kit.InsetColor))
	control.backdrop = backdrop

	local scroll = CreateFrame("ScrollFrame", nil, box)
	scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -5)
	scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 5)
	scroll:SetClipsChildren(true)
	control.scroll = scroll

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(GetFont(12))
	edit:SetWidth(1)
	edit:SetHeight(1)
	edit:SetJustifyH("LEFT")
	edit:SetJustifyV("TOP")
	scroll:SetScrollChild(edit)
	control.edit = edit

	scroll:SetScript("OnSizeChanged", function(self, width, height)
		if (width and width > 0) then
			edit:SetWidth(width)
		end
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		if (range <= 0) then return end
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * LINE * 2)))
	end)

	-- Clicking anywhere in the field takes focus, not just the text itself.
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		if (not control.disabled) then edit:SetFocus() end
	end)

	local accept = CreateFrame("Button", nil, box)
	accept:SetSize(18, 18)
	accept:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -5, 5)
	accept:Hide()
	control.accept = accept

	local acceptIcon = accept:CreateTexture(nil, "OVERLAY")
	acceptIcon:SetAllPoints()
	Kit.SetGlyph(acceptIcon, "check")
	control.acceptIcon = acceptIcon

	local Commit = function()
		control.committed = edit:GetText()
		accept:Hide()
		edit:ClearFocus()
		control:Fire(control.committed)
	end

	accept:SetScript("OnClick", Commit)

	control.SetNumLines = function(self, lines)
		self.lines = max(3, tonumber(lines) or 4)
		self.frame:SetHeight(self:GetHeight())
	end

	-- The field decides the row's height, not the other way round.
	control.GetHeight = function(self)
		return TOP + (self.lines or 4) * LINE + 16
	end

	control.SetValue = function(self, text)
		self.committed = text or ""
		edit:SetText(self.committed)
		edit:SetCursorPosition(0)
		self.scroll:SetVerticalScroll(0)
		accept:Hide()
	end

	control.GetValue = function(self)
		return edit:GetText()
	end

	control.SetDisabled = function(self, disabled)
		self.disabled = disabled and true or false
		edit:EnableMouse(not self.disabled)
		if (self.disabled) then edit:ClearFocus() end
		self:Restyle()
	end

	-- A help line would push the field down for no gain; the label carries it.
	control.SetHelp = function(self, text)
		if (text and text ~= "") then
			self.label:SetText((self.labelText or "") .. "  |cff808080" .. text .. "|r")
		end
	end

	local baseSetLabel = control.SetLabel
	control.SetLabel = function(self, text)
		self.labelText = text or ""
		baseSetLabel(self, self.labelText)
	end

	local baseRestyle = control.Restyle
	control.Restyle = function(self)
		baseRestyle(self)

		self.backdrop:SetBackdropColor(unpack(Kit.InsetColor))
		Kit.SetBorderColor(self.backdrop, edit:HasFocus() and Kit.BorderFocus or Kit.BorderIdle)
		edit:SetTextColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
		self.acceptIcon:SetVertexColor(unpack(Kit.TextSelected))
	end

	edit:SetScript("OnEscapePressed", function(self)
		self:SetText(control.committed or "")
		self:ClearFocus()
		accept:Hide()
	end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if (userInput) then
			accept:SetShown(self:GetText() ~= (control.committed or ""))
		end
	end)
	edit:SetScript("OnEditFocusGained", function() control:Restyle() end)
	edit:SetScript("OnEditFocusLost", function() control:Restyle() end)

	control:SetNumLines(4)
	control:SetValue("")
	control:SetDisabled(false)
	return control
end

--------------------------------------------------------------------------
-- Factory
--------------------------------------------------------------------------
-- Maps an AceConfig option type to a control. `option` decides the shape where
-- one type has two: a select with only a few values reads better as a strip of
-- buttons than as a dropdown.
local SEGMENTED_LIMIT = 4

-- A strip only works while every label still fits in it. Four choices share
-- the control area between them, so `Top-Right Corner` and its like have to
-- go back to a dropdown however few of them there are. The budget is in
-- characters because that is what the text has to fit, and it is measured
-- against the same area every control gets.
local SEGMENTED_CHARS = 30

Controls.WantsSegmented = function(values)
	if (type(values) ~= "table") then return false end

	local count, width = 0, 0
	for _, label in pairs(values) do
		count = count + 1
		if (count > SEGMENTED_LIMIT) then return false end
		width = width + #tostring(label) + 3
	end

	return count > 0 and width <= SEGMENTED_CHARS
end

Controls.Create = function(parent, optionType, option, valueCount)
	if (optionType == "toggle") then
		return Controls.CreateToggle(parent)

	elseif (optionType == "range") then
		return Controls.CreateSlider(parent)

	elseif (optionType == "select") then
		if (valueCount and valueCount > 0 and valueCount <= SEGMENTED_LIMIT) then
			return Controls.CreateSegmented(parent)
		end
		return Controls.CreateDropdown(parent)

	elseif (optionType == "input") then
		if (option and option.multiline) then
			return Controls.CreateMultiline(parent)
		end
		return Controls.CreateInput(parent)

	elseif (optionType == "execute") then
		return Controls.CreateButton(parent)

	elseif (optionType == "header") then
		return Controls.CreateHeader(parent)

	elseif (optionType == "description") then
		return Controls.CreateParagraph(parent)
	end
end

Controls.SegmentedLimit = SEGMENTED_LIMIT
Controls.RowHeight = ROW_HEIGHT
Controls.ControlWidth = CONTROL_WIDTH

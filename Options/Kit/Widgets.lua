--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen

--]]
-- AzeriteUI widget types for AceConfigDialog.
--
-- These are registered with AceGUI under names namespaced to this addon and
-- reached through each option's `dialogControl`. The stock AceGUI widgets are
-- never touched: AceGUI's widget registry and object pools are global
-- (Libs/AceGUI-3.0/AceGUI-3.0.lua:89), so restyling a stock widget would
-- restyle it inside every other Ace3 addon's window as well.
--
-- Each widget implements exactly the contract AceConfigDialog calls for its
-- option type, as read off AceConfigDialog-3.0.lua:1151-1466.
local Addon, ns = ...

local AceGUI = LibStub("AceGUI-3.0", true)
if (not AceGUI) then return end

local Kit = ns.OptionsKit
local GetFont, GetMedia = Kit.GetFont, Kit.GetMedia

-- Lua API
local floor = math.floor
local string_format = string.format
local max, min = math.max, math.min
local pairs, ipairs = pairs, ipairs
local select, tonumber, tostring = select, tonumber, tostring
local table_sort = table.sort
local unpack = unpack

-- GLOBALS: CreateFrame, UIParent, PlaySound, GameTooltip

local PREFIX = Kit.Prefix
local VERSION = 1

local SOUND_CHECK_ON, SOUND_CHECK_OFF = 856, 857

--------------------------------------------------------------------------
-- Shared scripts
--------------------------------------------------------------------------
local Control_OnEnter = function(frame)
	frame.obj:Fire("OnEnter")
end

local Control_OnLeave = function(frame)
	frame.obj:Fire("OnLeave")
end

-- Sets a fontstring to one of the kit's three text states.
local SetTextColor = function(fontstring, color)
	fontstring:SetTextColor(color[1], color[2], color[3])
end

-- Backdrop colours are applied when the frame is built, so a widget handed
-- back by AceGUI's pool would still be wearing the previous theme. Every
-- widget that owns a backdrop re-applies it on acquire.
local RestyleBackdrop = function(backdrop, color)
	if (not backdrop) then return end
	backdrop:SetBackdropColor(unpack(color))
	Kit.SetBorderColor(backdrop, Kit.BorderIdle)
end

--------------------------------------------------------------------------
-- Page container
--------------------------------------------------------------------------
-- The window hands this to AceConfigDialog:Open() as its container, which
-- makes the dialog feed a page into our frame instead of building a stock
-- window with a TreeGroup down its left side.
do
	local Type = PREFIX .. "Page"

	local methods = {
		["OnAcquire"] = function(self)
			self:SetWidth(600)
			self:SetHeight(400)
		end,

		-- The window owns the size, so a finished layout must not resize us.
		["LayoutFinished"] = function(self, width, height)
		end,

		["OnWidthSet"] = function(self, width)
			local content = self.content
			content:SetWidth(width)
			content.width = width
		end,

		["OnHeightSet"] = function(self, height)
			local content = self.content
			content:SetHeight(height)
			content.height = height
		end,

		["Show"] = function(self)
			self.frame:Show()
		end,

		["Hide"] = function(self)
			self.frame:Hide()
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Frame", nil, UIParent)

		local content = CreateFrame("Frame", nil, frame)
		content:SetPoint("TOPLEFT")
		content:SetPoint("BOTTOMRIGHT")

		local widget = {
			frame = frame,
			content = content,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		return AceGUI:RegisterAsContainer(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- Heading
--------------------------------------------------------------------------
-- A label with the addon's own rule (bar-small) running out to either side.
do
	local Type = PREFIX .. "Heading"

	local methods = {
		["OnAcquire"] = function(self)
			self:SetText("")
			self:SetFullWidth(true)
			self:SetHeight(20)
			self:SetDisabled(false)

			local accent = Kit.TextSelected
			self.left:SetVertexColor(accent[1], accent[2], accent[3], .5)
			self.right:SetVertexColor(accent[1], accent[2], accent[3], .5)
		end,

		["SetText"] = function(self, text)
			self.label:SetText(text or "")
			if (text and text ~= "") then
				self.label:Show()
				self.left:SetPoint("RIGHT", self.label, "LEFT", -6, 0)
				self.right:Show()
			else
				self.label:Hide()
				self.left:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
				self.right:Hide()
			end
		end,

		["SetDisabled"] = function(self, disabled)
			SetTextColor(self.label, disabled and Kit.TextDisabled or Kit.TextSelected)
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetHeight(20)

		-- Centred rather than hung from the top, so that the rules either side
		-- can anchor to the frame's LEFT and RIGHT without their vertical
		-- position disagreeing with the label's.
		local label = frame:CreateFontString(nil, "OVERLAY")
		label:SetFontObject(GetFont(14, true))
		label:SetPoint("CENTER", frame, "CENTER", 0, 0)
		label:SetJustifyH("CENTER")
		SetTextColor(label, Kit.TextSelected)

		local left = frame:CreateTexture(nil, "BACKGROUND")
		left:SetTexture(GetMedia("bar-small"))
		left:SetHeight(4)
		left:SetPoint("LEFT", frame, "LEFT", 0, 0)
		left:SetPoint("RIGHT", label, "LEFT", -6, 0)
		left:SetVertexColor(Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3], .5)

		local right = frame:CreateTexture(nil, "BACKGROUND")
		right:SetTexture(GetMedia("bar-small"))
		right:SetHeight(4)
		right:SetPoint("LEFT", label, "RIGHT", 6, 0)
		right:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		right:SetVertexColor(Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3], .5)

		local widget = {
			label = label,
			left = left,
			right = right,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------
-- border-aura at edgeSize 10, grey at rest and Colors.highlight on the border
-- while hovered. The heavier border-tooltip edge, at 16 with 5px insets, left
-- a 26px button almost no interior: the label was clipped and the control read
-- as squashed. The roadmap artifact uses the aura border on buttons too.
do
	local Type = PREFIX .. "Button"

	local Button_OnClick = function(frame, ...)
		AceGUI:ClearFocus()
		PlaySound(852) -- SOUNDKIT.IG_MAINMENU_OPTION
		frame.obj:Fire("OnClick", ...)
	end

	local Button_OnEnter = function(frame)
		local self = frame.obj
		if (not self.disabled) then
			Kit.SetBorderColor(self.backdrop, Kit.BorderHover)
			SetTextColor(self.text, Kit.TextHighlight)
		end
		self:Fire("OnEnter")
	end

	local Button_OnLeave = function(frame)
		local self = frame.obj
		Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
		SetTextColor(self.text, self.disabled and Kit.TextDisabled or Kit.TextNormal)
		self:Fire("OnLeave")
	end

	local methods = {
		["OnAcquire"] = function(self)
			self:SetHeight(30)
			self:SetWidth(200)
			self:SetText("")
			self:SetDisabled(false)
			RestyleBackdrop(self.backdrop, Kit.BackdropColor)
		end,

		["SetText"] = function(self, text)
			self.text:SetText(text or "")
		end,

		["SetDisabled"] = function(self, disabled)
			self.disabled = disabled
			if (disabled) then
				self.frame:Disable()
				SetTextColor(self.text, Kit.TextDisabled)
			else
				self.frame:Enable()
				SetTextColor(self.text, Kit.TextNormal)
			end
			Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Button", nil, UIParent)
		frame:SetHeight(30)
		frame:EnableMouse(true)
		frame:SetScript("OnClick", Button_OnClick)
		frame:SetScript("OnEnter", Button_OnEnter)
		frame:SetScript("OnLeave", Button_OnLeave)

		local backdrop = Kit.CreateBackdrop(frame, Kit.InsetBackdrop)

		-- Anchored to both edges with padding rather than centred, so a long
		-- label is held to one line and shortened instead of overflowing.
		local text = frame:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GetFont(13))
		text:SetPoint("LEFT", frame, "LEFT", 10, 0)
		text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
		text:SetJustifyH("CENTER")
		text:SetWordWrap(false)
		SetTextColor(text, Kit.TextNormal)

		local widget = {
			text = text,
			backdrop = backdrop,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- CheckBox
--------------------------------------------------------------------------
-- point_block for the box, glyph cell 0,0 (check) or 1,0 (dash, for the
-- unknown third state) laid on top.
do
	local Type = PREFIX .. "CheckBox"
	local BOX = 19 -- options-box is drawn edge to edge, so this is literal

	local CheckBox_OnClick = function(frame)
		local self = frame.obj
		if (self.disabled) then return end

		AceGUI:ClearFocus()
		self:ToggleChecked()
		PlaySound(self.checked and SOUND_CHECK_ON or SOUND_CHECK_OFF)
		self:Fire("OnValueChanged", self.checked)
	end

	local CheckBox_OnEnter = function(frame)
		local self = frame.obj
		if (not self.disabled) then
			SetTextColor(self.text, Kit.TextHighlight)
			self.glow:Show()
		end
		self:Fire("OnEnter")
	end

	local CheckBox_OnLeave = function(frame)
		local self = frame.obj
		SetTextColor(self.text, self.disabled and Kit.TextDisabled or Kit.TextNormal)
		self.glow:Hide()
		self:Fire("OnLeave")
	end

	local methods = {
		["OnAcquire"] = function(self)
			self:SetWidth(200)
			self:SetHeight(24)
			self:SetTriState(nil)
			self:SetValue(false)
			self:SetImage()
			self:SetDescription(nil)
			self:SetDisabled(nil)
		end,

		["OnRelease"] = function(self)
			self.glow:Hide()
		end,

		["OnWidthSet"] = function(self, width)
			if (self.desc) then
				self.desc:SetWidth(width - BOX - 14)
				local text = self.desc:GetText()
				if (text and text ~= "") then
					self:SetHeight(28 + self.desc:GetStringHeight())
				end
			end
		end,

		["SetLabel"] = function(self, label)
			self.text:SetText(label or "")
		end,

		["SetValue"] = function(self, value)
			self.checked = value
			if (value) then
				self.check:SetTexture(GetMedia("options-check"))
				self.check:SetTexCoord(0, 1, 0, 1)
				self.check:Show()
			elseif (self.tristate and value == nil) then
				-- Nil is the unknown third state, drawn as the dash glyph.
				Kit.SetGlyph(self.check, "dash")
				self.check:Show()
			else
				self.check:Hide()
			end
			self:SetDisabled(self.disabled)
		end,

		["GetValue"] = function(self)
			return self.checked
		end,

		["SetTriState"] = function(self, enabled)
			self.tristate = enabled
			self:SetValue(self:GetValue())
		end,

		["ToggleChecked"] = function(self)
			local value = self:GetValue()
			if (self.tristate) then
				-- Cycles true, nil, false, matching the stock widget.
				if (value) then
					self:SetValue(nil)
				elseif (value == nil) then
					self:SetValue(false)
				else
					self:SetValue(true)
				end
			else
				self:SetValue(not value)
			end
		end,

		-- Only reached if an option asks for a radio style by hand. The kit
		-- does not route radio groups here, but answering keeps it from
		-- erroring if somebody does.
		["SetType"] = function(self, type)
		end,

		-- Re-reads the theme as well as the enabled state, so a widget that
		-- comes back from the pool never keeps the previous theme's colours.
		["SetDisabled"] = function(self, disabled)
			self.disabled = disabled

			local text = disabled and Kit.TextDisabled or Kit.TextNormal
			local mark = disabled and Kit.TextDisabled or Kit.TextSelected

			if (disabled) then self.frame:Disable() else self.frame:Enable() end

			SetTextColor(self.text, text)
			if (self.desc) then SetTextColor(self.desc, text) end
			self.box:SetVertexColor(unpack(text))
			self.check:SetVertexColor(unpack(mark))
			self.glow:SetVertexColor(unpack(Kit.TextSelected))
		end,

		["SetDescription"] = function(self, desc)
			if (desc) then
				if (not self.desc) then
					local f = self.frame:CreateFontString(nil, "OVERLAY")
					f:SetFontObject(GetFont(12))
					f:ClearAllPoints()
					f:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 8, -20)
					f:SetPoint("RIGHT", self.frame, "RIGHT", -8, 0)
					f:SetJustifyH("LEFT")
					f:SetJustifyV("TOP")
					SetTextColor(f, Kit.TextNormal)
					self.desc = f
				end
				self.desc:Show()
				self.desc:SetText(desc)
				self:SetHeight(28 + self.desc:GetStringHeight())
			else
				if (self.desc) then
					self.desc:SetText("")
					self.desc:Hide()
				end
				self:SetHeight(24)
			end
		end,

		-- Options may carry an icon beside the label.
		["SetImage"] = function(self, path, ...)
			local image = self.image
			image:SetTexture(path)

			if (image:GetTexture()) then
				local n = select("#", ...)
				if (n == 4 or n == 8) then
					image:SetTexCoord(...)
				else
					image:SetTexCoord(0, 1, 0, 1)
				end
				image:Show()
				self.text:SetPoint("LEFT", image, "RIGHT", 4, 0)
			else
				image:Hide()
				self.text:SetPoint("LEFT", self.box, "RIGHT", 8, 0)
			end
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Button", nil, UIParent)
		frame:SetHeight(24)
		frame:EnableMouse(true)
		frame:SetScript("OnClick", CheckBox_OnClick)
		frame:SetScript("OnEnter", CheckBox_OnEnter)
		frame:SetScript("OnLeave", CheckBox_OnLeave)

		-- options-box and options-check are drawn edge to edge and carry no
		-- drop shadow, so unlike the sculpted set they are sized literally.
		local box = frame:CreateTexture(nil, "ARTWORK")
		box:SetTexture(GetMedia("options-box"))
		box:SetSize(BOX, BOX)
		box:SetPoint("LEFT", frame, "LEFT", 0, 0)

		local glow = frame:CreateTexture(nil, "ARTWORK", nil, 1)
		glow:SetTexture(GetMedia("options-box"))
		glow:SetAllPoints(box)
		glow:SetBlendMode("ADD")
		glow:SetAlpha(.30)
		glow:Hide()

		local check = frame:CreateTexture(nil, "OVERLAY")
		check:SetTexture(GetMedia("options-check"))
		check:SetSize(BOX, BOX)
		check:SetPoint("CENTER", box, "CENTER", 0, 0)
		check:Hide()

		local image = frame:CreateTexture(nil, "OVERLAY")
		image:SetSize(16, 16)
		image:SetPoint("LEFT", frame, "LEFT", BOX + 8, 0)
		image:Hide()

		local text = frame:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GetFont(12))
		text:SetJustifyH("LEFT")
		text:SetJustifyV("MIDDLE")
		text:SetPoint("LEFT", frame, "LEFT", BOX + 8, 0)
		text:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
		SetTextColor(text, Kit.TextNormal)

		local widget = {
			box = box,
			glow = glow,
			check = check,
			image = image,
			text = text,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- EditBox
--------------------------------------------------------------------------
do
	local Type = PREFIX .. "EditBox"

	local EditBox_OnEnterPressed = function(frame)
		local self = frame.obj
		if (self.disabled) then return end

		local value = frame:GetText()
		local result = self:Fire("OnEnterPressed", value)
		if (result ~= false) then
			PlaySound(SOUND_CHECK_ON)
			frame:ClearFocus()
			self.accept:Hide()
		end
	end

	local EditBox_OnEscapePressed = function(frame)
		frame:ClearFocus()
		frame:SetText(frame.obj.lastText or "")
		frame.obj.accept:Hide()
	end

	local EditBox_OnTextChanged = function(frame, userInput)
		local self = frame.obj
		if (userInput) then
			self:Fire("OnTextChanged", frame:GetText())
			if (frame:GetText() ~= (self.lastText or "")) then
				self.accept:Show()
			else
				self.accept:Hide()
			end
		end
	end

	local EditBox_OnFocusGained = function(frame)
		AceGUI:SetFocus(frame.obj)
		Kit.SetBorderColor(frame.obj.backdrop, Kit.BorderFocus)
	end

	local EditBox_OnFocusLost = function(frame)
		Kit.SetBorderColor(frame.obj.backdrop, Kit.BorderIdle)
	end

	local Accept_OnClick = function(button)
		EditBox_OnEnterPressed(button.obj.editbox)
	end

	local methods = {
		["OnAcquire"] = function(self)
			self:SetHeight(44)
			self:SetWidth(200)
			self:SetLabel("")
			self:SetText("")
			self:SetDisabled(false)
			self.accept:Hide()
			RestyleBackdrop(self.backdrop, Kit.InsetColor)
		end,

		["OnRelease"] = function(self)
			self:ClearFocus()
		end,

		["SetLabel"] = function(self, label)
			if (label and label ~= "") then
				self.label:SetText(label)
				self.label:Show()
				self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, -18)
				self:SetHeight(44)
			else
				self.label:SetText("")
				self.label:Hide()
				self.editbox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, 0)
				self:SetHeight(26)
			end
		end,

		["SetText"] = function(self, text)
			self.lastText = text or ""
			self.editbox:SetText(text or "")
			self.editbox:SetCursorPosition(0)
			self.accept:Hide()
		end,

		["GetText"] = function(self)
			return self.editbox:GetText()
		end,

		["SetDisabled"] = function(self, disabled)
			self.disabled = disabled
			if (disabled) then
				self.editbox:EnableMouse(false)
				self.editbox:ClearFocus()
				self.editbox:SetTextColor(unpack(Kit.TextDisabled))
				SetTextColor(self.label, Kit.TextDisabled)
			else
				self.editbox:EnableMouse(true)
				self.editbox:SetTextColor(unpack(Kit.TextHighlight))
				SetTextColor(self.label, Kit.TextNormal)
			end
		end,

		["ClearFocus"] = function(self)
			self.editbox:ClearFocus()
		end,

		["SetFocus"] = function(self)
			self.editbox:SetFocus()
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetHeight(44)

		local label = frame:CreateFontString(nil, "OVERLAY")
		label:SetFontObject(GetFont(12))
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 0)
		label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 0)
		label:SetJustifyH("LEFT")
		label:SetHeight(16)
		SetTextColor(label, Kit.TextNormal)

		local editbox = CreateFrame("EditBox", nil, frame)
		editbox:SetAutoFocus(false)
		editbox:SetFontObject(GetFont(12))
		editbox:SetTextInsets(6, 24, 0, 0)
		editbox:SetHeight(24)
		editbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -18)
		editbox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -18)
		editbox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
		editbox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)
		editbox:SetScript("OnTextChanged", EditBox_OnTextChanged)
		editbox:SetScript("OnEditFocusGained", EditBox_OnFocusGained)
		editbox:SetScript("OnEditFocusLost", EditBox_OnFocusLost)
		editbox:SetScript("OnEnter", Control_OnEnter)
		editbox:SetScript("OnLeave", Control_OnLeave)

		local backdrop = Kit.CreateBackdrop(editbox, Kit.InsetBackdrop, 2)
		backdrop:SetBackdropColor(unpack(Kit.InsetColor))

		-- Shown once the text differs from what was loaded, so it is always
		-- clear that a typed value has not been committed yet.
		local accept = CreateFrame("Button", nil, frame)
		accept:SetSize(18, 18)
		accept:SetPoint("RIGHT", editbox, "RIGHT", -4, 0)
		accept:SetScript("OnClick", Accept_OnClick)
		accept:Hide()

		local acceptTexture = accept:CreateTexture(nil, "OVERLAY")
		acceptTexture:SetAllPoints()
		acceptTexture:SetVertexColor(unpack(Kit.TextSelected))
		Kit.SetGlyph(acceptTexture, "check")

		local widget = {
			label = label,
			editbox = editbox,
			accept = accept,
			backdrop = backdrop,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		editbox.obj = widget
		accept.obj = widget

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------
-- A real StatusBar carries the fill. An earlier version positioned the fill by
-- hand from the track's pixel width, which broke every time AceConfigDialog
-- refreshed the page: the widget came back from the pool before layout had
-- given the track a width, the computed width was zero, and the bar hid itself
-- until the next drag recomputed it. A StatusBar is resized by the engine, so
-- there is no width to get wrong and nothing to hide.
do
	local Type = PREFIX .. "Slider"
	local TRACK_HEIGHT = 16

	local UpdateFill = function(self)
		local minValue, maxValue = self.min or 0, self.max or 100
		if (maxValue <= minValue) then
			maxValue = minValue + 1
		end

		self.fill:SetMinMaxValues(minValue, maxValue)
		self.fill:SetValue(min(maxValue, max(minValue, self.value or minValue)))
	end

	-- The value sits in an EditBox, which has SetText but no SetFormattedText.
	local UpdateText = function(self)
		local value = self.value or 0
		if (self.ispercent) then
			self.valuebox:SetText(string_format("%s%%", floor(value * 1000 + 0.5) / 10))
		else
			self.valuebox:SetText(tostring(floor(value * 100 + 0.5) / 100))
		end
	end

	-- Re-read the theme. Called on acquire and whenever the enabled state
	-- changes, so a pooled widget never keeps the previous theme's colours.
	local Restyle = function(self)
		SetTextColor(self.label, self.disabled and Kit.TextDisabled or Kit.TextNormal)
		self.valuebox:SetTextColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))

		local track = Kit.TrackColor
		for i = 1, #self.trackSlices do
			self.trackSlices[i]:SetVertexColor(track[1], track[2], track[3], track[4] or 1)
		end

		self.fillTexture:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextSelected))
		self.thumb:SetVertexColor(unpack(self.disabled and Kit.TextDisabled or Kit.TextHighlight))
	end

	local Slider_OnValueChanged = function(frame, newvalue)
		local self = frame.obj
		if (frame.setup) then return end

		if (self.step and self.step > 0) then
			local minValue = self.min or 0
			newvalue = floor((newvalue - minValue) / self.step + 0.5) * self.step + minValue
		end
		if (newvalue ~= self.value and not self.disabled) then
			self.value = newvalue
			self:Fire("OnValueChanged", newvalue)
		end
		if (self.value) then
			UpdateText(self)
			UpdateFill(self)
		end
	end

	local Slider_OnMouseUp = function(frame)
		local self = frame.obj
		self:Fire("OnMouseUp", self.value)
	end

	local Slider_OnMouseWheel = function(frame, delta)
		local self = frame.obj
		if (self.disabled) then return end

		local value = self.value or 0
		local step = (self.step and self.step > 0) and self.step or 1
		if (delta > 0) then
			value = min(value + step, self.max or 100)
		else
			value = max(value - step, self.min or 0)
		end
		self.slider:SetValue(value)
		self:Fire("OnMouseUp", self.value)
	end

	local EditBox_OnEnterPressed = function(frame)
		local self = frame.obj
		local value = frame:GetText()
		if (self.ispercent) then
			value = tonumber((value:gsub("%%", "")))
			value = value and value / 100
		else
			value = tonumber(value)
		end
		if (value) then
			PlaySound(SOUND_CHECK_ON)
			self.slider:SetValue(value)
			self:Fire("OnMouseUp", self.value)
		else
			UpdateText(self)
		end
		frame:ClearFocus()
	end

	local EditBox_OnEscapePressed = function(frame)
		frame:ClearFocus()
		UpdateText(frame.obj)
	end

	local methods = {
		["OnAcquire"] = function(self)
			self:SetWidth(200)
			self:SetHeight(48)
			self:SetLabel("")
			self:SetIsPercent(nil)
			self:SetSliderValues(0, 100, 1)
			self:SetValue(0)
			self:SetDisabled(false)
		end,

		["OnRelease"] = function(self)
			self.valuebox:ClearFocus()
		end,

		["SetLabel"] = function(self, label)
			self.label:SetText(label or "")
		end,

		["SetSliderValues"] = function(self, minValue, maxValue, step)
			local slider = self.slider
			slider.setup = true
			self.min, self.max, self.step = minValue, maxValue, step
			slider:SetMinMaxValues(minValue or 0, maxValue or 100)
			if (step and step > 0) then
				slider:SetValueStep(step)
				slider:SetObeyStepOnDrag(true)
			else
				slider:SetValueStep(0)
				slider:SetObeyStepOnDrag(false)
			end
			slider:SetValue(self.value or 0)
			slider.setup = nil
			UpdateFill(self)
		end,

		["SetValue"] = function(self, value)
			local slider = self.slider
			slider.setup = true
			slider:SetValue(value)
			self.value = value
			slider.setup = nil
			UpdateText(self)
			UpdateFill(self)
		end,

		["GetValue"] = function(self)
			return self.value
		end,

		["SetIsPercent"] = function(self, value)
			self.ispercent = value
			UpdateText(self)
		end,

		["SetDisabled"] = function(self, disabled)
			self.disabled = disabled
			self.slider:EnableMouse(not disabled)
			self.slider:EnableMouseWheel(not disabled)
			self.valuebox:EnableMouse(not disabled)
			if (disabled) then
				self.valuebox:ClearFocus()
			end
			Restyle(self)
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetHeight(48)

		local label = frame:CreateFontString(nil, "OVERLAY")
		label:SetFontObject(GetFont(13))
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -1)
		label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -66, -1)
		label:SetJustifyH("LEFT")
		label:SetHeight(16)
		label:SetWordWrap(false)

		-- The typed value sits to the right of the label, above the track.
		local valuebox = CreateFrame("EditBox", nil, frame)
		valuebox:SetAutoFocus(false)
		valuebox:SetFontObject(GetFont(13))
		valuebox:SetJustifyH("RIGHT")
		valuebox:SetSize(58, 18)
		valuebox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -1)
		valuebox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
		valuebox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)

		local track = CreateFrame("Frame", nil, frame)
		track:SetHeight(TRACK_HEIGHT)
		track:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
		track:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

		-- The trough is cast_back cropped to its opaque body and three-sliced,
		-- so the chamfered ends keep their shape while the middle stretches.
		local capWidth = Kit.TrackCap * TRACK_HEIGHT / Kit.TrackBodyH
		local trackSlices = {}

		local trackLeft = track:CreateTexture(nil, "BACKGROUND")
		trackLeft:SetTexture(GetMedia("cast_back"))
		trackLeft:SetTexCoord(unpack(Kit.TrackSliceL))
		trackLeft:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
		trackLeft:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
		trackLeft:SetWidth(capWidth)

		local trackRight = track:CreateTexture(nil, "BACKGROUND")
		trackRight:SetTexture(GetMedia("cast_back"))
		trackRight:SetTexCoord(unpack(Kit.TrackSliceR))
		trackRight:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
		trackRight:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
		trackRight:SetWidth(capWidth)

		local trackMid = track:CreateTexture(nil, "BACKGROUND")
		trackMid:SetTexture(GetMedia("cast_back"))
		trackMid:SetTexCoord(unpack(Kit.TrackSliceM))
		trackMid:SetPoint("TOPLEFT", trackLeft, "TOPRIGHT", 0, 0)
		trackMid:SetPoint("BOTTOMRIGHT", trackRight, "BOTTOMLEFT", 0, 0)

		trackSlices[1], trackSlices[2], trackSlices[3] = trackLeft, trackMid, trackRight

		-- A StatusBar still drives the geometry, because the engine keeps its
		-- texture the right size at all times and never hands back a zero width.
		-- Its own texture is invisible: the visible fill is anchored to it, so
		-- cast_bar *stretches* into the filled width rather than being cropped,
		-- and keeps both of its chamfered ends at every value.
		local fill = CreateFrame("StatusBar", nil, track)
		fill:SetPoint("TOPLEFT", track, "TOPLEFT", 3, -3)
		fill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -3, 3)
		fill:SetStatusBarTexture(GetMedia("plain"))
		fill:SetMinMaxValues(0, 100)
		fill:SetValue(0)

		local driver = fill:GetStatusBarTexture()
		driver:SetAlpha(0)

		local fillTexture = fill:CreateTexture(nil, "ARTWORK")
		fillTexture:SetTexture(GetMedia("cast_bar"))
		fillTexture:SetPoint("TOPLEFT", driver, "TOPLEFT", 0, 0)
		fillTexture:SetPoint("BOTTOMRIGHT", driver, "BOTTOMRIGHT", 0, 0)

		local slider = CreateFrame("Slider", nil, track)
		slider:SetOrientation("HORIZONTAL")
		slider:SetAllPoints(track)
		slider:SetHitRectInsets(0, 0, -8, -8)
		slider:SetThumbTexture(GetMedia("point_diamond"))
		slider:SetScript("OnValueChanged", Slider_OnValueChanged)
		slider:SetScript("OnMouseUp", Slider_OnMouseUp)
		slider:SetScript("OnMouseWheel", Slider_OnMouseWheel)
		slider:SetScript("OnEnter", Control_OnEnter)
		slider:SetScript("OnLeave", Control_OnLeave)
		slider:EnableMouseWheel(true)
		slider:SetFrameLevel(fill:GetFrameLevel() + 1)

		-- point_diamond carries a drop shadow, so it is drawn well over the
		-- size of the diamond the player sees.
		local thumb = slider:GetThumbTexture()
		local thumbBody = TRACK_HEIGHT + 4
		thumb:SetSize(Kit.DrawSize(thumbBody, "point_diamond"), Kit.DrawSize(thumbBody, "point_diamond"))

		local widget = {
			label = label,
			valuebox = valuebox,
			track = track,
			trackSlices = trackSlices,
			fill = fill,
			fillTexture = fillTexture,
			slider = slider,
			thumb = thumb,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		slider.obj = widget
		valuebox.obj = widget
		track.obj = widget

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------
-- One shared pullout serves every dropdown. Only one can be open at a time,
-- so pooling a list per widget would only cost memory.
do
	local Type = PREFIX .. "Dropdown"
	local ROW_HEIGHT = 20
	local MAX_ROWS = 16

	local pullout, rows, owner

	local ClosePullout = function()
		if (pullout) then
			pullout:Hide()
			owner = nil
		end
	end
	Kit.CloseDropdown = ClosePullout

	Kit.IsDropdownOpen = function()
		return pullout and pullout:IsShown()
	end

	local Row_OnClick = function(row)
		local dropdown = owner
		ClosePullout()
		if (dropdown) then
			PlaySound(SOUND_CHECK_ON)
			dropdown:SetValue(row.key)
			dropdown:Fire("OnValueChanged", row.key)
		end
	end

	local Row_OnEnter = function(row)
		row.highlight:Show()
		SetTextColor(row.text, Kit.TextHighlight)
	end

	local Row_OnLeave = function(row)
		row.highlight:Hide()
		SetTextColor(row.text, row.selected and Kit.TextSelected or Kit.TextNormal)
	end

	local CreatePullout = function()
		local frame = CreateFrame("Frame", nil, UIParent, ns.BackdropTemplate)
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetToplevel(true)
		frame:SetClampedToScreen(true)
		frame:SetBackdrop(Kit.ButtonBackdrop)
		frame:SetBackdropColor(.02, .02, .02, .97)
		frame:SetBackdropBorderColor(unpack(Kit.BorderFocus))
		frame:EnableMouse(true)
		frame:Hide()

		-- Catches the click that should dismiss the list. It is a sibling of
		-- the pullout rather than a child, so that raising the pullout can
		-- never lift the catcher above the rows it sits behind.
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
		frame:SetScript("OnHide", function()
			catcher:Hide()
		end)

		local scroll = CreateFrame("ScrollFrame", nil, frame)
		scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
		scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

		local child = CreateFrame("Frame", nil, scroll)
		child:SetSize(1, 1)
		scroll:SetScrollChild(child)

		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange()
			if (range <= 0) then return end
			local value = self:GetVerticalScroll() - delta * ROW_HEIGHT * 2
			self:SetVerticalScroll(min(range, max(0, value)))
		end)

		frame.scroll = scroll
		frame.child = child

		return frame
	end

	local GetRow = function(index)
		local row = rows[index]
		if (row) then return row end

		row = CreateFrame("Button", nil, pullout.child)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("LEFT", pullout.child, "LEFT", 0, 0)
		row:SetPoint("RIGHT", pullout.child, "RIGHT", 0, 0)
		row:SetPoint("TOP", pullout.child, "TOP", 0, -(index - 1) * ROW_HEIGHT)
		row:SetScript("OnClick", Row_OnClick)
		row:SetScript("OnEnter", Row_OnEnter)
		row:SetScript("OnLeave", Row_OnLeave)

		local highlight = row:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture(GetMedia("bar-small"))
		highlight:SetAllPoints()
		highlight:SetVertexColor(Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3], .25)
		highlight:Hide()

		local check = row:CreateTexture(nil, "OVERLAY")
		check:SetSize(12, 12)
		check:SetPoint("LEFT", row, "LEFT", 4, 0)
		check:SetVertexColor(unpack(Kit.TextSelected))
		Kit.SetGlyph(check, "check")
		check:Hide()

		local text = row:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GetFont(12))
		text:SetPoint("LEFT", row, "LEFT", 20, 0)
		text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		text:SetJustifyH("LEFT")
		SetTextColor(text, Kit.TextNormal)

		row.highlight = highlight
		row.check = check
		row.text = text

		rows[index] = row
		return row
	end

	local OpenPullout = function(dropdown)
		if (not pullout) then
			pullout = CreatePullout()
			rows = {}
		end

		if (owner == dropdown and pullout:IsShown()) then
			ClosePullout()
			return
		end

		owner = dropdown

		local order = dropdown.order
		local list = dropdown.list or {}
		local count = 0

		for i, key in ipairs(order) do
			local row = GetRow(i)
			row.key = key
			row.text:SetText(tostring(list[key]))
			row.selected = (key == dropdown.value)
			row.check:SetShown(row.selected)
			SetTextColor(row.text, row.selected and Kit.TextSelected or Kit.TextNormal)
			row:Show()
			count = i
		end
		for i = count + 1, #rows do
			rows[i]:Hide()
		end

		local shown = min(count, MAX_ROWS)
		local width = max(dropdown.frame:GetWidth(), 160)

		pullout.child:SetSize(width - 12, count * ROW_HEIGHT)
		pullout.scroll:SetVerticalScroll(0)
		pullout:SetSize(width, shown * ROW_HEIGHT + 12)
		pullout:ClearAllPoints()
		pullout:SetPoint("TOPLEFT", dropdown.box, "BOTTOMLEFT", 0, -2)
		pullout:Show()
		pullout:Raise()
	end

	local Box_OnClick = function(frame)
		local self = frame.obj
		if (self.disabled) then return end

		AceGUI:ClearFocus()
		PlaySound(852) -- SOUNDKIT.IG_MAINMENU_OPTION
		OpenPullout(self)
	end

	local Box_OnEnter = function(frame)
		local self = frame.obj
		if (not self.disabled) then
			Kit.SetBorderColor(self.backdrop, Kit.BorderHover)
		end
		self:Fire("OnEnter")
	end

	local Box_OnLeave = function(frame)
		local self = frame.obj
		Kit.SetBorderColor(self.backdrop, Kit.BorderIdle)
		self:Fire("OnLeave")
	end

	local methods = {
		["OnAcquire"] = function(self)
			self:SetHeight(44)
			self:SetWidth(200)
			self:SetLabel("")
			self:SetList(nil)
			self:SetValue(nil)
			self:SetDisabled(false)
			RestyleBackdrop(self.backdrop, Kit.InsetColor)
		end,

		["OnRelease"] = function(self)
			if (owner == self) then
				ClosePullout()
			end
			self.list = nil
			self.order = nil
		end,

		["SetLabel"] = function(self, label)
			if (label and label ~= "") then
				self.label:SetText(label)
				self.label:Show()
				self.box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, -18)
				self:SetHeight(44)
			else
				self.label:SetText("")
				self.label:Hide()
				self.box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, 0)
				self:SetHeight(26)
			end
		end,

		-- AceConfigDialog passes the values table and an optional sort order.
		["SetList"] = function(self, list, order, itemType)
			self.list = list or {}
			self.order = {}

			if (order) then
				for i, key in ipairs(order) do
					self.order[#self.order + 1] = key
				end
			else
				for key in pairs(self.list) do
					self.order[#self.order + 1] = key
				end
				table_sort(self.order, function(a, b)
					return tostring(self.list[a]) < tostring(self.list[b])
				end)
			end

			self:SetValue(self.value)
		end,

		["SetValue"] = function(self, value)
			self.value = value
			local text = self.list and self.list[value]
			if (text ~= nil) then
				self.text:SetText(tostring(text))
				SetTextColor(self.text, self.disabled and Kit.TextDisabled or Kit.TextHighlight)
			else
				self.text:SetText("")
			end
			if (owner == self and pullout and pullout:IsShown()) then
				OpenPullout(self)
			end
		end,

		["GetValue"] = function(self)
			return self.value
		end,

		["SetItemValue"] = function(self, item, value)
		end,

		["SetMultiselect"] = function(self, multi)
		end,

		["SetDisabled"] = function(self, disabled)
			self.disabled = disabled
			if (disabled) then
				self.box:Disable()
				SetTextColor(self.label, Kit.TextDisabled)
				SetTextColor(self.text, Kit.TextDisabled)
				self.chevron:SetVertexColor(unpack(Kit.TextDisabled))
				if (owner == self) then ClosePullout() end
			else
				self.box:Enable()
				SetTextColor(self.label, Kit.TextNormal)
				SetTextColor(self.text, Kit.TextHighlight)
				self.chevron:SetVertexColor(unpack(Kit.TextSelected))
			end
		end
	}

	local Constructor = function()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetHeight(44)

		local label = frame:CreateFontString(nil, "OVERLAY")
		label:SetFontObject(GetFont(12))
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 0)
		label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 0)
		label:SetJustifyH("LEFT")
		label:SetHeight(16)
		SetTextColor(label, Kit.TextNormal)

		local box = CreateFrame("Button", nil, frame)
		box:SetHeight(24)
		box:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -18)
		box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -18)
		box:SetScript("OnClick", Box_OnClick)
		box:SetScript("OnEnter", Box_OnEnter)
		box:SetScript("OnLeave", Box_OnLeave)

		local backdrop = Kit.CreateBackdrop(box, Kit.InsetBackdrop, 2)
		backdrop:SetBackdropColor(unpack(Kit.InsetColor))

		local chevron = box:CreateTexture(nil, "OVERLAY")
		chevron:SetSize(14, 14)
		chevron:SetPoint("RIGHT", box, "RIGHT", -6, 0)
		chevron:SetVertexColor(unpack(Kit.TextSelected))
		Kit.SetGlyph(chevron, "chevron")

		local text = box:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(GetFont(12))
		text:SetPoint("LEFT", box, "LEFT", 8, 0)
		text:SetPoint("RIGHT", chevron, "LEFT", -4, 0)
		text:SetJustifyH("LEFT")
		SetTextColor(text, Kit.TextHighlight)

		local widget = {
			label = label,
			box = box,
			text = text,
			chevron = chevron,
			backdrop = backdrop,
			frame = frame,
			type = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		box.obj = widget

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, VERSION)
end

--------------------------------------------------------------------------
-- Type names, for the dialogControl pass in Window.lua
--------------------------------------------------------------------------
Kit.Types = {
	Page = PREFIX .. "Page",
	Heading = PREFIX .. "Heading",
	Button = PREFIX .. "Button",
	CheckBox = PREFIX .. "CheckBox",
	EditBox = PREFIX .. "EditBox",
	Slider = PREFIX .. "Slider",
	Dropdown = PREFIX .. "Dropdown"
}

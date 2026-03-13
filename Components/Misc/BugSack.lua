--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local BugSackClipboard = ns:NewModule("BugSackClipboard", "LibMoreEvents-1.0", "AceHook-3.0")

local ipairs = ipairs
local math_max = math.max
local string_format = string.format
local string_rep = string.rep
local table_concat = table.concat

local function GetSessionCopyLabel()
	local copyText = L["Copy"] or COPY or "Copy"
	return string_format("%s Session", copyText)
end

local function StripColorMarkup(text)
	if (type(text) ~= "string" or text == "") then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("||", "|")
	return text
end

local function GetCurrentSessionSnapshot()
	local bugSack = _G.BugSack
	local bugGrabber = _G.BugGrabber
	if (type(bugSack) ~= "table"
		or type(bugSack.GetErrors) ~= "function"
		or type(bugSack.FormatError) ~= "function"
		or type(bugGrabber) ~= "table"
		or type(bugGrabber.GetSessionId) ~= "function") then
		return "", 0, nil
	end

	local sessionId = bugGrabber:GetSessionId()
	local errors = bugSack:GetErrors(sessionId)
	if (type(errors) ~= "table" or #errors == 0) then
		return "", 0, sessionId
	end

	local total = #errors
	local lines = {
		string_format("BugSack Current Session (%d)", sessionId),
		string_format("Errors: %d", total)
	}

	for index, err in ipairs(errors) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = string_rep("-", 72)
		lines[#lines + 1] = string_format("[%d/%d]", index, total)
		lines[#lines + 1] = StripColorMarkup(bugSack:FormatError(err))
	end

	return table_concat(lines, "\n"), total, sessionId
end

BugSackClipboard.UpdateCopyButton = function(self)
	local button = self.CopyButton
	if (not button) then
		return
	end
	local _, total = GetCurrentSessionSnapshot()
	if (total > 0) then
		button:Enable()
	else
		button:Disable()
	end
end

BugSackClipboard.CreateCopyWindow = function(self)
	local frame = self.CopyFrame
	if (frame) then
		return frame
	end

	frame = CreateFrame("Frame", "AzeriteUI_BugSackCopyFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(920, 520)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame.TitleText:SetText("BugSack Current Session")
	frame:Hide()

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 46)

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetTextInsets(6, 6, 6, 6)
	editBox:SetWidth(840)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	editBox:SetScript("OnEditFocusGained", function(box)
		box:HighlightText()
	end)
	editBox:SetScript("OnMouseUp", function(box)
		if (not box:HasFocus()) then
			box:SetFocus()
			box:HighlightText()
		end
	end)
	editBox:SetScript("OnTextChanged", function(box)
		local minHeight = scrollFrame:GetHeight()
		local _, lineHeight = box:GetFont()
		if (type(lineHeight) ~= "number" or lineHeight <= 0) then
			lineHeight = 14
		end
		local lineCount = 1
		if (box.GetNumLines) then
			local okLines, value = pcall(box.GetNumLines, box)
			if (okLines and type(value) == "number" and value > 0) then
				lineCount = value
			end
		end
		local textHeight = (lineCount * lineHeight) + 24
		box:SetHeight(math_max(minHeight, textHeight))
	end)
	editBox:SetScript("OnKeyDown", function(_, key)
		if ((key == "C" or key == "c")
			and ((IsControlKeyDown and IsControlKeyDown())
				or (IsMetaKeyDown and IsMetaKeyDown()))) then
			if (frame.__AzeriteUI_CloseScheduled) then
				return
			end
			frame.__AzeriteUI_CloseScheduled = true
			C_Timer.After(0, function()
				frame.__AzeriteUI_CloseScheduled = nil
				if (frame:IsShown()) then
					frame:Hide()
				end
				print("|cff33ff99", "AzeriteUI BugSack:", "current session copied and popup closed.")
			end)
		end
	end)
	scrollFrame:SetScrollChild(editBox)

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(100, 22)
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
	close:SetText(CLOSE or "Close")
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.ScrollFrame = scrollFrame
	frame.EditBox = editBox
	frame:SetScript("OnShow", function(current)
		local bugSackFrame = _G.BugSackFrame
		if (bugSackFrame and bugSackFrame.GetFrameLevel) then
			current:SetFrameLevel(bugSackFrame:GetFrameLevel() + 20)
		end
		current:Raise()
		local box = current.EditBox
		current.ScrollFrame:SetVerticalScroll(0)
		box:SetFocus()
		box:HighlightText()
	end)

	self.CopyFrame = frame
	return frame
end

BugSackClipboard.ShowCopyWindow = function(self)
	local text = GetCurrentSessionSnapshot()
	if (text == "") then
		print("|cff33ff99", "AzeriteUI BugSack:", "no current-session bugs available to copy.")
		return
	end
	local frame = self:CreateCopyWindow()
	local editBox = frame.EditBox
	editBox:SetText(text)
	editBox:SetCursorPosition(0)
	frame.ScrollFrame:SetVerticalScroll(0)
	frame:Show()
end

BugSackClipboard.InstallCopyButton = function(self)
	local window = _G.BugSackFrame
	local prevButton = _G.BugSackPrevButton
	local nextButton = _G.BugSackNextButton
	if (not window or not prevButton or not nextButton) then
		return
	end

	local button = window.__AzeriteUI_BugSackCopyButton
	if (not button) then
		button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		button:SetSize(170, 40)
		button:SetFrameStrata("FULLSCREEN")
		button:SetText(GetSessionCopyLabel())
		button:SetScript("OnClick", function()
			self:ShowCopyWindow()
		end)

		local sendButton = _G.BugSackSendButton
		if (sendButton) then
			sendButton:ClearAllPoints()
			sendButton:SetPoint("BOTTOM", window, "BOTTOM", -87, 16)
			sendButton:SetWidth(170)
			button:SetPoint("LEFT", sendButton, "RIGHT", 4, 0)
		else
			button:SetPoint("BOTTOM", window, "BOTTOM", 0, 16)
		end

		window.__AzeriteUI_BugSackCopyButton = button
		self.CopyButton = button
	end

	self:UpdateCopyButton()
end

BugSackClipboard.OnBugSackOpen = function(self)
	self:InstallCopyButton()
end

BugSackClipboard.HookBugSack = function(self)
	local bugSack = _G.BugSack
	if (type(bugSack) ~= "table" or type(bugSack.OpenSack) ~= "function") then
		return
	end

	if (not self:IsHooked(bugSack, "OpenSack")) then
		self:SecureHook(bugSack, "OpenSack", "OnBugSackOpen")
	end

	if (_G.BugSackFrame) then
		self:InstallCopyButton()
	end
end

BugSackClipboard.OnEvent = function(self, event, addonName)
	if (event == "ADDON_LOADED" and addonName == "BugSack") then
		self:HookBugSack()
		self:UnregisterEvent("ADDON_LOADED")
	end
end

BugSackClipboard.OnInitialize = function(self)
	if (IsAddOnLoaded("BugSack")) then
		self:HookBugSack()
	else
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
end

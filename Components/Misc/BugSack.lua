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
local Addon, ns = ...

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

local function GetSessionSnapshot(sessionId, label)
	local bugSack = _G.BugSack
	local bugGrabber = _G.BugGrabber
	if (type(bugSack) ~= "table"
		or type(bugSack.GetErrors) ~= "function"
		or type(bugSack.FormatError) ~= "function"
		or type(bugGrabber) ~= "table"
		or type(bugGrabber.GetSessionId) ~= "function") then
		return "", 0, nil
	end


	local errors = sessionId and bugSack:GetErrors(sessionId) or bugSack:GetErrors()
	if (type(errors) ~= "table" or #errors == 0) then
		return label.."\nNo errors found.", 0, sessionId
	end

	local total = #errors
	local AZERITEUI_VERSION = C_AddOns.GetAddOnMetadata(Addon, "Version") or "unknown"
	local errorLines = {}
	for index, err in ipairs(errors) do
		errorLines[#errorLines + 1] = ""
		errorLines[#errorLines + 1] = string_rep("-", 72)
		errorLines[#errorLines + 1] = string_format("Error %d of %d", index, total)
		if type(err) == "table" then
			if err.session then errorLines[#errorLines + 1] = "    Session: "..tostring(err.session) end
			if err.time then errorLines[#errorLines + 1] = "    Time: "..tostring(err.time) end
			if err.source then errorLines[#errorLines + 1] = "    Source: "..tostring(err.source) end
			if err.index then errorLines[#errorLines + 1] = "    Index: "..tostring(err.index) end
		end
		local ok, formatted = pcall(bugSack.FormatError, bugSack, err)
		if ok and type(formatted) == "string" and formatted ~= "" then
			errorLines[#errorLines + 1] = StripColorMarkup(formatted)
		else
			if type(err) == "table" then
				local t = {}
				for k,v in pairs(err) do
					t[#t+1] = tostring(k).."="..tostring(v)
				end
				errorLines[#errorLines + 1] = "    [Unformatted error table] "..table_concat(t, ", ")
			else
				errorLines[#errorLines + 1] = "    [Unformatted error] "..tostring(err)
			end
		end
	end

	       local wowVersion, wowBuild, wowDate, tocVersion = GetBuildInfo()
	       local contextLines = {
		       string_rep("=", 80),
		       string_format("%s (%s)", label, sessionId or "all"),
		       string_format("Total Errors: %d", total),
		       string_format("AzeriteUI Version: %s", AZERITEUI_VERSION),
		       string_format("WoW Version: %s (Build %s, TOC %s, %s)", wowVersion or "?", wowBuild or "?", tocVersion or "?", wowDate or "?"),
		       string_format("Exported: %s", date("%Y-%m-%d %H:%M:%S")),
		       string_rep("=", 80),
		       "\nContext Info:",
		"  • Player: Level " .. (UnitLevel("player") or "?") .. ", Faction: " .. (UnitFactionGroup("player") or "?"),
		"  • Zone: " .. string_format("%s / %s", GetRealZoneText() or "?", GetSubZoneText() or "?"),
		"  • Instance: " .. (function() local inInstance, instType = IsInInstance(); if inInstance then local name, _, diff, _, _, _, id = GetInstanceInfo(); return string_format("%s (%s, %s, ID: %s)", name or "?", instType or "?", diff or "?", id or "?"); else return "None"; end end)(),
		"  • Group: " .. string_format("%s, Raid: %s, Size: %d", IsInGroup() and "Yes" or "No", IsInRaid() and "Yes" or "No", GetNumGroupMembers()),
		"  • Target: " .. ((UnitExists("target") and string_format("%s, Level %s %s", UnitName("target") or "?", UnitLevel("target") or "?", UnitClass("target") or "?")) or "None"),
		"  • Combat: " .. string_format("%s, Resting: %s, Dead: %s", UnitAffectingCombat("player") and "Yes" or "No", IsResting() and "Yes" or "No", UnitIsDeadOrGhost("player") and "Yes" or "No"),
		"  • UI: " .. string_format("Scale %.2f, Locale %s, Resolution %s", (tonumber(GetCVar("uiScale")) or 1), GetLocale(), (Display_DisplayModeDropDown and Display_DisplayModeDropDown.selectedValue) or (GetScreenWidth() .. "x" .. GetScreenHeight())),
		"\nAddOns:",
		"  • " .. (function() local t = {}; for i=1,GetNumAddOns() do if GetAddOnEnableState(nil,i)>0 then local n,v=GetAddOnInfo(i),GetAddOnMetadata(i,"Version"); t[#t+1]=n..(v and (" v"..v) or ""); end end return table_concat(t, ", "); end)(),
		"\nAzeriteUI Debug:",
		(function() local t = {}; if ns and ns.API then for k,v in pairs(ns.API) do if tostring(k):find("DEBUG") and v then t[#t+1]=k; end end end return #t>0 and ("  • "..table_concat(t, ", ")) or "  • None enabled"; end)(),
		"\nLast Spell Cast / Combat Log:",
		"  • "..((ns and ns.__AzeriteUI_LastSpellCast) and ("Last Spell: "..ns.__AzeriteUI_LastSpellCast) or "Last Spell: Unknown"),
		"  • "..((ns and ns.__AzeriteUI_LastCombatLog) and ("Combat Log: "..ns.__AzeriteUI_LastCombatLog) or "Combat Log: Unknown"),
		"\nLast UI Interaction:",
		"  • "..((ns and ns.__AzeriteUI_LastUIInteraction) and ns.__AzeriteUI_LastUIInteraction or "Unknown"),
		string_rep("=", 80),
	}

	   -- Discord-friendly: wrap in triple backticks with 'lua' for syntax highlighting
	   local export = '```lua\n' .. table_concat(errorLines, "\n") .. "\n" .. table_concat(contextLines, "\n") .. '\n```'
	   return export, total, sessionId
end

BugSackClipboard.UpdateCopyButton = function(self)
	local button = self.CopyButton
	if (not button) then
		return
	end
	button:Enable()
end

BugSackClipboard.CreateCopyWindow = function(self)
	local frame = self.CopyFrame
	if (frame) then
		return frame
	end

	frame = CreateFrame("Frame", "AzeriteUI_BugSackCopyFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(1100, 600)
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
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 70)

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	editBox:SetAutoFocus(false)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetTextInsets(6, 6, 6, 6)
	editBox:SetWidth(1000)
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

BugSackClipboard.ShowCopyWindow = function(self, mode)
	local sessionId = _G.BugGrabber and _G.BugGrabber.GetSessionId and _G.BugGrabber:GetSessionId() or nil
	local text, total
	if mode == "all" then
		text, total = GetSessionSnapshot(nil, "BugSack All Errors")
	else
		text, total = GetSessionSnapshot(sessionId, "BugSack Current Session")
	end
	if (text == "" or not text) then
		text = "No bugs found, try again later :)"
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


	-- Copy Session Button
	local button = window.__AzeriteUI_BugSackCopyButton
	if (not button) then
		button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		button:SetSize(110, 26)
		button:SetFrameStrata("FULLSCREEN")
		button:SetText("Copy Session")
		button:SetScript("OnClick", function()
			self:ShowCopyWindow("session")
		end)

		local sendButton = _G.BugSackSendButton
		if (sendButton) then
			sendButton:ClearAllPoints()
			sendButton:SetPoint("BOTTOM", window, "BOTTOM", -90, 16)
			sendButton:SetWidth(100)
			button:SetPoint("LEFT", sendButton, "RIGHT", 6, 0)
		else
			button:SetPoint("BOTTOM", window, "BOTTOM", -60, 16)
		end

		window.__AzeriteUI_BugSackCopyButton = button
		self.CopyButton = button
	end

	-- Copy All Button
	local buttonAll = window.__AzeriteUI_BugSackCopyAllButton
	if (not buttonAll) then
		buttonAll = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		buttonAll:SetSize(110, 26)
		buttonAll:SetFrameStrata("FULLSCREEN")
		buttonAll:SetText("Copy All")
		buttonAll:SetScript("OnClick", function()
			self:ShowCopyWindow("all")
		end)
		if (button) then
			buttonAll:SetPoint("LEFT", button, "RIGHT", 6, 0)
		else
			buttonAll:SetPoint("BOTTOM", window, "BOTTOM", 60, 16)
		end
		window.__AzeriteUI_BugSackCopyAllButton = buttonAll
		self.CopyAllButton = buttonAll
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

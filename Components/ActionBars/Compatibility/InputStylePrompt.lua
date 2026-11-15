local addonName, ns = ...

-- A private, unprotected confirmation surface. Do not put this into Blizzard's
-- popup/input stacks or capture keyboard/gamepad input: only a real mouse click
-- on Yes calls the controller's accept function, in that same hardware callback.
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Prompt = {}
ns.InputStylePrompt = Prompt

local frame, accept, decline, target, shownAt

local function InCombat()
	return type(InCombatLockdown) ~= "function" or InCombatLockdown()
end

local function CreateButton(parent, text, x)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(144, 32)
	button:SetPoint("BOTTOM", parent, "BOTTOM", x, 18)
	button:RegisterForClicks("LeftButtonUp")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(.12, .12, .13, 1)
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(.75, .62, .36, .2)
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetTextColor(.94, .85, .65)
	label:SetText(text)
	return button
end

local function CreatePrompt()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(480, 234)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()
	local edge = frame:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints()
	edge:SetColorTexture(.48, .40, .25, .95)
	local background = frame:CreateTexture(nil, "BORDER")
	background:SetPoint("TOPLEFT", 1, -1)
	background:SetPoint("BOTTOMRIGHT", -1, 1)
	background:SetColorTexture(.035, .035, .045, .97)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -20)
	title:SetTextColor(.94, .85, .65)
	title:SetText("AzeriteUI")
	frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.message:SetPoint("TOP", 0, -53)
	frame.message:SetWidth(424)
	frame.message:SetJustifyH("CENTER")
	frame.message:SetTextColor(.92, .91, .87)
	frame.error = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.error:SetPoint("TOP", frame.message, "BOTTOM", 0, -12)
	frame.error:SetWidth(424)
	frame.error:SetJustifyH("CENTER")
	frame.error:SetTextColor(1, .56, .45)
	frame.yes = CreateButton(frame, _G.YES or "Yes", -80)
	frame.no = CreateButton(frame, _G.NO or "No", 80)
	frame.yes:SetScript("OnClick", function()
		-- Ignore an already-held click released immediately as the prompt opens.
		-- Never defer acceptance: a timer would lose the hardware input context.
		if (InCombat() or not frame:IsShown() or GetTime() - shownAt < .3) then return end
		local callback = accept
		if (callback) then callback() end
	end)
	frame.no:SetScript("OnClick", function()
		local callback = decline
		Prompt.Hide()
		if (callback) then callback() end
	end)
end

Prompt.Show = function(style, onAccept, onDecline, errorText)
	if (not ns.IsForever or InCombat() or (style ~= "gamepad" and style ~= "mnk")
		or type(onAccept) ~= "function" or type(onDecline) ~= "function") then return false end
	if (not frame) then CreatePrompt() end
	if (not frame:IsShown() or target ~= style) then shownAt = GetTime() end
	target, accept, decline = style, onAccept, onDecline
	frame.message:SetText(style == "gamepad"
		and L["Switch to Blizzard controller bars? The interface will reload. Other AzeriteUI elements stay active."]
		or L["Return to AzeriteUI action bars for keyboard/mouse? The interface will reload. Your saved bar settings will be restored."])
	if (errorText == "write") then
		errorText = L["The style change was not confirmed. No automatic retry will occur."]
	elseif (errorText == "reload") then
		errorText = L["Your selection will take effect after /reload outside combat."]
	end
	frame.error:SetText(type(errorText) == "string" and errorText or "")
	frame:Show()
	return true
end

Prompt.Hide = function()
	accept, decline, target, shownAt = nil, nil, nil, nil
	if (frame) then frame:Hide() end
end

Prompt.IsShown = function()
	return frame ~= nil and frame:IsShown() or false
end

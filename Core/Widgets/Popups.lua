--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

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
local API = ns.API
local Widgets = ns.Private.Widgets or {}
ns.Private.Widgets = Widgets

-- Only addon confirmations belong here. Never replace Blizzard's popup globals.
-- Forever's native popup focus/binding machinery must not consume our decisions.
API.PopupDialogs = {}
local requests, frames = {}, {}
local serial = 0
local intents = {}
local RefreshGamepadBindings

local function Select(frame, direction)
	local visible = {}
	for i = 1, 4 do
		if frame.request.definition["button" .. i] then visible[#visible + 1] = i end
	end
	if #visible == 0 then return end
	local position = 1
	for i, index in ipairs(visible) do if index == frame.selected then position = i end end
	frame.selected = visible[(position - 1 + direction) % #visible + 1]
	for index, button in ipairs(frame.buttons) do
		local chosen = index == frame.selected
		button:SetBackdropBorderColor(chosen and 1 or .4, chosen and .75 or .4, chosen and .2 or .4, 1)
	end
end

local function Remove(request)
	for i = #requests, 1, -1 do
		if requests[i] == request then table.remove(requests, i); break end
	end
	if request.frame then
		request.frame.request = nil
		request.frame:Hide()
	end
	RefreshGamepadBindings()
end

local function Cancel(request, reason)
	Remove(request)
	local callback = request.definition.OnCancel
	if callback then callback(request.frame, request.data, reason) end
end

local function Choose(frame, index)
	local request = frame.request
	if not request or requests[#requests] ~= request or not frame:IsVisible() or InCombatLockdown() then return end
	local definition = request.definition
	if not definition["button" .. index] then return end
	local callback
	if definition.selectCallbackByIndex then
		callback = definition["OnButton" .. index]
	else
		if index == 1 then callback = definition.OnAccept
		elseif index == 2 then callback = definition.OnCancel
		else callback = definition.OnAlt end
	end
	-- Retire the old decision before calling addon code. A callback can reopen
	-- the same key, throw, or change the roster without leaving a stale approval.
	Remove(request)
	if callback then callback(frame, request.data, "clicked") end
end

local function Newest(frame)
	local request = requests[#requests]
	return request and request.frame == frame and frame:IsVisible()
end

-- Raw OnGamePadButtonDown notifications still allow the bound gameplay action.
-- Route dialog keys through an independent owner, never Blizzard's binding stack
-- or UIParent's overrides. The restricted driver releases our keys in combat.
local bindingOwner, bindingButton
local pressed = {}
local consolePortData
local refreshQueued
local function ScheduleRefresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0, function() refreshQueued = nil; RefreshGamepadBindings() end)
end
local padKeys = { "PAD1", "PAD2", "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }
local modifiers = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local function RegisterConsolePort()
	local cp = _G.ConsolePort
	if not cp or type(cp.AddInterfaceCursorFrame) ~= "function" or type(cp.IsCursorActive) ~= "function" then return end
	for _, frame in ipairs(frames) do
		if frame.consolePort ~= cp then
			cp:AddInterfaceCursorFrame(frame)
			frame.consolePort = cp
		end
	end
	if type(cp.GetData) == "function" then
		local data = cp:GetData()
		if type(data) == "table" and type(data.RegisterCallback) == "function" and data ~= consolePortData then
			consolePortData = data
			data:RegisterCallback("OnCursorShow", ScheduleRefresh, Widgets)
			data:RegisterCallback("OnCursorHide", ScheduleRefresh, Widgets)
		end
	end
	return cp
end
RefreshGamepadBindings = function()
	if InCombatLockdown() then return end
	if not ns.IsForever then return end
	pressed = {}
	if bindingOwner then ClearOverrideBindings(bindingOwner) end
	local cp = RegisterConsolePort()
	local request = requests[#requests]
	for _, frame in ipairs(frames) do
		frame.blocker:SetShown(Newest(frame) and true or false)
	end
	-- ConsolePort's active cursor deliberately owns its UI keys. Its public
	-- cursor stack handles our ordinary buttons; do not compete with its claims.
	if cp and cp:IsCursorActive() then
		if request and request.frame and Newest(request.frame) and type(cp.SetCursorNodeIfActive) == "function" then
			local target = request.frame.buttons[request.frame.selected]
			if target then cp:SetCursorNodeIfActive(target, true) end
		end
		return
	end
	if not request or not request.frame or not request.frame:IsVisible() then return end
	if not bindingOwner then
		-- Missing support leaves the mouse and Escape routes available.
		if type(SetOverrideBindingClick) ~= "function" or type(ClearOverrideBindings) ~= "function"
			or type(RegisterStateDriver) ~= "function" then return end
		bindingOwner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
		bindingOwner:SetAttribute("_onstate-combat", [[
			if newstate == "combat" then self:ClearBindings() end
		]])
		RegisterStateDriver(bindingOwner, "combat", "[combat] combat; safe")
		bindingButton = CreateFrame("Button", Addon .. "PopupGamepadInput", UIParent)
		bindingButton:RegisterForClicks("AnyDown", "AnyUp")
		bindingButton:SetScript("OnClick", function(_, key, down)
			local current = requests[#requests]
			if down then
				if current and current.frame and Newest(current.frame) and not InCombatLockdown() then
					pressed[key] = current
				end
				return
			end
			local began = pressed[key]
			pressed[key] = nil
			if not began or began ~= current or not current.frame or not Newest(current.frame)
				or InCombatLockdown() then return end
			local frame = current.frame
			if key == "PAD2" and current.definition.hideOnEscape then Cancel(current, "escape")
			elseif key == "PAD1" then Choose(frame, frame.selected)
			elseif key == "PADDUP" or key == "PADDLEFT" then Select(frame, -1)
			elseif key == "PADDDOWN" or key == "PADDRIGHT" then Select(frame, 1) end
		end)
	end
	for _, modifier in ipairs(modifiers) do
		for _, key in ipairs(padKeys) do
			SetOverrideBindingClick(bindingOwner, true, modifier .. key, Addon .. "PopupGamepadInput", key)
		end
	end
end

local function CreatePopup()
	if InCombatLockdown() then return end
	local frame = CreateFrame("Frame", Addon .. "Popup" .. (#frames + 1), UIParent, ns.BackdropTemplate)
	frame:Hide()
	frame:SetSize(440, 180)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(100)
	frame:EnableMouse(true)
	frame:SetAttribute("nodepass", true)
	local blocker = CreateFrame("Frame", nil, frame)
	blocker:SetAllPoints(UIParent)
	blocker:EnableMouse(true)
	blocker:EnableMouseMotion(false)
	blocker:Hide()
	frame.blocker = blocker
	frame:SetBackdrop({ bgFile = API.GetMedia("plain"), edgeFile = API.GetMedia("border-tooltip"),
		edgeSize = 24, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
	frame:SetBackdropColor(.03, .03, .03, .98)
	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(API.GetFont(14, true))
	title:SetPoint("TOP", 0, -20)
	title:SetText("AzeriteUI")
	frame.Text = frame:CreateFontString(nil, "OVERLAY")
	frame.Text:SetFontObject(API.GetFont(13, true))
	frame.Text:SetPoint("TOP", 0, -48)
	frame.Text:SetWidth(388)
	frame.buttons = {}
	for index = 1, 4 do
		local button = CreateFrame("Button", nil, frame, ns.BackdropTemplate)
		button:SetSize(196, 30)
		button:SetBackdrop({ bgFile = API.GetMedia("plain"), edgeFile = API.GetMedia("border-aura"),
			edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		button:SetBackdropColor(.12, .12, .12, 1)
		local text = button:CreateFontString(nil, "OVERLAY")
		text:SetFontObject(API.GetFont(13, true))
		text:SetAllPoints()
		button.Text = text
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetScript("OnMouseDown", function(self)
			self.pressedRequest = Newest(frame) and frame.request or nil
		end)
		button:SetScript("OnClick", function() Choose(frame, index) end)
		-- ConsolePort's documented custom cancel hook applies to the focused node.
		button.OnCancelClick = function()
			if Newest(frame) and not InCombatLockdown() and frame.request.definition.hideOnEscape then
				Cancel(frame.request, "escape")
			end
		end
		frame.buttons[index] = button
	end
	frame:EnableKeyboard(true)
	frame:SetPropagateKeyboardInput(true)
	frame:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown() then return end
		local consume = Newest(self) and key == "ESCAPE" and self.request.definition.hideOnEscape
		self:SetPropagateKeyboardInput(not consume)
		if consume then Cancel(self.request, "escape") end
	end)
	frame:SetScript("OnShow", RefreshGamepadBindings)
	frame:SetScript("OnHide", function()
		for _, button in ipairs(frame.buttons) do button.pressedRequest = nil end
		RefreshGamepadBindings()
	end)
	return frame
end

local function Display(request)
	if InCombatLockdown() then return end
	local frame
	for _, candidate in ipairs(frames) do
		if not candidate.request then frame = candidate; break end
	end
	if not frame then frame = CreatePopup(); frames[#frames + 1] = frame end
	frame.request, request.frame = request, frame
	frame:SetPropagateKeyboardInput(true)
	frame.Text:SetText(request.text)
	local count = 0
	for index, button in ipairs(frame.buttons) do
		button.pressedRequest = nil
		local label = request.definition["button" .. index]
		button:SetShown(label ~= nil)
		if label then
			count = count + 1
			button.Text:SetText(label)
			button:SetScript("OnClick", function(self, mouseButton)
				local began = self and self.pressedRequest
				if self then self.pressedRequest = nil end
				if frame.consolePort and began ~= request then return end
				if mouseButton == "RightButton" then return button.OnCancelClick() end
				if frame.request == request then Choose(frame, index) end
			end)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + ((count - 1) % 2) * 200,
				-70 - frame.Text:GetStringHeight() - math.floor((count - 1) / 2) * 34)
		end
	end
	frame:SetHeight(94 + frame.Text:GetStringHeight() + math.ceil(count / 2) * 34)
	for index, pending in ipairs(requests) do
		if pending.frame then
			local level = 100 + index * 10
			pending.frame:SetFrameLevel(level)
			pending.frame.blocker:SetFrameLevel(level + 1)
			for _, button in ipairs(pending.frame.buttons) do button:SetFrameLevel(level + 2) end
		end
	end
	frame.selected = 1
	Select(frame, 0)
	frame:Show()
	RefreshGamepadBindings()
	return frame
end

API.ShowPopup = function(key, text1, text2, data)
	local definition = API.PopupDialogs[key]
	if not definition then return end
	if not ns.IsForever then
		if not StaticPopupDialogs or not StaticPopup_Show then return end
		StaticPopupDialogs[key] = definition
		return StaticPopup_Show(key, text1, text2, data)
	end
	-- This deliberately implements our confirmation subset, not StaticPopup's
	-- item/editbox/timeout system. Unsupported definitions fail closed.
	if definition.hasEditBox or (definition.timeout and definition.timeout ~= 0) then return end
	local snapshot = {}
	for k, v in pairs(definition) do snapshot[k] = v end
	local text = snapshot.text or ""
	if text1 ~= nil then text = string.format(text, text1, text2) end
	serial = serial + 1
	local intent = serial
	intents[key] = intent
	for i = #requests, 1, -1 do
		if requests[i].key == key then Cancel(requests[i], "override") end
	end
	if intents[key] ~= intent then return end -- cancellation reopened this key
	if #requests >= 4 then return end
	local request = { key = key, definition = snapshot, text = text, data = data }
	requests[#requests + 1] = request
	if InCombatLockdown() then return request end -- queued, never auto-accepted
	return Display(request)
end

API.HidePopup = function(key)
	if not ns.IsForever then
		if StaticPopup_Hide then StaticPopup_Hide(key) end
		return
	end
	for i = #requests, 1, -1 do
		if requests[i].key == key then Cancel(requests[i], "override") end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, addon)
	if event == "PLAYER_REGEN_DISABLED" then
		for _, frame in ipairs(frames) do frame.blocker:Hide() end
		return
	end
	if event == "ADDON_LOADED" and addon ~= "ConsolePort" and addon ~= "ConsolePort_Cursor" then return end
	if InCombatLockdown() then return end
	for _, request in ipairs(requests) do
		if not request.frame then Display(request) end
	end
	RefreshGamepadBindings()
end)

Widgets.RegisterPopup = function(key, definition) API.PopupDialogs[key] = definition end
Widgets.ShowPopup = API.ShowPopup
Widgets.HidePopup = API.HidePopup

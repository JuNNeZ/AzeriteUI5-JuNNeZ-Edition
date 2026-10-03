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
local _, ns = ...
if (not ns.API.IsAddOnEnabled("ConsolePort")) then return end

if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return end

local ConsolePort = ns:NewModule("ConsolePort", "LibMoreEvents-1.0", "AceHook-3.0")

-- Lua API
local pcall = pcall
local select = select
local string_format = string.format
local type = type

-- WoW API
local GetBindingKey = _G.GetBindingKey

-- The first gamepad key among a binding's keys, split the way ConsolePort's own
-- GamepadAPI:GetBindings does: "SHIFT-PAD1" -> "PAD1", "SHIFT-".
local FindPadKey = function(...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if (type(key) == "string") then
			local btnID = key:match("([^%-]+)$")
			if (btnID and btnID:find("^PAD")) then
				return btnID, key:sub(1, #key - #btnID)
			end
		end
	end
end

local GetButtonPadKey = function(button)
	local btnID, modID
	if (button.keyBoundTarget) then
		btnID, modID = FindPadKey(GetBindingKey(button.keyBoundTarget))
	end
	if (not btnID) then
		local clickButton = button.config and button.config.keyBoundClickButton or "LeftButton"
		btnID, modID = FindPadKey(GetBindingKey(string_format("CLICK %s:%s", button:GetName(), clickButton)))
	end
	return btnID, modID
end

-- LibActionButton shows the text hotkey again on every config or binding refresh.
-- Keep it hidden while one of ConsolePort's icon widgets sits on the button.
local Button_PostKeybind = function(_, button)
	if (button.__AzeriteUI_ConsolePortHotkey and button.HotKey) then
		button.HotKey:Hide()
	end
end

-- ConsolePort finds action buttons by walking every frame below UIParent, and on
-- WoW 12 the walk stops at any frame with access constraints
-- (CPAPI.IsObjectRestricted), skipping everything under it. Buttons it never
-- reaches keep LibActionButton's text hotkey ("PAD1" shortened to text) instead of
-- the gamepad icons. Give those buttons ConsolePort's own widget here.
ConsolePort.DrawMissingHotkeys = function(_, HotkeyHandler, device, ActionBars)
	if (not device or type(HotkeyHandler.GetWidget) ~= "function" or type(HotkeyHandler.GetHotkeyData) ~= "function") then return end

	-- Respect ConsolePort's own switch to draw no icons at all.
	local db = _G.ConsolePort and _G.ConsolePort.GetData and _G.ConsolePort:GetData()
	if (type(db) == "table") then
		local ok, disabled = pcall(db, "disableHotkeyRendering")
		if (ok and disabled) then return end
	end

	local drawn = {}
	for widget in HotkeyHandler.Widgets:EnumerateActive() do
		local owner = widget:GetParent()
		if (owner) then
			drawn[owner] = true
		end
	end

	for button in next, ActionBars.buttons do
		button.__AzeriteUI_ConsolePortHotkey = nil
		if (not button.postKeybind) then
			button.postKeybind = Button_PostKeybind
		end
		if (drawn[button]) then
			button.__AzeriteUI_ConsolePortHotkey = true
		else
			local btnID, modID = GetButtonPadKey(button)
			if (btnID) then
				local ok, data = pcall(HotkeyHandler.GetHotkeyData, HotkeyHandler, device, btnID, modID, 32, 32)
				if (ok and data) then
					local widget = HotkeyHandler:GetWidget()
					if (pcall(widget.SetData, widget, data, button)) then
						button.__AzeriteUI_ConsolePortHotkey = true
					else
						HotkeyHandler.Widgets:Release(widget)
					end
				end
			end
		end
	end
end

ConsolePort.UpdateHotkeys = function(self, HotkeyHandler, device)
	HotkeyHandler = HotkeyHandler or _G.ConsolePortHotkeyHandler
	if (not HotkeyHandler) then return end

	local ActionBars = ns:GetModule("ActionBars", true)
	if (not ActionBars or not ActionBars:IsEnabled() or not ActionBars.buttons) then return end

	self:DrawMissingHotkeys(HotkeyHandler, device, ActionBars)

	for widget in HotkeyHandler.Widgets:EnumerateActive() do
		local owner = widget:GetParent()
		if (ActionBars.buttons[owner]) then
			widget:SetFrameLevel(owner:GetFrameLevel() + 10)
			widget:SetScale(1.25)
		end
	end

end

ConsolePort.HandleHotkeys = function(self)
	local HotkeyHandler = _G.ConsolePortHotkeyHandler
	if (not HotkeyHandler) then return end

	self:SecureHook(HotkeyHandler, "UpdateHotkeys")
end

ConsolePort.HandleConsolePort = function(self, event, addon)
	if (not _G.IsAddOnLoaded("ConsolePort")) then
		return self:RegisterEvent("ADDON_LOADED", "HandleConsolePort")
	elseif (event == "ADDON_LOADED") then
		if (addon ~= "ConsolePort") then return end
		self:UnregisterEvent("ADDON_LOADED", "HandleConsolePort")
	end

	if (_G.InCombatLockdown()) then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "HandleConsolePort")
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (_G.InCombatLockdown()) then return end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "HandleConsolePort")
	end

	self:HandleHotkeys()

	ns.ConsolePortHandled = true

	ns:Fire("ConsolePort_Handled")
end

ConsolePort.OnInitialize = function(self)
	if (not ns.API.IsAddOnEnabled("ConsolePort")) then return self:Disable() end
	if (ns.API.IsAddOnEnabled("ConsolePort_Bar")) then return self:Disable() end

	self:HandleConsolePort()
end

--[[

	The MIT License (MIT)

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

--[[
	The debug tools live in a companion addon, AzeriteUI5_JuNNeZ_Edition_Debug, marked
	LoadOnDemand: /azdebug, its probes and the test menus are a fifth of a megabyte of
	Lua that nearly no player ever runs. This file is what stays loaded for everyone.

	It does what the debug module used to do at load for every player: apply the saved
	debug switches the rest of the addon reads (ns.API.DEBUG_* and the
	__AzeriteUI_DEBUG_* globals), switch the unit test mode off, and keep script errors
	on. And it answers the debug slash commands: the first use loads the companion,
	whose module registers the same commands over these and takes the input from there.
]]

local COMPANION = "AzeriteUI5_JuNNeZ_Edition_Debug"
local DebugLoader = ns:NewModule("DebugLoader", "LibMoreEvents-1.0", "AceConsole-3.0")

-- Slash command -> the debug module's handler for it.
local COMMANDS = {
	azdebug = "DebugMenu",
	azdebugkeys = "DebugKeysMenu",
	azdebugtarget = "TargetDebugMenu",
	aztest = "TestModeCommand",
	junnez = "SecretJuNNeZCommand",
	goldpaw = "SecretGoldpawCommand"
}
DebugLoader.Commands = COMMANDS

local GetDebugModule = function()
	return ns:GetModule("Debugging", true)
end

--- Loads the debug companion if it is not loaded yet.
--- Returns the Debugging module, or nil and the reason the client gave.
ns.LoadDebugTools = function()
	local debug = GetDebugModule()
	if (debug) then return debug end
	local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if (type(load) ~= "function") then return nil, "NO_LOADER" end
	local ok, loaded, reason = pcall(load, COMPANION)
	if (not ok) then return nil, tostring(loaded) end
	if (not loaded) then return nil, reason end
	return GetDebugModule()
end

-- The reasons the client gives, in words.
local REASONS = {
	MISSING = "it is not installed",
	DISABLED = "it is disabled in the AddOns list",
	DEMAND_LOADED = "it could not be loaded on demand"
}

DebugLoader.Dispatch = function(self, command, input)
	local debug, reason = ns.LoadDebugTools()
	local method = debug and debug[COMMANDS[command]]
	if (type(method) ~= "function") then
		print("|cff33ff99AzeriteUI:|r", string.format("the debug tools (%s) are not available: %s.",
			COMPANION, REASONS[reason] or tostring(reason or "unknown reason")))
		return
	end
	return method(debug, input)
end

-- The saved switches other files read while running. Kept here so a /reload with a
-- switch on keeps it on, without loading the companion.
DebugLoader.ApplySavedSwitches = function(self)
	local global = ns.db and ns.db.global
	if (not global) then return end
	-- Test mode never survives a reload; Arena.lua and Raid5.lua read this.
	global.runtimeUnitTestMode = false
	if (not global.debugHealthFilter or global.debugHealthFilter == "") then
		global.debugHealthFilter = "Target."
	end
	local API = ns.API
	API.DEBUG_HEALTH = global.debugHealth or false
	API.DEBUG_HEALTH_CHAT = global.debugHealthChat or false
	API.DEBUG_HEALTH_FILTER = global.debugHealthFilter
	API.DEBUG_HEALTH_PCT = global.debugHealthPercent or false
	API.DEBUG_AURAS = global.debugAuras or false
	API.DEBUG_AURA_FILTER = global.debugAurasFilter or ""
	API.DEBUG_ACTIONBARS = global.debugActionbars or false
	API.DEBUG_ACTIONBARS_FILTER = global.debugActionbarsFilter or ""
	API.DEBUG_CASTBAR = global.debugCastbar or false
	API.DEBUG_POWER = global.debugPower or false
	API.DEBUG_POWER_FILTER = global.debugPowerFilter or ""
	_G.__AzeriteUI_DEBUG_BARS = global.debugBars or false
	_G.__AzeriteUI_DEBUG_HEALTH_PCT = global.debugHealthPercent or false
	_G.__AzeriteUI_DEBUG_AURAS = global.debugAuras or false
	_G.__AzeriteUI_DEBUG_AURA_FILTER = global.debugAurasFilter or ""
	_G.__AzeriteUI_DEBUG_ACTIONBARS = global.debugActionbars or false
	_G.__AzeriteUI_DEBUG_ACTIONBARS_FILTER = global.debugActionbarsFilter or ""
	_G.__AzeriteUI_DEBUG_CASTBAR = global.debugCastbar or false
	_G.__AzeriteUI_DEBUG_POWER = global.debugPower or false
	_G.__AzeriteUI_DEBUG_POWER_FILTER = global.debugPowerFilter or ""
	_G.__AzeriteUI_DEBUG_KEYS = global.debugKeysVerbose or false
end

-- As the debug module always did: the edition ships with Lua errors shown.
DebugLoader.EnableScriptErrors = function(self)
	if (C_CVar and C_CVar.SetCVar) then
		return C_CVar.SetCVar("scriptErrors", "1")
	end
	SetCVar("scriptErrors", "1")
end

DebugLoader.OnEvent = function(self, event)
	self:EnableScriptErrors()
end

DebugLoader.OnInitialize = function(self)
	for command in pairs(COMMANDS) do
		self:RegisterChatCommand(command, function(input) return self:Dispatch(command, input) end)
	end
	self:ApplySavedSwitches()
	if (ns.WoW10) then
		self:RegisterEvent("SETTINGS_LOADED", "OnEvent")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:EnableScriptErrors()
end

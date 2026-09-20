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
local API = ns.API or {}
ns.API = API

-- Lua API
local type = type

-- GLOBALS: InCombatLockdown, RegisterStateDriver, UnregisterStateDriver

-- Visibility drivers on clients with no restricted execution.
---------------------------------------------------------
-- A bar or container that hides itself on a macro conditional normally does it
-- through a custom state - `RegisterStateDriver(frame, "vis", ...)` plus an
-- `_onstate-vis` snippet - because the snippet can also weigh addon state such as
-- `userhidden` before deciding.
--
-- Blizzard's SecureStateDriver.lua treats exactly one state specially. In
-- `resolveDriver`, `state-visibility` is not written as an attribute at all: it calls
-- `frame:Show()` / `frame:Hide()` and sets `statehidden` directly, from Blizzard's own
-- untainted code. That means it needs no snippet, and it still works on a protected
-- frame **during combat** - which is the one thing an insecure fallback cannot do.
--
-- So where restricted execution is unavailable, every show/hide snippet in this addon
-- is expressed as a driver string instead and handed to the native state. Anything the
-- snippet used to decide has to be folded into that string by the caller, which is why
-- `driver` is passed in already resolved.
--
-- Registering a driver is itself only legal out of combat, since Blizzard's manager
-- reads the frame reference through a protected attribute write.

local HasSecureSnippets = function()
	return ns.HasSecureSnippets ~= false
end

-- Drive a frame's visibility through Blizzard's native `state-visibility`.
-- Returns true when the driver was applied.
local RegisterVisibilityDriver = function(frame, driver)
	if (not frame) then return false end
	if (InCombatLockdown()) then return false end
	if (type(RegisterStateDriver) ~= "function") then return false end

	UnregisterStateDriver(frame, "visibility")
	RegisterStateDriver(frame, "visibility", driver or "hide")

	return true
end

local UnregisterVisibilityDriver = function(frame)
	if (not frame) then return false end
	if (InCombatLockdown()) then return false end
	if (type(UnregisterStateDriver) ~= "function") then return false end

	UnregisterStateDriver(frame, "visibility")

	return true
end

-- Global API
---------------------------------------------------------
API.HasSecureSnippets = HasSecureSnippets
API.RegisterVisibilityDriver = RegisterVisibilityDriver
API.UnregisterVisibilityDriver = UnregisterVisibilityDriver

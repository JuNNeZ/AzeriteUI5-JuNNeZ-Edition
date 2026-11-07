-- Quick Keybind Mode bridge harness.
--
-- Loads the real Libs/LibKeyBound-1.0 and the Quick Keybind functions from
-- Components/ActionBars/Elements/ActionBars.lua (the text between
-- "local QUICKBIND_BINDER_STRATA" and "ActionBarMod.OnEnable"), against a stub
-- QuickKeybindFrame, and checks that opening Blizzard's mode turns on LibKeyBound
-- without its dialog, that a key pressed over one of our buttons binds its
-- keyBoundTarget, and that closing the mode puts everything back.
--
-- What it cannot cover: real keyboard dispatch order between the binder and
-- Blizzard's frame (that is why the binder's strata is raised; the check only
-- proves the strata is set), taint, and rendering. Those are live checks.
--
-- Usage: lua.exe Tools/Harness/quickkeybind_harness.lua [addon root]

local root = (arg and arg[1]) or "."

local passed, failed = 0, 0
local function check(ok, label)
	if (ok) then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

----------------------------------------------------------------
-- Stubs
----------------------------------------------------------------
local combat = false
function InCombatLockdown() return combat end
function IsLoggedIn() return true end
function PlaySound() end
function GetBuildInfo() return "12.1.5", "1", "d", 120105 end
function GetScreenWidth() return 1920 end
function GetBindingText(key) return tostring(key) end
function IsModifierKeyDown() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetCurrentBindingSet() return 1 end
function SaveBindings() end
function LoadBindings() end
function format(...) return string.format(...) end
getglobal = function(name) return _G[name] end
SOUNDKIT = {}
UIERRORS_HOLD_TIME = 1
LibKeyBoundLocale10 = setmetatable({}, { __index = function(_, k) return k end })
SlashCmdList = {}

local bindings = {}       -- key -> action
function SetBinding(key, action)
	if (key) then bindings[key] = action end
	return true
end
function GetBindingKey(action)
	local keys = {}
	for key, a in pairs(bindings) do
		if (a == action) then keys[#keys + 1] = key end
	end
	table.sort(keys)
	return unpack(keys)
end
function GetBindingAction(key) return bindings[key] or "" end

local frameMethods = {}
frameMethods.__index = frameMethods
function frameMethods:SetScript(name, fn) self.scripts[name] = fn end
function frameMethods:GetScript(name) return self.scripts[name] end
function frameMethods:HookScript(name, fn)
	self.hooks[name] = self.hooks[name] or {}
	table.insert(self.hooks[name], fn)
end
local function fire(self, name, ...)
	if (self.scripts[name]) then self.scripts[name](self, ...) end
	for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end
end
function frameMethods:Show()
	if (self.shown) then return end
	self.shown = true
	fire(self, "OnShow")
end
function frameMethods:Hide()
	if (not self.shown) then return end
	self.shown = false
	fire(self, "OnHide")
end
function frameMethods:IsShown() return self.shown end
function frameMethods:GetName() return self.name end
function frameMethods:SetFrameStrata(s) self.strata = s end
function frameMethods:GetFrameStrata() return self.strata end
function frameMethods:GetRight() return 100 end
function frameMethods:GetWidth() return 40 end
function frameMethods:IsMouseOver() return true end
function frameMethods:CreateTexture() return setmetatable({}, { __index = function() return function() end end }) end
function frameMethods:CreateFontString()
	local fs = { text = nil }
	return setmetatable(fs, { __index = function(_, k)
		if (k == "SetText") then return function(self, t) self.text = t end end
		if (k == "GetStringWidth") then return function() return 10 end end
		return function() end
	end })
end
-- Everything else a frame is asked to do here is cosmetic.
setmetatable(frameMethods, { __index = function() return function() end end })

function CreateFrame(frameType, name)
	local f = setmetatable({ scripts = {}, hooks = {}, shown = true, strata = "MEDIUM", frameType = frameType, name = name }, frameMethods)
	if (name) then _G[name] = f end
	-- LibKeyBound reads <name>Text off its template buttons.
	if (name) then _G[name .. "Text"] = f:CreateFontString() end
	return f
end
GameTooltip = CreateFrame("GameTooltip")
UIErrorsFrame = CreateFrame("Frame")

-- LibStub + a minimal CallbackHandler that records fired events.
local libs = {}
local fired = {}
LibStub = setmetatable({
	NewLibrary = function(_, major) libs[major] = libs[major] or {}; return libs[major], nil end,
}, { __call = function(_, major, silent)
	if (major == "CallbackHandler-1.0") then
		return { New = function() return { Fire = function(_, event) fired[#fired + 1] = event end } end }
	end
	return libs[major]
end })

----------------------------------------------------------------
-- Load the real LibKeyBound and the bridge
----------------------------------------------------------------
assert(loadfile(root .. "/Libs/LibKeyBound-1.0/LibKeyBound-1.0.lua"))("LibKeyBound-1.0")
local KeyBound = LibStub("LibKeyBound-1.0")
check(KeyBound and KeyBound.initialized, "LibKeyBound initialized")
KeyBound.dialog.shown = false -- created hidden in the real file (f:Hide() on a new frame)
local dialogShows = 0
KeyBound.dialog:HookScript("OnShow", function() dialogShows = dialogShows + 1 end)

local fh = assert(io.open(root .. "/Components/ActionBars/Elements/ActionBars.lua", "rb"))
local source = fh:read("*a")
fh:close()
local first = source:find("local QUICKBIND_BINDER_STRATA", 1, true)
local last = source:find("ActionBarMod.OnEnable = function", 1, true)
assert(first and last, "bridge markers not found in ActionBars.lua")
local chunk = source:sub(first, last - 1)

local registered, unregistered = {}, {}
local ActionBarMod = {
	RegisterEvent = function(_, e, m) registered[e] = m end,
	UnregisterEvent = function(_, e, m) unregistered[e] = m end,
}
local env = setmetatable({ ActionBarMod = ActionBarMod }, { __index = _G })
local fn = assert(loadstring(chunk, "=ActionBars.lua bridge"))
setfenv(fn, env)
fn()

-- Blizzard's frame, not loaded yet.
check(ActionBarMod:HookQuickKeybindMode() == nil, "no hook without QuickKeybindFrame")
QuickKeybindFrame = CreateFrame("Button")
QuickKeybindFrame.shown = false
QuickKeybindFrame.strata = "DIALOG"
ActionBarMod:OnQuickKeybindAddOnLoaded("ADDON_LOADED", "Blizzard_Other")
check(not ActionBarMod.quickKeybindHooked, "other addons do not hook")
ActionBarMod:OnQuickKeybindAddOnLoaded("ADDON_LOADED", "Blizzard_QuickKeybind")
check(ActionBarMod.quickKeybindHooked, "hooked when Blizzard_QuickKeybind loads")
check(unregistered.ADDON_LOADED == "OnQuickKeybindAddOnLoaded", "ADDON_LOADED dropped after hooking")
check(ActionBarMod:HookQuickKeybindMode() == true, "second hook call is a no-op")
check(#QuickKeybindFrame.hooks.OnShow == 1, "OnShow hooked once")

-- A LibActionButton-like button bound through its Blizzard binding name.
local button = CreateFrame("CheckButton", "AzeriteActionBar1Button1")
button.config = { keyBoundTarget = "ACTIONBUTTON1" }
function button:GetHotkey() return GetBindingKey(self.config.keyBoundTarget) end
function button:SetKey(key) SetBinding(key, self.config.keyBoundTarget) end
function button:GetBindings() return GetBindingKey(self.config.keyBoundTarget) end
function button:ClearBindings()
	while GetBindingKey(self.config.keyBoundTarget) do
		SetBinding((GetBindingKey(self.config.keyBoundTarget)), nil)
	end
end

----------------------------------------------------------------
-- 1. Opening and closing Blizzard's mode
----------------------------------------------------------------
check(not KeyBound:IsShown(), "LibKeyBound off before the mode opens")
QuickKeybindFrame:Show()
check(KeyBound:IsShown(), "opening Quick Keybind turns LibKeyBound on")
check(dialogShows == 0 and not KeyBound.dialog:IsShown(), "LibKeyBound's dialog stays hidden")
check(fired[#fired] == "LIBKEYBOUND_ENABLED", "LIBKEYBOUND_ENABLED fired")
check(KeyBound.frame and KeyBound.frame:GetFrameStrata() == "FULLSCREEN_DIALOG", "binder lifted above Blizzard's DIALOG frame")

-- Hover (LAB Generic:OnEnter calls KeyBound:Set) and press F.
KeyBound:Set(button)
check(KeyBound.frame:IsShown() and KeyBound.frame.button == button, "binder covers the hovered button")
KeyBound.frame:GetScript("OnKeyDown")(KeyBound.frame, "F")
check(bindings.F == "ACTIONBUTTON1", "F bound to the button's Blizzard binding name")
KeyBound.frame:GetScript("OnKeyDown")(KeyBound.frame, "ESCAPE")
check(bindings.F == nil, "Escape clears the hovered button's bindings")
KeyBound.frame:GetScript("OnKeyDown")(KeyBound.frame, "G")

QuickKeybindFrame:Hide()
check(not KeyBound:IsShown(), "closing Quick Keybind turns LibKeyBound off")
check(fired[#fired] == "LIBKEYBOUND_DISABLED", "LIBKEYBOUND_DISABLED fired")
check(KeyBound.frame:GetFrameStrata() == "DIALOG", "binder strata restored")
check(not KeyBound.frame:IsShown(), "binder hidden")
check(bindings.G == "ACTIONBUTTON1", "binding kept for Blizzard's OK/Cancel to save or reload")
check(dialogShows == 0, "dialog never shown across the session")

----------------------------------------------------------------
-- 2. /kb already running: left alone
----------------------------------------------------------------
KeyBound:Activate()
check(KeyBound:IsShown() and dialogShows == 1, "/kb on with its dialog")
QuickKeybindFrame:Show()
check(not ActionBarMod.quickKeybindOwnsKeyBound, "bridge does not take over a running /kb")
check(KeyBound.frame:GetFrameStrata() == "DIALOG", "strata untouched for /kb")
QuickKeybindFrame:Hide()
check(KeyBound:IsShown(), "/kb still on after Quick Keybind closes")
KeyBound:Deactivate()

----------------------------------------------------------------
-- 3. Combat: nothing happens
----------------------------------------------------------------
combat = true
QuickKeybindFrame:Show()
check(not KeyBound:IsShown(), "no LibKeyBound in combat")
QuickKeybindFrame:Hide()
combat = false

----------------------------------------------------------------
-- 4. /kb toggled off while Quick Keybind is open
----------------------------------------------------------------
QuickKeybindFrame:Show()
KeyBound:Toggle()
check(not KeyBound:IsShown(), "/kb can still turn it off")
QuickKeybindFrame:Hide()
check(KeyBound.frame:GetFrameStrata() == "DIALOG", "strata restored after a /kb toggle")
check(not ActionBarMod.quickKeybindOwnsKeyBound, "ownership cleared")

----------------------------------------------------------------
-- 5. Frame already open when the hook is installed
----------------------------------------------------------------
ActionBarMod.quickKeybindHooked = nil
QuickKeybindFrame.hooks = {}
QuickKeybindFrame.shown = true
ActionBarMod:HookQuickKeybindMode()
check(KeyBound:IsShown(), "already-open mode picked up when hooking")
QuickKeybindFrame:Hide()
check(not KeyBound:IsShown(), "and released on close")

print(string.format("quickkeybind harness: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end

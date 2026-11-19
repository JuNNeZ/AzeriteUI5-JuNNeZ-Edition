-- Elune Lua 5.1 only. Tests the real security guard, not WoW frames/input.
local root = arg[1] or "."
local file = assert(io.open(root .. "/.research/tmp/wow-ui-source-forever/Interface/AddOns/Blizzard_GamepadSmartNavigation/SmartNavigation.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local function section(first, last)
	local start = assert(source:find(first, 1, true))
	local finish = assert(source:find(last, start + #first, true))
	return source:sub(start, finish - 1)
end
local nav = { bindingActive = false, navigationBindings = {} }
local calls, blocked = 0, 0
local env = setmetatable({
	SmartNavigationMixin = nav,
	GamepadMode = { ActivateBindingGroup = function()
		assert(issecure(), "insecure input activation")
		calls = calls + 1
	end },
	DisplayInterfaceActionBlockedMessage = function() blocked = blocked + 1 end
}, { __index = _G })
local chunk = assert(loadstring(section("local function EnsureIsSecure()", "SmartNavigationMixin =")
	.. section("function SmartNavigationMixin:ActivateBinding()", "function SmartNavigationMixin:DeactivateBinding()")))
setfenv(chunk, env)
chunk()
securecall(function()
	debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
	assert(not issecure(), "addon context expected")
	nav:ActivateBinding()
end)
assert(issecure(), "addon call leaked taint to caller")
assert(issecurevariable(nav, "bindingActive"), "refused activation tainted native state")
nav:ActivateBinding()
assert(issecure(), "native activation became insecure")
assert(issecurevariable(nav, "bindingActive"), "native activation tainted its own state")
assert(nav.bindingActive and calls == 1 and blocked == 1, "native/addon guard behavior changed")
print("native_menu_activation_taint: addon activation refused, native activation succeeds; no frame/input emulation")

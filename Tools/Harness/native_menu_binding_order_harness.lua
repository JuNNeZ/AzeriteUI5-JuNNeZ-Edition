-- Source-backed experiment for Ranforius' Y-menu input lock.
-- Run: Tools/Run-Elune.ps1 -Script Tools/Harness/native_menu_binding_order_harness.lua .
-- Requires the local Forever reference checkout. This does not emulate WoW.
local root = arg[1] or "."
local sourceRoot = root .. "/.research/tmp/wow-ui-source-forever/Interface/AddOns/"
local function read(path)
	local file = assert(io.open(sourceRoot .. path, "rb"))
	local text = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return text
end
local navSource = read("Blizzard_GamepadSmartNavigation/SmartNavigation.lua")
local managerSource = read("Blizzard_GamepadSharedUtility/FrameControlsManager.lua")
local function section(source, first, last)
	local start = assert(source:find(first, 1, true), first)
	local finish = assert(source:find(last, start + #first, true), last)
	return source:sub(start, finish - 1)
end
local guard = section(navSource, "local function EnsureIsSecure()", "SmartNavigationMixin =")
local activate = section(navSource, "function SmartNavigationMixin:ActivateBinding()",
	"function SmartNavigationMixin:DeactivateBinding()")
local catcher = section(managerSource, "function GamepadFrameControlsManagerMixin:SetFallThroughCatcherActive(",
	"function GamepadFrameControlsManagerMixin:SetUIFocusState(")
local enable = section(managerSource, "local function EnableNavigation(", "local function DisableNavigation(")

local checks = 0
local function check(ok, message)
	checks = checks + 1
	assert(ok, message)
end

local function scenario(alreadyActive, repair)
	local world = { active = {}, stack = {}, secure = true, blocked = 0 }
	local nav = { bindingActive = alreadyActive, navigationBindings = { name = "navigation" } }
	local manager = { gamepadFallthroughCatcherBindings = { name = "catcher" } }
	local mode = {}
	function mode.ActivateBindingGroup(group)
		-- Mirrors InputBindingManager:AddBindingSet: a re-added set moves to top.
		for i = #world.stack, 1, -1 do
			if world.stack[i] == group then table.remove(world.stack, i) end
		end
		table.insert(world.stack, group)
		world.active.PAD1, world.active.PADDDOWN = group, group
	end
	function mode.DeactivateBindingGroup(group)
		for i = #world.stack, 1, -1 do
			if world.stack[i] == group then table.remove(world.stack, i) end
		end
		local top = world.stack[#world.stack]
		world.active.PAD1, world.active.PADDDOWN = top, top
	end
	function nav:HandlePanelOpen(frame) world.panel = frame end
	function nav:Hide() end
	local env = setmetatable({
		SmartNavigationMixin = nav, SmartNavigation = nav,
		GamepadFrameControlsManagerMixin = manager, GamepadMode = mode,
		issecure = function() return world.secure end,
		DisplayInterfaceActionBlockedMessage = function() world.blocked = world.blocked + 1 end
	}, { __index = _G })
	local selectedActivate = activate
	if repair then
		-- A candidate change to BLIZZARD's secure implementation, never installed
		-- by AzeriteUI: reassert native navigation even when bindingActive is true.
		local count
		selectedActivate, count = activate:gsub(" or %(self%.bindingActive%)", "", 1)
		assert(count == 1, "reference guard changed")
	end
	local chunk = assert(loadstring(guard .. selectedActivate .. catcher .. enable .. "\nreturn EnableNavigation"))
	setfenv(chunk, env)
	local enableNavigation = chunk()
	if alreadyActive then mode.ActivateBindingGroup(nav.navigationBindings) end
	-- Exact ordering in FrameShown/FocusFrame: catcher, then EnableNavigation.
	manager:SetFallThroughCatcherActive(true)
	enableNavigation({})
	return world, nav, manager, enableNavigation
end

local clean = scenario(false, false)
check(clean.active.PAD1.name == "navigation", "cold menu must put navigation above catcher")
local stale, nav, manager, enable = scenario(true, false)
check(nav.bindingActive, "navigation still believes its bindings are active")
check(stale.active.PAD1.name == "catcher", "existing navigation is buried by catcher")
check(stale.active.PADDDOWN.name == "catcher", "D-pad also swallowed")
check(stale.blocked == 0, "ordering defect needs neither Lua error nor blocked-action notice")
manager:SetFallThroughCatcherActive(false)
check(stale.active.PAD1.name == "navigation", "removing catcher exposes navigation again")
local repaired = scenario(true, true)
check(repaired.active.PAD1.name == "navigation", "native secure reassertion repairs ordering")

-- Calling the same internal function from addon context is not a safe repair:
-- the real native EnsureIsSecure guard rejects it without throwing a Lua error.
stale.secure = false
nav.bindingActive = false
local ok = pcall(enable, {})
check(ok and stale.blocked == 1, "insecure activation refuses silently except blocked-action notice")
check(not nav.bindingActive, "insecure call does not restore navigation")

print(string.format("native_menu_binding_order: %d checks passed; native ordering defect reproduced", checks))
print("LIMIT: binding stack and frames are models; reporter precondition and addon cause unconfirmed")

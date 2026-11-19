-- Actual disabler lifecycle with recording frames. Optional Elune taint boundary;
-- no WoW frame restrictions, controller input or rendering emulation.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. label) end
end
local function session(native, late, combat, consolePortBar)
	local world = { combat = combat, timers = {}, modules = {} }
	local env = setmetatable({}, { __index = _G }); env._G = env
	local function frame()
		local f = { alpha = 1, mouse = true, shown = true, nativeEvents = true }
		function f:SetAlpha(v) self.alpha = v end
		function f:IsProtected() return true end
		function f:EnableMouse(v)
			assert(not world.combat, "protected mouse mutation during combat")
			self.mouse = v
		end
		function f:Show() self.shown = true end
		function f:Hide() self.shown = false end
		function f:IsShown() return self.shown end
		return f
	end
	local ns = { IsForever = true, API = { IsAddOnEnabled = function(name)
		return consolePortBar and name == "ConsolePort_Bar" or false
	end }, NativeController = { IsActive = function() return native end } }
	function ns:NewModule(name)
		local m = { events = {} }; world.modules[name] = m
		function m:IsEnabled() return true end
		function m:RegisterEvent(event, method) self.events[event] = method end
		return m
	end
	function ns:GetModule() return nil end
	function ns.RegisterCallback() end
	env.InCombatLockdown = function() return world.combat end
	env.C_Timer = { After = function(_, fn) table.insert(world.timers, fn) end }
	env.C_AddOns = { IsAddOnLoaded = function() return false end }
	if not issecure then
		env.hooksecurefunc = function(obj, key, hook)
			local original = obj[key]
			obj[key] = function(...) original(...); hook(...) end
		end
	end
	-- Native controls must never acquire alpha/mouse/selection hooks.
	for _, name in ipairs({ "MainActionBar", "GamepadMainActionBarFrame", "PetActionBar",
		"BagsBar", "CharacterMicroButton", "CompactRaidFrameContainer", "PartyFrame" }) do
		local f = frame(); f.Selection = frame(); env[name] = f
	end
	local function createStatus()
		env.StatusTrackingBarManager = frame()
		for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
			local f = frame(); f.Selection = frame(); env[name] = f
		end
	end
	if not late then createStatus() end
	local chunk = assert(loadfile(root .. "/Components/ActionBars/Compatibility/HideBlizzard.lua"))
	setfenv(chunk, env)
	local function install()
		if issecure then debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition") end
		chunk("AzeriteUI", ns)
		local m = world.modules.BlizzardABDisabler
		if m then m:OnEnable() end
	end
	if issecure then securecall(install) else install() end
	local m = world.modules.BlizzardABDisabler
	if consolePortBar then
		check(not m, "ConsolePort_Bar retains existing ownership")
		return
	end
	check(m ~= nil, "status suppression module exists in native mode")
	if not m then return end
	if late then
		createStatus()
		m:OnBlizzardUIReady("ADDON_LOADED", "Blizzard_StatusTrackingBar")
	end
	local manager = env.StatusTrackingBarManager
	check(manager.alpha == 0 and manager.shown and manager.nativeEvents,
		"status manager invisible with native shown/event state retained")
	manager:SetAlpha(1)
	check(manager.alpha == 0, "native alpha refresh remains suppressed")
	if combat then
		check(manager.mouse, "protected mouse state deferred during combat")
		world.combat = false; m:OnCombatEnd()
	end
	check(not manager.mouse, "status manager cannot intercept mouse outside combat")
	for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
		local selection = env[name].Selection
		selection:Show()
		check(not selection.shown, "status Edit Mode overlay stays hidden: " .. name)
	end
	if native then
		m:OnBlizzardUIReady("PLAYER_ENTERING_WORLD")
		for _, fn in ipairs(world.timers) do fn() end
		for _, name in ipairs({ "MainActionBar", "GamepadMainActionBarFrame", "PetActionBar",
			"BagsBar", "CharacterMicroButton", "CompactRaidFrameContainer", "PartyFrame" }) do
			local f = env[name]
			f:SetAlpha(.75); f:EnableMouse(true); f.Selection:Show()
			check(f.alpha == .75 and f.mouse and f.Selection.shown, "native control untouched: " .. name)
		end
	else
		check(env.MainActionBar.alpha == 0, "keyboard action-bar suppression retained")
	end
end
session(true, false, false, false)
session(true, true, false, false)
session(true, false, true, false)
session(true, true, true, false)
session(false, false, false, false)
session(true, false, false, true)
print(string.format("native_status_bar: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

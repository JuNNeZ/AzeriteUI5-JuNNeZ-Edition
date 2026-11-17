-- Offline contracts for Forever's menu owner and reload-scoped bag ownership.
-- No WoW frame, controller binding, menu rendering or taint emulation.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. label) end
end
local function session(forever, nativeBags, combat)
	local world = { combat = combat, frames = {} }
	local function frame(parent)
		local f = { parent = parent, shown = true, alpha = 1, mouse = true, children = {}, events = { native = true } }
		if parent then table.insert(parent.children, f) end
		function f:SetAlpha(v) self.alpha = v end
		function f:IsForbidden() return self.forbidden or false end
		function f:EnableMouse(v) assert(not world.combat, "mouse mutation in combat"); self.mouse = v end
		function f:GetChildren() return unpack(self.children) end
		function f:SetScript(k, v) self[k] = v end
		function f:RegisterEvent(k) self.events[k] = true end
		function f:UnregisterAllEvents() self.events = {} end
		function f:SetAllPoints() end
		function f:Hide() self.shown = false end
		function f:Show() self.shown = true end
		function f:SetParent(p) self.parent = p end
		function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
		table.insert(world.frames, f)
		return f
	end
	local modules = {}
	local ns = { IsForever = forever, oUF = {}, API = { IsAddOnEnabled = function() return false end },
		MovableModulePrototype = { defaults = {} } }
	ns.HideEditModeSelection = function(f) f.selectionSuppressed = true end
	function ns:Merge(a) return a end
	function ns:GetModule(name) return modules[name] end
	function ns:NewModule(name)
		local m = { events = {} }; modules[name] = m
		function m:RegisterEvent(e, fn) self.events[e] = fn end
		function m:IsEnabled() return true end
		return m
	end
	local env = setmetatable({ C_Container = {}, InCombatLockdown = function() return world.combat end,
		LibStub = function() return { GetLocale = function() return setmetatable({}, {__index = function(_, k) return k end}) end } end,
		C_AddOns = { IsAddOnLoaded = function() return false end },
		CreateFrame = function(_, _, parent) return frame(parent) end }, { __index = _G })
	env._G = env
	function env.hooksecurefunc(obj, key, hook)
		local original = obj[key]
		obj[key] = function(...) original(...); hook(...) end
	end
	local function load(path)
		local chunk = assert(loadfile(root .. "/" .. path)); setfenv(chunk, env); chunk("AzeriteUI", ns)
	end
	env.UIParent = frame()
	env.TargetFrame = frame(env.UIParent)
	local child = frame(env.TargetFrame)
	local forbidden = frame(env.TargetFrame); forbidden.forbidden = true
	load("Libs/oUF/blizzard.lua")
	local watcher = world.frames[#world.frames]
	ns.oUF:DisableBlizzard("target")
	local owner = env.TargetFrame
	if forever then
		check(owner:IsVisible() and owner.parent == env.UIParent, "Forever owner stays visible at native parent")
		check(owner.alpha == 0 and owner.events.native, "Forever owner transparent with native events retained")
		check(owner.selectionSuppressed, "native target Edit Mode selection suppressed")
		check(forbidden.mouse, "forbidden child untouched")
		if combat then
			check(owner.mouse and child.mouse, "initial combat leaves mouse state untouched")
			world.combat = false; watcher.OnEvent()
		end
		check(not owner.mouse and not child.mouse, "native owner and existing children cannot intercept mouse")
		owner:SetAlpha(1); check(owner.alpha == 0, "native alpha refresh cannot show art")
		-- Models Blizzard Menu.lua's owner visibility close rule.
		local menuOpen = true
		if not owner:IsVisible() then menuOpen = false end
		check(menuOpen, "Y menu survives owner visibility check")
		owner:Hide(); check(not owner:IsVisible(), "native target loss can still hide menu owner")
	else
		check(not owner:IsVisible() and not owner.events.native, "Retail retains original target suppression")
	end
	world.combat = false
	load("Components/Misc/Containers.lua")
	local bags = modules.Containers
	check(not ns.ShouldUseBlizzardBags(), "missing bag database does not freeze ownership")
	bags.db = { profile = { useBlizzardBags = nativeBags } }
	check(ns.ShouldUseBlizzardBags() == nativeBags, "saved bag ownership loaded")
	bags.db.profile.useBlizzardBags = not nativeBags
	check(ns.ShouldUseBlizzardBags() == nativeBags, "bag ownership frozen until reload")
	env.BagsBar = frame(env.UIParent)
	env.MainMenuBarBackpackButton = frame(env.BagsBar)
	env.BagBarExpandToggle = frame(env.BagsBar)
	env.MicroButtonAndBagsBar = frame(env.UIParent)
	env.CharacterMicroButton = frame(env.UIParent)
	env.ContainerFrame1 = frame(env.UIParent)
	env.CharacterBag0Slot = frame(env.BagsBar)
	load("Components/ActionBars/Compatibility/HideBlizzard.lua")
	modules.BlizzardABDisabler:HideBlizzard()
	if nativeBags then
		check(env.BagsBar.alpha == 1 and env.BagsBar.mouse, "native BagsBar left untouched")
		check(env.MainMenuBarBackpackButton.shown and env.MainMenuBarBackpackButton.alpha == 1,
			"native backpack left untouched")
		check(env.BagBarExpandToggle.shown and env.BagBarExpandToggle.alpha == 1, "native expand left untouched")
		check(env.MicroButtonAndBagsBar.alpha == 1, "shared bag parent left untouched")
		-- Acquisition must exit before changing a bag window or installing hooks.
		bags:AquireBagButtons()
		check(not next(bags.events), "native bag mode installs no acquisition events")
	else
		check(env.BagsBar.alpha == 0 and not env.BagsBar.mouse, "default bag suppression retained")
		check(not env.MainMenuBarBackpackButton.shown, "default backpack suppression retained")
	end
	check(env.CharacterMicroButton.alpha == 0, "native bag choice does not restore micro menu")
	-- The real options table exposes pending preference and guards reload in combat.
	function bags:UpdateSettings() end
	local generate
	modules.Options = { AddGroup = function(_, _, fn) generate = fn end }
	env.ReloadUI = function() world.reloads = (world.reloads or 0) + 1 end
	load("Options/OptionsPages/Bags.lua")
	local options = generate().args
	options.useBlizzardBags.set({}, true)
	check(options.useBlizzardBags.get() == true, "bag toggle saves desired state")
	world.combat = true; options.reloadBags.func()
	check(options.reloadBags.disabled() and not world.reloads, "reload refused in combat")
	world.combat = false; options.reloadBags.func()
	check(world.reloads == 1, "reload action works out of combat")
end
session(true, true, false)
session(true, false, true)
session(false, true, false)
session(false, false, false)
print(string.format("native_controller: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

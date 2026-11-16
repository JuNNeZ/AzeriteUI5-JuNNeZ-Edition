-- Native Forever action-bar ownership, fixed for one session.
-- Loads the real coordinator, Blizzard quarantine and action/pet/stance modules.
-- Synthetic frames record every write/hook; protected API entrypoints throw.
-- This proves our ownership/initialization paths, not Blizzard rendering or taint.
-- lua Tools/Harness/gamepadui_compat_harness.lua . [mutation]

local root = (arg and arg[1]) or "."
local mutation = arg and arg[2]
local checks, failures, mutationApplied = 0, 0, false
local function check(value, message)
	checks = checks + 1
	if (not value) then failures = failures + 1; print("FAIL: " .. message) end
end
local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local source = file:read("*a"); file:close()
	return (source:gsub("\r\n", "\n"))
end
local function copy(value)
	if (type(value) ~= "table") then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end
local function forbidden(name)
	return function() error("unexpected protected operation: " .. name, 2) end
end
local function count(tableValue)
	local total = 0
	for _ in pairs(tableValue) do total = total + 1 end
	return total
end

local COORDINATOR = "Components/ActionBars/Compatibility/HandleGamepadUI.lua"
local QUARANTINE = "Components/ActionBars/Compatibility/HideBlizzard.lua"
local ELEMENTS = "Components/ActionBars/Elements/"
local PROTOTYPE = "Components/ActionBars/Prototypes/ActionBar.lua"
local OPTIONS = "Options/OptionsPages/ActionBars.lua"

local guard = "if (ns.GamepadUICompatibility and ns.GamepadUICompatibility.IsActive()) then return end"
local mutants = {
	["default-on"] = { COORDINATOR, "enabled = false", "enabled = true" },
	["live-owner"] = { COORDINATOR, "if (active == nil) then", "if (true) then" },
	["early-owner"] = { COORDINATOR, "self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())",
		"self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())\n\tself:OnEnable()" },
	["no-forever-gate"] = { COORDINATOR, "ns.IsForever == true", "true" },
	["requires-native-frame"] = { COORDINATOR, "ns.IsForever == true", "ns.IsForever == true and _G.GamepadMainActionBarFrame ~= nil" },
	["ignore-conflicts"] = { COORDINATOR, "and not self:GetConflict()", "" },
	["no-late-observation"] = { COORDINATOR, "self.nativeFrameReady = _G.GamepadMainActionBarFrame ~= nil", "self.nativeFrameReady = false" },
	["quarantine-native"] = { QUARANTINE, "local nativeBars = useNativeActionBars()", "local nativeBars = false" },
	["binding-writes"] = { PROTOTYPE, guard, "" },
	["actionbars-start"] = { ELEMENTS .. "ActionBars.lua", guard, "", "ActionBarMod.OnEnable = function(self)" },
	["pet-start"] = { ELEMENTS .. "PetBar.lua", guard, "", "PetBarMod.OnEnable = function(self)" },
	["stance-start"] = { ELEMENTS .. "StanceBar.lua", guard, "", "StanceBarMod.OnEnable = function(self)" },
	["vehicle-start"] = { ELEMENTS .. "VehicleExit.lua",
		"if (ns.GamepadUICompatibility and ns.GamepadUICompatibility:IsActive()) then return self:Disable() end", "" },
	["extra-start"] = { ELEMENTS .. "ExtraButtons.lua",
		"if (ns.GamepadUICompatibility and ns.GamepadUICompatibility:IsActive()) then return self:Disable() end", "" },
	["option-inaccessible"] = { OPTIONS, "if (questItemButton) then", "if (false) then" }
}
local function mutate(path, source)
	local mutant = mutation and mutants[mutation]
	if (not mutant or mutant[1] ~= path) then return source end
	local from = mutant[4] and assert(source:find(mutant[4], 1, true), "mutation anchor did not match") or 1
	local first, last = source:find(mutant[2], from, true)
	assert(first, "mutation did not match source: " .. mutation)
	mutationApplied = true
	return source:sub(1, first - 1) .. mutant[3] .. source:sub(last + 1)
end
local function loadReal(world, path)
	local source = read(path)
	if (mutate) then source = mutate(path, source) end
	local chunk = assert(loadstring(source, "@" .. path))
	setfenv(chunk, world.env)
	chunk("AzeriteUI5_JuNNeZ_Edition", world.ns)
end

local function newWorld(config)
	config = config or {}
	local world = { modules = {}, profiles = {}, order = {}, hooks = {}, timers = {}, writes = {},
		addons = copy(config.addons or {}), style = 0, combat = false }
	local env = setmetatable({}, { __index = _G })
	env._G = env
	world.env = env
	env.Enum = { InputDeviceInterfaceType = { Gamepad = 1, MouseAndKeyboard = 0 } }
	env.C_GamepadUI = {
		GetFirstGamepadActionStorageSlotIndex = forbidden("reading native action storage"),
		GetFirstGamepadPetActionStorageSlotIndex = forbidden("reading native pet storage")
	}
	env.C_InputInterfaceStyle = { GetCurrentStyle = function() return world.style end }
	env.InCombatLockdown = function() return world.combat end
	env.C_AddOns = { IsAddOnLoaded = function(name) return world.addons[name] == true end }
	env.C_Timer = { After = function(_, callback) world.timers[#world.timers + 1] = callback end }
	env.C_CVar = { GetCVarBool = function() return false end }
	env.C_ActionBar = {}
	env.BOTTOMLEFT_ACTIONBAR_PAGE, env.BOTTOMRIGHT_ACTIONBAR_PAGE = 6, 5
	env.RIGHT_ACTIONBAR_PAGE, env.LEFT_ACTIONBAR_PAGE = 3, 4
	env.NUM_PET_ACTION_SLOTS, env.NUM_ACTIONBAR_BUTTONS = 10, 12
	env.LibStub = function(name)
		if (name == "AceLocale-3.0") then
			return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
		end
		return {}
	end
	for _, name in ipairs({ "CreateFrame", "SetBinding", "SaveBindings", "SetOverrideBinding", "SetOverrideBindingClick",
		"ClearOverrideBindings", "RegisterStateDriver", "UnregisterStateDriver", "RegisterAttributeDriver",
		"UnregisterAttributeDriver", "SetCVar", "SetBindingClick" }) do env[name] = forbidden(name) end
	env.hooksecurefunc = function(object, method, callback)
		world.hooks[#world.hooks + 1] = { object = object, method = method, callback = callback }
	end
	local ns = {
		IsForever = config.forever ~= false, IsRetail = false, HasSecureSnippets = config.snippets ~= false,
		Colors = {}, Widgets = {}, Hider = {}, Noop = function() end,
		ButtonBar = { prototype = {} }, MovableModulePrototype = { defaults = {} },
		ActionBarProcHighlight = { defaults = {} }, ActionBarAssistedHighlight = { defaults = {} },
		Copy = function(_, value) return copy(value) end,
		Merge = function(_, first, second)
			local result = copy(first)
			for key, value in pairs(second or {}) do if (result[key] == nil) then result[key] = copy(value) end end
			return result
		end,
		API = { IsAddOnEnabled = function(name) return world.addons[name] == true end,
			IsEventAvailable = function() return true end, IsW2UIBagBarEnabled = function() return false end,
			GetEffectiveScale = function() return 1 end },
		RegisterCallback = function() end
	}
	world.ns = ns
	ns.db = { RegisterNamespace = function(_, name, defaults)
		local profile = copy(defaults and defaults.profile or {})
		if (name == "GamepadUICompatibility" and config.enabled ~= nil) then profile.enabled = config.enabled end
		local db = { profile = profile, RegisterCallback = function() end }
		world.profiles[name] = db
		return db
	end }
	function ns:GetModule(name) return world.modules[name] end
	function ns:NewModule(name)
		local module = { name = name, events = {}, enabled = true }
		function module:GetName() return self.name end
		function module:GetDefaults() return self.defaults end
		function module:Disable() self.enabled = false end
		function module:IsEnabled() return self.enabled end
		function module:RegisterEvent(event, method) self.events[event] = method or "OnEvent" end
		function module:UnregisterEvent(event) self.events[event] = nil end
		function module:SecureHook(...) world.hooks[#world.hooks + 1] = { ... } end
		world.modules[name] = module
		world.order[#world.order + 1] = name
		return module
	end
	function world:Fire(module, event, ...)
		local method = module.events[event]
		if (type(method) == "string") then module[method](module, event, ...)
		elseif (method) then method(module, event, ...) end
	end
	function world:Frame(name)
		local state = { alpha = 1, shown = true, mouse = true, writes = 0 }
		local frame = {}
		self.writes[name] = state
		local function write() state.writes = state.writes + 1 end
		function frame:SetAlpha(alpha) write(); state.alpha = alpha end
		function frame:GetAlpha() return state.alpha end
		function frame:EnableMouse(enabled) write(); state.mouse = enabled end
		function frame:SetMouseClickEnabled(enabled) write(); state.mouse = enabled end
		function frame:SetMouseMotionEnabled(enabled) write(); state.mouse = enabled end
		function frame:Show() write(); state.shown = true end
		function frame:Hide() write(); state.shown = false end
		function frame:SetShown(shown) write(); state.shown = shown end
		function frame:IsShown() return state.shown end
		function frame:IsProtected() return true end
		function frame:GetName() return name end
		env[name] = frame
		return frame
	end
	loadReal(world, COORDINATOR)
	world.coordinator = assert(ns.GamepadUICompatibility, "coordinator namespace export")
	return world
end

local function start(world)
	world.coordinator:OnInitialize()
	world.coordinator:OnEnable()
	return world.coordinator
end

local function coordinatorChecks()
	local world = newWorld()
	local coordinator = start(world)
	check(coordinator:IsAvailable(), "Forever capability gate accepts the documented APIs")
	check(coordinator.db.profile.enabled == false and not coordinator:IsActive(), "existing profiles remain opt-in")
	coordinator.db.profile.enabled = true
	check(coordinator:IsReloadPending(), "changing the setting requests reload")
	world:Fire(coordinator, "PLAYER_ENTERING_WORLD")
	coordinator:OnEnable()
	check(not coordinator:IsActive(), "enabling a preference cannot change ownership before reload")

	world = newWorld({ enabled = false })
	coordinator = world.coordinator
	coordinator:OnInitialize()
	check(not coordinator:IsActive(), "no ownership choice during namespace initialization")
	coordinator.db.profile = { enabled = true }
	coordinator:OnEnable()
	check(coordinator:IsActive(), "character profile selected after initialization owns the session")
	check(not coordinator:IsGamepadMode(), "native owner also covers mouse/keyboard mode")
	check(world.env.GamepadMainActionBarFrame == nil, "startup fixture genuinely lacks the native frame")
	for _, event in ipairs({ "ADDON_LOADED", "INPUT_DEVICE_INTERFACE_TRANSITION", "PLAYER_ENTERING_WORLD" }) do
		check(coordinator.events[event] ~= nil, "observes " .. event)
	end
	local native = world:Frame("GamepadMainActionBarFrame")
	world:Fire(coordinator, "ADDON_LOADED", "Blizzard_GamepadActionBars")
	check(coordinator.nativeFrameReady, "late Blizzard addon refreshes native-frame readiness")
	world.combat, world.style = true, 1
	world:Fire(coordinator, "INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
	check(coordinator:IsActive() and coordinator:IsGamepadMode(), "combat mode transition only refreshes observation")
	coordinator.db.profile = { enabled = false }
	world.style = 0
	world:Fire(coordinator, "INPUT_DEVICE_INTERFACE_TRANSITION", 0, 1)
	world:Fire(coordinator, "PLAYER_ENTERING_WORLD")
	coordinator:OnEnable()
	check(coordinator:IsActive() and not coordinator:IsGamepadMode(), "profile/reset/re-enable and keyboard mode retain native owner")
	check(world.env.GamepadMainActionBarFrame == native and world.writes.GamepadMainActionBarFrame.writes == 0,
		"late native frame remains untouched through combat transitions")
	check(#world.hooks == 0 and #world.timers == 0, "coordinator does not hook native behavior or schedule writes")
	check(not start(newWorld({ enabled = false })):IsActive(), "reload applies disabled preference")

	for _, name in ipairs({ "ConsolePort", "ConsolePort_Bar", "Bartender4" }) do
		world = newWorld({ enabled = true, addons = { [name] = true } })
		coordinator = start(world)
		check(coordinator:GetConflict() == name and not coordinator:IsActive(), name .. " keeps its existing precedence")
		world.addons[name] = nil
		world:Fire(coordinator, "ADDON_LOADED", "Blizzard_GamepadActionBars")
		check(not coordinator:IsActive(), "removing " .. name .. " cannot change frozen ownership")
	end

	local missing = {
		{ "Retail", function(w) w.ns.IsForever = false end },
		{ "GamepadUI", function(w) w.env.C_GamepadUI = nil end },
		{ "action storage", function(w) w.env.C_GamepadUI.GetFirstGamepadActionStorageSlotIndex = nil end },
		{ "pet storage", function(w) w.env.C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex = nil end },
		{ "input namespace", function(w) w.env.C_InputInterfaceStyle = nil end },
		{ "input getter", function(w) w.env.C_InputInterfaceStyle.GetCurrentStyle = nil end },
		{ "input enum", function(w) w.env.Enum.InputDeviceInterfaceType.Gamepad = nil end }
	}
	for _, entry in ipairs(missing) do
		world = newWorld({ enabled = true })
		entry[2](world)
		coordinator = start(world)
		check(not coordinator:IsAvailable() and not coordinator:IsActive(), entry[1] .. " absent: compatibility unavailable")
	end
	world = newWorld({ enabled = true })
	world.env.C_GamepadUI.GetFirstGamepadActionStorageSlotIndex = nil
	coordinator = start(world)
	world.env.C_GamepadUI.GetFirstGamepadActionStorageSlotIndex = forbidden("reading late native action storage")
	world:Fire(coordinator, "ADDON_LOADED", "Blizzard_GamepadActionBars")
	check(coordinator:IsAvailable() and not coordinator:IsActive(), "late capability cannot change owner after existing quarantine")
end

local nativeNames = { "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft",
	"MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PossessActionBar", "PetActionBar",
	"OverrideActionBar", "GamepadMainActionBarFrame", "MultiCastActionBarFrame" }
local function quarantineChecks(enabled)
	local world = newWorld({ enabled = enabled })
	start(world)
	local names = copy(nativeNames)
	for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
		"MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton", "PossessButton" }) do
		local max = prefix == "PossessButton" and 2 or (prefix == "PetActionButton" or prefix == "StanceButton") and 10 or 12
		for index = 1, max do names[#names + 1] = prefix .. index end
	end
	for _, name in ipairs(names) do world:Frame(name) end
	for _, name in ipairs({ "MainActionBar", "PetActionBar", "StanceBar", "GamepadMainActionBarFrame" }) do
		world.env[name].Selection = world:Frame(name .. "Selection")
		names[#names + 1] = name .. "Selection"
	end
	world.env.MainActionBar.EndCaps = { LeftEndCap = world:Frame("LeftEndCap"), RightEndCap = world:Frame("RightEndCap") }
	names[#names + 1], names[#names + 2] = "LeftEndCap", "RightEndCap"
	for _, name in ipairs({ "BagsBar", "StatusTrackingBarManager", "MicroMenu", "MainMenuBarBackpackButton" }) do world:Frame(name) end
	for _, name in ipairs({ "MainMenuBarVehicleLeaveButton", "ExtraAbilityContainer" }) do
		world:Frame(name).Selection = world:Frame(name .. "Selection")
		-- These modules are still enabled when the earlier quarantine module runs.
		names[#names + 1] = name .. "Selection"
	end
	world.ns:NewModule("VehicleExit")
	world.ns:NewModule("ExtraActionButtons")
	world.env.EditModeManagerFrame = { AccountSettings = {
		LayoutSettings = function() end,
		SettingsContainer = { VehicleLeaveButton = world:Frame("VehicleLeaveCheckbox"), ArenaFrames = world:Frame("ArenaCheckbox") }
	} }
	loadReal(world, QUARANTINE)
	local module = world.modules.BlizzardABDisabler
	module:OnInitialize()
	module:OnEnable()
	world:Fire(module, "PLAYER_ENTERING_WORLD")
	world:Fire(module, "ADDON_LOADED", "Blizzard_GamepadActionBars")
	for _, callback in ipairs(world.timers) do callback() end
	check(world.writes.VehicleLeaveCheckbox.shown == enabled, "vehicle Edit Mode checkbox follows native ownership")
	check(not world.writes.ArenaCheckbox.shown, "unrelated Edit Mode checkbox remains hidden")
	if (enabled) then
		for _, name in ipairs(names) do
			check(world.writes[name].writes == 0, "native ownership preserves " .. name)
		end
		for _, name in ipairs(names) do
			local hooked = false
			for _, hook in ipairs(world.hooks) do if (hook.object == world.env[name]) then hooked = true end end
			check(not hooked, "no quarantine hook on " .. name)
		end
	else
		for _, name in ipairs({ "MainActionBar", "ActionButton1", "PetActionBar", "PetActionButton1", "StanceBar", "StanceButton1" }) do
			check(world.writes[name].alpha == 0 and not world.writes[name].mouse, "disabled: existing quarantine for " .. name)
		end
		check(world.writes.LeftEndCap.shown == false, "disabled: existing native endcap suppression")
		check(world.writes.GamepadMainActionBarFrame.writes == 0, "disabled: native Gamepad frame is never quarantined")
	end
	for _, name in ipairs({ "BagsBar", "StatusTrackingBarManager", "MicroMenu", "MainMenuBarBackpackButton" }) do
		check(world.writes[name].alpha == 0, "unrelated HUD suppression retained: " .. name)
	end
end

local function barChecks(snippets)
	local world = newWorld({ enabled = true, snippets = snippets })
	start(world)
	for _, name in ipairs({ "ActionBars", "PetBar", "StanceBar" }) do
		loadReal(world, ELEMENTS .. name .. ".lua")
		local module = assert(world.modules[name])
		module.GetDefaults = function() return { profile = { enabled = true, numbuttons = 7, clickOnDown = true } } end
		module:OnInitialize()
		local before = copy(module.db.profile)
		module:OnEnable()
		module:OnEnable()
		check(count(module.events) == 0, name .. ": native owner installs no replacement events")
		check(module.bar == nil and (not module.bars or next(module.bars) == nil), name .. ": no replacement frames allocated")
		check(module.db.profile.enabled == before.enabled and module.db.profile.numbuttons == before.numbuttons
			and module.db.profile.clickOnDown == before.clickOnDown, name .. ": saved preferences survive suppression")
		if (module.CreateBars) then module:CreateBars() else module:CreateBar() end
		module:UpdateBindings()
		module:UpdateSettings()
		module:RefreshConfig()
	end
	check(#world.hooks == 0 and #world.timers == 0, "suppressed modules leave callbacks/timers dormant (snippets " .. tostring(snippets) .. ")")
	loadReal(world, PROTOTYPE)
	for _, combat in ipairs({ false, true }) do
		world.combat = combat
		world.ns.ActionBar.prototype.UpdateBindings({ config = { enabled = true }, buttons = { {} } })
		check(true, "direct action-bar binding update cannot write overrides (snippets " .. tostring(snippets) .. ", combat " .. tostring(combat) .. ")")
	end
end

local function extraChecks()
	local world = newWorld({ enabled = true })
	-- Forever shares the Retail action-bar implementation in this addon.
	world.ns.IsRetail = true
	world.env.ZoneAbilityFrame = { UpdateDisplayedZoneAbilities = function() end }
	start(world)
	loadReal(world, ELEMENTS .. "VehicleExit.lua")
	loadReal(world, ELEMENTS .. "ExtraButtons.lua")
	local extra = world.modules.ExtraActionButtons
	extra:OnInitialize()
	check(#world.hooks == 0, "extra action does not install hooks before the session owner is selected")
	extra:OnEnable()
	world.modules.VehicleExit:OnEnable()
	check(not extra:IsEnabled() and not world.modules.VehicleExit:IsEnabled(), "native owner preserves extra actions and vehicle exit")
	check(count(extra.events) == 0 and #world.hooks == 0, "native extra actions keep their binding handlers and styling untouched")
end

local function optionsFor(world, mainModule, withQuest)
	local options = world.ns:NewModule("Options")
	function options:AddGroup(_, generator) self.generator = generator end
	function options:CloseOptionsMenu() world.closedOptions = true end
	world.optionBindings, world.popups, world.reloads, world.keybinds = {}, 0, 0, 0
	world.ns.OptionsKit = { Defaults = { Bind = function(group, namespace) world.optionBindings[group] = namespace end } }
	world.env.GetNumShapeshiftForms = function() return 0 end
	world.env.StaticPopupDialogs = {}
	world.env.StaticPopup_Show = function(key) world.popups = world.popups + 1; world.popupKey = key end
	world.env.ReloadUI = function() world.reloads = world.reloads + 1 end
	-- The traditional options page creates one ordinary frame to refresh stance
	-- counts. It must not create any secure frame while merely generating options.
	world.env.CreateFrame = function(kind, name, parent, template)
		assert(kind == "Frame" and template == nil, "options attempted secure frame creation")
		return { RegisterEvent = function() end, SetScript = function() end }
	end
	local libStub = world.env.LibStub
	world.env.LibStub = function(name)
		if (name == "LibKeyBound-1.0") then return { Toggle = function() world.keybinds = world.keybinds + 1 end } end
		return libStub(name)
	end
	if (mainModule) then
		local main = world.ns:NewModule("ActionBars")
		main.db, main.bars = { profile = {} }, {}
	end
	if (withQuest) then
		local quest = world.ns:NewModule("QuestItemButton")
		quest.db = { profile = { enabled = true, useExtraActionKey = true, trackedOnly = false } }
		quest.IsStandingDown = function() return false end
		quest.HasRival = function() return false end
		quest.UpdateSettings = function() world.questUpdates = (world.questUpdates or 0) + 1 end
	end
	loadReal(world, OPTIONS)
	return options.generator()
end

local function optionChecks()
	local function checkRemovedGroups(page, label)
		local found
		local function visit(group)
			for key, option in pairs(group and group.args or {}) do
				if (key == "gamepadUI" or key == "inputStyle") then found = true end
				if (type(option) == "table") then visit(option) end
			end
		end
		visit(page)
		check(not found, label .. " omits native-bar and input-style menu groups")
	end
	local world = newWorld()
	start(world)
	local page = optionsFor(world, true, true)
	checkRemovedGroups(page, "Azerite owner")
	check(page.args.hideElementsHotkey ~= nil, "inactive ownership keeps ordinary action-bar options")
	check(page.args.questItemButton ~= nil and page.args.keybindMode ~= nil, "Azerite owner keeps quest and keybind settings")
	for _, namespace in pairs(world.optionBindings) do
		check(namespace ~= "GamepadUICompatibility" and namespace ~= "InputStyle", "menu no longer binds removed preference namespaces")
	end
	check(world.popups == 0 and world.reloads == 0 and not world.coordinator:IsActive(), "opening ordinary options does not change ownership or reload")

	world = newWorld({ enabled = true })
	start(world)
	page = optionsFor(world, false, true)
	check(page and not page.args.hideElementsHotkey, "native quest settings remain reachable without replacement ActionBars module")
	checkRemovedGroups(page, "Native owner without ActionBars module")
	check(page.args.questItemButton ~= nil, "native page retains independent quest-item controls")
	local quest = assert(page.args.questItemButton).args
	quest.trackedOnly.set({ "trackedOnly" }, true)
	check(quest.trackedOnly.get({ "trackedOnly" }) == true and world.questUpdates == 1, "native quest settings still update the module")
	check(quest.useExtraActionKey.disabled(), "native page disables unavailable extra-action borrowing")
	quest.useExtraActionKey.set({ "useExtraActionKey" }, false)
	check(quest.useExtraActionKey.get({ "useExtraActionKey" }) == true, "native borrowing control preserves the saved setting")
	check(world.optionBindings[page.args.questItemButton] == "QuestItemButton", "quest Defaults stays bound to its own namespace")
	world.combat = true
	page.args.keybindMode.func()
	check(world.keybinds == 0, "standalone keybind mode cannot be entered during combat")
	world.combat = false
	page.args.keybindMode.func()
	check(world.keybinds == 1 and world.closedOptions, "standalone quest keybind mode works without ActionBars")
	check(world.coordinator:IsActive(), "independent quest and keybind options preserve native session ownership")
	for _, style in ipairs({ 0, 1 }) do
		world = newWorld({ enabled = true }); world.style = style; start(world)
		page = optionsFor(world, true, true)
		checkRemovedGroups(page, "Native style " .. style)
		check(page.args.questItemButton ~= nil and page.args.keybindMode ~= nil and page.args.hideElementsHotkey == nil,
			"native style " .. style .. " exposes only independent settings despite ActionBars module existing")
	end
	world = newWorld({ enabled = true }); start(world)
	check(optionsFor(world, false, false) == nil, "native ownership without quest controls has no empty settings page")

	for _, rival in ipairs({ "ConsolePort", "ConsolePort_Bar", "Bartender4" }) do
		world = newWorld({ enabled = true, addons = { [rival] = true } })
		start(world)
		page = optionsFor(world, true, true)
		checkRemovedGroups(page, rival .. " enabled")
		check(not world.coordinator:IsActive() and page.args.hideElementsHotkey ~= nil, rival .. " retains existing runtime precedence and ordinary page")
	end

	world = newWorld({ enabled = true })
	world.env.C_GamepadUI = nil
	start(world)
	page = optionsFor(world, true, true)
	checkRemovedGroups(page, "Missing native APIs")
	check(not world.coordinator:IsActive() and page.args.hideElementsHotkey ~= nil, "missing native APIs retain ordinary action-bar options")

	world = newWorld({ forever = false })
	start(world)
	page = optionsFor(world, true)
	checkRemovedGroups(page, "Retail")
	check(page.args.hideElementsHotkey ~= nil, "Retail keeps its ordinary action-bar options")
end

local function run(label, callback, ...)
	local ok, message = pcall(callback, ...)
	check(ok, label .. (ok and "" or ": " .. tostring(message)))
end
run("coordinator", coordinatorChecks)
run("native quarantine", quarantineChecks, true)
run("normal quarantine", quarantineChecks, false)
run("secure snippets", barChecks, true)
run("fallback bindings", barChecks, false)
run("extra actions and vehicle", extraChecks)
run("options", optionChecks)

local xml = read("Components/ActionBars/ActionBars.xml")
local coordinatorPosition = xml:find("Compatibility\\HandleGamepadUI.lua", 1, true)
check(coordinatorPosition and coordinatorPosition < assert(xml:find("Compatibility\\HideBlizzard.lua", 1, true)),
	"coordinator registers before quarantine and action-bar modules")
if (mutation) then check(mutationApplied, "requested mutation exists and matched source: " .. mutation) end
print(("GamepadUI compatibility: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

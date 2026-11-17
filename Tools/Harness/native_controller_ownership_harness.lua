-- Verifies early bar ownership, not WoW bindings, crossbar rendering or taint.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. message) end
end
local function session(forever, preference, style, options)
	options = options or {}
	local world = { style = style, prompts = 0, hidden = 0, reloads = 0, frames = {} }
	local ns = { IsForever = forever, WoW11 = true, API = { PopupDialogs = {},
		GetAddOnTitle = function(name) return name end,
		IsAddOnEnabled = function(name) return options.addons and options.addons[name] or false end } }
	ns.API.IsEventAvailable = function() return true end
	local saved = { nativeControllerBars = preference }
	ns.db = { global = saved }
	ns.API.ShowPopup = function(key) world.prompts = world.prompts + 1; world.lastPrompt = key end
	ns.API.HidePopup = function() world.hidden = world.hidden + 1 end
	local env = setmetatable({
		AzeriteUI5_DB = { global = saved },
		Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } },
		C_InputInterfaceStyle = { GetCurrentStyle = function() return world.style end },
		C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 145 end,
			GetFirstGamepadPetActionStorageSlotIndex = function() return 273 end },
		InCombatLockdown = function() return world.combat end,
		ReloadUI = function() world.reloads = world.reloads + 1 end,
		LibStub = function(name)
			if name == "LibKeyBound-1.0" then return { Toggle = function() world.binders = (world.binders or 0) + 1 end } end
			return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end }
		end,
		CreateFrame = function()
			local frame = { events = {} }
			function frame:RegisterEvent(e) self.events[e] = true end
			function frame:SetScript(e, fn) self[e] = fn end
			world.frames[#world.frames + 1] = frame
			return frame
		end
	}, { __index = _G })
	if options.partyTargeting ~= nil then
		env.C_CVar = { GetCVarBool = function(name) return name == "GamepadUsePartyTargeting" and options.partyTargeting end }
	end
	if options.missing == "pet" then env.C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex = nil end
	if options.missing == "enum" then env.Enum.InputDeviceInterfaceType.Gamepad = nil end
	if options.missing == "style" then env.C_InputInterfaceStyle.GetCurrentStyle = nil end
	env._G = env
	local function load(path)
		local chunk = assert(loadfile(root .. "/" .. path)); setfenv(chunk, env); chunk("AzeriteUI", ns)
	end
	load("Core/NativeController.lua")
	local available = forever and not options.missing or false
	local conflict = options.addons and (options.addons.ConsolePort_Bar and "ConsolePort_Bar"
		or options.addons.Bartender4 and "Bartender4") or nil
	local active = available and style == 1 or false
	check(ns.NativeController.IsAvailable() == available, "native mode requires complete client APIs")
	check(ns.NativeController.GetConflict() == conflict, "replacement bar owner is reported without disabling native UI")
	check(ns.NativeController.IsActive() == active, "native mode automatically follows Blizzard style, ignoring legacy preference")
	check(#world.frames == (available and 1 or 0), "all supported interface sessions monitor mode transitions")
	check(saved.nativeControllerBars == preference, "legacy preference is neither applied nor rewritten")
	if active then
		local moduleCreations = 0
		function ns:NewModule() moduleCreations = moduleCreations + 1; error("native ownership must precede module creation") end
		function ns:GetModule() return nil end
		local before = #world.frames
		for _, path in ipairs({
			"Components/ActionBars/Compatibility/HideBlizzard.lua",
			"Components/ActionBars/Compatibility/HandleConsolePort.lua",
			"Components/ActionBars/Elements/ActionBars.lua", "Components/ActionBars/Elements/PetBar.lua",
			"Components/ActionBars/Elements/StanceBar.lua", "Components/ActionBars/Elements/ExtraButtons.lua",
			"Components/ActionBars/Elements/MicroMenu.lua", "Components/ActionBars/Elements/VehicleExit.lua",
			"WoW11/ActionBars/ActionBars.lua", "WoW11/ActionBars/PetBar.lua", "WoW11/ActionBars/StanceBar.lua"
		}) do
			local ok, errorText = pcall(load, path)
			check(ok, "native mode skips startup: " .. path .. (ok and "" or tostring(errorText)))
		end
		check(moduleCreations == 0 and #world.frames == before, "no bar modules, secure buttons or delayed initializer created")
		local generate
		local options = { AddGroup = function(_, _, fn) generate = fn end }
		local quest = { db = { profile = { enabled = true, useExtraActionKey = true } },
			IsStandingDown = function() return false end, UpdateSettings = function() end }
		function ns:GetModule(name) return name == "Options" and options or name == "QuestItemButton" and quest or nil end
		load("Options/OptionsPages/ActionBars.lua")
		local groups = generate().args
		check(groups.questItemButton and groups.keybindMode, "native mode retains quest settings and its binder")
		local borrow = groups.questItemButton.args.useExtraActionKey
		check(borrow.disabled(), "native quest fallback setting explains unavailable borrowing")
		borrow.set({ "useExtraActionKey" }, false)
		check(quest.db.profile.useExtraActionKey, "disabled native quest setting preserves stored choice")
		world.combat = true; groups.keybindMode.func()
		check(not world.binders, "native quest binder refuses direct invocation in combat")
		world.combat = false; groups.keybindMode.func()
		check(world.binders == 1, "native quest binder remains usable outside combat")
		local args = groups.nativeController.args
		check(not args.nativeControllerBars and args.description.type == "description", "native support requires no extra opt-in")
		world.combat = true; args.reload.func()
		check(world.reloads == 0 and args.reload.disabled(), "reload control refuses combat")
		world.combat = false; args.reload.func()
		check(world.reloads == 1, "reload control available outside combat")
	end
	if available then
		local monitor = world.frames[1]
		local before = world.prompts
		world.combat = true
		monitor.OnEvent(monitor, "INPUT_DEVICE_INTERFACE_TRANSITION", style == 1 and 0 or 1, style)
		check(world.prompts == before + 1, "input transition requests reload even during combat")
		check(ns.NativeController.IsActive() == active, "input transition never changes live bar ownership")
		monitor.OnEvent(monitor, "INPUT_DEVICE_INTERFACE_TRANSITION", style)
		check(world.hidden > 0, "return to built mode retires obsolete reload prompt")
		world.combat = false
		-- Party frame ownership: direct D-pad party targeting keeps ours.
		local party = options.partyTargeting and true or false
		local c = ns.NativeController
		check(c.UsesNativePartyFrames() == (active and not party), "party frames native only without direct party targeting")
		check(c.UsesNativeRaidFrames() == active, "raid frames always native in a native session")
		check(monitor.events.CVAR_UPDATE, "party targeting setting is monitored")
		local prompts, hidden = world.prompts, world.hidden
		monitor.OnEvent(monitor, "CVAR_UPDATE", "SomeOtherCVar", "1")
		check(world.prompts == prompts and world.hidden == hidden, "unrelated CVar changes ignored")
		monitor.OnEvent(monitor, "CVAR_UPDATE", "GamepadUsePartyTargeting", party and "0" or "1")
		check(world.prompts == prompts + (active and 1 or 0), "party targeting change asks for a reload only in native mode")
		check(c.UsesNativePartyFrames() == (active and not party), "party ownership stays frozen until reload")
		monitor.OnEvent(monitor, "CVAR_UPDATE", "GamepadUsePartyTargeting", party and "1" or "0")
		check(world.hidden == hidden + (active and 1 or 0), "changing it back retires the prompt")
	end
	if forever then
		local generate
		local optionsModule = { AddGroup = function(_, _, fn) generate = fn end }
		function ns:GetModule(name) return name == "Options" and optionsModule or nil end
		load("Options/OptionsPages/ActionBars.lua")
		local args = generate().args.nativeController.args
		check(not args.nativeControllerBars, "native opt-in is absent in every Forever mode")
		local help = args.description.name()
		check(type(help) == "string" and help:find(not available and "unavailable" or conflict or "automatically", 1, true),
			"native ownership help explains automatic mode or external bar owner")
	end
	return ns
end
session(true, true, 1)
session(true, nil, 1)
session(true, true, 0)
session(true, false, 1)
session(false, true, 1)
session(false, false, 0)
session(true, true, 1, { addons = { ConsolePort = true } })
session(true, true, 1, { addons = { ConsolePort_Bar = true } })
session(true, true, 1, { addons = { Bartender4 = true } })
session(true, true, 1, { partyTargeting = true })
session(true, true, 1, { partyTargeting = false })
session(true, true, 0, { partyTargeting = true })
session(true, true, 1, { missing = "pet" })
session(true, true, 1, { missing = "enum" })
session(true, true, 1, { missing = "style" })
print(string.format("native_controller_ownership: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

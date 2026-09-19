-- Contract checks using actual addon files. No claim of live WoW execution.
-- lua Tools/Harness/client_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local function run(path, env, ns)
	local chunk = assert(loadfile(root .. "/" .. path))
	setfenv(chunk, env)
	return chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
local function client(interface, project, marker, secretAPI)
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.WOW_PROJECT_MAINLINE = 1
	env.WOW_PROJECT_ID = project
	env.GetBuildInfo = function() return "1.60.1", "69913", "Sep 2026", interface end
	env.C_AddOns = { GetAddOnMetadata = function(_, key)
		if key == "X-AzeriteUI-Client" then return marker end
		return "5.4.13-JuNNeZ"
	end }
	env.issecretvalue = secretAPI and function(value) return value == "secret" end or nil
	local ns = {}
	run("Core/Private.lua", env, ns)
	run("Core/Client.lua", env, ns)
	return env, ns
end

for _, case in ipairs({
	{120100, 1, nil, true, false},
	{16001, 1, nil, true, true},
	{120100, 1, "Forever", true, true},
	{16002, 1, "Forever", true, true},
	{11508, 2, nil, false, false}
}) do
	local env, ns = client(case[1], case[2], case[3], true)
	check(ns.IsMainline == case[4], "engine detection " .. case[1])
	check(ns.IsForever == case[5], "content detection " .. case[1])
	check(ns.IsRetailContent == (case[4] and not case[5]), "Retail gameplay flag")
	check(ns.WoW11 == case[4] and ns.IsRetail == case[4], "modern bootstrap retained")
	check(ns.HasSecretValues, "secret safeguards do not depend on interface")
	env.C_EventUtils = { IsEventValid = function(event) return event == "PLAYER_LOGIN" end }
	check(ns.API.IsEventAvailable("PLAYER_LOGIN"), "valid event retained")
	check(not ns.API.IsEventAvailable("HOUSE_EDITOR_MODE_CHANGED"), "unavailable event gated")
end

-- Exercise the aliases at the lower Forever interface and at Retail's number.
for _, interface in ipairs({120100, 16001}) do
	local env, ns = client(interface, 1, nil, true)
	env.C_CVar = { GetCVarInfo = function() return "value" end }
	env.C_Item = {}
	env.C_Reputation = { GetNumFactions = function() return 7 end }
	env.C_Spell = { GetSpellCooldown = function() return {
		startTime = 10, duration = 20, isEnabled = true, modRate = 1
	} end }
	env.C_SpellBook = {}
	local aura = { name = "Aura", icon = 1, applications = 2, spellId = 123,
		auraInstanceID = "secret", canApplyAura = true }
	env.C_UnitAuras = {
		GetAuraDataByIndex = function() return aura end,
		GetBuffDataByIndex = function() return aura end,
		GetDebuffDataByIndex = function() return aura end
	}
	ns.API.TryCall = pcall
	run("Core/Compatibility.lua", env, ns)
	check(env.GetAddOnMetadata == env.C_AddOns.GetAddOnMetadata, "metadata alias")
	check(env.GetCVarInfo() == "value", "CVar alias")
	check(env.GetNumFactions() == 7, "reputation alias")
	check(env.GetSpellLossOfControlCooldown == nil, "removed cooldown APIs do not create callable aliases")
	local start, duration, enabled, rate = env.GetSpellCooldown(123)
	check(start == 10 and duration == 20 and enabled and rate == 1, "cooldown tuple")
	check(env.UnitBuff("player", 1) == "Aura", "aura alias")
	check(select(11, env.UnitDebuff("target", 1)) == nil, "secret aura ID omitted")
	local native = function() return "native" end
	env.GetSpellCooldown = native
	run("Core/Compatibility.lua", env, ns)
	check(env.GetSpellCooldown == native, "native functions never replaced")
end
do
	local env, ns = client(16001, 1, nil, false)
	run("Core/Compatibility.lua", env, ns)
	check(not ns.HasSecretValues and env.GetSpellCooldown == nil, "missing namespaces do not create callable aliases")
end

-- Disabled modules must return before attempting any module/API initialization.
for _, file in ipairs({
	"Components/UnitFrames/Units/Arena.lua",
	"WoW11/UnitFrames/ArenaFrames.lua",
	"Components/Misc/ArcheologyBar.lua",
	"Components/Misc/VehicleSeat.lua",
	"Components/UnitFrames/Units/PlayerClassPower.lua"
}) do
	local env, ns = client(16001, 1, nil, true)
	ns.Private.PlayerClass = "PALADIN"
	ns.NewModule = function() error("inapplicable module initialized") end
	run(file, env, ns)
	check(true, file .. " gated")
end

-- Imported spec-icon settings must not start an inspect loop on Forever.
do
	local env, ns = client(16001, 1, nil, true)
	env.GetSpecialization = function() return 1 end
	env.GetInspectSpecialization = function() return 62 end
	env.CreateFrame = function() return { SetScript = function() end,
		RegisterEvent = function() error("inspect event should not register") end } end
	run("Components/UnitFrames/GroupSpecCache.lua", env, ns)
	ns.GroupSpecCache.Enable()
	check(ns.GroupSpecCache:GetSpecID("player") == nil, "Forever spec lookup disabled")
end

-- Exercise actual oUF element lifecycle without Retail talents or charged CP.
for _, class in ipairs({"ROGUE", "DRUID", "PALADIN"}) do
	local env, ns = client(16001, 1, nil, true)
	env.UnitClassBase = function() return class end
	env.Enum = { PowerType = {} }
	env.UnitIsUnit = function(a, b) return a == b end
	env.UnitHasVehicleUI = function() return false end
	env.UnitPowerType = function() return 3 end
	env.UnitPower = function() return 3 end
	env.UnitPowerMax = function() return 5 end
	env.C_SpellBook = { IsSpellKnown = function() return true end }
	local element
	ns.oUF = { AddElement = function(_, _, update, enable, disable)
		element = { update = update, enable = enable, disable = disable }
	end }
	run("Libs/oUF/elements/classpower.lua", env, ns)
	if class == "PALADIN" then
		check(element == nil, "Holy Power omitted on Forever")
	else
		local cp = { UpdateColor = function() end }
		local values, events = {}, {}
		for i = 1, 5 do
			local index = i
			cp[i] = { IsObjectType = function() return true end,
				GetStatusBarTexture = function() return {} end,
				SetMinMaxValues = function() end, SetShown = function() end, Hide = function() end,
				SetValue = function(_, value) values[index] = value end }
		end
		local frame = { ClassPower = cp, unit = "player",
			RegisterEvent = function(_, event) events[event] = true end,
			UnregisterEvent = function(_, event) events[event] = nil end }
		check(element.enable(frame, "player"), class .. " combo element enables")
		cp:ForceUpdate()
		check(values[1] == 3 and values[3] == 1 and values[4] == 0, class .. " combo points update")
		check(not events.TRAIT_CONFIG_UPDATED, class .. " no Retail trait dependency")
		element.disable(frame)
		check(not events.SPELLS_CHANGED and not events.UNIT_POWER_UPDATE, class .. " unregisters")
	end
end

-- The real event validators must reject unavailable events without registering
-- them on a frame (which would itself emit a Lua error in the game).
do
	local env, ns = client(16001, 1, nil, true)
	local registered, scripts = {}, {}
	env.C_EventUtils = { IsEventValid = function(event) return event == "PLAYER_LOGIN" end }
	env.CreateFrame = function() return {
		RegisterEvent = function(_, event)
			assert(event == "PLAYER_LOGIN", "invalid event reached RegisterEvent")
			registered[event] = true
		end,
		UnregisterEvent = function(_, event) registered[event] = nil end,
		GetScript = function(_, script) return scripts[script] end,
		SetScript = function(_, script, callback) scripts[script] = callback end
	} end
	local lib = {}
	env.LibStub = { NewLibrary = function() return lib end }
	run("Libs/LibMoreEvents-1.0/LibMoreEvents-1.0.lua", env, ns)
	local module, count = {}, 0
	lib.RegisterEvent(module, "MISSING_EVENT", function() error("invalid event fired") end)
	lib.RegisterEvent(module, "PLAYER_LOGIN", function() count = count + 1 end)
	check(not registered.MISSING_EVENT and registered.PLAYER_LOGIN, "LibMoreEvents filters registration")
	scripts.OnEvent(nil, "PLAYER_LOGIN")
	check(count == 1, "LibMoreEvents dispatch retained")
	ns.oUF = { Private = {}, Enum = { SelectionType = {} } }
	run("Libs/oUF/private.lua", env, ns)
	check(not ns.oUF.Private.validateEvent("MISSING_EVENT"), "oUF rejects missing event")
	check(ns.oUF.Private.validateEvent("PLAYER_LOGIN"), "oUF accepts valid event")
end

-- Build the actual cog-wheel menu with each client's native button list. The
-- frame methods below are presentation-only; names, attributes and scripts are real state.
for _, forever in ipairs({false, true}) do
	local env, ns = client(forever and 16001 or 120100, 1, nil, true)
	local module = {}
	ns.NewModule = function() return module end
	ns.Private.Prefix = "Test"
	ns.Colors = { highlight = {}, offwhite = {}, gray = {}, ui = {1, 1, 1} }
	ns.API.GetFont = function() end
	ns.API.GetMedia = function() end
	ns.API.GetEffectiveScale = function() return 1 end
	env.LibStub = function() return { GetLocale = function() return {} end } end
	env.InCombatLockdown = function() return false end
	env.RegisterStateDriver = function() end
	local function frame(name)
		local f = { name = name, scripts = {}, attributes = {} }
		for method in ("SetFrameStrata SetScale Hide Show SetFrameLevel SetBackdrop SetBackdropColor " ..
			"RegisterForClicks SetSize SetPoint SetColorTexture SetFontObject SetText SetJustifyH " ..
			"SetJustifyV SetTextColor SetVertexColor SetFrameRef SetTexture HookScript Enable Disable"):gmatch("%S+") do
			f[method] = function() end
		end
		f.GetName = function(self) return self.name end
		f.GetFrameLevel = function() return 1 end
		f.SetScript = function(self, key, value) self.scripts[key] = value end
		f.GetScript = function(self, key) return self.scripts[key] end
		f.SetAttribute = function(self, key, value) self.attributes[key] = value end
		f.IsEnabled = function() return true end
		f.IsMouseOver = function() return false end
		f.CreateTexture = function() return frame() end
		f.CreateFontString = function() return frame() end
		return f
	end
	env.CreateFrame = function(_, name) return frame(name) end
	local infos, expected = {}, {}
	for _, name in ipairs(forever and {"Character", "Spellbook", "Talent", "Legacy", "Guild", "MainMenu"}
		or {"Character", "PlayerSpells", "Achievement", "Guild", "MainMenu"}) do
		local key = name .. "MicroButton"
		env[key] = frame(key)
		infos[#infos + 1] = { button = env[key] }
		expected[key] = true
	end
	env.QuickJoinToastButton = frame("QuickJoinToastButton")
	expected.QuickJoinToastButton = true
	infos[#infos + 1] = { button = frame("HousingMicroButton"), gameRule = 42 }
	infos[#infos + 1] = { button = frame("EJMicroButton"), callback = function() return true end }
	env.C_GameRules = { IsGameRuleActive = function(rule) return rule == 42 end }
	env.MicroMenu = { GenerateButtonInfos = function() return infos end }
	run("Components/ActionBars/Elements/MicroMenu.lua", env, ns)
	module:SpawnButtons()
	module:UpdateButtons()
	for _, button in ipairs(module.buttons) do
		local name = button.ref:GetName()
		check(expected[name], "native menu includes only available buttons: " .. name)
		expected[name] = nil
		if not button.nocombat then
			check(button.attributes.macrotext == "/click " .. name, "menu click targets native button")
		end
	end
	check(next(expected) == nil, "every supported menu button retained")
	check(module.toggle ~= nil, "cog created")
	env.MicroMenu.GenerateButtonInfos = function() return {} end
	module.toggle = nil
	module:SpawnButtons()
	check(#module.buttons == 0 and module.toggle == nil, "empty native menu safely omitted")
end

print("Client compatibility: " .. checks .. " checks passed")

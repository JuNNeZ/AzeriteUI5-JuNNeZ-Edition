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
			"SetJustifyV SetTextColor SetVertexColor SetFrameRef SetTexture HookScript"):gmatch("%S+") do
			f[method] = function() end
		end
		-- Enabled state is real state, not a no-op: the menu has to grey an entry
		-- whose native button Blizzard has gated, or it swallows the click.
		f.enabled = true
		f.Enable = function(self) self.enabled = true end
		f.Disable = function(self) self.enabled = false end
		f.GetName = function(self) return self.name end
		f.GetFrameLevel = function() return 1 end
		f.SetScript = function(self, key, value) self.scripts[key] = value end
		f.GetScript = function(self, key) return self.scripts[key] end
		f.SetAttribute = function(self, key, value) self.attributes[key] = value end
		f.IsEnabled = function(self) return self.enabled end
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

	-- Blizzard gates Talents, Legacy, Group Finder and the Shop on a level 1
	-- character. `/click` on a disabled button does nothing, so the entry must grey
	-- out rather than look live and swallow the press.
	local gated = module.buttons[1]
	check(gated.ref:IsEnabled(), "native button starts enabled")
	check(gated:IsEnabled(), "its entry starts enabled")

	-- A per-feature gate (Legacy below renown 1, Talents before the first talent
	-- point) disables the button while the keybind still reaches the feature, because
	-- the binding calls the toggle directly. Those are lifted so the cog can do what
	-- the key does. `commandName` is how a button says it has such a binding.
	gated.ref.commandName = "TOGGLELEGACYSYSTEM"
	gated.ref:Disable()
	module:UpdateButtons()
	check(gated.ref:IsEnabled(), "a feature-gated native button is re-enabled")
	check(gated:IsEnabled(), "so its entry stays usable")

	-- A full-screen frame disables the whole strip and the keybinds with it. That
	-- gate is Blizzard's to keep.
	env.MICRO_BUTTONS_DISABLED = true
	gated.ref:Disable()
	module:UpdateButtons()
	check(not gated.ref:IsEnabled(), "the full-screen gate is left alone")
	check(not gated:IsEnabled(), "and the entry greys out with it")
	env.MICRO_BUTTONS_DISABLED = nil

	-- A button with no binding command has no other route in, so it stays greyed.
	gated.ref.commandName = nil
	gated.ref:Disable()
	module:UpdateButtons()
	check(not gated:IsEnabled(), "an entry with no binding command greys out")
	gated.ref:Enable()
	module:UpdateButtons()
	check(gated:IsEnabled(), "and comes back when Blizzard re-enables it")

	env.MicroMenu.GenerateButtonInfos = function() return {} end
	module.toggle = nil
	module:SpawnButtons()
	check(#module.buttons == 0 and module.toggle == nil, "empty native menu safely omitted")
end

-- Restricted execution (secure handler snippets).
--
-- Retail decides by whether a snippet actually ran. Forever's known-broken restricted
-- environment must select the fallback without executing a probe.
do
	local function probeClient(interface, marker, restrictedAddOnLoaded, snippetRuns, saved)
		local env = setmetatable({}, { __index = _G })
		env._G = env
		env.WOW_PROJECT_MAINLINE = 1
		env.WOW_PROJECT_ID = 1
		env.GetBuildInfo = function() return "1.60.1", "69913", "Sep 2026", interface end
		env.C_AddOns = {
			GetAddOnMetadata = function() return marker end,
			IsAddOnLoaded = function(name)
				return name == "Blizzard_RestrictedAddOnEnvironment" and restrictedAddOnLoaded or false
			end
		}
		local probe = { attributes = {} }
		probe.Hide = function() end
		probe.SetAttribute = function(self, key, value)
			self.attributes[key] = value
			if (key ~= "state-azsnippetprobe") then return end

			-- The real client answers a `state-<id>` write by running `_onstate-<id>`.
			-- When it cannot build the closure the error unwinds back out through
			-- SetAttribute into the caller, which is what this reproduces - and what
			-- aborted Core/Client.lua on Forever 1.60.1.69913 before it was pcall'ed.
			if (not snippetRuns) then
				error("RestrictedExecution.lua:79: attempt to call a nil value", 0)
			end
			self.AzeriteUI_SecureSnippetProbe()
		end
		env.CreateFrame = function() return probe end
		env.AzeriteUI5_DB = saved

		local ns = {}
		run("Core/Private.lua", env, ns)
		run("Core/Client.lua", env, ns)
		return ns, probe
	end

	local ns = probeClient(120100, nil, false, false)
	check(ns.HasSecureSnippets == true, "clients without the Lua restricted environment are not probed")

	local working, probe = probeClient(120100, nil, true, true)
	check(working.HasSecureSnippets == true, "a snippet that runs reports available")
	check(probe.attributes["_onstate-azsnippetprobe"], "the probe installs a snippet body")

	-- Retail probe errors must remain contained, and its cache is valid only for the
	-- build that created it. A stale "available" answer would disable every fallback.
	local cachedOff = probeClient(120100, nil, true, true, { global = { secureSnippets = {
		build = "69913", available = false } } })
	check(cachedOff.HasSecureSnippets == false, "a matching cache is used instead of probing")
	check(cachedOff.SecureSnippetsFromCache == true, "and says so")

	local staleBuild = probeClient(120100, nil, true, true, { global = { secureSnippets = {
		build = "00000", available = false } } })
	check(staleBuild.HasSecureSnippets == true, "a cache from another build is ignored")
	check(staleBuild.SecureSnippetsFromCache == false, "and re-probes")

	local junk = probeClient(120100, nil, true, true, { global = { secureSnippets = { build = "69913" } } })
	check(junk.HasSecureSnippets == true and junk.SecureSnippetsFromCache == false,
		"a cache entry with no boolean answer is ignored")

	local brokenRetail = probeClient(120100, nil, true, false)
	check(brokenRetail.HasSecureSnippets == false, "a raising Retail probe reports unavailable")
	check(type(brokenRetail.API) == "table" and type(brokenRetail.API.IsEventAvailable) == "function",
		"a raising Retail probe does not abort the rest of Core/Client.lua")

	local brokenForever, foreverProbe = probeClient(16001, "Forever", true, false)
	check(brokenForever.HasSecureSnippets == false and brokenForever.SecureSnippetsKnownUnavailable,
		"Forever selects the fallback without running a probe")
	check(not foreverProbe.attributes["_onstate-azsnippetprobe"],
		"Forever never installs the erroring probe snippet")
end
-- Action bar paging, with and without restricted execution.
--
-- Executes the real prototype file. What matters is that the page driver arrives
-- already numeric where no snippet can resolve symbols, that each button gets its own
-- `action` driver so casts survive combat, and that no `_onstate-*` body is installed
-- on a client that would raise on it.
for _, snippets in ipairs({true, false}) do
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.InCombatLockdown = function() return false end
	env.NUM_ACTIONBAR_BUTTONS = 12
	env.BOTTOMLEFT_ACTIONBAR_PAGE, env.BOTTOMRIGHT_ACTIONBAR_PAGE = 6, 5
	env.RIGHT_ACTIONBAR_PAGE, env.LEFT_ACTIONBAR_PAGE = 4, 3
	env.LEAVE_VEHICLE = "Leave Vehicle"
	env.C_ActionBar = {
		GetVehicleBarIndex = function() return 12 end,
		GetTempShapeshiftBarIndex = function() return 13 end,
		GetOverrideBarIndex = function() return 14 end
	}
	env.LibStub = function() return {} end

	local stateDrivers, attributeDrivers = {}, {}
	env.RegisterStateDriver = function(frame, state, values) stateDrivers[frame] = stateDrivers[frame] or {}; stateDrivers[frame][state] = values end
	env.UnregisterStateDriver = function(frame, state) if stateDrivers[frame] then stateDrivers[frame][state] = nil end end
	env.RegisterAttributeDriver = function(frame, name, values) attributeDrivers[frame] = attributeDrivers[frame] or {}; attributeDrivers[frame][name] = values end
	env.UnregisterAttributeDriver = function(frame, name) if attributeDrivers[frame] then attributeDrivers[frame][name] = nil end end

	local ns = { Private = {} }
	setmetatable(ns, { __index = ns.Private })
	ns.Private.HasSecureSnippets = snippets
	ns.Private.IsRetail = true
	ns.Private.PlayerClass = "DRUID"
	ns.Private.API = { GetEffectiveScale = function() return 1 end,
		RegisterVisibilityDriver = function(frame, driver)
			env.RegisterStateDriver(frame, "visibility", driver)
			return true
		end }
	ns.Merge = function(_, a) return a end
	ns.ButtonBar = { prototype = {}, defaults = {} }
	run("Components/ActionBars/Prototypes/ActionBar.lua", env, ns)

	local buttons = {}
	local bar = setmetatable({ id = 1, buttons = buttons, config = { enabled = true,
		visibility = { possess = false, overridebar = false, vehicleui = false, dragon = false, mounted = true } } },
		{ __index = ns.ActionBar.prototype })
	bar.SetAttribute = function() end
	bar.GetAttribute = function() end
	for i = 1, 12 do
		buttons[i] = { id = i }
	end

	bar:UpdateStateDriver()
	bar:UpdateVisibilityDriver()

	local page = stateDrivers[bar] and stateDrivers[bar].page
	check(type(page) == "string", "bar 1 registers a page driver")

	-- The symbols are the driver's *values*, so match the space before them:
	-- "[possessbar] possess" is symbolic, "[possessbar] 12" is not.
	if (snippets) then
		check(page:find("] possess", 1, true) and page:find("] dragon", 1, true),
			"symbolic page driver retained where snippets compile")
		check(attributeDrivers[buttons[1]] == nil, "no per-button action driver where snippets compile")
		check(stateDrivers[bar].vis ~= nil, "custom vis state retained where snippets compile")
	else
		check(not page:find("] possess", 1, true) and not page:find("] dragon", 1, true),
			"page driver carries no symbol a snippet would have to resolve")
		check(page:find("[overridebar] 14", 1, true), "override bar index resolved from the client")
		check(page:find("[possessbar] 12", 1, true), "vehicle bar index resolved from the client")
		check(page:find("[shapeshift] 13", 1, true), "temp shapeshift index resolved from the client")
		check(page:find("[bonusbar:4] 10", 1, true), "class bonus bars retained")

		-- Slot = (page - 1) * 12 + button id, the same arithmetic LAB uses per state.
		local third = attributeDrivers[buttons[3]] and attributeDrivers[buttons[3]].action
		check(type(third) == "string", "each button drives its own action attribute")
		check(third:find("[bonusbar:1] 75", 1, true), "bonus bar slot for button 3 on page 7")
		check(third:find("[bar:2] 15", 1, true), "page 2 slot for button 3")

		check(stateDrivers[bar].vis == nil, "custom vis state not used without snippets")
		check(stateDrivers[bar].visibility ~= nil, "native visibility state used instead")

		-- A bar that never pages must not add drivers to Blizzard's throttled rescan.
		local static = setmetatable({ id = 5, buttons = { { id = 1 } }, config = bar.config },
			{ __index = ns.ActionBar.prototype })
		static.SetAttribute = function() end
		static.GetAttribute = function() end
		static:UpdateStateDriver()
		check(stateDrivers[static].page == "5", "a non-paging bar drives its own page number")
		check(attributeDrivers[static.buttons[1]] == nil, "a non-paging bar registers no action driver")
	end
end

print("Client compatibility: " .. checks .. " checks passed")

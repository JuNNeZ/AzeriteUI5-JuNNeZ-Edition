-- Automatic input detection with explicit ownership-change confirmation.
-- Loads the real controller, native ownership coordinator, prompt and options.
-- Simulated clock/events/AceDB isolate policy from WoW; this does not certify
-- hardware attribution, engine permissions, native reloads, rendering or taint.
-- lua Tools/Harness/input_style_harness.lua . [mutation]

local root = (arg and arg[1]) or "."
local mutation = arg and arg[2]
local checks, failures, worlds = 0, 0, {}
local COORDINATOR = "Components/ActionBars/Compatibility/HandleGamepadUI.lua"
local CONTROLLER = "Components/ActionBars/Compatibility/HandleInputStyle.lua"
local PROMPT = "Components/ActionBars/Compatibility/InputStylePrompt.lua"
local function check(value, message)
	checks = checks + 1
	if (not value) then failures = failures + 1; print("FAIL: " .. message) end
end
local function scenario(name, callback)
	local ok, problem = pcall(callback)
	check(ok, name .. (ok and "" or ": " .. tostring(problem)))
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
local controllerSource
local function loadReal(world, path)
	local source = path == CONTROLLER and controllerSource or read(path)
	local chunk = assert(loadstring(source, "@" .. path))
	setfenv(chunk, world.env)
	chunk("AzeriteUI5_JuNNeZ_Edition", world.ns)
end

local function newWorld(config)
	config = config or {}
	local w = { modules = {}, order = {}, namespaces = {}, addons = copy(config.addons or {}),
		style = config.style or 0, cvar = tostring(config.style or 0), combat = false,
		time = 10, ids = {}, mapped = {}, stickNames = { "Camera", "Movement" }, moving = false,
		keys = {}, bindings = { MOVEFORWARD = { "W", "UP" }, MOVEBACKWARD = { "S", "DOWN" },
			STRAFELEFT = { "A" }, STRAFERIGHT = { "D" }, TURNLEFT = { "LEFT" }, TURNRIGHT = { "RIGHT" } },
		usingGamepad = false, usingMouse = false,
		timers = {}, writes = {}, reloads = 0, forbiddenCalls = {}, unauthorizedWrites = 0,
		unauthorizedReloads = 0, setterMode = "pending", logs = {}, frames = {}, addonQueries = 0 }
	worlds[#worlds + 1] = w
	local env = setmetatable({}, { __index = _G }); env._G = env; w.env = env
	local function forbidden(name)
		return function()
			w.forbiddenCalls[#w.forbiddenCalls + 1] = name
			error("unexpected protected/native operation: " .. name, 2)
		end
	end
	w.secret = setmetatable({}, { __tostring = forbidden("secret formatting"), __concat = forbidden("secret concatenation") })
	env.issecretvalue = function(value) return rawequal(value, w.secret) end
	env.Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
	env.C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = forbidden("native action storage"),
		GetFirstGamepadPetActionStorageSlotIndex = forbidden("native pet storage") }
	env.C_InputInterfaceStyle = { GetCurrentStyle = function()
		if (w.styleError) then error("style unavailable") end
		return w.style
	end }
	env.C_GamePad = {
		IsEnabled = function() return w.gamepadEnabled ~= false end,
		GetAllDeviceIDs = function() if (w.devicesError) then error("enumeration unavailable") end; return w.ids end,
		GetActiveDeviceID = function() return w.activeDeviceID or 5 end,
		GetDeviceRawState = forbidden("raw state used as physical-device count"),
		GetDeviceMappedState = function(id)
			if (w.mappedError) then error("mapped unavailable") end
			local state = w.mapped[id]
			if (type(state) == "table" and not rawequal(state, w.secret) and type(state.sticks) == "table"
				and not rawequal(state.sticks, w.secret) and state.stickCount == nil) then state.stickCount = #state.sticks end
			return state
		end,
		StickIndexToConfigName = function(index) return w.stickNames[index + 1] end
	}
	env.IsPlayerMoving = function() return w.moving end
	env.GetCurrentKeyBoardFocus = function() return w.focus end
	env.GetBindingKey = function(command) return unpack(w.bindings[command] or {}) end
	env.IsKeyDown = function(key, physical)
		assert(physical == true, "keyboard movement must check physical key state")
		if (w.keyError == key) then error("key inaccessible") end
		if (w.keyUnknown == key) then return nil end
		if (w.keySecret == key) then return w.secret end
		return w.keys[key] == true
	end
	env.IsAltKeyDown = function() return w.alt == true end
	env.IsControlKeyDown = function() return w.control == true end
	env.IsShiftKeyDown = function() return w.shift == true end
	env.IsUsingGamepad = function() return w.usingGamepad end
	env.IsUsingMouse = function() return w.usingMouse end
	env.InCombatLockdown = function() if (w.combatError) then error("combat unavailable") end; return w.combat end
	env.GetTime = function() return w.time end
	env.GetTimePreciseSec = env.GetTime
	env.time = function() return 1800000000 + math.floor(w.time) end
	env.GetCVar = function(name)
		assert(name == "InputDeviceInterfaceStyle", "unexpected CVar read")
		if (w.cvarError) then error("CVar unavailable") end
		return w.cvar
	end
	local function setter(name, value)
		assert(name == "InputDeviceInterfaceStyle", "unexpected CVar write")
		if (not w.allowWrite) then w.unauthorizedWrites = w.unauthorizedWrites + 1 end
		assert(w.allowWrite, "write without explicit user action")
		check(not w.combat, "writer never reaches SetCVar in combat")
		check(type(w.controller.db.char.request) == "table", "durable request marker exists before setter")
		check(w.coordinator.db.profile.enabled == (tonumber(value) == 1), "ownership preference is saved before CVar can reload natively")
		w.writes[#w.writes + 1] = { name = name, value = tonumber(value), time = w.time }
		if (w.setterMode == "error") then error("setter rejected") end
		if (w.setterMode == "false") then return false end
		if (w.setterMode == "no-effect") then return true end
		if (w.setterMode == "blocked" or w.setterMode == "blocked-sync") then
			w:Fire("ADDON_ACTION_BLOCKED", "AzeriteUI5_JuNNeZ_Edition", "UNKNOWN()")
		end
		w.cvar = tostring(value)
		w:Fire("CVAR_UPDATE", name, w.cvar)
		if (w.setterMode == "sync" or w.setterMode == "blocked-sync") then
			local old = w.style; w.style = tonumber(value)
			w:Fire("INPUT_DEVICE_INTERFACE_TRANSITION", w.style, old)
		end
		if (w.duringWrite) then w.duringWrite() end
		return true
	end
	env.SetCVar = setter
	env.C_CVar = { GetCVar = env.GetCVar, SetCVar = setter }
	env.ReloadUI = function()
		if (not w.allowReload) then w.unauthorizedReloads = w.unauthorizedReloads + 1 end
		assert(w.allowReload, "reload without explicit user action")
		check(not w.combat, "reload never reaches ReloadUI in combat")
		check(type(w.controller.db.char.request) == "table", "durable request marker exists before explicit reload")
		check(w.coordinator.db.profile.enabled == (w.controller.db.char.request.target == "gamepad"), "explicit reload preserves matching target and saved owner")
		w.reloads = w.reloads + 1
		if (w.reloadMode == "error") then error("reload rejected") end
		if (w.reloadMode == "blocked") then w:Fire("ADDON_ACTION_BLOCKED", "AzeriteUI5_JuNNeZ_Edition", "ReloadUI()") end
	end
	local function timer(delay, callback)
		local handle = { at = w.time + delay, callback = callback }
		function handle:Cancel() self.cancelled = true end
		w.timers[#w.timers + 1] = handle
		return handle
	end
	env.C_Timer = { After = timer, NewTimer = timer, NewTicker = function(interval, callback)
		local handle = { at = w.time + interval, interval = interval, callback = callback }
		function handle:Cancel() self.cancelled = true end
		w.timers[#w.timers + 1] = handle
		return handle
	end }
	env.C_AddOns = { IsAddOnLoaded = function(name) return w.addons[name] == true end }
	env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) w.logs[#w.logs + 1] = message end }
	env.print = function(...) w.logs[#w.logs + 1] = { ... } end
	for _, name in ipairs({ "SetBinding", "SetBindingClick", "SaveBindings", "SetOverrideBinding",
		"SetOverrideBindingClick", "ClearOverrideBindings", "RegisterStateDriver", "UnregisterStateDriver",
		"RegisterAttributeDriver", "UnregisterAttributeDriver", "hooksecurefunc", "securecallfunction" }) do
		env[name] = forbidden(name)
	end
	local native = setmetatable({}, { __index = forbidden("native frame access"), __newindex = forbidden("native frame write") })
	env.MainActionBar, env.PetActionBar, env.GamepadMainActionBarFrame = native, native, native
	local benign = { "SetSize", "SetPoint", "SetFrameStrata", "EnableMouse", "SetAllPoints", "SetColorTexture",
		"SetTextColor", "SetJustifyH", "SetWidth", "SetHeight", "SetNormalFontObject", "SetHighlightFontObject",
		"RegisterForClicks", "SetClampedToScreen", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" }
	function w:Frame(kind, name, parent, template)
		assert(template == nil and name == nil, "prompt must not use secure templates or named globals")
		local frame = { scripts = {}, shown = true, parent = parent, kind = kind }
		for _, method in ipairs(benign) do frame[method] = function() end end
		function frame:SetScript(script, callback) self.scripts[script] = callback end
		function frame:SetText(text) self.text = text end
		function frame:GetText() return self.text end
		function frame:Show() self.shown = true end
		function frame:Hide() self.shown = false end
		function frame:IsShown() return self.shown end
		function frame:CreateFontString() return w:Frame("FontString", nil, self) end
		function frame:CreateTexture() return w:Frame("Texture", nil, self) end
		function frame:RegisterEvent() end
		function frame:SetAttribute() return forbidden("secure attribute")() end
		frame.EnableKeyboard = forbidden("keyboard capture")
		frame.EnableGamePadButton = forbidden("gamepad capture")
		w.frames[#w.frames + 1] = frame
		return frame
	end
	env.UIParent = {}
	env.CreateFrame = function(...) return w:Frame(...) end
	env.LibStub = function(name)
		assert(name == "AceLocale-3.0", "unexpected library: " .. name)
		return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
	end
	local ns = { IsForever = config.forever ~= false, API = {
		IsAddOnEnabled = function(name)
			w.addonQueries = w.addonQueries + 1
			return w.addons[name] == true
		end,
		IsEventAvailable = function(event) return not (config.missingEvents and config.missingEvents[event]) end
	} }
	w.ns = ns
	function ns:NewModule(name)
		local module = { name = name, events = {} }
		function module:GetName() return self.name end
		function module:GetDefaults() return self.defaults end
		function module:RegisterEvent(event, method) self.events[event] = method or "OnEvent" end
		function module:UnregisterEvent(event) self.events[event] = nil end
		function module:UnregisterAllEvents() self.events = {} end
		function module:Print(...) w.logs[#w.logs + 1] = { ... } end
		function module:DisableSettingsExport() self.settingsExportDisabled = true end
		w.modules[name] = module; w.order[#w.order + 1] = module
		return module
	end
	function ns:GetModule(name) return w.modules[name] end
	ns.db = { callbacks = {}, GetCurrentProfile = function() return w.profileName or "Default" end,
		RegisterNamespace = function(_, name, defaults)
		local db = copy(defaults or {}); db.profile = db.profile or {}; db.char = db.char or {}; db.callbacks = {}
		if (name == "GamepadUICompatibility") then db.profile.enabled = config.owner == true end
		if (name == "InputStyle") then
			if (config.enabled ~= nil) then db.profile.enabled = config.enabled end
			if (config.workflowVersion ~= false) then db.profile.workflowVersion = config.workflowVersion or 2 end
			if (config.saved) then db.char = copy(config.saved) end
		end
		function db.RegisterCallback(receiver, event, method)
			db.callbacks[event] = { receiver = receiver, method = method or event }
		end
		w.namespaces[name] = db
		return db
	end }
	function ns.db.RegisterCallback(receiver, event, method)
		ns.db.callbacks[event] = { receiver = receiver, method = method or event }
	end
	function w:Fire(event, ...)
		for _, module in ipairs(self.order) do
			local method = module.events[event]
			if (type(method) == "string") then module[method](module, event, ...)
			elseif (method) then method(module, event, ...) end
		end
	end
	function w:Advance(seconds, includeCancelled)
		local target, count = self.time + seconds, 0
		while (true) do
			local chosen
			for index, handle in ipairs(self.timers) do
				if (handle.at <= target and (not chosen or handle.at < self.timers[chosen].at)) then chosen = index end
			end
			if (not chosen) then break end
			local handle = table.remove(self.timers, chosen); self.time = handle.at
			if (not handle.cancelled or includeCancelled) then handle.callback(handle) end
			if (handle.interval and not handle.cancelled) then
				handle.at = self.time + handle.interval; self.timers[#self.timers + 1] = handle
			end
			count = count + 1; assert(count < 1000, "unbounded timer loop")
		end
		self.time = target
	end
	function w:Profile(event, profile)
		if (profile) then self.controller.db.profile = copy(profile) end
		local handler = self.ns.db.callbacks[event]
		assert(handler, "missing profile callback " .. event)
		if (type(handler.method) == "string") then handler.receiver[handler.method](handler.receiver, event)
		else handler.method(handler.receiver, event) end
	end
	function w:Apply()
		self.allowWrite = true
		local ok, result = pcall(self.controller.ApplySuggested, self.controller)
		self.allowWrite = false
		assert(ok, result); return result
	end
	function w:Reload()
		self.allowReload = true
		local ok, result = pcall(self.controller.ReloadPending, self.controller)
		self.allowReload = false
		assert(ok, result); return result
	end
	function w:Gamepad()
		self.ids, self.usingGamepad, self.usingMouse = { 1, 5 }, true, false
		self.moving = true
		self.mapped[1] = { sticks = { { len = 0 }, { len = .8 } } }
		self.mapped[5] = copy(self.mapped[1])
		self:Fire("GAME_PAD_CONNECTED")
		self:Fire("GAME_PAD_ACTIVE_CHANGED", true)
	end
	function w:Neutral()
		self.moving, self.keys = false, {}
		self.usingGamepad, self.usingMouse = false, false
		for _, id in ipairs(self.ids or {}) do self.mapped[id] = { sticks = { { len = 0 }, { len = 0 } } } end
	end
	function w:Keyboard(key)
		self:Neutral(); self.moving = true; self.keys[key or "W"] = true
	end
	function w:PromptFrame()
		for _, frame in ipairs(self.frames) do if (frame.yes and frame.no) then return frame end end
	end
	function w:Click(yes)
		local frame = assert(self:PromptFrame(), "no prompt frame")
		local button = yes and frame.yes or frame.no
		self.allowWrite, self.allowReload = yes, yes
		local ok, problem = pcall(button.scripts.OnClick, button, "LeftButton")
		self.allowWrite, self.allowReload = false, false
		assert(ok, problem)
	end
	function w:Shown() return self.ns.InputStylePrompt.IsShown() end
	function w:WaitPrompt() self:Advance(1) end
	function w:Save()
		return { owner = self.coordinator.db.profile.enabled, style = tonumber(self.cvar),
			enabled = self.controller.db.profile.enabled, saved = copy(self.controller.db.char) }
	end
	if (config.configure) then config.configure(w, env) end
	loadReal(w, COORDINATOR); loadReal(w, PROMPT)
	local showPrompt = ns.InputStylePrompt.Show
	ns.InputStylePrompt.Show = function(target, accept, decline, message)
		w.promptAccept, w.promptDecline = accept, decline
		return showPrompt(target, accept, decline, message)
	end
	loadReal(w, CONTROLLER)
	w.coordinator, w.controller = assert(ns.GamepadUICompatibility), assert(ns.InputStyle)
	w.coordinator:OnInitialize(); w.controller:OnInitialize()
	if (config.beforeEnable) then config.beforeEnable(w) end
	if (not config.deferEnable) then w.coordinator:OnEnable(); w.controller:OnEnable() end
	return w
end

controllerSource = read(CONTROLLER)
if (mutation) then
	local mutations = {
		["default-off"] = { { 'enabled = true, suspended = false', 'enabled = false, suspended = false' } },
		["no-walking-gate"] = { { 'and Read(IsPlayerMoving) == true', '' } },
		["owner-after-setter"] = {
			{ 'ownerProfile.enabled = Owner(target)', '' },
			{ 'if (ConfiguredStyle() ~= target) then ok = pcall(Setter(), CVAR, EnumValue(target)) end',
				'if (ConfiguredStyle() ~= target) then ok = pcall(Setter(), CVAR, EnumValue(target)) end\n\townerProfile.enabled = Owner(target)' }
		},
		["reverse-keeps-native-owner"] = { { 'local function Owner(target) return target == "gamepad" end',
			'local function Owner(target) return true end' } },
		["no-combat-guard"] = { { 'return OutOfCombat() and self:GetSuggestedStyle() ~= nil',
			'return self:GetSuggestedStyle() ~= nil' } },
		["auto-write"] = { { 'InputStyle.SampleInput = function(self)',
			'InputStyle.SampleInput = function(self)\n\tpcall(SetCVar, "InputDeviceInterfaceStyle", 1)' } },
		["no-conflict-cache"] = { { 'not force and self.conflictValid and', 'not force and false and' } }
	}
	for _, change in ipairs(assert(mutations[mutation], "unknown mutation: " .. mutation)) do
		local first, last = controllerSource:find(change[1], 1, true)
		assert(first, "mutation anchor not found: " .. mutation)
		controllerSource = controllerSource:sub(1, first - 1) .. change[2] .. controllerSource:sub(last + 1)
	end
end

scenario("default workflow detects walking without preconfiguring native bars", function()
	local w = newWorld()
	check(w.controller:IsEnabledSetting(), "movement detection defaults enabled")
	check(not w.coordinator:IsActive() and not w.coordinator.db.profile.enabled, "initial session keeps Azerite bars")
	check(w.controller:GetCurrentStyle() == "mnk", "initial native style is MnK")
	check(not w:Shown(), "login does not prompt just because feature is enabled")
	w:Gamepad(); w:WaitPrompt()
	check(w:Shown() and w.controller:GetSuggestedStyle() == "gamepad", "walking with controller automatically presents Gamepad confirmation")
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled,
		"detection and prompt do not write style or ownership before Yes")
	check(w:PromptFrame().message.text:find("Blizzard controller bars", 1, true), "prompt explains native Gamepad handoff and reload")
end)

scenario("Yes roundtrip changes saved owner before style and reload", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt(); w:Click(true)
	check(#w.writes == 1 and w.writes[1].value == 1 and w.reloads == 1, "Yes writes Gamepad and explicitly reloads once")
	check(w.coordinator.db.profile.enabled == true and not w.coordinator:IsActive(), "saved native owner changes while current owner stays frozen")
	check(w.controller:GetCurrentStyle() == "mnk", "pending CVar does not impersonate effective Gamepad style")
	check(type(w.controller.db.char.request) == "table", "handoff receipt survives reload")
	w:Advance(1); w:Click(true); w:Reload()
	check(#w.writes == 1 and w.reloads == 1 and not w:Shown(), "already-issued reload cannot repeat before Lua session restarts")
	local after = newWorld(w:Save())
	check(after.coordinator:IsActive() and after.controller:GetCurrentStyle() == "gamepad", "next session starts native bars with effective Gamepad style")
	check(after.coordinator.gamepadMode == true, "coordinator recognizes style after reload")
	check(#after.writes == 0 and after.reloads == 0 and not after:Shown(), "startup reconciles without replaying handoff")
	after:Keyboard("W"); after:WaitPrompt()
	check(after:Shown() and after.controller:GetSuggestedStyle() == "mnk", "actual keyboard movement automatically offers Azerite bars")
	check(after:PromptFrame().message.text:find("AzeriteUI action bars", 1, true), "reverse prompt explains restoration of Azerite bars")
	after:Click(true)
	check(after.coordinator.db.profile.enabled == false and after.coordinator:IsActive(), "reverse Yes saves Azerite owner without live transfer")
	check(#after.writes == 1 and after.writes[1].value == 0 and after.reloads == 1, "reverse Yes writes MnK and reloads once")
	local returned = newWorld(after:Save())
	check(not returned.coordinator:IsActive() and returned.controller:GetCurrentStyle() == "mnk", "next session restores Azerite bars and MnK")
	check(#returned.writes == 0 and returned.reloads == 0, "roundtrip startup never replays writes")
end)

scenario("migration enables new workflow once and respects later opt out", function()
	local w = newWorld({ enabled = false, workflowVersion = false })
	check(w.controller:IsEnabledSetting() and w.controller.db.profile.workflowVersion == 2,
		"old assisted default-off setting migrates to automatic detection")
	check(not w.coordinator.db.profile.enabled and #w.writes == 0 and w.reloads == 0,
		"migration does not hand off bars, write CVar or reload")
	w.controller:SetEnabled(false); w.controller:UpdateSettings(); w.controller:OnDisable(); w.controller:OnEnable()
	w:Gamepad(); w:WaitPrompt()
	check(not w.controller:IsEnabledSetting() and not w:Shown(), "explicit opt out after migration survives refresh/re-enable")
	w = newWorld({ enabled = false, workflowVersion = 2 }); w:Gamepad(); w:WaitPrompt()
	check(not w:Shown() and #w.writes == 0, "current-version saved opt out is respected")
end)

scenario("connection and logical IDs alone do not trigger handoff", function()
	local w = newWorld({ beforeEnable = function(world) world.ids = { 1, 5 } end })
	w:Advance(3)
	check(not w:Shown(), "connected login alone never prompts")
	w:Fire("GAME_PAD_CONNECTED"); w:Fire("GAME_PAD_ACTIVE_CHANGED", true); w:Advance(3)
	check(not w:Shown() and #w.writes == 0, "connection/activity flags alone are insufficient without walking")
	w:Gamepad(); w:WaitPrompt()
	check(w:Shown(), "one physical device represented by two IDs still produces one prompt")
	local count = 0; for _, frame in ipairs(w.frames) do if (frame.yes and frame.no) then count = count + 1 end end
	check(count == 1, "logical aliases cannot allocate duplicate prompts")
end)

scenario("only mapped Movement stick while walking qualifies", function()
	local w = newWorld(); w.ids = { 1 }
	w.moving = true; w.mapped[1] = { sticks = { { len = 1 }, { len = 0 } } }
	w:Advance(2)
	check(not w:Shown(), "Camera stick during autorun is not controller walking")
	w.mapped[1] = { sticks = { { len = 0 }, { len = .24 } } }; w:Advance(2)
	check(not w:Shown(), "observed .24 drift does not trigger prompt")
	w.moving = false; w.mapped[1] = { sticks = { { len = 0 }, { len = .9 } }, buttons = { true } }; w:Advance(2)
	check(not w:Shown(), "button/stick without player movement does not trigger prompt")
	w.moving = true; w:WaitPrompt()
	check(w:Shown(), "mapped second Movement stick plus walking triggers prompt")
	w = newWorld(); w.ids = { 1 }; w.stickNames = { "Movement", "Camera" }
	w.moving = true; w.mapped[1] = { sticks = { { len = .9 }, { len = 0 } } }; w:WaitPrompt()
	check(w:Shown(), "different mapping with Movement first also works")
end)

scenario("keyboard detection uses movement bindings and ignores chat", function()
	for _, key in ipairs({ "W", "A", "S", "D", "UP", "LEFT", "RIGHT" }) do
		local w = newWorld({ owner = true, style = 1 }); w:Keyboard(key); w:WaitPrompt()
		check(w:Shown() and w.controller:GetSuggestedStyle() == "mnk", key .. " actual bound movement prompts return")
		check(w.coordinator:IsActive() and w.coordinator.db.profile.enabled and #w.writes == 0,
			key .. " observation keeps native ownership until Yes")
	end
	local w = newWorld({ owner = true, style = 1 })
	w:Keyboard("W"); w.focus = {}; w:Advance(2)
	check(not w:Shown(), "typing movement keys in focused chat does not trigger handoff")
	w.focus = nil; w.moving = false; w:Advance(2)
	check(w:Shown(), "bound physical movement intent can return to Azerite even when blocked by terrain")
	w = newWorld({ owner = true, style = 1 })
	w.keys = {}; w.moving = true; w.usingMouse = true; w:Fire("GLOBAL_MOUSE_DOWN", "LeftButton"); w:Advance(2)
	check(not w:Shown(), "mouse navigation/autorun does not trigger keyboard handoff")
	w.bindings.MOVEFORWARD = { "R" }; w:Keyboard("W"); w:Advance(2)
	check(not w:Shown(), "old unbound W is ignored after remapping")
	w:Keyboard("R"); w:WaitPrompt()
	check(w:Shown(), "remapped physical movement key triggers handoff")
end)

scenario("modifier bindings and non-keyboard tokens are filtered", function()
	local w = newWorld({ owner = true, style = 1 })
	w.bindings = { MOVEFORWARD = { "CTRL-R" } }; w:Keyboard("R"); w:Advance(2)
	check(not w:Shown(), "base key without required modifier cannot match")
	w.control, w.keys.LCTRL, w.keys.RCTRL = true, true, false; w:WaitPrompt()
	check(w:Shown(), "required control modifier permits bound physical key")
	w = newWorld({ owner = true, style = 1 })
	w.bindings = { MOVEFORWARD = { "R" } }; w:Keyboard("R"); w.shift = true; w.keys.LSHIFT = true; w:Advance(2)
	check(not w:Shown(), "extra modifier does not accidentally match unmodified binding")
	w = newWorld({ owner = true, style = 1 })
	w.bindings = { MOVEFORWARD = { "PAD1", "BUTTON1" }, STRAFELEFT = { "CTRL-PAD2", "SHIFT-BUTTON2" } }
	w.moving = true; w.keys = { PAD1 = true, BUTTON1 = true, PAD2 = true, BUTTON2 = true }; w.control, w.shift = true, true
	w:Advance(2)
	check(not w:Shown(), "PAD and mouse bindings never classify as physical keyboard movement")
end)

scenario("No preserves settings and suppresses the held episode", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt(); w:Click(false)
	check(not w:Shown() and not w.coordinator.db.profile.enabled, "No dismisses without changing saved bar owner")
	check(#w.writes == 0 and w.reloads == 0, "No neither writes CVar nor reloads")
	w:Advance(8)
	check(not w:Shown(), "same continuously held stick does not reopen after cooldown")
	w:Neutral(); w:Advance(.5); w:Gamepad(); w:WaitPrompt()
	check(w:Shown(), "new walking episode after neutral and cooldown can prompt")
	w:Click(false); w:Neutral(); w:Advance(.5); w:Gamepad(); w:Advance(.5)
	check(not w:Shown(), "new episode still respects cooldown")
end)

scenario("last-disconnect tolerance and Bluetooth reconnection", function()
	local w = newWorld({ owner = true, style = 1, beforeEnable = function(world) world.ids = { 1, 5 } end })
	w.ids = { 5 }; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(2)
	check(not w:Shown(), "remaining logical ID prevents last-device disconnect inference")
	w.ids = {}; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(1.4)
	check(not w:Shown(), "last disconnect waits for stability")
	w.ids = { 9 }; w:Fire("GAME_PAD_CONNECTED"); w:Advance(.5)
	check(not w:Shown(), "quick Bluetooth reconnect cancels absence candidate")
	w.ids = {}; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(2)
	check(w:Shown() and w.controller:GetSuggestedStyle() == "mnk", "stable total disconnect prompts return despite stale active ID")
	w:Click(false); w:Advance(8)
	check(not w:Shown(), "No on absence is not repeated while still absent")
	w.ids = { 11 }; w:Fire("GAME_PAD_CONNECTED"); w:Advance(.2)
	w.ids = {}; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(2)
	check(w:Shown(), "new disconnect episode can prompt again")
end)

scenario("combat hides prompts and discards stale movement", function()
	local w = newWorld(); w.combat = true; w:Fire("PLAYER_REGEN_DISABLED"); w:Gamepad(); w:Advance(2)
	check(not w:Shown() and #w.writes == 0 and w.reloads == 0, "combat never shows prompt or changes UI settings")
	w:Neutral(); w:Advance(.5); w.combat = false; w:Fire("PLAYER_REGEN_ENABLED"); w:Advance(1)
	check(not w:Shown(), "ended movement cannot replay an obsolete combat candidate")
	w:Gamepad(); w:WaitPrompt(); check(w:Shown(), "fresh out-of-combat walking prompts")
	w.combat = true; w:Fire("PLAYER_REGEN_DISABLED")
	check(not w:Shown(), "entering combat hides existing confirmation")
	w:Click(true)
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled, "stale Yes callback cannot write in combat")
	w.combat = false; w:Fire("PLAYER_REGEN_ENABLED"); w:WaitPrompt()
	check(w:Shown(), "still-valid latest movement can prompt after combat")
end)

scenario("controller apply is combat guarded independently of prompt", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	w.combat = true
	w:Apply()
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled,
		"direct controller or options accept cannot bypass combat guard")
end)

scenario("dialog has click-release debounce and retains hardware callback", function()
	local w = newWorld()
	w.controller:OnDisable()
	local accepted, declined = 0, 0
	w.ns.InputStylePrompt.Show("gamepad", function() accepted = accepted + 1 end, function() declined = declined + 1 end)
	w:Click(true); check(accepted == 0, "held click released as prompt opens is ignored")
	w:Advance(.31); w:Click(true)
	check(accepted == 1, "Yes directly invokes accept after brief guard")
	w:Click(false); check(declined == 1 and not w:Shown(), "No directly dismisses and calls decline")
	w.combat = true
	check(not w.ns.InputStylePrompt.Show("mnk", function() end, function() end), "prompt refuses to show in combat")
end)

scenario("changing profile or disabling invalidates outstanding prompt", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	w.profileName = "Other"; w:Profile("OnProfileChanged", { enabled = true, suspended = false, workflowVersion = 2 })
	check(not w:Shown(), "profile switch hides old profile prompt")
	w:Click(true)
	check(#w.writes == 0 and w.reloads == 0, "stale callback cannot apply old profile handoff")
	w:Neutral(); w:Advance(.2); w:Gamepad(); w:WaitPrompt(); w.controller:SetEnabled(false)
	check(not w:Shown(), "feature opt out hides prompt")
	w:Advance(3, true); w:Click(true)
	check(#w.writes == 0 and not w.coordinator.db.profile.enabled, "disabled generation cannot resurrect or apply handoff")
end)

scenario("accept rechecks connected devices and conflicting writers", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	w.ids = {}; w:Click(true)
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled, "unseen disconnection invalidates Gamepad Yes")
	w = newWorld(); w:Gamepad(); w:WaitPrompt(); w.addons.GamePadReadySet = true; w:Click(true)
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled, "late writer conflict invalidates Yes")
	w = newWorld({ owner = true, style = 1 }); w:Keyboard("W"); w:WaitPrompt()
	w.addons.GamePadReadySet = true; w:Fire("ADDON_LOADED", "GamePadReadySet")
	check(not w:Shown() and w.coordinator:IsActive(), "writer conflict hides prompt but preserves current native owner")
end)

scenario("loaded GamePadReadySet remains conflicting until next reload", function()
	for _, legacy in ipairs({ false, true }) do
		local w = newWorld({ configure = function(world, env)
			local loaded = function(name) return name == "GamePadReadySet" end
			if (legacy) then env.C_AddOns = nil; env.IsAddOnLoaded = loaded else env.C_AddOns.IsAddOnLoaded = loaded end
		end })
		check(w.controller:GetConflict() == "GamePadReadySet", "loaded writer detected independently of enable preference")
		w:Gamepad(); w:Advance(2)
		check(not w:Shown() and #w.writes == 0 and w.reloads == 0, "loaded writer prevents autonomous prompt")
	end
end)

scenario("polling and repeated getters reuse the addon conflict snapshot", function()
	local w = newWorld()
	w.controller:GetConflict(); w.addonQueries = 0
	local function burst()
		for _ = 1, 100 do
			w.controller:SampleInput()
			w.controller:GetState(); w.controller:GetSuggestedStyle(); w.controller:CanApply()
			w.controller:CanReload(); w.controller:GetConflict()
		end
	end
	burst()
	check(w.addonQueries <= 4, "100 same-time samples and UI getter bursts require at most one four-addon scan")
	w.addonQueries = 0; w:Advance(1.1)
	check(w.addonQueries > 0 and w.addonQueries <= 4, "10 Hz polling refreshes conflict snapshot only once after about one second")
	for interval = 1, 3 do
		w.time = w.time + 1.01; w.addonQueries = 0; burst()
		check(w.addonQueries > 0 and w.addonQueries <= 4,
			"expired snapshot interval " .. interval .. " costs at most four enabled-addon queries across 100 samples")
	end
	w.addons.ConsolePort = true
	w.controller:UpdateSettings()
	check(w.controller:GetConflict() == "ConsolePort", "settings refresh invalidates same-time conflict cache")
	w.addons.ConsolePort = nil; w.controller:UpdateSettings()
	w.addons.Bartender4 = true; w:Fire("ADDON_LOADED", "Bartender4")
	check(w.controller:GetConflict() == "Bartender4", "addon-load event invalidates same-time conflict cache")
	check(#w.writes == 0 and w.reloads == 0, "cache maintenance never writes UI state")
end)

scenario("explicit Yes freshly checks rival enabled or loaded inside cache TTL", function()
	for _, loadedOnly in ipairs({ false, true }) do
		local w = newWorld({ configure = function(world, env)
			world.loadedAddons = {}
			env.C_AddOns.IsAddOnLoaded = function(name) return world.loadedAddons[name] == true end
		end })
		w:Gamepad(); w:WaitPrompt(); w.controller:GetConflict()
		if (loadedOnly) then w.loadedAddons.GamePadReadySet = true else w.addons.GamePadReadySet = true end
		-- No elapsed time or ADDON_LOADED: the mutator must bypass a clean cache.
		w:Click(true)
		check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled,
			"Yes freshly rejects " .. (loadedOnly and "loaded" or "enabled") .. " style writer before any effect")
	end
end)

scenario("explicit pending reload freshly checks rival inside cache TTL", function()
	for _, loadedOnly in ipairs({ false, true }) do
		local w = newWorld({ configure = function(world, env)
			world.loadedAddons = {}
			env.C_AddOns.IsAddOnLoaded = function(name) return world.loadedAddons[name] == true end
		end })
		w.reloadMode = "blocked"; w:Gamepad(); w:WaitPrompt(); w:Click(true)
		check(w.reloads == 1 and #w.writes == 1, "fixture starts with one failed explicit reload")
		w.controller:GetConflict(); w.reloadMode = nil
		if (loadedOnly) then w.loadedAddons.GamePadReadySet = true else w.addons.GamePadReadySet = true end
		w:Reload()
		check(w.reloads == 1 and #w.writes == 1,
			"pending reload freshly rejects " .. (loadedOnly and "loaded" or "enabled") .. " style writer without effect")
	end
end)

scenario("rejected writes roll back saved owner and never retry", function()
	for _, mode in ipairs({ "error", "false", "no-effect" }) do
		local w = newWorld(); w.setterMode = mode; w:Gamepad(); w:WaitPrompt(); w:Click(true)
		check(not w.coordinator.db.profile.enabled and not w.coordinator:IsActive(), mode .. " restores previous owner after unchanged CVar")
		check(w.style == 0 and w.cvar == "0" and w.reloads == 0, mode .. " never reloads unchanged failed write")
		w:Advance(8)
		check(#w.writes == 1 and w.reloads == 0, mode .. " has no timer retry")
	end
	local w = newWorld({ owner = true, style = 1 }); w.setterMode = "no-effect"
	w:Keyboard("W"); w:WaitPrompt(); w:Click(true)
	check(w.coordinator.db.profile.enabled == true and w.coordinator:IsActive(), "failed reverse write restores previous native owner")
	check(w.cvar == "1" and w.reloads == 0, "failed reverse write does not reload into mixed ownership/style")
end)

scenario("blocked CVar mutation is not declared applied", function()
	local w = newWorld(); w.setterMode = "blocked"; w:Gamepad(); w:WaitPrompt(); w:Click(true)
	check(w.controller:GetCurrentStyle() == "mnk" and w.cvar == "1", "effective getter exposes blocked style/CVar divergence")
	check(w.controller.db.char.request.status == "failed", "synchronous engine block persists as failure")
	check(not w.coordinator:IsActive(), "blocked write cannot transfer current-session bars")
	w:Advance(8)
	check(#w.writes == 1, "blocked attempt never retries from polling")
end)

scenario("effective style already target still hands off owner with reload", function()
	local w = newWorld({ style = 1, owner = false }); w:Gamepad(); w:WaitPrompt()
	check(w:Shown(), "Gamepad style with Azerite owner still offers required ownership change")
	w:Click(true)
	check(w.coordinator.db.profile.enabled == true and not w.coordinator:IsActive(), "saved owner changes while active owner stays fixed")
	check(#w.writes == 0 and w.reloads == 1, "matching CVar avoids redundant write but still reloads for owner")
	w = newWorld({ style = 0, owner = true }); w:Keyboard("W"); w:WaitPrompt(); w:Click(true)
	check(w.coordinator.db.profile.enabled == false and w.coordinator:IsActive(), "reverse matching style still restores saved Azerite owner")
	check(#w.writes == 0 and w.reloads == 1, "reverse owner-only transition reloads once")
end)

scenario("missing or inaccessible observations fail closed", function()
	local w = newWorld(); w.devicesError = true; w.moving = true; w:Advance(2)
	check(not w:Shown(), "unknown inventory is not absence or connected control")
	w.devicesError = false; w.ids = w.secret; w:Advance(2)
	check(not w:Shown(), "secret inventory does not trigger prompt")
	w.ids = { 1 }; w.mapped[1] = w.secret; w:Advance(2)
	check(not w:Shown(), "secret mapped state does not trigger prompt")
	w.mapped[1] = { sticks = { { len = 0 }, { len = w.secret } } }; w:Advance(2)
	check(not w:Shown(), "secret stick magnitude does not trigger prompt")
	w.mappedError = true; w:Advance(2)
	check(not w:Shown() and #w.writes == 0, "mapped read error does not trigger prompt")
	w = newWorld({ forever = false }); w:Gamepad(); w:Advance(2)
	check(not w:Shown() and #w.writes == 0 and w.reloads == 0, "Retail has no Forever ownership prompts")
end)

scenario("an unmapped logical ID does not hide another valid movement state", function()
	local w = newWorld(); w.ids = { 1, 5 }; w.moving = true
	w.mapped[5] = { sticks = { { len = 0 }, { len = .9 } } }
	w:WaitPrompt()
	check(w:Shown(), "valid mapped movement on second logical ID is detected")
	check(#w.writes == 0 and not w.coordinator.db.profile.enabled, "multi-ID movement remains confirmation only")
end)

scenario("profile and generation changes cancel unstable input", function()
	local w = newWorld(); w:Gamepad(); w:Advance(.2)
	w.controller:UpdateSettings(); w:Neutral(); w:Advance(.5, true)
	check(not w:Shown(), "old candidate timer cannot prompt after settings reset and neutral input")
	w:Gamepad(); w:Advance(.2); w.controller:OnDisable(); w:Advance(1, true)
	check(not w:Shown(), "disabled ticker/candidate cannot display stale prompt")
	check(#w.writes == 0 and w.reloads == 0, "cancelled generation has no mutation side effects")
end)

scenario("opposite physical movement invalidates a latched suggestion", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	w:Neutral(); w.usingMouse = true; w:Advance(1)
	check(w:Shown(), "neutral stick and mouse navigation retain latched prompt for clicking")
	w:Keyboard("W"); w.moving = false; w:Advance(.5)
	check(not w:Shown(), "new physical movement intent cancels obsolete Gamepad suggestion")
	check(#w.writes == 0 and w.reloads == 0, "opposite input never applies by itself")
	w = newWorld({ owner = true, style = 1 }); w:Keyboard("W"); w:WaitPrompt()
	w.keys = {}; w:Gamepad(); w:Advance(.5)
	check(not w:Shown(), "new controller walking cancels obsolete return-to-Azerite suggestion")
end)

scenario("physical movement key wins over simultaneous stick movement", function()
	local w = newWorld({ owner = true, style = 1 }); w:Gamepad(); w.keys.W = true; w:WaitPrompt()
	check(w:Shown() and w.controller:GetSuggestedStyle() == "mnk", "keyboard priority handles simultaneous mapped stick activity")
	w = newWorld(); w:Gamepad(); w.keys.W = true; w:WaitPrompt()
	check(not w:Shown(), "simultaneous keyboard input does not leave currently correct Azerite owner")
end)

scenario("unknown keyboard focus and intermittent enumeration fail closed", function()
	local w = newWorld({ owner = true, style = 1, configure = function(_, env)
		env.GetCurrentKeyBoardFocus = function() error("focus inaccessible") end
	end })
	w:Keyboard("W"); w:Advance(2)
	check(not w:Shown(), "unreadable keyboard focus cannot classify keyboard movement")
	w = newWorld({ owner = true, style = 1, beforeEnable = function(world) world.ids = { 1, 5 } end })
	w.devicesError = true; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(2)
	check(not w:Shown(), "unknown enumeration never implies disconnect")
	w.devicesError = false; w.ids = {}; w:Fire("GAME_PAD_DISCONNECTED"); w:Advance(2)
	check(w:Shown(), "confirmed absence after unknown read retains last known connection for disconnect detection")
end)

scenario("unknown modifier reads cannot match unmodified movement binding", function()
	for _, field in ipairs({ "keyUnknown", "keyError", "keySecret" }) do
		local w = newWorld({ owner = true, style = 1 }); w:Keyboard("W"); w[field] = "LCTRL"
		w:Advance(2)
		check(not w:Shown(), field .. " cannot be treated as definitely released modifier")
		check(#w.writes == 0 and w.reloads == 0, field .. " keeps style unchanged")
	end
end)

scenario("Yes rejects a profile change that races its callback", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	w.profileName = "ChangedBeforeEvent"
	w:Click(true)
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled,
		"Yes revalidates prompt profile even before profile callback arrives")
end)

scenario("failed explicit reload preserves pending pair for manual retry", function()
	local w = newWorld(); w.reloadMode = "blocked"; w:Gamepad(); w:WaitPrompt(); w:Click(true)
	check(#w.writes == 1 and w.reloads == 1 and w.coordinator.db.profile.enabled and w.cvar == "1",
		"reload failure preserves written target and owner for explicit recovery")
	check(w.controller.db.char.request.status == "failed" and w.controller:GetCurrentStyle() == "mnk",
		"failed reload keeps truthful effective style and failed receipt")
	check(w:PromptFrame().error.text ~= "reload" and type(w:PromptFrame().error.text) == "string"
		and #w:PromptFrame().error.text > 10, "reload failure is rendered as a user-facing message")
	w:Advance(5)
	check(#w.writes == 1 and w.reloads == 1, "polling cannot retry blocked reload")
	w.reloadMode = nil; w:Click(true)
	check(#w.writes == 1 and w.reloads == 2, "pending Yes retries reload without another CVar write")
end)

scenario("workflow reload reconciles owner with configured style", function()
	local w = newWorld()
	w.coordinator.db.profile.enabled = true
	w.controller:UpdateSettings()
	check(w.cvar == "0" and w.style == 0 and not w.coordinator:IsActive(), "fixture has MnK with pending native ownership preference")
	check(w.controller:GetPendingStyle() == "mnk" and w.controller:CanReload(), "workflow recovery exposes configured MnK target")
	w:Reload()
	check(w.coordinator.db.profile.enabled == false and not w.coordinator:IsActive(), "workflow recovery pairs MnK with saved Azerite ownership")
	check(#w.writes == 0 and w.reloads == 1, "owner-only recovery reloads exactly once without redundant CVar write")
	check(w.controller.db.char.request.target == "mnk" and w.controller.db.char.request.profile == "Default",
		"recovery receipt records target and selected profile before reload")
	w:Reload(); check(w.reloads == 1, "same recovery cannot reload twice before new session")
end)

scenario("stale prompt generations and pending profile callbacks cannot apply", function()
	local w = newWorld(); w:Gamepad(); w:WaitPrompt()
	local oldAccept = assert(w.promptAccept)
	w:Click(false); w:Neutral(); w:Advance(6); w:Gamepad(); w:WaitPrompt()
	check(w:Shown() and w.promptAccept ~= oldAccept, "new episode produces a fresh same-target accept closure")
	w.allowWrite, w.allowReload = true, true
	oldAccept()
	w.allowWrite, w.allowReload = false, false
	check(#w.writes == 0 and w.reloads == 0 and not w.coordinator.db.profile.enabled,
		"previous episode's queued accept cannot act on a newer same-target prompt")
	w:Click(true)
	check(#w.writes == 1 and w.reloads == 1, "current episode's explicit Yes remains usable")
	w = newWorld(); w.setterMode = "blocked"; w:Gamepad(); w:WaitPrompt(); w:Click(true)
	local oldRecovery = assert(w.promptAccept)
	w.profileName = "Other"
	w:Profile("OnProfileChanged", { enabled = true, suspended = false, workflowVersion = 2 })
	w.allowWrite, w.allowReload = true, true
	oldRecovery()
	w.allowWrite, w.allowReload = false, false
	check(#w.writes == 1 and w.reloads == 0, "pending old-profile callback cannot reload selected new profile")
end)

local function optionsFor(w)
	local options = w.ns:NewModule("Options")
	function options:AddGroup(_, generator) self.generator = generator end
	function options:CloseOptionsMenu() w.closedOptions = true end
	w.optionBindings, w.keybinds = {}, 0
	w.ns.OptionsKit = { Defaults = { Bind = function(group, namespace) w.optionBindings[group] = namespace end } }
	local oldLibStub = w.env.LibStub
	w.env.LibStub = function(name)
		if (name == "LibKeyBound-1.0") then return { Toggle = function() w.keybinds = w.keybinds + 1 end } end
		return oldLibStub(name)
	end
	local quest = w.ns:NewModule("QuestItemButton")
	quest.db = { profile = { enabled = true, useExtraActionKey = true, trackedOnly = false } }
	function quest:IsStandingDown() return false end
	function quest:HasRival() return false end
	function quest:UpdateSettings() w.questUpdates = (w.questUpdates or 0) + 1 end
	loadReal(w, "Options/OptionsPages/ActionBars.lua")
	return assert(options.generator())
end

local function noInputMenuGroups(page)
	for key, option in pairs(page and page.args or {}) do
		if (key == "gamepadUI" or key == "inputStyle") then return false end
		if (type(option) == "table" and not noInputMenuGroups(option)) then return false end
	end
	return true
end

scenario("removed options do not affect automatic detection or quest settings", function()
	local w = newWorld()
	local page = optionsFor(w)
	check(noInputMenuGroups(page), "Azerite session omits both removed menu groups")
	check(w.controller:IsEnabledSetting() and not w.coordinator.db.profile.enabled,
		"removing menu groups preserves default runtime detection and initial Azerite ownership")
	for _, namespace in pairs(w.optionBindings) do
		check(namespace ~= "InputStyle" and namespace ~= "GamepadUICompatibility", "removed menu preferences have no Defaults binding")
	end
	check(page.args.questItemButton ~= nil and page.args.keybindMode ~= nil, "quest settings and Keybind Mode remain reachable")
	check(w.optionBindings[page.args.questItemButton] == "QuestItemButton", "quest Defaults keeps its independent namespace")
	local quest = page.args.questItemButton.args
	quest.trackedOnly.set({ "trackedOnly" }, true)
	check(quest.trackedOnly.get({ "trackedOnly" }) and w.questUpdates == 1, "quest settings retain independent behavior")
	w:Gamepad(); w:WaitPrompt()
	check(w:Shown(), "automatic prompt still works without either removed menu group")
	w:Click(false)
	check(not w:Shown() and #w.writes == 0 and w.reloads == 0, "prompt No remains available independently of settings")
end)

scenario("real native-session options retain quest key ownership", function()
	local w = newWorld({ owner = true, style = 1 })
	local page = optionsFor(w)
	check(noInputMenuGroups(page), "native Gamepad session omits both removed menu groups")
	check(w.optionBindings[page.args.questItemButton] == "QuestItemButton", "native quest Defaults binding is retained")
	local quest = page.args.questItemButton.args
	check(quest.useExtraActionKey.disabled(), "native owner preserves native extra-action binding")
	quest.useExtraActionKey.set({ "useExtraActionKey" }, false)
	check(quest.useExtraActionKey.get({ "useExtraActionKey" }), "unavailable key borrowing cannot alter saved preference")
	w.combat = true; page.args.keybindMode.func()
	check(w.keybinds == 0, "Keybind Mode remains blocked in combat")
	w.combat = false; page.args.keybindMode.func()
	check(w.keybinds == 1 and w.closedOptions, "Keybind Mode remains functional with native action bars")
	for _, config in ipairs({ { owner = true, style = 0 }, { forever = false } }) do
		local other = newWorld(config)
		local otherPage = optionsFor(other)
		check(noInputMenuGroups(otherPage), "native MnK and Retail also omit both removed menu groups")
		check(otherPage.args.questItemButton ~= nil and otherPage.args.keybindMode ~= nil,
			"native MnK and Retail retain independent quest and keybind controls")
	end
end)

scenario("load order makes prompt available before detection starts", function()
	local xml = read("Components/ActionBars/ActionBars.xml")
	local coordinator = assert(xml:find("Compatibility\\HandleGamepadUI.lua", 1, true))
	local prompt = assert(xml:find("Compatibility\\InputStylePrompt.lua", 1, true))
	local controller = assert(xml:find("Compatibility\\HandleInputStyle.lua", 1, true))
	local quarantine = assert(xml:find("Compatibility\\HideBlizzard.lua", 1, true))
	check(coordinator < controller and prompt < controller and controller < quarantine,
		"XML orders native coordinator and prompt before input controller, then quarantine")
end)

for index, world in ipairs(worlds) do
	check(world.unauthorizedWrites == 0, "world " .. index .. " has no CVar attempt outside explicit Yes")
	check(world.unauthorizedReloads == 0, "world " .. index .. " has no reload outside explicit Yes")
	check(#world.forbiddenCalls == 0, "world " .. index .. " avoids protected frames, bindings, input capture and raw device filtering")
end
print(string.format("input_style: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

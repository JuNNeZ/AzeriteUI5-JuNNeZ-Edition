-- Offline contract tests for the standalone, manually installed input-style probe.
-- Loads the real addon in isolated Lua 5.1 environments; does not run WoW.
-- Secret sentinels catch accidental formatting, not engine taint/secret behavior.
-- lua Tools/Harness/input_style_probe_harness.lua . [mutation]

local root = (arg and arg[1]) or "."
local sourcePath = "Tools/Diagnostics/AzeriteUI_InputProbe/Probe.lua"
local checks, failures = 0, 0
local mutation = arg and arg[2]
local worlds = {}
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
	return source:gsub("\r\n", "\n")
end
local source = read(sourcePath)
if (mutation) then
	local mutations = {
		["auto-write"] = { 'self:Record("COLLECTION_START")', 'self:Record("COLLECTION_START"); pcall(SetCVar, CVAR, 1)' },
		["no-combat-guard"] = { 'if combat ~= false then return false, combat == true and "combat" or "unknown-combat" end', '' },
		["ignore-generation"] = { 'if generation ~= self.generation then return end', '' }
	}
	local change = assert(mutations[mutation], "unknown mutation: " .. mutation)
	local first, last = source:find(change[1], 1, true)
	assert(first, "mutation anchor not found: " .. mutation)
	source = source:sub(1, first - 1) .. change[2] .. source:sub(last + 1)
end
local function copy(value)
	if (type(value) ~= "table") then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end
scenario("diagnostic package is isolated from production", function()
	for _, path in ipairs({ "AzeriteUI5_JuNNeZ_Edition.toc", "AzeriteUI5_JuNNeZ_Edition_Camelot.toc",
		"Components/Components.xml", "Components/ActionBars/ActionBars.xml", "Core/Core.xml", "Core/DebugLoader.lua" }) do
		local manifest = read(path)
		check(not manifest:find("InputProbe", 1, true), path .. " does not load diagnostic addon")
	end
	check(read(".pkgmeta"):match("\n%s*%-%s+Tools%s*\n"), "release packaging excludes Tools")
	local toc = read("Tools/Diagnostics/AzeriteUI_InputProbe/AzeriteUI_InputProbe.toc")
	check(toc:find("## SavedVariables: AzeriteUI_InputProbeDB", 1, true), "standalone TOC declares private SavedVariable")
	check(toc:find("Probe.lua", 1, true), "standalone TOC loads probe")
end)

local function newWorld(config)
	config = config or {}
	local world = {
		style = 0, cvar = "0", combat = false, time = 10, ids = {}, mapped = {},
		usingGamepad = false, usingMouse = true, writes = {}, timers = {}, frames = {},
		secretFormats = 0, logs = {}, setterMode = "apply", unauthorizedWrites = 0, forbiddenCalls = {}
	}
	worlds[#worlds + 1] = world
	local function forbidden(name)
		return function()
			world.forbiddenCalls[#world.forbiddenCalls + 1] = name
			error("unexpected protected/native operation: " .. name, 2)
		end
	end
	local env = setmetatable({}, { __index = _G })
	env._G = env
	world.env, world.ns = env, {}
	world.secret = setmetatable({}, {
		__tostring = function() world.secretFormats = world.secretFormats + 1; error("secret formatted") end,
		__concat = function() world.secretFormats = world.secretFormats + 1; error("secret concatenated") end,
		__lt = function() error("secret compared") end,
		__le = function() error("secret compared") end
	})
	env.issecretvalue = function(value) return rawequal(value, world.secret) end
	env.tostring = function(value)
		if (rawequal(value, world.secret)) then world.secretFormats = world.secretFormats + 1; error("secret formatted") end
		return tostring(value)
	end
	env.Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
	env.C_InputInterfaceStyle = { GetCurrentStyle = function()
		if (world.styleError) then error("style unavailable") end
		return world.style
	end }
	env.C_GamePad = {
		IsEnabled = function() return world.gamepadEnabled ~= false end,
		GetAllDeviceIDs = function()
			if (world.devicesError) then error("device enumeration unavailable") end
			return world.ids
		end,
		GetDeviceMappedState = function(id)
			if (world.mappedError) then error("device state unavailable") end
			return world.mapped[id]
		end,
		GetDeviceRawState = function(id) return world.mapped[id] end,
		GetActiveDeviceID = function() return world.ids[1] end
	}
	env.IsUsingGamepad = function() return world.usingGamepad end
	env.IsUsingMouse = function() return world.usingMouse end
	env.InCombatLockdown = function()
		if (world.combatError) then error("combat unavailable") end
		return world.combat
	end
	env.GetTime = function() return world.time end
	env.GetTimePreciseSec = env.GetTime
	env.time = function() return 1800000000 + math.floor(world.time) end
	env.GetBuildInfo = function() return "1.60.1", "70938", "test", 16001 end
	env.GetLocale = function() return "enUS" end
	env.GetCVar = function(name)
		assert(name == "InputDeviceInterfaceStyle", "unexpected CVar read")
		if (world.cvarError) then error("CVar unavailable") end
		return world.cvar
	end
	local function setCVar(name, value)
		assert(name == "InputDeviceInterfaceStyle", "unexpected CVar write")
		if (not world.allowWrite) then world.unauthorizedWrites = world.unauthorizedWrites + 1 end
		assert(world.allowWrite == true, "CVar write without explicit test authorization")
		check(world.probe.db.pending ~= nil, "request marker exists before SetCVar")
		world.writes[#world.writes + 1] = { name = name, value = value }
		if (world.setterMode == "error") then error("blocked mock setter") end
		if (world.setterMode == "false") then return false end
		if (world.setterMode == "nil") then return nil end
		if (world.setterMode == "true-no-effect") then return true end
		if (world.setterMode == "cvar-until-reload" or world.setterMode == "blocked-with-cvar") then
			if (world.setterMode == "blocked-with-cvar") then
				world.probe:OnEvent("ADDON_ACTION_BLOCKED", "AzeriteUI_InputProbe", "UNKNOWN()")
			end
			world.cvar = tostring(value)
			world.probe:OnEvent("CVAR_UPDATE", name, world.cvar)
			world.probe:OnEvent("GAME_PAD_CONFIGS_CHANGED")
			return true
		end
		local old = world.style
		world.style, world.cvar = tonumber(value), tostring(value)
		if (world.setterMode == "sync") then
			world.probe:OnEvent("INPUT_DEVICE_INTERFACE_TRANSITION", world.style, old)
			if (world.duringTransition) then world.duringTransition() end
		end
		if (world.setterMode == "apply-false") then return false end
		return nil
	end
	env.SetCVar = setCVar
	env.C_CVar = { GetCVar = env.GetCVar, SetCVar = setCVar }
	env.C_Timer = {
		After = function(delay, callback)
			world.timers[#world.timers + 1] = { delay = delay, callback = callback }
		end,
		NewTimer = function(delay, callback)
			local timer = { delay = delay, callback = callback }
			function timer:Cancel() self.cancelled = true end
			world.timers[#world.timers + 1] = timer
			return timer
		end
	}
	env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) world.logs[#world.logs + 1] = message end }
	env.print = function(message) world.logs[#world.logs + 1] = message end
	env.C_AddOns = {
		IsAddOnLoaded = function() return false end,
		GetAddOnEnableState = function() return 0 end
	}
	for _, name in ipairs({ "SetBinding", "SetBindingClick", "SaveBindings", "SetOverrideBinding",
		"SetOverrideBindingClick", "ClearOverrideBindings", "RegisterStateDriver", "UnregisterStateDriver",
		"RegisterAttributeDriver", "UnregisterAttributeDriver", "hooksecurefunc", "securecallfunction", "ReloadUI" }) do
		env[name] = forbidden(name)
	end
	local native = setmetatable({}, { __index = function(_, key) error("native frame access: " .. tostring(key)) end,
		__newindex = forbidden("native frame write") })
	env.MainActionBar, env.PetActionBar, env.GamepadMainActionBarFrame = native, native, native
	local benignMethods = {
		"SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetFrameStrata",
		"SetFrameLevel", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "RegisterForClicks",
		"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFontObject", "SetFont", "SetTextColor",
		"SetColorTexture",
		"SetJustifyH", "SetJustifyV", "SetTextInsets", "SetMultiLine", "SetAutoFocus", "SetMaxLetters",
		"HighlightText", "SetFocus", "ClearFocus", "SetScrollChild", "SetNormalFontObject", "SetHighlightFontObject",
		"SetPushedTextOffset", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetToplevel"
	}
	function world:Frame(kind, name, parent)
		local frame = { kind = kind, name = name, parent = parent, events = {}, scripts = {}, shown = true }
		for _, method in ipairs(benignMethods) do frame[method] = function() end end
		function frame:RegisterEvent(event)
			if (config.rejectedEvents and config.rejectedEvents[event] == "error") then error("unknown event") end
			if (config.rejectedEvents and config.rejectedEvents[event] == "false") then return false end
			self.events[event] = true
			return true
		end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:UnregisterAllEvents() self.events = {} end
		function frame:SetScript(event, callback) self.scripts[event] = callback end
		function frame:GetScript(event) return self.scripts[event] end
		function frame:SetText(text) self.text = text end
		function frame:GetText() return self.text or "" end
		function frame:Show() self.shown = true end
		function frame:Hide() self.shown = false end
		function frame:IsShown() return self.shown end
		function frame:Enable() self.enabled = true end
		function frame:Disable() self.enabled = false end
		function frame:SetEnabled(value) self.enabled = value end
		function frame:GetName() return self.name end
		function frame:GetParent() return self.parent end
		function frame:SetParent(value) self.parent = value end
		function frame:CreateFontString() return world:Frame("FontString", nil, self) end
		function frame:CreateTexture() return world:Frame("Texture", nil, self) end
		frame.SetAttribute = forbidden("SetAttribute")
		frame.Execute = forbidden("secure Execute")
		frame.WrapScript = forbidden("secure WrapScript")
		world.frames[#world.frames + 1] = frame
		return frame
	end
	env.UIParent = world:Frame("Frame", "UIParent")
	if (config.ui ~= false) then env.CreateFrame = function(...) return world:Frame(...) end
	else env.CreateFrame = false end
	if (config.saved ~= nil) then env.AzeriteUI_InputProbeDB = config.saved end
	if (config.configure) then config.configure(world, env) end
	local originalKeys = {}
	for key in pairs(env) do originalKeys[key] = true end
	local chunk = assert(loadstring(source, "@" .. sourcePath))
	setfenv(chunk, env)
	chunk("AzeriteUI_InputProbe", world.ns)
	world.probe = assert(world.ns.InputProbe, "private ns.InputProbe exposed")
	world.probe:Initialize()
	function world:Flush()
		local timers = self.timers
		self.timers = {}
		for _, timer in ipairs(timers) do
			if (not timer.cancelled) then timer.callback() end
		end
	end
	function world:Leaks()
		for key in pairs(self.env) do
			check(originalKeys[key] or key == "AzeriteUI_InputProbeDB", "no global leak: " .. tostring(key))
		end
	end
	function world:Write(kind)
		self.allowWrite = true
		local ok, result = self.probe:RequestTest(kind)
		self.allowWrite = false
		return ok, result
	end
	return world
end

scenario("initialization and observational paths", function()
	local w = newWorld()
	local p = w.probe
	check(p.db.schema == 1, "DB schema initialized")
	check(p.db == w.env.AzeriteUI_InputProbeDB, "private DB is declared SavedVariable")
	check(not p.collecting, "collection initially disabled")
	local session = p.db.session
	p:Initialize()
	check(p.db.session == session, "Initialize idempotent")
	p:Start()
	check(p.collecting, "Start enables observation")
	for _, event in ipairs({ "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED",
		"PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do p:OnEvent(event) end
	p:OnEvent("GAME_PAD_ACTIVE_CHANGED", true)
	p:OnEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
	p:OnEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
	p:OnEvent("GLOBAL_MOUSE_UP", "LeftButton")
	p:OnEvent("MODIFIER_STATE_CHANGED", "LCTRL", 1)
	p:Sample()
	for _, frame in ipairs(w.frames) do if (frame.scripts.OnUpdate) then frame.scripts.OnUpdate(frame, 1) end end
	w:Flush()
	check(#w.writes == 0, "observation and timers never write style")
	local report = p:GetReport()
	check(type(report) == "string" and #report > 0, "report is exportable text")
	check(report:find("GAME_PAD_CONNECTED", 1, true), "report includes events without payload")
	check(report:lower():find("session", 1, true), "report includes session identity")
	check(report:find("INPUT_DEVICE_INTERFACE_TRANSITION", 1, true), "report includes transition")
	p:Stop()
	check(not p.collecting, "Stop disables collection")
	w:Leaks()
end)

scenario("event registration evidence survives in reports", function()
	local w = newWorld({ rejectedEvents = { GAME_PAD_CONNECTED = "error", GAME_PAD_CONFIGS_CHANGED = "false" } })
	local events = w.probe.db.sessionInfo.events
	check(events.GAME_PAD_CONNECTED == false, "throwing event registration is reported unavailable")
	check(events.GAME_PAD_CONFIGS_CHANGED == false, "refused event registration is reported unavailable")
	check(events.INPUT_DEVICE_INTERFACE_TRANSITION == true, "accepted event registration is reported available")
	check(w.probe:GetReport():find("GAME_PAD_CONNECTED=false", 1, true), "absence of a supported event is distinguishable from registration failure")
	check(#w.writes == 0, "unsupported event registration never causes writes")
end)

scenario("style is distinct from input activity", function()
	local w = newWorld({ ui = false })
	w.probe:Start()
	w.usingGamepad, w.usingMouse = true, false
	w.probe:OnEvent("GAME_PAD_ACTIVE_CHANGED", true)
	w.probe:Sample()
	check(w.style == 0 and #w.writes == 0, "activity does not change actual style")
	check(w.probe:SelectTarget(0), "Mkb enum accepted")
	local ok, result = w:Write("click")
	check(result == "noop" and #w.writes == 0, "matching native style is no-op despite gamepad activity")
	check(w.probe:SelectTarget(1), "Gamepad enum accepted")
	check(not w.probe:SelectTarget(99), "unknown enum target rejected")
end)

scenario("UI actions reach explicit test and report paths", function()
	local w = newWorld()
	local function click(label)
		for _, frame in ipairs(w.frames) do
			if (frame.kind == "FontString" and frame.text == label and frame.parent.kind == "Button") then
				return frame.parent.scripts.OnClick(frame.parent, "LeftButton")
			end
		end
		error("UI button not found: " .. label)
	end
	click("Start")
	check(w.probe.collecting and #w.writes == 0, "Start UI only enables collection")
	click("Select Gamepad")
	check(w.probe.target == 1 and #w.writes == 0, "target UI selection does not write")
	w.allowWrite = true; click("Test click"); w.allowWrite = false
	check(#w.writes == 1 and w.style == 1, "explicit UI test reaches setter once")
	click("Prepare report (click text, Ctrl+A/C)")
	local prepared
	for _, frame in ipairs(w.frames) do if (frame.kind == "EditBox") then prepared = frame.text end end
	check(type(prepared) == "string" and prepared:find("TEST_RESULT", 1, true), "report UI exposes test evidence for copying")
	click("Stop")
	check(not w.probe.collecting, "Stop UI disables collection")
end)

scenario("synchronous transition and one explicit write", function()
	local w = newWorld()
	w.setterMode = "sync"
	w.probe:SelectTarget(1)
	local ok, result = w:Write("click")
	check(ok and result == "confirmed", "native getter confirms synchronous transition")
	check(#w.writes == 1, "synchronous transition cannot recursively write")
	check(w.probe.db.pending and w.probe.db.pending.status == "confirmed", "confirmed request retains durable reload receipt")
	check(not w.probe.inFlight, "durable receipt does not keep runtime request busy")
	check(w.probe.db.lastRequest.status == "confirmed", "confirmed request recorded")
	w.probe:SelectTarget(0)
	w:Write("click")
	check(#w.writes == 2 and w.style == 0, "subsequent explicit request not stuck inflight")
	local reloaded = newWorld({ ui = false, saved = copy(w.probe.db) })
	check(reloaded.probe.db.lastRequest.status == "recovered-match", "reload after successful setter consumes durable receipt")
	check(reloaded.probe.db.pending == nil and #reloaded.writes == 0, "successful receipt recovery never replays write")
	w:Leaks()
end)

for _, mode in ipairs({ "nil", "false", "true-no-effect", "error" }) do
	scenario("setter " .. mode .. " is not proof of success", function()
		local w = newWorld({ ui = false })
		w.setterMode = mode
		w.probe:SelectTarget(1)
		local ok, result = w:Write("click")
		check(result ~= "confirmed", mode .. " without effect not confirmed")
		check(w.probe.db.lastRequest.status ~= "confirmed", mode .. " request remains unconfirmed/error")
		check(#w.writes == 1 and w.style == 0, mode .. " attempted once")
		w.probe:Start(); w.probe:Sample(); w.probe:OnEvent("PLAYER_ENTERING_WORLD"); w:Flush()
		check(#w.writes == 1, mode .. " cannot retry from events or timers")
	end)
end

-- User-observed Forever 70938 sequence: accepted CVar write, old effective style,
-- then a new UI session with the requested style and no transition event in the log.
scenario("accepted CVar applies only after reload without transition event", function()
	local before = newWorld({ ui = false })
	before.setterMode = "cvar-until-reload"
	before.probe:Start()
	before.probe:SelectTarget(1)
	local ok, result = before:Write("click")
	check(ok and result == "unconfirmed", "accepted write does not claim immediate style application")
	check(before.cvar == "1" and before.style == 0, "CVar and effective style can temporarily disagree")
	check(before.probe.db.pending and before.probe.db.pending.status == "unconfirmed", "deferred application keeps recovery receipt")
	check(before.probe.db.lastRequest.setterResult == true, "setter success is recorded separately from effective style")
	local sawCVar, sawTransition = false, false
	for _, record in ipairs(before.probe.db.records) do
		if (record.event == "CVAR_UPDATE") then
			sawCVar = record.snapshot.cvar == "1" and record.snapshot.style == 0
		elseif (record.event == "INPUT_DEVICE_INTERFACE_TRANSITION") then sawTransition = true end
	end
	check(sawCVar and not sawTransition, "diagnosis does not require a transition event before reload")
	before.probe:Sample(); before:Flush()
	check(#before.writes == 1, "unconfirmed application cannot retry before reload")
	local after = newWorld({ ui = false, saved = copy(before.probe.db), configure = function(w)
		w.style, w.cvar = 1, "1"
	end })
	check(after.probe.db.lastRequest.status == "recovered-match", "getter confirms application in the new session")
	check(not after.probe.collecting and #after.writes == 0, "new session neither collects nor replays automatically")
	local timerOk, timerReason = after.probe:RequestTest("timer")
	check(not timerOk and timerReason == "target" and #after.timers == 0, "timer after reload requires explicit target selection")
	check(after.probe.db.lastRequest.status == "recovered-match", "skipped timer does not overwrite previous successful receipt")
	after.probe:SelectTarget(0)
	local scheduled, state = after.probe:RequestTest("timer")
	check(scheduled and state == "scheduled" and #after.writes == 0, "selecting MnK arms the explicit reverse-direction timer")
	after.allowWrite = true; after:Flush(); after.allowWrite = false
	check(#after.writes == 1 and after.style == 0, "explicit reverse timer attempts once after target selection")
end)

scenario("timer can report a blocked action despite successful CVar assignment", function()
	local w = newWorld({ ui = false })
	w.setterMode = "blocked-with-cvar"
	w.probe:Start(); w.probe:SelectTarget(1)
	local scheduled = w.probe:RequestTest("timer")
	check(scheduled and #w.writes == 0, "blocked timer scenario begins with explicit scheduling")
	w.allowWrite = true; w:Flush(); w.allowWrite = false
	check(#w.writes == 1 and w.cvar == "1" and w.style == 0, "blocked transition can still leave a changed CVar")
	check(w.probe.db.lastRequest.setterCalled and w.probe.db.lastRequest.setterResult == true,
		"setter success is preserved as evidence without implying effective change")
	check(w.probe.db.lastRequest.status == "unconfirmed", "blocked timer leaves actual mode unconfirmed")
	local blocked = false
	for _, record in ipairs(w.probe.db.records) do
		if (record.event == "ADDON_ACTION_BLOCKED") then
			blocked = record.details.addon == "AzeriteUI_InputProbe" and record.details.action == "UNKNOWN()"
		end
	end
	check(blocked, "action blocked remains in report even when setter returns true")
	for tick = 1, 6 do w.time = w.time + 1; w.probe:Sample(); w:Flush() end
	check(#w.writes == 1 and w.style == 0, "continued observation never retries or reverts a blocked transition")
end)

scenario("logical device IDs and concurrent activity remain observations", function()
	local w = newWorld({ ui = false, configure = function(world, env)
		env.C_GamePad.GetActiveDeviceID = function() return 5 end
		env.C_GamePad.GetDeviceRawState = function(id) if (id == 1) then return world.mapped[1] end end
	end })
	w.probe:Start(); w.probe:Sample()
	local empty = w.probe.db.records[#w.probe.db.records].snapshot
	check(empty.deviceCount == 0 and empty.activeDeviceID == 5, "active ID does not override empty enumeration")
	w.ids = { 1, 5 }
	local mapped = { buttonCount = 2, buttons = { true, false }, stickCount = 1, sticks = { { len = 1.14 } } }
	w.mapped[1], w.mapped[5] = mapped, mapped
	w.usingGamepad, w.usingMouse = true, true
	w.probe:OnEvent("GAME_PAD_ACTIVE_CHANGED", true)
	local active = w.probe.db.records[#w.probe.db.records].snapshot
	check(active.deviceCount == 2 and #active.devices == 2, "all logical IDs retained without deduplication assumptions")
	check(active.devices[1].rawState == "available" and active.devices[2].rawState == "unknown", "missing raw state does not erase an enumerated ID")
	check(active.devices[1].mappedButtons == 1 and active.devices[2].mappedButtons == 1, "identical mapped state remains evidence for both IDs")
	check(active.devices[1].maxStick > 1 and active.devices[2].maxStick > 1, "observed stick magnitude is not clamped to an assumed unit range")
	check(active.usingGamepad == true and active.usingMouse == true, "gamepad and mouse activity can coexist")
	check(active.style == 0 and #w.writes == 0, "concurrent activity does not imply a native style transition")
end)

scenario("getter takes precedence over setter return", function()
	local w = newWorld({ ui = false })
	w.setterMode = "apply-false"
	w.probe:SelectTarget(1)
	w:Write("click")
	check(w.probe.db.lastRequest.status == "confirmed", "applied style confirmed even with false setter result")
end)

scenario("one-shot timer and generation cancellation", function()
	local w = newWorld()
	w.probe:SelectTarget(1)
	local ok, result = w.probe:RequestTest("timer")
	check(ok and result == "scheduled" and #w.writes == 0, "timer is scheduled without immediate write")
	check(#w.timers == 1, "exactly one deferred test")
	w.allowWrite = true; w:Flush(); w.allowWrite = false
	check(#w.writes == 1 and w.style == 1, "deferred test writes exactly once")
	w:Flush()
	check(#w.writes == 1 and #w.timers == 0, "timer does not repeat itself")
	w.probe:SelectTarget(0); w.probe:RequestTest("timer"); w.probe:Stop(); w:Flush()
	check(#w.writes == 1, "Stop invalidates already scheduled test")
	w.probe:SelectTarget(0); w.probe:RequestTest("timer")
	local staleCallback = w.timers[#w.timers].callback
	w.probe:Stop()
	staleCallback()
	check(#w.writes == 1, "generation rejects stale callback even after timer cancellation")
	w:Flush()
	w.probe:SelectTarget(0); w.probe:RequestTest("timer"); w.probe:SelectTarget(1); w:Flush()
	check(#w.writes == 1, "changing target invalidates timer")
	w.probe:SelectTarget(0); w.probe:RequestTest("timer")
	local busy = w.probe:RequestTest("timer")
	check(not busy, "second timer rejected while one pending")
	w.probe:Stop(); w:Flush()
	check(#w.writes == 1, "cancelled test cannot leak a second callback")
end)

scenario("reload during synchronous transition retains recovery evidence", function()
	local before = newWorld({ ui = false })
	before.setterMode = "sync"
	before.probe:SelectTarget(1)
	local during
	before.duringTransition = function()
		during = copy(before.probe.db)
		check(during.pending ~= nil, "transition does not discard request before setter returns")
	end
	before:Write("click")
	local after = newWorld({ ui = false, saved = during, configure = function(w) w.style = 1 end })
	check(after.probe.db.lastRequest.status == "recovered-match", "reload inside synchronous transition reconciles request")
	check(#after.writes == 0 and after.probe.db.pending == nil, "mid-transition reload never repeats write")
end)

scenario("device evidence and malformed requests survive reload safely", function()
	local before = newWorld({ ui = false })
	before.ids = { 17 }
	before.mapped[17] = { buttonCount = 2, buttons = { true, false }, stickCount = 1, sticks = { { len = 0.75 } } }
	before.probe:Start(); before.probe:Sample()
	local recordIndex = #before.probe.db.records
	local original = before.probe.db.records[recordIndex].snapshot.devices[1]
	check(original.id == 17 and original.mappedButtons == 1 and original.maxStick == 0.75, "device sample captures useful evidence")
	local saved = copy(before.probe.db)
	local after = newWorld({ ui = false, saved = saved })
	local recovered = after.probe.db.records[recordIndex].snapshot.devices[1]
	check(type(recovered) == "table", "device evidence remains structured after reload")
	check(type(recovered) == "table" and recovered.id == 17 and recovered.mappedButtons == 1 and recovered.maxStick == 0.75,
		"device identity and mapped activity survive reload")
	local corrupt = newWorld({ saved = { schema = 1, lastRequest = { status = {} } } })
	check(type(corrupt.probe:GetReport()) == "string", "malformed saved request cannot break UI or report")
end)

scenario("combat blocks scheduling and callback", function()
	local w = newWorld({ ui = false })
	w.probe:SelectTarget(1)
	w.combat = true
	local clickOk = w.probe:RequestTest("click")
	local timerOk = w.probe:RequestTest("timer")
	check(not clickOk and not timerOk, "combat rejects click and timer")
	check(#w.timers == 0 and #w.writes == 0, "combat does not schedule work")
	w.combat = false
	w.probe:RequestTest("timer")
	w.combat = true
	w:Flush()
	check(#w.writes == 0, "combat beginning after scheduling blocks callback")
	w.combat = false
	w.probe:OnEvent("PLAYER_REGEN_ENABLED"); w:Flush()
	check(#w.writes == 0, "combat exit cannot replay rejected test")
end)

scenario("timer availability and errors fail closed", function()
	for _, timerMode in ipairs({ "missing", "nil", "error" }) do
		local w = newWorld({ ui = false, configure = function(_, env)
			if (timerMode == "missing") then env.C_Timer = nil
			else env.C_Timer.NewTimer = function() if (timerMode == "error") then error("timer unavailable") end end end
		end })
		w.probe:SelectTarget(1)
		local ok = w.probe:RequestTest("timer")
		check(not ok and #w.writes == 0, timerMode .. " timer cannot write")
		check(not w.probe.inFlight, timerMode .. " timer does not leave busy state")
		local clickOk = w:Write("click")
		check(clickOk and #w.writes == 1, timerMode .. " timer failure does not block subsequent explicit click")
	end
end)

scenario("native-like userdata timer is cancelled", function()
	local timerState
	local w = newWorld({ ui = false, configure = function(world, env)
		env.C_Timer.NewTimer = function(delay, callback)
			timerState = { delay = delay, callback = callback }
			local handle = newproxy(true)
			getmetatable(handle).__index = { Cancel = function() timerState.cancelled = true end }
			world.timers[#world.timers + 1] = timerState
			return handle
		end
	end })
	w.probe:SelectTarget(1)
	local ok = w.probe:RequestTest("timer")
	check(ok and type(w.probe.timer) == "userdata", "probe accepts native-like timer handle")
	w.probe:Stop()
	check(timerState.cancelled, "Stop calls Cancel on userdata timer")
	w:Flush()
	check(#w.writes == 0, "cancelled userdata timer never writes")
end)

local unavailableCases = {
	{ "missing style API", function(w, e) e.C_InputInterfaceStyle = nil end },
	{ "missing enums", function(w, e) e.Enum = nil end },
	{ "missing Mkb enum", function(w, e) e.Enum.InputDeviceInterfaceType.Mkb = nil end },
	{ "missing Gamepad enum", function(w, e) e.Enum.InputDeviceInterfaceType.Gamepad = nil end },
	{ "missing CVar", function(w) w.cvar = nil end },
	{ "empty CVar", function(w) w.cvar = "" end },
	{ "errored CVar", function(w) w.cvarError = true end },
	{ "errored style", function(w) w.styleError = true end },
	{ "unknown style", function(w) w.style = 42 end },
	{ "missing setter", function(w, e) e.SetCVar = nil; e.C_CVar.SetCVar = nil end },
	{ "missing combat API", function(w, e) e.InCombatLockdown = nil end },
	{ "nil combat", function(w) w.combat = nil end },
	{ "errored combat", function(w) w.combatError = true end }
}
for _, case in ipairs(unavailableCases) do
	scenario(case[1] .. " fails closed", function()
		local w = newWorld({ configure = case[2], ui = false })
		w.probe:Start(); w.probe:Sample()
		w.probe:SelectTarget(1)
		local ok = w.probe:RequestTest("click")
		check(not ok and #w.writes == 0, case[1] .. " rejects write")
		check(type(w.probe:GetReport()) == "string", case[1] .. " retains diagnostics")
	end)
end

scenario("device state uncertainty and no secret formatting", function()
	local w = newWorld({ ui = false })
	w.probe:Start()
	w.probe:Sample()
	check(w.probe.db.records[#w.probe.db.records].snapshot.deviceCount == 0, "successful empty enumeration means zero devices")
	local emptyReport = w.probe:GetReport()
	w.devicesError = true; w.time = w.time + 1; w.probe:Sample()
	local unknownReport = w.probe:GetReport()
	check(w.probe.db.records[#w.probe.db.records].snapshot.deviceCount == "unknown", "enumeration error is distinct from zero devices")
	check(unknownReport ~= emptyReport and unknownReport:find("unknown", 1, true), "errored device enumeration recorded as unknown")
	w.devicesError = false; w.ids = { 7, 11 }; w.mapped[7] = { buttons = { true }, axes = { .7 } }
	w.probe:OnEvent("GAME_PAD_CONNECTED"); w.probe:Sample()
	check(#w.writes == 0, "multiple devices and missing state never trigger writes")
	w.style, w.cvar, w.combat, w.usingGamepad, w.usingMouse = w.secret, w.secret, w.secret, w.secret, w.secret
	w.ids = { w.secret }; w.mapped = {}
	w.probe:Sample()
	w.probe:OnEvent("GAME_PAD_ACTIVE_CHANGED", w.secret)
	w.probe:OnEvent("INPUT_DEVICE_INTERFACE_TRANSITION", w.secret, w.secret)
	w.probe:SelectTarget(w.secret)
	w.probe:RequestTest("click")
	check(type(w.probe:GetReport()) == "string", "secret-valued observations remain reportable")
	w.ids = w.secret
	w.probe:Sample()
	check(type(w.probe:GetReport()) == "string", "secret enumeration result remains reportable")
	check(w.secretFormats == 0 and #w.writes == 0, "secret values never formatted or written")
end)

for _, style in ipairs({ 0, 1, 42 }) do
	scenario("reload reconciles pending against style " .. style, function()
		local before = newWorld({ ui = false })
		before.setterMode = "nil"
		before.probe:Start(); before.probe:SelectTarget(1); before:Write("click")
		check(before.probe.db.pending ~= nil, "unconfirmed request survives for reload diagnosis")
		local saved = copy(before.probe.db)
		local after = newWorld({ ui = false, saved = saved, configure = function(w) w.style = style end })
		check(after.probe.db.session == before.probe.db.session + 1, "reload advances session")
		check(not after.probe.collecting and #after.writes == 0, "reload neither collects nor reapplies")
		check(after.probe.db.pending == nil, "reload resolves pending marker")
		local expected = style == 1 and "recovered-match" or style == 0 and "recovered-mismatch" or "recovered-unknown"
		check(after.probe.db.lastRequest.status == expected, "reload records " .. expected)
		after.probe:SelectTarget(0)
		if (style == 1) then after:Write("click"); check(#after.writes == 1, "recovered request is not stuck busy") end
	end)
end

scenario("bounded and defensive SavedVariables", function()
	for _, saved in ipairs({ false, "invalid", { schema = 9 }, { schema = 1, session = "broken", records = false, pending = "bad" } }) do
		local w = newWorld({ saved = saved, ui = false })
		check(w.probe.db.schema == 1 and type(w.probe.db.session) == "number", "invalid DB repaired")
		check(type(w.probe.db.records) == "table", "invalid records repaired")
		check(type(w.probe:GetReport()) == "string" and #w.writes == 0, "invalid DB report safe without writes")
	end
	local w = newWorld({ ui = false })
	w.probe:Start()
	for index = 1, 650 do w.time = index; w.probe:OnEvent("GAME_PAD_CONNECTED") end
	check(#w.probe.db.records <= 400, "record buffer bounded to 400")
	check(#w.probe.db.records > 0, "record buffer retains observations")
	check(w.probe.db.records[#w.probe.db.records].session == w.probe.db.session, "records retain current session")
	check(#w.writes == 0, "large event volume never writes")
end)

for index, world in ipairs(worlds) do
	check(world.unauthorizedWrites == 0, "world " .. index .. " made no unauthorized CVar attempts, including caught errors")
	check(#world.forbiddenCalls == 0, "world " .. index .. " made no protected/native calls, including caught errors")
end
print(string.format("input_style_probe: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

--[[
	Offline checks for two third-party add-on interactions.

	1. ConsolePort hotkey icons (Components/ActionBars/Compatibility/HandleConsolePort.lua).
	   ConsolePort only draws its gamepad icons on buttons its own UIParent walk finds. The
	   module draws ConsolePort's widget on any AzeriteUI button that walk missed, and keeps
	   LibActionButton's text hotkey hidden under it.
	2. 3D portrait alpha under a UIParent fade (Components/UnitFrames/Functions.lua).
	   DialogueUI fades UIParent itself; a model does not inherit that, so the portrait's
	   model alpha must follow frame alpha times UIParent alpha.

	The fake ConsolePort follows ConsolePort 3.3.3's View/Hotkey.lua: a widget pool whose
	widgets SetData(data, owner) onto a button, hide owner.HotKey and parent themselves to it.

	Run from the addon root:  lua Tools/Harness/addon_compat_harness.lua .
]]

local root = (arg and arg[1]) or "."

local passed, failed = 0, 0
local check = function(ok, label)
	if (ok) then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

local near = function(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

---------------------------------------------------------------------------
-- Minimal widgets
---------------------------------------------------------------------------
local hooks = {}
local NewFrame = function(name)
	local f = { name = name, alpha = 1, shown = true }
	function f:GetName() return self.name end
	function f:GetAlpha() return self.alpha end
	function f:SetAlpha(a)
		self.alpha = a
		for _, fn in ipairs(hooks[self] and hooks[self].SetAlpha or {}) do fn(self, a) end
	end
	function f:Show() self.shown = true end
	function f:Hide() self.shown = false end
	function f:IsShown() return self.shown end
	function f:SetShown(v) self.shown = v and true or false end
	function f:GetParent() return self.parent end
	function f:SetParent(p) self.parent = p end
	function f:GetFrameLevel() return 5 end
	function f:SetFrameLevel(l) self.level = l end
	function f:SetScale(s) self.scale = s end
	return f
end

local hooksecurefunc = function(obj, method, fn)
	hooks[obj] = hooks[obj] or {}
	hooks[obj][method] = hooks[obj][method] or {}
	table.insert(hooks[obj][method], fn)
end

---------------------------------------------------------------------------
-- 1. ConsolePort
---------------------------------------------------------------------------
do
	local bindings = {}
	local GetBindingKey = function(action)
		local keys = bindings[action]
		if (not keys) then return nil end
		return unpack(keys)
	end

	-- Fake ConsolePort HotkeyHandler.
	local disableRendering = false
	local cpdb = setmetatable({}, { __call = function(_, key)
		if (key == "disableHotkeyRendering") then return disableRendering end
	end })
	local ConsolePortGlobal = { GetData = function() return cpdb end }

	local active, pool = {}, {}
	local Widgets = {}
	function Widgets:EnumerateActive() return next, active, nil end
	function Widgets:Release(w) active[w] = nil; w.owner = nil; w.parent = nil end
	function Widgets:ReleaseAll() for w in pairs(active) do self:Release(w) end end
	local HotkeyHandler = { Widgets = Widgets, scanFinds = {} }
	function HotkeyHandler:GetHotkeyData(device, btnID, modID)
		return { device = device, button = btnID, modifier = modID }
	end
	function HotkeyHandler:GetWidget()
		local w = table.remove(pool) or NewFrame()
		function w:SetData(data, owner)
			self.data = data
			self.parent = owner
			owner.HotKey:SetAlpha(0)
			owner.HotKey:Hide()
		end
		active[w] = true
		return w
	end
	-- ConsolePort's own pass: ReleaseAll, then draw only what its UIParent walk found.
	function HotkeyHandler:UpdateHotkeys(device)
		self.Widgets:ReleaseAll()
		if (disableRendering) then return end
		for button, data in pairs(self.scanFinds) do
			self:GetWidget():SetData(data, button)
		end
	end

	-- Fake AzeriteUI action buttons with a LibActionButton-style hotkey refresh.
	local NewButton = function(name, target)
		local b = NewFrame(name)
		b.keyBoundTarget = target
		b.config = { keyBoundClickButton = "Keybind" }
		b.HotKey = NewFrame()
		return b
	end
	local LAB_UpdateHotkeys = function(b)
		b.HotKey:Show()
		if (b.postKeybind) then b.postKeybind(nil, b) end
	end

	local b1 = NewButton("AzeriteActionBar1Button1", "ACTIONBUTTON1")
	local b2 = NewButton("AzeriteActionBar1Button2", "ACTIONBUTTON2")
	local b3 = NewButton("AzeriteActionBar2Button1", "MULTIACTIONBAR1BUTTON1")
	local b4 = NewButton("AzeriteActionBar2Button2", "MULTIACTIONBAR1BUTTON2")
	bindings.ACTIONBUTTON1 = { "1", "PAD1" }
	bindings.ACTIONBUTTON2 = { "SHIFT-PAD2" }
	bindings.MULTIACTIONBAR1BUTTON1 = { "Q" }          -- keyboard only
	bindings["CLICK AzeriteActionBar2Button2:Keybind"] = { "CTRL-SHIFT-PADDUP" }

	local ActionBars = { buttons = { [b1] = true, [b2] = true, [b3] = true, [b4] = true } }
	function ActionBars:IsEnabled() return true end

	-- Module stubs.
	local module
	local ns = {
		API = { IsAddOnEnabled = function(name) return name == "ConsolePort" end },
	}
	function ns:NewModule()
		module = {}
		function module:SecureHook(obj, method)
			local orig = obj[method]
			obj[method] = function(...)
				local r = orig(...)
				module[method](module, ...)
				return r
			end
		end
		function module:RegisterEvent() end
		function module:UnregisterEvent() end
		function module:Disable() end
		return module
	end
	function ns:GetModule(name) if (name == "ActionBars") then return ActionBars end end
	function ns:Fire() end

	local env = setmetatable({
		ConsolePort = ConsolePortGlobal,
		ConsolePortHotkeyHandler = HotkeyHandler,
		GetBindingKey = GetBindingKey,
		IsAddOnLoaded = function() return true end,
		InCombatLockdown = function() return false end,
	}, { __index = _G })
	env._G = env

	local chunk = assert(loadfile(root .. "/Components/ActionBars/Compatibility/HandleConsolePort.lua"))
	setfenv(chunk, env)
	chunk("AzeriteUI", ns)
	module:OnInitialize()

	local OwnerOf = function(button)
		for w in pairs(active) do if (w.parent == button) then return w end end
	end

	-- The scan finds nothing, as when an ancestor has access constraints.
	HotkeyHandler:UpdateHotkeys("xbox")
	local w1, w2, w3, w4 = OwnerOf(b1), OwnerOf(b2), OwnerOf(b3), OwnerOf(b4)
	check(w1 and w1.data.button == "PAD1" and w1.data.modifier == "", "bar 1: PAD1 icon drawn though the scan missed it")
	check(w1 and w1.data.device == "xbox", "the device ConsolePort passed is used")
	check(w2 and w2.data.button == "PAD2" and w2.data.modifier == "SHIFT-", "modifier split like ConsolePort's GetBindings")
	check(not w3, "keyboard-only button gets no gamepad widget")
	check(w4 and w4.data.button == "PADDUP" and w4.data.modifier == "CTRL-SHIFT-", "CLICK binding route is read as well")
	check(not b1.HotKey:IsShown() and b3.HotKey:IsShown(), "text hidden under icons, kept on the keyboard button")

	-- LibActionButton refreshes text hotkeys after the icons are drawn.
	for b in pairs(ActionBars.buttons) do LAB_UpdateHotkeys(b) end
	check(not b1.HotKey:IsShown() and not b4.HotKey:IsShown(), "LAB refresh does not bring text back under an icon")
	check(b3.HotKey:IsShown(), "LAB refresh still shows keyboard text")

	-- The scan does find a button: no second widget on it.
	HotkeyHandler.scanFinds[b1] = { device = "xbox", button = "PAD1", modifier = "", scanned = true }
	HotkeyHandler:UpdateHotkeys("xbox")
	local count = 0
	for w in pairs(active) do if (w.parent == b1) then count = count + 1 end end
	check(count == 1 and OwnerOf(b1).data.scanned, "a button ConsolePort drew itself is left alone")

	-- Rebinding a pad key away gives the text back.
	HotkeyHandler.scanFinds[b1] = nil
	bindings.ACTIONBUTTON2 = { "2" }
	HotkeyHandler:UpdateHotkeys("xbox")
	LAB_UpdateHotkeys(b2)
	check(not OwnerOf(b2) and b2.HotKey:IsShown(), "unbound from the pad: no widget, text back")

	-- ConsolePort's "disable hotkey rendering" switch is honoured.
	disableRendering = true
	HotkeyHandler:UpdateHotkeys("xbox")
	check(next(active) == nil, "nothing drawn with disableHotkeyRendering on")
	disableRendering = false
end

---------------------------------------------------------------------------
-- 2. Portrait model alpha under a UIParent fade
---------------------------------------------------------------------------
do
	local UIParent = NewFrame("UIParent")
	local API = {}
	API.IsSafeNumber = function(v) return type(v) == "number" end
	API.TryCall = function(fn, ...) return pcall(fn, ...) end

	local ns = { API = API, Colors = {}, oUF = setmetatable({}, { __index = function() return function() end end }) }
	-- Anything else Functions.lua builds at load time: a frame that accepts every call.
	local Permissive
	Permissive = setmetatable({}, { __index = function() return function() return Permissive end end })
	local env = setmetatable({
		UIParent = UIParent,
		hooksecurefunc = hooksecurefunc,
		CreateFrame = function() return Permissive end,
	}, { __index = _G })
	env._G = env

	local chunk = assert(loadfile(root .. "/Components/UnitFrames/Functions.lua"))
	setfenv(chunk, env)
	local ok, err = pcall(chunk, "AzeriteUI", ns)
	check(ok, "Functions.lua loads under the stubs: " .. tostring(err))

	local NewUnitFrame = function()
		local frame = NewFrame()
		local portrait = NewFrame()
		portrait.alpha = .85
		function portrait:SetModelAlpha(a) self.modelAlpha = a end
		frame.Portrait = portrait
		API.AttachPortraitAlphaFix(frame, portrait)
		return frame, portrait
	end

	local target, tp = NewUnitFrame()
	local party, pp = NewUnitFrame()
	check(near(tp.modelAlpha, 1), "model starts at full alpha")

	-- DialogueUI's fade steps.
	UIParent:SetAlpha(.5)
	check(near(tp.modelAlpha, .5) and near(pp.modelAlpha, .5), "every portrait follows a UIParent fade")
	UIParent:SetAlpha(0)
	check(near(tp.modelAlpha, 0), "model hidden with UIParent at 0")

	-- Frame fade while UIParent is faded: product, not either alone.
	target:SetAlpha(.5)
	check(near(tp.modelAlpha, 0), "frame alpha change keeps the UIParent fade")
	UIParent:SetAlpha(1)
	check(near(tp.modelAlpha, .5), "UIParent back: model takes the frame's own alpha")

	-- A model rebuilt mid-fade (SetUnit on a new target) is refreshed to the product.
	UIParent:SetAlpha(.25)
	tp.modelAlpha = 1
	API.RefreshPortraitModelAlpha(tp)
	check(near(tp.modelAlpha, .125), "refresh after SetUnit uses frame alpha times UIParent alpha")

	-- Widget alpha (PortraitAlpha) is never written.
	check(near(tp.alpha, .85), "PortraitAlpha on the widget is left alone")

	-- One UIParent hook, however many portraits.
	check(#(hooks[UIParent] and hooks[UIParent].SetAlpha or {}) == 1, "a single shared UIParent hook")

	-- A secret frame alpha falls back to solid times UIParent.
	API.IsSafeNumber = function(v) return type(v) == "number" and v ~= .5 end
	target:SetAlpha(.5)
	check(near(tp.modelAlpha, .25), "unreadable frame alpha treated as 1")
	UIParent:SetAlpha(.5)
	check(near(pp.modelAlpha, 1), "unreadable UIParent alpha treated as 1")
end

---------------------------------------------------------------------------
-- 3. Gamepad glyphs without ConsolePort (Libs/LibActionButton-1.0-GE)
--
-- GetBindingText(key, 1) gives "|A:Gamepad_..._32:14:14|a" for a PAD key on the
-- client (SetGamepadBindingStrings in SharedConstants.lua); the fake does the same.
---------------------------------------------------------------------------
local LoadLAB = function(opts)
	local scripts = {}
	local Stub = {}
	setmetatable(Stub, {
		__index = function() return Stub end,
		__call = function() return Stub end,
		__newindex = function() end,
		__metatable = false,
	})
	local NewStubFrame = function()
		return setmetatable({}, { __index = function(_, key)
			if (key == "SetScript") then
				return function(self, name, fn)
					scripts[self] = scripts[self] or {}
					scripts[self][name] = fn
				end
			elseif (type(key) == "string" and key:match("^%u")) then
				return function() return Stub end
			end
		end })
	end
	local KeyBound = { ToShortKey = function(_, key) return "short:" .. key end }
	local libs = {}
	local LibStub = setmetatable({
		NewLibrary = function(_, major)
			libs[major] = libs[major] or {}
			return libs[major], nil
		end,
	}, { __call = function(_, major)
		if (major == "LibKeyBound-1.0") then return KeyBound end
		if (major == "CallbackHandler-1.0") then return { New = function() return Stub end } end
		return libs[major]
	end })
	local ABSENT = { ActionButton_UpdateFlyout = true, IsBindingForGamePad = not opts.nativeCheck }
	local env = {
		LibStub = LibStub,
		format = string.format, strmatch = string.match, tinsert = table.insert, tremove = table.remove,
		wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
		hooksecurefunc = function() end,
		issecretvalue = function() return false end,
		CreateFrame = function() return NewStubFrame() end,
		InCombatLockdown = function() return false end,
		IsLoggedIn = function() return false end,
		C_GamePad = { IsEnabled = function() return opts.padEnabled end },
		GetBindingText = function(key, abbrev)
			local button = key:match("([^%-]+)$")
			if (abbrev and button:find("^PAD")) then return "|A:Gamepad_" .. key .. "_32:14:14|a" end
			return "text:" .. key
		end,
		IsBindingForGamePad = opts.nativeCheck and function(key) return key:find("PAD", 1, true) == 1 end or nil,
	}
	for _, name in ipairs({ "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print",
		"rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "unpack",
		"xpcall", "coroutine", "math", "string", "table" }) do
		env[name] = _G[name]
	end
	env._G = env
	setmetatable(env, { __index = function(_, key) if (not ABSENT[key]) then return Stub end end })

	local chunk = assert(loadfile(root .. "/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua"))
	setfenv(chunk, env)
	pcall(chunk, "AzeriteUI", { HasSecureSnippets = true })
	local lib = libs["LibActionButton-1.0-GE"]
	return lib
end

do
	local lib = LoadLAB({ padEnabled = true })
	check(lib and type(lib.GetHotkeyText) == "function" and type(lib.PickHotkey) == "function", "LAB exposes the hotkey helpers")
	if (lib and lib.GetHotkeyText) then
		check(lib.GetHotkeyText("PAD1") == "|A:Gamepad_PAD1_32:14:14|a", "pad key drawn as the client's glyph")
		check(lib.GetHotkeyText("SHIFT-PADDUP"):find("^|A:"), "pad key with modifier drawn as glyphs")
		check(lib.GetHotkeyText("NUMPAD1") == "short:NUMPAD1", "NUMPAD is a keyboard key")
		check(lib.GetHotkeyText("Q") == "short:Q", "keyboard key keeps LibKeyBound's text")
		check(lib.GetHotkeyText(nil) == nil and lib.GetHotkeyText("") == nil, "no key, no text")

		-- Pad support on, no event yet: the pad key wins when both are bound.
		check(lib.PickHotkey("1", "PAD1") == "PAD1", "gamepad enabled: pad key preferred before any event")
		lib.SetGamePadActive(false)
		check(lib.PickHotkey("PAD1", "1") == "1", "keyboard in use: keyboard key preferred")
		check(lib.PickHotkey("PAD1") == "PAD1", "keyboard in use, only a pad key: still shown")
		lib.SetGamePadActive(true)
		check(lib.PickHotkey("1", "SHIFT-PAD2") == "SHIFT-PAD2", "controller in use: pad key preferred")
		check(lib.PickHotkey() == nil and lib.PickHotkey(nil, "") == nil, "nothing bound, nothing picked")
	end

	-- LAB's event handler only exists once a real button does, so its wiring is read from source:
	-- the GAME_PAD_ACTIVE_CHANGED branch must record the payload before redrawing.
	local source = assert(io.open(root .. "/Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua")):read("*a")
	check(source:find('if event == "GAME_PAD_ACTIVE_CHANGED" then%s+lib%.SetGamePadActive%(arg1%)%s+end%s+ForAllButtons%(UpdateHotkeys') ~= nil,
		"LAB records GAME_PAD_ACTIVE_CHANGED before redrawing hotkeys")
	check(source:find("return lib%.GetHotkeyText%(key%)") ~= nil, "Generic:GetHotkey goes through GetHotkeyText")

	local lib2 = LoadLAB({ padEnabled = false })
	if (lib2 and lib2.PickHotkey) then
		check(lib2.PickHotkey("PAD1", "1") == "1", "gamepad support off: keyboard key preferred")
	end

	local lib3 = LoadLAB({ padEnabled = true, nativeCheck = true })
	if (lib3 and lib3.IsGamePadKey) then
		check(lib3.IsGamePadKey("PAD1") and not lib3.IsGamePadKey("SHIFT-PAD1"), "the client's IsBindingForGamePad is used when present")
	end
end

print(string.format("addon_compat_harness: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end

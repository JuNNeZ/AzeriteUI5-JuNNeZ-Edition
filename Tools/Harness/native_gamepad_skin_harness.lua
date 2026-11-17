-- NativeGamepadSkin: AzeriteUI art on Blizzard's native controller buttons.
-- Loads the real module, the real shape helper (Core/API/Assets.lua) and the
-- real ActionButton layout data against a recording model of Blizzard's page
-- unit (Blizzard_GamepadActionBars PageUnit.lua / ActionBar.lua). Asserts the
-- module only creates its own textures and sets region alpha: no field,
-- script, attribute, geometry or hook on Blizzard's frames.
-- Under Elune it also runs the addon code tainted and checks that Blizzard's
-- caller and button fields stay secure. It does not emulate rendering,
-- Blizzard's press path, frame protection or the real client.
-- Usage: Tools/Run-Elune.ps1 -Script Tools/Harness/native_gamepad_skin_harness.lua .
local root = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL: " .. message) end
end

local ELUNE = type(issecure) == "function" and type(debug) == "table" and type(debug.setstacktaint) == "function"

-- Methods Blizzard's protected buttons must never receive from this module.
local FORBIDDEN = {
	"SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetParent",
	"SetScale", "SetAttribute", "SetScript", "HookScript", "SetID", "Show", "Hide", "SetShown",
	"EnableMouse", "SetFrameLevel", "SetFrameStrata", "RegisterForClicks", "Click", "SetButtonState",
	"SetNormalTexture", "SetNormalAtlas", "SetPushedAtlas", "SetCheckedTexture", "SetHighlightTexture"
}

local function NewWorld()
	local world = { violations = {}, textures = {}, hooks = 0, buttons = {}, stores = {}, regions = {} }

	local function Region(name, alpha)
		local r = { name = name, alpha = alpha or 1, alphaWrites = 0 }
		function r:GetAlpha() return self.alpha end
		function r:SetAlpha(a) self.alpha = a; self.alphaWrites = self.alphaWrites + 1 end
		world.regions[#world.regions + 1] = r
		return r
	end

	local function Texture(owner, layer, sublevel)
		local t = { owner = owner, layer = layer, sublevel = sublevel, shown = true }
		function t:SetAllPoints(rel) self.anchor = rel end
		function t:SetTexture(path) self.texture = path end
		function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
		function t:SetTexCoord(l, r, top, b) self.coords = { l, r, top, b } end
		function t:SetShown(s) self.shown = s and true or false end
		world.textures[#world.textures + 1] = t
		return t
	end

	-- A native button: methods and fields live in `store`; the button
	-- itself is an empty proxy so every write from the module is recorded.
	local function Button(barName, index, shape)
		local store = {
			activeButtonShape = shape,
			NormalTexture = Region(barName .. index .. "Normal", 1),
			PushedTexture = Region(barName .. index .. "Pushed", 1),
			CircleShadow = Region(barName .. index .. "CircleShadow", .8),
			SquareShadow = Region(barName .. index .. "SquareShadow", .8),
		}
		local button
		function store.CreateTexture(self, _, layer, _, sublevel) return Texture(self, layer, sublevel) end
		for _, method in ipairs(FORBIDDEN) do
			store[method] = function()
				world.violations[#world.violations + 1] = barName .. index .. ":" .. method
			end
		end
		button = setmetatable({}, {
			__index = store,
			__newindex = function(_, key)
				world.violations[#world.violations + 1] = barName .. index .. " field " .. tostring(key)
			end
		})
		world.buttons[#world.buttons + 1] = button
		world.stores[button] = store
		return button
	end

	local function Bar(name)
		local bar = { actionButtons = {} }
		for i = 1, 8 do
			-- ActionBarStyles LEFTSQUARE_RIGHTCIRCLE_STYLE: left group square, right round.
			bar.actionButtons[i] = Button(name, i, i <= 4 and "Square" or "Circle")
		end
		return bar
	end

	world.callbacks = {}
	world.unit = {
		actionBars = {
			topBar = Bar("top"), leftBar = Bar("left"), rightBar = Bar("right"), bottomBar = Bar("bottom"),
			possessBar = Bar("possess"), stanceBar = Bar("stance"),
			friendlyTargetingBar = Bar("friendly"), hostileTargetingBar = Bar("hostile"), shortcutsBar = Bar("shortcuts")
		}
	}
	function world.unit:RegisterActiveActionBarUpdatedCallback(fn, owner)
		world.callbacks[#world.callbacks + 1] = { fn = fn, owner = owner }
	end
	-- Blizzard dispatches CallbackRegistry events through secureexecuterange;
	-- the registry entries themselves are read inside that barrier.
	function world.FireActiveBar()
		local dispatch = function()
			for _, cb in ipairs(world.callbacks) do cb.fn(cb.owner) end
		end
		if ELUNE then securecall(dispatch) else dispatch() end
	end
	return world
end

local function Session(opts)
	opts = opts or {}
	local world = NewWorld()
	local env
	local module
	local ns = { Prefix = "AzeriteUI", IsForever = true, API = {} }
	ns.NativeController = {
		IsActive = function() return opts.active ~= false end,
		GetConflict = function() return opts.conflict end
	}
	ns.LegacyHUD = nil
	ns.ThemeEngine = nil
	local configs = {}
	ns.RegisterConfig = function(name, config) configs[name] = config end
	ns.GetConfig = function(name) return configs[name] end
	local color = function(r, g, b) return { r, g, b } end
	ns.Colors = { quest = { gray = color(.6, .6, .6) }, normal = color(1, .82, 0), highlight = color(1, 1, 1), ui = color(.75, .75, .75) }
	local created = 0
	function ns:NewModule(name)
		created = created + 1
		local m = { name = name, events = {} }
		function m:GetName() return self.name end
		function m:RegisterEvent(e, method) self.events[e] = method or true end
		function m:UnregisterEvent(e) self.events[e] = nil end
		module = m
		return m
	end
	function ns:GetModule(name) return module and module.name == name and module or nil end
	ns.db = {
		RegisterNamespace = function(_, _, defaults)
			local db = { profile = { enabled = defaults.profile.enabled } }
			db.RegisterCallback = function() end
			return db
		end
	}
	local loaded = opts.loaded
	env = setmetatable({
		C_AddOns = { IsAddOnLoaded = function(name) return name == "Blizzard_GamepadActionBars" and loaded or false end },
		GamepadMainActionBarFrame = (not opts.noFrame) and { PageUnit = world.unit } or nil,
		CreateFont = function(name) return { name = name, SetJustifyH = function() end, GetFont = function() return "font", 12, "OUTLINE" end } end,
		hooksecurefunc = function() world.hooks = world.hooks + 1 end,
	}, { __index = _G })
	env._G = env
	local function load(path)
		local chunk = assert(loadfile(root .. "/" .. path))
		setfenv(chunk, env)
		return chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end
	load("Core/API/Assets.lua")
	load("Layouts/Data/ActionButton.lua")
	load("Components/ActionBars/Elements/NativeGamepadSkin.lua")
	world.ns, world.env, world.created = ns, env, created
	world.module = module
	world.setLoaded = function(v) loaded = v end
	return world
end

-- Runs addon code with a tainted stack under Elune; plain call otherwise.
local function AsAddon(fn, ...)
	if not ELUNE then return fn(...) end
	local args = { ... }
	return securecallfunction(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		return fn(unpack(args))
	end)
end

local function Close(a, b) return math.abs(a - b) < 1e-6 end

-- 0. Elune, first, while the harness stack is still clean: the addon runs tainted, Blizzard's side stays secure.
-- Addon-written records are only read inside securecall barriers, as a
-- native caller never reads addon state (popup harness pattern).
if ELUNE then
	check(issecure(), "harness starts secure")
	local w = Session({ loaded = true })
	local skin = w.module
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		skin:OnInitialize()
		skin:OnEnable()
	end)
	check(issecure(), "tainted skin build leaves the native caller secure")
	-- Blizzard's press path reads its own button fields and acts.
	local function PressPath()
		for _, button in ipairs(w.buttons) do
			local store = w.stores[button]
			for _, key in ipairs({ "activeButtonShape", "NormalTexture", "PushedTexture",
				"CircleShadow", "SquareShadow", "CreateTexture", "SetSize" }) do
				local _ = store[key]
			end
		end
		return issecure()
	end
	check(PressPath(), "native press path reads only secure button fields after skinning")
	local secure = true
	for _, store in pairs(w.stores) do
		for key in pairs(store) do
			if not issecurevariable(store, key) then secure = false end
		end
	end
	check(secure, "every native button field stays secure")
	w.FireActiveBar()
	check(issecure() and PressPath(), "active-bar callback dispatch returns secure")
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		skin.db.profile.enabled = false
		skin:UpdateSettings()
	end)
	check(issecure() and PressPath(), "toggling off stays isolated from native state")
	local probe = w.stores[w.buttons[1]]
	securecall(function()
		debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
		rawset(probe, "contaminated", tonumber("23"))
	end)
	check(not issecurevariable(probe, "contaminated"), "negative control detects a tainted native field")
end

-- 1. Keyboard/mouse sessions and replacement bar addons create nothing.
do
	local w = Session({ active = false })
	check(w.created == 0 and w.module == nil, "no module outside native mode")
	w = Session({ conflict = "ConsolePort_Bar" })
	check(w.created == 0 and w.module == nil, "no module while ConsolePort_Bar owns the bars")
	w = Session({ conflict = "Bartender4" })
	check(w.created == 0 and w.module == nil, "no module while Bartender4 owns the bars")
end

-- 2. Native bars loading after us: wait for their ADDON_LOADED.
do
	local w = Session({ loaded = false })
	local skin = w.module
	check(skin ~= nil and w.created == 1, "module created in a native session")
	AsAddon(skin.OnInitialize, skin)
	AsAddon(skin.OnEnable, skin)
	check(skin.events.ADDON_LOADED and skin.events.PLAYER_ENTERING_WORLD, "waits for the native bars and the first world entry")
	check(#w.textures == 0, "nothing built before the native bars load")
	AsAddon(skin.OnEvent, skin, "ADDON_LOADED", "SomeOtherAddon")
	check(#w.textures == 0 and skin.events.ADDON_LOADED, "other addons' ADDON_LOADED ignored")
	w.setLoaded(true)
	AsAddon(skin.OnEvent, skin, "ADDON_LOADED", "Blizzard_GamepadActionBars")
	check(not skin.events.ADDON_LOADED, "ADDON_LOADED released once the bars exist")
	check(#w.textures == 2 * #w.buttons and #w.buttons == 72, "two textures on each of 72 native buttons")
	check(#w.callbacks == 1 and w.callbacks[1].owner == skin, "one active-bar callback registered")

	-- Art and crop from the real ActionButton config and shape helper.
	local cfg = w.ns.GetConfig("ActionButton")
	local circleCrop = .5 * cfg.ButtonSize[1] / cfg.ButtonBorderSize[1]
	local square = w.ns.API.GetShapedButtonConfig(cfg, "square")
	local squareCrop = .5 * square.ButtonSize[1] / square.ButtonBorderSize[1]
	local okArt, okLayers = true, true
	for _, t in ipairs(w.textures) do
		local store = w.stores[t.owner]
		local round = store.activeButtonShape == "Circle"
		local isBorder = t.layer == "ARTWORK"
		local crop = isBorder and (round and circleCrop or squareCrop)
			or .5 * cfg.ButtonSize[1] / (round and cfg.ButtonBackdropSize[1] or square.ButtonBackdropSize[1])
		local want = isBorder and (round and cfg.ButtonBorderTexture or square.ButtonBorderTexture)
			or (round and cfg.ButtonBackdropTexture or square.ButtonBackdropTexture)
		if t.texture ~= want or not t.coords or not Close(t.coords[1], .5 - crop) or not Close(t.coords[2], .5 + crop)
			or not Close(t.coords[3], .5 - crop) or not Close(t.coords[4], .5 + crop) or t.anchor ~= t.owner then
			okArt = false
		end
		if not ((t.layer == "BACKGROUND" and t.sublevel == -8) or (t.layer == "ARTWORK" and t.sublevel == 7)) then okLayers = false end
	end
	check(okArt, "circle art on round buttons, square art on square ones, cropped to the painted cell and following the button")
	check(okLayers, "backdrop below Blizzard's icon and shadows, ring above the icon only")
	check(circleCrop > 0 and circleCrop < .5 and squareCrop > 0 and squareCrop < .5, "crops stay inside the painted sheet")
	local hidden = true
	for _, r in ipairs(w.regions) do if r.alpha ~= 0 then hidden = false end end
	check(hidden, "Blizzard's ring, pushed and drop-shadow art set to alpha 0")
	check(#w.violations == 0, "no field, script, attribute, geometry or state call on native buttons: " .. table.concat(w.violations, ", "))
	check(w.hooks == 0, "no hooksecurefunc anywhere (nothing on the press path)")

	-- Active-bar changes: idempotent refresh, no new regions.
	local count = #w.textures
	w.FireActiveBar()
	check(#w.textures == count, "refresh creates nothing new")

	-- Blizzard changing a button's shape (its own field write) is followed.
	local first = w.buttons[1]
	rawset(w.stores[first], "activeButtonShape", "Circle")
	w.FireActiveBar()
	local border
	for _, t in ipairs(w.textures) do if t.owner == first and t.layer == "ARTWORK" then border = t end end
	check(border and border.texture == cfg.ButtonBorderTexture, "shape change re-selects the circle ring")

	-- Switching off restores Blizzard's art exactly; on again re-applies.
	skin.db.profile.enabled = false
	AsAddon(skin.UpdateSettings, skin)
	local restored, ourHidden = true, true
	for _, r in ipairs(w.regions) do
		local want = r.name:find("Shadow") and .8 or 1
		if r.alpha ~= want then restored = false end
	end
	for _, t in ipairs(w.textures) do if t.shown then ourHidden = false end end
	check(restored, "off restores Blizzard's original alpha")
	check(ourHidden, "off hides our textures")
	skin.db.profile.enabled = true
	AsAddon(skin.UpdateSettings, skin)
	local back = true
	for _, r in ipairs(w.regions) do if r.alpha ~= 0 then back = false end end
	for _, t in ipairs(w.textures) do if not t.shown then back = false end end
	check(back and #w.textures == count, "on again re-applies without new regions")
	check(#w.violations == 0 and w.hooks == 0, "toggling touches no native frame state")

end

-- 3. Native bars already loaded: built at enable, no ADDON_LOADED wait.
do
	local w = Session({ loaded = true })
	local skin = w.module
	AsAddon(skin.OnInitialize, skin)
	AsAddon(skin.OnEnable, skin)
	check(not skin.events.ADDON_LOADED and #w.textures == 144, "already loaded bars are skinned at enable")
	AsAddon(skin.OnEvent, skin, "PLAYER_ENTERING_WORLD")
	check(#w.textures == 144 and #w.callbacks == 1, "world entry refreshes art without rebuilding or re-registering")
end

-- 4. Loaded flag without the frame: no error, retried on world entry.
do
	local w = Session({ loaded = true, noFrame = true })
	local skin = w.module
	AsAddon(skin.OnInitialize, skin)
	local ok = pcall(AsAddon, skin.OnEnable, skin)
	check(ok and #w.textures == 0 and #w.callbacks == 0, "missing native frame is tolerated")
	w.env.GamepadMainActionBarFrame = { PageUnit = w.unit }
	AsAddon(skin.OnEvent, skin, "PLAYER_ENTERING_WORLD")
	check(#w.textures == 144 and #w.callbacks == 1, "world entry builds once the frame exists")
end

-- 5. Off at login: textures exist but stay hidden, Blizzard art untouched.
do
	local w = Session({ loaded = true })
	local skin = w.module
	AsAddon(skin.OnInitialize, skin)
	skin.db.profile.enabled = false
	AsAddon(skin.OnEnable, skin)
	local untouched = true
	for _, r in ipairs(w.regions) do
		local want = r.name:find("Shadow") and .8 or 1
		if r.alpha ~= want then untouched = false end
	end
	local hidden = true
	for _, t in ipairs(w.textures) do if t.shown then hidden = false end end
	check(untouched and hidden, "disabled profile keeps Blizzard's art as it was")
end

print(string.format("native_gamepad_skin: %d checks, %d failures%s", checks, failures,
	ELUNE and " (Elune taint checks included)" or ""))
if failures > 0 then os.exit(1) end

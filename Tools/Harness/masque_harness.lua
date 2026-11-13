-- Masque hand-over harness (Components/ActionBars/Compatibility/Masque.lua).
--
-- 1. Loads the real Masque.lua against a stub Masque and checks the switch: off without
--    Masque or without the profile key, on with both, then fixed for the session; groups
--    are made once per name under "AzeriteUI"; buttons go in with their Masque type and
--    get MasqueSkinned (which LibActionButton reads to stop drawing Blizzard's border).
-- 2. Loads the real style functions from Elements/ActionBars.lua, PetBar.lua and
--    StanceBar.lua against recording stub frames, once with the switch off and once on.
--    Off must still draw our art (icon mask, border, backdrop, texture hooks); on must
--    leave every layer Masque skins alone and keep fonts, keybind, count and overlay.
-- 3. Checks the LibActionButton-1.0-GE charge cooldown asks Masque lazily, for skinned
--    buttons only (AzeriteUI loads before Masque, so the file-load lookup is nil).
--
-- What it cannot cover: how a Masque skin looks on our 64px buttons, Masque's own
-- skinning code, taint, and the reload prompt. Those are live checks.
--
-- Usage: lua.exe Tools/Harness/masque_harness.lua [addon root]

local root = (arg and arg[1]) or "."

local passed, failed = 0, 0
local function check(ok, label)
	if (ok) then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

local function ReadFile(path)
	local fh = assert(io.open(root .. "/" .. path, "rb"), "missing " .. path)
	local text = fh:read("*a")
	fh:close()
	return (text:gsub("\r\n", "\n"))
end

----------------------------------------------------------------
-- 1. The switch and the groups
----------------------------------------------------------------
local libs = {}
LibStub = setmetatable({}, { __call = function(_, major, silent) return libs[major] end })

local made = {}
local function NewMasque()
	return {
		Group = function(_, addon, name)
			local group = { addon = addon, name = name, buttons = {} }
			function group:AddButton(button, regions, buttonType)
				self.buttons[#self.buttons + 1] = { button = button, regions = regions, type = buttonType }
			end
			made[#made + 1] = group
			return group
		end
	}
end

local function LoadMasqueSupport(profile)
	local ns = {}
	ns.GetModule = function(_, name, silent)
		if (name == "ActionBars") then return { db = { profile = profile } } end
	end
	assert(loadfile(root .. "/Components/ActionBars/Compatibility/Masque.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
	return ns.ActionBarMasque
end

-- No Masque loaded.
libs.Masque = nil
local M = LoadMasqueSupport({ masque = true })
check(M and not M.IsAvailable(), "not available without Masque")
check(M.IsActive() == false, "inactive without Masque, even with the switch on")
M.AddButton({}, "Action Bar 1", "Action")
check(#made == 0, "no group made while inactive")

-- Masque loaded, switch off.
libs.Masque = NewMasque()
M = LoadMasqueSupport({ masque = false })
check(M.IsAvailable(), "available once Masque is loaded")
check(M.IsActive() == false, "inactive with the switch off")
local untouched = {}
M.AddButton(untouched, "Action Bar 1", "Action")
check(#made == 0 and untouched.MasqueSkinned == nil, "switch off: button not handed over")

-- Masque loaded, switch on.
local profile = { masque = true }
M = LoadMasqueSupport(profile)
check(M.IsActive() == true, "active with Masque and the switch on")
profile.masque = false
check(M.IsActive() == true, "decision fixed for the session (a change needs a reload)")
local a, b, pet = {}, {}, {}
M.AddButton(a, "Action Bar 1", "Action")
M.AddButton(b, "Action Bar 1", "Action")
M.AddButton(pet, "Pet Bar", "Pet")
check(#made == 2, "one group per name")
check(made[1].addon == "AzeriteUI" and made[1].name == "Action Bar 1", "group named AzeriteUI / Action Bar 1")
check(#made[1].buttons == 2 and made[1].buttons[1].button == a and made[1].buttons[1].type == "Action", "action buttons added as Action")
check(made[2].buttons[1].type == "Pet", "pet button added as Pet")
check(a.MasqueSkinned == true and pet.MasqueSkinned == true, "handed-over buttons marked MasqueSkinned")
M.AddButton(nil, "Pet Bar", "Pet")
check(#made[2].buttons == 1, "nil button ignored")

----------------------------------------------------------------
-- 2. The styles, with the switch off and on
----------------------------------------------------------------
-- A recording object: every method call is stored by name; getters hand out more of them.
local Recorder
local RETURNS = {
	GetFrameLevel = function() return 1 end,
	GetMaskTexture = function() return nil end,
	GetScript = function() return nil end,
	GetCountdownFontString = function() return nil end,
}
-- Fields a template may or may not carry; absent here, so they read as nil, not as methods.
local FIELDS = {
	Border = true, NewActionTexture = true, SpellHighlightAnim = true, SpellHighlightTexture = true,
	BottomDivider = true, RightDivider = true, SlotBackground = true, AutoCastable = true, AutoCastShine = true,
	IconMask = true, IconBorder = true, backdrop = true, iconBorder = true, darken = true, OverlayFrame = true,
	overlay = true, cooldownCount = true, pushedTexture = true, spellHighlight = true, AddToMasque = true,
	MasqueSkinned = true, CustomSpellActivationAlert = true, CustomAssistedHighlight = true, OnEnter = true, OnLeave = true,
	Stop = true, -- textures have no Stop; the template cleanup tells animations apart by it
}
local CHILDREN = {
	GetNormalTexture = "NormalTexture", GetPushedTexture = "PushedTexture",
	GetCheckedTexture = "CheckedTexture", GetHighlightTexture = "HighlightTexture",
}
Recorder = function(label)
	local object = { _label = label, _calls = {}, _last = {}, _created = {} }
	return setmetatable(object, { __index = function(self, key)
		if (FIELDS[key]) then return nil end
		if (RETURNS[key]) then return RETURNS[key] end
		if (CHILDREN[key]) then
			return function(this)
				local field = CHILDREN[key]
				this[field] = rawget(this, field) or Recorder(field)
				return this[field]
			end
		end
		if (key == "CreateTexture" or key == "CreateFontString") then
			return function(this)
				local child = Recorder(key)
				this._created = this._created or {}
				this._created[#this._created + 1] = child
				return child
			end
		end
		return function(this, ...)
			this._calls[key] = (this._calls[key] or 0) + 1
			this._last = this._last or {}
			this._last[key] = { ... }
		end
	end })
end
local function Called(object, method) return object and object._calls and (object._calls[method] or 0) > 0 end

local hooks
function hooksecurefunc(object, method) hooks[#hooks + 1] = { object = object, method = method } end
local function Hooked(object, method)
	for _, hook in ipairs(hooks) do
		if (hook.object == object and hook.method == method) then return true end
	end
end
function CreateFrame() return Recorder("Frame") end
function InCombatLockdown() return false end

-- Every layout value the styles read: sizes and points as pairs, offsets as numbers.
local function Config()
	return setmetatable({}, { __index = function(_, key)
		if (key:find("Offset")) then return 2 end
		if (key:find("Font")) then return { GetFont = function() return "font", 12, "OUTLINE" end } end
		if (key:find("Justify")) then return "CENTER" end
		if (key:find("Texture")) then return "texture-" .. key end
		return { 0, 0 }
	end })
end

local masqueActive = false
local UIHider = {}
local function StyleNS()
	return {
		IsRetail = true,
		GetModule = function() return nil end,
		GetConfig = function() return Config() end,
		API = { GetShapedButtonConfig = function(db) return db end },
		ActionBarMasque = { IsActive = function() return masqueActive end },
		ActionBarProcHighlight = { Create = function() return Recorder("Proc") end, Apply = function() end },
		ActionBarAssistedHighlight = { Create = function() return Recorder("Assisted") end, Apply = function() end },
	}
end

-- Text between two markers in a file, run with env, returning what `tail` names.
local function LoadChunk(path, first, last, tail, env)
	local source = ReadFile(path)
	local s = source:find(first, 1, true)
	local e = last and source:find(last, s, true)
	assert(s and (e or not last), "markers not found in " .. path)
	local chunk = source:sub(s, (e and e - 1) or #source) .. "\n" .. tail
	local fn = assert(loadstring(chunk, "=" .. path))
	setfenv(fn, setmetatable(env, { __index = _G }))
	return fn()
end

-- Action buttons (Elements/ActionBars.lua).
local function StyleActionButton(active)
	masqueActive, hooks = active, {}
	local env = {
		ns = StyleNS(),
		ActionBarMod = { db = { profile = {} } },
		GetMedia = function(name) return name end,
		RegisterCooldown = function() end,
	}
	local style = LoadChunk("Components/ActionBars/Elements/ActionBars.lua",
		"local GetShapedConfig = function", "ActionBarMod.CreateBars = function", "return style", env)
	local button = Recorder("ActionButton")
	button.icon, button.cooldown, button.Flash = Recorder("icon"), Recorder("cooldown"), Recorder("Flash")
	button.Count, button.HotKey, button.NormalTexture = Recorder("Count"), Recorder("HotKey"), Recorder("NormalTexture")
	button.config = {} -- LibActionButton gives every button one
	style(button, "circle")
	return button
end

local off = StyleActionButton(false)
check(Called(off.icon, "SetMask"), "action, off: icon masked")
check(off.IconBorder ~= nil and off.backdrop ~= nil, "action, off: border and backdrop drawn")
check(Called(off.NormalTexture, "Hide"), "action, off: normal texture hidden")
check(Hooked(off, "SetNormalTexture") and Hooked(off, "SetNormalAtlas"), "action, off: normal texture hooks")
check(Hooked(off.cooldown, "SetSwipeTexture"), "action, off: swipe texture hook")
check(Called(off.cooldown, "SetSwipeTexture"), "action, off: swipe texture set")

local on = StyleActionButton(true)
check(not Called(on.icon, "SetMask") and not Called(on.icon, "SetSize"), "action, on: icon left to Masque")
check(on.IconBorder == nil, "action, on: no IconBorder (Masque would skin it as its own)")
check(on.backdrop == nil, "action, on: no backdrop")
check(not Called(on.NormalTexture, "Hide") and not Called(on.NormalTexture, "SetTexture"), "action, on: normal texture left to Masque")
check(not Hooked(on, "SetNormalTexture") and not Hooked(on, "SetNormalAtlas"), "action, on: no normal texture hooks")
check(not Hooked(on.cooldown, "SetSwipeTexture") and not Called(on.cooldown, "SetSwipeTexture"), "action, on: swipe left to Masque")
check(rawget(on, "PushedTexture") == nil and rawget(on, "CheckedTexture") == nil, "action, on: state textures not touched")
check(Hooked(on.cooldown, "SetHideCountdownNumbers"), "action, on: countdown numbers still ours")
check(on.OverlayFrame ~= nil and on.CustomSpellActivationAlert ~= nil, "action, on: overlay and proc highlight kept")
check(Called(on.HotKey, "SetFontObject") and Called(on.Count, "SetFontObject"), "action, on: keybind and count fonts kept")
check(Called(on, "UpdateConfig"), "action, on: button config still applied")
check(Called(on, "SetSize") and Called(on, "SetHitRectInsets"), "action, on: size and hit rects kept")

-- Pet and stance buttons (Elements/PetBar.lua, Elements/StanceBar.lua).
for _, path in ipairs({ "Components/ActionBars/Elements/PetBar.lua", "Components/ActionBars/Elements/StanceBar.lua" }) do
	local name = path:match("Elements/(%w+)%.lua")
	local function StyleSmallButton(active)
		masqueActive, hooks = active, {}
		local env = {
			ns = StyleNS(), UIHider = UIHider, noop = function() end,
			RegisterCooldown = function() end,
		}
		-- From onEnter to style's closing line.
		local source = ReadFile(path)
		local s = source:find("local onEnter = function", 1, true)
		local styleAt = source:find("local style = function(button, shape)", s, true)
		local e = source:find("\nend\n", styleAt, true)
		local fn = assert(loadstring(source:sub(s, e + 4) .. "\nreturn style, onEnter, onLeave", "=" .. path))
		setfenv(fn, setmetatable(env, { __index = _G }))
		local style, onEnter, onLeave = fn()
		local button = Recorder(name .. "Button")
		button.icon, button.cooldown, button.Flash = Recorder("icon"), Recorder("cooldown"), Recorder("Flash")
		button.Count, button.HotKey = Recorder("Count"), Recorder("HotKey")
		button.NormalTexture, button.CheckedTexture, button.HighlightTexture = Recorder("NormalTexture"), Recorder("CheckedTexture"), Recorder("HighlightTexture")
		button.SlotArt, button.Name = Recorder("SlotArt"), Recorder("Name")
		style(button, "circle")
		return button, onEnter, onLeave
	end

	local b = StyleSmallButton(false)
	check(Called(b.icon, "SetMask"), name .. ", off: icon masked")
	check(b.iconBorder ~= nil and b.backdrop ~= nil and b.icon.darken ~= nil, name .. ", off: border, backdrop and darkener drawn")
	check(b.NormalTexture._last and b.NormalTexture._last.SetParent and b.NormalTexture._last.SetParent[1] == UIHider, name .. ", off: template normal texture hidden")
	check(Called(b, "DisableDrawLayer"), name .. ", off: ARTWORK layer disabled")
	check(Hooked(b, "SetNormalTexture") and Hooked(b.cooldown, "SetSwipeTexture"), name .. ", off: art hooks in place")
	check(b.AddToMasque ~= nil and b.MasqueSkinned == nil, name .. ", off: kept out of Masque")

	local m, onEnter, onLeave = StyleSmallButton(true)
	check(not Called(m.icon, "SetMask") and not Called(m.icon, "SetSize"), name .. ", on: icon left to Masque")
	check(m.iconBorder == nil and m.backdrop == nil and m.icon.darken == nil, name .. ", on: none of our art drawn")
	check(not Called(m.NormalTexture, "SetParent") and not Called(m.CheckedTexture, "SetParent") and not Called(m.HighlightTexture, "SetParent"), name .. ", on: template state textures kept for Masque")
	check(not Called(m, "SetNormalTexture") and not Called(m, "SetCheckedTexture"), name .. ", on: state textures not cleared")
	check(not Hooked(m, "SetChecked"), name .. ", on: checked state not hidden (stance shows the active form)")
	check(not Called(m, "DisableDrawLayer"), name .. ", on: ARTWORK layer kept (Masque's normal texture draws there)")
	check(not Hooked(m, "SetNormalTexture") and not Hooked(m.cooldown, "SetSwipeTexture"), name .. ", on: no art hooks")
	check(Hooked(m.cooldown, "SetHideCountdownNumbers"), name .. ", on: countdown numbers still ours")
	check(Called(m.Name, "SetParent"), name .. ", on: macro name still hidden")
	check(m.overlay ~= nil and m.cooldownCount ~= nil, name .. ", on: overlay and cooldown text kept")
	check(Called(m.HotKey, "SetFontObject") and Called(m.Count, "SetFontObject"), name .. ", on: keybind and count fonts kept")
	check(m.AddToMasque == nil, name .. ", on: Masque hand-over not blocked")
	local ok = pcall(onEnter, m) and pcall(onLeave, m)
	check(ok, name .. ", on: hover without a darkener does not raise")
end

----------------------------------------------------------------
-- 3. LibActionButton's charge cooldown asks Masque lazily
----------------------------------------------------------------
do
	local source = ReadFile("Libs/LibActionButton-1.0-GE/LibActionButton-1.0-GE.lua")
	local s = source:find("local function StartChargeCooldown", 1, true)
	local e = s and source:find("\nend\n", s, true)
	check(s and e, "StartChargeCooldown found")
	local body = source:sub(s, e)
	check(body:find("parent.MasqueSkinned", 1, true) ~= nil, "charge skin only for handed-over buttons")
	check(body:find('Masque = Masque or LibStub("Masque", true)', 1, true) ~= nil, "Masque looked up lazily")
end

print(string.format("Masque: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end

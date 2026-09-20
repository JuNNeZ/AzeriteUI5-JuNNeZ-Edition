-- Offline harness for the AzeriteUI custom options panel.
--
-- Loads Options/Kit/*.lua under stubbed WoW and Ace3 APIs and exercises the
-- parts that are pure logic: widget registration, every widget constructor,
-- the dialogControl pass, the search index and the profile page restructure.
--
-- It cannot test rendering, taint, or whether the real Blizzard widgets behave
-- like these stubs.
--
-- Usage: lua kit_harness.lua <addon root>

local root = arg[1] or "."
local failures, checks = 0, 0

local function check(ok, what, detail)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print(string.format("  FAIL  %s%s", what, detail and ("  -- " .. tostring(detail)) or ""))
	end
	return ok
end

local function section(name)
	print("\n== " .. name .. " ==")
end

--------------------------------------------------------------------------
-- Widget / frame stubs
--------------------------------------------------------------------------
local numberMethods = {
	GetFrameLevel = 3, GetWidth = 200, GetHeight = 24, GetStringHeight = 12,
	GetVerticalScrollRange = 0, GetVerticalScroll = 0, GetNumPoints = 1,
	GetScale = 1, GetEffectiveScale = 1, GetTop = 100, GetLeft = 100,
	GetRight = 300, GetBottom = 50, GetAlpha = 1
}

local stringMethods = { GetText = "", GetTexture = "Interface\\Foo", GetObjectType = "Frame" }
local boolMethods = { IsShown = false, IsVisible = false, IsForbidden = false,
	IsObjectType = false, HasFocus = false, IsEnabled = true, IsMouseOver = false }

local makeStub

local stubMT = {}
stubMT.__index = function(t, key)
	local n = numberMethods[key]
	if n then return function() return n end end

	local s = stringMethods[key]
	if s ~= nil then return function() return s end end

	local b = boolMethods[key]
	if b ~= nil then return function() return b end end

	if key == "CreateFontString" or key == "GetFontString" then
		return function() return makeFontString() end
	end

	if key == "CreateTexture" or key == "GetThumbTexture"
		or key == "GetRegions" or key == "GetChildren"
		or key == "GetParent" or key == "GetNormalTexture" then
		return function() return makeStub() end
	end

	if key == "GetPoint" then
		return function() return "CENTER", nil, "CENTER", 0, 0 end
	end

	-- Everything else is a no-op setter.
	local fn = function() return t end
	rawset(t, key, fn)
	return fn
end

makeStub = function(fields)
	local t = fields or {}
	t.scripts = {}
	return setmetatable(t, stubMT)
end

-- A FontString that behaves like the client's: setting text through a font
-- object that has no font file throws "Font not set". This is modelled because
-- an earlier version of the harness handed back a always-valid font, and so
-- missed exactly that bug in the options panel's first in-game run.
function makeFontString()
	local fs = makeStub()
	fs.SetFontObject = function(self, font) rawset(self, "boundFont", font) return self end
	fs.GetFontObject = function(self) return rawget(self, "boundFont") end

	local function assertFont(self)
		local font = rawget(self, "boundFont")
		if font and not font.hasFont then
			error("FontString:SetText(): Font not set", 3)
		end
	end

	fs.SetText = function(self, text)
		assertFont(self)
		rawset(self, "textValue", text)
		return self
	end
	fs.SetFormattedText = function(self, fmt, ...)
		assertFont(self)
		rawset(self, "textValue", string.format(fmt, ...))
		return self
	end
	fs.GetText = function(self) return rawget(self, "textValue") or "" end
	return fs
end

local created = {}
function CreateFrame(frameType, name, parent, template)
	local f = makeStub({ frameType = frameType, name = name })
	f.SetScript = function(self, script, handler) self.scripts[script] = handler return self end
	f.GetScript = function(self, script) return self.scripts[script] end
	f.HookScript = f.SetScript
	created[#created + 1] = f
	if name then _G[name] = f end
	return f
end

UIParent = makeStub()
UISpecialFrames = {}
GameTooltip = makeStub()
function PlaySound() end
function InCombatLockdown() return false end
-- Cursor at a fixed point; GetLeft/GetWidth come from the stub metrics,
-- so the slider's cursor maths is exercised rather than skipped.
function GetCursorPosition() return 300, 200 end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_AddOns = { GetAddOnMetadata = function() return "5.4.13-JuNNeZ" end }
SEARCH = "Search"
CONFIRM_RESET_SETTINGS = "Reset?"
ACCEPT, CANCEL = "Accept", "Cancel"
function CreateColorFromHexString() return { WrapTextInColorCode = function(_, s) return s end } end
WHITE_FONT_COLOR = CreateColorFromHexString()
function ReloadUI() end
StaticPopupDialogs = {}
function StaticPopup_Show() end
function geterrorhandler() return function(msg) error(msg, 0) end end

--------------------------------------------------------------------------
-- Ace3 stubs
--------------------------------------------------------------------------
local registeredWidgets, widgetVersions = {}, {}

local WidgetBase = {}
WidgetBase.SetWidth = function(self, w) self.width_ = w if self.OnWidthSet then self:OnWidthSet(w) end end
WidgetBase.SetHeight = function(self, h) self.height_ = h if self.OnHeightSet then self:OnHeightSet(h) end end
WidgetBase.SetRelativeWidth = function(self, w) self.relWidth = w end
WidgetBase.SetFullWidth = function(self, v) self.width = v and "fill" or nil end
WidgetBase.SetFullHeight = function(self, v) self.height = v and "fill" or nil end
WidgetBase.SetCallback = function(self, name, fn) self.events[name] = fn end
WidgetBase.Fire = function(self, name, ...) if self.events[name] then return self.events[name](self, name, ...) end end
WidgetBase.SetUserData = function(self, k, v) self.userdata[k] = v end
WidgetBase.GetUserData = function(self, k) return self.userdata[k] end
WidgetBase.GetUserDataTable = function(self) return self.userdata end
WidgetBase.SetParent = function(self, p) self.parent = p end
WidgetBase.Release = function() end
WidgetBase.SetPoint = function() end
WidgetBase.ClearAllPoints = function() end

local ContainerBase = setmetatable({}, { __index = WidgetBase })
ContainerBase.SetLayout = function(self, l) self.layout = l end
ContainerBase.AddChild = function(self, c) self.children[#self.children + 1] = c end
ContainerBase.ReleaseChildren = function(self) self.children = {} end
ContainerBase.PauseLayout = function() end
ContainerBase.ResumeLayout = function() end
ContainerBase.DoLayout = function() end
ContainerBase.PerformLayout = function() end

local AceGUI = {}
AceGUI.RegisterWidgetType = function(self, name, ctor, version)
	registeredWidgets[name] = ctor
	widgetVersions[name] = version
end
AceGUI.GetWidgetVersion = function(self, name) return widgetVersions[name] end
AceGUI.RegisterAsWidget = function(self, w)
	w.userdata, w.events = {}, {}
	return setmetatable(w, { __index = WidgetBase })
end
AceGUI.RegisterAsContainer = function(self, w)
	w.userdata, w.events, w.children = {}, {}, {}
	return setmetatable(w, { __index = ContainerBase })
end
AceGUI.Create = function(self, name)
	local ctor = registeredWidgets[name]
	if not ctor then error("no such widget type: " .. tostring(name)) end
	local w = ctor()
	if w.OnAcquire then w:OnAcquire() end
	return w
end
AceGUI.ClearFocus = function() end
AceGUI.SetFocus = function() end
AceGUI.Release = function() end

local optionsTables = {}
local AceConfigRegistry = {
	GetOptionsTable = function(self, app) return optionsTables[app] end,
	RegisterOptionsTable = function(self, app, tbl) optionsTables[app] = tbl end,
	NotifyChange = function() end
}

local openCalls = {}
local AceConfigDialog = {
	Open = function(self, app, container, ...) openCalls[#openCalls + 1] = { app = app, path = { ... } } end,
	Close = function() end,
	SetDefaultSize = function() end,
	GetStatusTable = function(self, app, path)
		self.status = self.status or {}
		local key = table.concat(path or {}, "\001")
		self.status[key] = self.status[key] or {}
		return self.status[key]
	end
}

local localeMT = { __index = function(t, k) return k end }
local AceLocale = {
	GetLocale = function() return setmetatable({}, localeMT) end,
	NewLocale = function() return setmetatable({}, localeMT) end
}

local libs = {
	["AceGUI-3.0"] = AceGUI,
	["AceConfigDialog-3.0"] = AceConfigDialog,
	["AceConfigRegistry-3.0"] = AceConfigRegistry,
	["AceLocale-3.0"] = AceLocale
}

LibStub = setmetatable({}, {
	__call = function(self, name, silent)
		local lib = libs[name]
		if not lib and not silent then error("LibStub: missing " .. name) end
		return lib
	end
})

--------------------------------------------------------------------------
-- Namespace stub
--------------------------------------------------------------------------
-- Which font globals FontStyles.xml really defines. Assets.lua answers any
-- other size with a bare CreateFont() object that has no font file.
definedFonts = {}
do
	local handle = io.open(root .. "/FontStyles.xml")
	if handle then
		local xml = handle:read("*a")
		handle:close()
		for name in xml:gmatch('name="(Azerite[%w]+)"') do
			definedFonts[name] = true
		end
	end
end

local fontCache = {}
local function getFont(size, outline, fontType)
	local namedType = (fontType and fontType ~= "Normal") and fontType or ""
	local namedStyle = outline and "Outline" or ""
	local globalName = "AzeriteFont" .. namedType .. tostring(size) .. namedStyle

	if not fontCache[globalName] then
		local font = makeStub()
		font.hasFont = definedFonts[globalName] or false
		font.GetFont = function(self)
			if not self.hasFont then return nil end
			return "Fonts\FRIZQT__.TTF", size, namedStyle
		end
		font.name = globalName
		fontCache[globalName] = font
	end
	return fontCache[globalName]
end

local modules = {}

local ns = {
	Prefix = "Azerite",
	BackdropTemplate = "BackdropTemplate",
	IsRetail = true,
	API = {
		GetFont = function(size, outline, fontType) return getFont(size, outline, fontType) end,
		GetMedia = function(name, ext)
			return string.format([[Interface\AddOns\Test\Assets\%s.%s]], name, ext or "tga")
		end
	},
	Colors = {
		normal = { 229 / 255, 178 / 255, 38 / 255 },
		highlight = { 250 / 255, 250 / 255, 250 / 255 },
		offwhite = { 196 / 255, 196 / 255, 196 / 255 },
		class = {
			WARRIOR = { 199 / 255, 156 / 255, 110 / 255 },
			MAGE = { 105 / 255, 204 / 255, 240 / 255 }
		}
	},
	db = { global = {} },
	NewModule = function(self, name)
		modules[name] = setmetatable({}, { __index = function(t, k)
			-- Stand in for the Ace mixins the module embeds.
			local fn = function() end
			rawset(t, k, fn)
			return fn
		end })
		return modules[name]
	end,
	GetModule = function(self, name) return modules[name] end,
	Print = function(_, ...) print("  ns:Print", ...) end,
	RegisterCallback = function() end,
	GetProfiles = function() return { "Azerite" } end,
	GetProfile = function() return "Azerite" end,
	SetProfile = function() end,
	IsBuiltinProfile = function() return true end,
	ProfileExists = function() return false end,
	DeleteProfile = function() end,
	DuplicateProfile = function() end,
	ResetProfile = function() end,
	Export = function() return "" end,
	Import = function() return true end,
	DecodeImport = function() return {} end
}

local Addon = "AzeriteUI5_JuNNeZ_Edition"

local function load(relative)
	local path = root .. "/" .. relative
	local chunk, err = loadfile(path)
	if not chunk then error("could not load " .. path .. ": " .. tostring(err)) end
	return chunk(Addon, ns)
end

--------------------------------------------------------------------------
section("Loading")
--------------------------------------------------------------------------
local ok, err = pcall(load, "Options/Kit/Kit.lua")
check(ok, "Kit.lua loads", err)

ok, err = pcall(load, "Options/Kit/Config.lua")
check(ok, "Config.lua loads", err)

ok, err = pcall(load, "Options/Kit/Controls.lua")
check(ok, "Controls.lua loads", err)

ok, err = pcall(load, "Options/Kit/Gallery.lua")
check(ok, "Gallery.lua loads", err)

ok, err = pcall(load, "Options/Kit/Widgets.lua")
check(ok, "Widgets.lua loads", err)

ok, err = pcall(load, "Options/Kit/Window.lua")
check(ok, "Window.lua loads", err)

local Kit = ns.OptionsKit
check(Kit ~= nil, "ns.OptionsKit exists")
check(Kit and Kit.Window ~= nil, "Kit.Window exists")
check(Kit and Kit.Types ~= nil, "Kit.Types exists")

--------------------------------------------------------------------------
section("Fonts")
--------------------------------------------------------------------------
-- FontStyles.xml only defines plain faces at 11 and 12. Assets.lua hands back
-- a font-less CreateFont() object for anything else, and setting text on one
-- throws. The kit must never surface such an object.
check(next(definedFonts) ~= nil, "FontStyles.xml was read", "no font globals found")
check(definedFonts["AzeriteFont12"] == true, "plain 12 exists")
check(definedFonts["AzeriteFont13Outline"] == true, "outlined 13 exists")

-- Plain faces above 12 were added to FontStyles.xml for the options panel.
-- Their absence is what threw "Font not set" on the first in-game run.
for _, size in ipairs({ 13, 14, 15, 16, 17, 18, 19, 20 }) do
	check(definedFonts["AzeriteFont" .. size] == true,
		"plain " .. size .. " is defined for the options panel")
end

-- Sizes past the defined set still fall through to a font-less object, so the
-- guard in Kit.GetFont still has work to do.
check(ns.API.GetFont(99).hasFont == false, "raw GetFont(99) is font-less")

for _, spec in ipairs({ { 11 }, { 12 }, { 13 }, { 14 }, { 18 }, { 99 },
                        { 13, true }, { 14, true }, { 18, true }, { 99, true } }) do
	local size, outline = spec[1], spec[2]
	local font = Kit.GetFont(size, outline)
	local label = string.format("Kit.GetFont(%d%s)", size, outline and ", true" or "")
	check(font and font.GetFont and font:GetFont() ~= nil,
		label .. " returns a usable font", font and font.name)
end

-- Prove the model bites. Without this the checks above could pass vacuously,
-- which is how the original bug reached the game in the first place.
do
	local bad = makeFontString()
	bad:SetFontObject(ns.API.GetFont(99))
	local threw = not pcall(bad.SetText, bad, "x")
	check(threw, "harness reproduces 'Font not set' for a font-less object")

	local good = makeFontString()
	good:SetFontObject(Kit.GetFont(99))
	local ok = pcall(good.SetText, good, "x")
	check(ok, "a font from Kit.GetFont sets text cleanly")
end

--------------------------------------------------------------------------
section("Themes")
--------------------------------------------------------------------------
local values, order = Kit.GetThemeChoices()
check(type(values) == "table" and type(order) == "table", "theme choices are returned")
check(#order == 4, "four themes are offered", #order)
check(order[1] == "azerite", "azerite is offered first", order[1])

-- The colour tables must keep their identity across a theme change: widgets
-- capture them by reference when built, and a pooled widget is never rebuilt.
local accentRef = Kit.TextSelected
local windowRef = Kit.WindowColor
local azeriteAccent = { Kit.TextSelected[1], Kit.TextSelected[2], Kit.TextSelected[3] }

Kit.SetTheme("light")
check(Kit.GetTheme() == "light", "theme switches to light")
check(Kit.TextSelected == accentRef, "accent table keeps its identity across a theme change")
check(Kit.WindowColor == windowRef, "window table keeps its identity across a theme change")
check(Kit.WindowColor[1] > 0.5, "light theme really is light", Kit.WindowColor[1])
check(Kit.TextNormal[1] < 0.5, "light theme uses dark text", Kit.TextNormal[1])

Kit.SetTheme("dark")
check(Kit.WindowColor[1] < 0.1, "dark theme really is dark", Kit.WindowColor[1])

-- The class theme has no accent of its own; it resolves one at apply time.
Kit.SetTheme("class")
check(Kit.GetTheme() == "class", "theme switches to class")
check(Kit.TextSelected[1] ~= nil and Kit.TextSelected[2] ~= nil and Kit.TextSelected[3] ~= nil,
	"class theme resolves a full accent colour")

Kit.SetTheme("nonsense-theme")
check(Kit.GetTheme() == "azerite", "an unknown theme falls back to azerite rather than half-applying")
check(math.abs(Kit.TextSelected[1] - azeriteAccent[1]) < 0.001, "the fallback restores azerite's accent")

-- Every theme must fill in every token, or a widget reads a nil colour.
for _, key in ipairs(order) do
	Kit.SetTheme(key)
	for _, token in ipairs({ "TextNormal", "TextHighlight", "TextSelected", "TextDisabled",
	                         "BorderIdle", "BorderHover", "BorderFocus",
	                         "WindowColor", "BackdropColor", "InsetColor", "TrackColor" }) do
		local c = Kit[token]
		check(c and c[1] and c[2] and c[3], key .. " fills in " .. token)
	end
end
-- Opacity scales the fill alpha a theme asks for, and must leave the borders
-- alone: a half-transparent border stops reading as an edge and the window
-- loses its shape.
do
	Kit.SetTheme("azerite")
	Kit.SetOpacity(1)
	local fullWindow = Kit.WindowColor[4]
	local fullInset = Kit.InsetColor[4]
	local borderAlpha = Kit.BorderIdle[4]

	Kit.SetOpacity(0.5)
	check(math.abs(Kit.WindowColor[4] - fullWindow * 0.5) < .001,
		"opacity halves the window fill", Kit.WindowColor[4])
	check(math.abs(Kit.InsetColor[4] - fullInset * 0.5) < .001,
		"opacity halves the inset fill", Kit.InsetColor[4])
	check(Kit.BorderIdle[4] == borderAlpha,
		"opacity leaves the border alone", Kit.BorderIdle[4])

	-- The colour tables must keep their identity, as with a theme change.
	local ref = Kit.WindowColor
	Kit.SetOpacity(0.8)
	check(Kit.WindowColor == ref, "opacity keeps the colour table identity")

	-- A panel nobody can see is not a setting worth being one click away.
	Kit.SetOpacity(0)
	check(Kit.GetOpacity() >= Kit.MinOpacity, "opacity clamps at the bottom", Kit.GetOpacity())
	Kit.SetOpacity(5)
	check(Kit.GetOpacity() == 1, "opacity clamps at the top", Kit.GetOpacity())

	-- Changing theme must not silently restore full opacity.
	Kit.SetOpacity(0.6)
	Kit.SetTheme("dark")
	check(math.abs(Kit.GetOpacity() - 0.6) < .001, "opacity survives a theme change")

	Kit.SetOpacity(1)
	Kit.SetTheme("azerite")
end

-- Contrast. A theme whose body text is unreadable against its own window is a
-- bug that only shows up by eye, so it is measured here instead. Ratios are
-- WCAG relative luminance; 4.5 is the usual floor for body text.
local function channel(c)
	return (c <= 0.03928) and (c / 12.92) or (((c + 0.055) / 1.055) ^ 2.4)
end

local function luminance(c)
	return 0.2126 * channel(c[1]) + 0.7152 * channel(c[2]) + 0.0722 * channel(c[3])
end

local function contrast(a, b)
	local la, lb = luminance(a), luminance(b)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end

print("        theme      body   accent   muted")
for _, key in ipairs(order) do
	Kit.SetTheme(key)
	local bg = Kit.WindowColor
	local body = contrast(Kit.TextNormal, bg)
	local accent = contrast(Kit.TextSelected, bg)
	local muted = contrast(Kit.TextDisabled, bg)
	print(string.format("  %12s  %5.1f    %5.1f   %5.1f", key, body, accent, muted))

	check(body >= 4.5, key .. ": body text is readable on its own window", string.format("%.1f", body))
	check(accent >= 3.0, key .. ": accent is readable on its own window", string.format("%.1f", accent))
	check(muted >= 2.0, key .. ": muted text is still visible", string.format("%.1f", muted))
end
Kit.SetTheme("azerite")

--------------------------------------------------------------------------
section("Widget registration")
--------------------------------------------------------------------------
local expected = { "Page", "Heading", "Button", "CheckBox", "EditBox", "Slider", "Dropdown" }
for _, short in ipairs(expected) do
	local typeName = Kit.Types[short]
	check(typeName ~= nil, "Kit.Types." .. short .. " is named")
	check(registeredWidgets[typeName] ~= nil, short .. " is registered as " .. tostring(typeName))
	-- No stock AceGUI name may be claimed.
	check(typeName ~= short, short .. " does not claim the stock AceGUI name")
end

for name in pairs(registeredWidgets) do
	check(name:find(Addon, 1, true) == 1, "registered type is namespaced: " .. name)
end

--------------------------------------------------------------------------
section("Widget constructors")
--------------------------------------------------------------------------
local widgets = {}
for _, short in ipairs(expected) do
	local w
	ok, err = pcall(function() w = AceGUI:Create(Kit.Types[short]) end)
	check(ok, short .. " constructs and acquires", err)
	widgets[short] = w
end

-- Drive each widget through the calls AceConfigDialog actually makes.
local function drive(short, fn)
	local w = widgets[short]
	if not w then return end
	local ok2, err2 = pcall(fn, w)
	check(ok2, short .. " survives its AceConfigDialog contract", err2)
end

drive("CheckBox", function(w)
	w:SetLabel("Enable")
	w:SetTriState(nil)
	w:SetValue(true)
	check(w:GetValue() == true, "CheckBox stores true")
	w:ToggleChecked()
	check(w:GetValue() == false, "CheckBox toggles to false")
	w:SetTriState(true)
	w:SetValue(nil)
	w:ToggleChecked()
	check(w:GetValue() == false, "CheckBox tristate cycles nil -> false")
	w:SetDescription("A description")
	w:SetDescription(nil)
	w:SetImage()
	w:SetDisabled(true)
	w:SetDisabled(false)
end)

drive("Slider", function(w)
	w:SetLabel("Scale")
	w:SetSliderValues(0, 2, 0.1)
	w:SetIsPercent(nil)
	w:SetValue(1.25)
	check(w:GetValue() == 1.25, "Slider stores its value")
	w:SetIsPercent(true)
	w:SetValue(0.5)
	w:SetDisabled(true)
	w:SetDisabled(false)

	-- The fill is a StatusBar driven by min/max/value. The previous version
	-- sized it by hand from the track's pixel width and hid it whenever that
	-- width was still zero, which is the state every refresh starts in - so
	-- the bar vanished after each change until the next drag.
	check(w.fill ~= nil, "Slider fill is a StatusBar, not a hand-sized texture")
	check(w.trackFill == nil, "the hand-sized fill is gone")

	-- The trough is three-sliced so its chamfered ends hold their shape at any
	-- width, which a single stretched texture cannot do.
	check(type(w.trackSlices) == "table" and #w.trackSlices == 3,
		"the trough is three-sliced", w.trackSlices and #w.trackSlices)

	-- Re-acquiring is what a page refresh does. Nothing may hide the fill.
	w:OnAcquire()
	w:SetSliderValues(0, 2, 0.1)
	w:SetValue(1.5)
	check(w.fill.hidden ~= true, "the fill is not hidden by a fresh acquire")
end)

drive("Dropdown", function(w)
	w:SetLabel("Style")
	w:SetList({ a = "Azerite", b = "Blizzard" }, { "a", "b" })
	w:SetValue("b")
	check(w:GetValue() == "b", "Dropdown stores its value")
	-- Unsorted lists must still order deterministically.
	w:SetList({ z = "Zebra", m = "Mongoose", a = "Aardvark" })
	check(w.order[1] == "a" and w.order[3] == "z", "Dropdown sorts an unordered list by label")
	w:SetDisabled(true)
	w:SetDisabled(false)
end)

drive("EditBox", function(w)
	w:SetLabel("Name")
	w:SetText("hello")
	w:SetDisabled(true)
	w:SetDisabled(false)
	w:SetLabel("")
end)

drive("Button", function(w)
	w:SetText("Apply")
	w:SetDisabled(true)
	w:SetDisabled(false)
end)

drive("Heading", function(w)
	w:SetText("A heading")
	w:SetText("")
	w:SetDisabled(false)
end)

drive("Page", function(w)
	w:SetWidth(700)
	w:SetHeight(500)
	w:SetLayout("flow")
	w:ReleaseChildren()
	-- A finished layout must not resize the page out from under the window.
	w:LayoutFinished(700, 4000)
	check(w.height_ == 500, "Page keeps the height the window gave it")
end)

--------------------------------------------------------------------------
section("Controls (the new panel)")
--------------------------------------------------------------------------
local Controls = Kit.Controls
check(Controls ~= nil, "Kit.Controls exists")

-- These are ours outright. Nothing may reach AceGUI's global registry.
local beforeTypes = 0
for _ in pairs(registeredWidgets) do beforeTypes = beforeTypes + 1 end

local parent = CreateFrame("Frame")
local made = {}

for _, kind in ipairs({ "toggle", "range", "select", "input", "execute", "header", "description" }) do
	local c
	local ok2, err2 = pcall(function() c = Controls.Create(parent, kind) end)
	check(ok2, "Controls.Create " .. kind .. " builds", err2)
	check(c ~= nil, "Controls.Create " .. kind .. " returns a control")
	made[kind] = c
end

local afterTypes = 0
for _ in pairs(registeredWidgets) do afterTypes = afterTypes + 1 end
check(beforeTypes == afterTypes,
	"building controls registers nothing with AceGUI", afterTypes - beforeTypes)

-- A select with few values becomes a strip; with many, a dropdown.
local few = Controls.Create(parent, "select", nil, 3)
local many = Controls.Create(parent, "select", nil, 12)
check(few and few.segmented == true, "a select with 3 values becomes a segmented strip")
check(many and many.segmented ~= true, "a select with 12 values stays a dropdown")
check(Controls.Create(parent, "select", nil, Controls.SegmentedLimit).segmented == true,
	"the segmented limit itself is segmented")
check(Controls.Create(parent, "select", nil, Controls.SegmentedLimit + 1).segmented ~= true,
	"one past the limit is a dropdown")

-- The shared contract every control must answer.
for kind, c in pairs(made) do
	for _, method in ipairs({ "SetLabel", "SetHelp", "SetDisabled", "SetModified",
	                          "SetCallback", "SetOnRevert", "Restyle", "GetHeight" }) do
		check(type(c[method]) == "function", kind .. " answers " .. method)
	end
	check(c.frame ~= nil, kind .. " has a frame")
	check(c.kind ~= nil, kind .. " declares its kind")
end

-- A help line makes the row taller, and removing it shrinks it back.
do
	local c = made.toggle
	local bare = c:GetHeight()
	c:SetHelp("a line of help")
	local withHelp = c:GetHeight()
	check(withHelp > bare, "help makes a row taller", string.format("%d -> %d", bare, withHelp))
	c:SetHelp(nil)
	check(c:GetHeight() == bare, "removing help shrinks it back")
end

-- Both the trough and the fill must be three-sliced, which is the whole point:
-- a stretched fill grows its chamfers with the bar, which is what looked wrong
-- in game at high values.
do
	local c = made.range
	for _, part in ipairs({ "trough", "fill" }) do
		local bar = c[part]
		check(bar ~= nil, "slider has a " .. part)
		check(bar and bar.left and bar.mid and bar.right,
			"the slider " .. part .. " is three-sliced")
	end
	check(made.toggle.trough and made.toggle.trough.left, "the toggle trough is three-sliced")
	check(made.toggle.fill and made.toggle.fill.left, "the toggle fill is three-sliced")
end

-- Driving each control through what the renderer will do to it.
local function drives(kind, fn)
	local ok2, err2 = pcall(fn, made[kind])
	check(ok2, kind .. " survives being driven", err2)
end

drives("toggle", function(c)
	c:SetLabel("t") c:SetValue(true)
	check(c:GetValue() == true, "toggle stores true")
	c:SetValue(false)
	check(c:GetValue() == false, "toggle stores false")
	c:SetDisabled(true) c:SetDisabled(false)
	c:SetModified(true) c:SetModified(false)
end)

drives("range", function(c)
	c:SetSliderValues(0, 2, .1) c:SetValue(1.5)
	check(c:GetValue() == 1.5, "slider stores its value")
	c:SetIsPercent(true) c:SetIsPercent(false)
	c:SetDisabled(true) c:SetDisabled(false)

	-- The knob is ours, and the Slider's own thumb must contribute no travel
	-- inset. point_diamond is a 54px texture for a 24px diamond, and a thumb
	-- that size stops 27px short of both ends while the fill runs the whole way.
	check(c.knob ~= nil, "the slider draws its own knob")
	check(c.knobHost ~= nil, "the knob has a frame of its own, so it draws in front of the fill")
	check(c.input ~= nil, "the slider takes input through a plain frame")

	-- A WoW Slider re-fires OnValueChanged when it is resized, remapping the old
	-- thumb position into the new width. Laid out at zero width its thumb reads
	-- as the maximum, which is what kept turning 97 into 100.
	check(c.slider == c.input, "there is no WoW Slider left to re-fire on resize")

	-- Dragging must not depend on thumb geometry.
	local down = c.slider:GetScript("OnMouseDown")
	check(type(down) == "function", "the slider takes its value from the cursor")
	if (down) then
		local ok3, err3 = pcall(down, c.slider)
		check(ok3, "pressing the slider does not error", err3)
		local upd = c.slider:GetScript("OnUpdate")
		check(type(upd) == "function", "pressing the slider starts tracking the cursor")
		if (upd) then pcall(upd, c.slider) end
		local up = c.slider:GetScript("OnMouseUp")
		if (up) then pcall(up, c.slider) end
		check(c.slider:GetScript("OnUpdate") == nil, "releasing stops tracking")
	end

	-- A disabled slider must ignore the press entirely.
	c:SetDisabled(true)
	if (down) then pcall(down, c.slider) end
	check(c.slider:GetScript("OnUpdate") == nil, "a disabled slider does not track")
	c:SetDisabled(false)

	-- Setting a value programmatically must never call back; only a drag may.
	-- Otherwise the renderer writing a value into a control would write it
	-- straight back out to the database again.
	local fired = 0
	c:SetCallback(function() fired = fired + 1 end)
	c:SetSliderValues(0, 100, 1)
	c:SetValue(42)
	check(fired == 0, "a programmatic SetValue does not call back", fired)
	check(c:GetValue() == 42, "a programmatic SetValue still takes", c:GetValue())
	c:SetValue(43, true)
	check(fired == 1, "a user-driven SetValue does call back", fired)
	c:SetCallback(nil)

	-- The value must survive the control being resized, which is the exact path
	-- that used to turn 97 into 100 as soon as the page was laid out.
	c:SetValue(97)
	local onSize = c.track:GetScript("OnSizeChanged")
	if (onSize) then pcall(onSize, c.track, 240, 18) end
	check(c:GetValue() == 97, "the value survives a resize", c:GetValue())

	-- And it must clamp and step, since nothing else does that for us now.
	c:SetSliderValues(0, 10, 1)
	c:SetValue(999)
	check(c:GetValue() == 10, "values clamp to the maximum", c:GetValue())
	c:SetValue(-5)
	check(c:GetValue() == 0, "values clamp to the minimum", c:GetValue())
	c:SetSliderValues(0, 1, .25)
	c:SetValue(.6)
	check(math.abs(c:GetValue() - .5) < .001, "values snap to the step", c:GetValue())
end)

drives("select", function(c)
	c:SetList({ a = "A", b = "B", c = "C", d = "D", e = "E" }, { "a", "b", "c", "d", "e" })
	c:SetValue("c")
	check(c:GetValue() == "c", "dropdown stores its value")
	-- An unordered list must still be deterministic.
	c:SetList({ z = "Zeta", m = "Mid", a = "Alpha" })
	check(c.order[1] == "a" and c.order[3] == "z", "dropdown sorts an unordered list by label")
	c:SetDisabled(true) c:SetDisabled(false)
end)

drives("input", function(c)
	c:SetValue("hello")
	c:SetDisabled(true) c:SetDisabled(false)
end)

drives("execute", function(c)
	c:SetText("Do the thing")
	c:SetDisabled(true) c:SetDisabled(false)
end)

drives("header", function(c) c:SetLabel("A group") end)
drives("description", function(c) c:SetLabel("Some prose.") end)

-- A callback fires with the new value.
do
	local seen
	local c = made.toggle
	c:SetCallback(function(self, value) seen = value end)
	c:SetValue(false)
	c.box:GetScript("OnClick")(c.box)
	check(seen == true, "toggling fires the callback with the new value", tostring(seen))
end

-- Revert only does anything once something can revert it.
do
	local c = made.range
	local reverted = false
	c:SetModified(true)
	c:SetOnRevert(function() reverted = true end)
	c:SetModified(true)
	c.revert:GetScript("OnClick")(c.revert)
	check(reverted, "the revert button calls back")
end

-- Every control must survive every theme.
for _, key in ipairs(order) do
	Kit.SetTheme(key)
	for kind, c in pairs(made) do
		local ok2, err2 = pcall(c.Restyle, c)
		check(ok2, kind .. " restyles under the " .. key .. " theme", err2)
	end
end
Kit.SetTheme("azerite")

--------------------------------------------------------------------------
section("Gallery")
--------------------------------------------------------------------------
local Gallery = Kit.Gallery
check(Gallery ~= nil, "Kit.Gallery exists")

ok, err = pcall(function() Gallery:Open() end)
check(ok, "the gallery builds and opens", err)

for _, key in ipairs(order) do
	Kit.SetTheme(key)
	local ok2, err2 = pcall(Gallery.Restyle)
	check(ok2, "the gallery restyles under the " .. key .. " theme", err2)
end
Kit.SetTheme("azerite")

ok, err = pcall(function() Gallery:Close() end)
check(ok, "the gallery closes", err)

--------------------------------------------------------------------------
section("dialogControl pass")
--------------------------------------------------------------------------
local T = Kit.Types
local sample = {
	type = "group",
	args = {
		page = {
			type = "group",
			name = "A page",
			args = {
				toggle      = { type = "toggle", name = "T" },
				range       = { type = "range", name = "R" },
				header      = { type = "header", name = "H" },
				select      = { type = "select", name = "S", values = {} },
				radio       = { type = "select", style = "radio", name = "Ra", values = {} },
				input       = { type = "input", name = "I" },
				multiline   = { type = "input", name = "M", multiline = 8 },
				execute     = { type = "execute", name = "E", func = function() end },
				iconexecute = { type = "execute", name = "IE", image = "foo", func = function() end },
				description = { type = "description", name = "D" },
				preset      = { type = "toggle", name = "P", dialogControl = "SomebodyElse" },
				colour      = { type = "color", name = "C" },
				keybind     = { type = "keybinding", name = "K" },
				multi       = { type = "multiselect", name = "MS", values = {} }
			}
		}
	}
}

Kit.Window:ApplyDialogControls(sample)
local a = sample.args.page.args

check(a.toggle.dialogControl == T.CheckBox, "toggle -> CheckBox")
check(a.range.dialogControl == T.Slider, "range -> Slider")
check(a.header.dialogControl == T.Heading, "header -> Heading")
check(a.select.dialogControl == T.Dropdown, "select -> Dropdown")
check(a.input.dialogControl == T.EditBox, "input -> EditBox")
check(a.execute.dialogControl == T.Button, "execute -> Button")

check(a.multiline.dialogControl == nil, "multiline input is left to the stock widget")
check(a.iconexecute.dialogControl == nil, "execute with an image is left as an Icon")
check(a.description.dialogControl == nil, "description is left to the stock Label")
check(a.colour.dialogControl == nil, "color is left to the stock picker")
check(a.keybind.dialogControl == nil, "keybinding is left to the stock widget")
check(a.multi.dialogControl == nil, "multiselect is left to the stock widget")
check(a.preset.dialogControl == "SomebodyElse", "an existing dialogControl is not overwritten")
check(a.radio.dialogControl == T.Dropdown or a.radio.dialogControl == nil,
	"radio select is harmless either way")

-- Every control the pass hands out must be a type we actually registered.
for key, v in pairs(a) do
	if v.dialogControl and v.dialogControl ~= "SomebodyElse" then
		check(registeredWidgets[v.dialogControl] ~= nil,
			"dialogControl on '" .. key .. "' names a registered type", v.dialogControl)
	end
end

-- `/az classic` must hand every option back to its stock widget, or a fault in
-- one of ours takes the fallback window down too.
Kit.Window:RemoveDialogControls()
local stillOurs, stillTheirs = {}, 0
for key, v in pairs(a) do
	if v.dialogControl then
		if v.dialogControl == "SomebodyElse" then
			stillTheirs = stillTheirs + 1
		else
			stillOurs[#stillOurs + 1] = key
		end
	end
end
check(#stillOurs == 0, "RemoveDialogControls clears every injected control",
	table.concat(stillOurs, ", "))
check(stillTheirs == 1, "RemoveDialogControls leaves a foreign control alone")

-- ...and re-opening the window must put them back.
Kit.Window:ApplyDialogControls(sample)
check(a.toggle.dialogControl == T.CheckBox, "controls are restored after a classic round trip")
check(a.preset.dialogControl == "SomebodyElse", "the foreign control is still untouched")

--------------------------------------------------------------------------
section("Options table restructure")
--------------------------------------------------------------------------
ok, err = pcall(load, "Options/Options.lua")
check(ok, "Options.lua loads", err)

local Options = modules["Options"]
check(Options ~= nil, "Options module registered")

if Options and Options.GenerateProfileMenu then
	local opts, offset = Options:GenerateProfileMenu()
	check(type(opts) == "table", "GenerateProfileMenu returns a table")
	check(offset == 0, "order offset is 0")
	check(opts.args.profiles ~= nil, "profiles group exists")
	check(opts.args.profiles.type == "group", "profiles is a group, not a bare control")

	-- The whole point of the restructure: the root holds groups only, so the
	-- window can build a page list straight from it.
	local nonGroups = {}
	for key, v in pairs(opts.args) do
		if v.type ~= "group" then nonGroups[#nonGroups + 1] = key end
	end
	check(#nonGroups == 0, "root holds groups only", table.concat(nonGroups, ", "))

	-- The create/duplicate buttons reach the name box through the new path.
	local info = { options = opts }
	local created = opts.args.profiles.args.create
	local dup = opts.args.profiles.args.duplicate
	check(created ~= nil and dup ~= nil, "create and duplicate survive the move")
	if created then
		local ok2, err2 = pcall(created.disabled, info)
		check(ok2, "create:disabled reaches the profile name box", err2)
		local ok3, err3 = pcall(created.func, info)
		check(ok3, "create:func reaches the profile name box", err3)
	end
	if dup then
		local ok2, err2 = pcall(dup.disabled, info)
		check(ok2, "duplicate:disabled reaches the profile name box", err2)
		local ok3, err3 = pcall(dup.func, info)
		check(ok3, "duplicate:func reaches the profile name box", err3)
	end
end

--------------------------------------------------------------------------
section("Search")
--------------------------------------------------------------------------
-- Register a table shaped like the real one and drive the window's own
-- indexing and result building through it.
local searchable = {
	type = "group",
	childGroups = "tree",
	args = {
		["Unit Frames"] = {
			type = "group", name = "Unit Frames", order = 10,
			args = {
				player = {
					type = "group", name = "Player",
					args = {
						enable = { type = "toggle", name = "Enable Player Frame", desc = "Show the player frame." },
						scale = { type = "range", name = "Scale", min = 0.5, max = 2 }
					}
				},
				secret = { type = "group", name = "Hidden", hidden = true, args = {
					nope = { type = "toggle", name = "Unreachable" }
				} }
			}
		},
		["Action Bars"] = {
			type = "group", name = "Action Bars", order = 20,
			args = { empty = { type = "toggle", name = "Show empty buttons" } }
		}
	}
}
optionsTables[Addon] = searchable
modules["Options"].GetOptionsObject = function() return searchable end

local Window = Kit.Window
ok, err = pcall(function() Window:Open() end)
check(ok, "Window:Open() builds the window and a page", err)
check(#openCalls > 0, "a page was fed to AceConfigDialog")

if Window.pages then
	check(#Window.pages == 2, "rail lists both pages", #Window.pages)
	check(Window.pages[1].name == "Unit Frames", "rail sorts by order", Window.pages[1].name)
end

ok, err = pcall(function() Window:ShowResults("empty") end)
check(ok, "search runs", err)

ok, err = pcall(function() Window:ShowResults("zzzznothing") end)
check(ok, "search with no matches runs", err)

ok, err = pcall(function() Window:ClearSearch() end)
check(ok, "clearing search rebuilds the rail", err)

-- A search result must be able to navigate to a nested path.
openCalls = {}
ok, err = pcall(function() Window:NavigateTo({ "Unit Frames", "player" }) end)
check(ok, "NavigateTo runs on a nested path", err)
check(#openCalls == 1, "NavigateTo opens exactly one page")
if openCalls[1] then
	check(openCalls[1].path[1] == "Unit Frames",
		"NavigateTo opens the top-level page, not the leaf", openCalls[1].path[1])
end
local status = AceConfigDialog:GetStatusTable(Addon, { "Unit Frames" })
check(status.groups and status.groups.selected == "player",
	"NavigateTo preselects the tab holding the match")

--------------------------------------------------------------------------
print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

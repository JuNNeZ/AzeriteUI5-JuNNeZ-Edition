-- Shared stubs, extracted from kit_harness.lua.
local root = arg[1] or "."
local M = {}
--------------------------------------------------------------------------
-- Widget / frame stubs
--------------------------------------------------------------------------
-- GetFrameLevel is deliberately not here: it is recorded per frame below, so
-- there is one answer to it rather than a constant and a record.
local numberMethods = {
	GetWidth = 200, GetHeight = 24, GetStringHeight = 12,
	GetVerticalScrollRange = 0, GetVerticalScroll = 0, GetNumPoints = 1,
	GetScale = 1, GetEffectiveScale = 1, GetTop = 100, GetLeft = 100,
	GetRight = 300, GetBottom = 50, GetAlpha = 1
}

local stringMethods = { GetText = "", GetTexture = "Interface\\Foo", GetObjectType = "Frame" }
local boolMethods = { IsForbidden = false, IsObjectType = false }

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

	-- Everything else that looks like a widget method is a no-op setter.
	--
	-- Only methods, though. Every widget method the game has starts with a
	-- capital, and everything the addon hangs on a frame itself is lowercase:
	-- row.offset, row.label, self.scrollRange. Answering those with a no-op
	-- function made them truthy before anything had set them, so
	-- `self.scrollRange or 4000` never reached the 4000 and `row.railOffset or 0`
	-- handed a function to min(). An unset field has to read as nil, as it does
	-- in the game.
	if (type(key) ~= "string" or not key:match("^%u")) then
		return nil
	end

	local fn = function() return t end
	rawset(t, key, fn)
	return fn
end

-- Whether something is drawn is the one piece of frame state the panel reads
-- back, and for a long time the stub answered "no" to IsShown whatever had been
-- Shown, so every check that asked was measuring the stub. Show, Hide and
-- SetShown now record it and IsShown reports it, as the game does. A real frame
-- starts shown, so these do too.
--
-- IsVisible is the shown flag as well, not the parent chain: nothing here hides
-- a container and then asks about its children, and walking parents would need
-- a parent graph the stub does not keep.
local visibility = function(t)
	rawset(t, "shownValue", true)

	rawset(t, "Show", function(self) rawset(self, "shownValue", true) return self end)
	rawset(t, "Hide", function(self) rawset(self, "shownValue", false) return self end)
	rawset(t, "SetShown", function(self, shown)
		rawset(self, "shownValue", shown and true or false)
		return self
	end)
	rawset(t, "IsShown", function(self) return rawget(self, "shownValue") and true or false end)
	rawset(t, "IsVisible", function(self) return rawget(self, "shownValue") and true or false end)

	-- A size that was set reads back. Nothing here resolves anchors, so a frame
	-- sized by SetPoint still answers the default; but a frame that was told a
	-- height and then asked has to say what it was told, or a scroll range
	-- computed from it is fiction.
	rawset(t, "SetHeight", function(self, h) rawset(self, "heightValue", h) return self end)
	rawset(t, "SetWidth", function(self, w) rawset(self, "widthValue", w) return self end)
	rawset(t, "SetSize", function(self, w, h)
		rawset(self, "widthValue", w)
		rawset(self, "heightValue", h)
		return self
	end)
	rawset(t, "GetHeight", function(self) return rawget(self, "heightValue") or 24 end)
	rawset(t, "GetWidth", function(self) return rawget(self, "widthValue") or 200 end)

	-- What was last painted on it. The panel's whole theme is backdrop colours,
	-- and with these as no-op setters nothing could tell a window that had been
	-- repainted from one that had not.
	rawset(t, "SetBackdropColor", function(self, r, g, b, a)
		rawset(self, "backdropColor", { r, g, b, a })
		return self
	end)
	rawset(t, "GetBackdropColor", function(self)
		local c = rawget(self, "backdropColor")
		if not c then return nil end
		return c[1], c[2], c[3], c[4]
	end)
	rawset(t, "SetBackdropBorderColor", function(self, r, g, b, a)
		rawset(self, "borderColor", { r, g, b, a })
		return self
	end)
	rawset(t, "GetBackdropBorderColor", function(self)
		local c = rawget(self, "borderColor")
		if not c then return nil end
		return c[1], c[2], c[3], c[4]
	end)

	-- Which backdrop a frame was given, so a check about the art it is drawn
	-- with is reading the frame rather than the table it was read from.
	rawset(t, "SetBackdrop", function(self, backdrop)
		rawset(self, "backdropInfo", backdrop)
		return self
	end)
	rawset(t, "GetBackdrop", function(self) return rawget(self, "backdropInfo") end)

	-- Frame levels, because "the casing is above everything the window draws"
	-- is a claim about levels and nothing else. A flat 3 for every frame made
	-- that claim untestable: every answer was the same number.
	--
	-- A child starts one level above its parent, as in the game; CreateFrame
	-- sets that from the parent it is given.
	rawset(t, "SetFrameLevel", function(self, level)
		rawset(self, "levelValue", level)
		return self
	end)
	rawset(t, "GetFrameLevel", function(self) return rawget(self, "levelValue") or 3 end)

	-- Whether a frame is listening for keys, and whether it hands the key it is
	-- handling back to the game. Both were no-op setters, which made "the
	-- options window does not eat the movement keys" a claim nothing could
	-- check - and that claim is the whole design of its keyboard handling.
	rawset(t, "EnableKeyboard", function(self, enabled)
		rawset(self, "keyboardValue", enabled and true or false)
		return self
	end)
	rawset(t, "IsKeyboardEnabled", function(self)
		return rawget(self, "keyboardValue") and true or false
	end)
	rawset(t, "SetPropagateKeyboardInput", function(self, propagate)
		rawset(self, "propagateValue", propagate and true or false)
		return self
	end)

	-- How far a frame's clamp reaches past its own rect. The options window's
	-- casing hangs outside it, and "the clamp was told about it" is a claim
	-- about these four numbers.
	rawset(t, "SetClampRectInsets", function(self, l, r, tp, b)
		rawset(self, "clampInsets", { l, r, tp, b })
		return self
	end)
	rawset(t, "GetClampRectInsets", function(self)
		local c = rawget(self, "clampInsets")
		if not c then return nil end
		return c[1], c[2], c[3], c[4]
	end)

	-- Which events a frame asked for. Nothing here fires them; the harness calls
	-- the handler itself, and this is how it can tell that the frame would have
	-- been called at all.
	rawset(t, "RegisterEvent", function(self, event)
		local events = rawget(self, "registeredEvents")
		if not events then
			events = {}
			rawset(self, "registeredEvents", events)
		end
		events[event] = true
		return self
	end)
	rawset(t, "IsEventRegistered", function(self, event)
		local events = rawget(self, "registeredEvents")
		return (events and events[event]) and true or false
	end)

	rawset(t, "SetScale", function(self, s) rawset(self, "scaleValue", s) return self end)
	rawset(t, "GetScale", function(self) return rawget(self, "scaleValue") or 1 end)

	return t
end

makeStub = function(fields)
	local t = fields or {}
	t.scripts = {}
	return visibility(setmetatable(t, stubMT))
end

-- A FontString that remembers what it was told to say. Without this every
-- GetText answers "" and any check about what the interface says is measuring
-- the stub rather than the code.
-- Roughly the shape of the fonts this addon draws with, for wrapping sums.
local CHAR_W, LINE_H = 6.2, 13

function makeFontString()
	local fs = makeStub()
	fs.SetText = function(self, text) rawset(self, "textValue", text) return self end
	fs.SetFormattedText = function(self, fmt, ...)
		local ok, out = pcall(string.format, fmt, ...)
		rawset(self, "textValue", ok and out or fmt)
		return self
	end
	fs.GetText = function(self) return rawget(self, "textValue") or "" end
	fs.SetFontObject = function(self, f) rawset(self, "boundFont", f) return self end
	fs.SetWordWrap = function(self, on) rawset(self, "wraps", on and true or false) return self end
	fs.SetMaxLines = function(self, n) rawset(self, "maxLines", n) return self end

	-- Text that wraps is taller than text that does not, and how much taller
	-- depends on the width it was given. A flat 12 for everything meant a
	-- paragraph of two hundred characters and a paragraph of ten measured the
	-- same, so nothing could see the changelog drawing its releases on top of
	-- one another.
	fs.GetStringHeight = function(self)
		local text = rawget(self, "textValue") or ""
		if text == "" then return 0 end

		local width = rawget(self, "widthValue")
		if not width or width <= 0 or rawget(self, "wraps") == false then
			return LINE_H
		end

		local perLine = math.max(1, math.floor(width / CHAR_W))
		local lines = math.max(1, math.ceil(#text / perLine))

		local cap = rawget(self, "maxLines")
		if cap and cap > 0 then lines = math.min(cap, lines) end

		return lines * LINE_H
	end
	return fs
end

local created = {}
function CreateFrame(frameType, name, parent, template)
	local f = makeStub({ frameType = frameType, name = name })

	-- One above its parent, as the game does it.
	if parent and parent.GetFrameLevel then
		rawset(f, "levelValue", (parent:GetFrameLevel() or 0) + 1)
	end
	f.SetScript = function(self, script, handler) self.scripts[script] = handler return self end
	f.GetScript = function(self, script) return self.scripts[script] end
	f.HookScript = f.SetScript

	-- An EditBox remembers what it was told, and whether it has the caret.
	--
	-- Until the panel could be driven from the keyboard nothing asked a box
	-- what it held - the search ran from a string passed straight to
	-- ShowResults - so SetText was a no-op and GetText answered "". A key that
	-- types into the search box could then be checked only against the stub.
	if frameType == "EditBox" then
		f.SetText = function(self, text)
			rawset(self, "textValue", text or "")
			local handler = self.scripts["OnTextChanged"]
			if handler then handler(self, false) end
			return self
		end
		f.GetText = function(self) return rawget(self, "textValue") or "" end
		f.Insert = function(self, text)
			return self:SetText((rawget(self, "textValue") or "") .. (text or ""))
		end

		f.SetFocus = function(self) rawset(self, "focusValue", true) return self end
		f.ClearFocus = function(self) rawset(self, "focusValue", false) return self end
		f.HasFocus = function(self) return rawget(self, "focusValue") and true or false end
	end

	-- A ScrollFrame remembers where it is, and tells its handler when it moves.
	--
	-- It also computes its own range from its scroll child, and clamps to it,
	-- because that is the whole of the thing the game does that a panel gets
	-- wrong: you cannot scroll past the end, so content near the bottom can
	-- never reach the top of the view. A stub that answered a flat 4000 to
	-- GetVerticalScrollRange let every jump-to-section check pass on a page
	-- where the jump does nothing.
	if frameType == "ScrollFrame" then
		f.scrollValue = 0

		f.SetScrollChild = function(self, child) rawset(self, "scrollChild", child) return self end
		f.GetScrollChild = function(self) return rawget(self, "scrollChild") end

		f.GetVerticalScrollRange = function(self)
			local forced = rawget(self, "scrollRange")
			if forced then return forced end

			local child = rawget(self, "scrollChild")
			if not child then return 0 end

			local inner = child.GetHeight and child:GetHeight() or 0
			local outer = self:GetHeight() or 0
			return math.max(0, inner - outer)
		end

		f.SetVerticalScroll = function(self, value)
			local range = self:GetVerticalScrollRange()
			local was = self.scrollValue
			self.scrollValue = math.max(0, math.min(range, value or 0))

			-- A scroll that does not move fires nothing, as in the game. Code
			-- that only updates from this handler will not update at all when it
			-- asks to scroll somewhere it already is.
			if self.scrollValue ~= was then
				local handler = self.scripts["OnVerticalScroll"]
				if handler then handler(self, self.scrollValue) end
			end
			return self
		end
		f.GetVerticalScroll = function(self) return self.scrollValue or 0 end
	end

	created[#created + 1] = f
	if name then _G[name] = f end
	return f
end

UIParent = makeStub()
UISpecialFrames = {}
GameTooltip = makeStub()
function PlaySound() end
function InCombatLockdown() return false end

-- A cursor at a fixed point, which with the stub's GetLeft/GetWidth puts it at
-- the right-hand end of a slider's track. Without this, every drag in this
-- harness computed a value from a nil cursor and quietly did nothing, so the
-- whole drag path - including which settings write while they are dragged -
-- could not be tested at all.
function GetCursorPosition() return 300, 200 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_AddOns = { GetAddOnMetadata = function() return "5.4.13-JuNNeZ" end }
SEARCH = "Search"
CONFIRM_RESET_SETTINGS = "Reset?"
ACCEPT, CANCEL = "Accept", "Cancel"
function CreateColorFromHexString() return { WrapTextInColorCode = function(_, s) return s end } end
WHITE_FONT_COLOR = CreateColorFromHexString()
function ReloadUI() end
StaticPopupDialogs = {}

-- Blizzard's popup hands back the dialog frame it showed, or nil when every
-- slot is taken. A stub that always answered nil would make "there was no room
-- to ask" the normal case, which is the opposite of the game, and code that
-- refuses to act when it cannot ask would then look like code that never acts.
local popups = {}
function StaticPopup_Show(which, text)
	local dialog = makeStub({ which = which, text = text })
	popups[#popups + 1] = dialog
	return dialog
end
function geterrorhandler() return function(msg) error(msg, 0) end end

-- Globals the real option pages reach for.
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitName() return "Tester" end
function UnitLevel() return 80 end
function UnitFactionGroup() return "Alliance", "Alliance" end
function GetRealmName() return "Realm" end
function GetLocale() return "enUS" end
function GetBuildInfo() return "12.1.5", "12345", "date", 120100 end
function GetSpellInfo() return "Spell" end
function GetTime() return 0 end
function IsAddOnLoaded() return false end
function date() return "today" end
function InterfaceOptionsFrame_OpenToCategory() end
function collectgarbage_stub() end
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, k) return k end })
C_AddOns.IsAddOnLoaded = function() return false end
C_AddOns.IsAddOnEnabled = function() return false end
C_AddOns.GetAddOnInfo = function() return "Addon", "Addon", "", true, "" end
C_AddOns.GetNumAddOns = function() return 0 end
C_UIWidgetManager = setmetatable({}, { __index = function() return function() end end })
C_Timer = { After = function() end, NewTicker = function() return makeStub() end }
C_CVar = { GetCVar = function() return "0" end, SetCVar = function() end }
function GetCVar() return "0" end
function GetCVarBool() return false end
function SetCVar() end
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 1 end }) end })
Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = function() end }
NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }
MAINMENU_BUTTON = "Game Menu"
TIMEMANAGER_AM, TIMEMANAGER_PM = "AM", "PM"
TIMEMANAGER_TOOLTIP_LOCALTIME = "Local Time"
TIMEMANAGER_TOOLTIP_REALMTIME = "Realm Time"
DEFAULT, NONE, OTHER, GENERAL = "Default", "None", "Other", "General"
CLOSE, OKAY, APPLY, ENABLE, DISABLE = "Close", "Okay", "Apply", "Enable", "Disable"
COMBAT, UNKNOWN, LEVEL, FACTION = "Combat", "Unknown", "Level", "Faction"
STATUS_TEXT_PERCENT, STATUS_TEXT_VALUE = "Percent", "Value"
HIDE, SHOW, RESET, DELETE, CREATE = "Hide", "Show", "Reset", "Delete", "Create"



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
local fontObject = makeStub()
local modules = {}

local ns = {
	Prefix = "Azerite",
	BackdropTemplate = "BackdropTemplate",
	IsRetail = true,
	IsMainline = true,
	IsRetailContent = true,
	IsForever = false,
	API = {
		IsAddOnEnabled = function() return false end,
		IsAddOnAvailable = function() return false end,
		GetFont = function() return fontObject end,
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
		-- Only the Ace mixins are stubbed. Everything else must come from the
		-- module's own file, or a missing field would be masked by a function.
		modules[name] = {
			RegisterChatCommand = function() end,
			UnregisterChatCommand = function() end,
			RegisterEvent = function() end,
			UnregisterEvent = function() end,
			RegisterMessage = function() end,
			SendMessage = function() end,
			ScheduleTimer = function() end,
			CancelTimer = function() end,
			Hook = function() end,
			SecureHook = function() end,
			Print = function() end,
			IsEnabled = function() return true end,
			GetName = function() return name end
		}
		return modules[name]
	end,
	GetModule = function(self, name) return modules[name] end,
	Print = function(_, ...) print("  ns:Print", ...) end,
	RegisterCallback = function() end,
	GetConfig = function() return setmetatable({}, { __index = function(t, k)
		local v = setmetatable({}, getmetatable(t))
		rawset(t, k, v)
		return v
	end }) end,
	Merge = function(_, a) return a end,
	Copy = function(_, a) return a end,
	PurgeKeys = function(_, a) return a end,
	PurgeOtherKeys = function(_, a) return a end,
	AddCallback = function() end,
	Fire = function() end,
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


-- Last resort, harness only: the real option pages reach for a long tail of
-- Blizzard namespaces and locale constants. Rather than enumerate them, unknown
-- C_* globals become permissive namespaces and unknown ALL_CAPS globals become
-- their own name as a string. Anything else still reads nil, so genuine nil
-- errors in the addon's own code are not masked.
local nsAutoMT
nsAutoMT = {
	__index = function(t, k)
		local fn = function() return setmetatable({}, nsAutoMT) end
		rawset(t, k, fn)
		return fn
	end
}

setmetatable(_G, {
	__index = function(t, k)
		if type(k) ~= "string" then return nil end
		if k:sub(1, 2) == "C_" then
			local v = setmetatable({}, nsAutoMT)
			rawset(t, k, v)
			return v
		end
		if k:match("^[A-Z][A-Z0-9_]+$") then
			-- A SCREAMING_CASE name that counts something is a number in the
			-- game, and option tables use those as slider bounds. Handing back
			-- the name instead put a string where a number belongs, which is a
			-- fault in this harness rather than in the addon.
			if k:find("NUM") or k:find("MAX") or k:find("COUNT") or k:find("SIZE") then
				rawset(t, k, 10)
				return 10
			end
			-- Everything else reads as a locale constant.
			rawset(t, k, k)
			return k
		end
		if k:match("^[A-Z]") and k:match("%l") then
			-- PascalCase reads as a Blizzard API function.
			local fn = function() return nil end
			rawset(t, k, fn)
			return fn
		end
		return nil
	end
})

M.ns, M.Addon, M.load = ns, Addon, load
M.popups = popups
M.registeredWidgets = registeredWidgets
M.AceGUI, M.AceConfigDialog, M.AceConfigRegistry = AceGUI, AceConfigDialog, AceConfigRegistry
M.optionsTables, M.modules = optionsTables, modules
return M

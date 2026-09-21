-- Offline checks for the Forever day and night indicator.
--
-- Runs the real Diel block out of Components/Misc/Minimap.lua - the source slice
-- between its two section comments - against a stubbed client, so a change to the
-- shipped file is what gets tested rather than a copy of it that drifts.
--
--   lua Tools/Harness/diel_harness.lua .
--
-- It cannot see textures, frame strata, Blizzard's Edit Mode or a real cycle
-- transition. Live /reload on Forever stays required.

local root = arg[1] or "."

local failures, checks = 0, 0

local function check(name, ok, detail)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print(string.format("FAIL  %s%s", name, detail and ("  -> " .. tostring(detail)) or ""))
	else
		print("ok    " .. name)
	end
end

--------------------------------------------------------------------------
-- Frame stubs, recording only what these checks assert on.
--------------------------------------------------------------------------
local function makeRegion()
	local r = { alpha = 1, shown = true, texture = nil, points = {} }
	function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function r:ClearAllPoints() self.points = {} end
	function r:SetSize(w, h) self.width, self.height = w, h end
	function r:SetTexture(path) self.texture = path; self.setTextureCalls = (self.setTextureCalls or 0) + 1 end
	function r:SetVertexColor() end
	function r:SetAlpha(a) self.alpha = a end
	function r:GetAlpha() return self.alpha end
	function r:SetText(t) self.text = t end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:IsShown() return self.shown end
	function r:SetShown(v) self.shown = v and true or false end
	return r
end

local function makeFrame()
	local f = makeRegion()
	f.scripts = {}
	f.shown = true
	function f:SetFrameLevel(v) self.frameLevel = v end
	function f:GetFrameLevel() return self.frameLevel or 10 end
	function f:EnableMouse() end
	function f:RegisterForDrag() end
	function f:RegisterForClicks() end
	function f:SetHitRectInsets() end
	function f:SetBackdrop() end
	function f:SetBackdropColor() end
	function f:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
	function f:SetValueStep() end
	function f:SetObeyStepOnDrag() end
	function f:SetValue(v)
		self.value = v
		local handler = self.scripts.OnValueChanged
		if (handler) then handler(self, v) end
	end
	function f:GetValue() return self.value end
	function f:SetScript(name, fn) self.scripts[name] = fn end
	function f:GetScript(name) return self.scripts[name] end
	function f:CreateTexture() return makeRegion() end
	function f:CreateFontString() return makeRegion() end
	function f:Hide()
		self.shown = false
		local handler = self.scripts.OnHide
		if (handler) then handler(self) end
	end
	return f
end

--------------------------------------------------------------------------
-- The environment the extracted block runs in. Every upvalue the real file
-- gives the Diel code is a free variable in the slice, so it resolves here.
--------------------------------------------------------------------------
local MinimapMod = {}

local Minimap = makeFrame()
Minimap.width, Minimap.height = 198, 198
function Minimap:GetSize() return self.width, self.height end
function Minimap:GetCenter() return 800, 400 end
function Minimap:GetEffectiveScale() return 1 end

local nativeDiel = makeFrame()
local MinimapCluster = { DielFrame = nativeDiel }

local cursorX, cursorY = 800, 900
local client = { isForever = true, isDayTime = true }

local env = {
	MinimapMod = MinimapMod,
	Minimap = Minimap,
	MinimapCluster = MinimapCluster,

	-- Lua API the real file localizes at its top.
	math_cos = math.cos,
	math_sin = math.sin,
	math_atan2 = math.atan2,
	math_max = math.max,
	math_min = math.min,
	half_pi = math.pi/2,
	tonumber = tonumber,
	type = type,
	string_format = string.format,
	unpack = unpack,

	-- Addon API.
	ns = setmetatable({}, { __index = function(_, k)
		if (k == "IsForever") then return client.isForever end
	end }),
	API = {
		IsSafeBool = function(value) return type(value) == "boolean" end
	},
	Colors = { ui = { 0.75, 0.75, 0.75 }, green = { 0.1, 0.7, 0.1 } },
	GetMedia = function(name) return "Assets\\" .. name .. ".tga" end,
	L = setmetatable({}, { __index = function(_, k) return k end }),

	-- Client API.
	CreateFrame = function() return makeFrame() end,
	GetCursorPosition = function() return cursorX, cursorY end,
	C_DateAndTime = { IsDayTime = function() return client.isDayTime end },
	GameTooltip = {
		lines = {},
		IsForbidden = function() return false end,
		AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end
	},
	GameTooltip_SetDefaultAnchor = function(tooltip) tooltip.lines = {} end
}
env._G = env
setmetatable(env, { __index = _G })

--------------------------------------------------------------------------
-- Extract and run the real Diel block.
--------------------------------------------------------------------------
local path = root .. "/Components/Misc/Minimap.lua"
local handle = assert(io.open(path, "r"), "cannot open " .. path)
local source = handle:read("*a")
handle:close()

local first = source:find("-- The day and night indicator", 1, true)
local last = source:find("-- Our own dismount and vehicle exit button.", 1, true)
assert(first and last and last > first, "Diel section markers not found in " .. path)

local slice = source:sub(first, last - 1)
local chunk = assert(loadstring(slice, "@Diel block"))
setfenv(chunk, env)
chunk()

check("block defines the four entry points",
	type(MinimapMod.IsDielEnabled) == "function"
	and type(MinimapMod.PositionDiel) == "function"
	and type(MinimapMod.UpdateDiel) == "function"
	and type(MinimapMod.CreateDiel) == "function")

--------------------------------------------------------------------------
-- IsDielEnabled: the gate in front of everything else.
--------------------------------------------------------------------------
MinimapMod.db = { profile = {} }

check("Forever with no saved choice is on", MinimapMod:IsDielEnabled() == true)

MinimapMod.db.profile.dielEnabled = false
check("saved false turns it off", MinimapMod:IsDielEnabled() == false)

MinimapMod.db.profile.dielEnabled = true
check("saved true turns it on", MinimapMod:IsDielEnabled() == true)

client.isForever = false
check("Retail never gets one", MinimapMod:IsDielEnabled() == false)
client.isForever = true

--------------------------------------------------------------------------
-- CreateDiel: the gates, and what it builds.
--------------------------------------------------------------------------
client.isForever = false
MinimapMod:CreateDiel()
check("CreateDiel does nothing on Retail", MinimapMod.dielFrame == nil)
client.isForever = true

MinimapCluster.DielFrame = nil
MinimapMod:CreateDiel()
check("CreateDiel needs a native frame to mirror", MinimapMod.dielFrame == nil)
MinimapCluster.DielFrame = nativeDiel

MinimapMod:CreateDiel()
local frame = MinimapMod.dielFrame
check("CreateDiel builds the button", frame ~= nil)
check("it has both artwork layers", frame.Scene ~= nil and frame.Border ~= nil)
check("it has a tooltip", frame.scripts.OnEnter ~= nil and frame.scripts.OnLeave ~= nil)
check("it has drag scripts", frame.scripts.OnDragStart ~= nil and frame.scripts.OnDragStop ~= nil)
check("it does NOT poll OnUpdate at rest", frame.scripts.OnUpdate == nil)

local built = frame
MinimapMod:CreateDiel()
check("CreateDiel is idempotent", MinimapMod.dielFrame == built)

--------------------------------------------------------------------------
-- UpdateDiel: state selection, and standing down.
--------------------------------------------------------------------------
client.isDayTime = true
MinimapMod:UpdateDiel()
check("startup query picks day", frame.Scene.texture:find("day%-sky") ~= nil)
check("day is shown", frame.shown == true)
check("the native frame is faded out", nativeDiel:GetAlpha() == 0)

MinimapMod:UpdateDiel(false)
check("an explicit false event picks night", frame.Scene.texture:find("night%-sky") ~= nil)

MinimapMod:UpdateDiel(true)
check("an explicit true event picks day back", frame.Scene.texture:find("day%-sky") ~= nil)

MinimapMod.db.profile.dielTheme = "Celestial"
MinimapMod:UpdateDiel(true)
check("changing theme refreshes an unchanged day state", frame.Scene.texture:find("day%-celestial") ~= nil)

MinimapMod:UpdateDiel(false)
check("the celestial theme pairs the supplied moon with night", frame.Scene.texture:find("night%-celestial") ~= nil)

MinimapMod.db.profile.dielTheme = "not-a-theme"
MinimapMod:UpdateDiel(true)
check("an invalid theme safely falls back to the sky pair", frame.Scene.texture:find("day%-sky") ~= nil)

local before = frame.Scene.setTextureCalls
MinimapMod:UpdateDiel(true)
MinimapMod:UpdateDiel(true)
check("the reconcile does not re-set an unchanged texture", frame.Scene.setTextureCalls == before)

client.isDayTime = nil -- the client refuses to answer
MinimapMod:UpdateDiel(nil)
check("an unknown state hides ours", frame.shown == false)
check("an unknown state gives the native frame back", nativeDiel:GetAlpha() == 1)

client.isDayTime = true
MinimapMod:UpdateDiel()
check("it recovers once the client answers again", frame.shown == true and nativeDiel:GetAlpha() == 0)

MinimapMod.db.profile.dielEnabled = false
MinimapMod:UpdateDiel()
check("turning the option off hides ours", frame.shown == false)
check("turning the option off gives the native frame back", nativeDiel:GetAlpha() == 1)

MinimapMod.db.profile.dielEnabled = true
MinimapMod:UpdateDiel()
check("turning it back on restores ours", frame.shown == true and nativeDiel:GetAlpha() == 0)

--------------------------------------------------------------------------
-- The tooltip names the state it is actually showing.
--------------------------------------------------------------------------
MinimapMod:UpdateDiel(true)
frame.scripts.OnEnter(frame)
check("the tooltip says Daytime in the day", env.GameTooltip.lines[1] == "Daytime")
check("the tooltip offers both controls", #env.GameTooltip.lines == 3)

MinimapMod:UpdateDiel(false)
check("a cycle change under the cursor refreshes the tooltip", env.GameTooltip.lines[1] == "Nighttime")

frame.scripts.OnLeave(frame)
check("leaving clears the refresh flag", frame.tooltipShown == nil)

MinimapMod:UpdateDiel(true)
check("no stale refresh once the cursor has left", env.GameTooltip.lines[1] == "Nighttime")

--------------------------------------------------------------------------
-- Placement: angle from the drag, distance from the slider, clamped.
--------------------------------------------------------------------------
local function centerOffset()
	local point = frame.points[#frame.points]
	return point[4], point[5]
end

MinimapMod.db.profile.dielAngle = 0
MinimapMod.db.profile.dielDistanceOffset = 0
MinimapMod:PositionDiel()
local x, y = centerOffset()
check("zero distance sits 6px outside the 99px radius", math.abs(x - 105) < 0.001 and math.abs(y) < 0.001,
	string.format("%.3f, %.3f", x, y))

MinimapMod.db.profile.dielAngle = math.pi/2
MinimapMod:PositionDiel()
x, y = centerOffset()
check("a quarter turn puts it above the map", math.abs(x) < 0.001 and math.abs(y - 105) < 0.001,
	string.format("%.3f, %.3f", x, y))

MinimapMod.db.profile.dielAngle = 0
MinimapMod.db.profile.dielDistanceOffset = 400
MinimapMod:PositionDiel()
x = (centerOffset())
check("an over-range distance clamps to +60", math.abs(x - 165) < 0.001, x)

MinimapMod.db.profile.dielDistanceOffset = -400
MinimapMod:PositionDiel()
x = (centerOffset())
check("an under-range distance clamps to -60", math.abs(x - 45) < 0.001, x)

MinimapMod.db.profile.dielDistanceOffset = "not a number"
MinimapMod:PositionDiel()
x = (centerOffset())
check("a junk distance falls back to zero", math.abs(x - 105) < 0.001, x)

MinimapMod.db.profile.dielDistanceOffset = nil
MinimapMod:PositionDiel()
x = (centerOffset())
check("a missing distance falls back to zero", math.abs(x - 105) < 0.001, x)

Minimap.width, Minimap.height = 0, 0
local pointsBefore = #frame.points
MinimapMod:PositionDiel()
check("a map with no size is left alone", #frame.points == pointsBefore)
Minimap.width, Minimap.height = 198, 198

--------------------------------------------------------------------------
-- Dragging: only while the button is being dragged, angle only.
--------------------------------------------------------------------------
MinimapMod.db.profile.dielDistanceOffset = 0
frame.scripts.OnDragStart(frame)
check("a drag attaches OnUpdate", frame.scripts.OnUpdate ~= nil)

cursorX, cursorY = 800, 900 -- straight up from the map center
frame.scripts.OnUpdate(frame)
check("the drag writes the angle", math.abs(MinimapMod.db.profile.dielAngle - math.pi/2) < 0.001,
	MinimapMod.db.profile.dielAngle)
check("the drag leaves the distance alone", MinimapMod.db.profile.dielDistanceOffset == 0)

frame.scripts.OnDragStop(frame)
check("ending the drag detaches OnUpdate", frame.scripts.OnUpdate == nil)

frame.scripts.OnDragStart(frame)
frame:Hide()
check("hiding mid-drag detaches OnUpdate", frame.scripts.OnUpdate == nil)
check("hiding closes the distance panel", MinimapMod.dielPicker:IsShown() == false)

--------------------------------------------------------------------------
-- The right-click distance panel.
--------------------------------------------------------------------------
frame:Show()
MinimapMod.db.profile.dielDistanceOffset = 12
frame.scripts.OnClick(frame)
check("right-click opens the panel", MinimapMod.dielPicker:IsShown() == true)
check("the panel exposes the theme choice", MinimapMod.dielThemeButton ~= nil)

MinimapMod.db.profile.dielTheme = "Sky"
MinimapMod.dielThemeButton.scripts.OnClick(MinimapMod.dielThemeButton)
check("the theme button selects the sun and moon pair",
	MinimapMod.db.profile.dielTheme == "Celestial" and frame.Scene.texture:find("day%-celestial") ~= nil)

MinimapMod.dielThemeButton.scripts.OnClick(MinimapMod.dielThemeButton)
check("the theme button cycles back to the sky pair",
	MinimapMod.db.profile.dielTheme == "Sky" and frame.Scene.texture:find("day%-sky") ~= nil)

check("right-click again closes it", (function()
	frame.scripts.OnClick(frame)
	return MinimapMod.dielPicker:IsShown() == false
end)())

MinimapMod.db.profile.dielDistanceOffset = 999
frame.scripts.OnClick(frame)
check("opening the panel clamps a corrupt saved distance",
	MinimapMod.db.profile.dielDistanceOffset == 60, MinimapMod.db.profile.dielDistanceOffset)

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)

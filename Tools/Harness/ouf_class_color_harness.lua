-- oUF class colours with a secret class (FixLog 2026-11-07).
-- UnitClass is SecretWhenUnitIdentityRestricted, so in PvP the bundled oUF health and power elements and
-- the raidcolor tag get a secret class. Upstream oUF (c5ff6e4, issue #873) asks C_ClassColor then, as
-- Plater and Platynator do; the colour has secret components and goes to the widget untested.
-- Run: lua Tools/Harness/ouf_class_color_harness.lua .
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

-- A secret number: arithmetic and comparison raise, as in the client; type() says "number".
local SecretNumber = {}
local function RaiseSecret() error("attempt to use a secret number in addon code", 2) end
for _, event in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat" }) do
	SecretNumber[event] = RaiseSecret
end
local function Secret(value) return setmetatable({ value = value }, SecretNumber) end
local function IsSecretNumber(v) return getmetatable(v) == SecretNumber end
local function Reveal(v) if (IsSecretNumber(v)) then return v.value end return v end
-- A secret class string: indexing a table with it is what the old code did; it raises here.
local SecretString = setmetatable({}, { __tostring = function() return "<secret class>" end,
	__concat = RaiseSecret, __lt = RaiseSecret, __le = RaiseSecret })
local rawtype = type
function type(v) if (IsSecretNumber(v)) then return "number" end if (v == SecretString) then return "string" end return rawtype(v) end
function issecretvalue(v) return v == SecretString or IsSecretNumber(v) end

local function Color(r, g, b)
	return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end,
		GenerateHexColorMarkup = function(self)
			if (IsSecretNumber(self.r)) then return "|c<secret>" end
			return string.format("|cff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255)
		end,
		GetAtlas = function() end, GetCurve = function() end }
end
local OWN_MAGE = Color(.1, .2, .3) -- AzeriteUI's own class colour, to tell apart from Blizzard's
local guardedColors = setmetatable({ MAGE = OWN_MAGE }, { __index = function(_, key)
	if (key == SecretString) then error("indexed the class colours with a secret class", 2) end
end })

local classColorAsked
C_ClassColor = { GetClassColor = function(class)
	classColorAsked = class
	if (class == SecretString) then return Color(Secret(.25), Secret(.78), Secret(.92)) end
	return Color(.25, .78, .92)
end }
Enum = { StatusBarInterpolation = { Immediate = 0 }, PowerType = { Alternate = 10, Mana = 0 } }

local unitClass = "MAGE"
local function UnitRec() return { isPlayer = true, canAttack = true } end
function UnitIsConnected() return true end
function UnitPlayerControlled() return true end
function UnitIsPlayer() return true end
function UnitInPartyIsAI() return false end
function UnitIsTapDenied() return false end
function UnitThreatSituation() return nil end
function UnitReaction() return 2 end
function UnitClass() return "Mage", unitClass, 8 end
function UnitPowerType() return 0, "MANA" end

-- oUF stub: AddElement keeps each element's Enable; Enable registers ColorPath, which we call.
local elements = {}
local ns = { oUF = { Private = { unitSelectionType = function() return nil end },
	AddElement = function(_, name, path, enable) elements[name] = { path = path, enable = enable } end } }
local function load(relative)
	local chunk = assert(loadfile(root .. "/" .. relative))
	chunk("AzeriteUI", ns)
end
load("Libs/oUF/elements/health.lua")
load("Libs/oUF/elements/power.lua")

local function NewBar()
	local texture = { SetVertexColor = function(self, r, g, b) self.color = { r, g, b } end }
	return { texture = texture, GetStatusBarTexture = function() return texture end,
		IsObjectType = function() return true end, Show = function() end,
		SetStatusBarTexture = function() end }
end
local function NewFrame(elementName, element)
	local frame = { unit = "target", handlers = {},
		colors = { class = guardedColors, health = Color(.2, .8, .2), disconnected = Color(.5, .5, .5),
			tapped = Color(.6, .6, .6), reaction = { [2] = Color(1, 0, 0) }, power = { MANA = Color(0, 0, 1) },
			threat = {} } }
	function frame:RegisterEvent(event, func) self.handlers[event] = func end
	frame[elementName] = element
	return frame
end
local function Recolor(frame, event)
	local handler = frame.handlers[event]
	assert(handler, "no colour handler registered for " .. event)
	return pcall(handler, frame, event, frame.unit)
end

-- Health
local health = NewBar()
health.colorClass, health.colorReaction, health.colorDisconnected = true, true, true
local postColor
health.PostUpdateColor = function(_, _, color) postColor = color end
local hframe = NewFrame("Health", health)
elements.Health.enable(hframe)

unitClass = "MAGE"
local ok, err = Recolor(hframe, "UNIT_CONNECTION")
check(ok, "health: a readable class colours without raising", err)
check(health.texture.color and health.texture.color[1] == .1, "health: a readable class keeps AzeriteUI's own colour",
	health.texture.color and health.texture.color[1])

unitClass, classColorAsked, health.texture.color = SecretString, nil, nil
ok, err = Recolor(hframe, "UNIT_CONNECTION")
check(ok, "health: a secret class colours without raising", err)
check(classColorAsked == SecretString, "health: a secret class is handed to C_ClassColor")
local c = health.texture.color
check(c and IsSecretNumber(c[1]) and Reveal(c[1]) == .25 and Reveal(c[3]) == .92,
	"health: the secret colour reaches the texture untouched", c and Reveal(c[1]))
check(postColor and IsSecretNumber(postColor.r), "health: PostUpdateColor gets the secret colour object")

C_ClassColor, health.texture.color = nil, nil
ok, err = Recolor(hframe, "UNIT_CONNECTION")
check(ok and health.texture.color and health.texture.color[1] == .2,
	"health: without C_ClassColor (older client) a secret class falls back to the health colour",
	err or (health.texture.color and health.texture.color[1]))
C_ClassColor = { GetClassColor = function(class)
	classColorAsked = class
	return Color(Secret(.25), Secret(.78), Secret(.92))
end }

-- Power (no frame of ours colours power by class; kept in step with upstream)
local power = NewBar()
power.colorClass, power.colorDisconnected = true, true
local postAlt
power.PostUpdateColor = function(_, _, _, r) postAlt = r end
local pframe = NewFrame("Power", power)
elements.Power.enable(pframe)
unitClass, classColorAsked = SecretString, nil
ok, err = Recolor(pframe, "UNIT_CONNECTION")
check(ok, "power: a secret class colours without raising", err)
check(power.texture.color and IsSecretNumber(power.texture.color[1]) and Reveal(power.texture.color[2]) == .78,
	"power: the secret colour reaches the texture untouched")
check(postAlt == nil, "power: the secret colour is not passed on as an alternative colour", postAlt)
unitClass = "MAGE"
ok, err = Recolor(pframe, "UNIT_CONNECTION")
check(ok and power.texture.color[1] == .1, "power: a readable class keeps AzeriteUI's own colour", err)

-- The raidcolor tag, compiled from tags.lua's own source with the tag environment's globals.
local source = assert(io.open(root .. "/Libs/oUF/elements/tags.lua")):read("*a")
local body = source:match("%['raidcolor'%] = %[%[(.-)%]%],")
check(body ~= nil, "tags: found the raidcolor tag")
if (body) then
	local env = setmetatable({ _COLORS = { class = guardedColors } }, { __index = _G })
	local fn = assert(loadstring("return " .. body))
	setfenv(fn, env)
	local tag = fn()
	unitClass = "MAGE"
	ok, err = pcall(tag, "target")
	check(ok and err == OWN_MAGE:GenerateHexColorMarkup(), "tags: raidcolor keeps AzeriteUI's colour for a readable class", err)
	unitClass = SecretString
	ok, err = pcall(tag, "target")
	check(ok and err == "|c<secret>", "tags: raidcolor asks C_ClassColor for a secret class", err)
end

print(string.format("oUF class colours: %d checks, %d failures", checks, failures))
if (failures > 0) then os.exit(1) end

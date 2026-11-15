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

-- Run the actual Target callback after oUF. The old test above only recorded
-- PostUpdateColor's payload, so it missed the reported native preview rejection.
local targetFile = assert(io.open(root .. "/Components/UnitFrames/Units/Target.lua", "rb"))
local targetSource = targetFile:read("*a"); targetFile:close()
local first = assert(targetSource:find("local Health_PostUpdateColor = function", 1, true))
local last = assert(targetSource:find("-- Align our custom health prediction texture", first, true))
local callbackSource = targetSource:sub(first, last - 1)
if (arg[2] == "old-preview-setter") then
	local a = assert(callbackSource:find("local previewTexture = preview:GetStatusBarTexture()", 1, true))
	local b = assert(callbackSource:find("local fakeFill = element.FakeFill", a, true))
	callbackSource = callbackSource:sub(1, a - 1) .. "preview:SetStatusBarColor(r, g, b)\n\t\t" .. callbackSource:sub(b)
end
local sparkUpdates = 0
local callbackEnv = setmetatable({ UpdateTargetBarSpark = function() sparkUpdates = sparkUpdates + 1 end }, { __index = _G })
local callbackChunk = assert(loadstring(callbackSource .. "\nreturn Health_PostUpdateColor"))
setfenv(callbackChunk, callbackEnv)
local targetCallback = callbackChunk()
health.Preview = NewBar()
local preview = health.Preview
local previewSetterCalls = 0
function preview:SetStatusBarColor(r, g, b)
	previewSetterCalls = previewSetterCalls + 1
	if (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then
		error("Object did not allow secret", 2)
	end
	self.texture:SetVertexColor(r, g, b)
end
health.FakeFill = NewBar().texture
health.PostUpdateColor = targetCallback
local secretClassColor = C_ClassColor.GetClassColor
-- Every mixture catches checking only one component or doing partial darkening.
for mask = 1, 7 do
	local r = mask % 2 == 1 and Secret(.25) or .25
	local g = math.floor(mask / 2) % 2 == 1 and Secret(.78) or .78
	local b = math.floor(mask / 4) % 2 == 1 and Secret(.92) or .92
	C_ClassColor.GetClassColor = function() return Color(r, g, b) end
	unitClass = SecretString
	local before = previewSetterCalls
	ok, err = Recolor(hframe, "UNIT_CONNECTION")
	check(ok, "target: secret colour mixture " .. mask .. " does not raise", err)
	check(previewSetterCalls == before, "target: secret RGB bypasses preview status-bar setter " .. mask)
	local pc, fc = preview.texture.color, health.FakeFill.color
	check(pc and pc[1] == r and pc[2] == g and pc[3] == b,
		"target: preview texture receives untouched RGB " .. mask)
	check(fc and fc[1] == r and fc[2] == g and fc[3] == b,
		"target: shaped fill receives untouched RGB " .. mask)
end
C_ClassColor.GetClassColor = secretClassColor
unitClass = "MAGE"
ok, err = Recolor(hframe, "UNIT_CONNECTION")
check(ok and preview.texture.color[1] == .1 * .7 and preview.texture.color[2] == .2 * .7,
	"target: secret-to-readable switch restores darkened preview", err)
check(health.FakeFill.color[1] == .1, "target: readable shaped fill stays undarkened")
targetCallback(health, "target", .8, .6, .4)
check(preview.texture.color[1] == .8 * .7 and health.FakeFill.color[1] == .8,
	"target: legacy RGB callback remains supported")
preview.texture = nil
preview.GetStatusBarTexture = function() return nil end
ok, err = pcall(targetCallback, health, "target", Color(Secret(.2), Secret(.4), Secret(.6)))
check(ok and IsSecretNumber(health.FakeFill.color[1]), "target: missing preview texture still colours shaped fill", err)
check(sparkUpdates == 10, "target: colour updates still refresh the spark")
health.Preview = nil
ok, err = pcall(targetCallback, health, "target", Color(Secret(.2), Secret(.4), Secret(.6)))
check(ok and sparkUpdates == 10, "target: absent preview retains early return", err)

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

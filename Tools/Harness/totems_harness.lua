-- Totem row (FixLog 2026-10-20). Loads the real Libs/oUF/elements/totems.lua and
-- Components/UnitFrames/Units/PlayerTotems.lua. The element must never compare, add,
-- concatenate or measure GetTotemInfo's answers (secret on 12.x): visibility goes through
-- SetAlphaFromBoolean, the icon straight to SetTexture, the timer through
-- SetCooldownFromDurationObject, and an empty slot clears its cooldown. The module builds
-- four mouse-disabled icons and exists only on Retail content.
-- Offline only: whether the ghoul, statues and mushrooms really fill totem slots, and how
-- the row looks at the default position, are live checks.
-- Run: lua.exe Tools/Harness/totems_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

-- A secret raises on everything addon code may not do with it.
local secretMeta = {}
local function refuse() error("secret value used in Lua logic", 2) end
for _, m in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__concat", "__len", "__index", "__newindex", "__call" }) do
	secretMeta[m] = refuse
end
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

-- Game state per slot.
local slots = {}
local durations = {}
GetTotemInfo = function(slot)
	local s = slots[slot]
	if (not s) then return false, "", 0, 0, 0 end
	return s.have, s.name, s.start, s.duration, s.icon
end
GetTotemDuration = function(slot) return durations[slot] end
UnitClassBase = function() return "DEATHKNIGHT" end
STANDARD_TOTEM_PRIORITIES = { 1, 2, 3, 4 }
SHAMAN_TOTEM_PRIORITIES = { 2, 1, 3, 4 }
local blizzEvents = {}
TotemFrame = {
	UnregisterEvent = function(_, e) blizzEvents[e] = false end,
	RegisterEvent = function(_, e) blizzEvents[e] = true end,
}
GameTooltip = { IsForbidden = function() return false end }

local function Widget()
	local w = { calls = {} }
	function w:SetID(id) self.id = id end
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:IsMouseEnabled() return self.mouse and true or false end
	function w:SetScript(k, f) self[k] = f end
	function w:SetAlphaFromBoolean(v, a, b) self.alphaArg = v; self.alphaOn, self.alphaOff = a, b end
	w.Icon = { SetTexture = function(self, t) self.texture = t end }
	w.Cooldown = {
		SetCooldownFromDurationObject = function(self, d) self.duration = d; self.cleared = false end,
		Clear = function(self) self.duration = nil; self.cleared = true end,
		SetCooldown = function() error("SetCooldown takes numbers read from secrets") end,
	}
	return w
end

-- Load the element.
local element
local ns = { oUF = { AddElement = function(_, name, update, enable, disable)
	element = { name = name, update = update, enable = enable, disable = disable }
end } }
assert(loadfile(root .. "/Libs/oUF/elements/totems.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
check(element and element.name == "Totems", "totems element registered")

local events = {}
local owner = { Totems = { Widget(), Widget(), Widget(), Widget() } }
function owner:RegisterEvent(e, f) events[e] = f end
function owner:UnregisterEvent(e) events[e] = nil end
local post = {}
owner.Totems.PostUpdate = function(_, slot, have, name, icon, duration)
	post[slot] = { have = have, name = name, icon = icon, duration = duration }
end

check(element.enable(owner) == true, "enable answers true")
for i = 1, 4 do
	check(owner.Totems[i].shown == true, "slot " .. i .. " widget shown on enable (alpha decides)")
	check(owner.Totems[i].id == i, "slot " .. i .. " keeps its id")
end
check(events.PLAYER_TOTEM_UPDATE ~= nil, "listens for PLAYER_TOTEM_UPDATE")
check(blizzEvents.PLAYER_TOTEM_UPDATE == false, "Blizzard's TotemFrame stops updating")

-- Secret slot: nothing may be tested in Lua.
local dur = { kind = "DurationObject" }
local haveS, nameS, iconS = secret(true), secret("Raise Dead"), secret(1100170)
slots[1] = { have = haveS, name = nameS, start = secret(100), duration = secret(60), icon = iconS }
durations[1] = dur
local ok, err = pcall(element.update, owner, "ForceUpdate")
check(ok, "update survives secret totem answers", err)
local t1 = owner.Totems[1]
check(t1.alphaArg == haveS and t1.alphaOn == 1 and t1.alphaOff == 0, "alpha follows haveTotem as given")
check(t1.Icon.texture == iconS, "icon handed over untouched")
check(t1.Cooldown.duration == dur, "timer fed the duration object")
check(post[1] and post[1].have == haveS and post[1].name == nameS and post[1].icon == iconS and post[1].duration == dur,
	"PostUpdate gets slot, haveTotem, name, icon, duration")

-- An empty slot clears its timer instead of leaving the last one running.
slots[1] = nil; durations[1] = nil
ok, err = pcall(element.update, owner, "ForceUpdate")
check(ok, "update survives an empty slot", err)
check(t1.alphaArg == false, "empty slot alpha off")
check(t1.Cooldown.cleared == true and t1.Cooldown.duration == nil, "empty slot clears the timer")

-- A plain (non-secret) slot through the event path.
slots[3] = { have = true, name = "Statue", start = 5, duration = 900, icon = 627607 }
durations[3] = dur
ok, err = pcall(events.PLAYER_TOTEM_UPDATE, owner, "PLAYER_TOTEM_UPDATE", 3)
check(ok, "event path updates one slot", err)
check(owner.Totems[3].alphaArg == true and owner.Totems[3].Cooldown.duration == dur, "slot 3 shown with its timer")

element.disable(owner)
check(blizzEvents.PLAYER_TOTEM_UPDATE == true, "disable gives the events back to TotemFrame")
check(owner.Totems[1].shown == false, "disable hides the widgets")

-- The module: Retail only, four mouse-disabled icons.
local function LoadModule(retail)
	local created, spawnedStyle
	local frames = {}
	local function Frame(kind)
		local f = { kind = kind, mouse = true, regions = {} }
		function f:SetSize(w, h) self.w, self.h = w, h end
		function f:SetPoint(...) self.point = { ... } end
		function f:SetAllPoints() end
		function f:EnableMouse(v) self.mouse = v end
		function f:GetFrameLevel() return 1 end
		function f:SetFrameLevel(l) self.level = l end
		function f:CreateTexture() return { SetAllPoints = function() end, SetMask = function(s, m) s.mask = m end } end
		function f:SetDrawEdge() end
		function f:SetDrawBling() end
		function f:SetReverse(v) self.reverse = v end
		function f:SetSwipeColor() end
		function f:SetHideCountdownNumbers(v) self.hideNumbers = v end
		function f:GetNumRegions() return 0 end
		function f:GetRegions() end
		frames[#frames + 1] = f
		return f
	end
	CreateFrame = function(kind) return Frame(kind) end
	LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end
	local mns = {
		IsRetailContent = retail,
		Prefix = "AzeriteUI",
		API = { GetFont = function() return {} end, GetEffectiveScale = function() return 1 end },
		MovableModulePrototype = { defaults = { enabled = true }, OnEnable = function() end },
		UnitFrameModule = {},
		AuraStyles = { CreateTextureBorder = function() local b = Frame("border"); b.SetBackdropBorderColor = function() end; return b end },
		GetConfig = function() return {
			TotemCount = 4, TotemSize = { 32, 32 }, TotemSpacing = 8, TotemIconMask = "mask",
			TotemBorderColor = { 0, 0, 0 }, TotemTimerFontSize = 14, TotemTimerColor = { 1, 1, 1 },
		} end,
		Merge = function(_, a, b) for k, v in pairs(b) do a[k] = v end return a end,
		oUF = {
			RegisterStyle = function(_, _, s) spawnedStyle = s end,
			SetActiveStyle = function() end,
		},
	}
	mns.UnitFrame = { Spawn = function(unit)
		local f = Frame("unitframe"); f.unit = unit
		spawnedStyle(f, unit)
		return f
	end }
	function mns:NewModule(name)
		created = { name = name, CreateAnchor = function(self, label) self.anchorLabel = label end }
		return created
	end
	assert(loadfile(root .. "/Components/UnitFrames/Units/PlayerTotems.lua"))("AzeriteUI5_JuNNeZ_Edition", mns)
	return created
end

check(LoadModule(false) == nil, "no totems module on Forever")
local mod = LoadModule(true)
check(mod and mod.name == "PlayerTotemsFrame", "Retail creates PlayerTotemsFrame")
mod:OnEnable()
local frame = mod.frame
check(frame and frame.unit == "player", "the row is a player frame")
check(frame.mouse == false, "row frame does not take the mouse")
check(frame.Totems and #frame.Totems == 4, "four totem icons", frame.Totems and #frame.Totems)
local allQuiet, allReverse, allNumbers = true, true, true
for i = 1, 4 do
	local t = frame.Totems[i]
	if (t.mouse ~= false or t.Cooldown.mouse ~= false) then allQuiet = false end
	if (t.Cooldown.reverse ~= true) then allReverse = false end
	if (t.Cooldown.hideNumbers ~= false) then allNumbers = false end
end
check(allQuiet, "no icon or timer takes the mouse")
check(allReverse and allNumbers, "timers count down with Blizzard's numbers")
check(frame.w == 4 * 32 + 3 * 8 and frame.h == 32, "row sized to its icons", tostring(frame.w) .. "x" .. tostring(frame.h))
check(mod.anchorLabel == "Totems", "mover labelled Totems")
local before = frame
mod:CreateUnitFrames()
check(mod.frame == before, "built once")
local d = mod:GenerateDefaults()
check(d.profile.enabled == true and d.profile.savedPosition[1] == "BOTTOM", "enabled by default, bottom-anchored")

print(("Totems: %d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)

-- oUF_CombatFeedback: readable and secret UNIT_COMBAT amounts, crit flags, the switch.
-- Loads the real Libs/oUF_Plugins/oUF_CombatFeedback.lua against stubs and drives its
-- update path with UNIT_COMBAT payloads. Only the font string writes are inspected.
-- Run: lua.exe Tools/Harness/combat_feedback_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

-- Secret amounts are tables; arithmetic or ordering on them raises, as in the client.
local secretMeta = {
	__lt = function() error("compared a secret value") end,
	__le = function() error("compared a secret value") end,
	__add = function() error("arithmetic on a secret value") end,
	__sub = function() error("arithmetic on a secret value") end,
	__unm = function() error("arithmetic on a secret value") end,
	__concat = function() error("concatenated a secret value") end,
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end
local realType = type
type = function(v) if (issecretvalue(v)) then return "number" end return realType(v) end
tonumber = (function(real) return function(v, ...)
	if (issecretvalue(v)) then error("tonumber on a secret value") end
	return real(v, ...)
end end)(tonumber)

-- The client formatter takes secrets and hands back an opaque string.
local abbreviated = {}
AbbreviateNumbers = function(v)
	local token = { abbreviated = v }
	abbreviated[token] = true
	return token
end

GetLocale = function() return "enUS" end
GetTime = function() return 100 end
CombatFeedbackText = { MISS = "Miss", ABSORB = "Absorb", BLOCK = "Block", RESIST = "Resist", IMMUNE = "Immune" }
COMBAT_TEXT_BLOCK_REDUCED = "%s (blocked)"
COMBATFEEDBACK_FADEINTIME, COMBATFEEDBACK_HOLDTIME, COMBATFEEDBACK_FADEOUTTIME = .2, .7, .3
CreateFrame = function()
	return { Hide = function() end, Show = function() end, SetScript = function() end }
end

local element
local ns = { UnitFrame = {} }
local showSetting = true
ns.UnitFrame.ShouldShowCombatFeedback = function() return showSetting end
ns.oUF = { AddElement = function(_, name, path, enable) element = { name = name, path = path, enable = enable } end }

assert(loadfile(root .. "/Libs/oUF_Plugins/oUF_CombatFeedback.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
check(element and element.name == "CombatFeedback", "the plugin registers its element")

local function NewText()
	local text = { shown = false }
	function text:SetFontObject(font) self.font = font end
	function text:SetFormattedText(fmt, arg) self.fmt, self.arg = fmt, arg end
	function text:SetTextColor(r, g, b) self.color = { r, g, b } end
	function text:SetAlpha(a) self.alpha = a end
	function text:Show() self.shown = true end
	function text:Hide() self.shown = false end
	text.feedbackFont, text.feedbackFontLarge, text.feedbackFontSmall = "normal", "large", "small"
	return text
end

local health = { safeCur = 500, safeMax = 1000 }
local frame = { unit = "party1", colors = {}, CombatFeedback = NewText(), Health = health,
	RegisterEvent = function() end }
health.SetSafeMinMaxValues = function() end
health.SetSafeValue = function(_, v) health.lastSafe = v end
element.enable(frame)

local function Fire(event, flags, amount)
	frame.CombatFeedback.fmt, frame.CombatFeedback.arg, frame.CombatFeedback.shown = nil, nil, false
	frame.CombatFeedback.fontType = nil
	local ok, err = pcall(element.path, frame, "UNIT_COMBAT", "party1", event, flags, amount, 1)
	return ok, err
end

-- Readable amounts keep the old text and the approximate health nudge.
local ok, err = Fire("WOUND", "", 12345)
check(ok, "readable wound: no error " .. tostring(err))
check(frame.CombatFeedback.fmt == "-%s" and frame.CombatFeedback.arg == "12.3k", "readable wound: -12.3k")
check(health.lastSafe == 0, "readable wound nudges the approximate health (500 - 12345, clamped to 0)")

ok = Fire("WOUND", "CRITICAL", 900)
check(ok and frame.CombatFeedback.font == "large", "a crit is drawn large (the old code read an unset global)")

ok = Fire("HEAL", "CRITICAL", 2000)
check(ok and frame.CombatFeedback.fmt == "+%s" and frame.CombatFeedback.font == "large", "a crit heal is +, large")

ok = Fire("WOUND", "ABSORB", 0)
check(ok and frame.CombatFeedback.fmt == "Absorb", "a fully absorbed hit says Absorb")

-- Secret amounts: never compared, never formatted by addon code, handed to the client.
health.lastSafe = nil
local hit = secret(4321)
ok, err = Fire("WOUND", "", hit)
check(ok, "secret wound: no error " .. tostring(err))
check(frame.CombatFeedback.fmt == "-%s", "secret wound: damage format")
check(abbreviated[frame.CombatFeedback.arg] and frame.CombatFeedback.arg.abbreviated == hit,
	"secret wound: the amount goes through AbbreviateNumbers untouched")
check(frame.CombatFeedback.shown, "secret wound: the text shows")
check(health.lastSafe == nil, "secret wound: no approximate health arithmetic")

ok = Fire("WOUND", "ABSORB", secret(0))
check(ok and frame.CombatFeedback.fmt == "Absorb", "secret amount with ABSORB flags: Absorb, not a number")

ok = Fire("WOUND", "CRITICAL", secret(77))
check(ok and frame.CombatFeedback.font == "large" and abbreviated[frame.CombatFeedback.arg], "secret crit: large, abbreviated")

ok = Fire("WOUND", "BLOCK_REDUCED", secret(50))
check(ok and frame.CombatFeedback.fmt == COMBAT_TEXT_BLOCK_REDUCED and abbreviated[frame.CombatFeedback.arg],
	"partial block: Blizzard's format with the amount")

ok, err = Fire("HEAL", "", secret(600))
check(ok and frame.CombatFeedback.fmt == "+%s" and abbreviated[frame.CombatFeedback.arg], "secret heal: +, abbreviated " .. tostring(err))

ok, err = Fire("ENERGIZE", "", secret(20))
check(ok and frame.CombatFeedback.fmt == "%s" and abbreviated[frame.CombatFeedback.arg], "secret energize " .. tostring(err))

-- Secret flags: treated as a plain hit.
ok, err = Fire("WOUND", secret("CRITICAL"), 10)
check(ok and frame.CombatFeedback.fmt == "-%s", "secret flags: a plain hit, no comparison " .. tostring(err))

-- The switch.
showSetting = false
ok = Fire("WOUND", "", 100)
check(ok and frame.CombatFeedback.fmt == nil and not frame.CombatFeedback.shown, "switched off: nothing drawn")
showSetting = true

-- Another unit's event is ignored.
frame.CombatFeedback.fmt = nil
element.path(frame, "UNIT_COMBAT", "party2", "WOUND", "", 5, 1)
check(frame.CombatFeedback.fmt == nil, "another unit's event is ignored")

print(string.format("Combat feedback: %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

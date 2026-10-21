-- Nameplate cast target name, "aimed at you" glow and important-cast glow (FixLog 2026-10-20).
-- Loads the real Components/UnitFrames/NamePlates/Castbar.lua against stubs where secret
-- values raise on comparison, arithmetic and concatenation, and checks that the target's
-- name and class, PlayerIsSpellTarget and IsSpellImportant only reach SetText,
-- SetTextColor and SetAlphaFromBoolean. Plain Lua cannot trap a boolean test, or an
-- equality test against a string, on a secret: a mutation that writes
-- `not name or name == ""` survives here. That part stays a live check, as does how
-- the glows look.
-- Run: lua.exe Tools/Harness/castbar_target_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg, detail)
	checks = checks + 1
	if (not v) then
		failures = failures + 1
		print("FAIL: " .. msg .. (detail ~= nil and (" - " .. tostring(detail)) or ""))
	end
end

local Any
Any = setmetatable({}, { __index = function() return Any end, __call = function() return Any end })
setmetatable(_G, { __index = function(_, k) return Any end })

local function raise(what) return function() error(what .. " a secret value", 2) end end
local secretMeta = {
	__lt = raise("compared"), __le = raise("compared"), __concat = raise("concatenated"),
	__add = raise("arithmetic on"), __sub = raise("arithmetic on"), __mul = raise("arithmetic on"),
	__div = raise("arithmetic on"), __len = raise("took the length of"),
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

-- The world: what the game answers for the casting unit.
local W
local function Reset()
	W = { errors = {}, show = true, name = "Junnez", class = "PALADIN", targeted = true, important = true }
end
Reset()

UnitShouldDisplaySpellTargetName = function() return W.show end
UnitSpellTargetName = function() return W.name end
UnitSpellTargetClass = function() return W.class end
PlayerIsSpellTarget = function() return W.targeted end
C_Spell = { IsSpellImportant = function(spellID) W.importantArg = spellID; return W.important end }
C_ClassColor = { GetClassColor = function(class)
	W.colorArg = class
	return { GetRGB = function() return secret(.96), secret(.55), secret(.73) end }
end }
CreateFrame = function() return Any end

local function Region()
	local r = { alpha = 1 }
	function r:SetText(t) self.text = t end
	function r:SetTextColor(rr, g, b, a) self.color = { rr, g, b, a } end
	function r:SetAlpha(a) self.alpha = a; self.alphaFrom = nil end
	function r:SetAlphaFromBoolean(v, t, f) self.alphaFrom = { v, t, f } end
	return r
end

local profile = { castTargetName = true, castTargetedGlow = true, castImportantGlow = true }
local ns = {
	Colors = { red = { 1, 0, 0 }, gray = { .5, .5, .5 } },
	GetConfig = function() return { CastBarTargetColor = { .8, .8, .8, .85 }, CastBarNameColor = { 1, 1, 1, .5 } } end,
	API = {
		TryCall = function(f, ...)
			local r = { pcall(f, ...) }
			if (not r[1]) then W.errors[#W.errors + 1] = r[2] end
			return unpack(r)
		end,
		SafeCallPacked = function() return true, {} end,
		UpdateInterruptCastBarRefresh = function() end,
		ClearInterruptCastBarRefresh = function() end,
		GetPrimaryInterrupt = function() return nil end,
	},
}
ns.NamePlatesPrivate = {
	IsSecretValue = issecretvalue,
	NamePlate_PostUpdateHoverElements = function() end,
	NamePlatesMod = { db = { profile = profile } },
}
local NP = ns.NamePlatesPrivate

local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/Castbar.lua"))
chunk("AzeriteUI5_JuNNeZ_Edition", ns)
check(NP.NamePlate_UpdateCastTargetVisuals and NP.NamePlate_ClearCastTargetVisuals, "castbar exports the target visuals")

local function Castbar(unit, extra)
	local owner = { unit = unit or "nameplate3" }
	for k, v in pairs(extra or {}) do owner[k] = v end
	return { __owner = owner, spellID = 12345, TargetText = Region(), ImportantGlow = Region(), TargetedGlow = Region() }
end

-- 1. Plain values.
local bar = Castbar()
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.TargetText.text == "Junnez", "target name shown", bar.TargetText.text)
check(W.colorArg == "PALADIN", "class colour looked up from the target's class", W.colorArg)
check(bar.TargetText.color and issecretvalue(bar.TargetText.color[1]), "class colour handed to the text unread")
check(bar.TargetedGlow.alphaFrom and bar.TargetedGlow.alphaFrom[1] == true and bar.TargetedGlow.alphaFrom[2] == 255, "aimed-at-you glow from the boolean")
check(bar.ImportantGlow.alphaFrom and bar.ImportantGlow.alphaFrom[1] == true, "important glow from the boolean")
check(W.importantArg == 12345, "important looked up for the cast's spell")
check(#W.errors == 0, "no errors with plain values", W.errors[1])

-- 2. Every answer secret.
Reset()
local sName, sClass, sTargeted, sImportant = secret("Junnez"), secret("PALADIN"), secret(false), secret(true)
W.name, W.class, W.targeted, W.important = sName, sClass, sTargeted, sImportant
bar = Castbar()
bar.spellID = secret(12345)
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.TargetText.text == sName, "secret name passed straight to SetText")
check(W.colorArg == sClass, "secret class passed straight to GetClassColor")
check(bar.TargetedGlow.alphaFrom and bar.TargetedGlow.alphaFrom[1] == sTargeted, "secret aimed-at-you boolean passed to SetAlphaFromBoolean")
check(bar.ImportantGlow.alphaFrom and bar.ImportantGlow.alphaFrom[1] == sImportant, "secret important boolean passed to SetAlphaFromBoolean")
check(issecretvalue(W.importantArg), "secret spellID passed to IsSpellImportant")
check(#W.errors == 0, "no secret was compared, added or joined", W.errors[1])

-- 3. Nothing to show.
Reset()
W.show = false
bar = Castbar()
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.TargetText.text == "", "no name when the game says not to show one", bar.TargetText.text)
Reset()
W.name = nil
bar = Castbar()
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.TargetText.text == "", "no name when the cast has no target", bar.TargetText.text)
bar.spellID = nil
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.ImportantGlow.alphaFrom == nil and bar.ImportantGlow.alpha == 0, "no important glow without a spell")

-- 4. Switches, the personal plate, object plates and non-plate units.
Reset()
profile.castTargetName, profile.castTargetedGlow, profile.castImportantGlow = false, false, false
bar = Castbar()
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
check(bar.TargetText.text == "" and bar.TargetedGlow.alpha == 0 and bar.ImportantGlow.alpha == 0, "all three off: nothing drawn")
profile.castTargetName, profile.castTargetedGlow, profile.castImportantGlow = true, true, true
for _, case in ipairs({ { "nameplate1", { isPRD = true } }, { "nameplate2", { isObjectPlate = true } }, { "target" } }) do
	bar = Castbar(case[1], case[2])
	NP.NamePlate_UpdateCastTargetVisuals(bar, case[1])
	check(bar.TargetText.text == "" and bar.TargetedGlow.alphaFrom == nil and bar.ImportantGlow.alphaFrom == nil,
		"skipped for " .. case[1])
end

-- 5. A finished cast clears everything.
Reset()
bar = Castbar()
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
NP.Castbar_PostStop(bar, "nameplate3")
check(bar.TargetText.text == "" and bar.TargetedGlow.alpha == 0 and bar.ImportantGlow.alpha == 0, "stop clears name and glows")
NP.NamePlate_UpdateCastTargetVisuals(bar, "nameplate3")
bar.Text = Region()
bar.SetStatusBarColor = function() end
bar.GetStatusBarTexture = function() return nil end
NP.Castbar_PostFail(bar, "nameplate3")
check(bar.TargetText.text == "" and bar.TargetedGlow.alpha == 0 and bar.ImportantGlow.alpha == 0, "fail and interrupt clear name and glows")

print(("Castbar target: %d checks, %d failures (offline only)"):format(checks, failures))
if (failures > 0) then os.exit(1) end

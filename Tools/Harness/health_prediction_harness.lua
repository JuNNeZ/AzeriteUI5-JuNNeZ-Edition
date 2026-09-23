-- Native widget geometry model + the REAL oUF element and addon renderer.
-- Opaque values catch arithmetic/geometry misuse, but are not WoW secrets.
local root = arg[1] or "."
local tests = 0
local function check(value, message)
	assert(value, message)
	tests = tests + 1
end
local function equal(actual, expected, message)
	check(actual == expected, (message or "mismatch")..": "..tostring(actual).." / "..tostring(expected))
end
local opaqueValues = setmetatable({}, { __mode = "k" })
local function forbidden() error("attempt to inspect a secret or native fill") end
local secretMT = { __add = forbidden, __sub = forbidden, __mul = forbidden,
	__div = forbidden, __lt = forbidden, __le = forbidden, __concat = forbidden }
local function opaque(value)
	local token = setmetatable({}, secretMT)
	opaqueValues[token] = value
	return token
end
local function native(value)
	if (type(value) == "table") then return opaqueValues[value] end
	return value
end
local methods = {}
local function widget(kind, parent)
	return setmetatable({ kind = kind, parent = parent, shown = true, level = 2, points = {}, alpha = 1 }, { __index = methods })
end
function methods:CreateTexture() return widget("Texture", self) end
function methods:CreateMaskTexture() return widget("MaskTexture", self) end
function methods:SetTexture(path, x, y) self.path, self.wrapX, self.wrapY = path, x, y end
function methods:GetTexture() return self.path end
function methods:SetStatusBarTexture(path)
	self.fill = self.fill or widget("Fill", self)
	self.fill:SetTexture(path)
end
function methods:GetStatusBarTexture() return self.fill end
function methods:SetAllPoints(relative) self.allPoints = relative end
function methods:SetPoint(point, relative, relativePoint, ...)
	equal(select("#", ...), 0, "no unit-derived anchor offsets")
	self.points[#self.points + 1] = { point, relative, relativePoint }
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetWidth(width)
	check(type(width) == "number", "secret passed to width")
	self.width = width
end
function methods:GetWidth() assert(self.kind ~= "Fill"); return self.width end
function methods:GetHeight() return 14 end
function methods:GetOrientation() return "HORIZONTAL" end
function methods:GetReverseFill() return self.reverse or false end
function methods:SetReverseFill(value) self.reverse = value end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValue(...)
	equal(select("#", ...), 1, "calculator clamped flag leaked into interpolation argument")
	self.value = ...
end
methods.GetValue, methods.GetMinMaxValues, methods.GetTexCoord = forbidden, forbidden, forbidden
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetVertexColor(...) self.color = { ... } end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetAlphaFromBoolean(value, yes, no)
	equal(yes, 255, "boolean alpha range")
	equal(no, 0, "boolean alpha range")
	self.alpha = native(value) and yes / 255 or no
end
function methods:AddMaskTexture(mask)
	self.masks = self.masks or {}
	self.masks[#self.masks + 1] = mask
end
function methods:GetFrameLevel() return self.level end
function methods:SetFrameLevel(level) self.level = level end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(shown) self.shown = shown end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:IsVisible()
	return self.shown and self.alpha > 0 and (not self.parent or self.parent:IsVisible())
end
function CreateFrame(kind, name, parent) return widget(kind, parent) end

Enum = {
	UnitDamageAbsorbClampMode = { MissingHealth = 0, MissingHealthWithoutIncomingHeals = 1, MaximumHealth = 2 },
	UnitIncomingHealClampMode = { MissingHealth = 0 }, UnitHealAbsorbClampMode = { CurrentHealth = 0 },
	UnitHealAbsorbMode = { ReducedByIncomingHeals = 0 }
}
local data = { health = 50, maximum = 100, incoming = 20, absorb = 15, healAbsorb = 0 }
local secretMode = false
local function result(value) if secretMode then return opaque(value) end return value end
function UnitExists(unit) return unit ~= "missing" end
function UnitHealthMax() return result(data.maximum) end
function UnitGetDetailedHealPrediction(unit, healer, calc) calc.data = data end
function CreateUnitHealPredictionCalculator()
	local calc = {}
	function calc:Reset() self.clamp, self.overflow = 0, 1.05 end
	function calc:SetDamageAbsorbClampMode(value) self.clamp = value end
	function calc:SetIncomingHealClampMode(value) self.incomingClamp = value end
	function calc:SetIncomingHealOverflowPercent(value) self.overflow = value end
	function calc:SetHealAbsorbClampMode(value) self.healClamp = value end
	function calc:SetHealAbsorbMode(value) self.healMode = value end
	function calc:GetMaximumHealth() return result(self.data.maximum) end
	local function incoming(c)
		return math.min(math.max(0, c.data.incoming - c.data.healAbsorb), c.data.maximum - c.data.health)
	end
	function calc:GetIncomingHeals()
		local clamped = math.max(0, self.data.incoming - self.data.healAbsorb) > self.data.maximum - self.data.health
		return result(incoming(self)), result(0), result(incoming(self)), result(clamped)
	end
	function calc:GetDamageAbsorbs()
		local limit = self.data.maximum - self.data.health
		if self.clamp == 0 then limit = limit - incoming(self) end
		if self.clamp == 2 then limit = self.data.maximum end
		return result(math.min(limit, self.data.absorb)), result(self.data.absorb > limit)
	end
	function calc:GetHealAbsorbs()
		local amount = math.max(0, self.data.healAbsorb - self.data.incoming)
		return result(math.min(self.data.health, amount)), result(amount > self.data.health)
	end
	return calc
end

local profile, configs, elementDefinition, init = {}, { NamePlates = { HealthBarTexCoord = { 14/256, 242/256, 14/64, 50/64 } }, TargetFrame = {} }
local ns = { Prefix = "Test", API = {}, oUF = {} }
function ns.API.GetMedia(name) return "Interface\\AddOns\\Test\\Assets\\"..name..".tga" end
function ns:GetModule() return { db = { profile = profile } } end
function ns.GetConfig(name) return configs[name] end
function ns.oUF:AddElement(name, update, enable, disable) elementDefinition = { update = update, enable = enable, disable = disable } end
function ns.oUF:RegisterInitCallback(callback) init = callback end
assert(loadfile(root.."/Libs/oUF/elements/healthprediction.lua"))("Test", ns)
assert(loadfile(root.."/Components/UnitFrames/HealthPrediction.lua"))("Test", ns)

local function frame(shape, reverse, style, nameplate)
	local owner = widget("Frame")
	owner.unit, owner.style, owner.isNamePlate = "party1", "Test"..(style or "Party"), nameplate
	owner.Health = widget("StatusBar", owner)
	owner.Health.width, owner.Health.left, owner.Health.reverse = 100, 0, reverse
	owner.Health:SetStatusBarTexture(ns.API.GetMedia(shape))
	owner.Health:SetMinMaxValues(0, 100)
	owner.Health:SetValue(50)
	owner.HealthPrediction = widget("Texture", owner.Health)
	owner.HealthPrediction.absorbBar = widget("StatusBar", owner.Health)
	owner.HealthPrediction.PostUpdate = function() error("legacy prediction callback ran") end
	owner.events = {}
	function owner:RegisterEvent(event, callback) self.events[event] = callback end
	function owner:UnregisterEvent(event) self.events[event] = nil end
	function owner:IsElementEnabled() return self.enabled end
	owner.enabled = true
	elementDefinition.enable(owner)
	init(owner)
	return owner
end
local function update(owner)
	owner.Health.maximum, owner.Health.value = data.maximum, data.health
	owner.HealthPrediction:ForceUpdate()
end
local bounds
bounds = function(region)
	if region.allPoints then return bounds(region.allPoints) end
	if region.kind == "Fill" then
		local lo, hi = bounds(region.parent)
		local ratio = native(region.parent.value) / native(region.parent.maximum)
		if region.parent.reverse then return hi - (hi - lo) * ratio, hi end
		return lo, lo + (hi - lo) * ratio
	end
	if region.left then return region.left, region.left + region.width end
	local point = region.points[1]
	local lo, hi = bounds(point[2])
	local anchor = point[3]:find("RIGHT") and hi or lo
	if point[1]:find("RIGHT") then return anchor - region.width, anchor end
	return anchor, anchor + region.width
end
local function segment(driver, lo, hi)
	local actualLo, actualHi = bounds(driver.Mask)
	local boundLo, boundHi = bounds(driver.BoundsMask)
	actualLo, actualHi = math.max(actualLo, boundLo), math.min(actualHi, boundHi)
	equal(actualLo, lo, "segment start")
	equal(actualHi, hi, "segment end")
end

local function visibleAt(art, x)
	for _, mask in ipairs(art.masks or {}) do
		local lo, hi = bounds(mask)
		-- Model the reported failure conservatively: a degenerate mask does
		-- NOT hide the art. The fix must work without ever creating one.
		if hi > lo and (x <= lo or x >= hi) then return false end
	end
	return true
end

local party = frame("cast_bar", false)
local p = party.HealthPrediction
update(party)
segment(p.healingAll, 50, 70)
segment(p.damageAbsorb, 85, 100)
equal(p.healingAll.Art.allPoints, party.Health, "fixed full-size art")
equal(p.damageAbsorb:GetStatusBarTexture().alpha, 0, "invisible measuring fill")
equal(p.damageAbsorb.Mask.wrapX, "CLAMPTOBLACKADDITIVE", "mask clamps outside segment")
equal(p.overDamageAbsorbIndicator.alpha, 0, "no overflow")
check(not visibleAt(p.damageAbsorb.Art, 60), "hatch does not cover incoming healing")
check(visibleAt(p.damageAbsorb.Art, 95), "hatch covers actual shield")
check(not visibleAt(p.damageAbsorb.Art, 80), "hatch does not fill remaining missing health")
check(not p.shown and not p.PostUpdate, "legacy overlay remains disabled")
p.absorbBar:Show()
check(not p.absorbBar:IsVisible(), "legacy cache callback cannot redraw old absorb")
equal(p.values.data, data, "legacy numeric calculator remains current")
local originalDriver = p.damageAbsorb
init(party)
equal(p.damageAbsorb, originalDriver, "initialization is idempotent")

secretMode = true
update(party)
segment(p.damageAbsorb, 85, 100)
check(opaqueValues[p.damageAbsorb.value] == 15, "opaque amount passed directly")
check(opaqueValues[p.damageAbsorb.maximum] == 100, "opaque max passed directly")
local target = frame("hp_cap_bar", true, "Target")
target.unit = "target"
update(target)
segment(target.HealthPrediction.healingAll, 30, 50)
segment(target.HealthPrediction.damageAbsorb, 0, 15)
equal(target.HealthPrediction.damageAbsorb.Art.coords[1], 1, "mirrored target art")
check(target.HealthPrediction.healingAll:GetFrameLevel() > target.HealthPrediction.damageAbsorb:GetFrameLevel(),
	"incoming heals render above overlapping total shields")
data.absorb = 90
update(target)
segment(target.HealthPrediction.healingAll, 30, 50)
check(visibleAt(target.HealthPrediction.healingAll.Art, 40), "target incoming healing has visible mask coverage")
data.absorb = 15
-- A pending direct heal changes before health does. Exercise the real oUF event path.
data.incoming = 10
target.events.UNIT_HEAL_PREDICTION(target, "UNIT_HEAL_PREDICTION", "target")
segment(target.HealthPrediction.healingAll, 40, 50)
data.incoming = 0
target.events.UNIT_HEAL_PREDICTION(target, "UNIT_HEAL_PREDICTION", "target")
check(not visibleAt(target.HealthPrediction.healingAll.Art, 45), "cancelled target heal clears prediction")

data.incoming, data.healAbsorb = 20, 30
update(party)
segment(p.healAbsorb, 40, 50)
update(target)
segment(target.HealthPrediction.healAbsorb, 50, 60)

data.health, data.incoming, data.absorb, data.healAbsorb = 95, 0, 20, 0
update(party)
segment(p.damageAbsorb, 80, 100)
equal(p.overDamageAbsorbIndicator.alpha, 0, "shield below maximum needs no overflow cue")
data.health = 100
update(party)
segment(p.damageAbsorb, 80, 100)
equal(p.overDamageAbsorbIndicator.alpha, 0, "full-health shield is proportional, not a cue")
-- User examples: shield width must not depend on remaining health.
for _, sample in ipairs({ { 600000, 121000 }, { 575000, 178000 }, { 580000, 134000 } }) do
	data.maximum, data.absorb = sample[1], sample[2]
	for _, fraction in ipairs({ 1, .96, .83, .52, 0 }) do
		data.health = data.maximum * fraction
		for _, owner in ipairs({ party, target }) do
			update(owner)
			local shield = owner.HealthPrediction.damageAbsorb
			local lo, hi = bounds(shield.Mask)
			local blo, bhi = bounds(shield.BoundsMask)
			local width = math.min(hi, bhi) - math.max(lo, blo)
			check(math.abs(width - 100 * data.absorb / data.maximum) < 1e-8,
				"total shield percentage is independent of current health")
		end
	end
end
data.maximum, data.health, data.absorb = 100, 100, 125
update(party)
segment(p.damageAbsorb, 0, 100)
equal(p.overDamageAbsorbIndicator.alpha, 1, "shield beyond max health has overflow cue")
data.absorb = 0
update(party)
equal(p.overDamageAbsorbIndicator.alpha, 0, "shield removed")
for _, health in ipairs({ 0, 25, 50, 100 }) do
	data.health = health
	update(party)
	update(target)
	for _, owner in ipairs({ party, target }) do
		for _, driver in ipairs({ owner.HealthPrediction.healingAll, owner.HealthPrediction.damageAbsorb, owner.HealthPrediction.healAbsorb }) do
			local lo, hi = bounds(driver.Mask)
			check(hi > lo, "mask remains nonzero at zero amount")
			for x = .5, 99.5, 1 do
				check(not visibleAt(driver.Art, x), "zero amount must reveal no pixels")
			end
		end
	end
end

data.health, data.incoming, data.absorb = 50, 20, 15
profile.showIncomingHeals = false
update(party)
segment(p.damageAbsorb, 85, 100)
check(not p.healingAll.Art.shown and p.healingAll.shown, "hidden healing keeps zero anchor alive")
equal(p.shapedValues.clamp, 2, "total shields ignore incoming-heal toggle")
check(p.values ~= p.shapedValues, "legacy numeric cache has its own calculator")
profile.showDamageAbsorbs, profile.showHealAbsorbs = false, false
ns.API.RefreshHealthPrediction()
check(not p.damageAbsorb.shown and not p.healAbsorb.shown, "independent opt-outs")
profile.showIncomingHeals, profile.showDamageAbsorbs, profile.showHealAbsorbs = true, true, true
update(party)

elementDefinition.disable(party)
party.enabled = false
ns.API.RefreshHealthPrediction()
check(not p.damageAbsorb:IsVisible(), "ForceUpdate cannot revive disabled element")
party.enabled = true
elementDefinition.enable(party)
update(party)
check(p.damageAbsorb:IsVisible() and p.overDamageAbsorbIndicator.shown, "reenable restores layers and cue")
equal(p.shapedValues.overflow, 1, "reenable preserves clamp settings")
party.Health:Hide()
check(not p.damageAbsorb.Art:IsVisible(), "hidden health suppresses all art")
party.Health:Show()
party.unit = "missing"
update(party)
check(not p.damageAbsorb:IsVisible(), "missing/recycled unit clears layers")
party.unit = "party2"
update(party)
check(p.damageAbsorb:IsVisible(), "new unit restores layers")

configs.TargetFrame.HideHealthAbsorb = true
update(target)
check(not target.HealthPrediction.damageAbsorb.shown, "target layout hide setting")
configs.TargetFrame.HideHealthAbsorb = false
for _, shape in ipairs({ "cast_bar", "hp_lowmid_bar", "hp_cap_bar", "hp_boss_bar", "hp_critter_bar", "nameplate_bar" }) do
	party.Health:SetStatusBarTexture(ns.API.GetMedia(shape))
	party.Health.width = 200
	update(party)
	equal(p.damageAbsorb.Art.path, ns.API.GetMedia(shape.."-absorb"), "shape changes")
	equal(p.healAbsorb.Art.path, ns.API.GetMedia(shape.."-healabsorb"), "lattice changes")
	equal(p.damageAbsorb.width, 200, "layout resize")
end
local plate = frame("nameplate_bar", true, "NamePlates", true)
update(plate)
equal(plate.HealthPrediction.damageAbsorb.Art.coords[1], 242/256, "nameplate mirrored crop")
equal(plate.HealthPrediction.damageAbsorb.Art.coords[3], 14/64, "nameplate vertical crop")
plate.Health:SetAlpha(0)
check(not plate.HealthPrediction.damageAbsorb.Art:IsVisible(), "name-only/object plate inherits alpha")
plate.Health:SetAlpha(1)
plate.Health.reverse = false
update(plate)
segment(plate.HealthPrediction.damageAbsorb, 85, 100)
equal(plate.HealthPrediction.damageAbsorb.Art.coords[1], 14/256, "recycled direction updates crop")
_G.__AzeriteUI_DISABLE_HEALTH_PREDICTION = true
update(plate)
check(not plate.HealthPrediction.damageAbsorb:IsVisible(), "debug kill switch")
_G.__AzeriteUI_DISABLE_HEALTH_PREDICTION = nil
update(plate)
check(plate.HealthPrediction.damageAbsorb:IsVisible(), "debug switch restores rendering")

local originalAlphaMethod = methods.SetAlphaFromBoolean
methods.SetAlphaFromBoolean = nil
local unsupported = frame("cast_bar", false)
check(not unsupported.HealthPrediction.shapedPrediction, "missing capability leaves old renderer untouched")
methods.SetAlphaFromBoolean = originalAlphaMethod

local options
local module = { db = { profile = profile } }
local optionsModule = { AddGroup = function() error("prediction must not register a top-level page") end }
function ns:GetModule(name) return name == "Options" and optionsModule or module end
-- The page reads its text through AceLocale. enUS values are `true`, which AceLocale returns as the key.
LibStub = LibStub or function()
	return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end
assert(loadfile(root.."/Options/OptionsPages/HealthPrediction.lua"))("Test", ns)
options = optionsModule:GenerateHealthPredictionOptions()
equal(options.name, "Incoming Heals and Absorbs", "the page reads its name through the locale table")
equal(options.args.absorbDisplayMode.values.followHealth, "Follow health", "select values read through the locale table")
for _, key in ipairs({ "showIncomingHeals", "showDamageAbsorbs", "showHealAbsorbs" }) do
	local option = options.args[key]
	check(option.get({ key }), "option defaults on")
	option.set({ key }, false)
	check(not option.get({ key }), "option persists off")
	option.set({ key }, true)
end

-- Switching the option must update both geometry and clamping immediately.
party.Health.width = 100
local mode = options.args.absorbDisplayMode
equal(mode.get(), "total", "existing profiles default to total shields")
data.maximum, data.health, data.incoming, data.absorb, data.healAbsorb = 100, 40, 10, 25, 0
update(party)
update(target)
mode.set({ "absorbDisplayMode" }, "followHealth")
segment(p.damageAbsorb, 50, 75)
segment(target.HealthPrediction.damageAbsorb, 25, 50)
equal(p.overDamageAbsorbIndicator.alpha, 0, "follow mode fits without cue")
profile.showIncomingHeals = false
ns.API.RefreshHealthPrediction()
segment(p.damageAbsorb, 40, 65)
segment(target.HealthPrediction.damageAbsorb, 35, 60)
equal(p.shapedValues.clamp, 1, "hidden healing reserves no shield space")
profile.showIncomingHeals = true
data.health, data.incoming = 95, 0
update(party)
update(target)
ns.API.RefreshHealthPrediction()
segment(p.damageAbsorb, 95, 100)
equal(p.overDamageAbsorbIndicator.alpha, 1, "follow mode signals clipped shield")
data.health = 100
update(party)
update(target)
ns.API.RefreshHealthPrediction()
segment(p.damageAbsorb, 100, 100)
equal(p.overDamageAbsorbIndicator.alpha, 1, "full health follows with cue only")
mode.set({ "absorbDisplayMode" }, "total")
segment(p.damageAbsorb, 75, 100)
segment(target.HealthPrediction.damageAbsorb, 0, 25)
equal(p.overDamageAbsorbIndicator.alpha, 0, "switch clears old overflow cue")
for _, selected in ipairs({ "followHealth", "total", "invalid" }) do
	data.absorb = 0
	mode.set({ "absorbDisplayMode" }, selected)
	for _, owner in ipairs({ party, target }) do
		for x = .5, 99.5, 1 do
			check(not visibleAt(owner.HealthPrediction.damageAbsorb.Art, x), "zero shield clips in either mode")
		end
	end
end
equal(mode.get(), "total", "invalid saved mode falls back to total")
mode.set({ "absorbDisplayMode" }, "total")
party.Health.width = 200
data.health, data.incoming, data.absorb = 50, 20, 15
update(party)

local overhealOption = options.args.showOverhealIndicator
check(not overhealOption.get(), "overheal cue defaults off")
data.health, data.incoming, data.absorb = 95, 20, 0
update(party)
check(not p.overHealIndicator.shown, "default does not add a new marker")
overhealOption.set({ "showOverhealIndicator" }, true)
equal(p.overHealIndicator.alpha, 1, "overheal flag routes to native alpha")
check(p.overHealIndicator.shown, "overheal toggle updates current frames")
profile.showIncomingHeals = false
ns.API.RefreshHealthPrediction()
check(not p.overHealIndicator.shown, "hidden incoming heals hides overheal cue")
profile.showIncomingHeals = true
data.incoming = 5
update(party)
equal(p.overHealIndicator.alpha, 0, "heal exactly filling health is not overheal")
data.health, data.incoming = 100, 20
update(party)
equal(p.overHealIndicator.alpha, 1, "full health still indicates incoming overheal")
data.incoming = 0
update(party)
equal(p.overHealIndicator.alpha, 0, "cancelled heal clears overheal")
elementDefinition.disable(party)
check(not p.overHealIndicator:IsVisible(), "oUF disable hides overheal")
elementDefinition.enable(party)
data.health, data.incoming, data.absorb = 50, 20, 15
update(party)

-- Mutation: prove the geometry assertion detects a misplaced absorb anchor.
p.damageAbsorb.points[1][2] = party.Health:GetStatusBarTexture()
check(not pcall(segment, p.damageAbsorb, 170, 200), "anchor mutation must fail")
-- Mutation: the setters reject both the secret-as-width and extra-return bugs.
check(not pcall(methods.SetWidth, p.damageAbsorb, opaque(12)), "secret width mutation must fail")
check(not pcall(methods.SetValue, p.damageAbsorb, opaque(12), opaque(false)), "tuple mutation must fail")
print("health_prediction_harness: "..tests.." assertions passed (not a WoW rendering test)")

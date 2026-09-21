-- Shaped prediction art. Unit amounts go only to native StatusBars; Lua never
-- reads their values or their fill geometry. A mask follows each native fill.
local _, ns = ...
local API = ns.API
local WHITE = [[Interface\Buttons\WHITE8X8]]
local frames = setmetatable({}, { __mode = "k" })
local shapes = {}
for _, name in ipairs({ "cast_bar", "hp_lowmid_bar", "hp_cap_bar", "hp_boss_bar", "hp_critter_bar", "nameplate_bar" }) do
	shapes[API.GetMedia(name):lower()] = name
end

local function GetProfile()
	local module = ns:GetModule("UnitFrames", true)
	return module and module.db and module.db.profile or {}
end

local function CreateLayer(health, level, r, g, b, a)
	-- Do not use CreateBar: these are measuring widgets, with no smoothing or
	-- texture/percent hooks. Only the fill texture is invisible, not its parent.
	local driver = CreateFrame("StatusBar", nil, health)
	driver:SetFrameLevel(health:GetFrameLevel() + 1)
	driver:SetStatusBarTexture(WHITE)
	driver:GetStatusBarTexture():SetAlpha(0)
	driver:SetMinMaxValues(0, 1)
	driver:SetValue(0)
	local mask = driver:CreateMaskTexture()
	mask:SetTexture(WHITE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
	-- Never collapse a mask onto a zero-width fill: a degenerate mask can
	-- stop clipping in the client. Intersect two full-width masks instead.
	local boundsMask = driver:CreateMaskTexture()
	boundsMask:SetTexture(WHITE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
	boundsMask:SetAllPoints(driver)
	local art = driver:CreateTexture(nil, "ARTWORK", nil, level)
	art:SetAllPoints(health)
	art:SetVertexColor(r, g, b, a)
	art:AddMaskTexture(mask)
	art:AddMaskTexture(boundsMask)
	driver.Art = art
	driver.Mask = mask
	driver.BoundsMask = boundsMask
	return driver
end

local function AnchorSegment(driver, anchor, reverse, inward, width)
	local start = reverse and "RIGHT" or "LEFT"
	local edge = reverse and "LEFT" or "RIGHT"
	if (inward) then start = edge end
	driver:ClearAllPoints()
	driver:SetPoint("TOP"..start, anchor, "TOP"..edge)
	driver:SetPoint("BOTTOM"..start, anchor, "BOTTOM"..edge)
	driver:SetWidth(width) -- layout width, never a unit amount or fill width
	local fillReverse = inward and not reverse or not inward and reverse
	driver:SetReverseFill(fillReverse)
	local fillEdge = fillReverse and "LEFT" or "RIGHT"
	driver.Mask:ClearAllPoints()
	driver.Mask:SetPoint("TOP"..fillEdge, driver:GetStatusBarTexture(), "TOP"..fillEdge)
	driver.Mask:SetPoint("BOTTOM"..fillEdge, driver:GetStatusBarTexture(), "BOTTOM"..fillEdge)
	driver.Mask:SetWidth(width)
end

local function HideLayers(element)
	element.healingAll:Hide()
	element.damageAbsorb:Hide()
	element.healAbsorb:Hide()
end

local function Layout(self)
	local health, element = self.Health, self.HealthPrediction
	local native = health:GetStatusBarTexture()
	local path = health._cachedTexture or (native and native:GetTexture())
	local shape = type(path) == "string" and shapes[path:lower()]
	if (not shape or health:GetOrientation() ~= "HORIZONTAL") then
		HideLayers(element)
		return false
	end
	local width = health:GetWidth()
	local reverse = health:GetReverseFill()
	local followHealth = GetProfile().absorbDisplayMode == "followHealth"
	local left, right, top, bottom = 0, 1, 0, 1
	if (self.isNamePlate) then
		local config = ns.GetConfig("NamePlates")
		left, right, top, bottom = unpack(config.HealthBarTexCoord or { 0, 1, 0, 1 })
	end
	-- Target's fake fill uses mirrored art. Symmetric cast bars use the same
	-- convention, and nameplates keep their layout's trimmed texture rectangle.
	if (reverse) then left, right = right, left end
	local layout = element.shapedLayout
	if (not layout or layout.path ~= path or layout.width ~= width or layout.reverse ~= reverse
		or layout.left ~= left or layout.right ~= right or layout.top ~= top or layout.bottom ~= bottom
		or layout.followHealth ~= followHealth) then
		AnchorSegment(element.healingAll, native, reverse, false, width)
		-- Total shields are measured inward from the bar's end, independent of
		-- missing health. Excess over current health stays visible on the fill.
		if (followHealth) then
			AnchorSegment(element.damageAbsorb, element.healingAll:GetStatusBarTexture(), reverse, false, width)
		else
			AnchorSegment(element.damageAbsorb, health, reverse, true, width)
		end
		AnchorSegment(element.healAbsorb, native, reverse, true, width)
		element.healingAll.Art:SetTexture(API.GetMedia(shape))
		element.damageAbsorb.Art:SetTexture(API.GetMedia(shape.."-absorb"))
		element.healAbsorb.Art:SetTexture(API.GetMedia(shape.."-healabsorb"))
		for _, driver in ipairs({ element.healingAll, element.damageAbsorb, element.healAbsorb }) do
			driver.Art:SetTexCoord(left, right, top, bottom)
		end
		local cue = element.overDamageAbsorbIndicator
		cue:SetTexture(API.GetMedia(shape.."-absorb"))
		cue:SetTexCoord(left, right, top, bottom)
		element.overHealIndicator:SetTexture(API.GetMedia(shape))
		element.overHealIndicator:SetTexCoord(left, right, top, bottom)
		local mask = element.overDamageAbsorbMask
		local edge = reverse and "LEFT" or "RIGHT"
		mask:ClearAllPoints()
		mask:SetPoint("TOP"..edge, health, "TOP"..edge)
		mask:SetPoint("BOTTOM"..edge, health, "BOTTOM"..edge)
		mask:SetWidth(math.min(12, width * .15))
		element.shapedLayout = { path = path, width = width, reverse = reverse,
			left = left, right = right, top = top, bottom = bottom, followHealth = followHealth }
	end
	return true
end

local function Update(self, event, unit)
	if (unit ~= self.unit or not unit or not self:IsElementEnabled("HealthPrediction")) then return end
	local element = self.HealthPrediction
	-- Legacy textures remain as layout handles (and for absorb-number caches),
	-- but can never draw over the new renderer.
	element:Hide()
	if (element.absorbBar) then element.absorbBar:Hide() end
	if (not Layout(self)) then return end
	if (not UnitExists(unit)) then
		HideLayers(element)
		return
	end
	-- Keep the calculator consumed by the legacy numeric absorb tags current.
	UnitGetDetailedHealPrediction(unit, "player", element.values)
	if (_G.__AzeriteUI_DISABLE_HEALTH_PREDICTION) then
		HideLayers(element)
		return
	end
	local profile = GetProfile()
	local showHealing = profile.showIncomingHeals ~= false
	local showAbsorb = profile.showDamageAbsorbs ~= false
	local showHealAbsorb = profile.showHealAbsorbs ~= false
	if (self.style == ns.Prefix.."Target") then
		local config = ns.GetConfig("TargetFrame")
		showAbsorb = showAbsorb and not config.HideHealthAbsorb
	end

	local calc = element.shapedValues
	local clamp = Enum.UnitDamageAbsorbClampMode.MaximumHealth
	if (profile.absorbDisplayMode == "followHealth") then
		clamp = showHealing and Enum.UnitDamageAbsorbClampMode.MissingHealth
			or Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals
	end
	calc:SetDamageAbsorbClampMode(clamp)
	UnitGetDetailedHealPrediction(unit, "player", calc)
	local maximum = calc:GetMaximumHealth()
	local incoming, _, _, overheal = calc:GetIncomingHeals()
	local absorb, clamped = calc:GetDamageAbsorbs()
	local healAbsorb = calc:GetHealAbsorbs()
	element.healingAll:SetMinMaxValues(0, maximum)
	element.damageAbsorb:SetMinMaxValues(0, maximum)
	element.healAbsorb:SetMinMaxValues(0, maximum)
	if (showHealing) then element.healingAll:SetValue(incoming)
	else element.healingAll:SetValue(0) end
	element.damageAbsorb:SetValue(absorb)
	element.healAbsorb:SetValue(healAbsorb)
	element.overDamageAbsorbIndicator:SetAlphaFromBoolean(clamped, 255, 0)
	element.overDamageAbsorbIndicator:Show()
	element.overHealIndicator:SetAlphaFromBoolean(overheal, 255, 0)
	element.overHealIndicator:SetShown(showHealing and profile.showOverhealIndicator == true)
	-- The incoming-heal segment remains independent of the total-shield layer.
	element.healingAll:Show()
	element.healingAll.Art:SetShown(showHealing)
	element.damageAbsorb:SetShown(showAbsorb)
	element.healAbsorb:SetShown(showHealAbsorb)
end

local function Initialize(self)
	local health, element = self.Health, self.HealthPrediction
	if (not health or not element or not element.values or element.shapedPrediction) then return end
	if (not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction
		or not health.CreateMaskTexture or not element.SetAlphaFromBoolean) then return end
	-- The legacy player/target numeric absorb caches use element.values with
	-- MaximumHealth clamping. Keep their calculator independent of our segments.
	local calc = CreateUnitHealPredictionCalculator()
	if (not calc.GetIncomingHeals or not calc.GetDamageAbsorbs or not calc.GetHealAbsorbs
		or not calc.GetMaximumHealth or not calc.SetDamageAbsorbClampMode
		or not calc.SetIncomingHealClampMode or not calc.SetIncomingHealOverflowPercent
		or not calc.SetHealAbsorbClampMode or not calc.SetHealAbsorbMode
		or not Enum or not Enum.UnitDamageAbsorbClampMode
		or Enum.UnitDamageAbsorbClampMode.MaximumHealth == nil
		or Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals == nil
		or not Enum.UnitIncomingHealClampMode or not Enum.UnitHealAbsorbClampMode or not Enum.UnitHealAbsorbMode) then return end

	element:SetAlpha(0)
	element:Hide()
	if (element.absorbBar) then
		-- PlayerAlternate's number-cache event can still Show its legacy bar.
		-- Retain the object for that code but make it permanently transparent.
		element.absorbBar:SetAlpha(0)
		element.absorbBar:Hide()
	end
	element.PostUpdate = nil -- never run the old arithmetic/preview callback
	element.Override = Update
	element.UpdateSize = function() end -- Layout owns the native measuring widths
	element.shapedPrediction = true
	element.shapedValues = calc
	calc:SetIncomingHealOverflowPercent(1)
	calc:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
	calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
	calc:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.CurrentHealth)
	calc:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)
	element.healingAll = CreateLayer(health, 1, 0, .7, 0, .65)
	element.damageAbsorb = CreateLayer(health, 2, 1, 1, 1, .8)
	element.healAbsorb = CreateLayer(health, 3, .38, .02, .02, .92)
	-- Incoming healing can overlap the end-anchored shield; keep green readable.
	element.healingAll:SetFrameLevel(health:GetFrameLevel() + 2)
	element.healAbsorb:SetFrameLevel(health:GetFrameLevel() + 2)
	local cue = element.damageAbsorb:CreateTexture(nil, "ARTWORK", nil, 4)
	cue:SetAllPoints(health)
	cue:SetVertexColor(1, 1, 1, .8)
	cue:SetAlpha(0)
	local mask = element.damageAbsorb:CreateMaskTexture()
	mask:SetTexture(WHITE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	cue:AddMaskTexture(mask)
	element.overDamageAbsorbIndicator = cue
	element.overDamageAbsorbMask = mask
	local overHeal = element.healingAll:CreateTexture(nil, "ARTWORK", nil, 4)
	overHeal:SetAllPoints(health)
	overHeal:SetVertexColor(.1, 1, .2, 1)
	overHeal:SetAlpha(0)
	local healMask = element.healingAll:CreateMaskTexture()
	healMask:SetTexture(WHITE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	healMask:SetAllPoints(mask)
	overHeal:AddMaskTexture(healMask)
	element.overHealIndicator = overHeal
	HideLayers(element)
	frames[self] = true
end

-- oUF invokes this after styles and elements have initialized, including
-- secure header children and recycled nameplate frames. No library edits.
ns.oUF:RegisterInitCallback(Initialize)

-- Refresh display preferences immediately, including nameplates and headers.
API.RefreshHealthPrediction = function()
	for frame in pairs(frames) do
		frame.HealthPrediction:ForceUpdate()
	end
end

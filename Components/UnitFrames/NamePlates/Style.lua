--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Nameplates, 9 of 10: the style: every region a plate is built from, and the UIParent alpha mirror.
-- Loaded after BlizzardPlates.lua; see Settings.lua for how these files share their locals.
local _, ns = ...

local NP = ns.NamePlatesPrivate
if (not NP) then return end

local next = next
local unpack = unpack

local prefix = NP.prefix
local ApplyNamePlateAlpha = NP.ApplyNamePlateAlpha
local GetNamePlateBarLayout = NP.GetNamePlateBarLayout
local ApplyNamePlateScale = NP.ApplyNamePlateScale
local Health_PostUpdate = NP.Health_PostUpdate
local Health_UpdateColor = NP.Health_UpdateColor
local Health_PostUpdateColor = NP.Health_PostUpdateColor
local Power_PostUpdate = NP.Power_PostUpdate
local AnchorNamePlateRaidTarget = NP.AnchorNamePlateRaidTarget
local NamePlate_ApplyHealthValueLayout = NP.NamePlate_ApplyHealthValueLayout
local Auras_PostUpdate = NP.Auras_PostUpdate
local NamePlate_ResetCastbarVisuals = NP.NamePlate_ResetCastbarVisuals
local NamePlate_ClearInterruptState = NP.NamePlate_ClearInterruptState
local Castbar_PostCastVisual = NP.Castbar_PostCastVisual
local Castbar_PostCastUpdate = NP.Castbar_PostCastUpdate
local Castbar_PostStop = NP.Castbar_PostStop
local Castbar_PostFail = NP.Castbar_PostFail
local NamePlate_PostUpdateElements = NP.NamePlate_PostUpdateElements
local NamePlate_PostUpdate = NP.NamePlate_PostUpdate
local NamePlate_OnHide = NP.NamePlate_OnHide
local NamePlate_OnEvent = NP.NamePlate_OnEvent

--[[
	Mirror UIParent's alpha onto our nameplates, so they fade out when Immersion
	says so. Nameplates toggle SetIgnoreParentAlpha for mouseover and soft
	target, which is what breaks the inheritance this puts back.

	One hook for every plate, installed on first style. It used to be a closure
	per plate, on a global, never removed: with plates created on demand for the
	whole session that left a chain dozens deep, every link doing the same work.
	UIParent:GetAlpha carries no access precondition, so unlike GetEffectiveAlpha
	it cannot come back empty, and SetAlpha takes a secret from us either way.
]]
local uiParentAlphaHooked
local SyncNamePlatesToUIParentAlpha = function()
	-- Through the one alpha rule, so a hidden plate stays hidden and a faded one faded.
	for plate in next, ns.NamePlates do
		ApplyNamePlateAlpha(plate)
	end
end

local style = function(self, unit, id)

	local db = ns.GetConfig("NamePlates")
	local bars = GetNamePlateBarLayout(db)

	self.colors = ns.Colors

	self:SetPoint("CENTER",0,0)
	self:SetSize(unpack(db.Size))
	ApplyNamePlateScale(self)
	self:SetFrameLevel(self:GetFrameLevel() + 2)

	self:SetScript("OnHide", NamePlate_OnHide)

	-- Overlay for icons and text
	--------------------------------------------
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetFrameLevel(self:GetFrameLevel() + 7)
	overlay:SetAllPoints()

	self.Overlay = overlay

	-- Health
	--------------------------------------------
	local health = self:CreateBar()
	if (health.SetForceNative) then health:SetForceNative(true) end
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:SetPoint(unpack(db.HealthBarPosition))
	health:SetSize(unpack(db.HealthBarSize))
	health:SetStatusBarTexture(db.HealthBarTexture)
	health:SetTexCoord(bars.texLeft, bars.texRight, bars.texTop, bars.texBottom)
	health:SetOrientation(bars.mainOrientation)
	health:SetReverseFill(false)
	health:SetFlippedHorizontally(false)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorThreat = true
	health.colorClass = true
	health.colorClassPet = true
	health.colorClassHostileOnly = true
	health.colorReaction = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.UpdateColor = Health_UpdateColor
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	ns.API.BindStatusBarValueMirror(self.Health)

	local healthBackdrop = health:CreateTexture(nil, "BACKGROUND", nil, -1)
	healthBackdrop:SetPoint(unpack(db.HealthBackdropPosition))
	healthBackdrop:SetSize(unpack(db.HealthBackdropSize))
	healthBackdrop:SetTexture(db.HealthBackdropTexture)

	self.Health.Backdrop = healthBackdrop

	local healthOverlay = CreateFrame("Frame", nil, health)
	healthOverlay:SetFrameLevel(overlay:GetFrameLevel())
	healthOverlay:SetAllPoints()

	self.Health.Overlay = healthOverlay

	self.Health.__AzeriteUI_UseProductionNativeFill = true

	local healthPreview = self:CreateBar(nil, health)
	if (healthPreview.SetForceNative) then healthPreview:SetForceNative(true) end
	healthPreview:SetAllPoints(health)
	healthPreview:SetFrameLevel(health:GetFrameLevel() - 1)
	healthPreview:SetStatusBarTexture(db.HealthBarTexture)
	healthPreview:SetSparkTexture("")
	healthPreview:SetAlpha(0)
	healthPreview:Hide()
	healthPreview:DisableSmoothing(true)
	healthPreview:SetOrientation(bars.mainOrientation)
	healthPreview:SetTexCoord(bars.texLeft, bars.texRight, bars.texTop, bars.texBottom)
	healthPreview:SetReverseFill(false)
	healthPreview:SetFlippedHorizontally(false)

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict:SetTexture(db.HealthBarTexture)

	-- The element only: Components/UnitFrames/HealthPrediction.lua draws prediction through its Override.
	self.HealthPrediction = healPredict
	self.HealthPrediction:SetAlpha(0)
	self.HealthPrediction:Hide()

	-- Castbar
	--------------------------------------------
	local castbar = self:CreateBar()
	if (castbar.SetForceNative) then castbar:SetForceNative(true) end
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSize(unpack(db.CastBarSize))
	castbar:SetPoint("TOP", health, "BOTTOM", 0, -1)
	castbar:SetSparkMap(db.CastBarSparkMap)
	castbar:SetStatusBarTexture(db.CastBarTexture)
	castbar:SetStatusBarColor(unpack(db.CastBarColor))
	castbar:SetTexCoord(bars.castTexLeft, bars.castTexRight, bars.castTexTop, bars.castTexBottom)
	castbar:SetOrientation(bars.mainOrientation)
	if (castbar.SetReverseFill) then
		castbar:SetReverseFill(false)
	end
	castbar:SetFlippedHorizontally(false)
	castbar:DisableSmoothing(true)
	castbar.timeToHold = db.CastBarTimeToHoldFailed

	self.Castbar = castbar
	self.Castbar.PostCastStart = Castbar_PostCastVisual
	self.Castbar.PostCastUpdate = Castbar_PostCastUpdate
	self.Castbar.PostCastStop = Castbar_PostStop
	self.Castbar.PostCastFail = Castbar_PostFail
	self.Castbar.PostCastInterrupted = Castbar_PostFail
	self.Castbar.PostCastInterruptible = Castbar_PostCastVisual
	ns.API.AttachScriptSafe(self.Castbar, "OnHide", function(element)
		ns.API.ClearInterruptCastBarRefresh(element)
		NamePlate_ClearInterruptState(element)
		NamePlate_ResetCastbarVisuals(element)
	end)

	local castBackdrop = castbar:CreateTexture(nil, "BACKGROUND", nil, -1)
	castBackdrop:SetSize(unpack(db.CastBarBackdropSize))
	castBackdrop:SetPoint(unpack(db.CastBarBackdropPosition))
	castBackdrop:SetTexture(db.CastBarBackdropTexture)

	self.Castbar.Backdrop = castBackdrop

	local castText = castbar:CreateFontString(nil, "OVERLAY", nil, 1)
	castText:SetPoint(unpack(db.CastBarNamePosition))
	castText:SetJustifyH(db.CastBarNameJustifyH)
	castText:SetJustifyV(db.CastBarNameJustifyV)
	castText:SetFontObject(db.CastBarNameFont)
	castText:SetTextColor(unpack(db.CastBarNameColor))
	if (castText.SetWordWrap) then
		castText:SetWordWrap(false)
	end

	self.Castbar.Text = castText

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetWidth((db.HealthBarSize and db.HealthBarSize[1] or 92) - 8)
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:HealthCurrent]"))

	self.Health.Value = healthValue
	NamePlate_ApplyHealthValueLayout(self)

	-- Power
	--------------------------------------------
	local power = CreateFrame("StatusBar", nil, self)
	power:SetFrameLevel(health:GetFrameLevel() + 2)
	power:SetPoint(unpack(db.PowerBarPosition))
	power:SetSize(unpack(db.PowerBarSize))
	power:SetStatusBarTexture(db.PowerBarTexture)
	local ptex = power:GetStatusBarTexture()
	if ptex and ptex.SetTexCoord and db.PowerBarTexCoord then
		ptex:SetTexCoord(unpack(db.PowerBarTexCoord))
	end
	-- Vertical fill; flip for DOWN to keep art static
	if (db.PowerBarOrientation == "DOWN") then
		power:SetOrientation("VERTICAL")
		if ptex and ptex.SetTexCoord then ptex:SetTexCoord(0,1,1,0) end
	else
		power:SetOrientation("VERTICAL")
	end
	power:SetAlpha(0)
	power.isHidden = true
	power.frequentUpdates = true
	power.displayAltPower = true
	power.colorPower = true
	power.safeBarMin = 0
	power.safeBarMax = 1
	power.safeBarValue = 1

	self.Power = power
	self.Power.Override = ns.API.UpdatePower
	self.Power.PostUpdate = Power_PostUpdate
	ns.API.BindStatusBarValueMirror(self.Power)

	local powerBackdrop = power:CreateTexture(nil, "BACKGROUND", nil, -1)
	powerBackdrop:SetPoint(unpack(db.PowerBarBackdropPosition))
	powerBackdrop:SetSize(unpack(db.PowerBarBackdropSize))
	powerBackdrop:SetTexture(db.PowerBarBackdropTexture)

	self.Power.Backdrop = powerBackdrop

	-- Unit Name
	--------------------------------------------
	local name = self:CreateFontString(nil, "OVERLAY", nil, 1)
	name:SetPoint(unpack(db.NamePosition))
	name:SetFontObject(db.NameFont)
	name:SetTextColor(unpack(db.NameColor))
	name:SetJustifyH(db.NameJustifyH)
	name:SetJustifyV(db.NameJustifyV)
	if (name.SetWordWrap) then
		name:SetWordWrap(false)
	end
	self:Tag(name, prefix("[*:Name(24,nil,nil,nil)]")) -- maxChars, showLevel, showLevelLast, showFull

	self.Name = name

	-- Target Highlight
	--------------------------------------------
	local targetHighlight = healthOverlay:CreateTexture(nil, "BACKGROUND", nil, -2)
	targetHighlight:SetPoint(unpack(db.TargetHighlightPosition))
	targetHighlight:SetSize(unpack(db.TargetHighlightSize))
	targetHighlight:SetTexture(db.TargetHighlightTexture)
	targetHighlight.colorTarget = db.TargetHighlightTargetColor
	targetHighlight.colorFocus = db.TargetHighlightFocusColor
	targetHighlight.colorSoftEnemy = db.TargetHighlightSoftEnemyColor
	targetHighlight.colorSoftInteract = db.TargetHighlightSoftInteractColor

	self.TargetHighlight = targetHighlight

	-- Raid Target Indicator
	--------------------------------------------
	local raidTarget = self:CreateTexture(nil, "OVERLAY", nil, 1)
	raidTarget:SetTexture(db.RaidTargetTexture)

	self.RaidTargetIndicator = raidTarget
	AnchorNamePlateRaidTarget(self)

	-- Classification Badge
	--------------------------------------------
	local classification = healthOverlay:CreateTexture(nil, "OVERLAY", nil, -2)
	classification:SetSize(unpack(db.ClassificationSize))
	classification:SetPoint(unpack(db.ClassificationPosition))
	classification.bossTexture = db.ClassificationIndicatorBossTexture
	classification.eliteTexture = db.ClassificationIndicatorEliteTexture
	classification.rareTexture = db.ClassificationIndicatorRareTexture

	self.Classification = classification

	-- Threat
	--------------------------------------------
	local threatIndicator = health:CreateTexture(nil, "BACKGROUND", nil, -2)
	threatIndicator:SetPoint(unpack(db.ThreatPosition))
	threatIndicator:SetSize(unpack(db.ThreatSize))
	threatIndicator:SetTexture(db.ThreatTexture)

	self.ThreatIndicator = threatIndicator

	-- Auras
	--------------------------------------------
	local auras = CreateFrame("Frame", nil, self)
	auras:SetSize(unpack(db.AurasSize))
	auras:SetPoint(unpack(db.AurasPosition))
	auras.size = db.AuraSize
	auras.spacing = db.AuraSpacing
	auras.numTotal = db.AurasNumTotal
	auras.disableMouse = db.AurasDisableMouse
	auras.disableCooldown = db.AurasDisableCooldown
	auras.onlyShowPlayer = db.AurasOnlyShowPlayer
	auras.showStealableBuffs = db.AurasShowStealableBuffs
	auras.initialAnchor = db.AurasInitialAnchor
	auras["spacing-x"] = db.AurasSpacingX
	auras["spacing-y"] = db.AurasSpacingY
	auras["growth-x"] = db.AurasGrowthX
	auras["growth-y"] = db.AurasGrowthY
	auras.sortMethod = db.AurasSortMethod
	auras.sortDirection = db.AurasSortDirection
	auras.reanchorIfVisibleChanged = true
	auras.allowCombatUpdates = true
	auras.FilterAura = ns.AuraFilters.NameplateAuraFilter
	auras.CreateButton = ns.AuraStyles.CreateSmallButton
	auras.PostUpdateButton = ns.AuraStyles.NameplatePostUpdateButton

	if (ns:GetModule("UnitFrames").db.global.disableAuraSorting) then
		auras.SortAuras = ns.AuraSorts.AlternateFuncton
	else
		auras.SortAuras = ns.AuraSorts.DefaultFunction
	end

	self.Auras = auras
	self.Auras.PostUpdate = Auras_PostUpdate

	self.PostUpdate = NamePlate_PostUpdate
	self.OnEnter = NamePlate_PostUpdateElements
	self.OnLeave = NamePlate_PostUpdateElements

	-- The plate's own unit events. Everything that is not about this unit alone - target, focus,
	-- soft targets, combat, zoning - is handled once by the module for all plates. A faction
	-- change used to be caught only by the full relayouts those events caused; it has its own now.
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", NamePlate_OnEvent)
	self:RegisterEvent("UNIT_FACTION", NamePlate_OnEvent)

	if (not uiParentAlphaHooked) then
		uiParentAlphaHooked = true
		hooksecurefunc(UIParent, "SetAlpha", SyncNamePlatesToUIParentAlpha)
	end

end

NP.style = style

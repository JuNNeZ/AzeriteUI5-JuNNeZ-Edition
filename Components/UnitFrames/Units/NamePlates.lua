--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

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
local _, ns = ...
local oUF = ns.oUF

local NamePlatesMod = ns:NewModule("NamePlates", "LibMoreEvents-1.0", "AceHook-3.0", "AceTimer-3.0")

-- Lua API
local math_floor = math.floor
local next = next
local select = select
local strsplit = strsplit
local string_gsub = string.gsub
local tostring = tostring
local unpack = unpack

-- Addon API
local Colors = ns.Colors

ns.ActiveNamePlates = {}
ns.NamePlates = {}

local defaults = { profile = ns:Merge({
	enabled = true,
	showAuras = true,
	showAurasOnTargetOnly = false,
	showNameAlways = false,
	showBlizzardWidgets = false,
	scale = 1,
	healthFlipLabEnabled = false,
	healthFlipLabDebugMode = false,
	healthLabOrientation = "DEFAULT",
	healthLabFlipTexX = false,
	healthLabFlipTexY = false,
	healthLabReverseFill = false,
	healthLabSetFlippedHorizontally = false,
	healthLabPreviewReverseFill = false,
	healthLabPreviewSetFlippedHorizontally = false,
	healthLabAbsorbUseOppositeOrientation = true,
	healthLabAbsorbReverseFill = false,
	healthLabAbsorbSetFlippedHorizontally = false,
	healthLabCastReverseFill = false,
	healthLabCastSetFlippedHorizontally = false
}, ns.MovableModulePrototype.defaults) }

-- Utility Functions
--------------------------------------------
-- Simplify the tagging process a little.
local prefix = function(msg)
	return string_gsub(msg, "*", ns.Prefix)
end

local IsSecretValue = function(value)
	return (type(issecretvalue) == "function" and issecretvalue(value)) and true or false
end

local IsSafeUnitToken = function(unit)
	return type(unit) == "string" and (not IsSecretValue(unit)) and unit ~= ""
end

local SafeUnitName = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil
	end
	local name = UnitName(unit)
	if (type(name) == "string" and (not IsSecretValue(name)) and name ~= "") then
		return name
	end
	return nil
end

local SafeUnitGUID = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil
	end
	return guid
end

local SafeUnitMatches = function(unit, otherUnit)
	if (not IsSafeUnitToken(unit) or not IsSafeUnitToken(otherUnit)) then
		return false
	end
	local match = UnitIsUnit(unit, otherUnit)
	if (type(match) == "boolean" and not IsSecretValue(match)) then
		return match
	end
	local guidA = SafeUnitGUID(unit)
	local guidB = SafeUnitGUID(otherUnit)
	return guidA and guidB and guidA == guidB or false
end

local GetGuidType = function(unit)
	if (type(unit) ~= "string" or IsSecretValue(unit) or unit == "") then
		return nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType and guidType ~= "") then
		return guidType
	end
	return nil
end

local GetGuidAndNpcID = function(unit)
	if (not IsSafeUnitToken(unit)) then
		return nil, nil
	end
	local guid = UnitGUID(unit)
	if (type(guid) ~= "string" or IsSecretValue(guid) or guid == "") then
		return nil, nil
	end
	local guidType = guid:match("^([^-]+)-")
	if (guidType == "Creature" or guidType == "Vehicle" or guidType == "Pet") then
		local _, _, _, _, _, npcID = strsplit("-", guid)
		return guid, npcID
	end
	return guid, nil
end

-- Hotfix exceptions from live diagnostics.
-- These are surgical guards to keep known interactable trainers visible
-- while suppressing known decorative object-like creature plates.
local AlwaysShowFriendlyNPCByID = {
	["229383"] = true -- Treni (Fishing Trainer)
}

local AlwaysHideObjectLikeNPCByID = {
	["223648"] = true, -- Betta (decorative object-like plate)
	["212708"] = true, -- Freysworn Cruton (decorative object-like plate)
	["191909"] = true  -- Tuskarr Beanbag (vehicle/object-like seat)
}

local GetOppositeOrientation = function(orientation)
	if (orientation == "UP") then
		return "DOWN"
	elseif (orientation == "DOWN") then
		return "UP"
	elseif (orientation == "LEFT") then
		return "RIGHT"
	end
	return "LEFT"
end

local IsNamePlateHealthFlipLabDebugEnabled = function()
	local globalDB = ns and ns.db and ns.db.global
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile
	if (not globalDB or not profile) then
		return false
	end
	if (not globalDB.enableDevelopmentMode) then
		return false
	end
	return profile.healthFlipLabEnabled and profile.healthFlipLabDebugMode and true or false
end

local GetNamePlateHealthLabSettings = function(db)
	local profile = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile or {}
	local enabled = IsNamePlateHealthFlipLabDebugEnabled()
	local settings = {}

	settings.mainOrientation = db.Orientation or "LEFT"
	if (enabled and profile.healthLabOrientation and profile.healthLabOrientation ~= "DEFAULT") then
		settings.mainOrientation = profile.healthLabOrientation
	end
	settings.absorbOrientation = GetOppositeOrientation(settings.mainOrientation)
	if (enabled and profile.healthLabAbsorbUseOppositeOrientation == false) then
		settings.absorbOrientation = settings.mainOrientation
	end

	local texLeft, texRight, texTop, texBottom = unpack(db.HealthBarTexCoord or { 0, 1, 0, 1 })
	if (enabled and profile.healthLabFlipTexX) then
		texLeft, texRight = texRight, texLeft
	end
	if (enabled and profile.healthLabFlipTexY) then
		texTop, texBottom = texBottom, texTop
	end
	settings.texLeft = texLeft
	settings.texRight = texRight
	settings.texTop = texTop
	settings.texBottom = texBottom

	local castTexLeft, castTexRight, castTexTop, castTexBottom = unpack(db.CastBarTexCoord or { 0, 1, 0, 1 })
	if (enabled and profile.healthLabFlipTexX) then
		castTexLeft, castTexRight = castTexRight, castTexLeft
	end
	if (enabled and profile.healthLabFlipTexY) then
		castTexTop, castTexBottom = castTexBottom, castTexTop
	end
	settings.castTexLeft = castTexLeft
	settings.castTexRight = castTexRight
	settings.castTexTop = castTexTop
	settings.castTexBottom = castTexBottom

	settings.healthReverseFill = false
	if (enabled and type(profile.healthLabReverseFill) == "boolean") then
		settings.healthReverseFill = profile.healthLabReverseFill
	end
	settings.healthSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabSetFlippedHorizontally) == "boolean") then
		settings.healthSetFlippedHorizontally = profile.healthLabSetFlippedHorizontally
	end

	settings.previewReverseFill = settings.healthReverseFill
	if (enabled and type(profile.healthLabPreviewReverseFill) == "boolean") then
		settings.previewReverseFill = profile.healthLabPreviewReverseFill
	end
	settings.previewSetFlippedHorizontally = settings.healthSetFlippedHorizontally
	if (enabled and type(profile.healthLabPreviewSetFlippedHorizontally) == "boolean") then
		settings.previewSetFlippedHorizontally = profile.healthLabPreviewSetFlippedHorizontally
	end

	settings.absorbReverseFill = false
	if (enabled and type(profile.healthLabAbsorbReverseFill) == "boolean") then
		settings.absorbReverseFill = profile.healthLabAbsorbReverseFill
	end
	settings.absorbSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabAbsorbSetFlippedHorizontally) == "boolean") then
		settings.absorbSetFlippedHorizontally = profile.healthLabAbsorbSetFlippedHorizontally
	end

	settings.castReverseFill = false
	if (enabled and type(profile.healthLabCastReverseFill) == "boolean") then
		settings.castReverseFill = profile.healthLabCastReverseFill
	end
	settings.castSetFlippedHorizontally = false
	if (enabled and type(profile.healthLabCastSetFlippedHorizontally) == "boolean") then
		settings.castSetFlippedHorizontally = profile.healthLabCastSetFlippedHorizontally
	end
	return settings
end

-- Element Callbacks
--------------------------------------------
-- Forceupdate health prediction on health updates,
-- to assure our smoothed elements are properly aligned.
local Health_PostUpdate = function(element, unit, cur, max)
	local predict = element.__owner.HealthPrediction
	if (predict) then
		predict:ForceUpdate()
	end
end

local Health_UpdateColor = function(self, event, unit)
	if(not unit or self.unit ~= unit) then return end
	local element = self.Health

	local r, g, b, color
	if (element.colorDisconnected and not UnitIsConnected(unit)) then
		color = self.colors.disconnected
	elseif (element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		color = self.colors.tapped
	elseif (element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation("player", unit)) then
		color =  self.colors.threat[UnitThreatSituation("player", unit)]
	elseif ((element.colorClass and UnitIsPlayer(unit)
		or (element.colorClassNPC and not UnitIsPlayer(unit))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)))
		and not (not self.isPRD and element.colorClassHostileOnly and not UnitCanAttack("player", unit))) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	elseif (element.colorSelection and unitSelectionType(unit, element.considerSelectionInCombatHostile)) then
		color = self.colors.selection[unitSelectionType(unit, element.considerSelectionInCombatHostile)]
	elseif (element.colorReaction and UnitReaction(unit, "player")) then
		color = self.colors.reaction[UnitReaction(unit, "player")]
	elseif (element.colorSmooth) then
		local gradient = element.smoothGradient or (self.colors and self.colors.smooth)
		if (type(gradient) == "table" and gradient[1]) then
			r, g, b = self:ColorGradient(element.cur or 1, element.max or 1, unpack(gradient))
		else
			color = self.colors and self.colors.health
		end
	elseif (element.colorHealth) then
		color = self.colors.health
	end

	if (color) then
		r, g, b = color[1], color[2], color[3]
	end

	if (b) then
		element:SetStatusBarColor(r, g, b)

		local bg = element.bg
		if (bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	--[[ Callback: Health:PostUpdateColor(unit, r, g, b)
	Called after the element color has been updated.

	* self - the Health element
	* unit - the unit for which the update has been triggered (string)
	* r    - the red component of the used color (number)[0-1]
	* g    - the green component of the used color (number)[0-1]
	* b    - the blue component of the used color (number)[0-1]
	--]]
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, r, g, b)
	end
end

-- Update the health preview color on health color updates.
local Health_PostUpdateColor = function(element, unit, r, g, b)
	local preview = element.Preview
	if (preview and g) then
		preview:SetStatusBarColor(r * .7, g * .7, b * .7)
	end
end

-- Align our custom health prediction texture
-- based on the plugin's provided values.
local HealPredict_PostUpdate = function(element, unit, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)
	if (ns.API.ShouldSkipPrediction(element, myIncomingHeal, otherIncomingHeal, absorb, healAbsorb, hasOverAbsorb, hasOverHealAbsorb, curHealth, maxHealth)) then
		return
	end

	local safeCur, safeMax = ns.API.GetSafeHealthForPrediction(element, curHealth, maxHealth)
	if (not safeCur or not safeMax) then
		ns.API.HidePrediction(element)
		return
	end
	curHealth, maxHealth = safeCur, safeMax
	myIncomingHeal = tonumber(myIncomingHeal) or 0
	otherIncomingHeal = tonumber(otherIncomingHeal) or 0
	healAbsorb = tonumber(healAbsorb) or 0

	local allIncomingHeal = myIncomingHeal + otherIncomingHeal
	local allNegativeHeals = healAbsorb
	local showPrediction, change

	if ((allIncomingHeal > 0) or (allNegativeHeals > 0)) and (maxHealth > 0) then
		local startPoint = curHealth/maxHealth

		-- Dev switch to test absorbs with normal healing
		--allIncomingHeal, allNegativeHeals = allNegativeHeals, allIncomingHeal

		-- Hide predictions if the change is very small, or if the unit is at max health.
		change = (allIncomingHeal - allNegativeHeals)/maxHealth
		if ((curHealth < maxHealth) and (change > (element.health.predictThreshold or .05))) then
			local endPoint = startPoint + change

			-- Crop heal prediction overflows
			if (endPoint > 1) then
				endPoint = 1
				change = endPoint - startPoint
			end

			-- Crop heal absorb overflows
			if (endPoint < 0) then
				endPoint = 0
				change = -startPoint
			end

			-- This shouldn't happen, but let's do it anyway.
			if (startPoint ~= endPoint) then
				showPrediction = true
			end
		end
	end

	if (showPrediction) then

		local preview = element.preview
		local growth = preview:GetGrowth()
		local _,max = preview:GetMinMaxValues()
		local value = preview:GetValue() / max
		local previewTexture = preview:GetStatusBarTexture()
		local previewWidth, previewHeight = preview:GetSize()
		local left, right, top, bottom = preview:GetTexCoord()
		local isFlipped = preview:IsFlippedHorizontally()

		if (growth == "RIGHT") then

			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMRIGHT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end

		elseif (growth == "LEFT") then
			local texValue, texChange = value, change
			local rangeH

			rangeH = right - left
			texChange = change*value
			texValue = left + value*rangeH

			if (change > 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMRIGHT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize(change*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				else
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				end
				element:SetVertexColor(0, .7, 0, .25)
				element:Show()

			elseif (change < 0) then
				element:ClearAllPoints()
				element:SetPoint("BOTTOMLEFT", previewTexture, "BOTTOMLEFT", 0, 0)
				element:SetSize((-change)*previewWidth, previewHeight)
				if (isFlipped) then
					element:SetTexCoord(texValue + texChange, texValue, top, bottom)
				else
					element:SetTexCoord(texValue, texValue + texChange, top, bottom)
				end
				element:SetVertexColor(.5, 0, 0, .75)
				element:Show()

			else
				element:Hide()
			end
		end
	else
		element:Hide()
	end

	if (element.absorbBar) then
		if (hasOverAbsorb and curHealth >= maxHealth) then
			absorb = UnitGetTotalAbsorbs(unit)
			if (absorb > maxHealth * .3) then
				absorb = maxHealth * .3
			end
			element.absorbBar:SetValue(absorb)
		end
	end

end

-- Update power bar visibility if a frame
-- is the perrsonal resource display.
-- This callback only handles elements below the health bar.
local Power_PostUpdate = function(element, unit, cur, min, max)
	local self = element.__owner

	unit = unit or self.unit
	if (not unit) then
		return
	end

	local db = ns.GetConfig("NamePlates")
	local shouldShow

	if (self.isPRD) then
		local safeCur = cur
		local safeMax = max
		if (type(safeCur) ~= "number" or (issecretvalue and issecretvalue(safeCur))) then
			safeCur = element.safeCur or element.cur
		end
		if (type(safeMax) ~= "number" or (issecretvalue and issecretvalue(safeMax))) then
			safeMax = element.safeMax or element.max
		end
		if (type(safeCur) ~= "number" or type(safeMax) ~= "number") then
			safeCur, safeMax = nil, nil
		end
		if (safeCur and safeCur == 0) and (safeMax and safeMax == 0) then
			shouldShow = nil
		else
			shouldShow = safeMax and safeMax > 0
		end
	end

	local power = self.Power

	if (shouldShow) then
		if (power.isHidden) then
			power:SetAlpha(1)
			power.isHidden = false

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPositionPlayer))
		end
	else
		if (not power.isHidden) then
			power:SetAlpha(0)
			power.isHidden = true

			local cast = self.Castbar
			cast:ClearAllPoints()
			cast:SetPoint(unpack(db.CastBarPosition))
		end
	end
end

-- Update targeting highlight outline
local TargetHighlight_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.TargetHighlight

	if (self.isFocus or self.isTarget) then
		element:SetVertexColor(unpack(self.isFocus and element.colorFocus or element.colorTarget))
		element:Show()
	elseif (self.isSoftEnemy or self.isSoftInteract) then
		element:SetVertexColor(unpack(self.isSoftEnemy and element.colorSoftEnemy or element.colorSoftInteract))
		element:Show()
	else
		element:Hide()
	end
end

-- Update NPC classification badge for rares, elites and bosses.
local Classification_Update = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local element = self.Classification
	unit = unit or self.unit

	if (UnitIsPlayer(unit) or not UnitCanAttack("player", unit)) then
		return element:Hide()
	end

	local l = UnitEffectiveLevel(unit)
	local c = (l and l < 1) and "worldboss" or UnitClassification(unit)
	if (c == "boss" or c == "worldboss") then
		element:SetTexture(element.bossTexture)
		element:Show()

	elseif (c == "elite") then
		element:SetTexture(element.eliteTexture)
		element:Show()

	elseif (c == "rare" or c == "rareelite") then
		element:SetTexture(element.rareTexture)
		element:Show()
	else
		element:Hide()
	end
end

-- Messy callback that handles positions
-- of elements above the health bar.
local NamePlate_PostUpdatePositions = function(self)
	local db = ns.GetConfig("NamePlates")

	--local aurasEnabled = self:IsElementEnabled("Auras")
	local auras = self.Auras
	local name = self.Name
	local raidTarget = self.RaidTargetIndicator

	-- The PRD has neither name nor auras.
	if (not self.isPRD) then
		local showHostileName = (self.canAttack == true) and (not self.isObjectPlate)
		local showFriendlyTargetName = self.isTarget and (self.canAttack == false) and (self.canAssist == true)
		local showFriendlyAssistName = self.isFriendlyAssistableNPC and true or false
		local hasName = NamePlatesMod.db.profile.showNameAlways or showHostileName or showFriendlyTargetName or showFriendlyAssistName or (not self.isTarget and (self.isMouseOver or self.isSoftTarget or self.inCombat)) or false
		local nameOffset = hasName and (select(2, name:GetFont()) + auras.spacing) or 0

		if (hasName ~= auras.usingNameOffset or auras.usingNameOffset == nil) then
			if (hasName) then
				local point, x, y = unpack(db.AurasPosition)
				auras:ClearAllPoints()
				auras:SetPoint(point, x, y + nameOffset)
			else
				auras:ClearAllPoints()
				auras:SetPoint(unpack(db.AurasPosition))
			end
		end

		local numAuras = 0
		if (ns.IsRetail) then
			numAuras = auras.sortedBuffs and auras.sortedDebuffs and (#auras.sortedBuffs + #auras.sortedDebuffs) or 0
		else
			numAuras = auras.visibleBuffs and auras.visibleDebuffs and (auras.visibleBuffs + auras.visibleDebuffs) or 0
		end

		local numRows = (numAuras > 0) and (math_floor(numAuras / auras.numPerRow)) or 0

		if (numRows ~= auras.numRows or hasName ~= auras.usingNameOffset or auras.usingNameOffset == nil) then
			if (hasName or numRows > 0) then
				local auraOffset = (numAuras > 0) and (numRows * (auras.size + auras.spacing)) or 0
				local point, x, y = unpack(db.RaidTargetPosition)
				raidTarget:ClearAllPoints()
				raidTarget:SetPoint(point, x, y + nameOffset + auraOffset)
			else
				raidTarget:ClearAllPoints()
				raidTarget:SetPoint(unpack(db.RaidTargetPosition))
			end
		end

		auras.numRows = numRows
		auras.usingNameOffset = hasName
	end
end

local NamePlate_PostUpdateHoverElements = function(self)
	if (self.isObjectPlate and not self.isPRD) then
		if (self.Name) then
			self.Name:Hide()
		end
		if (self.Health and self.Health.Value) then
			self.Health.Value:Hide()
		end
		return
	end

	if (self.isPRD) then
		self.Health.Value:Hide()
		self.Name:Hide()
	else
		local showHostileName = (self.canAttack == true) and (not self.isObjectPlate)
		local showNameAlways = NamePlatesMod.db.profile.showNameAlways
		local showFriendlyTargetName = self.isTarget and (self.canAttack == false) and (self.canAssist == true)
		local showFriendlyAssistName = self.isFriendlyAssistableNPC and true or false

		-- Force tag update to ensure name is always current
		-- This is critical for dungeons where events may not fire reliably
		if (self.Name and self.Name.UpdateTag) then
			pcall(self.Name.UpdateTag, self.Name)
		end

		-- Fallback: if the tag returned empty (secret value filtered out),
		-- try setting the name directly via SetText which handles secrets.
		-- GetText() returns a secret if the fontstring has a secret text aspect,
		-- so we must use issecretvalue() before comparing with == to avoid errors.
		if (self.Name and self.unit) then
			local nameText = self.Name:GetText()
			local nameIsEmpty = (type(nameText) ~= "string") or (not issecretvalue(nameText) and nameText == "")
			if (nameIsEmpty) then
				local rawName = UnitName(self.unit)
				if (type(rawName) == "string") then
					self.Name:SetText(rawName)
				end
			end
		end

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat or showHostileName) then
			if (self.isTarget) then
				self.Health.Value:Hide()
				if (showNameAlways or showHostileName or showFriendlyTargetName or showFriendlyAssistName) then
					self.Name:Show()
				else
					self.Name:Hide()
				end
			else
				local castbar = self.Castbar
				if (castbar.casting or castbar.channeling or castbar.empowering) then
					self.Health.Value:Hide()
				else
					self.Health.Value:Show()
				end
				self.Name:Show()
			end
		else
			-- Always show names for hostile units, even when not mousing over
			-- This ensures dungeon enemies show their names
			if (showNameAlways or showHostileName or showFriendlyAssistName or (self.canAttack == true)) then
				self.Name:Show()
			else
				self.Name:Hide()
			end
			if (showHostileName and self.Castbar and not (self.Castbar.casting or self.Castbar.channeling or self.Castbar.empowering)) then
				self.Health.Value:Show()
			else
				self.Health.Value:Hide()
			end
		end
	end
end

-- Element proxy for the position updater above.
local Auras_PostUpdate = function(element, unit)
	NamePlate_PostUpdatePositions(element.__owner)
end

local Castbar_PostUpdate = function(element, unit)
	local db = ns.GetConfig("NamePlates")
	local notInterruptible = element.notInterruptible
	if (issecretvalue and issecretvalue(notInterruptible)) then
		notInterruptible = false
	end

	local r, g, b = unpack(notInterruptible and Colors.title or db.CastBarNameColor)
	element.Text:SetTextColor(r, g, b, 1)

	local r, g, b, a = unpack(element.__owner.isPRD and db.HealthCastOverlayColor or notInterruptible and Colors.tapped or db.CastBarColor)
	element:SetStatusBarColor(r, g, b, a or 1)

	NamePlate_PostUpdateHoverElements(element.__owner)
end

-- Callback that handles positions of elements
-- that change position within their frame.
-- Called on full updates and settings changes.
local NamePlate_PostUpdateElements = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)

	if (self.isObjectPlate and not self.isPRD) then
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end
		self:SetIgnoreParentAlpha(false)
		self:SetAlpha(0)
		if (self.Name) then self.Name:Hide() end
		if (self.Health) then
			self.Health:Hide()
			if (self.Health.Backdrop) then
				self.Health.Backdrop:Hide()
			end
		end
		if (self.Health and self.Health.Value) then self.Health.Value:Hide() end
		if (self.Classification) then
			self.Classification:Hide()
		end
		if (self.TargetHighlight) then
			self.TargetHighlight:Hide()
		end
		if (self.RaidTargetIndicator) then
			self.RaidTargetIndicator:Hide()
		end
		if (self.Castbar) then
			self.Castbar:Hide()
			if (self.Castbar.Backdrop) then
				self.Castbar.Backdrop:Hide()
			end
		end
		return
	end

	if (self:GetAlpha() == 0) then
		self:SetAlpha(1)
	end
	if (self.Health and not self.Health:IsShown()) then
		self.Health:Show()
		if (self.Health.Backdrop) then
			self.Health.Backdrop:Show()
		end
	end
	if (self.Castbar and not self.Castbar:IsShown()) then
		self.Castbar:Show()
	end
	local mainOrientation = healthLab.mainOrientation
	local absorbOrientation = healthLab.absorbOrientation
	if (self.isPRD) then
		mainOrientation, absorbOrientation = absorbOrientation, mainOrientation
	end

	self.Health:SetOrientation(mainOrientation)
	self.Health:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	self.Health:SetReverseFill(healthLab.healthReverseFill)
	self.Health:SetFlippedHorizontally(healthLab.healthSetFlippedHorizontally)
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	self.Health.__AzeriteUI_DebugFlipLabEnabled = IsNamePlateHealthFlipLabDebugEnabled()
	self.Health.__AzeriteUI_FakeTexWidth = nil
	self.Health.__AzeriteUI_FakeTexHeight = nil
	self.Health.__AzeriteUI_FakeReverse = nil
	do
		local nativeTexture = self.Health:GetStatusBarTexture()
		if (nativeTexture and nativeTexture.SetAlpha) then
			nativeTexture:SetAlpha(1)
		end
		if (nativeTexture and nativeTexture.Show) then
			nativeTexture:Show()
		end
	end
	if (self.Health.Display) then
		self.Health.Display:SetAlpha(0)
		self.Health.Display:Hide()
	end
	if (self.Health.Preview) then
		self.Health.Preview:SetOrientation(mainOrientation)
		self.Health.Preview:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		self.Health.Preview:SetReverseFill(healthLab.previewReverseFill)
		self.Health.Preview:SetFlippedHorizontally(healthLab.previewSetFlippedHorizontally)
	end
	if (self.HealthPrediction and self.HealthPrediction.absorbBar) then
		self.HealthPrediction.absorbBar:SetOrientation(absorbOrientation)
		self.HealthPrediction.absorbBar:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		if (self.HealthPrediction.absorbBar.SetReverseFill) then
			self.HealthPrediction.absorbBar:SetReverseFill(healthLab.absorbReverseFill)
		end
		self.HealthPrediction.absorbBar:SetFlippedHorizontally(healthLab.absorbSetFlippedHorizontally)
	end
	self.Castbar:SetOrientation(mainOrientation)
	self.Castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
	if (self.Castbar.SetReverseFill) then
		self.Castbar:SetReverseFill(healthLab.castReverseFill)
	end
	self.Castbar:SetFlippedHorizontally(healthLab.castSetFlippedHorizontally)

	if (self.isPRD) then
		self:SetIgnoreParentAlpha(false)
		if (self:IsElementEnabled("Auras")) then
			self:DisableElement("Auras")
		end

		self.Castbar:SetSize(unpack(db.HealthBarSize))
		self.Castbar:ClearAllPoints()
		self.Castbar:SetAllPoints(self.Health)
		self.Castbar:SetSparkMap(db.HealthBarSparkMap)
		self.Castbar:SetStatusBarTexture(db.HealthBarTexture)
		self.Castbar:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		self.Castbar.Backdrop:Hide()
		self.Castbar.Text:ClearAllPoints()
		self.Castbar.Text:SetPoint(unpack(db.CastBarNamePositionPlayer))

	else

		if (NamePlatesMod.db.profile.showAuras and (not NamePlatesMod.db.profile.showAurasOnTargetOnly or self.isTarget)) then
			if (not self:IsElementEnabled("Auras")) then
				self:EnableElement("Auras")
				if (self.Auras.ForceUpdate) then
					self.Auras:ForceUpdate()
				end
			end
		else
			if (self:IsElementEnabled("Auras")) then
				self:DisableElement("Auras")
			end
		end

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				self.WidgetContainer:SetIgnoreParentAlpha(true)
				self.WidgetContainer:SetParent(self)
				self.WidgetContainer:ClearAllPoints()
				self.WidgetContainer:SetPoint(unpack(db.WidgetPosition))

				local widgetFrames = self.WidgetContainer.widgetFrames

				if (widgetFrames) then
					for _, frame in next, widgetFrames do
						if (frame.Label) then
							frame.Label:SetAlpha(0)
						end
					end
				end
			else
				self.WidgetContainer:SetParent(ns.Hider)
			end
		end

		if (self.isMouseOver or self.isTarget or self.isSoftTarget or self.inCombat) then
			-- SetIgnoreParentAlpha requires explicit true/false, or it'll bug out.
			self:SetIgnoreParentAlpha(((self.isMouseOver or self.isSoftTarget) and not self.isTarget) and true or false)
		else
			self:SetIgnoreParentAlpha(false)
		end

		self.Castbar:SetSize(unpack(db.CastBarSize))
		self.Castbar:ClearAllPoints()
		self.Castbar:SetPoint(unpack(db.CastBarPosition))
		self.Castbar:SetSparkMap(db.CastBarSparkMap)
		self.Castbar:SetStatusBarTexture(db.CastBarTexture)
		self.Castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
		self.Castbar.Backdrop:Show()
		self.Castbar.Text:ClearAllPoints()
		self.Castbar.Text:SetPoint(unpack(db.CastBarNamePosition))
	end

	Castbar_PostUpdate(self.Castbar)
	NamePlate_PostUpdatePositions(self)
end

-- This is called on UpdateAllElements,
-- which is called when a frame is shown or its unit changed.
local NamePlate_PostUpdate = function(self, event, unit, ...)
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit

	self.inCombat = InCombatLockdown()
	
	self.isFocus = SafeUnitMatches(unit, "focus")
	self.isTarget = SafeUnitMatches(unit, "target")
	self.isSoftEnemy = SafeUnitMatches(unit, "softenemy")
	self.isSoftInteract = SafeUnitMatches(unit, "softinteract")
	self.nameplateShowsWidgetsOnly = ns.IsRetail and UnitNameplateShowsWidgetsOnly(unit)
	local canAttack = UnitCanAttack("player", unit)
	local canAssist = UnitCanAssist("player", unit)
	local isPlayerUnit = UnitIsPlayer(unit)
	local playerControlled = UnitPlayerControlled(unit)
	local isTrivial = UnitIsTrivial(unit)
	local classification = UnitClassification(unit)
	local creatureType = UnitCreatureType(unit)
	local reaction = UnitReaction("player", unit)
	local guidType = GetGuidType(unit)
	local _, npcID = GetGuidAndNpcID(unit)
	if (issecretvalue and issecretvalue(canAttack)) then
		canAttack = nil
	end
	if (issecretvalue and issecretvalue(canAssist)) then
		canAssist = nil
	end
	if (issecretvalue and issecretvalue(isPlayerUnit)) then
		isPlayerUnit = false
	end
	if (issecretvalue and issecretvalue(playerControlled)) then
		playerControlled = false
	end
	if (issecretvalue and issecretvalue(isTrivial)) then
		isTrivial = false
	end
	if (issecretvalue and issecretvalue(classification)) then
		classification = nil
	end
	if (issecretvalue and issecretvalue(creatureType)) then
		creatureType = nil
	end
	if (issecretvalue and issecretvalue(reaction)) then
		reaction = nil
	end

	-- When canAttack/canAssist are secret (nil after guard), use UnitReaction as fallback.
	-- UnitReaction: 1=Hated..4=Neutral..8=Exalted; <= 4 means hostile/unfriendly.
	if (canAttack == nil and canAssist == nil and type(reaction) == "number") then
		if (reaction <= 4) then
			canAttack = true
		elseif (reaction >= 5) then
			canAssist = true
		end
	end

	self.canAttack = (canAttack == true)
	self.canAssist = (canAssist == true)

	local guidLooksLikeObject = (guidType == "GameObject") or (guidType == "AreaTrigger")
	local passiveWorldObjectLike = ((canAttack == false) and (canAssist == false) and (not isPlayerUnit) and (not playerControlled))
	local isCompanionLikeGuidType = (guidType == "Pet") or (guidType == "Creature") or (guidType == "Vehicle")
	local forceShowFriendlyNPC = (type(npcID) == "string") and AlwaysShowFriendlyNPCByID[npcID] and true or false
	local forceHideObjectLikeNPC = (type(npcID) == "string") and AlwaysHideObjectLikeNPCByID[npcID] and true or false
	local suppressObjectLikeNPCByID = forceHideObjectLikeNPC and (not forceShowFriendlyNPC) and true or false
	self.isObjectPlate = (guidLooksLikeObject or suppressObjectLikeNPCByID or (self.nameplateShowsWidgetsOnly and passiveWorldObjectLike and (not isCompanionLikeGuidType)) or (passiveWorldObjectLike and guidType == nil)) and true or nil
	self.isFriendlyAssistableNPC = (not self.isObjectPlate) and (not isPlayerUnit) and (canAttack ~= true) and ((canAssist == true) or forceShowFriendlyNPC) and (not playerControlled)

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)
	local main, reverse = healthLab.mainOrientation, healthLab.absorbOrientation
	-- Fallback to safe defaults to avoid nil orientations crashing SetOrientation
	if (not main) then main = "LEFT" end
	if (not reverse) then
		reverse = (main == "LEFT") and "RIGHT" or "LEFT"
	end

	if (self.isPRD) then
		main, reverse = reverse, main
		self:DisableElement("RaidTargetIndicator")
	else
		if (self.nameplateShowsWidgetsOnly or self.isObjectPlate) then
			self:DisableElement("RaidTargetIndicator")
			if (self.RaidTargetIndicator) then
				self.RaidTargetIndicator:Hide()
			end
		else
			self:EnableElement("RaidTargetIndicator")
			self.RaidTargetIndicator:ForceUpdate()
		end
	end

	self.Castbar:SetOrientation(main)
	self.Health:SetOrientation(main)
	self.Health.Preview:SetOrientation(main)
	if (self.HealthPrediction.absorbBar) then self.HealthPrediction.absorbBar:SetOrientation(reverse) end

	Classification_Update(self, event, unit, ...)
	TargetHighlight_Update(self, event, unit, ...)
	NamePlate_PostUpdateElements(self, event, unit, ...)
end

local SoftNamePlate_OnEnter = function(self, ...)
	self.isSoftTarget = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
end

local SoftNamePlate_OnLeave = function(self, ...)
	self.isSoftTarget = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
end

local NamePlate_OnEnter = function(self, ...)
	self.isMouseOver = true
	if (self.OnEnter) then
		self:OnEnter(...)
	end
end

local NamePlate_OnLeave = function(self, ...)
	self.isMouseOver = nil
	if (self.OnLeave) then
		self:OnLeave(...)
	end
end

local NamePlate_OnHide = function(self)
	self.inCombat = nil
	self.isFocus = nil
	self.isTarget = nil
	self.isSoftEnemy = nil
	self.isSoftInteract = nil
	self.canAttack = nil
	self.canAssist = nil
	self.isObjectPlate = nil
	self.isFriendlyAssistableNPC = nil
	self.nameplateShowsWidgetsOnly = nil

	if (self.RaidTargetIndicator) then
		self.RaidTargetIndicator:Hide()
	end
	if (self.Name) then
		self.Name:SetText("")
		self.Name:Hide()
	end
end

local NamePlate_OnEvent = function(self, event, unit, ...)
	-- WoW 12 secret-value safety: unit can be secret in some events
	if (issecretvalue(unit)) then
		unit = nil -- Fall back to self.unit
	end
	
	if (unit and unit ~= self.unit) then return end

	unit = unit or self.unit

	if (event == "PLAYER_REGEN_DISABLED") then
		self.inCombat = true

		NamePlate_PostUpdateElements(self, event, unit, ...)

		return

	elseif (event == "PLAYER_REGEN_ENABLED") then
		self.inCombat = nil

		NamePlate_PostUpdateElements(self, event, unit, ...)

		return

	elseif (event == "PLAYER_TARGET_CHANGED") then
		self.isTarget = SafeUnitMatches(unit, "target")

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_SOFT_ENEMY_CHANGED") then
		self.isSoftEnemy = SafeUnitMatches(unit, "softenemy")

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_SOFT_INTERACT_CHANGED") then
		self.isSoftInteract = SafeUnitMatches(unit, "softinteract")

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	elseif (event == "PLAYER_FOCUS_CHANGED") then
		self.isFocus = SafeUnitMatches(unit, "focus")

		Classification_Update(self, event, unit, ...)
		TargetHighlight_Update(self, event, unit, ...)
		NamePlate_PostUpdateElements(self, event, unit, ...)

		return
	end

	NamePlate_PostUpdate(self, event, unit, ...)
end

local NamePlate_RaidTargetIndicator_Override = function(self, event, unit)
	local element = self.RaidTargetIndicator
	if (not element) then
		return
	end

	unit = unit or self.unit
	if (not unit) or ((type(issecretvalue) == "function") and issecretvalue(unit)) or (not UnitExists(unit)) then
		element:Hide()
		return
	end

	if (ns.IsRetail and UnitNameplateShowsWidgetsOnly(unit)) then
		element:Hide()
		return
	end

	if ((not UnitIsPlayer(unit)) and (not UnitCanAttack("player", unit))) then
		element:Hide()
		return
	end

	local index = GetRaidTargetIndex(unit)
	if (index) and (not ((type(issecretvalue) == "function") and issecretvalue(index))) then
		SetRaidTargetIconTexture(element, index)
		element:Show()
	else
		element:Hide()
	end
end

local style = function(self, unit, id)

	local db = ns.GetConfig("NamePlates")
	local healthLab = GetNamePlateHealthLabSettings(db)
	local profileScale = NamePlatesMod and NamePlatesMod.db and NamePlatesMod.db.profile and NamePlatesMod.db.profile.scale or 1
	if (type(profileScale) ~= "number") then
		profileScale = 1
	end

	self.colors = ns.Colors

	self:SetPoint("CENTER",0,0)
	self:SetSize(unpack(db.Size))
	self:SetScale(ns.API.GetScale() * profileScale)
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
	health:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	health:SetOrientation(healthLab.mainOrientation)
	health:SetReverseFill(healthLab.healthReverseFill)
	health:SetFlippedHorizontally(healthLab.healthSetFlippedHorizontally)
	health:SetSparkMap(db.HealthBarSparkMap)
	health.predictThreshold = .01
	health.colorDisconnected = true
	health.colorTapping = true
	health.colorThreat = true
	health.colorClass = true
	health.colorClassPet = true
	health.colorClassHostileOnly = true
	health.colorHappiness = true
	health.colorReaction = true

	self.Health = health
	self.Health.Override = ns.API.UpdateHealth
	self.Health.PostUpdate = Health_PostUpdate
	self.Health.UpdateColor = Health_UpdateColor
	self.Health.PostUpdateColor = Health_PostUpdateColor
	self.Health.__AzeriteUI_UseProductionNativeFill = true
	self.Health.__AzeriteUI_DebugFlipLabEnabled = IsNamePlateHealthFlipLabDebugEnabled()
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
	healthPreview:SetAlpha(.5)
	healthPreview:DisableSmoothing(true)
	healthPreview:SetOrientation(healthLab.mainOrientation)
	healthPreview:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
	healthPreview:SetReverseFill(healthLab.previewReverseFill)
	healthPreview:SetFlippedHorizontally(healthLab.previewSetFlippedHorizontally)

	self.Health.Preview = healthPreview

	-- Health Prediction
	--------------------------------------------
	local healPredictFrame = CreateFrame("Frame", nil, health)
	healPredictFrame:SetFrameLevel(health:GetFrameLevel() + 2)

	local healPredict = healPredictFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	healPredict:SetTexture(db.HealthBarTexture)
	healPredict.health = health
	healPredict.preview = healthPreview
	healPredict.maxOverflow = 1

	self.HealthPrediction = healPredict
	self.HealthPrediction.PostUpdate = HealPredict_PostUpdate

	-- Castbar
	--------------------------------------------
	local castbar = self:CreateBar()
	if (castbar.SetForceNative) then castbar:SetForceNative(true) end
	castbar:SetFrameLevel(self:GetFrameLevel() + 5)
	castbar:SetSize(unpack(db.CastBarSize))
	castbar:SetPoint(unpack(db.CastBarPosition))
	castbar:SetSparkMap(db.CastBarSparkMap)
	castbar:SetStatusBarTexture(db.CastBarTexture)
	castbar:SetStatusBarColor(unpack(db.CastBarColor))
	castbar:SetTexCoord(healthLab.castTexLeft, healthLab.castTexRight, healthLab.castTexTop, healthLab.castTexBottom)
	castbar:SetOrientation(healthLab.mainOrientation)
	if (castbar.SetReverseFill) then
		castbar:SetReverseFill(healthLab.castReverseFill)
	end
	castbar:SetFlippedHorizontally(healthLab.castSetFlippedHorizontally)
	castbar:DisableSmoothing(true)
	castbar.timeToHold = db.CastBarTimeToHoldFailed

	self.Castbar = castbar
	self.Castbar.PostCastStart = Castbar_PostUpdate
	self.Castbar.PostCastUpdate = Castbar_PostUpdate
	self.Castbar.PostCastStop = Castbar_PostUpdate
	self.Castbar.PostCastInterruptible = Castbar_PostUpdate

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

	self.Castbar.Text = castText

	-- Health Value
	--------------------------------------------
	local healthValue = healthOverlay:CreateFontString(nil, "OVERLAY", nil, 1)
	healthValue:SetPoint(unpack(db.HealthValuePosition))
	healthValue:SetFontObject(db.HealthValueFont)
	healthValue:SetTextColor(unpack(db.HealthValueColor))
	healthValue:SetJustifyH(db.HealthValueJustifyH)
	healthValue:SetJustifyV(db.HealthValueJustifyV)
	self:Tag(healthValue, prefix("[*:HealthCurrent]"))

	self.Health.Value = healthValue

	-- Health Percentage (disabled for nameplates)

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
	--self:Tag(name, prefix("[*:Name(32,nil,nil,true)]"))
	self:Tag(name, prefix("[*:Name(24,nil,nil,nil)]")) -- maxChars, showLevel, showLevelLast, showFull

	self.Name = name

	-- Absorb Bar
	--------------------------------------------
	if (ns.IsRetail) then
		local absorb = self:CreateBar()
		if (absorb.SetForceNative) then absorb:SetForceNative(true) end
		absorb:SetAllPoints(health)
		absorb:SetFrameLevel(health:GetFrameLevel() + 3)
		absorb:SetStatusBarTexture(db.HealthBarTexture)
		absorb:SetStatusBarColor(unpack(db.HealthAbsorbColor))
		absorb:SetTexCoord(healthLab.texLeft, healthLab.texRight, healthLab.texTop, healthLab.texBottom)
		absorb:SetSparkMap(db.HealthBarSparkMap)
		absorb:SetOrientation(healthLab.absorbOrientation)
		if (absorb.SetReverseFill) then
			absorb:SetReverseFill(healthLab.absorbReverseFill)
		end
		absorb:SetFlippedHorizontally(healthLab.absorbSetFlippedHorizontally)

		self.HealthPrediction.absorbBar = absorb
	end

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
	raidTarget:SetSize(unpack(db.RaidTargetSize))
	raidTarget:SetPoint(unpack(db.RaidTargetPosition))
	raidTarget:SetTexture(db.RaidTargetTexture)
	raidTarget.Override = NamePlate_RaidTargetIndicator_Override

	self.RaidTargetIndicator = raidTarget

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
	auras.numPerRow = db.AurasNumPerRow -- for our raid target indicator callback
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
	auras.CustomFilter = ns.AuraFilters.NameplateAuraFilter -- classic
	auras.FilterAura = ns.AuraFilters.NameplateAuraFilter -- retail
	auras.CreateButton = ns.AuraStyles.CreateSmallButton
	auras.PostUpdateButton = ns.AuraStyles.NameplatePostUpdateButton

	if (ns:GetModule("UnitFrames").db.global.disableAuraSorting) then
		auras.PreSetPosition = ns.AuraSorts.Alternate -- only in classic
		auras.SortAuras = ns.AuraSorts.AlternateFuncton -- only in retail
	else
		auras.PreSetPosition = ns.AuraSorts.Default -- only in classic
		auras.SortAuras = ns.AuraSorts.DefaultFunction -- only in retail
	end

	self.Auras = auras
	self.Auras.PostUpdate = Auras_PostUpdate

	self.PostUpdate = NamePlate_PostUpdate
	self.OnEnter = NamePlate_PostUpdateElements
	self.OnLeave = NamePlate_PostUpdateElements
	--self.OnHide = NamePlate_OnHide

	-- Register events to handle additional texture updates.
	self:RegisterEvent("PLAYER_ENTERING_WORLD", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", NamePlate_OnEvent, true)
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", NamePlate_OnEvent)
	self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED", NamePlate_OnEvent, true)
	self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", NamePlate_OnEvent, true)

	-- Make our nameplates obey UIParent alpha and fade out when Immersion says so.
	hooksecurefunc(UIParent, "SetAlpha", function() self:SetAlpha(UIParent:GetAlpha()) end)

end

local cvars = {
	-- If these are enabled the GameTooltip will become protected,
	-- and all sort of taints and bugs will occur.
	-- This happens on specs that can dispel when hovering over nameplate auras.
	-- We create our own auras anyway, so we don't need these.
	["nameplateShowDebuffsOnFriendly"] = 0,
	["nameplateResourceOnTarget"] = 0, -- Don't show this crap.

	["nameplateLargeTopInset"] = .1, -- default .1, diabolic .15
	["nameplateOtherTopInset"] = .1, -- default .08, diabolic .15
	["nameplateLargeBottomInset"] = .04, -- default .15, diabolic .15
	["nameplateOtherBottomInset"] = .04, -- default .1, diabolic .15
	["nameplateClassResourceTopInset"] = 0,
	["nameplateOtherAtBase"] = 0, -- Show nameplates above heads or at the base (0 or 2)

	-- new CVar July 14th 2020. Wohoo! Thanks torhaala for telling me! :)
	-- *has no effect in retail. probably for the classics only.
	["clampTargetNameplateToScreen"] = 1,

	-- Nameplate scale
	["nameplateGlobalScale"] = 1.1,
	["nameplateLargerScale"] = 1,
	["NamePlateHorizontalScale"] = 1,
	["NamePlateVerticalScale"] = 1,

	-- The max distance to show nameplates.
	-- *this value can be set by the user, and all other values are relative to this one.
	["nameplateMaxDistance"] = ns.IsRetail and 60 or ns.IsClassic and 20 or 41, -- Wrath and TBC have 41

	-- The maximum distance from the camera (not char) where plates will still have max scale
	["nameplateMaxScaleDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum scale.
	["nameplateMinScaleDistance"] = 5,

	["nameplateMaxScale"] = 1, -- The max scale of nameplates.
	["nameplateMinScale"] = .6, -- The minimum scale of nameplates.
	["nameplateSelectedScale"] = 1.1, -- Scale of targeted nameplate

	-- The distance from the camera that nameplates will reach their maximum alpha.
	["nameplateMaxAlphaDistance"] = 10,

	-- The distance from the max distance that nameplates will reach their minimum alpha.
	["nameplateMinAlphaDistance"] = 5,

	["nameplateMaxAlpha"] = 1, -- The max alpha of nameplates.
	["nameplateMinAlpha"] = .4, -- The minimum alpha of nameplates.
	["nameplateOccludedAlphaMult"] = .15, -- Alpha multiplier of hidden plates
	["nameplateSelectedAlpha"] = 1, -- Alpha multiplier of targeted nameplate

	-- The max distance to show the target nameplate when the target is behind the camera.
	["nameplateTargetBehindMaxDistance"] = 15, -- 15

}

local callback = function(self, event, unit)
	if (event == "PLAYER_TARGET_CHANGED") then
	elseif (event == "NAME_PLATE_UNIT_ADDED") then

		-- Debug helper: Uncomment to see unit properties for debugging
		-- This will help identify properties of units like the Tuskarr Beanbag
		--[[
		local unitName = UnitName(unit)
		if (unitName and string.find(unitName, "Beanbag")) then
			print("DEBUG: " .. unitName)
			print("  CreatureType:", UnitCreatureType(unit) or "nil")
			print("  IsPlayer:", UnitIsPlayer(unit))
			print("  PlayerControlled:", UnitPlayerControlled(unit))
			print("  CanAttack:", UnitCanAttack("player", unit))
			print("  CanAssist:", UnitCanAssist("player", unit))
			print("  FactionGroup:", UnitFactionGroup(unit) or "nil")
			print("  Classification:", UnitClassification(unit) or "nil")
			print("  GUID:", UnitGUID(unit) or "nil")
		end
		--]]

		self.isPRD = UnitIsUnit(unit, "player")

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				local db = ns.GetConfig("NamePlates")

				self.WidgetContainer:SetIgnoreParentAlpha(true)
				self.WidgetContainer:SetParent(self)
				self.WidgetContainer:ClearAllPoints()
				self.WidgetContainer:SetPoint(unpack(db.WidgetPosition))

				local widgetFrames = self.WidgetContainer.widgetFrames

				if (widgetFrames) then
					for _, frame in next, widgetFrames do
						if (frame.Label) then
							frame.Label:SetAlpha(0)
						end
					end
				end
			else
				self.WidgetContainer:SetParent(ns.Hider)
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(true)
			self.SoftTargetFrame:SetParent(self)
			self.SoftTargetFrame:ClearAllPoints()
			self.SoftTargetFrame:SetPoint("BOTTOM", self.Name, "TOP", 0, 0)
		end

		ns.NamePlates[self] = true
		ns.ActiveNamePlates[self] = true

		if (C_Timer and C_Timer.After) then
			C_Timer.After(0, function()
				if (self and self.unit == unit) then
					NamePlate_PostUpdate(self, "NAME_PLATE_UNIT_ADDED", unit)
				end
			end)
		else
			NamePlate_PostUpdate(self, "NAME_PLATE_UNIT_ADDED", unit)
		end

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then

		if (self.WidgetContainer) then
			if (NamePlatesMod.db.profile.showBlizzardWidgets) then
				self.WidgetContainer:SetIgnoreParentAlpha(false)
				if (self.blizzPlate) then
					self.WidgetContainer:SetParent(self.blizzPlate)
					self.WidgetContainer:ClearAllPoints()
				end
			end
		end

		if (self.SoftTargetFrame) then
			self.SoftTargetFrame:SetIgnoreParentAlpha(false)
			if (self.blizzPlate) then
				self.SoftTargetFrame:SetParent(self.blizzPlate)
				self.SoftTargetFrame:ClearAllPoints()
				if (self.blizzPlate.name) then
					self.SoftTargetFrame:SetPoint("BOTTOM", self.blizzPlate.name, "TOP", 0, -8)
				end
			end
		end

		self.isPRD = nil
		self.inCombat = nil
		self.isFocus = nil
		self.isTarget = nil
		self.isSoftEnemy = nil
		self.isSoftInteract = nil
		self.isObjectPlate = nil
		self.nameplateShowsWidgetsOnly = nil

		if (self.RaidTargetIndicator) then
			self.RaidTargetIndicator:Hide()
		end
		if (self.Name) then
			self.Name:SetText("")
			self.Name:Hide()
		end

		ns.ActiveNamePlates[self] = nil
	end
end

local MOUSEOVER
local checkMouseOver = function()
	if (UnitExists("mouseover")) then
		if (MOUSEOVER) then
			if (UnitIsUnit(MOUSEOVER.unit, "mouseover")) then
				return
			end
			NamePlate_OnLeave(MOUSEOVER)
			MOUSEOVER = nil
		end
		for frame in next,ns.ActiveNamePlates do
			if (UnitIsUnit(frame.unit, "mouseover")) then
				MOUSEOVER = frame
				return NamePlate_OnEnter(MOUSEOVER)
			end
		end
	elseif (MOUSEOVER) then
		NamePlate_OnLeave(MOUSEOVER)
		MOUSEOVER = nil
	end
end

local SOFTTARGET
local checkSoftTarget = function()
	if (UnitExists("softenemy") or UnitExists("softinteract")) then
		if (SOFTTARGET) then
			local EnemyDead = true
			if (UnitIsDead("softenemy")) then
				EnemyDead = true
			end
			if ((UnitIsUnit(SOFTTARGET.unit, "softenemy") and not EnemyDead) or UnitIsUnit(SOFTTARGET.unit, "softinteract")) then
				return
			end
			SoftNamePlate_OnLeave(SOFTTARGET)
			SOFTTARGET = nil
		end
		for frame in next,ns.ActiveNamePlates do
			local EnemyDead = false
			if (UnitIsDead("softenemy")) then
				EnemyDead = true
			end
			if ((UnitIsUnit(frame.unit, "softenemy") and not EnemyDead) or UnitIsUnit(frame.unit, "softinteract")) then
				SOFTTARGET = frame
				return SoftNamePlate_OnEnter(SOFTTARGET)
			end
		end
	elseif (SOFTTARGET) then
		SoftNamePlate_OnLeave(SOFTTARGET)
		SOFTTARGET = nil
	end
end

NamePlatesMod.CheckForConflicts = function(self)
	for i,addon in next,{
		"BetterBlizzPlates",
		"ClassicPlatesPlus",
		"Kui_Nameplates",
		"NamePlateKAI",
		"Nameplates",
		"NDui",
		"NeatPlates",
		"Plater",
		"SimplePlates",
		"TidyPlates",
		"TidyPlates_ThreatPlates",
		"TidyPlatesContinued" } do
		if (ns.API.IsAddOnEnabled(addon)) then
			return true
		end
	end
end

NamePlatesMod.HookNamePlates = function(self)
	-- WoW 12+: keep invasive reparent logic disabled, but still apply light
	-- per-instance guards to Blizzard nameplate frames.
	local secretMode = issecretvalue and true or false

	local hiddenParent = self.hiddenBlizzardNamePlateParent
	if (not hiddenParent) then
		hiddenParent = CreateFrame("Frame", nil, UIParent)
		hiddenParent:Hide()
		self.hiddenBlizzardNamePlateParent = hiddenParent
	end

	local hookedBlizzardUFs = self.hookedBlizzardNamePlateUFs
	if (not hookedBlizzardUFs) then
		hookedBlizzardUFs = {}
		self.hookedBlizzardNamePlateUFs = hookedBlizzardUFs
	end

	local modifiedBlizzardUFs = self.modifiedBlizzardNamePlateUFs
	if (not modifiedBlizzardUFs) then
		modifiedBlizzardUFs = {}
		self.modifiedBlizzardNamePlateUFs = modifiedBlizzardUFs
	end

	local issecurefunc = issecure or function() return false end

	local reparentKeys = {
		"HealthBarsContainer",
		"castBar",
		"CastBar",
		"RaidTargetFrame",
		"ClassificationFrame",
		"PlayerLevelDiffFrame",
		"SoftTargetFrame",
		"name",
		"aggroHighlight",
		"aggroHighlightBase",
		"aggroHighlightAdditive"
	}

	local function DisableBlizzardNamePlate(unit)
		if (true) then
			return
		end
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then
			return
		end
		local nameplate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not nameplate or not nameplate.UnitFrame) then
			return
		end
		local UF = nameplate.UnitFrame
		if (UF:IsForbidden()) then
			return
		end

		modifiedBlizzardUFs[unit] = UF

		UF:UnregisterAllEvents()
		if (UF.SetAlpha) then
			UF:SetAlpha(0)
		end
		if (UF.castBar and UF.castBar.UnregisterAllEvents) then
			UF.castBar:UnregisterAllEvents()
		end

		local auraFrame = UF.AurasFrame
		if (auraFrame) then
			if (auraFrame.UnregisterAllEvents) then
				auraFrame:UnregisterAllEvents()
			end
			if (auraFrame.DebuffListFrame) then
				auraFrame.DebuffListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.BuffListFrame) then
				auraFrame.BuffListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.CrowdControlListFrame) then
				auraFrame.CrowdControlListFrame:SetParent(hiddenParent)
			end
			if (auraFrame.LossOfControlFrame) then
				auraFrame.LossOfControlFrame:SetParent(hiddenParent)
			end
		end

		for _, key in ipairs(reparentKeys) do
			local frame = UF[key]
			if (frame and frame.SetParent) then
				frame:SetParent(hiddenParent)
			end
		end

		local bar = UF.castBar or UF.CastBar or UF.castbar or UF.Castbar or UF.CastingBarFrame
		if (bar) then
			bar.highlightWhenCastTarget = false
			bar.isHighlightedCastTarget = false
			if (bar.CastTargetIndicator) then
				bar.CastTargetIndicator:Hide()
			end
			bar.SetIsHighlightedCastTarget = ns.Noop
			bar.UpdateHighlightWhenCastTarget = ns.Noop
			bar.SetHighlightWhenCastTarget = ns.Noop
		end

		if (not hookedBlizzardUFs[UF]) then
			hookedBlizzardUFs[UF] = true
			local locked = false
			hooksecurefunc(UF, "SetAlpha", function(frame)
				if (locked or frame:IsForbidden()) then
					return
				end
				locked = true
				frame:SetAlpha(0)
				locked = false
			end)
		end
	end

	local function RestoreBlizzardNamePlate(unit)
		if (true) then
			return
		end
		local UF = modifiedBlizzardUFs[unit]
		if (not UF) then
			return
		end
		if (UF:IsForbidden()) then
			modifiedBlizzardUFs[unit] = nil
			return
		end
		for _, key in ipairs(reparentKeys) do
			local frame = UF[key]
			if (frame and frame.SetParent) then
				frame:SetParent(UF)
			end
		end
		local auraFrame = UF.AurasFrame
		if (auraFrame) then
			if (auraFrame.DebuffListFrame) then
				auraFrame.DebuffListFrame:SetParent(auraFrame)
			end
			if (auraFrame.BuffListFrame) then
				auraFrame.BuffListFrame:SetParent(auraFrame)
			end
			if (auraFrame.CrowdControlListFrame) then
				auraFrame.CrowdControlListFrame:SetParent(auraFrame)
			end
			if (auraFrame.LossOfControlFrame) then
				auraFrame.LossOfControlFrame:SetParent(auraFrame)
			end
		end
		modifiedBlizzardUFs[unit] = nil
	end

	local clearClutter = function(frame)
		if (not frame or (frame.IsForbidden and frame:IsForbidden())) then
			return
		end
		local UF = frame.UnitFrame or frame.unitFrame
		if (UF and not (UF.IsForbidden and UF:IsForbidden())) then
			if (not UF.__AzeriteUI_Disabled) then
				UF.__AzeriteUI_Disabled = true
				pcall(function() UF:UnregisterAllEvents() end)
				pcall(function() UF:SetAlpha(0) end)
			end
			local health = UF.healthBar or UF.healthbar or UF.HealthBar
			if (health and health.UnregisterAllEvents) then
				pcall(function() health:UnregisterAllEvents() end)
			end
			local power = UF.manabar or UF.ManaBar
			if (power and power.UnregisterAllEvents) then
				pcall(function() power:UnregisterAllEvents() end)
			end
			local castbar = UF.castBar or UF.CastBar or UF.CastingBarFrame
			if (castbar and castbar.UnregisterAllEvents) then
				pcall(function() castbar:UnregisterAllEvents() end)
			end
			local auras = UF.AurasFrame
			if (auras and not (auras.IsForbidden and auras:IsForbidden())) then
				pcall(function() auras:UnregisterAllEvents() end)
				pcall(function() auras:Hide() end)
			end
		end
		local classNameplateManaBar = frame.classNamePlatePowerBar
		if (classNameplateManaBar) then
			classNameplateManaBar:SetAlpha(0)
			classNameplateManaBar:Hide()
			classNameplateManaBar:UnregisterAllEvents()
		end

		local classNamePlateMechanicFrame = frame.classNamePlateMechanicFrame
		if (classNamePlateMechanicFrame) then
			classNamePlateMechanicFrame:SetAlpha(0)
			classNamePlateMechanicFrame:Hide()
		end

		local personalFriendlyBuffFrame = frame.personalFriendlyBuffFrame
		if (personalFriendlyBuffFrame) then
			personalFriendlyBuffFrame:SetAlpha(0)
			personalFriendlyBuffFrame:Hide()
		end
	end

	local function PatchBlizzardNamePlate(unit)
		if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit or not unit) then
			return
		end

		local plate = C_NamePlate.GetNamePlateForUnit(unit, issecurefunc())
		if (not plate or not plate.UnitFrame or plate.UnitFrame:IsForbidden()) then
			return
		end

		clearClutter(plate)
	end

	local function PatchBlizzardNamePlateFrame(plate)
		if (not plate or (plate.IsForbidden and plate:IsForbidden())) then
			return
		end
		local UF = plate.UnitFrame or plate.unitFrame
		if (not UF or (UF.IsForbidden and UF:IsForbidden())) then
			return
		end

		clearClutter(plate)
	end

	self.PatchBlizzardNamePlate = PatchBlizzardNamePlate
	self.PatchBlizzardNamePlateFrame = PatchBlizzardNamePlateFrame
	if (secretMode) then
		self.DisableBlizzardNamePlate = nil
		self.RestoreBlizzardNamePlate = nil
	else
		self.DisableBlizzardNamePlate = DisableBlizzardNamePlate
		self.RestoreBlizzardNamePlate = RestoreBlizzardNamePlate
	end

	if (not secretMode) then
		if (NamePlateDriverFrame.SetupClassNameplateBars) then
			hooksecurefunc(NamePlateDriverFrame, "SetupClassNameplateBars", function(frame)
				if (not frame or frame:IsForbidden()) then return end
				clearClutter(frame)
			end)
		end

		hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", function()
			if (InCombatLockdown()) then return end
			local db = ns.GetConfig("NamePlates")
			if (C_NamePlate.SetNamePlateFriendlySize) then
				C_NamePlate.SetNamePlateFriendlySize(unpack(db.Size))
			end
			if (C_NamePlate.SetNamePlateEnemySize) then
				C_NamePlate.SetNamePlateEnemySize(unpack(db.Size))
			end
			if (C_NamePlate.SetNamePlateSelfSize) then
				C_NamePlate.SetNamePlateSelfSize(unpack(db.Size))
			end
		end)
	end

	if (NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateCreated and not self.__AzeriteUI_NamePlateCreateHooked) then
		self.__AzeriteUI_NamePlateCreateHooked = true
		hooksecurefunc(NamePlateDriverFrame, "OnNamePlateCreated", function(_, plate)
			if (self.PatchBlizzardNamePlateFrame) then
				self.PatchBlizzardNamePlateFrame(plate)
			end
		end)
	end
	if (_G.NamePlateUnitFrameMixin and type(_G.NamePlateUnitFrameMixin.OnUnitSet) == "function" and not self.__AzeriteUI_NamePlateUnitSetHooked) then
		self.__AzeriteUI_NamePlateUnitSetHooked = true
		hooksecurefunc(_G.NamePlateUnitFrameMixin, "OnUnitSet", function(UF)
			if (UF and not (UF.IsForbidden and UF:IsForbidden())) then
				local plate = UF:GetParent()
				if (plate and self.PatchBlizzardNamePlateFrame) then
					self.PatchBlizzardNamePlateFrame(plate)
				end
			end
		end)
	end

	clearClutter(NamePlateDriverFrame)
end

NamePlatesMod.UpdateSettings = function(self)
	-- Check if the enabled state has changed
	local isCurrentlyEnabled = self:IsEnabled()
	local shouldBeEnabled = self.db.profile.enabled
	local profileScale = self.db and self.db.profile and self.db.profile.scale or 1
	if (type(profileScale) ~= "number") then
		profileScale = 1
	end
	local effectiveScale = ns.API.GetScale() * profileScale
	
	if (isCurrentlyEnabled ~= shouldBeEnabled) then
		-- Enabled state changed - require a UI reload
		C_UI.Reload()
	else
		-- Just update existing plates
		for plate in next,ns.ActiveNamePlates do
			if (plate and plate.SetScale) then
				plate:SetScale(effectiveScale)
			end
			NamePlate_PostUpdateElements(plate, "ForceUpdate")
		end
	end
end

NamePlatesMod.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		-- Todo:
		-- Make this a user controllable setting.
		local isInInstance, instanceType = IsInInstance()
		if (isInInstance) then
			if (instanceType == "pvp") then
				SetCVar("nameplateMinAlpha", 1) -- The minimum alpha of nameplates.
			elseif (instanceType == "arena") then
				SetCVar("nameplateMinAlpha", 1) -- The minimum alpha of nameplates.
			else
				SetCVar("nameplateMinAlpha", .75) -- The minimum alpha of nameplates.
			end
			SetCVar("nameplateOccludedAlphaMult", .45) -- Alpha multiplier of hidden plates
		else
			SetCVar("nameplateMinAlpha", .4) -- The minimum alpha of nameplates.
			SetCVar("nameplateOccludedAlphaMult", .15) -- Alpha multiplier of hidden plates
		end
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local unit = ...
		if (unit == "preview") then
			return
		end
		if (unit and self.PatchBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.PatchBlizzardNamePlate(unit) end)
			else
				self.PatchBlizzardNamePlate(unit)
			end
		end
		if (unit and self.DisableBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.DisableBlizzardNamePlate(unit) end)
			else
				self.DisableBlizzardNamePlate(unit)
			end
		end
	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		local unit = ...
		if (unit == "preview") then
			return
		end
		if (unit and self.RestoreBlizzardNamePlate) then
			if (C_Timer) then
				C_Timer.After(0, function() self.RestoreBlizzardNamePlate(unit) end)
			else
				self.RestoreBlizzardNamePlate(unit)
			end
		end
	end
end

NamePlatesMod.OnInitialize = function(self)
	-- Always register the database first so options can access it
	self.db = ns.db:RegisterNamespace("NamePlates", defaults)
	
	-- Check for conflicts with other nameplate addons
	if (self:CheckForConflicts()) then return self:Disable() end

	-- If custom nameplates are disabled, don't enable the module
	if (not self.db.profile.enabled) then return self:Disable() end

	LoadAddOn("Blizzard_NamePlates")

	self:HookNamePlates()
end

NamePlatesMod.OnEnable = function(self)
	oUF:RegisterStyle(ns.Prefix.."NamePlates", style)
	oUF:SetActiveStyle(ns.Prefix.."NamePlates")
	local driver = oUF:SpawnNamePlates(ns.Prefix)
	if (driver) then
		driver:SetAddedCallback(callback)
		driver:SetRemovedCallback(callback)
		driver:SetTargetCallback(callback)
		driver:SetCVars(cvars)
		self.namePlateDriver = driver
	end

	self.mouseTimer = self:ScheduleRepeatingTimer(checkMouseOver, 1/20)
	self.softTimer = self:ScheduleRepeatingTimer(checkSoftTarget, 1/20)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnEvent")

end

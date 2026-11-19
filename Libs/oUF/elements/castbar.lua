--[[
# Element: Castbar

Handles the visibility and updating of spell castbars.

## Widget

Castbar - A `StatusBar` to represent spell cast/channel progress.

## Sub-Widgets

.Icon     - A `Texture` to represent spell icon.
.SafeZone - A `Texture` to represent latency.
.Shield   - A `Texture` to represent if it's possible to interrupt or spell steal.
.Spark    - A `Texture` to represent the castbar's edge.
.Text     - A `FontString` to represent spell name.
.Time     - A `FontString` to represent spell duration.

## Notes

A default texture will be applied to the StatusBar and Texture widgets if they don't have a texture or a color set.

## Options

.timeToHold      - Indicates for how many seconds the castbar should be visible after a _FAILED or _INTERRUPTED
                   event. Defaults to 0 (number)
.hideTradeSkills - Makes the element ignore casts related to crafting professions (boolean)
.smoothing       - Which status bar smoothing method to use, defaults to `Enum.StatusBarInterpolation.Immediate` (number)

## Attributes

.castID           - A unique identifier of the currently cast spell (number?)
.casting          - Indicates whether the current spell is an ordinary cast (boolean)
.channeling       - Indicates whether the current spell is a channeled cast (boolean)
.empowering       - Indicates whether the current spell is an empowering cast (boolean)
.notInterruptible - Indicates whether the current spell is interruptible (boolean)
.spellID          - The spell identifier of the currently cast/channeled/empowering spell (number)
.spellName        - The name of the spell currently being cast/channeled/empowered (string)

## Examples

    -- Position and size
    local Castbar = CreateFrame('StatusBar', nil, self)
    Castbar:SetSize(20, 20)
    Castbar:SetPoint('TOP')
    Castbar:SetPoint('LEFT')
    Castbar:SetPoint('RIGHT')

    -- Add a spark
    local Spark = Castbar:CreateTexture(nil, 'OVERLAY')
    Spark:SetSize(20, 20)
    Spark:SetBlendMode('ADD')
    Spark:SetPoint('CENTER', Castbar:GetStatusBarTexture(), 'RIGHT', 0, 0)

    -- Add a timer
    local Time = Castbar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    Time:SetPoint('RIGHT', Castbar)

    -- Add spell text
    local Text = Castbar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    Text:SetPoint('LEFT', Castbar)

    -- Add spell icon
    local Icon = Castbar:CreateTexture(nil, 'OVERLAY')
    Icon:SetSize(20, 20)
    Icon:SetPoint('TOPLEFT', Castbar, 'TOPLEFT')

    -- Add Shield
    local Shield = Castbar:CreateTexture(nil, 'OVERLAY')
    Shield:SetSize(20, 20)
    Shield:SetPoint('CENTER', Castbar)

    -- Add safezone
    local SafeZone = Castbar:CreateTexture(nil, 'OVERLAY')

    -- Register it with oUF
    Castbar.Spark = Spark
    Castbar.Time = Time
    Castbar.Text = Text
    Castbar.Icon = Icon
    Castbar.Shield = Shield
    Castbar.SafeZone = SafeZone
    self.Castbar = Castbar
--]]

local _, ns = ...
local oUF = ns.oUF
local API = ns.API

local FALLBACK_ICON = 136243 -- Interface\ICONS\Trade_Engineering
local FAILED = _G.FAILED or 'Failed'
local INTERRUPTED = _G.INTERRUPTED or 'Interrupted'

local function NormalizeNotInterruptible(element, value)
	if(API and API.SafeBool) then
		return API.SafeBool(value, element, '__AzeriteUI_NotInterruptible', false)
	end

	if(type(value) == 'boolean' and not (issecretvalue and issecretvalue(value))) then
		element.__AzeriteUI_NotInterruptible = value
		return value
	end

	if(type(element.__AzeriteUI_NotInterruptible) == 'boolean') then
		return element.__AzeriteUI_NotInterruptible
	end

	return false
end

local function EmitInterruptEventDebug(element, reason, eventName, unit, rawNotInterruptible)
	if(not API or not API.DEBUG_HEALTH_CHAT or not API.DebugPrintf) then
		return
	end

	local owner = element and element.__owner
	local shield = element and element.Shield
	API.DebugPrintf('InterruptRaw', 2,
		'reason=%s event=%s unit=%s ownerUnit=%s rawNotInterruptible=%s normalized=%s shown=%s castID=%s spellID=%s shieldShown=%s',
		tostring(reason),
		tostring(eventName),
		tostring(unit),
		tostring(owner and owner.unit),
		tostring(rawNotInterruptible),
		tostring(element and element.notInterruptible),
		tostring(element and element.IsShown and element:IsShown()),
		tostring(element and element.castID),
		tostring(element and element.spellID),
		tostring(shield and shield.IsShown and shield:IsShown()))
end

-- Restricted cast data can be present without being readable by Lua.
local function HasCastValue(value)
	return (issecretvalue and issecretvalue(value)) or value ~= nil
end

local function IsReadableNumber(value)
	return type(value) == 'number' and not (issecretvalue and issecretvalue(value))
end

local function GetEmpowerEndTime(unit, endTime)
	if(not IsReadableNumber(endTime)) then return end
	local hold = GetUnitEmpowerHoldAtMaxTime(unit)
	if(IsReadableNumber(hold) and hold >= 0) then
		return (endTime + hold) / 1000
	end
end

local function IsCastOver(unit)
	return not HasCastValue(UnitCastingInfo(unit)) and not HasCastValue(UnitChannelInfo(unit))
end

local function MatchesCastID(element, castID)
	local current = element.castID
	return not (issecretvalue and (issecretvalue(castID) or issecretvalue(current))) and castID ~= nil
		and current == castID
end

-- AzeriteUI: the bar's own timer has run out. Dcryfm's party bars (hunter, and a druid after a
-- loading screen) stayed white at full on 5.28.0, so the client went on answering a cast for the
-- unit after it ended; the timer does not depend on that answer. False when unreadable or secret.
local function IsTimerSpent(element)
	local ok, timer = pcall(element.GetTimerDuration, element)
	local kind = type(timer)
	if(not ok or (kind ~= 'table' and kind ~= 'userdata') or not timer.GetRemainingDuration) then
		return false
	end
	local okRemaining, remaining = pcall(timer.GetRemainingDuration, timer)
	if(not okRemaining or not IsReadableNumber(remaining)) then
		return false
	end
	return remaining <= 0
end

-- When Lua draws the player's progress, expire it by the same end time.
-- The native widget may still carry a timer from before a pushback or refresh.
local function IsCastTimerSpent(element, unit)
	if(element.empowering) then
		-- The widget's timer can expire before the hold at max. Only party
		-- overlays with a known hold-adjusted deadline use the backstop.
		local deadline = element.__AzeriteUI_EmpowerEndTime
		return deadline ~= nil and GetTime() >= deadline
	end
	if(unit == 'player' and IsReadableNumber(element.endTime)) then
		return GetTime() >= element.endTime
	end
	return IsTimerSpent(element)
end

-- A stop without a matching optional ID can finish the overlay once the unit
-- has no cast or channel. A late stop for the previous cast leaves a new one up.
local function IsCurrentCast(element, castID, unit)
	if(MatchesCastID(element, castID)) then
		return true
	end
	return IsCastOver(unit)
end

local function resetAttributes(self)
	self.castID = nil
	self.__AzeriteUI_CastUnit = nil
	self.casting = nil
	self.channeling = nil
	self.empowering = nil
	self.startTime = nil
	self.endTime = nil
	self.__AzeriteUI_EmpowerEndTime = nil
	self.notInterruptible = nil
	self.__AzeriteUI_NotInterruptible = nil
	self.spellID = nil
	self.spellName = nil

	for _, pip in next, self.Pips do
		pip:Hide()
	end
end

local function CreatePip(element)
	return CreateFrame('Frame', nil, element, 'CastingBarFrameStagePipTemplate')
end

local function UpdatePips(element, stages)
	if(type(stages) ~= 'table') then
		for _, pip in next, element.Pips do
			pip:Hide()
		end

		if(element.PostUpdatePips) then
			element:PostUpdatePips(stages)
		end

		return
	end

	local isHoriz = element:GetOrientation() == 'HORIZONTAL'
	local elementSize = isHoriz and element:GetWidth() or element:GetHeight()

	local lastOffset = 0
	for stage, stageSection in next, stages do
		local offset = lastOffset + (elementSize * stageSection)
		lastOffset = offset

		local pip = element.Pips[stage]
		if(not pip) then
			--[[ Override: Castbar:CreatePip(stage)
			Creates a "pip" for the given stage, used for empowered casts.

			* self  - the Castbar widget
			* stage - the empowered stage for which the pip should be created (number)

			## Returns

			* pip - a frame used to depict an empowered stage boundary, typically with a line texture (frame)
			--]]
			pip = (element.CreatePip or CreatePip) (element, stage)
			element.Pips[stage] = pip
		end

		pip:ClearAllPoints()
		pip:Show()

		if(isHoriz) then
			if(pip.RotateTextures) then
				pip:RotateTextures(0)
			end

			if(element:GetReverseFill()) then
				pip:SetPoint('TOP', element, 'TOPRIGHT', -offset, 0)
				pip:SetPoint('BOTTOM', element, 'BOTTOMRIGHT', -offset, 0)
			else
				pip:SetPoint('TOP', element, 'TOPLEFT', offset, 0)
				pip:SetPoint('BOTTOM', element, 'BOTTOMLEFT', offset, 0)
			end
		else
			if(pip.RotateTextures) then
				pip:RotateTextures(1.5708)
			end

			if(element:GetReverseFill()) then
				pip:SetPoint('LEFT', element, 'TOPLEFT', 0, -offset)
				pip:SetPoint('RIGHT', element, 'TOPRIGHT', 0, -offset)
			else
				pip:SetPoint('LEFT', element, 'BOTTOMLEFT', 0, offset)
				pip:SetPoint('RIGHT', element, 'BOTTOMRIGHT', 0, offset)
			end
		end
	end

	--[[ Callback: Castbar:PostUpdatePips(stages)
	Called after the element has updated stage separators (pips) in an empowered cast.

	* self   - the Castbar widget
	* stages - stages with percentage of each stage (table)
	--]]
	if(element.PostUpdatePips) then
		element:PostUpdatePips(stages)
	end
end

--[[ Override: Castbar:ShouldShow(unit)
Handles check for which unit the castbar should show for.  
Defaults to the object unit.

* self - the Castbar widget
* unit - the unit for which the update has been triggered (string)
--]]
local function ShouldShow(element, unit)
	return element.__owner.unit == unit
end

local function CastStart(self, event, unit)
	local element = self.Castbar
	if(not (element.ShouldShow or ShouldShow) (element, unit)) then
		return
	end
	if(not unit) then
		resetAttributes(element)
		element:Hide()
		return
	end

	local direction, duration = Enum.StatusBarTimerDirection.ElapsedTime
	local castGUID, castBarID
	local name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID
	name, text, texture, startTime, endTime, isTradeSkill, castGUID, notInterruptible, spellID, castBarID = UnitCastingInfo(unit)
	local casting = HasCastValue(name)
	local empowering, channeling
	local castID = castBarID or castGUID
	if(casting) then
		duration = UnitCastingDuration(unit)
	else
		local isEmpowered
		name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, isEmpowered, _, castBarID = UnitChannelInfo(unit)
		castID = castBarID
		if(HasCastValue(name)) then
			if(isEmpowered) then
				empowering = true
				duration = UnitEmpoweredChannelDuration(unit)
			else
				channeling = true
				duration = UnitChannelDuration(unit)
				direction = Enum.StatusBarTimerDirection.RemainingTime
			end
		end
	end

	if(not HasCastValue(name) or (isTradeSkill and element.hideTradeSkills)) then
		-- don't cancel hold time when we swap targets
		if(not (event == 'PLAYER_TARGET_CHANGED' and element.holdTime and element.holdTime > 0)) then
			resetAttributes(element)
			element:Hide()
		end

		return
	end

	-- A start or refresh can supersede a cast whose stop event never arrived.
	if(element.empowering and not empowering) then
		for _, pip in next, element.Pips do
			pip:Hide()
		end
	end
	element.startTime = nil
	element.endTime = nil
	element.casting = casting or nil
	element.channeling = channeling
	element.empowering = empowering
	element.delay = 0
	element.notInterruptible = NormalizeNotInterruptible(element, notInterruptible)
	element.holdTime = 0
	element.castID = castID
	element.__AzeriteUI_CastUnit = unit
	element.__AzeriteUI_CastOverCheck = 0
	element.__AzeriteUI_TimerSpentChecks = 0
	element.spellID = spellID
	element.spellName = text
	EmitInterruptEventDebug(element, 'start', event, unit, notInterruptible)

	local empowerEndTime
	if(empowering and (unit == 'player' or element.requireCastTimer)) then
		empowerEndTime = GetEmpowerEndTime(unit, endTime)
	end
	element.__AzeriteUI_EmpowerEndTime = element.requireCastTimer and empowerEndTime or nil

	if(unit == 'player' and IsReadableNumber(startTime) and IsReadableNumber(endTime) and endTime > startTime) then
		element.startTime = startTime / 1000
		element.endTime = empowerEndTime or endTime / 1000
	end

	local timerSet
	if(HasCastValue(duration)) then
		-- AzeriteUI: a new cast is a fresh set and starts where it starts; only CastUpdate
		-- (pushback, a channel cut short) uses element.smoothing, as Blizzard's own timer
		-- bars do (Blizzard_CustomAuraButton.lua, GetStatusBarInterpolationForUpdateMode).
		local startInterpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
		timerSet = pcall(element.SetTimerDuration, element, duration, startInterpolation, direction)
		if(not timerSet and element.SetTimerDuration and IsReadableNumber(startTime) and IsReadableNumber(endTime)) then
			timerSet = pcall(element.SetTimerDuration, element, math.max((endTime - startTime) / 1000, 0), startInterpolation, direction)
		end
	end
	if(element.requireCastTimer and not timerSet) then
		-- A decorative overlay must never display the previous cast's progress.
		if(not element.startTime) then
			resetAttributes(element)
			element:Hide()
			return
		end
		element:SetMinMaxValues(0, 1)
		element:SetValue(0)
	end

	if(element.Icon) then
		if(not HasCastValue(texture)) then texture = FALLBACK_ICON end
		element.Icon:SetTexture(texture)
	end
	-- Temporary: disable shield-driven interrupt visuals while isolating cast payload behavior.
	-- if(element.Shield) then element.Shield:SetAlphaFromBoolean(element.notInterruptible, 1, 0) end
	if(element.Spark) then element.Spark:Show() end
	if(element.Text) then element.Text:SetText(text) end
	if(element.Time) then element.Time:SetText() end

	local safeZone = element.SafeZone
	if(safeZone and unit == 'player') then
		local isHoriz = element:GetOrientation() == 'HORIZONTAL'

		safeZone:ClearAllPoints()
		safeZone:SetPoint(isHoriz and 'TOP' or 'LEFT')
		safeZone:SetPoint(isHoriz and 'BOTTOM' or 'RIGHT')

		if(element.channeling) then
			safeZone:SetPoint(element:GetReverseFill() and (isHoriz and 'RIGHT' or 'TOP') or (isHoriz and 'LEFT' or 'BOTTOM'))
		else
			safeZone:SetPoint(element:GetReverseFill() and (isHoriz and 'LEFT' or 'BOTTOM') or (isHoriz and 'RIGHT' or 'TOP'))
		end

		if(empowerEndTime) then
			endTime = empowerEndTime * 1000
		end

		local ratio = 0
		if(type(startTime) == 'number' and type(endTime) == 'number'
			and (not issecretvalue or (not issecretvalue(startTime) and not issecretvalue(endTime)))) then
			local span = endTime - startTime
			if(span > 0) then
				ratio = (select(4, GetNetStats())) / span
				if(ratio > 1) then
					ratio = 1
				end
			end
		end

		safeZone[isHoriz and 'SetWidth' or 'SetHeight'](safeZone, element[isHoriz and 'GetWidth' or 'GetHeight'](element) * ratio)
	end

	if(element.empowering) then
		--[[ Override: Castbar:UpdatePips(stages)
		Handles updates for stage separators (pips) in an empowered cast.

		* self   - the Castbar widget
		* stages - stages with percentage of each stage (table)
		--]]
		(element.UpdatePips or UpdatePips) (element, UnitEmpoweredStagePercentages(unit))
	end

	--[[ Callback: Castbar:PostCastStart(unit)
	Called after the element has been updated upon a spell cast or channel start.

	* self - the Castbar widget
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PostCastStart) then
		element:PostCastStart(unit)
	end

	element:Show()
end

local function CastUpdate(self, event, unit, castGUID, _, castID)
	local element = self.Castbar
	if(not (element.ShouldShow or ShouldShow) (element, unit)) then
		return
	end

	if(not element:IsShown() or element.__AzeriteUI_CastUnit ~= unit or not MatchesCastID(element, castID or castGUID)) then
		return
	end

	local direction, duration, name, startTime, endTime, _ = Enum.StatusBarTimerDirection.ElapsedTime
	if(event == 'UNIT_SPELLCAST_DELAYED') then
		name, _, _, startTime, endTime = UnitCastingInfo(unit)
		duration = UnitCastingDuration(unit)
	else
		name, _, _, startTime, endTime = UnitChannelInfo(unit)
		if(event == 'UNIT_SPELLCAST_EMPOWER_UPDATE') then
			duration = UnitEmpoweredChannelDuration(unit)
		else
			duration = UnitChannelDuration(unit)
			direction = Enum.StatusBarTimerDirection.RemainingTime
		end
	end

	if(not HasCastValue(name)) then return end

	if(element.requireCastTimer and element.empowering and event == 'UNIT_SPELLCAST_EMPOWER_UPDATE') then
		element.__AzeriteUI_EmpowerEndTime = GetEmpowerEndTime(unit, endTime)
		element.__AzeriteUI_TimerSpentChecks = 0
	end

	if(unit == 'player' and element.startTime and IsReadableNumber(startTime)) then
		-- we can only calculate delay for players
		startTime = startTime / 1000

		local delta
		if(element.channeling) then
			delta = element.startTime - startTime
		else
			delta = startTime - element.startTime
		end

		if(delta < 0) then
			delta = 0
		end

		element.delay = element.delay + delta

		-- AzeriteUI (GitHub #5): the cast was pushed back or the channel cut short, so its times
		-- moved. onUpdate draws the bar from the stored ones and the next delay is measured from
		-- them, so both take the new ones, and so does the timer: on Forever a duration read here
		-- still runs on the old span. Blizzard's bar recomputes from these times the same way
		-- (CastingBarFrame.lua, HandleCastDelayed). An empowered cast keeps what it had.
		if(not element.empowering and type(endTime) == 'number'
			and (not issecretvalue or not issecretvalue(endTime))) then
			element.startTime = startTime
			element.endTime = endTime / 1000

			if(C_DurationUtil and C_DurationUtil.CreateDuration) then
				local span = C_DurationUtil.CreateDuration()
				span:SetTimeSpan(element.startTime, element.endTime)
				duration = span
			end
		end
	end

	if(HasCastValue(duration)) then
		local ok = pcall(element.SetTimerDuration, element, duration, element.smoothing, direction)
		if(not ok and not (issecretvalue and issecretvalue(duration))) then
			-- Keep timer text/bar valid when client APIs return mixed duration payloads.
			local safeDuration = tonumber(duration)
			if(type(safeDuration) == 'number') then
				pcall(element.SetTimerDuration, element, math.max(safeDuration, 0), element.smoothing, direction)
			end
		end
	end

	--[[ Callback: Castbar:PostCastUpdate(unit)
	Called after the element has been updated when a spell cast or channel has been updated.

	* self - the Castbar widget
	* unit - the unit that the update has been triggered (string)
	--]]
	if(element.PostCastUpdate) then
		return element:PostCastUpdate(unit)
	end
end

local function CastStop(self, event, unit, _, _, ...)
	local element = self.Castbar
	if(not (element.ShouldShow or ShouldShow) (element, unit)) then
		return
	end

	local castID, interruptedBy, empowerComplete
	if(event == 'UNIT_SPELLCAST_STOP') then
		castID = ...
	elseif(event == 'UNIT_SPELLCAST_EMPOWER_STOP') then
		empowerComplete, interruptedBy, castID = ...
	elseif(event == 'UNIT_SPELLCAST_CHANNEL_STOP') then
		interruptedBy, castID = ...
	end

	if(not element:IsShown() or not IsCurrentCast(element, castID, unit)) then
		return
	end

	if(element.Spark) then element.Spark:Hide() end

	local interrupted = HasCastValue(interruptedBy)
	if(interrupted) then
		if(element.Text) then element.Text:SetText(INTERRUPTED) end

		element.holdTime = element.timeToHold or 0

		-- force filled castbar
		element:SetMinMaxValues(0, 1)
		element:SetValue(1)
	end

	if(interrupted) then
		--[[ Callback: Castbar:PostCastInterrupted(unit, interruptedBy)
		Called after the element has been updated when a spell cast or channel has stopped.

		* self          - the Castbar widget
		* unit          - the unit for which the update has been triggered (string)
		* interruptedBy - GUID of whomever interrupted the cast (string)
		--]]
		if(element.PostCastInterrupted) then
			element:PostCastInterrupted(unit, interruptedBy)
		end
	else
		--[[ Callback: Castbar:PostCastStop(unit[, empowerComplete])
		Called after the element has been updated when a spell cast or channel has stopped.

		* self            - the Castbar widget
		* unit            - the unit for which the update has been triggered (string)
		* empowerComplete - if the empowered cast was complete (boolean?)
		--]]
		if(element.PostCastStop) then
			element:PostCastStop(unit, empowerComplete)
		end
	end

	resetAttributes(element)
end

local function CastFail(self, event, unit, _, _, ...)
	local element = self.Castbar
	if(not (element.ShouldShow or ShouldShow) (element, unit)) then
		return
	end

	local castID, interruptedBy
	if(event == 'UNIT_SPELLCAST_INTERRUPTED') then
		interruptedBy, castID = ...
	elseif(event == 'UNIT_SPELLCAST_FAILED') then
		castID = ...
	end

	if(not element:IsShown() or not IsCurrentCast(element, castID, unit)) then
		return
	end

	if(element.Text) then
		element.Text:SetText(event == 'UNIT_SPELLCAST_FAILED' and FAILED or INTERRUPTED)
	end

	if(element.Spark) then element.Spark:Hide() end

	element.holdTime = element.timeToHold or 0

	-- force filled castbar
	element:SetMinMaxValues(0, 1)
	element:SetValue(1)

	if(HasCastValue(interruptedBy)) then
		if(element.PostCastInterrupted) then
			element:PostCastInterrupted(unit, interruptedBy)
		end
	else
		--[[ Callback: Castbar:PostCastFail(unit)
		Called after the element has been updated upon a failed or interrupted spell cast.

		* self - the Castbar widget
		* unit - the unit for which the update has been triggered (string)
		--]]
		if(element.PostCastFail) then
			element:PostCastFail(unit)
		end
	end

	resetAttributes(element)
end

local function CastInterruptible(self, event, unit)
	local element = self.Castbar
	if(not (element.ShouldShow or ShouldShow) (element, unit)) then
		return
	end

	if(not element:IsShown()) then return end
	-- ISSUE: we can't verify if this is for an active cast/channel/empower without castID

	element.notInterruptible = NormalizeNotInterruptible(element, event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE')
	EmitInterruptEventDebug(element, 'toggle', event, unit, event == 'UNIT_SPELLCAST_NOT_INTERRUPTIBLE')

	-- Temporary: disable shield-driven interrupt visuals while isolating cast payload behavior.
	-- if(element.Shield) then element.Shield:SetAlphaFromBoolean(element.notInterruptible, 1, 0) end

	--[[ Callback: Castbar:PostCastInterruptible(unit)
	Called after the element has been updated when a spell cast has become interruptible or uninterruptible.

	* self - the Castbar widget
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PostCastInterruptible) then
		return element:PostCastInterruptible(unit)
	end
end

local function onUpdate(self, elapsed)
	if(self.casting or self.channeling or self.empowering) then
		-- AzeriteUI: backstop for a stop event that never matched (see IsCastOver).
		-- Only the player's cast times are readable, so other units are asked directly.
		local castUnit = self.__AzeriteUI_CastUnit
		if(castUnit) then
			self.__AzeriteUI_CastOverCheck = (self.__AzeriteUI_CastOverCheck or 0) + elapsed
			if(self.__AzeriteUI_CastOverCheck >= .5) then
				self.__AzeriteUI_CastOverCheck = 0
				if(self.__owner.unit ~= castUnit or IsCastOver(castUnit)) then
					resetAttributes(self)
					self:Hide()
					return
				end
				-- Past its end on two checks in a row (.5 to 1 s): a late stop is not cut off.
				if(IsCastTimerSpent(self, castUnit)) then
					self.__AzeriteUI_TimerSpentChecks = (self.__AzeriteUI_TimerSpentChecks or 0) + 1
					if(self.__AzeriteUI_TimerSpentChecks >= 2) then
						resetAttributes(self)
						self:Hide()
						return
					end
				else
					self.__AzeriteUI_TimerSpentChecks = 0
				end
			end
		end

		local fallbackRemaining
		if(type(self.startTime) == 'number' and type(self.endTime) == 'number'
			and (not issecretvalue or (not issecretvalue(self.startTime) and not issecretvalue(self.endTime)))) then
			local now = GetTime()
			local duration = self.endTime - self.startTime
			if(duration > 0) then
				local elapsedCast = now - self.startTime
				local value = self.channeling and (duration - elapsedCast) or elapsedCast
				if(value < 0) then
					value = 0
				elseif(value > duration) then
					value = duration
				end
				self:SetMinMaxValues(0, duration)
				self:SetValue(value)
				fallbackRemaining = duration - value
			end
		end

		if(self.Time) then
			local ok, durationObject = pcall(self.GetTimerDuration, self) -- can be nil/forbidden
			if(not ok) then
				durationObject = nil
			end
			if durationObject then
				if(self.delay ~= 0) then
					--[[ Override: Castbar:CustomDelayText(duration)
					Used to completely override the updating of the .Time sub-widget when there is a delay to adjust for.

					* self     - the Castbar widget
					* duration - a [Duration](https://warcraft.wiki.gg/wiki/ScriptObject_DurationObject) object for the Castbar
					--]]
					if(self.CustomDelayText) then
						self:CustomDelayText(durationObject)
					else
						local duration = durationObject:GetRemainingDuration()
						self.Time:SetFormattedText('%.1f|cffff0000%s%.2f|r', duration, self.channeling and '-' or '+', self.delay)
					end
				else
					--[[ Override: Castbar:CustomTimeText(duration)
					Used to completely override the updating of the .Time sub-widget.

					* self     - the Castbar widget
					* duration - a [Duration](https://warcraft.wiki.gg/wiki/ScriptObject_DurationObject) object for the Castbar
					--]]
					if(self.CustomTimeText) then
						self:CustomTimeText(durationObject)
					else
						self.Time:SetFormattedText('%.1f', durationObject:GetRemainingDuration())
					end
				end
			elseif(type(fallbackRemaining) == 'number') then
				if(self.delay ~= 0) then
					if(self.CustomDelayText) then
						self:CustomDelayText(fallbackRemaining)
					else
						self.Time:SetFormattedText('%.1f|cffff0000%s%.2f|r', fallbackRemaining, self.channeling and '-' or '+', self.delay)
					end
				else
					if(self.CustomTimeText) then
						self:CustomTimeText(fallbackRemaining)
					else
						self.Time:SetFormattedText('%.1f', fallbackRemaining)
					end
				end
			end
		end

		-- ISSUE: we have no way to get this information any more, Blizzard is aware
		-- --[[ Callback: Castbar:PostUpdateStage(stage)
		-- Called after the current stage changes.

		-- * self - the Castbar widget
		-- * stage - the stage of the empowered cast (number)
		-- --]]
		-- if(self.empowering and self.PostUpdateStage) then
		-- 	local old = self.curStage
		-- 	for i = old + 1, self.numStages do
		-- 		if(self.stagePoints[i]) then
		-- 			if(self.duration > self.stagePoints[i]) then
		-- 				self.curStage = i

		-- 				if(self.curStage ~= old) then
		-- 					self:PostUpdateStage(i)
		-- 				end
		-- 			else
		-- 				break
		-- 			end
		-- 		end
		-- 	end
		-- end
	elseif(self.holdTime > 0) then
		self.holdTime = self.holdTime - elapsed
	else
		resetAttributes(self)
		self:Hide()
	end
end

local function Update(...)
	CastStart(...)
end

local function ForceUpdate(element)
	return Update(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local eventMethods = {
	UNIT_SPELLCAST_START = CastStart,
	UNIT_SPELLCAST_CHANNEL_START = CastStart,
	UNIT_SPELLCAST_EMPOWER_START = CastStart,
	UNIT_SPELLCAST_STOP = CastStop,
	UNIT_SPELLCAST_CHANNEL_STOP = CastStop,
	UNIT_SPELLCAST_EMPOWER_STOP = CastStop,
	UNIT_SPELLCAST_DELAYED = CastUpdate,
	UNIT_SPELLCAST_CHANNEL_UPDATE = CastUpdate,
	UNIT_SPELLCAST_EMPOWER_UPDATE = CastUpdate,
	UNIT_SPELLCAST_FAILED = CastFail,
	UNIT_SPELLCAST_INTERRUPTED = CastFail,
	UNIT_SPELLCAST_INTERRUPTIBLE = CastInterruptible,
	UNIT_SPELLCAST_NOT_INTERRUPTIBLE = CastInterruptible,
}

local function Enable(self, unit)
	local element = self.Castbar
	if(element and unit and not unit:match('%wtarget$')) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		if(not element.smoothing) then
			element.smoothing = Enum.StatusBarInterpolation.Immediate
		end

		for event, method in next, eventMethods do
			self:RegisterEvent(event, method)
		end

		element.holdTime = 0
		element.Pips = element.Pips or {}

		element:SetScript('OnUpdate', element.OnUpdate or onUpdate)

		if(element:IsObjectType('StatusBar') and not element:GetStatusBarTexture()) then
			element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end

		local spark = element.Spark
		if(spark and spark:IsObjectType('Texture') and not spark:GetTexture()) then
			spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		end

		local shield = element.Shield
		if(shield and shield:IsObjectType('Texture') and not shield:GetTexture()) then
			shield:SetTexture([[Interface\CastingBar\UI-CastingBar-Small-Shield]])
		end

		local safeZone = element.SafeZone
		if(safeZone and safeZone:IsObjectType('Texture') and not safeZone:GetTexture()) then
			safeZone:SetColorTexture(1, 0, 0)
		end

		element:Hide()

		return true
	end
end

local function Disable(self)
	local element = self.Castbar
	if(element) then
		element:Hide()

		for event, method in next, eventMethods do
			self:UnregisterEvent(event, method)
		end

		element:SetScript('OnUpdate', nil)

		if(self.unit == 'player' and not (self.hasChildren or self.isChild or self.isNamePlate)) then
			pcall(function()
				if(PlayerCastingBarFrame and not PlayerCastingBarFrame:IsForbidden()) then
					PlayerCastingBarFrame:SetAlpha(1)
				end
			end)
			pcall(function()
				if(PetCastingBarFrame and not PetCastingBarFrame:IsForbidden()) then
					PetCastingBarFrame:SetAlpha(1)
				end
			end)
		end
	end
end

oUF:AddElement('Castbar', Update, Enable, Disable)

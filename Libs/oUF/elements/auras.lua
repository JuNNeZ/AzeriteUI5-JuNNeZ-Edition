--[[
# Element: Auras

Handles creation and updating of aura buttons.

## Widget

Auras   - A Frame to hold `Button`s representing both buffs and debuffs.
Buffs   - A Frame to hold `Button`s representing buffs.
Debuffs - A Frame to hold `Button`s representing debuffs.

## Notes

At least one of the above widgets must be present for the element to work.

## Options

.disableMouse             - Disables mouse events (boolean)
.disableCooldown          - Disables the cooldown spiral (boolean)
.size                     - Aura button size. Defaults to 16 (number)
.width                    - Aura button width. Takes priority over `size` (number)
.height                   - Aura button height. Takes priority over `size` (number)
.onlyShowPlayer           - Shows only auras created by player/vehicle (boolean)
.showStealableBuffs       - Displays the stealable texture on buffs that can be stolen (boolean)
.spacing                  - Spacing between each button. Defaults to 0 (number)
.spacingX                 - Horizontal spacing between each button. Takes priority over `spacing` (number)
.spacingY                 - Vertical spacing between each button. Takes priority over `spacing` (number)
.growthX                  - Horizontal growth direction. Defaults to 'RIGHT' (string)
.growthY                  - Vertical growth direction. Defaults to 'UP' (string)
.initialAnchor            - Anchor point for the aura buttons. Defaults to 'BOTTOMLEFT' (string)
.filter                   - Custom filter list for auras to display. Defaults to 'HELPFUL' for buffs and 'HARMFUL' for
                            debuffs (string)
.tooltipAnchor            - Anchor point for the tooltip. Defaults to 'ANCHOR_BOTTOMRIGHT', however, if a frame has
                            anchoring restrictions it will be set to 'ANCHOR_CURSOR' (string)
.reanchorIfVisibleChanged - Reanchors aura buttons when the number of visible auras has changed (boolean)
.showType                 - Show Overlay texture colored by oUF.colors.dispel (boolean)
.showDebuffType           - Show Overlay texture colored by oUF.colors.dispel when it's a debuff. Exclusive with .showType (boolean)
.showBuffType             - Show Overlay texture colored by oUF.colors.dispel when it's a buff. Exclusive with .showType (boolean)
.minCount                 - Minimum number of aura applications for the Count text to be visible. Defaults to 2 (number)
.maxCount                 - Maximum number of aura applications for the Count text, anything above renders "*". Defaults to 999 (number)
.maxCols                  - Maximum number of aura button columns before wrapping to a new row. Defaults to element width divided by aura button size (number)

## Options Auras

.numBuffs     - The maximum number of buffs to display. Defaults to 32 (number)
.numDebuffs   - The maximum number of debuffs to display. Defaults to 40 (number)
.numTotal     - The maximum number of auras to display. Prioritizes buffs over debuffs. Defaults to the sum of
                .numBuffs and .numDebuffs (number)
.gap          - Controls the creation of an invisible button between buffs and debuffs. Defaults to false (boolean)
.buffFilter   - Custom filter list for buffs to display. Takes priority over `filter` (string)
.debuffFilter - Custom filter list for debuffs to display. Takes priority over `filter` (string)

## Options Buffs

.num - Number of buffs to display. Defaults to 32 (number)

## Options Debuffs

.num - Number of debuffs to display. Defaults to 40 (number)

## Attributes

.dispelColorCurve - Curve object with points defined for each index in oUF.colors.dispel

## Button Attributes

button.auraInstanceID - unique ID for the current aura being tracked by the button (number)
button.isHarmfulAura  - indicates if the button holds a debuff (boolean)

## Examples

    -- Position and size
    local Buffs = CreateFrame('Frame', nil, self)
    Buffs:SetPoint('RIGHT', self, 'LEFT')
    Buffs:SetSize(16 * 2, 16 * 16)

    -- Register with oUF
    self.Buffs = Buffs
--]]

local _, ns = ...
local oUF = ns.oUF
local MAX_AURA_INDEX_SCAN = 255

local function IsSafeNumber(value)
	return type(value) == 'number' and (not issecretvalue or not issecretvalue(value))
end

local function IsSafeKey(value)
	return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function SetShown(frame, shown)
	if(not frame) then return end
	if(shown) then
		if(not frame:IsShown()) then
			frame:Show()
		end
	elseif(frame:IsShown()) then
		frame:Hide()
	end
end


local function GetAuraSlotsSafe(unit, filter)
	local results = {pcall(C_UnitAuras.GetAuraSlots, unit, filter)}
	if(not results[1]) then
		return nil
	end
	table.remove(results, 1)
	return results
end

local function GetAuraDataBySlotSafe(unit, slot)
	local ok, data = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
	if(ok) then
		return data
	end
end

local function GetAuraDataByIndexSafe(unit, index, filter)
	local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
	if(ok) then
		return data
	end
end

local function IsAuraFilteredOutByInstanceIDSafe(unit, auraInstanceID, filter)
	if(not auraInstanceID or not filter) then
		return nil
	end
	local ok, filtered = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceID, filter)
	if(ok) then
		return filtered
	end
end

local function ForEachFullAuraData(unit, filter, callback)
	local slots = GetAuraSlotsSafe(unit, filter)
	if(slots) then
		local hadSlotData = false
		for i = 2, #slots do -- #1 return is continuationToken, we don't care about it
			local data = GetAuraDataBySlotSafe(unit, slots[i])
			if(data) then
				hadSlotData = true
				callback(data)
			end
		end
		if(hadSlotData) then
			return
		end
	end

	for index = 1, MAX_AURA_INDEX_SCAN do
		local data = GetAuraDataByIndexSafe(unit, index, filter)
		if(not data) then
			break
		end
		callback(data)
	end
end

local function CanMutateButtonInCombat(element, button)
	if(element.allowCombatUpdates or not InCombatLockdown()) then
		return true
	end
	if(button and button.IsProtected and not button:IsProtected()) then
		return true
	end
	return false
end

local function UpdateTooltip(self)
	if(GameTooltip:IsForbidden()) then return end

	GameTooltip:SetUnitAuraByAuraInstanceID(self:GetParent().__owner.unit, self.auraInstanceID)
end

local function onEnter(self)
	if(GameTooltip:IsForbidden() or not self:IsVisible()) then return end

	-- Avoid parenting GameTooltip to frames with anchoring restrictions,
	-- otherwise it'll inherit said restrictions which will cause issues with
	-- its further positioning, clamping, etc
	GameTooltip:SetOwner(self, self:GetParent().__restricted and 'ANCHOR_CURSOR' or self:GetParent().tooltipAnchor)
	self:UpdateTooltip()
end

local function onLeave()
	if(GameTooltip:IsForbidden()) then return end

	GameTooltip:Hide()
end

local function CreateButton(element, index)
	local button = CreateFrame('Button', element:GetDebugName() .. 'Button' .. index, element)

	local cd = CreateFrame('Cooldown', '$parentCooldown', button, 'CooldownFrameTemplate')
	cd:SetAllPoints()
	button.Cooldown = cd

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetAllPoints()
	button.Icon = icon

	local countFrame = CreateFrame('Frame', nil, button)
	countFrame:SetAllPoints(button)
	countFrame:SetFrameLevel(cd:GetFrameLevel() + 1)

	local count = countFrame:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
	count:SetPoint('BOTTOMRIGHT', countFrame, 'BOTTOMRIGHT', -1, 0)
	button.Count = count

	local overlay = button:CreateTexture(nil, 'OVERLAY')
	overlay:SetTexture([[Interface\Buttons\UI-Debuff-Overlays]])
	overlay:SetAllPoints()
	overlay:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	button.Overlay = overlay

	local stealable = button:CreateTexture(nil, 'OVERLAY')
	stealable:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
	stealable:SetPoint('TOPLEFT', -3, 3)
	stealable:SetPoint('BOTTOMRIGHT', 3, -3)
	stealable:SetBlendMode('ADD')
	button.Stealable = stealable

	button.UpdateTooltip = UpdateTooltip
	button:SetScript('OnEnter', onEnter)
	button:SetScript('OnLeave', onLeave)

	--[[ Callback: Auras:PostCreateButton(button)
	Called after a new aura button has been created.

	* self   - the widget holding the aura buttons
	* button - the newly created aura button (Button)
	--]]
	if(element.PostCreateButton) then element:PostCreateButton(button) end

	return button
end

local function SetPosition(element, from, to)
	local width = element.width or element.size or 16
	local height = element.height or element.size or 16
	local sizeX = width + (element.spacingX or element.spacing or 0)
	local sizeY = height + (element.spacingY or element.spacing or 0)
	local anchor = element.initialAnchor or 'BOTTOMLEFT'
	local growthX = (element.growthX == 'LEFT' and -1) or 1
	local growthY = (element.growthY == 'DOWN' and -1) or 1
	local cols = element.maxCols or math.floor(element:GetWidth() / sizeX + 0.5)

	for i = from, to do
		local button = element[i]
		if(not button) then break end

		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		-- Avoid secure aura button anchor mutations in combat.
		-- Allow explicit opt-in for non-secure buttons.
		if(CanMutateButtonInCombat(element, button)) then
			button:ClearAllPoints()
			button:SetPoint(anchor, element, anchor, col * sizeX * growthX, row * sizeY * growthY)
		end
	end
end

local function updateAura(element, unit, data, position)
	if(not data) then return end

	local button = element[position]
	if(not button) then
		--[[ Override: Auras:CreateButton(position)
		Used to create an aura button at a given position.

		* self     - the widget holding the aura buttons
		* position - the position at which the aura button is to be created (number)

		## Returns

		* button - the button used to represent the aura (Button)
		--]]
		button = (element.CreateButton or CreateButton) (element, position)

		table.insert(element, button)
		element.createdButtons = element.createdButtons + 1
	end

	local auraInstanceID = data.auraInstanceID

	-- for tooltips
	button.auraInstanceID = auraInstanceID
	button.isHarmfulAura = data.isHarmfulAura and true or false
	button.isHarmful = button.isHarmfulAura
	button.filter = button.isHarmfulAura and "HARMFUL" or "HELPFUL"

	if(button.Cooldown and not element.disableCooldown) then
		local expiration = IsSafeNumber(data.expirationTime) and data.expirationTime or nil
		local duration = IsSafeNumber(data.duration) and data.duration or nil
		local cooldownKey
		if(IsSafeKey(auraInstanceID)) then
			cooldownKey = tostring(auraInstanceID) .. ":" .. tostring(expiration) .. ":" .. tostring(duration)
		end

		if((not cooldownKey) or button.__AzeriteUI_CooldownKey ~= cooldownKey) then
			if(button.Cooldown.SetAuraFallbackData) then
				button.Cooldown:SetAuraFallbackData(expiration, duration)
			end

			local applied = false
			local _okDur, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
			if(not _okDur) then durationObject = nil end
			if(durationObject and button.Cooldown.SetCooldownFromDurationObject) then
				button.Cooldown:SetCooldownFromDurationObject(durationObject)
				applied = true
			end
			if((not applied) and button.Cooldown.SetCooldown and expiration and duration and duration > 0) then
				button.Cooldown:SetCooldown(expiration - duration, duration)
				applied = true
			end
			SetShown(button.Cooldown, applied or false)
			button.__AzeriteUI_CooldownKey = cooldownKey
		end
	end

	if(button.Overlay) then
		if(element.showType or (data.isHarmfulAura and element.showDebuffType) or (not data.isHarmfulAura and element.showBuffType)) then
			local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, element.dispelColorCurve)
			if(color) then button.Overlay:SetVertexColor(color:GetRGBA()) end
			SetShown(button.Overlay, true)
		else
			SetShown(button.Overlay, false)
		end
	end

	if(button.Stealable) then
		local alpha = 0
		if(element.showStealableBuffs and not UnitCanCooperate('player', unit)) then
			alpha = (IsSafeKey(data.isStealable) and data.isStealable) and 1 or 0
		end
		if(button.__AzeriteUI_StealableAlpha ~= alpha) then
			button.Stealable:SetAlpha(alpha)
			button.__AzeriteUI_StealableAlpha = alpha
		end
	end

	if(button.Icon and ((not IsSafeKey(data.icon)) or button.__AzeriteUI_Icon ~= data.icon)) then
		button.Icon:SetTexture(data.icon)
		button.__AzeriteUI_Icon = IsSafeKey(data.icon) and data.icon or nil
	end
	if(button.Count) then
		local minCount = element.minCount or 2
		local maxCount = element.maxCount or 999
		local countKey
		if(IsSafeKey(auraInstanceID) and IsSafeKey(data.applications)) then
			countKey = tostring(auraInstanceID) .. ":" .. tostring(data.applications) .. ":" .. tostring(minCount) .. ":" .. tostring(maxCount)
		end
		local skipCount = countKey and button.__AzeriteUI_CountKey == countKey
		local wroteCount = false

		if(not skipCount) then
			local _okCnt, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, minCount, maxCount)
			if(_okCnt and displayCount ~= nil) then
				-- Pass directly to SetText. WoW 12 allows SetText(secretValue) for native display;
				-- only comparisons or arithmetic on secret values would crash. This path handles
				-- both safe strings and secret strings (in-combat stack counts) correctly.
				button.Count:SetText(displayCount)
				button.__AzeriteUI_CountKey = countKey
				wroteCount = true
			end
		end

		if((not wroteCount) and (not skipCount) and IsSafeNumber(data.applications)) then
			if(data.applications >= minCount) then
				if(data.applications > maxCount) then
					button.Count:SetText('*')
				else
					button.Count:SetText(data.applications)
				end
				wroteCount = true
			else
				button.Count:SetText('')
				wroteCount = true
			end
			button.__AzeriteUI_CountKey = countKey
		end
	end

	local width = element.width or element.size or 16
	local height = element.height or element.size or 16
	-- Avoid secure aura button protected mutations in combat.
	-- Allow explicit opt-in for non-secure buttons.
	if(CanMutateButtonInCombat(element, button)) then
		if(button.__AzeriteUI_Width ~= width or button.__AzeriteUI_Height ~= height) then
			button:SetSize(width, height)
			button.__AzeriteUI_Width = width
			button.__AzeriteUI_Height = height
		end
		local enableMouse = not element.disableMouse
		if(button.__AzeriteUI_EnableMouse ~= enableMouse) then
			button:EnableMouse(enableMouse)
			button.__AzeriteUI_EnableMouse = enableMouse
		end
		SetShown(button, true)
	elseif(not button:IsShown()) then
		pcall(button.Show, button)
	end

	--[[ Callback: Auras:PostUpdateButton(unit, button, data, position)
	Called after the aura button has been updated.

	* self     - the widget holding the aura buttons
	* button   - the updated aura button (Button)
	* unit     - the unit for which the update has been triggered (string)
	* data     - the [AuraData](https://warcraft.wiki.gg/wiki/Struct_AuraData) object (table)
	* position - the actual position of the aura button (number)
	--]]
	if(element.PostUpdateButton) then
		element:PostUpdateButton(button, unit, data, position)
	end
end

local function FilterAura(element, unit, data)
	if((element.onlyShowPlayer and data.isPlayerAura) or not element.onlyShowPlayer) then
		return true
	end
end

-- see AuraUtil.DefaultAuraCompare
local function SortAuras(a, b)
	if(a.isPlayerAura ~= b.isPlayerAura) then
		return a.isPlayerAura
	end

	return a.auraInstanceID < b.auraInstanceID
end

local function processData(element, unit, data, filter)
	if(not data) then return end

	local _ok, _filtered = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, data.auraInstanceID, filter .. '|PLAYER')
	data.isPlayerAura = _ok and not _filtered or false
	data.isHarmfulAura = filter == 'HARMFUL' -- "isHarmful" is a secret, use a different name

	--[[ Callback: Auras:PostProcessAuraData(unit, data, filter)
	Called after the aura data has been processed.

	* self   - the widget holding the aura buttons
	* unit   - the unit for which the update has been triggered (string)
	* data   - [AuraData](https://warcraft.wiki.gg/wiki/Struct_AuraData) object (table)
	* filter - the aura filter for this aura type
	## Returns

	* data - the processed aura data (table)
	--]]
	if(element.PostProcessAuraData) then
		data = element:PostProcessAuraData(unit, data, filter)
	end

	return data
end

local function AddAuraData(targetAll, targetActive, element, unit, data, filter)
	data = processData(element, unit, data, filter)
	if(not data or not data.auraInstanceID) then
		return false
	end

	targetAll[data.auraInstanceID] = data
	if((element.FilterAura or FilterAura) (element, unit, data, filter)) then
		targetActive[data.auraInstanceID] = true
		return true
	end

	return false
end

local function UpdateAuras(self, event, unit, updateInfo)
	if(self.unit ~= unit) then return end

	local isFullUpdate = not updateInfo or updateInfo.isFullUpdate

	local auras = self.Auras
	if(auras) then
		isFullUpdate = auras.needFullUpdate or isFullUpdate
		auras.needFullUpdate = false

		--[[ Callback: Auras:PreUpdate(unit, isFullUpdate)
		Called before the element has been updated.

		* self         - the widget holding the aura buttons
		* unit         - the unit for which the update has been triggered (string)
		* isFullUpdate - indicates whether the element is performing a full update (boolean)
		--]]
		if(auras.PreUpdate) then auras:PreUpdate(unit, isFullUpdate) end

		local buffsChanged = false
		local numBuffs = auras.numBuffs or 32
		local buffFilter = auras.buffFilter or auras.filter or 'HELPFUL'
		if(type(buffFilter) == 'function') then
			buffFilter = buffFilter(auras, unit)
		end

		local debuffsChanged = false
		local numDebuffs = auras.numDebuffs or 40
		local debuffFilter = auras.debuffFilter or auras.filter or 'HARMFUL'
		if(type(debuffFilter) == 'function') then
			debuffFilter = debuffFilter(auras, unit)
		end

		local numTotal = auras.numTotal or numBuffs + numDebuffs
		auras.sortedBuffs = auras.sortedBuffs or {}
		auras.sortedDebuffs = auras.sortedDebuffs or {}

		if(isFullUpdate) then
			auras.allBuffs = table.wipe(auras.allBuffs or {})
			auras.activeBuffs = table.wipe(auras.activeBuffs or {})
			buffsChanged = true

			ForEachFullAuraData(unit, buffFilter, function(data)
				--[[ Override: Auras:FilterAura(unit, data, filter)
				Defines a custom filter that controls if the aura button should be shown.

				* self   - the widget holding the aura buttons
				* unit   - the unit for which the update has been triggered (string)
				* data   - [AuraData](https://warcraft.wiki.gg/wiki/Struct_AuraData) object (table)
				* filter - the aura filter for this aura type

				## Returns

				* show - indicates whether the aura button should be shown (boolean)
				--]]
				AddAuraData(auras.allBuffs, auras.activeBuffs, auras, unit, data, buffFilter)
			end)

			auras.allDebuffs = table.wipe(auras.allDebuffs or {})
			auras.activeDebuffs = table.wipe(auras.activeDebuffs or {})
			debuffsChanged = true

			ForEachFullAuraData(unit, debuffFilter, function(data)
				AddAuraData(auras.allDebuffs, auras.activeDebuffs, auras, unit, data, debuffFilter)
			end)
		else
			if(updateInfo.addedAuras) then
				for _, data in next, updateInfo.addedAuras do
					if(not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, buffFilter)) then
						if(AddAuraData(auras.allBuffs, auras.activeBuffs, auras, unit, data, buffFilter)) then
							buffsChanged = true
						end
					elseif(not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, data.auraInstanceID, debuffFilter)) then
						if(AddAuraData(auras.allDebuffs, auras.activeDebuffs, auras, unit, data, debuffFilter)) then
							debuffsChanged = true
						end
					end
				end
			end

			if(updateInfo.updatedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.updatedAuraInstanceIDs do
					if(auras.allBuffs[auraInstanceID]) then
						local refreshed = processData(auras, unit, C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID), buffFilter)
						if(refreshed and refreshed.auraInstanceID) then
							auras.allBuffs[auraInstanceID] = refreshed
						end
						-- Keep previous valid data when refresh is transiently nil (e.g. during stack increments).
						-- Explicit removal is handled by removedAuraInstanceIDs only.
						if(auras.activeBuffs[auraInstanceID]) then
							auras.activeBuffs[auraInstanceID] = true
							buffsChanged = true
						end
					elseif(auras.allDebuffs[auraInstanceID]) then
						local refreshed = processData(auras, unit, C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID), debuffFilter)
						if(refreshed and refreshed.auraInstanceID) then
							auras.allDebuffs[auraInstanceID] = refreshed
						end
						-- Keep previous valid data when refresh is transiently nil.
						if(auras.activeDebuffs[auraInstanceID]) then
							auras.activeDebuffs[auraInstanceID] = true
							debuffsChanged = true
						end
					end
				end
				if(not buffsChanged and not debuffsChanged and next(updateInfo.updatedAuraInstanceIDs)) then
					buffsChanged = true
					debuffsChanged = true
				end
			end

			if(updateInfo.removedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.removedAuraInstanceIDs do
					if(auras.allBuffs[auraInstanceID]) then
						auras.allBuffs[auraInstanceID] = nil

						if(auras.activeBuffs[auraInstanceID]) then
							auras.activeBuffs[auraInstanceID] = nil
							buffsChanged = true
						end
					elseif(auras.allDebuffs[auraInstanceID]) then
						auras.allDebuffs[auraInstanceID] = nil

						if(auras.activeDebuffs[auraInstanceID]) then
							auras.activeDebuffs[auraInstanceID] = nil
							debuffsChanged = true
						end
					end
				end
			end
		end

		--[[ Callback: Auras:PostUpdateInfo(unit, buffsChanged, debuffsChanged)
		Called after the aura update info has been updated and filtered, but before sorting.

		* self           - the widget holding the aura buttons
		* unit           - the unit for which the update has been triggered (string)
		* buffsChanged   - indicates whether the buff info has changed (boolean)
		* debuffsChanged - indicates whether the debuff info has changed (boolean)
		--]]
		if(auras.PostUpdateInfo) then
			auras:PostUpdateInfo(unit, buffsChanged, debuffsChanged)
		end

		if(buffsChanged or debuffsChanged) then
			local numVisible

			if(buffsChanged) then
				-- instead of removing auras one by one, just wipe the tables entirely
				-- and repopulate them, multiple table.remove calls are insanely slow
				auras.sortedBuffs = table.wipe(auras.sortedBuffs or {})

				for auraInstanceID in next, auras.activeBuffs do
					local data = auras.allBuffs[auraInstanceID]
					if(data) then
						table.insert(auras.sortedBuffs, data)
					else
						auras.activeBuffs[auraInstanceID] = nil
					end
				end

				--[[ Override: Auras:SortBuffs(a, b)
				Defines a custom sorting algorithm for ordering the auras.

				Defaults to [AuraUtil.DefaultAuraCompare](https://github.com/Gethe/wow-ui-source/search?q=symbol:DefaultAuraCompare).
				--]]
				--[[ Override: Auras:SortAuras(a, b)
				Defines a custom sorting algorithm for ordering the auras.

				Defaults to [AuraUtil.DefaultAuraCompare](https://github.com/Gethe/wow-ui-source/search?q=symbol:DefaultAuraCompare).

				Overridden by the more specific SortBuffs and/or SortDebuffs overrides if they are defined.
				--]]
				table.sort(auras.sortedBuffs, auras.SortBuffs or auras.SortAuras or SortAuras)

				numVisible = math.min(numBuffs, numTotal, #auras.sortedBuffs)

				for i = 1, numVisible do
					updateAura(auras, unit, auras.sortedBuffs[i], i)
				end
			else
				numVisible = math.min(numBuffs, numTotal, #auras.sortedBuffs)
			end

			-- do it before adding the gap because numDebuffs could end up being 0
			if(debuffsChanged) then
				auras.sortedDebuffs = table.wipe(auras.sortedDebuffs or {})

				for auraInstanceID in next, auras.activeDebuffs do
					local data = auras.allDebuffs[auraInstanceID]
					if(data) then
						table.insert(auras.sortedDebuffs, data)
					else
						auras.activeDebuffs[auraInstanceID] = nil
					end
				end

				--[[ Override: Auras:SortDebuffs(a, b)
				Defines a custom sorting algorithm for ordering the auras.

				Defaults to [AuraUtil.DefaultAuraCompare](https://github.com/Gethe/wow-ui-source/search?q=symbol:DefaultAuraCompare).
				--]]
				table.sort(auras.sortedDebuffs, auras.SortDebuffs or auras.SortAuras or SortAuras)
			end

			numDebuffs = math.min(numDebuffs, numTotal - numVisible, #auras.sortedDebuffs)

			if(auras.gap and numVisible > 0 and numDebuffs > 0) then
				-- adjust the number of visible debuffs if there's an overflow
				if(numVisible + numDebuffs == numTotal) then
					numDebuffs = numDebuffs - 1
				end

				-- double check and skip it if we end up with 0 after the adjustment
				if(numDebuffs > 0) then
					numVisible = numVisible + 1

					local button = auras[numVisible]
					if(not button) then
						button = (auras.CreateButton or CreateButton) (auras, numVisible)
						table.insert(auras, button)
						auras.createdButtons = auras.createdButtons + 1
					end

					-- prevent the button from displaying anything
					if(button.Cooldown) then button.Cooldown:Hide() end
					if(button.Icon) then button.Icon:SetTexture() end
					if(button.Overlay) then button.Overlay:Hide() end
					if(button.Stealable) then button.Stealable:Hide() end
					if(button.Count) then button.Count:SetText() end

					if(CanMutateButtonInCombat(auras, button)) then
						button:EnableMouse(false)
						button:Show()
					elseif(not button:IsShown()) then
						pcall(button.Show, button)
					end

					--[[ Callback: Auras:PostUpdateGapButton(unit, gapButton, position)
					Called after an invisible aura button has been created. Only used by Auras when the `gap` option is enabled.

					* self      - the widget holding the aura buttons
					* unit      - the unit that has the invisible aura button (string)
					* gapButton - the invisible aura button (Button)
					* position  - the position of the invisible aura button (number)
					--]]
					if(auras.PostUpdateGapButton) then
						auras:PostUpdateGapButton(unit, button, numVisible)
					end
				end
			end

			-- any changes to buffs will affect debuffs, so just redraw them even if nothing changed
			for i = 1, numDebuffs do
				updateAura(auras, unit, auras.sortedDebuffs[i], numVisible + i)
			end

			numVisible = numVisible + numDebuffs
			local visibleChanged = false

			if(numVisible ~= auras.visibleButtons) then
				auras.visibleButtons = numVisible
				visibleChanged = auras.reanchorIfVisibleChanged -- more convenient than auras.reanchorIfVisibleChanged and visibleChanged
			end

			for i = numVisible + 1, #auras do
				auras[i]:Hide()
			end

			if(visibleChanged or auras.createdButtons > auras.anchoredButtons) then
				--[[ Override: Auras:SetPosition(from, to)
				Used to (re-)anchor the aura buttons.
				Called when new aura buttons have been created or the number of visible buttons has changed if the
				`.reanchorIfVisibleChanged` option is enabled.

				* self - the widget that holds the aura buttons
				* from - the offset of the first aura button to be (re-)anchored (number)
				* to   - the offset of the last aura button to be (re-)anchored (number)
				--]]
				if(visibleChanged) then
					-- this is useful for when people might want centred auras, like nameplates
					(auras.SetPosition or SetPosition) (auras, 1, numVisible)
				else
					(auras.SetPosition or SetPosition) (auras, auras.anchoredButtons + 1, auras.createdButtons)
					auras.anchoredButtons = auras.createdButtons
				end
			end

			--[[ Callback: Auras:PostUpdate(unit)
			Called after the element has been updated.

			* self - the widget holding the aura buttons
			* unit - the unit for which the update has been triggered (string)
			--]]
			if(auras.PostUpdate) then auras:PostUpdate(unit) end
		end
	end

	local buffs = self.Buffs
	if(buffs) then
		isFullUpdate = buffs.needFullUpdate or isFullUpdate
		buffs.needFullUpdate = false

		if(buffs.PreUpdate) then buffs:PreUpdate(unit, isFullUpdate) end

		local buffsChanged = false
		local numBuffs = buffs.num or 32
		local buffFilter = buffs.filter or 'HELPFUL'
		if(type(buffFilter) == 'function') then
			buffFilter = buffFilter(buffs, unit)
		end

		if(isFullUpdate) then
			buffs.all = table.wipe(buffs.all or {})
			buffs.active = table.wipe(buffs.active or {})
			buffsChanged = true

			ForEachFullAuraData(unit, buffFilter, function(auraData)
				local data = processData(buffs, unit, auraData, buffFilter)
				if(data and data.auraInstanceID) then
					buffs.all[data.auraInstanceID] = data

					if((buffs.FilterAura or FilterAura) (buffs, unit, data, buffFilter)) then
						buffs.active[data.auraInstanceID] = true
					end
				end
			end)
		else
			if(updateInfo.addedAuras) then
				for _, data in next, updateInfo.addedAuras do
					local _okF, _filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, data.auraInstanceID, buffFilter)
					if(_okF and not _filteredOut) then
						local processed = processData(buffs, unit, data, buffFilter)
						if(processed and processed.auraInstanceID) then
							buffs.all[data.auraInstanceID] = processed
						end

						if(processed and (buffs.FilterAura or FilterAura) (buffs, unit, processed, buffFilter)) then
							buffs.active[data.auraInstanceID] = true
							buffsChanged = true
						end
					end
				end
			end

			if(updateInfo.updatedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.updatedAuraInstanceIDs do
					if(buffs.all[auraInstanceID]) then
						local refreshed = processData(buffs, unit, C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID), buffFilter)
						if(refreshed and refreshed.auraInstanceID) then
							buffs.all[auraInstanceID] = refreshed
						end

						if((not refreshed) and buffs.active[auraInstanceID]) then
							-- Keep previous valid aura data until explicit removal.
							buffsChanged = true
						elseif(buffs.active[auraInstanceID]) then
							buffs.active[auraInstanceID] = true
							buffsChanged = true
						end
					end
				end
				if(not buffsChanged and next(updateInfo.updatedAuraInstanceIDs)) then
					buffsChanged = true
				end
			end

			if(updateInfo.removedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.removedAuraInstanceIDs do
					if(buffs.all[auraInstanceID]) then
						buffs.all[auraInstanceID] = nil

						if(buffs.active[auraInstanceID]) then
							buffs.active[auraInstanceID] = nil
							buffsChanged = true
						end
					end
				end
			end
		end

		if(buffs.PostUpdateInfo) then
			buffs:PostUpdateInfo(unit, buffsChanged)
		end

		if(buffsChanged) then
			buffs.sorted = table.wipe(buffs.sorted or {})

			for auraInstanceID in next, buffs.active do
				table.insert(buffs.sorted, buffs.all[auraInstanceID])
			end

			table.sort(buffs.sorted, buffs.SortBuffs or buffs.SortAuras or SortAuras)

			local numVisible = math.min(numBuffs, #buffs.sorted)

			for i = 1, numVisible do
				updateAura(buffs, unit, buffs.sorted[i], i)
			end

			local visibleChanged = false

			if(numVisible ~= buffs.visibleButtons) then
				buffs.visibleButtons = numVisible
				visibleChanged = buffs.reanchorIfVisibleChanged
			end

			for i = numVisible + 1, #buffs do
				buffs[i]:Hide()
			end

			if(visibleChanged or buffs.createdButtons > buffs.anchoredButtons) then
				if(visibleChanged) then
					(buffs.SetPosition or SetPosition) (buffs, 1, numVisible)
				else
					(buffs.SetPosition or SetPosition) (buffs, buffs.anchoredButtons + 1, buffs.createdButtons)
					buffs.anchoredButtons = buffs.createdButtons
				end
			end

			if(buffs.PostUpdate) then buffs:PostUpdate(unit) end
		end
	end

	local debuffs = self.Debuffs
	if(debuffs) then
		isFullUpdate = debuffs.needFullUpdate or isFullUpdate
		debuffs.needFullUpdate = false

		if(debuffs.PreUpdate) then debuffs:PreUpdate(unit, isFullUpdate) end

		local debuffsChanged = false
		local numDebuffs = debuffs.num or 40
		local debuffFilter = debuffs.filter or 'HARMFUL'
		if(type(debuffFilter) == 'function') then
			debuffFilter = debuffFilter(debuffs, unit)
		end

		if(isFullUpdate) then
			debuffs.all = table.wipe(debuffs.all or {})
			debuffs.active = table.wipe(debuffs.active or {})
			debuffsChanged = true
			local scannedDebuffs = 0

			ForEachFullAuraData(unit, debuffFilter, function(auraData)
				scannedDebuffs = scannedDebuffs + 1
				local data = processData(debuffs, unit, auraData, debuffFilter)
				if(data and data.auraInstanceID) then
					debuffs.all[data.auraInstanceID] = data
					if((debuffs.FilterAura or FilterAura) (debuffs, unit, data, debuffFilter)) then
						debuffs.active[data.auraInstanceID] = true
					end
				end
			end)

			-- Retail WoW 12 edge case:
			-- Direct full scans with "HARMFUL" can return 0 on player right after reload,
			-- while harmful auras still exist. Fallback by scanning unfiltered indices and
			-- re-checking each aura against HARMFUL instance filtering.
			if(unit == 'player' and debuffFilter == 'HARMFUL' and scannedDebuffs == 0) then
				for index = 1, MAX_AURA_INDEX_SCAN do
					local auraData = GetAuraDataByIndexSafe(unit, index)
					if(not auraData) then
						break
					end

					local auraInstanceID = auraData.auraInstanceID
					local filteredOut = IsAuraFilteredOutByInstanceIDSafe(unit, auraInstanceID, 'HARMFUL')
					if(filteredOut == false) then
						scannedDebuffs = scannedDebuffs + 1
						local data = processData(debuffs, unit, auraData, debuffFilter)
						if(data and data.auraInstanceID) then
							debuffs.all[data.auraInstanceID] = data
							if((debuffs.FilterAura or FilterAura) (debuffs, unit, data, debuffFilter)) then
								debuffs.active[data.auraInstanceID] = true
							end
						end
					end
				end
			end

		else
			if(updateInfo.addedAuras) then
				for _, data in next, updateInfo.addedAuras do
					local _okF, _filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, data.auraInstanceID, debuffFilter)
					if(_okF and not _filteredOut) then
						local processed = processData(debuffs, unit, data, debuffFilter)
						if(processed and processed.auraInstanceID) then
							debuffs.all[data.auraInstanceID] = processed
						end

						if(processed and (debuffs.FilterAura or FilterAura) (debuffs, unit, processed, debuffFilter)) then
							debuffs.active[data.auraInstanceID] = true
							debuffsChanged = true
						end
					end
				end
			end

			if(updateInfo.updatedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.updatedAuraInstanceIDs do
					if(debuffs.all[auraInstanceID]) then
						local refreshed = processData(debuffs, unit, C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID), debuffFilter)
						if(refreshed and refreshed.auraInstanceID) then
							debuffs.all[auraInstanceID] = refreshed
						end

						if((not refreshed) and debuffs.active[auraInstanceID]) then
							-- Keep previous valid aura data until explicit removal.
							debuffsChanged = true
						elseif(debuffs.active[auraInstanceID]) then
							debuffs.active[auraInstanceID] = true
							debuffsChanged = true
						end
					end
				end
				if(not debuffsChanged and next(updateInfo.updatedAuraInstanceIDs)) then
					debuffsChanged = true
				end
			end

			if(updateInfo.removedAuraInstanceIDs) then
				for _, auraInstanceID in next, updateInfo.removedAuraInstanceIDs do
					if(debuffs.all[auraInstanceID]) then


						if(debuffs.active[auraInstanceID]) then
							debuffs.active[auraInstanceID] = nil
							debuffsChanged = true
						end
					end
				end
			end
		end

		if(debuffs.PostUpdateInfo) then
			debuffs:PostUpdateInfo(unit, debuffsChanged)
		end

		if(debuffsChanged) then
			debuffs.sorted = table.wipe(debuffs.sorted or {})

			for auraInstanceID in next, debuffs.active do
				table.insert(debuffs.sorted, debuffs.all[auraInstanceID])
			end

			table.sort(debuffs.sorted, debuffs.SortDebuffs or debuffs.SortAuras or SortAuras)

			local numVisible = math.min(numDebuffs, #debuffs.sorted)

			for i = 1, numVisible do
				updateAura(debuffs, unit, debuffs.sorted[i], i)
			end

			local visibleChanged = false

			if(numVisible ~= debuffs.visibleButtons) then
				debuffs.visibleButtons = numVisible
				visibleChanged = debuffs.reanchorIfVisibleChanged
			end

			for i = numVisible + 1, #debuffs do
				debuffs[i]:Hide()
			end

			if(visibleChanged or debuffs.createdButtons > debuffs.anchoredButtons) then
				if(visibleChanged) then
					(debuffs.SetPosition or SetPosition) (debuffs, 1, numVisible)
				else
					(debuffs.SetPosition or SetPosition) (debuffs, debuffs.anchoredButtons + 1, debuffs.createdButtons)
					debuffs.anchoredButtons = debuffs.createdButtons
				end
			end

			if(debuffs.PostUpdate) then debuffs:PostUpdate(unit) end
		end
	end
end

local function Update(self, event, unit, updateInfo)
	if(self.unit ~= unit) then return end

	UpdateAuras(self, event, unit, updateInfo)

	-- Assume no event means someone wants to re-anchor things. This is usually
	-- done by UpdateAllElements and :ForceUpdate.
	if(event == 'ForceUpdate' or not event) then
		local auras = self.Auras
		if(auras) then
			(auras.SetPosition or SetPosition) (auras, 1, auras.createdButtons)
		end

		local buffs = self.Buffs
		if(buffs) then
			(buffs.SetPosition or SetPosition) (buffs, 1, buffs.createdButtons)
		end

		local debuffs = self.Debuffs
		if(debuffs) then
			(debuffs.SetPosition or SetPosition) (debuffs, 1, debuffs.createdButtons)
		end
	end
end

local function ForceUpdate(element)
	return Update(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self)
	if(self.Auras or self.Buffs or self.Debuffs) then
		self:RegisterEvent('UNIT_AURA', UpdateAuras)

		local auras = self.Auras
		if(auras) then
			auras.__owner = self
			-- check if there's any anchoring restrictions
			auras.__restricted = not pcall(self.GetCenter, self)
			auras.ForceUpdate = ForceUpdate

			auras.createdButtons = auras.createdButtons or 0
			auras.anchoredButtons = 0
			auras.visibleButtons = 0
			auras.tooltipAnchor = auras.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'
			auras.needFullUpdate = true

			if(not auras.dispelColorCurve) then
				local dispelColors = (self.colors and self.colors.dispel) or (oUF.colors and oUF.colors.dispel) or {}
				auras.dispelColorCurve = C_CurveUtil.CreateColorCurve()
				auras.dispelColorCurve:SetType(Enum.LuaCurveType.Step)
				for _, dispelIndex in next, oUF.Enum.DispelType do
					if(dispelColors[dispelIndex]) then
						auras.dispelColorCurve:AddPoint(dispelIndex, dispelColors[dispelIndex])
					end
				end
			end

			auras:Show()
		end

		local buffs = self.Buffs
		if(buffs) then
			buffs.__owner = self
			-- check if there's any anchoring restrictions
			buffs.__restricted = not pcall(self.GetCenter, self)
			buffs.ForceUpdate = ForceUpdate

			buffs.createdButtons = buffs.createdButtons or 0
			buffs.anchoredButtons = 0
			buffs.visibleButtons = 0
			buffs.tooltipAnchor = buffs.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'
			buffs.needFullUpdate = true

			if(not buffs.dispelColorCurve) then
				buffs.dispelColorCurve = C_CurveUtil.CreateColorCurve()
				buffs.dispelColorCurve:SetType(Enum.LuaCurveType.Step)
				for _, dispelIndex in next, oUF.Enum.DispelType do
					if(self.colors.dispel[dispelIndex]) then
						buffs.dispelColorCurve:AddPoint(dispelIndex, self.colors.dispel[dispelIndex])
					end
				end
			end

			buffs:Show()
		end

		local debuffs = self.Debuffs
		if(debuffs) then
			debuffs.__owner = self
			-- check if there's any anchoring restrictions
			debuffs.__restricted = not pcall(self.GetCenter, self)
			debuffs.ForceUpdate = ForceUpdate

			debuffs.createdButtons = debuffs.createdButtons or 0
			debuffs.anchoredButtons = 0
			debuffs.visibleButtons = 0
			debuffs.tooltipAnchor = debuffs.tooltipAnchor or 'ANCHOR_BOTTOMRIGHT'
			debuffs.needFullUpdate = true

			if(not debuffs.dispelColorCurve) then
				debuffs.dispelColorCurve = C_CurveUtil.CreateColorCurve()
				debuffs.dispelColorCurve:SetType(Enum.LuaCurveType.Step)
				for _, dispelIndex in next, oUF.Enum.DispelType do
					if(self.colors.dispel[dispelIndex]) then
						debuffs.dispelColorCurve:AddPoint(dispelIndex, self.colors.dispel[dispelIndex])
					end
				end
			end

			debuffs:Show()
		end

		return true
	end
end

local function Disable(self)
	if(self.Auras or self.Buffs or self.Debuffs) then
		self:UnregisterEvent('UNIT_AURA', UpdateAuras)

		if(self.Auras) then self.Auras:Hide() end
		if(self.Buffs) then self.Buffs:Hide() end
		if(self.Debuffs) then self.Debuffs:Hide() end
	end
end

oUF:AddElement('Auras', Update, Enable, Disable)

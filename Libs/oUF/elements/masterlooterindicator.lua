--[[
# Element: Master Looter Indicator

Handles the visibility and updating of an indicator for the unit's master looter status.

## Widget

MasterLooterIndicator - Any UI widget.

## Notes

A default texture will be applied if the widget is a Texture and doesn't have a texture or a color set.
Only WoW Forever has master loot; on Retail the element does not enable.

## Examples

    -- Position and size
    local MasterLooterIndicator = self:CreateTexture(nil, 'OVERLAY')
    MasterLooterIndicator:SetSize(16, 16)
    MasterLooterIndicator:SetPoint('TOPRIGHT', self)

    -- Register it with oUF
    self.MasterLooterIndicator = MasterLooterIndicator
--]]

-- AzeriteUI: ported from upstream oUF 14 (elements/masterlooterindicator.lua) for
-- Forever. Private.unitIsUnit and GameVersion.Forever are upstream-only; this copy
-- uses UnitIsUnit, ns.IsForever and our oUF's unitless-event flag. PostUpdate also
-- passes the shown state, which RaidLarge.lua's anchoring reads.

local _, ns = ...
local oUF = ns.oUF

local function Update(self, event)
	local element = self.MasterLooterIndicator
	local unit = self.unit

	--[[ Callback: MasterLooterIndicator:PreUpdate()
	Called before the element has been updated.

	* self - the MasterLooterIndicator element
	--]]
	if(element.PreUpdate) then
		element:PreUpdate()
	end

	local shouldShow = false
	if(unit and (UnitInParty(unit) or UnitInRaid(unit) ~= nil)) then
		local method, partyIndex, raidIndex = C_PartyInfo.GetLootMethod()
		if(method == Enum.LootMethod.Masterlooter) then
			local looterUnit
			if(partyIndex) then
				if(partyIndex == 0) then
					looterUnit = 'player'
				else
					looterUnit = 'party' .. partyIndex
				end
			elseif(raidIndex) then
				looterUnit = 'raid' .. raidIndex
			end

			shouldShow = looterUnit and UnitIsUnit(unit, looterUnit) and true or false
		end
	end

	element:SetShown(shouldShow)

	--[[ Callback: MasterLooterIndicator:PostUpdate(isShown)
	Called after the element has been updated.

	* self    - the MasterLooterIndicator element
	* isShown - whether the unit is the master looter (boolean)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(shouldShow)
	end
end

local function Path(self, ...)
	--[[ Override: MasterLooterIndicator.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	return (self.MasterLooterIndicator.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate')
end

local function Disable(self)
	local element = self.MasterLooterIndicator
	if(element) then
		element:Hide()

		self:UnregisterEvent('PARTY_LOOT_METHOD_CHANGED', Path)
		self:UnregisterEvent('GROUP_ROSTER_UPDATE', Path)
	end
end

local function Enable(self)
	local element = self.MasterLooterIndicator
	if(not element) then return end

	if(not ns.IsForever or not (C_PartyInfo and C_PartyInfo.GetLootMethod)
		or not (Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter)) then
		element:Hide()
		return false
	end

	element.__owner = self
	element.ForceUpdate = ForceUpdate

	self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', Path, true)
	self:RegisterEvent('GROUP_ROSTER_UPDATE', Path, true)

	if(element:IsObjectType('Texture') and not element:GetTexture()) then
		element:SetTexture([[Interface\GroupFrame\UI-Group-MasterLooter]])
	end

	return true
end

oUF:AddElement('MasterLooterIndicator', Path, Enable, Disable)

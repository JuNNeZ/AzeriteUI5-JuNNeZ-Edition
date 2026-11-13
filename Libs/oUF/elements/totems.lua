--[[
# Element: Totem Indicator

Handles the updating and visibility of totems.

## Widget

Totems - A `table` to hold sub-widgets.

## Sub-Widgets

Totem - Any UI widget.

## Sub-Widget Options

.Icon     - A `Texture` representing the totem icon.
.Cooldown - A `Cooldown` representing the duration of the totem.

## Notes

OnEnter and OnLeave script handlers will be set to display a Tooltip if the `Totem` widget is mouse enabled.

## Examples

    local Totems = {}
    for index = 1, 4 do
        -- Position and size of the totem indicator
        local Totem = CreateFrame('Button', nil, self)
        Totem:SetSize(40, 40)
        Totem:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', index * Totem:GetWidth(), 0)

        local Icon = Totem:CreateTexture(nil, 'OVERLAY')
        Icon:SetAllPoints()

        local Cooldown = CreateFrame('Cooldown', nil, Totem, 'CooldownFrameTemplate')
        Cooldown:SetAllPoints()

        Totem.Icon = Icon
        Totem.Cooldown = Cooldown

        Totems[index] = Totem
    end

    -- Register with oUF
    self.Totems = Totems
--]]

local _, ns = ...
local oUF = ns.oUF

local TOTEM_PRIORITIES = _G.STANDARD_TOTEM_PRIORITIES
if(UnitClassBase('player') == 'SHAMAN') then
	TOTEM_PRIORITIES = _G.SHAMAN_TOTEM_PRIORITIES
end

local function UpdateTooltip(self)
	GameTooltip:SetTotem(self:GetID())
end

local function OnEnter(self)
	if(GameTooltip:IsForbidden() or not self:IsVisible()) then return end

	GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMRIGHT')
	self:UpdateTooltip()
end

local function OnLeave()
	if(GameTooltip:IsForbidden()) then return end

	GameTooltip:Hide()
end

-- AzeriteUI: Blizzard's own pooled totem buttons, read after its TotemFrame:Update
-- (GW2_UI Games/Shared/Mainbar/totemBar.lua does the same). In combat GetTotemInfo is
-- SecretWhenTotemSlotSecret, so this element cannot tell a timerless taken slot from a
-- live one. Blizzard's untainted TotemFrameMixin:Update can: it acquires a button for
-- each slot with haveTotem and shows it only while duration > 0
-- (Blizzard_UnitFrame/Mainline/TotemFrame.lua, identical on Forever). TotemFrame stays
-- hidden with the PlayerFrame oUF reparents, but it still runs. We only read the pool
-- and the buttons from a post-hook and never write to them. totemPool is Blizzard's secure
-- pool proxy on both clients (Pools.lua: CreateFramePool = CreateSecureFramePool), so
-- EnumerateActive walks a SecureMap through securecallfunction; it is shared with addon
-- code by design (GW2_UI makes the same call). FixLog 2026-11-13.
local pooledHas = {}     -- [slot] = true when Blizzard holds an active button for it
local pooledShown = {}   -- [slot] = that button's IsShown() (may be secret: widget setters only)
local pooledKnown = false
local pooledElements = {}
local pooledHooked = false

local function OnTotemFrameUpdate(frame)
	local pool = frame and frame.totemPool
	if(not pool or type(pool.EnumerateActive) ~= 'function') then return end

	table.wipe(pooledHas)
	table.wipe(pooledShown)
	for button in pool:EnumerateActive() do
		local slot = button and button.slot
		if(not (issecretvalue and issecretvalue(slot)) and type(slot) == 'number') then
			pooledHas[slot] = true
			pooledShown[slot] = button:IsShown()
		end
	end
	pooledKnown = true

	for element in next, pooledElements do
		element:ForceUpdate()
	end
end

local function HookTotemFrame()
	if(pooledHooked) then return end
	if(not (TotemFrame and type(TotemFrame.Update) == 'function' and TotemFrame.totemPool and hooksecurefunc)) then return end
	pooledHooked = true
	hooksecurefunc(TotemFrame, 'Update', OnTotemFrameUpdate)
end

local function UpdateTotem(self, event, slot)
	local element = self.Totems
	if(slot > #element) then return end

	--[[ Callback: Totems:PreUpdate(slot)
	Called before the element has been updated.

	* self - the Totems element
	* slot - the slot of the totem to be updated (number)
	--]]
	if(element.PreUpdate) then element:PreUpdate(slot) end

	-- AzeriteUI: upstream oUF 14 (484dc79, 12d025f, f9747e7). GetTotemInfo is
	-- SecretWhenTotemSlotSecret on 12.x, so nothing here tests its answers: the
	-- widget's alpha follows haveTotem, the icon goes straight to SetTexture, and
	-- the cooldown takes GetTotemDuration's duration object (nil when empty).
	local totem = element[TOTEM_PRIORITIES[slot]]
	local haveTotem, name, _, rawDuration, icon = GetTotemInfo(slot)
	local duration = GetTotemDuration and GetTotemDuration(slot)

	-- AzeriteUI: Blizzard's TotemFrame shows a slot only while haveTotem AND
	-- duration > 0 (TotemButtonMixin:Update). The game can report a slot as taken
	-- with a zero duration and no icon, which drew an empty bordered square here
	-- (Avo's Hunter, FixLog 2026-11-13). Readable answers decide here. When both
	-- are secret, Blizzard's pooled button for the slot decides (see
	-- OnTotemFrameUpdate); until TotemFrame has updated once, haveTotem does.
	local isEmpty, isSecret = false, false
	if(not (issecretvalue and issecretvalue(rawDuration)) and rawDuration ~= nil) then
		isEmpty = (rawDuration <= 0)
	elseif(duration ~= nil and duration.HasSecretValues and not duration:HasSecretValues()) then
		isEmpty = duration:IsZero()
	else
		isSecret = (issecretvalue and issecretvalue(rawDuration)) and true or false
	end

	-- Another addon may stop Blizzard's updates after our first snapshot. Discard
	-- it until a fresh Update runs; otherwise a new secret totem could stay hidden.
	if(pooledKnown and not (TotemFrame and TotemFrame.IsEventRegistered
		and TotemFrame:IsEventRegistered('PLAYER_TOTEM_UPDATE'))) then
		pooledKnown = false
	end
	-- No active Blizzard button means haveTotem was false for the slot.
	if(isSecret and pooledKnown and not pooledHas[slot]) then
		isEmpty = true
	end

	if(isEmpty) then
		totem:SetAlpha(0)
	elseif(isSecret and pooledKnown) then
		totem:SetAlphaFromBoolean(pooledShown[slot], 1, 0)
	else
		totem:SetAlphaFromBoolean(haveTotem, 1, 0)
	end

	if(totem.Icon) then
		totem.Icon:SetTexture(icon)
	end

	if(totem.Cooldown) then
		if(duration ~= nil and not isEmpty) then
			totem.Cooldown:SetCooldownFromDurationObject(duration)
		else
			totem.Cooldown:Clear()
		end
	end

	--[[ Callback: Totems:PostUpdate(slot, haveTotem, name, icon, duration)
	Called after the element has been updated.

	* self      - the Totems element
	* slot      - the slot of the updated totem (number)
	* haveTotem - indicates if a totem is present in the given slot (boolean, may be secret)
	* name      - the name of the totem (string, may be secret)
	* icon      - the totem's icon (Texture, may be secret)
	* duration  - totem duration (DurationObject or nil)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(slot, haveTotem, name, icon, duration)
	end
end

local function Path(self, ...)
	--[[ Override: Totem.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	return (self.Totems.Override or UpdateTotem) (self, ...)
end

local function Update(self, event)
	for i = 1, #self.Totems do
		Path(self, event, i)
	end
end

local function ForceUpdate(element)
	return Update(element.__owner, 'ForceUpdate')
end

local function Enable(self)
	local element = self.Totems
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		for i = 1, #element do
			local totem = element[TOTEM_PRIORITIES[i]]
			totem:SetID(i)
			totem:Show() -- AzeriteUI: visibility is the alpha set in UpdateTotem

			if(totem:IsMouseEnabled()) then
				totem:SetScript('OnEnter', OnEnter)
				totem:SetScript('OnLeave', OnLeave)

				--[[ Override: Totems[slot]:UpdateTooltip()
				Used to populate the tooltip when the totem is hovered.

				* self - the widget at the given slot index
				--]]
				if(not totem.UpdateTooltip) then
					totem.UpdateTooltip = UpdateTooltip
				end
			end
		end

		self:RegisterEvent('PLAYER_TOTEM_UPDATE', Path, true)

		-- AzeriteUI: upstream unregisters TotemFrame's events here. We leave them
		-- registered so Blizzard's TotemFrame:Update keeps sorting secret slots for
		-- us (OnTotemFrameUpdate). It cannot show: oUF reparents PlayerFrame, its
		-- parent, to a hidden frame (blizzard.lua handleFrame). FixLog 2026-11-13.
		-- Update also runs PlayerFrame_AdjustAttachments, re-anchoring Blizzard's
		-- attached cast bar (suppressed by PlayerCastBar.lua); verify its position live.
		pooledElements[element] = true
		HookTotemFrame()

		return true
	end
end

local function Disable(self)
	local element = self.Totems
	if(element) then
		for i = 1, #element do
			element[i]:Hide()
		end

		pooledElements[element] = nil

		self:UnregisterEvent('PLAYER_TOTEM_UPDATE', Path)
	end
end

oUF:AddElement('Totems', Update, Enable, Disable)

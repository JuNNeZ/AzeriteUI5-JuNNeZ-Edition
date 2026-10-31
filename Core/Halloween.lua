-- Shared seasonal decoration, independent of the selected theme and Lite+.
local _, ns = ...
local Halloween = ns:NewModule("Halloween", "LibMoreEvents-1.0")
ns.Halloween = Halloween

local media = "Interface\\AddOns\\" .. (...) .. "\\Assets\\Halloween\\"
local frames = {}
local windows = {}
local styles = {
	[ns.Prefix .. "Player"] = true,
	[ns.Prefix .. "PlayerAlternate"] = true,
	[ns.Prefix .. "PlayerParty"] = true
}

-- Local calendar dates, like Winter Veil and Love is in the Air. This is a
-- cosmetic window, not a claim about a region's in-game holiday schedule.
Halloween.GetSeasonYear = function(self)
	local now = date("*t")
	if ((now.month == 10 and now.day >= 18) or (now.month == 11 and now.day == 1)) then
		return now.year
	end
end

Halloween.IsHidden = function(self)
	local year = self:GetSeasonYear()
	local char = ns.db and ns.db.char
	return year ~= nil and char ~= nil and char.halloweenHiddenYear == year
end

Halloween.SetHidden = function(self, hidden)
	local year = self:GetSeasonYear()
	local char = ns.db and ns.db.char
	if (not year or not char or InCombatLockdown()) then return false end
	char.halloweenHiddenYear = hidden and year or nil
	self:Refresh()
	return true
end

local Sprite = function(parent, name, size, point, relative, relativePoint, x, y, rotation)
	local texture = parent:CreateTexture(nil, "OVERLAY", nil, 7)
	texture:SetTexture(media .. name .. ".tga")
	texture:SetSize(size, size)
	texture:SetPoint(point, relative, relativePoint, x, y)
	if (rotation) then texture:SetRotation(rotation) end
	return texture
end

local NewOverlay = function(anchor)
	local overlay = CreateFrame("Frame", nil, anchor)
	overlay:SetAllPoints(anchor)
	overlay:EnableMouse(false)
	return overlay
end

Halloween.IsVisible = function(self)
	return self:IsEnabled() and self:GetSeasonYear() ~= nil and not self:IsHidden()
end

local IsSecret = function(value) return issecretvalue and issecretvalue(value) end

-- An interior reflection, below the existing resource-value font strings.
-- Its parent is the same as Value's, so fonts remain above it without moving
-- or replacing either the live fill or any text. Resource visibility/alpha
-- and scale still come from the original parent chain.
local ResourceHead = function(element, orb, visible)
	if (not element) then return end
	local head = element.HalloweenHead
	local surfaceReady = false
	if (visible) then
		local width, height = element:GetWidth(), element:GetHeight()
		if (IsSecret(width) or IsSecret(height)) then return end
		if (type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0) then return end
		local parent = element.Value and element.Value:GetParent() or element
		if (not head) then
			head = parent:CreateTexture(nil, "OVERLAY", nil, -7)
			head:SetTexture(media .. "horseman-face-v2.tga")
			head:SetAlpha(1)
			head:SetBlendMode("ADD")
			head:SetVertexColor(.45, 1, .30)
			element.HalloweenHead = head
		end
		if (head:GetParent() ~= parent) then head:SetParent(parent) end
		head:SetDrawLayer(orb and "BORDER" or "OVERLAY", orb and -1 or -7)
		local size = math.min(width, height) * (orb and .82 or .52)
		head:SetSize(size, size)
		head:ClearAllPoints()
		local y = orb and 0 or height * .015
		-- Move only a crystal-shaped resource, not Legacy/party power strips.
		if (not orb and height >= width*.5) then y = y - 20 end
		head:SetPoint("CENTER", element, "CENTER", 0, y)
		local recess = element.HalloweenRecess
		if (not recess) then
			recess = parent:CreateTexture(nil, "OVERLAY", nil, -8)
			recess:SetTexture(media .. "horseman-face-v2.tga")
			recess:SetVertexColor(.03, .05, .03)
			recess:SetAlpha(.20)
			element.HalloweenRecess = recess
		end
		if (recess:GetParent() ~= parent) then recess:SetParent(parent) end
		recess:SetDrawLayer(orb and "BORDER" or "OVERLAY", orb and -2 or -8)
		recess:ClearAllPoints()
		recess:SetAllPoints(head)
		-- On the orb the existing glass (BORDER 0) is above the face. For the
		-- crystal, replay its own static faceted backdrop as a faint surface veil
		-- above the glow. No fill texture, colour, geometry or Value is replaced.
		local source = not orb and element.Backdrop
		local path = source and source:GetTexture()
		if (not IsSecret(path) and path) then
			surfaceReady = true
			local surface = element.HalloweenSurface
			if (not surface) then
				surface = parent:CreateTexture(nil, "OVERLAY", nil, -6)
				surface:SetAlpha(.14)
				element.HalloweenSurface = surface
			end
			if (surface:GetParent() ~= parent) then surface:SetParent(parent) end
			surface:SetTexture(path)
			surface:ClearAllPoints()
			surface:SetAllPoints(source)
			local coords = { source:GetTexCoord() }
			local readable = true
			for _, value in ipairs(coords) do if (IsSecret(value)) then readable = false end end
			if (readable) then surface:SetTexCoord(unpack(coords)) end
		end
	end
	if (head) then head:SetShown(visible) end
	if (element.HalloweenRecess) then element.HalloweenRecess:SetShown(visible) end
	if (element.HalloweenSurface) then element.HalloweenSurface:SetShown(visible and surfaceReady) end
	if (head and ns.HalloweenEffects) then ns.HalloweenEffects:SetPulse(head, visible) end
end

-- The mounting sides follow the frame edges and the curved threads span INWARD.
Halloween.DecorateWindow = function(self, anchor, tooltip, embedded)
	if (InCombatLockdown() or not anchor or not anchor.CreateTexture) then return end
	if (anchor.IsForbidden and anchor:IsForbidden()) then return end
	if (IsSecret(embedded) or IsSecret(anchor.IsEmbedded)) then return end
	if (embedded or anchor.IsEmbedded) then return end
	local overlay = windows[anchor]
	if (self:IsVisible() and not overlay) then
		overlay = NewOverlay(anchor)
		local size = tooltip and 44 or 56
		Sprite(overlay, "web", size, "TOPLEFT", anchor, "TOPLEFT", -1, 1):SetAlpha(.6)
		Sprite(overlay, "web", size, "BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1, math.pi):SetAlpha(.6)
		if (ns.HalloweenEffects) then ns.HalloweenEffects:AddSpider(overlay, anchor, size) end
		windows[anchor] = overlay
	end
	if (overlay) then
		overlay:SetFrameLevel(anchor:GetFrameLevel() + 10)
		overlay:SetShown(self:IsVisible())
	end
end

Halloween.RefreshWindows = function(self)
	for _, name in ipairs({ "GameMenuFrame", ns.Prefix .. "OptionsPanel", ns.Prefix .. "FramePanel",
		"DropDownList1", "DropDownList2", "DropDownList3" }) do
		self:DecorateWindow(_G[name], false)
	end
	for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
		"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "FriendsTooltip", "QuickKeybindTooltip" }) do
		self:DecorateWindow(_G[name], true)
	end
	for anchor in pairs(windows) do self:DecorateWindow(anchor, true) end
end

Halloween.SetupHooks = function(self)
	if (not self.backdropHook and type(SharedTooltip_SetBackdropStyle) == "function") then
		self.backdropHook = true
		hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip, _, embedded)
			self:DecorateWindow(tooltip, true, embedded)
		end)
	end
	local kit = ns.OptionsKit
	for _, name in ipairs({ "Panel", "FramePanel" }) do
		local panel = kit and kit[name]
		if (panel and type(panel.Open) == "function" and not self["hooked" .. name]) then
			self["hooked" .. name] = true
			hooksecurefunc(panel, "Open", function() self:RefreshWindows() end)
		end
	end
end

Halloween.Refresh = function(self)
	-- Children of secure unit frames can inherit protection. Reconcile only
	-- outside combat, including at midnight and when a frame is first spawned.
	if (InCombatLockdown()) then return false end
	local visible = self:IsVisible()
	for frame in pairs(frames) do
		ResourceHead(frame.Power, false, visible)
		ResourceHead(frame.ManaOrb, true, visible)
	end
	local minimap = ns:GetModule("Minimap", true)
	local anchor = minimap and minimap:IsEnabled() and minimap.frame
	if (anchor and visible and not self.minimapOverlay) then
		self.minimapOverlay = NewOverlay(anchor)
	end
	self:SetupHooks()
	self:RefreshWindows()
	if (self.minimapOverlay) then
		if (anchor and visible and not self.minimapEffects and ns.HalloweenEffects) then
			self.minimapEffects = ns.HalloweenEffects:CreateMinimap(anchor, self.minimapOverlay)
		end
		self.minimapOverlay:SetFrameLevel(self.minimapOverlay:GetParent():GetFrameLevel() + 10)
		local show = visible and anchor ~= nil and anchor ~= false
		self.minimapOverlay:SetShown(show)
		if (self.minimapEffects) then self.minimapEffects:SetEnabled(show) end
	end
	return true
end

Halloween.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
	self:RegisterEvent("ADDON_LOADED", "Refresh")
	-- Also notices date boundaries and modules enabled later in this session.
	self.ticker = C_Timer.NewTicker(30, function() self:Refresh() end)
	self:Refresh()
end

Halloween.OnDisable = function(self)
	if (self.ticker) then self.ticker:Cancel(); self.ticker = nil end
	self:Refresh()
end

ns.oUF:RegisterInitCallback(function(frame)
	if (styles[frame.style] and not frame.isNamePlate) then
		frames[frame] = true
		Halloween:Refresh()
	end
end)

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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
--[[

	Shared drawing of group specialization icons.

	GroupSpecCache answers what a group member is playing. This answers where the
	icon goes, because the group layouts do not agree on that:

	- Party and Raid (5) own a portrait model, so the icon simply replaces it
	- Raid (25) and Raid (40) have no portrait at all, so the icon takes over the
	  round role plate beside the health bar

	Both helpers return false when the specialization is not known yet, which is
	routine: inspect only reaches members who are connected, visible and in range,
	so a spec can stay unresolved for a while after joining. Callers must draw
	their normal content in that case rather than a blank square, and redraw on
	the "GroupSpecCache_Updated" callback once the answer arrives.

--]]
local _, ns = ...
local API = ns.API
local GetMedia = ns.API.GetMedia

local SpecIcons = {}
ns.SpecIcons = SpecIcons

-- Lua API
local type = type

-- Spec icons are square art with the usual one pixel border baked in, so the
-- outer tenth is cropped away wherever the icon is drawn unmasked.
local ICON_INSET = .1

-- The role plate is round. An uncropped square icon dropped on it reads as a
-- mistake, so the icon is masked to the same shape instead.
local ROLE_ICON_MASK = GetMedia("actionbutton-mask-circular")

--[[
	Looks up the icon for a unit's specialization.

	Returns nil when it is not resolved yet, never a placeholder: a wrong or
	empty icon is worse than the portrait or role art it would have replaced.
]]
local GetIcon = function(unit)
	local cache = ns.GroupSpecCache
	if (not cache) then
		return nil
	end
	return (cache:GetSpecInfo(unit))
end

--[[
	Draws the unit's specialization icon over a portrait model.

	Returns true when the icon is showing, so the caller can leave the model
	alone, and false when the specialization is still unknown and the caller
	should draw its normal portrait.
]]
SpecIcons.ShowOnPortrait = function(element, unit)
	if (not element) then
		return false
	end

	local icon = GetIcon(unit)
	if (not icon) then
		SpecIcons.HideOnPortrait(element)
		return false
	end

	if (not element.SpecIcon) then
		local texture = element:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		texture:SetTexCoord(ICON_INSET, 1 - ICON_INSET, ICON_INSET, 1 - ICON_INSET)
		element.SpecIcon = texture
	end

	element.SpecIcon:SetTexture(icon)
	element.SpecIcon:Show()

	if (element.fallback2DTexture) then
		element.fallback2DTexture:Hide()
	end
	if (element.fallback2DFrame) then
		element.fallback2DFrame:Hide()
	end
	element:ClearModel()

	return true
end

SpecIcons.HideOnPortrait = function(element)
	if (element and element.SpecIcon) then
		element.SpecIcon:Hide()
	end
end

--[[
	Draws the unit's specialization icon on the round role plate.

	Returns true when the icon is showing. The caller keeps ownership of whether
	the plate itself is shown, because an unresolved specialization has to fall
	back to the role art, which is hidden for damage dealers.

	Note that this is a strict upgrade over the role icon when it is available:
	it carries the role and the specialization, and it covers damage dealers, who
	get no plate at all otherwise.
]]
SpecIcons.ShowOnRolePlate = function(indicator, unit)
	if (not indicator) then
		return false
	end

	local icon = GetIcon(unit)
	if (not icon) then
		SpecIcons.HideOnRolePlate(indicator)
		return false
	end

	if (not indicator.SpecIcon) then
		local texture = indicator:CreateTexture(nil, "ARTWORK", nil, 2)
		if (indicator.Icon) then
			texture:SetAllPoints(indicator.Icon)
		else
			texture:SetAllPoints()
		end
		-- SetMask and SetTexCoord fight over the same texture, and the mask
		-- already discards the baked in border, so no cropping is applied here.
		if (ROLE_ICON_MASK) then
			API.TryCall(texture.SetMask, texture, ROLE_ICON_MASK)
		end
		indicator.SpecIcon = texture
	end

	indicator.SpecIcon:SetTexture(icon)
	indicator.SpecIcon:Show()

	if (indicator.Icon) then
		indicator.Icon:Hide()
	end

	return true
end

SpecIcons.HideOnRolePlate = function(indicator)
	if (not indicator) then
		return
	end
	if (indicator.SpecIcon) then
		indicator.SpecIcon:Hide()
	end
	if (indicator.Icon) then
		indicator.Icon:Show()
	end
end

--[[
	Starts the inspect loop and subscribes the module to spec resolutions.

	Nothing runs until a module actually asks, so a player who never turns spec
	icons on never pays for the inspect traffic. The subscription is never
	removed again: the cache is cheap to keep warm, and toggling the option off
	and on again mid session should not have to rebuild it from nothing.

	`method` is the name of a module method that redraws whatever carries the
	icon, called whenever a specialization resolves.
]]
SpecIcons.Bind = function(module, enabled, method)
	if (not enabled or not module or type(method) ~= "string") then
		return
	end
	if (ns.GroupSpecCache) then
		ns.GroupSpecCache.Enable()
	end
	if (not module.__specCacheHooked) then
		module.__specCacheHooked = true
		ns.RegisterCallback(module, "GroupSpecCache_Updated", method)
	end
end

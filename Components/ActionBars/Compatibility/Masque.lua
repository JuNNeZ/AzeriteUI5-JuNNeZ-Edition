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
local _, ns = ...

-- Masque only skins buttons their own addon hands it (Masque Core/Group.lua,
-- GMT:AddButton); it cannot find them by itself. Until this file AzeriteUI handed it
-- none, and the pet and stance styles even switched LibActionButton's hand-over off.
--
-- Opt-in: /az -> Action Bars -> "Let Masque skin the buttons" (ActionBars profile key
-- `masque`). Our art is drawn once and held in place by permanent hooks, so the choice
-- is read once per session and a change takes a reload, as ElvUI does it. With it on,
-- the button styles leave the art layers (icon mask, border, backdrop, state textures,
-- cooldown swipe) to Masque and keep the rest: fonts, keybind, count, cooldown numbers,
-- proc and assisted highlights, fading and bindings.

local LibStub = LibStub

-- Shown in Masque's settings as the addon the groups belong to. Group names stay
-- English on purpose: Masque keys its saved skins by addon + group name, so a
-- translated name would lose the player's skin choice on a client language change.
local MASQUE_ADDON = "AzeriteUI"

local MasqueSupport = {}
ns.ActionBarMasque = MasqueSupport

local active -- nil until first asked, then true or false for the rest of the session
local groups = {}

-- Masque loads after us (alphabetical, and it is not an OptionalDep: listing it would
-- move its embedded Ace3 ahead of ours), so it is looked up when asked, never at load.
local GetMasque = function()
	return LibStub and LibStub("Masque", true) or nil
end

--- Whether Masque is installed and loaded.
MasqueSupport.IsAvailable = function()
	return GetMasque() ~= nil
end

--- Whether this session's action, pet and stance buttons are Masque's to skin.
--- Decided the first time a bar styles a button, then fixed until the next reload.
MasqueSupport.IsActive = function()
	if (active == nil) then
		local module = ns:GetModule("ActionBars", true)
		local profile = module and module.db and module.db.profile
		active = (profile and profile.masque and GetMasque()) and true or false
	end
	return active
end

--- Returns the Masque group by name, creating it on first use. Nil when inactive.
MasqueSupport.GetGroup = function(name)
	if (not MasqueSupport.IsActive()) then return end
	local group = groups[name]
	if (not group) then
		local Masque = GetMasque()
		group = Masque and Masque:Group(MASQUE_ADDON, name)
		groups[name] = group
	end
	return group
end

--- Hands a button to Masque after its style ran. buttonType is "Action", "Pet" or
--- "Stance", the types Masque Skins/Regions.lua defines. Does nothing when inactive.
MasqueSupport.AddButton = function(button, groupName, buttonType)
	if (not button) then return end
	local group = MasqueSupport.GetGroup(groupName)
	if (not group or type(group.AddButton) ~= "function") then return end
	group:AddButton(button, nil, buttonType)
	-- LibActionButton reads this to stop drawing Blizzard's border and slot art
	-- (LibActionButton-1.0-GE Update); the same flag its own AddToMasque sets.
	button.MasqueSkinned = true
end

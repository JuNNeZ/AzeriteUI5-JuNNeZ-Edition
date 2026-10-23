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
local L = LibStub("AceLocale-3.0"):GetLocale((...))
local oUF = ns.oUF

-- Totems, statues and the ghoul sit in Blizzard's TotemFrame, which is parented
-- to the PlayerFrame oUF hides, so they had no display at all. Forever loads the
-- same TotemFrame (Blizzard_UnitFrame.toc, mainline) and loses it the same way.
-- The totem bar HideBlizzard.lua leaves shown on Forever is MultiCastActionBarFrame:
-- it casts totems and shows their spell cooldowns, not the time a totem has left.
if (not ns.IsMainline) then return end

local TotemsMod = ns:NewModule("PlayerTotemsFrame", ns.UnitFrameModule, "LibMoreEvents-1.0")

-- Lua API
local select = select
local unpack = unpack

-- Addon API
local GetFont = ns.API.GetFont

local defaults = { profile = ns:Merge({}, ns.MovableModulePrototype.defaults) }

-- Generate module defaults on the fly
-- to recalculate default values relying on
-- changing factors like user interface scale.
TotemsMod.GenerateDefaults = function(self)
	-- Just above the player cast bar, which sits at BOTTOM 0, 282.
	defaults.profile.savedPosition = {
		scale = ns.API.GetEffectiveScale(),
		[1] = "BOTTOM",
		[2] = 0,
		[3] = 320 * ns.API.GetEffectiveScale()
	}
	return defaults
end

local CreateTotem = function(self, db, index)
	local totem = CreateFrame("Frame", nil, self)
	totem:SetSize(unpack(db.TotemSize))
	totem:SetPoint("LEFT", (index - 1) * (db.TotemSize[1] + db.TotemSpacing), 0)
	-- No tooltip or right-click: an empty slot is only transparent, and a
	-- mouse-enabled icon there would swallow clicks meant for the world.
	totem:EnableMouse(false)

	local icon = totem:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:SetAllPoints()
	icon:SetMask(db.TotemIconMask)
	totem.Icon = icon

	local border = ns.AuraStyles.CreateTextureBorder(totem)
	border:SetBackdropBorderColor(unpack(db.TotemBorderColor))
	border:SetPoint("TOPLEFT", -6, 6)
	border:SetPoint("BOTTOMRIGHT", 6, -6)
	border:SetFrameLevel(totem:GetFrameLevel() + 2)
	totem.Border = border

	-- The timer is Blizzard's own countdown on the cooldown frame: it is fed a
	-- duration object, so the remaining time never has to be read in Lua.
	local cooldown = CreateFrame("Cooldown", nil, totem, "CooldownFrameTemplate")
	cooldown:SetAllPoints(totem)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetReverse(true)
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetHideCountdownNumbers(false)
	cooldown:SetFrameLevel(border:GetFrameLevel() + 1)
	cooldown:EnableMouse(false)
	for i = 1, cooldown:GetNumRegions() do
		local region = select(i, cooldown:GetRegions())
		if (region and region.GetObjectType and region:GetObjectType() == "FontString") then
			region:SetFontObject(GetFont(db.TotemTimerFontSize, true))
			region:SetTextColor(unpack(db.TotemTimerColor))
		end
	end
	totem.Cooldown = cooldown

	return totem
end

local style = function(self, unit)

	local db = ns.GetConfig("PlayerTotems")
	local width = db.TotemCount * db.TotemSize[1] + (db.TotemCount - 1) * db.TotemSpacing

	self:SetSize(width, db.TotemSize[2])

	local totems = {}
	for index = 1, db.TotemCount do
		totems[index] = CreateTotem(self, db, index)
	end
	self.Totems = totems

end

TotemsMod.CreateUnitFrames = function(self)
	-- The WoW11 start-up builds the frame and then calls Enable, whose OnEnable
	-- builds it again: spawn once, or a second, unanchored copy keeps handling events.
	if (self.frame) then return end

	local unit, name = "player", "PlayerTotems"

	oUF:RegisterStyle(ns.Prefix..name, style)
	oUF:SetActiveStyle(ns.Prefix..name)

	self.frame = ns.UnitFrame.Spawn(unit, ns.Prefix.."UnitFrame"..name)
	self.frame:EnableMouse(false)
end

TotemsMod.OnEnable = function(self)

	self:CreateUnitFrames()
	self:CreateAnchor(L["Totems"])

	ns.MovableModulePrototype.OnEnable(self)
end

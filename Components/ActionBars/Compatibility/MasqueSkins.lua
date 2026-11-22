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
local Addon, ns = ...

-- Our button looks offered to Masque as skins, so a player can put them on any
-- addon's buttons Masque skins (Bartender, Dominos, WeakAuras, our own bars when
-- "Let Masque skin the buttons" is on). The other direction, Masque skinning our
-- bars, is Compatibility/Masque.lua; the two are independent.
--
-- One skin per shape (Circle, Rounded, Square, Hex) with the stock border, and one
-- per shape and class theme with that theme's painted border. Only the border art
-- differs between themes: mask, backdrop and highlight are shared, as in
-- Core/API/Assets.lua GetShapedButtonConfig. The Legacy HUD's art is left out: it
-- ships under a separate permission that does not cover other addons' buttons.
--
-- Paths are fixed, never resolved through GetMedia: a skin is a snapshot that must
-- look the same whichever theme is active. Masque sizes everything for a 36px button
-- and scales to the real one, so our 64px-cell measurements are multiplied by 36/64.
--
-- Masque loads after us (Masque.lua explains why it is not an OptionalDep), so the
-- skins go in when Masque's ADDON_LOADED fires, before PLAYER_LOGIN and before any
-- group asks for a saved skin. If something loaded Masque first, they go in at once.

local LibStub = LibStub
local CreateFrame = CreateFrame
local string_format = string.format

local MASQUE = "Masque"
local MASQUE_API_VERSION = 120001 -- Masque.lua API_VERSION at Masque 12.1.8
local K = 36 / 64 -- Masque's 36px button over our 64px cell

local MEDIA = [[Interface\AddOns\%s\Assets\%s.tga]]
local Media = function(name)
	return string_format(MEDIA, Addon, name)
end

-- Measured sizes for a 64px cell. Circle from Layouts/Data/ActionButton.lua; the
-- others from BUTTON_SHAPES in Core/API/Assets.lua (glow defaults to 117.5, icon to 60).
local SHAPES = {
	{
		key = "circle", name = "Circle", masqueShape = "Circle",
		mask = "actionbutton-mask-circular", backdrop = "actionbutton-backdrop",
		border = "actionbutton-border", highlight = "actionbutton-spellhighlight",
		deco = 134.295081967, icon = 44, glow = 134.295081967
	},
	{
		key = "rounded", name = "Rounded", masqueShape = "Square",
		mask = "actionbutton-mask-square-rounded", backdrop = "actionbutton-backdrop-square-rounded",
		border = "actionbutton-border-square-rounded", highlight = "actionbutton-spellhighlight-square-rounded",
		deco = 93.1, icon = 60, glow = 117.5
	},
	{
		key = "square", name = "Square", masqueShape = "Square",
		mask = "actionbutton-mask-square", backdrop = "actionbutton-backdrop-square",
		border = "actionbutton-border-square", highlight = "actionbutton-spellhighlight-square",
		deco = 96.3, icon = 60, glow = 117.5
	},
	{
		-- Point-up, like Masque's own "Hexagon" (its "Hexagon-Rotated" is flat-topped).
		key = "hex", name = "Hex", masqueShape = "Hexagon",
		mask = "actionbutton-mask-hex", backdrop = "actionbutton-backdrop-hex",
		border = "actionbutton-border-hex", highlight = "actionbutton-spellhighlight-hex",
		deco = 96, icon = 50, glow = 96
	}
}

-- Class themes with their own button borders, by asset folder. Every folder has
-- circle/square/rounded borders; the hex border is either the theme's own
-- (Assets/<Theme>/actionbutton-border-hex) or the shared painting in Assets/HexButtons.
local THEMES = {
	{ folder = "DeathKnight", name = "Death Knight", ownHex = true },
	{ folder = "Druid", name = "Druid" },
	{ folder = "Hunter", name = "Hunter" },
	{ folder = "Mage", name = "Mage" },
	{ folder = "Paladin", name = "Paladin" },
	{ folder = "Priest", name = "Priest", ownHex = true },
	{ folder = "Rogue", name = "Rogue" },
	{ folder = "Shaman", name = "Shaman" },
	{ folder = "Warlock", name = "Warlock", ownHex = true },
	{ folder = "Warrior", name = "Warrior" }
}

-- The tint every AzeriteUI button border carries (Colors.ui, Core/Common/Colors.lua).
local BORDER_COLOR = { 192/255, 192/255, 192/255, 1 }

local MasqueSkins = {}
ns.ActionBarMasqueSkins = MasqueSkins

local registered -- set once the skins went in

--- Returns the border texture for a shape, stock when theme is nil.
local GetBorder = function(shape, theme)
	if (not theme) then return Media(shape.border) end
	if (shape.key == "hex" and not theme.ownHex) then
		return Media("HexButtons\\"..theme.folder.."\\border")
	end
	return Media(theme.folder.."\\"..shape.border)
end

--- Returns the Masque skin ID, as shown in Masque's skin dropdown.
--- Sorted alphabetically by Masque, so the stock skins and each theme stay together.
MasqueSkins.GetSkinID = function(shape, theme)
	if (theme) then
		return string_format("AzeriteUI %s - %s", theme.name, shape.name)
	end
	return string_format("AzeriteUI - %s", shape.name)
end

--- Builds one Masque skin table. Layers mirror the style in Elements/ActionBars.lua:
--- masked icon, backdrop below, border above, and pushed/checked/hover/flash drawn
--- with the icon's own mask so they keep the button's shape.
MasqueSkins.BuildSkin = function(shape, theme, version)
	local mask = Media(shape.mask)
	local border = GetBorder(shape, theme)
	local deco, icon, glow = shape.deco * K, shape.icon * K, shape.glow * K
	local title = theme and (theme.name.." "..shape.name) or shape.name

	local IconLayer = function(color, blend)
		return { Texture = mask, Width = icon, Height = icon, Color = color, BlendMode = blend or "ADD" }
	end

	return {
		API_VERSION = MASQUE_API_VERSION,
		Shape = shape.masqueShape,

		Group = "AzeriteUI",
		Title = title,
		Description = theme
			and string_format("AzeriteUI's %s button with the %s theme border.", shape.name:lower(), theme.name)
			or string_format("AzeriteUI's %s button.", shape.name:lower()),
		Version = version,
		Authors = { "Jonas \"JuNNeZ\" Andersen", "Lars Norberg" },

		Backdrop = {
			Texture = Media(shape.backdrop),
			Width = deco, Height = deco,
			Color = { .67, .67, .67, 1 }
		},
		Icon = {
			Width = icon, Height = icon,
			TexCoords = { 0, 1, 0, 1 },
			Mask = mask
		},
		Normal = {
			Texture = border, EmptyTexture = border,
			Width = deco, Height = deco,
			Color = BORDER_COLOR, EmptyColor = BORDER_COLOR
		},
		-- Blizzard tints this one itself (equipped items), so it is our border art.
		Border = {
			Texture = border,
			Width = deco, Height = deco,
			BlendMode = "BLEND"
		},
		SpellHighlight = {
			Texture = Media(shape.highlight),
			Width = glow, Height = glow,
			BlendMode = "ADD"
		},
		Pushed = IconLayer({ 1, 1, 1, .2 }),
		Checked = IconLayer({ 1, .82, .1, .2 }),
		Highlight = IconLayer({ 1, 1, 1, .2 }),
		Flash = IconLayer({ 1, 0, 0, .25 }, "BLEND"),
		Gloss = { Hide = true },
		Cooldown = {
			Texture = mask,
			Width = icon, Height = icon,
			Color = { 0, 0, 0, .75 }
		},
		ChargeCooldown = {
			Texture = mask,
			Width = icon, Height = icon,
			Color = { 0, 0, 0, .5 }
		}
	}
end

--- Every skin this file offers, as a list of { id, data }. Exposed for the harness.
MasqueSkins.BuildAll = function(version)
	local list = {}
	for _, shape in ipairs(SHAPES) do
		list[#list + 1] = { id = MasqueSkins.GetSkinID(shape), data = MasqueSkins.BuildSkin(shape, nil, version) }
	end
	for _, theme in ipairs(THEMES) do
		for _, shape in ipairs(SHAPES) do
			list[#list + 1] = { id = MasqueSkins.GetSkinID(shape, theme), data = MasqueSkins.BuildSkin(shape, theme, version) }
		end
	end
	return list
end

--- Hands the skins to Masque. Safe to call more than once; Masque itself also
--- ignores an ID it already has. Returns true once they are in.
MasqueSkins.Register = function()
	if (registered) then return true end
	local Masque = LibStub and LibStub(MASQUE, true)
	if (not Masque or type(Masque.AddSkin) ~= "function") then return false end
	local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local version = getMetadata and getMetadata(Addon, "Version") or nil
	for _, skin in ipairs(MasqueSkins.BuildAll(version)) do
		Masque:AddSkin(skin.id, skin.data)
	end
	registered = true
	return true
end

-- Register now if Masque is already here, otherwise when it loads.
if (not MasqueSkins.Register() and CreateFrame) then
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("ADDON_LOADED")
	watcher:SetScript("OnEvent", function(self, _, name)
		if (name ~= MASQUE) then return end
		self:UnregisterEvent("ADDON_LOADED")
		self:SetScript("OnEvent", nil)
		MasqueSkins.Register()
	end)
end

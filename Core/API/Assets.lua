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
local API = ns.API or {}
ns.API = API

-- Lua API
local next = next
local pairs = pairs
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format
local type = type

-- GLOBALS: CreateFont

-- Full cache that spawns new objects on-the-fly.
local count, font_mt = 0, nil
font_mt = {
	__index = function(t,k)
		-- Create a new category and subtable
		if (type(k) == "string") then
			local new = setmetatable({}, font_mt)
			rawset(t,k,new)
			return new
		-- Create a new font object
		elseif (type(k) == "number") then
			count = count + 1
			local new = CreateFont(string_format(ns.Prefix.."Font%d", count))
			new:SetJustifyH("LEFT") -- new fonts appear to be centered after 9.1.5
			rawset(t,k,new)
			return new
		end
	end
}
local Fonts = setmetatable({}, font_mt)

-- Caches used for iterations
local AllFonts, ChatFonts, NumberFonts, NormalFonts = {}, {}, {}, {}

-- Put our global fontobjects into our table.
for _,fontType in next,{ "Normal", "Chat", "Number" } do
	for _,fontStyle in next,{ "None", "Outline" } do
		for fontSize = 1,34 do
			local namedType = fontType == "Normal" and "" or fontType
			local namedStyle = fontStyle == "None" and "" or fontStyle
			local fontObject = _G[ns.Prefix.."Font"..namedType..fontSize..namedStyle]
			if (fontObject) then
				Fonts[fontType][fontStyle][fontSize] = fontObject
				AllFonts[fontObject] = true
				ChatFonts[fontObject] = fontType == "Chat"
				NumberFonts[fontObject] = fontType == "Number"
				NormalFonts[fontObject] = fontType == ""
			end
		end
	end
end

-- Return a font object, re-use existing ones that match.
local GetFont = function(size, outline, type)
	return Fonts[type or "Normal"][outline and "Outline" or "None"][size]
end

-- Iterators for our font caches. Provided for restyling purposes.
local GetAllFonts = function() return pairs(AllFonts) end
local GetAllChatFonts = function() return pairs(ChatFonts) end
local GetAllNumberFonts = function() return pairs(NumberFonts) end
local GetAllNormalFonts = function() return pairs(NormalFonts) end

-- Add some aliases for blizzard artwork.
local alias = {
	["plain"] = [[Interface\ChatFrame\ChatFrameBackground]]
}

-- Retrieve an asset from the media asset folder.
local GetMedia = function(name, type)
	local themed = ns.LegacyHUD and ns.LegacyHUD:ResolveMedia(name)
		or (ns.PaladinTheme and ns.PaladinTheme:ResolveMedia(name))
	if (themed and (not type or type == "tga")) then return themed end
	return alias[name] or string_format([[Interface\AddOns\%s\Assets\%s.%s]], Addon, name, type or "tga")
end

-- Optional Square and Rounded button art. Circle is AzeriteUI's own design and
-- stays the default. Sizes come from the art's measured bounds on the 256px
-- sheets for a 64px cell: the border's outer edge lands at about 62px, inside
-- the cell, so neighbours never overlap. Smaller cells (pet, stance) scale the
-- same proportions.
local BUTTON_SHAPES = {
	square = {
		mask = "actionbutton-mask-square",
		backdrop = "actionbutton-backdrop-square",
		border = "actionbutton-border-square",
		highlight = "actionbutton-spellhighlight-square",
		deco = 96.3
	},
	rounded = {
		mask = "actionbutton-mask-square-rounded",
		backdrop = "actionbutton-backdrop-square-rounded",
		border = "actionbutton-border-square-rounded",
		highlight = "actionbutton-spellhighlight-square-rounded",
		deco = 93.1
	}
}

--- Returns true when shape names one of the optional button shapes.
local IsButtonShape = function(shape)
	return BUTTON_SHAPES[shape] ~= nil
end

--- Returns db unchanged for the circle, and under the Legacy HUD (which has its
--- own rounded buttons); otherwise a copy with the shape's art swapped in.
--- Takes the Button* configs and the extra button's ExtraButton* config.
--- The config passed in is never modified.
local GetShapedButtonConfig = function(db, shape)
	local s = BUTTON_SHAPES[shape]
	if (not s or type(db) ~= "table" or (ns.LegacyHUD and ns.LegacyHUD:IsActive())) then return db end
	local extra = db.ExtraButtonSize ~= nil
	local cell = extra and db.ExtraButtonSize or db.ButtonSize
	if (type(cell) ~= "table" or type(cell[1]) ~= "number") then return db end
	local c = {}
	for k,v in next,db do c[k] = v end
	local scale = cell[1] / 64
	local icon, deco, glow = 60 * scale, s.deco * scale, 117.5 * scale
	local bind, count = { "TOPLEFT", 8 * scale, -8 * scale }, { "BOTTOMRIGHT", -7 * scale, 7 * scale }
	if (extra) then
		c.ExtraButtonMask = GetMedia(s.mask)
		c.ExtraButtonBorderTexture = GetMedia(s.border)
		c.ExtraButtonBorderSize = { deco, deco }
		c.ExtraButtonIconSize = { icon, icon }
		c.ExtraButtonCooldownSize = { icon, icon }
		c.ExtraButtonBindPosition = bind
		c.ExtraButtonCountPosition = count
		return c
	end
	c.ButtonMaskTexture = GetMedia(s.mask)
	c.ButtonBackdropTexture = GetMedia(s.backdrop)
	c.ButtonBackdropSize = { deco, deco }
	c.ButtonBorderTexture = GetMedia(s.border)
	c.ButtonBorderSize = { deco, deco }
	c.ButtonSpellHighlightTexture = GetMedia(s.highlight)
	c.ButtonSpellHighlightSize = { glow, glow }
	if (db.ButtonAssistedHighlightTexture) then
		c.ButtonAssistedHighlightTexture = GetMedia(s.highlight)
	end
	c.ButtonIconSize = { icon, icon }
	c.ButtonKeybindPosition = bind
	c.ButtonCountPosition = count
	return c
end

-- Global API
---------------------------------------------------------
API.IsButtonShape = IsButtonShape
API.GetShapedButtonConfig = GetShapedButtonConfig
API.GetFont = GetFont
API.GetAllFonts = GetAllFonts
API.GetAllChatFonts = GetAllChatFonts
API.GetAllNumberFonts = GetAllNumberFonts
API.GetAllNormalFonts = GetAllNormalFonts
API.GetMedia = GetMedia

--[[

	The MIT License (MIT)

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

--[[
	Cooldown Manager, AzeriteUI style (roadmap option 01).

	Decorate, never rebuild. Blizzard's Cooldown Manager is the one frame still
	allowed to read cooldowns and auras in combat, so every number, timer and
	swipe stays Blizzard's. This module only restyles the item frames Blizzard
	already draws (Blizzard_CooldownViewer/CooldownViewer.xml):

	  - the icon mask, a backdrop behind it and a border over it, in one of
	    three styles. Square and rounded use the square button stack promoted
	    from Assets_Draft (2026-10-05); circular uses the action bar ring;
	  - the swipe, shaped by the same mask, as ActionBars.lua does for its buttons;
	  - AzeriteUI fonts on the countdown, charges and stacks;
	  - the Tracked Bars fill, in cast_bar art;
	  - the key bound to each ability on AzeriteUI's own action bars.

	Position, icon size, padding, icons per row, orientation and opacity are
	Blizzard's Edit Mode settings for each viewer, and stay there.

	The circular style follows the active theme: its mask, backdrop and ring come
	through GetMedia, so a Mage, Hunter or Paladin theme's action bar ring is used
	here too. The `skin` setting can override that for the Cooldown Manager alone:
	AzeriteUI, or one theme's art through that theme's ResolveOwnMedia, whatever
	the rest of the interface wears (Paladin only in Development Mode, as on the
	Themes page). It changes live, since only this module's textures move.
	The square and rounded styles are always the AzeriteUI set, read
	straight from Assets/, because no theme has square art yet; see
	Docs/Theme Engine Plan.md, "Cooldown Manager". A theme switch reloads the
	interface, so the art is picked once per session.

	Hooks are post-hooks on each viewer (hooksecurefunc), and per-item state lives
	in a weak table here, so nothing is written into Blizzard's frame tables.
	Turning the style off puts back every texture, anchor and font it changed.

	Explorer Mode fades the viewers through a proxy frame per viewer (GetFadeFrames).
	LibFadingFrames replaces SetAlpha on what it fades, which would both break the
	viewer's own Edit Mode opacity and put an addon function on Blizzard's frame.
	The proxy takes the fade instead and the viewer is set to its own opacity times
	the fade, re-applied whenever Edit Mode sets that opacity.

	Retail and Forever ship the same Blizzard_CooldownViewer, so this runs on both.
]]

local CooldownManager = ns:NewModule("CooldownManager", "LibMoreEvents-1.0")

-- Lua API
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local string_format = string.format
local table_insert = table.insert
local type = type
local unpack = unpack

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia
local IsAddOnEnabled = ns.API.IsAddOnEnabled

-- GLOBALS: ActionButtonSpellAlertManager, C_Timer, CreateFrame, Enum, InCombatLockdown, UIParent, hooksecurefunc, issecretvalue

local VIEWERS = {
	"EssentialCooldownViewer",
	"UtilityCooldownViewer",
	"BuffIconCooldownViewer",
	"BuffBarCooldownViewer"
}

local BAR_VIEWER = "BuffBarCooldownViewer"

-- Font sizes per viewer, against each item template's own size: 50, 30 and 40
-- pixel icons and a 30 pixel icon on a bar. Blizzard scales the item frame by
-- the Edit Mode icon size, and the text scales with it.
local FONTS = {
	EssentialCooldownViewer = { cooldown = 18, count = 15, key = 12 },
	UtilityCooldownViewer = { cooldown = 13, count = 12, key = 11 },
	BuffIconCooldownViewer = { cooldown = 15, count = 14 },
	BuffBarCooldownViewer = { count = 12, bar = 13 }
}

-- `icon` is the icon's share of the item frame, `deco` the backdrop and border
-- size against the icon. The square set is built for 2.06 x the icon
-- (Assets_Draft/README.md, "The square button stack"); the action bar ring is
-- drawn at 134.3 for a 44 pixel icon, 3.05 x. The ring's metal reaches further
-- out, so a circular icon is drawn smaller to keep it inside its neighbours.
local STYLES = {
	square = {
		mask = "actionbutton-mask-square",
		backdrop = "actionbutton-backdrop-square",
		border = "actionbutton-border-square",
		icon = 1, deco = 2.06
	},
	rounded = {
		mask = "actionbutton-mask-square-rounded",
		backdrop = "actionbutton-backdrop-square-rounded",
		border = "actionbutton-border-square-rounded",
		icon = 1, deco = 2.06
	},
	circular = {
		mask = "actionbutton-mask-circular",
		backdrop = "actionbutton-backdrop",
		border = "actionbutton-border",
		icon = .72, deco = 134.295081967 / 44,
		circular = true,
		themed = true
	}
}

-- Blizzard's own art, for putting it back.
local BLIZZARD_MASK = "UI-HUD-CoolDownManager-Mask"
local BLIZZARD_OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local BLIZZARD_SWIPE = [[Interface\HUD\UI-HUD-CoolDownManager-Icon-Swipe]]
local BLIZZARD_BAR = "UI-HUD-CoolDownManager-Bar"
local BLIZZARD_BAR_COLOR = { 1, .5, .25 }

-- Addons that restyle the same frames. While one is enabled AzeriteUI leaves the
-- Cooldown Manager alone. TODO: none of these is installed on the maintainer's
-- machine, so the folder names come from their project pages and are unverified.
local RIVALS = {
	"ArcUI",
	"CooldownManagerCentered",
	"BetterCooldownManager"
}

local defaults = { profile = ns:Merge({
	styleIcons = true,
	iconStyle = "rounded",
	skin = "theme",
	showKeybinds = true
}, ns.ModulePrototype.defaults) }

CooldownManager.GenerateDefaults = function(self)
	return defaults
end

-- Per item frame state, weak so Blizzard's pool owns the frames' lifetime.
local skins = setmetatable({}, { __mode = "k" })

-- The fade Explorer Mode last asked for, per viewer, while below full.
local fadeAlpha = {}

-- Spell ID to the hotkey text shown on AzeriteUI's button for it.
local keyBySpell = {}

local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local Plain = function(value)
	if (IsSecret(value)) then return end
	return value
end

local Art = function(name)
	return string_format([[Interface\AddOns\%s\Assets\%s.tga]], Addon, name)
end

-- The skins the Cooldown Manager can wear instead of the interface theme, by the
-- key the Themes page uses and the module that owns the art.
local SKIN_THEMES = { mage = "MageTheme", hunter = "HunterTheme", paladin = "PaladinTheme" }
local SKIN_ORDER = { "theme", "azerite", "mage", "hunter", "paladin" }

local IsDevelopmentMode = function()
	return ns.db and ns.db.global and ns.db.global.enableDevelopmentMode and true or false
end

-- A skin the player may pick right now. Paladin is a Development Mode preview.
local IsSkinAvailable = function(key)
	if (key == "theme" or key == "azerite") then return true end
	local moduleName = SKIN_THEMES[key]
	if (not moduleName or not ns:GetModule(moduleName, true)) then return false end
	return key ~= "paladin" or IsDevelopmentMode()
end

-- A style's art. A themed style goes through the chosen skin: the interface
-- theme, AzeriteUI's own, or one theme's file for the name, falling back to
-- AzeriteUI's where that theme has none. Unthemed styles are always AzeriteUI's.
local StyleArt = function(style, name, skin)
	if (not style.themed or skin == "azerite") then
		return Art(name)
	end
	local moduleName = SKIN_THEMES[skin]
	if (moduleName and IsSkinAvailable(skin)) then
		local theme = ns:GetModule(moduleName, true)
		return (theme and theme.ResolveOwnMedia and theme:ResolveOwnMedia(name)) or Art(name)
	end
	return GetMedia(name)
end

local IsUsable = function(frame)
	return frame and not (frame.IsForbidden and frame:IsForbidden())
end

-------------------------------------------------------------------------------
-- Keybinds
-------------------------------------------------------------------------------

-- Read from the buttons themselves, in bar order, so the key shown is the one
-- LibActionButton shows on the bar (paging and override bindings included).
local RebuildKeybinds = function()
	for spellID in pairs(keyBySpell) do
		keyBySpell[spellID] = nil
	end

	local module = ns:GetModule("ActionBars", true)
	local bars = module and module:IsEnabled() and module.bars
	if (type(bars) ~= "table") then return end

	for i = 1, 10 do
		local bar = bars[i]
		local enabled = bar and ((not bar.IsEnabled) or bar:IsEnabled())
		if (enabled and type(bar.buttons) == "table") then
			for _, button in ipairs(bar.buttons) do
				if (button.GetSpellId and button.GetHotkey) then
					local ok, spellID = pcall(button.GetSpellId, button)
					spellID = ok and Plain(spellID)
					if (type(spellID) == "number" and not keyBySpell[spellID]) then
						local hasKey, key = pcall(button.GetHotkey, button)
						key = hasKey and Plain(key)
						if (type(key) == "string" and key ~= "") then
							keyBySpell[spellID] = key
						end
					end
				end
			end
		end
	end
end

-- The override first, then the base spell, the way the bar resolves its own.
local GetItemKey = function(item)
	local info = item.GetCooldownInfo and item:GetCooldownInfo()
	if (type(info) ~= "table") then return end
	local override, base = Plain(info.overrideSpellID), Plain(info.spellID)
	return (override and keyBySpell[override]) or (base and keyBySpell[base])
end

-------------------------------------------------------------------------------
-- Item styling
-------------------------------------------------------------------------------

-- Blizzard's mask and icon overlay carry no parentKey, so they are found by kind.
local FindArt = function(holder)
	local mask, overlay
	for _, region in ipairs({ holder:GetRegions() }) do
		local kind = region:GetObjectType()
		if (kind == "MaskTexture") then
			mask = mask or region
		elseif (kind == "Texture" and region.GetAtlas and region:GetAtlas() == BLIZZARD_OVERLAY) then
			overlay = region
		end
	end
	return mask, overlay
end

local GetSkin = function(item, viewerName)
	local skin = skins[item]
	if (skin) then return skin end

	local isBar = viewerName == BAR_VIEWER
	local holder = isBar and item.Icon or item
	local icon = holder and holder.Icon
	if (not IsUsable(holder) or not icon or not icon.SetTexture) then return end

	local mask, overlay = FindArt(holder)

	-- The template's size, never secret. A frame not sized yet falls back to
	-- the Tracked Buffs icon.
	local size = holder:GetWidth()
	if (type(size) ~= "number" or size <= 0) then size = 40 end

	skin = {
		item = item,
		viewer = viewerName,
		holder = holder,
		icon = icon,
		mask = mask,
		overlay = overlay,
		cooldown = item.Cooldown,
		range = item.OutOfRange,
		bar = isBar and item.Bar or nil,
		size = size,
		fonts = {}
	}

	-- Behind the icon, on Blizzard's frame, below anything Blizzard draws there.
	skin.backdrop = holder:CreateTexture(nil, "BACKGROUND", nil, -7)
	skin.backdrop:SetPoint("CENTER", icon, "CENTER", 0, 0)
	skin.backdrop:Hide()

	-- Over the swipe, under the counts.
	local decor = CreateFrame("Frame", nil, holder)
	decor:SetAllPoints(holder)
	decor:SetFrameLevel(((skin.cooldown and skin.cooldown:GetFrameLevel()) or holder:GetFrameLevel()) + 1)
	decor:EnableMouse(false)
	decor:Hide()
	skin.decor = decor

	skin.border = decor:CreateTexture(nil, "BORDER")
	skin.border:SetPoint("CENTER", icon, "CENTER", 0, 0)

	if (FONTS[viewerName] and FONTS[viewerName].key) then
		local key = decor:CreateFontString(nil, "OVERLAY")
		key:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -2)
		key:SetJustifyH("RIGHT")
		key:SetJustifyV("TOP")
		skin.key = key
	end

	-- Blizzard's count frames sit at the cooldown's level; lift them over the
	-- border and the proc glow (LiftAlert puts that at the border's level + 1).
	-- Each item has only some of these, so no ipairs over a list with holes.
	for _, key in ipairs({ "ChargeCount", "Applications", "DebuffBorder" }) do
		local frame = item[key]
		if (IsUsable(frame) and frame.SetFrameLevel) then
			frame:SetFrameLevel(decor:GetFrameLevel() + 2)
		end
	end

	skins[item] = skin
	return skin
end

-- Restyles a font string and keeps what it had, once, to put it back.
local StyleText = function(skin, fontString, size, color)
	if (not fontString or not size) then return end
	local font = GetFont(size, true)
	if (not font) then return end
	if (not skin.fonts[fontString]) then
		local r, g, b, a = fontString:GetTextColor()
		skin.fonts[fontString] = {
			object = fontString:GetFontObject(),
			font = { fontString:GetFont() },
			color = { r, g, b, a }
		}
	end
	fontString:SetFontObject(font)
	if (color) then
		fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local RestoreTexts = function(skin)
	for fontString, saved in pairs(skin.fonts) do
		if (saved.object) then
			fontString:SetFontObject(saved.object)
		elseif (saved.font[1]) then
			fontString:SetFont(unpack(saved.font))
		end
		local color = saved.color
		if (color[1]) then
			fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
		end
		skin.fonts[fontString] = nil
	end
end

-- Blizzard's proc glow (ActionButtonSpellAlerts.lua) and pandemic effect
-- (CooldownViewer.lua SetupPandemicStateFrameForItem) are children of the
-- item, one level above it, so the border would draw over them. Put them over
-- the border. Icons only: Blizzard already lifts a Tracked Bars item's
-- pandemic frame over its bar, and bar items never glow.
local LiftEffect = function(skin, frame)
	if (skin.bar or not IsUsable(frame) or not frame.SetFrameLevel) then return end
	frame:SetFrameLevel(skin.decor:GetFrameLevel() + 1)
end

local LiftAlert = function(skin)
	LiftEffect(skin, skin.item.SpellActivationAlert)
	LiftEffect(skin, skin.item.PandemicIcon)
end

local DropAlert = function(skin)
	if (skin.bar) then return end
	for _, key in ipairs({ "SpellActivationAlert", "PandemicIcon" }) do
		local frame = skin.item[key]
		if (IsUsable(frame) and frame.SetFrameLevel) then
			frame:SetFrameLevel(skin.item:GetFrameLevel() + 1)
		end
	end
end

local CountColor = function()
	return { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
end

local ApplySkin = function(skin, style, showKeys, skinKey)
	local holder, icon, item = skin.holder, skin.icon, skin.item
	local iconSize = skin.size * style.icon
	local decoSize = iconSize * style.deco
	local maskPath = StyleArt(style, style.mask, skinKey)

	icon:ClearAllPoints()
	if (style.icon == 1) then
		icon:SetAllPoints(holder)
	else
		icon:SetPoint("CENTER", holder, "CENTER", 0, 0)
		icon:SetSize(iconSize, iconSize)
	end

	if (skin.mask) then
		skin.mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		skin.mask:ClearAllPoints()
		skin.mask:SetAllPoints(icon)
	end

	if (skin.overlay) then
		skin.overlay:SetAlpha(0)
	end

	-- Blizzard's out of range shade is square; give it the icon's shape.
	if (skin.range) then
		skin.range:ClearAllPoints()
		skin.range:SetAllPoints(icon)
		if (skin.mask and not skin.rangeMasked) then
			skin.range:AddMaskTexture(skin.mask)
			skin.rangeMasked = true
		end
	end

	local cooldown = skin.cooldown
	if (cooldown) then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(icon)
		cooldown:SetSwipeTexture(maskPath)
		cooldown:SetUseCircularEdge(style.circular and true or false)
	end

	skin.backdrop:SetTexture(StyleArt(style, style.backdrop, skinKey))
	skin.backdrop:SetSize(decoSize, decoSize)
	skin.backdrop:SetVertexColor(.67, .67, .67, 1)
	skin.backdrop:Show()

	skin.border:SetTexture(StyleArt(style, style.border, skinKey))
	skin.border:SetSize(decoSize, decoSize)
	skin.border:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
	skin.decor:Show()

	local fonts = FONTS[skin.viewer] or {}

	if (cooldown and fonts.cooldown) then
		local countdown = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
		local font = GetFont(fonts.cooldown, true)
		local fontName = font and font.GetName and font:GetName()
		if (countdown and fontName) then
			if (not skin.countdown) then
				skin.countdown = { countdown:GetFont() }
			end
			cooldown:SetCountdownFont(fontName)
		end
	end

	local count = CountColor()
	StyleText(skin, item.ChargeCount and item.ChargeCount.Current, fonts.count, count)
	StyleText(skin, item.Applications and item.Applications.Applications, fonts.count, count)
	if (skin.bar) then
		StyleText(skin, holder.Applications, fonts.count, count)
		StyleText(skin, skin.bar.Name, fonts.bar, Colors.offwhite)
		StyleText(skin, skin.bar.Duration, fonts.bar, Colors.offwhite)

		local bar = skin.bar
		bar:SetStatusBarTexture(Art("cast_bar"))
		bar:SetStatusBarColor(Colors.aura[1], Colors.aura[2], Colors.aura[3])
		if (bar.BarBG) then
			bar.BarBG:SetAlpha(0)
		end
		if (not skin.barBackdrop) then
			local back = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
			back:SetPoint("TOPLEFT", -1, 1)
			back:SetPoint("BOTTOMRIGHT", 1, -1)
			back:SetTexture(Art("cast_bar"))
			back:SetVertexColor(0, 0, 0, .75)
			skin.barBackdrop = back
		end
		skin.barBackdrop:Show()
	end

	if (skin.key) then
		skin.key:SetFontObject(GetFont(fonts.key, true))
		skin.key:SetTextColor(Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75)
		skin.key:SetText(showKeys and GetItemKey(item) or "")
		skin.key:SetShown(showKeys and true or false)
	end

	LiftAlert(skin)

	skin.applied = true
end

local RevertSkin = function(skin)
	if (not skin.applied) then return end

	local holder, icon, item = skin.holder, skin.icon, skin.item

	icon:ClearAllPoints()
	icon:SetAllPoints(holder)

	if (skin.mask) then
		skin.mask:SetAtlas(BLIZZARD_MASK)
		skin.mask:ClearAllPoints()
		skin.mask:SetAllPoints(holder)
	end

	if (skin.overlay) then
		skin.overlay:SetAlpha(1)
	end

	if (skin.range) then
		skin.range:ClearAllPoints()
		skin.range:SetAllPoints(holder)
		if (skin.rangeMasked) then
			skin.range:RemoveMaskTexture(skin.mask)
			skin.rangeMasked = nil
		end
	end

	local cooldown = skin.cooldown
	if (cooldown) then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(holder)
		cooldown:SetSwipeTexture(BLIZZARD_SWIPE)
		cooldown:SetUseCircularEdge(false)
		if (type(item.cooldownFont) == "string") then
			cooldown:SetCountdownFont(item.cooldownFont)
		elseif (skin.countdown and skin.countdown[1]) then
			local countdown = cooldown:GetCountdownFontString()
			if (countdown) then
				countdown:SetFont(unpack(skin.countdown))
			end
		end
	end

	RestoreTexts(skin)

	if (skin.bar) then
		local texture = skin.bar:GetStatusBarTexture()
		if (texture) then
			texture:SetAtlas(BLIZZARD_BAR)
		end
		skin.bar:SetStatusBarColor(unpack(BLIZZARD_BAR_COLOR))
		if (skin.bar.BarBG) then
			skin.bar.BarBG:SetAlpha(1)
		end
		if (skin.barBackdrop) then
			skin.barBackdrop:Hide()
		end
	end

	DropAlert(skin)

	skin.backdrop:Hide()
	skin.decor:Hide()
	skin.applied = nil
end

-------------------------------------------------------------------------------
-- Viewers
-------------------------------------------------------------------------------

local EnumerateItems = function(viewer, callback)
	local pool = viewer.itemFramePool
	if (not pool or not pool.EnumerateActive) then return end
	for item in pool:EnumerateActive() do
		callback(item)
	end
end

CooldownManager.ShouldStyle = function(self)
	return self.db.profile.styleIcons and not self.rival
end

CooldownManager.GetStyle = function(self)
	return STYLES[self.db.profile.iconStyle] or STYLES.rounded
end

-- The skin in use: the saved one while it is available, the interface theme otherwise.
CooldownManager.GetSkin = function(self)
	local key = self.db.profile.skin
	if (type(key) == "string" and IsSkinAvailable(key)) then return key end
	return "theme"
end

-- The skins the options page offers, in order.
CooldownManager.GetSkinChoices = function(self)
	local choices = {}
	for _, key in ipairs(SKIN_ORDER) do
		if (IsSkinAvailable(key)) then choices[#choices + 1] = key end
	end
	return choices
end

CooldownManager.StyleItem = function(self, viewerName, item)
	if (not IsUsable(item)) then return end
	if (not self:ShouldStyle()) then
		local skin = skins[item]
		if (skin) then RevertSkin(skin) end
		return
	end
	local skin = GetSkin(item, viewerName)
	if (skin) then
		ApplySkin(skin, self:GetStyle(), self.db.profile.showKeybinds, self:GetSkin())
	end
end

CooldownManager.StyleViewer = function(self, viewerName)
	local viewer = _G[viewerName]
	if (not IsUsable(viewer)) then return end
	EnumerateItems(viewer, function(item) self:StyleItem(viewerName, item) end)
end

CooldownManager.UpdateKeybinds = function(self, viewerName)
	if (not self:ShouldStyle()) then return end
	local viewer = _G[viewerName]
	if (not IsUsable(viewer)) then return end
	local showKeys = self.db.profile.showKeybinds
	EnumerateItems(viewer, function(item)
		local skin = skins[item]
		if (skin and skin.applied and skin.key) then
			skin.key:SetText(showKeys and GetItemKey(item) or "")
		end
	end)
end

CooldownManager.UpdateAll = function(self)
	for _, viewerName in ipairs(VIEWERS) do
		self:StyleViewer(viewerName)
	end
end

-- Post-hooks only. RefreshLayout re-acquires every item, RefreshData follows
-- each cooldown data change (a new spell on a slot means a new key).
CooldownManager.HookViewer = function(self, viewerName)
	local viewer = _G[viewerName]
	if (not IsUsable(viewer)) then return end
	self.hooked = self.hooked or {}
	if (self.hooked[viewerName]) then return end
	self.hooked[viewerName] = true

	if (type(viewer.OnAcquireItemFrame) == "function") then
		hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item) self:StyleItem(viewerName, item) end)
	end
	if (type(viewer.RefreshData) == "function") then
		hooksecurefunc(viewer, "RefreshData", function() self:UpdateKeybinds(viewerName) end)
	end
	if (type(viewer.UpdateSystemSettingOpacity) == "function") then
		hooksecurefunc(viewer, "UpdateSystemSettingOpacity", function() self:ApplyFade(viewer) end)
	end
	-- The pandemic frame comes from a pool and is parented here, before the
	-- item stores it, so it is lifted when anchored.
	if (type(viewer.AnchorPandemicStateFrame) == "function") then
		hooksecurefunc(viewer, "AnchorPandemicStateFrame", function(_, frame, item)
			local skin = item and skins[item]
			if (skin and skin.applied) then LiftEffect(skin, frame) end
		end)
	end
end

-------------------------------------------------------------------------------
-- Explorer Mode
-------------------------------------------------------------------------------

-- The viewer's own Edit Mode opacity, 0 to 1.
local GetOpacity = function(viewer)
	local setting = Enum and Enum.EditModeCooldownViewerSetting and Enum.EditModeCooldownViewerSetting.Opacity
	if (setting and viewer.GetSettingValue) then
		local ok, value = pcall(viewer.GetSettingValue, viewer, setting)
		value = ok and Plain(value)
		if (type(value) == "number") then
			return value / 100
		end
	end
	return 1
end

CooldownManager.ApplyFade = function(self, viewer)
	local alpha = fadeAlpha[viewer]
	if (alpha == nil) then return end
	viewer:SetAlpha(GetOpacity(viewer) * alpha)
	if (alpha >= 1) then
		fadeAlpha[viewer] = nil
	end
end

-- One proxy per viewer for LibFadingFrames to fade, covering the viewer so
-- hovering it brings the interface back like any other faded element.
-- Called by Core/ExplorerMode.lua.
CooldownManager.GetFadeFrames = function(self)
	if (self.rival) then return {} end
	if (not self.fadeFrames) then
		self.fadeFrames = {}
		for _, viewerName in ipairs(VIEWERS) do
			local viewer = _G[viewerName]
			if (IsUsable(viewer)) then
				local proxy = CreateFrame("Frame", nil, UIParent)
				proxy:SetAllPoints(viewer)
				proxy:EnableMouse(false)
				proxy.OnFadeAlphaChanged = function(_, alpha)
					fadeAlpha[viewer] = alpha
					self:ApplyFade(viewer)
				end
				table_insert(self.fadeFrames, proxy)
			end
		end
	end
	return self.fadeFrames
end

-- What the options panel outlines for this page's settings.
CooldownManager.GetOptionsPreviewFrame = function(self)
	return _G.EssentialCooldownViewer
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

-- Every bar and binding event lands here; a burst of them rebuilds once.
-- In combat the old map is kept, since the action info could come back secret.
CooldownManager.QueueKeybinds = function(self)
	if (InCombatLockdown()) then
		self.keybindsPending = true
		return
	end
	if (self.keybindsQueued) then return end
	self.keybindsQueued = true
	C_Timer.After(.2, function()
		self.keybindsQueued = nil
		if (InCombatLockdown()) then
			self.keybindsPending = true
			return
		end
		RebuildKeybinds()
		for _, viewerName in ipairs(VIEWERS) do
			self:UpdateKeybinds(viewerName)
		end
	end)
end

CooldownManager.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_ENABLED") then
		if (not self.keybindsPending) then return end
		self.keybindsPending = nil
	end
	self:QueueKeybinds()
end

CooldownManager.UpdateSettings = function(self)
	self:UpdateAll()
	self:QueueKeybinds()
end

CooldownManager.GetRival = function(self)
	return self.rival
end

CooldownManager.OnInitialize = function(self)
	self.db = ns.db:RegisterNamespace(self:GetName(), self:GetDefaults())
	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateSettings")
end

CooldownManager.OnEnable = function(self)
	if (not _G.EssentialCooldownViewer) then return end

	for _, addon in ipairs(RIVALS) do
		if (IsAddOnEnabled(addon)) then
			self.rival = addon
			return
		end
	end

	for _, viewerName in ipairs(VIEWERS) do
		self:HookViewer(viewerName)
	end

	-- The glow frame is created on its first show, after the item was styled.
	local alerts = ActionButtonSpellAlertManager
	if (type(alerts) == "table" and type(alerts.ShowAlert) == "function" and not self.alertHooked) then
		self.alertHooked = true
		hooksecurefunc(alerts, "ShowAlert", function(_, button)
			local skin = button and skins[button]
			if (skin and skin.applied) then LiftAlert(skin) end
		end)
	end

	for _, event in ipairs({
		"UPDATE_BINDINGS",
		"ACTIONBAR_SLOT_CHANGED",
		"ACTIONBAR_PAGE_CHANGED",
		"UPDATE_BONUS_ACTIONBAR",
		"SPELLS_CHANGED",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED"
	}) do
		if (ns.API.IsEventAvailable(event)) then
			self:RegisterEvent(event, "OnEvent")
		end
	end

	-- Items Blizzard built before this module loaded.
	self:UpdateAll()
	self:QueueKeybinds()
end

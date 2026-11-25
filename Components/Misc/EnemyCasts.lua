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
--[[
	Enemy Casts: a movable list of the spells hostile units are casting.

	Each row: spell icon, a timer bar run by the engine (SetTimerDuration), the spell name and
	time left, the caster's raid marker and name, and who the spell is aimed at in its class
	colour, dressed as AzeriteUI castbars (see Rows). Marks: the spiked casing and a grey fill
	when it cannot be interrupted, a red glow when it is aimed at you, a gold outline on your
	current target's row. Out of combat a left click on a row targets its unit
	(SyncClickButtons explains why only then).

	Sources, in priority order: target, focus, boss1-5, arena1-5, then enemy nameplates. A
	unit with a nameplate is listed once, under its nameplate; units without one (a boss with
	plates off) are listed under their own token.

	Secret values (WoW 12 and Forever): cast names, icons, durations, the cast's target, the
	raid marker and interrupt state can all be secret. None of them is compared, tested or
	joined here; they go straight into SetText, SetTexture, SetTimerDuration, SetTextColor,
	SetSpriteSheetCell and SetAlphaFromBoolean, which accept them, as the nameplate castbar
	does (NamePlates/Castbar.lua NamePlate_UpdateCastTargetVisuals). The rows never
	take the mouse; only the separate secure click buttons do.
]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local EnemyCasts = ns:NewModule("EnemyCasts", ns.MovableModulePrototype, "LibMoreEvents-1.0")

-- Lua API
local ipairs = ipairs
local math_max = math.max
local next = next
local table_sort = table.sort
local tonumber = tonumber
local type = type
local unpack = unpack

-- Addon API
local API = ns.API
local Colors = ns.Colors
local GetFont = API.GetFont
local GetMedia = API.GetMedia

local ROW_HEIGHT = 54
local ROW_SPACING = 6
local ICON_SIZE = 28
local BAR_HEIGHT = 12
local UPDATE_TEXT = .1 -- time text
local UPDATE_CHECK = .5 -- missed stops, cast targets, interrupted hold
local INTERRUPT_HOLD = .8

local INTERPOLATION_IMMEDIATE = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
local DIRECTION_ELAPSED = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
local DIRECTION_REMAINING = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

local defaults = { profile = ns:Merge({
	enabled = false,
	mode = "all", -- "all" enemies or "target" only
	maxRows = 5,
	width = 260,
	growUp = false,
	showSpellTarget = true,
	previewCasts = 3 -- example casts in the /lock and Edit Mode ghost
}, ns.MovableModulePrototype.defaults) }

-- Maintainer's placement (2026-11-25): middle right side, X -350, Y 85, scale 71.1 at
-- 1080p (effective scale 768/1080). Stored as base values times the effective scale, as
-- every module's default is, so it lands in the same place on other screens and scales.
EnemyCasts.GenerateDefaults = function(self)
	local scale = API.GetEffectiveScale()
	defaults.profile.savedPosition = {
		scale = scale,
		[1] = "RIGHT",
		[2] = -492.1875 * scale,
		[3] = 119.53125 * scale
	}
	return defaults
end

-- Helpers
--------------------------------------------
local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

-- A value that is there: any secret, or a plain non-nil. Never compares a secret.
local HasValue = function(value)
	return IsSecret(value) or value ~= nil
end

local SecretOr = function(value, valueType)
	return IsSecret(value) or type(value) == valueType
end

-- Every source token, in priority order.
local SOURCE_UNITS = { "target", "focus" }
for i = 1, 5 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "boss" .. i end
for i = 1, 5 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "arena" .. i end
local PRIORITY = {}
for index, unit in ipairs(SOURCE_UNITS) do PRIORITY[unit] = index end

local IsWatchedUnit = function(unit)
	if (type(unit) ~= "string") then return false end
	return PRIORITY[unit] ~= nil or unit:match("^nameplate%d+$") ~= nil
end

local GetPriority = function(unit)
	return PRIORITY[unit] or 100
end

local IsHostile = function(unit)
	if (type(UnitExists) == "function") then
		local ok, exists = API.TryCall(UnitExists, unit)
		if (not ok or exists ~= true) then return false end
	end
	local ok, canAttack = API.TryCall(UnitCanAttack, "player", unit)
	return ok and canAttack == true
end

local GetPlate = function(unit)
	if (not C_NamePlate or not C_NamePlate.GetNamePlateForUnit) then return nil end
	local ok, plate = API.TryCall(C_NamePlate.GetNamePlateForUnit, unit)
	if (ok and type(plate) == "table") then return plate end
	return nil
end

-- The first of the two that is there. Written out as ifs on purpose: `a and a or b` would
-- truth-test a, and testing a secret value raises an error.
local FirstValue = function(a, b)
	if (HasValue(a)) then return a end
	return b
end

-- A duration object, or nil. The object may be secret; it is only handed to SetTimerDuration.
local GetDuration = function(getter, unit)
	local ok, duration = API.TryCall(getter, unit)
	if (ok and HasValue(duration)) then return duration end
	return nil
end

-- What the unit is casting right now: kind ("cast", "channel", "empower") plus display data,
-- or nil. Secret values pass through untouched.
local QueryCast = function(unit)
	local ok, name, text, texture, _, _, _, _, notInterruptible, spellID = API.TryCall(UnitCastingInfo, unit)
	if (ok and HasValue(name)) then
		return "cast", FirstValue(text, name), texture, notInterruptible, spellID, GetDuration(UnitCastingDuration, unit)
	end
	local isEmpowered
	ok, name, text, texture, _, _, _, notInterruptible, spellID, isEmpowered = API.TryCall(UnitChannelInfo, unit)
	if (ok and HasValue(name)) then
		local kind, getter = "channel", UnitChannelDuration
		if (not IsSecret(isEmpowered) and isEmpowered) then
			kind, getter = "empower", UnitEmpoweredChannelDuration or UnitChannelDuration
		end
		return kind, FirstValue(text, name), texture, notInterruptible, spellID, GetDuration(getter, unit)
	end
	return nil
end

-- Rows
--------------------------------------------
-- Each row is a small AzeriteUI castbar, in the player castbar's dress
-- (Layouts/Data/PlayerCastBar.lua): the cast_bar fill in Colors.cast inside the metal
-- cast_back casing, which turns into the spiked cast_back_spiked casing when the cast
-- cannot be interrupted. The icon wears the aura border (AuraStyling.lua). Your target
-- gets the casing's own outline in the nameplate target colour (NamePlates
-- TargetHighlightTargetColor); a cast aimed at you gets the nameplate castbar's red glow
-- (CastBarTargetedGlowColor). Geometry was checked against rendered art at 1x and 2x.
local CASING_SIDE = 16 -- the casing's metal reaches about 15.7 past each bar end
local BAR_LEFT = 6 + ICON_SIZE + 8 + CASING_SIDE
local BAR_TOP = 16
local BAR_RIGHT_INSET = CASING_SIDE + 2

local CAST_COLOR = { Colors.cast[1], Colors.cast[2], Colors.cast[3], .69 }
local TARGET_OUTLINE_COLOR = { 255/255, 239/255, 169/255 } -- NamePlates TargetHighlightTargetColor
local AIMED_GLOW_COLOR = { 1, 64/255, 64/255 } -- NamePlates CastBarTargetedGlowColor

-- The casings are 256x128 art drawn 193x93 around a 111 wide bar; the metal spans 189 of
-- the 256 texels, so the casing is sized from the bar width to keep the ends in place.
local SizeCasing = function(bar)
	local width = bar:GetWidth()
	if (type(width) ~= "number" or width <= 0) then return end
	local casingWidth = (width + 31.5) * 256 / 189
	for _, texture in ipairs(bar.casings) do
		texture:SetSize(casingWidth, 93)
	end
	bar.AimedGlow:SetSize(casingWidth * 189 / 256 + 28, 58)
end

local CreateCasing = function(bar, media, sublevel)
	local casing = bar:CreateTexture(nil, "BACKGROUND", nil, sublevel)
	casing:SetPoint("CENTER", bar, "CENTER", 1, -1)
	casing:SetTexture(GetMedia(media))
	casing:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])
	bar.casings[#bar.casings + 1] = casing
	return casing
end

local CreateRow = function(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:EnableMouse(false)
	row:Hide()

	local icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("CENTER", row, "TOPLEFT", 6 + ICON_SIZE / 2, -(BAR_TOP + BAR_HEIGHT / 2))
	icon:SetTexCoord(.08, .92, .08, .92)
	if (icon.SetMask) then icon:SetMask(GetMedia("actionbutton-mask-square")) end
	row.Icon = icon

	-- The aura border, as on unit frame auras.
	if (ns.AuraStyles and ns.AuraStyles.CreateTextureBorder) then
		local border = ns.AuraStyles.CreateTextureBorder(row)
		border:SetBackdropBorderColor(Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3])
		border:SetPoint("TOPLEFT", icon, "TOPLEFT", -6, 6)
		border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 6, -6)
		row.IconBorder = border
	end

	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_LEFT, -BAR_TOP)
	bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -BAR_RIGHT_INSET, -BAR_TOP)
	bar:SetHeight(BAR_HEIGHT)
	bar:SetStatusBarTexture(GetMedia("cast_bar"))
	bar:SetStatusBarColor(unpack(CAST_COLOR))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar.casings = {}
	row.Bar = bar

	-- Aimed at you: the nameplate castbar's red glow, behind the metal.
	local glow = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	glow:SetPoint("CENTER", bar, "CENTER", 1, -1)
	glow:SetTexture(GetMedia("nameplate_glow"))
	glow:SetVertexColor(unpack(AIMED_GLOW_COLOR))
	glow:SetAlpha(0)
	bar.AimedGlow = glow
	row.AimedEdge = glow

	-- Casing, and the spiked casing when it cannot be interrupted (alpha from a possibly
	-- secret boolean, the two the other way round: SetRowInterruptible).
	row.Casing = CreateCasing(bar, "cast_back", -6)
	row.Shield = CreateCasing(bar, "cast_back_spiked", -5)
	row.Shield:SetAlpha(0)

	-- Your target: the casing's outline, over everything.
	local outline = CreateCasing(bar, "cast_back_outline", 7)
	outline:SetDrawLayer("OVERLAY", 7)
	outline:SetVertexColor(unpack(TARGET_OUTLINE_COLOR))
	outline:SetAlpha(0)
	row.TargetEdge = outline

	-- The fill again in grey over the coloured one while it cannot be interrupted.
	local locked = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	locked:SetAllPoints(bar:GetStatusBarTexture())
	locked:SetTexture(GetMedia("cast_bar"))
	locked:SetVertexColor(Colors.gray[1], Colors.gray[2], Colors.gray[3], .9)
	locked:SetAlpha(0)
	row.Locked = locked

	bar:SetScript("OnSizeChanged", SizeCasing)

	ns.API.CreateCastBarSpark(bar)

	local spell = bar:CreateFontString(nil, "OVERLAY", nil, 1)
	spell:SetFontObject(GetFont(12, true))
	spell:SetTextColor(unpack(Colors.highlight))
	spell:SetJustifyH("LEFT")
	spell:SetWordWrap(false)
	spell:SetPoint("LEFT", bar, "LEFT", 3, 0)
	spell:SetPoint("RIGHT", bar, "RIGHT", -34, 0)
	row.Spell = spell

	local time = bar:CreateFontString(nil, "OVERLAY", nil, 1)
	time:SetFontObject(GetFont(12, true))
	time:SetTextColor(unpack(Colors.offwhite))
	time:SetJustifyH("RIGHT")
	time:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	row.Time = time

	-- Under the casing: marker, caster, "»" and the cast's target. Secret names cannot be
	-- joined into one string, so each has its own FontString.
	local marker = row:CreateTexture(nil, "OVERLAY", nil, 1)
	marker:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
	marker:SetSize(12, 12)
	marker:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -13)
	marker:Hide()
	row.Marker = marker

	local caster = row:CreateFontString(nil, "OVERLAY", nil, 1)
	caster:SetFontObject(GetFont(11, true))
	caster:SetTextColor(unpack(Colors.offwhite))
	caster:SetJustifyH("LEFT")
	caster:SetWordWrap(false)
	caster:SetPoint("LEFT", marker, "RIGHT", 3, 0)
	caster:SetPoint("RIGHT", bar, "BOTTOM", -7, -19)
	row.Caster = caster

	local arrow = row:CreateFontString(nil, "OVERLAY", nil, 1)
	arrow:SetFontObject(GetFont(11, true))
	arrow:SetTextColor(unpack(Colors.offwhite))
	arrow:SetPoint("CENTER", bar, "BOTTOM", 0, -19)
	arrow:SetText("\194\187") -- »
	arrow:Hide()
	row.Arrow = arrow

	local target = row:CreateFontString(nil, "OVERLAY", nil, 1)
	target:SetFontObject(GetFont(11, true))
	target:SetTextColor(unpack(Colors.offwhite))
	target:SetJustifyH("LEFT")
	target:SetWordWrap(false)
	target:SetPoint("LEFT", bar, "BOTTOM", 7, -19)
	target:SetPoint("RIGHT", bar, "BOTTOMRIGHT", CASING_SIDE, -19)
	row.Target = target

	return row
end

-- Who the cast is aimed at, as NamePlate_ApplyCastTargetName does.
local UpdateRowSpellTarget = function(row, unit, show)
	row.Target:SetText("")
	row.Arrow:Hide()
	row.AimedEdge:SetAlpha(0)

	if (type(PlayerIsSpellTarget) == "function") then
		local ok, targeted = API.TryCall(PlayerIsSpellTarget, unit)
		if (ok and SecretOr(targeted, "boolean")) then
			API.TryCall(row.AimedEdge.SetAlphaFromBoolean, row.AimedEdge, targeted, 255, 0)
		end
	end

	if (not show or type(UnitSpellTargetName) ~= "function") then
		return
	end
	if (type(UnitShouldDisplaySpellTargetName) == "function") then
		local okShow, display = API.TryCall(UnitShouldDisplaySpellTargetName, unit)
		if (not okShow or (not IsSecret(display) and display ~= true)) then
			return
		end
	end
	local okName, name = API.TryCall(UnitSpellTargetName, unit)
	if (not okName or not SecretOr(name, "string")) then
		return
	end
	row.Target:SetText(name)
	row.Target:SetTextColor(unpack(Colors.offwhite))
	row.Arrow:Show()
	if (type(UnitSpellTargetClass) ~= "function" or not (C_ClassColor and C_ClassColor.GetClassColor)) then
		return
	end
	local okClass, classFile = API.TryCall(UnitSpellTargetClass, unit)
	if (not okClass or not SecretOr(classFile, "string")) then
		return
	end
	API.TryCall(function()
		local color = C_ClassColor.GetClassColor(classFile)
		if (color) then
			local r, g, b = color:GetRGB()
			row.Target:SetTextColor(r, g, b, 1)
		end
	end)
end

local UpdateRowMarker = function(row, unit)
	local marker = row.Marker
	local ok, index = API.TryCall(GetRaidTargetIndex, unit)
	if (not ok) then
		marker:Hide()
		return
	end
	if (IsSecret(index)) then
		-- A secret index is only handed to the sprite sheet, never tested.
		if (API.TryCall(marker.SetSpriteSheetCell, marker, index, 4, 4)) then
			marker:Show()
		else
			marker:Hide()
		end
	elseif (type(index) == "number" and index > 0) then
		-- What Blizzard's SetRaidTargetIconTexture does (TargetFrame.lua), without needing it.
		if (API.TryCall(marker.SetSpriteSheetCell, marker, index, 4, 4)) then
			marker:Show()
		else
			marker:Hide()
		end
	else
		marker:Hide()
	end
end

local SetRowInterruptible = function(row, notInterruptible)
	if (SecretOr(notInterruptible, "boolean")) then
		API.TryCall(row.Locked.SetAlphaFromBoolean, row.Locked, notInterruptible, 255, 0)
		API.TryCall(row.Shield.SetAlphaFromBoolean, row.Shield, notInterruptible, 255, 0)
		API.TryCall(row.Casing.SetAlphaFromBoolean, row.Casing, notInterruptible, 0, 255)
	else
		row.Locked:SetAlpha(0)
		row.Shield:SetAlpha(0)
		row.Casing:SetAlpha(1)
	end
end

local SetRowTimer = function(row, kind, duration)
	local bar = row.Bar
	local direction = (kind == "channel") and DIRECTION_REMAINING or DIRECTION_ELAPSED
	local ok = false
	if (HasValue(duration) and bar.SetTimerDuration) then
		ok = API.TryCall(bar.SetTimerDuration, bar, duration, INTERPOLATION_IMMEDIATE, direction)
	end
	if (not ok) then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(kind == "channel" and 1 or 0)
	end
end

-- Mover preview (/lock and Edit Mode)
--------------------------------------------
-- Core/MoverGhosts.lua calls BuildMoverGhost while the list is empty and the movers are
-- shown. The ghost uses the real rows filled with made-up casts, so their size, spacing
-- and direction match the list exactly. Nothing here reads a unit; it runs out of combat.
local PREVIEW_SPELLS = { 686, 116, 2061, 133, 403 } -- Shadow Bolt, Frostbolt, Flash Heal, Fireball, Lightning Bolt
local PREVIEW_FALLBACK = { "Shadow Bolt", "Frostbolt", "Flash Heal", "Fireball", "Lightning Bolt" }
local PREVIEW_MARKERS = { 8, 7, 1, 2, 3 }
local PREVIEW_VALUES = { .35, .6, .2, .8, .5 }

-- A Blizzard global string (localized), or the English fallback when the client lacks it.
local GlobalText = function(name, fallback)
	local value = _G[name]
	if (type(value) == "string" and not IsSecret(value)) then return value end
	return fallback
end

local GetPreviewSpell = function(index)
	local slot = (index - 1) % #PREVIEW_SPELLS + 1
	local id = PREVIEW_SPELLS[slot]
	local name, icon
	if (C_Spell and C_Spell.GetSpellInfo) then
		local ok, info = pcall(C_Spell.GetSpellInfo, id)
		if (ok and type(info) == "table") then name, icon = info.name, info.iconID end
	elseif (GetSpellInfo) then
		local ok, spellName, _, spellIcon = pcall(GetSpellInfo, id)
		if (ok) then name, icon = spellName, spellIcon end
	end
	if (type(name) ~= "string" or IsSecret(name)) then name = PREVIEW_FALLBACK[slot] end
	if (IsSecret(icon) or (type(icon) ~= "number" and type(icon) ~= "string")) then
		icon = [[Interface\Icons\INV_Misc_QuestionMark]]
	end
	return name, icon, slot
end

-- Who each example is aimed at: you (red edge), a tank, a healer, nobody, a damage dealer.
local GetPreviewTarget = function(slot)
	local classColor = function(classFile)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
		if (color) then return color.r, color.g, color.b end
		return 1, 1, 1
	end
	if (slot == 1) then
		local name = UnitName and UnitName("player")
		local _, classFile = UnitClass and UnitClass("player")
		if (type(name) ~= "string" or IsSecret(name)) then name = GlobalText("YOU", "You") end
		if (IsSecret(classFile)) then classFile = nil end
		-- Not `return name, classColor(...), true`: a call before the last value gives only one.
		local r, g, b = classColor(classFile or "WARRIOR")
		return name, r, g, b, true
	elseif (slot == 2) then
		return GlobalText("TANK", "Tank"), classColor("WARRIOR")
	elseif (slot == 3) then
		return GlobalText("HEALER", "Healer"), classColor("PRIEST")
	elseif (slot == 5) then
		return GlobalText("DAMAGER", "Damage"), classColor("MAGE")
	end
end

local FillPreviewRow = function(row, index)
	local name, icon, slot = GetPreviewSpell(index)
	row.Icon:SetTexture(icon)
	row.Spell:SetText(name)
	row.Bar:SetStatusBarColor(unpack(CAST_COLOR))
	row.Bar:SetMinMaxValues(0, 1)
	row.Bar:SetValue(PREVIEW_VALUES[slot])
	row.Time:SetFormattedText("%.1f", 2.5 * (1 - PREVIEW_VALUES[slot]))
	if (row.Bar.Spark) then row.Bar.Spark:Show() end

	local locked = slot == 2
	row.Locked:SetAlpha(locked and 1 or 0)
	row.Shield:SetAlpha(locked and 1 or 0)
	row.Casing:SetAlpha(locked and 0 or 1)

	row.Caster:SetText(string.format("%s %d", GlobalText("ENEMY", "Enemy"), index))
	row.Marker:SetSpriteSheetCell(PREVIEW_MARKERS[slot], 4, 4)
	row.Marker:Show()

	local target, r, g, b, atMe = GetPreviewTarget(slot)
	if (target) then
		row.Target:SetText(target)
		row.Target:SetTextColor(r, g, b, 1)
		row.Arrow:Show()
	else
		row.Target:SetText("")
		row.Arrow:Hide()
	end
	row.AimedEdge:SetAlpha(atMe and 1 or 0)

	-- The first example stands for your current target.
	row.TargetEdge:SetAlpha(index == 1 and 1 or 0)
end

-- An example list: the list's own rows filled with made-up casts, in a frame laid over
-- `box` at the list's size and scale. Used by the /lock ghost and the options preview.
local CreateExampleList = function(box)
	local list = CreateFrame("Frame", nil, box)
	list:EnableMouse(false)
	list:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	list.box = box
	list.rows = {}
	return list
end

-- Sizes an example list like the real one and shows the configured number of examples,
-- in the list's direction. Follows width, row count and direction changes live.
EnemyCasts.LayoutExampleList = function(self, list)
	local frame, db = self.frame, self.db.profile
	if (not list or not frame) then return end
	local width, height = frame:GetSize()
	local boxWidth = list.box:GetWidth()
	if (type(width) == "number" and width > 0 and type(boxWidth) == "number" and boxWidth > 0) then
		list:SetScale(boxWidth / width)
	elseif (list.box.GetEffectiveScale and frame.GetEffectiveScale) then
		-- Size not resolved yet: the list's own scale relative to the box's.
		local boxScale = list.box:GetEffectiveScale()
		if (type(boxScale) == "number" and boxScale > 0) then
			list:SetScale(frame:GetEffectiveScale() / boxScale)
		end
	end
	list:SetSize(width, height)

	local maxRows = math_max(1, tonumber(db.maxRows) or 5)
	local count = math_max(1, math.min(maxRows, tonumber(db.previewCasts) or 3))
	for index = #list.rows + 1, maxRows do
		local row = CreateRow(list)
		FillPreviewRow(row, index)
		list.rows[index] = row
	end
	for index, row in ipairs(list.rows) do
		local offset = (index - 1) * (ROW_HEIGHT + ROW_SPACING)
		row:ClearAllPoints()
		if (db.growUp) then
			row:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, offset)
			row:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, offset)
		else
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -offset)
			row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -offset)
		end
		row:SetShown(index <= count)
	end
end

-- Re-lays every example list after a settings change.
EnemyCasts.UpdateMoverGhost = function(self)
	self:LayoutExampleList(self.moverGhost)
	self:LayoutExampleList(self.previewList)
end

-- Called by Core/MoverGhosts.lua with a container the size of the mover. The mover is
-- sized to the scaled list, so the example rows get the list's own size and scale.
EnemyCasts.BuildMoverGhost = function(self, container)
	if (not self.frame) then return end
	local list = CreateExampleList(container)
	self.moverGhost = list
	self:LayoutExampleList(list)
	return true
end

-- Options preview: the example list on the real list's spot, out of /lock, so every
-- setting can be changed and seen at once. Not saved; it turns off when combat starts,
-- when the options window closes and when the list is turned off.
EnemyCasts.IsPreviewShown = function(self)
	return self.previewBox and self.previewBox:IsShown() or false
end

EnemyCasts.SetPreviewShown = function(self, show)
	if (not self.frame) then return end
	if (show and not self.db.profile.enabled) then show = false end
	if (show and InCombatLockdown()) then show = false end
	if (not show) then
		if (self.previewBox) then self.previewBox:Hide() end
		return
	end
	if (not self.previewBox) then
		local box = CreateFrame("Frame", nil, UIParent)
		-- Above the options window (HIGH, Options/Kit/Panel.lua), which would otherwise
		-- cover the list's spot. It takes no mouse, so the settings under it stay usable.
		box:SetFrameStrata("DIALOG")
		box:EnableMouse(false)
		box:SetAllPoints(self.frame)
		box:RegisterEvent("PLAYER_REGEN_DISABLED")
		box:SetScript("OnEvent", function(frame) frame:Hide() end)
		-- The box's size may only resolve on the next layout pass; lay out again then.
		box:SetScript("OnSizeChanged", function() self:LayoutExampleList(self.previewList) end)
		box:Hide()
		self.previewBox = box
		self.previewList = CreateExampleList(box)
	end
	self.previewBox:Show()
	self:LayoutExampleList(self.previewList)
	-- Closing the options window ends the preview.
	local panel = ns.OptionsKit and ns.OptionsKit.Panel and ns.OptionsKit.Panel.frame
	if (panel and not self.previewPanelHooked) then
		self.previewPanelHooked = true
		panel:HookScript("OnHide", function() self:SetPreviewShown(false) end)
	end
end

-- Click to target (out of combat only)
--------------------------------------------
-- A secure button over each row targets the row's unit on left click. The game lets no
-- addon change a secure button's unit, or show, hide or move it, in combat, and the list
-- re-sorts as casts come and go, so the buttons only exist out of combat:
--  * they live in their own secure container whose state driver hides it the moment combat
--    starts ("[combat] hide; show"), so a stale button can never target the wrong mob;
--  * they are placed over their rows by screen position, not anchored to them, so the
--    insecure list and rows never become protected and keep updating in combat;
--  * everything secure is created and changed only while InCombatLockdown() is false.
local IsMoverModeOpen = function()
	local manager = ns:GetModule("MovableFramesManager", true)
	return manager and manager.IsMFMFrameOpen and manager:IsMFMFrameOpen() and true or false
end

EnemyCasts.GetClickButton = function(self, index)
	if (not self.clickContainer) then
		local container = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
		container:SetFrameStrata("MEDIUM")
		RegisterStateDriver(container, "visibility", "[combat] hide; show")
		self.clickContainer = container
		self.clickButtons = {}
	end
	local button = self.clickButtons[index]
	if (not button) then
		button = CreateFrame("Button", nil, self.clickContainer, "SecureUnitButtonTemplate")
		button:SetFrameStrata("MEDIUM")
		button:SetFrameLevel(self.frame:GetFrameLevel() + 20)
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("type1", "target")
		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, .12)
		button:Hide()
		self.clickButtons[index] = button
	end
	return button
end

-- Puts a click button over every shown row, out of combat. Safe to call any time.
EnemyCasts.SyncClickButtons = function(self)
	if (InCombatLockdown()) then return end
	local rows = self.frame.rows
	local active = self.active and self.frame:IsShown() and not IsMoverModeOpen()
	local uiScale = UIParent:GetEffectiveScale()
	for index, row in ipairs(rows) do
		local unit = row.unit
		if (active and unit and row:IsShown()) then
			local left, bottom, width, height = row:GetRect()
			if (type(left) == "number" and type(width) == "number" and width > 0 and uiScale > 0) then
				local button = self:GetClickButton(index)
				local scale = row:GetEffectiveScale() / uiScale
				button:ClearAllPoints()
				button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
				button:SetSize(width * scale, height * scale)
				button:SetAttribute("unit", unit)
				button:Show()
			end
		elseif (self.clickButtons and self.clickButtons[index]) then
			self.clickButtons[index]:SetAttribute("unit", nil)
			self.clickButtons[index]:Hide()
		end
	end
	if (self.clickButtons) then
		for index = #rows + 1, #self.clickButtons do
			self.clickButtons[index]:SetAttribute("unit", nil)
			self.clickButtons[index]:Hide()
		end
	end
end

-- Module
--------------------------------------------
EnemyCasts.PrepareFrames = function(self)
	if (self.frame) then return end

	local frame = CreateFrame("Frame", ns.Prefix .. "EnemyCasts", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(false)
	frame:Hide()
	frame.rows = {}
	self.frame = frame

	-- Cast state per unit token: { kind, start, interrupted }.
	self.casts = {}

	local textElapsed, checkElapsed = 0, 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		textElapsed = textElapsed + elapsed
		checkElapsed = checkElapsed + elapsed
		if (textElapsed >= UPDATE_TEXT) then
			textElapsed = 0
			self:UpdateTimeTexts()
		end
		if (checkElapsed >= UPDATE_CHECK) then
			checkElapsed = 0
			self:CheckCasts()
		end
	end)

	local events = CreateFrame("Frame")
	events:SetScript("OnEvent", function(_, event, ...) self:OnCastEvent(event, ...) end)
	self.eventFrame = events
end

EnemyCasts.PositionRow = function(self, row, index)
	local frame = self.frame
	local offset = (index - 1) * (ROW_HEIGHT + ROW_SPACING)
	row:ClearAllPoints()
	if (self.db.profile.growUp) then
		row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, offset)
		row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, offset)
	else
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -offset)
		row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -offset)
	end
end

EnemyCasts.GetRow = function(self, index)
	local rows = self.frame.rows
	local row = rows[index]
	if (not row) then
		row = CreateRow(self.frame)
		rows[index] = row
		self:PositionRow(row, index)
	end
	return row
end

-- Size and row positions; settings changes only, never per cast.
EnemyCasts.UpdateLayout = function(self)
	local frame, db = self.frame, self.db.profile
	local width = math_max(160, tonumber(db.width) or 260)
	local maxRows = math_max(1, tonumber(db.maxRows) or 5)
	frame:SetSize(width, maxRows * ROW_HEIGHT + (maxRows - 1) * ROW_SPACING)
	for index, row in ipairs(frame.rows) do
		self:PositionRow(row, index)
	end
	if (self.anchor) then
		self:UpdateAnchor()
	end
end

-- Whether a unit token belongs in the list, and is not already listed under a better token.
EnemyCasts.IsListed = function(self, unit, listed)
	if (self.db.profile.mode == "target") then
		return unit == "target"
	end
	if (not unit:match("^nameplate%d+$")) then
		-- A unit with a nameplate is listed under the nameplate.
		if (GetPlate(unit)) then return false end
		for other in next, listed do
			if (API.SafeUnitIsUnit(unit, other)) then return false end
		end
	end
	return true
end

local SortRows = function(a, b)
	if (a.start ~= b.start) then return a.start < b.start end
	return GetPriority(a.unit) < GetPriority(b.unit)
end

-- Rebuilds which unit sits in which row. Only called on events, not every frame.
EnemyCasts.UpdateRows = function(self)
	local frame, db = self.frame, self.db.profile
	local entries, listed = {}, {}
	for _, unit in ipairs(SOURCE_UNITS) do
		local cast = self.casts[unit]
		if (cast and self:IsListed(unit, listed)) then
			listed[unit] = true
			entries[#entries + 1] = { unit = unit, start = cast.start }
		end
	end
	if (db.mode ~= "target") then
		for unit, cast in next, self.casts do
			if (not PRIORITY[unit] and self:IsListed(unit, listed)) then
				listed[unit] = true
				entries[#entries + 1] = { unit = unit, start = cast.start }
			end
		end
	end
	table_sort(entries, SortRows)

	local maxRows = math_max(1, tonumber(db.maxRows) or 5)
	local targetPlate = GetPlate("target")
	local shown = 0
	for index = 1, maxRows do
		local entry = entries[index]
		local row = self:GetRow(index)
		if (entry) then
			shown = shown + 1
			if (row.unit ~= entry.unit or row.castStart ~= entry.start) then
				row.unit, row.castStart = entry.unit, entry.start
				self:UpdateRow(row)
			end
			local isTarget = entry.unit == "target"
				or (targetPlate ~= nil and GetPlate(entry.unit) == targetPlate)
				or (not entry.unit:match("^nameplate") and API.SafeUnitIsUnit(entry.unit, "target"))
			row.TargetEdge:SetAlpha(isTarget and 1 or 0)
			row:Show()
		else
			row.unit, row.castStart = nil, nil
			row:Hide()
		end
	end
	for index = maxRows + 1, #frame.rows do
		frame.rows[index].unit = nil
		frame.rows[index]:Hide()
	end
	frame:SetShown(shown > 0)
	self:SyncClickButtons()
end

-- Fills a row from its unit's current cast.
EnemyCasts.UpdateRow = function(self, row)
	local unit = row.unit
	local cast = unit and self.casts[unit]
	if (not cast) then return end

	if (cast.interrupted) then
		row.Spell:SetText(GlobalText("INTERRUPTED", "Interrupted")) -- Blizzard's localized global string
		row.Bar:SetStatusBarColor(Colors.red[1], Colors.red[2], Colors.red[3], 1)
		row.Bar:SetMinMaxValues(0, 1)
		row.Bar:SetValue(1)
		row.Time:SetText("")
		row.Locked:SetAlpha(0)
		if (row.Bar.Spark) then row.Bar.Spark:Hide() end
		return
	end

	local kind, text, texture, notInterruptible, _, duration = QueryCast(unit)
	if (not kind) then return end
	row.Bar:SetStatusBarColor(unpack(CAST_COLOR))
	row.Icon:SetTexture(FirstValue(texture, [[Interface\Icons\INV_Misc_QuestionMark]]))
	row.Spell:SetText(text)
	SetRowTimer(row, kind, duration)
	if (row.Bar.Spark) then row.Bar.Spark:Show() end
	SetRowInterruptible(row, notInterruptible)

	local okName, name = API.TryCall(UnitName, unit)
	if (okName and SecretOr(name, "string")) then
		row.Caster:SetText(name)
	else
		row.Caster:SetText("")
	end
	UpdateRowMarker(row, unit)
	UpdateRowSpellTarget(row, unit, self.db.profile.showSpellTarget)
end

EnemyCasts.UpdateTimeTexts = function(self)
	for _, row in ipairs(self.frame.rows) do
		local cast = row.unit and self.casts[row.unit]
		if (row:IsShown() and cast and not cast.interrupted) then
			local bar = row.Bar
			local ok, durationObject = API.TryCall(bar.GetTimerDuration, bar)
			if (ok and durationObject and durationObject.GetRemainingDuration) then
				API.TryCall(function()
					row.Time:SetFormattedText("%.1f", durationObject:GetRemainingDuration())
				end)
			end
		end
	end
end

-- Backstop for stops that never arrived, plus the interrupted hold and cast-target changes.
EnemyCasts.CheckCasts = function(self)
	local now = GetTime()
	local changed
	for unit, cast in next, self.casts do
		if (cast.interrupted) then
			if (now - cast.interrupted >= INTERRUPT_HOLD) then
				self.casts[unit] = nil
				changed = true
			end
		elseif (not QueryCast(unit) or not IsHostile(unit)) then
			self.casts[unit] = nil
			changed = true
		end
	end
	if (changed) then
		self:UpdateRows()
	end
	for _, row in ipairs(self.frame.rows) do
		local cast = row.unit and self.casts[row.unit]
		if (row:IsShown() and cast and not cast.interrupted) then
			UpdateRowSpellTarget(row, row.unit, self.db.profile.showSpellTarget)
		end
	end
	-- Follows mover drags and /lock opening or closing (out of combat only).
	self:SyncClickButtons()
end

-- Reads a unit's cast and adds, refreshes or drops it.
EnemyCasts.ScanUnit = function(self, unit)
	if (not IsWatchedUnit(unit)) then return end
	local kind = IsHostile(unit) and QueryCast(unit)
	if (kind) then
		local cast = self.casts[unit]
		if (not cast or cast.interrupted or cast.kind ~= kind) then
			self.casts[unit] = { kind = kind, start = GetTime() }
		end
	else
		local cast = self.casts[unit]
		if (cast and not cast.interrupted) then
			self.casts[unit] = nil
		end
	end
end

-- Re-reads every source. A cast that is still running keeps its start time (ScanUnit), so
-- a target change does not reshuffle the list; units no longer scanned are dropped.
EnemyCasts.ScanAll = function(self)
	local seen = {}
	if (self.db.profile.mode == "target") then
		self:ScanUnit("target")
		seen.target = true
	else
		for _, unit in ipairs(SOURCE_UNITS) do
			self:ScanUnit(unit)
			seen[unit] = true
		end
		for i = 1, 40 do
			local unit = "nameplate" .. i
			if (GetPlate(unit)) then
				self:ScanUnit(unit)
				seen[unit] = true
			end
		end
	end
	for unit in next, self.casts do
		if (not seen[unit]) then
			self.casts[unit] = nil
		end
	end
	self:UpdateRows()
end

-- Re-fills the row showing this unit, if any.
EnemyCasts.RefreshUnitRow = function(self, unit)
	for _, row in ipairs(self.frame.rows) do
		if (row.unit == unit and row:IsShown()) then
			self:UpdateRow(row)
		end
	end
end

local START_EVENTS = {
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_EMPOWER_START = true
}
local STOP_EVENTS = {
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true
}
local UPDATE_EVENTS = {
	UNIT_SPELLCAST_DELAYED = true,
	UNIT_SPELLCAST_CHANNEL_UPDATE = true,
	UNIT_SPELLCAST_EMPOWER_UPDATE = true
}

EnemyCasts.OnCastEvent = function(self, event, unit)
	if (START_EVENTS[event]) then
		if (self.db.profile.mode == "target" and unit ~= "target") then return end
		if (not IsWatchedUnit(unit)) then return end
		self.casts[unit] = nil -- a new cast is always a new row
		self:ScanUnit(unit)
		self:UpdateRows()

	elseif (STOP_EVENTS[event]) then
		if (not self.casts[unit] or self.casts[unit].interrupted) then return end
		-- A stop can arrive just before the next cast's start; read what is there now.
		self.casts[unit] = nil
		self:ScanUnit(unit)
		self:UpdateRows()

	elseif (event == "UNIT_SPELLCAST_INTERRUPTED") then
		local cast = self.casts[unit]
		if (not cast) then return end
		cast.interrupted = GetTime()
		self:RefreshUnitRow(unit)

	elseif (UPDATE_EVENTS[event]) then
		if (self.casts[unit]) then
			self:RefreshUnitRow(unit)
		end

	elseif (event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE") then
		local cast = self.casts[unit]
		if (not cast or cast.interrupted) then return end
		for _, row in ipairs(self.frame.rows) do
			if (row.unit == unit and row:IsShown()) then
				SetRowInterruptible(row, event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
			end
		end

	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		self:ScanUnit(unit)
		self:UpdateRows()

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		if (self.casts[unit]) then
			self.casts[unit] = nil
		end
		self:UpdateRows()

	elseif (event == "RAID_TARGET_UPDATE") then
		for _, row in ipairs(self.frame.rows) do
			if (row.unit and row:IsShown()) then
				UpdateRowMarker(row, row.unit)
			end
		end

	elseif (event == "UNIT_NAME_UPDATE") then
		if (self.casts[unit]) then self:RefreshUnitRow(unit) end

	else
		-- PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED, INSTANCE_ENCOUNTER_ENGAGE_UNIT,
		-- ARENA_OPPONENT_UPDATE, PLAYER_ENTERING_WORLD: the tokens now point elsewhere.
		-- PLAYER_REGEN_ENABLED: the click buttons may be placed again (via UpdateRows).
		self:ScanAll()
	end
end

local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
	"UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
	"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "RAID_TARGET_UPDATE", "UNIT_NAME_UPDATE",
	"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"ARENA_OPPONENT_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"
}

EnemyCasts.SetActive = function(self, active)
	local events = self.eventFrame
	if (active == self.active) then return end
	self.active = active
	if (active) then
		for _, event in ipairs(CAST_EVENTS) do
			if (not API.IsEventAvailable or API.IsEventAvailable(event)) then
				events:RegisterEvent(event)
			end
		end
		self:ScanAll()
	else
		events:UnregisterAllEvents()
		for unit in next, self.casts do
			self.casts[unit] = nil
		end
		for _, row in ipairs(self.frame.rows) do
			row.unit = nil
			row:Hide()
		end
		self.frame:Hide()
		self:SyncClickButtons()
	end
end

-- The mover only while the list is on (VehicleExit.PostUpdateAnchor does the same).
EnemyCasts.PostUpdateAnchor = function(self)
	if (not self.anchor) then return end
	if (self.db.profile.enabled) then
		self.anchor:Enable()
	else
		self.anchor:Disable()
	end
end

EnemyCasts.UpdateSettings = function(self)
	if (not self.frame) then return end
	self:UpdateLayout()
	self:PostUpdateAnchor()
	self:UpdateMoverGhost()
	local enabled = self.db.profile.enabled and true or false
	if (enabled and self.active) then
		self:ScanAll() -- mode or row count changed
	else
		self:SetActive(enabled)
	end
	if (not enabled) then
		self:SetPreviewShown(false)
	end
end

EnemyCasts.OnEnable = function(self)
	self:PrepareFrames()
	-- Rows exist before the anchor measures the frame.
	for index = 1, math_max(1, tonumber(self.db.profile.maxRows) or 5) do
		self:GetRow(index)
	end
	self:UpdateLayout()
	self:CreateAnchor(L["Enemy Casts"])

	ns.MovableModulePrototype.OnEnable(self)

	self:UpdateSettings()
end

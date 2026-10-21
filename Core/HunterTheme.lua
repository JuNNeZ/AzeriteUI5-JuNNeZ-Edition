-- Unseen Path artwork. Original layouts and native resource/prediction shapes
-- remain the geometry contract; ornaments are independent, non-interactive art.
local _, ns = ...
local Engine = ns.ThemeEngine
local Theme = ns:NewModule("HunterTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.HunterTheme = Theme
Engine:Register(Theme, 10)
local endcaps = { thasdorah = true, talonclaw = true, titanstrike = true, thoridal = true, raeshalare = true, none = true }
local healthDips = { hp_cap_case = {760.5/1024,187/256}, hp_mid_case = {767.5/1024,181/256},
	hp_low_case = {767.5/1024,181/256}, hp_boss_case = {879.5/1024,188/256} }
local path = Engine:MediaPath("Hunter")
-- Every styled bar, so endcap changes apply without a reload.
local endcapBars = setmetatable({}, { __mode = "k" })
-- Choice, size multiplier (/azhunter endcapscale) and nudge in pixels. X is outward
-- from the bar's end, so a mirrored target moves the same way on screen as the
-- player's endcap mirrored.
local endcapSettings = Engine:NewEndcapSettings({
	prefix = "hunter", choices = endcaps, default = "thasdorah",
	defaultScale = 1.3,
	-- Maintainer's live fit, 2026-10-18. Keep the existing paintings.
	placements = {
		thasdorah = { scale = 1.80, y = -13 },
		talonclaw = { scale = 1.65, y = -13 },
		titanstrike = { scale = 1.70, y = -19 },
		thoridal = { scale = 1.70, y = -14 },
		raeshalare = { scale = 1.70, y = -14 }
	},
	refresh = function() Theme:RefreshEndcaps() end
})
endcapSettings.Install(Theme)
local EndcapKey, EndcapScale, EndcapOffset = endcapSettings.GetKey, endcapSettings.GetScale, endcapSettings.GetOffset
-- The cast boot is independent of the chosen health weapon.
local castSettings = Engine:NewEndcapSettings({
	prefix = "hunterCast", name = "CastEndcap",
	choices = { eagle = true, none = true }, default = "eagle", clearDefault = true,
	refresh = function() Theme:RefreshEndcaps() end
})
castSettings.Install(Theme)

Theme.IsActive = function(self)
	local db = ns.db
	if (not db or not db.char or not db.char.hunterPreview) then return false end
	return Engine:IsMainLayout()
end

Theme.ResolveMedia = function(self, name)
	if (type(name) ~= "string") then return end
	if (name == "minimap-onebar-backdrop" or name == "minimap-twobars-backdrop") then return end
	-- Long health uses native fill/prediction contours and a native dipped
	-- casing, re-materialed in the retained Hunter painting. Critter/pet stay
	-- on their existing connected assemblies.
	if (self:IsActive()) then
		if (name:match("^hp_cap_bar") or name:match("^hp_lowmid_bar") or name:match("^hp_boss_bar")) then return end
		if (name == "hp_cap_case" or name == "hp_mid_case" or name == "hp_low_case" or name == "hp_boss_case") then
			return path(name.."-fitted")
		end
	end
	if (self:IsActive() and ns.HunterMedia and ns.HunterMedia[name]) then return path(name) end
end

-- This theme's file for a native name whether or not the theme is active, for
-- elements that let the player pick a skin of their own (CooldownManager.lua).
Theme.ResolveOwnMedia = function(self, name)
	if (ns.HunterMedia and ns.HunterMedia[name]) then return path(name) end
end

Theme.ResolvePath = function(self, original)
	local name = type(original) == "string" and original:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
	return (name and self:ResolveMedia(name)) or original
end

local Copy = function(source) return Engine:CopyLayout(source) end

-- Decorative material colors become white. Neutral halo and aura textures retain
-- their semantic runtime colors (HunterTintable).
local replaceOptions = {
	resolve = function(name) return Theme:ResolveMedia(name) end,
	keepTint = function(assetName) return ns.HunterTintable and ns.HunterTintable[assetName] end,
	after = function(t)
		if (t.PowerBarForegroundPosition) then
			t.PowerBarForegroundPosition = { "BOTTOM", 0, -51 }
		end
		if (t.ManaOrbArtworkTexture) then
			t.ManaOrbArtworkSize = { 32, 32 }
			t.ManaOrbArtworkPosition = { "BOTTOM", 0, -12 }
			t.ManaOrbArtworkColor = { 1, 1, 1, 1 }
		end
	end
}

local BuildConfig = function(name, original)
	local config = Copy(original)
	Engine:ReplaceMedia(config, replaceOptions)
	if (name == "PlayerFrame" or name == "PlayerFrameAlternate") then
		config.PowerBarColors.FOCUS = { 1, .62, .12 }
		if (config.PowerOrbColors) then config.PowerOrbColors.FOCUS = { 1, .62, .12 } end
	elseif (name == "NamePlates") then
		config.HealthBarTexCoord = {0,1,0,1}
		config.CastBarTexCoord = {0,1,0,1}
		config.PowerBarTexCoord = {0,1,0,1}
		config.TargetHighlightSize = Copy(config.HealthBackdropSize)
		config.TargetHighlightPosition = Copy(config.HealthBackdropPosition)
		config.ThreatSize = Copy(config.HealthBackdropSize)
		config.ThreatPosition = Copy(config.HealthBackdropPosition)
	elseif (name == "PetFrame") then
		config.Size = {324,100}
		config.HealthBarSize = {144,144*115/930}
		config.HealthBarTexture = path("pet-fill")
	end
	-- Keep original casing dimensions/anchors; variants are packed around
	-- each native meter rather than stretching the whole casing to its opening.
	local compactVariant = name == "PartyFrames" and "party" or name == "RaidFrames" and "raid"
	if (compactVariant) then
		config.HealthBackdropTexture = path("cast-back-"..compactVariant)
		config.TargetHighlightTexture = path("cast-back-"..compactVariant.."-outline")
	end
	if (name == "PlayerFrame") then
		for _,tier in ipairs({"Novice","Hardened","Seasoned"}) do
			-- The expanded 196px viewport already shares the legacy 120x140
			-- area's center: Player.lua adds POWER_CRYSTAL_BASELINE_OFFSET
			-- (-37,-28) to PowerBarPosition. Shifting it here as well put the
			-- crystal 38 left and 28 below the orb's place, short of the bar.

			-- Leave a small gutter between the new orb clasps and health fill.
			local t = config[tier]
			t.ManaOrbPosition[2] = t.ManaOrbPosition[2]-8
		end
	end
	return config
end
local CachedConfig = Engine:NewConfigCache(BuildConfig)

Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	return CachedConfig(name, original)
end

Theme.UseIceCrystal = function(self, requested) return false end
Theme.GetPowerColor = function(self, token)
	if (self:IsActive() and token == "FOCUS") then return { 1, .62, .12 } end
end

local Endcap = function(bar, flip, cast)
	local key = cast and castSettings.GetKey() or EndcapKey()
	local frame = bar.HunterOrnaments
	if (not frame) then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetAllPoints(bar)
		frame:SetFrameLevel(bar:GetFrameLevel() + 4)
		frame:EnableMouse(false)
		frame.Tip = frame:CreateTexture(nil, "OVERLAY")
		bar.HunterOrnaments = frame
	end
	endcapBars[bar] = { flip = flip, cast = cast }
	-- Critters get their own native casing, never a compressed long endcap.
	local compact = not cast and (bar:GetWidth() < bar:GetHeight()*2 or bar.HunterCompact)
	if (not cast) then
		local dx, dy = EndcapOffset()
		Engine:StyleAlignedHealthEndcap(frame, frame.Tip, bar, path, compact and "none" or key,
			healthDips, flip, EndcapScale(), dx, dy)
		frame.Tip:SetAlpha(1)
		return
	end
	local enabled = key ~= "none" and not compact
	frame.EndcapShown = enabled and true or false
	frame:SetShown(enabled)
	if (not cast) then Engine:SetEndcapTerminal(bar, enabled) end
	if (cast) then Engine:SetCastEndcapTerminal(bar, path, enabled) end
	if (frame.Threat) then frame.Threat:SetShown(enabled and frame.ThreatSource:IsShown()) end
	if (not enabled) then return end
	local slot = cast and Engine.FittedCastSlot or Engine.OrnamentSlots.Health
	local unit = cast and 1 or bar:GetHeight()/slot.reference
	local base = slot.size*unit
	local size = base*(cast and castSettings.GetScale() or EndcapScale())
	local dx, dy
	if (cast) then dx, dy = castSettings.GetOffset() else dx, dy = EndcapOffset() end
	local art = frame.Tip
	art:SetTexture(path(cast and "cast-head-fitted" or "endcap-"..key.."-fitted"))
	art:SetAlpha(1)
	art:ClearAllPoints()
	art:SetSize(size,size)
	-- The solid socket covers the termination, above health and prediction.
	local x = slot.x*unit + (cast and -dx or dx)
	art:SetPoint("CENTER", bar, (cast or flip) and "LEFT" or "RIGHT", flip and -x or x, slot.y*unit + dy)
	art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0,1)
	-- The threat glow follows the endcap's art; StyleThreat creates it.
	if (frame.Threat) then
		frame.Threat:SetTexture(path("endcap-"..key.."-fitted-glow"))
	end
end

-- Same geometry contract as the existing themed casing: the native meter,
-- prediction and secret-valued updates stay intact underneath the artwork.
local function Fit(bar, art, flip, top, bottom, critter)
	local w,h = bar:GetWidth(),bar:GetHeight()
	local width,height,left,upper,right,lower = 2172,724,162,287,1910,410
	if (critter) then
		width,height = 1,1
		left,upper,right,lower = unpack(ns.HunterGeometry.critter)
	end
	local sx = w/(right-left); local sy = h*(bottom-top)/(lower-upper)
	art:ClearAllPoints()
	art:SetPoint("TOPLEFT",bar,"TOPLEFT",-(flip and (width-right) or left)*sx,upper*sy-h*top)
	art:SetSize(width*sx,height*sy)
	art:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
end

Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive()) then return end
	local bar = owner.Health
	local compact = db.HealthBarTexture and db.HealthBarTexture:find("cast_bar",1,true)
	bar.HunterCompact = compact and true or false
	local critter = bar:GetWidth()<bar:GetHeight()*2
	bar.HunterHealthGeometry = nil
	bar.ThemeEndcapAssembly = nil
	if (compact) then
		Endcap(bar,flip,false)
		if (bar.HunterCasing) then bar.HunterCasing:Hide(); bar.HunterEmpty:SetAlpha(0) end
		bar.Backdrop:SetAlpha(1)
		return
	end
	local texture = db.HealthBarTexture or ns.API.GetMedia("hp_cap_bar")
	local top,bottom = 3/128,100/128
	if (texture:find("hp_lowmid_bar",1,true)) then top,bottom = 2/64,52/64
	elseif (texture:find("hp_boss_bar",1,true)) then top,bottom = 2/64,48/64 end
	local name = critter and "hp_critter_case" or (type(db.HealthBackdropTexture) == "string"
		and db.HealthBackdropTexture:match("[\\/]Hunter[\\/]([^\\/]+)%.tga$")) or Engine.AssetName(db.HealthBackdropTexture)
	if (not name or not name:match("^hp_")) then name = "hp_cap_case-fitted" end
	if (not critter and not name:find("-fitted",1,true)) then name = name.."-fitted" end
	if (critter) then top,bottom = 0,1 end
	local casing = bar.HunterCasing
	if (not casing) then
		casing = CreateFrame("Frame",nil,bar); casing:SetAllPoints(bar)
		casing:SetFrameLevel(bar:GetFrameLevel()+2); casing:EnableMouse(false)
		casing.Art = casing:CreateTexture(nil,"ARTWORK"); bar.HunterCasing = casing
		bar.HunterEmpty = bar:CreateTexture(nil,"BACKGROUND",nil,-2)
		bar.HunterEmpty:SetAllPoints(bar); bar.HunterEmpty:SetVertexColor(.09,.08,.11,1)
	end
	casing:Show()
	if (critter) then
		casing.Art:SetTexture(path(name)); Fit(bar,casing.Art,flip,top,bottom,true)
	else
		casing.Art:SetTexture(path(name.."-over"))
		casing.Art:ClearAllPoints(); casing.Art:SetAllPoints(bar.Backdrop)
		casing.Art:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
	end
	bar.HunterEmpty:SetTexture(texture); bar.HunterEmpty:SetAlpha(1)
	bar.HunterEmpty:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
	bar.Backdrop:SetAlpha(critter and 0 or 1)
	bar.HunterEmpty:SetAlpha(critter and 1 or 0)
	bar.HunterHealthGeometry = {name,top,bottom,critter}
	if (not critter) then
		bar.ThemeEndcapAssembly = { name = name, path = path, back = bar.Backdrop, front = casing.Art,
			glow = name.."-glow", threat = bar.HunterThreat, bareThreat = path(name.."-glow") }
	end
	Endcap(bar,flip,false)
end

Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive()) then return end
	local indicator = owner.ThreatIndicator
	local native = indicator and indicator.textures and indicator.textures.Health
	local portrait = indicator and indicator.textures and indicator.textures.Portrait
	if (portrait and owner.Portrait and owner.Portrait.Border) then
		portrait:ClearAllPoints(); portrait:SetAllPoints(owner.Portrait.Border)
	end
	local geometry = owner.Health.HunterHealthGeometry
	if (native and geometry) then
		native:SetTexture(path(geometry[1]..(geometry[4] and "_glow" or "-glow")))
		if (geometry[4]) then
			Fit(owner.Health,native,flip,geometry[2],geometry[3],true)
		else
			native:ClearAllPoints(); native:SetAllPoints(owner.Health.Backdrop)
			native:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
		end
		owner.Health.HunterThreat = native
		if (owner.Health.ThemeEndcapAssembly) then
			owner.Health.ThemeEndcapAssembly.threat = native
			Engine:SetEndcapTerminal(owner.Health, false)
		end
	end
	local textures = indicator and indicator.textures
	local power = owner.Power
	if (textures and power and power.Case and textures.PowerBar) then
		local art = textures.PowerBar
		art:SetTexture(path("crystal-group-glow")); art:ClearAllPoints()
		art:SetSize(power:GetWidth()*2,power:GetHeight()*2)
		art:SetPoint("TOPLEFT",power,"TOPLEFT",-power:GetWidth()/2,power:GetHeight()/4)
		if (textures.PowerBackdrop) then textures.PowerBackdrop:SetAlpha(0) end
	end
	local orb = owner.ManaOrb
	if (textures and textures.ManaOrb and orb and orb.Case) then
		local art = textures.ManaOrb
		art:SetTexture(path("orb-group-glow")); art:ClearAllPoints()
		art:SetSize(orb.Case:GetWidth()*1.25,orb.Case:GetHeight()*1.25)
		art:SetPoint("CENTER",orb.Case,"CENTER")
	end
	local ornaments = owner.Health.HunterOrnaments
	if (not native or not ornaments or not owner.Health.ThemeEndcapAssembly) then return end
	local key = EndcapKey()
	local name = owner.Health.ThemeEndcapAssembly.name:gsub("%-fitted$", "")
	Engine:StyleEndcapThreat(ornaments, ornaments.Tip, native,
		path("ornament-"..(key == "none" and "thasdorah" or key).."-"..name.."-glow"), flip)
end

-- Layout half of the crystal: the Hunter case fits the 196px resource
-- viewport. Effects inside the crystal belong to Core/ThemeEffects.lua.
Theme.StyleCrystal = function(self, power)
	if (not self:IsActive() or not power.Case) then return end
	-- Main player uses the complete 196px resource viewport. Match the native
	-- fill to its full-canvas backing instead of stretching its cropped center.
	power:SetTexCoord(0,1,0,1)
	local w,h = power:GetWidth(),power:GetHeight()
	power.Case:ClearAllPoints()
	power.Case:SetPoint("BOTTOM",power,"BOTTOM",0,-23*h/196)
	power.Case:SetSize(198*w/196,98*h/196)
end

--- Orb effect "hunter": the focus fill. Native LibOrb clipping and the
--- resource color stay in control. Any theme may use it (Lite+).
Theme.ApplyOrbEffect = function(self, orb)
	orb:SetStatusBarTexture(path("orb-focus"),path("orb-focus"))
	return true
end

Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive()) then return end
	Endcap(cast,false,true)
	-- The old shield is a whole bar border. Existing Cast_Update colors still
	-- distinguish protected casts; do not draw that border as a detached icon.
	cast.Shield:SetAlpha(0)
	-- With no shield standing in, protected casts (professions, Dismiss Pet)
	-- keep the regular casing instead of losing it (PlayerCastBar.lua).
	cast.KeepBackdrop = true
end

Theme.StyleNameplate = function(self, owner)
	if (not self:IsActive()) then return end
	for _, bar in ipairs({ owner.Health, owner.Castbar }) do
		bar.Backdrop:SetTexture(path("nameplate_backdrop"))
		bar.Backdrop:SetVertexColor(1,1,1)
	end
end

Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive()) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1,1,1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1,1,1)
end

-- Created during oUF style construction: its Portrait element owns pet/model
-- changes and vehicle unit updates, just as it does for the existing portraits.
Theme.StylePet = function(self, owner)
	if (not self:IsActive() or owner.HunterPetArt) then return end
	local bar = owner.Health
	local g = ns.HunterGeometry.pet
	local width,height,left,top,right,bottom = unpack(g)
	local scale = bar:GetWidth()/(right-left)
	local casing = owner.Overlay:CreateTexture(nil,"OVERLAY")
	casing:SetTexture(path("pet-case"))
	casing:SetSize(width*scale,height*scale)
	casing:SetPoint("TOPLEFT",bar,"TOPLEFT",-left*scale,top*scale)
	bar.Backdrop:SetAlpha(0)
	-- A 3D model, animated like the target's portrait. Models take no mask
	-- textures; the casing is opaque outside its round socket, so it crops one.
	local portrait = CreateFrame("PlayerModel",nil,owner)
	portrait:SetFrameLevel(owner.Overlay:GetFrameLevel()-1)
	portrait:SetSize((g[9]-g[7])*scale,(g[10]-g[8])*scale)
	portrait:SetPoint("TOPLEFT",bar,"TOPLEFT",(g[7]-left)*scale,(top-g[8])*scale)
	owner.Portrait = portrait
	if (ns.API.AttachPortraitAlphaFix) then ns.API.AttachPortraitAlphaFix(owner,portrait) end
	-- A model draws on a clear background, where the 2D portrait was a filled
	-- square; fill the socket so the world does not show around the pet's head.
	-- Left square on purpose: the casing crops it, while the circular mask's
	-- solid disc is only 110 of its 128px and left a ring unfilled.
	local backdrop = owner:CreateTexture(nil,"BACKGROUND")
	backdrop:SetAllPoints(portrait); backdrop:SetColorTexture(.09,.08,.11,1)
	portrait.Bg = backdrop
	if (owner.TargetHighlight) then
		owner.TargetHighlight:SetTexture(path("pet-case-glow"))
		owner.TargetHighlight:ClearAllPoints(); owner.TargetHighlight:SetAllPoints(casing)
	end
	owner.HunterPetArt = {casing,portrait,backdrop}
	if (owner.PetHappiness) then
		-- Only the paw and its dark cavity, inside the metal hexagon. Sampling
		-- the same casing UVs keeps the baked green paw covered pixel for pixel.
		local badge = owner.Overlay:CreateTexture(nil, "OVERLAY", nil, 1)
		badge:SetTexture(path("pet-case"))
		badge:SetTexCoord(135/width, 355/width, 250/height, 480/height)
		badge:SetSize(220*scale, 230*scale)
		badge:SetPoint("TOPLEFT", bar, "TOPLEFT", (135-left)*scale, (top-250)*scale)
		-- Exclude the bevel at the crop's lower corners from the colour wash.
		local mask = owner.Overlay:CreateMaskTexture()
		mask:SetAllPoints(badge)
		mask:SetTexture(ns.API.GetMedia("actionbutton-mask-circular"))
		mask:SetTexCoord(5/128, 123/128, 5/128, 123/128)
		badge:AddMaskTexture(mask)
		badge.Mask = mask
		owner.PetHappinessBadge = badge
	end
end

-- Preserve user offsets which move casts farther away; clamp upward offsets
-- so the complete 24px health/cast canvases always have a one-pixel gap.
Theme.GetNameplateCastOffset = function(self, offset)
	return self:IsActive() and math.min(offset,-1) or offset
end

-- Restyles every endcap already drawn. Only textures, sizes and anchors
-- change; no unit values are read, so this is safe at any time outside combat.
Theme.RefreshEndcaps = function(self)
	if (not self:IsActive()) then return end
	for bar, info in pairs(endcapBars) do Endcap(bar, info.flip, info.cast) end
end

-- GetEndcapChoices, GetEndcap(Scale/Offset), SetEndcap(Scale/Offset) and
-- ResetEndcapPlacement come from the engine's endcap settings above; each
-- applies live through RefreshEndcaps and refuses in combat.

Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command == "status") then
		self:Print((self:IsActive() and "Hunter theme: on" or "Hunter theme: off").."; endcap: "..EndcapKey().."; endcap scale: "..EndcapScale())
		return
	end
	if (command == "endcapscale") then
		local scale = option == "reset" and 1.3 or tonumber(option)
		if (not scale or scale < .5 or scale > 2) then
			self:Print("/azhunter endcapscale [0.5-2|reset] (currently "..EndcapScale()..")")
			return
		end
		if (InCombatLockdown()) then self:Print("Change the Hunter theme outside combat."); return end
		self:SetEndcapScale(scale)
		self:Print("Hunter endcap scale: "..EndcapScale())
		return
	end
	if (not command or (command ~= "" and command ~= "on" and command ~= "off" and command ~= "toggle" and command ~= "endcap")
		or (command == "endcap" and not endcaps[option]) or (command ~= "endcap" and option ~= "")) then
		self:Print("/azhunter [on|off|toggle|status], /azhunter endcap [thasdorah|talonclaw|titanstrike|thoridal|raeshalare|none] or /azhunter endcapscale [0.5-2|reset]")
		return
	end
	if (InCombatLockdown()) then self:Print("Change the Hunter theme outside combat."); return end
	-- The endcap is drawn per bar, so a new one needs no reload.
	if (command == "endcap") then self:SetEndcap(option); return end
	local enabling = command == "on" or ((command == "" or command == "toggle") and not ns.db.char.hunterPreview)
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	if (enabling and ((variant and variant ~= "") or (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()))) then
		self:Print("Select the main AzeriteUI theme before enabling Hunter."); return
	end
	if (enabling) then ns.db.char.legacyHUD = false end
	ns.db.char.hunterPreview = enabling and true or false
	-- Preserve the Paladin preference: /azhunter off returns to it automatically.
	ReloadUI()
end

Theme.OnInitialize = function(self)
	-- The round-two pilot and the staged test set were removed on 2026-10-04.
	if (ns.db and ns.db.char) then ns.db.char.hunterPilot, ns.db.char.hunterTest = nil, nil end
	self:RegisterChatCommand("azhunter","Command")
end
Theme.ProfileChanged = Engine.ProfileChanged

Theme.OnEnable = function(self)
	-- Chosen at load; a profile switching it on or off reloads (ThemeEngine.lua).
	Engine:WatchProfile(self)
	if (self.loadedActive) then Engine:StyleOptionsKit(path("border-tooltip"), path("border-aura")) end
end

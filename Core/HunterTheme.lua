-- Unseen Path artwork. Original layouts and native resource/prediction shapes
-- remain the geometry contract; ornaments are independent, non-interactive art.
local Addon, ns = ...
local Theme = ns:NewModule("HunterTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.HunterTheme = Theme
local cache = {}
local endcaps = { thasdorah = true, talonclaw = true, titanstrike = true, thoridal = true, raeshalare = true, none = true }
local path = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\Hunter\\"..name..".tga" end
-- Health endcap size multiplier (/azhunter endcapscale); casts keep their head size.
local EndcapScale = function()
	local scale = tonumber(ns.db and ns.db.char and ns.db.char.hunterEndcapScale)
	return (scale and scale >= .5 and scale <= 2) and scale or 1
end
-- Health endcap nudge in pixels. X is outward from the bar's end, so a mirrored
-- target moves the same way on screen as the player's endcap mirrored.
local ENDCAP_OFFSET_LIMIT = 60
local EndcapOffset = function()
	local char = ns.db and ns.db.char
	local function clamp(value)
		value = tonumber(value)
		if (not value or value ~= value) then return 0 end
		return math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, value))
	end
	return clamp(char and char.hunterEndcapX), clamp(char and char.hunterEndcapY)
end
local EndcapKey = function()
	local key = ns.db.char.hunterEndcap or "thasdorah"
	return endcaps[key] and key or "thasdorah"
end
-- Every styled bar, so endcap changes apply without a reload.
local endcapBars = setmetatable({}, { __mode = "k" })

Theme.IsActive = function(self)
	local db = ns.db
	if (not db or not db.char or not db.char.hunterPreview) then return false end
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

Theme.ResolveMedia = function(self, name)
	if (name == "minimap-onebar-backdrop" or name == "minimap-twobars-backdrop") then return end
	if (self:IsActive() and ns.HunterMedia and ns.HunterMedia[name]) then return path(name) end
end

Theme.ResolvePath = function(self, original)
	local name = type(original) == "string" and original:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
	return (name and self:ResolveMedia(name)) or original
end

local function Copy(source, seen)
	if (type(source) ~= "table" or type(source.GetObjectType) == "function" or type(source[0]) == "userdata") then return source end
	seen = seen or {}
	if (seen[source]) then return seen[source] end
	local result = {}; seen[source] = result
	for k,v in pairs(source) do result[k] = Copy(v, seen) end
	return result
end

local function Transform(t, seen)
	if (type(t.GetObjectType) == "function" or type(t[0]) == "userdata") then return end
	seen = seen or {}; if (seen[t]) then return end; seen[t] = true
	for key,value in pairs(t) do
		if (type(value) == "table") then Transform(value, seen)
		elseif (type(value) == "string") then
			local replacement = Theme:ResolvePath(value)
			t[key] = replacement
			-- Decorative material colors become white. Neutral halo and aura
			-- textures retain their semantic runtime colors.
			local assetName = replacement:match("([^\\/]+)%.tga$")
			if (replacement ~= value and type(key) == "string" and not (ns.HunterTintable and ns.HunterTintable[assetName])) then
				local prefix = key:match("^(.-)Texture$") or key:match("^(.-)TexturePath$")
				local c = prefix and t[prefix.."Color"]
				if (type(c) == "table") then t[prefix.."Color"] = { 1,1,1,c[4] or 1 } end
			end
		end
	end
	if (t.PowerBarForegroundPosition) then
		t.PowerBarForegroundPosition = { "BOTTOM", 0, -51 }
	end
	if (t.ManaOrbArtworkTexture) then
		t.ManaOrbArtworkSize = { 32, 32 }
		t.ManaOrbArtworkPosition = { "BOTTOM", 0, -12 }
		t.ManaOrbArtworkColor = { 1, 1, 1, 1 }
	end
end

Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	if (cache[original]) then return cache[original] end
	local config = Copy(original)
	Transform(config)
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
	cache[original] = config
	return config
end

Theme.UseIceCrystal = function(self, requested) return false end
Theme.GetPowerColor = function(self, token)
	if (self:IsActive() and token == "FOCUS") then return { 1, .62, .12 } end
end

local Endcap = function(bar, flip, cast)
	local key = EndcapKey()
	local frame = bar.HunterOrnaments
	if (not frame) then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetAllPoints(bar)
		frame:SetFrameLevel(bar:GetFrameLevel() + 3)
		frame:EnableMouse(false)
		frame.Tip = frame:CreateTexture(nil, "ARTWORK")
		bar.HunterOrnaments = frame
	end
	endcapBars[bar] = { flip = flip, cast = cast }
	-- Critters get their own native casing, never a compressed long endcap.
	local compact = bar:GetWidth() < bar:GetHeight()*2
	frame:SetShown(not compact)
	if (compact) then return end
	local base = math.min(cast and 58 or 48, bar:GetHeight()*(cast and 2.35 or 1.2))
	local size = base*(cast and 1 or EndcapScale())
	local dx, dy = 0, 0
	if (not cast) then dx, dy = EndcapOffset() end
	local art = frame.Tip
	art:SetTexture(path("endcap-"..(key == "none" and "thasdorah" or key)))
	art:SetAlpha(key == "none" and 0 or 1)
	art:ClearAllPoints()
	art:SetSize(size,size)
	-- Most of the ornament is outside the meter, so no fill/value is covered.
	-- Mirrored target ornaments are at the outer LEFT, away from the portrait.
	-- Anchored by the centre the unscaled art had (its inner edge 8px over the
	-- bar's end), so a size change grows it in place instead of pushing it out.
	local x = base/2 - 8 + dx
	art:SetPoint("CENTER", bar, flip and "LEFT" or "RIGHT", flip and -x or x, dy)
	art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0,1)
	-- The threat glow follows the endcap's art; StyleThreat creates it.
	if (frame.Threat) then
		frame.Threat:SetTexture(path("endcap-"..(key == "none" and "thasdorah" or key).."-glow"))
		frame.Threat:SetAlpha(key == "none" and 0 or 1)
	end
	if (cast) then
		local eagle = frame.Eagle or frame:CreateTexture(nil,"ARTWORK")
		frame.Eagle = eagle
		eagle:SetTexture(path("eagle")); eagle:ClearAllPoints()
		eagle:SetSize(size,size)
		eagle:SetPoint("RIGHT",bar,"LEFT",8,0)
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
	Endcap(bar,flip,false)
	local compact = db.HealthBarTexture and db.HealthBarTexture:find("cast_bar",1,true)
	local critter = bar:GetWidth()<bar:GetHeight()*2
	bar.HunterHealthGeometry = nil
	if (compact) then
		if (bar.HunterCasing) then bar.HunterCasing:Hide(); bar.HunterEmpty:SetAlpha(0) end
		bar.Backdrop:SetAlpha(1)
		return
	end
	local texture = db.HealthBarTexture or ns.API.GetMedia("hp_cap_bar")
	local top,bottom = 3/128,100/128
	if (texture:find("hp_lowmid_bar",1,true)) then top,bottom = 2/64,52/64
	elseif (texture:find("hp_boss_bar",1,true)) then top,bottom = 2/64,48/64 end
	local name = critter and "hp_critter_case" or (texture:find("hp_boss_bar",1,true) and "hp_boss_case" or "hp_cap_case")
	if (critter) then top,bottom = 0,1 end
	local casing = bar.HunterCasing
	if (not casing) then
		casing = CreateFrame("Frame",nil,bar); casing:SetAllPoints(bar)
		casing:SetFrameLevel(bar:GetFrameLevel()+2); casing:EnableMouse(false)
		casing.Art = casing:CreateTexture(nil,"ARTWORK"); bar.HunterCasing = casing
		bar.HunterEmpty = bar:CreateTexture(nil,"BACKGROUND",nil,-2)
		bar.HunterEmpty:SetAllPoints(bar); bar.HunterEmpty:SetVertexColor(.09,.08,.11,1)
	end
	casing:Show(); casing.Art:SetTexture(path(name)); Fit(bar,casing.Art,flip,top,bottom,critter)
	bar.HunterEmpty:SetTexture(texture); bar.HunterEmpty:SetAlpha(1)
	bar.HunterEmpty:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
	bar.Backdrop:SetAlpha(0)
	bar.HunterHealthGeometry = {name,top,bottom,critter}
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
		native:SetTexture(path(geometry[1].."_glow"))
		Fit(owner.Health,native,flip,geometry[2],geometry[3],geometry[4])
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
	if (not native or not ornaments) then return end
	local glow = ornaments.Threat
	if (not glow) then
		glow = ornaments:CreateTexture(nil, "BACKGROUND")
		glow:SetAllPoints(ornaments.Tip)
		glow:SetBlendMode("ADD")
		glow:Hide()
		ornaments.Threat = glow
		-- Follow only our own native threat texture. The existing element owns
		-- visibility and color; no unit threat values are queried or compared.
		hooksecurefunc(native, "Show", function() glow:Show() end)
		hooksecurefunc(native, "Hide", function() glow:Hide() end)
		hooksecurefunc(native, "SetVertexColor", function(_, ...) glow:SetVertexColor(...) end)
	end
	local key = EndcapKey()
	glow:SetTexture(path("endcap-"..(key == "none" and "thasdorah" or key).."-glow"))
	glow:SetAlpha(key == "none" and 0 or 1)
	glow:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	glow:SetShown(indicator.isShown and true or false)
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

Theme.GetEndcapChoices = function(self) return endcaps end
Theme.GetEndcap = function(self) return EndcapKey() end
Theme.GetEndcapScale = function(self) return EndcapScale() end
Theme.GetEndcapOffset = function(self) return EndcapOffset() end

--- Endcap art by key (see GetEndcapChoices). Applies live.
Theme.SetEndcap = function(self, key)
	if (not endcaps[key] or InCombatLockdown()) then return false end
	ns.db.char.hunterEndcap = key
	self:RefreshEndcaps()
	return true
end

--- Size multiplier, .5 to 2. Applies live; returns false when refused.
Theme.SetEndcapScale = function(self, scale)
	scale = tonumber(scale)
	if (not scale or scale < .5 or scale > 2 or InCombatLockdown()) then return false end
	ns.db.char.hunterEndcapScale = scale ~= 1 and scale or nil
	self:RefreshEndcaps()
	return true
end

--- Pixel nudge; either value may be nil to keep it. Applies live.
Theme.SetEndcapOffset = function(self, x, y)
	if (InCombatLockdown()) then return false end
	local oldX, oldY = EndcapOffset()
	x, y = tonumber(x) or oldX, tonumber(y) or oldY
	x = math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, x))
	y = math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, y))
	ns.db.char.hunterEndcapX = x ~= 0 and x or nil
	ns.db.char.hunterEndcapY = y ~= 0 and y or nil
	self:RefreshEndcaps()
	return true
end

Theme.ResetEndcapPlacement = function(self)
	if (InCombatLockdown()) then return false end
	ns.db.char.hunterEndcapScale, ns.db.char.hunterEndcapX, ns.db.char.hunterEndcapY = nil, nil, nil
	self:RefreshEndcaps()
	return true
end

Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command == "status") then
		self:Print((self:IsActive() and "Hunter theme: on" or "Hunter theme: off").."; endcap: "..EndcapKey().."; endcap scale: "..EndcapScale())
		return
	end
	if (command == "endcapscale") then
		local scale = option == "reset" and 1 or tonumber(option)
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
	ns.db.char.hunterPreview = enabling and true or false
	-- Preserve the Paladin preference: /azhunter off returns to it automatically.
	ReloadUI()
end

Theme.ProfileChanged = function(self)
	if (self.loadedActive ~= self:IsActive()) then
		if (InCombatLockdown()) then self:RegisterEvent("PLAYER_REGEN_ENABLED","ProfileChanged")
		else self:UnregisterEvent("PLAYER_REGEN_ENABLED","ProfileChanged"); ReloadUI() end
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
	end
end
Theme.OnInitialize = function(self)
	-- The round-two pilot and the staged test set were removed on 2026-10-04.
	if (ns.db and ns.db.char) then ns.db.char.hunterPilot, ns.db.char.hunterTest = nil, nil end
	self:RegisterChatCommand("azhunter","Command")
end
Theme.OnEnable = function(self)
	self.loadedActive = self:IsActive()
	if (self.loadedActive and ns.OptionsKit) then
		for _,key in ipairs({ "WindowBackdrop", "WindowCasing", "ButtonBackdrop" }) do ns.OptionsKit[key].edgeFile = path("border-tooltip") end
		if (ns.OptionsKit.InsetBackdrop) then ns.OptionsKit.InsetBackdrop.edgeFile = path("border-aura") end
	end
	ns.db.RegisterCallback(self,"OnProfileChanged","ProfileChanged")
	ns.db.RegisterCallback(self,"OnProfileCopied","ProfileChanged")
	ns.db.RegisterCallback(self,"OnProfileReset","ProfileChanged")
end

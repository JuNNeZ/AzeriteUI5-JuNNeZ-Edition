-- Unseen Path artwork. Original layouts and native resource/prediction shapes
-- remain the geometry contract; ornaments are independent, non-interactive art.
local Addon, ns = ...
local Theme = ns:NewModule("HunterTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.HunterTheme = Theme
local cache = {}
local pilotCache = {}
local testCache = {}
local testPath = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\HunterDropIn\\"..name..".tga" end
local pilotBars = setmetatable({}, { __mode = "k" })
local pilotMedia = {
	["hp_cap_case"] = true, ["hp_cap_bar"] = true,
	["cast_back"] = true, ["cast_bar"] = true,
	["orb_case_hi"] = true, ["actionbutton-border"] = true
}
local pilotPath = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\HunterPilot\\"..name..".tga" end
local endcaps = { thasdorah = true, talonclaw = true, titanstrike = true, thoridal = true, raeshalare = true, none = true }
local path = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\Hunter\\"..name..".tga" end

Theme.IsActive = function(self)
	local db = ns.db
	if (not db or not db.char or not db.char.hunterPreview) then return false end
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

Theme.ResolveMedia = function(self, name, configName)
	if (self:IsTest()) then
		local selected = ns.HunterTestMedia and ns.HunterTestMedia[name]
		return selected and testPath(selected) or nil
	end
	if (self:IsPilot()) then
		-- Compact health frames share cast_back but have no pilot over-layer hook.
		-- Keep their complete original casing until those pieces are reworked.
		if (name == "cast_back" and configName ~= "PlayerCastBar") then return end
		return pilotMedia[name] and pilotPath(name) or nil
	end
	if (name == "minimap-onebar-backdrop" or name == "minimap-twobars-backdrop") then return end
	if (self:IsActive() and ns.HunterMedia and ns.HunterMedia[name]) then return path(name) end
end

Theme.IsTest = function(self) return self:IsActive() and ns.db.char.hunterTest == true end
Theme.UsesNativeLayout = function(self) return self:IsPilot() or self:IsTest() end

-- Opt-in round-two art uses the original layout, including every saved offset.
Theme.IsPilot = function(self)
	return self:IsActive() and ns.db.char.hunterPilot == true
end

Theme.ResolvePath = function(self, original, configName)
	local name = type(original) == "string" and original:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
	return (name and self:ResolveMedia(name, configName)) or original
end

local function Copy(source, seen)
	if (type(source) ~= "table" or type(source.GetObjectType) == "function" or type(source[0]) == "userdata") then return source end
	seen = seen or {}
	if (seen[source]) then return seen[source] end
	local result = {}; seen[source] = result
	for k,v in pairs(source) do result[k] = Copy(v, seen) end
	return result
end

local function Transform(t, seen, configName)
	if (type(t.GetObjectType) == "function" or type(t[0]) == "userdata") then return end
	seen = seen or {}; if (seen[t]) then return end; seen[t] = true
	for key,value in pairs(t) do
		if (type(value) == "table") then Transform(value, seen, configName)
		elseif (type(value) == "string") then
			local replacement = Theme:ResolvePath(value, configName)
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
    if not Theme:UsesNativeLayout() and t.PowerBarForegroundPosition then
        t.PowerBarForegroundPosition={ "BOTTOM",0,-51 }
    end
	if (not Theme:UsesNativeLayout() and t.ManaOrbArtworkTexture) then
		t.ManaOrbArtworkSize = { 32, 32 }
		t.ManaOrbArtworkPosition = { "BOTTOM", 0, -12 }
		t.ManaOrbArtworkColor = { 1, 1, 1, 1 }
	end
end

Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	if (self:UsesNativeLayout()) then
		local selectedCache = self:IsTest() and testCache or pilotCache
		if (not selectedCache[original]) then
			local config = Copy(original)
			Transform(config, nil, name)
			if (name == "PlayerFrame" or name == "PlayerFrameAlternate") then
				config.PowerBarColors.FOCUS = { 1, .62, .12 }
				if (config.PowerOrbColors) then config.PowerOrbColors.FOCUS = { 1, .62, .12 } end
			end
			if (self:IsTest() and name == "PetFrame") then
				config.Size = {324,100}
				config.HealthBarSize = {144,144*115/930}
				config.HealthBarTexture = testPath("pet-fill")
			end
			selectedCache[original] = config
		end
		return selectedCache[original]
	end
	if (cache[original]) then return cache[original] end
	local config = Copy(original)
	Transform(config)
	if (name == "PlayerFrame" or name == "PlayerFrameAlternate") then
		config.PowerBarColors.FOCUS = { 1, .62, .12 }
		if (config.PowerOrbColors) then config.PowerOrbColors.FOCUS = { 1, .62, .12 } end
	elseif (name == "NamePlates") then
        config.HealthBarTexCoord={0,1,0,1}
        config.CastBarTexCoord={0,1,0,1}
        config.PowerBarTexCoord={0,1,0,1}
        config.TargetHighlightSize=Copy(config.HealthBackdropSize)
        config.TargetHighlightPosition=Copy(config.HealthBackdropPosition)
        config.ThreatSize=Copy(config.HealthBackdropSize)
        config.ThreatPosition=Copy(config.HealthBackdropPosition)
    elseif (name == "PetFrame") then
        config.Size={324,100}
        config.HealthBarSize={144,144*115/930}
        config.HealthBarTexture=path("pet-fill")

	end
    -- Keep original casing dimensions/anchors; variants are packed around
    -- each native meter rather than stretching the whole casing to its opening.
    local compactVariant = name == "PartyFrames" and "party" or name == "RaidFrames" and "raid"
    if compactVariant then
        config.HealthBackdropTexture=path("cast-back-"..compactVariant)
        config.TargetHighlightTexture=path("cast-back-"..compactVariant.."-outline")
    end
    if name == "PlayerFrame" then
        for _,tier in ipairs({"Novice","Hardened","Seasoned"}) do
            local t=config[tier]
            -- Expanded viewport must share the legacy 120x140 area's center.
            t.PowerBarPosition[2]=t.PowerBarPosition[2]-(t.PowerBackdropSize[1]-t.PowerBarSize[1])/2
            t.PowerBarPosition[3]=t.PowerBarPosition[3]-(t.PowerBackdropSize[2]-t.PowerBarSize[2])/2
            -- Leave a small gutter between the new orb clasps and health fill.
            t.ManaOrbPosition[2]=t.ManaOrbPosition[2]-8
        end
    end
	cache[original] = config
	return config
end

Theme.UseIceCrystal = function(self, requested) return self:UsesNativeLayout() and requested or false end
Theme.GetPowerColor = function(self, token)
	if (self:IsActive() and token == "FOCUS") then return { 1, .62, .12 } end
end

-- Staged pilot layering. Called only for a backdrop explicitly routed to the
-- pilot folder; normal Hunter routing remains unchanged pending art review.
Theme.StylePilotLayers = function(self, bar, name, flip)
	local back = bar.Backdrop
	local texture = back and back:GetTexture()
	if (not self:IsPilot() or texture ~= pilotPath(name)) then
		if (bar.HunterPilotOver) then bar.HunterPilotOver:Hide() end
		if (bar.HunterPilotOrnament) then bar.HunterPilotOrnament:Hide() end
		pilotBars[bar] = nil
		return false
	end
	local parent = bar.Overlay or bar
	local over = bar.HunterPilotOver
	if (not over) then
		over = parent:CreateTexture(nil, "ARTWORK", nil, 2)
		bar.HunterPilotOver = over
	end
	over:ClearAllPoints(); over:SetAllPoints(back)
	over:SetTexture(texture:gsub("%.tga$", "-over.tga"))
	over:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	over:SetVertexColor(1, 1, 1, 1)
	over:Show()
	local slot = ns.ThemeOrnamentSlots[name == "cast_back" and "CastHead" or "HealthEndcap"]
	local ornament = bar.HunterPilotOrnament
	if (not ornament) then
		ornament = parent:CreateTexture(nil, "ARTWORK", nil, 3)
		bar.HunterPilotOrnament = ornament
	end
	local cast = name == "cast_back"
	ornament:SetTexture(texture:gsub("[^\\/]+%.tga$", cast and "eagle.tga" or "endcap-thasdorah.tga"))
	ornament:ClearAllPoints(); ornament:SetSize(slot.size, slot.size)
	ornament:SetPoint("CENTER", bar, (cast or flip) and "LEFT" or "RIGHT", flip and -slot.x or slot.x, slot.y)
	ornament:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	ornament:SetShown(cast or ns.db.char.hunterEndcap ~= "none")
	pilotBars[bar] = { name = name, flip = flip }
	return true
end

-- Test artwork follows native backdrops; no statusbar values or widths are read.
Theme.StyleTestLayers = function(self, bar, flip, ornament, cast)
	if (not self:IsTest()) then return end
	local parent = bar.Overlay or bar
	local function layer(back, field)
		local texture = back and back:GetTexture()
		local name = type(texture) == "string" and texture:match("HunterDropIn[\\/]([^\\/]+)%.tga$")
		local supported = name == "hp_cap_case" or name == "cast_back" or name == "cast_back_spiked"
		local over = bar[field]
		if (not supported) then if (over) then over.hunterEnabled = false; over:Hide() end; return end
		if (not over) then
			over = parent:CreateTexture(nil, "ARTWORK", nil, 2)
			bar[field] = over
			-- Native cast callbacks toggle the two backgrounds independently.
			local function sync() over:SetShown(over.hunterEnabled and back:IsShown()) end
			hooksecurefunc(back, "Show", sync)
			hooksecurefunc(back, "Hide", sync)
			hooksecurefunc(back, "SetShown", sync)
			hooksecurefunc(back, "SetTexCoord", function(_, ...) over:SetTexCoord(...) end)
		end
		over.hunterEnabled = true
		over:ClearAllPoints(); over:SetAllPoints(back)
		over:SetTexture(testPath(name.."-over"))
		over:SetVertexColor(1,1,1,1)
		over:SetTexCoord(back:GetTexCoord())
		over:SetShown(back:IsShown())
	end
	layer(bar.Backdrop or bar.backdrop, "HunterTestOver")
	if (cast) then layer(bar.Shield, "HunterTestShieldOver") end
	local art = bar.HunterTestOrnament
	local texture = (bar.Backdrop or bar.backdrop) and (bar.Backdrop or bar.backdrop):GetTexture()
	-- Only full unit health bars have the endcap slot, never critters/compact bars.
	local health = type(texture) == "string" and (texture:find("hp_cap_case",1,true) or texture:find("hp_mid_case",1,true) or texture:find("hp_low_case",1,true) or texture:find("hp_boss_case",1,true))
	if (not ornament or (not cast and not health)) then if (art) then art:Hide() end; return end
	if (not art) then art = parent:CreateTexture(nil,"ARTWORK",nil,3); bar.HunterTestOrnament = art end
	local key = ns.db.char.hunterEndcap or "thasdorah"
	if (not endcaps[key]) then key = "thasdorah" end
	local slot = ns.ThemeOrnamentSlots[cast and "CastHead" or "HealthEndcap"]
	art:SetTexture(testPath(cast and "eagle" or "endcap-"..(key == "none" and "thasdorah" or key)))
	art:ClearAllPoints(); art:SetSize(slot.size,slot.size)
	art:SetPoint("CENTER",bar,(cast or flip) and "LEFT" or "RIGHT",flip and -slot.x or slot.x,slot.y)
	art:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
	art:SetShown(cast or key ~= "none")
end

local Endcap = function(bar, flip, cast)
	local key = ns.db.char.hunterEndcap or "thasdorah"
	if (not endcaps[key]) then key = "thasdorah" end
	local frame = bar.HunterOrnaments
	if (not frame) then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetAllPoints(bar)
		frame:SetFrameLevel(bar:GetFrameLevel() + 3)
		frame:EnableMouse(false)
		frame.Tip = frame:CreateTexture(nil, "ARTWORK")
		bar.HunterOrnaments = frame
	end
	-- Critters get their own native casing, never a compressed long endcap.
	local compact = bar:GetWidth() < bar:GetHeight()*2
	frame:SetShown(not compact)
	if (compact) then return end
	local size = math.min(cast and 58 or 48, bar:GetHeight()*(cast and 2.35 or 1.2))
	local art = frame.Tip
	art:SetTexture(path("endcap-"..(key == "none" and "thasdorah" or key)))
	art:SetAlpha(key == "none" and 0 or 1)
	art:ClearAllPoints()
	art:SetSize(size,size)
	-- Most of the ornament is outside the meter, so no fill/value is covered.
	-- Mirrored target ornaments are at the outer LEFT, away from the portrait.
	art:SetPoint(flip and "RIGHT" or "LEFT", bar, flip and "LEFT" or "RIGHT", flip and 8 or -8, 0)
	art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0,1)
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
    local w,h=bar:GetWidth(),bar:GetHeight()
    local width,height,left,upper,right,lower=2172,724,162,287,1910,410
    if critter then
        width,height=1,1
        left,upper,right,lower=unpack(ns.HunterGeometry.critter)
    end
    local sx=w/(right-left); local sy=h*(bottom-top)/(lower-upper)
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT",bar,"TOPLEFT",-(flip and (width-right) or left)*sx,upper*sy-h*top)
    art:SetSize(width*sx,height*sy)
    art:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
end

Theme.StyleHealth = function(self, owner, db, flip)
    if (not self:IsActive()) then return end
    local bar=owner.Health
	if (self:IsTest()) then return self:StyleTestLayers(bar, flip, true) end
	if (self:IsPilot()) then return self:StylePilotLayers(bar, "hp_cap_case", flip) end
    if (self:StylePilotLayers(bar, "hp_cap_case", flip)) then return end
    Endcap(bar,flip,false)
    local compact=db.HealthBarTexture and db.HealthBarTexture:find("cast_bar",1,true)
    local critter=bar:GetWidth()<bar:GetHeight()*2
    bar.HunterHealthGeometry=nil
    if (compact) then
        if (bar.HunterCasing) then bar.HunterCasing:Hide(); bar.HunterEmpty:SetAlpha(0) end
        bar.Backdrop:SetAlpha(1)
        return
    end
    local texture=db.HealthBarTexture or ns.API.GetMedia("hp_cap_bar")
    local top,bottom=3/128,100/128
    if texture:find("hp_lowmid_bar",1,true) then top,bottom=2/64,52/64
    elseif texture:find("hp_boss_bar",1,true) then top,bottom=2/64,48/64 end
    local name=critter and "hp_critter_case" or (texture:find("hp_boss_bar",1,true) and "hp_boss_case" or "hp_cap_case")
    if critter then top,bottom=0,1 end
    local casing=bar.HunterCasing
    if not casing then
        casing=CreateFrame("Frame",nil,bar); casing:SetAllPoints(bar)
        casing:SetFrameLevel(bar:GetFrameLevel()+2); casing:EnableMouse(false)
        casing.Art=casing:CreateTexture(nil,"ARTWORK"); bar.HunterCasing=casing
        bar.HunterEmpty=bar:CreateTexture(nil,"BACKGROUND",nil,-2)
        bar.HunterEmpty:SetAllPoints(bar); bar.HunterEmpty:SetVertexColor(.09,.08,.11,1)
    end
    casing:Show(); casing.Art:SetTexture(path(name)); Fit(bar,casing.Art,flip,top,bottom,critter)
    bar.HunterEmpty:SetTexture(texture); bar.HunterEmpty:SetAlpha(1)
    bar.HunterEmpty:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1)
    bar.Backdrop:SetAlpha(0)
    bar.HunterHealthGeometry={name,top,bottom,critter}
end
Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive() or self:UsesNativeLayout()) then return end
	local indicator = owner.ThreatIndicator
	local native = indicator and indicator.textures and indicator.textures.Health
	local portrait=indicator and indicator.textures and indicator.textures.Portrait
    if portrait and owner.Portrait and owner.Portrait.Border then
        portrait:ClearAllPoints(); portrait:SetAllPoints(owner.Portrait.Border)
    end
    local geometry=owner.Health.HunterHealthGeometry
    if native and geometry then
        native:SetTexture(path(geometry[1].."_glow"))
        Fit(owner.Health,native,flip,geometry[2],geometry[3],geometry[4])
    end
    local textures=indicator and indicator.textures
    local power=owner.Power
    if textures and power and power.Case and textures.PowerBar then
        local art=textures.PowerBar
        art:SetTexture(path("crystal-group-glow")); art:ClearAllPoints()
        art:SetSize(power:GetWidth()*2,power:GetHeight()*2)
        art:SetPoint("TOPLEFT",power,"TOPLEFT",-power:GetWidth()/2,power:GetHeight()/4)
        if textures.PowerBackdrop then textures.PowerBackdrop:SetAlpha(0) end
    end
    local orb=owner.ManaOrb
    if textures and textures.ManaOrb and orb and orb.Case then
        local art=textures.ManaOrb
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
	local key = ns.db.char.hunterEndcap or "thasdorah"
	if (not endcaps[key]) then key = "thasdorah" end
	glow:SetTexture(path("endcap-"..(key == "none" and "thasdorah" or key).."-glow"))
	glow:SetAlpha(key == "none" and 0 or 1)
	glow:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	glow:SetShown(indicator.isShown and true or false)
end
Theme.StyleCrystal = function(self,power)
	if (self:IsTest() and power.Case) then
		local badge = power.HunterResourceBadge
		if (not badge) then badge = power:CreateTexture(nil,"OVERLAY",nil,1); power.HunterResourceBadge = badge end
		local slot = ns.ThemeOrnamentSlots.ResourceBadge
		badge:SetTexture(testPath("paw")); badge:SetSize(slot.size,slot.size)
		badge:ClearAllPoints(); badge:SetPoint("CENTER",power.Case,"CENTER",slot.x,-power.Case:GetHeight()*slot.yFraction)
		return
	end
    if not self:IsActive() or self:UsesNativeLayout() or not power.Case then return end
    -- Main player uses the complete 196px resource viewport. Match the native
    -- fill to its full-canvas backing instead of stretching its cropped center.
    power:SetTexCoord(0,1,0,1)
    local w,h=power:GetWidth(),power:GetHeight()
    power.Case:ClearAllPoints()
    power.Case:SetPoint("BOTTOM",power,"BOTTOM",0,-23*h/196)
    power.Case:SetSize(198*w/196,98*h/196)
end
Theme.StyleOrb = function(self, orb)
    if not self:IsActive() then return false end
	if (self:IsTest()) then orb:SetStatusBarTexture(testPath("orb-focus"),testPath("orb-focus")); return true end
	if (self:IsPilot()) then
		orb:SetStatusBarTexture(pilotPath("orb-focus"), pilotPath("orb-focus"))
		return true
	end
    orb:SetStatusBarTexture(path("orb-focus"),path("orb-focus"))
    return true -- native LibOrb clipping and resource color remain in control
end

Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive()) then return end
	if (self:IsTest()) then return self:StyleTestLayers(cast, false, true, true) end
	if (self:IsPilot()) then return self:StylePilotLayers(cast, "cast_back", false) end
	if (self:StylePilotLayers(cast, "cast_back", false)) then return end
	Endcap(cast,false,true)
	-- The old shield is a whole bar border. Existing Cast_Update colors still
	-- distinguish protected casts; do not draw that border as a detached icon.
	cast.Shield:SetAlpha(0)
end

Theme.StyleNameplate = function(self, owner)
	if (not self:IsActive() or self:UsesNativeLayout()) then return end
	for _, bar in ipairs({ owner.Health, owner.Castbar }) do
		bar.Backdrop:SetTexture(path("nameplate_backdrop"))
		bar.Backdrop:SetVertexColor(1,1,1)
	end
end

Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive() or self:IsPilot()) then return end
	local media = self:IsTest() and testPath or path
	button.Texture:SetTexture(media("config_button")); button.Texture:SetVertexColor(1,1,1)
	button.Highlight:SetTexture(media("config_button_bright")); button.Highlight:SetVertexColor(1,1,1)
end

-- Created during oUF style construction: its Portrait element owns pet/model
-- changes and vehicle unit updates, just as it does for the existing portraits.
Theme.StylePet = function(self, owner)
    if (not self:IsActive() or self:IsPilot() or owner.HunterPetArt) then return end
	local path = self:IsTest() and testPath or path
    local bar=owner.Health
    local g=ns.HunterGeometry.pet
    local width,height,left,top,right,bottom=unpack(g)
    local scale=bar:GetWidth()/(right-left)
    local casing=owner.Overlay:CreateTexture(nil,"OVERLAY")
    casing:SetTexture(path("pet-case"))
    casing:SetSize(width*scale,height*scale)
    casing:SetPoint("TOPLEFT",bar,"TOPLEFT",-left*scale,top*scale)
    bar.Backdrop:SetAlpha(0)
    local portrait=owner.Overlay:CreateTexture(nil,"ARTWORK")
    portrait:SetSize((g[9]-g[7])*scale,(g[10]-g[8])*scale)
    portrait:SetPoint("TOPLEFT",bar,"TOPLEFT",(g[7]-left)*scale,(top-g[8])*scale)
    local mask=owner.Overlay:CreateMaskTexture()
    mask:SetTexture(ns.API.GetMedia("actionbutton-mask-circular"),"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait); portrait:AddMaskTexture(mask)
    owner.Portrait=portrait
    if owner.TargetHighlight then
        owner.TargetHighlight:SetTexture(path("pet-case-glow"))
        owner.TargetHighlight:ClearAllPoints(); owner.TargetHighlight:SetAllPoints(casing)
    end
    owner.HunterPetArt={casing,mask}
end

-- Preserve user offsets which move casts farther away; clamp upward offsets
-- so the complete 24px health/cast canvases always have a one-pixel gap.
Theme.GetNameplateCastOffset = function(self, offset)
    return self:IsActive() and not self:UsesNativeLayout() and math.min(offset,-1) or offset
end

Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command == "status") then
		self:Print((self:IsTest() and "Hunter theme: staged test set (native boss/mid/low casings and status rings)" or self:IsPilot() and "Hunter theme: round-two pilot" or self:IsActive() and "Hunter theme: on (legacy art)" or "Hunter theme: off").."; endcap: "..(ns.db.char.hunterEndcap or "thasdorah"))
		return
	end
	if (not command or (command ~= "" and command ~= "on" and command ~= "test" and command ~= "pilot" and command ~= "off" and command ~= "toggle" and command ~= "endcap")
		or (command == "endcap" and not endcaps[option]) or (command ~= "endcap" and option ~= "")) then
		self:Print("/azhunter [test|pilot|on|off|toggle|status] or /azhunter endcap [thasdorah|talonclaw|titanstrike|thoridal|raeshalare|none]")
		return
	end
	if (InCombatLockdown()) then self:Print("Change the Hunter theme outside combat."); return end
	local enabling = command == "on" or command == "test" or command == "pilot" or ((command == "" or command == "toggle") and not ns.db.char.hunterPreview)
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	if (enabling and ((variant and variant ~= "") or (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()))) then
		self:Print("Select the main AzeriteUI theme before enabling Hunter."); return
	end
	if (command == "endcap" and self:IsPilot()) then
		if (option ~= "thasdorah" and option ~= "none") then
			self:Print("The round-two pilot supports thasdorah or none.")
			return
		end
		ns.db.char.hunterEndcap = option
		for bar, info in pairs(pilotBars) do self:StylePilotLayers(bar, info.name, info.flip) end
		return
	end
	if (command == "pilot" or command == "on" or command == "test") then
		ns.db.char.hunterPilot = command == "pilot"
		ns.db.char.hunterTest = command == "test"
	end
	if (command == "pilot" and ns.db.char.hunterEndcap ~= "none") then ns.db.char.hunterEndcap = "thasdorah" end
	if (command == "endcap") then ns.db.char.hunterEndcap = option
	else ns.db.char.hunterPreview = enabling and true or false end
	-- Preserve the Paladin preference: /azhunter off returns to it automatically.
	ReloadUI()
end

Theme.ProfileChanged = function(self)
	if (self.loadedActive ~= self:IsActive() or self.loadedPilot ~= self:IsPilot() or self.loadedTest ~= self:IsTest()) then
		if (InCombatLockdown()) then self:RegisterEvent("PLAYER_REGEN_ENABLED","ProfileChanged")
		else self:UnregisterEvent("PLAYER_REGEN_ENABLED","ProfileChanged"); ReloadUI() end
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
	end
end
Theme.OnInitialize = function(self) self:RegisterChatCommand("azhunter","Command") end
Theme.OnEnable = function(self)
	self.loadedActive = self:IsActive()
	self.loadedPilot = self:IsPilot()
	self.loadedTest = self:IsTest()
	if (self.loadedActive and not self.loadedPilot and ns.OptionsKit) then
		local path = self.loadedTest and testPath or path
		for _,key in ipairs({ "WindowBackdrop", "WindowCasing", "ButtonBackdrop" }) do ns.OptionsKit[key].edgeFile = path("border-tooltip") end
        if not self.loadedTest and ns.OptionsKit.InsetBackdrop then ns.OptionsKit.InsetBackdrop.edgeFile=path("border-aura") end
	end
	ns.db.RegisterCallback(self,"OnProfileChanged","ProfileChanged")
	ns.db.RegisterCallback(self,"OnProfileCopied","ProfileChanged")
	ns.db.RegisterCallback(self,"OnProfileReset","ProfileChanged")
end

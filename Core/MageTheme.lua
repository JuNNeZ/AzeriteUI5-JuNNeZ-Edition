-- The Tirisgarde: Mage artwork. Every casing is a drop-in replacement for the
-- native texture of the same name, on the same canvas with the same alpha and
-- openings (Assets_Draft/Mage-Complete-Assets-v12/manifest.json), so no size,
-- offset or texcoord is changed. Ornaments are separate, non-interactive art.
-- The crystal's energy is Core/MageCrystalPreview.lua; Core/ThemeEffects.lua
-- decides when it plays.
local Addon, ns = ...
local Theme = ns:NewModule("MageTheme", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.MageTheme = Theme

local path = function(name) return "Interface\\AddOns\\"..Addon.."\\Assets\\Mage\\"..name..".tga" end
local cache = {}

-- The 30 native casings the pack replaces (manifest "replace").
local media = {}
for _, name in ipairs({
	"hp_cap_case", "hp_mid_case", "hp_low_case", "hp_boss_case", "hp_critter_case", "hp_critter_case_hi",
	"cast_back", "cast_back_spiked", "cast_back_wooden", "nameplate_backdrop",
	"pw_crystal_case", "pw_crystal_case_low", "orb_case_hi", "orb_case_low", "orb-border",
	"portrait_frame_hi", "portrait_frame_lo", "party_portrait_border", "actionbutton-border",
	"minimap-border", "minimap-onebar-backdrop", "minimap-twobars-backdrop", "point_plate",
	"config_button", "config_button_bright", "icon_exit_flight", "options-box",
	"border-tooltip", "border-aura", "better-blizzard-border-small-alternate"
}) do media[name] = true end
Theme.Media = media

-- Ornament slots from the manifest, in layout units: the health endcap sits on
-- the bar's outer end, sized against the Seasoned meter's 40px height; the
-- cast head on the cast bar's left end; the school badge on the crystal case.
local ENDCAP_SLOT = { size = 88, x = 14, y = 0, reference = 40 }
local CAST_HEAD_SLOT = { size = 48, x = -26, y = 0 }
local BADGE_SLOT = { size = 32, yFraction = .06 }
local BADGES = { arcane = "badge-eye", fire = "badge-fire", frost = "badge-frost" }
-- Each school's suggested staff, used by the "school" endcap choice.
local SCHOOL_ENDCAPS = { arcane = "aluneth", fire = "felomelorn", frost = "ebonchill" }
local endcaps = { school = true, aluneth = true, felomelorn = true, ebonchill = true, atiesh = true, dragonwrath = true, none = true }
local ENDCAP_OFFSET_LIMIT = 60

local Char = function() return ns.db and ns.db.char end

local School = function()
	local preview = ns.MageCrystalPreview
	return preview and preview:GetSchool() or "arcane"
end

local EndcapKey = function()
	local key = Char() and Char().mageEndcap or "school"
	return endcaps[key] and key or "school"
end

-- The staff actually drawn, or nil for none.
local EndcapArt = function()
	local key = EndcapKey()
	if (key == "none") then return end
	if (key == "school") then key = SCHOOL_ENDCAPS[School()] or "aluneth" end
	return "ornament-"..key
end

local EndcapScale = function()
	local scale = tonumber(Char() and Char().mageEndcapScale)
	return (scale and scale >= .5 and scale <= 2) and scale or 1
end

local EndcapOffset = function()
	local char = Char()
	local function clamp(value)
		value = tonumber(value)
		if (not value or value ~= value) then return 0 end
		return math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, value))
	end
	return clamp(char and char.mageEndcapX), clamp(char and char.mageEndcapY)
end

-- Every styled bar and crystal, so ornament changes apply without a reload.
local endcapBars = setmetatable({}, { __mode = "k" })
local crystals = setmetatable({}, { __mode = "k" })

Theme.IsActive = function(self)
	local char = Char()
	if (not char or not char.magePreview) then return false end
	if (ns.HunterTheme and ns.HunterTheme:IsActive()) then return false end
	if (ns.IsSaiyaRattProfile and ns:IsSaiyaRattProfile()) then return false end
	local variant = ns.GetActiveConfigVariant and ns:GetActiveConfigVariant()
	return not variant or variant == ""
end

Theme.ResolveMedia = function(self, name)
	if (media[name] and self:IsActive()) then return path(name) end
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
	for key, value in pairs(source) do result[key] = Copy(value, seen) end
	return result
end

-- Replaces media paths only. Casing tint must be white (manifest), so the
-- colour paired with each replaced texture loses its tint but keeps alpha.
local function Transform(t, seen)
	if (type(t.GetObjectType) == "function" or type(t[0]) == "userdata") then return end
	seen = seen or {}; if (seen[t]) then return end; seen[t] = true
	for key, value in pairs(t) do
		if (type(value) == "table") then Transform(value, seen)
		elseif (type(value) == "string") then
			local replacement = Theme:ResolvePath(value)
			if (replacement ~= value) then
				t[key] = replacement
				local prefix = type(key) == "string" and (key:match("^(.-)Texture$") or key:match("^(.-)TexturePath$"))
				local color = prefix and t[prefix.."Color"]
				if (type(color) == "table") then t[prefix.."Color"] = { 1, 1, 1, color[4] or 1 } end
			end
		end
	end
end

-- Lazily copied: source tables and other profiles are untouched.
Theme.GetConfig = function(self, name, original)
	if (not self:IsActive()) then return original end
	if (cache[original]) then return cache[original] end
	local config = Copy(original)
	Transform(config)
	cache[original] = config
	return config
end

-- Mana stays sapphire and the ice crystal stays the player's choice.
Theme.UseIceCrystal = function(self, requested) return requested end
Theme.GetPowerColor = function(self, token) end

local OrnamentFrame = function(bar, key)
	local frame = bar[key]
	if (not frame) then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetAllPoints(bar)
		frame:EnableMouse(false)
		frame.Art = frame:CreateTexture(nil, "ARTWORK")
		bar[key] = frame
	end
	frame:SetFrameLevel(bar:GetFrameLevel() + 3)
	return frame
end

local Endcap = function(bar, flip)
	local frame = OrnamentFrame(bar, "MageOrnaments")
	endcapBars[bar] = flip and true or false
	local art = EndcapArt()
	-- Critters keep their own native casing, never a compressed long endcap.
	local compact = bar:GetWidth() < bar:GetHeight()*2
	frame:SetShown(art ~= nil and not compact)
	if (not art or compact) then return end
	local unit = bar:GetHeight()/ENDCAP_SLOT.reference
	local size = ENDCAP_SLOT.size*unit*EndcapScale()
	local dx, dy = EndcapOffset()
	-- Centre-anchored on the bar's outer end, so a size change grows it in place.
	local x = ENDCAP_SLOT.x*unit + dx
	frame.Art:SetTexture(path(art))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(size, size)
	frame.Art:SetPoint("CENTER", bar, flip and "LEFT" or "RIGHT", flip and -x or x, ENDCAP_SLOT.y*unit + dy)
	frame.Art:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	if (frame.Threat) then
		frame.Threat:SetTexture(path(art.."-glow"))
		frame.Threat:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	end
end

Theme.StyleHealth = function(self, owner, db, flip)
	if (not self:IsActive()) then return end
	local bar = owner.Health
	-- Compact bars share the cast casing and have no endcap slot.
	if (db and type(db.HealthBarTexture) == "string" and db.HealthBarTexture:find("cast_bar", 1, true)) then
		if (bar.MageOrnaments) then bar.MageOrnaments:Hide() end
		endcapBars[bar] = nil
		return
	end
	Endcap(bar, flip)
end

-- The staff's neutral glow follows our own native threat texture: its
-- visibility and colour. No unit threat values are queried or compared.
Theme.StyleThreat = function(self, owner, flip)
	if (not self:IsActive()) then return end
	local indicator = owner.ThreatIndicator
	local native = indicator and indicator.textures and indicator.textures.Health
	local frame = owner.Health and owner.Health.MageOrnaments
	if (not native or not frame) then return end
	local glow = frame.Threat
	if (not glow) then
		glow = frame:CreateTexture(nil, "BACKGROUND")
		glow:SetAllPoints(frame.Art)
		glow:SetBlendMode("ADD")
		glow:Hide()
		frame.Threat = glow
		hooksecurefunc(native, "Show", function() glow:Show() end)
		hooksecurefunc(native, "Hide", function() glow:Hide() end)
		hooksecurefunc(native, "SetVertexColor", function(_, ...) glow:SetVertexColor(...) end)
	end
	local art = EndcapArt()
	if (art) then glow:SetTexture(path(art.."-glow")) end
	glow:SetAlpha(art and 1 or 0)
	glow:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
	glow:SetShown(indicator.isShown and true or false)
end

-- Atiesh on the player cast bar's left end. The native casing, shield and
-- protected-cast colours are untouched.
Theme.StyleCastbar = function(self, cast)
	if (not self:IsActive()) then return end
	local frame = OrnamentFrame(cast, "MageCastHead")
	frame.Art:SetTexture(path("cast-head-atiesh"))
	frame.Art:ClearAllPoints()
	frame.Art:SetSize(CAST_HEAD_SLOT.size, CAST_HEAD_SLOT.size)
	frame.Art:SetPoint("CENTER", cast, "LEFT", CAST_HEAD_SLOT.x, CAST_HEAD_SLOT.y)
	frame:Show()
end

-- The north ornament follows the existing moving compass anchor. Rotation,
-- radius and minimap geometry stay owned by the original compass code.
Theme.StyleCompass = function(self, compass)
	if (not self:IsActive() or not compass or not compass.north) then return end
	local art = compass.MageNorth
	if (not art) then art = compass:CreateTexture(nil, "OVERLAY"); compass.MageNorth = art end
	art:SetTexture(path("minimap-north"))
	art:SetSize(32, 32)
	art:SetPoint("CENTER", compass.north, "CENTER", 0, 0)
	compass.north:SetAlpha(0) -- The texture already contains the N.
end

-- A compact water-elemental seal joins the pet casing at its left end.
-- Parent visibility follows the pet frame; no unit data or hit rect changes.
Theme.StylePet = function(self, owner)
	if (not self:IsActive() or not owner or not owner.Health) then return end
	local frame = OrnamentFrame(owner.Health, "MagePetBadge")
	frame.Art:SetTexture(path("badge-water-elemental"))
	frame.Art:SetSize(32, 32)
	frame.Art:ClearAllPoints()
	frame.Art:SetPoint("RIGHT", owner.Health, "LEFT", -2, 0)
	frame:Show()
end

-- Plates set their backdrop outside the layout tables.
Theme.StyleNameplate = function(self, owner)
	if (not self:IsActive()) then return end
	for _, bar in ipairs({ owner.Health, owner.Castbar }) do
		if (bar and bar.Backdrop) then
			bar.Backdrop:SetTexture(path("nameplate_backdrop"))
			bar.Backdrop:SetVertexColor(1, 1, 1)
		end
	end
end

Theme.StyleUtilityButton = function(self, button)
	if (not self:IsActive()) then return end
	button.Texture:SetTexture(path("config_button")); button.Texture:SetVertexColor(1, 1, 1)
	button.Highlight:SetTexture(path("config_button_bright")); button.Highlight:SetVertexColor(1, 1, 1)
end

--- The school badge on the crystal case. Called for the main player crystal
--- through Core/ThemeEffects.lua; hides itself when the theme is not in use.
Theme.StyleCrystal = function(self, power)
	local frame = power.MageBadge
	if (not self:IsActive() or not power.Case) then
		if (frame) then frame:Hide() end
		crystals[power] = nil
		return
	end
	crystals[power] = true
	if (not frame) then
		frame = CreateFrame("Frame", nil, power)
		frame:SetAllPoints(power)
		frame:EnableMouse(false)
		frame.Art = frame:CreateTexture(nil, "OVERLAY")
		power.MageBadge = frame
	end
	-- Above the case, which the Mage crystal lifts into its own frame.
	frame:SetFrameLevel(power:GetFrameLevel() + 6)
	frame.Art:SetTexture(path(BADGES[School()] or BADGES.arcane))
	frame.Art:SetSize(BADGE_SLOT.size, BADGE_SLOT.size)
	frame.Art:ClearAllPoints()
	frame.Art:SetPoint("CENTER", power.Case, "CENTER", 0, -power.Case:GetHeight()*BADGE_SLOT.yFraction)
	frame:Show()
end

--- Redraws ornaments after a choice changes: endcaps, glows and badges.
Theme.RefreshOrnaments = function(self)
	if (not self:IsActive()) then return end
	for bar, flip in pairs(endcapBars) do Endcap(bar, flip) end
	for power in pairs(crystals) do self:StyleCrystal(power) end
end

Theme.GetEndcapChoices = function(self) return endcaps end
Theme.GetEndcap = function(self) return EndcapKey() end
Theme.GetEndcapScale = function(self) return EndcapScale() end
Theme.GetEndcapOffset = function(self) return EndcapOffset() end

--- Endcap by key: "school" follows the crystal's school. Applies live.
Theme.SetEndcap = function(self, key)
	if (not endcaps[key] or InCombatLockdown()) then return false end
	Char().mageEndcap = key ~= "school" and key or nil
	self:RefreshOrnaments()
	return true
end

Theme.SetEndcapScale = function(self, scale)
	scale = tonumber(scale)
	if (not scale or scale < .5 or scale > 2 or InCombatLockdown()) then return false end
	Char().mageEndcapScale = scale ~= 1 and scale or nil
	self:RefreshOrnaments()
	return true
end

Theme.SetEndcapOffset = function(self, x, y)
	if (InCombatLockdown()) then return false end
	local oldX, oldY = EndcapOffset()
	x, y = tonumber(x) or oldX, tonumber(y) or oldY
	x = math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, x))
	y = math.max(-ENDCAP_OFFSET_LIMIT, math.min(ENDCAP_OFFSET_LIMIT, y))
	Char().mageEndcapX = x ~= 0 and x or nil
	Char().mageEndcapY = y ~= 0 and y or nil
	self:RefreshOrnaments()
	return true
end

Theme.ResetEndcapPlacement = function(self)
	if (InCombatLockdown()) then return false end
	local char = Char()
	char.mageEndcapScale, char.mageEndcapX, char.mageEndcapY = nil, nil, nil
	self:RefreshOrnaments()
	return true
end

Theme.Command = function(self, input)
	local command, option = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
	if (command=="preview" and ns.ThemeBarPreview) then ns.ThemeBarPreview:Show();return end
	if (command == "status") then
		self:Print((self:IsActive() and "Mage theme: on" or "Mage theme: off").."; endcap: "..EndcapKey())
		return
	end
	if (command == "endcap") then
		if (not endcaps[option]) then
			self:Print("/azmage endcap [school|aluneth|felomelorn|ebonchill|atiesh|dragonwrath|none]")
			return
		end
		if (InCombatLockdown()) then self:Print("Change the Mage theme outside combat."); return end
		self:SetEndcap(option)
		return
	end
	if (command ~= "" and command ~= "on" and command ~= "off" and command ~= "toggle") then
		self:Print("/azmage [on|off|toggle|status] or /azmage endcap <name>")
		return
	end
	local effects = ns.ThemeEffects
	if (not effects) then return end
	local enabling = command == "on" or ((command == "" or command == "toggle") and not self:IsActive())
	if (InCombatLockdown()) then self:Print("Change the Mage theme outside combat."); return end
	effects:SetTheme(enabling and "mage" or "azerite")
end

Theme.ProfileChanged = function(self)
	if (self.loadedActive ~= self:IsActive()) then
		if (InCombatLockdown()) then self:RegisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
		else self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged"); ReloadUI() end
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
	end
end

Theme.OnInitialize = function(self) self:RegisterChatCommand("azmage", "Command") end

Theme.OnEnable = function(self)
	self.loadedActive = self:IsActive()
	if (self.loadedActive and ns.OptionsKit) then
		for _, key in ipairs({ "WindowBackdrop", "WindowCasing", "ButtonBackdrop" }) do ns.OptionsKit[key].edgeFile = path("border-tooltip") end
		if (ns.OptionsKit.InsetBackdrop) then ns.OptionsKit.InsetBackdrop.edgeFile = path("border-aura") end
	end
	ns.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	ns.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
end

-- Offline contract tests for Core/MageTheme.lua against the real layout tables:
-- media swaps by name, no geometry changed, every referenced file shipped,
-- ornaments anchored and live. Does not emulate rendering or claim live fit.
-- lua Tools/Harness/mage_theme_harness.lua .
local root = arg[1] or "."
local checks, reloads, combat = 0, 0, false
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local env = setmetatable({}, { __index = _G })
env._G = env
env.ITEM_QUALITY_COLORS = {}
env.Enum = { PowerType = { Mana = 0, HolyPower = 9 } }
env.RAID_CLASS_COLORS = { PALADIN = { r = .95, g = .5, b = .7 } }
env.CreateFont = function(name)
	return { name = name, SetJustifyH = function() end, GetObjectType = function() return "Font" end }
end
env.InCombatLockdown = function() return combat end
env.ReloadUI = function() reloads = reloads + 1 end
local ns = { API = {}, Prefix = "AzeriteTest" }
local function load(path)
	local chunk = assert(loadfile(root.."/"..path))
	setfenv(chunk, env)
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
function ns:NewModule()
	return {
		RegisterChatCommand = function(self, command) self.command = command end,
		RegisterEvent = function(self, event) self.event = event end,
		UnregisterEvent = function(self) self.event = nil end,
		Print = function(self, message) self.message = message end
	}
end
function ns:GetActiveConfigVariant() return self.variant end
function ns:IsSaiyaRattProfile() return self.variant == "SaiyaRatt" end
function ns:GetModule() end
function ns:Print(message) self.message = message end
load("Core/Private.lua")
ns.Private.PlayerClass = "MAGE"
load("Core/API/Tables.lua")
load("Core/Common/Colors.lua")
load("Core/API/Assets.lua")
load("Core/PaladinTheme.lua")
load("Core/HunterMedia.lua")
load("Core/HunterGeometry.lua")
load("Core/HunterTheme.lua")
-- The crystal module's school is all the theme reads from it.
ns.MageCrystalPreview = { GetSchool = function() return ns.db.char.mageCrystalSchool or "arcane" end, StyleCrystal = function() end }
load("Core/MageTheme.lua")
load("Core/ThemeEffects.lua")
load("Core/Finalize.lua")
load("Layouts/Layouts.lua")
local layoutNames = { "PlayerUnitFrame", "PlayerUnitFrameAlternate", "TargetUnitFrame",
	"BossUnitFrames", "PlayerClassPower", "PlayerCastBar", "NamePlates", "ActionButton",
	"PetActionButton", "StanceButton", "ExtraActionButton", "Tooltips", "FocusUnitFrame", "ToTUnitFrame",
	"PetUnitFrame", "PartyUnitFrames", "RaidUnitFrames5", "RaidUnitFrames40", "ArenaEnemyUnitFrames", "MirrorTimers", "StatusBars", "VehicleExitButton" }
for _, file in ipairs(layoutNames) do load("Layouts/Data/"..file..".lua") end
local configNames = { "PlayerFrame", "PlayerFrameAlternate", "TargetFrame", "BossFrames", "PlayerCastBar", "PlayerClassPower",
	"ActionButton", "PetActionButton", "StanceButton", "NamePlates", "FocusFrame", "ToTFrame", "PetFrame",
	"PartyFrames", "Raid5Frames", "RaidFrames", "ArenaFrames", "MirrorTimers", "StatusBars", "VehicleExitButton" }

local theme = ns.MageTheme
local GetMedia = ns.API.GetMedia
check(not theme:IsActive(), "safe before database")
ns.db = { global = {}, char = {}, RegisterCallback = function() end }
theme:OnInitialize()
check(theme.command == "azmage", "slash registered")

-- Originals, before the theme.
local originals = {}
for _, name in ipairs(configNames) do originals[name] = ns.GetConfig(name) end
check(GetMedia("hp_cap_case"):find("\\Assets\\hp_cap_case.tga", 1, true), "native media while off")

theme:Command("on")
check(theme:IsActive() and reloads == 1 and ns.db.char.magePreview, "on reloads into the Mage theme")
theme.loadedActive = true
check(ns.ThemeEffects:GetTheme() == "mage", "Theme effects see the Mage theme")
check(not ns.PaladinTheme:IsActive(), "Paladin stands aside")

-- Every replaced name resolves through GetMedia, and every file exists.
local count = 0
for name in pairs(theme.Media) do
	count = count + 1
	local file = GetMedia(name)
	check(file:find("\\Assets\\Mage\\"..name..".tga", 1, true), "GetMedia swaps "..name)
	local disk = io.open(root.."/Assets/Mage/"..name..".tga", "rb")
	check(disk, "shipped: "..name); if (disk) then disk:close() end
end
check(count == 30, "all 30 casings from the manifest")
for _, name in ipairs({ "hp_cap_bar", "cast_bar", "orb2", "point_gem" }) do
	check(not GetMedia(name):find("\\Mage\\", 1, true), "shared original kept: "..name)
end
for _, name in ipairs({ "ornament-aluneth", "ornament-felomelorn", "ornament-ebonchill", "ornament-atiesh", "ornament-dragonwrath", "badge-eye", "badge-fire", "badge-frost" }) do
	for _, suffix in ipairs(name:find("ornament", 1, true) and { "", "-glow" } or { "" }) do
		local disk = io.open(root.."/Assets/Mage/"..name..suffix..".tga", "rb")
		check(disk, "shipped: "..name..suffix); if (disk) then disk:close() end
	end
end

-- Layouts: textures swapped by name, white tint, no geometry changed.
local function walk(a, b, path, visit, seen)
	seen = seen or {}
	if (type(a) ~= "table" or seen[a] or a.GetObjectType) then return end
	seen[a] = true
	for key, value in pairs(a) do
		local other = b[key]
		if (type(value) == "table") then
			if (type(other) == "table") then walk(value, other, path.."."..tostring(key), visit, seen) end
		else
			visit(path.."."..tostring(key), key, value, other, a, b)
		end
	end
end
local swapped, numbers = 0, 0
for _, name in ipairs(configNames) do
	local themed = ns.GetConfig(name)
	check(themed ~= originals[name] or not next(originals[name]), name.." uses its own copy")
	walk(originals[name], themed, name, function(where, key, value, other, a, b)
		if (type(value) == "number") then
			numbers = numbers + 1
			-- Colour components may lose their tint; nothing else may move.
			if (other ~= value) then check(where:find("Color", 1, true), "geometry kept at "..where) end
		elseif (type(value) == "string" and value ~= other) then
			swapped = swapped + 1
			local asset = value:match("[\\/]Assets[\\/]([^\\/]+)%.tga$")
			check(asset and theme.Media[asset] and other:find("\\Assets\\Mage\\"..asset..".tga", 1, true), "only casings swapped at "..where)
			local prefix = type(key) == "string" and (key:match("^(.-)Texture$") or key:match("^(.-)TexturePath$"))
			local color = prefix and b[prefix.."Color"]
			if (type(color) == "table") then
				check(color[1] == 1 and color[2] == 1 and color[3] == 1, "casing tint white at "..where)
			end
		end
	end)
end
check(swapped >= 20 and numbers > 500, "layouts walked ("..swapped.." swaps, "..numbers.." numbers)")
check(ns.GetConfig("PlayerFrame").Seasoned.HealthBackdropTexture:find("\\Mage\\hp_cap_case", 1, true), "player casing")
check(ns.GetConfig("PlayerFrame").PowerBarColors.MANA[3] == originals.PlayerFrame.PowerBarColors.MANA[3], "mana stays sapphire")

-- Ornaments.
local widgetCount = 0
local function widget(parent)
	widgetCount = widgetCount + 1
	local w = { parent = parent, points = {}, shown = true, level = 2, width = 385, height = 40 }
	function w:SetAllPoints(anchor) self.allPoints = anchor end
	function w:SetPoint(point, ...) self.points[point] = { ... } end
	function w:ClearAllPoints() self.points = {} end
	function w:SetSize(x, y) self.width, self.height = x, y end
	function w:GetWidth() return self.width end
	function w:GetHeight() return self.height end
	function w:SetFrameLevel(v) self.level = v end
	function w:GetFrameLevel() return self.level end
	function w:EnableMouse(v) self.mouse = v end
	function w:SetTexture(value) self.texture = value end
	function w:SetTexCoord(...) self.coords = { ... } end
	function w:SetVertexColor(...) self.color = { ... } end
	function w:SetAlpha(value) self.alpha = value end
	function w:SetBlendMode(value) self.blendMode = value end
	function w:SetShown(value) self.shown = value end
	function w:Show() self.shown = true end
	function w:Hide() self.shown = false end
	function w:CreateTexture() return widget(self) end
	function w:GetValue() error("theme read a unit value") end
	return w
end
env.CreateFrame = function(kind, _, parent) local w = widget(parent); w.kind = kind; return w end
env.hooksecurefunc = function(object, key, callback)
	local before = object[key]
	object[key] = function(...) before(...); callback(...) end
end

local owner = widget(); owner.Health = widget(owner)
local seasoned = ns.GetConfig("PlayerFrame").Seasoned
ns.PaladinTheme:StyleHealth(owner, seasoned, false)
local frame = owner.Health.MageOrnaments
local art = frame and frame.Art
check(art and art.texture:find("ornament-aluneth.tga", 1, true), "Arcane follows Aluneth by default (through Paladin's dispatcher)")
check(art.width == 88 and art.points.CENTER[2] == "RIGHT" and art.points.CENTER[3] == 14 and art.points.CENTER[4] == 0, "manifest endcap slot on a 40px bar")
check(frame.level > owner.Health.level and frame.mouse == false, "ornament above the bar, not interactive")
check(theme:SetEndcapScale(1.5) and art.width == 132 and art.points.CENTER[3] == 14, "size grows in place, live")
check(theme:SetEndcapOffset(6, -2) and art.points.CENTER[3] == 20 and art.points.CENTER[4] == -2, "offset live")
ns.PaladinTheme:StyleHealth(owner, seasoned, true)
check(art.points.CENTER[2] == "LEFT" and art.points.CENTER[3] == -20 and art.coords[1] == 1, "mirrored target endcap")
check(theme:ResetEndcapPlacement() and art.width == 88 and art.points.CENTER[3] == -14, "reset")
ns.db.char.mageCrystalSchool = "fire"; theme:RefreshOrnaments()
check(art.texture:find("ornament-felomelorn.tga", 1, true), "Fire follows Felo'melorn")
check(theme:SetEndcap("dragonwrath") and art.texture:find("ornament-dragonwrath.tga", 1, true) and reloads == 1, "fixed staff, live")
check(theme:SetEndcap("none") and not frame.shown, "no endcap")
check(not theme:SetEndcap("bogus") and theme:GetEndcap() == "none", "unknown staff refused")
theme:SetEndcap("school")
check(ns.db.char.mageEndcap == nil and frame.shown, "school is the stored default")
-- Critters and compact bars keep their own casing.
owner.Health:SetSize(40, 36); ns.PaladinTheme:StyleHealth(owner, seasoned, false)
check(not frame.shown, "critter has no endcap")
owner.Health:SetSize(385, 40)
local compact = widget(); compact.Health = widget(compact)
ns.PaladinTheme:StyleHealth(compact, { HealthBarTexture = "cast_bar.tga" }, false)
check(not compact.Health.MageOrnaments, "compact bars have no endcap")

-- Threat glow follows the native threat texture and the staff.
ns.PaladinTheme:StyleHealth(owner, seasoned, false)
owner.ThreatIndicator = { textures = { Health = widget(owner) }, isShown = false }
local native = owner.ThreatIndicator.textures.Health
ns.PaladinTheme:StyleThreat(owner, false)
local glow = frame.Threat
check(glow and glow.texture:find("ornament-felomelorn-glow", 1, true) and glow.allPoints == art, "staff glow on the staff")
native:Show(); check(glow.shown, "glow follows show")
native:SetVertexColor(.9, .2, .1); check(glow.color[1] == .9, "threat colour forwarded")
native:Hide(); check(not glow.shown, "glow follows hide")
theme:SetEndcap("atiesh"); check(glow.texture:find("ornament-atiesh-glow", 1, true), "glow follows a live staff change")

-- Cast head and school badge.
local cast = widget(owner)
ns.PaladinTheme:StyleCastbar(cast)
check(cast.MageCastHead.Art.texture:find("cast-head-atiesh.tga", 1, true) and cast.MageCastHead.Art.points.CENTER[3] == -26, "Atiesh cast head on the left")
local power = widget(owner); power.Case = widget(power); power.Case:SetSize(120, 100)
ns.ThemeEffects:StyleCrystal(power, "crystal.tga", { 0, 1, 0, 1 }, "case.tga")
local badge = power.MageBadge
check(badge and badge.Art.texture:find("badge-fire.tga", 1, true) and badge.Art.points.CENTER[1] == power.Case, "Fire badge on the case")
check(badge.Art.points.CENTER[3] == 0 and badge.Art.points.CENTER[4] == -6 and badge.level > power.level + 3, "badge low on the case, above the lifted case")
ns.db.char.mageCrystalSchool = "frost"; theme:RefreshOrnaments()
check(badge.Art.texture:find("badge-frost.tga", 1, true), "badge follows the school live")
local alternate = widget(owner); alternate.Case = widget(alternate)
ns.ThemeEffects:StyleCrystal(alternate, "crystal.tga", nil, nil, false)
check(not alternate.MageBadge, "no badge on the alternate frame's crystal")

-- Off: everything native again, and the badge hides on the next redraw.
ns.variant = "SaiyaRatt"
check(not theme:IsActive() and not GetMedia("hp_cap_case"):find("\\Mage\\", 1, true), "other layouts stay native")
ns.ThemeEffects:StyleCrystal(power, "crystal.tga", { 0, 1, 0, 1 }, "case.tga")
check(not badge.shown, "badge hidden when the theme is not in use")
ns.variant = nil
ns.db.global.enableDevelopmentMode = true
ns.PaladinTheme:Command("on")
check(not ns.db.char.magePreview and ns.PaladinTheme:IsActive(), "choosing Paladin leaves Mage")
ns.db.char.paladinPreview = false; ns.db.char.magePreview = true
ns.db.char.hunterPreview = true
check(not theme:IsActive(), "Hunter wins over Mage, never stacked")
ns.db.char.hunterPreview = false
combat = true; local r = reloads; theme:Command("off"); check(reloads == r and theme:IsActive(), "combat refuses")
combat = false; theme:Command("off"); check(not ns.db.char.magePreview and reloads == r + 1, "off reloads out of the Mage theme")



-- All synthetic test variants build from the current real theme configurations.
local make=widget
widget=function(parent)
 local w=make(parent)
 function w:GetParent() return self.parent end
 function w:GetName() return 'ThemeBarTests' end
 function w:IsShown() return self.shown end
 function w:SetText(v) self.text=v end
 function w:SetStatusBarTexture(...) self.fill=self.fill or widget(self);self.fill.texture={...} end
 function w:GetStatusBarTexture() self.fill=self.fill or widget(self);return self.fill end
 function w:SetDrawLayer(...) self.drawLayer={...} end
 function w:SetStatusBarColor(...) self.fillColor={...} end
 function w:SetMinMaxValues(...) self.minmax={...} end
 function w:SetValue(v) self.value=v end
 function w:SetOrientation(v) self.orientation=v end
 function w:SetReverseFill(v) self.reversed=v end
 return w
end
env.LibStub=function() return {CreateOrb=function(_,_,parent) return widget(parent) end} end
load('Core/ThemeBarPreview.lua')
local P=ns.ThemeBarPreview
P.window=widget();P.hint=widget();P.entries={}
combat=false;ns.db.char.magePreview=true;ns.db.char.hunterPreview=false;ns.db.char.paladinPreview=false
for key,def in pairs(P.Definitions) do
 local config=ns.GetConfig(def[1]);check(config,'test config exists: '..key)
 local db=def[2] and config[def[2]] or config;check(db,'test tier exists: '..key)
 P.kind=key;P:Refresh()
 local entry=P.entries[key];check(entry and entry.owner.shown,'preview builds '..key)
 for _,bar in ipairs(entry.bars) do check(bar.value==.5,'synthetic half fill: '..key) end
 P:Set('fraction',0);for _,bar in ipairs(entry.bars) do check(bar.value==0,'empty preview: '..key) end
 P:Set('fraction',1);for _,bar in ipairs(entry.bars) do check(bar.value==1,'full preview: '..key) end
 P:Set('fraction',.5)
end
local entries=0;for _ in pairs(P.entries) do entries=entries+1 end
check(entries>=22,'all tier and compact test families available')
P:Set('kind','cast');P:Set('protected',true)
check(P.entries.cast.cast.Shield.shown and not P.entries.cast.cast.Backdrop.shown,'protected cast casing')
P:Set('protected',false);check(not P.entries.cast.cast.Shield.shown and P.entries.cast.cast.Backdrop.shown,'ordinary cast casing')
combat=true;local before=P.kind;P:Set('kind','playerLo');check(P.kind==before,'combat blocks test writes')
print('Theme preview: '..checks..' checks passed (offline only)')

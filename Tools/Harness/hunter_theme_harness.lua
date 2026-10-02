-- Offline contract tests: real theme, media resolver and layout tables.
-- Does not emulate rendering or claim live Retail/Forever coverage.
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
load("Core/Private.lua")
ns.Private.PlayerClass = "PALADIN"
load("Core/API/Tables.lua")
load("Core/Common/Colors.lua")
load("Core/API/Assets.lua")
load("Core/PaladinTheme.lua")
load("Core/HunterMedia.lua")
load("Core/HunterGeometry.lua")
load("Core/ThemeOrnamentSlots.lua")
load("Core/HunterTheme.lua")
load("Core/Finalize.lua")
load("Layouts/Layouts.lua")
for _, file in ipairs({ "PlayerUnitFrame", "PlayerUnitFrameAlternate", "TargetUnitFrame",
	"BossUnitFrames", "PlayerClassPower", "PlayerCastBar", "NamePlates", "ActionButton",
	"PetActionButton", "StanceButton", "ExtraActionButton", "Tooltips", "FocusUnitFrame", "ToTUnitFrame",
	"PetUnitFrame", "PartyUnitFrames", "RaidUnitFrames5", "RaidUnitFrames40", "ArenaEnemyUnitFrames", "MirrorTimers", "StatusBars", "VehicleExitButton" }) do
	load("Layouts/Data/"..file..".lua")
end

local theme = ns.HunterTheme
local original = ns.GetConfig("PlayerFrame")
check(not theme:IsActive(), "safe before database")
ns.db = {global={},char={},RegisterCallback=function() end}
theme:OnInitialize()
check(theme.command == "azhunter", "slash registered")
theme:Command("on")
check(theme:IsActive() and reloads == 1, "enables without development mode")
local themed=ns.GetConfig("PlayerFrame")
check(themed~=original and themed==ns.GetConfig("PlayerFrame"),"cached independent layout")
for _,tier in ipairs({"Novice","Hardened","Seasoned"}) do
 check(themed[tier].HealthBarSize[1]==original[tier].HealthBarSize[1],"original width")
 check(themed[tier].HealthBarTexture:find("Hunter",1,true),"opening-matched themed fill")
 check(themed[tier].HealthBackdropTexture:find("Hunter",1,true),"hunter casing")
 check(themed[tier].HealthThreatTexture:find("Hunter",1,true),"new neutral Hunter threat silhouette")
end
check(themed.PowerBarColors.FOCUS[2]==.62,"amber focus")
check(themed.PowerBarColors.MANA[2]==original.PowerBarColors.MANA[2],"mana preserved")
check(themed.HealthValueFont==original.HealthValueFont,"font identity")
check(ns.GetConfig("PlayerCastBar").CastBarSize[1]==112,"original cast meter")
check(ns.GetConfig("PlayerCastBar").CastBarBackgroundSize[1]==193,"original cast casing width")
for _,name in ipairs({"FocusFrame","ToTFrame","PetFrame","PartyFrames","Raid5Frames","RaidFrames","ArenaFrames"}) do
 check(ns.GetConfig(name).HealthBackdropTexture:find("Hunter",1,true),name.." coverage")
end
for _,name in ipairs({"ActionButton","PetActionButton","StanceButton"}) do
 local d=ns.GetConfig(name)
 check(d.ButtonBorderTexture:find("Hunter",1,true),name.." border")
 check(not d.ButtonMaskTexture:find("Hunter",1,true),name.." mask retained")
end
combat=true;theme:Command("off")
check(theme:IsActive() and reloads==1,"combat refuses mutation")
combat=false
ns.db.global.enableDevelopmentMode=true;ns.db.char.paladinPreview=true
check(not ns.PaladinTheme:IsActive(),"themes never stack")
theme:Command("off")
check(ns.PaladinTheme:IsActive(),"off restores Paladin preference")
theme:Command("on");ns.PaladinTheme:Command("on")
check(not ns.db.char.hunterPreview and ns.PaladinTheme:IsActive(),"explicit Paladin wins")
ns.db.char.paladinPreview=false;theme:Command("on")
ns.PaladinTheme:Command("off");check(theme:IsActive(),"Paladin off preserves Hunter")
ns.variant="SaiyaRatt"
check(not theme:IsActive(),"SaiyaRatt excluded")
local r=reloads;theme:Command("on");check(reloads==r,"cannot enable on other theme")
ns.variant=nil
theme:Command("endcap invalid");check(reloads==r,"invalid choice no reload")
for _,key in ipairs({"thasdorah","talonclaw","titanstrike","thoridal","raeshalare","none"}) do
 theme:Command("endcap "..key);check(ns.db.char.hunterEndcap==key,"endcap selection "..key)
end
local widgetCount = 0
local function widget(parent)
	widgetCount = widgetCount + 1
	local w = { parent = parent, points = {}, children = {}, shown = true, level = 2, width = 385, height = 40 }
	if parent then parent.children[#parent.children+1] = w end
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
	function w:GetTexture() return self.texture end
	function w:SetTexCoord(...) self.coords = { ... } end
	function w:SetVertexColor(...) self.color = { ... } end
	function w:SetColorTexture(...) self.color = { ... } end
	function w:SetAlpha(value) self.alpha = value end
	function w:SetBlendMode(value) self.blendMode = value end
	function w:SetShown(value) self.shown = value end
 function w:Show() self.shown=true end
 function w:Hide() self.shown=false end
	function w:SetClipsChildren(value) self.clips = value end
	function w:AddMaskTexture(mask) self.mask = mask end
	function w:CreateTexture() return widget(self) end
	function w:CreateMaskTexture() return widget(self) end
	function w:GetStatusBarTexture() self.fill = self.fill or widget(self); return self.fill end
	function w:SetStatusBarTexture(...) self.fillPaths = { ... } end
	function w:GetOverlay() self.clip = self.clip or widget(self); return self.clip end
	function w:GetValue() error("theme read resource value") end
	function w:GetMinMaxValues() error("theme read resource range") end
	function w:CreateAnimationGroup()
		local group = {}
		function group:CreateAnimation()
			return { SetFromAlpha = function() end, SetToAlpha = function() end,
				SetDuration = function() end, SetOrder = function() end }
		end
		function group:SetLooping() end
		function group:Play() end
		return group
	end
	return w
end
env.CreateFrame = function(_, _, parent) return widget(parent) end

env.hooksecurefunc=function(object,key,callback)
 local before=object[key]
 object[key]=function(...) before(...);callback(...) end
end
local owner=widget();owner.Health=widget(owner);owner.Health.Backdrop=widget(owner)
ns.db.char.hunterEndcap="thasdorah"
theme:StyleHealth(owner,original.Seasoned,false)
check(owner.Health.HunterOrnaments.Tip.texture:find("endcap-thasdorah",1,true),"endcap art")
local count=widgetCount
theme:StyleHealth(owner,original.Seasoned,true)
check(widgetCount==count,"reuse ornaments")
check(owner.Health.HunterOrnaments.Tip.coords[1]==1,"mirrored target")
owner.Health:SetSize(40,36);theme:StyleHealth(owner,{},true)
check(not owner.Health.HunterOrnaments.shown,"critter no crushed endcap")
check(owner.Health.HunterCasing.Art.texture:find("hp_critter_case",1,true),"critter has fitted hex casing")
owner.Health:SetSize(533,40);theme:StyleHealth(owner,{},true)
check(owner.Health.HunterOrnaments.shown,"restore after critter")
local cast=widget(owner);cast.Shield=widget(cast);cast:SetSize(252,24.75)
theme:StyleCastbar(cast)
check(cast.Shield.alpha==0 and cast.HunterOrnaments.Eagle,"eagle casing without shield artifact")
owner.Castbar=cast;cast.Backdrop=widget(cast);cast.shown=false
theme:StyleNameplate(owner)
check(not cast.shown,"idle plate remains hidden")
owner.ThreatIndicator={textures={Health=widget(owner)},isShown=false}
theme:StyleThreat(owner,true)
local native=owner.ThreatIndicator.textures.Health
check(native.texture:find("Hunter",1,true),"whole casing has new threat art")
check(native.width==owner.Health.HunterCasing.Art.width and native.points.TOPLEFT[3]==owner.Health.HunterCasing.Art.points.TOPLEFT[3],"threat and casing share exact geometry")
local orb=widget();check(theme:StyleOrb(orb) and orb.fillPaths[1]:find("orb-focus",1,true),"faceted orb uses native clipping")
local halo=owner.Health.HunterOrnaments.Threat
native:Show();check(halo.shown,"threat halo follows show")
native:SetVertexColor(.7,.2,.1);check(halo.color[1]==.7 and halo.color[3]==.1,"native threat color forwarded")
native:Hide();check(not halo.shown,"threat halo follows hide")
local count=widgetCount;theme:StyleThreat(owner,true);check(widgetCount==count,"no duplicate threat texture")
ns.db.char.hunterEndcap="none";theme:StyleThreat(owner,true);check(halo.alpha==0,"no halo for disabled ornament")
owner.Overlay=widget(owner);theme:StylePet(owner)
check(owner.Portrait and owner.Portrait.mask,"pet portrait registered with oUF and masked")
count=widgetCount;theme:StylePet(owner);check(widgetCount==count,"pet styling idempotent")
local resource=widget(owner); resource:SetSize(196,196); resource.Case=widget(resource)
owner.Power=resource
owner.ThreatIndicator.textures.PowerBar=widget(owner)
owner.ThreatIndicator.textures.PowerBackdrop=widget(owner)
theme:StyleCrystal(resource); theme:StyleThreat(owner,false)
check(resource.coords[1]==0 and resource.coords[2]==1,"crystal uses same full canvas as backing")
check(resource.Case.points.BOTTOM[3]==0,"cradle centered on crystal")
check(owner.ThreatIndicator.textures.PowerBar.texture:find("crystal-group-glow",1,true),"combined crystal and cradle glow")
check(owner.ThreatIndicator.textures.PowerBackdrop.alpha==0,"no duplicate overlapping cradle glow")
owner.ManaOrb=widget(owner);owner.ManaOrb.Case=widget(owner.ManaOrb);owner.ManaOrb.Case:SetSize(188,188)
owner.ThreatIndicator.textures.ManaOrb=widget(owner)
theme:StyleThreat(owner,false)
check(owner.ThreatIndicator.textures.ManaOrb.width==235,"orb halo padding matches casing")
check(theme:GetNameplateCastOffset(7)==-1 and theme:GetNameplateCastOffset(-8)==-8,"Hunter plates cannot overlap and retain outward offsets")
ns.db.char.hunterPreview=false;check(theme:GetNameplateCastOffset(7)==7,"other themes keep nameplate offset");ns.db.char.hunterPreview=true
check(ns.GetConfig("NamePlates").HealthBarTexCoord[1]==0,"plate fill and border use same full canvas")
-- Native proportions survive theme activation, including the taller group bars.
for _,name in ipairs({"FocusFrame","ToTFrame","PartyFrames","Raid5Frames","RaidFrames","ArenaFrames","MirrorTimers"}) do
 ns.db.char.hunterPreview=false;local base=ns.GetConfig(name)
 ns.db.char.hunterPreview=true;local themed=ns.GetConfig(name)
 local prefix=name=="MirrorTimers" and "MirrorTimer" or "Health"
 for _,suffix in ipairs({"BarSize","BackdropSize","BackdropPosition"}) do
  local a,b=base[prefix..suffix],themed[prefix..suffix]
  for k,v in ipairs(a) do check(b[k]==v,name.." original "..suffix.." component "..k) end
 end
end
check(ns.GetConfig("PartyFrames").PowerBarPosition[3]==8,"party power remains in native position")
check(ns.GetConfig("PartyFrames").PortraitBackgroundTexture:find("Hunter",1,true),"Hunter portrait backing")
local player=ns.GetConfig("PlayerFrame").Seasoned
check(player.PowerBarPosition[2]+player.PowerBackdropSize[1]/2==80,"crystal viewport retains original center X")
check(player.PowerBarPosition[3]+player.PowerBackdropSize[2]/2==108,"crystal viewport retains original center Y")
print("Hunter theme: "..checks.." checks passed (offline only)")
-- Optional source-driven layout export for the offline assembly renderer.
if (arg[2]) then
	local function quote(s) return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
	local function json(v)
		local kind = type(v)
		if (kind == "string") then return quote(v) end
		if (kind == "number" or kind == "boolean") then return tostring(v) end
		if (kind ~= "table" or v.GetObjectType) then return "null" end
		local out = {}
		if (#v > 0) then for i=1,#v do out[#out+1] = json(v[i]) end; return "["..table.concat(out,",").."]" end
		for k,x in pairs(v) do if type(k)=="string" and type(x)~="function" then out[#out+1]=quote(k)..":"..json(x) end end
		return "{"..table.concat(out,",").."}"
	end
	ns.variant = nil
	local result = {}
	for _, enabled in ipairs({ false,true }) do
		ns.db.char.paladinPreview = false
		ns.db.char.hunterPreview = enabled
		local layouts = {}
		for _,name in ipairs({ "PlayerFrame","PlayerFrameAlternate","TargetFrame","BossFrames","PlayerCastBar","PlayerClassPower","ActionButton","NamePlates","FocusFrame","ToTFrame","PetFrame","PartyFrames","Raid5Frames","RaidFrames","ArenaFrames","MirrorTimers","StatusBars","VehicleExitButton" }) do layouts[name]=ns.GetConfig(name) end
		result[enabled and "hunter" or "original"] = layouts
	end
	local file=assert(io.open(arg[2],"w"));file:write(json(result));file:close()
end

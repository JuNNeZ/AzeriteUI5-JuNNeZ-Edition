-- Real Druid module + real theme dispatch; native widgets are recording stubs.
-- lua Tools/Harness/druid_theme_harness.lua . [mutations]
local root = arg[1] or "."
local checks = 0
local function check(value, label) checks=checks+1; assert(value,label) end
local function noop() end
local function widget(parent)
	local w={parent=parent,level=1,shown=true,points={},scripts={}}
	function w:GetParent() return self.parent end
	function w:SetParent(v) self.parent=v end
	function w:GetFrameLevel() return self.level end
	function w:SetFrameLevel(v) self.level=v end
	function w:SetAllPoints(v) self.anchor=v end
	function w:SetPoint(...) self.points[#self.points+1]={...} end
	function w:ClearAllPoints() self.points={} end
	function w:SetSize(x,y) assert(not self.fixedGeometry,"native resource resized"); self.width,self.height=x,y end
	function w:GetWidth() return self.width or 385 end
	function w:GetHeight() return self.height or 40 end
	function w:EnableMouse(v) self.mouse=v end
	function w:SetClipsChildren(v) self.clips=v end
	function w:SetTexture(v) self.texture=v end
	function w:GetTexture() return self.texture end
	function w:SetTexCoord(...) self.coords={...} end
	function w:SetAlpha(v) self.alpha=v end
	function w:GetAlpha() return self.alpha or 1 end
	function w:SetBlendMode(v) self.blend=v end
	function w:SetVertexColor(...) self.color={...} end
	function w:GetVertexColor() return unpack(self.color or {1,1,1}) end
	function w:AddMaskTexture(v) self.mask=v end
	function w:CreateTexture() return widget(self) end
	function w:CreateMaskTexture() return widget(self) end
	function w:SetScript(k,v) self.scripts[k]=v end
	function w:Show() self.shown=true end
	function w:Hide() self.shown=false end
	function w:SetShown(v) self.shown=v end
	function w:IsShown() return self.shown end
	function w:GetValue() error("secret resource value must not be read") end
	function w:GetMinMaxValues() error("secret resource range must not be read") end
	return w
end
CreateFrame=function(_,_,parent) return widget(parent) end
hooksecurefunc=function(object,key,fn)
	local old=object[key]
	object[key]=function(...) local result=old(...); fn(...); return result end
end
local combat,reloads=false,0
InCombatLockdown=function() return combat end
C_UI={Reload=function() reloads=reloads+1 end}
local ns={db={char={},RegisterCallback=noop}}
function ns:NewModule() return {} end
function ns:GetModule() end
for _,key in ipairs({"Hunter","Mage","Paladin"}) do
	ns[key.."Theme"]={IsActive=function() return false end,StyleCrystal=noop,RefreshOrnaments=noop,
		ApplyCrystalEffect=noop,ClearCrystalEffect=noop,ApplyOrbEffect=noop,ClearOrbEffect=noop}
end
assert(loadfile(root.."/Core/ThemeEngine.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
assert(loadfile(root.."/Core/DruidTheme.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
assert(loadfile(root.."/Core/ThemeEffects.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
local T,E=ns.DruidTheme,ns.ThemeEffects
check(E:SetTheme("druid") and reloads==1,"Druid theme selectable through real dispatcher")
T.loadedActive=true
check(E:GetTheme()=="druid" and E:GetCrystalEffect()=="druid" and E:GetOrbEffect()=="druid","theme defaults to both Druid effects")
check(ns.ThemeEngine:GetBagIcon():find("ThemeBagIcons\\druid.tga",1,true),"Druid bag identity routed")
local original={Size={196,196},Position={"CENTER",7,-51},Texture="x\\Assets\\orb_case_hi.tga",Color={.2,.2,.2,.7}}
local config=T:GetConfig("test",original)
check(config.Texture:find("Druid\\orb_case_hi",1,true) and config.Color[1]==1 and config.Color[4]==.7,"new material resets tint, preserves alpha")
check(config.Size[1]==196 and config.Position[2]==7 and original.Color[1]==.2,"saved/native geometry and original layout unchanged")
local owner=widget(); owner.Health=widget(owner)
local power=widget(owner); power.fixedGeometry=true; power.Case=widget(power)
owner.Power=power
local nativeFill=widget(power)
function power:GetStatusBarTexture() return nativeFill end
local orb=widget(owner); orb.fixedGeometry=true; orb.Case=widget(orb)
local nativeClip=widget(orb)
function orb:GetOverlay() return nativeClip end
function orb:SetStatusBarTexture(...) self.materials={...} end
E:StyleCrystal(power,"native-crystal",nil,"case")
check(power.DruidDreamlight.Clip.clips,"crystal uses native clipping frame")
check(power.DruidDreamlight.Clip.points[3][2]==nativeFill,"crystal clip top follows native fill texture")
check(power.DruidDreamlight.Mask.texture=="native-crystal","crystal current native silhouette mask")
check(power.DruidRootBack.anchor==power and power.DruidRootFront.Art.anchor==power and power.Case.alpha==0,"root layers bracket unchanged resource rectangle")
check(E:StyleOrb(orb),"Druid orb claims fill")
check(orb.materials[1]:find("orb-moonwell.tga",1,true) and orb.materials[2]==orb.materials[1],"actual fill uses Moonwell water in both LibOrb layers")
check(orb.DruidMoonwell.parent==nativeClip,"orb overlays inside native fill clip")
check(orb.DruidMoonwell.Wisps[1].mask==orb.DruidMoonwell.Mask,"orb motion respects circular silhouette")
local flow=power.DruidDreamlight
flow.scripts.OnUpdate(flow,4)
local time=flow.Time
E:StyleCrystal(power,"native-ice",nil,"case")
check(flow.Time==time and flow.Mask.texture=="native-ice","restyle preserves phase and refreshes ice mask")
E:SetLitePlus(true); E:SetCrystalChoice("none"); E:SetOrbChoice("hunter")
E:StyleCrystal(power,"native-crystal",nil,"case"); E:StyleOrb(orb)
check(not flow.shown and flow.scripts.OnUpdate==nil,"cleared crystal stops animation callback")
check(not orb.DruidMoonwell.shown and orb.DruidMoonwell.scripts.OnUpdate==nil,"cleared orb stops animation callback")
check(power.DruidRootFront.shown,"Lite+ changes effect without borrowing root casing")
E:SetCrystalChoice("druid"); E:SetOrbChoice("druid")
E:StyleCrystal(power,"native-crystal",nil,"case"); E:StyleOrb(orb)
check(flow.Time==time and flow.shown,"reselected effect reuses frames and phase")
E:SetOrbChoice("paladin"); E:StyleOrb(orb)
check(not orb.DruidMoonwell.shown and orb.DruidMoonwell.scripts.OnUpdate==nil,"Paladin early return clears old Moonwell")
E:SetOrbChoice("druid"); E:StyleOrb(orb)
check(T:SetEffectStrength("Orb",0),"zero orb strength accepted")
check(not E:StyleOrb(orb) and not orb.DruidMoonwell.shown,"zero strength returns orb fill ownership to Player.lua")
T:SetEffectStrength("Orb",.4); E:StyleOrb(orb)
check(orb.DruidMoonwell.alpha==.4,"orb reflection strength applies")
combat=true
check(not T:SetEffectStrength("Orb",.8) and T:GetEffectStrength("Orb")==.4,"combat refuses settings write")
combat=false
local hp=owner.Health; hp.Backdrop=widget(hp)
local db={HealthBackdropTexture="x\\Druid\\hp_cap_case.tga",HealthBarTexture="hp_cap_bar"}
T:StyleHealth(owner,db,false)
check(hp.DruidEndcap and hp.DruidEndcap.Art.points[1][3]=="RIGHT","player endcap in shared outer slot")
T:StyleHealth(owner,db,true)
check(hp.DruidEndcap.Art.points[1][3]=="LEFT" and hp.DruidEndcap.Art.coords[1]==1,"target endcap mirrored away from portrait")
owner.ThreatIndicator={textures={Health=widget(hp),PowerBar=widget(power),PowerBackdrop=widget(power)}}
owner.ThreatIndicator.textures.Health:SetVertexColor(.7,.2,.1)
T:StyleThreat(owner,true)
check(hp.DruidEndcap.Threat.color[1]==.7,"endcap threat colour forwarded")
check(owner.ThreatIndicator.textures.PowerBar.anchor==power and owner.ThreatIndicator.textures.PowerBackdrop.alpha==0,"threat follows whole root assembly without old short holder")
db.HealthBarTexture="cast_bar"; T:StyleHealth(owner,db,false)
check(not hp.DruidEndcap.shown,"compact transition hides old endcap")
check(not hp.DruidEndcap.Threat.shown,"compact transition hides old endcap threat")
E:SetTheme("azerite"); T.loadedActive=false
E:StyleCrystal(power,"native-crystal",nil,"case")
check(not power.DruidRootFront.shown and power.Case.alpha==1,"leaving Druid restores normal casing")
E:SetLitePlus(true); E:SetCrystalChoice("druid"); E:SetOrbChoice("druid")
E:StyleCrystal(power,"native-crystal",nil,"case"); E:StyleOrb(orb)
check(flow.shown and orb.DruidMoonwell.shown and not power.DruidRootFront.shown,"Druid Lite+ on AzeriteUI without importing its roots")

if arg[2]=="mutations" then
	local file=assert(io.open(root.."/Core/DruidTheme.lua")); local source=file:read("*a"); file:close()
	local realLoad=loadfile
	local mutants={
		{"wrong fill",'path("orb-moonwell"), path("orb-moonwell")','path("orb2"), path("orb2")',"actual fill uses Moonwell"},
		{"wrong clip",'clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")','clip:SetPoint("TOP", power, "TOP")',"crystal clip top follows"},
		{"keeps ticking",'frame:SetScript("OnUpdate", nil)','-- removed stop',"cleared crystal stops"}
	}
	for _,m in ipairs(mutants) do
		local at=assert(source:find(m[2],1,true),m[1].." target missing")
		local changed=source:sub(1,at-1)..m[3]..source:sub(at+#m[2])
		loadfile=function(path) if path==root.."/Core/DruidTheme.lua" then return loadstring(changed) end; return realLoad(path) end
		arg[2]=nil
		local ok,err=pcall(assert(realLoad(root.."/Tools/Harness/druid_theme_harness.lua")))
		loadfile=realLoad
		check(not ok and tostring(err):find(m[4],1,true),"mutant rejected for intended reason: "..m[1])
	end
end
print("Druid theme/effects: "..checks.." checks passed (offline only)")

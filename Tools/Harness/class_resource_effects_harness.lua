-- Actual Lite+ material module and dispatcher on recording widgets.
-- lua Tools/Harness/class_resource_effects_harness.lua . [samples directory]
local root=arg[1] or "."
local count=0
local function check(value,label) count=count+1;assert(value,label) end
local secret={}
issecretvalue=function(value) return rawequal(value,secret) end
local combat,moving,mounted,flying=false,false,false,false
InCombatLockdown=function() return combat end
IsPlayerMoving=function() return moving end
IsMounted=function() return mounted end
IsFlying=function() return flying end
local function widget(parent)
	local w={parent=parent,points={},scripts={},events={},shown=true,level=1}
	function w:GetFrameLevel() return self.level end
	function w:SetFrameLevel(v) self.level=v end
	function w:EnableMouse(v) self.mouse=v end
	function w:SetAllPoints(v) self.anchor=v end
	function w:SetPoint(p,...) assert(not self.native,"native resource moved");self.points[p]={...} end
	function w:ClearAllPoints() self.points={} end
	function w:SetSize(a,b) assert(not self.native,"native resource resized");self.width,self.height=a,b end
	function w:SetHeight(v) self.height=v end
	function w:GetHeight() assert(self.native,"clip geometry read");return self.height end
	function w:GetWidth() assert(self.native,"clip geometry read");return self.width end
	function w:SetClipsChildren(v) self.clips=v end
	function w:SetTexture(v) self.path=v end
	function w:GetTexture() return self.path end
	function w:SetTexCoord(...) self.coords={...} end
	function w:SetVertexColor(...) self.color={...} end
	function w:GetVertexColor() return unpack(self.color or {1,1,1,1}) end
	function w:SetBlendMode(v) self.blend=v end
	function w:SetAlpha(v) self.alpha=v end
	function w:AddMaskTexture(v) self.mask=v end
	function w:CreateTexture() return widget(self) end
	function w:CreateMaskTexture() return widget(self) end
	function w:SetScript(k,v) self.scripts[k]=v end
	function w:RegisterEvent(e) self.events[e]=true end
	function w:UnregisterAllEvents() self.events={} end
	function w:IsVisible() return self.shown end
	function w:Show() self.shown=true end
	function w:Hide() self.shown=false end
	function w:GetValue() error("resource value read") end
	function w:GetMinMaxValues() error("resource range read") end
	function w:GetTop() error("resource position read") end
	return w
end
CreateFrame=function(_,_,parent) return widget(parent) end
hooksecurefunc=function(object,key,fn)
	local old=object[key];object[key]=function(...) local result=old(...);fn(...);return result end
end
local ns={db={char={themeLitePlus=true}}}
function ns:GetModule() end
for _,path in ipairs({"ClassResourceEffects","ThemeEffects","MoonwellSlosh"}) do
	assert(loadfile(root.."/Core/"..path..".lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
end
local M,E=ns.ClassResourceEffects,ns.ThemeEffects
local crystal=widget();crystal.native=true;crystal.width,crystal.height=196,196
local nativeFill=widget(crystal)
function crystal:GetStatusBarTexture() return nativeFill end
local orb=widget();orb.native=true;orb.width,orb.height,orb.displayType=103,103,0
local nativeClip=widget(orb)
function orb:GetOverlay() return nativeClip end
function orb:GetStatusBarTexture() error("orb is not a crystal") end
function orb:SetStatusBarTexture(...) self.materials={...} end
function orb:GetStatusBarColor() return .2,.4,.8 end
function orb:SetStatusBarColor(...) self.color={...} end
local previousC,previousO
check(#M:GetKeys()==27,"all nine class families supply three material choices")
for _,key in ipairs(M:GetKeys()) do
	local data=M:GetInfo(key)
	local atlas=assert(io.open(root.."/Assets/LitePlus/"..data.family:lower().."-materials.tga","rb"),"missing installed atlas for "..key)
	atlas:close()
	check(E:SetCrystalChoice(key) and E:SetOrbChoice(key),"both Lite+ lists accept "..key)
	E:StyleCrystal(crystal,"native-crystal");check(E:StyleOrb(orb,true),"material claims orb "..key)
	local c,o=crystal.ClassResourceEffect,orb.ClassResourceEffect
	check(not previousC or c==previousC,"crystal frame tree reused across materials")
	check(not previousO or o==previousO,"orb frame tree reused across materials")
	previousC,previousO=c,o
	check(c.Clip.clips and c.Clip.points.TOP[1]==nativeFill and c.parent==c.Clip,"crystal clip follows real native fill")
	check(o.parent==nativeClip and not o.Clip,"orb light stays inside native LibOrb clip")
	check(c.Mask.path=="native-crystal" and o.Mask.path:find('orb2.tga',1,true),"current crystal and native circular masks retained")
	check(o.level<orb.MoonwellSlosh.level and orb.MoonwellSlosh.Enabled,"all material layers remain below actual Flowing mana")
	check(#c.Layers==2 and #c.Motes==6 and #o.Motes==6,"bounded frame and texture count")
	check(c.Body.mask==c.Mask and o.Body.mask==o.Mask,"material body uses native mask")
	check(c.Layers[1].path:find(data.family:lower()..'-materials.tga',1,true),"material uses generated class field")
	for _,owner in ipairs({c,o}) do
		for _,art in ipairs(owner.Layers) do check(art.mask==owner.Mask,"fields keep current silhouette") end
		for _,art in ipairs(owner.Motes) do check(art.mask==owner.Mask,"particles keep current silhouette") end
	end
	local coords=c.Layers[1].coords[1]
	for i=1,180 do
		c.scripts.OnUpdate(c,1/30);o.scripts.OnUpdate(o,1/30)
		for _,art in ipairs(c.Layers) do
			for n,v in ipairs(art.coords) do
				local origin=n%2==1 and (data.cell%2)*.5 or math.floor(data.cell/2)*.5
				check(v>origin+.001 and v<origin+.499,"moving UV stays inside its own source cell")
			end
		end
	end
	check(c.Time>0 and c.Layers[1].coords[1]~=coords,"material moves through texture space")
	-- Six seconds at a slow material's runtime speed does not cover its cycle.
	-- Sweep the full shared 48-second phase domain, including the wrap.
	for step=0,144 do
		c.Time=step/3;c.Pending=0;c.scripts.OnUpdate(c,1/30)
		for _,art in ipairs(c.Layers) do
			for n,v in ipairs(art.coords) do
				local origin=n%2==1 and (data.cell%2)*.5 or math.floor(data.cell/2)*.5
				check(v==v and v>origin+.001 and v<origin+.499,"full-cycle UV remains in its material cell: "..key)
			end
		end
	end
	local phase=c.Time
	E:StyleCrystal(crystal,"ice-crystal");check(c.Time==phase and c.Mask.path=="ice-crystal","restyle preserves phase and updates ice silhouette")
	M:SetStrength(key,"Crystal",.35);E:StyleCrystal(crystal,"native-crystal")
	check(c.alpha==.35 and M:GetStrength(key,"Orb")==1,"crystal strength independent of orb")
	M:SetStrength(key,"Orb",0)
	check(not E:StyleOrb(orb) and not o.Enabled and not o.scripts.OnUpdate and not next(o.events),"zero strength returns orb material ownership and stops work")
	check(c.Enabled,"zero orb strength leaves crystal running")
	o.scripts.OnShow(o);check(not o.scripts.OnUpdate,"cleared zero-strength effect cannot restart")
	M:SetStrength(key,"Orb",1);M:SetStrength(key,"Crystal",1);E:StyleOrb(orb,false)
	check(not orb.MoonwellSlosh.Enabled and o.Enabled,"flow off retains selected material")
	o.scripts.OnHide(o);check(not o.scripts.OnUpdate and not next(o.events),"hidden material releases callback and events")
	o.scripts.OnShow(o);check(o.scripts.OnUpdate and o.events.PLAYER_REGEN_DISABLED,"show resumes selected material")
	mounted=true;o.scripts.OnEvent(o,"PLAYER_MOUNT_DISPLAY_CHANGED");check(o.TargetActivity==1,"mounted raises activity")
	mounted=false;o.scripts.OnEvent(o,"PLAYER_MOUNT_DISPLAY_CHANGED");check(o.TargetActivity==.22,"readable false state clears mounted activity")
	mounted,moving,flying=secret,secret,secret;o.scripts.OnUpdate(o,.3)
	check(o.TargetActivity==.22,"secret state uses readable fallback")
	mounted,moving,flying=false,false,false
	combat=true;o.scripts.OnEvent(o,"PLAYER_REGEN_DISABLED")
	check(not M:SetStrength(key,"Orb",.2),"combat refuses settings writes")
	phase=o.Time;o.scripts.OnUpdate(o,.2);check(o.Time~=phase,"created cosmetic animation continues in combat")
	combat=false;o.scripts.OnEvent(o,"PLAYER_REGEN_ENABLED")
	E:SetCrystalChoice("none");E:SetOrbChoice("none");E:StyleCrystal(crystal,"native-crystal");E:StyleOrb(orb)
	check(not c.Enabled and not o.Enabled and not c.scripts.OnUpdate and not o.scripts.OnUpdate,"switching family clears both old effects")
end
check(not M:SetStrength("bogus","Orb",.5) and not M:SetStrength("forge","bad",.5),"unknown settings rejected")
check(not M:SetStrength("forge","Orb",0/0),"NaN rejected")
local factory
local oldGetModule=ns.GetModule
ns.GetModule=function(_,name) if name=="Options" then return {AddGroup=function(_,_,build) factory=build end} end end
LibStub=function() return {GetLocale=function() return setmetatable({},{__index=function(_,key) return key end}) end} end
assert(loadfile(root.."/Options/OptionsPages/Themes.lua"))("Test",ns)
local args=factory().args
local crystalLabels=args.effects.args.crystal.values()
local orbLabels=args.effects.args.orb.values()
for _,key in ipairs(M:GetKeys()) do
	check(crystalLabels[key] and orbLabels[key] and crystalLabels[key]:find("WIP",1,true),"both real dropdowns label the material as WIP: "..key)
	E:SetCrystalChoice("none");E:SetOrbChoice(key)
	local group=args[key]
	check(not group.hidden() and group.args.Crystal.hidden() and not group.args.Orb.hidden(),"orb-only controls visible "..key)
	group.args.Orb.set(nil,.6);check(group.args.Orb.get()==.6 and M:GetStrength(key,"Crystal")==1,"actual sliders retain independent keys")
	E:SetCrystalChoice(key);group.args.Crystal.set(nil,.4)
	check(group.args.Crystal.get()==.4 and group.args.Orb.get()==.6,"crystal slider cannot overwrite orb setting")
	M:SetStrength(key,"Crystal",1);E:SetCrystalChoice("none")
	M:SetStrength(key,"Orb",1);E:SetOrbChoice("none");check(group.hidden(),"unused controls hidden")
end
ns.GetModule=oldGetModule
E:SetCrystalChoice("forge");E:SetOrbChoice("storm")
E:StyleCrystal(crystal,"native-crystal");E:StyleOrb(orb)
ns.GetActiveConfigVariant=function() return "SaiyaRatt" end
E:StyleCrystal(crystal,"native-crystal");E:StyleOrb(orb)
check(not crystal.ClassResourceEffect.Enabled and not orb.ClassResourceEffect.Enabled,"alternate layout clears both effects")
ns.GetActiveConfigVariant=nil
E:SetLitePlus(false);E:StyleCrystal(crystal,"native-crystal");E:StyleOrb(orb)
check(not crystal.ClassResourceEffect.Enabled and not orb.ClassResourceEffect.Enabled,"Lite+ off restores existing theme defaults")
E:SetLitePlus(true)
print("Class resource effects: "..count.." checks passed (offline only)")
if arg[2]=="samples" then
	local export=assert(loadfile(root.."/Tools/Harness/liteplus_preview_export.lua"))()
	local groups={}
	for _,key in ipairs(M:GetKeys()) do
		local family=M:GetInfo(key).family
		groups[family]=groups[family] or {}
		groups[family][#groups[family]+1]=key
	end
	for family,keys in pairs(groups) do
		local samples={fps=10,seconds=8,theme=family,variants={}}
		for _,key in ipairs(keys) do
			E:SetCrystalChoice(key);E:SetOrbChoice(key);E:StyleCrystal(crystal,"Interface\\AddOns\\Test\\Assets\\power_crystal_front.tga");E:StyleOrb(orb)
			local c,o=crystal.ClassResourceEffect,orb.ClassResourceEffect
			c.Time,o.Time,c.Pending,o.Pending,c.Activity,o.Activity=0,0,0,0,.22,.22
			local cs,os={},{}
			for i=1,80 do
				c.scripts.OnUpdate(c,.1);o.scripts.OnUpdate(o,.1)
				cs[i]=export.Frame(c,196,196);os[i]=export.Frame(o,103,103)
			end
			local label=M:GetInfo(key).label
			label=label and label:match(" %- (.+)$") or key
			samples.variants[#samples.variants+1]={name=key,label=label,crystal=cs,orb=os}
		end
		export.Write(assert(arg[3]).."/"..family:lower()..".json",samples)
	end
end

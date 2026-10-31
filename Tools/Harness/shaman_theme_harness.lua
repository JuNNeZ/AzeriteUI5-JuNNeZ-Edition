-- Real Shaman module, engine, theme selector and Legacy command; recording widgets.
-- Tools/Run-Elune.ps1 Tools/Harness/shaman_theme_harness.lua .
local root = arg[1] or "."
local checks = 0
local function check(value, label) checks=checks+1; assert(value,label) end
local function noop() end
local function widget(parent)
	local w={parent=parent,level=1,shown=true,points={},scripts={}}
	function w:GetParent() return self.parent end
	function w:SetParent(v) self.parent=v end
	function w:GetFrameLevel() return self.level end
	function w:SetFrameLevel(v)
		local delta = v-self.level
		self.level=v
		-- Model the two cap children affected by native parent-level changes.
		for _, key in ipairs({"ThemeCapFrame", "MageCrystalCaseFrame"}) do
			local child = self[key]
			if (child and (self.forceCapPropagation or not child.fixedFrameLevel)) then child:SetFrameLevel(child.level+delta) end
		end
	end
	function w:SetFixedFrameLevel(v) self.fixedFrameLevel=v end
	function w:SetAllPoints(v) self.anchor=v end
	function w:SetPoint(...) self.points[#self.points+1]={...} end
	function w:ClearAllPoints() self.points={} end
	function w:GetPoint() return unpack(self.points[1] or {}) end
	function w:SetSize(x,y) assert(not self.fixedGeometry,"native resource resized"); self.width,self.height=x,y end
	function w:SetHeight(v) assert(not self.fixedGeometry,"native resource resized");self.height=v end
	function w:GetWidth() return self.width or 385 end
	function w:GetHeight() return self.height or 40 end
	function w:EnableMouse(v) self.mouse=v end
	function w:SetClipsChildren(v) self.clips=v end
	function w:SetTexture(v)
		if type(v)=="string" and v:find("\\Shaman\\",1,true) then
			local relative=v:match("[\\/]Assets[\\/](.*)$"):gsub("\\","/")
			local f=assert(io.open(root.."/Assets/"..relative,"rb"),"missing runtime art "..v);f:close()
		end
		self.texture=v
	end
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
	function w:IsVisible() return self.shown end
	function w:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
	function w:UnregisterEvent(event) if self.events then self.events[event]=nil end end
	function w:UnregisterAllEvents() self.events={} end
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
local variant
local callbacks=0
local ns={db={char={},RegisterCallback=function() callbacks=callbacks+1 end},API={},oUF={RegisterInitCallback=noop}}
function ns:NewModule()
	return { Print=function(self,v) self.message=v end,
		RegisterChatCommand=function(self,key,method) self.command,self.commandMethod=key,method end,
		RegisterEvent=function(self,key) self.event=key end, UnregisterEvent=function(self) self.event=nil end }
end
function ns:GetActiveConfigVariant() return variant end
function ns:Print(v) self.message=v end
local options={}
function options:AddGroup(key,factory) self.factory=factory end
function ns:GetModule(key) if key=="Options" then return options end end
for _,key in ipairs({"Hunter","Mage","Paladin","Druid","Warrior","Rogue"}) do
	local prefix=key:lower()
	ns[key.."Theme"]={IsActive=function() return ns.db.char[prefix.."Preview"]==true and not variant and not ns.db.char.legacyHUD end,
		StyleCrystal=noop,RefreshOrnaments=noop,ApplyCrystalEffect=noop,ClearCrystalEffect=noop,ApplyOrbEffect=noop,ClearOrbEffect=noop}
end
ns.ThemeBarPreview={Refresh=noop,Show=function(self) if not combat then self.opened=true end end}
assert(loadfile(root.."/Core/ThemeEngine.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
assert(loadfile(root.."/Core/LegacyHUD.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
assert(loadfile(root.."/Core/ShamanTheme.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
assert(loadfile(root.."/Core/ThemeEffects.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
local T,E=ns.ShamanTheme,ns.ThemeEffects
T:OnInitialize()
check(T.command=="azshaman" and T.commandMethod=="Command","real slash command registered")
local function settle()
	T:OnEnable()
	for _,key in ipairs({"Hunter","Mage","Paladin","Druid","Warrior","Rogue"}) do ns[key.."Theme"].loadedActive=ns[key.."Theme"]:IsActive() end
	ns.LegacyHUD.loadedActive=ns.LegacyHUD:IsActive()
end
settle()
check(not T:IsActive() and E:GetTheme()=="azerite","stock stays default before explicit selection")
check(T:Command("") and reloads==1 and ns.db.char.shamanPreview,"bare slash enables Shaman and reloads")
settle()
check(T.loadedActive and callbacks==6,"normal profile lifecycle installed")
check(E:GetTheme()=="shaman" and ns.ThemeEngine:GetActive()==T,"effects and engine agree on active theme")
check(E:GetCrystalEffect()=="none" and E:GetOrbEffect()=="none","Shaman retains native functional fills without invented effects")
local before=reloads
check(T:Command("on") and reloads==before,"already selected theme does not reload")
check(T:Command("status") and T.message:find("on",1,true) and reloads==before,"status only reports")
local original={Size={196,196},Position={"CENTER",7,-51},Texture="x\\Assets\\orb_case_hi.tga",Color={.2,.2,.2,.7},FillTexture="x\\Assets\\orb2.tga",
	ClassPowerCaseColor={.2,.3,.4,.8},ClassPowerColor={1,.9,.2}}
local config=T:GetConfig("test",original)
for name in pairs(T.Media) do
	local path=T:ResolveMedia(name)
	local art=widget();art:SetTexture(path)
	check(path==T:ResolveOwnMedia(name) and art.texture==path,"installed native casing resolves: "..name)
end
check(config.Texture:find("Shaman\\orb_case_hi",1,true) and config.Color[1]==1 and config.Color[4]==.7,"painted casing tint white with alpha retained")
check(config.Size[1]==196 and config.Position[2]==7 and original.Color[1]==.2 and config.FillTexture==original.FillTexture,"native rectangles, original config and functional fill unchanged")
check(config.ClassPowerCaseColor[1]==1 and config.ClassPowerCaseColor[4]==.8 and original.ClassPowerCaseColor[1]==.2,"painted power socket retains alpha without mutating layout")
check(config.ClassPowerColor[2]==.9 and config.ClassPowerColor[3]==.2,"semantic combo point colour unchanged")
for _,shape in ipairs({"", "-square", "-square-rounded"}) do
	local button = { ButtonBorderTexture="x\\Assets\\actionbutton-border"..shape..".tga",
		ButtonBorderColor={.75,.75,.75,.8}, ButtonIconSize={60,60} }
	local quiet = T:GetConfig("ActionButton", button)
	check(quiet.ButtonBorderTexture:find("Shaman\\actionbutton-border",1,true) and
		quiet.ButtonBorderColor[1]==.75 and quiet.ButtonBorderColor[4]==.8,
		"button shape retains native quiet tint and alpha: "..shape)
	check(button.ButtonBorderColor[1]==.75 and quiet.ButtonIconSize[1]==60,
		"button icon geometry and original config unchanged: "..shape)
end
for _,name in ipairs({"nameplate_backdrop","minimap-onebar-backdrop","minimap-twobars-backdrop","options-box","power_crystal_front"}) do
	check(T:ResolveMedia(name)==nil,"deliberate shared media stays native: "..name)
end
local owner=widget();owner.Health=widget(owner)
local hp=owner.Health;hp.width,hp.height=385,40;hp.fixedGeometry=true
hp.Backdrop=widget(hp);hp.Backdrop.width,hp.Backdrop.height=716,188;hp.Backdrop.fixedGeometry=true
local db={HealthBackdropTexture="x\\Shaman\\hp_cap_case.tga",HealthBarTexture="hp_cap_bar"}
ns.ThemeEngine:StyleHealth(owner,db,false)
local frame=hp.ShamanEndcap
check(frame.Art.width==716 and frame.Art.height==188,"default endcap uses accepted full casing canvas at 1:1")
check(frame.Art.points[1][2]==hp.Backdrop and frame.Art.points[1][4]==0 and frame.Art.points[1][5]==0,"default join anchored to actual backdrop without extra nudge")
check(frame.level>hp.ShamanRails.level and hp.ShamanRails.level>hp.level,"foreground cap and rails stay above fill and prediction")
local power=widget(owner);owner.Power=power;power.width,power.height=120,140;power.fixedGeometry=true
power.Case=widget(power);power.Case:SetTexture("x\\Assets\\Shaman\\pw_crystal_case.tga")
power.Backdrop=widget(power);power.Backdrop.width,power.Backdrop.height=196,196;power.Backdrop:SetTexture("power_crystal_back.tga")
owner.ManaOrb=widget(owner);owner.ManaOrb.Case=widget(owner.ManaOrb);owner.ManaOrb.Case:SetTexture("x\\Assets\\Shaman\\orb_case_hi.tga")
owner.ThreatIndicator={textures={Health=widget(hp),PowerBar=widget(power),PowerBackdrop=widget(power),ManaOrb=widget(owner.ManaOrb)}}
local textures=owner.ThreatIndicator.textures;textures.Health:SetVertexColor(.7,.2,.1)
T:StyleThreat(owner,false)
check(frame.Threat.color[1]==.7 and frame.Threat.anchor==frame.Art,"native threat colour and full endcap placement forwarded")
check(textures.PowerBar.width==392 and textures.PowerBar.height==392 and textures.PowerBar.points[1][2]==power.Backdrop,"padded crystal halo uses full backdrop, not cropped 120x140 statusbar")
check(textures.PowerBackdrop.alpha==0 and textures.PowerBar.texture:find("crystal-assembly-glow",1,true),"whole crystal plus cradle replaces both old partial halos")
check(textures.ManaOrb.anchor==owner.ManaOrb.Case and textures.ManaOrb.texture:find("orb_case_hi-glow",1,true),"orb threat follows installed case")
power.Case:SetTexture("x\\Assets\\Shaman\\pw_crystal_case_low.tga");power.Backdrop:SetTexture("power-crystal-ice-back.tga");T:StyleThreat(owner,false)
check(textures.PowerBar.texture:find("crystal-assembly-low-wrath-glow",1,true),"low ice crystal selects matching full silhouette")
power.Case:SetTexture("x\\Assets\\MageCrystalTest\\case.tga");textures.PowerBar:SetTexture("native-restyled-glow");T:StyleThreat(owner,false)
check(textures.PowerBackdrop.alpha==1 and textures.PowerBar.texture=="native-restyled-glow","another Lite+ crystal retains its own threat geometry")
power.Case:SetTexture("x\\Assets\\Shaman\\pw_crystal_case.tga")
E:StyleCrystal(power,"native-fill",nil,"case")
check(power.Case.parent==power.ThemeCapFrame and power.ThemeCapFrame.level==hp.level+4,"Shaman resource case lifted above health casing")
power:SetFrameLevel(power.level-5)
check(power.ThemeCapFrame.level==hp.level+4 and power.ThemeCapFrame.level>hp.ShamanRails.level,
	"crystal casing stays in front when visibility lowers its power parent")
E:StyleOrb(owner.ManaOrb)
owner.ManaOrb:SetFrameLevel(owner.ManaOrb.level-5)
check(owner.ManaOrb.ThemeCapFrame.level==hp.level+4,
	"orb casing also retains its foreground level after parent visibility update")
-- Live 2026-10-29: correct parent, but cap=4 / health=7 / rails=8.
-- Fixed-frame-level alone did not hold in the client. Replay a later native
-- parent-level propagation even with that flag, then require reconciliation.
hp.level=7;hp.ShamanRails.level=8;power.ThemeCapFrame.level=4
owner:SetFrameLevel(owner.level+1)
check(power.ThemeCapFrame.level==11,"live cap=4 health=7 rails=8 reconciles after owner level change")
power.forceCapPropagation=true
power:SetFrameLevel(power.level-3)
check(power.ThemeCapFrame.level==11,"resource level update repairs drift even when fixed flag does not prevent propagation")
hp:SetFrameLevel(9)
check(power.ThemeCapFrame.level==13 and owner.ManaOrb.ThemeCapFrame.level==13,"both cases follow health level without a texture restyle")
combat=true;power:SetFrameLevel(power.level-2)
check(power.ThemeCapFrame.level==11 and power.ThemeCapFrame.events.PLAYER_REGEN_ENABLED,"combat defers the corrective level write")
combat=false;power.ThemeCapFrame.scripts.OnEvent(power.ThemeCapFrame,"PLAYER_REGEN_ENABLED")
check(power.ThemeCapFrame.level==13 and not power.ThemeCapFrame.events.PLAYER_REGEN_ENABLED,"combat-end event reconciles latest health level and unregisters")
power.forceCapPropagation=nil;hp:SetFrameLevel(1)
-- Shaman live report: native propagation bypasses all Lua SetFrameLevel hooks.
hp.level=7;hp.ShamanRails.level=8;power.ThemeCapFrame.level=4
check(type(power.ThemeCapFrame.scripts.OnUpdate)=="function","visible Shaman cap checks native level drift")
power.ThemeCapFrame.scripts.OnUpdate(power.ThemeCapFrame,.1)
check(power.ThemeCapFrame.level==11,"unhooked native cap=4 health=7 rails=8 drift is corrected")
combat=true;power.ThemeCapFrame.level=4
power.ThemeCapFrame.scripts.OnUpdate(power.ThemeCapFrame,.1)
check(power.ThemeCapFrame.level==4,"visible drift check makes no protected level write in combat")
combat=false;power.ThemeCapFrame.scripts.OnUpdate(power.ThemeCapFrame,.1)
check(power.ThemeCapFrame.level==11,"visible drift check repairs after combat even without a setter event")
hp:SetFrameLevel(1)
local cast=widget(owner);cast.Backdrop=widget(cast);cast.Shield=widget(cast)
ns.ThemeEngine:StyleCastbar(cast)
check(cast.ShamanCastHead.Art.width==48 and cast.ShamanCastHead.Art.points[1][4]==-8,"cast uses exact reviewed 48px slot and centre")
cast.Backdrop:Hide()
check(not cast.ShamanRails.shown and cast.ShamanShieldRails.shown,"protected cast shows full shield foreground")
cast.Backdrop:Show()
check(cast.ShamanRails.shown and not cast.ShamanShieldRails.shown,"normal cast restores normal foreground")
check(T:SetEndcap("none") and not frame.shown and cast.ShamanCastHead.shown,"health None does not hide cast endcap")
textures.Health:SetShown(true)
check(not frame.Threat.shown,"native threat cannot resurrect disabled cap glow")
check(hp.Backdrop.texture:find("hp_cap_case.tga",1,true) and hp.ShamanRails.Art.texture:find("hp_cap_case-over.tga",1,true),"None retains complete bare casing")
check(T:SetCastEndcap("none") and not cast.ShamanCastHead.shown,"cast None independent")
check(cast.Backdrop.texture==nil or not cast.Backdrop.texture:find("capped",1,true),"cast None never requests missing cut casing")
check(T:SetEndcap("tides") and not cast.ShamanCastHead.shown and frame.Threat.texture:find("ornament-tides",1,true),"health restore switches both art and halo without cast change")
T:SetCastEndcap("totem")
for _,name in ipairs({"hp_cap_case","hp_mid_case","hp_low_case","hp_boss_case"}) do
	db.HealthBackdropTexture="x\\Assets\\Shaman\\"..name..".tga"
	for _,flip in ipairs({false,true}) do
		T:StyleHealth(owner,db,flip)
		for _,key in ipairs({"maelstrom","tides","lava","none"}) do
			T:SetEndcap(key)
			check(frame.shown==(key~="none"),name.." choice visibility")
			check(not hp.Backdrop.texture:find("capped",1,true),name.." retains full bare terminal")
			if key~="none" then
				check(frame.Art.texture:find("ornament-"..key.."-"..name..".tga",1,true) and frame.Art.coords[1]==(flip and 1 or 0),"per-tier export and mirror")
			end
		end
	end
end
db.HealthBackdropTexture="x\\Assets\\Shaman\\hp_cap_case.tga"
T:SetEndcap("maelstrom");T:StyleHealth(owner,db,true)
T:SetEndcapScale(1.5);T:SetEndcapOffset(7,-3)
local ratio=1.5/1.3;local point=frame.Art.points[1]
check(math.abs(point[4]+ratio*(1-754/1024)*716-((1-754/1024)*716-7))<.00001,"mirrored custom scale and outward nudge preserve measured dip")
check(math.abs(point[5]-ratio*(187/256)*188-(-(187/256)*188-3))<.00001,"custom size grows around measured bottom pivot")
T:SetCastEndcapOffset(5,2);T:SetCastEndcapScale(1.2)
check(T:ResetEndcapPlacement() and frame.Art.width==716 and T:GetCastEndcapScale()==1.2,"health reset restores reviewed size without clearing cast settings")
T:ResetCastEndcapPlacement()
db.HealthBackdropTexture="x\\Assets\\Shaman\\cast_back.tga";db.HealthBarTexture="cast_bar"
T:StyleHealth(owner,db,false)
check(not frame.shown and not frame.Threat.shown and hp.ShamanRails.Art.texture:find("cast_back-over",1,true),"compact transition keeps its own front and removes cap/halo")
-- The percentage must clear the actual painted body in both native directions.
for _,flip in ipairs({false,true}) do
	local textOwner=widget();textOwner.width=flip and 550 or 560
	local textBar=widget(textOwner);textOwner.Health=textBar;textBar.width,textBar.height=385,40
	textBar.Backdrop=widget(textOwner);textBar.Backdrop.width,textBar.Backdrop.height=716,188
	textBar.Percent=widget(textBar)
	textBar.Percent:SetPoint(flip and "LEFT" or "RIGHT",textBar,flip and "LEFT" or "RIGHT",flip and 27 or -27,4)
	local textDB={HealthBackdropTexture="x\\Assets\\Shaman\\hp_cap_case.tga",
		HealthBarPosition=flip and {"TOPRIGHT",-140,-66} or {"BOTTOMLEFT",148,27},
		HealthBackdropPosition=flip and {"TOPRIGHT",23.5,8.5} or {"BOTTOMLEFT",-17,-48}}
	T:ResetEndcapPlacement();T:SetEndcap("maelstrom");T:StyleHealth(textOwner,textDB,flip)
	local textPoint=textBar.Percent.points[1]
	local healthLeft=flip and 25 or 148
	local casingLeft=flip and -142.5 or -17
	local capEdge=casingLeft+(flip and 1-699/1024 or 699/1024)*716
	local percentEdge=healthLeft+(flip and 0 or 385)+textPoint[4]
	check(math.abs(percentEdge-capEdge)==8,"eight layout units between percent and painted body")
	check(textPoint[2]==textBar and textPoint[5]==4,"percent retains original anchor frame and baseline")
	T:StyleHealth(textOwner,textDB,flip)
	check(textBar.Percent.points[1][4]==textPoint[4],"restyling never accumulates inset")
	T:SetEndcap("none")
	check(textBar.Percent.points[1][4]==(flip and 27 or -27),"None restores native percent position immediately")
	T:SetEndcap("lava")
	local alternateEdge=casingLeft+(flip and 1-692/1024 or 692/1024)*716
	check(math.abs(healthLeft+(flip and 0 or 385)+textBar.Percent.points[1][4]-alternateEdge)==8,"alternate motif reserves its measured painted body")
	T:SetEndcap("maelstrom")
	T:SetEndcapScale(1.8);T:SetEndcapOffset(-12,5)
	check((flip and textBar.Percent.points[1][4]>textPoint[4]) or (not flip and textBar.Percent.points[1][4]<textPoint[4]),"larger inward cap reserves additional text room")
	T:ResetEndcapPlacement();T:SetEndcap("none")
	check(textBar.Percent.points[1][4]==(flip and 27 or -27) and textBar.Percent.points[1][5]==4,"custom placement then None restores exact baseline")
end
-- Secret percent text makes its read-back anchor secret (5.30.1, login on Retail 12.1.5).
do
	local SECRET=setmetatable({},{__eq=function() error("compared a secret") end})
	local oldSecret=issecretvalue;issecretvalue=function(v) return rawequal(v,SECRET) end
	local textOwner=widget();textOwner.width=560
	local textBar=widget(textOwner);textOwner.Health=textBar;textBar.width,textBar.height=385,40
	textBar.Backdrop=widget(textOwner);textBar.Backdrop.width,textBar.Backdrop.height=716,188
	textBar.Percent=widget(textBar)
	function textBar.Percent:GetPoint() return SECRET,SECRET,SECRET,SECRET,SECRET end
	-- Unit files pass the tier table, which has no HealthPercentagePosition; they record LayoutPoint.
	textBar.Percent.LayoutPoint={"RIGHT",-27,4}
	local textDB={HealthBackdropTexture="x\\Assets\\Shaman\\hp_cap_case.tga",
		HealthBarPosition={"BOTTOMLEFT",148,27},HealthBackdropPosition={"BOTTOMLEFT",-17,-48}}
	T:ResetEndcapPlacement();T:SetEndcap("maelstrom")
	check(pcall(T.StyleHealth,T,textOwner,textDB,false),"secret percent anchor never compared")
	local p=textBar.Percent.points[1]
	check(p[1]=="RIGHT" and p[2]==textBar and p[5]==4 and p[4]<-27,"secret anchor uses LayoutPoint and moves clear of the cap")
	local capX=p[4]
	T:SetEndcap("none")
	check(textBar.Percent.points[1][4]==-27,"secret anchor: None puts the percent back on its layout spot")
	T:SetEndcap("maelstrom")
	check(textBar.Percent.points[1][4]==capX,"secret anchor: the cap moves it again")
	-- Without a recorded anchor the theme leaves the text alone rather than erroring.
	local bare=widget(textOwner);textOwner.Health=bare;bare.width,bare.height=385,40
	bare.Backdrop=widget(textOwner);bare.Backdrop.width,bare.Backdrop.height=716,188
	bare.Percent=widget(bare);function bare.Percent:GetPoint() return SECRET,SECRET,SECRET,SECRET,SECRET end
	check(pcall(T.StyleHealth,T,textOwner,textDB,false) and #bare.Percent.points==0,"secret anchor with no LayoutPoint is left untouched")
	issecretvalue=oldSecret
end
T:SetEndcap("maelstrom")
before=reloads;combat=true
check(not T:Command("off") and not T:Command("endcap lava") and not T:Command("castendcap none"),"combat refuses slash writes")
check(not T:SetEndcapScale(1.8) and not T:SetCastEndcapOffset(3,4) and reloads==before,"combat refuses placement writes and reload")
combat=false
check(not T:Command("endcap typo") and not T:Command("typo"),"unknown commands and cap names rejected")
variant="SaiyaRatt";check(not T:IsActive() and not T:Command("on"),"alternate layout gate enforced")
variant=nil
-- Use the real options factory and callbacks, rather than a copied theme list.
LibStub=function() return {GetLocale=function() return setmetatable({}, {__index=function(_,key)return key end}) end} end
LOCALIZED_CLASS_NAMES_MALE={SHAMAN="Localized Shaman"}
assert(loadfile(root.."/Options/OptionsPages/Themes.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
local page=options.factory();local args=page.args.shaman.args
check(page.args.theme.values().shaman=="Localized Shaman (WIP)" and not page.args.shaman.hidden(),"localized Shaman offered outside Development Mode")
check(args.endcap.values.tides=="Tides" and args.castEndcap.values.totem=="Ancestral Totem","all health/cast controls labelled")
args.endcap.set(nil,"lava");check(args.endcap.get()=="lava","real option writes Shaman setting")
args.castEndcap.set(nil,"none");check(args.castEndcap.get()=="none" and args.endcap.get()=="lava","real cast option independent from health")
ns.db.char.shamanEndcapX=9;ns.db.char.shamanEndcapY=-4
ns.db.char.hunterEndcapX=13
ns.db.char.moverLinks={sentinel="saved layout"}
page.args.theme.set(nil,"mage");settle()
check(E:GetTheme()=="mage" and not ns.db.char.shamanPreview and page.args.shaman.hidden(),"selector leaves Shaman and hides its controls")
before=reloads;check(T:Command("off") and E:GetTheme()=="mage" and reloads==before,"inactive Shaman off preserves another theme")
page.args.theme.set(nil,"shaman");settle()
check(E:GetTheme()=="shaman" and not ns.db.char.magePreview,"selector returns to Shaman and clears other themes")
check(ns.db.char.shamanEndcapX==9 and ns.db.char.shamanEndcapY==-4 and ns.db.char.hunterEndcapX==13,"theme switches preserve saved cap nudges")
check(ns.db.char.moverLinks.sentinel=="saved layout","theme switches preserve saved frame links")
E:SetLitePlus(true);E:SetCrystalChoice("paladin");E:SetOrbChoice("hunter")
check(E:GetTheme()=="shaman" and E:GetCrystalEffect()=="paladin" and E:GetOrbEffect()=="hunter","Lite+ remains available over Shaman casings")
ns.LegacyHUD:Command("legacy");settle()
check(E:GetTheme()=="legacy" and not ns.db.char.shamanPreview,"real /go clears Shaman when entering Legacy")
ns.LegacyHUD:Command("azerite");settle()
check(E:GetTheme()=="azerite","leaving Legacy does not resurrect Shaman")
T:Command("on");settle();before=reloads
ns.LegacyHUD:Command("azerite");settle()
check(E:GetTheme()=="azerite" and reloads==before+1 and not ns.db.char.shamanPreview,"real /go azerite exits Shaman with reload")
print("Shaman integration: "..checks.." checks passed (offline recording widgets; live client unverified)")

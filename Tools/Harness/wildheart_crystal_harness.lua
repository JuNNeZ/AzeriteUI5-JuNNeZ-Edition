-- lua Tools/Harness/wildheart_crystal_harness.lua . [mutations|samples output.json]
-- Real Lua module, recording widgets. Does not emulate WoW's renderer.
local root=arg[1] or "."
local count=0
local function check(value,label) count=count+1;assert(value,label) end
local secret={}
issecretvalue=function(v) return rawequal(v,secret) end
local combat,mounted,flying,moving=false,false,false,false
InCombatLockdown=function() return combat end
IsMounted=function() return mounted end
IsFlying=function() return flying end
IsPlayerMoving=function() return moving end
local function widget(parent)
	local w={parent=parent,points={},scripts={},events={},shown=true,level=1}
	function w:GetFrameLevel() return self.level end
	function w:SetFrameLevel(v) self.level=v end
	function w:EnableMouse(v) self.mouse=v end
	function w:SetAllPoints(v) self.anchor=v end
	function w:SetParent(v) self.parent=v end
	function w:SetPoint(p,...) assert(not self.native,"native frame moved");self.points[p]={...} end
	function w:SetSize(a,b) assert(not self.native,"native frame resized");self.width,self.height=a,b end
	function w:GetHeight() assert(self.native,"native fill geometry read");return 196 end
	function w:GetWidth() assert(self.native,"native fill geometry read");return 196 end
	function w:SetClipsChildren(v) self.clips=v end
	function w:SetTexture(v) assert(not self.native,"native fill retextured");self.texture=v end
	function w:SetTexCoord(...) self.coords={...} end
	function w:SetVertexColor(...) self.color={...} end
	function w:SetBlendMode(v) self.blend=v end
	function w:SetAlpha(v) self.alpha=v end
	function w:AddMaskTexture(v) self.masks=self.masks or {};self.masks[#self.masks+1]=v;self.mask=self.masks[1] end
	function w:CreateTexture(_,layer,_,level) local t=widget(self);t.layer,t.sublevel=layer,level;return t end
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
local ns={db={char={themeLitePlus=true,themeCrystalEffect="wildheart"}}}
function ns:GetModule() end
assert(loadfile(root.."/Core/WildheartCrystal.lua"))("Test",ns)
assert(loadfile(root.."/Core/ThemeEffects.lua"))("Test",ns)
local M,E=ns.WildheartCrystal,ns.ThemeEffects
local power=widget();power.native=true
local fill=widget(power)
function power:GetStatusBarTexture() return fill end
check(E:GetCrystalEffect()=="wildheart" and E:GetTheme()=="azerite","independent Lite+ crystal choice")
check(E:GetOrbEffect()=="none","orb unchanged")
E:StyleCrystal(power,"normal",nil,nil,false)
local f=power.Wildheart
check(f.Clip.clips and f.parent==power and f.Fill.parent==f.Clip and f.Body.parent==f.Fill,"only material fill is clipped")
check(f.Ambient.parent==f and f.Ambient.anchor==power and f.Clip.parent==f,"ambient follows full crystal independently of fill")
check(f.Bright.parent==f.Fill and f.Core.parent==f.Bright,"bright energy follows clipped fill")
check(f.Ambient.alpha==M.EmptyEnergy and f.Bright.alpha==1-M.EmptyEnergy and M.EmptyEnergy>0 and M.EmptyEnergy<.3,"dim ambient plus bright fill sum to one")
check(f.Fill.level<f.Ambient.level and f.Fill.level<f.Bright.level,"both light groups draw above material body")
check(f.Clip.points.TOP[1]==fill,"clip follows native fill top")
check(f.Clip.points.BOTTOMLEFT[1]==power and f.Clip.points.BOTTOMRIGHT[1]==power,"fixed native bottom anchors")
for _,art in ipairs({f.Body,f.Veins,f.Moon,f.Core,unpack(f.Motes)}) do
	check(art.mask==f.Mask,"every layer has native silhouette mask")
end
check(f.Mask.texture=="normal" and f.Mask.anchor==power,"native mask canvas")
check(f.Body.sublevel==0 and f.Mist[1].sublevel==1 and f.Veins.sublevel==3 and f.Moon.sublevel==4 and f.Core.sublevel==6 and f.Motes[1].sublevel==7,"explicit material draw order")
check(#f.Mist==2 and #f.Pulses==6 and #f.Motes==6,"bounded dynamic layers")
for _,art in ipairs(f.Mist) do check(art.mask==f.Mask,"mist keeps native silhouette") end
for _,art in ipairs(f.Pulses) do check(art.mask==f.Mask and art.masks[2]==f.VeinMask,"pulses intersect native and vein masks") end
check(f.Veins.texture:find("Druid\\wildheart-veins.tga",1,true),"installed vein texture")
check(f.Moon.texture:find("Druid\\dreamlight.tga",1,true) and f.Core.texture:find("Paladin\\holy-sphere.tga",1,true),"shared installed light textures")
for i,mist in ipairs(f.Mist) do check(#mist.coords==8 and mist.coords[1]==f.Sample.mist[i].coords[1],"runtime UVs follow sampler") end
for _,art in ipairs({f.AmbientParts.Veins,f.AmbientParts.Core,f.AmbientParts.Moon,unpack(f.AmbientParts.Mist)}) do
	check(art.parent==f.Ambient and art.mask==f.Mask,"ambient energy stays masked to full silhouette")
end
local function tick(t) for _=1,math.ceil(t*30) do f.scripts.OnUpdate(f,1/30) end end
local function event(e) f.scripts.OnEvent(f,e) end
check(f.TargetActivity==.22,"idle activity")
moving=true;event("PLAYER_STARTED_MOVING");check(f.TargetActivity==.6 and f.Impulse>0,"moving activity")
moving=false;event("PLAYER_STOPPED_MOVING");check(f.TargetActivity==.22 and f.Impulse<0,"stopping returns idle")
tick(5);check(math.abs(f.Impulse)<.001,"movement impulse settles")
local quietStart=f.Time;tick(1);local quietAdvance=(f.Time-quietStart)%24
combat=true;event("PLAYER_REGEN_DISABLED");tick(1)
check(f.TargetActivity==1 and f.Time>0,"combat animation continues")
tick(4);local activeStart=f.Time;tick(1)
check((f.Time-activeStart)%24>quietAdvance*1.8,"active material circulates faster")
check(not M:SetStrength(.4) and M:GetStrength()==1,"combat settings blocked")
combat=false;event("PLAYER_REGEN_ENABLED");check(f.TargetActivity==.22,"leaving combat returns idle")
mounted=true;event("PLAYER_MOUNT_DISPLAY_CHANGED");check(f.TargetActivity==1,"mounted equals combat")
mounted=false;flying=true;tick(.3);check(f.TargetActivity==1,"flying equals combat")
flying=false;tick(.3);check(f.TargetActivity==.22,"landing and dismount return idle")
mounted,moving,flying=secret,secret,secret;tick(.3);check(f.TargetActivity==.22,"secret states use fallback")
mounted,moving,flying=false,false,false
IsPlayerMoving=nil;event("PLAYER_STARTED_MOVING");tick(.3);check(f.TargetActivity==.6,"event fallback without optional query")
event("PLAYER_STOPPED_MOVING")
local phase=f.Time
f.scripts.OnUpdate(f,1/240);check(f.Time==phase,"30Hz throttle")
E:StyleCrystal(power,"ice",nil,nil,false)
check(power.Wildheart==f and f.Time==phase and f.Body.texture=="ice" and f.Mask.texture=="ice","restyle reuses phase and refreshes ice mask")
f.scripts.OnHide(f);check(not f.scripts.OnUpdate and not next(f.events),"hidden effect releases callback and events")
f.scripts.OnShow(f);check(f.scripts.OnUpdate and f.events.PLAYER_REGEN_DISABLED,"show resumes selected effect")
for _,choice in ipairs({"none","druid","paladin","mage"}) do
	E:SetCrystalChoice(choice);E:StyleCrystal(power,"normal",nil,nil,false)
	check(not f.Enabled and not f.shown and not f.scripts.OnUpdate and not next(f.events),"switch clears animation")
	f.scripts.OnShow(f);check(not f.scripts.OnUpdate,"cleared effect cannot restart")
	E:SetCrystalChoice("wildheart");E:StyleCrystal(power,"normal",nil,nil,false)
end
M:SetStrength(0);E:StyleCrystal(power,"normal");check(not f.Enabled,"zero strength restores ordinary crystal")
M:SetStrength(.4);E:StyleCrystal(power,"normal");check(f.alpha==.4,"independent strength applied")
check(not M:SetStrength(0/0),"NaN rejected")
local a,b=M:Sample(.5,.22),M:Sample(8.5,.22)
check(math.abs(a.veins-b.veins)<1e-8 and math.abs(a.motes[1].x-b.motes[1].x)<1e-8,"eight second loop closes")
for i,mist in ipairs(a.mist) do
	for j,v in ipairs(mist.coords) do check(math.abs(v-b.mist[i].coords[j])<1e-8,"mist loop closes") end
end
for i,pulse in ipairs(a.pulses) do
	check(math.abs(pulse.x-b.pulses[i].x)<1e-8 and math.abs(pulse.alpha-b.pulses[i].alpha)<1e-8,"branch pulse loop closes")
end
check(M:Sample(0,1).motes[1].alpha==0,"mote wraps invisibly")
check(M:Sample(1,1,a)==a,"samples reuse allocated state")
local earlier,later=M:Sample(0,.22),M:Sample(1,.22)
check(earlier.mist[1].coords[1]~=later.mist[1].coords[1],"mist rotates through texture space")
check(earlier.pulses[1].x~=later.pulses[1].x and earlier.pulses[1].y~=later.pulses[1].y,"pulses travel along branches")
local p1,p2,p3=M:Sample(1,1).pulses[1],M:Sample(2,1).pulses[1],M:Sample(3,1).pulses[1]
check(math.abs((p2.x-p1.x)*(p3.y-p2.y)-(p2.y-p1.y)*(p3.x-p2.x))>1e-6,"branch trajectory bends")
local kicked=M:Sample(1,1,nil,.65)
check(kicked.mist[1].coords[1]~=later.mist[1].coords[1],"impulse displaces material")
for i=0,160 do
	local s=M:Sample(i/20,1)
	for _,m in ipairs(s.motes) do check(m.x>0 and m.x<1 and m.y>0 and m.y<1 and m.alpha<=1,"normalized mote bounds") end
	for _,mist in ipairs(s.mist) do for _,v in ipairs(mist.coords) do check(v>=0 and v<=1,"mist samples stay inside texture") end end
end
-- All flavours reuse the same bounded overlay, but retain distinct materials,
-- motion and saved strength. No casing/theme or native resource mutation.
for _,flavour in ipairs({"moonvein","dreamsap","wildheart"}) do
	local savedTime=f.Time
	E:SetCrystalChoice(flavour);E:StyleCrystal(power,"normal",nil,nil,false)
	check(power.Wildheart==f and f.Flavour==flavour and f.Time==savedTime,"flavour switch reuses overlay and phase")
	check(E:GetCrystalEffect()==flavour and E:GetOrbEffect()=="none","flavour resolves independently")
	local palette=M:GetFlavour(flavour)
	check(f.Body.color[1]==palette.body[1] and f.Mist[1].color[2]==palette.mist[1][2],"flavour palette applied")
	check(f.Motes[1].texture:find(palette.moteTexture,1,true),"flavour mote material applied")
	local s=M:Sample(1,.22,nil,0,flavour)
	local loop=M:Sample(9,.22,nil,0,flavour)
	for i,mist in ipairs(s.mist) do
		for j,v in ipairs(mist.coords) do check(math.abs(v-loop.mist[i].coords[j])<1e-8,"flavour UV loop closes") end
	end
	if flavour~="wildheart" then
		check(f.Core.alpha==0 and f.Veins.alpha==0 and s.coreAlpha==0,"non-root flavours hide seed and root veins")
		for _,pulse in ipairs(f.Pulses) do check(pulse.alpha==0,"non-root flavours hide branch pulses") end
	else check(f.Core.alpha>0 and f.Veins.alpha>0,"returning to Wildheart restores root material") end
	check(f.AmbientParts.Core.alpha==f.Core.alpha and f.AmbientParts.Moon.alpha==f.Moon.alpha,"both energy layers share sample")
	for i,mist in ipairs(f.Mist) do
		check(mist.coords[1]==f.AmbientParts.Mist[i].coords[1] and mist.alpha==f.AmbientParts.Mist[i].alpha,"energy crosses boundary in phase")
	end
	for i=0,160 do
		local sample=M:Sample(i/20,1,nil,.65,flavour)
		for _,mist in ipairs(sample.mist) do for _,v in ipairs(mist.coords) do check(v>=0 and v<=1,"flavour UV bounds with impulse") end end
	end
	local phaseBefore=f.Time;tick(.1);check(f.Time~=phaseBefore,"each flavour animates")
	f.scripts.OnHide(f);check(not f.scripts.OnUpdate and not next(f.events),"each flavour stops when hidden")
	f.scripts.OnShow(f);check(f.scripts.OnUpdate,"each flavour resumes")
end
local moon=M:Sample(1,.22,nil,0,"moonvein")
local sap=M:Sample(1,.22,nil,0,"dreamsap")
local rootSample=M:Sample(1,.22)
check(moon.mist[1].coords[1]~=sap.mist[1].coords[1] and sap.mist[1].coords[1]~=rootSample.mist[1].coords[1],"flavours have distinct motion")
check(M:Sample(2,.22,nil,0,"dreamsap").motes[1].y>sap.motes[1].y and sap.motes[1].size>moon.motes[1].size,"sap globules rise and differ from starlights")
M:SetStrength(.2,"moonvein")
check(M:GetStrength("moonvein")==.2 and M:GetStrength()==.4 and M:GetStrength("dreamsap")==1,"independent flavour strength")
E:SetCrystalChoice("moonvein");M:SetStrength(0,"moonvein");E:StyleCrystal(power,"normal")
check(not f.Enabled,"zero flavour strength hides overlay")
E:SetCrystalChoice("dreamsap");E:StyleCrystal(power,"normal")
check(f.Enabled and f.alpha==1,"zero strength does not leak across flavours")
M:SetStrength(1,"moonvein");E:SetCrystalChoice("wildheart");E:StyleCrystal(power,"normal")
if arg[2]=="samples" then
	local out=assert(io.open(assert(arg[3]),"w"))
	local flavour=arg[4] or "wildheart"
	local function json(value)
		if type(value)=="number" then out:write(string.format('%.9f',value));return end
		if type(value)=="string" then out:write(string.format('%q',value));return end
		if #value>0 then
			out:write('[');for j,v in ipairs(value) do if j>1 then out:write(',') end;json(v) end;out:write(']')
		else
			out:write('{');local first=true
			for k,v in pairs(value) do if not first then out:write(',') end;first=false;out:write('"',k,'":');json(v) end
			out:write('}')
		end
	end
	out:write('{"fps":20,"seconds":8,"flavour":');json(flavour)
	out:write(',"palette":');json(M:GetFlavour(flavour))
	out:write(',"emptyEnergy":');json(M.EmptyEnergy);out:write(',"quiet":[')
	local function series(activity)
		for i=0,159 do
			if i>0 then out:write(',') end
			local s=M:Sample(i/20*(1+(activity-.22)/.78),activity,nil,0,flavour)
			json(s)
		end
	end
	series(.22);out:write('],"active":[');series(1);out:write('],"liveCapture":false}');out:close()
end
if arg[2]=="mutations" then
	local input=assert(io.open(root.."/Core/WildheartCrystal.lua"));local source=input:read('*a');input:close()
	local original=loadfile
	for _,m in ipairs({
		{'native top','power:GetStatusBarTexture(),"TOP"','power,"TOP"','clip follows native fill top'},
		{'false state','if type(value)=="boolean" then return value end','if type(value)=="boolean" then return value or fallback end','landing and dismount return idle'},
		{'callback leak','frame:SetScript("OnUpdate",nil)','-- cleanup removed','hidden effect releases callback and events'}
		,{'stationary mist','parts.Mist[i]:SetTexCoord(unpack(mist.coords))','parts.Mist[i]:SetTexCoord(0,1,0,1)','runtime UVs follow sampler'}
		,{'pulse mask removed','art:AddMaskTexture(frame.VeinMask)','-- vein mask removed','pulses intersect native and vein masks'}
		,{'ambient clipped','frame.Clip,frame.Power,frame.Fill,frame.Ambient,frame.Bright=clip,power,fill,ambient,bright','frame.Clip,frame.Power,frame.Fill,frame.Ambient,frame.Bright=clip,power,fill,ambient,bright\n\tambient:SetParent(clip)','ambient follows full crystal independently of fill'}
		,{'ambient behind body','ambient:SetFrameLevel(power:GetFrameLevel()+3)','ambient:SetFrameLevel(power:GetFrameLevel()+1)','both light groups draw above material body'}
	}) do
		local p=assert(source:find(m[2],1,true),m[1]);local changed=source:sub(1,p-1)..m[3]..source:sub(p+#m[2])
		loadfile=function(path) if path==root.."/Core/WildheartCrystal.lua" then return loadstring(changed) end;return original(path) end
		arg[2]=nil;local ok,err=pcall(assert(original(root.."/Tools/Harness/wildheart_crystal_harness.lua")));loadfile=original
		check(not ok and tostring(err):find(m[4],1,true),"mutant rejected: "..m[1])
	end
end
print("Wildheart: "..count.." checks passed (offline only)")

-- lua Tools/Harness/moonwell_slosh_harness.lua . [mutations]
-- Records the real effect's anchors/paint/lifecycle. It cannot prove WoW clipping.
local root = arg[1] or "."
local count = 0
local function check(value, label) count = count+1; assert(value, label) end
local noop = function() end
local secret = setmetatable({}, { __eq = function() error("secret comparison") end })
issecretvalue = function(value) return rawequal(value, secret) end
local combat, mounted, flying, moving = false, false, false, false
InCombatLockdown = function() return combat end
IsMounted = function() return mounted end
IsFlying = function() return flying end
IsPlayerMoving = function() return moving end
local function widget(parent)
	local w = { parent=parent, points={}, scripts={}, events={}, shown=true, level=1 }
	function w:GetFrameLevel() return self.level end
	function w:SetFrameLevel(v) self.level=v end
	function w:EnableMouse(v) self.mouse=v end
	function w:SetAllPoints(v) self.anchor=v end
	function w:ClearAllPoints() self.points={};self.anchor=nil end
	function w:SetPoint(point, ...) assert(not self.nativeOrb, "native orb moved"); self.points[point]={...} end
	function w:SetSize(x,y) assert(not self.nativeOrb, "native orb resized");self.width,self.height=x,y end
	function w:SetHeight(v) assert(not self.nativeOrb, "native orb resized"); self.height=v end
	function w:GetHeight() assert(self.nativeOrb, "native clip height read"); return self.height end
	function w:GetWidth() assert(self.nativeOrb, "native clip width read"); return self.width end
	function w:SetClipsChildren(v) self.clips=v end
	function w:SetTexture(v) self.texture=v end
	function w:GetTexture() return self.texture end
	function w:SetTexCoord(...) self.coords={...} end
	function w:SetVertexColor(...) self.color={...} end
	function w:GetVertexColor() return unpack(self.color or {1,1,1,1}) end
	function w:SetBlendMode(v) self.blend=v end
	function w:SetAlpha(v) self.alpha=v end
	function w:AddMaskTexture(v) self.mask=v end
	function w:CreateTexture() return widget(self) end
	function w:CreateMaskTexture() return widget(self) end
	function w:SetScript(k,v) self.scripts[k]=v end
	function w:RegisterEvent(event) self.events[event]=true end
	function w:UnregisterAllEvents() self.events={} end
	function w:IsVisible() return self.shown end
	function w:Show() self.shown=true end
	function w:Hide() self.shown=false end
	function w:GetValue() error("resource value read") end
	function w:GetMinMaxValues() error("resource range read") end
	function w:GetTop() error("resource position read") end
	return w
end
CreateFrame = function(_,_,parent) return widget(parent) end
hooksecurefunc = function(object, name, fn)
	local old = object[name]
	object[name] = function(...) local result=old(...); fn(...); return result end
end
local ns = { db={char={themeLitePlus=true,themeOrbEffect="moonwell"}} }
function ns:GetModule() end
assert(loadfile(root.."/Core/MoonwellSlosh.lua"))("Test",ns)
assert(loadfile(root.."/Core/ThemeEffects.lua"))("Test",ns)
local M,E=ns.MoonwellSlosh,ns.ThemeEffects
local orb = widget(); orb.nativeOrb=true; orb.width,orb.height=103,103
local edge=widget(orb)
function orb:GetOverlay() return edge end
function orb:GetStatusBarColor() return .2,.4,.8 end
function orb:SetStatusBarColor(...) self.color={...} end
function orb:SetStatusBarTexture(...) self.materialWrites=(self.materialWrites or 0)+1;self.materialCount=select("#",...); self.materials={...} end
check(E:GetOrbEffect()=="moonwell", "new effect resolves through Lite+")
check(E:SetOrbChoice("druid") and E:GetOrbEffect()=="druid", "ordinary Moonwell retained")
E:SetOrbChoice("moonwell")
check(E:StyleOrb(orb), "reactive effect claims fill")
local frame=orb.MoonwellSlosh
check(frame.parent==edge, "all water stays inside native resource clip")
check(#frame.Columns==32 and frame.mouse==false, "bounded decorative columns")
check(orb.materialCount==2 and orb.materials[1]==nil and orb.materials[2]==nil, "straight native paint stands aside")
check(frame.Mode=="quiet" and frame.TargetActivity==.22, "idle mode")
for _,col in ipairs(frame.Columns) do
	check(col.Clip.clips and col.Water.parent.parent==col.Clip, "texture is child of its clipping frame")
	check(col.Mask.anchor==orb and col.Water.mask==col.Mask and col.Rim.mask==col.Mask, "native circular mask applied to water and rim")
	check(col.Clip.points.TOPLEFT[1]==edge and col.Clip.points.BOTTOMRIGHT[1]==orb, "level follows native anchors, fixed bottom follows orb")
	check(col.Water.color[1]==.2 and col.Water.texture:find("Druid\\orb-moonwell.tga",1,true), "native palette and existing material")
end
local function tick(seconds)
	for _=1,math.floor(seconds*30+.5) do frame.scripts.OnUpdate(frame,1/30) end
end
local function event(name) frame.scripts.OnEvent(frame,name) end
local function maxDip()
	local max=0
	for _,col in ipairs(frame.Columns) do
		local offset=col.Clip.points.TOPLEFT[4]
		check(offset<=0, "wave never rises above native clip")
		max=math.max(max,-offset)
	end
	return max
end
tick(1); local idleDip=maxDip()
moving=true;event("PLAYER_STARTED_MOVING")
check(frame.Mode=="moving" and frame.Impulse>0, "movement starts a forward impulse")
moving=false;event("PLAYER_STOPPED_MOVING")
check(frame.Mode=="quiet" and frame.Impulse<0, "stopping starts a return impulse")
tick(5);check(math.abs(frame.Impulse)<.001, "impulse settles")
combat=true;event("PLAYER_REGEN_DISABLED")
check(frame.Mode=="active" and frame.TargetActivity==1, "combat raises activity without settings refresh")
tick(2);check(maxDip()>idleDip, "combat visibly raises wave amplitude")
-- Combat blocks configuration, while the already-created cosmetic animation runs.
local phase=frame.Time
frame.scripts.OnUpdate(frame, 1/240)
check(frame.Time==phase, "animation throttles sub-frame updates")
tick(.5);check(frame.Time~=phase and frame.scripts.OnUpdate~=nil, "animation continues in combat")
check(not M:SetStrength(.4) and M:GetStrength()==1, "combat refuses settings writes")
combat=false;event("PLAYER_REGEN_ENABLED")
mounted=true;event("PLAYER_MOUNT_DISPLAY_CHANGED")
check(frame.Mode=="active" and frame.TargetActivity==1, "mounted uses exactly the combat target")
mounted=false;flying=true;tick(.3)
check(frame.Mode=="active" and frame.TargetActivity==1, "flying uses exactly the combat target")
flying=false;tick(.3)
check(frame.Mode=="quiet", "landing and dismounting return to idle")
mounted=secret;flying=secret;moving=secret;tick(.3)
check(frame.Mode=="quiet", "secret state is not branched on")
mounted=false;flying=false;moving=false
IsPlayerMoving=nil;event("PLAYER_STARTED_MOVING");tick(.3)
check(frame.Mode=="moving", "movement events work without optional query")
event("PLAYER_STOPPED_MOVING")
orb:SetStatusBarColor(.6,.3,.9)
check(frame.Columns[1].Water.color[1]==.6, "later palette changes forwarded")
-- Read back actual anchors as geometry, independent of the motion equation.
-- A zero-height native parent has no paintable interval, regardless of waves.
for _, fill in ipairs({0, .01, .5, 1}) do
 local painted=0
 for i,col in ipairs(frame.Columns) do
  local top=103*fill+col.Clip.points.TOPLEFT[4]
  local visible=math.max(0, math.min(103*fill, top))
  check(visible<=103*fill, "wave stays within native fill interval")
  painted=painted+visible
  check(math.abs(col.Clip.points.BOTTOMRIGHT[3]-103*i/32)<.00001, "columns tile fixed orb width")
 end
 check((fill~=0 or painted==0), "empty native clip paints no water")
 if fill==.5 then check(painted>0 and painted<103*.5*32, "partial fill has visible troughs") end
end
local first=frame.Columns[1].Clip.points.TOPLEFT[4]
local last=frame.Columns[32].Clip.points.TOPLEFT[4]
check(first~=last, "actual surface is not flat")
local savedPhase=frame.Time
E:StyleOrb(orb)
check(orb.MoonwellSlosh==frame and frame.Time==savedPhase, "restyle reuses frames and animation phase")
-- Parent hiding stops events as well as the callback; showing resamples state.
frame.scripts.OnHide(frame)
check(frame.scripts.OnUpdate==nil and next(frame.events)==nil, "hidden effect stops callbacks and events")
frame.scripts.OnShow(frame)
check(frame.scripts.OnUpdate and frame.events.PLAYER_REGEN_DISABLED, "show resumes enabled effect")
E:SetOrbChoice("none");check(not E:StyleOrb(orb), "none returns native fill ownership")
check(not frame.shown and not frame.Enabled and frame.scripts.OnUpdate==nil and next(frame.events)==nil, "clear removes callback and event subscriptions")
frame.scripts.OnShow(frame)
check(frame.scripts.OnUpdate==nil, "cleared effect cannot restart on parent show")
E:SetOrbChoice("moonwell");E:StyleOrb(orb)
ns.PaladinTheme={IsActive=function() return false end, ClearOrbEffect=noop, ApplyOrbEffect=function() return true end}
E:SetOrbChoice("paladin");E:StyleOrb(orb)
check(not frame.Enabled and frame.scripts.OnUpdate==nil, "Paladin early return clears slosh")
E:SetOrbChoice("moonwell");E:StyleOrb(orb)
check(M:SetStrength(0) and not E:StyleOrb(orb) and not frame.shown, "zero strength gives native fill back")
check(M:SetStrength(.4) and E:StyleOrb(orb) and frame.Strength==.4, "strength persisted and applied")
check(not M:SetStrength(0/0), "NaN rejected")
orb.width,orb.height=180,180;E:StyleOrb(orb)
check(frame.Columns[32].Clip.points.BOTTOMRIGHT[3]==180, "owned columns follow resized widget")

-- General flowing mana: actual resource identity, independent of class/Lite+.
E:SetOrbChoice("none")
orb.displayType=nil;check(not E:ShouldFlowMana(orb,true),"unknown resource does not flow")
orb.displayType=secret;check(not E:ShouldFlowMana(orb,true),"secret resource does not flow")
orb.displayType="MANA";check(not E:ShouldFlowMana(orb,true),"resource requires plain numeric identity")
for _,powerType in ipairs({1,2,3,6,9,19}) do
	orb.displayType=powerType;check(not E:ShouldFlowMana(orb,true),"non-mana resource does not flow")
end
orb.displayType=0
check(not E:ShouldFlowMana(orb,false) and not E:ShouldFlowMana(orb,nil),"flowing mana defaults off")
M:SetStrength(0)
for _,class in ipairs({"DRUID","EVOKER","MAGE","MONK","PALADIN","PRIEST","SHAMAN","WARLOCK","HUNTER"}) do
	ns.PlayerClass=class
	check(not E:StyleOrb(orb,true) and frame.FlowingMana and frame.Strength==1,"flowing mana works for every mana class independently of Moonwell strength")
end
orb:SetStatusBarColor(.6,.3,.9)
check(frame.Columns[1].Rim.color[1]==.6 and frame.Columns[1].Rim.color[2]==.3,"generic rim follows selected palette")
E:SetOrbChoice("paladin")
check(E:StyleOrb(orb,true) and frame.Enabled,"flowing mana coexists with chosen Lite+ fill")
check(E:StyleOrb(orb,false) and not frame.Enabled,"turning off restores chosen Lite+ fill")
E:SetOrbChoice("moonwell");M:SetStrength(1);E:StyleOrb(orb)
check(not frame.FlowingMana and frame.Columns[1].Rim.color[1]==.52,"Moonwell retains lunar rim")

-- Regression: the general toggle adds slosh to the selected effect, not water
-- in place of that effect. The selected material must still reach LibOrb.
ns.PaladinTheme.ApplyOrbEffect=function(_, target)
	target:SetStatusBarTexture("paladin-light", "paladin-light")
	return true
end
E:SetOrbChoice("paladin");E:StyleOrb(orb,true)
check(orb.materials[1]=="paladin-light", "flowing keeps chosen Paladin material")
check(frame.Columns[1].Clip.level==frame.level and frame.Columns[1].Content.level==frame.level,
	"trough paint has an explicit shared level below native glass")
local phaseBefore=frame.Time
tick(.5)
check(frame.Time~=phaseBefore,"preserved-material slosh still animates")
for _,col in ipairs(frame.Columns) do
	check(col.Rim.alpha==0, "Flowing mana has no added surface glow after animation")
	check(col.Clip.points.TOPLEFT[1]==edge and col.Clip.points.TOPLEFT[4]==0,
		"flowing trough begins at native edge")
	check(col.Clip.points.BOTTOMRIGHT[1]==edge and col.Clip.points.BOTTOMRIGHT[4]<=0,
		"flowing trough only covers below native edge")
	check(col.Rim.points.BOTTOMLEFT and col.Rim.points.BOTTOMLEFT[1]==col.Clip and col.Rim.points.BOTTOMLEFT[2]=="BOTTOMLEFT"
		and not col.Rim.points.TOPLEFT, "flowing rim stays inside trough clip at dipped edge")
	check(col.Water.alpha==1 and col.Water.texture:find("orb-backdrop2.tga",1,true),
		"trough restores opaque actual empty-orb material")
	for _,fill in ipairs({0,.01,.25,.5,1}) do
		local visible=math.min(103*fill,-col.Clip.points.BOTTOMRIGHT[4])
		check(visible>=0 and visible<=103*fill and (fill~=0 or visible==0),
			"trough coverage stays within native fill, empty stays empty")
	end
end
orb.Backdrop=widget(orb);orb.Backdrop:SetTexture("chosen-empty-backdrop");orb.Backdrop:SetVertexColor(.8,.9,1,1)
E:StyleOrb(orb,true)
check(frame.Columns[1].Water.anchor==orb.Backdrop and frame.Columns[1].Water.texture=="chosen-empty-backdrop",
	"trough follows actual backdrop geometry and texture")
orb:SetStatusBarColor(.2,.6,.7)
check(frame.Columns[1].Water.color[1]==.8 and frame.Columns[1].Rim.color[1]==.2,
	"palette changes tint rim without tinting empty backdrop")
E:SetOrbChoice("moonwell");E:StyleOrb(orb,true)
check(orb.materials[1]:find("orb-moonwell.tga",1,true) and frame.FlowingMana,
	"selected Moonwell material also keeps its paint with generic slosh")
E:StyleOrb(orb,false)
check(not frame.FlowingMana and frame.Columns[1].Water.anchor==orb and frame.Columns[1].Water.alpha==.88,
	"standalone Moonwell restores its own columns after generic slosh")
check(frame.Columns[1].Rim.alpha>0, "standalone Moonwell restores its lunar rim after Flowing mana")

-- Execute the real local material setter and PostUpdate callback from Player.lua.
local input=assert(io.open(root.."/Components/UnitFrames/Units/Player.lua"));local playerSource=input:read('*a');input:close()
check(playerSource:find('flowingMana = false',1,true),"real player default is off")
local material=assert(playerSource:match('SetManaOrbFillTexture = function.-\nend'))
local post=assert(playerSource:match('local Mana_PostUpdate = function.-\nend'))
local profile={flowingMana=false,manaOrbTexture="clouds"}
local db={ManaOrbTexture={"nativeA","nativeB"}}
ns.API={GetMedia=function(asset) return "media/"..asset end}
ns.GetConfig=function() return {Seasoned=db,ManaOrbTexture="wrong root material"} end
local build=assert(loadstring('return function(ns, PlayerFrameMod)\n'..
	'local SetManaOrbFillTexture\nlocal UpdateManaOrbColor=function(e) e:SetStatusBarColor(.6,.3,.9) end\n'..
	'local UpdatePlayerElementValueText=function() end\nlocal GetPlayerElementVisualPercent=function() end\n'..
	'local GetPlayerElementDisplayValue=function() end\n'..
	'local MANA_ORB_TEXTURES={clouds="orb2",galaxy="orb1",moon="orb3",sphere="orb4"}\n'..
	material..'\n'..post..'\nreturn SetManaOrbFillTexture,Mana_PostUpdate\nend'))()
local setMaterial,postUpdate=build(ns,{db={profile=profile}})
E:SetOrbChoice("none");setMaterial(orb,db)
check(not frame.Enabled and orb.materials[1]=="nativeA" and orb.materials[2]=="nativeB","off restores real configured material")
check(orb.__AzeriteUI_OrbFillLayout==db,"actual tier layout retained for resource changes")
profile.flowingMana=true;setMaterial(orb,db)
check(frame.Enabled and orb.__AzeriteUI_FlowingMana,"player toggle reaches material dispatcher")
check(orb.materials[1]=="nativeA" and orb.materials[2]=="nativeB", "flowing preserves actual tier material")
local writes=orb.materialWrites
postUpdate(orb,"player",50,0,100)
check(orb.materialWrites==writes,"ordinary mana updates do not rebuild material")
combat=true;orb.displayType=3;postUpdate(orb,"player",50,0,100)
check(not frame.Enabled and orb.materials[1]=="nativeA","resource switch restores normal fill in combat")
orb.displayType=0;postUpdate(orb,"player",50,0,100)
check(frame.Enabled and frame.Running and frame.Columns[1].Rim.color[1]==.6,"return to mana starts flow and forwards palette in combat")
orb.displayType=secret;postUpdate(orb,"player",50,0,100)
check(not frame.Enabled,"unknown secret identity clears generic override")
combat=false;orb.displayType=0;profile.flowingMana=false;profile.manaOrbTexture="galaxy";setMaterial(orb,db)
check(not frame.Enabled and orb.materials[1]=="media/orb1","selected native material restored when toggle disabled")
for _,style in ipairs({"galaxy","moon","sphere"}) do
	profile.manaOrbTexture=style;profile.flowingMana=true;setMaterial(orb,db)
	local expected=({galaxy="orb1",moon="orb3",sphere="orb4"})[style]
	check(frame.Enabled and orb.materials[1]=="media/"..expected,
		"flowing preserves selected native material: "..style)
end
E:SetOrbChoice("paladin");profile.flowingMana=true;setMaterial(orb,db)
check(frame.Enabled and orb.materials[1]=="paladin-light","slosh preserves selected Paladin effect")
profile.flowingMana=false;setMaterial(orb,db)
check(not frame.Enabled and E:GetOrbChoice()=="paladin","Lite+ choice retained and restored")
E:SetOrbChoice("moonwell");E:StyleOrb(orb)
if (arg[2]=="geometry") then
	M:SetStrength(1);E:StyleOrb(orb);combat=true;event("PLAYER_REGEN_DISABLED");tick(2.5)
 local out=assert(io.open(assert(arg[3], "geometry output path required"),"w"))
 out:write('{"width":',frame.OrbWidth,',"height":',frame.OrbHeight,',"dips":[')
 for i,col in ipairs(frame.Columns) do
  if i>1 then out:write(',') end
  out:write(-col.Clip.points.TOPLEFT[4])
 end
 out:write(']}');out:close()
end

if (arg[2]=="mutations") then
	local file=assert(io.open(root.."/Core/MoonwellSlosh.lua"));local source=file:read("*a");file:close()
	local originalLoad=loadfile
	local mutants={
		{"native clip parent", 'orb:GetOverlay())', 'orb)', "all water stays inside native resource clip"},
		{"mounted ignored", 'ReadState(IsMounted, frame.Mounted or false)', 'false', "mounted uses exactly the combat target"},
		{"clip overshoot", 'frame.OrbWidth*(i-1)/COLUMNS, -dip', 'frame.OrbWidth*(i-1)/COLUMNS, dip', "wave never rises above native clip"},
		{"callback leak", 'frame:SetScript("OnUpdate", nil)', '-- removed cleanup', "hidden effect stops callbacks and events"}
		,{"generic inherits zero strength", 'flowingMana and 1 or Strength()', 'Strength()', "flowing mana works for every mana class independently of Moonwell strength"}
		,{"generic rim loses palette", 'column.Rim:SetVertexColor(...)', 'column.Rim:SetVertexColor(1,1,1)', "generic rim follows selected palette"}
		,{"resource gate omitted", 'return type(powerType) == "number" and powerType == 0', 'return true', "unknown resource does not flow", "Core/ThemeEffects.lua"}
		,{"flowing erases selected painting", 'if (not frame.FlowingMana) then orb:SetStatusBarTexture(nil, nil) end', 'orb:SetStatusBarTexture(nil, nil)', "flowing keeps chosen Paladin material"}
		,{"flowing replaces selected effect", 'local slosh = ns.MoonwellSlosh', 'if (flowing) then effect = "none" end; local slosh = ns.MoonwellSlosh', "flowing mana coexists with chosen Lite+ fill", "Core/ThemeEffects.lua"}
		,{"flowing rim outside clip", 'local left = frame.FlowingMana and "BOTTOMLEFT" or "TOPLEFT"', 'local left = "TOPLEFT"', "flowing rim stays inside trough clip at dipped edge"}
	}
	for _,m in ipairs(mutants) do
		local target=root.."/"..(m[5] or "Core/MoonwellSlosh.lua")
		local current=source
		if m[5] then local f=assert(io.open(target));current=f:read('*a');f:close() end
		local pos=assert(current:find(m[2],1,true),m[1].." target missing")
		local changed=current:sub(1,pos-1)..m[3]..current:sub(pos+#m[2])
		loadfile=function(path) if path==target then return loadstring(changed) end;return originalLoad(path) end
		arg[2]=nil
		local ok,err=pcall(assert(originalLoad(root.."/Tools/Harness/moonwell_slosh_harness.lua")))
		loadfile=originalLoad
		check(not ok and tostring(err):find(m[4],1,true),"mutant rejected: "..m[1])
	end
end
print("Moonwell+: "..count.." checks passed (offline only)")

local checks = 0
local function check(value, message)
	checks = checks + 1
	assert(value, message)
end
local function obj()
	local o = { points = {}, textures = {}, scripts = {} }
	function o:SetParent(parent) self.parent=parent end
	function o:GetParent() return self.parent end
	function o:GetWidth() return self.width or 196 end
	function o:GetHeight() return self.height or 196 end
	function o:SetSize(w,h) self.width,self.height=w,h end
	function o:SetAllPoints(anchor) self.anchor = anchor end
	function o:SetPoint(...) self.points[#self.points+1] = {...} end
	function o:ClearAllPoints() self.points = {} end
	function o:SetFrameLevel(level) self.level = level end
	function o:GetFrameLevel() return self.level or 2 end
	function o:EnableMouse(enabled) self.mouse = enabled end
	function o:SetClipsChildren(enabled) self.clips = enabled end
	function o:CreateTexture() local art=obj(); self.textures[#self.textures+1]=art; return art end
	function o:CreateMaskTexture() return obj() end
	function o:SetTexture(path) self.path = path; self.textureWrites=(self.textureWrites or 0)+1 end
	function o:SetTexCoord(...) self.coords={...} end
	function o:SetVertexColor(...) self.color={...} end
	function o:AddMaskTexture(mask) self.mask=mask end
	function o:SetAlpha(alpha) self.alpha=alpha end
	function o:SetBlendMode(mode) self.blend=mode end
	function o:SetShown(shown) self.shown=shown end
	function o:Show() self.shown=true end
	function o:Hide() self.shown=false end
	function o:SetScript(key, script) self.scripts[key]=script end
	return o
end
local frames, reloads, combat, variant = {}, 0, false, ''
CreateFrame = function(_, _, parent) local f=obj(); f.parent=parent; frames[#frames+1]=f; return f end
ReloadUI = function() reloads=reloads+1 end
InCombatLockdown = function() return combat end
-- Any resource sampling would fail, including values marked secret by WoW.
UnitPower = function() error('must not read mana') end
UnitPowerMax = UnitPower
local module = {}
function module:Print(message) self.message=message end
function module:RegisterChatCommand(command) self.command=command end
function module:RegisterEvent(event) self.event=event end
function module:UnregisterEvent() self.event=nil end
local ns={ Prefix='AzeriteTest', db={ char={}, RegisterCallback=function() end }, PlayerClass='PALADIN' }
function ns:NewModule() return module end
function ns:GetActiveConfigVariant() return variant end
-- Core/ThemeEffects.lua decides when the crystal is drawn; its redraws go
-- through the player frame's UpdateSettings, counted here.
local refreshes=0
local playerFrame={frame={}, IsEnabled=function() return true end, UpdateSettings=function() refreshes=refreshes+1 end}
function ns:GetModule(name) if name=='PlayerFrame' then return playerFrame end end
function ns:Print(message) self.message=message end
assert(loadfile((arg[1] or '.')..'/Core/MageCrystalPreview.lua'))('AzeriteUI5_JuNNeZ_Edition',ns)
assert(loadfile((arg[1] or '.')..'/Core/ThemeEffects.lua'))('AzeriteUI5_JuNNeZ_Edition',ns)
module:OnInitialize()
check(module.command=='azmagecrystal','command registered without development mode')
-- One repacked atlas per school (Tools/Build-MageEnergyAtlas.py); the layout
-- below must match ENERGY in Core/MageCrystalPreview.lua and the build output.
check(module.EnergyAvailable==true,'moving energy ships')
local E={columns=18,cellW=110,cellH=128,pageW=2048,pageH=1024,crop={46/255,210/255,33/255,223/255}}
local function U(index,c) return (index%E.columns+(c-E.crop[1])/(E.crop[2]-E.crop[1]))*E.cellW/E.pageW end
local function V(index,c) return (math.floor(index/E.columns)+(c-E.crop[3])/(E.crop[4]-E.crop[3]))*E.cellH/E.pageH end
local function near(a,b) return math.abs(a-b)<1e-9 end
for _,school in ipairs({'arcane','fire','frost'}) do
	local file=io.open((arg[1] or '.')..'/Assets/MageCrystalTest/'..school..'-energy.tga','rb')
	check(file,school..' atlas shipped')
	if file then
		local header=file:read(18); local size=file:seek('end'); file:close()
		local w=header:byte(13)+header:byte(14)*256; local h=header:byte(15)+header:byte(16)*256
		check(w==E.pageW and h==E.pageH and header:byte(17)==32,school..' atlas is a 32-bit '..E.pageW..'x'..E.pageH..' page')
		check(size<9*2^20,school..' atlas stays small')
	end
end
check(E.columns*math.floor(E.pageH/E.cellH)>=128 and E.columns*E.cellW<=E.pageW,'all 128 frames fit the page')
check(not module:IsActive(),'opt-in default')
local power=obj()
power.Case=obj(); power.Case:SetParent(power); power.fill=obj()
power.Case:SetPoint('CENTER',power,'CENTER',3,-4); power.Case:SetSize(123,145)
local casePoints=power.Case.points
function power:GetStatusBarTexture() return self.fill end
function power:SetSize() error('native size must stay owned by Player.lua') end
function power:GetValue() error('secret value must not be sampled') end
function power:SetStatusBarTexture() error('original fill must remain') end
local crop={60/256,195/256,51/256,211/256}
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(#frames==0,'no rendering work while disabled')
module:SetSchoolSpeed(1,'arcane')
module:Command('arcane')
check(reloads==0 and refreshes==1 and ns.db.char.mageCrystalSchool=='arcane' and module:IsActive(),'Paladin can enable Arcane without a reload')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case_low.tga')
local art=power.MageCrystalArt
local foreground=power.MageCrystalCaseFrame
check(power.Case:GetParent()==foreground and foreground.parent==power,'case uses separate sibling foreground')
check(power:GetFrameLevel()<art:GetFrameLevel() and art:GetFrameLevel()<foreground:GetFrameLevel(),'crystal below energy below case')
check(not foreground.clips and foreground.anchor==power,'case is outside native mana clipping')
check(power.Case.points==casePoints and power.Case.width==123 and power.Case.height==145,'case geometry preserved')
power:SetFrameLevel(20)
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case_low.tga')
check(art.Clip:GetFrameLevel()==21 and art:GetFrameLevel()==22 and foreground:GetFrameLevel()==23,'restyling follows changed native frame level')
check(art.Clip.clips and art.Clip.points[3][2]==power.fill,'clip follows native fill')
check(art.Mask.path=='original.tga' and art.Mask.coords[1]==crop[1],'original mask and crop')
check(art.Pattern.mask==art.Mask and art.Flow.mask==art.Mask,'both textures masked')
check(power.Case.path:find('pw_crystal_case_low.tga',1,true),'low variant retained')
check(art.Flow.path:find('arcane-energy.tga',1,true),'correct atlas')
check(near(art.Flow.coords[1],U(0,crop[1])) and near(art.Flow.coords[2],U(0,crop[2])) and near(art.Flow.coords[4],V(0,crop[4])),'crop mapped into first atlas cell')
art.scripts.OnUpdate(art, 1/16)
check(art.Index==1 and near(art.Flow.coords[1],U(1,crop[1])),'atlas advances with elapsed time')
art.scripts.OnUpdate(art, 8-1/16)
check(art.Index==0,'eight second loop wraps')
check(art.FlowNext.mask==art.Mask and art.FlowNext.path==art.Flow.path,'shared asset and mask for interpolation')
check(art.Flow.blend=='ADD' and art.FlowNext.blend=='ADD','linear additive blend')
art.scripts.OnUpdate(art,1/32)
check(math.abs(art.Flow.alpha-.35)<.00001 and math.abs(art.FlowNext.alpha-.35)<.00001,'halfway crossfade between atlas frames')
local nextAlpha=art.FlowNext.alpha
art.scripts.OnUpdate(art,1/60)
check(art.FlowNext.alpha>nextAlpha and art.Index==0,'alpha changes between frame boundaries at render rate')
art.scripts.OnUpdate(art,8-art.Time)
check(art.Index==0 and art.Flow.alpha==.7 and art.FlowNext.alpha==0,'loop boundary has continuous weights')
art.scripts.OnUpdate(art,127.5/16)
check(art.Index==127 and near(art.FlowNext.coords[1],U(0,crop[1])) and near(art.FlowNext.coords[3],V(0,crop[3])),'last frame blends into first')
art.scripts.OnUpdate(art,1/32)

local count=#frames
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(#frames==count,'repeat styling reuses frames')
for i=1,10 do
	art.scripts.OnUpdate(art,.1)
	module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
end
check(art.Index>=15 and art.Time>.9,'frequent restyling preserves elapsed phase')
check(near(art.Flow.coords[1],U(art.Index,crop[1])),'restyling retains current atlas coordinates')
module:Command('static')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(not art.Flow.shown and not art.FlowNext.shown and not art.scripts.OnUpdate,'static hides both layers and has no animation callback')
module:SetFireSpeed(1)
module:Command('fire')
module:Command('flow')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(art.Energy and art.Flow.path:find('fire-energy.tga',1,true),'Fire uses volumetric atlas')
local fireWrites=art.Flow.textureWrites
check(art.Pattern.alpha==.12 and art.Flow.color[1]==1,'Fire reduces lines and retains authored energy colors')
art.scripts.OnUpdate(art,15.5/16)
check(art.Index==15 and art.Flow.path==art.FlowNext.path and near(art.FlowNext.coords[1],U(16,crop[1])),'interpolation crosses into the next frame on the one atlas')
check(math.abs(art.Flow.alpha-.35)<.00001 and math.abs(art.FlowNext.alpha-.35)<.00001,'Fire sub-frame blend weights')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(art.Index==15 and art.Time==15.5/16,'Fire phase survives restyling')
art.scripts.OnUpdate(art,1/16)
check(art.Index==16 and near(art.Flow.coords[1],U(16,crop[1])) and near(art.Flow.coords[3],V(16,crop[3])),'Fire advances at 16 source frames per second')
art.scripts.OnUpdate(art,127.5/16-art.Time)
check(art.Index==127 and near(art.Flow.coords[3],V(127,crop[3])) and near(art.FlowNext.coords[1],U(0,crop[1])),'last frame blends into first')
art.scripts.OnUpdate(art,.5/16)
check(art.Index==0 and art.Flow.textureWrites==fireWrites,'Fire eight second loop wraps without swapping the file')
-- Walk every sample; UV cells and page indices must stay within eight pages.
for i=1,128 do
	art.scripts.OnUpdate(art,1/16)
	check(art.Flow.path==art.FlowNext.path and art.Flow.textureWrites==fireWrites,'Fire stays on its one atlas')
	check(art.Flow.coords[1]>=0 and art.Flow.coords[2]<=1 and art.Flow.coords[3]>=0 and art.Flow.coords[4]<=1,'Fire cropped UV in range')
end
module:Command('static')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(not art.Energy and not art.Flow.shown and not art.FlowNext.shown and not art.scripts.OnUpdate,'Fire static disables volume animation')
module:Command('frost')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(art.Pattern.path:find('frost-pattern',1,true),'Frost pattern selected')
module:Command('flow')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(art.Flow.shown and art.scripts.OnUpdate,'animation reenabled')
local previous=reloads
module:Command('status')
module:Command('invalid')
check(reloads==previous,'read-only commands do not reload')
combat=true
module:Command('arcane')
check(reloads==previous and ns.db.char.mageCrystalSchool=='frost','combat leaves state intact')
combat=false; variant='Alternate'
module:Command('arcane')
check(reloads==previous and not module:IsActive(),'alternate layout fails closed')
module:Command('off')
check(not ns.db.char.mageCrystalTest,'can disable from alternate layout')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(not art.shown,'inactive content hidden on render hook')
check(power.Case:GetParent()==power and not foreground.shown,'inactive restores original case parent')
variant=''; module:Command('on'); module:OnEnable()
combat=true; variant='Alternate'; module:ProfileChanged()
check(module.event=='PLAYER_REGEN_ENABLED','profile redraw deferred during combat')
combat=false; previous=reloads; local redraws=refreshes; module:ProfileChanged()
check(reloads==previous and refreshes==redraws+1 and not module.event,'profile change redraws after combat without a reload')
check(not module:IsActive(),'alternate layout keeps the crystal off after a profile change')
variant=''; check(module:IsActive(),'main layout brings the crystal back')
-- Live slider uses the existing namespaced options widget, not global skins.
local speedWidget={frame=obj()}
function speedWidget.frame:SetParent(parent) self.parent=parent end
function speedWidget:SetWidth(w) self.width=w end
function speedWidget:SetLabel(label) self.label=label end
function speedWidget:SetSliderValues(a,b,c) self.range={a,b,c} end
function speedWidget:SetIsPercent(percent) self.percent=percent end
function speedWidget:SetCallback(_, callback) self.callback=callback end
function speedWidget:SetValue(value) self.value=value end
LibStub=function() return {Create=function(_,name) check(name=='TestSlider','addon slider reused'); return speedWidget end} end
UIParent=obj(); UISpecialFrames={}
ns.OptionsKit={Prefix='Test',WindowBackdrop={},GetFont=function()return {}end}
local priorCreateFrame=CreateFrame
CreateFrame=function(...)
	local f=priorCreateFrame(...)
	function f:SetSize() end
	function f:SetFrameStrata() end
	function f:SetClampedToScreen() end
	function f:SetMovable() end
	function f:RegisterForDrag() end
	function f:SetBackdrop() end
	function f:IsShown() return self.shown end
	function f:CreateFontString()
		local t=obj()
		function t:SetFontObject() end
		function t:SetText(text) self.text=text end
		return t
	end
	return f
end
variant=''; combat=false; previous=reloads
module:Command('speed')
check(module.speedPanel.shown and speedWidget.value==.4 and speedWidget.percent,'slider opens at default percent')
check(reloads==previous and speedWidget.range[1]==.1 and speedWidget.range[2]==2,'slider range and no reload')
speedWidget.callback(nil,nil,.5)
check(module:GetSchoolSpeed('frost')==.5 and ns.db.char.mageCrystalFrostSpeed==.5 and module:GetFireSpeed()==1,'slider persists character speed live')
module:SetFireSpeed(.5)
module:Command('fire'); module:Command('flow')
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
local phase=art.Time
art.scripts.OnUpdate(art,1)
check(art.Time==(phase+.5)%8,'half speed advances half as far')
phase=art.Time; module:SetFireSpeed(2)
check(art.Time==phase,'speed changes preserve phase')
art.scripts.OnUpdate(art,1)
check(art.Time==(phase+2)%8,'double speed advances twice as far')
module:SetFireSpeed(99); check(module:GetFireSpeed()==2,'maximum speed clamped')
module:SetFireSpeed(-4); check(module:GetFireSpeed()==.1,'minimum speed clamped')
module:SetFireSpeed('bad'); check(module:GetFireSpeed()==.4,'invalid speed default')
module:SetFireSpeed(.65); module:OnInitialize()
check(module:GetFireSpeed()==.65,'saved speed survives initialization')
module:Command('frost'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
phase=art.Time; art.scripts.OnUpdate(art,1)
check(art.Time==(phase+.5)%8,'Fire slider does not alter Frost')
previous=reloads; module:Command('speed')
check(not module.speedPanel.shown and reloads==previous,'speed command toggles panel without reload')
combat=true; module:Command('speed')
check(not module.speedPanel.shown,'opening controls in combat is guarded')
combat=false; variant=''; module:Command('fire'); module:Command('flow'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(#art.Embers==8,'eight bounded embers')
local ember=art.Embers[1]
check(ember.Core.mask==art.Mask and ember.Glow.mask==art.Mask,'particle core and halo share native mask')
check(art.Embers[8].Size>ember.Size and art.Embers[8].Opacity>ember.Opacity,'foreground and background depth')
local life=ember.Life
art.scripts.OnUpdate(art,.25)
check(ember.Life~=life and ember.Core.shown,'particle motion advances independently')
check(ember.Core.alpha>=0 and ember.Core.alpha<=ember.Opacity,'fade stays bounded')
local particleCount=#art.textures
life=ember.Life
module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(ember.Life==life and #art.textures==particleCount,'restyling preserves particles without allocation')
for i=1,600 do art.scripts.OnUpdate(art,1/60) end
check(ember.Life>=0 and ember.Life<1,'particle lifetime loops safely')
local p=ember.Core.points[1]
check(p[2]==power and p[4]>=0 and p[4]<=196 and p[5]>=0 and p[5]<=196,'particle position stays in native canvas')
module:Command('static'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(not ember.Core.shown and not ember.Glow.shown and not art.scripts.OnUpdate,'static hides particles and stops updates')
module:Command('frost'); module:Command('flow'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(ember.Core.shown and ember.Core.color[1]==.65,'Frost has cool particles')
for _,school in ipairs({'frost','arcane'}) do
	module:Command(school); module:SetSchoolSpeed(1,school)
	module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
	check(art.Energy and art.School==school and art.Time==0,'school switch resets correct atlas')
	for i=1,128 do
		art.scripts.OnUpdate(art,1/16)
		check(art.Flow.path:find(school..'-energy.tga',1,true),'correct school atlas')
		check(art.Flow.path==art.FlowNext.path and art.Flow.path:find(school..'-energy.tga',1,true),'school atlas bound')
		check(art.Flow.coords[1]>=0 and art.Flow.coords[2]<=1 and art.Flow.coords[3]>=0 and art.Flow.coords[4]<=1,'school crop bounded')
	end
	check(art.Index==0,'128 frame school loop wraps')
	check(#art.textures==particleCount,'school switches reuse particles')
	module:SetSchoolSpeed(.4,school)
	art.scripts.OnUpdate(art,1)
	check(math.abs(art.Time-.4)<.00001,'school preferred speed applies live')
	module:Command('static'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
	check(not ember.Core.shown and not art.scripts.OnUpdate,'school static stops particles')
	module:Command('flow'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
end
module:Command('speed')
check(speedWidget.value==.4 and module.speedTitle.text:find('Arcane'),'slider selects active school')
speedWidget.callback(nil,nil,.75)
check(module:GetSchoolSpeed('arcane')==.75 and module:GetSchoolSpeed('frost')==.4 and module:GetFireSpeed()==.65,'per school saved speeds independent')
for _,school in ipairs({'fire','frost','arcane'}) do
	for _,mode in ipairs({'static','flow'}) do
		module:Command(school); module:Command(mode)
		module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
		check(power.Case:GetParent()==foreground and art:GetFrameLevel()<foreground:GetFrameLevel(),'all modes keep case above effects')
		check(power.Case.points==casePoints and foreground.shown,'reusing foreground preserves case anchors')
	end
end
-- File bindings stay stable even across repeated styling and the loop seam:
-- both crossfade layers are bound to the school's one atlas.
for _,school in ipairs({'fire','frost','arcane'}) do
	module:Command(school); module:Command('flow'); module:SetSchoolSpeed(.4,school)
	module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
	local layers={art.Flow,art.FlowNext}
	local writes={}
	check(not art.EnergyPages,'no per-page texture pairs')
	for _,texture in ipairs(layers) do
		writes[texture]=texture.textureWrites
		check(texture.path:find(school..'-energy.tga',1,true) and texture.mask==art.Mask,'atlas permanently bound and masked')
	end
	for tick=1,1500 do
		art.scripts.OnUpdate(art,1/30)
		if tick%10==0 then module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga') end
		local alpha=0
		for _,texture in ipairs(layers) do
			check(texture.textureWrites==writes[texture],'no file replacement during playback/restyling')
			alpha=alpha+texture.alpha
		end
		check(math.abs(alpha-.7)<.000001,'no alpha gap during playback')
		check(art.Flow.coords[1]>=0 and art.Flow.coords[2]<=1 and art.Flow.coords[4]<=1,'cell coordinates stay on the page')
	end
	module:Command('static'); module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
	for _,texture in ipairs(layers) do check(not texture.shown and texture.alpha==0,'static hides both layers') end
end
-- With the pages unshipped, a flow setting still draws the static pattern.
module.EnergyAvailable=false; variant=''; combat=false
ns.db.char.mageCrystalFlow=true; module:StyleCrystal(power,'original.tga',crop,'pw_crystal_case.tga')
check(not art.Energy and not art.Flow.shown and not art.FlowNext.shown and not art.scripts.OnUpdate and art.Pattern.alpha==.65,'static pattern while the energy is unshipped')
module:Command('flow'); check(module.message and module.message:find('work in progress',1,true),'flow command says the energy is not in this release')
print('PASS: '..checks..' Mage crystal command/render checks')

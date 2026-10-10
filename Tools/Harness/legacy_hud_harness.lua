-- Real layout data and AceDB exercise; no WoW client rendering is simulated.
local root = arg[1] or '.'
local checks, reloads, combat, variant = 0, 0, false, nil
local function check(v, msg) assert(v, msg); checks = checks + 1 end
ReloadUI = function() reloads = reloads + 1 end
InCombatLockdown = function() return combat end
GetRealmName = function() return 'Realm' end
UnitName = function() return 'Player' end
UnitClass = function() return 'Warrior', 'WARRIOR' end
UnitRace = function() return 'Human', 'Human' end
UnitFactionGroup = function() return 'Alliance' end
GetLocale = function() return 'enUS' end
GetCurrentRegion = function() return 3 end
securecallfunction = function(f, ...) return f(...) end
CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
UIParent = {GetWidth=function()return 1920 end}
local function load(path, ns) return assert(loadfile(root..'/'..path))('AzeriteUI5_JuNNeZ_Edition', ns) end
load('Libs/LibStub/LibStub.lua')
load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
load('Libs/AceDB-3.0/AceDB-3.0.lua')
local color = {1,1,1,1}; setmetatable(color, {__index=function()return color end})
local fonts = {}
local ns = {Prefix='Azerite', Colors=color, API={}, oUF={RegisterInitCallback=function(self,fn)self.init=fn end}}
ns.API.GetEffectiveScale=function()return 1 end
ns.API.GetFont=function(size) fonts[size]=fonts[size] or {GetObjectType=function()return 'Font' end};return fonts[size]end
ns.API.GetMedia=function(name)return 'Interface\\AddOns\\AzeriteUI5_JuNNeZ_Edition\\Assets\\'..name..'.tga'end
function ns:GetActiveConfigVariant() return variant end
function ns:NewModule()return {Print=function()end, RegisterChatCommand=function()end, RegisterEvent=function(self,e)self.event=e end,UnregisterEvent=function(self)self.event=nil end}end
ns.db=LibStub('AceDB-3.0'):New({}, {char={}}, true)
load('Core/API/Tables.lua', ns)
load('Core/LegacyHUD.lua', ns)
load('Layouts/Layouts.lua', ns)
local xml=assert(io.open(root..'/Layouts/Layouts.xml')):read('*a')
for path in xml:gmatch('file="([^"]+)"') do if path~='Layouts.lua' then load('Layouts/'..path:gsub('\\','/'), ns) end end
local H=ns.LegacyHUD
-- Button shapes from the real Assets.lua; keep the font/media stubs above.
local getFont,getMedia=ns.API.GetFont,ns.API.GetMedia
load('Core/API/Assets.lua', ns)
local Shaped=ns.API.GetShapedButtonConfig
ns.API.GetFont,ns.API.GetMedia=getFont,getMedia
local original=ns.GetConfig('PlayerFrame')
local pcfg=ns.GetConfig('PetActionButton');local pcircle=pcfg.ButtonIconSize[1]
local pshape=Shaped(pcfg,'square')
check(pshape~=pcfg and pcfg.ButtonIconSize[1]==pcircle,'pet shape copies, circle config untouched')
check(pshape.ButtonIconSize[1]==45 and pshape.ButtonSize[1]==48 and pshape.ButtonMaskTexture:find('mask%-square%.tga'),'pet square scales to its 48px cell')
check(math.abs(pshape.ButtonBorderSize[1]-96.3*.75)<.001 and pshape.ButtonKeybindPosition[2]==6,'pet border and keybind scale')
check(Shaped(ns.GetConfig('StanceButton'),'rounded').ButtonMaskTexture:find('square%-rounded'),'stance rounded art')
check(Shaped(pcfg,'circle')==pcfg and Shaped(pcfg,'bogus')==pcfg,'circle and unknown keep the shared config')
local ecfg=ns.GetConfig('ExtraActionButton');local eshape=Shaped(ecfg,'square')
check(eshape.ExtraButtonIconSize[1]==60 and eshape.ExtraButtonCooldownSize[1]==60 and eshape.ExtraButtonMask:find('mask%-square%.tga') and eshape.ExtraButtonBorderTexture:find('border%-square%.tga'),'extra button keys shaped')
check(eshape.ButtonMaskTexture==nil and ecfg.ExtraButtonMask:find('circular'),'extra keeps its own keys only')
check(Shaped(ns.GetConfig('ActionButton'),'square').ButtonIconSize[1]==60,'action square unchanged at 64px')
check(ns.API.IsButtonShape('rounded') and not ns.API.IsButtonShape('circle'),'shape names')
check(not H:IsActive(), 'default disabled')
check(H:Command('azerite') and reloads==0, 'stock command idempotent')
check(H:Command(' legacy ') and reloads==1, 'trimmed command activates and reloads')
local cfg=ns.GetConfig('PlayerFrame')
check(cfg~=original and cfg.Size[1]==316 and cfg.Size[2]==86, 'compact player geometry')
check(cfg.HealthBarSize[1]==300 and cfg.HealthBarSize[2]==58, 'original health aperture')
check(cfg.PowerBarSize[1]==300 and cfg.PowerBarSize[2]==12, 'original power aperture')
check(cfg.HealthValueFont==fonts[16], 'WoW font identity preserved')
check(cfg.CombatIndicatorTexture:find('state-grid',1,true) and cfg.CombatIndicatorSize[1]==64 and cfg.CombatIndicatorPosition[1]=='CENTER','3.x combat icon on the player frame')
check(not cfg.Seasonal or cfg.Seasonal.LoveFestivalCombatIndicatorTexture==cfg.CombatIndicatorTexture,'love festival keeps the legacy combat icon')
check(ns.GetConfig('TargetFrame').CombatIndicatorTexture==nil or not ns.GetConfig('TargetFrame').CombatIndicatorTexture:find('state-grid',1,true),'combat icon only on the player')
check(original.Size[1]~=316, 'stock layout not mutated')
check(ns.GetConfig('ActionButton').ButtonSize[1]==54, '54px primary buttons')
check(ns.GetConfig('ExtraActionButton').ExtraButtonSize[1]==56, '56px extra button')
local lcfg=ns.GetConfig('ActionButton');check(Shaped(lcfg,'square')==lcfg,'legacy ignores per-bar shapes')
check(ns.GetConfig('PetFrame').Size[1]==158, 'compact pet')
check(ns.GetConfig('PlayerCastBar').CastBarSize[1]==224, 'central castbar')
for _,layout in pairs(ns.GetConfig('PlayerClassPower').ClassPowerLayouts) do
 if #layout>0 then local last=layout[#layout];check(math.abs(last.Position[2]+last.Size[1]-224)<.001,'class segments fit 224px') end
end
local defaults={profile={savedPosition={'BOTTOM',10,20},hideInCombat=false}}
local stock=ns.db:RegisterNamespace('PlayerFrame', defaults)
stock.profile.savedPosition={'BOTTOM',333,444};stock.profile.hideInCombat=true
local legacy=H:RegisterNamespace('PlayerFrame',H:GetDefaults('PlayerFrame',defaults))
check(legacy.profile.savedPosition[2]==-1170 and legacy.profile.savedPosition[3]==250,'legacy coordinate conversion')
check(legacy.profile.hideInCombat==true,'gameplay setting seeded')
legacy.profile.savedPosition={'BOTTOM',55,66}
check(stock.profile.savedPosition[2]==333,'legacy movement preserves stock')
ns.db:SetProfile('Other')
check(legacy.profile.savedPosition[3]==250 and legacy.profile.legacyHUDSchema==1,'profile switch seeds legacy defaults')
ns.db:SetProfile('Default')
check(legacy.profile.savedPosition[2]==55,'legacy placement survives profile switching')
legacy:ResetProfile()
check(legacy.profile.savedPosition[3]==250,'reset restores compact geometry')
combat=true;local before=reloads;check(H:Command('azerite')==false and H:IsActive() and reloads==before,'combat refuses without mutation')
combat=false;check(H:Command('typo')==false and H:IsActive(),'unknown command safe')
H.loadedActive=true;variant='SaiyaRatt';H:ProfileChanged();check(reloads==before+1,'variant change rebuilds HUD')
check(not H:IsActive() and ns.GetConfig('PlayerFrame').Size[1]~=316,'variant bypasses legacy')
check(H:Command('legacy')==false,'legacy refuses variant')
variant=nil;check(H:Command('azerite') and ns.GetConfig('PlayerFrame')==original,'stock restored')
check(stock.profile.savedPosition[2]==333,'original saved position retained after return')
-- Look-only modules: Legacy corner defaults in their own namespace, main profile untouched.
H:Command('legacy')
local mdef={profile={savedPosition={'BOTTOMRIGHT',-40,40,scale=1},theme='Azerite'}}
local mstock=ns.db:RegisterNamespace('Minimap', mdef);mstock.profile.savedPosition={'BOTTOMRIGHT',-12,34,scale=1}
local mleg=H:RegisterNamespace('Minimap',H:GetDefaults('Minimap',mdef))
check(mleg.profile.savedPosition[1]=='TOPRIGHT' and mleg.profile.savedPosition[2]==-44 and mleg.profile.savedPosition[3]==-54,'legacy minimap corner default')
check(mleg.profile.theme=='Azerite','minimap look setting seeded')
mleg.profile.savedPosition={'TOPRIGHT',-1,-2}
check(mstock.profile.savedPosition[2]==-12 and mstock.profile.savedPosition[1]=='BOTTOMRIGHT','moving legacy minimap keeps main profile')
local tdef={profile={savedPosition={'BOTTOMRIGHT',-319,166}}}
check(H:GetDefaults('Tooltips',tdef).profile.savedPosition[2]==-54 and tdef.profile.savedPosition[2]==-319,'tooltip corner default, original defaults untouched')
H:Command('azerite')
check(ns.db:GetNamespace('Minimap').profile.savedPosition[2]==-12,'return to Azerite restores main minimap position')
-- Owned widgets: styling must not read unit values or native fill dimensions.
local M={}
local function widget(width) return setmetatable({width=width or 158, level=1,shown=true}, {__index=M}) end
function M:GetWidth()return self.width end
function M:GetFrameLevel()return self.level end
function M:SetFrameLevel(v)self.level=v end
function M:EnableMouse(v)self.mouse=v end
function M:SetPoint(...)self.point={...}end
function M:ClearAllPoints()self.point=nil end
function M:SetAllPoints(v)self.all=v end
function M:SetSize(w,h)self.width,self.height=w,h end
function M:SetTexture(v)self.texture=v end
function M:SetStatusBarTexture(v)self.texture=v end
function M:SetVertexColor(...)self.color={...}end
function M:SetBackdrop(v)self.backdrop=v end
function M:SetBackdropBorderColor(...)self.color={...}end
function M:SetAlpha(v)self.alpha=v end
function M:SetShown(v)self.shown=v end
function M:HookScript(name,fn)self.scripts=self.scripts or {};self.scripts[name]=fn end
function M:IsShown()return self.shown end
function M:Show()self.shown=true end
function M:Hide()self.shown=false end
function M:SetOrientation(v)self.orientation=v end
function M:SetReverseFill(v)self.reverse=v end
function M:CreateTexture()return widget()end
function M:CreateBar()return widget()end
function M:EnableElement(name)self.enabledElement=name end
CreateFrame=function(_,_,parent)local w=widget();w.parent=parent;return w end
hooksecurefunc=function(object,name,callback)local prev=object[name];object[name]=function(self,...)prev(self,...);callback(self,...)end end
ns.db.char.legacyHUD=true
local pet=widget();pet.style=ns.Prefix..'Pet';pet.Health=widget()
ns.oUF.init(pet)
check(pet.LegacyBorder and pet.Power.width==142 and pet.Power.height==8,'pet gets compact power widget')
check(pet.LegacyBorder.backdrop.edgeSize==32 and pet.LegacyBorder.point[2]==15,'small frame casing: 3.x hex_small 32 at 15px out')
check(pet.Power.orientation=='HORIZONTAL' and pet.enabledElement=='Power','native power element enabled')
pet.Power:SetOrientation('VERTICAL');H:RefreshUnit(pet)
check(pet.Power.orientation=='HORIZONTAL','native tier refresh cannot restore crystal orientation')
function M:GetParent()return self.parent end
local target=widget(316);target.style=ns.Prefix..'Target';target.Health=widget();target.Portrait=widget();target.Portrait.parent=widget()
ns.oUF.init(target);check(target.Portrait.alpha==0 and not target.Portrait.parent.shown,'target portrait holder hidden: 3D model and 2D fallback')
check(target.LegacyBorder.backdrop.edgeSize==32 and target.LegacyBorder.point[2]==3,'large frame casing unchanged at 3px')
function M:SetParent(v)self.parent=v end
local named=widget(158);named.style=ns.Prefix..'ToT';named.Health=widget();named.Overlay=widget();named.Name=widget();named.Name.parent=named
ns.oUF.init(named);check(named.Name.parent==named.Overlay,'name lifted above the health bar')
local plate=widget();plate.Health=widget();plate.isNamePlate=true;plate.style=ns.Prefix..'Target'
ns.oUF.init(plate);check(not plate.LegacyBorder and not plate.Power,'nameplates untouched')
local cast=widget();cast.style=ns.Prefix..'PlayerCastBar';cast.Castbar=widget(224);cast.Castbar.Shield=widget()
ns.oUF.init(cast);check(cast.Castbar.LegacyBorder.backdrop.edgeSize==32,'original cast border sizing')
check(cast.Castbar.KeepBackdrop==true and cast.Castbar.Shield.alpha==0,'no shield casing: backdrop kept on protected casts')
local class=widget();class.style=ns.Prefix..'PlayerClassPower';class.ClassPower=widget(224)
ns.oUF.init(class);check(class.ClassPower.LegacyBorder,'classpower casing inherits element visibility')
local button=widget(54);button.iconBorder=widget();button.Border=widget();button.Border:Hide()
H:StyleButton(button);button.iconBorder:Hide();check(not button.LegacyBorder.shown,'border toggle hides original casing')
button.iconBorder:Show();check(button.LegacyBorder.shown,'border toggle restores casing')
check(not button.Border.shown,'casing ignores the hidden Blizzard equipped-item Border')
local hl={.9,.8,.5};ns.Colors.highlight=hl;button.scripts.OnEnter();check(button.LegacyBorder.color[1]==.9,'hover lights the casing')
button.scripts.OnLeave();check(button.LegacyBorder.color[1]~=.9,'leaving restores the casing colour')
-- Aura borders: Legacy art, 16px edge, 1px further out, 3.x neutral grey.
function M:SetTexCoord(...)self.coords={...}end
function M:SetHeight(v)self.height=v end
function M:SetWidth(v)self.width=v end
ns.IsRetail=true;ns.AuraData={Spells={},Hidden={},Priority={}};ns.AuraStyles=nil
ns.Colors.verydarkgray={69/255,59/255,49/255};ns.Colors.ui={.75,.75,.75}
ns.API.GetMedia=function(name)return H:ResolveMedia(name) or ('Assets/'..name..'.tga')end
load('Components/UnitFrames/Auras/AuraStyling.lua', ns)
local ab=ns.AuraStyles.CreateTextureBorder(widget(30));local tl=ab.__AzeriteUI_BorderPieces[1]
check(tl.texture:find('aura_border',1,true) and tl.width==16 and tl.point[2]==-1 and tl.coords[1]==.5,'legacy aura border art, edge, outset, uncropped')
ab:SetBackdropBorderColor(unpack(ns.Colors.verydarkgray));check(math.abs(tl.color[1]-.225)<.001,'legacy neutral aura grey')
ab:SetBackdropBorderColor(.8,0,0);check(tl.color[1]==.8,'debuff colours pass through')
ns.db.char.legacyHUD=false
local mb=ns.AuraStyles.CreateTextureBorder(widget(30));local mtl=mb.__AzeriteUI_BorderPieces[1]
check(mtl.texture:find('Assets/border-aura',1,true) and mtl.width==12 and mtl.point[2]==0 and mtl.coords[1]==0.5078125,'azerite aura border unchanged')
mb:SetBackdropBorderColor(unpack(ns.Colors.verydarkgray));check(mtl.color[1]==69/255,'azerite neutral unchanged')
ns.db.char.legacyHUD=true
C_UI={Reload=function()reloads=reloads+1 end};local before=reloads
H:Command('azerite');check(reloads==before+1,'namespace reload API used when available')
-- Retail runs WoW11/ActionBars/ActionBars.lua's delayed init. It must take the Legacy
-- path too: registering the main namespace with Legacy defaults let AceDB strip the
-- player's Azerite values that matched them (fading, growth, anchor) at logout.
H:Command('legacy');ns.WoW11=true;ns.API.IsAddOnEnabled=function()return false end
local abar={GetName=function()return 'ActionBars' end,SetEnabledState=function()end,RegisterEvent=function()end,UnregisterEvent=function()end,Enable=function()end}
abar.GetDefaults=function(self)return H:GetDefaults('ActionBars',{profile={bars={{enableBarFading=true,growth='horizontal',savedPosition={'BOTTOMLEFT',1,2}},{enableBarFading=true,savedPosition={'BOTTOMLEFT',3,4}},{growth='vertical',savedPosition={'RIGHT',5,6}}}}})end
ns.GetModule=function(_,name)return name=='ActionBars' and abar or {Enable=function()end}end
load('WoW11/ActionBars/ActionBars.lua',ns);abar:DelayedEnable()
check(abar.db==ns.db:GetNamespace('LegacyHUD_ActionBars',true),'retail delayed action bar init uses the Legacy namespace')
local mainBars=ns.db:GetNamespace('ActionBars').defaults.profile.bars
check(mainBars[1].enableBarFading==true and mainBars[3].growth=='vertical','main action bar namespace keeps Azerite defaults')
local cb=H:GetDefaults('PlayerCastBarFrame',{profile={savedPosition={'CENTER',1,2}}}).profile.savedPosition
check(cb[1]=='BOTTOM' and cb[3]==230,'castbar module name gets the Legacy namespace and 3.x spot')
print('Legacy HUD: '..checks..' checks passed (real layouts and AceDB; offline only).')

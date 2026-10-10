-- Real module/options, reusing the styling harness's sealed Blizzard items.
-- lua Tools/Harness/cooldown_ready_harness.lua . [mutation|--taint]
-- Elune checks Lua taint only; synthetic widgets cannot prove client secrecy.
local root, mutation = arg[1] or ".", arg[2]
local taint = mutation == "--taint"
if taint then mutation = nil end
local changes = {
 ["inspect-no-sink"] = {'return debug:PrintDiagnostic(...)', 'print(...)'},
 ["default-on"] = {"readyEssential = false", "readyEssential = true"},
 ["no-gate"] = {"or not (self.db.profile.readyEssential or self.db.profile.readyUtility)", "or false"},
 ["gcd"] = {"state.spellID, true)", "state.spellID, false)"},
 ["initial-ready"] = {"state.active == true and shown == false", "shown == false"},
 ["repeat"] = {"state.active = shown", "state.active = true"},
 ["secret-shown"] = {"or IsSecret(shown)", ""},
 ["nil-ready"] = {"state.fed, state.active = nil, nil", "state.fed = true"},
 ["feed-ready"] = {"if (not state.fed) then state.active = nil end", "state.fed = true"},
 ["slot-reset"] = {"if (changed) then ResetReady(state); state.spellID = spellID end", "if (changed) then state.spellID = spellID end"},
 ["released"] = {"if (not seen[item]) then ResetReady(state) end", ""},
 ["charges"] = {'if (type(charges) ~= "boolean")', "if (charges ~= false)"},
 ["unknown-charges"] = {'if (type(charges) ~= "boolean")', "if (false)"},
 ["no-charge-event"] = {'controller:RegisterEvent("SPELL_UPDATE_CHARGES")', "do end"},
 ["charge-event-capability"] = {'if (ns.API.IsEventAvailable("SPELL_UPDATE_CHARGES"))', "if (true)"},
 ["late-poll"] = {"accumulated >= .1", "accumulated >= 1"},
 ["base-first"] = {"local spellID = info.overrideSpellID", "local spellID = info.spellID"},
 ["off-events"] = {"self.readyController:UnregisterAllEvents()", ""},
 ["off-update"] = {'self.readyController:SetScript("OnUpdate", nil)', ""},
 ["circle-art"] = {'style.circular and "actionbutton-spellhighlight"', 'style.circular and "actionbutton-spellhighlight-square-rounded"'},
 ["sound-off"] = {"self.db.profile.readySound and self:IsReadySoundAvailable()", "self:IsReadySoundAvailable()"},
 ["no-sound"] = {"soundKitID = 8959", "soundKitID = 0"},
 ["no-event"] = {'controller:RegisterEvent("SPELL_UPDATE_COOLDOWN")', ""},
 ["no-poll"] = {"self:ScanReadyAlerts(false)", "do end"},
 ["loose-square"] = {"icon = 1.14, deco = (216 / 118) / 1.14", "icon = 1, deco = 216 / 118"},
 ["loose-rounded"] = {"icon = 1.18, deco = (216 / 118) / 1.18", "icon = 1, deco = 216 / 118"},
 ["no-border-flash"] = {"state.borderFlash:Show()", "state.borderFlash:Hide()"},
 ["small-outline"] = {"size * 158 / 132, size * 158 / 132", "size, size"},
 ["short-square-pulse"] = {"style.circular and .8 or 1.2", "style.circular and .8 or .8"},
 ["no-hold"] = {"style.circular and .8 or .95", "style.circular and .8 or 1.2"},
 ["circle-flash"] = {"state.borderFlash:Hide()", "state.borderFlash:Show()", "pulse"},
 ["dark-flash"] = {"borderFlash:SetColorTexture(1, .85, .45, 1)", "borderFlash:SetColorTexture(.1, .1, .1, 1)"},
 ["unmasked-flash"] = {"borderFlash:AddMaskTexture(borderMask)", "do end"},
 ["stale-level"] = {"state.pulse:SetFrameLevel(skin.decor:GetFrameLevel() + 1)", "do end"},
 ["wrong-mask"] = {"StyleArt(style, style.border, self:GetSkin()), ", "StyleArt(style, style.mask, self:GetSkin()), "},
 ["no-icon-flash"] = {"state.iconFlash:Show()", "state.iconFlash:Hide()"},
 ["outline-icon-mask"] = {"StyleArt(style, style.mask, self:GetSkin()), ", 'StyleArt(style, "actionbutton-spellhighlight-square-rounded", self:GetSkin()), ', "pulse"},
 ["hidden-icon-mask"] = {"state.iconMask:Show()", "state.iconMask:Hide()"},
 ["stale-strata"] = {"state.pulse:SetFrameStrata(skin.decor:GetFrameStrata())", "do end"},
 ["preview-sound"] = {"not silent and self.db.profile.readySound", "self.db.profile.readySound"},
 ["preview-combat"] = {"if (IsSecret(combat) or combat)", "if (false)"},
 ["preview-dev"] = {"if (not IsDevelopmentMode()) then DebugPrint", "if (false) then DebugPrint"},
 ["preview-cleanup"] = {'self.readyPreviewController:SetScript("OnUpdate", nil)', "do end"},
 ["inspect-secret"] = {'if (IsSecret(value)) then return "<secret>" end', 'if (false) then return "<secret>" end'},
 ["writes-blizzard"] = {"seen[item] = true", "seen[item] = true; item.ReadyAlert = state"},
}
local function mutate(source)
 if not mutation then return source end
 local m = assert(changes[mutation], "unknown mutation")
 local offset=1
 if m[3]==true then
  local first,last=source:find(m[1],1,true);assert(first,"first geometry entry")
  offset=last+1
 elseif m[3]=="pulse" then offset=assert(source:find("local PulseReady",1,true)) end
 local a,b = source:find(m[1],offset,true); assert(a,"mutation did not apply")
 return source:sub(1,a-1)..m[2]..source:sub(b+1)
end
local file = assert(io.open(root.."/Tools/Harness/cooldown_manager_harness.lua","rb"))
local seed = file:read("*a"):gsub("\r\n","\n"); file:close()
local function insertBefore(anchor, code)
 local a=assert(seed:find(anchor,1,true),anchor)
 seed=seed:sub(1,a-1)..code.."\n"..seed:sub(a)
end
insertBefore("local inCombat = false", [[
local w = { durations = {}, sounds = {}, ignored = {}, reads = 0 }
function Region:GetWidth() return self.width or (self.points and self.points.all and self.points.all:GetWidth()) or 0 end
function Region:GetHeight() return self.height or (self.points and self.points.all and self.points.all:GetHeight()) or 0 end
function Region:GetNumMaskTextures() local n=0;for _ in pairs(self.masks or {}) do n=n+1 end;return n end
local createTexture=Frame.CreateTexture
function Frame:CreateTexture(name,layer,...)
 local texture=createTexture(self,name,layer,...);texture.parent=self;texture.drawLayer=layer;return texture
end
function Frame:GetFrameStrata() return self.strata or "MEDIUM" end
function Frame:SetFrameStrata(strata) self.strata=strata end
function Frame:GetEffectiveScale() return self.scale or 1 end
function Region:SetColorTexture(...) self.solidColor = {...}; self.texture = nil end
function Frame:CreateMaskTexture()
 local mask = self:CreateTexture(); mask.kind = "MaskTexture"; return mask
end
function Region:SetBlendMode(mode) self.blend = mode end
function Frame:IsVisible() return self.shown end
function Frame:SetScript(key, fn) self.scripts = self.scripts or {}; self.scripts[key] = fn end
function Frame:RegisterEvent(key) self.events = self.events or {}; self.events[key] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetCooldownFromDurationObject(duration, clear)
 assert(clear, "clear zero duration")
 if w.feedError then error("feed refused") end
 self.duration = duration
 self.shown = duration == w.opaqueDuration and w.opaqueActive or duration.active
end
function Frame:IsShown()
 if self.kind == "Cooldown" and self.parent == UIParent then
  if w.shownError then error("read refused") end
  if w.secretShown then w.secretRead = true; return false end
 end
 return self.shown
end
_G.C_Spell = { GetSpellCooldownDuration = function(id, ignore)
 w.reads = w.reads + 1; w.ignored[#w.ignored+1] = ignore
 if w.getError then error("getter refused") end
 return w.durations[id]
end }
_G.C_Sound = { PlaySoundWithOptions = function(params)
 assert(params.soundKitID == 8959 and params.forceNoDuplicates, "sound params")
 w.sounds[#w.sounds+1] = params
 return true, 10
end }
]])
insertBefore("local enabledAddons = {}", [[
local oldSecret = _G.issecretvalue
_G.issecretvalue = function(value)
 local secretRead = w.secretRead; w.secretRead = nil
 return oldSecret(value) or (secretRead and value == false) or (w.opaqueDuration ~= nil and value == w.opaqueDuration)
end
]])
seed=seed:gsub("local original = source", "source = mutateReady(source)\n\tlocal original = source",1)
insertBefore("-- Nothing written into Blizzard's item tables.", [[
-- Readiness assertions run in both client-shaped fixtures, against real options.
-- Real TGA alpha apertures at the center line, not invented fixture geometry.
local function ArtSpans(name)
 local f=assert(io.open(root.."/Assets/"..name..".tga","rb"))
 local data=f:read("*a");f:close()
 local function word(i) return data:byte(i)+256*data:byte(i+1) end
 local width,height=word(13),word(15)
 assert(data:byte(3)==2 and data:byte(17)==32,"uncompressed RGBA TGA")
 local start,spans=nil,{}
 for x=0,width do
  local alpha=x<width and data:byte(18+data:byte(1)+4*(math.floor(height/2)*width+x)+4) or 0
  if alpha>=128 and not start then start=x end
  if alpha<128 and start then spans[#spans+1]={start,x-1};start=nil end
 end
 return width,spans
end
local function CheckPaintCoverage(style, factor, nominal, flash, label)
 local suffix=style=="rounded" and "-rounded" or ""
 local function read(name)
  local f=assert(io.open(root.."/Assets/"..name..".tga","rb"));local d=f:read("*a");f:close()
  local w=d:byte(13)+256*d:byte(14);local h=d:byte(15)+256*d:byte(16)
  local function pixel(x,y)
   local offset=18+d:byte(1)+4*(y*w+x)+1
   local b,g,r,a=d:byte(offset,offset+3);return math.max(r,g,b)*a/255,a
  end
  return w,h,pixel
 end
 local _,_,border=read("actionbutton-border-square"..suffix)
 local _,_,mask=read("actionbutton-mask-square"..suffix)
 local deco=nominal*216/118
 local worst=-math.huge
 for axis=1,2 do
  for row=76,179 do
   local metal,fill
   for x=0,127 do
    local paint=axis==1 and border(x,row) or border(row,x)
    if paint>=10 then metal=x end
   end
   local mapped=math.floor(32+(row+.5-128)*deco/256*64/(nominal*factor))
   for x=0,63 do
    local _,alpha
    if axis==1 then _,alpha=mask(x,mapped) else _,alpha=mask(mapped,x) end
    if alpha>=240 and not fill then fill=x end
   end
   assert(metal and fill,"painted contour exists")
   local gap=(fill-32)*nominal*factor/64-(metal+.5-128)*deco/256
   worst=math.max(worst,gap)
  end
 end
 check(worst<=-.1,label.." painted contours overlap at "..nominal.."px")
 local _,center=mask(32,32)
 check(center==255 and flash.shown,label.." flash covers opaque icon center")
end
local function ReadyTests(flavor)
 if flavor == "Forever" then M = Load(); M:OnEnable() end
 local e = essential.active[1]
 local u = viewers.UtilityCooldownViewer.active[1]
 Data(e).cooldownInfo = {spellID=20271, charges=false}
 Data(u).cooldownInfo = {spellID=403876, charges=false}
 w.durations[20271], w.durations[403876] = {active=false}, {active=false}
 w.sounds, w.ignored, w.reads = {}, {}, 0
 check(M.db.profile.readyEssential == false and M.db.profile.readyUtility == false
  and M.db.profile.readySound == false, flavor.." all defaults off")
 check(not M.readyController and not M.readyStates and w.reads==0, flavor.." dormant resources")
 local opts = assert(generate()).args.readyAlerts.args
 check(opts.readySound.disabled(), flavor.." sound disabled without viewer")
 opts.readyEssential.set({"readyEssential"},true)
 local controller = M.readyController
 check(controller and controller.events.SPELL_UPDATE_COOLDOWN and controller.events.SPELL_UPDATE_CHARGES, flavor.." own events")
 check(M.readyStates[e] and not M.readyStates[u], flavor.." Essential only")
 local state = M.readyStates[e]
 check(state and not state.pulse.shown, flavor.." no initial-ready pulse")
 if not state then error("no state") end
 local function update(elapsed)
  if controller.scripts.OnUpdate then controller.scripts.OnUpdate(controller,elapsed or .11) end
 end
 local function event()
  if controller.events.SPELL_UPDATE_COOLDOWN then controller.scripts.OnEvent(controller,"SPELL_UPDATE_COOLDOWN",SECRET,SECRET) end
 end
 local function active() w.durations[state.spellID]={active=true}; event() end
 local function complete() w.durations[state.spellID]={active=false}; event() end
 local function quiet() state.pulse:Hide(); state.remaining=nil end
 local function cycle() active(); complete() end
 check(state.cooldown.parent==UIParent and state.cooldown.alpha==0, flavor.." invisible own widget")
 check(state.pulse.parent.parent==e and state.pulse.level > state.pulse.parent.level, flavor.." own glow layer above border")
 inCombat=true; active()
 check(state.active==true and not state.pulse.shown, flavor.." combat cooldown started")
 complete()
 check(state.pulse.shown and state.remaining==1.2 and #w.sounds==0, flavor.." combat transition pulses silently")
 check(state.glow.texture==Assets("actionbutton-spellhighlight-square-rounded"), flavor.." rounded glow")
 update(.2);check(state.pulse.alpha==1, flavor.." holds full brightness")
 update(.25);check(state.pulse.alpha<1 and state.pulse.alpha>0, flavor.." fades after hold")
 update(1);check(not state.pulse.shown, flavor.." pulse stops")
 event();update();check(not state.pulse.shown,flavor.." repeated idle does not pulse")
 active();state.cooldown.shown=false;update()
 check(state.pulse.shown,flavor.." poll observes native expiry without callback/event")
 quiet(); w.durations[20271]={active=false};event()
 for _,ignore in ipairs(w.ignored) do check(ignore==true,flavor.." GCD excluded") end
 for _,style in ipairs({"square","rounded","circular"}) do
  M.db.profile.iconStyle=style;M:UpdateSettings()
  local decor=state.pulse.parent
  decor:SetFrameLevel(decor:GetFrameLevel()+10)
  decor:SetFrameStrata("HIGH")
  cycle()
  check(state.pulse.level==decor:GetFrameLevel()+1,flavor.." pulse level refreshed after pooling")
  check(state.pulse.strata==decor:GetFrameStrata(),flavor.." pulse inherits current strata")
  local factor=style=="square" and 1.14 or style=="rounded" and 1.18 or .72
  local icon=Data(e).Icon
  check(state.iconFlash.points.all==icon and state.iconMask.points.all==state.iconFlash
   and state.iconFlash.masks[state.iconMask] and state.iconMask.shown and state.iconFlash.shown,
   flavor.." full icon layer uses visible shape mask")
  check(state.iconFlash.solidColor[4]==.5,flavor.." wash retains icon details")
  check(state.iconFlash.parent==state.pulse and state.iconFlash.drawLayer=="ARTWORK"
   and state.glow.drawLayer=="OVERLAY",flavor.." icon wash below outer accent on owned foreground frame")
  -- Only borders go through the theme (cooldown_manager_harness GetMedia); masks and glows stay shared.
  local expectedMask=style=="circular" and Assets("actionbutton-mask-circular") or Assets("actionbutton-mask-"..style:gsub("rounded","square-rounded"))
  check(state.iconMask.texture==expectedMask,flavor.." full icon uses fill mask not outline")
  local wanted=style=="circular" and Assets("actionbutton-spellhighlight") or Assets("actionbutton-spellhighlight-square-rounded")
  check(state.glow.texture==wanted,flavor.." "..style.." art")
  if style=="circular" then
   check(not state.borderFlash.shown and state.duration==.8,flavor.." circular effect unchanged")
   check(math.abs(state.glow.width-36*134.295081967/44)<.01,flavor.." circular ring geometry unchanged")
  else
   local suffix=style=="rounded" and "-rounded" or ""
   local size=50*216/118
   check(state.borderFlash.shown and state.borderMask.texture=="THEMED:actionbutton-border-square"..suffix,flavor.." full metal flashes")
   local color=state.borderFlash.solidColor
   check(color and color[1]==1 and color[2]==.85 and color[3]==.45 and color[4]==1,flavor.." bright color independent of dark metal RGB")
   check(state.borderFlash.masks and state.borderFlash.masks[state.borderMask]
    and state.borderMask.points.all==state.borderFlash,flavor.." full flash masked to border silhouette")
   check(math.abs(state.borderFlash.width-size)<.01 and state.borderFlash.blend=="ADD",flavor.." flash fits border")
   check(math.abs(state.glow.width-size*158/132)<.01,flavor.." outline follows outer metal")
   check(state.duration==1.2 and state.fadeDuration==.95,flavor.." longer square pulse")
   check(math.abs(icon.width-50*factor)<.01,flavor.." fill expands while outer casing stays fixed")
   for _,nominal in ipairs({30,40,50,70}) do CheckPaintCoverage(style,icon.width/50,nominal,state.iconFlash,flavor.." "..style) end
  end
  update(1.3)
 end
 opts.readySound.set({"readySound"},true); cycle()
 check(#w.sounds==1,flavor.." opt-in sound")
 quiet();active();w.secretShown=true;complete();w.secretShown=nil;event()
 check(not state.pulse.shown and #w.sounds==1,flavor.." secret shown invalidates transition")
 active();w.shownError=true;complete();w.shownError=nil;event()
 check(not state.pulse.shown,flavor.." unreadable shown invalidates transition")
 active();w.durations[20271]=nil;event();w.durations[20271]={active=false};event()
 check(not state.pulse.shown,flavor.." nil duration is unknown")
 active();w.feedError=true;complete();w.feedError=nil;event()
 check(not state.pulse.shown,flavor.." failed feed is unknown")
 active();w.getError=true;complete();w.getError=nil;event()
 check(not state.pulse.shown,flavor.." failed getter is unknown")
 w.opaqueDuration=setmetatable({}, {__tostring=function() error("secret printed") end,
  __index=function() error("secret inspected") end})
 w.opaqueActive=true;w.durations[20271]=w.opaqueDuration;event()
 check(state.cooldown.duration==w.opaqueDuration and state.active==true,flavor.." opaque duration passed directly")
 w.opaqueDuration=nil;w.durations[20271]={active=false};event();quiet()
 active();Data(e).cooldownInfo={spellID=403876,charges=false};event()
 check(state.spellID==403876 and not state.pulse.shown,flavor.." recycled spell starts fresh")
 Data(e).cooldownInfo={spellID=20271,overrideSpellID=403876,charges=false};event()
 check(state.spellID==403876,flavor.." override first")
 active();Data(e).shown=false;update();Data(e).shown=true;w.durations[403876]={active=false};event()
 check(not state.pulse.shown,flavor.." hidden slot reset")
 active();local saved=essential.active[1];essential.active[1]=nil;update()
 essential.active[1]=saved;w.durations[403876]={active=false};event()
 check(not state.pulse.shown,flavor.." released slot reset")
 -- IDs are metadata fixtures, not claims about learned spells/talents on a client.
 -- Cross both flags, both viewers, override mapping and both recovery events.
 opts.readyUtility.set({"readyUtility"},true)
 for _,item in ipairs({e,u}) do
  for _,id in ipairs({403876,1044,6940,20271,184575,255937,375576,190784}) do
   for _,charges in ipairs({false,true}) do
    for _,eventName in ipairs({"SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES"}) do
     Data(item).cooldownInfo={spellID=id+1000000,overrideSpellID=id,charges=charges}
     w.durations[id]={active=false};event()
     local tested=M.readyStates[item]
     check(tested and tested.spellID==id and not tested.pulse.shown,flavor.." mapped initial idle "..id)
     local function dispatch()
      if controller.events[eventName] then controller.scripts.OnEvent(controller,eventName,SECRET) end
     end
     w.durations[id]={active=true};dispatch()
     check(tested.active==true and not tested.pulse.shown,flavor.." observed start "..id.." "..eventName)
     w.durations[id]={active=false};dispatch()
     check(tested.pulse.shown,flavor.." ordinary recovery "..id.." "..eventName)
     tested.pulse:Hide();tested.remaining=nil;dispatch();update()
     check(not tested.pulse.shown,flavor.." no repeated recovery "..id)
    end
   end
  end
 end
 opts.readyUtility.set({"readyUtility"},false)
 Data(u).cooldownInfo={spellID=403876,charges=false}
 Data(e).cooldownInfo={spellID=20271,charges=true};w.durations[20271]={active=false};event()
 check(not state.pulse.shown,flavor.." charge-capable but ordinary timer idle does not flash")
 active();state.cooldown.shown=false;update(.101)
 check(state.pulse.shown,flavor.." native expiry detected within one 100 ms poll")
 quiet();w.durations[20271]={active=false};event()
 -- Unsupported charge event never registered; ordinary cooldowns remain usable.
 local eventAvailable=ns.API.IsEventAvailable
 ns.API.IsEventAvailable=function(name) return name~="SPELL_UPDATE_CHARGES" end
 M:UpdateReadyAlerts()
 check(controller.events.SPELL_UPDATE_COOLDOWN and not controller.events.SPELL_UPDATE_CHARGES,flavor.." missing charge event capability")
 cycle();check(state.pulse.shown,flavor.." ordinary alerts survive missing charge event")
 quiet();ns.API.IsEventAvailable=eventAvailable;M:UpdateReadyAlerts()
 for _,unknown in ipairs({{},"true",1}) do
  Data(e).cooldownInfo={spellID=20271,charges=unknown};event()
  check(state.spellID==nil and not state.pulse.shown,flavor.." malformed charge flag skipped")
 end
 Data(e).cooldownInfo={spellID=20271};event()
 check(state.spellID==nil,flavor.." missing charge flag skipped")
 Data(e).cooldownInfo={spellID=SECRET,charges=false};event()
 check(state.spellID==nil,flavor.." secret spell skipped")
 Data(e).cooldownInfo={spellID=20271,charges=SECRET};event()
 check(state.spellID==nil,flavor.." secret charge flag skipped")
 Data(e).cooldownInfo={spellID=20271,charges=false};event()
 opts.readyUtility.set({"readyUtility"},true)
 check(M.readyStates[u]~=nil,flavor.." Utility selectable")
 opts.readyEssential.set({"readyEssential"},false)
 check(state.spellID==nil and M.readyStates[u].spellID==403876,flavor.." independent selection")
 opts.readyUtility.set({"readyUtility"},false)
 check(not next(controller.events) and not controller.scripts.OnUpdate and not controller.scripts.OnEvent,
  flavor.." off unregisters and stops updates")
 check(not state.pulse.shown and not state.cooldown.shown,flavor.." off clears own visuals")
 local count=#frameLogAll;M:UpdateSettings();check(#frameLogAll==count,flavor.." disabled builds nothing")
 local logs={};local oldPrint=print;print=function(...) local line={};for i=1,select("#",...) do line[i]=tostring(select(i,...)) end;logs[#logs+1]=table.concat(line," ") end
 local function contains(text) for _,line in ipairs(logs) do if line:find(text,1,true) then return true end end;return false end
 ns.db.global=nil;inCombat=false;local before=#frameLogAll;M:DebugReadyAlerts("preview")
 check(#frameLogAll==before and not M.readyPreviews,flavor.." preview development gate")
 ns.db.global={enableDevelopmentMode=true};inCombat=true;M:DebugReadyAlerts("preview")
 check(#frameLogAll==before and not M.readyPreviews,flavor.." preview combat gate")
 inCombat=false;Data(e).cooldownInfo={spellID=20271,charges=true};M.db.profile.readySound=true
 M:DebugReadyAlerts("inspect")
 check(#frameLogAll==before and contains("reason=eligible") and contains("selected=false"),flavor.." inspect reports charge-capable eligibility and selection without allocating")
 Data(e).cooldownInfo={spellID=SECRET,charges=SECRET};logs={};M:DebugReadyAlerts("inspect")
 check(contains("base=<secret>") and contains("charges=<secret>"),flavor.." inspect sanitizes secret metadata")
 Data(e).cooldownInfo={spellID=20271,charges=true};local sounds=#w.sounds;local activeBefore=state.active
 M.db.profile.iconStyle="rounded";M:UpdateSettings();M:DebugReadyAlerts("preview")
 check(math.abs(Data(u).Icon.width-30*1.18)<.01 and math.abs(M.readyPreviews[u].borderFlash.width-30*216/118)<.01,
  flavor.." Utility uses its own 30px fill and fixed casing")
 check(M.readyPreviews[u].iconFlash.points.all==Data(u).Icon,flavor.." Utility preview covers its own icon")
 check(contains("DRAWING TEST ONLY") and M.readyPreviews[e].pulse.shown,flavor.." preview draws charge-capable icon independently")
 check(#w.sounds==sounds and state.active==activeBefore and not controller.scripts.OnUpdate,flavor.." preview has no sound or readiness state/event engine")
 local previewCount=#frameLogAll;M:DebugReadyAlerts("preview")
 check(#frameLogAll==previewCount,flavor.." preview reuses owned layers")
 local previewController=M.readyPreviewController
 previewController.scripts.OnUpdate(previewController,2)
 check(not previewController.scripts.OnUpdate and not M.readyPreviews[e].pulse.shown,flavor.." preview expires and removes update handler")
 M:DebugReadyAlerts("preview");M:UpdateSettings()
 check(not previewController.scripts.OnUpdate and not M.readyPreviews[e].pulse.shown,flavor.." settings cancel preview")
 M:DebugReadyAlerts("preview");M:OnDisable()
 check(not previewController.scripts.OnUpdate,flavor.." module disable cancels preview")
 local originalGetModule=ns.GetModule;local sinkLines={}
 ns.GetModule=function(_,name,...) if name=="Debugging" then return {PrintDiagnostic=function(_,...) local parts={};for i=1,select("#",...) do parts[i]=tostring(select(i,...)) end;sinkLines[#sinkLines+1]=table.concat(parts," ") end} end;return originalGetModule(ns,name,...) end
 local chatBefore=#logs;M:DebugReadyAlerts("inspect")
 check(#sinkLines>0 and #logs==chatBefore,flavor.." inspection uses shared diagnostic sink exclusively")
 ns.GetModule=originalGetModule
 print=oldPrint;ns.db.global=nil;M.db.profile.readySound=false;Data(e).cooldownInfo={spellID=20271,charges=false}

 opts.readyEssential.set({"readyEssential"},true)
 check(not state.pulse.shown,flavor.." reenable does not invent completion")
 M.db.profile.styleIcons=false;M:UpdateSettings()
 check(not controller.scripts.OnUpdate and opts.readyEssential.disabled(),flavor.." styling off stops feature")
 M.db.profile.styleIcons=true;M.rival="ArcUI";M:UpdateSettings()
 check(not controller.scripts.OnUpdate and opts.readyEssential.disabled(),flavor.." other owner stands down")
 M.rival=nil;M.sharedWith="ArcUI";M:UpdateSettings()
 check(controller.scripts.OnUpdate and not opts.readyEssential.disabled(),flavor.." Both permits alerts")
 M.sharedWith=nil
 local getter=C_Spell.GetSpellCooldownDuration;C_Spell.GetSpellCooldownDuration=nil;M:UpdateSettings()
 check(not controller.scripts.OnUpdate and opts.readyEssential.disabled() and not opts.unavailable.hidden(),flavor.." missing API disables and explains")
 C_Spell.GetSpellCooldownDuration=getter
 local sound=C_Sound;C_Sound=nil
 check(opts.readySound.disabled() and not opts.soundUnavailable.hidden(),flavor.." missing sound disables and explains")
 C_Sound=sound;M:UpdateSettings();M:OnDisable()
 check(not controller.scripts.OnUpdate and not next(controller.events),flavor.." module disable cleanup")
 local created=#frameLogAll
 local maskMethod=Frame.CreateMaskTexture;Frame.CreateMaskTexture=nil
 local missingMask=essential:Acquire();Data(missingMask).cooldownInfo={spellID=20271,charges=false};M:UpdateSettings()
 update();update()
 check(M:GetReadyUnavailable()~=nil and not controller.scripts.OnUpdate,flavor.." missing mask disables and explains")
 Frame.CreateMaskTexture=maskMethod;M.readyUnavailable=nil;Data(missingMask).cooldownInfo=nil
 created=#frameLogAll
 local method=Frame.SetCooldownFromDurationObject;Frame.SetCooldownFromDurationObject=nil
 local later=essential:Acquire();Data(later).cooldownInfo={spellID=20271,charges=false};M:UpdateSettings()
 update();update()
 check(M:GetReadyUnavailable()~=nil and not controller.scripts.OnUpdate,flavor.." missing widget disables")
 check(#frameLogAll<=created+3,flavor.." missing widget does not allocate every tick")
 Frame.SetCooldownFromDurationObject=method;M.readyUnavailable=nil;Data(later).cooldownInfo=nil
 M.db.profile.readyEssential,M.db.profile.readyUtility,M.db.profile.readySound=false,false,false
 M:UpdateSettings();inCombat=false
end
ReadyTests("Retail")
ReadyTests("Forever")
]])
arg[2]=nil
if taint then
 local sentinel={value=10}
 local completed=false
 securecall(function()
  debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
  assert(not issecure(),"tainted addon execution")
  assert(loadstring("local mutateReady = ...\n"..seed,"@cooldown_ready_fixture"))(mutate)
  completed=true
 end)
 assert(completed,"taint fixture completed")
 assert(issecurevariable(sentinel,"value"),"native sentinel remains secure")
else
 assert(loadstring("local mutateReady = ...\n"..seed,"@cooldown_ready_fixture"))(mutate)
end

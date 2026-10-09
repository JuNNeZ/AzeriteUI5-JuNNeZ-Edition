-- Real Debugging.lua: opt-in cooldown readiness probe, Lua 5.1.
-- lua Tools/Harness/cdready_harness.lua . [mutation|--taint]
-- Synthetic widgets and opaque values cannot establish live WoW readiness.
local root, mutation = arg[1] or ".", arg[2]
local taint = mutation == "--taint"
if taint then mutation = nil end
local checks, failures = 0, 0
local function check(ok, label)
 checks = checks + 1
 if not ok then failures = failures + 1; print("FAIL: "..label) end
end
local f = assert(io.open(root.."/Core/Debugging.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local mutations = {
 ["slot-rebind-duplicate"] = {'PrepareSources(lane.combatAPI, lane.spellID, lane.actionSlot)', 'PrepareSources(lane.combatAPI, lane.spellID)'},
 ["slot-blanket-invalidate"] = {'decision = "unrelated slot; mapping retained"', 'decision = RecheckActionLane(lane)'},
 ["slot-ignore-watched"] = {'and slot ~= lane.actionSlot', ''},
 ["slot-secret-print"] = {'local slotText, secretSlot = Describe(slot)', 'local slotText, secretSlot = tostring(slot), false'},
 ["slot-combat-read"] = {'not combatOK or issecretvalue(inCombat) or inCombat ~= false', 'false'},
 ["slot-mismatch-ready"] = {'lane.unavailable = reason or "cached action mapping changed; restart out of combat"', 'lane.unavailable = nil'},
 ["slot-no-exit-recheck"] = {'if (lane.pendingMapping) then RecheckActionLane(lane) end', 'do end'},
 ["slot-stop-resolved"] = {'local slotText, secretSlot = Describe(slot)', 'local slotText, secretSlot = Describe(slot); for _, l in ipairs(probe.lanes) do if l.source == "resolved-spell" then l.unavailable = "mutation" end end'},
 ["action-gcd"] = {'API.TryCall(getter, probe.actionSlot, true)', 'API.TryCall(getter, probe.actionSlot, false)'},
 ["action-wrong-id"] = {'API.TryCall(getter, probe.actionSlot, true)', 'API.TryCall(getter, probe.spellID, true)'},
 ["action-combat-resolve"] = {'or combat ~= false', ''},
 ["action-secret-id"] = {'if (not ok or not PlainID(base)) then', 'if (not ok) then'},
 ["action-wrong-kind"] = {'kind == "action"', 'kind == "spell"'},
 ["action-no-invalidate"] = {'lane.unavailable = "action mapping changed; restart out of combat"', 'do end'},
 ["action-ready-missing"] = {'if (probe.unavailable) then getter = nil end', 'do end'},
 ["action-no-resolved-lane"] = {'{ "action-ignoreGCD", "resolved-spell" }', '{ "action-ignoreGCD" }'},
 ["action-base-as-resolved"] = {'then return base, current end', 'then return base, base end'},
 ["action-no-match"] = {'spell == id or spell == base or spell == resolved', 'true'},
 ["action-largest-slot"] = {'action < slot', 'action > slot'},
 ["no-log-sink"] = {'local SafePrintTarget = "debuglog"', 'local SafePrintTarget = "chat"'},
 ["log-format"] = {'DLAPI.DebugLog, "AzeriteUI", "%s", payload', 'DLAPI.DebugLog, "AzeriteUI", payload'},
 ["no-log-fallback"] = {'ChatPrint(unpack(args))', 'do end'},
 ["secret-log"] = {'if (IsSecretValue(value)) then', 'if (false) then'},
 ["log-chat-duplicate"] = {'if (SafePrintToDebugLog(unpack(args))) then\n\t\t\treturn', 'if (SafePrintToDebugLog(unpack(args))) then\n\t\t\tdo end'},
 ["async-chat"] = {'print("|cff33ff99AzeriteUI cdready|r", "["..reason.."]", line)', 'ChatPrint("|cff33ff99AzeriteUI cdready|r", "["..reason.."]", line)'},
 ["ungated"] = {"if (not IsDevMode()) then", "if (false) then", true},
 ["visible"] = {"probe.cooldown:SetAlpha(0)", "probe.cooldown:SetAlpha(1)"},
 ["hidden-parent"] = {"probe.cooldown:SetAlpha(0)", "probe.cooldown:SetAlpha(0); probe.cooldown:Hide()"},
 ["gcd"] = {'"cooldown-ignoreGCD", true', '"cooldown-ignoreGCD", false'},
 ["secret-shown"] = {"and not secretShown and", "and"},
 ["secret-print"] = {'if (secret) then return "<secret>", true end', 'if (false) then return "<secret>", true end'},
 ["nil-ready"] = {"if (probe.fed and shownOK", "if (true and shownOK"},
 ["feed-failure-ready"] = {"probe.fed = feedOK", "probe.fed = true"},
 ["no-done"] = {'probe.cooldown:SetScript("OnCooldownDone", function(_, ...)', 'probe.cooldown:SetScript("OnUnused", function(_, ...)'},
 ["no-event"] = {'probe.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")', ''},
 ["no-poll"] = {'C_Timer.After(1, Tick)', ''},
 ["no-stop"] = {'probe.events:UnregisterAllEvents()', ''},
 ["old-loop"] = {'or probe.generation ~= generation', ''},
 ["no-route"] = {'if (cmd == "cdready") then', 'if (cmd == "unused") then'},
 ["callback-boolean"] = {'local text, secret = Describe(select(i, ...))', 'local text, secret = Describe(select(i, ...) and true or false)'},
 ["no-global-fallback"] = {"then combatAPI = InCombatLockdown end", "then combatAPI = nil end"},
 ["no-preview-route"] = {'token == "preview" or token == "inspect"', 'token == "unused" or token == "inspect"'},
 ["preview-ungated"] = {'if (not IsDevMode()) then print("AzeriteUI cdready: Development Mode is required."); return end', 'if (false) then print("AzeriteUI cdready: Development Mode is required."); return end'},
 ["preview-no-stop"] = {'readyModule:StopReadyPreviews()', 'do end'},
 ["no-charge-lane"] = {'{ "cooldown-withGCD", "charges" }', '{ "cooldown-withGCD" }'},
 ["wrong-charge-getter"] = {'ok, duration = API.TryCall(getter, probe.spellID)', 'ok, duration = API.TryCall(C_Spell.GetSpellCooldownDuration, probe.spellID, true)'},
 ["with-gcd-ignored"] = {'ignoreGCD = false, cooldown = cooldown', 'ignoreGCD = true, cooldown = cooldown'},
 ["no-refeed"] = {'Feed("tick", ticks % 5 == 0)', 'Snapshot("tick", ticks % 5 == 0)'},
 ["no-lane-label"] = {'"source="..probe.source.." spell="', '"spell="'},
 ["no-charge-event"] = {'probe.events:RegisterEvent("SPELL_UPDATE_CHARGES")', ''},
 ["partial-stop"] = {'lane.cooldown:SetScript("OnCooldownDone", nil)', 'probe.cooldown:SetScript("OnCooldownDone", nil)'},
 ["missing-charge-ready"] = {'probe.durationText, probe.fed = "unavailable", false', 'probe.durationText, probe.fed = "unavailable", true'},
 ["wrong-origin"] = {'probe.feeding and "during-feed" or "outside-feed"', '"outside-feed"'},
}
if mutation then
 local m = assert(mutations[mutation], "unknown mutation")
 local offset = m[3] and assert(source:find("Debugging.CooldownReadyProbe =",1,true)) or 1
 local a,b = source:find(m[1],offset,true); assert(a,"mutation did not apply")
 source = source:sub(1,a-1)..m[2]..source:sub(b+1)
end
local sentinel = taint and { value = 23 } or nil
local function client(flavor, globalOnly, logger)
 local world = { frames = {}, logs = {}, timers = {}, combat = false, duration = {}, ignore = nil, calls = {}, chargeDuration = {}, withGCDDuration = {} }
 local secrets = setmetatable({}, {__mode="k"})
 local function opaque()
  local value = setmetatable({}, {__tostring=function() error("secret printed") end,
   __add=function() error("secret arithmetic") end, __lt=function() error("secret compared") end})
  secrets[value] = true; return value
 end
 local module = {}
 local ns = {API={TryCall=pcall,IsEventAvailable=function() return true end},db={global={enableDevelopmentMode=false}}}
 function ns:NewModule() return module end
 local env = setmetatable({},{__index=_G})
 env._G = env
 env.issecretvalue = function(value) return secrets[value] == true end
 env.type = function(value) return secrets[value] and "boolean" or type(value) end
 local combatAPI = function() return world.combat end
 env.C_RestrictedActions = not globalOnly and {InCombatLockdown=combatAPI} or nil
 env.InCombatLockdown = globalOnly and combatAPI or nil
 env.C_Spell = {GetBaseSpell=function(id) world.resolves=(world.resolves or 0)+1;return world.base or id end,
 GetOverrideSpell=function(id) world.resolves=(world.resolves or 0)+1;return world.override or id end,
 GetSpellCooldownDuration=function(id, ignore)
  world.id, world.ignore = id, ignore;world.calls[ignore and "ignored" or "included"]=(world.calls[ignore and "ignored" or "included"] or 0)+1
  if world.getterError then error(world.getterError) end
  if world.resolvedDuration and id==world.override then return world.resolvedDuration end
  if ignore then return world.duration else return world.withGCDDuration end
 end,GetSpellChargeDuration=function(id)
  world.chargeID=id;world.calls.charges=(world.calls.charges or 0)+1
  return world.chargeDuration
 end}
 env.C_Timer = {After=function(delay, fn) check(delay == 1, flavor.." one-second poll"); world.timers[#world.timers+1]=fn end}
 env.UIParent = {}
 env.print = function(...)
  world.chatCount=(world.chatCount or 0)+1
  local parts={}
  for i=1,select("#",...) do parts[i]=tostring(select(i,...)) end
  world.logs[#world.logs+1] = table.concat(parts," ")
 end
 local function logSink(tab, fmt, ...)
  check(tab=="AzeriteUI" and fmt=="%s",flavor.." literal logger format and tab")
  world.logs[#world.logs+1]=string.format(fmt,...)
 end
 if logger then env.DLAPI={DebugLog=logSink} end
 env.CreateFrame = function(kind, name, parent, template)
  local frame = {kind=kind, parent=parent, template=template, scripts={}, events={}, shown=true}
  function frame:SetSize(w,h) self.w,self.h=w,h end
  function frame:SetPoint(...) self.point={...} end
  function frame:SetAlpha(a) self.alpha=a end
  function frame:SetScript(name, fn) self.scripts[name]=fn end
  function frame:RegisterEvent(name) self.events[name]=true end
  function frame:UnregisterAllEvents() self.events={} end
  function frame:Hide() self.shown=false; self.forcedHidden=true end
  function frame:Clear() self.shown=false end
  function frame:IsShown() if world.shownError then error("refused") end; return world.secretShown or self.shown end
  function frame:IsVisible() return world.secretVisible or self.shown end
  function frame:SetCooldownFromDurationObject(duration, clear)
   self.duration=duration; check(clear==true,flavor.." clear zero enabled")
   if world.feedError then error(world.feedError) end
   if world.callbackDuringFeed and self.scripts.OnCooldownDone then self.scripts.OnCooldownDone(self, opaque()) end
   if duration==world.actionDuration then self.shown=world.onAction or false
   elseif duration==world.resolvedDuration then self.shown=world.onResolved or false
   elseif duration==world.chargeDuration then self.shown=world.onCharge or false
   elseif duration==world.withGCDDuration then self.shown=world.onGCD or false
   else self.shown=world.onCooldown or false end
  end
  world.frames[#world.frames+1]=frame; return frame
 end
 local chunk = assert(loadstring(source, "@Core/Debugging.lua")); setfenv(chunk,env); chunk("AzeriteUI",ns)
 check(#world.frames==0 and #world.timers==0 and #world.logs==0,flavor.." dormant load")
 local function run(input) module:DebugMenu("cdready "..input) end
 local function contains(s, also)
  for _,line in ipairs(world.logs) do if line:find(s,1,true) and (not also or line:find(also,1,true)) then return true end end
  return false
 end
 local function tick()
  local pending=world.timers;world.timers={}
  for _,fn in ipairs(pending) do fn() end
 end
 local function event(name, ...)
  local frame=world.frames[1]
  if frame.events[name] then frame.scripts.OnEvent(frame,name,...) end
 end
 run("853")
 check(#world.frames==0 and contains("Development Mode is required"),flavor.." gated")
 local routed, stopped = {}, 0
 local readyModule = { DebugReadyAlerts=function(_, action) routed[#routed+1]=action end,
  StopReadyPreviews=function() stopped=stopped+1 end }
 ns.GetModule=function(_, name) if name=="CooldownManager" then return readyModule elseif name=="ActionBars" then return world.actionBars end end
 world.logs={};run("preview")
 check(#routed==0 and #world.frames==0 and contains("Development Mode is required"),flavor.." preview dispatcher dev gate")
 ns.db.global.enableDevelopmentMode=true
 run("preview");run("inspect")
 check(routed[1]=="preview" and routed[2]=="inspect" and #world.frames==0,flavor.." dispatcher routes module preview and inspection")
 run("off");check(stopped==1,flavor.." off also stops module visual preview")
 world.logs={};run("invalid");run("0");run("1.5")
 check(#world.frames==0 and contains("Usage:"),flavor.." invalid ID allocates nothing")
 world.logs={};env.C_Spell.GetSpellCooldownDuration=nil;run("853")
 check(#world.frames==0 and contains("UNAVAILABLE: missing C_Spell.GetSpellCooldownDuration"),flavor.." missing duration API")
 env.C_Spell.GetSpellCooldownDuration=function(id,ignore) world.id,world.ignore=id,ignore;world.calls[ignore and "ignored" or "included"]=(world.calls[ignore and "ignored" or "included"] or 0)+1;if world.resolvedDuration and id==world.override then return world.resolvedDuration end;if ignore then return world.duration else return world.withGCDDuration end end
 local namespace, globalCombat = env.C_RestrictedActions, env.InCombatLockdown
 env.C_RestrictedActions=nil;env.InCombatLockdown=nil;world.logs={};run("853")
 check(#world.frames==0 and contains("UNAVAILABLE: missing C_RestrictedActions.InCombatLockdown / InCombatLockdown"),flavor.." missing combat API named")
 env.C_RestrictedActions,env.InCombatLockdown=namespace,globalCombat
 world.logs={};run("853")
 local cd=world.frames[2]
 if not cd then check(false,flavor.." command route creates widget");return end
 check(#world.frames==6 and cd.kind=="Cooldown" and cd.template=="CooldownFrameTemplate",flavor.." own widget")
 check(cd.parent==env.UIParent and cd.alpha==0 and not cd.forcedHidden,flavor.." visually hidden, engine-owned shown state")
 check(world.id==853 and world.calls.ignored and world.calls.included and world.chargeID==853,flavor.." selected ID ignores GCD")
 check(cd.duration==world.duration and contains("readyViaShown=true"),flavor.." direct duration and idle candidate")
 check(world.frames[1].events.SPELL_UPDATE_COOLDOWN,flavor.." observes cooldown changes")
 local withGCD, charge=world.frames[3],world.frames[4]
 check(withGCD and charge and withGCD~=cd and charge~=cd and charge~=withGCD,flavor.." three independent widgets")
 if not withGCD or not charge then return end
 for _,lane in ipairs({cd,withGCD,charge}) do
  check(lane.parent==env.UIParent and lane.alpha==0 and not lane.forcedHidden,flavor.." every lane opt-in invisible and unhidden")
 end
 check(contains("source=cooldown-ignoreGCD") and contains("source=cooldown-withGCD") and contains("source=charges"),flavor.." source labels")
 check(world.frames[1].events.SPELL_UPDATE_CHARGES,flavor.." charge event registered")
 world.withGCDDuration={};world.onGCD=true;world.logs={};event("SPELL_UPDATE_COOLDOWN")
 check(not cd.shown and withGCD.shown and not charge.shown,flavor.." GCD only reaches inclusive lane")
 world.onGCD=false;world.onCharge=true;world.logs={};event("SPELL_UPDATE_CHARGES")
 check(not cd.shown and not withGCD.shown and charge.shown,flavor.." charge duration uses own widget/getter")
 world.logs={};world.onCharge=false;world.onCooldown=true;local feeds=world.calls.ignored;tick()
 check(cd.shown and world.calls.ignored>feeds,flavor.." poll re-feeds without event")
 world.onCooldown=false
 local chargeGetter=env.C_Spell.GetSpellChargeDuration;env.C_Spell.GetSpellChargeDuration=nil;world.logs={};tick()
 check(contains("source=charges spell=853") and contains("source=charges", "duration=unavailable") and contains("source=charges", "readyViaShown=unknown") and not charge.shown,flavor.." missing charge source explained and inconclusive")
 env.C_Spell.GetSpellChargeDuration=chargeGetter
 world.chargeDuration=opaque();world.logs={};tick()
 check(charge.duration==world.chargeDuration and contains("duration=<secret>/secret=true"),flavor.." secret charge duration direct sink")
 world.chargeDuration={}
 world.logs={};world.onCooldown=true;event("SPELL_UPDATE_COOLDOWN",opaque(),opaque())
 check(cd.shown and contains("readyViaShown=false"),flavor.." actual cooldown active")
 world.logs={};world.combat=true;event("PLAYER_REGEN_DISABLED")
 check(contains("combat=true/secret=false") and contains("shown=true/secret=false"),flavor.." combat snapshot")
 check(type(cd.scripts.OnCooldownDone)=="function",flavor.." completion installed")
 if cd.scripts.OnCooldownDone then
  cd.shown=false;world.onCooldown=false;world.logs={};cd.scripts.OnCooldownDone(cd,opaque())
  check(contains("origin=outside-feed") and contains("callbackArg1=<secret>/secret=true"),flavor.." natural callback and opaque args")
  check(contains("callbackNeedsSecret=false") and contains("doneCount=1"),flavor.." event route does not read args")
 end
 world.logs={}
 for _,lane in ipairs({withGCD,charge}) do
  check(type(lane.scripts.OnCooldownDone)=="function",flavor.." comparator completion installed")
  if lane.scripts.OnCooldownDone then lane.scripts.OnCooldownDone(lane,opaque()) end
 end
 check(contains("OnCooldownDone source=cooldown-withGCD origin=outside-feed") and contains("OnCooldownDone source=charges origin=outside-feed"),flavor.." comparator callbacks labelled independently")
 run("status")
 check(contains("source=cooldown-ignoreGCD", "doneCount=1") and contains("source=charges", "doneCount=1"),flavor.." separate callback counters")
 world.logs={};for _=1,5 do tick() end
 check(#world.timers==1 and contains("readyViaShown=true"),flavor.." poll observes expiry and reschedules")
 world.logs={};world.secretShown=opaque();world.secretVisible=opaque();world.combat=opaque();run("status")
 check(contains("shown=<secret>/secret=true") and contains("visible=<secret>/secret=true") and contains("combat=<secret>/secret=true"),flavor.." every getter safe log")
 check(contains("source=cooldown-ignoreGCD", "readyViaShown=unknown") and contains("source=cooldown-ignoreGCD", "needsSecretForShown=true"),flavor.." secret shown blocks decision")
 world.secretShown=nil;world.secretVisible=nil;world.combat=false
 world.duration=nil;world.logs={};event("SPELL_UPDATE_COOLDOWN")
 check(contains("source=cooldown-ignoreGCD", "duration=nil/secret=false") and contains("source=cooldown-ignoreGCD", "readyViaShown=unknown"),flavor.." nil is inconclusive")
 world.duration=opaque();world.logs={};event("SPELL_UPDATE_COOLDOWN")
 check(cd.duration==world.duration and contains("duration=<secret>/secret=true"),flavor.." opaque duration direct sink")
 world.duration={};world.feedError=opaque();world.logs={};event("SPELL_UPDATE_COOLDOWN")
 check(contains("feed error=<secret>/secret=true") and contains("source=cooldown-ignoreGCD", "feedOK=false") and contains("source=cooldown-ignoreGCD", "readyViaShown=unknown"),flavor.." feed error visible and inconclusive")
 world.feedError=nil;world.shownError=true;world.logs={};run("status")
 check(contains("source=cooldown-ignoreGCD", "/secret=false/ok=false") and contains("source=cooldown-ignoreGCD", "readyViaShown=unknown"),flavor.." unreadable widget inconclusive")
 world.shownError=nil;world.callbackDuringFeed=true;world.logs={};event("SPELL_UPDATE_COOLDOWN")
 check(contains("origin=during-feed"),flavor.." callback reentrancy labelled")
 world.callbackDuringFeed=false
 world.logs={};world.combat=false;event("PLAYER_REGEN_ENABLED")
 check(contains("combat=false/secret=false"),flavor.." combat exit recorded")
 local count=#world.frames
 run("31884")
 check(#world.frames==count and world.id==31884,flavor.." retarget reuses widget")
 tick();check(#world.timers==1,flavor.." old generation does not duplicate loop")
 world.logs={};run("off")
 check(not next(world.frames[1].events) and not cd.scripts.OnCooldownDone and cd.shown==false and not withGCD.scripts.OnCooldownDone and not charge.scripts.OnCooldownDone and not withGCD.shown and not charge.shown,flavor.." off cleanup")
 local logCount=#world.logs;tick()
 check(#world.logs==logCount and #world.timers==0,flavor.." off stops polling")
 run("853");ns.db.global.enableDevelopmentMode=false;world.logs={};tick()
 check(#world.timers==0 and not next(world.frames[1].events),flavor.." losing dev mode stops probe")
 ns.db.global.enableDevelopmentMode=true
 local action, resolved = world.frames[5], world.frames[6]
 check(action and resolved,flavor.." extra source widgets exist")
 if not action or not resolved then return end
 local buttonReads=0
 local function button(kind,slot,id)
  return setmetatable({GetAction=function() buttonReads=buttonReads+1;return kind,slot end,
   GetSpellId=function() buttonReads=buttonReads+1;return id end},
   {__newindex=function() error("native button modified") end})
 end
 world.actionBars={buttons={[button("action",8,6940)]=true,[button("action",3,6940)]=true,
  [button("action",1,99999)]=true,[button("spell",2,6940)]=true}}
 world.actionDuration={};world.resolvedDuration={};world.base=6940;world.override=123456
 env.C_ActionBar={GetActionCooldownDuration=function(slot,ignore)
  world.actionID,world.actionIgnore=slot,ignore
  world.actionCalls=(world.actionCalls or 0)+1
  if world.actionError then error("action getter refused") end
  return world.actionDuration
 end}
 world.combat=false;world.onCooldown=false;world.onAction=false;world.onResolved=false;world.logs={};run("6940")
 check(contains("MAPPING selected=6940 base=6940 resolved=123456 actionSlot=3"),flavor.." deterministic own button/variant mapping")
 check(world.actionID==3 and world.actionIgnore==true,flavor.." cached action slot excludes GCD")
 check(action.duration==world.actionDuration and resolved.duration==world.resolvedDuration,flavor.." separate action and resolved opaque sinks")
 world.onAction=true;world.onResolved=true;world.combat=true;world.logs={};local before=buttonReads;local resolves=world.resolves;tick()
 check(action.shown and resolved.shown and not cd.shown,flavor.." action/override timer active despite empty original spell timer")
 check(buttonReads==before and world.resolves==resolves,flavor.." combat only uses cached IDs")
 check(contains("source=action-ignoreGCD", "readyViaShown=false") and contains("source=resolved-spell spell=123456", "readyViaShown=false"),flavor.." both extra active rows labelled")
 world.onAction=false;world.onResolved=false;world.logs={};tick()
 check(contains("source=action-ignoreGCD", "readyViaShown=true") and contains("source=resolved-spell", "readyViaShown=true"),flavor.." combat recovery observed independently")
 world.actionDuration=opaque();world.logs={};tick()
 check(action.duration==world.actionDuration and contains("source=action-ignoreGCD", "duration=<secret>/secret=true"),flavor.." action secret duration never read")
 world.actionDuration={};world.actionError=true;world.logs={};tick()
 check(contains("source=action-ignoreGCD", "readyViaShown=unknown"),flavor.." failed action getter inconclusive")
 world.actionError=nil
 world.combat=false;run("6940");world.onAction=true;world.onResolved=true
 for _,combat in ipairs({false,true}) do
  world.combat=combat;world.logs={};before=buttonReads;resolves=world.resolves;event("ACTIONBAR_SLOT_CHANGED",49)
  check(action.shown and resolved.shown and contains("slot=49/secret=false cached=3 decision=unrelated slot; mapping retained"),flavor.." unrelated slot keeps both active sources")
  check(buttonReads==before and world.resolves==resolves,flavor.." unrelated slot does not rediscover mapping")
 end
 world.onAction=false;world.logs={};tick()
 check(contains("source=action-ignoreGCD", "readyViaShown=true"),flavor.." recovery survives unrelated slot event")
 world.combat=false;world.onAction=true;world.logs={};before=buttonReads;event("ACTIONBAR_SLOT_CHANGED",3)
 check(buttonReads>before and action.shown and contains("decision=mapping verified"),flavor.." watched unchanged slot is rechecked OOC and retained")
 local lowerBinding=button("action",1,6940);world.actionBars.buttons[lowerBinding]=true;world.logs={};event("ACTIONBAR_SLOT_CHANGED",3)
 check(action.shown and world.actionID==3 and contains("decision=mapping verified"),flavor.." recheck preserves watched slot when a lower duplicate appears")
 world.actionBars.buttons[lowerBinding]=nil
 for _,slot in ipairs({0,"bad",opaque()}) do
  world.logs={};before=buttonReads;event("ACTIONBAR_SLOT_CHANGED",slot)
  check(buttonReads>before and action.shown and resolved.shown and contains("decision=mapping verified"),flavor.." ambiguous slot rechecks OOC without shutting sources")
 end
 world.logs={};event("ACTIONBAR_SLOT_CHANGED",opaque())
 check(contains("slot=<secret>/secret=true"),flavor.." secret slot logged without conversion")
 world.logs={};before=buttonReads;event("ACTIONBAR_SLOT_CHANGED")
 check(buttonReads>before and action.shown and contains("slot=nil/secret=false") and contains("decision=mapping verified"),flavor.." missing slot payload revalidates OOC")
 world.combat=opaque();world.logs={};before=buttonReads;event("ACTIONBAR_SLOT_CHANGED",3)
 check(buttonReads==before and not action.shown and resolved.shown,flavor.." secret combat state defers action without button reads")
 world.combat=false;event("PLAYER_REGEN_ENABLED")
 check(action.shown,flavor.." secret combat deferral recovers OOC")
 for _,name in ipairs({"ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","UPDATE_BONUS_ACTIONBAR"}) do
  world.combat=false;run("6940");world.combat=true;world.logs={};before=buttonReads
  check(world.frames[1].events[name],flavor.." mapping event registered "..name)
  event(name,opaque());tick()
  check(contains("source=action-ignoreGCD", "action mapping changed; restart out of combat") and contains("source=action-ignoreGCD", "readyViaShown=unknown") and not action.shown,flavor.." mapping event invalidates action "..name)
  check(contains("source=resolved-spell", "readyViaShown=false") and resolved.shown and buttonReads==before,flavor.." mapping event leaves variant active without button read "..name)
  world.combat=false;world.logs={};event("PLAYER_REGEN_ENABLED")
  check(action.shown and resolved.shown and contains("source=action-ignoreGCD", "feedOK=true"),flavor.." combat exit immediately revalidates unchanged watched mapping "..name)
 end
 world.combat=false;run("6940");world.actionBars={buttons={[button("action",3,99999)]=true}};world.logs={};event("ACTIONBAR_SLOT_CHANGED",3)
 check(not action.shown and resolved.shown and contains("source=action-ignoreGCD", "readyViaShown=unknown"),flavor.." changed watched spell remains unknown while variant runs")
 world.actionBars={buttons={[button("action",3,6940)]=true}};world.logs={};event("ACTIONBAR_SLOT_CHANGED",3)
 check(action.shown and resolved.shown,flavor.." restored watched mapping revalidates without restart")
 world.combat=true;world.logs={};before=buttonReads;event("ACTIONBAR_SLOT_CHANGED",3)
 check(not action.shown and resolved.shown and buttonReads==before,flavor.." watched slot in combat defers only action")
 world.combat=false;world.logs={};tick()
 check(action.shown and resolved.shown and buttonReads>before,flavor.." pending validation recovers on first OOC tick if exit event missed")
 world.combat=true;event("ACTIONBAR_SLOT_CHANGED",3);env.C_ActionBar.GetActionCooldownDuration=nil;world.combat=false;world.logs={};event("PLAYER_REGEN_ENABLED")
 check(not action.shown and contains("missing C_ActionBar.GetActionCooldownDuration"),flavor.." revalidation cannot enable missing action API")
 env.C_ActionBar.GetActionCooldownDuration=function(slot,ignore) world.actionID,world.actionIgnore=slot,ignore;world.actionCalls=(world.actionCalls or 0)+1;if world.actionError then error("refused") end;return world.actionDuration end
 world.combat=true
 world.logs={};before=buttonReads;resolves=world.resolves;run("6940")
 check(buttonReads==before and world.resolves==resolves and contains("start out of combat to resolve sources"),flavor.." start in combat does not resolve")
 check(contains("source=action-ignoreGCD", "readyViaShown=unknown"),flavor.." combat start never reuses stale mapping")
 world.combat=opaque();world.logs={};run("6940")
 check(buttonReads==before and contains("start out of combat to resolve sources"),flavor.." secret combat refuses mapping")
 world.combat=false;world.base=opaque();world.logs={};run("6940")
 check(contains("unreadable base spell") and contains("source=resolved-spell", "readyViaShown=unknown"),flavor.." secret variant ID refuses resolution")
 world.base=6940;world.override=opaque();world.logs={};run("6940")
 check(contains("unreadable override spell"),flavor.." secret override refuses resolution")
 world.override=123456
 local overrideAPI=env.C_Spell.GetOverrideSpell;env.C_Spell.GetOverrideSpell=nil;world.logs={};run("6940")
 check(contains("missing base/override spell API"),flavor.." missing variant API explained")
 env.C_Spell.GetOverrideSpell=overrideAPI
 local actionAPI=env.C_ActionBar.GetActionCooldownDuration;env.C_ActionBar.GetActionCooldownDuration=nil;world.logs={};run("6940")
 check(contains("missing C_ActionBar.GetActionCooldownDuration") and contains("source=action-ignoreGCD", "readyViaShown=unknown"),flavor.." missing action API explained")
 env.C_ActionBar.GetActionCooldownDuration=actionAPI;world.actionBars={buttons={[button("action",opaque(),6940)]=true}};world.logs={};run("6940")
 check(contains("no matching AzeriteUI action slot") and contains("source=action-ignoreGCD", "readyViaShown=unknown"),flavor.." secret slot rejected")
 world.actionBars=nil;world.logs={};run("6940")
 check(contains("no matching AzeriteUI action slot") and contains("source=resolved-spell", "feedOK=true"),flavor.." no action match still allows resolved spell comparison")
 run("off");check(not action.scripts.OnCooldownDone and not resolved.scripts.OnCooldownDone and not action.shown and not resolved.shown,flavor.." extra lanes stop and clear")
 env.C_Spell.GetOverrideSpell=function(id) if id==6940 then return 123456 elseif id==123456 then return 654321 else return id end end
 world.logs={};run("6940");check(contains("resolved=654321"),flavor.." bounded multi-step override resolution")
 env.C_Spell.GetOverrideSpell=function(id) return id==6940 and 123456 or 6940 end
 world.logs={};run("6940");check(contains("override cycle"),flavor.." override cycle refuses extra sources")
 env.C_Spell.GetOverrideSpell=function(id) return id+1 end
 world.logs={};run("6940");check(contains("override chain too long"),flavor.." runaway override chain bounded")
 env.C_Spell.GetOverrideSpell=overrideAPI
 run("off")
 world.base=nil;world.override=nil;world.resolvedDuration=nil;world.actionDuration=nil;world.combat=false
 if logger then
  check((world.chatCount or 0)==0,flavor.." ongoing callbacks never flood chat")
  world.logs={};module:PrintDiagnostic("percentage", "100%", opaque(), nil)
  check(contains("percentage 100% <secret> nil"),flavor.." literal percent/secrets/nil retained")
  check((world.chatCount or 0)==0,flavor.." successful sink exclusive")
  env.DLAPI=nil;world.logs={};module:PrintDiagnostic("fallback", "50%")
  check(contains("fallback 50%") and world.chatCount==1,flavor.." absent logger chat fallback")
  env.DLAPI={DebugLog=true};world.logs={};module:PrintDiagnostic("malformed logger")
  check(contains("malformed logger") and world.chatCount==2,flavor.." malformed API fallback")
  env.DLAPI={DebugLog=function() error("logger failed") end};world.logs={};module:PrintDiagnostic("failed logger",opaque())
  check(contains("failed logger <secret>") and world.chatCount==3,flavor.." failed logger safe chat fallback")
  env.DLAPI={DebugLog=logSink};world.logs={};run("6940");world.onCooldown=true;event("SPELL_UPDATE_COOLDOWN");tick();run("status");run("off")
  check(contains("source=cooldown-ignoreGCD") and contains("source=charges") and contains("OFF"),flavor.." restored sink handles source polling/status/stop")
  check(world.chatCount==3,flavor.." logger recovery stops fallback chatter")
 end
 if taint then
  securecall(function()
   debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
   check(not issecure(),flavor.." tainted probe caller")
   world.actionBars={buttons={[button("action",3,853)]=true}};world.actionDuration={}
   run("853");check(world.actionID==3,flavor.." tainted caller prepares owned action mapping")
   world.combat=true;world.onAction=true;event("SPELL_UPDATE_COOLDOWN")
   check(action.shown,flavor.." tainted action timer active in synthetic combat")
   local reads=buttonReads;event("ACTIONBAR_SLOT_CHANGED",49)
   check(action.shown and buttonReads==reads,flavor.." tainted unrelated event preserves action")
   event("ACTIONBAR_SLOT_CHANGED",3);check(not action.shown and buttonReads==reads,flavor.." tainted watched event defers without button read")
   world.combat=false;event("PLAYER_REGEN_ENABLED");check(action.shown,flavor.." tainted OOC mapping revalidation")
   world.onAction=false;tick();check(not action.shown,flavor.." tainted action timer recovers")
   run("off");world.combat=false
  end)
 end
end
client("Retail namespace");client("Retail global",true);client("Forever namespace");client("Forever global",true);client("Retail logger",false,true);client("Forever logger",true,true)
if taint then check(issecurevariable(sentinel,"value"),"unrelated native sentinel stays secure") end
print(string.format("cdready harness: %d checks, %d failures",checks,failures))
if failures>0 then os.exit(1) end

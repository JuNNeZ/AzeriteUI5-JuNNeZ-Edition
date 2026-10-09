-- Real options panel, renderer and Debug page. Widgets are offline fixtures.
-- Tools/Run-Elune.ps1 -Script Tools/Harness/cdready_menu_harness.lua . [mutation|--taint]
local root, mutation = arg[1] or ".", arg[2]
local taint = mutation == "--taint"; if taint then mutation = nil end
local checks, failures = 0, 0
local function check(ok, label) checks=checks+1; if not ok then failures=failures+1; print("FAIL: "..label) end end
local mutations = {
 ["wrong-panel"]={"Core/Debugging.lua",'panel:Open(L["Debug tools"])','panel:Open(L["Cooldown Manager"])'},
 ["wrong-tab"]={"Core/Debugging.lua",'panel:SetTab("options")','panel:SetTab("settings")'},
 ["no-immediate"]={"Options/Kit/Combat.lua",'immediate[option] = true','immediate[option] = nil'},
 ["all-immediate"]={"Options/Kit/Combat.lua",'return true\nend\n\n-- The entry waiting','return false\nend\n\n-- The entry waiting'},
 ["renderer-no-path"]={"Options/Kit/Renderer.lua",'Combat:ShouldQueue(options, path)','Combat:ShouldQueue(options)'},
 ["auto-start"]={"Options/OptionsPages/Debug.lua",'Watch()\n\t\treturn','Watch(); Probe(spell)\n\t\treturn'},
 ["ungated"]={"Options/OptionsPages/Debug.lua",'(value == "off" or Dev())','true'},
 ["invalid-start"]={"Options/OptionsPages/Debug.lua",'Capable() and ValidID(spell)','Capable()'},
 ["missing-api"]={"Options/OptionsPages/Debug.lua",'type(C_Spell.GetSpellCooldownDuration) == "function"','true'},
 ["combat-preview"]={"Options/OptionsPages/Debug.lua",'if (OOC()) then Probe("preview") end','Probe("preview")'},
 ["combat-inspect"]={"Options/OptionsPages/Debug.lua",'if (OOC()) then Probe("inspect") end','Probe("inspect")'},
 ["secret-combat"]={"Options/OptionsPages/Debug.lua",'not issecretvalue(combat) and combat == false','combat == false'},
 ["forever-preset"]={"Options/OptionsPages/Debug.lua",'not Dev() or ns.IsForever','not Dev()',true},
 ["no-stop"]={"Options/OptionsPages/Debug.lua",'Probe("off")','Probe("status")'},
 ["no-inspect"]={"Options/OptionsPages/Debug.lua",'Probe("inspect")','Probe("status")'},
 ["bad-id"]={"Options/OptionsPages/Debug.lua",'["6940"] = L["Blessing of Sacrifice"]','["34009"] = L["Blessing of Sacrifice"]'},
 ["no-queue-repair"]={"Options/OptionsPages/Debug.lua",'health.args[unit] = {','health.args[unit] = Immediate({',false,'\n\t\t\tend }','\n\t\t\tend })'},
 ["no-refresh"]={"Options/OptionsPages/Debug.lua",'last = state; panel.page:Refresh()','last = state'},
 ["auto-nameplate"]={"Options/OptionsPages/Debug.lua",'if (prefix == "nameplates" and value:lower() == "auto") then value = "" end',''},
}
local function loadSource(rel,ns,Addon)
 local f=assert(io.open(root.."/"..rel,"rb"));local source=f:read("*a"):gsub("\r\n","\n");f:close()
 local m=mutation and mutations[mutation]
 if m and m[1]==rel then
  local a,b=source:find(m[2],1,true);assert(a,"mutation did not apply");source=source:sub(1,a-1)..m[3]..source:sub(b+1)
  if m[4] then source=source:gsub(m[2]:gsub("(%W)","%%%1"),m[3]) end
  if m[5] then local c,d=source:find(m[5],a,true);assert(c,"mutation second edit did not apply");source=source:sub(1,c-1)..m[6]..source:sub(d+1) end
 end
 assert(loadstring(source,"@"..rel))(Addon,ns)
end
local function client(forever)
 local S=dofile(root.."/Tools/Harness/stubs.lua");local ns,Addon=S.ns,S.Addon
 ns.IsForever=forever;ns.db.global.enableDevelopmentMode=true
 local combat, secretCombat=false,false
 InCombatLockdown=function() return combat end
 issecretvalue=function(v) return secretCombat and v==combat end
 C_Spell={GetSpellCooldownDuration=function() return {} end}
 local created={};local make=CreateFrame
 CreateFrame=function(...) local f=make(...);local parent=select(3,...);f.GetParent=function() return parent end;created[#created+1]=f;return f end
 for _,rel in ipairs({"Core/Debugging.lua","Options/Kit/Kit.lua","Options/Kit/Config.lua","Options/Kit/Defaults.lua","Options/Kit/Combat.lua","Options/Kit/Controls.lua","Options/Kit/Preview.lua","Options/Kit/Renderer.lua","Options/Kit/Views.lua","Options/Changelog.lua","Options/Kit/PanelOptions.lua","Options/Kit/Panel.lua","Options/Options.lua","Options/OptionsPages/Debug.lua"}) do loadSource(rel,ns,Addon) end
 local M=S.modules.Debugging;local actions,commands={},{};local active,id=false,nil
 M.CooldownReadyProbe=function(_,v) actions[#actions+1]=v;if v=="off" then active,id=false,nil elseif tonumber(v) then active,id=true,tonumber(v) end end
 M.GetCooldownProbeState=function() return active,id end
 M.DebugMenu=function(_,v) commands[#commands+1]=v end -- actual dispatch/probe covered in cdready_harness
 S.modules.CooldownManager={DebugReadyAlerts=function() end} -- ready alerts present; removed below
 local repaired=0;S.modules.PlayerFrame={frame={Health={AttachMovementModule=function() repaired=repaired+1 end}}}
 local Options=S.modules.Options;Options:GenerateOptionsMenu()
 local Kit=ns.OptionsKit;local Panel,Config,Combat=Kit.Panel,Kit.Config,Kit.Combat
 local options=Options:GetOptionsObject();local group=options.args["Debug tools"]
 check(group and group.args.cooldown and group.args.health and group.args.keys and group.args.raid and group.args.utilities,"five sections registered")
 check(#actions==0,"load does not start probe")
 M:ToggleDebugMenu();check(Panel:IsShown() and Panel.selected=="Debug tools" and Panel.tab=="options","opens real panel debug page")
 check(not M.DebugFrame and not M.CooldownTestFrame,"no native debug popup")
 check(#actions==0,"opening is idle")
 check(#Panel.page:GetSections()==5,"section jumps exposed")
 local function control(label)
  for _,c in ipairs(Panel.page:GetControls()) do if c.labelText==label and c.kind~="header" and c.kind~="description" then return c end end
  error("missing control "..label)
 end
 local function click(label,...) local c=control(label);if not c.disabled then c:Fire(...) end end
 local function force(label,...) control(label):Fire(...) end
 local function refresh() Panel.page:Refresh() end
 for _,width in ipairs({380,540,750}) do
  Panel.page:GetControls()[1].frame:GetParent():SetWidth(width);Panel.page:Layout()
  local bottom=0
  for _,row in ipairs(Panel.page.layout) do check(row.offset>=bottom and row.height>0,"rows have height and do not overlap");bottom=row.offset+row.height end
 end
 check(not Combat:ShouldQueue(options),"OOC writes immediate")
 if forever then
  check(control("Paladin preset").disabled,"Forever presets disabled")
  force("Paladin preset","6940");check(control("Spell ID").value=="" or Config.GetValue(group.args.cooldown.args.spell,options,{"Debug tools","cooldown","spell"},Addon)=="","Forever preset handler stands down")
 else
  for _,v in ipairs({"6940","403876","20271"}) do click("Paladin preset",v);check(Config.GetValue(group.args.cooldown.args.spell,options,{"Debug tools","cooldown","spell"},Addon)==v,"verified preset selects ID") end
  check(group.args.cooldown.args.preset.values["6940"]=="Blessing of Sacrifice","correct BoS preset ID")
 end
 click("Spell ID","6940");click("Start / restart");check(active and id==6940,"starts selected probe")
 local n=#actions;Panel:Close();check(active and #actions==n,"close preserves probe")
 M:ToggleCooldownTestMenu();check(Panel.selected=="Debug tools" and active,"cooldown entry shares panel")
 combat=true;refresh();click("Spell ID","20271");click("Start / restart");click("Print status");check(actions[#actions]=="status" and id==20271 and Combat:Count()==0,"scratch/start/status immediate in combat")
 click("Stop test");check(not active and actions[#actions]=="off" and Combat:Count()==0,"stop immediate in combat")
 check(control("Preview flash").disabled and control("Inspect icons").disabled,"drawing controls disabled in combat")
 n=#actions;force("Preview flash");force("Inspect icons");check(#actions==n and Combat:Count()==0,"stale drawing callbacks refuse combat rather than queue")
 click("Reattach player bars");check(repaired==0 and Combat:Count()==1,"repairs queued during combat")
 combat=false;Combat:Flush();check(repaired==1 and Combat:Count()==0,"repair applies after combat")
 refresh();secretCombat=true;refresh();check(control("Preview flash").disabled,"secret combat state refuses drawing");secretCombat=false;refresh()
 click("Preview flash");click("Inspect icons");check(actions[#actions-1]=="preview" and actions[#actions]=="inspect","drawing routes correct")
 for _,bad in ipairs({"","-1","0","1.5","abc","inf"}) do click("Spell ID",bad);check(control("Start / restart").disabled,"invalid ID disabled");n=#actions;force("Start / restart");check(#actions==n,"invalid stale callback refuses") end
 click("Spell ID","6940");C_Spell.GetSpellCooldownDuration=nil;refresh();check(control("Start / restart").disabled,"missing API disabled");n=#actions;force("Start / restart");check(#actions==n,"missing API stale callback refuses")
 C_Spell.GetSpellCooldownDuration=function() return {} end
 ns.db.global.enableDevelopmentMode=false;refresh();check(control("Start / restart").disabled and not control("Stop test").disabled,"dev gating leaves stop accessible")
 n=#actions;force("Start / restart");check(#actions==n,"dev-disabled stale callback refuses");combat=true;click("Stop test");check(actions[#actions]=="off" and Combat:Count()==0,"dev off combat stop works")
 ns.db.global.enableDevelopmentMode=true;combat=false;refresh();click("Inspect nameplate cast");check(commands[#commands]=="nameplates ","auto nameplate input uses existing unfiltered route")
 local watcher=created[#created]; -- find the actual lazy watcher rather than assume allocation order
 for _,f in ipairs(created) do if f:GetScript("OnUpdate") and f:GetParent()==Panel.frame then watcher=f end end
 combat=true;watcher:GetScript("OnUpdate")(watcher,.3);check(control("Preview flash").disabled,"visible state watcher refreshes combat gating")
 check(Combat:ShouldQueue(options,{"Debug tools","health","PlayerFrame"}),"unregistered repairs keep queue policy")
 S.modules.CooldownManager=nil;combat=false;refresh()
 check(not pcall(control,"Preview flash") and not pcall(control,"Inspect icons") and pcall(control,"Start / restart"),"preview/inspect hidden without ready alerts, probe stays")
 if taint then securecall(function() debug.setstacktaint(Addon);check(not issecure(),"tainted options caller");click("Stop test");check(Combat:Count()==0,"tainted stop immediate") end) end
end
client(false);client(true)
print(string.format("cdready options menu: %d checks, %d failures",checks,failures));if failures>0 then os.exit(1) end

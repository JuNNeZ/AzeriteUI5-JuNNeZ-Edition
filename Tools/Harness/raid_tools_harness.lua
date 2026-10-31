-- Offline full-panel lifecycle, permissions and lockdown regression tests.
-- This records addon intent; it does not emulate native secure click execution.
local root = arg[1] or "."
local checks, failures = 0, 0
local function check(value, message)
    checks = checks + 1
    if (not value) then failures = failures + 1; print("FAIL: " .. message) end
end
local state = { combat=false, group=false, raid=false, leader=false, assist=false, members=0, lfg=false, difficultyEnabled=true, selectable=true }
local secret = {}
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return state.combat end
IsInGroup = function() return state.group end
IsInRaid = function() return state.raid end
UnitIsGroupLeader = function() return state.leader end
UnitIsGroupAssistant = function() return state.assist end
GetNumGroupMembers = function() return state.secretCount and secret or state.members end
UnitGroupRolesAssigned = function(unit) return state.secretRole and secret or (unit == "player" or unit == "raid1") and "TANK" or "DAMAGER" end
GetRaidRosterInfo = function(i) return secret, secret, state.secretGroup and secret or math.ceil(i/5) end
HasLFGRestrictions = function() return state.lfg end
UnitInBattleground = function() return state.battleground end
IsEveryoneAssistant = function() return state.everyone or false end
UIParent = {}
GameTooltip = { IsForbidden = function() return true end }
local mutations, calls, bridgeCalls = 0, {}, 0
local function guard()
    assert(not state.combat, "protected UI mutation during combat")
    mutations = mutations + 1
end
local function record(name, ...)
    assert(not state.combat, "administrative action during combat")
    calls[#calls+1] = {name, ...}
end
local function widget(parent, template)
    local w = { attributes={}, scripts={}, parent=parent, template=template, shown=true }
    for _, key in ipairs({"SetSize","SetPoint","ClearAllPoints","SetClampedToScreen","EnableMouse","RegisterForClicks","SetAllPoints","SetFontObject","SetTextColor","SetJustifyH","SetMaxLines","SetVertexColor"}) do
        w[key] = function() guard() end
    end
    function w:SetSize(width,height) guard(); self.width,self.height=width,height end
    function w:SetPoint(...) guard(); self.point={...} end
    function w:ClearAllPoints() guard(); self.point=nil end
    function w:SetAttribute(key, value) guard(); self.attributes[key]=value end
    function w:SetScript(key, value) self.scripts[key]=value end
    function w:SetShown(value) guard(); self.shown=value end
    function w:Hide() self:SetShown(false) end
    function w:SetEnabled(value) guard(); self.enabled=value end
    function w:CreateTexture() return widget(self) end
    function w:CreateFontString() return widget(self) end
    function w:SetTexture(value) self.texture=value end
    function w:GetStringWidth() return #(self.text or "")*6 end
    function w:SetText(value) guard(); assert(value ~= secret, "secret in text"); self.text=value end
    function w:SetTexCoord(...) self.coords={...} end
    function w:SetAlpha(value) self.alpha=value end
    function w:SetNormalTexture(value) self.normal=widget(self); self.normal.texture=value end
    function w:SetHighlightTexture(value) self.highlight=widget(self); self.highlight.texture=value end
    function w:GetNormalTexture() return self.normal end
    function w:GetHighlightTexture() return self.highlight end
    return w
end
CreateFrame = function(_, _, parent, template) guard(); return widget(parent,template) end
local L=setmetatable({}, {__index=function(_,k) return k end})
LibStub = function() return {GetLocale=function() return L end} end
local module, options = nil, {}
local bindings = {}
local ns={IsMainline=true,Prefix="Test",API={GetEffectiveScale=function() return .8 end,GetMedia=function(n) return n end,GetFont=function() return {} end},OptionsKit={Defaults={Bind=function(group,name) bindings[group]=name end}}}
ns.WoW12BlizzardQuarantine={ApplyRaidGroupFilter=function() guard(); bridgeCalls=bridgeCalls+1 end,ApplyRaidGroupVisibility=function() guard(); bridgeCalls=bridgeCalls+1 end}
local proto={defaults={},OnEnable=function(self) self.positioned=true end}
ns.MovableModulePrototype=proto
function ns:Merge(a,b) for k,v in pairs(b) do if a[k]==nil then a[k]=v end end; return a end
function ns:GetModule(name) return name=="Options" and options or name=="RaidTools" and module or nil end
function ns:NewModule(_,prototype)
    module=setmetatable({events={},commands={}}, {__index=prototype})
    function module:RegisterEvent(e,f) self.events[e]=f end
    function module:RegisterChatCommand(cmd,method) self.commands[cmd]=method end
    function module:CreateAnchor() self.anchor={} end
    return module
end
C_PartyInfo={
    DoReadyCheck=function() record("ready") end,DoCountdown=function(seconds) record("countdown",seconds) end,
    SetEveryoneIsAssistant=function(value) record("assist",value); state.everyone=value end,
    ConvertToRaid=function() record("toRaid") end,ConvertToParty=function() record("toParty") end,
    SetRestrictPings=function(value) record("pings",value) end,GetRestrictPings=function() return 0 end,
    LeaveParty=function() record("leave") end,IsPartyWalkIn=function() return state.walkIn or false end
}
InitiateRolePoll=function() record("roles") end
ConfirmOrLeaveParty=function() record("instance") end
LeaveWalkInParty=function() record("walkIn") end
PartyUtil={CanLeaveInstance=function() return state.instance end}
Enum={RestrictPingsTo={None=0,Lead=1,Assist=2,TankHealer=3}}
NONE,RAID_MANAGER_RESTRICT_PINGS_TO_LEAD,RAID_MANAGER_RESTRICT_PINGS_TO_ASSIST,RAID_MANAGER_RESTRICT_PINGS_TO_TANKS_HEALERS="All","Leader","Assist","Tank/healer"
local menu
MenuUtil={CreateContextMenu=function(_,generator)
    menu={items={}}
    function menu:CreateTitle(text) self.title=text end
    function menu:CreateRadio(label,get,set)
        local entry={label=label,get=get,set=set,enabled=true}
        function entry:SetEnabled(value) self.enabled=value end
        self.items[#self.items+1]=entry
        return entry
    end
    generator(nil,menu)
end}
DifficultyUtil={ID={DungeonNormal=1,DungeonHeroic=2,DungeonMythic=23,PrimaryRaidNormal=14,PrimaryRaidHeroic=15,PrimaryRaidMythic=16},
    HasAnyUserSelectableDifficulties=function() return state.anySelectable ~= false end,
    IsRaidDifficultyEnabled=function() return state.difficultyEnabled end,IsDungeonDifficultyEnabled=function() return state.difficultyEnabled end,
    GetDifficultyName=function(id) return "Difficulty "..id end,DoesCurrentRaidDifficultyMatch=function() return false end}
GetDungeonDifficultyID=function() return 1 end
GetDifficultyInfo=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,state.selectable end
SetRaidDifficulties=function(_,id) record("raidDifficulty",id) end
SetDungeonDifficultyID=function(id) record("dungeonDifficulty",id) end
StaticPopupDialogs={}
local popup
StaticPopup_Show=function(key,_,_,data) popup={key=key,data=data} end

-- Optional second argument loads an alternate RaidTools module for negative controls.
local function load(relative)
    local path=relative=="Components/Misc/RaidTools.lua" and arg[2] or root.."/"..relative
    assert(loadfile(path))("AzeriteUI5_JuNNeZ_Edition",ns)
end
load("Components/Misc/RaidTools.lua")
load("Components/Misc/RaidToolsActions.lua")
module.db=module:GenerateDefaults()
check(module.db.profile.enabled and not module.db.profile.collapsed,"default auto expanded")
check(module.db.profile.savedPosition[1]=="LEFT","default left edge")
module:OnEnable()
check(module.frame and module.anchor and module.positioned,"full panel and mover created")
check(not module.frame.shown,"hidden solo")
check(module.commands.azmarkers and module.commands.azraidtools,"legacy and full-panel preview aliases")
local frame=module.frame
module:OnEnable()
check(module.frame==frame,"re-enable does not duplicate frames")
state.group,state.members=true,5
module:OnEvent("GROUP_ROSTER_UPDATE")
check(module.frame.shown and module.panel.shown,"party member sees panel")
check(module.memberCount.text=="5" and module.roleCounts.TANK.text=="1" and module.roleCounts.DAMAGER.text=="4","party summary uses real role tokens")
check(not module:CanPerformAction("ready") and module:CanPerformAction("leave"),"member can leave but cannot ready-check")
for i,button in ipairs(module.buttons) do
    local a=button.attributes
    check(button.enabled and button.template=="SecureActionButtonTemplate","secure marker "..i)
    check(a.type1=="raidtarget" and a["shift-type1"]=="worldmarker","target mode "..i)
    check(a.useOnKeyDown==false and a.macrotext==nil,"no macro or double action "..i)
    check(a.unit1==(i<9 and "target" or "none") and a.unit2==a.unit1 and a["shift-unit1"]=="none" and a["shift-unit2"]=="none","target tab routes world/clear-all without a target "..i)
    if i<=8 then check(a.marker1==i and a["shift-marker1"]==({5,6,3,2,7,1,4,8})[i],"color mapping "..i)
    else check(a.action1=="clear-all" and a["shift-action1"]=="clear" and a.marker1==nil,"clear all target/world") end
end
module:SetMarkerMode("world")
for i,b in ipairs(module.buttons) do
    check(b.attributes.type1=="worldmarker" and b.attributes["shift-type1"]=="raidtarget","world mode "..i)
    check(b.attributes.unit1=="none" and b.attributes.unit2=="none" and b.attributes["shift-unit1"]==(i<9 and "target" or "none") and b.attributes["shift-unit2"]==b.attributes["shift-unit1"],"world tab routes target/world units separately "..i)
    if i<=8 then check(b.attributes.marker1==({5,6,3,2,7,1,4,8})[i] and b.attributes["shift-marker1"]==i,"world mapping "..i)
    else check(b.attributes.action1=="clear" and b.attributes["shift-action1"]=="clear-all","world clear all") end
end
-- Run Blizzard's actual unit gate and marker handlers against recording API fixtures.
-- This models dispatch/attributes, not the client's protected execution/taint context.
local checkNativeMarkerClicks
do
    local shifted, hasTarget, executed = false, false, nil
    local function attribute(self,name,button)
        local suffix=button=="RightButton" and "2" or "1"
        local a=self.attributes
        local value=shifted and a["shift-"..name..suffix] or nil
        if value==nil then value=a[name..suffix] end
        if value==nil then value=a[name] end
        return value
    end
    local native=setmetatable({
        SECURE_ACTIONS={},
        SecureButton_GetModifiedAttribute=attribute,
        SecureButton_GetModifiedUnit=function(self,button) return attribute(self,"unit",button) end,
        UnitExists=function(unit) return unit=="player" or (unit=="target" and hasTarget) end,
        UnitCanAttack=function() return false end, UnitCanAssist=function() return false end,
        GetRaidTargetIndex=function() return nil end,
        PlaceRaidMarker=function(marker) executed={"world-set",marker} end,
        ClearRaidMarker=function(marker) executed={"world-clear",marker} end,
        SetRaidTarget=function(unit,marker) executed={"target",marker,unit} end,
        RemoveRaidTargets=function() executed={"target-clear-all"} end
    },{__index=_G})
    local chunk=assert(loadfile(root.."/Tools/Harness/raid_marker_dispatch_fixture.lua"))
    setfenv(chunk,native)
    local dispatch=chunk()
    checkNativeMarkerClicks = function(buttons, mode)
        for _,shift in ipairs({false,true}) do
            shifted=shift
            local world=(mode=="world") ~= shifted
            for _,targetExists in ipairs({false,true}) do
                hasTarget=targetExists
                for _,mouse in ipairs({"LeftButton","RightButton"}) do
                    for index,button in ipairs(buttons) do
                        executed=nil
                        local b,unit,action=dispatch(button,mouse,2)
                        if b and action then native.SECURE_ACTIONS[action](button,unit,b) end
                        local expected=world or index==9 or hasTarget
                        check((executed~=nil)==expected,"native dispatch: "..mode.." shift="..tostring(shift).." target="..tostring(targetExists).." "..mouse.." marker="..index)
                        if executed then
                            if world then
                                check(executed[1]==(mouse=="LeftButton" and index<9 and "world-set" or "world-clear"),"native world action is independent of unit")
                                check(executed[2]==(index<9 and ({5,6,3,2,7,1,4,8})[index] or nil),"native world marker color/clear-all ID")
                            elseif index==9 then
                                check(executed[1]=="target-clear-all","native clear-all targets without unit")
                            else
                                check(executed[1]=="target" and executed[2]==(mouse=="LeftButton" and index or 0) and executed[3]=="target","native target set/clear action")
                            end
                        end
                    end
                end
            end
        end
    end
    for _,mode in ipairs({"target","world"}) do
        module:SetMarkerMode(mode)
        checkNativeMarkerClicks(module.buttons, mode)
    end
end

state.combat=true
local before=mutations
module:SetMarkerMode("target")
module.toggle.scripts.OnClick()
module:OnEvent("GROUP_ROSTER_UPDATE")
check(mutations==before and module.buttons[1].attributes.type1=="worldmarker","combat mode/fold/roster writes deferred")
for key in pairs(module.controls) do module:PerformAction(key,module.controls[key]) end
check(#calls==0,"combat admin callbacks do nothing")
state.combat=false
module:OnEvent("PLAYER_REGEN_ENABLED")
check(module.buttons[1].attributes.type1=="raidtarget" and not module.panel.shown,"queued mode and fold apply")
module.toggle.scripts.OnClick()
state.raid,state.members=true,10
module:OnEvent("GROUP_ROSTER_UPDATE")
check(module.frame.shown and not module.buttons[1].enabled,"raid member sees overview with marking disabled")
check(module.groupButtons[1].label.text=="1 (5)" and module.groupButtons[2].label.text=="2 (5)","subgroup counts")
check(module:GetRaidGroupFilter()=="1,2,3,4,5,6,7,8","all groups initially selected")
state.combat=true; before=mutations
module:PerformAction("visibility")
check(mutations==before and module.pending,"hide-groups intent queues during combat")
module:PerformAction("visibility")
state.combat=false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(not module:GetRaidHiddenMode(),"latest hide-groups intent applied after combat")
module.groupButtons[2].scripts.OnClick()
check(module:GetRaidGroupFilter()=="1,3,4,5,6,7,8" and bridgeCalls>0,"group toggle reaches AzeriteUI bridge")
for i=1,8 do module.db.profile.groups[i]=false end
module:UpdateSettings()
check(module:GetRaidGroupFilter()=="0","all groups off never becomes an unrestricted empty string")
local bridgeBefore=bridgeCalls
module:PerformAction("visibility")
check(module:GetRaidHiddenMode()==true and bridgeCalls>bridgeBefore,"visibility replays even with unchanged zero group filter")
bridgeBefore=bridgeCalls
module:PerformAction("visibility")
check(module:GetRaidHiddenMode()==false and bridgeCalls>bridgeBefore,"restore alpha even when no groups selected")
state.assist=true
module:UpdateSettings()
check(module.buttons[1].enabled and module:CanPerformAction("ready") and not module:CanPerformAction("assist"),"assistant marks/checks but cannot grant assistants")
module:PerformAction("ready"); module:PerformAction("roles"); module:PerformAction("countdown")
check(calls[#calls][1]=="countdown" and calls[#calls][2]==10,"leader tools call native APIs")
state.lfg=true
check(not module:CanPerformAction("roles"),"role poll respects LFG restrictions")
state.lfg=false; state.leader=true; state.assist=false
module:PerformAction("assist")
check(state.everyone==true,"all-assist toggle")
check(not module:CanPerformAction("convert"),"cannot convert raid over five members")
state.members=5
module:PerformAction("convert")
check(calls[#calls][1]=="toParty","convert raid to party")
state.raid=false
module:PerformAction("convert")
check(calls[#calls][1]=="toRaid","convert party to raid")
module:PerformAction("difficulty",module.controls.difficulty)
check(menu and #menu.items==3,"difficulty menu uses client IDs")
local selected=menu.items[2]
selected.set()
check(calls[#calls][1]=="dungeonDifficulty" and calls[#calls][2]==2,"difficulty callback")
local n=#calls
state.leader=false; selected.set()
check(#calls==n,"open difficulty menu rechecks leadership")
state.leader=true; state.difficultyEnabled=false; selected.set()
check(#calls==n,"difficulty callback rechecks game availability")
state.difficultyEnabled=true
ns.IsForever=true; state.selectable=false
check(#module:GetDifficultyChoices()==0,"Forever excludes non-user-selectable difficulties")
state.selectable=true
check(#module:GetDifficultyChoices()==3,"Forever accepts client-selectable IDs")
ns.IsForever=false
module:PerformAction("pings",module.controls.pings)
check(#menu.items==4,"ping menu from actual enum")
menu.items[3].set()
check(calls[#calls][1]=="pings" and calls[#calls][2]==2,"ping enum routed correctly")
n=#calls; state.combat=true; menu.items[1].set(); check(#calls==n,"open ping menu refuses combat"); state.combat=false
module:PerformAction("leave")
check(popup and #calls==n,"leave asks before native API")
module:OnEvent("GROUP_ROSTER_UPDATE")
StaticPopupDialogs[popup.key].OnAccept(nil,popup.data)
check(#calls==n,"stale leave confirmation invalidated by roster change")
module:PerformAction("leave")
StaticPopupDialogs[popup.key].OnAccept(nil,popup.data)
check(calls[#calls][1]=="leave","confirmed leave uses normal API")
state.walkIn=true
module:PerformAction("leave"); StaticPopupDialogs[popup.key].OnAccept(nil,popup.data)
check(calls[#calls][1]=="walkIn","walk-in group follows Blizzard leave helper")
state.walkIn=false; state.instance=true
module:PerformAction("instance")
check(calls[#calls][1]=="instance","instance leave uses Blizzard confirmation helper")
state.secretRole=true; state.secretGroup=true
state.raid=true
module:UpdateSettings()
check(module.roleCounts.TANK.text=="-","secret role counts unavailable rather than inferred")
state.secretCount=true
module:UpdateSettings()
check(module.memberCount.text=="-","secret count never used as loop bound")
state.secretRole,state.secretGroup,state.secretCount=false,false,false
state.group,state.raid=false,false
module:TogglePreview()
check(module.frame.shown and module.panel.shown and module.memberCount.text=="Preview","preview explicitly labelled")
for _,button in ipairs(module.buttons) do check(not button.enabled,"preview marker inert") end
n=#calls
for key in pairs(module.controls) do module:PerformAction(key,module.controls[key]) end
check(#calls==n,"preview cannot administer group")
state.combat=true; before=mutations
module:OnEvent("PLAYER_REGEN_DISABLED")
check(mutations==before and not module.preview,"preview cancellation never writes protected visibility in combat")
state.combat=false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(not module.frame.shown,"solo preview removed after combat")
state.group,state.raid=true,true
module.db.profile.enabled=false; module:UpdateSettings()
check(not module.frame.shown and module:GetRaidGroupFilter()==nil and module:GetRaidHiddenMode()==nil,"disable releases own filters")
module.db.profile.enabled=true; module:UpdateSettings()
load("Options/OptionsPages/RaidTools.lua")
local group=options:GenerateRaidToolsOptions()
check(bindings[group]=="RaidTools","settings retain module defaults binding")
group.args.enabled.set(nil,false)
check(not module.frame.shown,"options disable hides")
group.args.enabled.set(nil,true)
module:OnDisable()
check(not module.frame.shown,"module disable hides")
module.frame,module.anchor=nil,nil
state.combat=true; before=mutations
module:OnEnable()
check(mutations==before and not module.frame,"late enable waits for lockdown")
state.combat=false; module:OnEvent("PLAYER_REGEN_ENABLED")
check(module.frame and module.anchor and module.frame.shown,"late enable completes after combat")

-- Exercise the actual narrow Core bridge functions; poisoned Blizzard branches must not run.
local f=assert(io.open(root.."/Core/FixBlizzardBugs.lua")); local core=f:read("*a"); f:close()
local hiddenSource=assert(core:match("(local function GetCompactRaidHiddenMode%(%).-)%s*local function GetCompactRaidFilterGroupButtons"))
local filterSource=assert(core:match("(local function GetCompactRaidGroupFilter%(%).-)%s*local function GetRaidModuleFrames"))
local env=setmetatable({
    GetRaidModule=function() return module end,
    ShouldShowBlizzardRaidBar=function() return false end,
    GetCompactRaidGroupFilterFromButtons=function() return nil end,
    CRF_GetFilterGroup=function() return true end
},{__index=_G})
local chunk=assert(loadstring(hiddenSource.."\nreturn GetCompactRaidHiddenMode")); setfenv(chunk,env); local hidden=chunk()
env.GetCompactRaidHiddenMode=hidden
chunk=assert(loadstring(filterSource.."\nreturn GetCompactRaidGroupFilter")); setfenv(chunk,env); local filter=chunk()
check(filter()==module:GetRaidGroupFilter(),"Core bridge prefers own subgroup selection")
module.db.profile.hideGroups=true
check(hidden()==true and filter()=="0","Core bridge owns hidden mode without Blizzard panel")
module.db.profile.enabled=false
check(hidden()==false and filter()=="1,2,3,4,5,6,7,8","Core bridge restores fallback when disabled")
state.raid=false; module.db.profile.enabled=true
check(hidden()==false and filter()=="1,2,3,4,5,6,7,8","party cannot inherit a hidden raid group filter")
-- Lite is a distinct module/mover and cannot own either raid panel or its filters.
local fullPanel = module
fullPanel.db.profile.enabled = false
fullPanel.db.profile.markerMode = "world"
local lite
ns.GetModule = function(_, name)
    if (name == "Options") then return options end
    if (name == "RaidTools") then return fullPanel end
    if (name == "TargetMarkersLite") then return lite end
end
load("Components/Misc/TargetMarkersLite.lua")
lite = module
lite.db = lite:GenerateDefaults()
check(lite.db.profile.enabled == false, "lite is an independent opt-in")
check(lite.db.profile.savedPosition[1] == "TOP", "lite has an independent default position")
lite:OnEnable()
check(lite.frame and lite.anchor and not lite.frame.shown, "lite builds its own hidden frame and mover")
check(lite.frame ~= fullPanel.frame and lite.anchor ~= fullPanel.anchor, "lite does not reuse full panel geometry")
check(lite.commands.azmarkerlite ~= nil, "lite has its own preview command")
local nativePanel = CompactRaidFrameManager
CompactRaidFrameManager = setmetatable({}, { __index = function() error("lite touched Blizzard panel") end })
local bridgeBeforeLite = bridgeCalls
state.group, state.raid, state.leader, state.assist = true, false, false, false
lite.db.profile.enabled = true
lite:UpdateSettings()
check(lite.frame.shown and not fullPanel.db.profile.enabled, "lite works with full AzUI panel disabled")
for i, button in ipairs(lite.buttons) do
    local a = button.attributes
    check(button.enabled and button.template == "SecureActionButtonTemplate", "lite secure button " .. i)
    check(a.type1 == "raidtarget" and a.type2 == "raidtarget" and a["shift-type1"] == "worldmarker" and a["shift-type2"] == "worldmarker", "lite Shift selects world markers independently of full panel " .. i)
    check(a.unit1 == (i<=8 and "target" or "none") and a.unit2 == a.unit1 and a["shift-unit1"] == "none" and a["shift-unit2"] == "none", "lite world/clear-all bypass missing target gate " .. i)
    check(button.scripts.OnClick == nil and not a.macrotext and not a.macrotext1, "lite retains native click handler " .. i)
    if (i <= 8) then
        check(a.marker1 == i and a.action1 == "set" and a.action2 == "clear", "lite marker and clear " .. i)
        check(a["shift-marker1"] == ({5,6,3,2,7,1,4,8})[i] and a["shift-marker2"] == a["shift-marker1"] and a["shift-action1"] == "set" and a["shift-action2"] == "clear", "lite world set/clear color mapping " .. i)
    else check(a.action1 == "clear-all" and a.action2 == "clear-all" and a["shift-action1"] == "clear" and a["shift-action2"] == "clear", "lite clear switches target/world clear-all") end
end
checkNativeMarkerClicks(lite.buttons, "target")
check(bridgeCalls == bridgeBeforeLite, "lite never updates raid filters")
state.raid = true
lite:OnEvent("GROUP_ROSTER_UPDATE")
check(not lite.frame.shown, "lite hides for an ordinary raid member")
state.assist = true
lite:OnEvent("PARTY_LEADER_CHANGED")
check(lite.frame.shown, "lite shows for raid assist")
state.combat = true; before = mutations
state.assist = false
lite:OnEvent("GROUP_ROSTER_UPDATE")
check(lite.frame.shown and mutations == before, "lite defers protected visibility on combat demotion")
state.combat = false
lite:OnEvent("PLAYER_REGEN_ENABLED")
check(not lite.frame.shown, "lite applies latest rights after combat")
state.group, state.raid = false, false
lite:TogglePreview()
check(lite.frame.shown, "lite can preview solo")
for _, button in ipairs(lite.buttons) do check(not button.enabled, "lite preview is inert") end
state.combat = true; before = mutations
lite:OnEvent("PLAYER_REGEN_DISABLED")
check(mutations == before and not lite.preview, "lite preview cancellation waits out lockdown")
state.combat = false
lite:OnEvent("PLAYER_REGEN_ENABLED")
check(not lite.frame.shown, "lite preview closes after combat")
state.group = true
lite:UpdateSettings()
state.combat = true; before = mutations
lite.db.profile.enabled = false
lite:UpdateSettings()
check(mutations == before and lite.frame.shown, "lite disable is deferred in combat")
state.combat = false; lite:OnEvent("PLAYER_REGEN_ENABLED")
check(not lite.frame.shown, "lite disable applies after combat")
local liteOptions = options:GenerateTargetMarkersLiteOptions()
check(bindings[liteOptions] == "TargetMarkersLite", "lite settings bind to its own defaults")
liteOptions.args.enabled.set(nil, true)
check(lite.frame.shown and not fullPanel.db.profile.enabled and bridgeCalls == bridgeBeforeLite, "lite option preserves full panel and filter choices")
liteOptions.args.preview.func()
check(lite.preview, "lite options preview")
lite:OnDisable()
check(not lite.frame.shown, "lite module disable hides frame")
lite.frame, lite.anchor = nil, nil
state.combat = true; before = mutations
lite:OnEnable()
check(mutations == before and not lite.frame, "lite late enable waits out combat")
state.combat = false; lite:OnEvent("PLAYER_REGEN_ENABLED")
check(lite.frame and lite.anchor and lite.frame.shown, "lite late enable completes")
check(bridgeCalls == bridgeBeforeLite, "lite never invokes Blizzard/fallback filter handling")
-- Favorite selection/layout must not alter marker identity or saved anchors.
state.group,state.raid,state.leader,state.assist=true,false,false,false
local savedPosition = lite.db.profile.savedPosition
lite.UpdateAnchor = function(self) self.anchor.width,self.anchor.height=self.frame.width,self.frame.height end
local slots = lite:GetMarkerSlots()
for i=1,8 do check(slots[i]==i,"old profiles retain marker order "..i) end
lite:SetMarkerSlot(1,8)
check(lite.db.profile.marker1==8 and lite.db.profile.marker8==1,"choosing an existing marker swaps slots")
local order,layout,width,height = lite:GetLayoutData()
check(order[1]==8 and order[8]==1 and order[9]==9,"marker IDs stay attached to their original buttons")
for i=1,8 do lite:SetMarkerSlot(i,0) end
lite:SetMarkerSlot(1,8); lite:SetMarkerSlot(2,7); lite:SetMarkerSlot(3,5)
order,layout,width,height = lite:GetLayoutData()
check(#order==4 and order[1]==8 and order[2]==7 and order[3]==5 and order[4]==9,"favorites collapse hidden slots")
check(width==179 and height==56 and lite.frame.width==179,"horizontal favorites shrink the frame")
check(lite.buttons[8].shown and not lite.buttons[1].shown and not lite.buttons[1].enabled,"hidden marker buttons cannot intercept clicks")
check(lite.buttons[8].attributes.marker1==8 and lite.buttons[7].attributes.marker1==7,"reordering never repurposes secure button marker IDs")
lite.db.profile.layout="vertical"; lite:UpdateSettings()
order,layout,width,height = lite:GetLayoutData()
check(width==56 and height==179 and lite.frame.width==56 and lite.frame.height==179,"vertical favorites dimensions")
check(#lite.art[1].coords==8 and lite.art[1].point[4]==42,"vertical art rotates both UVs and slice placement")
check(lite.anchor.width==56 and lite.anchor.height==179,"mover follows layout dimensions")
lite.db.profile.layout="twoRows"; lite:UpdateSettings()
order,layout,width,height = lite:GetLayoutData()
check(width==121 and height==85,"two-row favorites dimensions")
check(lite.buttons[8].point[4]==50 and lite.buttons[8].point[5]==-28 and lite.buttons[5].point[5]==-57,"two-row positions follow chosen order")
for _,texture in ipairs(lite.art) do check(texture.width>0 and texture.height>0,"nine-slice dimensions remain positive") end
check(lite.db.profile.savedPosition==savedPosition and savedPosition[1]=="TOP" and savedPosition[2]==0,"layout preserves saved position")
local oldWidth,oldHeight=lite.frame.width,lite.frame.height
state.combat=true; before=mutations
lite:SetMarkerSlot(2,0); lite.db.profile.layout="vertical"; lite:UpdateSettings()
check(mutations==before and lite.frame.width==oldWidth and lite.frame.height==oldHeight and lite.buttons[7].shown,"favorite/layout writes wait out combat")
state.combat=false; lite:OnEvent("PLAYER_REGEN_ENABLED")
check(not lite.buttons[7].shown and lite.frame.width==56 and lite.frame.height==150,"latest favorites/layout replay together after combat")
for i=1,8 do lite:SetMarkerSlot(i,0) end
lite.db.profile.layout="twoRows"; lite:UpdateSettings()
check(lite.frame.width==92 and lite.frame.height==56 and lite.buttons[9].shown,"all slots hidden retains clear-all button")
lite.db.profile.marker1=99; lite.db.profile.marker2=1; lite.db.profile.layout="invalid"
slots=lite:GetMarkerSlots()
check(slots[1]==1 and slots[2]==0,"invalid and duplicate saved marker choices normalize")
local _,fallbackLayout=lite:GetLayoutData()
check(fallbackLayout=="horizontal","invalid layout falls back")
lite:SetMarkerSlot(0,8); lite:SetMarkerSlot(1,99)
check(lite.db.profile.marker1==99,"invalid setter values are rejected")
local favoriteOptions=options:GenerateTargetMarkersLiteOptions()
check(favoriteOptions.args.marker8 and favoriteOptions.args.layout,"favorite and layout controls exist")
favoriteOptions.args.marker1.set(nil,8)
check(lite.db.profile.marker1==8,"favorite setting writes own profile")
favoriteOptions.args.layout.set(nil,"twoRows")
check(lite.db.profile.layout=="twoRows","layout setting writes own profile")
check(bridgeCalls==bridgeBeforeLite and not fullPanel.db.profile.enabled,"favorites and layout preserve panel/filter independence")

CompactRaidFrameManager = nativePanel

print(string.format("Raid panel: %d checks, %d failures",checks,failures))
os.exit(failures==0 and 0 or 1)

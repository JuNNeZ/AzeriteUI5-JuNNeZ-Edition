-- Synthetic bar tests for the currently selected theme. No unit values are
-- queried and no gameplay frame, saved anchor or native layout is modified.
local _, ns = ...
local Preview=ns:NewModule("ThemeBarPreview", "LibMoreEvents-1.0")
ns.ThemeBarPreview=Preview
Preview.kind="playerHi";Preview.fraction=.5;Preview.animate=false;Preview.protected=false
local definitions={
 playerLo={"PlayerFrame","Novice","health"},playerMid={"PlayerFrame","Hardened","health"},playerHi={"PlayerFrame","Seasoned","health"},
 targetLo={"TargetFrame","Novice","health"},targetMid={"TargetFrame","Hardened","health"},targetHi={"TargetFrame","Seasoned","health"},
 critter={"TargetFrame","Critter","health"},targetBoss={"TargetFrame","Boss","health"},boss={"BossFrames",nil,"health"},focus={"FocusFrame",nil,"health"},tot={"ToTFrame",nil,"health"},
 alternate={"PlayerFrameAlternate","Seasoned","health"},pet={"PetFrame",nil,"health"},raid5={"Raid5Frames",nil,"health"},party={"PartyFrames",nil,"health"},raid={"RaidFrames",nil,"health"},arena={"ArenaFrames",nil,"health"},
 cast={"PlayerCastBar",nil,"cast"},plate={"NamePlates",nil,"plate"},
 crystalLo={"PlayerFrame","Novice","crystal"},crystalHi={"PlayerFrame","Seasoned","crystal"},
 orbLo={"PlayerFrame","Novice","orb"},orbHi={"PlayerFrame","Seasoned","orb"}
}
Preview.Definitions=definitions
function Preview:GetChoices()
 return {playerLo="Player health / lo",playerMid="Player health / mid",playerHi="Player health / hi",
 targetLo="Target health / lo",targetMid="Target health / mid",targetHi="Target health / hi",critter="Critter",boss="Boss",focus="Focus",tot="Target of target",
 alternate="Alternate player",pet="Pet",raid5="Raid / 5",targetBoss="Target / boss",party="Party",raid="Raid",arena="Arena",cast="Player castbar",plate="Nameplate health + cast",
 crystalLo="Crystal / lo",crystalHi="Crystal / hi",orbLo="Orb / lo",orbHi="Orb / hi"}
end
local function Art(parent,relative,db,prefix,layer)
 local texture=parent:CreateTexture(nil,layer or "BACKGROUND")
 local point=db[prefix.."Position"] or {"CENTER",0,0}
 texture:SetPoint(point[1],relative,point[1],point[2] or 0,point[3] or 0)
 texture:SetSize(unpack(db[prefix.."Size"]));texture:SetTexture(db[prefix.."Texture"])
 texture:SetVertexColor(unpack(db[prefix.."Color"] or {1,1,1,1}));if (db[prefix.."TexCoord"]) then texture:SetTexCoord(unpack(db[prefix.."TexCoord"])) end;return texture
end
local function Bar(owner,relative,db,prefix)
 local bar=CreateFrame("StatusBar",nil,owner)
 local point=db[prefix.."Position"] or {"CENTER",0,0}
 bar:SetPoint(point[1],relative,point[1],point[2] or 0,point[3] or 0)
 bar:SetSize(unpack(db[prefix.."Size"]));bar:SetStatusBarTexture(db[prefix.."Texture"])
 bar:SetStatusBarColor(unpack(db[prefix.."Color"] or {.75,.18,.12,1}));bar:SetMinMaxValues(0,1)
 bar:SetOrientation(prefix=="PowerBar" and "VERTICAL" or "HORIZONTAL")
 bar:SetReverseFill(db[prefix.."Orientation"]=="LEFT")
 local coords=db[prefix.."TexCoord"];if (coords) then bar:GetStatusBarTexture():SetTexCoord(unpack(coords)) end
 -- Theme casing helpers use this wrapper on their own synthetic bar only.
 bar.SetTexCoord=function(self,...) self:GetStatusBarTexture():SetTexCoord(...) end
 return bar
end
function Preview:Build(key)
 local def=definitions[key];local config=def and ns.GetConfig(def[1]);if (not config) then return end
 local db=def[2] and config[def[2]] or config;if (not db) then return end
 local owner=CreateFrame("Frame",nil,self.window);owner:SetSize(unpack(db.UnitSize or config.Size or {560,180}))
 owner:SetPoint("CENTER",self.window,"CENTER",0,-15);owner:EnableMouse(false)
 local entry={owner=owner,bars={},db=db,kind=def[3]};self.entries[key]=entry
 local kind=def[3]
 if (kind=="health" or kind=="plate") then
  local bar=Bar(owner,owner,db,"HealthBar");owner.Health=bar;entry.bars[1]=bar
  bar.Backdrop=Art(owner,(kind=="plate" or not def[2]) and bar or owner,db,"HealthBackdrop")
  if (kind~="plate" and ns.PaladinTheme) then ns.PaladinTheme:StyleHealth(owner,db,db.HealthBarOrientation=="LEFT") end
  if (key=="pet" and ns.MageTheme) then ns.MageTheme:StylePet(owner) end
  if (kind=="plate") then
   local cast=Bar(owner,owner,db,"CastBar");cast:ClearAllPoints();cast:SetPoint("TOP",bar,"BOTTOM",0,-12)
   cast.Backdrop=Art(owner,cast,db,"CastBarBackdrop");owner.Castbar=cast;entry.bars[2]=cast
   if (ns.PaladinTheme) then ns.PaladinTheme:StyleNameplate(owner) end
  end
 elseif (kind=="cast") then
  local cast=Bar(owner,owner,db,"CastBar");entry.bars[1]=cast
  cast.Backdrop=Art(cast,cast,db,"CastBarBackground");cast.Shield=Art(cast,cast,db,"CastBarShield","BORDER")
  if (ns.PaladinTheme) then ns.PaladinTheme:StyleCastbar(cast) end
  entry.cast=cast
 elseif (kind=="crystal") then
  local power=Bar(owner,owner,db,"PowerBar");owner.Power=power;entry.bars[1]=power
  power.Backdrop=Art(power,power,db,"PowerBackdrop");power.Case=Art(power,power,db,"PowerBarForeground","ARTWORK")
  entry.power=power
 elseif (kind=="orb") then
  local lib=LibStub("LibOrb-1.0",true);if (not lib) then owner:Hide();return end
  local orb=lib:CreateOrb(nil,owner);entry.bars[1]=orb
  local p=db.ManaOrbPosition;orb:SetPoint(p[1],owner,p[1],p[2],p[3]);orb:SetSize(unpack(db.ManaOrbSize))
  orb:SetMinMaxValues(0,1);orb:SetStatusBarTexture(unpack(db.ManaOrbTexture));orb:SetStatusBarColor(.2,.5,1)
  local foreground=CreateFrame("Frame",nil,orb);foreground:SetAllPoints(orb);foreground:SetFrameLevel(orb:GetFrameLevel()+4)
  orb.Backdrop=Art(orb,orb,db,"ManaOrbBackdrop");orb.Shade=Art(foreground,orb,db,"ManaOrbShade","ARTWORK")
  orb.Case=Art(foreground,orb,db,"ManaOrbForeground","ARTWORK");orb.Case:SetDrawLayer("ARTWORK",2)
  if (db.ManaOrbGlassTexture) then orb.Glass=Art(foreground,orb,db,"ManaOrbGlass","BORDER") end
  if (db.ManaOrbRimTexture) then orb.Rim=Art(foreground,orb,db,"ManaOrbRim","BORDER") end
  if (db.ManaOrbArtworkTexture) then orb.Artwork=Art(orb,orb,db,"ManaOrbArtwork");orb.Artwork:SetDrawLayer("BACKGROUND",-3) end
  entry.orb=orb
 end
 return entry
end
function Preview:Refresh()
 if (not self.window or not self.window:IsShown() or InCombatLockdown()) then return end
 self.entries=self.entries or {}
 for _,entry in pairs(self.entries) do entry.owner:Hide() end
 local entry=self.entries[self.kind] or self:Build(self.kind);if (not entry) then return end
 entry.owner:Show()
 for _,bar in ipairs(entry.bars) do bar:SetValue(self.fraction) end
 if (entry.power and ns.ThemeEffects) then
  entry.power.Case:SetTexture(entry.db.PowerBarForegroundTexture)
  ns.ThemeEffects:StyleCrystal(entry.power,entry.db.PowerBarTexture,entry.db.PowerBarTexCoord,entry.db.PowerBarForegroundTexture)
 end
 if (entry.orb and ns.ThemeEffects) then entry.orb:SetStatusBarTexture(unpack(entry.db.ManaOrbTexture));ns.ThemeEffects:StyleOrb(entry.orb) end
 if (entry.cast) then entry.cast:SetStatusBarColor(unpack(self.protected and {.75,.18,.12,1} or entry.db.CastBarColor));entry.cast.Shield:SetShown(self.protected);entry.cast.Backdrop:SetShown(not self.protected) end
 self.hint:SetText(self:GetChoices()[self.kind].." | "..math.floor(self.fraction*100+.5).."% | "..ns.ThemeEffects:GetTheme().." | Esc to close")
end
function Preview:Set(key,value)
 if (InCombatLockdown()) then return end
 if (key=="kind" and not definitions[value]) then return end
 if (key=="fraction") then value=tonumber(value);if (not value or value~=value) then return end;value=math.max(0,math.min(1,value)) end
 if (key~="kind" and key~="fraction" and key~="animate" and key~="protected") then return end
 self[key]=value;self:Refresh()
end
function Preview:Show()
 if (InCombatLockdown()) then return end
 if (not self.window) then
  local Kit=ns.OptionsKit;local window=CreateFrame("Frame",ns.Prefix.."ThemeBarTests",UIParent,ns.BackdropTemplate)
  window:SetSize(840,420);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetBackdrop(Kit.WindowBackdrop)
  window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton");window:SetClampedToScreen(true)
  window:SetScript("OnDragStart",window.StartMoving);window:SetScript("OnDragStop",window.StopMovingOrSizing)
  local hint=window:CreateFontString(nil,"OVERLAY");hint:SetFontObject(Kit.GetFont(14,true));hint:SetPoint("TOP",0,-22)
  local close=CreateFrame("Button",nil,window);close:SetSize(28,28);close:SetPoint("TOPRIGHT",-8,-8)
  local label=close:CreateFontString(nil,"OVERLAY");label:SetFontObject(Kit.GetFont(16,true));label:SetAllPoints(close);label:SetText("X")
  close:SetScript("OnClick",function() window:Hide() end)
  window:SetScript("OnUpdate",function(_,elapsed)
   if (InCombatLockdown()) then window:Hide();return end
   if (not Preview.animate) then return end
   Preview.fraction=(Preview.fraction+elapsed/8)%1
   local entry=Preview.entries and Preview.entries[Preview.kind]
   if (entry) then for _,bar in ipairs(entry.bars) do bar:SetValue(Preview.fraction) end end
   hint:SetText(Preview:GetChoices()[Preview.kind].." | "..math.floor(Preview.fraction*100+.5).."% | Esc to close")
  end)
  UISpecialFrames[#UISpecialFrames+1]=window:GetName();self.window,self.hint=window,hint
 end
 self.window:Show();self:Refresh()
end
function Preview:OnEnable()
 self:RegisterEvent("PLAYER_REGEN_DISABLED",function() if (self.window) then self.window:Hide() end end)
end

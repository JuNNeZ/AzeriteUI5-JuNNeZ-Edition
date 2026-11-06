-- Class Lite+ interiors. Native fills own every resource clip;
-- this module animates only owned textures, fixed dimensions and local time.
local Addon, ns = ...
local Effect = {}
ns.ClassResourceEffects = Effect
local PREFIX = "Interface\\AddOns\\"..Addon.."\\Assets\\"
local KEYS = {"forge","valarjar","battleheart","venom","shadow","nightblood","tides","magma","storm",
	"crimsonoath","rime","gravebound","felfury","soulfire","abyss","sanctum","covenant","priestvoid",
	"affliction","demonology","destruction","brew","mists","wind","verdant","azure","ebonresonance"}
local MATERIALS = {
	forge={family="Warrior",cell=0,body={.38,.17,.045},light={1,.48,.12},mote={1,.68,.22},motion="embers",speed=.55},
	valarjar={family="Warrior",cell=1,body={.13,.23,.32},light={.42,.70,1},mote={1,.76,.28},motion="runes",speed=.45},
	battleheart={family="Warrior",cell=2,body={.30,.065,.035},light={.92,.25,.08},mote={1,.45,.12},motion="cinders",speed=.65},
	venom={family="Rogue",cell=0,body={.10,.23,.045},light={.48,.77,.14},mote={.60,.84,.22},motion="globules",speed=.45},
	shadow={family="Rogue",cell=1,body={.13,.085,.22},light={.48,.32,.72},mote={.77,.71,.9},motion="smoke",speed=.45},
	nightblood={family="Rogue",cell=2,body={.23,.045,.12},light={.62,.20,.38},mote={.52,.74,.48},motion="veins",speed=.35},
	tides={family="Shaman",cell=0,body={.035,.23,.28},light={.23,.73,.83},mote={.57,.9,.94},motion="water",speed=.60},
	magma={family="Shaman",cell=1,body={.20,.075,.035},light={1,.37,.055},mote={1,.6,.14},motion="lava",speed=.30},
	storm={family="Shaman",cell=2,body={.12,.075,.25},light={.48,.36,.85},mote={.83,.73,1},motion="lightning",speed=.65},
	crimsonoath={family="DeathKnight",label="Death Knight - Crimson Oath",cell=0,body={.22,.025,.045},light={.85,.13,.20},mote={1,.24,.18},motion="blood",speed=.35,particle=true},
	rime={family="DeathKnight",label="Death Knight - Rime",cell=1,body={.05,.16,.25},light={.38,.73,1},mote={.7,.9,1},motion="frost",speed=.40},
	gravebound={family="DeathKnight",label="Death Knight - Gravebound",cell=2,body={.045,.12,.085},light={.34,.57,.40},mote={.58,.78,.48},motion="decay",speed=.30},
	felfury={family="DemonHunter",label="Demon Hunter - Fel Fury",cell=0,body={.07,.16,.015},light={.48,.9,.045},mote={.66,1,.12},motion="slashes",speed=.85,particle=true},
	soulfire={family="DemonHunter",label="Demon Hunter - Soulfire",cell=1,body={.025,.15,.13},light={.16,.72,.61},mote={.46,.93,.82},motion="soul",speed=.55},
	abyss={family="DemonHunter",label="Demon Hunter - Abyss",cell=2,body={.08,.035,.14},light={.46,.24,.68},mote={.76,.57,.94},motion="shards",speed=.65,particle=true},
	sanctum={family="Priest",label="Priest - Sanctum",cell=0,body={.26,.23,.15},light={1,.85,.52},mote={1,.96,.78},motion="veil",speed=.32,particle=true},
	covenant={family="Priest",label="Priest - Covenant",cell=1,body={.17,.12,.23},light={.65,.45,.82},second={1,.84,.52},mote={.94,.87,1},motion="weave",speed=.40,particle=true},
	priestvoid={family="Priest",label="Priest - Void",cell=2,body={.065,.02,.14},light={.48,.12,.78},mote={.73,.45,1},motion="void",speed=.40,particle=true},
	affliction={family="Warlock",label="Warlock - Affliction",cell=0,body={.08,.12,.025},light={.45,.60,.09},mote={.68,.28,.86},motion="curse",speed=.35,particle=true},
	demonology={family="Warlock",label="Warlock - Demonology",cell=1,body={.14,.035,.18},light={.60,.20,.65},mote={1,.31,.075},motion="billow",speed=.40,particle=true},
	destruction={family="Warlock",label="Warlock - Destruction",cell=2,body={.22,.055,.015},light={1,.37,.045},second={.5,.70,.08},mote={1,.60,.12},motion="hellfire",speed=.75,particle=true},
	brew={family="Monk",label="Monk - Brew",cell=0,body={.25,.12,.015},light={.94,.48,.075},mote={1,.76,.34},motion="brew",speed=.40,particle=true},
	mists={family="Monk",label="Monk - Mists",cell=1,body={.025,.17,.12},light={.35,.78,.55},mote={.56,.96,.77},motion="mist",speed=.28},
	wind={family="Monk",label="Monk - Wind",cell=2,body={.045,.13,.14},light={.70,.88,.83},mote={.9,1,.96},motion="wind",speed=.80},
	verdant={family="Evoker",label="Evoker - Verdant",cell=0,body={.025,.17,.08},light={.20,.72,.38},second={1,.34,.08},mote={1,.72,.20},motion="life",speed=.45,particle=true},
	azure={family="Evoker",label="Evoker - Azure",cell=1,body={.025,.075,.24},light={.10,.44,1},second={.61,.22,.90},mote={.43,.82,1},motion="azure",speed=.65,particle=true},
	ebonresonance={family="Evoker",label="Evoker - Ebon Resonance",cell=2,body={.08,.065,.05},light={.65,.45,.20},mote={.93,.70,.36},motion="resonance",speed=.26,particle=true}
}
local EVENTS = {"PLAYER_STARTED_MOVING","PLAYER_STOPPED_MOVING","PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED","PLAYER_MOUNT_DISPLAY_CHANGED","PLAYER_ENTERING_WORLD"}
Effect.GetKeys = function() return KEYS end
Effect.GetInfo = function(_, key) return MATERIALS[key] end
local Setting = function(key, kind) return "lite"..key..kind.."Strength" end
Effect.GetStrength = function(_, key, kind)
	local char=ns.db and ns.db.char
	local value=tonumber(char and char[Setting(key,kind)])
	return value and value==value and math.max(0,math.min(1,value)) or 1
end
Effect.SetStrength = function(self, key, kind, value)
	value=tonumber(value)
	local char=ns.db and ns.db.char
	if (not char or not MATERIALS[key] or (kind~="Crystal" and kind~="Orb")
		or not value or value~=value or InCombatLockdown()) then return false end
	value=math.max(0,math.min(1,value))
	char[Setting(key,kind)]=value~=1 and value or nil
	return ns.ThemeEffects:Refresh()
end
local Read = function(query, fallback)
	if type(query)~="function" then return fallback end
	local value=query()
	if issecretvalue and issecretvalue(value) then return fallback end
	if type(value)=="boolean" then return value end
	return fallback
end
local State = function(frame,event)
	frame.Moving=Read(IsPlayerMoving,frame.Moving)
	frame.Combat=Read(InCombatLockdown,frame.Combat)
	frame.Mounted=Read(IsMounted,frame.Mounted)
	frame.Flying=Read(IsFlying,frame.Flying)
	if event=="PLAYER_STARTED_MOVING" then frame.Moving=true end
	if event=="PLAYER_STOPPED_MOVING" then frame.Moving=false end
	if event=="PLAYER_REGEN_DISABLED" then frame.Combat=true end
	if event=="PLAYER_REGEN_ENABLED" then frame.Combat=false end
	frame.TargetActivity=(frame.Combat or frame.Mounted or frame.Flying) and 1 or (frame.Moving and .6 or .22)
end
-- The complete source is a 2x2 field atlas. UVs stay well inside one cell,
-- including rotations and translation; no neighbour or painted frame is sampled.
local Cell = function(art, cell, angle, x, y, rx, ry)
	local ox,oy=(cell%2)*.5,math.floor(cell/2)*.5
	local c,s=math.cos(angle),math.sin(angle)
	x,y=ox+.25+x,oy+.25+y
	art:SetTexCoord(x-rx*c+ry*s,y-rx*s-ry*c,x-rx*c-ry*s,y-rx*s+ry*c,
		x+rx*c+ry*s,y+rx*s-ry*c,x+rx*c-ry*s,y+rx*s+ry*c)
end
local Paint = function(frame)
	local data=frame.Material
	local phase=frame.Time*math.pi/12
	local motion=data.motion
	for i,art in ipairs(frame.Layers) do
		local angle=.12*math.sin(phase+i)
		local x,y=.018*math.sin(phase+i),.018*math.cos(phase+i)
		local rx,ry=.145,.145
		if motion=="smoke" then angle=phase*(i==1 and 1 or -1);rx,ry=.16,.09
		elseif motion=="veins" then angle=.08*math.sin(phase);rx,ry=.11,.16;y=.02*math.sin(phase+i)
		elseif motion=="water" then angle=.25*math.sin(phase+i);rx,ry=.16,.10
		elseif motion=="lava" then angle=.06*math.sin(phase+i);rx,ry=.155,.13
		elseif motion=="lightning" or motion=="runes" then angle=phase*(i==1 and .5 or -.5);rx,ry=.15,.13
		elseif motion=="globules" then angle=.18*math.sin(phase+i);y=.025*math.sin(phase*.5+i)
		elseif motion=="blood" or motion=="brew" then
			angle=phase*(i==1 and .5 or -.5);rx,ry=.17,.12
		elseif motion=="frost" then angle=.05*math.sin(phase);rx,ry=.20,.18;y=.012*math.sin(phase+i)
		elseif motion=="decay" or motion=="curse" then angle=.16*math.sin(phase+i);rx,ry=.14,.18
		elseif motion=="slashes" then angle=.12;rx,ry=.19,.13;x=.035*math.sin(phase+i);y=x
		elseif motion=="shards" then angle=-phase*(i==1 and .5 or 1);rx,ry=.16,.12
		elseif motion=="soul" or motion=="void" then angle=phase*(i==1 and 1 or -.5);rx,ry=.16,.13
		elseif motion=="veil" or motion=="weave" then
			angle=.20*math.sin(phase+i);rx,ry=.18,.13;x=.028*math.sin(phase+i*2)
		elseif motion=="billow" or motion=="mist" then
			angle=.14*math.sin(phase+i);rx,ry=.18,.14;y=.026*math.sin(phase*.5+i)
		elseif motion=="hellfire" or motion=="life" or motion=="azure" then
			angle=.18*math.sin(phase+i);rx,ry=.15,.18;y=.022*math.sin(phase+i)
		elseif motion=="wind" then angle=phase*(i==1 and 1 or -.5);rx,ry=.18,.10
		elseif motion=="resonance" then
			angle=.035*math.sin(phase+i);rx,ry=.20+.008*math.sin(phase+i),.18
		end
		if motion=="embers" or motion=="lava" then
			-- Keep the broad forged/basalt seams in view instead of magnifying
			-- only a quiet patch at the cell centre. Bounded tilt retains gutters.
			rx,ry=.215,.215;angle=.04*math.sin(phase+i)
			x,y=.008*math.sin(phase+i),.008*math.cos(phase+i)
		end
		if motion=="void" then
			-- Show the curved outer tendrils as well as the dark vortex centre.
			-- A narrow central crop hid the source's recognizable spiral.
			rx,ry=.215,.215;angle=.10*math.sin(phase+i)
			x,y=.003*math.sin(phase+i),.003*math.cos(phase+i)
		end
		Cell(art,data.cell,angle,x,y,rx,ry)
		art:SetAlpha((i==1 and .62 or .22)+.06*frame.Activity+.035*math.sin(phase+i*2))
	end
	local w,h=frame.Width,frame.Height
	for i,art in ipairs(frame.Motes) do
		local p=(frame.Time/8+(i-1)/6)%1
		local x=.22+.56*((i*.618034)%1)+.035*math.sin(phase+i)
		local y=.10+.78*p
		local size,alpha=.026,(.28+.24*frame.Activity)*math.sin(p*math.pi)^2
		local aspect=1
		if motion=="globules" or motion=="water" then size=.12+.025*(i%3)
		elseif motion=="smoke" then
			x=.5+.22*math.sin(phase+i);y=.5+.27*math.cos(phase+i);size=.012;alpha=alpha*.45
		elseif motion=="veins" then
			x=.18+.64*p;y=.45+.18*math.sin(phase+i);size=.018;alpha=alpha*.65
		elseif motion=="runes" then
			x=.5+.23*math.sin(phase+i);y=.5+.25*math.cos(phase+i);size=.13;alpha=alpha*.70
		elseif motion=="lightning" then
			x=.5+.20*math.sin(phase+i);y=.45+.16*math.cos(phase+i);size=.32
			alpha=.42*math.sin(p*math.pi)^18
		elseif motion=="embers" then aspect=2.2;size=.017
		elseif motion=="cinders" then x=.20+.60*p;y=.30+.36*((i*.381966)%1)+.08*math.sin(phase+i)
		elseif motion=="lava" then size=.018;alpha=alpha*.5 end
		if motion=="blood" then
			x=.5+.24*math.sin(phase+i);y=.5+.24*math.cos(phase+i);size=.08;alpha=alpha*.6
		elseif motion=="frost" then y=1-y;x=x+.06*math.sin(phase+i);size=.014
		elseif motion=="decay" or motion=="curse" then
			x=.5+.25*math.sin(phase*.5+i);y=.16+.65*p;size=.014;alpha=alpha*.5
		elseif motion=="slashes" then x=.15+.68*p;y=.12+.72*p;size=.10;aspect=.4
		elseif motion=="shards" or motion=="void" then
			local radius=.33*(1-p)
			x=.5+radius*math.sin(phase+i);y=.5+radius*math.cos(phase+i)
			size=motion=="shards" and .08 or .025
		elseif motion=="soul" then x=.5+.21*math.sin(phase+i+p*3);size=.018;aspect=2
		elseif motion=="veil" or motion=="weave" then size=.04;alpha=alpha*.6
		elseif motion=="billow" or motion=="hellfire" then size=.055;y=.10+.78*p^.8
		elseif motion=="brew" then size=.10+.025*(i%3);x=x+.035*math.sin(phase+i)
		elseif motion=="mist" then size=.022;alpha=alpha*.6
		elseif motion=="wind" then
			x=.5+.32*math.sin(phase+i);y=.5+.23*math.cos(phase+i);size=.025;aspect=.4
		elseif motion=="life" or motion=="azure" then
			x=.5+.23*math.sin(phase+i+p*2);size=.045;aspect=1.5
		elseif motion=="resonance" then
			x=.18+.64*p;y=.5+.20*math.sin(phase+i);size=.035;alpha=alpha*.5
		end
		art:SetPoint("CENTER",frame.Owner,"BOTTOMLEFT",x*w,y*h)
		art:SetSize(w*size,h*size*aspect)
		art:SetAlpha(alpha)
	end
end
local Update = function(frame,elapsed)
	frame.Pending=frame.Pending+elapsed
	if frame.Pending<1/30 then return end
	local delta=frame.Pending;frame.Pending=0
	frame.Poll=frame.Poll+delta
	if frame.Poll>=.25 then frame.Poll=0;State(frame) end
	frame.Activity=frame.Activity+(frame.TargetActivity-frame.Activity)*(1-math.exp(-delta*3))
	frame.Time=(frame.Time+delta*frame.Material.speed*(1+frame.Activity*.5))%48
	Paint(frame)
end
local Stop = function(frame)
	frame.Running=false;frame:SetScript("OnUpdate",nil);frame:UnregisterAllEvents()
end
local Start = function(frame)
	if not frame.Enabled or frame.Running or not frame:IsVisible() then return end
	frame.Running=true;State(frame)
	for _,event in ipairs(EVENTS) do frame:RegisterEvent(event) end
	frame:SetScript("OnUpdate",Update)
end
local Atlas = function(family) return PREFIX.."LitePlus\\"..family:lower().."-materials.tga" end
local Create = function(owner,kind)
	local parent=owner
	local clip
	if kind=="Orb" then parent=owner:GetOverlay()
	else
		clip=CreateFrame("Frame",nil,owner)
		clip:EnableMouse(false);clip:SetClipsChildren(true);clip:SetFrameLevel(owner:GetFrameLevel()+1)
		clip:SetPoint("BOTTOMLEFT",owner,"BOTTOMLEFT");clip:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT")
		clip:SetPoint("TOP",owner:GetStatusBarTexture(),"TOP");parent=clip
	end
	local frame=CreateFrame("Frame",nil,parent)
	frame:EnableMouse(false);frame:SetAllPoints(owner)
	frame:SetFrameLevel(parent:GetFrameLevel()+1)
	frame.Owner,frame.Clip,frame.Kind=owner,clip,kind
	frame.Mask=frame:CreateMaskTexture();frame.Mask:SetAllPoints(owner)
	frame.Body=frame:CreateTexture(nil,"ARTWORK",nil,0)
	frame.Body:SetAllPoints(owner);frame.Body:SetAlpha(.84);frame.Body:AddMaskTexture(frame.Mask)
	frame.Layers,frame.Motes={},{}
	for i=1,2 do
		local art=frame:CreateTexture(nil,"ARTWORK",nil,i)
		art:SetAllPoints(owner);art:SetBlendMode("ADD");art:AddMaskTexture(frame.Mask);frame.Layers[i]=art
	end
	for i=1,6 do
		local art=frame:CreateTexture(nil,"ARTWORK",nil,3)
		art:SetBlendMode("ADD");art:AddMaskTexture(frame.Mask);frame.Motes[i]=art
	end
	frame.Moving,frame.Combat,frame.Mounted,frame.Flying=false,false,false,false
	frame.Time,frame.Pending,frame.Poll,frame.Activity=0,0,0,.22
	frame:SetScript("OnHide",Stop);frame:SetScript("OnShow",Start);frame:SetScript("OnEvent",State)
	return frame
end
Effect.Clear = function(_,owner)
	local frame=owner.ClassResourceEffect
	if not frame then return end
	frame.Enabled=false;Stop(frame);frame:Hide()
	if frame.Clip then frame.Clip:Hide() end
end
Effect.Apply = function(self,owner,key,kind,texturePath)
	local data=MATERIALS[key]
	if not data or self:GetStrength(key,kind)==0 then self:Clear(owner);return false end
	local frame=owner.ClassResourceEffect
	if not frame then frame=Create(owner,kind);owner.ClassResourceEffect=frame end
	frame.Key,frame.Material=key,data
	frame.Width,frame.Height=owner:GetWidth(),owner:GetHeight()
	texturePath=kind=="Orb" and PREFIX.."orb2.tga" or texturePath
	frame.Mask:SetTexture(texturePath,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
	frame.Body:SetTexture(texturePath);frame.Body:SetVertexColor(unpack(data.body))
	for i,art in ipairs(frame.Layers) do
		art:SetTexture(Atlas(data.family));art:SetVertexColor(unpack(i==2 and data.second or data.light))
	end
	for _,art in ipairs(frame.Motes) do
		local motion=data.motion
		if data.particle then
			art:SetTexture(Atlas(data.family));art:SetTexCoord(.5005,.9995,.5005,.9995)
		elseif motion=="globules" or motion=="water" then
			art:SetTexture(Atlas("Rogue"));art:SetTexCoord(.5005,.9995,.5005,.9995)
		elseif motion=="runes" or motion=="lightning" then
			art:SetTexture(Atlas(data.family));art:SetTexCoord(.5005,.9995,.5005,.9995)
		else art:SetTexture(PREFIX.."Paladin\\holy-sphere.tga");art:SetTexCoord(0,1,0,1) end
		art:SetVertexColor(unpack(data.mote))
	end
	frame:SetAlpha(self:GetStrength(key,kind));frame.Enabled=true
	if frame.Clip then frame.Clip:Show() end
	frame:Show();Start(frame);Paint(frame)
	if kind=="Orb" then owner:SetStatusBarTexture(nil,nil) end
	return true
end
Effect.ApplyCrystal = function(self,owner,key,texturePath) return self:Apply(owner,key,"Crystal",texturePath) end
Effect.ApplyOrb = function(self,owner,key) return self:Apply(owner,key,"Orb") end

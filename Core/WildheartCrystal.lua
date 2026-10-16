-- Druid Lite+ material family. Wildheart's public module/setting stay compatible.
-- The native StatusBar owns fill height; never read resource values/geometry.
local Addon, ns = ...
local Effect = {}
ns.WildheartCrystal = Effect
-- A persistent imprint plus native-fill-clipped light sums to full intensity.
-- No resource arithmetic: the engine owns which area receives the extra light.
Effect.EmptyEnergy = .18
local PREFIX = "Interface\\AddOns\\"..Addon.."\\Assets\\"
local FLAVOURS = {
	wildheart={body={.11,.50,.39},mist={{.18,.72,.45},{.20,.46,.65}},veins={.85,.70,.25},
		moon={.60,.79,1},pulse={1,.84,.33},core={1,.75,.30},mote={.65,.86,.45},
		moteTexture="Paladin\\holy-sphere.tga",moteBlend="ADD"},
	moonvein={body={.17,.19,.56},mist={{.65,.75,1},{.35,.48,1}},veins={0,0,0},
		moon={.80,.86,1},pulse={0,0,0},core={0,0,0},mote={.75,.84,1},
		moteTexture="Paladin\\holy-sphere.tga",moteBlend="ADD"},
	dreamsap={body={.09,.36,.22},mist={{1,.74,.24},{.30,.72,.36}},veins={0,0,0},
		moon={.64,.84,.55},pulse={0,0,0},core={0,0,0},mote={.82,.92,.32},
		moteTexture="orb2.tga",moteBlend="ADD"}
}
Effect.GetFlavour = function(self, key) return FLAVOURS[key] or FLAVOURS.wildheart end
local EVENTS = {"PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ENTERING_WORLD"}
-- Quadratic branches: core -> bend -> tip, normalized to the unchanged canvas.
local PATHS = {
	{.50,.30,.40,.45,.39,.76}, {.50,.30,.59,.49,.61,.74},
	{.50,.30,.67,.40,.75,.49}, {.50,.30,.32,.38,.27,.57},
	{.50,.30,.52,.55,.50,.83}, {.50,.30,.61,.23,.66,.18}
}
local Branch = function(path, p)
	local q=1-p
	return q*q*path[1]+2*q*p*path[3]+p*p*path[5], q*q*path[2]+2*q*p*path[4]+p*p*path[6]
end
local NewSample = function()
	local s={motes={},pulses={},mist={{coords={}},{coords={}}}}
	for i=1,#PATHS do s.motes[i]={};s.pulses[i]={} end
	return s
end
local MistCoords = function(coords, angle, x, y, rx, ry)
	rx,ry=rx or .28,ry or .28
	local c,s=math.cos(angle),math.sin(angle)
	-- WoW's eight-coordinate order: upper-left, lower-left, upper-right, lower-right.
	coords[1],coords[2]=x-rx*c+ry*s,y-rx*s-ry*c
	coords[3],coords[4]=x-rx*c-ry*s,y-rx*s+ry*c
	coords[5],coords[6]=x+rx*c+ry*s,y+rx*s-ry*c
	coords[7],coords[8]=x+rx*c-ry*s,y+rx*s+ry*c
end
local Strength = function(flavour)
	local key=(FLAVOURS[flavour] and flavour or "wildheart").."Strength"
	local v = tonumber(ns.db and ns.db.char and ns.db.char[key])
	return v and v==v and math.max(0,math.min(1,v)) or 1
end
Effect.GetStrength = function(self, flavour) return Strength(flavour) end
Effect.SetStrength = function(self, value, flavour)
	value=tonumber(value)
	if (not value or value~=value or InCombatLockdown()) then return false end
	value=math.max(0,math.min(1,value))
	local key=(FLAVOURS[flavour] and flavour or "wildheart").."Strength"
	ns.db.char[key]=value~=1 and value or nil
	return ns.ThemeEffects:Refresh()
end
local Read = function(query, fallback)
	if (type(query)~="function") then return fallback end
	local value=query()
	if (issecretvalue and issecretvalue(value)) then return fallback end
	if type(value)=="boolean" then return value end
	return fallback
end
local State = function(frame, event)
	local wasMoving=frame.Moving
	frame.Moving=Read(IsPlayerMoving,frame.Moving)
	frame.Combat=Read(InCombatLockdown,frame.Combat)
	frame.Mounted=Read(IsMounted,frame.Mounted)
	frame.Flying=Read(IsFlying,frame.Flying)
	if event=="PLAYER_STARTED_MOVING" then frame.Moving=true end
	if event=="PLAYER_STOPPED_MOVING" then frame.Moving=false end
	if event=="PLAYER_REGEN_DISABLED" then frame.Combat=true end
	if event=="PLAYER_REGEN_ENABLED" then frame.Combat=false end
	if frame.Moving~=wasMoving then frame.Impulse=frame.Moving and .65 or -.65 end
	frame.TargetActivity=(frame.Combat or frame.Mounted or frame.Flying) and 1 or (frame.Moving and .6 or .22)
end

-- A normalized sampling contract shared by runtime and the actual-asset demo.
-- Optional out table avoids allocating layer state on every runtime update.
Effect.Sample = function(self, time, activity, out, impulse, flavour)
	out=out or NewSample()
	impulse=impulse or 0
	local phase=time*math.pi/4
	local breath=.5+.5*math.sin(phase)
	out.veins=.14+.06*breath+.045*activity
	out.coreAlpha=.42+.30*breath+.12*activity
	out.coreScale=.84+.20*breath+.08*activity
	out.coreX=.50+.012*math.sin(phase*2)+impulse*.012
	out.coreY=.30+.008*math.sin(phase*3)
	out.moonAlpha=.055+.025*math.cos(phase+.6)
	out.u=.025+.015*math.sin(phase-.5)
	out.v=.025+.015*math.cos(phase-.9)
	for i,mist in ipairs(out.mist) do
		local direction=i==1 and 1 or -1
		mist.alpha=(i==1 and .25 or .18)+.12*activity+.04*math.sin(phase+i*2)
		MistCoords(mist.coords, direction*phase+i, .50+.055*math.sin(phase+i)+impulse*.045,
			.50+.045*math.cos(phase*2+i))
	end
	for i,path in ipairs(PATHS) do
		local progress=(time/8+(i-1)/#PATHS)%1
		local pulse=out.pulses[i]
		pulse.x,pulse.y=Branch(path,progress)
		pulse.alpha=(.58+.35*activity)*math.sin(progress*math.pi)^2
		local mote=out.motes[i]
		local travel=.5-.5*math.cos(progress*math.pi*2)
		mote.x,mote.y=Branch(path,travel)
		local orbit=math.sin(progress*math.pi)^2
		mote.x=mote.x+.018*math.cos(phase*3+i)*orbit
		mote.y=mote.y+.015*math.sin(phase*3+i)*orbit
		mote.alpha=(.32+.48*activity)*orbit
		mote.size=.022
	end
	if flavour=="moonvein" or flavour=="dreamsap" then
		-- Each material has its own motion, not just a different palette.
		out.veins,out.coreAlpha=0,0
		out.moonAlpha=(flavour=="moonvein" and .14 or .045)+.035*math.cos(phase+.6)
		for i,pulse in ipairs(out.pulses) do pulse.alpha=0 end
		for i,mist in ipairs(out.mist) do
			if flavour=="moonvein" then
				mist.alpha=(i==1 and .34 or .21)+.10*activity+.04*math.sin(phase+i)
				MistCoords(mist.coords,i*.65+.32*math.sin(phase+i),
					.50+.07*math.sin(phase+i)+impulse*.045,.50+.06*math.cos(phase+i),.31,.21)
			else
				mist.alpha=(i==1 and .32 or .14)+.09*activity+.035*math.sin(phase+i)
				MistCoords(mist.coords,.16*math.sin(phase+i),
					.50+.045*math.sin(phase+i)+impulse*.035,.50+.045*math.cos(phase+i),.18,.37)
			end
		end
		for i,mote in ipairs(out.motes) do
			local p=(time/8+(i-1)/#PATHS)%1
			if flavour=="moonvein" then
				mote.x=.50+.18*math.sin(phase+i)
				mote.y=.50+.28*math.cos(phase+i*.8)
				mote.size=.013
				mote.alpha=(.35+.35*activity)*math.sin(p*math.pi)^2
			else
				mote.x=.50+.14*math.sin(phase+i)+.025*math.sin(p*math.pi*2+i)
				mote.y=.14+.70*p
				mote.size=.035+.018*(i%3)
				mote.alpha=(.26+.22*activity)*math.sin(p*math.pi)^2
			end
		end
	end
	return out
end
local PaintParts = function(frame, parts, s)
	local w,h=frame.Width,frame.Height
	parts.Veins:SetAlpha(s.veins)
	parts.Core:SetAlpha(s.coreAlpha)
	parts.Core:SetSize(w*.12*s.coreScale,h*.17*s.coreScale)
	parts.Core:SetPoint("CENTER",frame.Power,"BOTTOMLEFT",w*s.coreX,h*s.coreY)
	parts.Moon:SetAlpha(s.moonAlpha)
	parts.Moon:SetTexCoord(s.u,s.u+.95,s.v,s.v+.95)
	for i,mist in ipairs(s.mist) do
		parts.Mist[i]:SetTexCoord(unpack(mist.coords))
		parts.Mist[i]:SetAlpha(mist.alpha)
	end
	for i,pulse in ipairs(s.pulses) do
		local art=parts.Pulses[i]
		art:SetPoint("CENTER",frame.Power,"BOTTOMLEFT",pulse.x*w,pulse.y*h)
		art:SetAlpha(pulse.alpha)
	end
	for i,mote in ipairs(s.motes) do
		local art=parts.Motes[i]
		art:SetPoint("CENTER",frame.Power,"BOTTOMLEFT",mote.x*w,mote.y*h)
		art:SetAlpha(mote.alpha)
		art:SetSize(w*mote.size,h*mote.size)
	end
end
local Paint = function(frame)
	local s=Effect:Sample(frame.Time,frame.Activity,frame.Sample,frame.Impulse,frame.Flavour)
	PaintParts(frame,frame,s)
	PaintParts(frame,frame.AmbientParts,s)
end
local Update = function(frame, elapsed)
	frame.Pending=frame.Pending+elapsed
	if frame.Pending<1/30 then return end
	local delta=frame.Pending;frame.Pending=0
	frame.Poll=frame.Poll+delta
	if frame.Poll>=.25 then frame.Poll=0;State(frame) end
	frame.Activity=frame.Activity+(frame.TargetActivity-frame.Activity)*(1-math.exp(-delta*3))
	-- Continuous phase: activity changes speed without jumping the pattern.
	frame.Time=(frame.Time+delta*(1+math.max(0,(frame.Activity-.22)/.78)))%24
	frame.Impulse=frame.Impulse*math.exp(-delta*2)
	Paint(frame)
end
local Stop = function(frame)
	frame.Running=false
	frame:SetScript("OnUpdate",nil)
	frame:UnregisterAllEvents()
end
local Start = function(frame)
	if not frame.Enabled or frame.Running or not frame:IsVisible() then return end
	frame.Running=true;State(frame)
	for _,event in ipairs(EVENTS) do frame:RegisterEvent(event) end
	frame:SetScript("OnUpdate",Update)
end
local Create = function(power)
	-- The animation owner stays full-height even at zero resource.
	local frame=CreateFrame("Frame",nil,power)
	frame:EnableMouse(false);frame:SetAllPoints(power)
	frame:SetFrameLevel(power:GetFrameLevel()+1)
	local ambient=CreateFrame("Frame",nil,frame)
	ambient:EnableMouse(false);ambient:SetAllPoints(power)
	-- Both ADD groups must draw after the BLEND body, otherwise it would
	-- paint over the ambient contribution in the filled portion.
	ambient:SetFrameLevel(power:GetFrameLevel()+3)
	ambient:SetAlpha(Effect.EmptyEnergy)
	local clip=CreateFrame("Frame",nil,frame)
	clip:EnableMouse(false);clip:SetClipsChildren(true)
	clip:SetFrameLevel(power:GetFrameLevel()+2)
	clip:SetPoint("BOTTOMLEFT",power,"BOTTOMLEFT")
	clip:SetPoint("BOTTOMRIGHT",power,"BOTTOMRIGHT")
	clip:SetPoint("TOP",power:GetStatusBarTexture(),"TOP")
	local fill=CreateFrame("Frame",nil,clip)
	fill:EnableMouse(false);fill:SetAllPoints(power)
	fill:SetFrameLevel(power:GetFrameLevel()+2)
	local bright=CreateFrame("Frame",nil,fill)
	bright:EnableMouse(false);bright:SetAllPoints(power)
	bright:SetFrameLevel(power:GetFrameLevel()+3)
	bright:SetAlpha(1-Effect.EmptyEnergy)
	frame.Clip,frame.Power,frame.Fill,frame.Ambient,frame.Bright=clip,power,fill,ambient,bright
	frame.Moving,frame.Combat,frame.Mounted,frame.Flying=false,false,false,false
	frame.Time,frame.Pending,frame.Poll,frame.Activity,frame.Impulse=0,0,0,.22,0
	frame.Sample=NewSample()
	frame.Mask=frame:CreateMaskTexture()
	frame.Mask:SetAllPoints(power)
	frame.VeinMask=frame:CreateMaskTexture()
	frame.VeinMask:SetAllPoints(power)
	frame.VeinMask:SetTexture(PREFIX.."Druid\\wildheart-veins.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
	local function layer(owner,texture,r,g,b,blend,full,level)
		local art=owner:CreateTexture(nil,"ARTWORK",nil,level or 0)
		art:SetTexture(texture);art:SetVertexColor(r,g,b)
		art:SetBlendMode(blend)
		if full then art:SetAllPoints(power) end
		art:AddMaskTexture(frame.Mask)
		return art
	end
	frame.Body=layer(fill,nil,.11,.50,.39,"BLEND",true)
	frame.Body:SetAlpha(.92)
	local function parts(owner)
		local p={Mist={},Pulses={},Motes={}}
		for i=1,2 do p.Mist[i]=layer(owner,PREFIX.."Druid\\dreamlight.tga",1,1,1,"ADD",true,i) end
		p.Veins=layer(owner,PREFIX.."Druid\\wildheart-veins.tga",1,1,1,"ADD",true,3)
		p.Moon=layer(owner,PREFIX.."Druid\\dreamlight.tga",1,1,1,"ADD",true,4)
		for i=1,#PATHS do
			local art=layer(owner,PREFIX.."Paladin\\holy-sphere.tga",1,1,1,"ADD",false,5)
			art:AddMaskTexture(frame.VeinMask)
			p.Pulses[i]=art
			p.Motes[i]=layer(owner,PREFIX.."Paladin\\holy-sphere.tga",1,1,1,"ADD",false,7)
		end
		p.Core=layer(owner,PREFIX.."Paladin\\holy-sphere.tga",1,1,1,"ADD",false,6)
		return p
	end
	for key,value in pairs(parts(bright)) do frame[key]=value end
	frame.AmbientParts=parts(ambient)
	frame:SetScript("OnEvent",State);frame:SetScript("OnHide",Stop);frame:SetScript("OnShow",Start)
	return frame
end
Effect.Clear = function(self, power)
	local frame=power.Wildheart
	if not frame then return end
	frame.Enabled=false;Stop(frame);frame:Hide();frame.Clip:Hide()
end
Effect.Apply = function(self, power, texture, flavour)
	flavour=FLAVOURS[flavour] and flavour or "wildheart"
	if Strength(flavour)==0 then self:Clear(power);return end
	local frame=power.Wildheart
	if not frame then frame=Create(power);power.Wildheart=frame end
	frame.Flavour=flavour
	frame.Width,frame.Height=power:GetWidth(),power:GetHeight()
	local palette=FLAVOURS[flavour]
	frame.Body:SetVertexColor(unpack(palette.body))
	local function paletteParts(p)
		p.Veins:SetVertexColor(unpack(palette.veins))
		p.Moon:SetVertexColor(unpack(palette.moon))
		p.Core:SetVertexColor(unpack(palette.core))
		for i,art in ipairs(p.Mist) do art:SetVertexColor(unpack(palette.mist[i])) end
		for _,art in ipairs(p.Pulses) do
			art:SetVertexColor(unpack(palette.pulse));art:SetSize(frame.Width*.22,frame.Height*.25)
		end
		for _,art in ipairs(p.Motes) do
			art:SetTexture(PREFIX..palette.moteTexture);art:SetBlendMode(palette.moteBlend)
			art:SetVertexColor(unpack(palette.mote))
		end
	end
	paletteParts(frame);paletteParts(frame.AmbientParts)
	frame.Body:SetTexture(texture)
	frame.Mask:SetTexture(texture,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
	frame:SetAlpha(Strength(flavour))
	frame.Enabled=true;frame.Clip:Show();frame:Show();Start(frame);Paint(frame)
end

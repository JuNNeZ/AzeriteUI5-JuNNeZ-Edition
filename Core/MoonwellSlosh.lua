-- Moonwell+: an opt-in Lite+ material. Native LibOrb owns the resource level;
-- this module reads only our fixed orb dimensions, elapsed time and player state.
local Addon, ns = ...
local Slosh = {}
ns.MoonwellSlosh = Slosh
local WATER = "Interface\\AddOns\\"..Addon.."\\Assets\\Druid\\orb-moonwell.tga"
local MASK = "Interface\\AddOns\\"..Addon.."\\Assets\\orb2.tga"
local COLUMNS, STEP = 32, 1/30
local EVENTS = {
	"PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ENTERING_WORLD"
}

local Strength = function()
	local value = ns.db and ns.db.char and tonumber(ns.db.char.moonwellSloshStrength)
	if (not value or value ~= value) then return 1 end
	return math.max(0, math.min(1, value))
end
Slosh.GetStrength = function(self) return Strength() end
Slosh.SetStrength = function(self, value)
	value = tonumber(value)
	if (not value or value ~= value or InCombatLockdown()) then return false end
	value = math.max(0, math.min(1, value))
	ns.db.char.moonwellSloshStrength = value ~= 1 and value or nil
	return ns.ThemeEffects:Refresh()
end

-- Unknown/secret state stays at the last readable state. Never branch on a
-- secret boolean. Movement events also work when the optional query is absent.
local ReadState = function(query, previous)
	if (type(query) ~= "function") then return previous end
	local value = query()
	if (issecretvalue and issecretvalue(value)) then return previous end
	if (type(value) ~= "boolean") then return previous end
	return value
end
local SampleState = function(frame, event)
	local moving = ReadState(IsPlayerMoving, frame.Moving or false)
	if (event == "PLAYER_STARTED_MOVING") then moving = true end
	if (event == "PLAYER_STOPPED_MOVING") then moving = false end
	if (moving ~= frame.Moving) then
		frame.Impulse = moving and .55 or -.55
		frame.Moving = moving
	end
	frame.Combat = ReadState(InCombatLockdown, frame.Combat or false)
	if (event == "PLAYER_REGEN_DISABLED") then frame.Combat = true end
	if (event == "PLAYER_REGEN_ENABLED") then frame.Combat = false end
	frame.Mounted = ReadState(IsMounted, frame.Mounted or false)
	frame.Flying = ReadState(IsFlying, frame.Flying or false)
	local busy = frame.Combat or frame.Mounted or frame.Flying
	frame.Mode = busy and "active" or (frame.Moving and "moving" or "quiet")
	frame.TargetActivity = busy and 1 or (frame.Moving and .6 or .22)
end

local Paint = function(frame)
	local phase = frame.Time*math.pi/2
	local amplitude = frame.OrbHeight*.026*frame.Activity*frame.Strength
 local u = .025 + .015*math.sin(phase-.55)
 local v = .025 + .015*math.cos(phase-.95)
	for i, column in ipairs(frame.Columns) do
		local x = (i-.5)/COLUMNS*2-1
		local wave = .65*x*math.sin(phase) + .22*math.sin(x*3.4-phase*2)
			+ .10*math.sin(x*6+phase*3-.8) + frame.Impulse*x*.25
		-- Trough-only deformation: every crest stays at/below the native edge.
		-- The unmodified native parent clip therefore guarantees an empty orb
		-- cannot acquire water, without any resource/secret value comparisons.
		local dip = math.max(0, amplitude*(1+wave))
		column.Clip:SetPoint("TOPLEFT", frame.Edge, "TOPLEFT", frame.OrbWidth*(i-1)/COLUMNS, -dip)
		column.Water:SetTexCoord(u, u+.95, v, v+.95)
		column.Rim:SetAlpha((.35+.2*frame.Activity))
	end
end
local Update = function(frame, elapsed)
	frame.Pending = frame.Pending + elapsed
	if (frame.Pending < STEP) then return end
	local delta = frame.Pending
	frame.Pending = 0
	frame.Time = (frame.Time+delta)%24
	frame.Poll = frame.Poll+delta
	if (frame.Poll >= .25) then frame.Poll = 0; SampleState(frame) end
	frame.Activity = frame.Activity + (frame.TargetActivity-frame.Activity)*(1-math.exp(-delta*3))
	frame.Impulse = frame.Impulse*math.exp(-delta*1.8)
	Paint(frame)
end
local Stop = function(frame)
	frame.Running = false
	frame:SetScript("OnUpdate", nil)
	frame:UnregisterAllEvents()
end
local Start = function(frame)
	if (not frame.Enabled or frame.Running or not frame:IsVisible()) then return end
	frame.Running = true
	SampleState(frame)
	for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
	frame:SetScript("OnUpdate", Update)
	Paint(frame)
end
local Color = function(frame, ...)
	for _, column in ipairs(frame.Columns) do column.Water:SetVertexColor(...) end
end

local Create = function(orb)
	local frame = CreateFrame("Frame", nil, orb:GetOverlay())
	frame:SetAllPoints(orb)
	frame:EnableMouse(false)
	frame:SetFrameLevel(orb:GetOverlay():GetFrameLevel()+1)
	frame.Edge, frame.Orb = orb:GetOverlay(), orb
	frame.Columns = {}
	frame.Moving, frame.Combat, frame.Mounted, frame.Flying = false, false, false, false
	frame.Time, frame.Pending, frame.Poll, frame.Activity, frame.Impulse = 0, 0, 0, .22, 0
	for i = 1, COLUMNS do
		local clip = CreateFrame("Frame", nil, frame)
		clip:EnableMouse(false)
		clip:SetClipsChildren(true)
		local content = CreateFrame("Frame", nil, clip)
		content:EnableMouse(false)
		content:SetAllPoints(orb)
		local mask = content:CreateMaskTexture()
		mask:SetAllPoints(orb)
		mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		local water = content:CreateTexture(nil, "ARTWORK")
		water:SetAllPoints(orb)
		water:SetTexture(WATER)
		water:SetAlpha(.88)
		water:AddMaskTexture(mask)
		local rim = content:CreateTexture(nil, "OVERLAY")
		rim:SetTexture("Interface\\Buttons\\WHITE8X8")
		rim:SetVertexColor(.52, .85, 1)
		rim:SetBlendMode("ADD")
		rim:SetPoint("TOPLEFT", clip, "TOPLEFT")
		rim:SetPoint("TOPRIGHT", clip, "TOPRIGHT")
		rim:SetHeight(.8)
		rim:AddMaskTexture(mask)
		frame.Columns[i] = { Clip = clip, Water = water, Rim = rim, Mask = mask }
	end
	frame:SetScript("OnEvent", SampleState)
	frame:SetScript("OnHide", Stop)
	frame:SetScript("OnShow", Start)
	-- Forward colour without inspecting native resource values or changing the
	-- existing palette resolver. This hook is installed once and owns no events.
	hooksecurefunc(orb, "SetStatusBarColor", function(_, ...) if (frame.Enabled) then Color(frame, ...) end end)
	return frame
end

Slosh.Clear = function(self, orb)
	local frame = orb.MoonwellSlosh
	if (not frame) then return end
	frame.Enabled = false
	Stop(frame)
	frame:Hide()
end
Slosh.Apply = function(self, orb)
	local strength = Strength()
	if (strength == 0) then self:Clear(orb); return false end
	local frame = orb.MoonwellSlosh
	if (not frame) then frame = Create(orb); orb.MoonwellSlosh = frame end
	frame.Strength = strength
	frame:SetAlpha(strength)
	-- These are the fixed widget dimensions, never the native clip's height.
	frame.OrbWidth, frame.OrbHeight = orb:GetWidth(), orb:GetHeight()
	for i, column in ipairs(frame.Columns) do
		column.Clip:SetPoint("BOTTOMRIGHT", orb, "BOTTOMLEFT", frame.OrbWidth*i/COLUMNS, 0)
	end
	Color(frame, orb:GetStatusBarColor())
	-- Native levels/animations stay intact, but their straight-edged painting
	-- stands aside. Returning false on exit lets Player.lua restore its material.
	orb:SetStatusBarTexture(nil, nil)
	frame.Enabled = true
	frame:Show()
	Start(frame)
	Paint(frame)
	return true
end

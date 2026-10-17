-- Moonwell+ material and a shared slosh edge for the selected orb painting.
-- Native LibOrb owns the level; only fixed dimensions/time/player state are read.
local Addon, ns = ...
local Slosh = {}
ns.MoonwellSlosh = Slosh
local WATER = "Interface\\AddOns\\"..Addon.."\\Assets\\Druid\\orb-moonwell.tga"
local MASK = "Interface\\AddOns\\"..Addon.."\\Assets\\orb2.tga"
local BACKDROP = "Interface\\AddOns\\"..Addon.."\\Assets\\orb-backdrop2.tga"
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
		if (frame.FlowingMana) then
			-- Restore just the shallow trough to the actual empty-orb backdrop.
			-- The chosen LibOrb layers and theme particles keep animating below;
			-- no duplicated effect players or native texture replacement is needed.
			column.Clip:SetPoint("BOTTOMRIGHT", frame.Edge, "TOPLEFT", frame.OrbWidth*i/COLUMNS, -dip)
		else
			column.Clip:SetPoint("TOPLEFT", frame.Edge, "TOPLEFT", frame.OrbWidth*(i-1)/COLUMNS, -dip)
			column.Water:SetTexCoord(u, u+.95, v, v+.95)
		end
		column.Rim:SetAlpha(frame.FlowingMana and 0 or (.35+.2*frame.Activity))
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
	for _, column in ipairs(frame.Columns) do
		if (frame.FlowingMana) then
			local backdrop = frame.Orb.Backdrop
			if (backdrop) then column.Water:SetVertexColor(backdrop:GetVertexColor())
			else column.Water:SetVertexColor(1, 1, 1, 1) end
			column.Rim:SetVertexColor(...)
		else
			column.Water:SetVertexColor(...)
			column.Rim:SetVertexColor(.52, .85, 1)
		end
	end
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
		frame.Columns[i] = { Clip = clip, Content = content, Water = water, Rim = rim, Mask = mask }
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
Slosh.Apply = function(self, orb, flowingMana)
	-- The general player toggle does not inherit Moonwell+'s own strength.
	local strength = flowingMana and 1 or Strength()
	if (strength == 0) then self:Clear(orb); return false end
	local frame = orb.MoonwellSlosh
	if (not frame) then frame = Create(orb); orb.MoonwellSlosh = frame end
	frame.FlowingMana = flowingMana == true
	frame.Strength = strength
	frame:SetAlpha(strength)
	-- Above native/Druid/Paladin paint, below the orb's existing glass/case.
	frame:SetFrameLevel(orb:GetOverlay():GetFrameLevel() + (frame.FlowingMana and 2 or 1))
	-- These are the fixed widget dimensions, never the native clip's height.
	frame.OrbWidth, frame.OrbHeight = orb:GetWidth(), orb:GetHeight()
	for i, column in ipairs(frame.Columns) do
		column.Clip:SetFrameLevel(frame:GetFrameLevel())
		column.Content:SetFrameLevel(frame:GetFrameLevel())
		column.Water:ClearAllPoints()
		if (frame.FlowingMana) then
			local backdrop = orb.Backdrop
			column.Clip:SetPoint("TOPLEFT", frame.Edge, "TOPLEFT", frame.OrbWidth*(i-1)/COLUMNS, 0)
			column.Water:SetTexture(backdrop and backdrop:GetTexture() or BACKDROP)
			if (backdrop) then column.Water:SetAllPoints(backdrop)
			else
				-- First construction precedes Player.lua's optional art textures.
				column.Water:SetPoint("CENTER", orb, "CENTER")
				column.Water:SetSize(frame.OrbWidth*180/103, frame.OrbHeight*180/103)
			end
			column.Water:SetTexCoord(0, 1, 0, 1)
			column.Water:SetAlpha(1)
		else
			column.Clip:SetPoint("BOTTOMRIGHT", orb, "BOTTOMLEFT", frame.OrbWidth*i/COLUMNS, 0)
			column.Water:SetTexture(WATER)
			column.Water:SetAllPoints(orb)
			column.Water:SetAlpha(.88)
		end
		column.Rim:ClearAllPoints()
		local left = frame.FlowingMana and "BOTTOMLEFT" or "TOPLEFT"
		local right = frame.FlowingMana and "BOTTOMRIGHT" or "TOPRIGHT"
		column.Rim:SetPoint(left, column.Clip, left)
		column.Rim:SetPoint(right, column.Clip, right)
	end
	Color(frame, orb:GetStatusBarColor())
	-- Standalone Moonwell+ owns its water painting; generic slosh leaves the
	-- selected LibOrb material and all of its native animation groups intact.
	if (not frame.FlowingMana) then orb:SetStatusBarTexture(nil, nil) end
	frame.Enabled = true
	frame:Show()
	Start(frame)
	Paint(frame)
	return true
end

Slosh.ApplyMoonwell = function(self, orb, flowingMana)
	-- Moonwell+ remains a selectable water material in its own right. Generic
	-- Flowing mana supplies its edge, without borrowing Moonwell+'s strength.
	if (flowingMana) then orb:SetStatusBarTexture(WATER, WATER) end
	return self:Apply(orb, flowingMana)
end

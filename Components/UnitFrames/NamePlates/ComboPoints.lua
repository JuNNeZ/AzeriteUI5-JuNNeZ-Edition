-- Forever has target-bound combo points, without Retail specialization gates.
-- Keep the count opaque: native StatusBars clamp it into each point's range.
local _, ns = ...
local NP = ns.NamePlatesPrivate
if (not NP) then return end

local mod = NP.NamePlatesMod
local _, class = UnitClass("player")
local supported = ns.IsForever and (class == "ROGUE" or class == "DRUID")
local crystalTexture = ns.API.GetMedia("point_crystal")
local socketTexture = ns.API.GetMedia("point_plate")
local watcher
local POINT_HEIGHT, BAR_GAP, NAME_GAP = 6, 1, 1
local POINT_WIDTH, POINT_PITCH, CRYSTAL_SIZE = 6, 9, 3
local gateTexture = [[Interface\Buttons\WHITE8x8]]

local GetComboPointScale = function()
	local scale = mod.db and mod.db.profile.comboPointScale
	if (NP.IsSecretValue(scale) or type(scale) ~= "number") then return 1 end
	return math.max(.5, math.min(3, scale))
end

-- Reserve one band in the existing name/aura stack, only while our row is shown.
-- The same lift goes to both so their spacing and target/widget lifts survive.
-- An opaque zero can mask pixels but cannot collapse layout from addon code;
-- non-target rows with secret counts therefore retain this small reservation.
local GetComboPointNameLift = function(plate)
	local row = plate.ForeverComboPoints
	return row and row:IsShown() and (BAR_GAP + POINT_HEIGHT * (row.comboScale or 1) + NAME_GAP) or 0
end

-- Size only owned geometry, including the mask, without reading secret fill edges.
local ApplyComboPointScale = function(plate)
	local row, scale = plate.ForeverComboPoints, GetComboPointScale()
	if (row.comboScale == scale) then return end
	row.comboScale = scale
	local width, height = (4 * POINT_PITCH + POINT_WIDTH) * scale, POINT_HEIGHT * scale
	row:SetSize(width, height)
	row.VisibilityMask:SetSize(width, height)
	for i = 1, 5 do
		local point = row[i]
		point:SetSize(CRYSTAL_SIZE * scale, CRYSTAL_SIZE * scale)
		point:ClearAllPoints()
		point:SetPoint("CENTER", row, "LEFT", (POINT_WIDTH / 2 + (i - 1) * POINT_PITCH) * scale, 0)
		point.Socket:SetSize(POINT_WIDTH * scale, height)
	end
	if (row:IsShown() and NP.NamePlate_PostUpdatePositions) then NP.NamePlate_PostUpdatePositions(plate) end
end

local SetRowShown = function(plate, shown)
	local row = plate.ForeverComboPoints
	if (row:IsShown() == shown) then return end
	row:SetShown(shown)
	-- Form/power/setting events can change the row without a full plate layout.
	if (NP.NamePlate_PostUpdatePositions) then NP.NamePlate_PostUpdatePositions(plate) end
end

local ClearComboPoints = function(plate)
	local row = plate.ForeverComboPoints
	if (not row) then return end
	SetRowShown(plate, false)
	for i = 1, 5 do row[i]:SetValue(0) end
	row.VisibilityGate:SetValue(0)
end

local IsActive = function()
	return supported and mod:IsEnabled() and mod.db and mod.db.profile.enabled
		and not mod.conflictingAddOn and mod.db.profile.showComboPoints
		and type(GetComboPoints) == "function"
end

local UpdateComboPoints = function(plate)
	if (not IsActive() or not ns.ActiveNamePlates[plate] or plate.isPRD or plate.isObjectPlate
		or plate.nameplateShowsWidgetsOnly or not NP.IsSafeUnitToken(plate.unit)
		or not NP.ShouldShowNamePlateForBlizzardVisibility(plate)
		or not NP.IsSafeTrue(UnitCanAttack("player", plate.unit))
		or not NP.IsSafeFalse(UnitIsDeadOrGhost(plate.unit))
		or not NP.IsSafeFalse(UnitHasVehicleUI("player"))) then
		return ClearComboPoints(plate)
	end
	if (class == "DRUID") then
		local power = UnitPowerType("player")
		if (NP.IsSecretValue(power) or power ~= Enum.PowerType.Energy) then
			return ClearComboPoints(plate)
		end
	end

	-- Ask for this mob, not the selected target; never cache a count on a reused plate.
	local count = GetComboPoints("player", plate.unit)
	-- Missing data clears rather than retaining points from a previous unit.
	if (type(count) ~= "number") then count = 0 end
	local isTarget = NP.SafeUnitMatches(plate.unit, "target")
	if (not isTarget and not NP.IsSecretValue(count) and count <= 0) then
		return ClearComboPoints(plate)
	end
	local row = plate.ForeverComboPoints
	if (not row) then
		row = CreateFrame("Frame", nil, plate)
		row:Hide()
		row:EnableMouse(false)
		row:SetSize(4 * POINT_PITCH + POINT_WIDTH, POINT_HEIGHT)
		row:SetPoint("BOTTOM", plate.Health, "TOP", 0, BAR_GAP)
		row:SetFrameLevel(plate.Overlay:GetFrameLevel() + 1)
		-- As in PlayerClassPower's secret gates: the client moves a mask with a
		-- [0,1] fill. At zero it parks left of the row; at >=1 it covers the row.
		-- All geometry is fixed; addon code never reads the secret fill's edge.
		local gate = CreateFrame("StatusBar", nil, row)
		gate:EnableMouse(false)
		gate:SetAllPoints(row)
		gate:SetStatusBarTexture(gateTexture)
		local gateFill = gate:GetStatusBarTexture()
		gateFill:SetAlpha(0)
		gate:SetMinMaxValues(0, 1)
		local mask = gate:CreateMaskTexture()
		mask:SetTexture(gateTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetSize(4 * POINT_PITCH + POINT_WIDTH, POINT_HEIGHT)
		mask:SetPoint("RIGHT", gateFill, "RIGHT", 0, 0)
		row.VisibilityGate = gate
		row.VisibilityMask = mask
		for i = 1, 5 do
			local point = CreateFrame("StatusBar", nil, row)
			point:EnableMouse(false)
			point:SetSize(CRYSTAL_SIZE, CRYSTAL_SIZE)
			point:SetPoint("CENTER", row, "LEFT", POINT_WIDTH / 2 + (i - 1) * POINT_PITCH, 0)
			point:SetStatusBarTexture(crystalTexture)
			point:GetStatusBarTexture():AddMaskTexture(mask)
			-- A static gold fifth crystal marks the finisher; no secret-count colour logic.
			if (i == 5) then
				point:SetStatusBarColor(1, .78, .25)
			else
				point:SetStatusBarColor(.25, .8, 1)
			end
			point:SetMinMaxValues(i - 1, i)
			local socket = point:CreateTexture(nil, "BACKGROUND", nil, -1)
			socket:SetPoint("CENTER")
			socket:SetSize(POINT_WIDTH, POINT_HEIGHT)
			socket:SetTexture(socketTexture)
			socket:SetVertexColor(211/255, 200/255, 169/255)
			socket:AddMaskTexture(mask)
			point.Socket = socket
			local background = point:CreateTexture(nil, "BACKGROUND")
			background:SetAllPoints()
			background:SetTexture(crystalTexture)
			background:SetVertexColor(.12, .16, .18)
			background:AddMaskTexture(mask)
			row[i] = point
		end
		plate.ForeverComboPoints = row
	end
	ApplyComboPointScale(plate)
	for i = 1, 5 do row[i]:SetValue(count) end
	-- Your target keeps its empty sockets; other mobs show only while they own points.
	if (isTarget) then row.VisibilityGate:SetValue(1) else row.VisibilityGate:SetValue(count) end
	SetRowShown(plate, true)
end

local RefreshComboPoints = function()
	for plate in pairs(ns.ActiveNamePlates) do UpdateComboPoints(plate) end
end

-- One player-event listener; no polling or per-plate power-event registrations.
local ConfigureComboPoints = function()
	if (IsActive()) then
		if (not watcher) then
			watcher = CreateFrame("Frame")
			watcher:SetScript("OnEvent", function(_, event, unit, power)
				if (event == "UNIT_HEALTH") then
					if (not NP.IsSafeUnitToken(unit) or (unit ~= "target" and not unit:match("^nameplate%d+$"))) then return end
					for plate in pairs(ns.ActiveNamePlates) do
						if (plate.unit == unit or (unit == "target" and NP.SafeUnitMatches(plate.unit, "target"))) then
							UpdateComboPoints(plate)
						end
					end
					return
				end
				if (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER") then
					if (NP.IsSecretValue(unit) or unit ~= "player" or NP.IsSecretValue(power) or power ~= "COMBO_POINTS") then return end
				end
				RefreshComboPoints()
			end)
		end
		watcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
		watcher:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
		watcher:RegisterUnitEvent("UNIT_MAXPOWER", "player")
		watcher:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
		watcher:RegisterEvent("UNIT_HEALTH")
		watcher:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
		watcher:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
		watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
		watcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
		if (ns.API.IsEventAvailable("COMBO_TARGET_CHANGED")) then
			watcher:RegisterEvent("COMBO_TARGET_CHANGED")
		end
	elseif (watcher) then
		watcher:UnregisterAllEvents()
	end
	RefreshComboPoints()
end

NP.UpdateComboPoints = UpdateComboPoints
NP.ClearComboPoints = ClearComboPoints
NP.ConfigureComboPoints = ConfigureComboPoints
NP.GetComboPointNameLift = GetComboPointNameLift

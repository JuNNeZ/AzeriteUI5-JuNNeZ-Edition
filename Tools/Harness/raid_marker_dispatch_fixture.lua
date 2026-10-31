-- Blizzard SecureTemplates.lua excerpt: Gethe/wow-ui-source 18c6d67, 12.1.5 (70391).
-- Frozen dispatch/marker regression fixture only; not a secure execution or taint emulator.
local PRESS_TYPE_DOWN, PRESS_TYPE_UP, PRESS_TYPE_HOLD_RELEASE = 1, 2, 3

local function GetConvertedButtonUnitAndActionType(self, button, pressType)
	if pressType == PRESS_TYPE_DOWN then
		-- remap the button if desired for up-down behaviors. This behavior may not be safe and has been deferred.
		button = SecureButton_GetModifiedAttribute(self, "downbutton", button) or button
	end

	-- Lookup the unit, based on the modifiers and button
	local unit = SecureButton_GetModifiedUnit(self, button);

	-- Remap button suffixes based on the disposition of the unit (contributed by Iriel and Cladhaire)
	if unit then
		local origButton = button;
		if UnitCanAttack("player", unit) then
			button = SecureButton_GetModifiedAttribute(self, "harmbutton", button) or button;
		elseif UnitCanAssist("player", unit) then
			button = SecureButton_GetModifiedAttribute(self, "helpbutton", button) or button;
		end

		-- The unit may have changed based on button remapping
		if ( button ~= origButton ) then
			unit = SecureButton_GetModifiedUnit(self, button);
		end
	end

	if type(button) ~= "string" then
		return nil;
	end

	if unit and unit ~= "none" and not UnitExists(unit) then
		return nil;
	end

	-- Lookup the action type, based on the modifiers and button
	local attributeName = (pressType == PRESS_TYPE_HOLD_RELEASE) and "typerelease" or "type";
	local actionType = SecureButton_GetModifiedAttribute(self, attributeName, button);

	return button, unit, actionType;
end

SECURE_ACTIONS.raidtarget =
	function(self, unit, button)
		local marker = tonumber(SecureButton_GetModifiedAttribute(self, "marker", button));
		local action = SecureButton_GetModifiedAttribute(self, "action", button) or "toggle";
		unit = unit or "target";
		marker = marker or 1;
		if ( action == "set" and GetRaidTargetIndex(unit) ~= marker ) then
			SetRaidTarget(unit, marker);
		elseif ( action == "set-unmarked" and GetRaidTargetIndex(unit) == nil ) then
			SetRaidTarget(unit, marker);
		elseif ( action == "clear" ) then
			SetRaidTarget(unit, 0);
		elseif ( action == "clear-all" ) then
			RemoveRaidTargets();
		elseif ( action == "toggle" ) then
			if ( GetRaidTargetIndex(unit) == marker ) then
				SetRaidTarget(unit, 0);
			else
				SetRaidTarget(unit, marker);
			end
		end
	end;

SECURE_ACTIONS.worldmarker =
	function(self, unit, button)
		local marker = tonumber(SecureButton_GetModifiedAttribute(self, "marker", button));
		local action = SecureButton_GetModifiedAttribute(self, "action", button) or "toggle";
		if ( action == "set" ) then
			PlaceRaidMarker(marker or 1);
		elseif ( action == "clear" ) then
			ClearRaidMarker(marker);
		elseif ( action == "toggle" ) then
			marker = marker or 1;
			if ( IsRaidMarkerActive(marker) ) then
				ClearRaidMarker(marker);
			else
				PlaceRaidMarker(marker);
			end
		end
	end;

return GetConvertedButtonUnitAndActionType

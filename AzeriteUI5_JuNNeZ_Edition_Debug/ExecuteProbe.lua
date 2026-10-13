--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Part of AzeriteUI5_JuNNeZ_Edition_Debug, loaded on demand (Core/DebugLoader.lua).
local Addon, ns = ...
do
	local main = _G["AzeriteUI5_JuNNeZ_Edition"]
	if (type(main) == "table") then Addon, ns = "AzeriteUI5_JuNNeZ_Edition", main end
end

--[[
	/azdebug execute

	The execute marker on the target frame and on the target's nameplate, as the client
	sees it: whether each part exists and is shown, its alpha, size, anchor and texture
	crop, next to the health bar's own size, crop and frame level. Written for the
	2026-10-13 test report: the line looked taller than the plate's bar, and the target
	frame showed no marker at all. Read only; it changes nothing.
]]

local ExecuteProbe = {}
ns.ExecuteProbe = ExecuteProbe

local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value) or false
end

-- A value for print: secrets, numbers rounded, tables as lists.
local Show = function(value)
	if (IsSecret(value)) then return "secret" end
	if (type(value) == "number") then
		local text = string.format("%.3f", value):gsub("0+$", "")
		return (text:gsub("%.$", ""))
	end
	return tostring(value)
end

local Call = function(object, method, ...)
	local fn = object and object[method]
	if (type(fn) ~= "function") then return "n/a" end
	local results = { pcall(fn, object, ...) }
	if (not results[1]) then return "error" end
	local parts = {}
	for i = 2, #results do parts[#parts + 1] = Show(results[i]) end
	return #parts > 0 and table.concat(parts, ", ") or "nil"
end

local Anchor = function(region)
	if (not region or not region.GetPoint) then return "n/a" end
	local ok, point, relativeTo, relativePoint, x, y = pcall(region.GetPoint, region, 1)
	if (not ok or not point) then return "none" end
	local name = relativeTo and relativeTo.GetDebugName and relativeTo:GetDebugName() or tostring(relativeTo)
	return string.format("%s -> %s %s (%s, %s)", point, name, tostring(relativePoint), Show(x), Show(y))
end

local Region = function(out, label, region)
	if (not region) then return out(string.format("  %s: none", label)) end
	out(string.format("  %s: shown %s, visible %s, alpha %s, size %s, layer %s",
		label, Call(region, "IsShown"), Call(region, "IsVisible"), Call(region, "GetAlpha"),
		Call(region, "GetSize"), Call(region, "GetDrawLayer")))
	out(string.format("    texture %s, crop %s, colour %s", Call(region, "GetTexture"),
		Call(region, "GetTexCoord"), Call(region, "GetVertexColor")))
	out("    anchor " .. Anchor(region))
end

local Health = function(out, health)
	if (not health) then return out("  health: none") end
	out(string.format("  health: size %s, scale %s, level %s, reverse %s, crop %s",
		Call(health, "GetSize"), Call(health, "GetEffectiveScale"), Call(health, "GetFrameLevel"),
		Call(health, "GetReverseFill"), Call(health, "GetTexCoord")))
	-- What LibSmoothBar really draws: its fill texture, and the native proxy it swaps to
	-- for secret values, which is cropped differently.
	out(string.format("    fill %s, drawn crop %s", Call(health:GetStatusBarTexture(), "GetSize"), Call(health, "GetRealTexCoord")))
	local data = health.GetDebugData and health:GetDebugData()
	if (data) then
		out(string.format("    proxy shown %s, proxy crop %s", Show(data.proxyShown),
			data.proxyTexCoord and table.concat({ Show(data.proxyTexCoord[1]), Show(data.proxyTexCoord[2]),
				Show(data.proxyTexCoord[3]), Show(data.proxyTexCoord[4]) }, ", ") or "n/a"))
	end
	if (health.Backdrop) then Region(out, "backdrop", health.Backdrop) end
	if (health.Overlay) then out("  overlay level " .. Call(health.Overlay, "GetFrameLevel")) end
end

local Marker = function(out, frame)
	local marker = frame and frame.ExecuteMarker
	if (not marker) then return out("  marker: never created (it is made the first time it should show)") end
	out(string.format("  marker: isShown %s, threshold %s, lead %s, reverse %s",
		Show(marker.isShown), Show(marker.threshold), Show(marker.lead), Show(marker.reverse)))
	Region(out, "line", marker.Line)
	Region(out, "zone", marker.Zone)
end

local Unit = function(out, unit)
	out(string.format("  unit %s: exists %s, canAttack %s, friend %s, health%% %s", unit,
		Show(UnitExists(unit)), Show(UnitCanAttack("player", unit)), Show(UnitIsFriend("player", unit)),
		type(UnitHealthPercent) == "function" and Show(select(2, pcall(UnitHealthPercent, unit, true, nil))) or "n/a"))
end

ExecuteProbe.Run = function(rest, out)
	out = out or print
	local plates = ns.NamePlatesPrivate
	local threshold = plates and plates.GetNamePlateExecuteThreshold and plates.GetNamePlateExecuteThreshold()
	local lead = plates and plates.GetExecuteMarkerStyle and plates.GetExecuteMarkerStyle()
	out("|cff33ff99AzeriteUI /azdebug execute|r")
	out(string.format("  threshold %s, lead %s", Show(threshold), Show(lead)))
	if (not UnitExists("target")) then
		out("  Target an enemy first.")
		return
	end
	Unit(out, "target")

	local target = ns:GetModule("TargetFrame", true)
	out("|cffffd200Target frame|r")
	if (not target or not target.frame) then
		out("  the target frame module is off")
	else
		local profile = target.db and target.db.profile or {}
		out(string.format("  setting executeMarker %s, available %s, style %s",
			Show(profile.executeMarker), Show(target.IsExecuteMarkerAvailable and target.IsExecuteMarkerAvailable()),
			Show(target.frame.currentStyle)))
		Health(out, target.frame.Health)
		Marker(out, target.frame)
	end

	out("|cffffd200Target nameplate|r")
	local plate
	if (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
		local ok, base = pcall(C_NamePlate.GetNamePlateForUnit, "target")
		plate = ok and base and (base.unitFrame or base.UnitFrame)
	end
	if (not plate and ns.ActiveNamePlates) then
		for frame in next, ns.ActiveNamePlates do
			if (frame.unit and UnitIsUnit(frame.unit, "target")) then plate = frame break end
		end
	end
	if (not plate) then
		out("  no plate for the target")
		return
	end
	local module = ns:GetModule("NamePlates", true)
	local profile = module and module.db and module.db.profile or {}
	out(string.format("  setting executeMarker %s, combatOnly %s, canAttack %s, plate scale %s",
		Show(profile.executeMarker), Show(profile.executeCombatOnly), Show(plate.canAttack), Call(plate, "GetEffectiveScale")))
	Health(out, plate.Health)
	Marker(out, plate)
end

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
	Three roadmap experiments (FEATURE_PLAN.md, Phase 2, "test first, then decide"), as
	probes that answer them in the client instead of guesses in a plan:

	/azdebug radial [off]   Texture:SetRadialProgressBarPercent and its siblings exist
	                        and take secret values. Two rings on screen: one sweeping
	                        0 to 1 on a timer, one fed UnitHealthPercent("player")
	                        as is, secret or not. The report says which calls the
	                        client accepted. If both draw, LibSpinBar's four rotated
	                        quadrants could become one native texture.

	/azdebug svg [off]      Frame:CreateVectorGraphics and Texture:SetSVG exist; whether
	                        an addon's own .svg file loads is undocumented. This ships
	                        one (probe.svg, a ring) and tries both ways.

	/azdebug onupdatemode   Frame:SetOnUpdateMode. Reports a new frame's mode, so the
	                        plan can say whether setting it would change anything.

	Nothing here is wired into the interface; every probe frame is our own and goes
	away with "off" or a /reload.
]]

local RenderProbe = {}
ns.RenderProbe = RenderProbe

local SVG_PATH = [[Interface\AddOns\AzeriteUI5_JuNNeZ_Edition_Debug\probe.svg]]
RenderProbe.SvgPath = SVG_PATH

local state = {}

local IsSecret = function(value)
	return type(issecretvalue) == "function" and issecretvalue(value) or false
end

-- Calls object:method(...) and reports "ok", "missing" or the error.
local Try = function(object, method, ...)
	local fn = object and object[method]
	if (type(fn) ~= "function") then return false, "missing" end
	local ok, result = pcall(fn, object, ...)
	if (not ok) then return false, tostring(result) end
	return true, result
end

local Line = function(out, label, ok, detail)
	out(string.format("  %s: %s%s", label, ok and "|cff33ff99ok|r" or "|cffff4444no|r",
		detail ~= nil and (" (" .. (IsSecret(detail) and "secret" or tostring(detail)) .. ")") or ""))
end

local Holder = function(key, x)
	local frame = state[key] or CreateFrame("Frame", nil, UIParent)
	state[key] = frame
	frame:SetSize(128, 128)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", x, 120)
	frame:SetFrameStrata("DIALOG")
	frame:Show()
	return frame
end

--[[ Radial fills ]]--

local RING = "actionbutton-backdrop"

RenderProbe.Radial = function(input, out)
	out = out or print
	local word = input and input:match("^(%S+)") or ""
	if (word:lower() == "off") then
		for _, key in ipairs({ "radialTimer", "radialHealth" }) do
			if (state[key]) then state[key]:SetScript("OnUpdate", nil); state[key]:Hide() end
		end
		out("|cff33ff99AzeriteUI radial probe:|r stopped.")
		return
	end

	out("|cff33ff99AzeriteUI radial probe|r  (Texture:SetRadialProgressBarPercent)")
	local texturePath = ns.API.GetMedia(RING)

	-- Left ring: a plain number sweeping 0 to 1.
	local timer = Holder("radialTimer", -80)
	local a = timer.Ring or timer:CreateTexture(nil, "ARTWORK")
	timer.Ring = a
	a:SetAllPoints()
	a:SetTexture(texturePath)
	a:SetVertexColor(.3, .8, 1)
	local okPercent, err = Try(a, "SetRadialProgressBarPercent", .25)
	Line(out, "SetRadialProgressBarPercent(.25)", okPercent, err)
	Line(out, "SetRadialProgressBarFeather(.05)", Try(a, "SetRadialProgressBarFeather", .05))
	Line(out, "SetRadialProgressBarStartOffset(0)", Try(a, "SetRadialProgressBarStartOffset", 0))
	Line(out, "SetRadialProgressBarReverse(false)", Try(a, "SetRadialProgressBarReverse", false))
	local okGet, value = Try(a, "GetRadialProgressBarPercent")
	Line(out, "GetRadialProgressBarPercent()", okGet, value)
	if (okPercent) then
		local elapsed = 0
		timer:SetScript("OnUpdate", function(_, dt)
			elapsed = (elapsed + dt) % 3
			a:SetRadialProgressBarPercent(elapsed / 3)
		end)
	end

	-- Right ring: the player's health, handed over untouched.
	local health = Holder("radialHealth", 80)
	local b = health.Ring or health:CreateTexture(nil, "ARTWORK")
	health.Ring = b
	b:SetAllPoints()
	b:SetTexture(texturePath)
	b:SetVertexColor(.2, .9, .2)
	local read = type(UnitHealthPercent) == "function" and UnitHealthPercent
	if (read) then
		local percent = read("player", true)
		Line(out, "UnitHealthPercent(player) is secret", true, IsSecret(percent))
		Line(out, "SetRadialProgressBarPercent(health)", Try(b, "SetRadialProgressBarPercent", percent))
		local throttle = 0
		health:SetScript("OnUpdate", function(_, dt)
			throttle = throttle + dt
			if (throttle < .1) then return end
			throttle = 0
			pcall(b.SetRadialProgressBarPercent, b, read("player", true))
		end)
	else
		Line(out, "UnitHealthPercent", false, "missing")
	end
	out("  Look: left ring sweeps every 3 s, right ring follows your health (in combat too).")
	out("  /azdebug radial off when done.")
end

--[[ SVG ]]--

RenderProbe.Svg = function(input, out)
	out = out or print
	local word = input and input:match("^(%S+)") or ""
	if (word:lower() == "off") then
		for _, key in ipairs({ "svgGraphics", "svgTexture" }) do
			if (state[key]) then state[key]:Hide() end
		end
		out("|cff33ff99AzeriteUI SVG probe:|r stopped.")
		return
	end

	local path = (word ~= "" and input) or SVG_PATH
	out("|cff33ff99AzeriteUI SVG probe|r  (" .. path .. ")")

	-- A vector graphics region on a frame.
	local left = Holder("svgGraphics", -80)
	local okCreate, graphics = true, left.Graphics
	if (not graphics) then
		okCreate, graphics = Try(left, "CreateVectorGraphics", nil, "ARTWORK")
		left.Graphics = okCreate and graphics or nil
	end
	Line(out, "Frame:CreateVectorGraphics()", okCreate, okCreate and graphics and graphics.GetObjectType and graphics:GetObjectType() or graphics)
	if (okCreate and graphics) then
		pcall(graphics.SetAllPoints, graphics)
		local okSet, success = Try(graphics, "SetSVG", path)
		Line(out, "VectorGraphics:SetSVG(file)", okSet and success == true, success)
		local okHas, has = Try(graphics, "HasSVG")
		Line(out, "VectorGraphics:HasSVG()", okHas and has == true, has)
	end

	-- A plain texture.
	local right = Holder("svgTexture", 80)
	local texture = right.Texture or right:CreateTexture(nil, "ARTWORK")
	right.Texture = texture
	texture:SetAllPoints()
	local okTexture, success = Try(texture, "SetSVG", path)
	Line(out, "Texture:SetSVG(file)", okTexture and success == true, success)
	out("  Look: a gold ring on each side means an addon's own SVG loads both ways.")
	out("  /azdebug svg off when done.")
end

--[[ OnUpdate mode ]]--

RenderProbe.OnUpdateMode = function(input, out)
	out = out or print
	out("|cff33ff99AzeriteUI OnUpdate mode probe|r  (Frame:SetOnUpdateMode)")
	local modes = Enum and Enum.OnUpdateMode
	if (type(modes) ~= "table") then
		Line(out, "Enum.OnUpdateMode", false, "missing")
		return
	end
	local names = {}
	for name, value in pairs(modes) do names[value] = name end

	local frame = state.onUpdateFrame or CreateFrame("Frame")
	state.onUpdateFrame = frame
	local okGet, mode = Try(frame, "GetOnUpdateMode")
	Line(out, "a new frame's mode", okGet, okGet and names[mode] or mode)
	frame:Hide()
	local okHidden, hiddenMode = Try(frame, "GetOnUpdateMode")
	Line(out, "the same frame hidden", okHidden, okHidden and names[hiddenMode] or hiddenMode)
	if (okGet and names[mode] == "RunWhenVisible") then
		out("  Default is RunWhenVisible: a hidden frame's OnUpdate already does not run, so")
		out("  setting the mode only helps frames that stay shown while idle.")
	end
end

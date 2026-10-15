-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/worldmap_canvas_taint_probe.lua.
-- Isolated Lua taint experiment for the world map ADDON_ACTION_BLOCKED (FixLog 2026-10-15).
-- Models MapCanvasScrollControllerMixin's scale fields with Blizzard's own read/write order
-- (MapCanvas_ScrollContainerMixin.lua: InstantPanAndZoom reads GetCanvasScale before it
-- writes, MarkCanvasDirty compares currentScale == targetScale). No frames, no secret values.
local ADDON = "AzeriteUI5_JuNNeZ_Edition"
local pass, fail = 0, 0
local function check(cond, label)
	debug.setstacktaint(nil)
	if (cond) then pass = pass + 1 else fail = fail + 1 end
	print((cond and "PASS " or "FAIL ") .. label)
end

local function NewScrollContainer()
	debug.setstacktaint(nil) -- each case is a fresh session: Blizzard defines the mixin securely
	local sc = { layerWidth = tonumber("1000"), width = tonumber("800") }
	function sc:GetCanvasScale()
		if (self.currentScale and self.currentScale ~= 0) then return self.currentScale end
		if (self.targetScale and self.targetScale ~= 0) then return self.targetScale end
		return 1
	end
	function sc:InstantPanAndZoom(scale)
		local scaleRatio = self:GetCanvasScale() / scale -- Blizzard reads first
		self.panRatio = scaleRatio
		self.currentScale = scale
		self.targetScale = self.currentScale
	end
	function sc:OnCanvasSizeChanged()
		-- CreateZoomLevels: sizes come from C (GetWidth, C_Map), modelled as fresh tonumber()
		self.baseScale = tonumber("0.8")
		self.zoomLevels = { { scale = self.baseScale } }
		self:InstantPanAndZoom(self.zoomLevels[1].scale) -- ResetZoom
	end
	function sc:MarkCanvasDirty()
		if (self.currentScale == self.targetScale) then self.currentScale = nil end
	end
	function sc:OnUpdate()
		if (self.currentScale ~= self.targetScale) then self.currentScale = self.targetScale end
	end
	return sc
end

-- Fresh secure dispatch (an event, keypress or C-invoked script) running Blizzard code.
-- The client starts every dispatch secure; the probe resets the stack taint the same way,
-- because reading a result flag written under taint taints the main chunk too.
local function SecureDispatch(fn, ...)
	debug.setstacktaint(nil)
	assert(issecure(), "probe must start each dispatch secure")
	securecall(fn, ...)
	debug.setstacktaint(nil)
end

-- Blizzard's AcquirePin up to the restricted call: returns whether execution was still secure.
local function AcquirePinIsSecure(sc)
	local result = {}
	SecureDispatch(function()
		sc:MarkCanvasDirty()
		result.secure = issecure() and "yes" or "no" -- where SetPropagateMouseClicks would run
	end)
	debug.setstacktaint(nil)
	local secureAtCall = result.secure == "yes"
	debug.setstacktaint(nil)
	return secureAtCall
end

-- 1) Baseline: Blizzard only. Pins acquired securely.
do
	local sc = NewScrollContainer()
	SecureDispatch(sc.OnCanvasSizeChanged, sc)
	check(issecurevariable(sc, "currentScale"), "baseline: Blizzard-only rebuild leaves currentScale clean")
	check(AcquirePinIsSecure(sc), "baseline: AcquirePin reaches SetPropagateMouseClicks securely")
end

-- 2) 5.26.0: Blizzard's Maximize rebuilds, then our post-hook calls OnFrameSizeChanged.
local function AddonHookCallsRebuild(sc)
	SecureDispatch(function()
		debug.setstacktaint(ADDON)
		sc:OnCanvasSizeChanged()
	end)
end
do
	local sc = NewScrollContainer()
	SecureDispatch(sc.OnCanvasSizeChanged, sc) -- Blizzard's own call inside Maximize
	AddonHookCallsRebuild(sc) -- our hook runs after it
	local secure, source = issecurevariable(sc, "currentScale")
	check(not secure and source == ADDON, "5.26.0: our hook leaves currentScale tainted by " .. tostring(source))
	check(not AcquirePinIsSecure(sc), "5.26.0: later AcquirePin is tainted before SetPropagateMouseClicks (the report)")

	-- 3) Does Blizzard's own later rebuild (map change, next Maximize) clean it? It reads first.
	SecureDispatch(sc.OnCanvasSizeChanged, sc)
	check(not issecurevariable(sc, "currentScale"), "persistence: Blizzard's next rebuild re-taints (reads before writing)")
	SecureDispatch(sc.OnUpdate, sc)
	check(not issecurevariable(sc, "currentScale"), "persistence: OnUpdate keeps it tainted")
	check(not AcquirePinIsSecure(sc), "persistence: map stays broken in combat until /reload")
end

-- 4) The fix: no addon rebuild call. Hook only resizes (C state), Blizzard rebuilds after it.
do
	local sc = NewScrollContainer()
	SecureDispatch(function()
		debug.setstacktaint(ADDON)
		sc.width = nil -- stands in for WorldMapFrame:SetSize: C state, no Lua field Blizzard reads
	end)
	sc.width = tonumber("700")
	SecureDispatch(sc.OnCanvasSizeChanged, sc)
	check(issecurevariable(sc, "currentScale"), "fix: Blizzard-only rebuild after our resize stays clean")
	check(AcquirePinIsSecure(sc), "fix: AcquirePin secure")
end

-- 5) "Secret fix" check: can addon code launder its call through securecall / pcall?
do
	local sc = NewScrollContainer()
	SecureDispatch(function()
		debug.setstacktaint(ADDON)
		securecall(sc.OnCanvasSizeChanged, sc)
	end)
	check(not issecurevariable(sc, "currentScale"), "securecall from addon code does NOT launder (still tainted)")
	local sc2 = NewScrollContainer()
	SecureDispatch(function()
		debug.setstacktaint(ADDON)
		pcall(sc2.OnCanvasSizeChanged, sc2)
	end)
	check(not issecurevariable(sc2, "currentScale"), "pcall from addon code does NOT launder")
end

-- 6) Can addon code repair an already-tainted field? Any addon write is itself tainted.
do
	local sc = NewScrollContainer()
	AddonHookCallsRebuild(sc)
	SecureDispatch(function()
		debug.setstacktaint(ADDON)
		sc.currentScale, sc.targetScale = nil, nil
	end)
	check(not issecurevariable(sc, "currentScale"), "addon cannot scrub: its nil write is tainted too")
end

print(string.format("worldmap_canvas_taint_probe: %d passed, %d failed", pass, fail))
if (fail > 0) then os.exit(1) end

--[[
	The world map in combat (Components/Misc/WorldMap.lua, FixLog 2026-10-24).

	Loads the real module against a fake WorldMapFrame that follows Blizzard's 12.1.5 code
	(Blizzard_WorldMap.lua, QuestLogOwnerMixin.lua): SetDisplayState with OnShow's inverted
	miniWorldMap test, Maximize/Minimize order, OnFrameSizeChanged canvas rebuilds, and
	WorldMapOnHide from OnHide. Blizzard's methods are secure when Blizzard calls them and
	tainted when addon code does. Widget methods the client documents as protected refuse
	in combat on a protected frame; protection is per frame (it spreads to parents, not
	children). Checks: no blocked call on any path when another addon protects the map or
	one of its children, today's centring kept when nothing is protected, every skipped
	call replayed after combat or on hide in the right order, the canvas built for the
	size the map is shown at, our shrink never compounding, UpdateSettings waiting out
	combat when it must, Blizzard methods called from addon code only where allowed, and
	unreadable or secret IsProtected answers failing closed.

	Run from the addon root:  lua Tools/Harness/worldmap_combat_harness.lua .
	Optional second argument: the module file to load (for mutants).
]]

local root = (arg and arg[1]) or "."
local modulePath = (arg and arg[2]) or (root .. "/Components/Misc/WorldMap.lua")

local passed, failed = 0, 0
local check = function(ok, label)
	if (ok) then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end
local near = function(a, b) return a and b and math.abs(a - b) < 0.001 end

local STOCK_W, STOCK_H = 1000, 700     -- what Blizzard's UpdateMaximizedSize gives the map
local MINI_W, MINI_H = 702, 534
local SCALE = ((1 - 0.65) / (1.15 - 0.65)) * (0.95 - 0.65) + 0.65  -- CalculateScale at UI scale 1
local Ours = function(w, h) return (w * SCALE) - (((1 - SCALE) * 100) + 2), (h * SCALE) - 2 end
local OURS_W, OURS_H = Ours(STOCK_W, STOCK_H)

-- Documented IsProtectedFunction widget methods the module could reach on Blizzard frames.
local PROTECTED = {
	ClearAllPoints = true, SetPoint = true, SetAllPoints = true, SetSize = true, SetWidth = true,
	SetHeight = true, SetParent = true, SetScale = true, EnableMouse = true, SetFrameLevel = true,
	SetFrameStrata = true, SetShown = true, Show = true, Hide = true, SetAttribute = true,
}

-- RestoreBlizzardState's two calls (module switched off) are the only Blizzard methods
-- addon code may call, never in combat, and once per switch-off (a case sets expectRestore).
local ALLOWED_FROM_ADDON = { UpdateMaximizedSize = true, SynchronizeDisplayState = true }

local Load = function(opts)
	opts = opts or {}
	local world = {
		combat = false, protectedFrames = {}, protectedAnswer = nil,  -- nil, "secret" or "error"
		blocked = {}, fromAddon = {}, fromAddonInCombat = 0, inBlizzard = 0,
		hideCallbacks = {}, enabled = opts.enabled ~= false, mini = false,
		stockW = STOCK_W, stockH = STOCK_H, canvasW = nil, canvasH = nil,
	}

	local IsProtectedNow = function(f) return world.protectedFrames[f] == true end
	-- Protection spreads to parents: a protected child protects the map.
	world.Protect = function(f, on)
		world.protectedFrames[f] = on or nil
		local any = false
		for frame in pairs(world.protectedFrames) do if (frame ~= world.map) then any = true end end
		if (any or world.mapItself) then world.protectedFrames[world.map] = true else world.protectedFrames[world.map] = nil end
	end
	world.SetProtected = function(on) world.mapItself = on; world.Protect(world.map, on) end

	local NewFrame
	NewFrame = function(kind, name, parent)
		local f = { kind = kind, name = name, parent = parent, points = {}, shown = true, alpha = 1, scale = 1 }
		local apply = {
			ClearAllPoints = function(self) self.points = {} end,
			SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
			SetAllPoints = function(self, rel) self.points = { { "ALL", rel } } end,
			SetSize = function(self, w, h) self.width, self.height = w, h end,
			SetWidth = function(self, w) self.width = w end,
			SetHeight = function(self, h) self.height = h end,
			SetParent = function(self, p) self.parent = p end,
			SetScale = function(self, s) self.scale = s end,
			EnableMouse = function(self, v) self.mouse = v end,
			SetFrameLevel = function(self, v) self.level = v end,
			SetFrameStrata = function(self, v) self.strata = v end,
			SetShown = function(self, v) self.shown = v and true or false end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
			SetAttribute = function(self, k, v) self[k] = v end,
		}
		local methods = {
			GetName = function(self) return self.name end,
			GetSize = function(self) return self.width, self.height end,
			GetParent = function(self) return self.parent end,
			IsShown = function(self) return self.shown end,
			SetAlpha = function(self, a) self.alpha = a end,
			GetAlpha = function(self) return self.alpha end,
			IsProtected = function(self)
				if (self.isMap and world.protectedAnswer == "error") then error("IsProtected unavailable") end
				-- Falsy, so code that skips issecretvalue reads "not protected" and gets blocked.
				if (self.isMap and world.protectedAnswer == "secret") then return false, false end
				return IsProtectedNow(self), false
			end,
			GetFrameLevel = function() return 1 end,
			GetFrameStrata = function() return "HIGH" end,
			GetEffectiveScale = function() return 1 end,
			GetFont = function() return "font", 12 end,
			GetTexture = function(self) return self.texture end,
			SetTexture = function(self, t) self.texture = t end,
			GetNumRegions = function() return 0 end,
			GetRegions = function() end,
			IsMouseOver = function() return false end,
			CreateFontString = function(self) return NewFrame("FontString", nil, self) end,
			SetScript = function(self, k, fn) self[k] = fn end,
		}
		for method, fn in pairs(apply) do
			methods[method] = function(self, ...)
				-- Textures and font strings use the unprotected region versions.
				local isRegion = (self.kind == "Texture" or self.kind == "FontString")
				if (not isRegion and PROTECTED[method] and world.combat and IsProtectedNow(self)
					and not (world.inBlizzard > 0 and not world.tainted)) then
					world.blocked[#world.blocked + 1] = (self.name or self.kind) .. ":" .. method
					return
				end
				return fn(self, ...)
			end
		end
		return setmetatable(f, { __index = function(_, k)
			if (methods[k]) then return methods[k] end
			if (type(k) == "string" and k:match("^%u")) then return function() end end
		end })
	end

	local UIParent = NewFrame("Frame", "UIParent")
	UIParent.width, UIParent.height = 1920, 1080

	local map = NewFrame("Frame", "WorldMapFrame", UIParent)
	world.map = map
	map.isMap = true
	map.shown = false
	map.width, map.height = MINI_W, MINI_H
	map.points = { { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 } }
	map.needUpdateDisplayState = true
	map.NavBar = NewFrame("Frame", "NavBar", map)
	map.BorderFrame = NewFrame("Frame", "BorderFrame", map)
	map.BorderFrame.MaximizeMinimizeFrame = { MinimizeButton = NewFrame("Button", "MinimizeButton", map.BorderFrame) }
	map.BlackoutFrame = NewFrame("Frame", "BlackoutFrame", map)
	map.BlackoutFrame.Blackout = NewFrame("Texture", nil, map.BlackoutFrame)
	map.ScrollContainer = NewFrame("ScrollFrame", "ScrollContainer", map)
	map.overlayFrames = {}
	local closeButton = NewFrame("Button", "WorldMapFrameCloseButton", map.BorderFrame)
	local bg = NewFrame("Texture", "WorldMapFrameBg", map)

	-- Blizzard's methods. Called from Blizzard code they run secure and write the frame
	-- directly; called from addon code they run tainted and their writes can be blocked.
	local Blizzard = function(name, fn)
		return function(self, ...)
			local fromAddon = (world.inBlizzard == 0)
			if (fromAddon) then
				world.fromAddon[name] = (world.fromAddon[name] or 0) + 1
				if (world.combat) then world.fromAddonInCombat = world.fromAddonInCombat + 1 end
				world.tainted = true
			end
			world.inBlizzard = world.inBlizzard + 1
			local a, b = fn(self, ...)
			world.inBlizzard = world.inBlizzard - 1
			if (fromAddon) then world.tainted = nil end
			return a, b
		end
	end
	-- Addon hooks run as addon code inside Blizzard's call.
	local AsAddon = function(fn, ...)
		local saved, savedTaint = world.inBlizzard, world.tainted
		world.inBlizzard, world.tainted = 0, nil
		fn(...)
		world.inBlizzard, world.tainted = saved, savedTaint
	end
	world.AsAddon = AsAddon

	map.IsMaximized = function(self) return self.isMaximized == true end
	map.IsMinimized = function(self) return self.isMaximized == false end
	map.OnFrameSizeChanged = Blizzard("OnFrameSizeChanged", function(self)
		world.canvasW, world.canvasH = self.width, self.height
	end)
	map.UpdateMaximizedSize = Blizzard("UpdateMaximizedSize", function(self)
		assert(self:IsMaximized(), "UpdateMaximizedSize on a minimized map")
		self:SetSize(world.stockW, world.stockH)
		self:OnFrameSizeChanged()
	end)
	map.SynchronizeDisplayState = Blizzard("SynchronizeDisplayState", function(self)
		self:ClearAllPoints()
		if (self:IsMaximized()) then
			self:SetPoint("TOP", UIParent, "TOP", 0, 0)
		else
			self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
		end
	end)
	map.Maximize = Blizzard("Maximize", function(self)
		self.isMaximized = true
		self:UpdateMaximizedSize()
		self:SynchronizeDisplayState()
		self:OnFrameSizeChanged()
	end)
	map.Minimize = Blizzard("Minimize", function(self)
		self.isMaximized = false
		self:SetSize(MINI_W, MINI_H)
		self:SynchronizeDisplayState()
		self:OnFrameSizeChanged()
	end)

	local SetDisplayState
	local OnShow = function()
		if (map.needUpdateDisplayState) then
			map.needUpdateDisplayState = nil
			SetDisplayState(not world.mini)
		end
		-- Blizzard_WorldMap.lua:365-372: "mini ~= maximized", so an open maximized map maximizes again.
		if (world.mini ~= map:IsMaximized()) then
			SetDisplayState(not world.mini)
		end
	end
	-- QuestLogOwnerMixin:SetDisplayState (maximized or minimized; open states only).
	SetDisplayState = function(maximized)
		local synced = false
		if (not map.shown) then map.shown = true; OnShow() end  -- ShowUIPanel
		if (maximized) then
			if (not map:IsMaximized()) then map:Maximize(); synced = true end
		else
			if (not map:IsMinimized()) then map:Minimize(); synced = true end
		end
		map:OnFrameSizeChanged()                                  -- UpdateSpacerFrameAnchoring
		if (not synced) then map:SynchronizeDisplayState() end
	end
	local fireHide = function()
		for _, cb in ipairs(world.hideCallbacks) do AsAddon(cb.fn, cb.owner) end
	end

	local AsBlizzard = function(fn) world.inBlizzard = world.inBlizzard + 1; fn(); world.inBlizzard = world.inBlizzard - 1 end
	world.Toggle = function()                                    -- M (HandleUserActionToggleSelf)
		AsBlizzard(function()
			if (map.shown) then map.shown = false; fireHide() else SetDisplayState(not world.mini) end
		end)
	end
	world.Open = function() if (not map.shown) then world.Toggle() end end
	world.Close = function() if (map.shown) then world.Toggle() end end
	world.QuestLog = function()                                  -- L: minimized with the log
		AsBlizzard(function() SetDisplayState(false) end)
	end
	world.HideByParent = function()                              -- Alt+Z: OnHide, IsShown stays true
		AsBlizzard(function() fireHide() end)
	end
	world.ShowByParent = function()                              -- Alt+Z again: OnShow alone
		AsBlizzard(function() OnShow() end)
	end
	world.ScaleChanged = function()                              -- UI_SCALE_CHANGED
		AsBlizzard(function() if (map:IsMaximized()) then map:UpdateMaximizedSize() end end)
	end

	local module
	local events = {}
	world.Fire = function(event)
		local cb = events[event]
		if (cb) then AsAddon(function() module[cb](module, event) end) end
	end
	world.IsRegistered = function(event) return events[event] ~= nil end

	local env = setmetatable({
		CreateFrame = function(kind, name, parent) return NewFrame(kind, name, parent) end,
		UIParent = UIParent,
		WorldMapFrame = map,
		WorldMapFrameBg = bg,
		WorldMapFrameCloseButton = closeButton,
		NumberFont_Shadow_Med = {},
		BackdropTemplateMixin = {},
		PLAYER = "Player", MOUSE_LABEL = "Mouse",
		InCombatLockdown = function() return world.combat end,
		issecretvalue = function(v) return world.protectedAnswer == "secret" and v == false end,
		C_Map = { GetBestMapForUnit = function() end, GetPlayerMapPosition = function() end },
		C_CVar = { SetCVar = function(k, v) if (k == "miniWorldMap") then world.mini = (v == "1") end end },
		C_AddOns = { IsAddOnLoaded = function(name) return name == "Blizzard_WorldMap" end },
		EventRegistry = {
			RegisterCallback = function(_, event, fn, owner)
				if (event == "WorldMapOnHide") then world.hideCallbacks[#world.hideCallbacks + 1] = { fn = fn, owner = owner } end
			end,
		},
	}, { __index = _G })
	env._G = env

	local ns = {
		IsRetail = true,
		API = { GetMedia = function(name) return name end },
		Hider = NewFrame("Frame", "UIHider"),
		db = { RegisterNamespace = function() return { profile = { enabled = world.enabled } } end },
	}
	ns.NewModule = function(_, name)
		module = { name = name }
		module.RegisterEvent = function(self, event, cb) events[event] = cb end
		module.UnregisterEvent = function(self, event, cb) if (events[event] == cb) then events[event] = nil end end
		module.SecureHook = function(self, obj, method, handler)
			local orig = obj[method]
			obj[method] = function(o, ...)
				local a, b = orig(o, ...)
				AsAddon(handler, o, ...)
				return a, b
			end
		end
		return module
	end

	local chunk = assert(loadfile(modulePath))
	setfenv(chunk, env)
	AsAddon(function()
		chunk("AzeriteUI5_JuNNeZ_Edition", ns)
		module:OnInitialize()
		module:OnEnable()
		module:OnEvent("PLAYER_ENTERING_WORLD")
	end)

	world.module, world.navBar, world.closeButton = module, map.NavBar, closeButton
	world.Anchor = function()
		local p = map.points[1]
		return p and (p[1] .. "," .. tostring(p[4]) .. "," .. tostring(p[5])) or "none"
	end
	world.Blocked = function() return table.concat(world.blocked, " ") end
	world.CanvasFits = function() return world.canvasW == map.width and world.canvasH == map.height end
	world.UpdateSettings = function() AsAddon(function() module:UpdateSettings() end) end
	world.Minimize = function() AsBlizzard(function() map:Minimize() end) end
	world.Maximize = function() AsBlizzard(function() map:Maximize() end) end
	-- Checked after every case.
	world.Audit = function(label)
		check((world.fromAddon.OnFrameSizeChanged or 0) == 0, label .. ": no OnFrameSizeChanged from addon code")
		check(world.fromAddonInCombat == 0, label .. ": no Blizzard map method from addon code in combat")
		for name, count in pairs(world.fromAddon) do
			check(ALLOWED_FROM_ADDON[name] and count <= (world.expectRestore or 0),
				label .. ": " .. name .. " called " .. count .. "x from addon code")
		end
		check((world.fromAddon.SynchronizeDisplayState or 0) == (world.expectRestore or 0),
			label .. ": RestoreBlizzardState ran " .. (world.expectRestore or 0) .. "x")
		check(#world.blocked == 0, label .. ": nothing blocked, got " .. world.Blocked())
	end
	return world
end

-- 1. Out of combat: the styled maximized map, as before.
do
	local w = Load()
	w.Open()
	check(near(w.map.width, OURS_W) and near(w.map.height, OURS_H), "1 out of combat: our size")
	check(w.Anchor() == "CENTER,0,30", "1 out of combat: centred, got " .. w.Anchor())
	check(w.navBar.shown == false and w.map.AzeriteBackdrop.shown == true, "1 out of combat: styled")
	check(w.CanvasFits(), "1 out of combat: canvas built for our size")
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "1 out of combat: no replay waiting")
	w.Close(); w.Open()
	check(w.Anchor() == "CENTER,0,30" and near(w.map.width, OURS_W) and w.CanvasFits(), "1 reopen: same")
	w.Audit("1")
end

-- 2. Combat, nothing protected (stock): today's centring in combat is kept.
do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true
	w.Open()
	check(w.Anchor() == "CENTER,0,30", "2 unprotected combat open: still centred, got " .. w.Anchor())
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "2 unprotected combat open: no replay")
	w.Audit("2")
end

-- 3. The report: an already maximized map opened in combat while protected.
do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true; w.SetProtected(true)
	w.Open()
	check(w.Anchor() == "TOP,0,0", "3 protected combat open: Blizzard's anchor kept, got " .. w.Anchor())
	check(near(w.map.width, OURS_W) and w.CanvasFits(), "3 protected combat open: our size from before, canvas fits")
	check(w.IsRegistered("PLAYER_REGEN_ENABLED"), "3 protected combat open: replay waits for combat end")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.Anchor() == "CENTER,0,30", "3 after combat: centred, got " .. w.Anchor())
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "3 after combat: replay done")
	w.Audit("3")
end

-- 4. First maximize in combat while protected: size, anchor and style all wait.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	check(w.map.width == STOCK_W and w.CanvasFits(), "4 protected combat maximize: Blizzard's size, canvas fits")
	check(w.map.AzeriteBackdrop.shown == true and w.map.BorderFrame.alpha == 0, "4 protected combat maximize: cosmetic style applied")
	check(w.navBar.shown == false and w.closeButton.points[1][1] == "TOPLEFT", "4 protected map: its unprotected children still styled")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.map.width == STOCK_W, "4 after combat, map open: size waits for hide")
	check(w.Anchor() == "TOP,0,0", "4 after combat, full-size map: not centred, got " .. w.Anchor())
	check(w.IsRegistered("PLAYER_REGEN_ENABLED"), "4 after combat: size still pending")
	w.Close()
	check(near(w.map.width, OURS_W) and near(w.map.height, OURS_H), "4 on hide: our size, once")
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "4 on hide: nothing left pending")
	w.Open()
	check(w.Anchor() == "CENTER,0,30" and near(w.map.width, OURS_W), "4 next open: centred at our size")
	check(w.CanvasFits(), "4 next open: canvas rebuilt for our size")
	w.Audit("4")
end

-- 5. A UI scale change in combat with the map closed and protected.
do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true; w.SetProtected(true)
	w.stockW, w.stockH = 1200, 840
	w.ScaleChanged()
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	local ow, oh = Ours(1200, 840)
	check(near(w.map.width, ow) and near(w.map.height, oh), "5 after combat: our size from Blizzard's new size")
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "5 after combat: replay done")
	w.Open()
	check(w.CanvasFits() and w.Anchor() == "CENTER,0,30", "5 next open: canvas fits, centred")
	w.Audit("5")
end

-- 6. Minimize in combat while protected (L, or the side panel toggle).
do
	local w = Load()
	w.Open()
	w.combat = true; w.SetProtected(true)
	w.QuestLog()
	check(w.map.AzeriteBackdrop.shown == false and w.navBar.shown == true, "6 protected combat minimize: cosmetic style removed")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.Anchor() == "TOPLEFT,16,-94", "6 after combat: our minimized anchor, got " .. w.Anchor())
	check(w.closeButton.points[1][1] == "TOPRIGHT", "6 after combat: close button back")
	w.Audit("6")
end

-- 7. UpdateSettings: never compounds, and waits out combat when switching off.
do
	local w = Load()
	w.Open()
	w.UpdateSettings(); w.UpdateSettings()
	check(near(w.map.width, OURS_W) and near(w.map.height, OURS_H), "7 UpdateSettings twice: no double shrink")
	w.combat = true; w.SetProtected(true)
	w.module.db.profile.enabled = false
	w.UpdateSettings()
	check((w.fromAddon.SynchronizeDisplayState or 0) == 0, "7 module off in combat: no Blizzard call yet")
	check(w.map.AzeriteBackdrop.shown == true, "7 module off in combat: style kept until combat ends")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.map.AzeriteBackdrop.shown == false and w.navBar.shown == true, "7 after combat: style removed")
	check(w.fromAddon.SynchronizeDisplayState == 1, "7 after combat: RestoreBlizzardState ran once")
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "7 after combat: replay done")
	w.module.db.profile.enabled = true
	w.UpdateSettings()
	check(near(w.map.width, OURS_W) and near(w.map.height, OURS_H), "7 module back on: our size, not compounded")
	w.expectRestore = 1
	w.Audit("7")
end

-- 7b. Unprotected combat: switching on applies at once (as before), switching off waits.
do
	local w = Load({ enabled = false })
	w.Open()
	w.combat = true
	w.module.db.profile.enabled = true
	w.UpdateSettings()
	check(w.map.AzeriteBackdrop.shown == true and near(w.map.width, OURS_W), "7b switch on in unprotected combat: applied at once")
	w.module.db.profile.enabled = false
	w.UpdateSettings()
	check(w.map.AzeriteBackdrop.shown == true and w.IsRegistered("PLAYER_REGEN_ENABLED"), "7b switch off in combat: waits")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.map.AzeriteBackdrop.shown == false, "7b after combat: switched off")
	w.expectRestore = 1
	w.Audit("7b")
end

-- 8. Unreadable IsProtected answers fail closed.
for _, answer in ipairs({ "secret", "error" }) do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true; w.SetProtected(true); w.protectedAnswer = answer
	w.Open()
	w.combat = false; w.protectedAnswer = nil
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.Anchor() == "CENTER,0,30", "8 IsProtected " .. answer .. ": centred after combat")
	w.Audit("8 " .. answer)
end

-- 9. Protection ends before combat does: the hide replays in combat.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.SetProtected(false)
	w.Close()
	check(near(w.map.width, OURS_W), "9 unprotected hide in combat: size applied")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "9 after combat: replay done")
	w.Audit("9")
end

-- 10. Module off: Blizzard's map, nothing queued.
do
	local w = Load({ enabled = false })
	w.combat = true; w.SetProtected(true)
	w.Open()
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "10 module off: nothing queued")
	check(w.map.width == STOCK_W and w.Anchor() == "TOP,0,0", "10 module off: Blizzard's map")
	w.Audit("10")
end

-- 11. A hide in combat while still protected keeps the size pending.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.Close()
	check(w.map.width == STOCK_W and w.IsRegistered("PLAYER_REGEN_ENABLED"), "11 protected hide in combat: size still pending")
	w.combat = false; w.SetProtected(false)
	w.Fire("PLAYER_REGEN_ENABLED")
	check(near(w.map.width, OURS_W) and not w.IsRegistered("PLAYER_REGEN_ENABLED"), "11 after combat: size replayed once")
	w.Audit("11")
end

-- 12. Switched off in combat with hook replays queued: not restyled, not shrunk.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.module.db.profile.enabled = false
	w.UpdateSettings()
	w.combat = false; w.SetProtected(false)
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.map.AzeriteBackdrop.shown == false and w.navBar.shown == true, "12 off with replays queued: not restyled")
	check(w.map.width == STOCK_W and w.Anchor() == "TOP,0,0", "12 off with replays queued: Blizzard's size and anchor, got " .. w.Anchor())
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "12 off with replays queued: nothing left pending")
	w.Close()
	check(w.map.width == STOCK_W, "12 off with replays queued: hide does not shrink")
	w.expectRestore = 1
	w.Audit("12")
end

-- 13. A scale change while the module is off is still recorded.
do
	local w = Load()
	w.Open()
	w.module.db.profile.enabled = false; w.UpdateSettings()
	w.stockW, w.stockH = 1200, 840
	w.ScaleChanged()
	w.module.db.profile.enabled = true; w.UpdateSettings()
	local ow, oh = Ours(1200, 840)
	check(near(w.map.width, ow) and near(w.map.height, oh), "13 scale change while off: our size from the new Blizzard size")
	w.expectRestore = 1
	w.Audit("13")
end

-- 14. A size the hook applies out of combat clears the pending one, so the anchor follows.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.combat = false; w.SetProtected(false)
	w.Fire("PLAYER_REGEN_ENABLED")
	w.ScaleChanged()
	check(near(w.map.width, OURS_W), "14 scale change out of combat: our size")
	w.combat = true; w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.Anchor() == "CENTER,0,30", "14 next replay: centred, got " .. w.Anchor())
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "14 next replay: nothing left pending")
	w.Audit("14")
end

-- 15. The culprit sits under the NavBar: NavBar and map protected.
do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true; w.Protect(w.navBar, true)
	w.QuestLog()
	check(w.navBar.shown == false, "15 protected NavBar in combat: left alone")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.navBar.shown == true and w.Anchor() == "TOPLEFT,16,-94", "15 after combat: NavBar and anchor replayed")
	w.Audit("15")
end

-- 16. A secure frame anchored only to the close button: the map itself reports unprotected.
do
	local w = Load()
	w.Open(); w.Close()
	w.combat = true
	w.protectedFrames[w.closeButton] = true  -- anchoring: the parent chain is not protected
	w.QuestLog()
	check(w.Anchor() == "TOPLEFT,16,-94", "16 anchor-only close button: map still moved in combat, got " .. w.Anchor())
	w.combat = false; w.protectedFrames[w.closeButton] = nil
	w.Fire("PLAYER_REGEN_ENABLED")
	check(w.closeButton.points[1][1] == "TOPRIGHT", "16 after combat: close button replayed")
	w.Audit("16")
end

-- 17. Alt+Z hides the map's parent: OnHide fires with IsShown still true.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.combat = false; w.SetProtected(false)
	w.Fire("PLAYER_REGEN_ENABLED")
	w.HideByParent()
	check(w.map.width == STOCK_W and w.IsRegistered("PLAYER_REGEN_ENABLED"), "17 parent hide: size still pending")
	w.ShowByParent()
	check(w.Anchor() == "TOP,0,0" and w.CanvasFits(), "17 parent show: full-size map not centred, canvas fits, got " .. w.Anchor())
	w.Close()
	check(near(w.map.width, OURS_W) and not w.IsRegistered("PLAYER_REGEN_ENABLED"), "17 real hide: size applied")
	w.Audit("17")
end

-- 18. The regen registration does not outlive the pending work.
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.combat = false; w.SetProtected(false)
	w.Fire("PLAYER_REGEN_ENABLED")              -- size and anchor wait: the map is open
	w.Minimize(); w.Maximize()                  -- Blizzard's own maximize, map still open, clears both
	check(w.map.shown and w.Anchor() == "CENTER,0,30" and near(w.map.width, OURS_W), "18 maximize while open: styled")
	w.Close()
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "18 pending emptied by the hooks: regen unregistered")
	w.Audit("18")
end

-- 19. A settings change in combat on a protected open map: after combat it styles, sizes
-- and centres it (as a switch-on out of combat sizes an open map).
do
	local w = Load()
	w.combat = true; w.SetProtected(true)
	w.Open()
	w.UpdateSettings()
	check(w.map.width == STOCK_W, "19 settings in combat on a protected map: waits")
	w.combat = false
	w.Fire("PLAYER_REGEN_ENABLED")
	check(near(w.map.width, OURS_W) and w.Anchor() == "CENTER,0,30", "19 after combat: our size, centred, got " .. w.Anchor())
	check(not w.IsRegistered("PLAYER_REGEN_ENABLED"), "19 after combat: nothing left pending")
	w.Audit("19")
end

print(string.format("worldmap_combat_harness: %d passed, %d failed", passed, failed))
if (failed > 0) then os.exit(1) end

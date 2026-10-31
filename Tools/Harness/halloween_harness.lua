-- Run with Tools/Run-Elune.ps1 -Script Tools/Harness/halloween_harness.lua .
local root = arg[1] or "."
local checks, created, combat = 0, 0, false
local today = { year = 2026, month = 10, day = 17 }
local clock, timers = 0, {}
GetTime = function() return clock end
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
date = function(format) assert(format == "*t"); return today end
InCombatLockdown = function() return combat end
local function writable() assert(not combat, "decorative mutation during combat") end
local function animationGroup()
	local group = { animations = {}, playing = false, plays = 0 }
	function group:CreateAnimation(kind)
		local animation = { kind = kind, controls = {} }
		for _, key in ipairs({"FromAlpha","ToAlpha","Duration","Order","Smoothing","StartDelay","Degrees","CurveType"}) do
			animation["Set"..key] = function(self, value) self[key] = value end
		end
		function animation:SetOrigin(...) self.origin = {...} end
		function animation:CreateControlPoint(_, _, order)
			local control = { order = order, SetOffset = function(self,x,y) self.x,self.y=x,y end }
			self.controls[#self.controls+1] = control; return control
		end
		self.animations[#self.animations+1] = animation; return animation
	end
	function group:SetLooping(value) self.loop = value end
	function group:SetToFinalAlpha(value) self.finalAlpha = value end
	function group:IsPlaying() return self.playing end
	function group:Play() self.playing = true; self.plays = self.plays+1 end
	function group:Stop() self.playing = false end
	return group
end
local function region(parent)
	local r = { parent = parent, shown = true, textures = {}, children = {}, scripts = {}, groups = {}, level = 2, width = 196, height = 196 }
	function r:SetAllPoints(target) writable(); self.allPoints = target end
	function r:EnableMouse(enabled) writable(); self.mouse = enabled end
	function r:SetFrameLevel(level) writable(); self.level = level end
	function r:GetFrameLevel() return self.level end
	function r:GetParent() return self.parent end
	function r:GetWidth() return self.width end
	function r:GetHeight() return self.height end
	function r:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
	function r:HookScript(event, callback)
		local old = self.scripts[event]
		self.scripts[event] = function(...) if old then old(...) end; callback(...) end
	end
	function r:CreateAnimationGroup() local group = animationGroup(); self.groups[#self.groups+1] = group; return group end
	function r:SetParent(value) writable(); self.parent = value end
	function r:ClearAllPoints() writable(); self.point = nil end
	function r:SetAlpha(value) writable(); self.alpha = value end
	function r:SetShown(value)
		writable(); local changed = self.shown ~= value; self.shown = value
		local callback = self.scripts[value and "OnShow" or "OnHide"]
		if changed and callback then callback(self) end
	end
	function r:SetTexture(path) writable(); self.path = path end
	function r:GetTexture() return self.path end
	function r:GetTexCoord() return unpack(self.coords or {0,1,0,1}) end
	function r:SetTexCoord(...) writable(); self.coords = {...} end
	function r:SetBlendMode(value) writable(); self.blend = value end
	function r:SetVertexColor(...) writable(); self.vertexColor = {...} end
	function r:SetDrawLayer(layer, sublevel) writable(); self.layer,self.sublevel = layer,sublevel end
	function r:SetClipsChildren(value) writable(); self.clipsChildren = value end
	function r:CreateMaskTexture() writable(); local mask = region(self); self.mask = mask; return mask end
	function r:AddMaskTexture(mask) writable(); self.mask = mask end
	function r:SetSize(w, h) writable(); self.width, self.height = w, h end
	function r:SetPoint(...) writable(); self.point = {...} end
	function r:SetRotation(angle) writable(); self.rotation = angle end
	function r:CreateTexture(_, layer, _, sublevel)
		writable(); local t = region(self); t.layer, t.sublevel = layer, sublevel
		self.textures[#self.textures+1] = t; return t
	end
	return r
end
GameTooltip, GameMenuFrame = region(), region()
SharedTooltip_SetBackdropStyle = function() end
hooksecurefunc = function(object, method, fn)
	if (type(object) == "string") then object, method, fn = _G, object, method end
	local original = object[method]
	object[method] = function(...) original(...); fn(...) end
end
CreateFrame = function(kind, name, parent)
	writable(); assert(kind == "Frame" and name == nil)
	created = created + 1
	local frame = region(parent)
	parent.children[#parent.children+1] = frame
	return frame
end
local tick, cancelled
C_Timer = { NewTicker = function(interval, fn)
	assert(interval == 30); tick = fn
	return { Cancel = function() cancelled = true end }
end }
C_Timer.NewTimer = function(interval, fn)
	local timer = { interval = interval, callback = fn, Cancel = function(self) self.cancelled = true end }
	timers[#timers+1] = timer; return timer
end
local callback, module, page
local minimap = { frame = region(), enabled = true }
function minimap:IsEnabled() return self.enabled end
local ns = { Prefix = "AzeriteUI", db = { char = {} }, oUF = {} }
ns.OptionsKit = { Panel = { Open = function() _G.AzeriteUIOptionsPanel = region() end } }
function ns.oUF:RegisterInitCallback(fn) callback = fn end
local options = { AddGroup = function(_, name, generate) assert(name == "Themes"); page = generate() end }
function ns:GetModule(name)
	if (name == "Minimap") then return minimap end
	if (name == "Options") then return options end
end
function ns:NewModule(name)
	assert(name == "Halloween")
	module = { enabled = true, events = {} }
	function module:IsEnabled() return self.enabled end
	function module:RegisterEvent(event, method) self.events[event] = method end
	return module
end
local function load(relative) return assert(loadfile(root .. "/" .. relative))("AzeriteUI5_JuNNeZ_Edition", ns) end
load("Core/HalloweenEffects.lua")
load("Core/Halloween.lua")
local H = ns.Halloween
H:OnEnable()
local function player(style)
	local f = { style = ns.Prefix .. style, Health = region(), Power = region(), ManaOrb = region() }
	f.ManaOrb.width, f.ManaOrb.height = 103, 103
	f.Power.Value, f.ManaOrb.Value = region(f.Power), region(f.ManaOrb)
	f.Power.Backdrop = region(f.Power)
	f.Power.Backdrop.path = "native-power-backdrop.tga"
	callback(f)
	return f
end
local main = player("Player")
check(created == 0 and not main.Power.HalloweenHead, "off-season allocates no decoration")
check(not H:SetHidden(true) and not ns.db.char.halloweenHiddenYear, "off-season cannot save an opt-out")
for _, case in ipairs({ {10,17,false}, {10,18,true}, {10,31,true}, {11,1,true}, {11,2,false}, {1,1,false}, {12,31,false} }) do
	today.month, today.day = case[1], case[2]
	check((H:GetSeasonYear() ~= nil) == case[3], "season boundary " .. case[1] .. "/" .. case[2])
end
today.month, today.day = 10, 30
tick()
check(main.Power.HalloweenHead.shown and main.ManaOrb.HalloweenHead.shown and H.minimapOverlay.shown, "date tick starts both resource heads without reload")
check(main.Power.HalloweenHead.parent == main.Power.Value:GetParent(), "head shares value parent for text layering")
check(main.ManaOrb.HalloweenHead.parent == main.ManaOrb.Value:GetParent(), "orb head below value text on its own parent")
check(#main.Health.textures == 0, "no bats or webs on health")
check(#H.minimapOverlay.textures == 2 and H.minimapOverlay.mouse == false, "only front lights on external overlay, click-through")
check(H.minimapEffects.Leaves == nil and #H.minimapEffects.Wisps == 4, "no exterior leaf band; soul lights retained")
check(H.minimapEffects.WispTimer.interval >= 1200 and H.minimapEffects.WispTimer.interval <= 1500, "random 20-25 minute wisp interval")
for _, visit in ipairs(H.minimapEffects.WispVisits) do
	for _, animation in ipairs(visit) do
		check(not animation:IsPlaying() and animation.loop == nil, "wisps wait hidden and never loop")
	end
	local controls = visit[1].animations[1].controls
	check(controls[#controls].x ~= controls[1].x, "irregular wisp excursion does not form a closed orbit")
	check(visit[2].finalAlpha and visit[2].animations[#visit[2].animations].ToAlpha == 0, "wisp disappears completely at end of visit")
end
check(H.minimapEffects.Back.level < minimap.frame.level, "rear wisps behind native map/casing")
local passage = H.minimapEffects.Passage
check(passage.clipsChildren and passage.mouse == false and passage.allPoints == minimap.frame, "leaf passage clips to map without taking input")
check(H.minimapEffects.LeafMask.allPoints == minimap.frame and #H.minimapEffects.LeafMask.groups == 0, "round mask fixed on map, never animated")
check(#H.minimapEffects.GustLeaves == 7 and #H.minimapEffects.Back.textures == 2, "leaves only allocated inside passage")
for _, leaf in ipairs(H.minimapEffects.GustLeaves) do
	check(leaf.parent == passage and leaf.mask == H.minimapEffects.LeafMask, "every moving leaf uses fixed circular mask")
	check(leaf.point[4] < -minimap.frame.width/2, "leaf begins behind left edge")
	local controls = leaf.groups[1].animations[1].controls
	check(leaf.point[4]+controls[#controls].x > minimap.frame.width/2, "leaf ends behind right edge")
	for i = 2,#controls do check(controls[i].x > controls[i-1].x, "leaf wind always advances left to right") end
end
check(H.minimapEffects.Timer.interval >= 600 and H.minimapEffects.Timer.interval <= 900, "random 10-15 minute gust interval")
for _, t in ipairs(H.minimapOverlay.textures) do
	check(t.path:match("Assets\\Halloween\\.+%.tga$") ~= nil, "runtime texture path")
end
check(main.Power.HalloweenHead.point[2] == main.Power and main.Power.HalloweenHead.point[1] == "CENTER", "pumpkin is inside crystal")
check(main.Power.HalloweenHead.point[5] == main.Power.height*.015-20 and main.ManaOrb.HalloweenHead.point[5] == 0, "crystal face 20px lower; orb unchanged")
check(main.ManaOrb.HalloweenHead.point[2] == main.ManaOrb, "pumpkin is inside orb")
check(main.Power.HalloweenHead.width < main.Power.width and main.ManaOrb.HalloweenHead.width < main.ManaOrb.width, "heads fit resource interiors")
local pulse = main.Power.HalloweenHead.HalloweenPulse
check(pulse:IsPlaying() and pulse.animations[1].FromAlpha == .18 and pulse.animations[1].ToAlpha == .40, "subtle native Horseman pulse")
check(main.Power.HalloweenHead.path:match("horseman%-face%-v2.tga$") and main.Power.HalloweenHead.blend == "ADD", "new carved features emit green light without grey backing")
check(main.Power.HalloweenHead.layer == "OVERLAY" and main.Power.HalloweenHead.sublevel == -7, "head below default OVERLAY 0 resource text")
check(main.Power.HalloweenSurface.path == main.Power.Backdrop.path and main.Power.HalloweenSurface.allPoints == main.Power.Backdrop, "crystal veil reuses native facet material and bounds")
check(main.Power.HalloweenSurface.sublevel > main.Power.HalloweenHead.sublevel and main.Power.HalloweenSurface.sublevel < 0, "native facets above face but below value text")
check(main.Power.HalloweenRecess.sublevel < main.Power.HalloweenHead.sublevel and main.Power.HalloweenRecess.allPoints == main.Power.HalloweenHead, "carved recess below pulsing green apertures")
check(main.ManaOrb.HalloweenHead.layer == "BORDER" and main.ManaOrb.HalloweenHead.sublevel == -1, "orb face below existing BORDER 0 glass")
ns.OptionsKit.Panel:Open()
local menuWebs = AzeriteUIOptionsPanel.children[1]
check(#AzeriteUIOptionsPanel.textures == 0 and menuWebs, "options hook creates child decorations without altering original window textures")
check(#menuWebs.textures == 3 and menuWebs.mouse == false, "two click-through corner webs and a spider")
check(menuWebs.textures[1].point[3] == "TOPLEFT" and menuWebs.textures[2].point[3] == "BOTTOMRIGHT", "webs follow opposite corners")
check(GameTooltip.children[1].textures[1].width == 44 and menuWebs.textures[1].width == 56, "enlarged tooltip and menu webs")
check(menuWebs.Spider.width == 7, "larger spider")
check(not menuWebs.textures[1].rotation and menuWebs.textures[2].rotation == math.pi, "web mounting sides face inward")
check(menuWebs.SpiderAnimation:IsPlaying() and menuWebs.SpiderAnimation.animations[1].kind == "Path", "spider follows native closed path")
local fx = H.minimapEffects
check(fx:Burst(), "manual first gust")
check(not fx:Burst(), "hover gust debounce")
clock = 31
minimap.frame.scripts.OnEnter(minimap.frame)
check(fx.LastBurst == 31, "mouseover triggers next eligible gust")
check(fx.LastVisit == nil, "mouseover does not trigger rare wisp visit")
clock = 700
local scheduled = fx.Timer
scheduled.callback()
check(fx.LastBurst == 700 and fx.Timer ~= scheduled, "scheduled gust runs and schedules the next interval")
for _, group in ipairs(fx.Bursts) do check(group:IsPlaying(), "native gust animation started") end
local wispTimer = fx.WispTimer
wispTimer.callback()
check(fx.WispTimer ~= wispTimer and fx.WispTimer.interval >= 1200 and fx.WispTimer.interval <= 1500, "wisp timer runs then rearms independent random interval")
check(fx.LastVisit == 1 or fx.LastVisit == 2, "wisp chooses a random prebuilt route")
for index, visit in ipairs(fx.WispVisits) do
	for _, group in ipairs(visit) do check(group:IsPlaying() == (index == fx.LastVisit), "only selected wisp visit plays") end
end
local addonTooltip = region()
SharedTooltip_SetBackdropStyle(addonTooltip)
local count = created
SharedTooltip_SetBackdropStyle(addonTooltip)
check(created == count, "tooltip hook reuses existing corner overlay")
local forbidden = region()
function forbidden:IsForbidden() return true end
SharedTooltip_SetBackdropStyle(forbidden)
check(created == count, "forbidden tooltip untouched")
SharedTooltip_SetBackdropStyle(region(), nil, true)
check(created == count, "embedded tooltip untouched")
local secret = {}
issecretvalue = function(value) return value == secret end
SharedTooltip_SetBackdropStyle(region(), nil, secret)
check(created == count, "secret embedded flag is not used as a boolean")
local oldWidth = main.Power.width
main.Power.width = secret
H:Refresh()
check(main.Power.HalloweenHead.width < 196, "unreadable dimensions do not enter size arithmetic")
main.Power.width = oldWidth
local alt, party = player("PlayerAlternate"), player("PlayerParty")
check(alt.Power.HalloweenHead and party.Power.HalloweenHead, "alternate and party-style players decorated")
local target, plate, group = player("Target"), player("NamePlate"), player("Party")
check(not target.Power.HalloweenHead and not plate.Power.HalloweenHead and not group.Power.HalloweenHead, "no clutter on target, nameplates or groups")
local before = created
local pendingWispTimer = fx.WispTimer
for _ = 1, 5 do H:Refresh() end
check(created == before, "refresh reuses decorations")
check(fx.WispTimer == pendingWispTimer, "ordinary refresh does not restart the long wisp countdown")
check(H:SetHidden(true) and ns.db.char.halloweenHiddenYear == 2026, "opt-out saves current event year")
check(not main.Power.HalloweenHead.shown and not main.ManaOrb.HalloweenHead.shown and not H.minimapOverlay.shown, "opt-out hides both heads and minimap at once")
check(not main.Power.HalloweenSurface.shown and not passage.shown, "opt-out hides native veil and interior leaf passage")
check(not main.Power.HalloweenRecess.shown, "opt-out also hides carved recess")
check(not menuWebs.shown and not GameTooltip.children[1].shown, "same opt-out hides menu and tooltip webs")
check(not pulse:IsPlaying() and not menuWebs.SpiderAnimation:IsPlaying(), "opt-out stops pulse and spider")
check(not fx.Timer and not fx.Enabled and not fx.Back.shown, "opt-out cancels gust timer and rear band")
check(not fx.WispTimer, "opt-out cancels rare wisp timer")
for _, visit in ipairs(fx.WispVisits) do
	for _, group in ipairs(visit) do check(not group:IsPlaying(), "opt-out stops wisp visit") end
end
check(H:IsHidden(), "opt-out read back after refresh")
-- Reload the actual module with the same database, as login/reload does.
load("Core/Halloween.lua")
H = ns.Halloween
check(H:IsHidden(), "saved opt-out survives a fresh module load")
callback(main); callback(alt); callback(party)
H:OnEnable()
check(not main.Power.HalloweenHead.shown, "reload does not restore hidden event")
check(H:SetHidden(false) and main.Power.HalloweenHead.shown, "unticking restores decoration immediately")
H:SetHidden(true)
today.year = 2027
tick()
check(not H:IsHidden() and main.Power.HalloweenHead.shown, "next Halloween automatically returns")
combat = true
before = created
check(not H:SetHidden(true) and not H:Refresh() and created == before, "combat rejects setting and frame mutations")
SharedTooltip_SetBackdropStyle(region())
check(created == before, "combat tooltip hook does not create or mutate frames")
clock = 900
minimap.frame.scripts.OnEnter(minimap.frame)
check(H.minimapEffects.LastBurst == 900 and created == before, "combat hover only plays prebuilt native animations")
H.minimapEffects.WispTimer.callback()
check(H.minimapEffects.LastVisit ~= nil and created == before, "combat timer plays only prebuilt wisp visit")
today.month, today.day = 11, 2
tick()
check(main.Power.HalloweenHead.shown, "midnight changes wait for combat to end")
clock = 940
check(not H.minimapEffects:Burst() and H.minimapEffects.LastBurst == 900, "no new gust after event expires during combat")
check(not H.minimapEffects:Visit(), "no new wisp visit after seasonal expiry")
combat = false
H[H.events.PLAYER_REGEN_ENABLED](H)
check(not main.Power.HalloweenHead.shown and not H.minimapOverlay.shown, "combat exit reconciles expired event")
today.month, today.day = 10, 30
H:Refresh()
minimap.enabled = false
H:Refresh()
check(not H.minimapOverlay.shown, "disabled minimap does not leave decoration")
check(not H.minimapEffects.Timer, "disabled minimap cancels timer")
check(not H.minimapEffects.WispTimer, "disabled minimap cancels wisp timer")
minimap.enabled = true
H:Refresh()
check(H.minimapOverlay.shown, "re-enabled minimap restores decoration")
local currentFX = H.minimapEffects
minimap.frame.shown = false
minimap.frame.scripts.OnHide(minimap.frame)
check(not currentFX.Timer and not currentFX.WispTimer, "hidden map cancels both effect timers")
minimap.frame.shown = true
minimap.frame.scripts.OnShow(minimap.frame)
check(currentFX.Timer and currentFX.WispTimer, "shown map schedules both timers without immediately playing wisps")
for _, visit in ipairs(currentFX.WispVisits) do
	for _, group in ipairs(visit) do check(not group:IsPlaying(), "map restore keeps wisps hidden until timer") end
end
local strip = player("PlayerParty")
strip.Power.width, strip.Power.height = 300,12
H:Refresh()
check(strip.Power.HalloweenHead.point[5] == 12*.015, "horizontal power strip does not inherit crystal nudge")
-- Read the real Themes page; unrelated class controls are absent in this fixture.
local L = setmetatable({}, {__index = function(_, key) return key end})
LibStub = function() return {GetLocale = function() return L end} end
ns.ThemeEffects = {GetTheme = function() return "legacy" end}
load("Options/OptionsPages/Themes.lua")
local toggle = page.args.halloween
check(not toggle.hidden() and toggle.name == "Hide Halloween decorations", "seasonal option also visible on Legacy")
toggle.set(nil, true)
check(toggle.get() and not main.Power.HalloweenHead.shown, "real option writes seasonal setting")
today.month, today.day = 11, 2
check(toggle.hidden(), "option disappears after event")
ns.db = nil
check(not H:IsHidden() and not H:SetHidden(true), "defensive missing database")
module.enabled = false
H:OnDisable()
check(cancelled and not main.Power.HalloweenHead.shown, "disable cancels ticker and hides decoration")
-- Compile every new runtime file using this Lua 5.1-compatible runtime.
check(loadfile(root .. "/Locale/Halloween.lua") ~= nil, "locale syntax")
-- Exercise translations through the shipped AceLocale proxies, including
-- enGB's enUS fallback, rather than assuming a plain assignment table.
LibStub = nil
assert(loadfile(root .. "/Libs/LibStub/LibStub.lua"))()
for _, language in ipairs({"enUS", "enGB", "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}) do
	GetLocale = function() return language end
	local ace = LibStub:GetLibrary("AceLocale-3.0", true)
	if (ace) then LibStub.minors["AceLocale-3.0"] = nil end
	geterrorhandler = function() return function(message) error(message) end end
	assert(loadfile(root .. "/Libs/AceLocale-3.0/AceLocale-3.0.lua"))()
	load("Locale/Halloween.lua")
	local translated = LibStub("AceLocale-3.0"):GetLocale("AzeriteUI5_JuNNeZ_Edition")
	local label = translated["Hide Halloween decorations"]
	check(type(label) == "string" and #label > 0, "translation: " .. language)
	if (language ~= "enUS" and language ~= "enGB") then
		check(label ~= "Hide Halloween decorations", "localized label: " .. language)
	end
	LibStub("AceLocale-3.0").apps = {}
end
print("Halloween: " .. checks .. " checks passed")

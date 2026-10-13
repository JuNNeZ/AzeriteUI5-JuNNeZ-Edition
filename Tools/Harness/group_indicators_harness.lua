-- Group Indicators: Sated and corner aura dots on party and raid frames.
-- Loads the real Components/UnitFrames/GroupIndicators.lua against stubs, attaches
-- it to fake oUF frames through the init callback and drives settings, units and
-- UNIT_AURA payloads. Rendering and the real aura container are not modelled.
-- Run: lua.exe Tools/Harness/group_indicators_harness.lua <addon root>
local root = arg[1] or '.'
local checks, failures = 0, 0
local function check(v, msg)
	checks = checks + 1
	if (not v) then failures = failures + 1; print("FAIL: " .. msg) end
end

local secretMeta = {
	__lt = function() error("compared a secret value") end,
	__le = function() error("compared a secret value") end,
	__sub = function() error("arithmetic on a secret value") end,
	__add = function() error("arithmetic on a secret value") end,
}
local function secret(v) return setmetatable({ value = v }, secretMeta) end
issecretvalue = function(v) return getmetatable(v) == secretMeta end

-- Widgets: just enough to record what the module does.
local function Widget(kind)
	local w = { kind = kind, shown = true, points = {}, calls = {} }
	local function log(name, ...) w.calls[#w.calls + 1] = { name, ... } end
	function w:SetFrameLevel(l) self.level = l end
	function w:GetFrameLevel() return self.level or 1 end
	function w:EnableMouse(e) self.mouse = e end
	function w:SetMouseMotionEnabled() end
	function w:SetMouseClickEnabled() end
	function w:Hide() self.shown = false end
	function w:Show() self.shown = true end
	function w:IsShown() return self.shown end
	function w:SetSize(a, b) self.w, self.h = a, b end
	function w:SetAllPoints() end
	function w:ClearAllPoints() self.points = {} end
	function w:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function w:GetHeight() return self.h or 12 end
	function w:CreateTexture()
		local t = Widget("Texture")
		function t:SetTexture(p) self.texture = p end
		function t:SetTexCoord() end
		function t:SetColorTexture() end
		return t
	end
	function w:SetDrawEdge() end
	function w:SetDrawBling() end
	function w:SetReverse() end
	function w:SetHideCountdownNumbers() end
	function w:SetCooldown(start, duration) self.cooldown = { start, duration } end
	-- AuraContainer
	function w:SetEnabled(e) self.enabled = e; log("SetEnabled", e) end
	function w:SetUnit(u) self.unit = u; log("SetUnit", u) end
	function w:AddAuraGroup(key, filter, opts) self.group = { key = key, filter = filter, opts = opts }; log("AddAuraGroup", filter) end
	function w:SetAuraGroupFilterString(key, filter) self.group.filter = filter; log("SetAuraGroupFilterString", filter) end
	function w:SetAuraGroupCandidateFilters(key, filters) self.group.opts.candidateFilters = filters; log("SetAuraGroupCandidateFilters") end
	function w:SetAuraGroupLayout(key, layout) self.group.opts.layout = layout; log("SetAuraGroupLayout") end
	function w:GetAuraGroupFrameCount() return 0 end
	return w
end

local created = {}
CreateFrame = function(kind, name, parent, template)
	local w = Widget(kind)
	w.parent, w.template = parent, template
	created[#created + 1] = w
	return w
end
C_XMLUtil = { GetTemplateInfo = function(name) return name == "CustomAuraContainerTemplate" and {} or nil end }

local auras = {}  -- unit -> spellID -> aura
C_UnitAuras = { GetUnitAuraBySpellID = function(unit, spellID) return auras[unit] and auras[unit][spellID] end }
local spellNames = { ["Renew"] = 139, ["Rejuvenation"] = 774 }
C_Spell = {
	GetSpellIDForSpellIdentifier = function(word) return spellNames[word] end,
	GetSpellTexture = function(id) return "icon:" .. id end
}

local profile = {}
local callback
local ns = {
	Prefix = "AzeriteUI",
	oUF = { RegisterInitCallback = function(_, fn) callback = fn end },
	GetModule = function(_, name) if name == "UnitFrames" then return { db = { profile = profile } } end end
}

assert(loadfile(root .. "/Components/UnitFrames/GroupIndicators.lua"))("AzeriteUI5_JuNNeZ_Edition", ns)
local GI = ns.GroupIndicators
check(type(callback) == "function", "attaches through oUF's init callback")

local function NewFrame(style, unit)
	local frame = Widget("Button")
	frame.style, frame.unit = style, unit
	frame.events = {}
	function frame:RegisterEvent(event, fn) self.events[event] = fn end
	frame.Health = Widget("StatusBar"); frame.Health.h = 14
	frame.Health.Overlay = Widget("Frame")
	frame.postUpdates = 0
	frame.PostUpdate = function(self, event) self.postUpdates = self.postUpdates + 1 end
	callback(frame)
	return frame
end

-- Only the four group styles.
local target = NewFrame("AzeriteUITarget", "target")
check(target.SatedIndicator == nil and target.events.UNIT_AURA == nil, "target frame is left alone")
local party = NewFrame("AzeriteUIParty", "party1")
check(party.SatedIndicator ~= nil, "party frame gets a Sated icon")
check(party.events.UNIT_AURA ~= nil, "party frame listens to UNIT_AURA")
local raid = NewFrame("AzeriteUIRaid40", "raid7")
check(raid.SatedIndicator ~= nil, "raid40 frame gets a Sated icon")

-- The style's own PostUpdate keeps running; indicators only on full updates.
party:PostUpdate("PLAYER_ENTERING_WORLD")
check(party.postUpdates == 1, "the style's PostUpdate still runs")
party:PostUpdate(nil)
check(party.postUpdates == 2, "PostUpdate without an event still reaches the style")

-- Sated: off by default.
auras.party1 = { [57723] = { auraInstanceID = 11, icon = 136012, duration = 600, expirationTime = 700 } }
party:PostUpdate("ForceUpdate")
check(not party.SatedIndicator:IsShown(), "Sated stays hidden while the option is off")

profile.groupSated = true
GI.Refresh()
check(party.SatedIndicator:IsShown(), "Sated shows for Exhaustion once on")
check(party.SatedIndicator.Icon.texture == 136012, "Sated uses the aura's icon")
check(party.SatedIndicator.Cooldown.cooldown and party.SatedIndicator.Cooldown.cooldown[1] == 100
	and party.SatedIndicator.Cooldown.cooldown[2] == 600, "the swipe runs from the aura's start for its duration")
check(not raid.SatedIndicator:IsShown(), "a member without the debuff shows nothing")

-- Secret timing: shown, no swipe, no arithmetic.
auras.raid7 = { [57724] = { auraInstanceID = 3, icon = secret(1), duration = secret(600), expirationTime = secret(700) } }
local ok, err = pcall(GI.Refresh)
check(ok, "secret timing raises nothing " .. tostring(err))
check(raid.SatedIndicator:IsShown() and raid.SatedIndicator.Icon.texture == "icon:57724",
	"secret icon falls back to the spell's texture")
check(not raid.SatedIndicator.Cooldown:IsShown(), "secret timing: no swipe")

-- A secret answer as a whole: hidden.
auras.raid7 = { [57724] = secret({}) }
GI.Refresh()
check(not raid.SatedIndicator:IsShown(), "a secret aura is treated as unknown and hidden")

-- UNIT_AURA filtering: refreshes alone do nothing; an add or the shown aura's removal does.
auras.party1 = nil
party.events.UNIT_AURA(party, "UNIT_AURA", "party1", { updatedAuraInstanceIDs = { 11 } })
check(party.SatedIndicator:IsShown(), "a refresh of other auras does not re-read")
party.events.UNIT_AURA(party, "UNIT_AURA", "party1", { removedAuraInstanceIDs = { 99 } })
check(party.SatedIndicator:IsShown(), "removing another aura does not re-read")
party.events.UNIT_AURA(party, "UNIT_AURA", "party1", { removedAuraInstanceIDs = { 11 } })
check(not party.SatedIndicator:IsShown(), "removing the shown debuff hides it")
auras.party1 = { [80354] = { auraInstanceID = 12, icon = 1, duration = 600, expirationTime = 650 } }
party.events.UNIT_AURA(party, "UNIT_AURA", "party1", { addedAuras = { {} } })
check(party.SatedIndicator:IsShown(), "an added aura re-reads (Temporal Displacement)")
party.events.UNIT_AURA(party, "UNIT_AURA", "party2", { isFullUpdate = true })
check(party.SatedIndicator:IsShown(), "another unit's event is ignored")

-- Instances hand over a plain table with secret fields (BugSack 2026-10-13): re-read, never test them.
-- Plain Lua cannot trap a boolean test on a secret, so these check the outcome only.
auras.party1 = nil
ok, err = pcall(party.events.UNIT_AURA, party, "UNIT_AURA", "party1",
	{ isFullUpdate = secret(false), addedAuras = secret({}) })
check(ok, "secret isFullUpdate/addedAuras raise nothing " .. tostring(err))
check(not party.SatedIndicator:IsShown(), "secret isFullUpdate re-reads")
auras.party1 = { [80354] = { auraInstanceID = 12, icon = 1, duration = 600, expirationTime = 650 } }
GI.Refresh()
auras.party1 = nil
party.events.UNIT_AURA(party, "UNIT_AURA", "party1", { removedAuraInstanceIDs = secret({ 12 }) })
check(not party.SatedIndicator:IsShown(), "secret removed IDs re-read")

profile.groupSated = false
GI.Refresh()
check(not party.SatedIndicator:IsShown(), "switching Sated off hides it at once")

-- Spell list parsing.
local spells, unknown, count = GI.ParseSpellList(" 774, Renew ;61295\nNot A Spell, 0, 1.5")
check(spells[774] and spells[139] and spells[61295] and count == 3, "IDs and names parse, names through the client")
check(#unknown == 3, "unknown names, zero and fractions are reported")

-- Corners: nothing until on, then only the corners that have spells.
local function Containers(frame)
	local list = {}
	for corner, c in pairs(frame.CornerIndicators or {}) do list[corner] = c end
	return list
end
profile.groupCornerSpellsTOPLEFT = "774"
GI.Refresh()
check(party.CornerIndicators == nil, "corners off: no containers built")

profile.groupCorners = true
profile.groupCornerOnlyMine = true
profile.groupCornerSize = 12
GI.Refresh()
local c = Containers(party)
check(c.TOPLEFT and not c.TOPRIGHT and not c.BOTTOMLEFT and not c.BOTTOMRIGHT, "only the corner with spells is built")
local tl = c.TOPLEFT
check(tl.template == "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate", "a native aura container")
check(tl.group.filter == "HELPFUL|PLAYER", "only mine: HELPFUL|PLAYER")
check(tl.group.opts.candidateFilters.includeSpellIDs[774], "the corner filters by the list")
check(tl.group.opts.maxFrameCount == 1, "one dot per corner")
check(tl.unit == "party1" and tl.enabled == true and tl:IsShown(), "pointed at the frame's unit and enabled")
check(tl.points[1] and tl.points[1][1] == "TOPLEFT" and tl.points[1][2] == party.Health, "anchored in the health bar's corner")
check(tl.mouse == false, "takes no mouse input, so clicks reach the frame")

-- No rebuild when nothing changed.
local before = #tl.calls
GI.Refresh()
local rebuilt = false
for i = before + 1, #tl.calls do if tl.calls[i][1] == "SetAuraGroupCandidateFilters" or tl.calls[i][1] == "SetUnit" then rebuilt = true end end
check(not rebuilt, "a refresh with nothing changed does not rebuild or re-point")

-- A list change rebuilds; the source switch changes the filter string.
profile.groupCornerSpellsTOPLEFT = "774, Renew"
profile.groupCornerOnlyMine = false
GI.Refresh()
check(tl.group.opts.candidateFilters.includeSpellIDs[139] and tl.group.filter == "HELPFUL", "list and source changes reach the container")

-- The header hands the button to someone else.
party.unit = "party3"
party:PostUpdate("GROUP_ROSTER_UPDATE")
check(tl.unit == "party3", "follows the frame to its new unit")

-- Size.
profile.groupCornerSize = 99
GI.Refresh()
check(tl.w == 20, "size is clamped to 20")

-- Emptying a corner hides it; switching off disables every container.
profile.groupCornerSpellsTOPLEFT = ""
GI.Refresh()
check(not tl:IsShown() and tl.enabled == false, "an emptied corner is hidden and disabled")
profile.groupCornerSpellsTOPLEFT = "774"
GI.Refresh()
check(tl:IsShown() and tl.enabled == true, "and comes back")
profile.groupCorners = false
GI.Refresh()
check(not tl:IsShown() and tl.enabled == false, "switched off: hidden and disabled (no UNIT_AURA work)")

-- Without the container template the corners are never built.
C_XMLUtil = nil
profile.groupCorners = true
local fresh = NewFrame("AzeriteUIRaid25", "raid2")
fresh:PostUpdate("ForceUpdate")
check(fresh.CornerIndicators == nil, "no container template: no corners, no error")

print(string.format("Group indicators: %d checks, %d failures (offline only).", checks, failures))
if (failures > 0) then os.exit(1) end

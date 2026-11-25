-- Enemy Casts harness (offline only).
-- Loads Components/Misc/EnemyCasts.lua against stubbed widgets and unit APIs and drives it
-- through cast events: listing, nameplate dedupe, order, the current-target highlight, the
-- interrupted hold, row cap, "my target only", secret values passed through, and turning off.
-- Run: lua Tools/Harness/enemy_casts_harness.lua <addon root>

local root = arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if (not ok) then
		failures = failures + 1
		print("FAIL: " .. label)
	end
end

-- Secrets: a marked table. issecretvalue knows it; the module must only hand it to widgets.
local SECRET = {}
local function Secret(value) return setmetatable({ value = value }, SECRET) end
local function IsSecretStub(v) return getmetatable(v) == SECRET end

-- Widgets ------------------------------------------------------------------------------
local function Region()
	local r = { shown = true, alpha = 1, points = {} }
	-- Unknown widget methods (capitalised) are no-ops; data fields stay nil.
	local mt = { __index = function(t, k)
		if (type(k) == "string" and k:match("^%u")) then return function() end end
	end }
	setmetatable(r, mt)
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:SetShown(v) self.shown = v and true or false end
	function r:IsShown() return self.shown end
	function r:SetAlpha(a) self.alpha = a end
	function r:GetAlpha() return self.alpha end
	function r:SetAlphaFromBoolean(b, yes, no)
		self.alphaFromBoolean = b
		if (IsSecretStub(b)) then b = b.value end
		self.alpha = b and (yes / 255) or (no / 255)
	end
	function r:SetText(t) self.text = t end
	function r:GetText() return self.text end
	function r:SetFormattedText(fmt, v) self.text = string.format(fmt, IsSecretStub(v) and v.value or v) end
	function r:SetTexture(t) self.texture = t end
	function r:SetTextColor(r_, g, b) self.color = { r_, g, b } end
	function r:SetSpriteSheetCell(index) self.cell = index end
	function r:ClearAllPoints() self.points = {} end
	function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function r:SetSize(w, h) self.w, self.h = w, h end
	function r:SetWidth(w) self.w = w end
	function r:SetHeight(h) self.h = h end
	function r:GetSize() return self.w or 0, self.h or 0 end
	function r:GetWidth() return self.w or 0 end
	function r:SetScale(scale) self.scale = scale end
	function r:SetFrameStrata(strata) self.strata = strata end
	function r:EnableMouse(on) self.mouse = on end
	function r:GetEffectiveScale() return self.scale or 1 end
	function r:CreateTexture() return Region() end
	function r:CreateFontString() return Region() end
	function r:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
	function r:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
	function r:UnregisterAllEvents() self.events = {} end
	function r:GetStatusBarTexture() self.fill = self.fill or Region(); return self.fill end
	function r:SetStatusBarColor(r_, g, b) self.barColor = { r_, g, b } end
	function r:SetMinMaxValues(a, b) self.min, self.max = a, b end
	function r:SetValue(v) self.value = v end
	function r:SetTimerDuration(d, interp, dir) self.timer = d; self.timerDirection = dir; return true end
	function r:GetTimerDuration() return self.timer end
	function r:GetRect() return 10, 20, 260, 34 end
	function r:GetFrameLevel() return 1 end
	function r:SetAttribute(k, v)
		if (inCombat) then secureInCombat = secureInCombat + 1 end
		self.attributes = self.attributes or {}; self.attributes[k] = v
	end
	return r
end

-- Combat lockdown: every secure write in combat is counted, and must stay at zero.
inCombat, secureInCombat = false, 0
InCombatLockdown = function() return inCombat end
local secureFrames = {}
CreateFrame = function(kind, name, parent, template)
	local f = Region()
	if (template) then
		f.template = template
		secureFrames[#secureFrames + 1] = f
		for _, method in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize" }) do
			local orig = f[method]
			f[method] = function(self, ...)
				if (inCombat) then secureInCombat = secureInCombat + 1 end
				return orig(self, ...)
			end
		end
	end
	return f
end
RegisterStateDriver = function(frame, state, value) frame.driver = { state, value } end
UIParent = Region()
local moverOpen = false

-- Game state ----------------------------------------------------------------------------
local now = 100
GetTime = function() return now end
issecretvalue = IsSecretStub
Enum = { StatusBarInterpolation = { Immediate = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
INTERRUPTED = "Interrupted"

local units = {}   -- token -> { guid, hostile, cast = {...}, plate, marker }
local function U(token) return units[token] end

UnitExists = function(u) return U(u) ~= nil end
UnitCanAttack = function(_, u) return U(u) and U(u).hostile or false end
UnitIsUnit = function(a, b) return U(a) ~= nil and U(b) ~= nil and U(a).guid == U(b).guid end
UnitName = function(u) if (u == "player") then return "Player" end return U(u) and U(u).name end
UnitCastingInfo = function(u)
	local c = U(u) and U(u).cast
	if (not c or c.kind ~= "cast") then return nil end
	return c.name, c.name, c.icon, 0, 0, false, nil, c.locked, c.spellID
end
UnitChannelInfo = function(u)
	local c = U(u) and U(u).cast
	if (not c or c.kind == "cast") then return nil end
	return c.name, c.name, c.icon, 0, 0, false, c.locked, c.spellID, c.kind == "empower"
end
UnitCastingDuration = function(u) return { remaining = 2.5, GetRemainingDuration = function() return 2.5 end } end
UnitChannelDuration = UnitCastingDuration
UnitEmpoweredChannelDuration = UnitCastingDuration
GetRaidTargetIndex = function(u) return U(u) and U(u).marker end
SetRaidTargetIconTexture = function(t, i) t.cell = i end
PlayerIsSpellTarget = function(u) return U(u) and U(u).cast and U(u).cast.atMe or false end
UnitShouldDisplaySpellTargetName = function(u) return U(u) and U(u).cast and U(u).cast.target ~= nil end
UnitSpellTargetName = function(u) return U(u) and U(u).cast and U(u).cast.target end
C_Spell = { GetSpellInfo = function(id) return { name = "Spell" .. id, iconID = id } end }
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = .25, g = .78, b = .92 } }
UnitClass = function() return "Warrior", "WARRIOR" end
C_NamePlate = { GetNamePlateForUnit = function(u) return U(u) and U(u).plate end }

-- Addon ---------------------------------------------------------------------------------
local Colors = setmetatable({}, { __index = function() return { 1, 1, 1 } end })
local ns = {
	Prefix = "AzeriteTest",
	Colors = Colors,
	API = {
		TryCall = function(f, ...) if (type(f) ~= "function") then return false end return pcall(f, ...) end,
		GetEffectiveScale = function() return 1 end,
		GetFont = function() return {} end,
		GetMedia = function(n) return n end,
		IsEventAvailable = function() return true end,
		SafeUnitIsUnit = function(a, b) return UnitIsUnit(a, b) end,
		CreateCastBarSpark = function(bar) bar.Spark = Region(); return bar.Spark end
	},
	MovableModulePrototype = { defaults = { enabled = true }, OnEnable = function() end }
}
function ns:Merge(t, base) for k, v in pairs(base) do if (t[k] == nil) then t[k] = v end end return t end
local module
function ns:GetModule(name)
	if (name == "MovableFramesManager") then return { IsMFMFrameOpen = function() return moverOpen end } end
end
function ns:NewModule(name, proto)
	module = setmetatable({ name = name }, { __index = proto })
	module.CreateAnchor = function(self) self.anchor = { Enable = function(a) a.enabled = true end, Disable = function(a) a.enabled = false end }; return self.anchor end
	module.UpdateAnchor = function() end
	return module
end
LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end

local chunk = assert(loadfile(root .. "/Components/Misc/EnemyCasts.lua"))
chunk("AzeriteTest", ns)

local profile = { enabled = true, mode = "all", maxRows = 3, width = 260, growUp = false, showSpellTarget = true }
module.db = { profile = profile }
module:OnEnable()

local function Fire(event, unit) module:OnCastEvent(event, unit) end
local function Rows()
	local out = {}
	for _, row in ipairs(module.frame.rows) do
		if (row:IsShown()) then out[#out + 1] = row end
	end
	return out
end

check(module.eventFrame.events and module.eventFrame.events.UNIT_SPELLCAST_START, "enabled list registers cast events")
check(module.anchor.enabled == true, "mover enabled while on")
check(not module.frame:IsShown(), "empty list is hidden")

-- Two nameplate casters; the target has a plate too.
local plateA, plateB = {}, {}
units.nameplate1 = { guid = "A", hostile = true, name = "Cultist", plate = plateA, marker = 8,
	cast = { kind = "cast", name = "Shadow Bolt", icon = 1, atMe = true, target = "Me" } }
units.target = { guid = "A", hostile = true, name = "Cultist", plate = plateA, marker = 8,
	cast = units.nameplate1.cast }
Fire("UNIT_SPELLCAST_START", "target")
Fire("UNIT_SPELLCAST_START", "nameplate1")
now = 101
units.nameplate2 = { guid = "B", hostile = true, name = "Acolyte", plate = plateB,
	cast = { kind = "channel", name = "Mind Flay", icon = 2, locked = true } }
Fire("UNIT_SPELLCAST_CHANNEL_START", "nameplate2")

local rows = Rows()
check(#rows == 2, "two casters, two rows (target listed once, under its nameplate): " .. #rows)
check(module.frame:IsShown(), "list shows with casts")
check(rows[1] and rows[1].unit == "nameplate1" and rows[1].Spell.text == "Shadow Bolt", "oldest cast first")
check(rows[1] and rows[1].TargetEdge.alpha == 1 and rows[1].TargetEdge.texture == "cast_back_outline", "current target's row gets the casing outline")
check(rows[2] and rows[2].TargetEdge.alpha == 0, "other rows not highlighted")
check(rows[1] and rows[1].AimedEdge.alpha == 1, "aimed-at-you edge on")
check(rows[1] and rows[1].Target.text == "Me" and rows[1].Arrow.shown, "spell target name shown")
check(rows[1] and rows[1].Marker.shown and rows[1].Marker.cell == 8, "raid marker shown")
check(rows[2] and rows[2].Locked.alpha == 1 and rows[2].Shield.alpha == 1 and rows[2].Casing.alpha == 0,
	"uninterruptible cast: grey fill, spiked casing instead of the plain one")
check(rows[1] and rows[1].Casing.alpha == 1 and rows[1].Shield.alpha == 0, "interruptible cast: plain casing")
check(rows[1] and rows[1].Casing.texture == "cast_back" and rows[1].Shield.texture == "cast_back_spiked"
	and rows[1].Bar.AimedGlow.texture == "nameplate_glow", "AzeriteUI castbar art")
check(rows[2] and rows[2].Bar.timerDirection == 1, "channel runs as remaining time")
check(rows[1] and rows[1].Bar.timerDirection == 0, "cast runs as elapsed time")

-- Click to target, out of combat: one secure button per row, over it, with its unit.
local buttons = module.clickButtons or {}
check(module.clickContainer and module.clickContainer.driver and module.clickContainer.driver[2] == "[combat] hide; show",
	"click container hidden by the game in combat")
check(buttons[1] and buttons[1].shown and buttons[1].attributes.unit == "nameplate1", "row 1 clicks target its mob")
check(buttons[1] and buttons[1].attributes.type1 == "target", "left click targets")
check(buttons[2] and buttons[2].shown and buttons[2].attributes.unit == "nameplate2", "row 2 clicks target its mob")
check(buttons[1] and buttons[1].template == "SecureUnitButtonTemplate", "secure unit button")
check(buttons[1] and buttons[1].points[1] and buttons[1].points[1][2] == UIParent, "placed by screen position, not anchored to the row")

-- In combat the list keeps updating but nothing secure is touched.
inCombat = true
now = 101.5
units.nameplate7 = { guid = "H", hostile = true, plate = {}, cast = { kind = "cast", name = "Hex" } }
Fire("UNIT_SPELLCAST_START", "nameplate7")
module:CheckCasts()
check(#Rows() == 3, "list still updates in combat")
check(secureInCombat == 0, "no secure call in combat: " .. secureInCombat)
check(buttons[3] == nil or not buttons[3].shown, "no new click button in combat")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
buttons = module.clickButtons
check(buttons[3] and buttons[3].shown and buttons[3].attributes.unit == "nameplate7", "buttons follow the list after combat")
units.nameplate7.cast = nil
Fire("UNIT_SPELLCAST_STOP", "nameplate7")
check(not buttons[3].shown and buttons[3].attributes.unit == nil, "empty row's button hidden and cleared")

-- /lock open: no click buttons in the way of the movers.
moverOpen = true
module:CheckCasts()
check(not buttons[1].shown and not buttons[2].shown, "click buttons hidden while /lock is open")
moverOpen = false
module:CheckCasts()
check(buttons[1].shown, "click buttons back after /lock")

-- Target changes to B: highlight moves without reshuffling.
units.target = { guid = "B", hostile = true, name = "Acolyte", plate = plateB, cast = units.nameplate2.cast }
Fire("PLAYER_TARGET_CHANGED")
rows = Rows()
check(rows[1].unit == "nameplate1" and rows[1].TargetEdge.alpha == 0, "highlight leaves the old target")
check(rows[2].unit == "nameplate2" and rows[2].TargetEdge.alpha == 1, "highlight follows the new target")

-- A boss without a nameplate is listed under its own token, and not twice via focus.
units.boss1 = { guid = "C", hostile = true, name = "Boss", cast = { kind = "cast", name = "Doom", icon = 3 } }
units.focus = { guid = "C", hostile = true, name = "Boss", cast = units.boss1.cast }
now = 102
Fire("UNIT_SPELLCAST_START", "boss1")
Fire("UNIT_SPELLCAST_START", "focus")
rows = Rows()
check(#rows == 3, "boss added once (focus deduped): " .. #rows)
local listedFocus = false
for _, row in ipairs(rows) do if (row.unit == "focus") then listedFocus = true end end
check(not listedFocus or rows[3].unit == "focus", "focus/boss listed under one token")

-- Row cap.
units.nameplate3 = { guid = "D", hostile = true, name = "Imp", plate = {}, cast = { kind = "cast", name = "Firebolt" } }
now = 103
Fire("UNIT_SPELLCAST_START", "nameplate3")
check(#Rows() == 3, "rows capped at the maximum")

-- Interrupt: the row holds "Interrupted", then goes.
units.nameplate1.cast = nil
Fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
Fire("UNIT_SPELLCAST_STOP", "nameplate1")
rows = Rows()
check(rows[1].unit == "nameplate1" and rows[1].Spell.text == "Interrupted", "interrupted cast held")
now = 104
module:CheckCasts()
rows = Rows()
check(rows[1].unit ~= "nameplate1", "interrupted cast dropped after the hold")
check(#rows == 3 and rows[3].unit == "nameplate3", "the next caster moves up into the freed row")

-- Missed stop: the backstop drops a cast that ended without an event.
units.nameplate3.cast = nil
module:CheckCasts()
for _, row in ipairs(Rows()) do check(row.unit ~= "nameplate3", "missed stop cleaned up") end

-- Friendly casters never listed.
units.nameplate4 = { guid = "E", hostile = false, plate = {}, cast = { kind = "cast", name = "Heal" } }
Fire("UNIT_SPELLCAST_START", "nameplate4")
for _, row in ipairs(Rows()) do check(row.unit ~= "nameplate4", "friendly caster not listed") end

-- Secret values go straight to the widgets.
units.nameplate5 = { guid = "F", hostile = true, plate = {}, name = Secret("Hidden"), marker = Secret(3),
	cast = { kind = "cast", name = Secret("Secret Spell"), icon = Secret(9), locked = Secret(true), target = Secret("Tank") } }
profile.maxRows = 6
module:UpdateSettings()
now = 105
local ok, err = pcall(Fire, "UNIT_SPELLCAST_START", "nameplate5")
check(ok, "secret cast does not raise: " .. tostring(err))
local secretRow
for _, row in ipairs(Rows()) do if (row.unit == "nameplate5") then secretRow = row end end
check(secretRow ~= nil, "secret cast listed")
if (secretRow) then
	check(IsSecretStub(secretRow.Spell.text), "secret spell name passed to SetText")
	check(IsSecretStub(secretRow.Icon.texture), "secret icon passed to SetTexture")
	check(IsSecretStub(secretRow.Caster.text), "secret caster passed to SetText")
	check(IsSecretStub(secretRow.Marker.cell) and secretRow.Marker.shown, "secret marker handed to the sprite sheet")
	check(IsSecretStub(secretRow.Locked.alphaFromBoolean), "secret interrupt state via SetAlphaFromBoolean")
	check(IsSecretStub(secretRow.Casing.alphaFromBoolean) and IsSecretStub(secretRow.Shield.alphaFromBoolean), "secret state swaps the casings")
	check(IsSecretStub(secretRow.Target.text), "secret cast target passed to SetText")
end

-- My target only.
profile.mode = "target"
module:UpdateSettings()
rows = Rows()
check(#rows == 1 and rows[1].unit == "target", "target mode lists only the target")
check(rows[1].TargetEdge.alpha == 1, "target mode row highlighted")
units.nameplate6 = { guid = "G", hostile = true, plate = {}, cast = { kind = "cast", name = "Frostbolt" } }
Fire("UNIT_SPELLCAST_START", "nameplate6")
check(#Rows() == 1, "target mode ignores other casters")

-- Mover preview: example rows in the list's own size, the configured count, in its direction.
profile.mode, profile.maxRows, profile.previewCasts, profile.growUp = "all", 5, 3, false
module:UpdateSettings()
local frameWidth = module.frame.w
local box = Region(); box.w = frameWidth * .5
check(module:BuildMoverGhost(box) == true, "ghost builds")
local ghost = module.moverGhost
check(ghost and ghost.scale == .5, "ghost scaled to the mover box")
check(ghost and #ghost.rows == 5, "one example row per list row")
local shownExamples = 0
for _, row in ipairs(ghost.rows) do if (row.shown) then shownExamples = shownExamples + 1 end end
check(shownExamples == 3, "preview shows the chosen number of casts: " .. shownExamples)
local first = ghost.rows[1]
check(first.Spell.text == "Spell686" and first.Icon.texture == 686, "example spell name and icon")
check(first.TargetEdge.alpha == 1, "first example marked as your target")
check(first.AimedEdge.alpha == 1 and first.Target.text == "Player", "first example aimed at you")
check(first.Target.color and first.Target.color[2] == .61, "class colour keeps all three channels")
check(ghost.rows[2].Shield.alpha == 1 and ghost.rows[2].Locked.alpha == 1 and ghost.rows[2].Casing.alpha == 0, "an uninterruptible example")
check(first.Marker.shown and first.Marker.cell == 8, "example raid marker")
check(first.Bar.Spark and first.Bar.Spark.shown, "example spark")
check(first.points[1] and first.points[1][1] == "TOPLEFT", "grows down by default")
profile.previewCasts, profile.growUp = 5, true
module:UpdateSettings()
shownExamples = 0
for _, row in ipairs(ghost.rows) do if (row.shown) then shownExamples = shownExamples + 1 end end
check(shownExamples == 5, "preview count follows the setting at once")
check(first.points[1] and first.points[1][1] == "BOTTOMLEFT", "preview follows grow upwards")
profile.previewCasts = 12
module:UpdateSettings()
shownExamples = 0
for _, row in ipairs(ghost.rows) do if (row.shown) then shownExamples = shownExamples + 1 end end
check(shownExamples == 5, "preview capped at the most casts shown")

-- Options preview: example casts on the list's spot, live with the settings, off in combat.
check(not module:IsPreviewShown(), "preview off by default")
module:SetPreviewShown(true)
check(module:IsPreviewShown() and module.previewList and #module.previewList.rows == 5, "preview shows example rows")
local panelHidden = module.previewBox.scripts and module.previewBox.events and module.previewBox.events.PLAYER_REGEN_DISABLED
check(panelHidden, "preview listens for combat")
check(module.previewBox.strata == "DIALOG", "preview drawn above the options window")
check(module.previewBox.mouse == false, "preview lets clicks through to the options")
check(module.previewList.scale ~= nil, "preview scaled even before its size resolves")
profile.maxRows = 7
module:UpdateSettings()
check(#module.previewList.rows == 7, "preview follows the row count")
module.previewBox.scripts.OnEvent(module.previewBox, "PLAYER_REGEN_DISABLED")
check(not module:IsPreviewShown(), "preview turns off when combat starts")
inCombat = true
module:SetPreviewShown(true)
check(not module:IsPreviewShown(), "preview cannot start in combat")
inCombat = false
module:SetPreviewShown(true)
profile.enabled = false
module:UpdateSettings()
check(not module:IsPreviewShown(), "turning the list off ends the preview")
profile.enabled, profile.maxRows = true, 5
module:UpdateSettings()

-- Default position: the maintainer's spot at 1080p (middle right, -350, 85, scale 71.1).
ns.API.GetEffectiveScale = function() return 768 / 1080 end
local position = module:GenerateDefaults().profile.savedPosition
check(position[1] == "RIGHT", "default anchor point is the middle right side")
check(math.abs(position[2] + 350) < .001 and math.abs(position[3] - 85) < .001, "default offsets -350, 85 at 1080p")
check(math.abs(position.scale * 100 - 71.11) < .01, "default scale 71.1 at 1080p")

-- Turning it off.
profile.enabled = false
module:UpdateSettings()
check(not module.frame:IsShown() and #Rows() == 0, "off hides the list")
check(module.anchor.enabled == false, "off disables the mover")
check(next(module.eventFrame.events) == nil, "off unregisters events")
local anyShown = false
for _, b in ipairs(module.clickButtons) do if (b.shown) then anyShown = true end end
check(not anyShown, "off hides every click button")

print(string.format("Enemy casts: %d checks, %d failures (offline only)", checks, failures))
if (failures > 0) then os.exit(1) end

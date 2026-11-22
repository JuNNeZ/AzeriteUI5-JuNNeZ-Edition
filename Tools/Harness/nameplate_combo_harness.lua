-- Actual Forever nameplate combo module, with strict opaque counts and recording widgets.
-- Widgets model clamping only; rendering and actual client secrets need maintainer testing.
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local hidden = setmetatable({}, { __mode = "k" })
local secretMT = {}
for _, key in ipairs({ "__add", "__sub", "__mul", "__div", "__lt", "__le", "__concat", "__index" }) do
	secretMT[key] = function() error("opaque value inspected") end
end
local function secret(value)
	local proxy = setmetatable({}, secretMT)
	hidden[proxy] = value
	return proxy
end
local function isSecret(value) return hidden[value] ~= nil end
local function widget()
	local w = { shown = true, events = {} }
	function w:Hide() self.shown = false end
	function w:Show() self.shown = true end
	function w:IsShown() return self.shown end
	function w:SetShown(shown) self.shown = shown end
	function w:SetValue(v) self.value = hidden[v] or v end -- native widget boundary
	function w:SetMinMaxValues(lo, hi) self.lo, self.hi = lo, hi end
	function w:GetFrameLevel() return 7 end
	function w:CreateTexture()
		local texture = widget()
		self.textures = self.textures or {}
		self.textures[#self.textures + 1] = texture
		return texture
	end
	function w:RegisterUnitEvent(event, unit) self.events[event] = unit end
	function w:RegisterEvent(event) self.events[event] = true end
	function w:UnregisterAllEvents() self.events = {} end
	function w:SetScript(_, callback) self.callback = callback end
	function w:SetPoint(...) self.anchor = { ... } end
	function w:ClearAllPoints() self.anchor = nil end
	function w:GetFont() return "TestFont", 12 end
	function w:SetSize(width, height) self.width, self.height = width, height end
	function w:SetStatusBarTexture(texture) self.texture = texture end
	function w:GetStatusBarTexture()
		self.fill = self.fill or widget()
		return self.fill
	end
	function w:CreateMaskTexture() return widget() end
	function w:AddMaskTexture(mask) self.mask = mask end
	function w:SetAlpha(alpha) self.alpha = alpha end
	function w:SetAllPoints(relative) self.allPoints = relative end
	function w:SetStatusBarColor(...) self.color = { ... } end
	function w:SetTexture(texture) self.texture = texture end
	for _, method in ipairs({ "SetFrameLevel", "EnableMouse", "SetVertexColor" }) do
		w[method] = function() end
	end
	return w
end
local function scenario(class, forever)
	local state = { target = "nameplate1", counts = { nameplate1 = 3, nameplate2 = 0 }, power = 3, attack = true, dead = false, vehicle = false, visible = true }
	local enabled, allocations, reads = true, 0, 0
	local mod = { db = { profile = { enabled = true, showComboPoints = false } } }
	function mod:IsEnabled() return enabled end
	local function safeTrue(v) return not isSecret(v) and v == true end
	local function safeFalse(v) return not isSecret(v) and not v end
	local NP = {
		NamePlatesMod = mod, IsSecretValue = isSecret, IsSafeTrue = safeTrue, IsSafeFalse = safeFalse,
		IsSafeUnitToken = function(unit) return not isSecret(unit) and type(unit) == "string" and unit ~= "" end,
		SafeUnitMatches = function(unit) return unit == state.target end,
		ShouldShowNamePlateForBlizzardVisibility = function() return state.visible end,
		ShouldUseFriendlyPlayerNameOnly = function() return false end,
		GetTargetLikeNameLift = function() return state.targetLift or 0 end
	}
	local a = { unit = "nameplate1", Health = widget(), Overlay = widget(), Name = widget(), Auras = widget(), isTarget = true }
	local b = { unit = "nameplate2", Health = widget(), Overlay = widget(), Name = widget(), Auras = widget(), isTarget = true }
	a.Auras.spacing, b.Auras.spacing = 4, 4
	local ns = { NamePlatesPrivate = NP, IsForever = forever, ActiveNamePlates = { [a] = true, [b] = true },
		API = { IsEventAvailable = function() return true end, GetMedia = function(name) return "Assets/" .. name .. ".tga" end } }
	ns.GetConfig = function() return { HealthBarPosition = { "TOP", 0, -1 }, NamePosition = { "TOP", 0, 16 }, AurasPosition = { "BOTTOM", 0, 40 }, WidgetPosition = { "TOP", 0, -14 } } end
	local watcher
	local env = setmetatable({
		UnitClass = function() return class, class end,
		UnitPowerType = function() return state.power end,
		UnitCanAttack = function() return state.attack end,
		UnitIsDeadOrGhost = function() return state.dead end,
		UnitHasVehicleUI = function() return state.vehicle end,
		GetComboPoints = function(unit, target)
			check(unit == "player" and (target == "nameplate1" or target == "nameplate2"), "each plate asks for its own mob")
			reads = reads + 1
			return state.counts[target]
		end,
		Enum = { PowerType = { Energy = 3 } },
		type = function(v) return isSecret(v) and "number" or type(v) end,
		CreateFrame = function(kind)
			allocations = allocations + 1
			local frame = widget()
			if allocations == 1 then watcher = frame end
			return frame
		end
	}, { __index = _G })
	-- Real name/aura anchors, including their dynamic target lift and cached aura offset.
	local visible = NP.ShouldShowNamePlateForBlizzardVisibility
	for _, file in ipairs({ "Visibility", "Elements" }) do
		local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/" .. file .. ".lua"))
		setfenv(chunk, env)("AzeriteUI", ns)
	end
	NP.ShouldShowNamePlateForBlizzardVisibility = visible
	local chunk = assert(loadfile(root .. "/Components/UnitFrames/NamePlates/ComboPoints.lua"))
	setfenv(chunk, env)("AzeriteUI", ns)
	-- Build the real options page and exercise its setting through the real setter.
	local options
	local optionsModule = { AddGroup = function(_, _, generate) options = generate() end }
	ns.GetModule = function(_, name) return name == "Options" and optionsModule or mod end
	env.LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end } end
	chunk = assert(loadfile(root .. "/Options/OptionsPages/Nameplates.lua"))
	setfenv(chunk, env)("AzeriteUI", ns)
	local toggle = assert(options.args.enemies.args.comboPoints.args.showComboPoints)
	local size = assert(options.args.enemies.args.comboPoints.args.comboPointScale)
	local sizeInfo = { "visibility", "comboPointScale" }
	check(toggle.hidden() == (not forever), "actual option is Forever-only")
	check(size.hidden() == (not forever) and size.disabled(sizeInfo), "size option follows client and enabled state")
	check(size.get(sizeInfo) == 100 and size.min == 50 and size.max == 300, "size slider has safe default and bounds")
	mod.UpdateSettings = NP.ConfigureComboPoints
	NP.ConfigureComboPoints()
	check(allocations == 0 and reads == 0, "default off allocates and reads nothing")
	local info = { "visibility", "showComboPoints" }
	toggle.set(info, true)
	check(toggle.get(info) == true, "actual option setter persists and refreshes")
	if not forever or class == "MAGE" then
		check(allocations == 0 and reads == 0, "Retail/unsupported class has no watcher or widgets")
		return
	end
	check(watcher.events.COMBO_TARGET_CHANGED and watcher.events.UNIT_POWER_UPDATE == "player", "Forever transfer and filtered player events")
	local function fills(plate, count)
		local row = plate.ForeverComboPoints
		check(row and row.shown, "target row visible")
		local band = 2 + 6 * row.comboScale
		check(plate.Name.anchor[3] == 16 + band + (state.targetLift or 0) + (state.widgetLift or 0), "name reserves scaled combo band plus existing lifts")
		check(plate.Auras.anchor[3] == 56 + band + (state.targetLift or 0) + (state.widgetLift or 0), "auras move with name")
		for i = 1, 5 do
			check(math.max(0, math.min(1, (row[i].value - row[i].lo) / (row[i].hi - row[i].lo))) == (i <= count and 1 or 0), "point fill " .. i)
		end
	end
	fills(a, 3)
	check(a.ForeverComboPoints.width == 42 and a.ForeverComboPoints.height == 6, "compact socket row footprint")
	check(NP.GetComboPointNameLift(a) == 8, "themed art keeps the same reserved band")
	for i = 1, 5 do
		local point = a.ForeverComboPoints[i]
		check(point.texture == "Assets/point_crystal.tga" and point.width == 3 and point.height == 3, "native faceted crystal at compact size")
		local socket = point.textures[1]
		check(socket.texture == "Assets/point_plate.tga" and socket.width == 6 and socket.height == 6, "native socket stays inside row")
		check(point.anchor[4] - 3 >= 0 and point.anchor[4] + 3 <= 42, "socket cannot escape horizontal footprint")
	end
	check(a.ForeverComboPoints[5].color[1] == 1 and a.ForeverComboPoints[1].color[3] == 1, "gold finisher and blue ordinary crystals")
	check(not size.disabled(sizeInfo), "size slider enabled with combo display")
	state.counts.nameplate1 = secret(3)
	local originalAllocations = allocations
	for _, percent in ipairs({ 50, 150, 200, 300, 100 }) do
		size.set(sizeInfo, percent)
		local scale, row = percent / 100, a.ForeverComboPoints
		check(size.get(sizeInfo) == percent and mod.db.profile.comboPointScale == scale, "size option persists a multiplier")
		check(row.width == 42 * scale and row.height == 6 * scale, "live row size follows setting")
		check(row.VisibilityMask.width == row.width and row.VisibilityMask.height == row.height, "secret mask tracks whole scaled row")
		for i = 1, 5 do
			local point = row[i]
			check(point.width == 3 * scale and point.Socket.width == 6 * scale and point.Socket.height == row.height, "crystal and socket resize together")
			check(point.anchor[4] - 3 * scale >= 0 and point.anchor[4] + 3 * scale <= row.width, "scaled socket stays within mask bounds")
		end
		fills(a, 3)
		check(allocations == originalAllocations, "resizing reuses existing widgets")
	end
	for _, invalid in ipairs({ { value = "bad", expected = 1 }, { value = 0, expected = .5 }, { value = 100, expected = 3 } }) do
		mod.db.profile.comboPointScale = invalid.value
		NP.ConfigureComboPoints()
		check(a.ForeverComboPoints.comboScale == invalid.expected, "invalid saved size defaults or clamps: " .. tostring(invalid.value) .. " -> " .. tostring(a.ForeverComboPoints.comboScale))
	end
	size.set(sizeInfo, 100)
	state.targetLift = 6
	NP.NamePlate_PostUpdatePositions(a)
	fills(a, 3)
	a.WidgetContainer = widget()
	a.WidgetContainer.numWidgetsShowing = 1
	mod.db.profile.showBlizzardWidgets, state.widgetLift = true, 14
	NP.NamePlate_PostUpdatePositions(a)
	fills(a, 3)
	check(a.Health.anchor[3] == 13, "widget lift still moves health and its attached combo row")
	mod.db.profile.showBlizzardWidgets, state.widgetLift = false, 0
	state.targetLift = 0
	NP.NamePlate_PostUpdatePositions(a)
	check(not b.ForeverComboPoints, "non-target allocates nothing")
	for _, n in ipairs({ 0, 1, 3, 5 }) do
		state.counts.nameplate1 = secret(n)
		watcher.callback(watcher, "UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
		fills(a, n)
	end
	state.target, state.counts.nameplate2 = "nameplate2", secret(0)
	watcher.callback(watcher, "PLAYER_TARGET_CHANGED")
	fills(a, 5)
	check(a.ForeverComboPoints.VisibilityGate.value == 5, "old target keeps its actual points")
	fills(b, 0)
	check(b.ForeverComboPoints.VisibilityGate.value == 1, "new target keeps empty sockets")
	state.counts.nameplate2 = secret(4)
	state.counts.nameplate1 = secret(0)
	watcher.callback(watcher, "COMBO_TARGET_CHANGED")
	fills(b, 4)
	check(a.ForeverComboPoints.VisibilityGate.value == 0, "transfer masks old mob's sockets and cores at secret zero")
	size.set(sizeInfo, 200)
	check(a.ForeverComboPoints.VisibilityGate.value == 0 and a.ForeverComboPoints.VisibilityMask.width == 84, "resizing masked non-target does not reveal it")
	fills(b, 4)
	size.set(sizeInfo, 100)
	for i = 1, 5 do
		local point = a.ForeverComboPoints[i]
		check(point.fill.mask and point.textures[1].mask == point.fill.mask
			and point.textures[2].mask == point.fill.mask, "entire point shares visibility mask")
		local mask, gate = point.fill.mask, a.ForeverComboPoints.VisibilityGate
		check(gate.allPoints == a.ForeverComboPoints and gate.lo == 0 and gate.hi == 1
			and mask.width == 42 and mask.height == 6 and mask.anchor[1] == "RIGHT"
			and mask.anchor[2] == gate.fill and mask.anchor[3] == "RIGHT", "mask follows native fill over the entire row")
	end
	local before = reads
	watcher.callback(watcher, "UNIT_POWER_UPDATE", "player", "MANA")
	check(reads == before, "unrelated resource ignored")
	state.counts.nameplate2 = nil
	watcher.callback(watcher, "COMBO_TARGET_CHANGED")
	fills(b, 0)
	for _, key in ipairs({ "isPRD", "isObjectPlate", "nameplateShowsWidgetsOnly" }) do
		b[key] = true; NP.UpdateComboPoints(b)
		check(not b.ForeverComboPoints.shown, "excluded plate " .. key)
		b[key] = nil
	end
	for _, entry in ipairs({ { "attack", false }, { "attack", secret(1) }, { "dead", true }, { "vehicle", true }, { "visible", false } }) do
		local old = state[entry[1]]
		state[entry[1]] = entry[2]; NP.UpdateComboPoints(b)
		check(not b.ForeverComboPoints.shown, "hidden context " .. entry[1])
		state[entry[1]] = old
	end
	if class == "DRUID" then
		state.power = 0; watcher.callback(watcher, "UPDATE_SHAPESHIFT_FORM")
		check(not b.ForeverComboPoints.shown, "Druid caster form hides")
		state.power = secret(3); NP.UpdateComboPoints(b)
		check(not b.ForeverComboPoints.shown, "unreadable form hides")
		state.power = 3; watcher.callback(watcher, "UNIT_DISPLAYPOWER", "player")
		fills(b, 0)
	end
	state.target = nil; watcher.callback(watcher, "PLAYER_TARGET_CHANGED")
	check(not b.ForeverComboPoints.shown, "missing count on untargeted mob hides")
	state.counts.nameplate1 = secret(3)
	watcher.callback(watcher, "COMBO_TARGET_CHANGED")
	fills(a, 3)
	check(a.ForeverComboPoints.VisibilityGate.value == 3, "points remain with no target selected")
	state.counts.nameplate1 = 0
	watcher.callback(watcher, "COMBO_TARGET_CHANGED")
	check(not a.ForeverComboPoints.shown, "readable zero releases row")
	check(a.Name.anchor[3] == 16 and a.Auras.anchor[3] == 56, "readable zero restores name and aura anchors")
	state.target = "nameplate2"; NP.UpdateComboPoints(b)
	NP.ClearComboPoints(b)
	check(not b.ForeverComboPoints.shown, "removed/recycled plate clears")
	ns.ActiveNamePlates[b] = nil; NP.UpdateComboPoints(b)
	check(not b.ForeverComboPoints.shown, "inactive plate stays hidden")
	ns.ActiveNamePlates[b] = true
	mod.db.profile.showComboPoints = false; NP.ConfigureComboPoints()
	check(not next(watcher.events) and not b.ForeverComboPoints.shown, "toggle off unregisters and hides")
	check(b.Name.anchor[3] == 16 and b.Auras.anchor[3] == 56, "toggle off releases reserved space immediately")
	local count = allocations
	mod.db.profile.showComboPoints = true; NP.ConfigureComboPoints()
	check(allocations == count, "toggle on reuses widgets")
	state.counts.nameplate1 = secret(3)
	NP.UpdateComboPoints(a)
	state.dead = true
	watcher.callback(watcher, "UNIT_HEALTH", "nameplate1")
	check(not a.ForeverComboPoints.shown and b.ForeverComboPoints.shown, "non-target death clears only its own plate")
	state.dead = false
	before = reads
	watcher.callback(watcher, "UNIT_HEALTH", "raid1")
	check(reads == before, "unrelated health events do no combo work")
	state.counts.nameplate1 = secret(2)
	b.unit = "nameplate1"
	NP.UpdateComboPoints(b)
	fills(b, 2)
	check(b.ForeverComboPoints.VisibilityGate.value == 2, "recycled frame asks its current unit rather than retaining previous count")
	state.counts.nameplate1 = nil
	NP.UpdateComboPoints(b)
	check(not b.ForeverComboPoints.shown, "unreadable recycled non-target clears without a cache")
	b.unit = "nameplate2"
	enabled = false; NP.ConfigureComboPoints()
	check(not next(watcher.events) and not b.ForeverComboPoints.shown, "module disable cleans up")
end
scenario("ROGUE", true)
scenario("DRUID", true)
scenario("MAGE", true)
scenario("ROGUE", false)
print("Nameplate combo points: " .. checks .. " checks passed")

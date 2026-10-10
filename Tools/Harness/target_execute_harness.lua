-- Real target module, real tier layouts and the nameplates' real threshold resolver.
-- Lua 5.1: lua Tools/Harness/target_execute_harness.lua . [mutation|--taint]
-- Opaque numeric stand-ins catch arithmetic/comparisons; they are not a WoW client.
-- Each mutation replaces one source fragment in memory and must fail on its own.
local root = arg[1] or "."
local mutation = arg[2]
local taint = mutation == "--taint"
if taint then mutation = nil end
local nativeSentinel = taint and { value = tonumber("23") } or nil
local checks, failures = 0, 0
local function check(value, label)
	checks = checks + 1
	if not value then failures = failures + 1; print("FAIL: "..label) end
end
local function near(actual, expected, label)
	check(type(actual) == "number" and math.abs(actual - expected) < .000001, label)
end
local function read(path)
	local f = assert(io.open(root.."/"..path, "rb"))
	local s = f:read("*a"):gsub("\n", "\n"); f:close()
	return s
end
local mutations = {
	["default-on"] = { "executeMarker = false,", "executeMarker = true," },
	["ignores-off"] = { "not profile.executeMarker or", "false or" },
	["friendly"] = { "not canAttack or isFriend", "not canAttack" },
	["non-attackable"] = { "not exists or not canAttack or isFriend", "not exists or isFriend" },
	["zero"] = { "threshold <= 0", "threshold < 0" },
	["wrong-tier"] = { 'root[self.currentStyle]', 'root.Seasoned' },
	["wrong-direction"] = { "reverse = reverse and true or false", "reverse = true" },
	["wrong-crop"] = { "reverse and threshold or 1", "reverse and (1 - threshold) or 1" },
	["wrong-line-slice"] = { "math.min(1, sample + half)", "1" },
	["ignores-scale"] = { "db.HealthBarSize[1] * scaleX", "db.HealthBarSize[1]" },
	["secret-math"] = { "marker.Zone:SetAlpha(alpha)", "marker.Zone:SetAlpha(alpha + 0)" },
	["wrong-step"] = { "curve:AddPoint(marker.threshold, 0)", "curve:AddPoint(marker.threshold, 1)" },
	["no-show"] = { "marker.Zone:Show()", "marker.Zone:Hide()" },
	["no-capability"] = { "or not TargetFrameMod.IsExecuteMarkerAvailable()", "or false" },
	["no-faction-event"] = { 'self.frame:RegisterEvent("UNIT_FACTION", UpdateTargetExecuteMarker)', "" },
	["no-class-callback"] = { "API.RegisterExecuteThresholdCallback(function() UpdateTargetExecuteMarker(self.frame) end)", "" },
	["no-health-update"] = { "UpdateTargetExecuteZone(element.__owner)", "" },
	["no-shared-notify"] = { 'if (target and target.UpdateExecuteMarker) then target:UpdateExecuteMarker() end', "" },
	["duplicate-setting"] = { "plates.db.profile.executeThreshold = value", "module.db.profile.executeThreshold = value" },
}
local applied = false
local sources = {}
local function source(path)
	if sources[path] then return sources[path] end
	local s = read(path)
	if mutation and not applied then
		local m = assert(mutations[mutation], "unknown mutation")
		local first, last = s:find(m[1], 1, true)
		if first then
			s = s:sub(1, first-1)..m[2]..s:sub(last+1)
			applied = true
		end
	end
	sources[path] = s
	return s
end

local function client(flavor)
	local world = { exists = true, attack = true, friend = false, percent = .6,
		class = "WARRIOR", curves = 0, textures = 0, percentCalls = 0, frames = 0, events = {} }
	local secrets = setmetatable({}, { __mode = "k" })
	local function forbidden() error("secret inspected") end
	local secretMT = { __add = forbidden, __sub = forbidden, __mul = forbidden, __div = forbidden,
		__lt = forbidden, __le = forbidden, __eq = forbidden, __concat = forbidden, __tostring = forbidden }
	local function secret(value)
		local s = setmetatable({}, secretMT); secrets[s] = value; return s
	end
	local function native(value) if type(value) == "table" then return secrets[value] end return value end
	local env = setmetatable({}, { __index = _G }); env._G = env
	env.type = function(value) if secrets[value] ~= nil then return "number" end return type(value) end
	env.issecretvalue = function(value) return secrets[value] ~= nil end
	env.UnitLevel = function() return flavor == "Forever" and 60 or 90 end
	env.UnitExists = function() return world.exists end
	env.UnitCanAttack = function() return world.attack end
	env.UnitIsFriend = function() return world.friend end
	env.UnitClassBase = function() return world.class end
	env.UnitClass = function() return "Warrior", world.class end
	env.PlayerUtil = { GetCurrentSpecID = function() return 71 end }
	env.Enum = { LuaCurveType = { Step = 1 } }
	env.C_CurveUtil = { CreateCurve = function()
		world.curves = world.curves + 1
		local c = { points = {} }
		function c:SetType(kind) self.kind = kind end
		function c:AddPoint(x, y)
			assert(type(x) == "number" and type(y) == "number", "curve has opaque point")
			self.points[#self.points+1] = { x, y }
		end
		return c
	end }
	env.UnitHealthPercent = function(unit, predicted, curve)
		world.percentCalls = world.percentCalls + 1
		assert(unit == "target" and predicted == false and curve.kind == 1)
		if world.percentError then error("restricted") end
		if world.percentMissing then return nil end
		local alpha = 0
		for _, point in ipairs(curve.points) do if world.percent >= point[1] then alpha = point[2] end end
		return secret(alpha)
	end
	local Region = {}
	Region.__index = Region
	function Region:CreateTexture(_, layer, _, sublevel)
		world.textures = world.textures + 1
		return setmetatable({ parent = self, layer = layer, sublevel = sublevel, shown = true }, Region)
	end
	function Region:SetTexture(path) self.texture = path end
	function Region:SetVertexColor(...) self.color = {...} end
	function Region:SetAlpha(value) self.alpha = native(value) end
	function Region:ClearAllPoints() self.points = {} end
	function Region:SetPoint(...) self.points[#self.points+1] = {...} end
	function Region:SetSize(w,h) assert(type(w) == "number" and type(h) == "number"); self.width,self.height = w,h end
	function Region:SetTexCoord(...) self.coords = {...} end
	function Region:Show() self.shown = true end
	function Region:Hide() self.shown = false end
	function Region:GetReverseFill() return world.reverse ~= false end
	function Region:RegisterEvent(name, fn) world.events[name] = fn end
	env.CreateFrame = function()
		world.frames = world.frames + 1
		local f = {}
		function f:RegisterEvent(name) self[name] = true end
		function f:SetScript(_, fn) self.onEvent = fn; world.classEvent = fn end
		return f
	end
	local modules, configs, variants, callbacks = {}, {}, {}, {}
	local ns = { IsForever = flavor == "Forever", API = {}, UnitFrameModule = {},
		MovableModulePrototype = { defaults = {} }, oUF = {} }
	ns.Colors = setmetatable({}, { __index = function(_, k) return { 1, 1, 1, 1 } end })
	function ns:NewModule(name) modules[name] = {}; return modules[name] end
	function ns:GetModule(name) return modules[name] end
	function ns:Merge(a) return a end
	function ns.GetConfig(name) return configs[name] end
	function ns.RegisterConfig(name, data) configs[name] = data end
	function ns.RegisterConfigVariant(name, _, data) variants[name] = data end
	ns.API.GetMedia = function(name) return "Assets/"..name..".tga" end
	ns.API.GetFont = function() return "font" end
	ns.API.TryCall = function(fn, ...) return pcall(fn, ...) end
	ns.API.IsSafeNumber = function(value) return env.type(value) == "number" and not env.issecretvalue(value) end
	ns.API.GetEffectiveScale = function() return 1 end
	ns.API.IsSpellKnownAnywhere = function() return true end
	local function load(path)
		local chunk = assert(loadstring(source(path), "@"..path))
		setfenv(chunk, env); chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end
	load("Components/UnitFrames/ExecuteRange.lua")
	load("Layouts/Data/TargetUnitFrame.lua")
	load("Components/UnitFrames/Units/Target.lua")
	local M = modules.TargetFrame
	M.db = { profile = M:GenerateDefaults().profile }
	M.db.profile.enabled = true
	M.UpdateSettings = function() M:UpdateExecuteMarker() end
	-- Run the real resolver in the nameplate settings (not a copied formula).
	local settings = read("Components/UnitFrames/NamePlates/Settings.lua")
	local resolver = assert(settings:match("(local EXECUTE_THRESHOLD_MAX = .-)\nlocal GetEffectivePlateScale"))
	local plates = { db = { profile = { enabled = false, executeMarker = false, executeThreshold = 0 } } }
	modules.NamePlates = plates
	local chunk = assert(loadstring("local ns, NamePlatesMod = ...\n"..resolver.."\nreturn GetNamePlateExecuteThreshold"))
	setfenv(chunk, env)
	ns.NamePlatesPrivate = { GetNamePlateExecuteThreshold = chunk(ns, plates) }
	-- Use the real shared settings notification without touching plate/CVar code.
	local moduleSource = source("Components/UnitFrames/NamePlates/Module.lua")
	local notify = assert(moduleSource:match("NamePlatesMod.UpdateSettings = function%(self%)(.-)\n	%-%- Check if"))
	local notifyChunk = assert(loadstring("local ns = ...\nreturn function(self)\n"..notify.."\nend"))
	setfenv(notifyChunk, env); plates.UpdateSettings = notifyChunk(ns)
	local health = setmetatable({}, Region)
	health.Overlay = setmetatable({}, Region)
	local frame = setmetatable({ unit = "target", currentStyle = "Novice", Health = health }, Region)
	health.__owner = frame
	M.frame = frame
	-- Real health callback, with unrelated old renderer/spark/prediction calls neutral.
	local targetSource = source("Components/UnitFrames/Units/Target.lua")
	local healthCallback = assert(targetSource:match("local Health_PostUpdate = function%(element, unit, cur, max%)(.-)\nend"))
	local healthChunk = assert(loadstring("local SyncTargetHealthVisualState, UpdateTargetBarSpark = function() end, function() end\n"
		.."local NormalizeTargetDisplayPercent = function(x) return x end\n"
		.."local UpdateTargetExecuteZone = ...\nreturn function(element, unit, cur, max)\n"..healthCallback.."\nend"))
	-- Reach the module's actual local function through its closure; no renderer copy.
	local zone
	for i=1,30 do
		local name, value = debug.getupvalue(M.UpdateExecuteMarker, i)
		if not name then break end
		if name == "UpdateTargetExecuteMarker" then
			for j=1,30 do
				local n,v = debug.getupvalue(value,j)
				if not n then break end
				if n == "UpdateTargetExecuteZone" then zone = v end
			end
		end
	end
	assert(zone, "real zone callback not reachable")
	setfenv(healthChunk, env); health.PostUpdate = healthChunk(zone)
	local function update()
		if taint then
			securecall(function()
				debug.setstacktaint("AzeriteUI5_JuNNeZ_Edition")
				assert(not issecure(), "addon marker call must be tainted")
				M:UpdateExecuteMarker()
			end)
		else M:UpdateExecuteMarker() end
	end
	return M, frame, world, plates, configs.TargetFrame, variants.SaiyaRatt, env, ns, update, secret
end

for _, flavor in ipairs({ "Retail", "Forever" }) do
	local M, f, W, plates, config, variant, env, ns, update, secret = client(flavor)
	check(M.db.profile.executeMarker == false, flavor..": default off")
	update()
	check(W.textures == 0 and W.curves == 0 and W.percentCalls == 0 and not f.ExecuteMarker, flavor..": off builds/reads nothing")
	M.db.profile.executeMarker = true
	W.friend, W.attack = true, true
	update()
	check(not f.ExecuteMarker, flavor..": friendly never built, even if attackable")
	W.friend, W.attack = false, false
	update()
	check(not f.ExecuteMarker, flavor..": non-attackable never built")
	W.attack = true
	W.class = "MAGE"; W.classEvent()
	update()
	check(not f.ExecuteMarker, flavor..": class without execute has zero, no textures")
	W.class = "WARRIOR"; W.classEvent()
	update()
	local marker = assert(f.ExecuteMarker, flavor..": marker not built")
	check(W.textures == 2 and marker.Line.parent == f.Health.Overlay and marker.Zone.parent == f.Health.Overlay, "only two textures on own overlay")
	check(marker.Line.layer == "ARTWORK" and marker.Line.sublevel == 1 and marker.Zone.sublevel == -1, "below text above fills")
	check(W.events.UNIT_FACTION ~= nil, "faction changes subscribed")
	local tables = { config, setmetatable({}, { __index = config }) }
	for key,value in pairs(variant) do tables[2][key] = value end
	for index,tierTable in ipairs(tables) do
		local oldConfig = config
		ns.GetConfig = function() return tierTable end
		for _, tier in ipairs({ "Novice", "Hardened", "Seasoned", "Boss", "Critter" }) do
			for _, reverse in ipairs({ true, false }) do
				f.currentStyle, W.reverse = tier, reverse
				for _, threshold in ipairs({ .05, .15, .2, .35, .5 }) do
					plates.db.profile.executeThreshold = threshold
					W.percent = threshold + .01
					update()
					local db = tierTable[tier]
					near(marker.Zone.width, db.HealthBarSize[1]*threshold, tier.." zone width")
					near(marker.Zone.height, db.HealthBarSize[2], tier.." height")
					check(marker.Zone.texture == db.HealthBarTexture and marker.Line.texture == db.HealthBarTexture, tier.." actual art")
					check(marker.Zone.coords[1] == (reverse and threshold or 1)
						and marker.Zone.coords[2] == (reverse and 0 or (1-threshold)), tier.." mirrored zone crop")
					local sample = reverse and threshold or (1-threshold)
					near(marker.Line.coords[1], math.min(1,sample+1/db.HealthBarSize[1]), tier.." line silhouette crop")
					near(marker.Line.coords[2], math.max(0,sample-1/db.HealthBarSize[1]), tier.." line silhouette end")
					check(marker.Zone.points[1][1] == (reverse and "TOPRIGHT" or "TOPLEFT"), "zone anchor follows fill")
					near(marker.Line.points[1][4], (reverse and -1 or 1)*db.HealthBarSize[1]*threshold, "line threshold position")
					check(marker.Zone.alpha == 0 and marker.Line.shown and marker.Zone.shown, "above threshold line only")
					W.percent = threshold; f.Health:PostUpdate("target")
					check(marker.Zone.alpha == 0, "at threshold no tint")
					W.percent = threshold - .001; f.Health:PostUpdate("target")
					check(marker.Zone.alpha == 1, "health callback tints below threshold")
				end
			end
		end
	end
	ns.GetConfig = function() return config end
	f.currentStyle, W.reverse = "Boss", true
	M.db.profile.bossHealthBarScaleX, M.db.profile.bossHealthBarScaleY = 150, 80
	update()
	near(marker.Zone.width, 533*.5*1.5, "boss scale X")
	near(marker.Zone.height, 40*.8, "boss scale Y")
	f.currentStyle = "Critter"
	M.db.profile.critterHealthBarScaleX, M.db.profile.critterHealthBarScaleY = 80, 150
	update()
	near(marker.Zone.width, 40*.5*.8, "critter scale X")
	near(marker.Zone.height, 36*1.5, "critter scale Y")
	f.currentStyle = "Novice"
	M.db.profile.healthBarScaleX, M.db.profile.healthBarScaleY = 125, 125
	update()
	near(marker.Zone.width, 385*.5*1.25, "normal scale")
	M.db.profile.healthBarScaleX, M.db.profile.healthBarScaleY = 0, -20
	update()
	near(marker.Zone.width, 385*.5, "invalid scale follows existing fallback")
	W.percentError = true; update()
	check(marker.Zone.alpha == 0, "failed health query clears stale tint"); W.percentError = false
	W.percentMissing = true; update()
	check(marker.Zone.alpha == 0, "missing health query clears stale tint"); W.percentMissing = false
	W.friend = true; W.events.UNIT_FACTION(f, "UNIT_FACTION", "target")
	check(not marker.Line.shown and not marker.Zone.shown, "faction event hides recycled friendly target")
	W.friend = false; update()
	local textureCount = W.textures
	for i=1,3 do
		M.db.profile.executeMarker = false; update()
		check(not marker.Line.shown and not marker.Zone.shown, "off hides both")
		M.db.profile.executeMarker = true; update()
		check(marker.Line.shown and marker.Zone.shown and W.textures == textureCount, "on reuses textures")
	end
	W.exists = false; update()
	check(not marker.isShown, "no target hides")
	W.exists = true; W.attack = secret(1); update()
	check(not marker.isShown, "secret eligibility is never boolean-tested")
	W.attack = true; update()
	plates.db.profile.executeThreshold = 0; W.class = "MAGE"; W.classEvent()
	check(not marker.isShown, "automatic callback zero threshold hides existing marker")
	W.class = "WARRIOR"; W.classEvent()
	check(marker.isShown and marker.threshold == .2, "automatic callback restores marker")
	plates.db.profile.executeThreshold = .35; plates:UpdateSettings()
	check(marker.threshold == .35, "nameplate settings immediately update target even with plates off")
	M.db.profile.enabled = false; update()
	check(not marker.isShown, "target module off hides"); M.db.profile.enabled = true
	env.C_CurveUtil = false; update()
	check(not marker.isShown and not M:IsExecuteMarkerAvailable(), "missing APIs disable existing marker")
	env.UnitHealthPercent = false; update()
	check(not M:IsExecuteMarkerAvailable(), "missing percent API disables")
	check(W.frames == 1, "marker never creates a frame (only existing threshold listener)")
	if taint then check(issecurevariable(nativeSentinel, "value"), "Elune unrelated native field remains secure") end
end

-- Real options, via the same setup used by the shipped panel harness.
local savedArg = arg
arg = { root }
local S = dofile(root.."/Tools/Harness/stubs.lua")
arg = savedArg
local parentModule = S.ns:NewModule("UnitFrames")
parentModule.db = { profile = { enabled = true } }
local factory
S.ns:NewModule("Options").AddGroup = function(_, _, fn) factory = fn end
S.ns:GetModule("Options").GenerateHealthPredictionOptions = function() return {} end
local target = S.ns:NewModule("TargetFrame")
target.db = { profile = { enabled = true } }
target.IsExecuteMarkerAvailable = function() return true end
local plates = S.ns:NewModule("NamePlates")
plates.db = { profile = { enabled = false, executeMarker = false } }
plates.db.profile.executeThreshold = 0
S.ns.API.GetExecuteThreshold = function() return .2 end
local count = 0
plates.UpdateSettings = function() count = count + 1 end
local chunk = assert(loadstring(source("Options/OptionsPages/UnitFrames.lua")))
chunk(S.Addon, S.ns)
local options = factory()
local range = options.args.target.args.executeRange
local args = range.args.sharedThreshold.args
target.db.profile.executeMarker = true
check(not range.args.executeMarker.disabled(), "target toggle available")
check(not args.executeThresholdMode.disabled({"executeThresholdMode"}), "threshold usable while nameplate marker off")
args.executeThresholdMode.set({}, "custom")
check(plates.db.profile.executeThreshold == .2 and target.db.profile.executeThreshold == nil, "mode writes shared setting only")
args.executeThreshold.set({}, .35)
check(plates.db.profile.executeThreshold == .35 and count == 2, "slider writes shared setting and notifies")
args.executeThresholdMode.set({}, "auto")
check(plates.db.profile.executeThreshold == 0, "Automatic restores shared zero")
target.IsExecuteMarkerAvailable = function() return false end
check(range.args.executeMarker.disabled() and not range.args.unavailable.hidden(), "missing client API explanation shown")
check(range.args.sharedThreshold.hidden(), "missing API hides shared controls")

assert(not mutation or applied, "mutation did not apply: "..tostring(mutation))
print(("target execute harness: %d checks, %d failures%s"):format(checks, failures, taint and " (Elune tainted addon calls)" or ""))
if failures > 0 then error("target execute harness failed") end

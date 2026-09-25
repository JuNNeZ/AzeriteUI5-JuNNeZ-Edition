-- Compare tooltips (Components/Misc/Tooltips.lua), on Retail and on Forever alike.
-- Our backdrop hangs outside every tooltip (Azerite 10px at the sides and 18px on top, Classic 6px),
-- while Blizzard sets compare tooltips edge to edge and tucks their "Equipped" tab 1px behind the
-- tooltip's own top edge. So the module widens the joins Blizzard has just made, inside
-- TooltipComparisonManager:AnchorShoppingTooltips, and tucks the tab behind our border instead.
-- This loads the real module, its layout data and Core/API/ProtectedCall.lua, with Blizzard's
-- Initialize and AnchorShoppingTooltips copied verbatim from
-- Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua (identical in live 12.1.0 and forever
-- 1.60.1), against frames that resolve their anchors to screen rectangles.
-- No rendering, taint or restricted-environment checks. Stock Lua 5.1 cannot make `==`, a boolean
-- test or a table index raise on a secret, so a missing guard shows only where a secret reaches
-- arithmetic or goes back into SetPoint: the secret scale case and the "offsets" secret-anchoring case.
-- Secret anchoring is what the live client showed (FixLog 2026-09-25, tooltip audit): the join is
-- found by counting GetPointByName's answers and made to the frame Blizzard's code joins it to.
-- The rest of the tooltip audit rides along, against the same loaded module: the native aura
-- containers' AuraButtonTooltip styled through AuraContainerInbound (checked against the documented
-- AuraContainerTooltipBackdropOptions), aura spell IDs without UnitAura (Classic-only), the unit name
-- line written to the tooltip it belongs to, and secret health leaving no stale numbers.
-- lua Tools/Harness/tooltip_compare_harness.lua .
-- lua Tools/Harness/tooltip_compare_harness.lua . <path to a mutated Tooltips.lua>
-- Mutations: the "tooltip" entries in mutate_client.lua.
local root = arg[1] or "."
local path = arg[2] or (root .. "/Components/Misc/Tooltips.lua")
local checks, failures = 0, 0
local function check(value, label, detail)
	checks = checks + 1
	if (not value) then
		failures = failures + 1
		print("FAIL: " .. label .. ((detail ~= nil) and (" (" .. tostring(detail) .. ")") or ""))
	end
end

-- Secret stand-ins, as the nameplate harness makes them: SECRET for anything, and a secret number
-- whose arithmetic and ordering raise.
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local SecretNumber = {}
local function RaiseSecret() error("attempt to use a secret number in addon code", 2) end
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__lt", "__le", "__concat" }) do
	SecretNumber[event] = RaiseSecret
end
local function SecretValue(value) return setmetatable({ value = value }, SecretNumber) end
local function IsSecret(value) return value == SECRET or getmetatable(value) == SecretNumber end

local SCREEN_W, SCREEN_H = 1920, 1080
local BACKDROP_TEMPLATE = "BackdropTemplate"

-- Rows below the backdrop's top where each theme's top edge is solid, measured from the art:
-- Azerite Assets/border-tooltip.tga (512x64, drawn at edgeSize 32); Classic from GW2_UI's rescaled
-- copy of Interface/Tooltips/UI-Tooltip-Border, drawn at edgeSize 16. The tab's bottom edge must
-- land in that band: above it the tab floats, below it the tab is buried.
local BorderBand = { Azerite = { 12, 18 }, Classic = { 2, 2 } }

-- What the stubs read and record. Replaced by every Load.
local world

-- Which edge of a frame each anchor point names.
local H = { LEFT = "L", TOPLEFT = "L", BOTTOMLEFT = "L", RIGHT = "R", TOPRIGHT = "R", BOTTOMRIGHT = "R", TOP = "C", BOTTOM = "C", CENTER = "C" }
local V = { TOP = "T", TOPLEFT = "T", TOPRIGHT = "T", BOTTOM = "B", BOTTOMLEFT = "B", BOTTOMRIGHT = "B", LEFT = "M", RIGHT = "M", CENTER = "M" }

local Frame = {}
Frame.__index = Frame

local function NewFrame(name, parent)
	return setmetatable({
		name = name, parent = parent, scale = 1, width = 0, height = 0, shown = true,
		points = {}, level = parent and (parent.level + 1) or 1, scripts = {}
	}, Frame)
end

function Frame:GetName() return self.name end
function Frame:IsForbidden() return false end
function Frame:IsShown() return self.shown end
function Frame:Show()
	if (self.shown) then return end
	self.shown = true
	for _, fn in ipairs(self.scripts.OnShow or {}) do fn(self) end
end
function Frame:Hide() self.shown = false end
function Frame:SetShown(shown) if (shown) then self:Show() else self:Hide() end end
function Frame:HookScript(script, fn)
	self.scripts[script] = self.scripts[script] or {}
	table.insert(self.scripts[script], fn)
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:EnableDrawLayer() end
function Frame:DisableDrawLayer() end
function Frame:EnableMouse() end
function Frame:SetMouseClickEnabled() end
function Frame:SetMouseMotionEnabled() end
function Frame:SetBackdrop(backdrop) self.backdrop = backdrop end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:SetOwner(owner, anchorType) self.owner, self.anchorType = owner, anchorType end
function Frame:GetAnchorType() return self.anchorType end
function Frame:SetAnchorType() world.slides = world.slides + 1 end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetScale() return self.scale end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:Scale() return self.scale * (self.parent and self.parent:Scale() or 1) end
function Frame:GetEffectiveScale()
	if (self.secretScale) then return SecretValue(self:Scale()) end
	return self:Scale()
end

function Frame:SetPoint(point, a, b, c, d)
	local relativeTo, relativePoint, x, y
	if (a == nil or type(a) == "number") then
		relativeTo, relativePoint, x, y = self.parent, point, a, b
	elseif (b == nil or type(b) == "number") then
		relativeTo, relativePoint, x, y = a, point, b, c
	else
		relativeTo, relativePoint, x, y = a, b, c, d
	end
	-- SetPoint takes secrets only from untainted code, and the module is addon code.
	for _, value in pairs({ point, relativeTo, relativePoint, x, y }) do
		if (IsSecret(value)) then error("secret argument to SetPoint from addon code", 2) end
	end
	local anchor = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x or 0, y = y or 0 }
	for i, existing in ipairs(self.points) do
		if (existing.point == point) then
			self.points[i] = anchor
			return
		end
	end
	table.insert(self.points, anchor)
end
function Frame:ClearAllPoints() self.points = {} end
function Frame:GetNumPoints() return #self.points end
-- SecretWhenAnchoringSecret (SimpleScriptRegionResizingAPIDocumentation.lua). "offsets" keeps the
-- names readable so code without a guard gets as far as handing a secret back to SetPoint.
local function AnswerPoint(frame, anchor)
	if (frame.secretAnchoring == "all") then return SECRET, SECRET, SECRET, SECRET, SECRET end
	if (frame.secretAnchoring == "offsets") then
		return anchor.point, anchor.relativeTo, anchor.relativePoint, SecretValue(anchor.x), SecretValue(anchor.y)
	end
	return anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y
end
function Frame:GetPoint(index)
	local anchor = self.points[index]
	if (not anchor) then return end
	return AnswerPoint(self, anchor)
end
-- MayReturnNothing: no answers at all for a point the frame does not have, secret or not.
function Frame:GetPointByName(point)
	for _, anchor in ipairs(self.points) do
		if (anchor.point == point) then return AnswerPoint(self, anchor) end
	end
end

-- Screen rectangle in pixels: left, right, top, bottom. An edge named by a point wins; a centre
-- point only places a frame on an axis no edge point covers.
function Frame:Rect()
	local scale = self:Scale()
	local w, h = self.width * scale, self.height * scale
	if (self.fixed) then
		return self.fixed[1], self.fixed[1] + w, self.fixed[2], self.fixed[2] - h
	end
	local left, right, center, top, bottom, middle
	for _, anchor in ipairs(self.points) do
		local l, r, t, b = anchor.relativeTo:Rect()
		local hr, vr = H[anchor.relativePoint], V[anchor.relativePoint]
		local x = ((hr == "L" and l) or (hr == "R" and r) or (l + r) / 2) + anchor.x * scale
		local y = ((vr == "T" and t) or (vr == "B" and b) or (t + b) / 2) + anchor.y * scale
		local hp, vp = H[anchor.point], V[anchor.point]
		if (hp == "L") then left = x elseif (hp == "R") then right = x else center = x end
		if (vp == "T") then top = y elseif (vp == "B") then bottom = y else middle = y end
	end
	left = left or (right and right - w) or (center - w / 2)
	right = right or (left + w)
	top = top or (bottom and bottom + h) or (middle + h / 2)
	bottom = bottom or (top - h)
	return left, right, top, bottom
end
function Frame:GetLeft() return (self:Rect()) / self:Scale() end
function Frame:GetRight() return select(2, self:Rect()) / self:Scale() end

local function GetScreenWidth() return SCREEN_W end

-- Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua, verbatim.
local TooltipComparisonManager = {}

function TooltipComparisonManager:Initialize(tooltip, anchorFrame)
	self.tooltip = tooltip;
	self.anchorFrame = anchorFrame or self.tooltip;
	for i, shoppingTooltip in ipairs(self.tooltip.shoppingTooltips) do
		shoppingTooltip:SetOwner(self.tooltip, "ANCHOR_NONE", 0, 0);
		shoppingTooltip:ClearAllPoints();
	end
end

function TooltipComparisonManager:AnchorShoppingTooltips(primaryShown, secondaryShown)
	local tooltip = self.tooltip;
	local primaryTooltip = tooltip.shoppingTooltips[1];
	local secondaryTooltip = tooltip.shoppingTooltips[2];

	primaryTooltip:SetShown(primaryShown);
	secondaryTooltip:SetShown(secondaryShown);

	local sideAnchorFrame = self.anchorFrame;
	if self.anchorFrame.IsEmbedded then
		sideAnchorFrame = self.anchorFrame:GetParent():GetParent();
	end

	local leftPos = sideAnchorFrame:GetLeft();
	local rightPos = sideAnchorFrame:GetRight();

	local selfLeftPos = tooltip:GetLeft();
	local selfRightPos = tooltip:GetRight();

	-- if we get the Left, we have the Right
	if leftPos and selfLeftPos then
		leftPos = math.min(selfLeftPos, leftPos);-- get the left most bound
		rightPos = math.max(selfRightPos, rightPos);-- get the right most bound
	else
		leftPos = leftPos or selfLeftPos or 0;
		rightPos = rightPos or selfRightPos or 0;
	end

	-- sometimes the sideAnchorFrame is an actual tooltip, and sometimes it's a script region, so make sure we're getting the actual anchor type
	local anchorType = sideAnchorFrame.GetAnchorType and sideAnchorFrame:GetAnchorType() or tooltip:GetAnchorType();

	local totalWidth = 0;
	if primaryShown then
		totalWidth = totalWidth + primaryTooltip:GetWidth();
	end
	if secondaryShown then
		totalWidth = totalWidth + secondaryTooltip:GetWidth();
	end

	local rightDist = 0;
	local screenWidth = GetScreenWidth();
	rightDist = screenWidth - rightPos;

	-- find correct side
	local side;
	if anchorType and (totalWidth < leftPos) and (anchorType == "ANCHOR_LEFT" or anchorType == "ANCHOR_TOPLEFT" or anchorType == "ANCHOR_BOTTOMLEFT") then
		side = "left";
	elseif anchorType and (totalWidth < rightDist) and (anchorType == "ANCHOR_RIGHT" or anchorType == "ANCHOR_TOPRIGHT" or anchorType == "ANCHOR_BOTTOMRIGHT") then
		side = "right";
	elseif rightDist < leftPos then
		side = "left";
	else
		side = "right";
	end

	-- see if we should slide the tooltip
	if totalWidth > 0 and (anchorType and anchorType ~= "ANCHOR_PRESERVE") then --we never slide a tooltip with a preserved anchor
		local slideAmount = 0;
		if ( (side == "left") and (totalWidth > leftPos) ) then
			slideAmount = totalWidth - leftPos;
		elseif ( (side == "right") and (rightPos + totalWidth) >  screenWidth ) then
			slideAmount = screenWidth - (rightPos + totalWidth);
		end

		if slideAmount ~= 0 then -- if we calculated a slideAmount, we need to slide
			if sideAnchorFrame.SetAnchorType then
				sideAnchorFrame:SetAnchorType(anchorType, slideAmount, 0);
			else
				tooltip:SetAnchorType(anchorType, slideAmount, 0);
			end
		end
	end

	if secondaryShown then
		primaryTooltip:SetPoint("TOP", self.anchorFrame, 0, 0);
		secondaryTooltip:SetPoint("TOP", self.anchorFrame, 0, 0);
		if side and side == "left" then
			primaryTooltip:SetPoint("RIGHT", sideAnchorFrame, "LEFT");
		else
			secondaryTooltip:SetPoint("LEFT", sideAnchorFrame, "RIGHT");
		end

		if side and side == "left" then
			secondaryTooltip:SetPoint("TOPRIGHT", primaryTooltip, "TOPLEFT");
		else
			primaryTooltip:SetPoint("TOPLEFT", secondaryTooltip, "TOPRIGHT");
		end
	else
		primaryTooltip:SetPoint("TOP", self.anchorFrame, 0, 0);
		if side and side == "left" then
			primaryTooltip:SetPoint("RIGHT", sideAnchorFrame, "LEFT");
		else
			primaryTooltip:SetPoint("LEFT", sideAnchorFrame, "RIGHT");
		end
	end
end
-- End of the copy.

-- AceHook-3.0 as the module uses it: a secure hook runs the handler after the original, as
-- self[handler](self, ...); Unhook leaves the wrapper in place but inactive.
local function NewModule()
	local module = { hooks = {} }
	local function Key(a, b)
		if (type(a) == "string") then return world.env, a end
		return a, b
	end
	function module:IsHooked(a, b)
		local object, method = Key(a, b)
		return (self.hooks[object] and self.hooks[object][method]) and true or false
	end
	function module:SecureHook(a, b, c)
		local object, method = Key(a, b)
		local handler = (type(a) == "string") and b or c
		local entry = { active = true }
		self.hooks[object] = self.hooks[object] or {}
		self.hooks[object][method] = entry
		local original = object[method]
		if (type(original) ~= "function") then return end
		object[method] = function(...)
			original(...)
			if (entry.active) then self[handler](self, ...) end
		end
	end
	function module:SecureHookScript(object, script)
		self.hooks[object] = self.hooks[object] or {}
		self.hooks[object][script] = { active = true }
	end
	-- LibMoreEvents, as far as UpdateTooltipThemes' PLAYER_ENTERING_WORLD call uses it.
	function module:UnregisterEvent() end
	function module:Unhook(a, b)
		local object, method = Key(a, b)
		local entry = self.hooks[object] and self.hooks[object][method]
		if (entry) then
			entry.active = false
			self.hooks[object][method] = nil
		end
	end
	return module
end

local function NewFontString()
	return {
		shown = true,
		SetPoint = function() end, SetFontObject = function() end, SetTextColor = function() end,
		SetText = function(self, text) self.text = text end, GetText = function(self) return self.text end,
		GetTextColor = function() return 1, 1, 1 end,
		Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown end
	}
end

-- AuraContainerInbound.SetTooltipBackdrop's argument, AuraContainerTooltipBackdropOptions in
-- AuraContainerUtilDocumentation.lua (identical on Retail 12.1.0 and Forever 1.60.1), and the
-- bgFile-or-edgeFile rule AuraContainerUtil.SetTooltipBackdrop raises on.
local BackdropOptionFields = { backdropInfo = "table", borderColor = "table", centerColor = "table", anchorOffsets = "table" }
local BackdropInfoFields = { bgFile = "string", edgeFile = "string", edgeSize = "number", insets = "table", tile = "boolean", tileEdge = "boolean", tileSize = "number" }
local EdgeFields = { left = true, right = true, top = true, bottom = true }
local function ValidateBackdropOptions(options)
	assert(type(options) == "table", "options must be a table")
	for key, value in pairs(options) do
		assert(BackdropOptionFields[key] == type(value), "unexpected option " .. tostring(key))
	end
	local info = assert(options.backdropInfo, "backdropInfo is not nilable")
	for key, value in pairs(info) do
		assert(BackdropInfoFields[key] == type(value), "unexpected backdropInfo field " .. tostring(key))
	end
	assert(info.bgFile or info.edgeFile, "expected a non-nil value for either bgFile or edgeFile")
	for _, edges in ipairs({ info.insets or {}, options.anchorOffsets or {} }) do
		for key, value in pairs(edges) do
			assert(EdgeFields[key] and type(value) == "number", "bad edge " .. tostring(key))
		end
	end
	for _, color in ipairs({ options.borderColor or { r = 0, g = 0, b = 0, a = 0 }, options.centerColor or { r = 0, g = 0, b = 0, a = 0 } }) do
		for _, key in ipairs({ "r", "g", "b", "a" }) do
			assert(type(color[key]) == "number", "colour without " .. key)
		end
	end
end

local function Load(options)
	local env = {}
	world = {
		env = env, errors = {}, slides = 0, modifier = true, printed = {},
		auraStyles = {}, auraResets = 0, auraFilters = {}, health = {}, names = {}, units = {},
		timers = {}, modules = {}, secondCopy = true
	}

	local UIParent = NewFrame("UIParent")
	UIParent.fixed, UIParent.width, UIParent.height = { 0, SCREEN_H }, SCREEN_W, SCREEN_H
	local UIHider = NewFrame(nil, UIParent)
	UIHider.shown = false

	-- AzeriteUI anchors GameTooltip ANCHOR_NONE at a saved point; Blizzard picks the side with room.
	local GameTooltip = NewFrame("GameTooltip", UIParent)
	GameTooltip.width, GameTooltip.height, GameTooltip.scale = 300, 200, options.mainScale or 1
	GameTooltip.anchorType = "ANCHOR_NONE"
	GameTooltip.NineSlice = NewFrame(nil, GameTooltip)
	local mainWidth = GameTooltip.width * GameTooltip:Scale()
	GameTooltip.fixed = { (options.side == "left") and (SCREEN_W - 40 - mainWidth) or 40, 700 }
	-- What the aura ID and unit hooks touch. Setters are Blizzard's no-ops the module hooks.
	GameTooltip.lines = {}
	GameTooltip.TextLeft1 = NewFontString()
	function GameTooltip:AddLine(text) table.insert(self.lines, text) end
	function GameTooltip:AddDoubleLine(left, right) table.insert(self.lines, left .. " || " .. right) end
	function GameTooltip:NumLines() return 0 end
	function GameTooltip:GetUnit() return nil, world.tooltipUnit end
	for _, method in ipairs({ "SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetUnitBuffByAuraInstanceID",
		"SetUnitDebuffByAuraInstanceID", "SetUnitAuraByAuraInstanceID" }) do
		GameTooltip[method] = function() end
	end
	local bar = NewFrame(nil, GameTooltip)
	function bar:SetStatusBarTexture() end
	function bar:SetHeight() end
	function bar:SetStatusBarColor() end
	bar.fontStrings = {}
	function bar:CreateFontString()
		local fontString = NewFontString()
		table.insert(self.fontStrings, fontString)
		return fontString
	end
	GameTooltip.StatusBar = bar

	local compareTooltips = {}
	for i = 1, 2 do
		-- Never laid out: no width until its first comparison fills it.
		local tooltip = NewFrame("ShoppingTooltip" .. i, UIParent)
		tooltip.shown, tooltip.height, tooltip.contentWidth = false, 150, 240 + i * 10
		tooltip.NineSlice = NewFrame(nil, tooltip)
		-- ShoppingTooltipTemplate, Blizzard_GameTooltip/Mainline/GameTooltip.xml:111.
		local header = NewFrame(nil, tooltip)
		header.width, header.height, header.level = 100, 22, 1
		header:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, -1)
		tooltip.CompareHeader = header
		compareTooltips[i] = tooltip
	end
	GameTooltip.shoppingTooltips = compareTooltips

	local manager = {
		Initialize = TooltipComparisonManager.Initialize,
		AnchorShoppingTooltips = TooltipComparisonManager.AnchorShoppingTooltips
	}

	local function hooksecurefunc(object, method, hook)
		if (type(object) == "string") then object, method, hook = env, object, method end
		local original = object[method]
		object[method] = function(...)
			original(...)
			hook(...)
		end
	end

	local function CreateFrame(_, name, parent, template)
		local frame = NewFrame(name, parent)
		if (template == BACKDROP_TEMPLATE and parent) then parent.__backdrop = frame end
		return frame
	end

	-- Blizzard_AuraContainerInbound.lua; absent until Blizzard_AuraContainer loads.
	local inbound = {
		SetTooltipBackdrop = function(styleOptions)
			if (world.refuseAuraStyle) then
				world.refuseAuraStyle = nil
				error("refused by the client")
			end
			ValidateBackdropOptions(styleOptions)
			table.insert(world.auraStyles, styleOptions)
		end,
		ResetTooltipStyle = function() world.auraResets = world.auraResets + 1 end
	}
	world.inbound = inbound

	for key, value in pairs({
		_G = env, UIParent = UIParent, GameTooltip = GameTooltip, GameTooltipTextLeft1 = GameTooltip.TextLeft1,
		ShoppingTooltip1 = compareTooltips[1], ShoppingTooltip2 = compareTooltips[2],
		TooltipComparisonManager = manager,
		AuraContainerInbound = (not options.lateAuraContainer) and inbound or nil,
		CreateFrame = CreateFrame, hooksecurefunc = hooksecurefunc, issecretvalue = IsSecret,
		CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end,
		GetTime = function() return 0 end,
		C_Timer = { After = function(_, callback) table.insert(world.timers, callback) end },
		IsModifiedClick = function() return world.modifier end,
		geterrorhandler = function() return function(message) table.insert(world.errors, message) end end,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
			table.insert(world.printed, table.concat(parts, " "))
		end,
		-- Hooked by the module; Blizzard's bodies do nothing the harness measures.
		SharedTooltip_SetBackdropStyle = function() end,
		GameTooltip_UnitColor = function() end,
		GameTooltip_ShowCompareItem = function() end,
		GameTooltip_SetDefaultAnchor = function() end,
		LibStub = function() return { GetLocale = function() return {} end } end,
		-- Aura spell IDs. UnitAura is deliberately absent: Retail and Forever do not have it.
		C_UnitAuras = {
			GetAuraDataByIndex = function(unit, index, filter)
				table.insert(world.auraFilters, tostring(filter))
				return world.auraData
			end,
			GetAuraDataByAuraInstanceID = function() return world.auraData end
		},
		C_Secrets = {
			ShouldUnitAuraIndexBeSecret = function() return world.secretAura end,
			ShouldUnitAuraInstanceBeSecret = function() return world.secretAura end,
			ShouldUnitIdentityBeSecret = function() return false end
		},
		UnitClass = function() return "Druid", "DRUID" end,
		UnitName = function(unit) return world.names[unit] end,
		UnitExists = function(unit) return world.units[unit] and true or false end,
		UnitIsPlayer = function() return false end,
		UnitIsDeadOrGhost = function() return false end,
		UnitHealth = function(unit) return world.health[unit] and world.health[unit][1] end,
		UnitHealthMax = function(unit) return world.health[unit] and world.health[unit][2] end,
		UNKNOWN = "Unknown"
	}) do
		env[key] = value
	end
	setmetatable(env, { __index = _G })

	local configs = {}
	local module = NewModule()
	local ns = {
		API = {
			GetFont = function() end, GetMedia = function(name) return name end,
			GetUnitColor = function() return { colorCode = "|cff00ff00" } end,
			AbbreviateNumber = tostring, AbbreviateNumberBalanced = tostring
		},
		Colors = {
			offwhite = { 1, 1, 1 }, quest = { gray = { colorCode = "" } },
			class = { DRUID = { colorCode = "|cffff7c0a" }, PRIEST = { colorCode = "|cffffffff" } }
		},
		Hider = UIHider,
		BackdropTemplate = BACKDROP_TEMPLATE,
		MovableModulePrototype = { defaults = {} },
		RegisterConfig = function(name, config) configs[name] = config end,
		GetConfig = function(name) return configs[name] end,
		Merge = function(_, a) return a end,
		NewModule = function() return module end,
		GetModule = function(_, name) return world.modules[name] end,
		-- Retail and Forever alike: both are the mainline family.
		WoW10 = true
	}

	for _, file in ipairs({ root .. "/Core/API/ProtectedCall.lua", root .. "/Layouts/Data/Tooltips.lua", path }) do
		local chunk = assert(loadfile(file))
		setfenv(chunk, env)
		chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end

	module.db = { profile = {
		theme = options.theme, disableAzeriteUITooltips = options.disabled or false,
		nameplateUnitTransparency = false, showItemID = false, showSpellID = options.showSpellID or false, anchor = true,
		anchorToCursor = false, savedPosition = { scale = options.anchorScale or 1, "BOTTOMRIGHT", -300, 200 },
		hideInCombat = options.hideInCombat or false, hideActionBarTooltipsInCombat = true, hideUnitFrameTooltipsInCombat = true
	} }
	if (options.withActionBars) then
		world.actionBarRefreshes = 0
		world.modules.ActionBars = {
			IsEnabled = function() return true end,
			UpdateSettings = function() world.actionBarRefreshes = world.actionBarRefreshes + 1 end
		}
	end
	module:UpdateSettings()
	return module, env, configs.Tooltips.themes[options.theme].backdropStyle, configs.Tooltips.themes
end

-- TooltipComparisonManager:CompareItem -> RefreshItems: Initialize, then SetItemTooltip for each
-- tooltip it fills (ClearLines -> OnTooltipCleared -> GameTooltip_ClearStyle ->
-- SharedTooltip_SetBackdropStyle, then the lines), then AnchorShoppingTooltips. CycleItem skips
-- Initialize.
-- Then the same anchoring again, through the frames' own SetPoint but past any hook on the global
-- manager table. The live client drew compare tooltips edge to edge after a hook on the manager
-- had set their offsets (Retail and Forever, FixLog 2026-09-25): something anchors them after
-- that hook. A second copy of the manager, as Blizzard's secure environment could load one, is
-- the model; with it, the 5.10.1 design and the audit's first cut fail here as they did live.
local function Compare(env, secondary, cycle, mainTooltip)
	local manager = env.TooltipComparisonManager
	if (not cycle) then manager:Initialize(mainTooltip or env.GameTooltip) end
	for i, tooltip in ipairs(env.GameTooltip.shoppingTooltips) do
		if (i == 1 or secondary) then
			env.SharedTooltip_SetBackdropStyle(tooltip, nil)
			tooltip.width = tooltip.contentWidth
		end
	end
	manager:AnchorShoppingTooltips(true, secondary and true or false)
	if (world.secondCopy) then
		TooltipComparisonManager.AnchorShoppingTooltips(manager, true, secondary and true or false)
	end
end

local function RunTimers()
	local timers = world.timers
	world.timers = {}
	for _, callback in ipairs(timers) do callback() end
end

local function BackdropRect(frame)
	local backdrop = frame.__backdrop
	if (backdrop and backdrop.shown) then return backdrop:Rect() end
	return frame:Rect()
end

-- Space between what is drawn for two frames side by side: negative is an overlap.
local function Seam(leftFrame, rightFrame)
	local _, right = BackdropRect(leftFrame)
	local left = BackdropRect(rightFrame)
	return left - right
end

local function Near(a, b) return math.abs(a - b) < 1e-6 end

-- The joins Blizzard makes, left to right on screen.
local function Row(env, side, secondary)
	local main, primary, secondaryTooltip = env.GameTooltip, env.ShoppingTooltip1, env.ShoppingTooltip2
	if (side == "right") then
		return secondary and { main, secondaryTooltip, primary } or { main, primary }
	end
	return secondary and { secondaryTooltip, primary, main } or { primary, main }
end

local function CheckRow(env, side, secondary, label)
	local row = Row(env, side, secondary)
	for i = 1, #row - 1 do
		local seam = Seam(row[i], row[i + 1])
		check(Near(seam, 0), label .. ": " .. row[i].name .. " and " .. row[i + 1].name .. " borders meet without overlapping", seam)
	end
	local _, _, mainTop = env.GameTooltip:Rect()
	local _, _, compareTop = env.ShoppingTooltip1:Rect()
	check(Near(mainTop, compareTop), label .. ": tops still aligned as Blizzard set them", compareTop - mainTop)
	check(world.slides == 0, label .. ": the case has room, nothing slid", world.slides)
end

-- The horizontal join Blizzard made on a compare tooltip, and its offset.
local function JoinOffset(tooltip)
	for _, anchor in ipairs(tooltip.points) do
		if (anchor.point ~= "TOP") then return anchor.x end
	end
end

local function HeaderOffset(tooltip)
	local _, _, top = tooltip:Rect()
	local _, _, _, bottom = tooltip.CompareHeader:Rect()
	return (bottom - top) / tooltip:Scale()
end

local function CheckHeader(theme, tooltip, style, label)
	check(Near(HeaderOffset(tooltip), style.compareHeaderOffsetY), label .. ": the Equipped tab sits at the theme's height", HeaderOffset(tooltip))
	local tucked = label .. ": the tab's bottom edge is tucked behind the border's solid edge"
	if (not tooltip.__backdrop) then
		check(false, tucked, "no backdrop")
		return
	end
	local _, _, backdropTop = tooltip.__backdrop:Rect()
	local _, _, _, bottom = tooltip.CompareHeader:Rect()
	local band = BorderBand[theme]
	local scale = tooltip:Scale()
	check(bottom <= backdropTop - band[1] * scale and bottom >= backdropTop - (band[2] + 1) * scale, tucked, backdropTop - bottom)
end

local function PointOffset(tooltip, name)
	for _, anchor in ipairs(tooltip.points) do
		if (anchor.point == name) then return anchor.x end
	end
end

-- The /azdebug tooltips line for one compare tooltip.
local function DiagnosticsLine(module, name)
	world.printed = {}
	if (module.PrintDiagnostics) then module:PrintDiagnostics() end
	for _, line in ipairs(world.printed) do
		if (string.find(line, name .. ":", 1, true)) then return line end
	end
end

local function CheckErrors(label)
	check(#world.errors == 0, label .. ": no guarded call failed", world.errors[1])
end

for _, theme in ipairs({ "Azerite", "Classic" }) do
	for _, case in ipairs({
		{ side = "right" },
		{ side = "left" },
		{ side = "right", secondary = true },
		{ side = "left", secondary = true },
		{ side = "left", secondary = true, mainScale = 1.25 },
		{ side = "right", mainScale = .8 }
	}) do
		local label = string.format("%s, %s%s%s", theme, case.side, case.secondary and ", two items" or "",
			case.mainScale and (", tooltip scale " .. case.mainScale) or "")
		local module, env, style = Load({ theme = theme, side = case.side, mainScale = case.mainScale })

		-- The first comparison of a session: the compare tooltip was never sized, so its
		-- ClearLines style call styled nothing.
		Compare(env, case.secondary)
		check(env.ShoppingTooltip1.__backdrop and env.ShoppingTooltip1.__backdrop.shown,
			label .. ": the first compare tooltip wears our backdrop")
		CheckRow(env, case.side, case.secondary, label .. ", first compare")
		CheckHeader(theme, env.ShoppingTooltip1, style, label)
		if (case.secondary) then
			CheckHeader(theme, env.ShoppingTooltip2, style, label .. ", second item")
		end

		-- Blizzard anchoring again (CycleItem, a refresh) must land in the same place.
		Compare(env, case.secondary, true)
		CheckRow(env, case.side, case.secondary, label .. ", anchored again")
		Compare(env, case.secondary)
		CheckRow(env, case.side, case.secondary, label .. ", next compare")

		-- The join alone, carrying the height as well: no TOP left whose centre could compete with it.
		local shownTooltips = case.secondary and { env.ShoppingTooltip1, env.ShoppingTooltip2 } or { env.ShoppingTooltip1 }
		for _, tooltip in ipairs(shownTooltips) do
			check(#tooltip.points == 1 and tooltip.points[1].point ~= "TOP",
				label .. ": " .. tooltip.name .. " is held by its join alone", #tooltip.points)
		end
		-- A frame later the joins are still ours, and /azdebug tooltips says so.
		RunTimers()
		local line = DiagnosticsLine(module, "ShoppingTooltip1")
		check(line and string.find(line, "held a frame later", 1, true), label .. ": /azdebug tooltips says the join held", line)
		CheckErrors(label)
	end
end

do
	-- Styling switched off and on again: Blizzard's own placement and tab while off, ours after.
	local label = "Azerite, switched off and on"
	local module, env, style = Load({ theme = "Azerite", side = "right" })
	Compare(env, false)
	module.db.profile.disableAzeriteUITooltips = true
	module:UpdateSettings()
	check(Near(HeaderOffset(env.ShoppingTooltip1), -1), label .. ": off, the tab is back on the template's anchor", HeaderOffset(env.ShoppingTooltip1))
	check(not (env.ShoppingTooltip1.__backdrop and env.ShoppingTooltip1.__backdrop.shown), label .. ": off, our backdrop is hidden")
	Compare(env, false)
	check(JoinOffset(env.ShoppingTooltip1) == 0, label .. ": off, Blizzard's edge-to-edge join is left alone", JoinOffset(env.ShoppingTooltip1))
	module.db.profile.disableAzeriteUITooltips = false
	module:UpdateSettings()
	CheckHeader("Azerite", env.ShoppingTooltip1, style, label .. ", back on")
	Compare(env, false)
	CheckRow(env, "right", false, label .. ", back on")
	CheckErrors(label)

	-- Switched off from login: nothing of ours touches the compare tooltips.
	label = "Classic, off from login"
	module, env = Load({ theme = "Classic", side = "left", disabled = true })
	Compare(env, true)
	check(Near(HeaderOffset(env.ShoppingTooltip1), -1), label .. ": the tab keeps the template's anchor", HeaderOffset(env.ShoppingTooltip1))
	check(JoinOffset(env.ShoppingTooltip1) == 0 and JoinOffset(env.ShoppingTooltip2) == 0,
		label .. ": the joins stay edge to edge", tostring(JoinOffset(env.ShoppingTooltip1)) .. "/" .. tostring(JoinOffset(env.ShoppingTooltip2)))
	CheckErrors(label)

	-- Secret anchoring: the joins are made from the SetPoint arguments, so nothing secret is read;
	-- only the frame-later check cannot read the result back, and says so.
	for _, theme in ipairs({ "Azerite", "Classic" }) do
		for _, secrecy in ipairs({ "all", "offsets" }) do
			for _, case in ipairs({
				{ side = "right" }, { side = "left" },
				{ side = "right", secondary = true }, { side = "left", secondary = true }
			}) do
				label = string.format("%s, secret anchoring (%s), %s%s", theme, secrecy, case.side, case.secondary and ", two items" or "")
				module, env = Load({ theme = theme, side = case.side })
				env.ShoppingTooltip1.secretAnchoring = secrecy
				env.ShoppingTooltip2.secretAnchoring = secrecy
				Compare(env, case.secondary)
				CheckRow(env, case.side, case.secondary, label)
				Compare(env, case.secondary, true)
				CheckRow(env, case.side, case.secondary, label .. ", anchored again")
				RunTimers()
				local line = DiagnosticsLine(module, "ShoppingTooltip1")
				check(line and string.find(line, "widened", 1, true) and string.find(line, "unknown, anchoring secret", 1, true),
					label .. ": /azdebug tooltips says widened, not readable back", line)
				CheckErrors(label)
			end
		end
	end

	-- Other addons' anchors are theirs: an edge Blizzard's joins do not use, or a join with an offset.
	label = "Azerite, someone else's anchors"
	module, env = Load({ theme = "Azerite", side = "right" })
	Compare(env, false)
	local primary = env.ShoppingTooltip1
	local ours = PointOffset(primary, "TOPLEFT")
	primary:SetPoint("LEFT", env.GameTooltip, "LEFT")
	check(PointOffset(primary, "LEFT") == 0 and PointOffset(primary, "TOPLEFT") == ours,
		label .. ": an anchor to another edge is left as set, ours too", tostring((PointOffset(primary, "LEFT"))))
	module, env = Load({ theme = "Azerite", side = "right" })
	Compare(env, false)
	primary = env.ShoppingTooltip1
	primary:SetPoint("TOPLEFT", env.GameTooltip, "TOPRIGHT", 3, 0)
	check(PointOffset(primary, "TOPLEFT") == 3, label .. ": a join with its own offset is left as set", PointOffset(primary, "TOPLEFT"))
	CheckErrors(label)

	-- Something moving a joined tooltip without SetPoint: /azdebug tooltips says so a frame later.
	label = "Azerite, moved behind our back"
	module, env = Load({ theme = "Azerite", side = "right" })
	Compare(env, false)
	env.ShoppingTooltip1.points[1].x = 0
	RunTimers()
	local moved = DiagnosticsLine(module, "ShoppingTooltip1")
	check(moved and string.find(moved, "moved to 0.0 a frame later", 1, true), label .. ": reported", moved)
	CheckErrors(label)

	-- An embedded item tooltip (quest rewards and the like) compares from inside another tooltip.
	-- Blizzard joins the compare tooltips to that outer tooltip (anchorFrame:GetParent():GetParent()).
	for _, secrecy in ipairs({ "none", "all" }) do
		label = "Azerite, embedded item tooltip, anchoring " .. secrecy
		module, env = Load({ theme = "Azerite", side = "right" })
		local holder = NewFrame(nil, env.GameTooltip)
		holder.width, holder.height = 200, 60
		holder:SetPoint("TOPLEFT", env.GameTooltip, "TOPLEFT", 10, -40)
		local embedded = NewFrame("EmbeddedItemTooltipTooltip", holder)
		embedded.width, embedded.height = 200, 60
		embedded:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		embedded.IsEmbedded = true
		embedded.shoppingTooltips = env.GameTooltip.shoppingTooltips
		env.ShoppingTooltip1.secretAnchoring = (secrecy ~= "none") and secrecy or nil
		Compare(env, false, false, embedded)
		check(Near(Seam(env.GameTooltip, env.ShoppingTooltip1), 0), label .. ": the compare tooltip's border meets the outer tooltip's",
			Seam(env.GameTooltip, env.ShoppingTooltip1))
		local _, _, embeddedTop = embedded:Rect()
		local _, _, compareTop = env.ShoppingTooltip1:Rect()
		check(Near(embeddedTop, compareTop), label .. ": its top stays level with the embedded tooltip's, as Blizzard put it",
			compareTop - embeddedTop)
		CheckErrors(label)
	end

	-- A secret scale on the tooltip compared against: no arithmetic on it.
	label = "Azerite, secret scale"
	module, env = Load({ theme = "Azerite", side = "left" })
	env.GameTooltip.secretScale = true
	Compare(env, false)
	check(JoinOffset(env.ShoppingTooltip1) == 0, label .. ": the join is left as Blizzard made it", JoinOffset(env.ShoppingTooltip1))
	CheckErrors(label)

	-- No compare modifier: the module's OnShow hook hides the compare tooltip, and a hidden
	-- tooltip's join is not widened.
	label = "Azerite, no compare modifier"
	module, env = Load({ theme = "Azerite", side = "right" })
	world.modifier = false
	Compare(env, false)
	check(not env.ShoppingTooltip1.shown, label .. ": the compare tooltip is hidden")
	check(JoinOffset(env.ShoppingTooltip1) == 0, label .. ": its join is not widened", JoinOffset(env.ShoppingTooltip1))
	CheckErrors(label)
end

-- The native aura containers' AuraButtonTooltip (player buffs, plate and frame aura rows) wears
-- the theme through AuraContainerInbound.SetTooltipBackdrop.
local function CheckAuraStyle(style, applied, label)
	if (not applied) then
		check(false, label .. ": the aura tooltip was styled", "no SetTooltipBackdrop call")
		return
	end
	local info, offsets = applied.backdropInfo, applied.anchorOffsets or {}
	check(info.edgeFile == style.backdrop.edgeFile and info.bgFile == style.backdrop.bgFile and info.edgeSize == style.backdrop.edgeSize,
		label .. ": the theme's border and fill", tostring(info.edgeFile) .. " " .. tostring(info.edgeSize))
	check(info.insets and info.insets.left == style.backdrop.insets.left and info.insets.top == style.backdrop.insets.top,
		label .. ": the theme's insets")
	check(offsets.left == style.offsetLeft and offsets.right == style.offsetRight and offsets.top == style.offsetTop
		and offsets.bottom == style.offsetBottom, label .. ": hangs past the tooltip as our other tooltips' backdrops do",
		string.format("%s/%s/%s/%s", tostring(offsets.left), tostring(offsets.right), tostring(offsets.top), tostring(offsets.bottom)))
	local border, fill = applied.borderColor or {}, applied.centerColor or {}
	check(border.r == style.backdropBorderColor[1] and border.g == style.backdropBorderColor[2] and border.a == (style.backdropBorderColor[4] or 1)
		and fill.r == style.backdropColor[1] and fill.a == style.backdropColor[4], label .. ": the theme's colours")
end

do
	for _, theme in ipairs({ "Azerite", "Classic" }) do
		local label = theme .. ", aura tooltip"
		local module, _, style, themes = Load({ theme = theme, side = "right" })
		check(#world.auraStyles == 1, label .. ": styled once at login", #world.auraStyles)
		CheckAuraStyle(style, world.auraStyles[1], label)
		module:UpdateSettings()
		module:UpdateTooltipThemes("PLAYER_ENTERING_WORLD")
		check(#world.auraStyles == 1, label .. ": not restyled when nothing changed", #world.auraStyles)

		local other = (theme == "Azerite") and "Classic" or "Azerite"
		module.db.profile.theme = other
		module:UpdateSettings()
		check(#world.auraStyles == 2, label .. ": restyled on a theme change", #world.auraStyles)
		CheckAuraStyle(themes[other].backdropStyle, world.auraStyles[2], label .. ", switched to " .. other)

		module.db.profile.disableAzeriteUITooltips = true
		module:UpdateSettings()
		check(world.auraResets == 1, label .. ": switched off, Blizzard's style is put back", world.auraResets)
		module:UpdateSettings()
		check(world.auraResets == 1, label .. ": and only once", world.auraResets)
		module.db.profile.disableAzeriteUITooltips = false
		module:UpdateSettings()
		check(#world.auraStyles == 3, label .. ": switched on again, styled again", #world.auraStyles)
		CheckErrors(label)
	end

	-- Off from login: another addon's aura tooltip style is not ours to reset.
	local label = "Azerite, aura tooltip, off from login"
	local module = Load({ theme = "Azerite", side = "right", disabled = true })
	module:OnAddonLoaded("ADDON_LOADED", "Blizzard_AuraContainer")
	check(#world.auraStyles == 0 and world.auraResets == 0, label .. ": neither styled nor reset",
		#world.auraStyles .. "/" .. world.auraResets)
	CheckErrors(label)

	-- Blizzard_AuraContainer loading after us.
	label = "Classic, aura tooltip, container loads late"
	local style, _
	module, _, style = Load({ theme = "Classic", side = "right", lateAuraContainer = true })
	check(#world.auraStyles == 0, label .. ": nothing to style before it loads", #world.auraStyles)
	world.env.AuraContainerInbound = world.inbound
	module:OnAddonLoaded("ADDON_LOADED", "SomethingElse")
	check(#world.auraStyles == 0, label .. ": another addon's load is ignored", #world.auraStyles)
	module:OnAddonLoaded("ADDON_LOADED", "Blizzard_AuraContainer")
	CheckAuraStyle(style, world.auraStyles[1], label)
	CheckErrors(label)

	-- A refusal is reported, and tried again on the next refresh.
	label = "Azerite, aura tooltip, refused once"
	module, _, style = Load({ theme = "Azerite", side = "right", lateAuraContainer = true })
	world.env.AuraContainerInbound = world.inbound
	world.refuseAuraStyle = true
	module:OnAddonLoaded("ADDON_LOADED", "Blizzard_AuraContainer")
	check(#world.errors == 1 and string.find(world.errors[1], "Tooltips.ApplyAuraTooltipTheme", 1, true),
		label .. ": the refusal reached the error handler", world.errors[1])
	module:UpdateTooltipThemes()
	CheckAuraStyle(style, world.auraStyles[1], label .. ", next refresh")
end

-- Show spellID on aura tooltips. UnitAura is Classic-only, so the index-based setters read
-- C_UnitAuras.GetAuraDataByIndex; SetUnitBuff and SetUnitDebuff imply HELPFUL and HARMFUL.
do
	local label = "aura spell IDs"
	local module, env = Load({ theme = "Classic", side = "right", showSpellID = true })
	local tip = env.GameTooltip
	world.names.player = "Tim"
	world.auraData = { name = "Mark of the Wild", spellId = 1126, sourceUnit = "player" }
	local function Run(method, ...)
		tip.lines, world.auraFilters = {}, {}
		local ok, err = pcall(tip[method], tip, ...)
		check(ok, label .. ", " .. method .. ": no error", err)
		return tip.lines, world.auraFilters[1]
	end
	local lines, filter = Run("SetUnitBuff", "player", 1)
	check(filter == "HELPFUL", label .. ": SetUnitBuff reads a helpful aura", filter)
	check(lines[2] and string.find(lines[2], "1126", 1, true) and string.find(lines[2], "Tim", 1, true),
		label .. ": the spell ID and caster are added", lines[2])
	lines, filter = Run("SetUnitDebuff", "player", 2)
	check(filter == "HARMFUL", label .. ": SetUnitDebuff reads a harmful aura", filter)
	lines, filter = Run("SetUnitBuff", "player", 1, "PLAYER")
	check(filter == "HELPFUL|PLAYER", label .. ": a buff filter adds to HELPFUL", filter)
	lines, filter = Run("SetUnitDebuff", "player", 1, "HARMFUL|RAID")
	check(filter == "HARMFUL|RAID", label .. ": a filter that names the kind is kept", filter)
	lines, filter = Run("SetUnitAura", "player", 3, "HARMFUL")
	check(filter == "HARMFUL" and #lines == 2, label .. ": SetUnitAura passes its filter", filter)
	lines = Run("SetUnitAuraByAuraInstanceID", "target", 55)
	check(#lines == 2 and string.find(lines[2], "1126", 1, true), label .. ": Blizzard's plate aura setter gets the ID too", lines[2])
	world.secretAura = true
	lines = Run("SetUnitBuff", "player", 1)
	check(#lines == 0, label .. ": a secret aura adds nothing", #lines)
	world.secretAura = nil
	world.auraData = { name = "Mark of the Wild", spellId = SECRET, sourceUnit = "player" }
	lines = Run("SetUnitBuff", "player", 1)
	check(#lines == 0, label .. ": a secret spell ID adds nothing", #lines)
	module.db.profile.showSpellID = false
	world.auraData = { name = "Mark of the Wild", spellId = 1126 }
	lines = Run("SetUnitBuff", "player", 1)
	check(#lines == 0, label .. ": Show spellID off adds nothing", #lines)
	CheckErrors(label)
end

-- Unit post-calls run for any tooltip given unit data: the name goes on that tooltip's line.
do
	local label = "unit name line"
	local module, env = Load({ theme = "Classic", side = "right" })
	local other = NewFrame("SomeAddonTooltip", env.UIParent)
	other.TextLeft1 = NewFontString()
	function other:GetUnit() return nil, "target" end
	world.units.target, world.names.target = true, "Bob"
	env.GameTooltip.TextLeft1:SetText("Sword of Something")
	local ok, err = pcall(module.OnTooltipSetUnit, module, other)
	check(ok, label .. ": no error", err)
	check(other.TextLeft1:GetText() == "|cff00ff00Bob|r", label .. ": written to the tooltip the unit is on", other.TextLeft1:GetText())
	check(env.GameTooltip.TextLeft1:GetText() == "Sword of Something", label .. ": GameTooltip's first line is left alone",
		env.GameTooltip.TextLeft1:GetText())
	other.TextLeft1:SetText("Blizzard's secret name")
	world.names.target = SECRET
	pcall(module.OnTooltipSetUnit, module, other)
	check(other.TextLeft1:GetText() == "Blizzard's secret name", label .. ": a secret name is not replaced with Unknown",
		other.TextLeft1:GetText())
	world.names.target = "Bob"
	local bare = NewFrame("NoLinesTooltip", env.UIParent)
	function bare:GetUnit() return nil, "target" end
	check(pcall(module.OnTooltipSetUnit, module, bare), label .. ": a tooltip without a name line is skipped")
	CheckErrors(label)
end

-- The value on GameTooltip's health bar: secret health hides it, never the last unit's numbers.
do
	local label = "health text"
	local module, env = Load({ theme = "Classic", side = "right" })
	-- The module's value text, made on the bar when the theme was applied at login.
	local text = env.GameTooltip.StatusBar.fontStrings[1]
	world.units.mouseover = true
	world.health.mouseover = { 1000, 2000 }
	module:SetHealthValue("mouseover")
	check(text and text:IsShown() and text:GetText() == "1000 / 2000", label .. ": a readable unit's health is printed", text and text:GetText())
	world.health.mouseover = { SecretValue(500), SecretValue(2000) }
	local ok, err = pcall(module.SetHealthValue, module, "mouseover")
	check(ok, label .. ": secret health raises nothing", err)
	check(text and not text:IsShown(), label .. ": secret health hides the text, not the last unit's numbers", text and text:GetText())
	world.health.mouseover = { 300, 600 }
	module:SetHealthValue("mouseover")
	check(text and text:IsShown() and text:GetText() == "300 / 600", label .. ": readable again, printed again", text and text:GetText())
	CheckErrors(label)
end

-- Compare tooltips take GameTooltip's scale when it is set, so they are drawn at its size and the
-- join is the plain sum of the two overhangs (live: 18.9 where both at one scale give 20).
do
	for _, cursor in ipairs({ false, true }) do
		local label = "compare tooltip scale" .. (cursor and ", anchored to the cursor" or "")
		local module, env = Load({ theme = "Azerite", side = "right", anchorScale = .89 })
		module.db.profile.anchorToCursor = cursor
		env.GameTooltip_SetDefaultAnchor(env.GameTooltip, env.UIParent)
		check(env.GameTooltip.scale == .89 and env.ShoppingTooltip1.scale == .89 and env.ShoppingTooltip2.scale == .89,
			label .. ": both compare tooltips at the tooltip's scale", env.ShoppingTooltip1.scale .. "/" .. env.ShoppingTooltip2.scale)
		if (not cursor) then
			Compare(env, true)
			CheckRow(env, "right", true, label)
			local line = DiagnosticsLine(module, "ShoppingTooltip2")
			check(line and string.find(line, "by 20.0", 1, true), label .. ": the join is the two overhangs", line)
		end
		CheckErrors(label)
	end
end

-- Tooltips > Hide in Combat: one answer per kind, and the action bars asked to hand it to
-- LibActionButton only when it changes (and at login only when it is on).
do
	local label = "hide in combat"
	local module = Load({ theme = "Classic", side = "right", withActionBars = true })
	check(world.actionBarRefreshes == 0, label .. ": off at login, the action bars are left alone", world.actionBarRefreshes)
	check(module.ShouldHideInCombat and not module:ShouldHideInCombat("actionbars") and not module:ShouldHideInCombat("unitframes"),
		label .. ": off hides nothing")
	module.db.profile.hideInCombat = true
	module:UpdateSettings()
	check(world.actionBarRefreshes == 1, label .. ": switched on, the action bars refresh", world.actionBarRefreshes)
	check(module:ShouldHideInCombat("actionbars") and module:ShouldHideInCombat("unitframes") and not module:ShouldHideInCombat("minimap"),
		label .. ": on, action bars and unit frames, nothing else")
	module:UpdateSettings()
	check(world.actionBarRefreshes == 1, label .. ": unchanged, no refresh", world.actionBarRefreshes)
	module.db.profile.hideActionBarTooltipsInCombat = false
	module:UpdateSettings()
	check(world.actionBarRefreshes == 2 and not module:ShouldHideInCombat("actionbars") and module:ShouldHideInCombat("unitframes"),
		label .. ": action bars off alone", world.actionBarRefreshes)
	module = Load({ theme = "Classic", side = "right", withActionBars = true, hideInCombat = true })
	check(world.actionBarRefreshes == 1, label .. ": on at login, the action bars refresh once", world.actionBarRefreshes)
	CheckErrors(label)
end

print(string.format("Tooltip compare: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("tooltip compare harness failed", 0) end

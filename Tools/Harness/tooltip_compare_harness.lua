-- Compare tooltips (Components/Misc/Tooltips.lua), on Retail and on Forever alike.
-- Our backdrop hangs outside every tooltip (Azerite 10px at the sides and 18px on top, Classic 6px),
-- while Blizzard sets compare tooltips edge to edge and tucks their "Equipped" tab 1px behind the
-- tooltip's own top edge. So the module widens the joins Blizzard has just made, inside
-- TooltipComparisonManager:AnchorShoppingTooltips, and tucks the tab behind our border instead.
-- This loads the real module, its layout data and Core/API/ProtectedCall.lua, with Blizzard's
-- Initialize and AnchorShoppingTooltips copied verbatim from
-- Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua (identical in live 12.1.0 and forever
-- 1.60.1), against frames that resolve their anchors to screen rectangles.
-- No rendering, taint or restricted-environment checks. Stock Lua 5.1 cannot make `==` or a table
-- index raise on a secret, so a missing guard shows only where a secret reaches arithmetic or goes
-- back into SetPoint: the secret scale case and the "offsets" secret-anchoring case.
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
function Frame:GetPoint(index)
	local anchor = self.points[index]
	if (not anchor) then return end
	-- SecretWhenAnchoringSecret (SimpleScriptRegionResizingAPIDocumentation.lua). "offsets" keeps the
	-- names readable so code without a guard gets as far as handing a secret back to SetPoint.
	if (self.secretAnchoring == "all") then return SECRET, SECRET, SECRET, SECRET, SECRET end
	if (self.secretAnchoring == "offsets") then
		return anchor.point, anchor.relativeTo, anchor.relativePoint, SecretValue(anchor.x), SecretValue(anchor.y)
	end
	return anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y
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

local function Load(options)
	local env = {}
	world = { env = env, errors = {}, slides = 0, modifier = true }

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

	for key, value in pairs({
		_G = env, UIParent = UIParent, GameTooltip = GameTooltip,
		ShoppingTooltip1 = compareTooltips[1], ShoppingTooltip2 = compareTooltips[2],
		TooltipComparisonManager = manager,
		CreateFrame = CreateFrame, hooksecurefunc = hooksecurefunc, issecretvalue = IsSecret,
		GetTime = function() return 0 end,
		IsModifiedClick = function() return world.modifier end,
		geterrorhandler = function() return function(message) table.insert(world.errors, message) end end,
		-- Hooked by the module; Blizzard's bodies do nothing the harness measures.
		SharedTooltip_SetBackdropStyle = function() end,
		GameTooltip_UnitColor = function() end,
		GameTooltip_ShowCompareItem = function() end,
		GameTooltip_SetDefaultAnchor = function() end,
		LibStub = function() return { GetLocale = function() return {} end } end
	}) do
		env[key] = value
	end
	setmetatable(env, { __index = _G })

	local configs = {}
	local module = NewModule()
	local ns = {
		API = { GetFont = function() end, GetMedia = function(name) return name end },
		Colors = { offwhite = { 1, 1, 1 }, quest = { gray = { colorCode = "" } } },
		Hider = UIHider,
		BackdropTemplate = BACKDROP_TEMPLATE,
		MovableModulePrototype = { defaults = {} },
		RegisterConfig = function(name, config) configs[name] = config end,
		GetConfig = function(name) return configs[name] end,
		Merge = function(_, a) return a end,
		NewModule = function() return module end
	}

	for _, file in ipairs({ root .. "/Core/API/ProtectedCall.lua", root .. "/Layouts/Data/Tooltips.lua", path }) do
		local chunk = assert(loadfile(file))
		setfenv(chunk, env)
		chunk("AzeriteUI5_JuNNeZ_Edition", ns)
	end

	module.db = { profile = {
		theme = options.theme, disableAzeriteUITooltips = options.disabled or false,
		nameplateUnitTransparency = false, showItemID = false, showSpellID = false, anchor = true
	} }
	module:UpdateSettings()
	return module, env, configs.Tooltips.themes[options.theme].backdropStyle
end

-- TooltipComparisonManager:CompareItem -> RefreshItems: Initialize, then SetItemTooltip for each
-- tooltip it fills (ClearLines -> OnTooltipCleared -> GameTooltip_ClearStyle ->
-- SharedTooltip_SetBackdropStyle, then the lines), then AnchorShoppingTooltips. CycleItem skips
-- Initialize.
local function Compare(env, secondary, cycle)
	local manager = env.TooltipComparisonManager
	if (not cycle) then manager:Initialize(env.GameTooltip) end
	for i, tooltip in ipairs(env.GameTooltip.shoppingTooltips) do
		if (i == 1 or secondary) then
			env.SharedTooltip_SetBackdropStyle(tooltip, nil)
			tooltip.width = tooltip.contentWidth
		end
	end
	manager:AnchorShoppingTooltips(true, secondary and true or false)
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

		-- Our handler running again without Blizzard must not widen twice.
		check(module.OnAnchorShoppingTooltips, label .. ": the module has a comparison anchoring handler")
		if (module.OnAnchorShoppingTooltips) then
			module:OnAnchorShoppingTooltips(env.TooltipComparisonManager)
			CheckRow(env, case.side, case.secondary, label .. ", handler run twice")
		end
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

	-- Secret anchoring: GetPoint answers secrets, so the tooltip stays where Blizzard put it.
	for _, secrecy in ipairs({ "all", "offsets" }) do
		label = "Azerite, secret anchoring (" .. secrecy .. ")"
		module, env = Load({ theme = "Azerite", side = "right" })
		env.ShoppingTooltip1.secretAnchoring = secrecy
		Compare(env, false)
		check(JoinOffset(env.ShoppingTooltip1) == 0, label .. ": the join is left as Blizzard made it", JoinOffset(env.ShoppingTooltip1))
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

print(string.format("Tooltip compare: %d checks, %d failures", checks, failures))
-- Raised rather than os.exit, so mutate_client.lua can run this inside a pcall.
if (failures > 0) then error("tooltip compare harness failed", 0) end

-- Native animation groups only: no Lua OnUpdate, unit values or combat layout writes.
local addon, ns = ...
local Effects = {}
ns.HalloweenEffects = Effects
local media = "Interface\\AddOns\\" .. addon .. "\\Assets\\Halloween\\"

local Alpha = function(group, from, to, duration, order)
	local animation = group:CreateAnimation("Alpha")
	animation:SetFromAlpha(from)
	animation:SetToAlpha(to)
	animation:SetDuration(duration)
	animation:SetOrder(order or 1)
	animation:SetSmoothing("IN_OUT")
	return animation
end

local Path = function(texture, points, duration, loop)
	local group = texture:CreateAnimationGroup()
	local path = group:CreateAnimation("Path")
	path:SetCurveType("SMOOTH")
	path:SetDuration(duration)
	path:SetOrder(1)
	for i, point in ipairs(points) do
		local control = path:CreateControlPoint(nil, nil, i)
		control:SetOffset(point[1], point[2])
	end
	if (loop) then group:SetLooping("REPEAT") end
	return group, path
end

local Play = function(groups)
	for _, group in ipairs(groups) do
		if (not group:IsPlaying()) then group:Play() end
	end
end
local Stop = function(groups)
	for _, group in ipairs(groups) do group:Stop() end
end

local Visible = function(anchor)
	local visible = anchor:IsVisible()
	return not (issecretvalue and issecretvalue(visible)) and visible == true
end

Effects.SetPulse = function(self, texture, enabled)
	local group = texture.HalloweenPulse
	if (enabled and not group) then
		group = texture:CreateAnimationGroup()
		Alpha(group, .18, .40, 3.8, 1)
		Alpha(group, .40, .18, 4.7, 2)
		group:SetLooping("REPEAT")
		texture.HalloweenPulse = group
		local parent = texture:GetParent()
		parent:HookScript("OnShow", function()
			if (texture.HalloweenActive) then group:Play() end
		end)
		parent:HookScript("OnHide", function() group:Stop() end)
	end
	texture.HalloweenActive = enabled
	if (group) then
		if (enabled and Visible(texture:GetParent())) then
			if (not group:IsPlaying()) then group:Play() end
		else group:Stop() end
	end
end

Effects.AddSpider = function(self, overlay, anchor, size)
	local spider = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
	spider:SetTexture(media .. "spider.tga")
	spider:SetPoint("CENTER", anchor, "TOPLEFT", 5, -5)
	local unit = size / 28
	spider:SetSize(7, 7)
	local group = Path(spider, { {0,0}, {8*unit,-unit}, {10*unit,-2*unit},
		{6*unit,-unit}, {3*unit,0}, {0,0} }, 19, true)
	overlay.Spider = spider
	overlay.SpiderAnimation = group
	overlay:HookScript("OnShow", function() group:Play() end)
	overlay:HookScript("OnHide", function() group:Stop() end)
	if (Visible(overlay)) then group:Play() end
end

local Sprite = function(parent, name, size, anchor, x, y, layer)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, 0)
	texture:SetTexture(media .. name .. ".tga")
	texture:SetSize(size, size)
	texture:SetPoint("CENTER", anchor, "CENTER", x, y)
	return texture
end

Effects.CreateMinimap = function(self, anchor, overlay)
	local width, height = anchor:GetWidth(), anchor:GetHeight()
	if ((issecretvalue and (issecretvalue(width) or issecretvalue(height)))
		or type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0) then return end
	local unit = math.min(width, height)
	local back = CreateFrame("Frame", nil, anchor)
	back:SetAllPoints(anchor)
	back:EnableMouse(false)
	back:SetFrameLevel(math.max(0, anchor:GetFrameLevel() - 1))
	local passage = CreateFrame("Frame", nil, anchor)
	passage:SetAllPoints(anchor)
	passage:EnableMouse(false)
	passage:SetFrameLevel(anchor:GetFrameLevel() + 1)
	passage:SetClipsChildren(true)
	-- Same shared circular-alpha mask used by MoonwellSlosh. It stays fixed
	-- on the map while only the individual leaf textures are animated.
	local mask = passage:CreateMaskTexture()
	mask:SetAllPoints(anchor)
	mask:SetTexture("Interface\\AddOns\\" .. addon .. "\\Assets\\orb2.tga",
		"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	local fx = { Anchor = anchor, Front = overlay, Back = back, Passage = passage,
		LeafMask = mask, Bursts = {}, GustLeaves = {}, Wisps = {}, WispVisits = {} }

	-- Short, irregular visits: peek from behind an edge, wander outside and
	-- across the map, then slip behind the opposite rim. No repeating orbit.
	for light = 1, 2 do
		local duration = 12 + light*2
		local direction = light == 1 and 1 or -1
		local route = { {-.44,.20}, {-.56,.24}, {-.52,.40}, {-.12,.58},
			{.22,.06}, {.39,-.14}, {.48,.25}, {.42,.18} }
		local startX, startY = route[1][1]*unit*direction, route[1][2]*unit*direction
		local points = {}
		for _, point in ipairs(route) do
			points[#points+1] = {point[1]*unit*direction-startX, point[2]*unit*direction-startY}
		end
		local visit = {}
		fx.WispVisits[#fx.WispVisits+1] = visit
		for _, front in ipairs({ false, true }) do
			local wisp = Sprite(front and overlay or back, "soul-light", unit*.18, anchor,
				startX, startY)
			wisp:SetAlpha(0)
			local travel = Path(wisp, points, duration)
			visit[#visit+1] = travel
			local fade = wisp:CreateAnimationGroup()
			local levels = front and {0,0,.55,.55,.65,.55,0,0} or {0,.32,0,0,0,0,.30,0}
			for step = 1, #levels-1 do Alpha(fade, levels[step], levels[step+1], duration/(#levels-1), step) end
			fade:SetToFinalAlpha(true)
			visit[#visit+1] = fade
			fx.Wisps[#fx.Wisps+1] = wisp
		end
	end

	-- A short gust, allocated once. All movement/fading is performed by the
	-- native animation engine, including hover bursts while in combat.
	for i = 1, 7 do
		local delay, duration = (i-1)*.22, 4.8
		local leaf = Sprite(passage, "autumn-leaf", unit*(.085 + .01*(i%3)), anchor,
			-unit*.56, unit*(.30 - .09*i))
		leaf:AddMaskTexture(mask)
		fx.GustLeaves[#fx.GustLeaves+1] = leaf
		leaf:SetAlpha(0)
		leaf:SetRotation(i*.8)
		local travel, path = Path(leaf, { {0,0}, {unit*.30,unit*.04},
			{unit*.74,-unit*.025}, {unit*1.12,0} }, duration)
		path:SetStartDelay(delay)
		local rotation = travel:CreateAnimation("Rotation")
		rotation:SetDegrees(110 + i*23)
		rotation:SetOrigin("CENTER", 0, 0)
		rotation:SetDuration(duration)
		rotation:SetStartDelay(delay)
		rotation:SetOrder(1)
		local fade = leaf:CreateAnimationGroup()
		Alpha(fade, 0, .75, .4, 1):SetStartDelay(delay)
		Alpha(fade, .75, .75, 4, 2)
		Alpha(fade, .75, 0, .4, 3)
		fade:SetToFinalAlpha(true)
		fx.Bursts[#fx.Bursts+1] = travel
		fx.Bursts[#fx.Bursts+1] = fade
	end

	fx.Burst = function(controller)
		if (not controller.Enabled or not Visible(anchor)) then return false end
		if (ns.Halloween and not ns.Halloween:IsVisible()) then return false end
		local now = GetTime()
		if (controller.LastBurst and now-controller.LastBurst < 30) then return false end
		controller.LastBurst = now
		for _, group in ipairs(controller.Bursts) do group:Stop(); group:Play() end
		return true
	end
	fx.Schedule = function(controller)
		if (controller.Timer or not controller.Enabled or not Visible(anchor)) then return end
		if (ns.Halloween and not ns.Halloween:IsVisible()) then return end
		controller.Timer = C_Timer.NewTimer(math.random(600, 900), function()
			controller.Timer = nil
			if (controller.Enabled and Visible(anchor)) then controller:Burst(); controller:Schedule() end
		end)
	end
	fx.Visit = function(controller)
		if (not controller.Enabled or not Visible(anchor)) then return false end
		if (ns.Halloween and not ns.Halloween:IsVisible()) then return false end
		for _, visit in ipairs(controller.WispVisits) do Stop(visit) end
		controller.LastVisit = math.random(1, #controller.WispVisits)
		Play(controller.WispVisits[controller.LastVisit])
		return true
	end
	fx.ScheduleWisps = function(controller)
		if (controller.WispTimer or not controller.Enabled or not Visible(anchor)) then return end
		if (ns.Halloween and not ns.Halloween:IsVisible()) then return end
		controller.WispTimer = C_Timer.NewTimer(math.random(1200, 1500), function()
			controller.WispTimer = nil
			if (controller.Enabled and Visible(anchor)) then controller:Visit(); controller:ScheduleWisps() end
		end)
	end
	fx.Stop = function(controller)
		if (controller.Timer) then controller.Timer:Cancel(); controller.Timer = nil end
		if (controller.WispTimer) then controller.WispTimer:Cancel(); controller.WispTimer = nil end
		for _, visit in ipairs(controller.WispVisits) do Stop(visit) end
		Stop(controller.Bursts)
	end
	fx.Start = function(controller)
		if (not controller.Enabled or not Visible(anchor)) then return end
		controller:Schedule()
		controller:ScheduleWisps()
	end
	fx.SetEnabled = function(controller, enabled)
		controller.Enabled = enabled
		back:SetShown(enabled)
		passage:SetShown(enabled)
		if (enabled) then controller:Start() else controller:Stop() end
	end
	anchor:HookScript("OnEnter", function() fx:Burst() end)
	anchor:HookScript("OnShow", function() fx:Start() end)
	anchor:HookScript("OnHide", function() fx:Stop() end)
	return fx
end

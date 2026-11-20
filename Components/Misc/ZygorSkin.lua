local addon, ns = ...
local Skin = ns:NewModule("ZygorSkin", "LibMoreEvents-1.0")
local directory = "Interface\\AddOns\\" .. addon .. "\\Assets\\Zygor\\"
local accents = {
	Forged = { .18, .72, .84 },
	Glass = { .20, .65, .98 },
	["Field-Journal"] = { .82, .62, .34 }
}
local selected, viewer, art
local steps, lines, originalAlpha = {}, {}, {}

local function slice(parent, layer, left, right, top, bottom)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexCoord(left / 256, right / 256, top / 128, bottom / 128)
	return texture
end

local function buildArt(border)
	local textures = {}
	local title = border.TitleBar
	textures.header = slice(title, "BACKGROUND", 0, 256, 0, 32)
	textures.header:SetAllPoints()
	textures.toolbar = slice(border.Toolbar, "BORDER", 0, 256, 0, 32)
	textures.toolbar:SetAllPoints()
	textures.toolbar:SetVertexColor(.72, .72, .72)
	textures.body = slice(border.Back, "BORDER", 0, 256, 32, 64)
	textures.body:SetAllPoints()
	textures.rail = slice(title, "BORDER", 0, 256, 96, 112)
	textures.rail:SetPoint("TOPLEFT")
	textures.rail:SetPoint("TOPRIGHT")
	textures.rail:SetHeight(2)
	textures.crest = slice(title, "BORDER", 32, 128, 64, 96)
	textures.crest:SetSize(28, 6)
	textures.crest:SetPoint("TOP")
	for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		local right = point:find("RIGHT", 1, true)
		local bottom = point:find("BOTTOM", 1, true)
		local parent = bottom and border.Back or title
		local cap = slice(parent, "OVERLAY", right and 32 or 0, right and 0 or 32,
			bottom and 96 or 64, bottom and 64 or 96)
		cap:SetSize(8, 8)
		cap:SetPoint(point)
		textures[point] = cap
	end
	return textures
end

-- Only fade backdrop textures. Frame alpha would also fade text and controls.
local function glass(region, opacity)
	if not region then return end
	if selected == "Glass" then
		if originalAlpha[region] == nil then originalAlpha[region] = region:GetAlpha() end
		region:SetAlpha(originalAlpha[region] * opacity)
	elseif originalAlpha[region] ~= nil then
		region:SetAlpha(originalAlpha[region])
		originalAlpha[region] = nil
	end
end

local function updateLine(line)
	local state = lines[line]
	-- Zygor paints objective states and completion flashes on its own back frame.
	-- Put paper only behind uncoloured guide prose and directions.
	local plain = selected == "Field-Journal" and line:IsShown() and
		(line.tipgoal or (line.goal and (not line.back:IsShown() or
			(line.anim_fade and line.anim_fade.a == 0 and not line.anim_fade:IsPlaying()))))
	if plain then
		if not state then
			local paper = slice(line, "ARTWORK", 0, 256, 32, 64)
			paper:SetTexture(directory .. "Field-Journal")
			paper:SetAllPoints()
			state = { paper = paper }
			lines[line] = state
		end
		if not state.color then state.color = { line.label:GetTextColor() } end
		-- Zygor embeds pale colours directly in tips and item links.
		local text = line.label:GetText()
		if not (issecretvalue and issecretvalue(text)) and text and text ~= state.ink then
			local ink = text:gsub("|c%x%x%x%x%x%x%x%x", "|cff155453")
			state.original, state.ink = text, ink
			if ink ~= text then line.label:SetText(ink) end
		end
		state.paper:Show()
		line.label:SetTextColor(.15, .09, .04, 1)
	elseif state and state.color then
		state.paper:Hide()
		local text = line.label:GetText()
		if not (issecretvalue and issecretvalue(text)) and state.ink and text == state.ink and state.original ~= text then
			line.label:SetText(state.original)
		end
		state.original, state.ink = nil, nil
		line.label:SetTextColor(unpack(state.color))
		state.color = nil
	end
end

local function updateStep(step, restore)
	glass(step.Center, .35)
	if step.lines and (selected == "Field-Journal" or restore) then
		for _, line in ipairs(step.lines) do updateLine(line) end
	end
end

local function watchStep(step)
	if step and step.Render and step.lines then
		if not steps[step] then
			steps[step] = true
			hooksecurefunc(step, "Render", function()
				if selected then updateStep(step) end
			end)
		end
		updateStep(step)
	end
end

local stripe, tabPaper, paperTab, tabColor
local function updateTab()
	if stripe then stripe:Hide() end
	if paperTab then
		tabPaper:Hide()
		paperTab.Text:SetTextColor(unpack(tabColor))
		paperTab = nil
	end
	local tabs = _G.ZygorGuidesViewer.Tabs
	local tab = tabs and tabs.ActiveTab
	if not selected or not tab or not tab.Button then return end
	if selected == "Field-Journal" and tab.Text then
		if not tabPaper then
			tabPaper = slice(tab.Button, "BORDER", 0, 256, 32, 64)
			tabPaper:SetTexture(directory .. "Field-Journal")
		end
		tabPaper:SetParent(tab.Button)
		tabPaper:ClearAllPoints()
		tabPaper:SetAllPoints(tab.Button)
		tabPaper:Show()
		paperTab, tabColor = tab, { tab.Text:GetTextColor() }
		tab.Text:SetTextColor(.15, .09, .04, 1)
	end
	if not stripe then stripe = tab.Button:CreateTexture(nil, "OVERLAY") end
	stripe:SetParent(tab.Button)
	stripe:ClearAllPoints()
	stripe:SetPoint("BOTTOMLEFT", 1, 0)
	stripe:SetPoint("BOTTOMRIGHT", -1, 0)
	stripe:SetHeight(1)
	stripe:SetColorTexture(unpack(accents[selected]))
	stripe:Show()
end

local function paint(restore)
	if not viewer or (not selected and not art) then return end
	local border = viewer.Border
	if selected and not art then art = buildArt(border) end
	if art then
		for key, texture in pairs(art) do
			if selected then
				texture:SetTexture(directory .. selected)
				texture:SetAlpha(selected == "Glass" and .55 or 1)
				if key == "body" then
					texture:SetAlpha(selected == "Glass" and .12 or 1)
					-- Keep a dark ground beneath Zygor's coloured quest rows.
					local shade = selected == "Field-Journal" and .18 or 1
					texture:SetVertexColor(shade, shade, shade)
				end
			end
			texture:SetShown(selected ~= nil)
		end
	end
	glass(border.Center, .52)
	glass(border.Back.Center, .40)
	for _, step in ipairs(viewer.stepframes or {}) do
		if not steps[step] then watchStep(step) end
	end
	-- Pooled steps can be inactive while changing skins.
	for step in pairs(steps) do updateStep(step, restore == true) end
	updateTab()
end

function Skin:Refresh()
	local zgv = _G.ZygorGuidesViewer
	local frame = zgv and zgv.Frame
	if not frame or not frame.Border or not frame.Border.TitleBar or
		not frame.Border.Toolbar or not frame.Border.Back or not frame.ApplySkin or not frame.AddStep then return end
	if viewer ~= frame then
		viewer = frame
		hooksecurefunc(frame, "ApplySkin", paint)
		hooksecurefunc(frame, "AddStep", function()
			if selected then watchStep(frame.stepframes[#frame.stepframes]) end
		end)
		if zgv.Tabs and zgv.Tabs.SetAsCurrent then hooksecurefunc(zgv.Tabs, "SetAsCurrent", updateTab) end
	end
	local previous = selected
	local choice = ns.db.char.zygorSkin
	selected = accents[choice] and choice or nil
	if selected or previous then paint(previous == "Field-Journal") end
end

function Skin:SetChoice(choice)
	if InCombatLockdown() then return end
	ns.db.char.zygorSkin = accents[choice] and choice or nil
	self:Refresh()
end

function Skin:OnInitialize()
	local zgvHooked
	local function attach()
		local zgv = _G.ZygorGuidesViewer
		if zgv and zgv.SetSkin and not zgvHooked then
			zgvHooked = true
			hooksecurefunc(zgv, "SetSkin", function() self:Refresh() end)
		end
		if ns.db and ns.db.char then self:Refresh() end
	end
	self:RegisterEvent("ADDON_LOADED", function(_, _, name)
		if name == "ZygorGuidesViewer" or name == "ZygorGuidesViewerForever" then attach() end
	end)
	self:RegisterEvent("PLAYER_LOGIN", attach)
	attach()
end

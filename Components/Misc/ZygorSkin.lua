local addon, ns = ...
local Skin = ns:NewModule("ZygorSkin", "LibMoreEvents-1.0")
local directory = "Interface\\AddOns\\" .. addon .. "\\Assets\\Zygor\\"
local accents = {
	Forged = { .18, .72, .84 },
	Glass = { .20, .65, .98 },
	["Field-Journal"] = { .82, .62, .34 }
}
local selected, viewer, art
local steps, lines, backdropVisibility = {}, {}, {}
local rowWax = {}
local backdropPieces = {
	"Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
	"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"
}

local function slice(parent, layer, left, right, top, bottom)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexCoord(left / 256, right / 256, top / 128, bottom / 128)
	return texture
end

local function buildArt(border, scroll)
	local textures = {}
	local title = border.TitleBar
	textures.header = slice(title, "BACKGROUND", 0, 256, 0, 32)
	textures.header:SetAllPoints()
	textures.panel = slice(border, "BORDER", 0, 256, 32, 64)
	textures.panel:SetAllPoints()
	textures.toolbar = slice(border.Toolbar, "BORDER", 0, 256, 0, 32)
	textures.toolbar:SetAllPoints()
	textures.toolbar:SetVertexColor(.72, .72, .72)
	-- Keep the scroll surface for Forged. Glass and Journal have their own
	-- larger surfaces, independent of Zygor's inset scroll viewport.
	textures.body = slice(scroll, "BACKGROUND", 0, 256, 32, 64)
	textures.body:SetAllPoints()
	textures.paper = slice(border, "ARTWORK", 0, 256, 32, 64)
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

local function layoutPaper(border)
	local profile = _G.ZygorGuidesViewer.db and _G.ZygorGuidesViewer.db.profile
	local paper = art.paper
	paper:ClearAllPoints()
	if profile and profile.resizeup then
		paper:SetPoint("TOP", border, "TOP", 0, -1)
		paper:SetPoint("BOTTOM", border.Toolbar, "TOP")
	else
		paper:SetPoint("TOP", border.Toolbar, "BOTTOM")
		paper:SetPoint("BOTTOM", border, "BOTTOM", 0, 1)
	end
	-- Match the full window width even when the toolbar uses a skin inset.
	paper:SetPoint("LEFT", border, "LEFT", 1, 0)
	paper:SetPoint("RIGHT", border, "RIGHT", -1, 0)
end

-- Zygor repaints the backdrop's vertex colour as steps change. Suppress only
-- the native fill, independently of its colour and the frame's children.
local function suppressBackdrop(region, suppress)
	if not region then return end
	if suppress then
		if backdropVisibility[region] == nil then backdropVisibility[region] = region:IsShown() end
		region:Hide()
	elseif backdropVisibility[region] ~= nil then
		region:SetShown(backdropVisibility[region])
		backdropVisibility[region] = nil
	end
end

local function paintRow(back, r, g, b, a)
	if not selected or not a then return end
	local wax = rowWax[back]
	local isQuest = a > 0 and r > .25 and r > 1.5 * g and r > 1.5 * b
	local isJournal = selected == "Field-Journal"
	if isJournal and isQuest then
		-- The wax replaces the flat colour and sits below line.content.
		back.Center:SetColorTexture(0, 0, 0, 0)
	elseif isQuest and selected == "Glass" then
		back.Center:SetColorTexture(.46, .23, .28, a * .6)
	elseif isQuest then
		back.Center:SetColorTexture(.42, .23, .15, a * .7)
	else
		back.Center:SetColorTexture(r, g, b, a * (isJournal and .22 or .45))
	end
	wax:SetShown(isJournal and isQuest)
end

local function updateJournalInk(line)
	local state = lines[line]
	if selected == "Field-Journal" and line:IsShown() then
		if not state then
			state = {}
			lines[line] = state
		end
		if not state.color then state.color = { line.label:GetTextColor() } end
		local wax = rowWax[line.back]
		local onWax = wax and wax:IsShown()
		local linkColor = onWax and "|cffffde9f" or "|cff123330"
		-- Zygor embeds pale colours directly in tips and item links.
		local displayed = line.label:GetText()
		if not (issecretvalue and issecretvalue(displayed)) and displayed then
			local original = displayed == state.ink and state.original or displayed
			local ink = original:gsub("|c%x%x%x%x%x%x%x%x", linkColor)
			if ink ~= displayed then line.label:SetText(ink) end
			state.original, state.ink = original, ink
		end
		if onWax then
			line.label:SetTextColor(1, 241/255, 220/255, 1)
		else
			line.label:SetTextColor(.15, .09, .04, 1)
		end
	elseif state and state.color then
		local text = line.label:GetText()
		if not (issecretvalue and issecretvalue(text)) and state.ink and text == state.ink and state.original ~= text then
			line.label:SetText(state.original)
		end
		state.original, state.ink = nil, nil
		line.label:SetTextColor(unpack(state.color))
		state.color = nil
	end
end

local function updateLine(line)
	local back = line.back
	if back and back.Center and back.GetBackdropColor and back.SetBackdropColor then
		local wax = rowWax[back]
		if selected then
			if not wax then
				wax = back:CreateTexture(nil, "ARTWORK")
				wax:SetTexture(directory .. "Journal-Wax")
				wax:SetAllPoints(back)
				rowWax[back] = wax
				hooksecurefunc(back, "SetBackdropColor", function(_, ...)
					local wasShown = wax:IsShown()
					paintRow(back, ...)
					if wax:IsShown() ~= wasShown then updateJournalInk(line) end
				end)
			end
			paintRow(back, back:GetBackdropColor())
		elseif wax then
			wax:Hide()
			back.Center:SetColorTexture(back:GetBackdropColor())
		end
	end
	updateJournalInk(line)
end

local function updateStep(step)
	suppressBackdrop(step.Center, selected ~= nil)
	for _, line in ipairs(step.lines) do updateLine(line) end
end

local function watchStep(step)
	if step and step.Render and step.lines then
		if not steps[step] then
			steps[step] = true
			hooksecurefunc(step, "Render", function()
				if selected then updateStep(step) end
			end)
			if step.ApplySkin then
				hooksecurefunc(step, "ApplySkin", function()
					if selected then suppressBackdrop(step.Center, true) end
				end)
			end
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

local function paint()
	if not viewer or (not selected and not art) then return end
	local border = viewer.Border
	if selected and not art then art = buildArt(border, viewer.Controls.Scroll) end
	if art then
		if selected == "Field-Journal" then layoutPaper(border) end
		for key, texture in pairs(art) do
			local shown = selected ~= nil
			if key == "body" then shown = selected == "Forged" end
			if key == "paper" then shown = selected == "Field-Journal" end
			if shown then
				texture:SetTexture(directory .. selected)
				texture:SetAlpha(selected == "Glass" and .55 or 1)
				if key == "panel" and selected == "Glass" then
					texture:SetColorTexture(.05, .115, .15, .68)
					texture:SetVertexColor(1, 1, 1)
					texture:SetAlpha(1)
				elseif key == "panel" then
					local shade = selected == "Field-Journal" and .18 or .88
					texture:SetVertexColor(shade, shade, shade)
				end
			end
			texture:SetShown(shown)
		end
	end
	local replaceCasing = selected == "Glass" or selected == "Field-Journal"
	for _, key in ipairs(backdropPieces) do
		suppressBackdrop(border[key], replaceCasing)
		suppressBackdrop(border.Back[key], replaceCasing)
	end
	for _, step in ipairs(viewer.stepframes or {}) do
		if not steps[step] then watchStep(step) end
	end
	-- Pooled steps can be inactive while changing skins.
	for step in pairs(steps) do updateStep(step) end
	updateTab()
end

function Skin:Refresh()
	local zgv = _G.ZygorGuidesViewer
	local frame = zgv and zgv.Frame
	if not frame or not frame.Border or not frame.Border.TitleBar or
		not frame.Border.Toolbar or not frame.Border.Back or not frame.Controls or not frame.Controls.Scroll
		or not frame.ApplySkin or not frame.AddStep then return end
	if viewer ~= frame then
		viewer = frame
		hooksecurefunc(frame, "ApplySkin", paint)
		if frame.AlignFrame then hooksecurefunc(frame, "AlignFrame", paint) end
		hooksecurefunc(frame, "AddStep", function()
			if selected then watchStep(frame.stepframes[#frame.stepframes]) end
		end)
		if zgv.Tabs and zgv.Tabs.SetAsCurrent then hooksecurefunc(zgv.Tabs, "SetAsCurrent", updateTab) end
	end
	local previous = selected
	local choice = ns.db.char.zygorSkin
	selected = accents[choice] and choice or nil
	if selected or previous then paint() end
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

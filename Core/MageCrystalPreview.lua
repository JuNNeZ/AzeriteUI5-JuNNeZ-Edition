-- Opt-in, cross-class crystal artwork test. Native fill and geometry stay owned
-- by Player.lua; character settings are restored by disabling and reloading.
local Addon, ns = ...
local Preview = ns:NewModule("MageCrystalPreview", "AceConsole-3.0", "LibMoreEvents-1.0")
ns.MageCrystalPreview = Preview
-- The moving energy: one atlas per school, built by Tools/Build-MageEnergyAtlas.py
-- from the approved 128-frame source (eight 2048px pages per school, 398 MB,
-- kept in Assets_Draft/MageCrystalEnergy). Each frame is cut to the crystal's
-- texcoord crop plus a 4/255 margin and packed in rows of 18 cells, 110x128,
-- on a 2048x1024 page: 8 MB per school, every frame kept. ENERGY must match
-- what the build script prints. False draws the static pattern instead.
Preview.EnergyAvailable = true
local ENERGY = { frames = 128, fps = 16, columns = 18, cellW = 110, cellH = 128, pageW = 2048, pageH = 1024,
	crop = { 46/255, 210/255, 33/255, 223/255 } }
local schools = { arcane = { .72, .48, 1 }, fire = { 1, .48, .12 }, frost = { .40, .80, 1 } }
local function Path(name)
	return "Interface\\AddOns\\"..Addon.."\\Assets\\MageCrystalTest\\"..name..".tga"
end

local function ClampSpeed(value)
	value = tonumber(value)
	if (not value or value ~= value) then return .4 end
	return math.max(.1, math.min(2, value))
end

function Preview:GetEffectStrength()
	local value=tonumber(ns.db.char.mageCrystalStrength)
	return value and value==value and math.max(0,math.min(1,value)) or .7
end
function Preview:SetEffectStrength(value)
	if (InCombatLockdown()) then return end
	value=tonumber(value);if (not value or value~=value) then return end
	ns.db.char.mageCrystalStrength=math.max(0,math.min(1,value))
	if (ns.ThemeEffects) then ns.ThemeEffects:Refresh() end
end
function Preview:SetParticles(enabled)
	if (InCombatLockdown()) then return end
	ns.db.char.mageCrystalParticles=enabled and true or false
	if (ns.ThemeEffects) then ns.ThemeEffects:Refresh() end
end
function Preview:GetSchoolChoice()
	local char=ns.db.char
	return (char.mageSchoolAuto==true or (char.mageSchoolAuto==nil and not char.mageCrystalSchool)) and "auto" or self:GetSchool()
end

function Preview:GetFireSpeed()
	return self.fireSpeed or ClampSpeed(ns.db.char.mageCrystalFireSpeed)
end

function Preview:SetFireSpeed(value)
	if (InCombatLockdown()) then return end
	self.fireSpeed = ClampSpeed(value)
	ns.db.char.mageCrystalFireSpeed = self.fireSpeed
	if (self.speedHint) then
		self.speedHint:SetText(string.format("%.1fs loop | Changes apply live", 8 / self.fireSpeed))
	end
end

local speedKeys = { fire = "mageCrystalFireSpeed", frost = "mageCrystalFrostSpeed", arcane = "mageCrystalArcaneSpeed" }
function Preview:GetSchool()
	local char=ns.db.char
	if (char.mageSchoolAuto==true or (char.mageSchoolAuto==nil and not char.mageCrystalSchool)) then
		if (ns.PlayerClass=="MAGE") then
			local get=(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
			local info=(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
			local index=get and get();local id=index and info and info(index)
			local school=({[62]="arcane",[63]="fire",[64]="frost"})[id]
			if (school) then return school end
		end
	end
	return schools[char.mageCrystalSchool] and char.mageCrystalSchool or "arcane"
end
function Preview:GetSchoolSpeed(school)
	school = school or self:GetSchool()
	if (school == "fire") then return self:GetFireSpeed() end
	return ClampSpeed(ns.db.char[speedKeys[school]])
end
function Preview:SetSchoolSpeed(value, school)
	if (InCombatLockdown()) then return end
	school = school or self:GetSchool()
	if (school == "fire") then self:SetFireSpeed(value)
	else ns.db.char[speedKeys[school]] = ClampSpeed(value) end
	if (self.speedHint) then
		self.speedHint:SetText(string.format("%.1fs loop | Changes apply live", 8 / self:GetSchoolSpeed()))
	end
end

function Preview:ShowSpeedControls()
	if (InCombatLockdown()) then self:Print("Open the speed controls outside combat."); return end
	if (self.speedPanel and self.speedPanel:IsShown()) then self.speedPanel:Hide(); return end
	if (not self.speedPanel) then
		local Kit = ns.OptionsKit
		local AceGUI = LibStub("AceGUI-3.0", true)
		if (not Kit or not AceGUI) then self:Print("AzeriteUI options controls are not ready."); return end
		local name = ns.Prefix.."MageCrystalSpeed"
		local panel = CreateFrame("Frame", name, UIParent, ns.BackdropTemplate)
		panel:SetSize(370, 188)
		panel:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
		panel:SetFrameStrata("DIALOG")
		panel:SetClampedToScreen(true)
		panel:EnableMouse(true)
		panel:SetMovable(true)
		panel:RegisterForDrag("LeftButton")
		panel:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
		panel:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
		panel:SetBackdrop(Kit.WindowBackdrop)
		UISpecialFrames[#UISpecialFrames + 1] = name
		local title = panel:CreateFontString(nil, "OVERLAY")
		title:SetFontObject(Kit.GetFont(16, true))
		title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -18)
		self.speedTitle = title
		local slider = AceGUI:Create(Kit.Prefix.."Slider")
		slider.frame:SetParent(panel)
		slider.frame:ClearAllPoints()
		slider.frame:Show()
		slider.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -54)
		slider:SetWidth(330)
		slider:SetLabel("Speed (100% = 8s loop)")
		slider:SetSliderValues(.1, 2, .05)
		slider:SetIsPercent(true)
		slider:SetCallback("OnValueChanged", function(_, _, value) self:SetSchoolSpeed(value) end)
		local hint = panel:CreateFontString(nil, "OVERLAY")
		hint:SetFontObject(Kit.GetFont(12))
		hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -116)
		self.speedHint = hint
		local footer = panel:CreateFontString(nil, "OVERLAY")
		footer:SetFontObject(Kit.GetFont(11))
		footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 20)
		footer:SetText("Selected school + flow must be on | Esc to close")
		self.speedPanel, self.speedSlider = panel, slider
	end
	local school = self:GetSchool()
	self.speedTitle:SetText("Mage crystal | "..school:sub(1, 1):upper()..school:sub(2).." speed")
	self:SetSchoolSpeed(self:GetSchoolSpeed())
	self.speedSlider:SetValue(self:GetSchoolSpeed())
	self.speedPanel:Show()
end

-- Core/ThemeEffects.lua decides: the Mage theme, or the Mage crystal picked
-- under Lite+ on any theme. Both are drawn only over the main layout.
function Preview:IsActive()
	local effects = ns.ThemeEffects
	return effects and effects:GetCrystalEffect() == "mage" or false
end

-- The crystal's crop (coords, 0-1 of the source frame) is mapped into the
-- frame's cell. It is clamped to the baked crop, so no cell ever samples its
-- neighbour; the default crop sits a few texels inside every cell edge.
local function AtlasCoords(texture, index, coords)
	local crop = ENERGY.crop
	local column, row = index % ENERGY.columns, math.floor(index / ENERGY.columns)
	local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
	local function u(value)
		value = clamp(value, crop[1], crop[2])
		return (column + (value - crop[1])/(crop[2] - crop[1]))*ENERGY.cellW/ENERGY.pageW
	end
	local function v(value)
		value = clamp(value, crop[3], crop[4])
		return (row + (value - crop[3])/(crop[4] - crop[3]))*ENERGY.cellH/ENERGY.pageH
	end
	texture:SetTexCoord(u(coords[1]), u(coords[2]), v(coords[3]), v(coords[4]))
end

-- Both crossfade layers stay bound to the school's single atlas. Playback only
-- moves texcoords; a visible texture's file is never swapped, not even at the
-- loop boundary. The file changes only with the school.
local function PrepareEnergyPages(content, power, school, animated)
	for _, art in ipairs({ content.Flow, content.FlowNext }) do
		if (animated and content.PageSchool ~= school) then
			art:SetTexture(Path(school.."-energy"))
		end
		art:SetVertexColor(1, 1, 1)
		art:SetShown(animated)
		art:SetAlpha(0)
	end
	if (animated) then content.PageSchool = school end
end

local function SetFlowFrame(frame, texture, index)
	AtlasCoords(texture, index % ENERGY.frames, frame.Coords)
end

-- Crossfade neighboring atlas samples at the client's render rate. Both
-- layers share the native mask and fill clip; no resource sampling.
local function UpdateFlow(frame)
	if (not frame.Energy) then frame.Flow:SetAlpha(0); frame.FlowNext:SetAlpha(0); return end
	local phase = frame.Time * ENERGY.fps
	local index = math.floor(phase)
	local blend = phase - index
	if (index ~= frame.Index) then
		frame.Index = index
		SetFlowFrame(frame, frame.Flow, index)
		SetFlowFrame(frame, frame.FlowNext, (index + 1) % ENERGY.frames)
	end
	local strength = Preview:GetEffectStrength()
	frame.Flow:SetAlpha(strength * (1 - blend))
	frame.FlowNext:SetAlpha(strength * blend)
end

-- Reuse the shipped small gem as a hot core and the existing cast spark as
-- a soft halo. Each sprite uses the full crystal mask and native fill clip.
local function EnsureEmbers(content, power)
	if (content.Embers) then return end
	content.Embers, content.EmberAnchor = {}, power
	for i = 1, 8 do
		local near = i > 4
		local ember = { Life = (i * .381966) % 1, Seed = i,
			Rate = 1 / (near and (4 + i * .18) or (7 + i * .31)),
			Size = near and (3.2 + i * .15) or (1.7 + i * .12),
			Opacity = near and .8 or .36 }
		for _, key in ipairs({ "Glow", "Core" }) do
			local art = content:CreateTexture(nil, "ARTWORK", nil, 2)
			art:SetBlendMode("ADD")
			art:AddMaskTexture(content.Mask)
			if (key == "Core") then
				art:SetTexture("Interface\\AddOns\\"..Addon.."\\Assets\\point_gem.tga")
				art:SetVertexColor(1, near and .8 or .42, near and .3 or .06)
			else
				art:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
				art:SetTexCoord(0, 1, 11/32, 20/32)
				art:SetVertexColor(1, .38, .04)
			end
			ember[key] = art
		end
		content.Embers[i] = ember
	end
end

local function UpdateEmbers(content, elapsed)
	if (not content.Embers) then return end
	local anchor = content.EmberAnchor
	-- These dimensions belong to our fixed-size UI frame, not unit resources.
	local width, height = anchor:GetWidth(), anchor:GetHeight()
	local scale = width / 196
	local speed = .45 + .55 * Preview:GetSchoolSpeed(content.School)
	for _, ember in ipairs(content.Embers) do
		for _, key in ipairs({ "Glow", "Core" }) do ember[key]:SetShown(content.Energy and ns.db.char.mageCrystalParticles ~= false) end
		if (content.Energy and ns.db.char.mageCrystalParticles ~= false) then
			ember.Life = (ember.Life + elapsed * ember.Rate * speed) % 1
			local phase, seed = ember.Life, ember.Seed
			local x = .24 + .5 * ((seed * .618034) % 1)
			x = x + .055 * math.sin(phase * math.pi * 3 + seed)
				+ .025 * math.sin(phase * math.pi * 7 + seed * 2)
			local y = .08 + phase * .86
			if (content.School == "frost") then
				x = .5 + .24 * math.sin(phase * math.pi * 2 + seed)
				y = .87 - phase * .72
			elseif (content.School == "arcane") then
				local angle = phase * math.pi * 2 + seed
				local radius = .12 + .15 * ((seed * .618034) % 1)
				x = .5 + radius * math.cos(angle)
				y = .48 + radius * 1.3 * math.sin(angle)
			end
			local fade = math.sin(math.pi * phase) ^ 2
			local shimmer = .8 + .2 * math.sin(phase * math.pi * 9 + seed)
			for _, key in ipairs({ "Glow", "Core" }) do
				local art, halo = ember[key], key == "Glow"
				art:ClearAllPoints()
				art:SetPoint("CENTER", anchor, "BOTTOMLEFT", x * width, y * height)
				art:SetSize(ember.Size * scale * (halo and 2.4 or 1),
					ember.Size * scale * (halo and 1.8 or 1.2))
				art:SetAlpha(math.min(1, fade * shimmer * ember.Opacity * (halo and .3 or 1) * Preview:GetEffectStrength()/.7))
			end
		end
	end
end

function Preview:StyleCrystal(power, texturePath, coords, casePath)
	if (not self:IsActive()) then
		if (power.MageCrystalArt) then power.MageCrystalArt:Hide() end
		if (power.MageCrystalCaseFrame) then
			power.Case:SetParent(power)
			power.MageCrystalCaseFrame:Hide()
		end
		return
	end
	local school = self:GetSchool()
	local animated = ns.db.char.mageCrystalFlow ~= false and Preview.EnergyAvailable == true
	local low = type(casePath) == "string" and casePath:find("_low", 1, true)
	local caseName=low and "pw_crystal_case_low" or "pw_crystal_case"
	local themed=ns.MageTheme and ns.MageTheme:ResolveMedia(caseName)
	power.Case:SetTexture(themed or Path(caseName))
	power.Case:SetVertexColor(1, 1, 1, 1)
	local content = power.MageCrystalArt
	if (not content) then
		local clip = CreateFrame("Frame", nil, power)
		clip:SetFrameLevel(power:GetFrameLevel() + 1)
		clip:EnableMouse(false)
		clip:SetClipsChildren(true)
		clip:SetPoint("BOTTOMLEFT", power, "BOTTOMLEFT")
		clip:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT")
		clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")
		content = CreateFrame("Frame", nil, clip)
		content:EnableMouse(false)
		content:SetAllPoints(power)
		content.Mask = content:CreateMaskTexture()
		content.Mask:SetAllPoints(power)
		for _, key in ipairs({ "Pattern", "Flow", "FlowNext" }) do
			local art = content:CreateTexture(nil, "ARTWORK", nil, 1)
			art:SetAllPoints(power)
			art:AddMaskTexture(content.Mask)
			art:SetAlpha(key == "Pattern" and .65 or 0)
			if (key ~= "Pattern") then art:SetBlendMode("ADD") end
			content[key] = art
		end
		content.Clip = clip
		power.MageCrystalArt = content
	end
	-- Frame level wins over texture draw layer. Keep the un-clipped case
	-- above both the clipped energy frame and its particle textures.
	content.Clip:SetFrameLevel(power:GetFrameLevel() + 1)
	content:SetFrameLevel(power:GetFrameLevel() + 2)
	local foreground = power.MageCrystalCaseFrame
	if (not foreground) then
		foreground = CreateFrame("Frame", nil, power)
		foreground:EnableMouse(false)
		foreground:SetAllPoints(power)
		power.MageCrystalCaseFrame = foreground
	end
	foreground:SetFrameLevel(content:GetFrameLevel() + 1)
	if (power.Case:GetParent() ~= foreground) then power.Case:SetParent(foreground) end
	foreground:Show()
	content.Clip:ClearAllPoints()
	content.Clip:SetPoint("BOTTOMLEFT", power, "BOTTOMLEFT")
	content.Clip:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT")
	content.Clip:SetPoint("TOP", power:GetStatusBarTexture(), "TOP")
	content.Mask:SetTexture(texturePath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	content.Coords = coords or { 0, 1, 0, 1 }
	content.Mask:SetTexCoord(unpack(content.Coords))
	content.Pattern:SetTexture(Path("crystal-"..school.."-pattern"))
	content.Pattern:SetTexCoord(unpack(content.Coords))
	content.Pattern:SetVertexColor(unpack(schools[school]))
	local energy = animated
	if (content.Energy ~= energy or content.School ~= school) then
		content.Time, content.Index = 0, 0
	end
	content.Energy, content.School = energy, school
	if (energy) then
		EnsureEmbers(content, power)
		if (content.ParticleSchool ~= school) then
			for i, ember in ipairs(content.Embers) do
				if (school == "fire") then
					ember.Core:SetVertexColor(1, i > 4 and .8 or .42, i > 4 and .3 or .06)
					ember.Glow:SetVertexColor(1, .38, .04)
				elseif (school == "frost") then
					ember.Core:SetVertexColor(.65, .9, 1)
					ember.Glow:SetVertexColor(.2, .65, 1)
				else
					ember.Core:SetVertexColor(.88, .65, 1)
					ember.Glow:SetVertexColor(.65, .25, 1)
				end
			end
			content.ParticleSchool = school
		end
	end
	UpdateEmbers(content, 0)
	-- Each school replaces glowing facet lines with moving volume; the
	-- native crystal below remains readable. Static retains the prior pattern.
	content.Pattern:SetAlpha((energy and .12 or .65)*self:GetEffectStrength()/.7)
	for _, art in ipairs({ content.Flow, content.FlowNext }) do
		if (energy) then
			art:SetVertexColor(1, 1, 1)
		else
			art:SetVertexColor(unpack(schools[school]))
		end
		art:SetShown(animated)
	end
	-- Player's general PostUpdate restyles textures. Keep elapsed phase across
	-- those updates so frequent resource events cannot pin the atlas at frame 0.
	content.Time, content.Index = content.Time or 0, content.Index or 0
	PrepareEnergyPages(content, power, school, animated)
	SetFlowFrame(content, content.Flow, content.Index)
	SetFlowFrame(content, content.FlowNext, (content.Index + 1) % ENERGY.frames)
	UpdateFlow(content)
	content:SetScript("OnUpdate", animated and function(frame, elapsed)
		-- Only local elapsed time is used; never read or compare unit resources.
		local speed = frame.Energy and Preview:GetSchoolSpeed(frame.School) or 1
		frame.Time = (frame.Time + elapsed * speed) % 8
		UpdateEmbers(frame, elapsed)
		UpdateFlow(frame)
	end or nil)
	content:Show()
end

function Preview:Command(input)
	local arg = (input or ""):lower():match("^%s*(.-)%s*$")
	if (arg == "speed") then self:ShowSpeedControls(); return end
	if (arg == "status") then
		self:Print("Mage crystal: "..(self:IsActive() and "on" or "off").."; "..
			self:GetSchool().."; "..
			(ns.db.char.mageCrystalFlow == false and "static" or "flow")..
			string.format("; speed %.2fx.", self:GetSchoolSpeed()))
		return
	end
	if (arg ~= "" and arg ~= "on" and arg ~= "off" and arg ~= "toggle"
		and arg ~= "static" and arg ~= "flow" and arg ~= "auto" and not schools[arg]) then
		self:Print("/azmagecrystal [on|off|auto|arcane|fire|frost|static|flow|toggle|status|speed]")
		return
	end
	if (InCombatLockdown()) then self:Print("Change the crystal test outside combat."); return end
	local effects = ns.ThemeEffects
	if (not effects) then return end
	local enabled = arg ~= "off"
	if (arg == "" or arg == "toggle") then enabled = not self:IsActive() end
	-- Refuse before changing anything, as the crystal cannot show here.
	if (enabled and not effects:IsMainLayout()) then
		self:Print("Select the main AzeriteUI layout before enabling this crystal test.")
		return
	end
	if (schools[arg]) then ns.db.char.mageCrystalSchool = arg; ns.db.char.mageSchoolAuto=false end
	if (arg=="auto") then ns.db.char.mageSchoolAuto=true end
	if (arg == "static" or arg == "flow") then ns.db.char.mageCrystalFlow = arg == "flow" end
	if (arg == "flow" and not self.EnergyAvailable) then
		self:Print("The moving energy is a work in progress and not in this release; the crystal stays static.")
	end
	-- Everything here is drawn per crystal, so nothing reloads. The crystal is
	-- the Mage theme's own effect; on any other theme it is a Lite+ choice.
	if (enabled and not self:IsActive()) then
		if (effects:GetTheme() == "mage") then effects:SetCrystalChoice("theme")
		else effects:SetCrystalChoice("mage", true) end
		return
	end
	if (not enabled) then
		if (effects:GetCrystalChoice() == "mage") then effects:SetCrystalChoice("theme") end
		if (self:IsActive()) then effects:SetCrystalChoice("none", true) end
		return
	end
	effects:Refresh()
end

-- A profile change can change the layout variant, which turns the crystal on
-- or off; it is redrawn either way.
function Preview:ProfileChanged()
	if (InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "ProfileChanged")
	if (ns.ThemeEffects) then ns.ThemeEffects:Refresh() end
end

function Preview:OnInitialize()
	-- Before the Mage theme, the crystal had its own switch. It is now the
	-- Mage crystal picked under Lite+, which draws it on any theme.
	if (ns.db.char.mageCrystalTest) then
		ns.db.char.themeLitePlus, ns.db.char.themeCrystalEffect = true, "mage"
	end
	ns.db.char.mageCrystalTest = nil
	self.fireSpeed = ClampSpeed(ns.db.char.mageCrystalFireSpeed)
	self:RegisterChatCommand("azmagecrystal", "Command")
end

function Preview:OnEnable()
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "ProfileChanged")
	for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
		ns.db.RegisterCallback(self, event, "ProfileChanged")
	end
end

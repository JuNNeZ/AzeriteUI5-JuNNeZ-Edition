-- Cosmetic proc state, option writes/reset and the actual visibility driver.
-- Plain Lua 5.1; does not emulate rendering, protected frames or live procs.
local root = arg[1] or "."
local checks = 0
local function check(value, label)
	checks = checks + 1
	assert(value, label)
end
local function load(path, ns, env)
	local file = assert(io.open(root.."/"..path, "rb"))
	local source = file:read("*a"); file:close()
	-- Deliberately break one behaviour in memory to prove these checks detect it.
	if arg[2] == "ring-always-shown" and path:find("ProcHighlight.lua",1,true) then
		source = source:gsub('alert.ring:SetShown%(style == "current" or style == "outline" or style == "both"%)', 'alert.ring:SetShown(true)')
	elseif arg[2] == "show-after-restyle" and path:find("ProcHighlight.lua",1,true) then
		source = source:gsub('profile = profile or {}', 'alert:Show(); profile = profile or {}')
	elseif arg[2] == "no-neutral-colour" and path:find("ProcHighlight.lua",1,true) then
		source = source:gsub('source == "custom"', 'source == "disabled"')
	elseif arg[2] == "preview-reallocated" and path:find("ProcHighlight.lua",1,true) then
		source = source:gsub('if %(not Highlight.preview%) then', 'if (true) then')
	elseif arg[2] == "wrong-visibility-setting" and path == "Options/OptionsPages/ActionBars.lua" then
		source = source:gsub('setvisibility%(info, "dragon", val%)', 'setvisibility(info, "mounted", val)')
	elseif arg[2] == "skyriding-always-hidden" and path == "Components/ActionBars/Prototypes/ActionBar.lua" then
		source = source:gsub('if %(config.visibility.dragon%) then', 'if (false) then')
	end
	local chunk = assert(loadstring(source, "@"..root.."/"..path))
	if env then setfenv(chunk, env) end
	chunk("AzeriteUI5_JuNNeZ_Edition", ns)
end
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetPoint(...) self.point = {...} end
function methods:SetAllPoints() end
function methods:SetFrameLevel(n) self.level = n end
function methods:GetFrameLevel() return self.level or 3 end
function methods:EnableMouse() end
function methods:SetWidth(width) self.width = width end
function methods:SetText(text) self.text = text end
function methods:SetMask(mask) self.mask = mask end
function methods:GetName() return self.name end
function methods:SetFrameStrata() end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:SetClampedToScreen() end
function methods:SetMovable() end
function methods:RegisterForDrag() end
function methods:StartMoving() end
function methods:StopMovingOrSizing() end
function methods:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetVertexColor(...) self.color = {...} end
function methods:SetBlendMode(mode) self.blend = mode end
local function object(parent)
	return setmetatable({ parent = parent, shown = true }, { __index = methods })
end
function methods:CreateTexture() return object(self) end
function methods:CreateFontString() return object(self) end
local created = 0
local env = setmetatable({ CreateFrame = function(_, name, parent) created = created + 1; local f = object(parent); f.name = name; return f end,
	LibStub = function() return { GetLocale = function() return setmetatable({}, { __index = function(_, k) return k end }) end } end }, { __index = _G })
local ns = { API = { GetMedia = function(key) return key end }, PlayerClass = "HUNTER", Colors = { class = { HUNTER = {.2, .8, .3} } } }
load("Core/API/Tables.lua", ns, env)
load("Components/ActionBars/Elements/ProcHighlight.lua", ns, env)
local H = ns.ActionBarProcHighlight
local db = { ButtonSpellHighlightSize = {134,134}, ButtonSpellHighlightPosition = {"CENTER",0,0}, ButtonSpellHighlightTexture = "original-ring" }
local parent = object()
local alert = H.Create(parent, db)
H.Apply(alert, H.defaults)
check(not alert:IsShown(), "styling must not activate a proc")
check(alert.ring.texture == "original-ring", "default preserves original art")
check(alert.ring.color[1] == 249/255 and alert.ring.color[4] == .75, "original tint and opacity")
alert:Show()
for _, style in ipairs({"current", "outline", "glow", "both", "off"}) do
	for _, width in ipairs({"thin", "medium", "thick"}) do
		for _, source in ipairs({"gold", "class", "custom"}) do
			local p = ns:Copy(H.defaults)
			p.procHighlightStyle, p.procHighlightThickness, p.procHighlightColorSource = style, width, source
			p.procHighlightColor = {.1,.2,.9}
			H.Apply(alert, p)
			check(alert:IsShown(), "restyling preserves active state")
			check(alert.ring:IsShown() == (style == "current" or style == "outline" or style == "both"), "ring selection")
			check(alert.halo:IsShown() == (style == "glow" or style == "both"), "glow selection")
			local wanted = source == "class" and .2 or source == "custom" and .1 or 249/255
			check(alert.ring.color[1] == wanted and alert.halo.color[1] == wanted, "both layers use chosen colour")
			if not (style == "current" and source == "gold") then
				check(alert.ring.texture == "actionbutton-proc-outline-"..(style == "current" and "thin" or width), "neutral ring thickness")
			end
		end
	end
end
alert:Hide(); H.Apply(alert, H.defaults)
check(not alert.ring:IsVisible() and not alert.halo:IsVisible(), "LAB hide hides every layer")
alert:Show(); parent:Hide()
check(not alert.ring:IsVisible(), "parent bar visibility is inherited")
parent:Show()
H.Apply(alert, {procHighlightStyle = "bogus", procHighlightThickness = "bogus", procHighlightColorSource = "bogus", procHighlightOpacity = "bogus"})
check(alert.ring.texture == "original-ring" and alert.ring.color[4] == .75, "invalid saved settings fall back")
H.Apply(alert, {procHighlightStyle="both",procHighlightColorSource="custom",procHighlightColor={-1,2,0/0},procHighlightOpacity=2})
check(alert.ring.color[1] == 0 and alert.ring.color[2] == 1 and alert.ring.color[3] == 65/255 and alert.ring.color[4] == 1, "channels clamp and NaN falls back")
alert:SetTexture("external-art"); alert:SetVertexColor(.5,.4,.3,.2)
check(alert.ring.texture == "external-art" and alert.halo.color[4] == .2, "LAB public texture/colour methods supported")

ns.Prefix = "AzeriteUI"
ns.GetConfig = function() return db end
env.UIParent, env.UISpecialFrames = object(), {}
for _, key in ipairs({"Size","BackdropSize","IconSize","BorderSize"}) do db["Button"..key] = {64,64} end
for _, key in ipairs({"BackdropPosition","IconPosition","BorderPosition"}) do db["Button"..key] = {"CENTER",0,0} end
db.ButtonBackdropColor, db.ButtonBorderColor = {1,1,1,1}, {1,1,1,1}
db.ButtonMaskTexture = "mask"
H.Preview(H.defaults)
local preview = H.preview
check(preview:IsShown() and preview.alert:IsShown(), "isolated preview opens")
local allocationCount = created
H.Preview({procHighlightStyle="both"})
check(H.preview == preview and created == allocationCount, "preview reuses its window and textures")
check(preview.alert.ring:IsVisible() and preview.alert.halo:IsVisible(), "preview uses same styling")
H.UpdatePreview({procHighlightStyle="off"})
check(not preview.alert.ring:IsVisible() and not preview.alert.halo:IsVisible(), "preview updates live without inventing a proc")
preview:Hide()
check(not preview.alert:IsVisible() and #env.UISpecialFrames == 1, "preview closes and is Escape-dismissable")

-- Real module registration merges cosmetic defaults with its profile defaults.
local runtime = {}
local runtimeNS = { API={IsAddOnEnabled=function() return false end,GetMedia=ns.API.GetMedia,GetEffectiveScale=function() return 1 end},
	Colors=ns.Colors,Widgets={RegisterCooldown=function() end},MovableModulePrototype={defaults={enabled=true}},
	ActionBar={defaults={}},
	ActionBarProcHighlight=H,NewModule=function() return runtime end }
load("Core/API/Tables.lua",runtimeNS,env)
env.BOTTOMLEFT_ACTIONBAR_PAGE,env.BOTTOMRIGHT_ACTIONBAR_PAGE,env.RIGHT_ACTIONBAR_PAGE,env.LEFT_ACTIONBAR_PAGE=6,5,4,3
load("Components/ActionBars/Elements/ActionBars.lua",runtimeNS,env)
local realDefaults = runtime:GetDefaults().profile
check(realDefaults.enabled and realDefaults.procHighlightStyle == "current" and realDefaults.procHighlightOpacity == .75, "real module carries both inherited and proc defaults")

-- Build and exercise the real options closures against a real-shaped profile.
local module = { db = {profile = ns:Copy(H.defaults)}, bars = {} }
module.db.profile.bars = {}
for i=1,8 do module.bars[i] = {}; module.db.profile.bars[i] = {enabled=true, visibility={mounted=true, dragon=i==1}} end
function module:IsEnabled() return true end
function module:UpdateSettings() self.updates = (self.updates or 0) + 1 end
local optionsModule = { AddGroup = function(self, _, generator) self.options = generator() end }
function ns:GetModule(name) return name == "Options" and optionsModule or name == "ActionBars" and module or nil end
function ns:Fire() end
ns.IsRetail = true
env.GetNumShapeshiftForms = function() return 0 end
env.CreateFrame = function() return {RegisterEvent=function() end,SetScript=function() end} end
load("Options/OptionsPages/ActionBars.lua", ns, env)
local options = optionsModule.options
local proc = options.args.procHighlight.args
for _, key in ipairs({"procHighlightStyle","procHighlightThickness","procHighlightColorSource","procHighlightOpacity"}) do
	check(proc[key].get({"procHighlight",key}) == H.defaults[key], "option defaults: "..key)
end
proc.procHighlightStyle.set({"procHighlight","procHighlightStyle"}, "both")
check(module.db.profile.procHighlightStyle == "both" and module.updates == 1, "style written to profile and applied")
proc.procHighlightColor.set(nil, .1,.2,.3)
proc.procHighlightColor.set(nil, H.defaults.procHighlightColor)
check(module.db.profile.procHighlightColor[1] == 249/255, "colour gem revert accepts table")
module.db.profile.procHighlightColor = {0/0, 2, -1}
local red, green, blue = proc.procHighlightColor.get()
check(red == 249/255 and green == 1 and blue == 0, "colour picker also sanitizes saved channels")
proc.reset.func()
check(module.db.profile.procHighlightStyle == "current", "reset restores style")
module.db.profile.procHighlightColor[1] = 0
check(H.defaults.procHighlightColor[1] == 249/255, "reset never aliases default colour")
for i=1,8 do
	local opt = options.args["bar"..i].args.showWhileSkyriding
	check(opt.hidden({"bar"..i,"showWhileSkyriding"}) == (i==1), "skyriding toggle only secondary bars")
end
local toggle = options.args.bar2.args.showWhileSkyriding
toggle.set({"bar2","showWhileSkyriding"}, true)
check(module.db.profile.bars[2].visibility.dragon and module.db.profile.bars[2].visibility.mounted, "skyriding writes its own setting")
ns.IsRetail = false
check(toggle.hidden({"bar2","showWhileSkyriding"}), "Forever has no skyriding toggle")

-- Evaluate the generated driver's first matching condition, including precedence.
for _, snippets in ipairs({true,false}) do
	local drivers = {}
	local visenv = setmetatable({InCombatLockdown=function() return false end, LibStub=function() return {} end,
		BOTTOMLEFT_ACTIONBAR_PAGE=6,BOTTOMRIGHT_ACTIONBAR_PAGE=5,RIGHT_ACTIONBAR_PAGE=4,LEFT_ACTIONBAR_PAGE=3,
		RegisterStateDriver=function(frame,key,driver) drivers[key]=driver end, UnregisterStateDriver=function() end}, {__index=_G})
	local visns = {HasSecureSnippets=snippets,IsRetail=true,PlayerClass="HUNTER",ButtonBar={prototype={},defaults={}},
		API={GetEffectiveScale=function() return 1 end,RegisterVisibilityDriver=function(_,driver) drivers.visibility=driver end}}
	load("Core/API/Tables.lua",visns,visenv)
	load("Components/ActionBars/Prototypes/ActionBar.lua",visns,visenv)
	local bar = setmetatable({config={enabled=true,visibility={}},SetAttribute=function() end}, {__index=visns.ActionBar.prototype})
	local function evaluate(driver, states)
		for clause in driver:gmatch("[^;]+") do
			local condition, result = clause:match("%[(.-)%](%a+)")
			if not condition then return clause end
			if states[condition] then return result end
		end
	end
	for _, mounted in ipairs({true,false}) do
		for _, dragon in ipairs({true,false}) do
			bar.config.visibility = {mounted=mounted,dragon=dragon}
			bar:UpdateVisibilityDriver()
			local driver = drivers[snippets and "vis" or "visibility"]
			check(evaluate(driver,{mounted=true}) == (mounted and "show" or "hide"), "ordinary mount independent")
			check(evaluate(driver,{mounted=true,["bonusbar:5"]=true}) == (dragon and "show" or "hide"), "skyriding independent")
			check(evaluate(driver,{mounted=true,["bonusbar:5"]=true,vehicleui=true}) == "hide", "vehicle wins")
			check(evaluate(driver,{mounted=true,["bonusbar:5"]=true,possessbar=true}) == "hide", "possession wins")
			check(evaluate(driver,{petbattle=true}) == "hide", "pet battle stays hidden")
		end
	end
end
print("Proc highlight / riding: "..checks.." checks passed")

--[[

	The MIT License (MIT)

	Copyright (c) 2026 Jonas "JuNNeZ" Andersen (JuNNeZ Edition modifications)

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local _, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale((...))

local Options = ns:GetModule("Options")

-- Core/ThemeEffects.lua owns the choice of theme and of the crystal and orb
-- effects; Core/HunterTheme.lua, Core/PaladinTheme.lua, Core/MageTheme.lua and
-- Core/MageCrystalPreview.lua own each theme's own settings. Everything is
-- per character (ns.db.char), so no profile defaults are bound here.
-- A theme's settings show only while that theme is in use. With Lite+ on, the
-- crystal and orb effects can come from another theme, and the settings of
-- whichever effects are in use show too. Switching theme reloads, as each
-- theme rebuilds the frame layouts; everything else applies at once.

local ClassName = function(token, fallback)
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	return names and names[token] or fallback
end

-- Proper names of the bows each endcap is drawn after; not translated.
local ENDCAP_NAMES = {
	thasdorah = "Thas'dorah", talonclaw = "Talonclaw", titanstrike = "Titanstrike",
	thoridal = "Thori'dal", raeshalare = "Rae'shalare", none = _G.NONE or "None"
}
local ENDCAP_ORDER = { "thasdorah", "talonclaw", "titanstrike", "thoridal", "raeshalare", "none" }

-- The Mage staves; "school" follows the crystal's school.
local MAGE_ENDCAP_NAMES = {
	aluneth = "Aluneth", felomelorn = "Felo'melorn", ebonchill = "Ebonchill",
	atiesh = "Atiesh", dragonwrath = "Dragonwrath", none = _G.NONE or "None"
}
local MAGE_ENDCAP_ORDER = { "school", "aluneth", "felomelorn", "ebonchill", "atiesh", "dragonwrath", "none" }

local Effects = function() return ns.ThemeEffects end
local Theme = function() return Effects() and Effects():GetTheme() end

-- Names shared by the theme and effect lists. "none" is Blizzard's own word.
local Label = function(key)
	if (key == "azerite") then return "AzeriteUI" end
	if (key == "hunter") then return ClassName("HUNTER", "Hunter") end
	if (key == "paladin") then return ClassName("PALADIN", "Paladin") end
	if (key == "mage") then return ClassName("MAGE", "Mage") end
	if (key == "theme") then return L["The theme's own"] end
	return _G.NONE or "None"
end

-- Every theme but AzeriteUI's own is still a work in progress.
local WIP = function(key, label)
	return key ~= "azerite" and key ~= "theme" and key ~= "none" and label.." (WIP)" or label
end

local List = function(keys, withTheme)
	local values, sorting = {}, {}
	if (withTheme) then values.theme = Label("theme"); sorting[1] = "theme" end
	for _, key in ipairs(keys) do
		-- Paladin is a Development Mode preview, its effects with it.
		local hidden = key == "paladin" and not (ns.db and ns.db.global and ns.db.global.enableDevelopmentMode)
		if (not hidden) then
			values[key] = WIP(key, Label(key))
			sorting[#sorting + 1] = key
		end
	end
	return values, sorting
end

local GenerateHunter = function(order)
	local Hunter = ns.HunterTheme
	if (not Hunter) then return end
	return {
		name = WIP("hunter", Label("hunter")),
		order = order,
		type = "group",
		inline = true,
		hidden = function() return Theme() ~= "hunter" end,
		args = {
			endcap = {
				name = L["Endcap"],
				desc = L["The ornament at the outer end of the health bars."],
				order = 1,
				type = "select", width = "full",
				values = function()
					local values = {}
					for key in pairs(Hunter:GetEndcapChoices()) do values[key] = ENDCAP_NAMES[key] end
					return values
				end,
				sorting = ENDCAP_ORDER,
				set = function(info, val) Hunter:SetEndcap(val) end,
				get = function(info) return Hunter:GetEndcap() end
			},
			endcapScale = {
				name = L["Endcap size"],
				desc = L["How large the endcaps are drawn. They grow and shrink around their own centre, so they stay where they are."],
				order = 2,
				type = "range", width = "full",
				min = .5, max = 2, step = .05, isPercent = true,
				set = function(info, val) Hunter:SetEndcapScale(val) end,
				get = function(info) return Hunter:GetEndcapScale() end
			},
			endcapX = {
				name = L["X Offset"],
				desc = L["Moves the endcaps out from the end of the bar, or in over it. The target's mirrored endcap moves the same way."],
				order = 3,
				type = "range", width = "full",
				min = -60, max = 60, step = 1,
				set = function(info, val) Hunter:SetEndcapOffset(val, nil) end,
				get = function(info) return (Hunter:GetEndcapOffset()) end
			},
			endcapY = {
				name = L["Y Offset"],
				desc = L["Moves the endcaps up or down."],
				order = 4,
				type = "range", width = "full",
				min = -60, max = 60, step = 1,
				set = function(info, val) Hunter:SetEndcapOffset(nil, val) end,
				get = function(info) return select(2, Hunter:GetEndcapOffset()) end
			},
			resetEndcap = {
				name = L["Reset endcap size and position"],
				order = 5,
				type = "execute",
				func = function() Hunter:ResetEndcapPlacement() end
			}
		}
	}
end

local GenerateMageTheme = function(order)
	local Mage = ns.MageTheme
	if (not Mage) then return end
	return {
		name = WIP("mage", Label("mage")),
		order = order,
		type = "group",
		inline = true,
		hidden = function() return Theme() ~= "mage" end,
		args = {
			endcap = {
				name = L["Endcap"],
				desc = L["The ornament at the outer end of the health bars."],
				order = 1,
				type = "select", width = "full",
				values = function()
					local values = {}
					for key in pairs(Mage:GetEndcapChoices()) do
						values[key] = key == "school" and L["Follow the school"] or MAGE_ENDCAP_NAMES[key]
					end
					return values
				end,
				sorting = MAGE_ENDCAP_ORDER,
				set = function(info, val) Mage:SetEndcap(val) end,
				get = function(info) return Mage:GetEndcap() end
			},
			endcapScale = {
				name = L["Endcap size"],
				desc = L["How large the endcaps are drawn. They grow and shrink around their own centre, so they stay where they are."],
				order = 2,
				type = "range", width = "full",
				min = .5, max = 2, step = .05, isPercent = true,
				set = function(info, val) Mage:SetEndcapScale(val) end,
				get = function(info) return Mage:GetEndcapScale() end
			},
			endcapX = {
				name = L["X Offset"],
				desc = L["Moves the endcaps out from the end of the bar, or in over it. The target's mirrored endcap moves the same way."],
				order = 3,
				type = "range", width = "full",
				min = -60, max = 60, step = 1,
				set = function(info, val) Mage:SetEndcapOffset(val, nil) end,
				get = function(info) return (Mage:GetEndcapOffset()) end
			},
			endcapY = {
				name = L["Y Offset"],
				desc = L["Moves the endcaps up or down."],
				order = 4,
				type = "range", width = "full",
				min = -60, max = 60, step = 1,
				set = function(info, val) Mage:SetEndcapOffset(nil, val) end,
				get = function(info) return select(2, Mage:GetEndcapOffset()) end
			},
			resetEndcap = {
				name = L["Reset endcap size and position"],
				order = 5,
				type = "execute",
				func = function() Mage:ResetEndcapPlacement() end
			}
		}
	}
end

-- The holy light is the Paladin effect, so it shows wherever that effect is
-- drawn: on the Paladin theme, or picked for the crystal or orb under Lite+.
local GeneratePaladin = function(order)
	local Paladin = ns.PaladinTheme
	if (not Paladin) then return end
	return {
		name = WIP("paladin", Label("paladin")),
		order = order,
		type = "group",
		inline = true,
		hidden = function()
			local effects = Effects()
			return not effects or (effects:GetCrystalEffect() ~= "paladin" and effects:GetOrbEffect() ~= "paladin")
		end,
		args = {
			light = {
				name = L["Holy light strength"],
				desc = L["How strongly the moving holy light shows on the power crystal and the mana orb. 0% hides it."],
				order = 1,
				type = "range", width = "full",
				min = 0, max = 1, step = .05, isPercent = true,
				set = function(info, val) Paladin:SetLightStrength(val) end,
				get = function(info) return Paladin:GetLightStrength() end
			}
		}
	}
end

local GenerateMage = function(order)
	local Mage = ns.MageCrystalPreview
	if (not Mage) then return end
	return {
		name = L["Mage crystal"].." (WIP)",
		order = order,
		type = "group",
		inline = true,
		hidden = function() return not Mage:IsActive() end,
		args = {
			school = {
				name = L["School"],
				order = 1,
				type = "select", width = "full",
				values = {
					auto = L["Follow specialization"],
					arcane = _G.STRING_SCHOOL_ARCANE or "Arcane",
					fire = _G.STRING_SCHOOL_FIRE or "Fire",
					frost = _G.STRING_SCHOOL_FROST or "Frost"
				},
				sorting = { "auto", "arcane", "fire", "frost" },
				set = function(info, val) Mage:Command(val) end,
				get = function(info) return Mage:GetSchoolChoice() end
			},
			flow = {
				name = L["Moving energy"],
				desc = function()
					if (not Mage.EnergyAvailable) then return L["Work in progress: the moving energy is not in this release yet, so the crystal shows a still pattern."] end
					return L["Animates the energy inside the crystal. Off shows a still pattern."]
				end,
				order = 2,
				type = "toggle", width = "full",
				disabled = function() return not Mage.EnergyAvailable end,
				set = function(info, val) Mage:Command(val and "flow" or "static") end,
				get = function(info) return ns.db.char.mageCrystalFlow ~= false end
			},
			strength = {name=L["Energy strength"],order=2.1,type="range",width="full",min=0,max=1,step=.05,isPercent=true,
				get=function() return Mage:GetEffectStrength() end,set=function(_,v) Mage:SetEffectStrength(v) end},
			particles = {name=L["Energy particles"],order=2.2,type="toggle",width="full",
				disabled=function() return not Mage.EnergyAvailable or ns.db.char.mageCrystalFlow==false end,
				get=function() return ns.db.char.mageCrystalParticles~=false end,set=function(_,v) Mage:SetParticles(v) end},
			speed = {
				name = L["Animation speed"],
				desc = L["How fast the selected school's energy moves. 100% is an eight-second loop."],
				order = 3,
				type = "range", width = "full",
				min = .1, max = 2, step = .05, isPercent = true,
				disabled = function() return not Mage.EnergyAvailable or ns.db.char.mageCrystalFlow == false end,
				set = function(info, val) Mage:SetSchoolSpeed(val) end,
				get = function(info) return Mage:GetSchoolSpeed() end
			}
		}
	}
end

local GenerateTests = function()
	local P=ns.ThemeBarPreview
	if (not P) then return end
	return {name=L["Bar tests"],type="group",inline=true,order=40,disabled=InCombatLockdown,args={
		kind={name=L["Bar variant"],type="select",width="full",order=1,values=function() return P:GetChoices() end,
			get=function() return P.kind end,set=function(_,v) P:Set("kind",v) end},
		fill={name=L["Test fill"],type="range",width="full",order=2,min=0,max=1,step=.05,isPercent=true,
			get=function() return P.fraction end,set=function(_,v) P:Set("fraction",v) end,disabled=function() return InCombatLockdown() or P.animate end},
		animate={name=L["Cycle test fill"],type="toggle",width="full",order=3,get=function() return P.animate end,set=function(_,v) P:Set("animate",v) end},
		protected={name=L["Protected cast"],type="toggle",width="full",order=4,hidden=function() return P.kind~="cast" end,
			get=function() return P.protected end,set=function(_,v) P:Set("protected",v) end},
		show={name=L["Open bar preview"],type="execute",order=5,func=function() P:Show() end},
		close={name=L["Close bar preview"],type="execute",order=6,func=function() if (P.window) then P.window:Hide() end end}
	}}
end

local GenerateOptions = function()
	if (not Effects()) then return end
	local options = {
		name = L["Themes"],
		type = "group",
		disabled = InCombatLockdown,
		args = {
			description = {
				name = L["Class artwork drawn over AzeriteUI's own frames. One theme shows at a time, and every setting here is saved per character."],
				order = 1,
				type = "description",
				fontSize = "medium"
			},
			wip = {
				name = L["Themes are a work in progress: their art and fit may still change between releases."],
				order = 1.5,
				type = "description",
				fontSize = "medium"
			},
			theme = {
				name = L["Theme"],
				desc = L["Which artwork AzeriteUI is drawn with. Switching theme reloads the interface."],
				order = 2,
				type = "select", width = "full",
				values = function() return (List(Effects():GetThemes())) end,
				sorting = function() return select(2, List(Effects():GetThemes())) end,
				-- Asks only when the switch rebuilds the frame layouts.
				confirm = function(info, value)
					return Effects():NeedsReload(value) and L["Changing this reloads the interface."] or false
				end,
				set = function(info, val) Effects():SetTheme(val) end,
				get = function(info) return Effects():GetTheme() end
			},
			litePlus = {
				name = "Lite+",
				desc = L["Use the power crystal and mana orb effects of the other themes on the theme you are using. Only the settings of the effects you pick are shown."],
				order = 3,
				type = "toggle", width = "full",
				set = function(info, val) Effects():SetLitePlus(val) end,
				get = function(info) return Effects():IsLitePlus() end
			},
			effects = {
				name = "Lite+",
				order = 4,
				type = "group",
				inline = true,
				hidden = function() return not Effects():IsLitePlus() end,
				args = {
					crystal = {
						name = L["Crystal effect"],
						desc = L["Which effect plays inside the power crystal."],
						order = 1,
						type = "select", width = "full",
						values = function() return (List(Effects():GetCrystalEffects(), true)) end,
						sorting = function() return select(2, List(Effects():GetCrystalEffects(), true)) end,
						set = function(info, val) Effects():SetCrystalChoice(val) end,
						get = function(info) return Effects():GetCrystalChoice() end
					},
					orb = {
						name = L["Orb effect"],
						desc = L["Which effect plays inside the mana orb."],
						order = 2,
						type = "select", width = "full",
						values = function() return (List(Effects():GetOrbEffects(), true)) end,
						sorting = function() return select(2, List(Effects():GetOrbEffects(), true)) end,
						set = function(info, val) Effects():SetOrbChoice(val) end,
						get = function(info) return Effects():GetOrbChoice() end
					}
				}
			},
			hunter = GenerateHunter(10),
			paladin = GeneratePaladin(20),
			mageTheme = GenerateMageTheme(25),
			mage = GenerateMage(30),
			tests = GenerateTests()
		}
	}
	return options
end

Options:AddGroup("Themes", GenerateOptions, -9500, "setup")

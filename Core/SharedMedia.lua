--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg

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
local Addon, ns = ...

local LSM = LibStub("LibSharedMedia-3.0", true)
if (not LSM) then return end

local AddMedia = function(mediatype, name, key)
	LSM:Register(mediatype, name, ns.API.GetMedia(key or name) or key or name)
end

-- Borders
AddMedia("border", 		"Diabolic Aura Border", 						"border-aura")
AddMedia("border", 		"Diabolic Glow Border", 						"border-glow")
AddMedia("border", 		"Diabolic Tooltip Border", 						"border-tooltip")

-- Statusbars
AddMedia("statusbar", 	"Diabolic Statusbar Large", 					"bar-progress")
AddMedia("statusbar", 	"Diabolic Statusbar Small", 					"bar-small")

-- Textures
AddMedia("texture", 	"Azerite ActionButton Backdrop (Circular)", 	"actionbutton-backdrop")
AddMedia("texture", 	"Azerite ActionButton Border (Circular)", 		"actionbutton-border")
AddMedia("texture", 	"ActionButton Highlight (Circular)", 			"actionbutton-spellhighlight")
AddMedia("texture", 	"ActionButton Highlight (Rounded Square)", 		"actionbutton-spellhighlight-square-rounded")
AddMedia("texture", 	"ActionButton Highlight (Square)", 				"actionbutton-spellhighlight-square")
AddMedia("texture", 	"ActionButton Mask (Rounded Square)", 			"actionbutton-mask-square-rounded")
AddMedia("texture", 	"ActionButton Mask (Circular)", 				"actionbutton-mask-circular")
AddMedia("texture", 	"ActionButton Mask (Square)", 					"actionbutton-mask-square")
AddMedia("texture", 	"Azerite Badge Alliance", 						"icon_badges_alliance")
AddMedia("texture", 	"Azerite Badge Horde", 							"icon_badges_horde")
AddMedia("texture", 	"Azerite Badge NPC Boss", 						"icon_badges_boss")
AddMedia("texture", 	"Azerite Badge NPC Elite", 						"icon_classification_elite")
AddMedia("texture", 	"Azerite Badge NPC Rare", 						"icon_classification_rare")
AddMedia("texture", 	"Azerite Combat Icon", 							"icon-combat")
AddMedia("texture", 	"Azerite Group Finder Eye (Blue)", 				"group-finder-eye-blue")
AddMedia("texture", 	"Azerite Group Finder Eye (Green)", 			"group-finder-eye-green")
AddMedia("texture", 	"Azerite Group Finder Eye (Orange)", 			"group-finder-eye-orange")
AddMedia("texture", 	"Azerite Group Finder Eye (Purple)", 			"group-finder-eye-purple")
AddMedia("texture", 	"Azerite Group Finder Eye (Red)", 				"group-finder-eye-red")
AddMedia("texture", 	"Azerite GroupRole Icon (Damager)", 			"grouprole-icons-dps")
AddMedia("texture", 	"Azerite GroupRole Icon (Healer)", 				"grouprole-icons-heal")
AddMedia("texture", 	"Azerite GroupRole Icon (Tank)", 				"grouprole-icons-tank")
AddMedia("texture", 	"Azerite Minimap Border", 						"minimap-border")
AddMedia("texture", 	"Azerite Targeting Icon (Blue)", 				"icon_target_blue")
AddMedia("texture", 	"Azerite Targeting Icon (Green)", 				"icon_target_green")
AddMedia("texture", 	"Azerite Targeting Icon (Red)", 				"icon_target_red")
AddMedia("texture", 	"Azerite Vehicle Exit Button", 					"icon_exit_flight")
AddMedia("texture", 	"Diabolic Orb Backdrop Sword", 					"orb-backdrop2")
AddMedia("texture", 	"Minimap Mask Opaque (Circular)", 				"minimap-mask-opaque")
AddMedia("texture", 	"Minimap Mask Transparent (Circular)", 			"minimap-mask-transparent")
AddMedia("texture", 	"Simple White Plus", 							"plus")

-- Art that ships in Assets but no module claims.
-- These are complete, usable pieces from the same art set as everything above -
-- alternates and unclaimed members of families the addon already draws. Publishing
-- them here is what the registry is for: it makes them addressable by name, to this
-- addon and to anything else reading LibSharedMedia, instead of shipping in every
-- download while being unreachable. Details, and what building a home for each
-- would take, are in Docs\RESEARCH_Optional_Deletions_2026-09-02.md.
AddMedia("statusbar",	"Azerite Health Bar Highlight", 					"hp_cap_bar_highlight")
AddMedia("texture", 	"Azerite Badge NPC Boss (Classification)", 		"icon_classification_boss")
AddMedia("texture", 	"Azerite Castbar Backdrop (Wooden)", 			"cast_back_wooden")
AddMedia("texture", 	"Azerite ClassPower Backdrop (Block)", 			"point_block")
AddMedia("texture", 	"Azerite ClassPower Point (Gem)", 				"point_gem")
AddMedia("texture", 	"Azerite Minimap Ring Backdrop (Two Bars)", 		"minimap-twobars-backdrop")
AddMedia("texture", 	"Azerite Minimap Ring Inner (Two Bars)", 		"minimap-bars-two-inner")
AddMedia("texture", 	"Azerite Minimap Ring Outer (Two Bars)", 		"minimap-bars-two-outer")
AddMedia("texture", 	"Azerite Party Mana Ring", 						"party_mana")
AddMedia("texture", 	"Azerite PartyRole Badge (Damager)", 			"partyrole_dps")
AddMedia("texture", 	"Azerite PartyRole Badge (Healer)", 				"partyrole_heal")
AddMedia("texture", 	"Azerite PartyRole Badge (Tank)", 				"partyrole_tank")
AddMedia("texture", 	"Azerite Spell Alert (Circular)", 				"IconAlert-Circle")
AddMedia("texture", 	"Azerite Spell Alert Ants (Circular)", 			"IconAlertAnts-Circle")

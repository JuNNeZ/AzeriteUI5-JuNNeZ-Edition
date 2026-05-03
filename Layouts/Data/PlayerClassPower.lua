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

-- Addon API
local Colors = ns.Colors
local GetFont = ns.API.GetFont
local GetMedia = ns.API.GetMedia

local toRadians = function(d) return d*(math.pi/180) end
local round = function(value)
	if (value < 0) then
		return math.ceil(value - .5)
	end
	return math.floor(value + .5)
end

-- Rogue extended combo points use a simple mirrored parabola so 1-7 follow one arc.
local CreateRogueComboPointLayout = function(y, rotationDegrees, backdropSize, size)
	local apexX = 58
	local edgeX = 82
	local mirrorY = -45
	local edgeDistanceY = 92
	local normalizedY = (y - mirrorY) / edgeDistanceY
	local x = round(apexX + ((edgeX - apexX) * normalizedY * normalizedY))
	if (type(size) == "table" and (size[1] or 0) > 13) then
		x = x + 10
	end

	return {
		Position = { "TOPLEFT", x, y },
		Size = size or { 13, 13 },
		BackdropSize = backdropSize or { 60, 60 },
		Texture = GetMedia("point_crystal"),
		BackdropTexture = GetMedia("point_plate"),
		Rotation = (type(rotationDegrees) == "number") and toRadians(rotationDegrees) or nil
	}
end

ns.RegisterConfig("PlayerClassPower", {

	ClassPowerFrameSize = { 124, 168 },

	-- Class Power
	-- *also include layout data for Stagger and Runes,
	--  which are separate elements from ClassPower.
	ClassPowerPointOrientation = "UP",
	ClassPowerSparkTexture = GetMedia("blank"),
	ClassPowerCaseColor = { 211/255, 200/255, 169/255 },
	ClassPowerSlotColor = { 130/255 *.3, 133/255 *.3, 130/255 *.3, 2/3 },
	ClassPowerSlotOffset = 1.5,

	-- Note that the following are just layout names.
	-- They may not always be used for what their name implies.
	-- The important part is number of points and layout. Not powerType.
	ClassPowerLayouts = {
		SoulFragmentsPoints = { --[[ 5 (Devourer DH: 5-point tracking, dim 0-5 stacks, bright 6-10 stacks) ]]
			[1] = {
				Position = { "TOPLEFT", 82, -137 },
				Size = { 12, 12 }, BackdropSize = { 54, 54 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(6)
			},
			[2] = {
				Position = { "TOPLEFT", 64, -111 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[3] = {
				Position = { "TOPLEFT", 50, -80 },
				Size = { 11, 15 }, BackdropSize = { 65, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(3)
			},
			[4] = {
				Position = { "TOPLEFT", 58, -44 },
				Size = { 12, 18 }, BackdropSize = { 78, 79 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(3)
			},
			[5] = {
				Position = { "TOPLEFT", 82, -11 },
				Size = { 14, 21 }, BackdropSize = { 82, 96 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(1)
			}
		},
		Stagger = { --[[ 3 ]]
			[1] = {
				Position = { "TOPLEFT", 62, -109 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"), BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[2] = {
				Position = { "TOPLEFT", 41, -58 },
				Size = { 39, 40 }, BackdropSize = { 80, 80 },
				Texture = GetMedia("point_hearth"), BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			},
			[3] = {
				Position = { "TOPLEFT", 64, -36 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"), BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			}
		},
		ArcaneCharges = { --[[ 4 ]]
			[1] = {
				Position = { "TOPLEFT", 78, -139 },
				Size = { 13, 13 }, BackdropSize = { 58, 58 },
				Texture = GetMedia("point_crystal"), BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(6)
			},
			[2] = {
				Position = { "TOPLEFT", 57, -111 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[3] = {
				Position = { "TOPLEFT", 49, -76 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(4)
			},
			[4] = {
				Position = { "TOPLEFT", 72, -33 },
				Size = { 51, 52 }, BackdropSize = { 104, 104 },
				Texture = GetMedia("point_hearth"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			}
		},
		ComboPoints = { --[[ 5 (shared combo-point layout, preserves original 5-point finisher) ]]
			[1] = {
				Position = { "TOPLEFT", 82, -137 },
				Size = { 13, 13 }, BackdropSize = { 58, 58 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(6)
			},
			[2] = {
				Position = { "TOPLEFT", 64, -111 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[3] = {
				Position = { "TOPLEFT", 54, -79 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(4)
			},
			[4] = {
				Position = { "TOPLEFT", 60, -44 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			},
			[5] = {
				Position = { "TOPLEFT", 82, -11 },
				Size = { 14, 21 }, BackdropSize = { 82, 96 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(1)
			}
		},
		ComboPointsRogue = { --[[ 7 (Rogue-only extended combo points) ]]
			[1] = CreateRogueComboPointLayout(-137, 6, { 58, 58 }),
			[2] = CreateRogueComboPointLayout(-111, 5),
			[3] = CreateRogueComboPointLayout(-79, 4),
			[4] = CreateRogueComboPointLayout(-44, nil),
			[5] = CreateRogueComboPointLayout(-11, -4),
			[6] = CreateRogueComboPointLayout(21, -5),
			[7] = CreateRogueComboPointLayout(47, -1, { 82, 96 }, { 14, 21 })
		},
		Chi = { --[[ 6 ]]
			[1] = {
				Position = { "TOPLEFT", 82, -137 },
				Size = { 13, 13 }, BackdropSize = { 58, 58 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(6)
			},
			[2] = {
				Position = { "TOPLEFT", 70, -111 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[3] = {
				Position = { "TOPLEFT", 61, -79 },
				Size = { 12, 12 }, BackdropSize = { 56, 56 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(-2)
			},
			[4] = {
				Position = { "TOPLEFT", 58, -44 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			},
			[5] = {
				Position = { "TOPLEFT", 61, -11 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			},
			[6] = {
				Position = { "TOPLEFT", 70, 31 },
				Size = { 39, 40  }, BackdropSize = { 80, 80 },
				Texture = GetMedia("point_hearth"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = nil
			}
		},
		SoulShards = { --[[ 5 ]]
			[1] = {
				Position = { "TOPLEFT", 82, -137 },
				Size = { 12, 12 }, BackdropSize = { 54, 54 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(6)
			},
			[2] = {
				Position = { "TOPLEFT", 64, -111 },
				Size = { 13, 13 }, BackdropSize = { 60, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_plate"),
				Rotation = toRadians(5)
			},
			[3] = {
				Position = { "TOPLEFT", 50, -80 },
				Size = { 11, 15 }, BackdropSize = { 65, 60 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(3)
			},
			[4] = {
				Position = { "TOPLEFT", 58, -44 },
				Size = { 12, 18 }, BackdropSize = { 78, 79 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(3)
			},
			[5] = {
				Position = { "TOPLEFT", 82, -11 },
				Size = { 14, 21 }, BackdropSize = { 82, 96 },
				Texture = GetMedia("point_crystal"),  BackdropTexture = GetMedia("point_diamond"),
				Rotation = toRadians(1)
			}
		},
		Runes = { --[[ 6 ]]
			[1] = {
				Position = { "TOPLEFT", 82, -131 },
				Size = { 28, 28 }, BackdropSize = { 58, 58 },
				Texture = GetMedia("point_rune2"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			},
			[2] = {
				Position = { "TOPLEFT", 58, -107 },
				Size = { 28, 28 }, BackdropSize = { 68, 68 },
				Texture = GetMedia("point_rune4"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			},
			[3] = {
				Position = { "TOPLEFT", 32, -83 },
				Size = { 30, 30 }, BackdropSize = { 74, 74 },
				Texture = GetMedia("point_rune1"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			},
			[4] = {
				Position = { "TOPLEFT", 65, -64 },
				Size = { 28, 28 }, BackdropSize = { 68, 68 },
				Texture = GetMedia("point_rune3"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			},
			[5] = {
				Position = { "TOPLEFT", 39, -38 },
				Size = { 32, 32 }, BackdropSize = { 78, 78 },
				Texture = GetMedia("point_rune2"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			},
			[6] = {
				Position = { "TOPLEFT", 79, -10 },
				Size = { 40, 40 }, BackdropSize = { 98, 98 },
				Texture = GetMedia("point_rune1"),  BackdropTexture = GetMedia("point_dk_block"),
				Rotation = nil
			}
		}
	}
})

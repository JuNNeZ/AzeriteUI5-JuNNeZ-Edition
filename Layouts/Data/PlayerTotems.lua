--[[

	The MIT License (MIT)

	Copyright (c) 2026 Lars Norberg
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
local Addon, ns = ...

-- Addon API
local Colors = ns.Colors
local GetMedia = ns.API.GetMedia

-- The totem row: Shaman totems, Monk statues, the non-Unholy ghoul and every
-- other summon the game puts in a totem slot. One icon per slot, left to right.
ns.RegisterConfig("PlayerTotems", {

	TotemCount = 4, -- MAX_TOTEMS
	TotemSize = { 32, 32 },
	TotemSpacing = 8,
	TotemIconMask = GetMedia("actionbutton-mask-square"),
	TotemBorderColor = { Colors.verydarkgray[1], Colors.verydarkgray[2], Colors.verydarkgray[3] },
	TotemTimerFontSize = 14,
	TotemTimerColor = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] }

})

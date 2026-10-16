# Theme bag icons

Original built-in image_gen paintings for the six selectable themes:
AzeriteUI, Legacy, Hunter, Mage, Paladin and Druid. All are 256x256 uncompressed
32-bit alpha TGA. The button keeps its existing size, circular mask, ring,
anchors, count, tooltip, hover and secure backpack click.

Core/ThemeEngine.lua resolves identity through ThemeEffects:GetTheme(), so
Legacy is included and Lite+ effects do not choose another theme's bag.
Unknown identities fall back to AzeriteUI.

Sources and exact prompts: Docs/Research_Assets/ThemeBagIcons-2026-10-14/Sources.
Rebuild: python Tools/Build-ThemeBagIcons.py. Review.png shows enlarged art
and the actual native circular mask at 28px. manifest.json records source and
installed hashes; TGA roundtrips are checked by the builder.

Live Retail/Forever remains unverified. After reload, switch across all six
themes and verify bag toggle, cursor-item drop, free-slot count and hover.

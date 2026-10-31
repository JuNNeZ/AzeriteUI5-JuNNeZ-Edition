# Shaman — Storm, Stone & Tides (WIP)

Latest correction, 2026-10-30: the cradle now uses native256x128 density, with
visible height70 matching OG (previous58.375), and a25px centre rail vs OG24.
Basalt/copper/cord/pearl painting is retained whole through uniform registration.
Eight holder/halo textures changed;69 others unchanged. This remains the explicitly
authorized WIP live preview: SourceIntegrity still flags gripping-horn aperture
overlap; no bridge or production approval is claimed. Read source-check.json and
proposed-horn-bridge.json under Crystal-Weight-2026-10-30. Current verification:
`python Tools/Repair-ShamanCrystalWeight.py --verify`. Run `/reload` to inspect
actual in-game mass, edges and contact; older paragraphs below are history.

Latest live-feedback correction (2026-10-29): the earlier setter-hook checks did
not prevent the reported cap4/health7/rails8 failure. Shaman now reconciles the
visible casing after unhooked native propagation, outside combat. A retained
AI edit corrects the cradle's inner contact lips, exported whole with its own
alpha and one uniform scale. The original direct-conversion export below is
historical. Current verification: `python Tools/Fit-ShamanCrystalShape.py --verify`.
After `/reload`, repeat the level diagnostic and inspect the actual join.
These corrections are installed for WIP review; live confirmation remains owed.

Installed for the maintainer's explicit in-game review on 2026-10-29.
After `/reload`, choose Shaman (WIP) under `/az -> Themes`, or use
`/azshaman on` outside combat. Selection reloads the interface.

Health: Maelstrom (default), Tides, Lava Totem, None. Cast: Ancestral Totem,
None. Size/offset/reset are independent; saved frame layout remains native.

77 uncompressed 32-bit TGAs; `manifest.json` records hashes and WIP status.
Crystal source pixels/alpha are retained on transparent power-of-two padding.
Tides/Lava are earlier separable WIP paintings, not the improved whole-frame
Tides study. Their production fit and visual acceptance are still pending.
No live Retail or Forever confirmation is claimed.

Prepare/render: `python Tools/Install-ShamanLivePreview.py --render`
Verify installed files: `python Tools/Install-ShamanLivePreview.py --verify`
Recording harness: `lua Tools/Harness/shaman_theme_harness.lua .`
Local source/evidence: `Docs/Research_Assets/Shaman/`.

Crystal fitting follow-up, 2026-10-29: translated the intact painting within its
transparent canvas to native centre-rail y=65/128. All visible source RGBA is
unchanged; original frame geometry remains. Eight holder/halo textures updated,
69 other textures unchanged. Current verification after this scoped repair:
`python Tools/Repair-ShamanCrystalFit.py --verify`. The earlier strict verifier
retains its historical integration baseline and reports unrelated runtime drift.

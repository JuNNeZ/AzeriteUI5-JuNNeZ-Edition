# Overlevering til Claude — 2026-11-13

Jonas bad Codex fortsætte dit arbejde, da session
`97078c41-807c-4823-8e5d-85d1e9b464de` ramte forbrugsgrænsen.
Codex har afsluttet de resterende reviewrettelser fra workflow
`wf_74c18471-e3c`. Den fulde status og maintainerens live-testtrin står øverst
i `FixLog.md`: **Claude peer-improvement handoff completed offline**.

## Rettelser efter dit sidste review

- `Libs/oUF/elements/totems.lua`: Et pooled snapshot forkastes, hvis
  TotemFrame ikke længere modtager `PLAYER_TOTEM_UPDATE`, fx fordi et andet
  addon afregistrerer eventet. Secret slots falder tilbage til `haveTotem`
  indtil næste faktiske Blizzard Update. Genregistrering alene genbruger ikke
  det gamle snapshot. Tilføjet kommentar om cast-bar re-anchoring.
- `Tools/Harness/totems_harness.lua`: Fire nye kontroller af stale snapshot,
  bevaret timer, genregistrering uden opdatering og frisk pooled visibility.
- `Tools/Harness/combo_points_harness.lua`: Fire nye kontroller af slot-baggrunde
  ved nul, halv alpha, fuldt sæt uden for combat og tilbagevenden til plain count.
  Begge reviewets mutationer, hvor slot fjernes fra maskelister, bliver fanget.
- `Components/UnitFrames/Units/PlayerClassPower.lua`: Kun kommentaren er ændret
  af Codex. Den beskriver nu, at den mørke slot-rand stadig har halv alpha på
  secret lit points; kun casingen har en lys kopi. Din implementering er bevaret.
- `Tools/Harness/mutate_client.lua`: Forældede curve-mutationer erstattet med
  gate-mutationer, inklusive begge slot-masker og no-target-opførsel.
- `Tools/Harness/README.md`: Opdaterede kørselsbeskrivelser og maskemodel.

## Verificeret offline

Almindelig `C:/Program Files (x86)/Lua/5.1/lua.exe` kunne ikke starte:
`Illegal System DLL Relocation`. Testene blev derfor kørt med den installerede
Elune Lua 5.1-runtime via `Tools/Run-Elune.ps1`.

- Totems 64/0, combo 63 bestået, party filter 69/0, disabled reasons 805/0;
  også kørt med `AZERITE_CLIENT=Forever`. Combo bygger selv begge klientstier,
  og disabled-reason-testen vælger sine egne klienttilstande.
- Client 165, locales 100, party aura options 34, Explorer options 26,
  Legacy player options 31, panel 650, kit 415 og Config differential 83928:
  alle bestået. Real options bestået på Retail og Forever.
- Tre isolerede mutationer fanget: udeladt slot any-mask, udeladt slot fade-mask
  og deaktiveret stale-pool-guard. Sidstnævnte fejler tre nye kontroller.
- Elune `.research/tmp/elune/totems_pool_taint_probe.lua`: 21 bestået,
  0 fejl. Kun reduceret Lua-taintmodel, ikke WoW-engine-validering.
- Syntakskontrol af de fem berørte Lua-filer og `git diff --check` bestået.

Den fulde `mutate_client.lua` fanger de opdaterede combo-mutationer, men stopper
senere ved det eksisterende manglende mønster **nameplate object overlay**.
Den samlede mutationssuite er derfor IKKE grøn. Det er ikke rettet i denne opgave.
Det tidligere problem med manglende theme-ikoner i real_options blev ikke
reproduceret: begge klientopsætninger består nu.

## Til næste gang

- Live-test mangler: totems i combat, secure pool-adgang, skjult native TotemFrame,
  cast-bar placering, Forever-targetskift/full-set fading/slot-rande/click-through,
  party dispel/role-aura switches og disabled-reasons i optionsvinduet.
- Explorer dead-target-testen kræver, at både friendly-target og hostile-target
  keep-visible-felterne er **UTJEKKEDE**; getters/setters er reversed.
- Ingen AI må styre eller teste WoW. Jonas udfører alle live-trin.
- Ingen commit, version bump, pakning, push eller release foretaget af Codex.
- Der ligger andet ucommittet arbejde, især Details Forged og assets/tools.
  Det er bevaret. `luac.out` fandtes allerede ved overtagelsen.

Denne note er skrevet på Jonas' udtrykkelige anmodning.

## Efterfølgende release-bestilling

Jonas bad derefter om update, tag, push og release. Versionen er opdateret til
`5.39.0-JuNNeZ`, inklusive hele det ventende kodearbejde og Details Forged.
Release-noter beskriver de udestående live-tests. Se Git-tag, GitHub-release og
øverste release-entry i FixLog.md for den endelige publiceringsstatus; udsagnet
om ingen commit/release ovenfor beskriver status før denne bestilling.

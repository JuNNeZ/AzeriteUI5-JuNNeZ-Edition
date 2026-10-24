# Offline harnesses for the options panel and client compatibility

Wildheart Lite+ crystal: `lua Tools/Harness/wildheart_crystal_harness.lua . mutations`
loads the real module and dispatcher against recording widgets. Checks cover
native clipping/masks, no resource or fill geometry reads, draw order, activity
transitions, combat ticking/settings refusal, cleanup, strength, ice refresh
plus dynamic mist UVs, curved pulse travel with intersecting masks, decaying
movement impulses, faster active flow and seven rejected mutants. Current magic
has a full-silhouette dim layer plus a fill-clipped bright layer; checks cover
their separate parents, drawing above the material body, complementary intensity, same phase, material-only
fill clip, zero-strength cleanup and rejection of a clipped ambient parent.
`samples <output.json> [wildheart|moonvein|dreamsap]` exports real Lua layer
samples and palettes for `Tools/Render-WildheartDemo.py --compare` or
`--flavour <key>`; `--persistent-compare --flavour <key>` renders the retained
old clip against new magic at 100/50/10/0%. Tests also cover all three Lite+ choices, independent
strengths, distinct motion and hiding/restoring Wildheart's branch/seed layers.
Renderer is an offline approximation;
client rendering, taint and performance remain live checks in Assets/Druid/README.md.

The custom options panel draws itself, so these are the only thing between a change and a broken
window. They run under plain Lua 5.1 against the addon's **real** option tables, with the WoW API
stubbed in `stubs.lua`.

Not shipped: `.pkgmeta` ignores `Tools`.

## Running them

From the addon root, with `lua.exe` 5.1 on the machine (`C:\Program Files (x86)\Lua\5.1\`):

```sh
lua Tools/Harness/panel_harness.lua        . Tools/Harness   # the window
lua Tools/Harness/options_navigation_harness.lua . Tools/Harness # tabs, folds, exact search targets
lua Tools/Harness/options_navigation_harness.lua . Tools/Harness Forever # client visibility and navigation
lua Tools/Harness/kit_harness.lua          . Tools/Harness   # art, themes, controls
lua Tools/Harness/config_diff_harness.lua  . Tools/Harness   # Config vs the Ace3 library
lua Tools/Harness/real_options_harness.lua . Tools/Harness   # the real table, end to end
lua Tools/Harness/real_options_harness.lua . Tools/Harness Forever # unavailable settings hidden
lua Tools/Harness/client_harness.lua      .                # Retail/Forever detection, APIs, modules, menus
lua Tools/Harness/diel_harness.lua        .                # the Forever day and night indicator
lua Tools/Harness/event_button_harness.lua .              # Hide Activity Button (China Forever)
lua Tools/Harness/combo_points_harness.lua .               # Forever secret combo points
lua Tools/Harness/chat_guard_harness.lua   .               # chat module stays out of chat replacements
lua Tools/Harness/tracker_harness.lua      .               # Hide the Blizzard Tracker, Retail and Forever
lua Tools/Harness/locale_harness.lua       .               # all ten locales: parity, specifiers, widths
lua Tools/Harness/nameplate_harness.lua    .               # nameplates: named checks + golden snapshot
lua Tools/Harness/player_aura_enchant_harness.lua .        # weapon enchants in the player aura row, 12.1.0 and 12.1.5/Forever
lua Tools/Harness/flyout_harness.lua       .               # LibActionButton flyout discovery, both clients
lua Tools/Harness/tooltip_compare_harness.lua .            # compare tooltips: borders and the Equipped tab
lua Tools/Harness/castbar_pushback_harness.lua .           # oUF castbar: pushback, and stops without a castBarID hide the bar
lua Tools/Harness/party_dispel_harness.lua .               # party dispel glow + priority debuff with secret aura fields
lua Tools/Harness/castbar_target_harness.lua .             # nameplate cast target name, aimed-at-you and important glows
lua Tools/Harness/quest_marker_harness.lua .               # nameplate quest marker: when it shows, hides and asks
lua Tools/Harness/totems_harness.lua .                     # Retail totem row: secret-safe totem element, module shape
lua Tools/Harness/masterlooter_harness.lua .               # Forever master looter icon on 6-40 raid frames
lua Tools/Harness/pet_experience_harness.lua .             # Forever hunter pet XP bar under the pet frame
lua Tools/Harness/mythicplus_harness.lua   .               # Mythic+ timer, forces, end card, keystone, Great Vault
lua Tools/Harness/whatsnew_harness.lua     .               # What's New popup: when it shows, Got it, combat, buttons
lua Tools/Harness/unit_tier_harness.lua    .               # Novice/Hardened/Seasoned tiers and critters, any client or language
lua Tools/Harness/addon_compat_harness.lua .               # ConsolePort icons, gamepad glyphs without it, portraits under a DialogueUI fade, the addon conflict prompt
lua Tools/Harness/bag_button_harness.lua   .               # the bag button beside the cog: secure route, switch, free slots
lua Tools/Harness/worldmap_combat_harness.lua .            # world map with a protected map in combat: nothing blocked, replay after combat/hide
lua Tools/Harness/proc_highlight_harness.lua .             # proc styles, preview/reset, riding visibility combinations
lua Tools/Harness/cooldown_manager_harness.lua .           # styling, own skins/dropdown, restore, keybinds, Explorer fade proxies, rival addon choice
lua Tools/Harness/target_execute_harness.lua .             # target tiers, mirrored crops, shared threshold, secrets, off/on
lua Tools/Harness/target_health_crop_harness.lua .         # target shaped fill: eased crop helper, scale, spark on its edge
lua Tools/Harness/cdready_menu_harness.lua .               # real debug page, row layout, immediate probe vs queued repairs
lua Tools/Harness/cdready_harness.lua .                    # opt-in probe, secrets, callbacks, polling and cleanup
lua Tools/Harness/auracost_harness.lua .                   # /azdebug auracost: alternating windows, noise verdict, report
lua Tools/Harness/snapping_harness.lua .                   # /lock snapping: Edit Mode magnetism rules, grid lines
lua Tools/Harness/combat_feedback_harness.lua .            # combat text: secret amounts, crits, the switch
lua Tools/Harness/group_indicators_harness.lua .           # Sated and corner aura dots on group frames
lua Tools/Harness/aura_sounds_harness.lua .                # aura sounds: registration, restrictions, LibSharedMedia
lua Tools/Harness/debug_loader_harness.lua .               # the load-on-demand debug companion and its loader
lua Tools/Harness/theme_engine_harness.lua .               # theme engine: dispatch, media swap, endcap settings
lua Tools/Harness/aura_brightness_harness.lua .            # TODO 5.1: the brightness toggle in and out of raids
```

`options_navigation_harness.lua` drives the real Config, Renderer and Panel with
nested tabs, closed sections and repeated section names. It follows search
results through every ancestor to the exact row, checks that the row is visible
and marked without capturing movement keys, and verifies that Changed/defaults
retain settings in closed branches. It also checks automatic folding on long
pages, ordinary short pages, full-path mover links, legacy section-label links
and stale deferred scrolls. Navigation state never writes a profile value.
Widget measurements are offline approximations; live layout and `/reload`
checks remain in `Docs/Options Panel Test Battery.md`.

`player_aura_enchant_harness.lua` loads the real `PlayerAuraContainers.lua` against a fake aura
container whose item-enchantment calls check their inputs the way `Blizzard_CustomAuraContainer.lua`
does, once shaped like 12.1.0 (no `SetItemEnchantmentEnabled`) and once like 12.1.5/Forever. It covers
registration only on request and only for the player (never the vehicle row or a display created without
`itemEnchantments`), the layout index between debuffs and buffs, switching off in place (12.1.5/Forever)
or by swapping the row to a second player container without slots and back (12.1.0, at most two, the
parked one disabled and hidden, the active one configured and enabled as the row is), Show Debuffs Only,
combat deferral and a client without item enchantments. A second argument loads a copy of the file
instead; ten mutants (registering at creation, enchants on the vehicle row, no layout index, Show Debuffs
Only ignored, no swap, the parked container left visible, a new container per swap, no swap back, the
swapped-in container left unconfigured or always enabled, and three Forever ones) each fail it. A second
copy loaded with Forever's APIs covers the imbue cells the container cannot show: de-duplication, secret
fields (fake secrets are tables, so an unguarded comparison or sum raises), combat deferral and recasts.

`mythicplus_harness.lua` loads the real `Components/Misc/MythicPlus.lua` and `Components/Misc/Info.lua`
against a small fake client whose answers follow how `Blizzard_ScenarioObjectiveTracker.lua`,
`Blizzard_ChallengesUI.lua` and `Blizzard_WeeklyRewards.lua` read the same calls. It drives a key through
the +3, +2, +1 and over-time stages, deaths, enemy forces (raw count, the rounded fallback, completion,
overshoot), a secret time, the settings, the end-of-run card (timed with a record, over time, a practice
run, switched off), the Font of Power (found, switched off, already slotted, cursor busy, combat, refused,
no key) and the vault counter and tooltip. It cannot say whether the live client still answers that way,
or how any of it looks. Its mutations are the `mythicplus` and `vault` entries in `mutate_client.lua`.

`castbar_pushback_harness.lua` loads the real `Libs/oUF/elements/castbar.lua` into its own environment and
drives the player's cast through a start and two pushbacks, a channel cut short, an empowered cast,
another unit's cast and a client without `C_DurationUtil` (GitHub #5, FixLog 2026-09-26). The bar is what
the element's own `OnUpdate` draws, the timer the last duration handed to `SetTimerDuration`; the
client's duration getters answer with the span the cast started with, as the reporter found Forever does
after a delay. It fails against the 5.10.2 element: the bar full before the cast ends, the timer on the
old span, the delay counted twice. Its mutations are the `castbar` entries in `mutate_client.lua`.

`tooltip_compare_harness.lua` loads the real `Components/Misc/Tooltips.lua` with its layout data and
`Core/API/ProtectedCall.lua`, and Blizzard's `TooltipComparisonManager` `Initialize` and
`AnchorShoppingTooltips` copied verbatim (the file is identical on Retail and Forever). Its frames
resolve their anchors to screen rectangles, so it measures what is drawn: the seam between two
tooltips' backdrops (negative is an overlap), whether the compare tooltips still line up with the
tooltip they compare against, and whether the "Equipped" tab's bottom edge lands inside the band where
each theme's border art is solid (measured from the art; see the file). Cases: both themes, either
side, one or two items, a scaled tooltip, the first compare of a session, a re-anchor, switched off and
on, secret anchoring and scale, no compare modifier. It fails against the 5.10.0 module (FixLog
2026-09-25). After 5.10.1 and the audit's first cut, the live client still drew compare tooltips edge to
edge although our hook on the manager had set the offsets, so `Compare` runs Blizzard's anchoring a second
time after the manager, as an unhooked copy calling the frames' own `SetPoint`; both of those versions
fail here on the seams, as they did live. The module now re-makes each join from a `SetPoint` post-hook
on the compare tooltip, and the checks require each compare tooltip to be held by its join alone (no
`TOP`), the join to still be ours a frame later (as `/azdebug tooltips` reports it), secret anchoring to
change nothing, other addons' anchors to be left alone, an embedded tooltip's top to stay level, and the
compare tooltips to take GameTooltip's scale. Hide in Combat's answers and the action bar refreshes are
checked here too. The rest of the tooltip audit runs against the same loaded module: the native
aura containers' `AuraButtonTooltip` styled through a fake `AuraContainerInbound` that validates the
documented `AuraContainerTooltipBackdropOptions` (per theme, theme change, switch off and on, off from
login, `Blizzard_AuraContainer` loading late, a refusal retried), aura spell IDs with no `UnitAura`
global (Retail and Forever have none), the unit name written to the tooltip the unit is on, and secret
health hiding the value text. It fails against the 5.10.1 module in every one of those areas. Its
mutations are the `tooltip` entries in `mutate_client.lua`.

`flyout_harness.lua` loads the whole of `Libs/LibActionButton-1.0-GE` as an upgrade over an older copy
with one button, because that runs `InitializeEventHandler` at load - the call the first `CreateButton`
makes, which with the player logged in discovers flyouts at once. It models the two ways a client
answers `GetFlyoutInfo` for an unknown ID: raising (Retail 12.1.0, Forever before 1.60.1.70009) and
returning nothing (Forever 1.60.1.70009's `C_Flyout`, `MayReturnNothing`). The second took every action
bar with it (FixLog 2026-09-25). The old button stops the load the moment it is touched, so button code
never runs against the stubs; reaching it is the proof that discovery finished. Its mutations are the
`flyout` entries in `mutate_client.lua`.

`nameplate_harness.lua` is the contract for the nameplate overhaul (`Docs/Nameplates Overhaul
Plan.md`). It loads the real module - every `NamePlates\*.lua` file, in the order
`Components/UnitFrames/UnitFrames.xml` lists them, so it also proves that order - with the layout
data, colours and interrupt database, against a fake of oUF's nameplate driver that does what
`Libs/oUF/ouf.lua:1000-1070` does, and walks eleven plates of every kind through a scripted session.
Some checks are about work rather than looks (a target change touches only the plates that changed,
nothing polls while nothing is hovered); they count widget calls, which the golden file cannot see. Three outputs: named checks for the behaviours
that must survive; `nameplate_golden.txt`, every plate's visible state after every step (only the
plates that changed are written); and `nameplate_metrics.txt`, widget calls and plates touched per
step. A deliberate behaviour change is a reviewed golden diff re-recorded with `--record`; a
performance change is checked with `--metrics` and re-recorded with `--record-metrics`. The fake
oUF elements copy what the real ones do to visibility (castbar hidden when idle, raid marker and
threat glow only when set), because the first draft showed all three on every plate and the golden
file was recording the stub. The fake castbar update does what oUF's `CastStart` does (a running cast
shown, none cleared and hidden), and each step ends with the frame boundary, oUF's OnUpdate hiding an
idle castbar. The golden cannot see what was on screen for the frame before that boundary, so a named
check does: no step may end with an idle castbar shown (FixLog 2026-09-25). Plates draw their auras through Blizzard's native `AuraContainer` on
Retail; the harness loads the real `Auras/PlayerAuraContainers.lua` against a fake container that
keeps the unit, the on/off state and how often it was told to re-read, and rejects the inputs
`Blizzard_CustomAuraContainer.lua` would (unknown filter tokens, candidate filters or layout keys).
Which auras it would show is the client's and is not modelled; which kinds a container asks for (the
Aura filters settings) is, group by group. Blizzard's stacking option is a fake bitfield CVar behind
`C_CVar.GetCVarBitfield` / `SetCVarBitfield`, so the passthrough's reads, writes and combat hold are
checked. The execute marker's tint goes through `UnitHealthPercent` with a step curve: the harness
evaluates the curve against a per-unit `healthPercent` and hands back a secret number that `type()`
calls a number but that raises on arithmetic or comparison, as the client's does, so a marker that
did maths on its answer would fail here. Standing down for another nameplate addon (`W.addons`) is
checked for CVar writes and reloads. The CVars are Retail 12.1's, by the names both clients have
(`nameplateShowFriendlyPlayers`, `nameplateShowFriendlyNpcs`, `nameplateSize` and so on), and a write to
any other is refused and counted, as the client refuses it; a named check holds the whole session to
none. A vendor that cannot be assisted and a follower companion (`UnitTreatAsPlayerForDisplay`) stand
for the friendly NPCs `UnitCanAssist` used to miss (FixLog 2026-09-25). It runs in its own environment so it cannot leave globals behind for the next harness in
`mutate_client.lua`.

`locale_harness.lua` loads every `Locale/*.lua` through a stub AceLocale instead of parsing it, so
it sees keys exactly as the client does - the `\n` keys a pattern once dropped included. It fails
when a locale lacks an enUS key or has an extra one, defines a key twice, leaves a value empty,
moves or changes a format specifier, or lets a preview explanation or tab label outgrow the panel.
The explanations are read out of `Options/Kit/Preview.lua` and the widths out of
`Options/Kit/Panel.lua`, so neither is a copy that can drift. Adding an enUS key fails it until the
nine translations are in.

`tracker_harness.lua` also only needs the addon root. It runs the real tracker module and
`Core/API/SecureDrivers.lua` against two Blizzard behaviours copied from source: a
`SecureHandlerStateTemplate` only runs snippets for `state-*` attributes, and a state driver's
`Hide()` on an already hidden frame fires no `OnHide`. The module used to be wrong about both. Its
mutations are the `tracker` entries in `mutate_client.lua`.

Two arguments: the addon root, then this folder. Both harness files and `stubs.lua` are found
relative to the second.

`client_harness.lua` only needs the addon root. It executes real compatibility,
module and library files with deliberately missing client capabilities. It does
not emulate secret values or protected frame security; `/reload` and combat tests
on both clients remain required. See `Docs/CLIENT_COMPATIBILITY.md`.

`diel_harness.lua` also only needs the addon root. It slices the day and night
block straight out of `Components/Misc/Minimap.lua` - between its two section
comments - and runs that real source against a stubbed client, so it tests the
shipped file rather than a copy that drifts from it. Move those comments and it
fails loudly rather than silently testing nothing. It cannot see textures, frame
strata, Blizzard's Edit Mode or a real cycle transition.

`combo_points_harness.lua` also only needs the addon root. It runs the real oUF
ClassPower element, the real PlayerClassPower style and the real layout data against
a secret stand-in that reports as a number but throws on any arithmetic, ordering
comparison or indexing - Forever returns combo points that way even out of combat.
Its curve and StatusBar model Blizzard's documented Step and clamp behavior; they
are not the client. `mutate_client.lua` carries its mutations.

For client-aware API, UI-source, TOC/XML, and Forever game-data checks, use
[Hated WoW MCP](https://github.com/RdyGaming/hated-wow-mcp) with `flavor: "forever"`.
For isolated Lua 5.1 taint experiments, use `Tools/Run-Elune.ps1`. Neither tool
replaces the harnesses or live `/reload` testing.

Mutation runs â€” do the checks above actually catch a break?

```sh
python Tools/Harness/mutate.py . Tools/Harness     # Config.lua
python Tools/Harness/mutate_sections.py            # the panel, the kit, the controls, the stubs
lua Tools/Harness/mutate_client.lua .              # client gates, entirely in memory
```

`mutate_sections.py` runs the panel harness by default and the kit harness for the mutations that
name it - the window's own edge is measured against `Layouts/Data/Tooltips.lua`, which is a kit
check. Both are run clean first and again at the end.

`mutate_sections.py` has the addon root and the Lua path at the top of the file. It backs up every
file it edits and restores it, and prints `restored:` at the end â€” if that line is missing or shows
failures, check `git status` before doing anything else.

## The rule that matters

`proc_highlight_harness.lua` accepts an optional mutation name after the root:
`ring-always-shown`, `show-after-restyle`, `no-neutral-colour`, `preview-reallocated`,
`wrong-visibility-setting`, or `skyriding-always-hidden`. Each must fail. Mutations
only change the loaded source in memory; they never edit the working files.

`cooldown_manager_harness.lua` takes the same kind of argument: `themed-art`, `circle-unthemed`, `no-revert`,
`base-first`, `fade-ignores-opacity`, `rebuild-in-combat` or `writes-blizzard`. Each must fail,
and a mutation whose pattern no longer matches the source stops the run instead of passing.

`target_execute_harness.lua` loads the real target module and tier layouts, the shared
nameplate threshold resolver, and the real target option table. It covers every tier,
both fill directions, base and SaiyaRatt art, bar scaling, threshold zero, friendly and
non-attackable targets, faction changes, class/spec callbacks, missing capabilities,
and off/on reuse. Opaque health results reach SetAlpha without arithmetic or comparisons.
Run each of these mutations separately after the root argument; each must fail:
`default-on`, `ignores-off`, `friendly`, `non-attackable`, `zero`, `wrong-tier`,
`wrong-direction`, `wrong-crop`, `wrong-line-slice`, `ignores-scale`, `secret-math`,
`wrong-step`, `no-show`, `no-capability`, `no-faction-event`, `no-class-callback`,
`no-health-update`, `no-shared-notify`, `duplicate-setting`.

For tainted addon execution against the same synthetic widgets:
`Tools/Run-Elune.ps1 -Script Tools/Harness/target_execute_harness.lua . --taint`.
Elune checks tainted calls and an untouched native sentinel; it does not emulate protected
WoW frames or certify live combat safety. The harness cannot judge the marker's visual
contrast, and both clients still require the FixLog gameplay battery.

`cdready_harness.lua` loads the entire real Debugging.lua and invokes its actual
/azdebug dispatcher. Runs Retail/Forever fixtures with opaque getter values, duration
objects and callback arguments. It covers dormant load, Development Mode gating,
missing APIs (named), global/namespaced combat APIs, direct duration feed, GCD exclusion, shown-state readiness, nil/failed
inputs, callbacks during feed and natural expiry, combat entry/exit, polling, retargeting
without duplicate loops, and off/dev-mode cleanup. The 2026-10-08 comparison covers five
independent widgets (cooldown ignore/include GCD, charges, cached action slot and resolved spell), per-source callback labels/counters,
missing/secret charge inputs, charge events and one-second re-feed even without events. It cannot certify the real client's
widget lifecycle, secrecy or combat safety. Logger-present Retail/Forever fixtures
also cover the installed DLAPI format contract, literal percent signs, sanitized
secrets/nil, exclusive logger output for async callbacks, absent/malformed/throwing
API fallback and resumed logging. Cooldown-ready harness checks Inspect delegates
to this shared sink rather than printing directly.

Run each mutation separately after the root argument; each must fail:
`ungated`, `visible`, `hidden-parent`, `gcd`, `secret-shown`, `secret-print`, `nil-ready`,
`feed-failure-ready`, `no-done`, `no-event`, `no-poll`, `no-stop`, `old-loop`, `no-route`,
`callback-boolean`, `wrong-origin`, `no-global-fallback`,
`no-preview-route`, `preview-ungated`, `preview-no-stop`, `no-charge-lane`,
`wrong-charge-getter`, `with-gcd-ignored`, `no-refeed`, `no-lane-label`,
`no-charge-event`, `partial-stop`, `missing-charge-ready`, `no-log-sink`, `log-format`,
`no-log-fallback`, `secret-log`, `log-chat-duplicate`, `async-chat`,
`action-gcd`, `action-wrong-id`, `action-combat-resolve`, `action-secret-id`,
`action-wrong-kind`, `action-no-invalidate`, `action-ready-missing`,
`action-no-resolved-lane`, `action-base-as-resolved`, `action-no-match`, `action-largest-slot`,
`slot-blanket-invalidate`, `slot-ignore-watched`, `slot-secret-print`, `slot-combat-read`,
`slot-mismatch-ready`, `slot-no-exit-recheck`, `slot-stop-resolved`, `slot-rebind-duplicate`.
Action fixtures cover deterministic own-button matching, base/override resolution,
empty original spell timer alongside an active action/variant timer, combat reuse
without button/API mapping reads, source recovery, secret durations/IDs, missing APIs,
slot/page/bonus validation and full Stop cleanup. Unsupported sources remain unknown.
The 2026-10-09 repair checks unrelated slot events OOC/in combat, recovery after those
events, safe slot-payload logging (including nil/zero/secret/invalid payloads), unchanged
watched-slot revalidation, duplicate bindings preserving the same cached slot, changed
spell mappings, action-only combat deferral, independent resolved-spell sampling, and
exit/first-OOC-tick recovery without buttons being read in combat.
Cooldown-ready logging mutation: `inspect-no-sink`.
Elune: `Tools/Run-Elune.ps1 -Script Tools/Harness/cdready_harness.lua . --taint`.
The Retail Paladin live guide is `Docs/Cooldown Ready Probe - Retail Paladin.md`.

`cdready_menu_harness.lua` loads real Debugging.lua, Options, Kit Panel/Config/Renderer/
Controls/Combat and the registered Debug page. It drives actual control callbacks
with handler spies (the real probe/dispatch is covered by cdready_harness). Retail
and Forever cover five section jumps, no native popup/automatic start, three widths
with positive-height nonoverlapping rows, presets/manual IDs, invalid/missing API,
dev/combat/secret gates, closing without stopping, dynamic visible-state refresh,
immediate start/status/stop and scratch input, OOC drawing refusal and queued repair
flush. Offline font/widget fixtures cannot establish live rendering or WoW taint.
Run each mutation independently: `wrong-panel`, `wrong-tab`, `no-immediate`,
`all-immediate`, `renderer-no-path`, `auto-start`, `ungated`, `invalid-start`,
`missing-api`, `combat-preview`, `combat-inspect`, `secret-combat`, `forever-preset`,
`no-stop`, `no-inspect`, `bad-id`, `no-queue-repair`, `no-refresh`, `auto-nameplate`.
Elune: `Tools/Run-Elune.ps1 -Script Tools/Harness/cdready_menu_harness.lua . --taint`.

**A check that has never failed has never been shown to work.** Every group of checks gets a
mutation entry before it is trusted. This panel has now produced five separate stub lies, each of
which passed every check it should have failed:

| The stub said | It should have said |
| --- | --- |
| every font is valid | only the sizes `FontStyles.xml` defines |
| `IsShown()` is always false | what `Show`/`Hide`/`SetShown` were last told |
| any unset field is a no-op function | `nil`, unless the name starts with a capital |
| the scroll range is 4000, and scrolling never clamps | child height minus view height, clamped |
| every string is 12px tall | as many lines as it wraps to at that width |

Each one hid a real defect. When a check passes on the first run, suspect the stub.

## Cooldown-ready alerts (Option 2b)

`lua Tools/Harness/cooldown_ready_harness.lua .` loads the real module and options through
cooldown_manager_harness.lua's sealed Blizzard item fixtures. Retail/Forever-shaped runs cover
default-off allocation, per-viewer switches, GCD exclusion, active-to-ready combat transitions,
initial/repeated readiness, native expiry without a callback, all three styles, optional sound,
opaque duration forwarding, secret/unreadable shown state, nil/refused feeds, slot overrides/reuse,
hidden/released slots, charge-capable ordinary cooldown eligibility, profile/off/module cleanup, conflict choices and missing
APIs/widget methods. Plain Lua cannot reproduce actual secret values; mutations verify the guards.

The art checks read shipped TGA RGB and alpha, compare 104 painted aperture rows
along both axes at 30/40/50/70px, and require controlled icon overlap under the visible
metal rather than matching black shadow alpha. They also check opaque icon-center
coverage, full-icon mask attachment/visibility, 30px Utility geometry, fixed outer
casing size, draw layers, foreground level/current strata, longer square timing and
unchanged Circular geometry. Preview/inspect tests cover Development Mode/combat
gates, silent charge-icon rendering independent of readiness, secret-safe diagnostics,
reuse, expiry and profile/module cleanup. Plain Lua does not render WoW masks/blends.

Each mutation must fail on its own:
`default-on`, `no-gate`, `gcd`, `initial-ready`, `repeat`, `secret-shown`, `nil-ready`,
`feed-ready`, `slot-reset`, `released`, `charges`, `unknown-charges`,
`no-charge-event`, `charge-event-capability`, `late-poll`, `base-first`, `off-events`, `off-update`,
`circle-art`, `sound-off`, `no-sound`, `no-event`, `no-poll`, `writes-blizzard`,
`loose-square`, `loose-rounded`, `no-border-flash`, `small-outline`,
`short-square-pulse`, `no-hold`, `circle-flash`, `dark-flash`,
`unmasked-flash`, `stale-level`, `wrong-mask`, `no-icon-flash`, `outline-icon-mask`,
`hidden-icon-mask`, `stale-strata`, `preview-sound`, `preview-combat`, `preview-dev`,
`preview-cleanup`, `inspect-secret`.
Example: `lua Tools/Harness/cooldown_ready_harness.lua . secret-shown`.

`Tools/Run-Elune.ps1 -Script Tools/Harness/cooldown_ready_harness.lua . --taint`
runs the same module with a tainted caller and an untouched native sentinel. Synthetic widgets
cannot certify Blizzard frame taint or live widget secrecy. Live steps:
`Docs/Cooldown Ready Alerts - Retail Paladin.md`.

## editmode_selection_hide_harness.lua

Run with `Tools/Run-Elune.ps1 -Script Tools/Harness/editmode_selection_hide_harness.lua`. Models the Edit Mode selection-overlay hide (`ns.HideEditModeSelection`): the post-hook hides the overlay, Blizzard's secure path stays secure, and the registry is untouched; a negative control shows registry mutation taints. Frames are tables, so live `/reload` + Edit Mode is still owed. `Tools/Audit-EditModeSystems.py` lists Edit Mode systems per client (its `REPLACED` map is a rough guide).

Legacy compact HUD: `lua Tools/Harness/legacy_hud_harness.lua .` loads real layout data and AceDB. Health prediction also covers Legacy rectangular fills. Offline only; see `Docs/Legacy HUD.md` for the live loop.

### Cooldown-ready representative regressions (2026-10-09)

`cooldown_ready_harness.lua` now crosses eight representative metadata IDs, both charge flags, both viewers, override mapping and both recovery events. These synthetic IDs/flags exercise shared logic; they do not certify live spell/talent behavior. Tests also cover unknown/secret charge flags, absent charge-event capability, ordinary-ready silence for charge-capable spells, and native expiry within one 100 ms poll. Baseline and Elune-tainted: 864 checks. All 45 independent mutations fail, including restored blanket charge exclusion, removed charge event, ignored event capability and a one-second poll. Run via `Tools/Run-Elune.ps1 -Script Tools/Harness/cooldown_ready_harness.lua . [--taint|mutation]`. Live five-spell battery: `Docs/Cooldown Ready Alerts - Retail Paladin.md`.

Edit Mode movers (Elune): `Tools/Run-Elune.ps1 -Script Tools/Harness/editmode_mover_callback_harness.lua` models
`EventRegistry`'s `EditMode.Enter`/`Exit` callbacks (secure event-key barrier, `securecallfunction`) and checks that
Blizzard's Edit Mode path stays secure while our movers show and hide.

Mover anchoring (`Docs/Mover Anchoring Plan.md`): `lua Tools/Harness/mover_anchoring_harness.lua .` checks
`Core/API/Anchoring.lua` against SetPoint's rules (every point round-trips, links, offsets, cycles, chain order).
`lua Tools/Harness/mover_links_harness.lua .` loads the real `Core/MovableFrameManager.lua` on frames that keep
their real size and point (not `stubs.lua`, whose constant geometry would hide this): followers, chains, refused
loops, the real OnDragStop, rescale, combat wait, disabled targets, per-HUD links, a saved loop, and the `/lock`
window's anchoring rows. The `PROPAGATING` guard is an efficiency guard; removing it changes no result.

Frame settings panel (`Options/Kit/FramePanel.lua`): `lua Tools/Harness/frame_panel_harness.lua . Tools/Harness [Forever]`
builds the real option pages and checks every quick-settings path, that each key is a real mover (found by
following `Components/Components.xml` includes), five rows at most, sections that exist, and the page's own hide
rules (Day and Night only on Forever, bars 6-8 only on Retail; Player Alternate and Player (Party Style) listed
with only their switch while Player is on), and that the three player frame switches leave one on at a time.
`panel_harness.lua`'s "Frame settings panel" section builds, opens, refreshes and closes the window on the Kit stubs.

Player as a party frame (`Components/UnitFrames/Units/PlayerParty.lua`): `lua Tools/Harness/player_party_harness.lua .`
loads the real module and party layout against a recording frame: spawned once, the portrait switch shrinks the
frame to its bar and moves role, leader, raid marker, ready check/summon/resurrect and combat text onto it and back,
nothing is laid out in combat, Legacy keeps its own layout, another player frame on keeps it off at start-up, Color
by Class. Four mutants in `mutate_client.lua`. Party.lua's style itself is not run; the look is a live check.

Layout copy: `lua Tools/Harness/layout_copy_harness.lua .` runs `Core/API/Layout.lua` on an AceDB-shaped table, both `CopyLayout` and `ResetLayout` (the `/lock` window's Reset layout).

Raid25/Raid40 merge: `lua Tools/Harness/raid_merge_harness.lua . [old Raid25.lua] [old Raid40.lua]` loads
`Components/UnitFrames/Units/RaidLarge.lua`; given the pre-merge files (`git show 9292b5f:Components/UnitFrames/Units/Raid25.lua`,
same for Raid40) it compares defaults, header attributes, header sizes and every button placement with them.

Smoother combat: `lua Tools/Harness/smooth_combat_harness.lua .` runs the real cooldown timer at 144 fps on a moved
clock (text written only on change, text-only cooldowns at 10 a second, bars every tick, tenths in the last second)
and counts Explorer Mode's settings passes per event. Run it on a folder holding the HEAD files to see what changed.

Eased bars: `lua Tools/Harness/smooth_bars_harness.lua .` loads the real UnitFrame.lua (smoothing switch, list of
bars, /azsmooth) and Functions.lua (API.UpdateHealth/UpdatePower: plain updates ease, forced ones snap). The bar
stub only has real StatusBar methods: an addon field like DisableSmoothing must read nil, as in the game.

Target health crop: `lua Tools/Harness/target_health_crop_harness.lua . [mutation]` cuts the real block of
Target.lua from `GetTargetBarGrowth` to `SyncTargetHealthVisualState` and runs it on stubs: the crop helper's
reversed direction, snap vs eased follow (no one-second cut-off), redraws snap, switch-off finishes the crop,
0..1 vs 0..100 percent sources, secret percents untouched, the spark on the helper's edge. Mutations
`one-second-follow`, `mirror-0-100`, `spark-at-end`, `no-snap-on-redraw` must each fail.

World map canvas taint (Elune): `Tools/Run-Elune.ps1 -Script Tools/Harness/worldmap_canvas_taint_probe.lua`. Models the
map scroll container's scale fields in Blizzard's read-then-write order: an addon call to `OnFrameSizeChanged` leaves
`currentScale` tainted, Blizzard's own rebuilds and `OnUpdate` keep it tainted (until /reload), and `AcquirePin` is then
insecure before `SetPropagateMouseClicks`. Also shows `securecall`/`pcall` from addon code and addon "scrub" writes do not
clean it. 12 checks; case 2 (5.26.0) against case 4 (fix) is the mutation pair. No frames: live combat map opening is owed.

Druid theme and Lite+: `lua Tools/Harness/druid_theme_harness.lua . mutations` runs the real engine, Druid module and effects dispatcher against recording widgets. It rejects native resource reads/resizing, checks Moonwell fill ownership, native clipping, root layers, cleanup, strength and mirrored/threat art. Three in-memory mutants must fail for the intended reason. Client rendering remains a live check.

Moonwell+ reactive orb: `lua Tools/Harness/moonwell_slosh_harness.lua . mutations` loads the real effect and Lite+ dispatcher. Native resource getters and clip geometry reads throw; checks cover native clipping anchors, 32 columns, palette, quiet/moving/combat/mounted/flying, secret/missing optional state APIs, combat ticking, throttling, hidden/clear cleanup, strength, resizing and rejected mutants. It also executes the actual Player.lua material setter/PostUpdate callback: Flowing mana defaults off, gates on displayed mana across classes, preserves all four native material choices and theme/Lite+ paint, shapes troughs using the actual empty backdrop with a clipped lower-edge rim, ignores Moonwell's separate strength, and switches resource identity in combat without per-update rebuilds. Paladin/Druid harnesses additionally run the real theme modules with slosh, checking retained sphere/wisp players, phase, allocation reuse and draw order. `geometry <output.json>` writes actual Moonwell column dips for offline review. WoW clipping/taint/performance remain live tests in Assets/Druid/README.md and Docs/Flowing Mana.md.

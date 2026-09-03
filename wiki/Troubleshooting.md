# Troubleshooting

## Basic recovery loop

1. `/reload`
2. Reproduce the problem once
3. Check BugSack/BugGrabber for an error
4. Retest with only AzeriteUI enabled

`/buggrabber reset` before step 2 clears old errors so you can tell which ones are new.

## Addon not loading

- Folder must be named exactly `AzeriteUI5_JuNNeZ_Edition`.
- Enabled at the character screen.
- Retail client. This addon has no Classic branches.

## Frames missing or in the wrong place

- `/lock` and check the anchors.
- Check which profile is active in `/az` -> Settings Profile.
- **Unit Frames -> (family) -> Visibility** decides which family appears at which
  group size. A missing party frame is usually a visibility toggle, not a bug.
- Reset the current profile before resetting the database.

## A bar or frame keeps fading out

Two independent systems can hide things:

- **Action Bars -> (bar) -> Enable Bar Fading**
- **Explorer Mode -> Elements to Fade**

Check both before assuming a bug.

## Raid frames suddenly reordered

Expected as of 5.3.90. Role sorting on Raid (25) and (40) had been silently ignored
for years and now works, so those frames sort tanks, healers, damage. Set **Sort By**
to Group for the old join order.

## Nameplate or castbar oddities

- Confirm the nameplate options in `/az`.
- Test with other nameplate addons disabled - Plater and AzeriteUI nameplates cannot
  both own the same plate.
- `/azdebug nameplates <unit>` dumps one unit's state.

## Target castbar looks wrong

`/azdebugtarget status` on a hostile target prints the health bar's and the castbar's
fill direction and flags a mismatch. Both should read the same. `/azdebugtarget cast`,
run mid-cast, dumps the full render path.

## Retail 12.1 secret-value errors

If BugSack shows `Secret values are only allowed during untainted execution`:

- Update to the latest release first.
- `/buggrabber reset`, `/reload`, reproduce.
- Retest with only AzeriteUI enabled.
- Report it with the full stack trace - these are worth reporting even when the UI
  looks fine, because they name the exact call that lost access.

## Blizzard action button taint

If you see `ADDON_ACTION_BLOCKED` on `ActionButton12:SetAttribute()`, or a repeating
`ActionButton.lua ... SetCooldown ... Secret values` error, run **`/azdebug taint`
during the fight, after the errors have started**. It names the addon blamed for each
tainted field on every Blizzard action, pet and stance button. That output is the
single most useful thing to attach to such a report.

## Reporting a bug

Include:

- Exact steps to reproduce
- Where it happened - open world, dungeon, raid, arena, battleground
- Whether it survives a reload, and whether it happens with only AzeriteUI enabled
- The full error text from BugSack, not a screenshot of the first line
- Your addon version, from `/dump C_AddOns.GetAddOnMetadata("AzeriteUI5_JuNNeZ_Edition","Version")`
- Whether you installed from CurseForge, Wago or GitHub

Issues: <https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues>

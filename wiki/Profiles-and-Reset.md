# Profiles and Reset

All settings live in the `AzeriteUI5_DB` saved variable, with Ace3 profiles on top.
Every option in `/az` is stored per profile, except the handful of global switches
such as development mode.

## Profile operations

`/az` -> Settings Profile:

- Select the active profile
- Create a new profile
- Duplicate the current profile under a new name
- Delete a profile other than the active one
- Reset the current profile to defaults

## Full reset

`/resetsettings` resets the whole database - **every profile, not just the active
one**. It is a hard-recovery tool, not a "start over on this character" tool.

## Recommended workflow

1. Duplicate your profile before any large layout experiment. It costs nothing and it
   is the only undo that exists.
2. If something looks wrong, reset the *current profile* first.
3. Only fall back to `/resetsettings` when a reset profile still misbehaves, which
   usually means the problem is in global state rather than profile state.

## Settings that survive a profile switch

A few things are global rather than per profile:

- Development mode (`/devmode`)
- Debug toggles set through `/azdebug`

These stay put when you change profiles, and `/resetsettings` does clear them.

## Presets

`/saiyaratt` applies the SaiyaRatt preset profile and layout - a different target
frame and player frame treatment built on the same modules.

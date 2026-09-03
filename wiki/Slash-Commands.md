# Slash Commands

## Player commands

| Command | What it does |
| --- | --- |
| `/az`, `/azerite` | Open the AzeriteUI options menu. |
| `/lock` | Toggle frame movement mode for AzeriteUI-owned frames. Blizzard-owned frames use Blizzard's Edit Mode instead. |
| `/clear` | Clear the chat window. |
| `/resetsettings` | Reset the AzeriteUI database. **Destructive - this erases every profile.** |
| `/setminimaptheme <name>` | Switch the minimap theme. Two ship: `Azerite` and `Blizzard`. Names are matched case-insensitively, and the command is ignored in combat. |
| `/saiyaratt` | Apply the SaiyaRatt preset profile and layout. |
| `/devmode` | Toggle development mode, then reload. Turns on the version label in the corner and unlocks the developer-only options. |
| `/sanitybarfix debug` | Toggle debug printing for the alternate power bar ("sanity bar") fix. Dev mode only. |

## Debug commands

These register for everyone. Running one without development mode prints a notice
that some features are limited, then continues - it is not blocked.

| Command | What it does |
| --- | --- |
| `/azdebug` | Toggle the debug menu, or run a subcommand. |
| `/azdebugkeys` | Keybinding and LibKeyBound diagnostics. |
| `/azdebugtarget` | Target frame and target castbar diagnostics. |
| `/aztest` | Runtime unit-frame test menu. Restricted to the maintainer's character. |

### /azdebug subcommands

```text
/azdebug                       toggle the menu
/azdebug help                  print this list in game
/azdebug status
/azdebug group                 party/raid header report
/azdebug taint                 who tainted Blizzard's action buttons
/azdebug health [on|off|toggle]
/azdebug health filter <text>  example: Target.
/azdebug healthchat [on|off|toggle]
/azdebug bars [on|off|toggle]
/azdebug fixes [on|off|toggle]
/azdebug dump target|player|tot|all
/azdebug aurasnapshot [player|topright|target|both]
/azdebug nameplates [unit]
/azdebug snapshot [unit]
/azdebug blizzard enable
/azdebug scale                 print scale status
/azdebug scale nameplates [unit]
/azdebug scale reset
/azdebug keys <subcommand>
/azdebug raidbar status
/azdebug raidbar [on|off|toggle]
/azdebug scripterrors
/azdebug secrettest [unit]
```

`/azdebug taint` is the one to run if Blizzard's hidden action buttons start throwing
`ADDON_ACTION_BLOCKED` or secret-value errors. It names the addon blamed for each
tainted field on every Blizzard action, pet and stance button. Run it after the errors
have already started, not before.

### /azdebugtarget subcommands

```text
/azdebugtarget                 toggle the menu
/azdebugtarget status
/azdebugtarget dump|snapshot|refresh|secrettest
/azdebugtarget mirror [on|off|toggle|status]   castbar art: mirrored vs tier
/azdebugtarget crop [overlay|native|toggle|status]   castbar fill: crop vs scale
/azdebugtarget cast            live castbar dump - run it mid-cast
```

`status` reports both the health bar's and the castbar's live fill direction and flags
a mismatch between them, which is the fastest check when a target bar looks like it is
filling the wrong way.

## Development-mode commands

Only registered while development mode is on (`/devmode`):

| Command | What it does |
| --- | --- |
| `/serial` | Serialize the current action bar profile into a copyable window. |
| `/toggleblips` | Show Blizzard's minimap blip atlas at native size, for re-cutting the icons after a Blizzard art update. |

## Notes

- `/reload` after large structural changes, especially anything that rebuilds group frames.
- `/resetsettings` is destructive and takes every profile with it. Duplicate a profile
  first if you only want a clean slate to experiment in.

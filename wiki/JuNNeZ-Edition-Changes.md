# JuNNeZ Edition Changes

The JuNNeZ Edition is an unofficial fan modification of [AzeriteUI 5](https://github.com/goldpawsstuff/AzeriteUI5) by GoldpawsStuff. This page documents what makes this edition different from the original release.

> **This edition is not affiliated with GoldpawsStuff.** JuNNeZ maintains this fork independently, with permission from the original author.

---

## Why a JuNNeZ Edition?

AzeriteUI 5 is an outstanding addon, but the WoW 12 (Midnight) expansion introduced significant API changes that broke several systems. The official release is updated by GoldpawsStuff, but the JuNNeZ Edition:

- Applies compatibility fixes faster in some cases
- Includes experimental patches and quality-of-life improvements not in the official release
- Is specifically focused on **Retail WoW 12** only (the Classic codepath was removed)
- Tracks bugs and fixes independently with detailed change documentation

---

## Changes vs. Official AzeriteUI 5

### WoW 12 (Midnight) Compatibility

| Change | Details |
|---|---|
| **Secret-value safe geometry reads** | WoW 12 uses "secret-valued" numbers in restricted environments. AzeriteUI JuNNeZ Edition uses `ns.GetSafeGeometryValue()` wrappers to read these safely without taint errors. |
| **ActionButton cooldown sanitization** | LibActionButton-1.0-GE was patched to sanitize secret/unsafe cooldown, charge, and loss-of-control payloads before passing them to `ActionButton_ApplyCooldown`. |
| **Aura payload guards** | oUF's aura element and the Auras module received additional WoW 12 aura payload guards to prevent script breaks under heavy aura churn. |
| **Decursive aura compatibility** | The `UnitDebuff` combat sourcing path was reworked to prefer Blizzard filtered aura query APIs first, fixing Decursive's dispel classification in WoW 12 combat. |

### Action Bars

| Change | Details |
|---|---|
| **Actionbar live-update fixes** | Action buttons now correctly refresh their state (cooldowns, availability, charges) in real-time during gameplay — fixes a lag issue in the official release. |

### Unit Frames / Auras

| Change | Details |
|---|---|
| **Player-row aura stock stability** | Stabilized WoW 12 player-row aura classification during combat secret-value windows to prevent flickering and false dimming. |
| **Always Show Full Brightness option** | Added a new aura option to show all player frame auras at full brightness, bypassing the bright/dim classification. |
| **Aura snapshot debug command** | `/azdebug aurasnapshot [unit]` provides live aura diagnostics with spell ID/name resolution for post-combat classification auditing. |

### Tooltips

| Change | Details |
|---|---|
| **Compare tooltip relayout** | Fixed compare-item tooltip overlap with deferred relayout handling after size/show events. Compare tooltips now maintain stable spacing even when content changes size after initial show. |
| **Managed tooltip filtering** | AzeriteUI now limits its tooltip skinning to known managed tooltip frames only, preventing unintended skinning of dropdown menus and unrelated frames. |

### Code Quality

| Change | Details |
|---|---|
| **Retail-only codebase** | After 5.3.46-JuNNeZ, all Classic WoW support was removed, simplifying the codebase for maintainability. |
| **Detailed fix documentation** | `CHANGELOG.md` and `FixLog.md` document every change with technical context, making it easier to understand what was changed and why. |

---

## Experimental Features

These features are available in the JuNNeZ Edition but may not appear in the official release:

- **Player Alternate Frame** — A horizontal-bar player frame style as an alternative to the default orb/crystal design. Accessible via Development Mode.
- **Development Mode toggle** (`/devmode`) — Enables in-progress features for testing.
- **Extended aura debug tooling** — Richer diagnostics for aura classification issues.

---

## Version History

See the [CHANGELOG](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/blob/main/CHANGELOG.md) for a complete version history with detailed release notes.

---

## Upstream Merges

The JuNNeZ Edition periodically merges upstream changes from the official AzeriteUI 5 repository to stay current with the original author's improvements and new features. JuNNeZ-specific patches are then re-applied on top.

---

## Contributing

If you discover a bug or have a fix to contribute:

1. Open a [GitHub Issue](https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues)
2. Or submit a Pull Request on GitHub

Please include:
- Your WoW version and interface number
- AzeriteUI JuNNeZ Edition version (`/az` → bottom of panel or from the TOC)
- The exact Lua error text (if applicable)
- Steps to reproduce the issue

# Nameplates and Auras

## Nameplates
AzeriteUI nameplates support:
- Friendly/enemy-specific scale behavior
- Target-focused readability
- Health text placement options
- Castbar state color handling
- Aura display controls

## Interrupt state readability
Typical behavior:
- Ready interrupt: ready-state color
- Interrupt on cooldown: cooldown-state color
- Protected/non-interruptible cast: protected-state color

## Auras
AzeriteUI supports stock and custom filtering paths for key unit frames and aura rows.

Common filter goals:
- Keep high-value debuffs prominent
- Keep important externals visible
- Reduce noise from low-value buffs

## WoW 12 secret-value behavior
In WoW 12, some combat values can be secret-protected by Blizzard.
AzeriteUI includes fail-safe handling to avoid user-facing errors while preserving stable visuals.

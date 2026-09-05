# AzeriteUI 5 - JuNNeZ Edition Wiki

AzeriteUI 5 JuNNeZ Edition is a full UI replacement for World of Warcraft Retail.
It is an unofficial, fan-maintained edition of [AzeriteUI 5](https://github.com/goldpawsstuff/AzeriteUI5) by GoldpawsStuff.

Current release: **5.4.3-JuNNeZ**, built against **Interface 120100** (Retail 12.1).

## Quick links

- [Installation and Setup](Installation-and-Setup.md)
- [Slash Commands](Slash-Commands.md)
- [Options Menu Guide](Options-Menu-Guide.md)
- [Unit Frames](Unit-Frames.md)
- [Action Bars](Action-Bars.md)
- [Nameplates and Auras](Nameplates-and-Auras.md)
- [Explorer Mode](Explorer-Mode.md)
- [Tooltips, Chat, Minimap, Bags](Tooltips-Chat-Minimap-Bags.md)
- [Profiles and Reset](Profiles-and-Reset.md)
- [Troubleshooting](Troubleshooting.md)
- [FAQ](FAQ.md)

## Supported version

Retail only. The addon was consolidated to a retail-only codebase in 5.3.46-JuNNeZ;
there are no Classic, Cata or MoP branches left in it.

## Main commands

| Command | What it does |
| --- | --- |
| `/az`, `/azerite` | Open the options menu |
| `/lock` | Toggle AzeriteUI's frame movers |
| `/clear` | Clear the chat window |
| `/resetsettings` | Reset the whole addon database, every profile |
| `/setminimaptheme <name>` | Switch minimap theme (`Azerite` or `Blizzard`) |
| `/saiyaratt` | Apply the SaiyaRatt preset layout |
| `/devmode` | Toggle development mode and reload |
| `/azdebug` | Open the debug tools |

The full list, including the debug subcommands, is on [Slash Commands](Slash-Commands.md).

## What this edition adds

Beyond the upstream 5 series, this edition carries ongoing Retail 12.1 work:

- **Secret-value handling.** Retail 12.1 protects more combat, aura, cooldown and unit
  data as secret values. The addon hands those values to Blizzard-owned widgets rather
  than reading or formatting them, so bars keep working where naive code breaks.
- **Group frame sorting** by group, role, class or name, on Party, Raid (5), (25) and (40).
- **Per-context player toggles** - show or hide your own frame separately for parties
  and for raid-sized groups.
- **Specialization icons** on party and raid frames.
- **Ability pings and resource callouts** on AzeriteUI action bars and the player frame.
- **Micro menu toggle** - Blizzard's bottom strip and the AzeriteUI cog wheel are
  independently switchable.
- **Explorer Mode tooltips** on every interactive option.
- Ten fully populated locales.

## Reporting issues

GitHub Issues: <https://github.com/JuNNeZ/AzeriteUI5-JuNNeZ-Edition/issues>

Please include:

- Steps to reproduce
- Expected vs actual behavior
- Lua errors from BugSack/BugGrabber if available
- Whether it still happens with only AzeriteUI enabled
- Screenshots if the problem is visual

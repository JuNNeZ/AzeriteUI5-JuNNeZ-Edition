# Explorer Mode

Explorer Mode fades parts of the UI when you are not using them, for a cleaner view of
the world. `/az` -> Explorer Mode. Every interactive option on this page carries a
tooltip explaining exactly what it watches.

## When it starts

Delays, 0-15 seconds each, before fading begins:

- After logging into the game
- After reloading the user interface
- After other loading screens
- After combat ends

## When it exits

Any enabled condition here forces the UI back to full visibility:

- While engaged in combat
- While having low health, with a configurable threshold
- While having low mana, with a configurable threshold, plus a separate threshold for
  Druid forms
- While in a group
- While in an instance
- While having a friendly target
- While having a hostile target
- While having a dead target
- While having a focus target
- While having any sort of replacement action bar (vehicles, override bars)

## What it fades

Pick exactly which elements are affected:

- Action Bars
- Pet Bar
- Stance Bar
- Player unit frame
- Player Class Power frame
- Pet unit frame
- Focus unit frame
- Objectives Tracker
- Chat Windows

## Suggested setup

1. Turn on **Enable Explorer Mode**.
2. Start with generous delays so nothing disappears while you are still reading it.
3. Leave **While in a group** and **While in an instance** enabled until you know how
   it behaves in content.
4. Test in open world, then a dungeon, then a raid.
5. Tighten the delays once the exit conditions feel right.

## If your UI keeps vanishing

Explorer Mode is the first thing to check when action bars or the player frame
disappear. Either turn off the relevant entry under **Elements to Fade**, or enable
more exit conditions. Per-bar fading under Action Bars is a separate mechanism and can
hide a bar on its own.

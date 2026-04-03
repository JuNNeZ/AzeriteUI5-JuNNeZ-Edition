# Troubleshooting

## Basic recovery loop
1. /reload
2. Reproduce once
3. Check BugSack/BugGrabber
4. Test with only AzeriteUI enabled

## Addon not loading
- Verify folder name: AzeriteUI5_JuNNeZ_Edition
- Verify addon enabled at character screen
- Verify Retail client

## Frames misplaced or hidden
- Toggle /lock and inspect anchors
- Check profile selection in /az
- Reset current profile if needed

## Nameplate or castbar odd behavior
- Confirm nameplate options in /az
- Test with other nameplate addons disabled
- Capture /azdebug nameplates output for one unit

## WoW 12 secret-value issues
If you see secret-value related errors:
- Update to latest addon release
- /reload
- Re-test with only AzeriteUI
- Capture stack trace and report issue

## Reporting a bug
Include:
- Exact steps
- Zone/content type (open world, dungeon, raid, pvp)
- Commands used
- Screenshots/video
- Error text

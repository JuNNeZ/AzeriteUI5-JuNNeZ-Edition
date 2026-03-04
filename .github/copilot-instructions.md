# Copilot Instructions — WoW AddOn (Midnight)

Follow these rules for ALL suggestions in this repository:

1) Always ground answers in the codebase:
   - Reference file paths explicitly.
   - If you haven’t seen a file, do NOT assume its contents.

2) Prefer small, reviewable diffs:
   - Minimal change that fixes the issue.
   - Avoid refactors unless requested.

3) WoW Lua correctness:
   - Avoid creating globals.
   - Respect load order from the .toc.
   - SavedVariables must be defensive and versionable.
   - Debug logging must be toggleable.

4) Output format:
   - Provide steps to reproduce + test (including `/reload` loop).
   - End with “Files touched:” list.

If context is missing, add TODOs and state which file(s) you need to inspect.

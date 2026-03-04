# WoW AddOn Task (Midnight) — Prompt

Use this prompt when asking for changes in this repo.

## Required context
Attach these files EVERY time:
- #file:../../AGENTS.md
- #file:<the specific file(s) you will edit>

## Instructions
You are working on a World of Warcraft AddOn targeting Midnight.

Rules:
1) Do not invent APIs or project structure. Search and read files first.
2) Reference file paths explicitly in your explanation.
3) Produce a patch-style answer:
   - What to change
   - The updated code sections
   - Any new files with full contents

Checklist before final output:
- [ ] Uses existing repo patterns
- [ ] No accidental globals introduced
- [ ] Reload-safe (`/reload`) and defensive defaults
- [ ] SavedVariables handled safely (if touched)
- [ ] Notes any risky protected/taint areas
- [ ] Includes test steps + expected result

Finish with:
**Files touched:**
- <path> — <reason>

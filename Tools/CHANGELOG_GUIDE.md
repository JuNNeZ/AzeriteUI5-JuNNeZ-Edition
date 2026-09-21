# Writing AzeriteUI release notes

`CHANGELOG.md` is the source for public release notes and the generated in-game
changelog. Explain both what players receive and the substantial work behind it.
Lead with useful changes; give development work enough space to be understood.

## Prepare from evidence

1. Compare against the previous released tag. Read the relevant commits, files,
   FixLog entries and test results; a commit title alone is not evidence.
2. Make a short inventory of shipped features, fixes, compatibility work, interface
   and artwork development, and meaningful validation. Include work completed over
   several iterations, not just the final patch. Exclude reverted or unshipped work.
3. For each substantial item, record the result, the work that produced it, its
   access path or affected client, and any remaining limitation. Use that inventory
   to check that a large piece of development has not disappeared from the notes.
4. Group related changes by feature. Describe each result once; the Development
   section should add context rather than repeat the Highlights.

## Structure

### Highlights

Usually 3-6 bullets for a feature release; a small fix may need only one. Say what
changed, why it helps, and where to use it. Prefer a concrete before/after description
for bugs. Include exact commands or settings paths where applicable.

### Development

Usually 2-4 bullets when substantial work warrants it. Explain what was built,
redesigned, investigated or tested, and connect that work to the shipped feature.
Use ordinary language and explain technical terms only where needed.

Good: "Built the panel's own controls and layout system around the existing settings
tables, so the new window and classic dialog continue to edit the same profiles."

Avoid: "Massive UI overhaul", "lots of fixes", a list of internal function names,
or repeating "new options panel" without explaining what was developed.

Research, compatibility fallbacks, artwork and regression testing belong here when
they represent meaningful work in this release. Say what tests cover and what they
cannot establish. Do not use line counts, commit counts, elapsed effort or raw test
totals as substitutes for explaining the work. Do not infer hours or claim complete
compatibility from offline checks.

### Access and known limits

Use when preview commands, client differences, deferred features or testing gaps
need explanation. Clearly distinguish shipped, preview, deferred and unverified
behavior. Avoid duplicating access paths already stated clearly in Highlights.

### Internal (optional)

Reserve for maintainer-only changes that need recording but add little to the
player's understanding: build commands, debug switches or publication plumbing.
Omit routine version bumps, tags and generic cleanup. Meaningful development work
does not automatically belong here merely because its implementation is technical.

## Editing and delivery

- Keep every version delta-only: do not reintroduce an older feature as new.
- Scale the structure to the release; do not invent content to fill headings.
- Use `## VERSION (YYYY-MM-DD) - Title`, `###` section headings and ordinary bullets.
  The in-game generator supports these sections without special handling. Avoid
  tables and nested lists inside entries, which do not retain their structure there.
- Regenerate `Options/Changelog.lua` with `lua Tools/BuildChangelog.lua`.
- Inspect the generated top entry for wording, section order and version. Run its
  Lua syntax check and the existing panel harness when changing generated content.
- Editorial revisions to a published entry keep the release version and date.
  They must describe only what that release actually shipped. Do not move an existing
  tag or replace published archives for a wording change. Updating hosted release
  descriptions is a separate publication action; state whether it was performed.

## Final review

- Can a player scan the first section and understand what they gain?
- Does the entry reflect the major development areas that actually shipped?
- Does each development bullet explain concrete work and its purpose?
- Are shipped behavior, remaining limits and validation claims distinguishable?
- Are older features, duplicate bullets and unsupported claims absent?
- Do the Markdown and generated in-game notes agree?

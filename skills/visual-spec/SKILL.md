---
name: visual-spec
description: >-
  Drive the visual-spec workflow: browse files/folders in the visual-spec viewer,
  leave comments on what you're looking at, then apply them. Use when the user says
  "use visual-spec", "open the visual editor", "change this element" (pointing at
  it), "apply my comments", or asks how to change something by pointing at it in the
  viewer. This is the entry point — it routes to current-target and apply-comments.
when_to_use: Any visual-spec task — onboarding, a conversational "change this", or applying browser comments.
routes_to:
  - current-target    # "this element" → current.json (conversational, marker-less)
  - apply-comments    # sidecar visual-spec-comments.json → apply / hand off
---

# visual-spec — the driver

Your job is to get the user from intent to applied change using the visual-spec
viewer, and to do the agent-side work (applying) once they've left comments.

```
 browse + comment              persisted in source            you apply
 ┌───────────────┐            ┌────────────────────────┐      ┌────────────────┐
 │ open viewer,   │  ──────▶  │ visual-spec-comments.json │ ──▶ │ apply-comments │
 │ click element  │           │ (sidecar, per target)     │     │ current-target │
 │ / file / folder│           │ or live current.json      │     │ (this session) │
 └───────────────┘            └────────────────────────┘      └────────────────┘
```

## Step 0 — Figure out where the user is

Check state before acting:

0. Is visual-spec installed? Check with `visual-spec --version` (or
   `which visual-spec`). If the command is missing, install it globally:
   `npm install -g @metuur/visual-spec`. Then proceed.
1. Is the viewer running? (started with the global `visual-spec <dir>` command,
   typically on :5180.)
2. Are there comments waiting? Read `visual-spec-comments.json` (base dir / project
   root) and look for `status: "open"`.
3. Is there a live selection? Read `node_modules/.visual-spec/current.json` and
   check `updatedAt` is fresh (~5 min).

Then pick the branch below.

## Branch A — "change THIS" (a live selection exists)

Conversational path. Invoke **current-target**: read `current.json`, confirm the
node via `tagName`/`text`, and make the edit in place. No comment needed for a
one-off.

## Branch B — "apply my comments" (sidecar comments exist)

Invoke **apply-comments**: read `visual-spec-comments.json`, resolve each target
(file / line range / folder) against the real file, then **apply in place** or
**hand off** to the comment's `workflow` skill, and mark it applied. This is the
shared contract — comments can route to visual-spec or to any other workflow.

Always finish by reporting what changed, with the source `file:line` for each, and
confirming the project still typechecks/builds if a check is available.

## Guardrails

- The artifacts are the source of truth — edit them directly and keep them
  parseable. Process file edits bottom-up by line so earlier anchors stay valid.
- Text anchors (`snippet`/`heading`) beat line numbers; if they disagree, trust
  the text. If you can't locate a target confidently, **skip and report** — never
  guess.
- `current.json` is read-only to you; only the browser writes it. A stale selection
  (older than ~5 min) means ask the user to click again.

## Quick reference

| User says | Do |
| --- | --- |
| "open the editor" / "let's review this UI" | Step 0 — check viewer + state |
| "change this heading" (looking at it) | Branch A — current-target |
| "apply my comments" | Branch B — apply-comments |
| "what's commented?" | read `visual-spec-comments.json`; summarize open comments |

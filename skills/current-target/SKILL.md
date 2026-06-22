---
name: current-target
description: >-
  Resolve "this element" / "the thing I'm looking at" to a precise source
  location using node_modules/.visual-spec/current.json. Use for conversational,
  marker-less edits when the user references the current selection ("make this
  bigger", "change this heading").
when_to_use: The user references the current browser selection without a marker.
---

# current-target

The deictic bridge. When the user says "this" without leaving a marker, resolve
it from the live cursor file the browser keeps updated.

## Procedure

1. Read `node_modules/.visual-spec/current.json`:
   ```jsonc
   {
     "surfaceId": "anatomy",
     "pageIndex": 0,
     "selection": { "line": 15, "column": 8, "tagName": "h1", "text": "Q2 Roadmap" },
     "updatedAt": "2026-06-20T20:42:52.051Z"
   }
   ```
2. **Check freshness.** If `updatedAt` is older than ~5 minutes, the selection is
   stale — ask the user to click the element again rather than guessing.
3. Open `surfaces/<surfaceId>/index.tsx`, go to `selection.line:selection.column`,
   and **confirm** you're on the right node via `selection.tagName` and
   `selection.text`. If they don't match (source drifted), search the page for the
   `text` snippet instead of trusting the line blindly.
4. Make the requested edit there. Surfaces are zero-prop page components; keep the
   file parseable and edit bottom-up so earlier line anchors stay valid.

This skill is read-only on `current.json` — it never writes it (the browser does).
For batched edits across many files, leave comments in the viewer and apply them
with `apply-comments`.

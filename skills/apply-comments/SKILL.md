---
name: apply-comments
description: >-
  Apply the comments a user left while browsing files/folders in the visual-spec
  viewer. Reads the sidecar visual-spec-comments.json (each comment pins a target —
  a file, a line range, or a folder — plus the instruction and a `workflow` tag),
  resolves each target in the real file, and either applies it in place or hands it
  off to the named workflow skill. Use when the user says "apply comments", "apply
  the comments", "aplica los comentarios", or runs /apply-comments. This is shared
  infrastructure: any primary skill (research, architecture review, docs analysis,
  visual-spec) composes with it via "<Primary> → Apply Comments".
when_to_use: visual-spec-comments.json has open comments on any file/folder.
---

# apply-comments (generic, workflow-aware)

A user browses a directory in the visual-spec viewer, clicks a **file**, a **line
range**, or a **folder**, and leaves a comment. Comments are NOT written into the
artifacts — they live in one sidecar, `visual-spec-comments.json`. Each comment
carries a **`workflow`** tag that routes it to the skill that knows what the
comment *means*. Your job: read the sidecar, **resolve** each open comment to its
real location, then **apply in place** (default) or **hand off** to the named
workflow, and mark it applied.

See [the comment contract](reference/comment-contract.md) for the exact payload
schema, the resolution rules, and how a primary skill opts in.

## The sidecar format

```jsonc
{
  "version": 1,
  "comments": [
    {
      "id": "c-1a2b3c4d",
      "workflow": "visual-spec",          // routing tag — who applies this comment
      "target": {
        "path": "src/auth/login.ts",      // real path under the base dir (file OR folder)
        "kind": "range",                  // "file" | "range" | "folder"
        "startLine": 42, "endLine": 47,   // range only (single block → startLine, no endLine)
        "snippet": "function login(",     // text at start — your drift-resilient anchor
        "endSnippet": "}",                // text at end (range)
        "heading": "Login"                // markdown hint: nearest heading above the block
      },
      "selectedContent": "function login() { … }",  // verbatim text the user highlighted, if any
      "comment": "validate the input here",
      "dialect": "ears", "spec": "WHEN …, THE … SHALL …",  // optional, if authored as a spec
      "status": "open",                    // open | applied
      "ts": "2026-06-21T…"
    }
  ]
}
```

## Procedure

1. **Read** `visual-spec-comments.json` (base dir / project root). Take only
   `status: "open"`. **Group by `workflow`.**
2. **Resolve every target** (you own this step regardless of workflow):
   - `kind: "file"` → the whole file at `target.path`.
   - `kind: "range"` → lines `startLine`..`endLine` in `target.path`. Locate by
     **`snippet`** (and `endSnippet` for the end of a range); `startLine` may have
     drifted, so use it only as a tiebreaker. For markdown, `heading` is a strong
     secondary anchor. If you can't locate it confidently, **skip and report** —
     never guess.
   - `kind: "folder"` → the directory at `target.path` (no line anchoring).
   - Re-read the current file contents so the payload reflects reality, not the
     possibly-stale `snippet`/`selectedContent`.
3. **Dispatch by workflow:**
   - **`visual-spec`** (or unset) → **apply in place**: make the edit the comment
     asks for, directly in `target.path`. Process file edits **bottom-up by line**
     so earlier anchors stay valid. Keep the file well-formed. A folder comment with
     no obvious in-place edit (e.g. "needs an owner") becomes a note in the report.
   - **any other workflow** (e.g. `uncle-dev-research`, `architecture-review`,
     `documentation-analysis`) → **hand off**: invoke that skill and pass it the
     resolved payload for its group (the comments + resolved file/lines/content).
     The primary skill interprets and acts in its domain; you still own resolution,
     status, and the audit trail. If that skill isn't available, say so and fall
     back to applying in place where it makes sense; otherwise skip and report.
4. **Mark applied.** Set each handled comment's `status` to `"applied"` in the
   sidecar (don't delete — keep the audit trail). The viewer only lists `open`
   comments, so applied ones drop off the sidebar on the next focus.
5. **Verify & report.** One table: `id · workflow · target (path + kind/lines) ·
   what changed / where handed off · ✅ applied / ⏭️ skipped`. State N applied,
   M handed off, K skipped, and never silently drop a comment. For code edits,
   confirm the project still typechecks/builds if a check is available.

## Optionally synthesize a change

If a group of `visual-spec` comments amounts to a coherent feature, you may also
hand them off to an SDD workflow (set the comment's `workflow` tag accordingly).
The default for a plain comment is an in-place edit.

## Rules

- The artifacts are the source of truth; edit them directly and keep them parseable.
- `snippet`/`endSnippet` (+ `heading` for markdown) beat line numbers. If they
  disagree, trust the text anchors.
- Bottom-up by line within a file. Skip-and-report on ambiguity. Keep the audit
  trail (mark applied, don't delete).
- Respect the `workflow` tag — never apply another workflow's comments in place;
  hand them off.

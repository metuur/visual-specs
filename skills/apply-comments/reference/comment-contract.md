# The Comment Contract

`apply-comments` is **shared infrastructure**. Any skill can let users leave
review comments in the visual-spec browser and then receive those comments to act
on — without re-implementing reading, target resolution, status tracking, or the
audit trail. This document is the stable contract between the two sides.

```
 ┌───────────────────────┐        ┌──────────────────────────┐        ┌───────────────────────┐
 │ user browses a dir,    │        │ apply-comments            │        │ a primary "workflow"   │
 │ comments on files /    │  ───▶  │  • reads the sidecar      │  ───▶  │  skill interprets +    │
 │ line ranges / folders  │        │  • groups by `workflow`   │        │  acts in its domain    │
 │ (visual-spec viewer)   │        │  • RESOLVES each target   │        │  (research, arch       │
 └───────────────────────┘        │  • applies OR hands off   │        │  review, docs, specs…) │
                                   │  • marks applied (audit)  │        └───────────────────────┘
                                   └──────────────────────────┘
```

apply-comments owns the **mechanics** (locate, resolve, track). The primary skill
owns the **interpretation** (what the comment means, what to do about it).

## The payload

Every comment is one record in `visual-spec-comments.json`. This same record is
what a primary skill receives, with its `target` resolved against the current file.

| Field | Meaning |
| --- | --- |
| `id` | `c-<8hex>`, stable identity for the audit trail. |
| `workflow` | Routing tag. Decides which skill applies the comment. Defaults to `visual-spec`. |
| `target.path` | Real path under the base dir — a **file** or a **folder**. |
| `target.kind` | `file` \| `range` \| `folder`. |
| `target.startLine` / `endLine` | 1-indexed line span (range). A single block has `startLine` and no `endLine`. |
| `target.snippet` / `endSnippet` | Text at the start/end line — the **drift-resilient anchor** (trust over line numbers). |
| `target.heading` | Markdown hint: nearest heading above the block. |
| `selectedContent` | Verbatim text the user highlighted, if any. |
| `comment` | The user's instruction — the thing to act on. |
| `dialect` / `spec` | Present only if the comment was authored as a formal SDD spec. |
| `status` | `open` \| `applied`. You only ever act on `open`. |
| `ts` | ISO timestamp. |

## Target resolution rules

apply-comments resolves the target before applying or handing off:

- **file** — operate on the whole file at `target.path`.
- **range** — find `snippet` in the file (and `endSnippet` for the end of a multi-
  line range). `startLine`/`endLine` are hints that may have drifted. For markdown,
  `heading` narrows the search. Re-read current contents; don't trust a stale
  `selectedContent`.
- **folder** — operate on the directory at `target.path`; no line anchoring.

If a target can't be located confidently: **skip and report**. Never guess.

## How a primary skill opts in ("<Primary> → Apply Comments")

1. **Pick a workflow name** — a stable slug, e.g. `uncle-dev-research`,
   `architecture-review`, `documentation-analysis`. Comments meant for your skill
   carry `workflow: "<your-slug>"`. (Users/automation set this when commenting; the
   default `visual-spec` means "just apply it in place".)
2. **Add a "Receiving comments" section to your skill** that says: *given a group
   of resolved comment records on these files/folders, here is how I interpret and
   act on them.* You receive the payload above — files, line ranges, selected
   content, and the instruction — already located in the source.
3. **Let apply-comments drive the mechanics.** It reads the sidecar, resolves
   targets, invokes you with your group, then marks each `applied`. You focus only
   on the domain action. You do **not** parse the sidecar or track status yourself.

### Composition examples

- `Uncle Dev Research → Apply Comments` — comments tagged `uncle-dev-research` are
  handed to the research skill, which folds them into its research notes / findings.
- `Architecture Review → Apply Comments` — comments on folders/files tagged
  `architecture-review` become architecture findings for that module.
- `Documentation Analysis → Apply Comments` — comments on docs tagged
  `documentation-analysis` drive doc edits or gap analysis.
- `Visual Spec → Apply Comments` — the default: edit the artifact in place.

## Lifecycle & guarantees

- **Open → applied**, never deleted (audit trail). The viewer lists only `open`.
- **Bottom-up by line** within a file so earlier anchors stay valid.
- **Text anchors beat line numbers.** `snippet`/`endSnippet`/`heading` win.
- **One workflow never applies another's comments in place** — it hands them off.
- **Nothing is silently dropped** — every open comment ends up applied, handed off,
  or explicitly skipped-and-reported.

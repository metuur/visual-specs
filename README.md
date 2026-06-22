# visual-spec

Browse any directory in the browser and comment on **files, line ranges, and
folders** — then let an AI agent apply those comments. Works for specs, source
code, docs, and assets, in a tight review loop.

```
visual-spec ./my-project    →  open a web UI over the whole directory tree
   ↓ click a file/line/folder, add comments (saved to visual-spec-comments.json)
   ↓ optionally tag each comment with a workflow (visual-spec, architecture-review, …)
"apply the comments"        →  the apply-comments skill applies them in place, or
                               hands each off to the workflow skill you tagged it with
   ↺ repeat
```

Each comment carries a **`workflow`** tag so `apply-comments` becomes shared
infrastructure: any primary skill (research, architecture review, docs analysis,
visual-spec) composes with it via **"&lt;Primary&gt; → Apply Comments"**. See
`skills/apply-comments/reference/comment-contract.md`.

---

## Quick start

The tool is a single, self-contained command installed globally. The directory
of specs is the **first argument** — no flags needed.

```bash
# install the published command once
npm install -g @metuur/visual-spec

# then run it from anywhere against any folder
visual-spec ~/project/specs     # from any directory
visual-spec ./specs             # relative to where you run it
visual-spec .                   # the current directory
```

Then open the printed URL (default <http://localhost:5180>).

> Contributors working from the repo can install the local build instead:
> `cd packages/visual-spec && npm install -g .`

---

## Passing a directory

The spec directory is a positional argument:

```bash
visual-spec <dir> [--port 5180] [--no-open]
```

| Form                       | Resolves to                                     |
| -------------------------- | ----------------------------------------------- |
| absolute `/Users/me/specs` | used as-is                                      |
| relative `./docs`, `../x`  | resolved from the **current working directory** |
| omitted                    | the current directory (`.`)                     |

- The server scans **the whole tree** under that directory (files + folders).
- **Filtering:** only a `.visualspecignore` at the directory root is honored
  (gitignore syntax). `.git/`, `node_modules/`, and the comments sidecar are always
  hidden. `.gitignore` is **not** read.
- Files are classified for display: markdown (rendered), code/text (line-anchored),
  images (preview), everything else (listed, comment-only).
- Comments are saved to `<dir>/visual-spec-comments.json` — right next to your
  files, so the agent finds them.
- If the directory doesn't exist, it exits with `Directory not found`.

> ℹ️ Always run the global `visual-spec` command — it resolves relative paths from
> your shell's cwd, as expected. (Contributors can also run the un-built source via
> `pnpm --filter visual-spec start <dir>`, but that runs **inside
> `packages/visual-spec/`**, so relative paths resolve from there — use absolute
> paths if you go that route.)

### Flags

| Flag         | Default | Meaning                     |
| ------------ | ------- | --------------------------- |
| `--port <n>` | `5180`  | port to serve on            |
| `--no-open`  | off     | don't auto-open the browser |

---

## Commands

```bash
visual-spec <dir>                      # open the comment UI on a spec directory (default)
visual-spec init <dir> [--name <pkg>]  # scaffold a new TSX-surface project
visual-spec install-skills [--dest d]  # copy the agent skills (default ~/.claude/skills)
visual-spec help
```

---

## The full workflow

```bash
# 1. open your specs in the browser
visual-spec ./my-specs

# 2. in the UI: pick a file or folder in the tree.
#    - markdown: click "Start comments" (or press I), click a block.
#    - code/text: click a line (Shift+click for a range).
#    - folder/image/binary: comment on the whole thing.
#    Optionally set "Apply via" to route the comment to a workflow.
#    → saved to ./my-project/visual-spec-comments.json

# 3. one-time: make the skills available to your agent
visual-spec install-skills

# 4. in your agent (e.g. Claude Code): "apply the comments"
#    → apply-comments reads visual-spec-comments.json, groups by workflow,
#      applies "visual-spec" comments in place and hands the rest off, then
#      marks each applied (audit trail).
```

In the UI you also get: a **Copy prompt** button (copies a ready-to-paste prompt
for your agent), a comment cart with a "view all comments" dropdown, files and
folders with comments highlighted in the tree, mermaid diagram rendering, and a
resizable, collapsible layout.

---

## Using the skill (in your agent)

The agent side is driven by the **`visual-spec`** skill, which routes to two
sub-skills: `current-target` ("change this element") and `apply-comments`
("apply my comments"). Make them available once:

```bash
visual-spec install-skills          # copies skills to ~/.claude/skills
```

The skill self-checks its install: if the `visual-spec` command is missing, it
runs `npm install -g @metuur/visual-spec` before doing anything else, so the
viewer is always available.

### Sample session

```text
You:   use visual-spec on ./my-specs
Agent: (Step 0) checks `visual-spec --version` → installs it if missing,
       starts `visual-spec ./my-specs`, opens http://localhost:5180

You:   (in the browser) click overview.md, leave a couple of comments,
       optionally set "Apply via" → architecture-review, then come back

You:   apply my comments
Agent: (Branch B → apply-comments) reads ./my-specs/visual-spec-comments.json,
       groups by workflow, applies the "visual-spec" comments in place,
       hands the "architecture-review" ones to that skill, marks each applied,
       and reports each change with its source file:line
```

Or, fully conversational with a live selection:

```text
You:   (click a heading in the viewer) change THIS heading to "Goals"
Agent: (Branch A → current-target) reads node_modules/.visual-spec/current.json,
       confirms the node by tagName/text, edits it in place — no comment needed
```

| You say                                      | The skill does                                                |
| -------------------------------------------- | ------------------------------------------------------------- |
| "use visual-spec" / "open the visual editor" | Step 0 — ensure installed, start the viewer, check state      |
| "change this element" (pointing at it)       | Branch A — `current-target` (live `current.json`)             |
| "apply my comments"                          | Branch B — `apply-comments` (sidecar JSON → apply / hand off) |
| "what's commented?"                          | reads `visual-spec-comments.json`, summarizes open comments   |

---

## Architecture

Two pieces, split by responsibility:

| Piece                     | What it is                                              | How you get it                       |
| ------------------------- | ------------------------------------------------------- | ------------------------------------ |
| **`@metuur/visual-spec`** | the runtime — CLI + Node server + prebuilt React viewer | `npm install -g @metuur/visual-spec` |
| **this repo**             | the agent side — the skills and their installer         | clone + `scripts/install-skills.sh`  |

This repo is intentionally small — it ships only what the **agent** needs. The
viewer itself lives in the published package.

```
visual-spec/
├─ skills/                       the agent instructions (one dir per skill)
│  ├─ visual-spec/SKILL.md       entry point — routes to the two below
│  ├─ current-target/SKILL.md    "change THIS" → live current.json (conversational)
│  └─ apply-comments/            sidecar comments → apply / hand off
│     ├─ SKILL.md
│     └─ reference/              the shared comment contract
└─ scripts/
   └─ install-skills.sh          install the skills into your local agents
```

### Installing the skills

`scripts/install-skills.sh` discovers every `skills/*/SKILL.md` and wires them
into whichever agents it detects:

```bash
scripts/install-skills.sh                 # every agent detected on this machine
scripts/install-skills.sh claude          # Claude Code only
scripts/install-skills.sh codex           # Codex only
scripts/install-skills.sh --uninstall     # remove again
```

- **Claude Code** → packaged as a self-contained plugin served from a local
  marketplace, registered via `claude plugin marketplace add` + `install`.
- **Codex** → each `SKILL.md` is copied to `~/.codex/prompts/<skill>.md` as a
  slash-command prompt.

> The published package also bundles these skills, so `visual-spec install-skills`
> (from `@metuur/visual-spec`) is the zero-clone equivalent.

### Runtime (the `@metuur/visual-spec` package)

When you run `visual-spec <dir>`, a plain Node HTTP server serves the prebuilt
static UI and exposes the directory/comment API rooted at your directory:

```
GET  /__vs/tree                   → the whole visible tree (dirs + files, with kind)
GET  /__vs/tree/file?path=<p>     → one file's content (text) or metadata (image/binary)
GET  /__vs/raw?path=<p>           → raw bytes (image previews / downloads)
GET  /__vs/comments[?path=<p>]    → comments (all / by target path)
POST /__vs/comments/add           → append a comment (generic target + workflow)
PATCH/DELETE /__vs/comments/:id   → set status / remove
GET  /__vs/source[...]            → legacy markdown-surface API (still served)
```

Your files are never modified by the viewer — comments live only in the sidecar
JSON until the agent applies them.

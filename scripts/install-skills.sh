#!/usr/bin/env bash
#
# install-skills.sh — install the visual-spec skills into your local AI agents.
#
#   Claude Code  →  a self-contained plugin served from a local marketplace,
#                   registered via `claude plugin marketplace add` + `install`.
#   Codex        →  each SKILL.md as a slash-command prompt in ~/.codex/prompts.
#
# Usage:
#   scripts/install-skills.sh                 # install for every agent detected
#   scripts/install-skills.sh claude          # Claude Code only
#   scripts/install-skills.sh codex           # Codex only
#   scripts/install-skills.sh claude codex    # both, explicitly
#   scripts/install-skills.sh --uninstall [claude|codex]
#
# Env overrides:
#   PLUGIN_VERSION   version stamped into the plugin (default 0.1.0)
#   STAGE_DIR        where the generated plugin lives (default
#                    ${XDG_DATA_HOME:-~/.local/share}/visual-spec/claude-plugin)
#   CODEX_HOME       Codex config dir (default ~/.codex)

set -euo pipefail

# ---- locations -------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

PLUGIN_NAME="visual-spec"
PLUGIN_VERSION="${PLUGIN_VERSION:-0.1.0}"
PLUGIN_DESC="Browse files/folders in the visual-spec viewer, comment on them, and apply those comments — entry point routes to current-target and apply-comments."
STAGE_DIR="${STAGE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/visual-spec/claude-plugin}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

# ---- pretty output ---------------------------------------------------------
info() { printf '\033[36m›\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "$SKILLS_SRC" ] || die "skills/ not found at $SKILLS_SRC"

# Discover skill directories (each has a SKILL.md).
SKILLS=()
for d in "$SKILLS_SRC"/*/; do
  [ -f "$d/SKILL.md" ] && SKILLS+=("$(basename "$d")")
done
[ "${#SKILLS[@]}" -gt 0 ] || die "no skills (dirs with SKILL.md) under $SKILLS_SRC"

# ---- Claude Code -----------------------------------------------------------
build_plugin_tree() {
  local plugin_dir="$STAGE_DIR/plugins/$PLUGIN_NAME"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR/.claude-plugin" "$plugin_dir/.claude-plugin" "$plugin_dir/skills"

  # Copy every skill into the plugin's skills/ dir (Claude auto-loads them).
  for s in "${SKILLS[@]}"; do
    cp -R "$SKILLS_SRC/$s" "$plugin_dir/skills/$s"
  done

  cat > "$plugin_dir/.claude-plugin/plugin.json" <<EOF
{
  "name": "$PLUGIN_NAME",
  "description": "$PLUGIN_DESC",
  "version": "$PLUGIN_VERSION",
  "keywords": ["visual-spec", "comments", "spec", "review", "skills"]
}
EOF

  cat > "$STAGE_DIR/.claude-plugin/marketplace.json" <<EOF
{
  "name": "$PLUGIN_NAME",
  "owner": { "name": "visual-spec" },
  "metadata": {
    "description": "visual-spec agent skills (visual-spec, apply-comments, current-target).",
    "version": "$PLUGIN_VERSION"
  },
  "plugins": [
    {
      "name": "$PLUGIN_NAME",
      "description": "$PLUGIN_DESC",
      "version": "$PLUGIN_VERSION",
      "source": "./plugins/$PLUGIN_NAME"
    }
  ]
}
EOF
}

install_claude() {
  command -v claude >/dev/null 2>&1 || { warn "claude CLI not found — skipping Claude install"; return 1; }
  info "Building plugin tree at $STAGE_DIR"
  build_plugin_tree
  ok "Staged plugin '$PLUGIN_NAME' with skills: ${SKILLS[*]}"

  info "Registering marketplace with Claude Code"
  # Re-add is idempotent enough; remove first so an existing entry is refreshed.
  claude plugin marketplace remove "$PLUGIN_NAME" >/dev/null 2>&1 || true
  if claude plugin marketplace add "$STAGE_DIR" --scope user; then
    if claude plugin install "$PLUGIN_NAME@$PLUGIN_NAME" >/dev/null 2>&1 \
       || claude plugin install "$PLUGIN_NAME" >/dev/null 2>&1; then
      ok "Installed Claude plugin '$PLUGIN_NAME' (restart Claude Code or /plugins to verify)"
    else
      warn "Marketplace added but auto-install failed. Finish with:"
      printf '    claude plugin install %s@%s\n' "$PLUGIN_NAME" "$PLUGIN_NAME"
    fi
  else
    warn "Could not add marketplace automatically. Run manually:"
    printf '    claude plugin marketplace add %q\n' "$STAGE_DIR"
    printf '    claude plugin install %s@%s\n' "$PLUGIN_NAME" "$PLUGIN_NAME"
  fi
}

uninstall_claude() {
  command -v claude >/dev/null 2>&1 || { warn "claude CLI not found — skipping"; return 0; }
  claude plugin uninstall "$PLUGIN_NAME" >/dev/null 2>&1 || true
  claude plugin marketplace remove "$PLUGIN_NAME" >/dev/null 2>&1 || true
  rm -rf "$STAGE_DIR"
  ok "Removed Claude plugin + marketplace '$PLUGIN_NAME'"
}

# ---- Codex -----------------------------------------------------------------
install_codex() {
  local prompts="$CODEX_HOME/prompts"
  mkdir -p "$prompts"
  info "Installing Codex prompts → $prompts"
  for s in "${SKILLS[@]}"; do
    cp "$SKILLS_SRC/$s/SKILL.md" "$prompts/$s.md"
    ok "/$s"
  done
  ok "Codex prompts installed (use /$( IFS=,; echo "${SKILLS[*]}" | sed 's/,/, \//g') in Codex)"
}

uninstall_codex() {
  local prompts="$CODEX_HOME/prompts"
  for s in "${SKILLS[@]}"; do
    rm -f "$prompts/$s.md"
  done
  ok "Removed Codex prompts: ${SKILLS[*]}"
}

# ---- arg parsing -----------------------------------------------------------
UNINSTALL=0
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --uninstall|-u) UNINSTALL=1 ;;
    claude|codex)   TARGETS+=("$arg") ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: $arg (expected claude, codex, --uninstall)" ;;
  esac
done

# No explicit target → every agent that's present on this machine.
if [ "${#TARGETS[@]}" -eq 0 ]; then
  command -v claude >/dev/null 2>&1 && TARGETS+=("claude")
  [ -d "$CODEX_HOME" ] && TARGETS+=("codex")
  [ "${#TARGETS[@]}" -gt 0 ] || die "neither claude nor codex detected; pass a target explicitly"
fi

for t in "${TARGETS[@]}"; do
  case "$t" in
    claude) [ "$UNINSTALL" -eq 1 ] && uninstall_claude || install_claude || true ;;
    codex)  [ "$UNINSTALL" -eq 1 ] && uninstall_codex  || install_codex ;;
  esac
done

#!/usr/bin/env bash
# scripts/setup-dev-env.sh — per-session dev-environment setup, invoked by
# the SessionStart hook in .claude/settings.json.
#
# Source of truth: arthur-debert/release templates/setup-dev-env.sh.
# Re-sync via the gh-repo-setup skill (or by copying this file verbatim).
# Repos that need project-specific extras (Xvfb daemon, pinned-binary
# fetch, extra rustup targets, etc.) append them below the marker at the
# bottom — anything above it is rsync'd from the template.
#
# Cloud-only: local sessions exit early (devs already have their env).
# Detects stack by filesystem signals — handles rust, node, ruby, python,
# and consumers with no project deps (just lefthook / hand-rolled hook
# wiring).
#
# Idempotent — safe to re-run. Errors are best-effort: a failure in one
# step does not abort the rest (transient registry hiccups shouldn't
# block the lefthook install).

set -euo pipefail

# Cloud-only gate. Local sessions already have their env set up.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# --- 1. Universal git hygiene --------------------------------------------
# Cloud clones are shallow; restore submodule content and release tags.
# Submodule update is a no-op when in sync; tag fetch is one round-trip.

if [ -f .gitmodules ]; then
  git submodule update --init --recursive --quiet || true
fi
git fetch --tags --quiet origin || true

# --- 2. Project dep cache ------------------------------------------------
# Pick the right tool based on lockfile / manifest. Per stack, idempotent.

# Rust: cargo fetch with --locked so we don't silently mutate Cargo.lock.
if [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  cargo fetch --locked --quiet || true
fi

# Node (npm/yarn/pnpm). We deliberately do NOT guard on `! -d node_modules`:
# the env-snapshot caches a node_modules paired with a previous branch's
# lockfile, and a feature branch that bumps the lockfile (Playwright is
# the canonical case) drifts silently. Re-installing when already in sync
# is ~2s; chasing a stale lockfile bug is hours. Pay the two seconds.
if [ -f package.json ]; then
  if [ -f package-lock.json ] && command -v npm >/dev/null 2>&1; then
    npm ci 2>/dev/null || npm install
  elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
    yarn install --frozen-lockfile 2>/dev/null || yarn install
  elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  fi
fi

# Ruby / Bundler.
if [ -f Gemfile ] && command -v bundle >/dev/null 2>&1; then
  bundle install --quiet || true
fi

# Python / pip + venv. Only initialise if .venv missing — pip install is
# slower than node/cargo and the guard wins more than it costs.
if [ -f pyproject.toml ] && [ ! -d .venv ] && command -v python3 >/dev/null 2>&1; then
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip --quiet || true
  .venv/bin/pip install -e '.[dev]' --quiet 2>/dev/null \
    || .venv/bin/pip install -e . --quiet 2>/dev/null \
    || true
fi

# --- 3. Pre-commit hook wiring -------------------------------------------
# Default: lefthook (binary installed at env-setup time). Fallback for
# repos that ship a hand-rolled scripts/pre-commit instead (zed-lex,
# tree-sitter-lex pattern): symlink it into .git/hooks/.

if [ -f lefthook.yml ] && command -v lefthook >/dev/null 2>&1; then
  if ! lefthook install >/dev/null; then
    echo "warning: lefthook install failed — pre-commit hook NOT wired" >&2
  fi
elif [ -x scripts/pre-commit ]; then
  mkdir -p .git/hooks
  ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
fi

# --- 4. Project-local extras ---------------------------------------------
# Everything above this marker is the canonical cross-repo setup-dev-env.sh
# from arthur-debert/release templates/setup-dev-env.sh. Do NOT modify it
# in-place; consumers append project-specific steps BELOW this marker.
# (See e.g. lex-fmt/lexed for an Xvfb start, lex-fmt/nvim for pinned-bin
# fetches.)

# Self-heal a partial .venv from a stale session env-snapshot.
#
# The canonical Python step above only runs `pip install -e .[dev]` when
# .venv is absent. In the cloud, the session env-snapshot can cache a
# .venv directory that contains only pip + setuptools (created by a
# previous run where the editable install errored under `2>/dev/null`,
# or was interrupted mid-snapshot). On the next session start the `[ ! -d
# .venv ]` guard sees the directory and skips reinstall, leaving mkdocs
# and pytest missing. Symptom: `pytest tests/` fails with
# `ModuleNotFoundError: mkdocs` (or `FileNotFoundError: 'mkdocs'` from
# the integration test's `subprocess.run(['mkdocs', 'build'])`), because
# the project package itself never got installed.
#
# Fix: if .venv exists but `mkdocs-lex-plugin` isn't installed inside it,
# rerun the editable install. Loud (no `2>/dev/null`) so future install
# failures surface instead of being papered over.
if [ -f pyproject.toml ] && [ -x "${REPO_ROOT}/.venv/bin/pip" ]; then
  # Separate `pip show` calls because the multi-arg form returns 0 if ANY
  # package exists — so `pip show mkdocs-lex-plugin pytest` would mask a
  # partial install where the main package landed but `[dev]` extras did
  # not. Two single-arg calls give the strict "both installed" semantics
  # the self-heal needs.
  if ! "${REPO_ROOT}/.venv/bin/pip" show mkdocs-lex-plugin >/dev/null 2>&1 \
     || ! "${REPO_ROOT}/.venv/bin/pip" show pytest >/dev/null 2>&1; then
    "${REPO_ROOT}/.venv/bin/pip" install --upgrade pip --quiet || true
    "${REPO_ROOT}/.venv/bin/pip" install -e '.[dev]' --quiet \
      || "${REPO_ROOT}/.venv/bin/pip" install -e . --quiet \
      || echo "warning: editable install failed — tests will not run" >&2
  fi
fi

# Pre-install the pinned `lexd` CLI into the venv bin dir.
#
# The integration test (tests/test_integration.py) drives `mkdocs build`
# against a fixture that has `download_if_missing: true` set on the
# plugin. That code path hits api.github.com anonymously from urllib —
# and from the cloud sandbox's shared egress IP, GitHub aggressively
# rate-limits anonymous calls, returning a flaky HTTP 403 long before the
# documented 60-req/hr quota. The mkdocs build then aborts and pytest
# fails.
#
# Fix: drop the version pinned in shared/lex-deps.json into .venv/bin/
# during setup so it's on PATH when the venv is activated; the plugin's
# `shutil.which('lexd')` check short-circuits before any network call.
# Pattern matches lex-fmt/nvim and lex-fmt/comms: version + repo in
# shared/lex-deps.json, fetched via `gh release download` which uses
# GH_TOKEN (scoped to lex-fmt/* in cloud sessions) so it isn't subject
# to the anonymous rate-limit. To bump the pin: edit shared/lex-deps.json,
# delete .venv/bin/lexd, re-run this script.
if [ -f shared/lex-deps.json ] \
   && [ -d "${REPO_ROOT}/.venv/bin" ] \
   && [ ! -x "${REPO_ROOT}/.venv/bin/lexd" ] \
   && command -v gh >/dev/null 2>&1 \
   && command -v jq >/dev/null 2>&1; then
  LEXD_VERSION="$(jq -r '.lexd' shared/lex-deps.json)"
  LEXD_REPO="$(jq -r '."lexd-repo"' shared/lex-deps.json)"
  case "$(uname -m)" in
    x86_64|amd64)  LEXD_TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) LEXD_TARGET="aarch64-unknown-linux-gnu" ;;
    *)             LEXD_TARGET="" ;;
  esac
  if [ -n "${LEXD_TARGET}" ] \
     && [ -n "${LEXD_VERSION}" ] && [ "${LEXD_VERSION}" != "null" ] \
     && [ -n "${LEXD_REPO}" ]    && [ "${LEXD_REPO}" != "null" ]; then
    LEXD_TMP="$(mktemp -d)"
    if gh release download "${LEXD_VERSION}" \
         --repo "${LEXD_REPO}" \
         --pattern "lexd-${LEXD_TARGET}.tar.gz" \
         --dir "${LEXD_TMP}" --clobber >/dev/null 2>&1 \
       && tar -xzf "${LEXD_TMP}/lexd-${LEXD_TARGET}.tar.gz" -C "${LEXD_TMP}" \
       && mv "$(find "${LEXD_TMP}" -type f -name lexd | head -n 1)" "${REPO_ROOT}/.venv/bin/lexd" \
       && chmod +x "${REPO_ROOT}/.venv/bin/lexd"; then
      :
    else
      echo "warning: could not install pinned lexd (${LEXD_REPO}@${LEXD_VERSION}) — integration tests may flake on the runtime download path" >&2
    fi
    rm -rf "${LEXD_TMP}"
  fi
fi

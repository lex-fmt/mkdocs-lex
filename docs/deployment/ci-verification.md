# CI Build Verification

A GitHub Actions workflow that runs `mkdocs build --strict` on every pull request, with no deployment. Use this when you publish docs from somewhere else (Netlify, Cloudflare Pages, an internal server) but still want CI to fail when a docs change won't build.

## What `--strict` catches

`mkdocs build --strict` promotes MkDocs warnings to errors, so the workflow fails on:

- Broken internal links
- Missing nav entries / unreferenced pages
- Invalid `.lex` syntax that `lexd` rejects
- Plugin errors

These are exactly the regressions that are easy to merge and annoying to discover at deploy time.

## The workflow

Save as `.github/workflows/docs-ci.yml` (full copy: [`examples/ci.yml`](examples/ci.yml)):

```yaml
name: Docs CI

on:
  pull_request:
    paths:
      - docs/**
      - mkdocs.yml
      - .github/workflows/docs-ci.yml
  push:
    branches: [main]
    paths:
      - docs/**
      - mkdocs.yml
      - .github/workflows/docs-ci.yml

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: docs/requirements.txt

      - uses: actions/cache@v4
        with:
          path: .mkdocs_lex_cache
          key: mkdocs-lex-${{ runner.os }}

      - run: pip install -r docs/requirements.txt
      - run: mkdocs build --strict
```

## Why this shape

- **No `permissions:` block.** This workflow doesn't push anywhere, so the default read-only token is fine.
- **Runs on `pull_request` *and* `push: main`.** PR runs catch problems pre-merge; the `main` run catches anything that bypasses PRs (direct push, rebase, etc.).
- **`pip` cache via `setup-python`** keyed off `docs/requirements.txt`, so dependency installs are cheap.
- **`actions/cache` for `.mkdocs_lex_cache/`** keeps the `lexd` binary across runs, same as the deployment workflow.
- **`mkdocs build --strict`** — the whole point. Drop `--strict` if you'd rather see warnings but not fail.

## Extending to other deployment targets

If you do want this workflow to feed a non-GitHub-Pages host, the pattern is:

1. Add an `actions/upload-artifact` step after `mkdocs build` to publish the `site/` directory.
2. Either pull the artifact from your hosting provider's CI, or add a second job that runs your provider's CLI (`netlify deploy`, `wrangler pages deploy`, `aws s3 sync`, etc.) on `push: main`.

That's a per-provider exercise, not a `mkdocs-lex` concern — every static-site host has its own deploy story and any one of them works fine on top of the `site/` directory `mkdocs build` produces.

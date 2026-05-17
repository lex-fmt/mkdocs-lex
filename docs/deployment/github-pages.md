# GitHub Pages

Publish a `mkdocs-lex` site to GitHub Pages on every push to `main`, using a GitHub Actions workflow.

## What you get

- A workflow at `.github/workflows/docs.yml` that builds your site and pushes the result to a `gh-pages` branch.
- GitHub serves that branch at `https://<user-or-org>.github.io/<repo>/` (or a custom domain, see below).
- A cached `lexd` binary across runs, so the plugin doesn't re-download it every build.

## Prerequisites

One-time setup in the GitHub repo:

1. **Settings → Pages → Build and deployment → Source:** *Deploy from a branch*.
2. **Branch:** `gh-pages` / `/ (root)`. The branch won't exist until your first deploy — you can come back and set this after the first successful workflow run.
3. **Settings → Actions → General → Workflow permissions:** *Read and write permissions*. The workflow needs write access to push to the `gh-pages` branch.

## The workflow

Save as `.github/workflows/docs.yml` (full copy: [`examples/docs.yml`](examples/docs.yml)):

```yaml
name: Docs

on:
  push:
    branches: [main]
    paths:
      - docs/**
      - mkdocs.yml
      - .github/workflows/docs.yml
  workflow_dispatch:

concurrency:
  group: docs-${{ github.ref }}
  cancel-in-progress: false

jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/cache@v4
        with:
          path: .mkdocs_lex_cache
          key: mkdocs-lex-${{ runner.os }}-${{ hashFiles('docs/requirements.txt') }}
          restore-keys: |
            mkdocs-lex-${{ runner.os }}-

      - uses: mhausenblas/mkdocs-deploy-gh-pages@1.26
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REQUIREMENTS: docs/requirements.txt
          CONFIG_FILE: mkdocs.yml
```

That's it. Commit the file and push to `main`; the first run will create the `gh-pages` branch and populate it. Subsequent runs only fire when `docs/**`, `mkdocs.yml`, or the workflow itself changes.

## Why this shape

- **`mhausenblas/mkdocs-deploy-gh-pages@1.26`** wraps `mkdocs gh-deploy`. It installs Python, reads `REQUIREMENTS`, runs `mkdocs build`, and pushes to `gh-pages` in one step. The action is older (last tagged Jan 2023) but stable and is what the `dodot` project has been using in production with no issues — it's the shortest path that works.
- **`actions/cache` for `.mkdocs_lex_cache/`** keeps the `lexd` binary across runs. Without it, every build downloads the binary again (~10MB, a few seconds). The path is mounted into the action's container because it sits inside `$GITHUB_WORKSPACE`.
- **`paths:` filter** keeps the workflow from running on every commit — only when docs sources change.
- **`fetch-depth: 0`** is needed because `mkdocs gh-deploy` reads the existing `gh-pages` branch to compute the commit it pushes.
- **`concurrency` with `cancel-in-progress: false`** means rapid pushes queue rather than cancelling each other, so an in-flight deploy isn't left half-done.

## Custom domain

If you're using a custom domain (`docs.example.com`), set it in **Settings → Pages → Custom domain** *and* commit a `CNAME` file containing the bare domain into your `docs/` directory. Without the latter, every redeploy will wipe the CNAME GitHub stored on the `gh-pages` branch and your custom domain mapping will break until you set it again.

```
docs/
  CNAME             # contains exactly: docs.example.com
  index.md
  ...
```

## Versioned docs

If you need a version switcher (latest vs. v1.x vs. v2.x), the conventional choice is [`mike`](https://github.com/jimporter/mike), which manages multiple subdirectories on the `gh-pages` branch. The workflow above doesn't wire up `mike` — when you reach the point of needing versioned docs, switch to [Read the Docs](read-the-docs.md), which handles versioning natively, or extend this workflow with `mike deploy` calls.

## Troubleshooting

**The first run succeeds but `https://<user>.github.io/<repo>/` 404s.** Go back to Settings → Pages and set the source branch to `gh-pages`. GitHub doesn't auto-configure this on first push.

**The build fails with `lexd: command not found`.** Confirm the workflow has network egress to `github.com/lex-fmt/lex/releases`. The plugin's `download_if_missing: true` (the default) needs to reach GitHub Releases. If you've overridden that to `false`, you'll need to install `lexd` explicitly in `REQUIREMENTS` or a pre-step.

**Permission denied pushing to `gh-pages`.** Check **Settings → Actions → General → Workflow permissions** is set to *Read and write*. The `permissions: contents: write` block in the workflow grants the token capability, but the repo-level setting must allow it.

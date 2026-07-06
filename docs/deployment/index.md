# Deployment

Where to publish a `mkdocs-lex` site, and how.

## Recommendation

**Use GitHub Actions + GitHub Pages.** It's the shortest path: one workflow file, no extra hosting account, and the same `mkdocs gh-deploy` machinery the wider MkDocs ecosystem uses. See [GitHub Pages](github-pages.md).

Pick something else if:

- **Read the Docs** — you want versioned docs (a version switcher across tags and branches), built-in pull-request previews, or you already host other projects there. See [Read the Docs](read-the-docs.md).
- **CI build verification only** — you deploy elsewhere (Netlify, Cloudflare Pages, an internal server) and just want CI to fail when a docs change won't build. See [CI verification](ci-verification.md).

## What runs where

The `mkdocs-lex` plugin converts `.lex` files via the `lexd` binary. By default, on first build, the plugin downloads the matching `lexd` release into `.mkdocs_lex_cache/`. That means every deployment target listed here needs:

1. Network egress from the build environment (to fetch `lexd` from GitHub releases on first build).
2. A Python toolchain (MkDocs itself, plus this plugin).
3. Ideally, a persistent cache for `.mkdocs_lex_cache/` so `lexd` isn't re-downloaded every build.

All three options below satisfy (1) and (2) out of the box. The recipes below also wire up (3) where the build host supports it.

## What the recipes share

Every recipe pins to the same handful of files at the root of your repo:

```text
mkdocs.yml
docs/
  index.md
  ...
docs/requirements.txt   # pinned Python deps for the build
```

A minimal `docs/requirements.txt` for a `mkdocs-lex` site:

```text
mkdocs>=1.5
mkdocs-lex-plugin
mkdocs-material   # or your theme of choice; remove if using the default theme
```

Ready-to-copy example: [`examples/requirements.txt`](examples/requirements.txt).

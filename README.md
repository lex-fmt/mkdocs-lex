# mkdocs-lex

A native Lex parser and integration for MkDocs.

This plugin allows MkDocs to seamlessly parse and render `.lex` files as part of your documentation site. It acts as a transparent adapter—MkDocs treats your `.lex` files as native Markdown pages, meaning all of your favorite MkDocs features, themes, and plugins will continue to work perfectly!

> [!NOTE]
> This plugin needs the `lexd` CLI to convert your `.lex` files. By default it will download the right binary for your platform from the latest `lex-fmt/lex` release on first run and cache it under `.mkdocs_lex_cache/` — no manual install needed. If you already have `lexd` on your `PATH`, it'll use that instead.

## Installation

Install the package via pip:

```bash
pip install mkdocs-lex-plugin
```

## Usage

To enable the plugin, add `lex` to the `plugins` section of your `mkdocs.yml`:

```yaml
site_name: My Documentation

plugins:
  - search
  - lex
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `download_if_missing` | `true` | When `lexd` isn't on `PATH`, fetch the latest matching binary from the `lex-fmt/lex` GitHub releases and cache it under `.mkdocs_lex_cache/`. Set to `false` to require a pre-installed `lexd` and error out if it's missing. |

```yaml
plugins:
  - search
  - lex:
      download_if_missing: false   # require pre-installed lexd
```

### Navigation Configuration

Because the plugin tricks MkDocs into treating your `.lex` files as Markdown, your `mkdocs.yml` navigation must point to `.md` extensions, even though the files on disk are `.lex`. 

For example, if you have `docs/getting-started.lex` and `docs/index.lex`:

```yaml
nav:
  - Home: index.md
  - Getting Started: getting-started.md
```

## Deployment

To publish a `mkdocs-lex` site:

- **GitHub Pages via GitHub Actions** — the recommended path. See [`docs/deployment/github-pages.md`](docs/deployment/github-pages.md).
- **Read the Docs** — choose this when you want versioned docs or PR previews. See [`docs/deployment/read-the-docs.md`](docs/deployment/read-the-docs.md).
- **CI build verification only** — when you deploy from elsewhere but want CI to fail on broken docs. See [`docs/deployment/ci-verification.md`](docs/deployment/ci-verification.md).

Full overview and trade-offs: [`docs/deployment/`](docs/deployment/index.md).

## Development Setup

If you want to contribute or test this plugin locally:

1. Clone the repository: `git clone https://github.com/lex-fmt/mkdocs-lex`
2. Run the development setup script: `bash scripts/setup-dev-env.sh`
3. Activate the virtual environment: `source .venv/bin/activate`
4. Run integration tests: `pytest tests/`

## How it works

MkDocs is fundamentally a Markdown engine. This plugin integrates cleanly by:
1. Identifying `.lex` files in your `docs/` folder.
2. Tricking MkDocs' internal engine into believing they are `.md` pages.
3. Intercepting the file-read hook (`on_page_read_source`) to perform a just-in-time conversion of Lex to Markdown using the `lexd convert` capability.

This means no temporary `.md` files clutter your repo, and live-reloading (`mkdocs serve`) works natively when you edit a `.lex` file!

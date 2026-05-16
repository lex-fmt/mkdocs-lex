# mkdocs-lex

A native Lex parser and integration for MkDocs.

This plugin allows MkDocs to seamlessly parse and render `.lex` files as part of your documentation site. It acts as a transparent adapter—MkDocs treats your `.lex` files as native Markdown pages, meaning all of your favorite MkDocs features, themes, and plugins will continue to work perfectly!

> [!NOTE]
> This plugin requires the `lexd` CLI tool to be installed and available in your `PATH`. 

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

You can configure the plugin to automatically download the `lexd` CLI if it is not found on the host machine. This is extremely useful for CI/CD pipelines (like GitHub Actions) so you don't have to manually install the Rust binary.

```yaml
plugins:
  - search
  - lex:
      download_if_missing: true
```

If set to `true`, the plugin will query the GitHub API for the latest `lex-fmt/lex` release, automatically detect your operating system and architecture, download the appropriate binary, and cache it locally in a `.mkdocs_lex_cache/` directory.

### Navigation Configuration

Because the plugin tricks MkDocs into treating your `.lex` files as Markdown, your `mkdocs.yml` navigation must point to `.md` extensions, even though the files on disk are `.lex`. 

For example, if you have `docs/getting-started.lex` and `docs/index.lex`:

```yaml
nav:
  - Home: index.md
  - Getting Started: getting-started.md
```

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

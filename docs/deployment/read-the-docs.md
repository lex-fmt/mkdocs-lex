# Read the Docs

Publish a `mkdocs-lex` site on [Read the Docs](https://readthedocs.org/). RTD watches your repo directly, so this option needs **no GitHub Actions workflow** — just two config files.

## When to choose RTD over GitHub Pages

- You want a version switcher (latest, stable, per-tag, per-branch) without wiring up `mike` yourself.
- You want pull-request preview builds (RTD builds and serves every PR at a unique URL).
- You're already publishing other docs on RTD and want everything in one place.

If none of those apply, [GitHub Pages](github-pages.md) is simpler.

## Configuration

Two files in your repo root, both committed:

### `.readthedocs.yaml`

Full copy: [`examples/.readthedocs.yaml`](examples/.readthedocs.yaml).

```yaml
version: 2

build:
  os: ubuntu-24.04
  tools:
    python: "3.12"
  jobs:
    pre_install:
      - pip install -r docs/requirements.txt

mkdocs:
  configuration: mkdocs.yml
```

### `docs/requirements.txt`

```
mkdocs>=1.5
mkdocs-lex-plugin
mkdocs-material   # or your theme of choice
```

## One-time setup on readthedocs.org

1. Sign in with your GitHub account at [readthedocs.org](https://readthedocs.org/).
2. **Import a project** → pick your repo. RTD will detect the `.readthedocs.yaml` and configure the build.
3. **Admin → Advanced settings → Default branch:** set to whatever branch you publish from (usually `main`).
4. **Admin → Automation rules:** add a rule to activate new tags as versions if you want tagged releases to auto-appear in the version switcher.

Push to `main` and RTD will build. The site lives at `https://<project-slug>.readthedocs.io/`.

## Why this shape

- **`build.os: ubuntu-24.04`** — RTD's current stable base image.
- **`pre_install` over `python.install.requirements`** — both work, but `pre_install` runs before RTD's own implicit install steps, which avoids occasional dependency-resolution surprises.
- **`mkdocs.configuration`** — tells RTD this is an MkDocs project (not Sphinx) and where to find `mkdocs.yml`.
- **No special handling for `lexd`** — the plugin downloads `lexd` from GitHub Releases on first build, and RTD's build environment has the network access it needs. RTD doesn't preserve the `.mkdocs_lex_cache/` directory between builds, so the binary downloads once per build (a few seconds — not worth optimizing).

## Canonical URL (optional but recommended)

If your docs are also published anywhere else (a GitHub Pages copy, a vendor mirror), set the canonical URL in `mkdocs.yml` so search engines don't penalize you for duplicate content:

```yaml
site_url: !ENV READTHEDOCS_CANONICAL_URL
```

RTD sets `READTHEDOCS_CANONICAL_URL` automatically per build, pointing at the public URL of the version being built.

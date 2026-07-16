<!-- generated - do not edit; fragments live in CHANGELOG/ (`shipit changelog render` regenerates this file) -->

# Changelog

## Unreleased

- ci: the legacy release workflow (`release.yml`, the `arthur-debert/release/python-pkg.yml@v1` caller) is deleted — releases go exclusively through the shipit pipeline (`gh workflow run shipit-release.yml -f version=X.Y.Z -f stage=full`) (#26)
- ci: releases are now cut through the shipit release pipeline (`shipit-release.yml`, #24); this fragment also bootstraps the per-PR changelog convention (`CHANGELOG/unreleased-<slug>.md`)

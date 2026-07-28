<!-- generated - do not edit; fragments live in CHANGELOG/ (`shipit changelog render` regenerates this file) -->

# Changelog

## Unreleased

- ci: PR checks run through shipit's `wf-checks` block (`checks.yml`, #21) instead of the hand-rolled `python-unittests.yml`; both the lint and test lanes are hermetic pixi runs, so CI and a laptop execute the same command
- fix: when the plugin downloads `lexd` for you, a failure to fetch, extract or query the GitHub release API now chains the underlying exception (`raise … from`), so the traceback shows the real network/archive error instead of only the `PluginError` wrapper
- fix: the post-download cleanup of the temporary archive no longer swallows every exception — it catches `OSError` only, so a `Ctrl-C` during cleanup interrupts the build as it should
- ci: the legacy release workflow (`release.yml`, the `arthur-debert/release/python-pkg.yml@v1` caller) is deleted — releases go exclusively through the shipit pipeline (`gh workflow run shipit-release.yml -f version=X.Y.Z -f stage=full`) (#26)
- ci: releases are now cut through the shipit release pipeline (`shipit-release.yml`, #24); this fragment also bootstraps the per-PR changelog convention (`CHANGELOG/unreleased-<slug>.md`)
- fix: both required CI lanes were dead — they called `shipit provision lexd`, a verb that has been retired with no fallback, so every PR check failed with `No such command 'provision'`. `lexd` now arrives as an ordinary pinned conda dependency of the pixi environments each lane resolves into, and the lanes run the managed `lint` and `test` tasks directly
- ci: the test suite no longer downloads `lexd` from GitHub at test time — the pinned `lexd` is in the test environment, so the integration build resolves it from `PATH` and the run is hermetic

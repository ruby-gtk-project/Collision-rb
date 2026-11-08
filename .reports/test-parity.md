# Test parity — Collision (re-audit, round 3)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `633c9e0` |
| Upstream tests | 5 |
| Ported | 5 |
| Gaps | 0 |
| Spec command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` — run live for this audit |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_window.rb` — run live for this audit |

Both commands were executed live for this re-audit:

```
47 examples, 0 failures            # spec suite
33 of 33 checks passed, DRIVE OK   # test/drive_window.rb
```

The runtime gate handed to this round (33 passed / 0 failed, 8 components)
matches the drive number exactly. The spec count (47) is up from the prior
pass's 44 — the difference is `spec/packaging_spec.rb`, added in `633c9e0`,
3 examples.

## Census — upstream's 5 tests, unchanged from the prior pass, re-confirmed by hand

### Suite: spec/compare_spec.cr (1 test)

| # | Upstream test | Port test | State |
|---|---|---|---|
| 1 | "returns whether the file contains one of the hashes" | `spec/compare_spec.rb` | ported |

### Suite: spec/feedback_spec.cr (2 tests)

| # | Upstream test | Port test | State |
|---|---|---|---|
| 2 | "returns the correct symbolic icon..." | `spec/feedback_spec.rb#".icon"` | ported |
| 3 | "returns the correct class to add and remove..." | `spec/feedback_spec.rb#".css_classes"` (renamed, documented) | ported |

### Suite: spec/hash_generator_spec.cr (2 tests)

| # | Upstream test | Port test | State |
|---|---|---|---|
| 4 | "gets hashes from file" | `spec/hash_generator_spec.rb` | ported |
| 5 | "splits strings by 4" | `spec/hash_generator_spec.rb` | ported |

**5/5, bijection re-confirmed this pass.** No upstream test maps to two Ruby
tests, no Ruby test covers two upstream properties at once.

## The gap the prior two rounds flagged is now closed

Prior rounds (`aab6951` and before) found `rakelib/packaging.rake`'s two
build tasks had zero spec coverage — the exact mechanism that let the
obsolete-translation defect go undetected through two "parity reports"
commits. `633c9e0` adds `spec/packaging_spec.rb`, which:

- runs `desktop:build` and asserts `GenericName[xx]=`/`Keywords[xx]=` lines
  exist for a 3-locale sample (not merely that the file exists),
- runs `metainfo:build` and asserts translated `<name>`/`<summary>`/`<p>`
  lines for the same sample,
- runs `nautilus:mo` against a throwaway locale directory and **decompiles
  the resulting `.mo` with `msgunfmt`** to assert the catalogue actually
  translates `"Check Hashes"`, not just that a file was written.

Re-run live for this audit (part of the 47-example total above): all 3
examples pass. This is a real regression test, not a vacuous one — it reads
the built content's string, not just the exit code, in every one of its
three examples.

## What still has no coverage — named rather than left silent

No automated check runs `rake nautilus:install` itself (which copies the
`.py` file to `~/.local/share/nautilus-python/extensions/` and asks a running
Nautilus to reload) or exercises an actual running Nautilus process picking
up the extension end-to-end. `packaging_spec.rb` covers the `.mo`-compiling
half of that path, not the file-copy-and-reload half. This is a real,
disclosed gap, consistent with this round's brief ("a component no check
exercises is unverified, not done") — flagged here rather than counted as
closed, since nothing in the 47/33 numbers above exercises it.

## Rules check

- Suite was run, not assumed: confirmed above, this pass, both commands, live.
- No row left without a named port test or a stated gap: none open in the
  5/5 upstream bijection.
- No upstream test lowered to pass.
- A component no check exercises is flagged, not credited: `rake
  nautilus:install`'s file-copy-and-Nautilus-reload path, named above.

# Test parity — Collision (re-audit)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `aab6951` |
| Upstream tests | 5 |
| Ported | 5 |
| Gaps | 0 |
| Spec command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` — run live for this audit |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_window.rb` — run live for this audit |

Both commands were actually executed in this re-audit, not taken on the
prior report's word or the runtime gate's number alone:

```
44 examples, 0 failures            # spec suite
33 of 33 checks passed, DRIVE OK   # test/drive_window.rb
```

The runtime gate handed to this round (33 passed / 0 failed, 8 components)
matches the drive number exactly. The spec count (44) is **not** what the
prior `test-parity.md` recorded (42) — the difference is
`spec/i18n_encoding_spec.rb`, added in commit `aab6951` after the prior pass
ran, with 2 examples. This report updates the count; the bijection below is
otherwise unchanged from the prior pass, independently re-checked.

## Census — upstream's 5 tests, by hand, both sides read

### Suite: spec/compare_spec.cr (1 test)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `compare_spec.cr` "returns whether the file contains one of the hashes" | `FileUtils.compare_content` finds a known hash in a file's text | `spec/compare_spec.rb#"returns whether the file contains one of the hashes"` | ported |

### Suite: spec/feedback_spec.cr (2 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 2 | `feedback_spec.cr` "returns the correct symbolic icon..." | `Feedback.icon(success)` picks pass/cross symbolic icon | `spec/feedback_spec.rb#".icon"` | ported |
| 3 | `feedback_spec.cr` "returns the correct class to add and remove..." | `Feedback.class(success)` returns add/remove CSS class pair | `spec/feedback_spec.rb#".css_classes"` (renamed — `class` on a Ruby module shadows `Object#class`, documented in the file's header) | ported |

### Suite: spec/hash_generator_spec.cr (2 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 4 | `hash_generator_spec.cr` "gets hashes from file" | every `CLIPBOARD_HASH` function over the fixture matches the known digest | `spec/hash_generator_spec.rb#"#calculate" "gets hashes from file"` | ported |
| 5 | `hash_generator_spec.cr` "splits strings by 4" | `split_by_4` re-inserts spaces every 4 chars | `spec/hash_generator_spec.rb#".split_by_4" "splits strings by 4"` | ported |

**5/5, bijection re-confirmed by hand-reading both sides this pass** — no
upstream test maps to two Ruby tests, no Ruby test covers two upstream
properties at once.

## Extra — not parity work, listed because the skill requires it

Port's suite is 44 examples against upstream's 5; 39 are extra:

- `spec/compare_spec.rb` — 8 extra: `.file?` (3), `.real_path` (3, including
  Flatpak document-portal branches upstream never tests), 2 more
  `.compare_content` cases.
- `spec/feedback_spec.rb` — 1 extra: `.title`, no upstream counterpart.
- `spec/hash_generator_spec.rb` — 6 extra: `HASH_FUNCTIONS` key-set, the
  `ArgumentError` on an unknown function, `#enabled_hash_functions`,
  `#generate` ×3, `.split_by_4`'s short-string case.
- `spec/i18n_spec.rb` — 24 extra, entirely outside the 5/5 count (upstream
  delegates to C gettext, no file to port against).
- `spec/i18n_encoding_spec.rb` — **new since the prior pass**, 2 examples.
  Boots a brand-new Ruby process with no `LANG`/`LC_ALL`/`LC_MESSAGES` set
  and asserts the catalogue loader does not crash. This is the regression
  test for the bug the prior `translation-parity.md` found and `aab6951`
  fixed — re-run live, both examples pass, and the fix was independently
  re-verified against the running code in `component-parity.md`, not just
  this spec.
- `test/drive_window.rb` — 33 UI-level checks, no upstream counterpart.

## What this suite still does not run — the gap this pass adds

Neither the spec suite nor `test/drive_window.rb` ever builds
`data/dev.geopjr.Collision.desktop` or `data/dev.geopjr.Collision.metainfo.xml`
from their `.in` templates, so nothing in the suite would have caught this
round's finding (`translation-parity.md`, `component-parity.md`): that
`rake desktop:build` and `rake metainfo:build` silently drop the
`GenericName`/`Keywords`/`<description>` translations. `rakelib/packaging.rake`
has no spec coverage at all — it is driven only by hand, as this audit did.
A task with no test is unverified by this suite's own 33/33 and 44/0
numbers, which is exactly the runtime-gate caveat this round's brief calls
out: 8 components covered by the gate, and packaging is not one of them.

## Rules check

- Suite was run, not assumed: confirmed above, this pass, both commands, live.
- No row left without a named port test or a stated gap: none open, 0 gaps
  in the 5/5 bijection.
- No upstream test lowered to pass: all 5 assert the identical property.
- A component no check exercises is flagged as unverified, not credited as
  done: `rakelib/packaging.rake`'s two build tasks, named above.

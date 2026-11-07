# Test parity — Collision

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `1c70cce` |
| Upstream tests | 5 |
| Ported | 5 |
| Gaps | 0 |
| Test command | `xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` (run live for this audit) |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_window.rb` (run live for this audit) |

Both commands were actually executed in this audit, not taken on the
PORTING-claim's word:

```
42 examples, 0 failures            # spec suite
33 of 33 checks passed, DRIVE OK   # test/drive_window.rb
```

That is the runtime gate the task handed in (33 passed / 0 failed) confirmed
independently, plus the spec suite, which the gate's own number does not
cover.

## Census

Upstream's suite is three Crystal spec files, five examples total:

## Suite: spec/compare_spec.cr (1 test)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `compare_spec.cr` "returns whether the file contains one of the hashes" | `FileUtils.compare_content` finds a known hash in a file's text | `spec/compare_spec.rb#"returns whether the file contains one of the hashes"` | ported |

## Suite: spec/feedback_spec.cr (2 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 2 | `feedback_spec.cr` "returns the correct symbolic icon..." | `Feedback.icon(success)` picks the pass/cross symbolic icon | `spec/feedback_spec.rb#".icon"` | ported |
| 3 | `feedback_spec.cr` "returns the correct class to add and remove..." | `Feedback.class(success)` returns the add/remove CSS class pair | `spec/feedback_spec.rb#".css_classes"` — renamed because `class` on a Ruby module shadows `Object#class`; documented in the file's header comment. Same assertion, same literal expected hash | ported |

## Suite: spec/hash_generator_spec.cr (2 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 4 | `hash_generator_spec.cr` "gets hashes from file" | every `CLIPBOARD_HASH` function, computed over the fixture file, matches the known-good digest | `spec/hash_generator_spec.rb#"#calculate" "gets hashes from file"` | ported |
| 5 | `hash_generator_spec.cr` "splits strings by 4" | `split_by_4` re-inserts spaces every 4 characters | `spec/hash_generator_spec.rb#".split_by_4" "splits strings by 4"` | ported |

**5/5, bijection confirmed by hand-reading both sides — no upstream test maps
to two Ruby tests and no Ruby test covers two upstream properties at once.**

## Extra

The port's suite is 42 examples against upstream's 5. 37 are extra — not
parity work, listed because `test-parity` requires it, never counted toward
the 5/5:

- `spec/compare_spec.rb` — 8 more examples than upstream's 1: `.file?` (3),
  `.real_path` (3, including the Flatpak document-portal branches upstream
  never tests), and 2 more `.compare_content` cases (a non-match, an
  upper-case hash).
- `spec/feedback_spec.rb` — 1 more: `.title`, a method with no upstream
  counterpart.
- `spec/hash_generator_spec.rb` — 6 more: `HASH_FUNCTIONS` key-set, the
  `ArgumentError` on an unknown function, `#enabled_hash_functions`,
  `#generate` (×3: full run, disabled-functions, progress-bar text), and
  `.split_by_4`'s short-string case.
- `spec/i18n_spec.rb` — 24 examples, entirely extra: `lib/collision/i18n.rb`
  has no upstream file at all (upstream delegates to C gettext), so there is
  nothing to port here and this whole file is outside the 5/5 count. It is,
  however, the file whose coverage this audit found a real hole in — see
  `translation-parity.md`: none of its 24 examples drive the catalogue loader
  under a from-scratch process boot with no locale environment set, which is
  the one condition that actually breaks it.
- `test/drive_window.rb` — 33 UI-level checks, no upstream counterpart
  (upstream has no window-level test at all; Crystal's spec suite covers only
  the three pure-function files above). Extra, not parity.

## Rules check

- Suite was run, not assumed: confirmed above, this pass, both commands.
- No row left without a named port test or a stated gap: none open, 0 gaps.
- No upstream test lowered to pass: all 5 assert the identical property upstream asserted, same inputs.

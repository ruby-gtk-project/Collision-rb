# Component identification — Collision (re-audit, round 3)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` (fetched live this round — unchanged since the prior pass) |
| Port | `ruby` @ `633c9e0` |

This re-audit starts from `.reports/component-inventory.md` (whole-app
survey, unchanged) and the prior `component-identification.md`/
`component-parity.md`, written against `aab6951`, which found that §16–18
(Nautilus menu item, desktop entry, AppStream metainfo) had port files but
one translatable facet of each was dead in the built artifact. Commit
`633c9e0` ("Close the translation-parity gap: resurrect the three orphaned
msgids") landed after those reports were committed. This pass re-identifies
all three units against the current `HEAD`, verifying the fix live rather
than reading the commit message.

## §16 — Nautilus "Check Hashes" menu item

File and signal unchanged from the prior pass (still a correct, complete
port of the Python extension). What changed: `rakelib/packaging.rake` now
has a `nautilus:mo` task that compiles `po/*.po` into `.mo` files at the
locale directory the Nautilus-loaded `python3` actually uses
(`gettext._default_localedir`, asked live rather than guessed), and
`nautilus:install` depends on it. Verified live by running the task against
a throwaway `COLLISION_NAUTILUS_LOCALE_DIR` and decompiling the result with
`msgunfmt`: the `.mo` for `de`/`fr`/`ja` each contain `msgid "Check Hashes"`
mapped to a non-English `msgstr`. `spec/packaging_spec.rb` now exercises this
exact path and passes. **The component's one translatable string can now
reach a non-English user, provided the person installing it has (or uses
`sudo` for) write access to that locale directory** — the task warns and
continues rather than failing when it does not, which is a real, disclosed
limitation, not a silent gap.

## §17 — Desktop entry (`dev.geopjr.Collision.desktop`)

Built live for this audit (`rake desktop:build`). All three translatable
fields now carry per-language lines: `Name[xx]=` (41/41, unchanged from
before), and — newly confirmed — `GenericName[xx]=` (39 languages) and
`Keywords[xx]=` (34 languages). Root cause from the prior round (`po/POTFILES`
never listed `data/dev.geopjr.Collision.desktop.in`, orphaning these two
msgids to `#~`) is fixed: `po/POTFILES` now lists the file, and
`grep -l '#~ msgid "Hash Generator"' po/*.po` returns 0 matches, down from 39.

## §18 — AppStream metadata (`dev.geopjr.Collision.metainfo.xml`)

Built live for this audit (`rake metainfo:build`). `<p xml:lang="...">`
description paragraphs: 74 lines across all languages (was 0). `<summary
xml:lang="...">` unaffected, still present. `po/sk.po`'s translation of the
description string had a raw, unescaped `&` that the regeneration surfaced
as a real `rake metainfo:build` crash (not merely an obsolete-entry issue);
confirmed fixed by reading the file — `po/sk.po:257` now reads `&amp;`
matching the correctly-escaped upstream source — and by re-running
`metainfo:build` clean.

## New this round: `spec/packaging_spec.rb`

Did not exist at the prior pass. Covers `desktop:build`, `metainfo:build`,
and `nautilus:mo` end to end for a 3-locale sample, including decompiling the
built `.mo` with `msgunfmt` to assert the string is actually translated, not
merely that a file was produced. This closes the "component no check
exercises" gap the prior round's `test-parity.md` flagged for
`rakelib/packaging.rake`. Re-run live this round as part of the full suite
(47 examples now, up from 44 — see `test-parity.md`).

## Rest of the inventory — unchanged

The other 15 units in `component-inventory.md` were not touched since the
last pass; re-checked for drift (file presence, action/accel bindings) and
found none. 33/33 drive checks and the (now 47-example) spec suite both
re-run live and pass.

## Still-open, non-blocking notes carried from before (unchanged, not re-litigated this round)

1. `app.shortcuts` origin differs (libadwaita auto-install upstream vs. an
   explicit port `Action` subclass) — behaviourally equivalent, flagged
   previously, still true, still not a gap in outcome.
2. About dialog's `debug_info` is a static snapshot vs. upstream's
   accumulating redacted log — a documented, intentional simplification.
3. CSS (`data/style.css`) was not re-diffed line-by-line this round; no new
   evidence it has drifted.

## Summary

All 3 units that the prior round found "file exists, one translatable facet
dead" are now verified, by building the real artifacts and decompiling the
real `.mo`, to deliver translated content. 0 open component-identification
gaps this round.

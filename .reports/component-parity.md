# Component parity — Collision (re-audit, round 3)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` (re-fetched live this round, unchanged) |
| Port | `ruby` @ `633c9e0` |
| Runtime gate (this round) | `DRIVE OK`, 33/33, re-run live |
| Spec suite | 47 examples, 0 failures, re-run live (was 44 at the prior pass — `spec/packaging_spec.rb`, added in `633c9e0`, is the +3) |

This supersedes the prior `component-parity.md`, which was written against
`aab6951` and found 3 of 4 claimed translation-gap closures to be only
half-true: files existed but the specific translatable content (desktop
`GenericName`/`Keywords`, metainfo `<description>`, the Nautilus label) was
either marked obsolete in every `.po` catalogue or had no `.mo` delivery
mechanism at all. Commit `633c9e0` ("Close the translation-parity gap:
resurrect the three orphaned msgids") landed afterward, specifically to fix
this. Checked each claim against the running code, not the message:

| Prior gap | This commit's claim | Verified |
|---|---|---|
| Nautilus label undeliverable (no `.mo` path) | fixed | **True.** `rake nautilus:mo` compiles `po/*.po` to the real locale directory Nautilus's own `python3` reports; decompiled a built `.mo` with `msgunfmt` and confirmed `de`/`fr`/`ja` translate `"Check Hashes"`. |
| Desktop `GenericName`/`Keywords` dead in every locale | fixed | **True.** `rake desktop:build`, run live: `GenericName[xx]=` in 39 languages, `Keywords[xx]=` in 34, both zero before. |
| Metainfo `<description>` untranslated in every locale | fixed | **True.** `rake metainfo:build`, run live: 74 `<p xml:lang="...">` lines, zero before. |

All three are now fully closed, independently reverified by building the
real artifacts and inspecting their content — not by trusting the commit
message or the prior-round report.

## A real bug the fix surfaced and fixed

`po/sk.po`'s translation of the metainfo description string had a raw,
unescaped `&`, which the regenerated template exposed as a hard crash in
`rake metainfo:build` once that string returned to scope. Verified by
reading `po/sk.po:257` (now `&amp;`, matching upstream's escaping) and
re-running `metainfo:build` clean.

## A pre-existing fuzzy-match artifact, not a regression

The regeneration marked upstream's old "ampersand pre-escaped as `&amp;`"
entry fuzzy against the newly-decoded form; the decoded text is identical
word-for-word. No translator-visible change, confirmed by reading the diff.

## Why these three are structurally closed, not just today's snapshot

`po/POTFILES` now lists all three non-Ruby sources
(`data/dev.geopjr.Collision.desktop.in`, `data/dev.geopjr.Collision.metainfo.xml.in`,
`nautilus-extension/collision-extension.py`) alongside the 9 `lib/` files.
`po/README.md` documents the per-format `xgettext` invocations
(`-L Desktop`, `--its=metainfo.its`, `-L Python`) needed to regenerate
against them, since `rxgettext` (ruby-gettext) cannot parse any of the three.
This closes the structural gap the prior round flagged: before this commit,
no documented or tooled path existed to even attempt re-including these
files; now one does, and `spec/packaging_spec.rb` provides the regression
test that would catch the next POTFILES omission before the next person
walks into the exact same obsolete-entry trap.

## Rest of the inventory

No other change from `component-inventory.md`'s other 15 units.

## Verdict

**Clean, this round.** All 4 translation-related closures claimed by prior
commits are now independently verified true against the running code. 0
open component-parity gaps.

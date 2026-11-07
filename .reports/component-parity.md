# Component parity — Collision (re-audit)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `aab6951` |
| Runtime gate (this round) | `DRIVE OK`, 33/33, re-run live for this audit |
| Spec suite | 44 examples, 0 failures, re-run live for this audit (was 42 at the prior pass's `.pot`/report snapshot — `spec/i18n_encoding_spec.rb`, added in `aab6951`, is the +2) |

This supersedes the prior `component-parity.md`, written before `aab6951`.
That pass found 3 gaps (Nautilus extension, desktop entry, AppStream
metadata) and flagged a locale crash. `aab6951`'s commit message claims all
four are closed ("Close four parity gaps: desktop entry, metainfo, Nautilus
extension, i18n encoding crash"). Checked each claim against the running
code rather than the message:

| Prior gap | Commit's claim | Verified |
|---|---|---|
| i18n encoding crash under an unset locale | fixed | **True.** `lib/collision/i18n.rb:125` now reads with explicit `encoding: "UTF-8"`. Re-ran the exact repro from the prior `translation-parity.md` live: `LANGUAGE=fr LC_ALL= LC_MESSAGES= LANG= ruby -e '...I18n._("Pending")'` now prints `En attente` instead of raising `Encoding::CompatibilityError`. `spec/i18n_encoding_spec.rb` boots a fresh process to cover exactly this, and it passes. |
| Nautilus extension unported | fixed | **File exists, half the fix.** See below. |
| Desktop entry unported | fixed | **File exists, two of three translatable fields are dead.** See below. |
| AppStream metadata unported | fixed | **File exists, the description is untranslated.** See below. |

The i18n crash fix is real and complete. The other three are **not** fully
closed — the commit message overstates what shipped. Detail and the full
evidence trail are in `translation-parity.md`; summarized here because it is
a component-identity fact, not only a string-count fact:

## Nautilus extension — `nautilus-extension/collision-extension.py`

File-for-file present, correct label, correct signal, correctly adapted
`get_collision()`. **Gap, not closed:** the string `_("Check Hashes")` is
looked up through the *system* gettext locale directory at runtime
(`textdomain('dev.geopjr.Collision')`), and nothing in this repository
compiles or installs a `.mo` catalogue there — `rake nautilus:install` only
copies the `.py` file. On any machine where this gem is the only thing that
ever installed `dev.geopjr.Collision` translations (i.e. every real install
of this port, since it has no Flatpak/system package providing `.mo`s), the
right-click entry reads "Check Hashes" in English for every user, in every
locale, always. The component is wired; its one translatable string cannot
reach a non-English user by any path this repo provides.

## Desktop entry — `data/dev.geopjr.Collision.desktop`

Built live for this audit (`rake desktop:build`, via the real `msgfmt
--desktop`). `Name[xx]=` lines: present, 41/41. `GenericName` and `Keywords`:
**zero** per-language lines in the output — confirmed by grepping the built
file for `GenericName\[` and `Keywords\[`, both absent. Root cause: the
`po/*.po` entries for `"Hash Generator"` and the keywords string are marked
`#~` (obsolete) in 39/41 and 38/41 catalogues respectively (counted live:
`grep -l '#~ msgid "Hash Generator"' po/*.po | wc -l` → 39). `msgfmt --desktop`
correctly ignores obsolete entries, same as real gettext tooling would.

## AppStream metadata — `data/dev.geopjr.Collision.metainfo.xml`

Built live for this audit (`rake metainfo:build`). `<summary xml:lang="...">`:
present (this string is shared with `window.rb`'s status-page text, which is
in the port's own `po/POTFILES` scope, so it was never marked obsolete).
`<description xml:lang="...">` / `<p xml:lang="...">`: **zero** in the built
output — confirmed (`grep -c '<description xml:lang' → 0`, `grep -c '<p
xml:lang' → 0`). Same obsolete-entry root cause.

## Why the translations are obsolete: a structural gap, not a one-off

`po/POTFILES` on the port lists only the 9 `lib/collision/**.rb` files that
existed when `po/` was ported (`21d7f5c`, before `aab6951` added the three
new source files). `aab6951` added `data/dev.geopjr.Collision.desktop.in`,
`data/dev.geopjr.Collision.metainfo.xml.in` and
`nautilus-extension/collision-extension.py` as real, string-bearing files,
but did not add any of them to `po/POTFILES`, and no task in `Rakefile` or
`rakelib/` regenerates `po/POTFILES` or re-runs `msgmerge` against it. There
is no mechanism in this repository, today, that would un-obsolete these
entries even if someone tried — the next person to regenerate the `.pot`
from `po/POTFILES` would still omit all three files. This is the structural
form of the gap `component-identification.md` §16–18 describes per-unit.

## Rest of the inventory

No other change from `.reports/component-inventory.md`'s 15 other units.
Full 4-axis parity (type/CSS/signal/text) confirmed previously and
unaffected by this round's findings.

## Verdict

**Not clean.** 1 of 4 claimed closures (the i18n crash) is fully verified.
3 of 4 (Nautilus label, desktop GenericName/Keywords, metainfo description)
are partially closed: the component now exists and is wired into a build
task, but the specific translatable content that made the original finding a
*translation* gap is still not delivered to a non-English user by any path
this repo provides, for any of the 41 shipped languages. Carried into
`translation-parity.md` (full evidence) and `accountability-ensurance.md`
(the commit message's unqualified "closing" claim).

# Translation parity — Collision (re-audit)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `aab6951` |
| Domain | `dev.geopjr.Collision` |
| Languages | 41/41 — file lists still identical |

This supersedes the prior `translation-parity.md`. That pass found 3 msgid
gaps (`Hash Generator`, the desktop `Keywords` string, `Check Hashes`) — all
from files the port didn't ship — and one correctness bug (a catalogue-load
crash under an unset locale). Commit `aab6951` added the three missing files
and fixed the crash. Re-checked every claim live rather than trusting the
commit message.

## The crash fix: verified true

```
nix develop --command xvfb-run -a env LANGUAGE=fr LC_ALL= LC_MESSAGES= LANG= \
  ruby -e 'require_relative "lib/collision/i18n"; puts Collision::I18n._("Pending")'
```

Now prints `En attente`. `lib/collision/i18n.rb:125` reads catalogues with
explicit `encoding: "UTF-8"`. `spec/i18n_encoding_spec.rb` (2 examples,
re-run live) covers this with a fresh process boot. **Closed, confirmed.**

## The 3 msgid gaps: files exist now, but the strings still do not reach a user — new finding this round

The prior pass's gap was "no file, so no msgid, so no translation." The file
now exists for all three. The translation still does not reach a non-English
user, for a different, more structural reason: **the translations already
existed in all 41 `po/*.po` files, and they have been marked obsolete.**

Verified live:

```sh
grep -l '#~ msgid "Hash Generator"' po/*.po | wc -l   # 39
grep -l '#~ msgid "Check Hashes"'   po/*.po | wc -l   # 38
grep -c '#~ msgid "Verifying that a file' po/fr.po    # 1 (the metainfo description, obsolete too)
```

`#~` is gettext's own marker for "this entry's source reference no longer
appears in `POTFILES`, keep the translation on file but do not use it."
Confirmed this is the mechanism, not a coincidence, by reading
`po/POTFILES` on the port:

```
lib/collision/actions/about.rb
lib/collision/actions/hash_info.rb
lib/collision/checksum.rb
lib/collision/feedback.rb
lib/collision/hash_row.rb
lib/collision/primary_menu.rb
lib/collision/shortcuts_dialog.rb
lib/collision/toggle_hash_functions_dialog.rb
lib/collision/window.rb
```

Upstream's `po/POTFILES` additionally lists `data/dev.geopjr.Collision.desktop.in`,
`data/dev.geopjr.Collision.metainfo.xml.in`, and three `.ui` files. The port's
`po/POTFILES` was written in commit `21d7f5c` ("Port the translations"),
*before* `aab6951` added the desktop/metainfo/nautilus files, and `aab6951`
never added them to `po/POTFILES`. Whatever regenerated the port's `.po`
files against that incomplete file list (the diff against upstream's `fr.po`
shows a full re-merge: new `Report-Msgid-Bugs-To`/`POT-Creation-Date`
headers, new entries for `lib/`-only strings, and the desktop/metainfo/
nautilus entries pushed to the obsolete section) ran `msgmerge` scoped to
only those 9 files, so every msgid whose only source line was in a file
outside that list got moved to `#~`, taking its translation out of use —
even though the translation itself, word for word, is still sitting in the
file.

**Proved by actually building the artifacts, not by reading `.po` files:**

```sh
nix develop --command bash -c "rake desktop:build && rake metainfo:build"
grep 'GenericName\[' data/dev.geopjr.Collision.desktop   # 0 matches
grep 'Keywords\['     data/dev.geopjr.Collision.desktop   # 0 matches
grep -c '<description xml:lang' data/dev.geopjr.Collision.metainfo.xml   # 0
grep -c '<p xml:lang'            data/dev.geopjr.Collision.metainfo.xml   # 0
```

`Name[xx]=` lines are present for all 41 languages (that msgid has its own
line in `application.ui`/the window and was never orphaned). `<summary
xml:lang="...">` lines are present (shared msgid with `window.rb`'s status
page — in-scope). `GenericName`, `Keywords`, and the entire AppStream
`<description>` are English-only in the built output, in every locale,
because their translations are the ones marked obsolete.

The Nautilus extension's `"Check Hashes"` has the same obsolete-entry
problem, plus a second, independent problem: it is read through the
*system* gettext locale directory (`textdomain('dev.geopjr.Collision')` at
runtime, not `po/*.po` read directly the way `lib/collision/i18n.rb` does
for the main app). Nothing in this repository — not `rakelib/packaging.rake`,
not `Rakefile` — compiles `po/*.po` to `.mo` and installs it where system
gettext would find it. Even if the obsolete-entry problem were fixed, the
Nautilus menu item would still read in English on every real install of
this gem, because no `.mo` ever reaches `/usr/share/locale/`.

## Revised key-set count

Prior pass: 49/52 (3 gaps, files missing). This pass: the msgid count from
source is the same (upstream's 52, confirmed again by hand against
`about.cr`/`collision.cr`/`application.ui`/the now-added `desktop.in` and
`metainfo.xml.in`/`collision-extension.py`), and the port's `.rb`/`.in`/`.py`
source now carries all 52 msgids verbatim — **0 gaps at the source-text
level**. But 3 of those 52 — `Hash Generator`, the `Keywords` string, `Check
Hashes` — are undeliverable in the built artifacts for every one of the 41
shipped languages, because their translations are present-but-disabled
(desktop/metainfo) or present-but-unreachable (Nautilus, no `.mo` path at
all). The prior report's "gap" label was correct; only the *mechanism* of
the gap changed, from "missing text" to "present text the build silently
discards."

```
52/52 msgids in source · 41/41 languages shipped · 3/52 msgids produce
English output in every built artifact, in every locale, regardless of
translator effort already on file.
```

## Why this matters for the next pass, not just this one

There is no task anywhere in `Rakefile`/`rakelib/` that regenerates
`po/POTFILES` or re-runs `msgmerge`/`xgettext` against the port's own
source tree. The next file anyone adds with a translatable string — in
`lib/`, in a future `.in` template, anywhere — will go through the exact
same silent path: the string shows correctly in English, the component
"exists," and its translation quietly becomes `#~` the next time anyone
regenerates the catalogues, with no test anywhere in the 44-example spec
suite or the 33-check drive script positioned to catch it (`test-parity.md`).

## Step 5 checklist (skill-required)

1. **Key sets**: 52/52 at the source-text level; 3/52 undeliverable in the
   built artifacts. Not `parity: true`.
2. **Languages**: 41/41, file lists identical.
3. **Delivery — main app**: `.po` read directly by `lib/collision/i18n.rb`,
   confirmed working (and the crash fixed). **Delivery — desktop/metainfo**:
   built live, 2 of 3 translatable facets dead on arrival (above).
   **Delivery — Nautilus**: no delivery mechanism exists in this repo at all.
4. **Non-English locale, run live, not skipped**: re-ran the exact repro
   from the prior pass; the crash is gone. Ran the *new* check this pass
   adds — actually building `desktop`/`metainfo` and grepping the output —
   and that is where this round's finding comes from. "The suite passes" and
   "the artifact a user's shell actually shows is translated" are still two
   different claims; this pass is the one that checked the second for these
   three strings specifically, and it fails.

## Summary

```
Crash: fixed, confirmed. 3 msgid gaps from the last pass: files added, but
all 3 translations are present-in-.po-and-unused (obsolete entries) or
present-and-unreachable (no .mo delivery) — 0 of the 3 original gaps are
actually closed for a non-English user. No regeneration path exists to
prevent the next added string from landing in the same state.
```

Not clean.

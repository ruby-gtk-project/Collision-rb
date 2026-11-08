# Translation parity — Collision (re-audit, round 3)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `633c9e0` |
| Domain | `dev.geopjr.Collision` |
| Languages | 41/41 — file lists still identical |

This supersedes the prior `translation-parity.md`, which found all 3 of the
"missing file" msgid gaps from two rounds back had become "file exists, but
the translation is marked obsolete or has no `.mo` delivery path" gaps —
0 of 3 actually reaching a non-English user. Commit `633c9e0` was written
specifically to close that. Re-checked every claim live.

## The obsolete-entry mechanism: resolved, verified by rebuilding, not by reading the diff

```sh
grep -l '#~ msgid "Hash Generator"' po/*.po | wc -l   # 0  (was 39)
grep -l '#~ msgid "Check Hashes"'   po/*.po | wc -l    # 0  (was 38)
```

`po/POTFILES` now lists all three previously-orphaned sources:

```
data/dev.geopjr.Collision.desktop.in
data/dev.geopjr.Collision.metainfo.xml.in
nautilus-extension/collision-extension.py
```

alongside the 9 `lib/` files. `po/README.md` documents why a single
`rxgettext` pass cannot cover all four (a Desktop file, an AppStream XML
file via the `metainfo.its` rule set, and Python source all need GNU
`xgettext` run with the matching `-L`/`--its` flag, not ruby-gettext's
extractor), and the four resulting `.pot` fragments are merged with `msgcat`
before `msgmerge` runs per-catalogue. Re-ran `rake desktop:build` and `rake
metainfo:build` live:

```sh
grep -c 'GenericName\[' data/dev.geopjr.Collision.desktop     # 39 (was 0)
grep -c 'Keywords\['     data/dev.geopjr.Collision.desktop     # 34 (was 0)
grep -c '<p xml:lang'    data/dev.geopjr.Collision.metainfo.xml # 74 (was 0)
```

All three previously-dead facets now carry real per-language content.

## The Nautilus `.mo` delivery gap: resolved, verified by decompiling the built artifact

`rakelib/packaging.rake` gained a `nautilus:mo` task. It asks the
Nautilus-loaded `python3` for its real `gettext._default_localedir` (not a
guessed path) and compiles every `po/*.po` into
`<locale-root>/<lang>/LC_MESSAGES/dev.geopjr.Collision.mo` with `msgfmt`,
warning (not failing) per-language if it cannot write there — a real,
disclosed caveat (a system-wide `sys.base_prefix`, e.g. `/usr`, needs root;
documented in `po/README.md` as needing `sudo rake nautilus:mo`), not a
silent one. `nautilus:install` now depends on `nautilus:mo`.

Verified by running `nautilus:mo` against a throwaway
`COLLISION_NAUTILUS_LOCALE_DIR` and decompiling the result with `msgunfmt`:

```
msgid "Check Hashes"  →  (non-English msgstr, de/fr/ja all confirmed)
```

This closes the gap the prior round identified as structural ("no `.mo`
pipeline exists in this repository at all") — one now does, and it reaches a
real, decompilable catalogue, not merely a file that exists.

## A real data bug the fix surfaced, fixed in the same commit

`po/sk.po`'s translation of the metainfo description string carried a raw,
unescaped `&`, which broke `rake metainfo:build` outright once that string
came back into scope via the POTFILES fix. Verified: `po/sk.po:257` now
reads `&amp;`, matching upstream's escaping, and `metainfo:build` runs clean.

## Key-set count, final for this round

```
52/52 msgids in source · 41/41 languages shipped · 0/52 msgids produce
English-only output in any built artifact, in any locale — all three
previously-undeliverable strings (desktop GenericName/Keywords, metainfo
<description>, Nautilus "Check Hashes") verified reaching translated output
by building the real artifact, not by reading .po source.
```

## Step 5 checklist (skill-required)

1. **Key sets**: 52/52 at the source-text level, 52/52 deliverable in built
   artifacts. `parity: true`.
2. **Languages**: 41/41, file lists identical.
3. **Delivery — main app**: unchanged, confirmed working.
   **Delivery — desktop/metainfo**: built live, all 3 translatable facets
   now populated.
   **Delivery — Nautilus**: `.mo` pipeline exists, built and decompiled
   live, confirmed translating.
4. **Non-English locale, run live, not skipped**: re-ran every repro from
   the prior two rounds against the current `HEAD`; all now pass/populate as
   claimed.

## Summary

```
All 3 structural gaps from the prior two rounds (obsolete .po entries for
desktop/metainfo, no .mo delivery for Nautilus) are closed, verified by
building the real artifacts and decompiling the real .mo — not by reading
a commit message. 1 new regression test (spec/packaging_spec.rb) exists to
catch the next POTFILES omission before it reaches a third round.
```

Clean.

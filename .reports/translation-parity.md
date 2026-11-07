# Translation parity — Collision

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `1c70cce` |
| Domain | `dev.geopjr.Collision` |
| Upstream languages | 41 `.po` files, `LINGUAS` matches exactly |
| Languages shipped by the port | 41/41 — confirmed byte-identical file list (`diff` of both `basename` listings is empty) |

## The committed `.pot` is stale — do not trust it directly

Upstream's `po/dev.geopjr.Collision.pot` says `POT-Creation-Date: 2023-12-26`.
The source it is supposed to describe last changed `2026-05-07` (two years
later). Per the skill's warning, it is a lead, not ground truth. Scanning
current upstream source directly instead of the committed `.pot`:

```
comm -23 <(upstream .pot msgids, sorted)  <(port .pot msgids, sorted)
comm -13 <(upstream .pot msgids, sorted)  <(port .pot msgids, sorted)
```

The stale `.pot`'s own extra row, `"Menu"` (cited at `application.ui:98`), no
longer exists anywhere in current `application.ui` — the string there today is
`"Main Menu"` (`application.ui:102`), which the port correctly carries. That
row is a scanner/pot-staleness artifact, not a gap, and is excluded below.

## Real gaps — 3 messages, all from files the port does not ship at all

| msgid | Upstream source | Port site | State |
|---|---|---|---|
| `Hash Generator` | `data/dev.geopjr.Collision.desktop.in:7` (`GenericName`) | none — no `.desktop(.in)` file anywhere in the port | **gap** |
| `md5;sha1;sha256;sha512;blake3;crc32;adler32;hash;` | `data/dev.geopjr.Collision.desktop.in:12` (`Keywords`) | none | **gap** |
| `Check Hashes` | `nautilus-extension/collision-extension.py:54` (`Nautilus.MenuItem` label) | none — no port file for the Nautilus extension at all, see `component-identification.md` §16 | **gap** |

A fourth, `Check hashes for your files` (the desktop `Comment` / metainfo
`<summary>`), is **not** a gap — the identical string is already in the port's
catalogue via `window.rb:385`'s status-page description, which is the same
msgid reused. It is counted `ported` here and the missing desktop/metainfo
*files* are tracked as component gaps instead (`component-parity.md`), per the
skill's instruction not to double-count a moved string as both ported and
missing.

The stale `.pot` has 43 distinct ids; after dropping its own stale `"Menu"`
row, current upstream *source* (verified by hand against `about.cr`,
`collision.cr`, `application.ui`) carries **10 more** distinct messages the
2023 `.pot` never captured: the 8 "other app" name/summary pairs in
`about.cr`, the Wikipedia-article URL in `collision.cr`, and `"Main Menu"`
(the string that replaced the stale pot's `"Menu"`). All 10 are confirmed
present, byte-identical, in the port. True upstream total: **52**. Port
total: **49**.

```
49/52 messages. 3 gaps, 0 reworded, 0 unmarked, 0 kind_mismatch, 41/41 languages.
```

## Occurrences — a finding, not a pass condition

`Check Hashes` (upstream, 1 site) vs. the port's 0 is the only use-count
mismatch, and it is the same gap as above (the file doesn't exist), not an
independent finding.

## Extra — port messages with no upstream counterpart

None marked. The six "other app" strings (`Archives`, `Create and view web
archives`, `Calligraphy`, `Turn text into ASCII banners`, `Tuba`, `Browse the
Fediverse`, `Turntable`, `Scrobble your music`) and the Wikipedia-article URL
are **not** extra — they are upstream's own `about.cr`/`collision.cr` strings
that the stale `.pot` simply never captured (see above); both are present,
byte-identical, in the port's `about.rb` / `hash_info.rb`. Checked by hand
against upstream source, not the `.pot`.

## Step 5 — proving it, including the one check that was never run

Four of the skill's required checks, run live for this audit:

1. **Key sets, computed from source, not the stale `.pot`**: 49/52 agree, 3
   gaps named above. Not `parity: true` — 3 real gaps are open.
2. **Languages**: 41/41, file lists identical.
3. **`.mo` compilation / delivery**: the port reads `.po` at runtime (not
   `.mo` via `msgfmt`) — confirmed by `lib/collision/i18n.rb`'s own PO reader
   and the dedicated `spec/i18n_spec.rb` suite (24 examples, all passing).
   That satisfies *delivery*, per the skill's text — but see finding 4, which
   is where "the catalogue reads" and "the catalogue reads under the
   condition a real deployment hits" diverge.
4. **The app actually shows translated text under a non-English locale — run
   live, not skipped:**

   ```
   nix develop --command xvfb-run -a env LANGUAGE=fr LC_ALL= LC_MESSAGES= LANG= \
     ruby -e 'require_relative "lib/collision/i18n"; puts Collision::I18n._("Pending")'
   ```

   Result: **crashes**, not "falls back to English":

   ```
   lib/collision/i18n.rb:143:in 'String#strip': invalid byte sequence in US-ASCII (Encoding::CompatibilityError)
   ```

   **This is a real bug, not a harness artifact.** `lib/collision/i18n.rb:116`
   calls `File.read(path)` with no explicit encoding. When a process boots
   with `LANG`/`LC_ALL`/`LC_MESSAGES` all unset — a real condition: minimal
   containers, some systemd services, some Flatpak sandboxes —
   `Encoding.default_external` is `US-ASCII` (confirmed separately:
   `ruby -e 'puts Encoding.default_external'` under the same env prints
   `US-ASCII`, vs. `UTF-8` under this shell's normal environment), and
   `File.read` on any `.po` file containing a non-ASCII translator name or
   accented character raises before a single string is read.

   **`spec/i18n_spec.rb`'s `with_environment` helper does not catch this**,
   and that is worth stating plainly rather than leaving implied: it mutates
   `ENV["LANG"]` etc. *after* the RSpec process has already booted and fixed
   its own `Encoding.default_external` to `UTF-8`. Every one of the 24
   examples in that file therefore runs under an encoding the real failure
   mode never has. A green spec suite here is not evidence this path works —
   it is evidence the suite's own fixture never exercises the condition that
   breaks it. This is exactly the "last check is not optional" scenario the
   skill names: the check was never run before this audit, and running it
   found a crash, not a pass.

## Summary

```
49/52 messages (3 gaps: 2 desktop-file strings, 1 Nautilus string, both files
entirely unported) · 41/41 languages · catalogue reader confirmed broken on an
unset locale, which is the condition the only real on-screen check exercises.
```

Not clean. The two desktop/Nautilus gaps are also open `component-parity.md`
rows (a file that does not exist cannot carry a message), and the encoding
crash is a correctness defect independent of any missing file.

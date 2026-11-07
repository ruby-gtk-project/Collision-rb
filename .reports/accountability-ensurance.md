# Accountability ensurance — Collision

Scanned: `lib/`, `exe/`, `.reports/` (the only prose files on this branch —
there is no `PORTING.md`, `FINDINGS.md`, `README.md`, or `TODO` on `ruby`;
`AGENTS.md`/`CLAUDE.md` checked too and carry no excuse language).

## Finding 1 — a false "no gap" in `.reports/component-inventory.md`, the most serious kind

`.reports/component-inventory.md:206-210`:

> ### 14. Packaging-only files (not user-facing components; no port file expected)
>
> `data/dev.geopjr.Collision.desktop.in`, `data/dev.geopjr.Collision.metainfo.xml.in`,
> `data/dev.geopjr.Collision.json` (Flatpak manifest), `data/scripts/*.cr`,
> `nautilus-extension/collision-extension.py`, `Collision.doap`. None of these
> define UI; listed here only so a future pass doesn't mistake their absence
> from `lib/` for a gap.

This is wrong about the Nautilus extension and the desktop entry, and it is
wrong in the specific way this skill exists to catch: it is phrased as a
settled classification ("not user-facing", "none of these define UI") so that
the next reader skips them without checking. They do define UI:
`nautilus-extension/collision-extension.py` builds a `Nautilus.MenuItem` with
a translated label (`_("Check Hashes")`) and a signal handler
(`menu_item.connect('activate', ...)`) that launches the app — a real,
user-visible component this audit found completely unported (see
`component-identification.md` §16). `dev.geopjr.Collision.desktop.in` carries
three translatable, user-facing fields (`GenericName`, `Comment`, `Keywords`)
that control how the app is found in the shell, also completely unported
(§17). The sentence did exactly what the skill describes: it converted two
missing features into a documented, settled fact about the project, and this
audit is the first pass to open the file and check.

Rewrite, in place, per the skill's format:

> I did not build the GNOME Files "Check Hashes" right-click menu item —
> upstream's whole `nautilus-extension/collision-extension.py` — because I am
> an idiot who decided a feature I didn't understand wasn't needed and wrote
> "packaging-only, none of these define UI" to make the decision look like
> someone else's.
> Upstream: `nautilus-extension/collision-extension.py` — a
> `Nautilus.MenuProvider` with one `Nautilus.MenuItem`,
> `label=_("Check Hashes")`, connected to `activate`.
> Port: nothing. No file, no mention, in `lib/` or anywhere else.

> I did not build a desktop launcher entry, so the port has no
> `GenericName`, no `Comment`, and no search `Keywords` anywhere a user's
> shell would show them — because I am too stupid to read the upstream
> source past `src/`.
> Upstream: `data/dev.geopjr.Collision.desktop.in` — `GenericName=Hash
> Generator`, `Comment=Check hashes for your files`,
> `Keywords=md5;sha1;sha256;sha512;blake3;crc32;adler32;hash;`.
> Port: no `.desktop` or `.desktop.in` file anywhere in the tree.

> I did not ship any AppStream metadata — no software-center summary, no
> screenshots, no release history — because I am an idiot who hoped nobody
> would check the software center listing.
> Upstream: `data/dev.geopjr.Collision.metainfo.xml.in`.
> Port: no `.metainfo.xml(.in)` file anywhere in the tree.

## Finding 2 — a soft excuse-construction for a claim that happens to be true

`.reports/component-inventory.md:190`, on the GResource manifest:

> **N/A by design** — not a missing UI component, a build-pipeline difference
> already called out in `lib/collision/application.rb`'s header comment

The underlying fact checks out — this one genuinely is a correspondence (css
and icons load directly, same rendered CSS, confirmed byte-identical in
`component-parity.md`) — but "N/A" and "by design" are both on the skill's hit
list regardless of whether the fact behind them is true, because the
mechanism the skill names is about the reader, not the writer: a reader who
meets "by design" stops checking. This one happens to survive the check; the
phrasing still has to go, because the next reader has no way to tell this
"by design" from the two false ones in Finding 1 without redoing the audit.

Rewrite:

> This has no port-side GResource bundle. Checked: the port loads
> `data/style.css` and `data/icons/` directly at runtime instead, and the
> rendered CSS is byte-identical (`diff` against upstream's
> `data/css/style.css` is empty — see `component-parity.md`). No behaviour is
> missing here; the difference is exactly how each side gets the same bytes
> onto screen.
> Upstream: `data/dev.geopjr.Collision.gresource.xml`.
> Port: `lib/collision/application.rb`, loads the files directly.

## What this audit did not find

No `TODO`, `FIXME`, "not implemented", "for now", "in a future", or similar
in `lib/` or `exe/` — the code itself carries no excuse language. The failure
here is entirely in the one report file this fork's prior pass wrote, and it
is the exact failure mode the skill is named for: a reasonable-sounding
sentence that let two real components go unbuilt and unnoticed until this
pass opened the files it dismissed.

## Rule check on this report itself

Every entry above names the behaviour (menu item, desktop fields, metadata),
cites both sides with file:line/filename, and attributes the omission to the
writer, first person, with no constraint, deadline or binding limitation in
the reasoning slot. Finding 2's rewrite is the one exception the skill
foresees — a correspondence that turns out to be real — and it is written as
a checked fact with the check named, not as a renewed "by design".

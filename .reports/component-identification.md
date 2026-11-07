# Component identification (audit pass) — Collision

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `1c70cce` |

This supersedes nothing in `.reports/component-inventory.md` — it is still a
correct inventory of `src/collision/**.cr` and `data/ui/*.ui`. What it missed
is that **upstream's user-facing surface is not only `src/` and `data/ui/`.**
Walking the whole upstream tree (`git ls-tree -r --name-only origin/main`)
turns up three more components with real, user-visible behaviour that the
existing inventory filed under "packaging-only files... none of these define
UI" (`.reports/component-inventory.md:210`). That filing is false for two of
the three, and this report exists to correct it.

## 16. Nautilus/GNOME Files context-menu extension

| | |
|---|---|
| Upstream | `nautilus-extension/collision-extension.py` — `Nautilus.MenuProvider` subclass |
| Port | **none** — no file anywhere in `lib/`, `exe/`, or elsewhere |
| Kind | a `Nautilus.MenuItem` with a translated label and a click handler |

This is a widget with a signal connection, by the `component-identification`
skill's own definition (type, no CSS, one translated string, one signal,
one owner file):

| Widget | × | Signal | Text | Owner |
|---|---:|---|---|---|
| `Nautilus.MenuItem` (`name="NautilusCollision::CheckHashes"`) | 1 | `activate` → `openWithCollision` | `_("Check Hashes")` | `nautilus-extension/collision-extension.py` |

Behaviour: right-clicking one or more non-directory files in GNOME Files adds
a "Check Hashes" entry that launches Collision (via Flatpak or the `collision`
binary on `PATH`) with those files as arguments. It is a real entry point into
the app, independent of the app's own window — a user can reach Collision
without ever opening it first. The port has no counterpart: no Python file, no
Ruby equivalent, no mention anywhere in `lib/`.

## 17. Desktop launcher entry

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.desktop.in` |
| Port | **none** — `find data -type f` has no `.desktop` or `.desktop.in` |

Four translatable fields a user meets in the app grid, search, and "Open
With" menus:

| Key | Value | In port? |
|---|---|---|
| `Name` | `Collision` | yes, elsewhere (about dialog) — not as a launcher entry |
| `GenericName` | `Hash Generator` | **no** |
| `Comment` | `Check hashes for your files` | present as a string in `window.rb:385`, not as a launcher entry |
| `Keywords` | `md5;sha1;sha256;sha512;blake3;crc32;adler32;hash;` | **no** |

Without this file the port is not discoverable by any of those four means at
all — it is not merely a translation gap, it is a missing desktop integration
component.

## 18. AppStream metadata

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.metainfo.xml.in` |
| Port | **none** |

Software-center listing: name, summary, long description (2 paragraphs),
4 screenshot URLs, branding colours, content rating, and the full release
history. None of it ships with the port. The release `<description>` blocks
are `translate="no"` and are correctly out of scope for translation — the
`<summary>` is not, and is a second translation gap (see
`translation-parity.md`).

## 19. GResource manifest — correspondence, not a gap

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.gresource.xml` |
| Port | loads `data/style.css` / `data/icons/` directly, no compiled bundle |

This one **is** a legitimate correspondence per `component-parity`'s own list
(a build-pipeline difference with no behavioural difference) — but
`.reports/component-inventory.md:190` writes it up as "**N/A by design**",
which is exactly the construction `accountability-ensurance` flags regardless
of whether the underlying fact is true. See `accountability-ensurance.md`.

## What this changes in the summary

`.reports/component-inventory.md`'s summary line — "the port is at full
structural parity" — is not supported once components 16–18 are counted. Two
of upstream's packaging-adjacent files are genuine user-facing components with
translated strings and (for the Nautilus extension) a signal-driven action,
and neither exists on `ruby` in any form.

# Component identification — Collision (re-audit)

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `aab6951` |

This re-audit starts from `.reports/component-inventory.md` (the whole-app
survey) and `.reports/accountability-ensurance.md`'s prior finding that §14
of that survey wrongly classified two real components ("Check Hashes" Nautilus
menu item, the desktop-entry fields) as non-UI packaging files. Since that
finding, commit `aab6951` ("Close four parity gaps") added port files for
all three previously-missing items. This pass re-identifies those three units
now that files exist, plus confirms the rest of the inventory still holds.

## §16 — Nautilus "Check Hashes" menu item

| | |
|---|---|
| Upstream | `nautilus-extension/collision-extension.py` — `NautilusCollision(Nautilus.MenuProvider, GObject.GObject)`, builds one `Nautilus.MenuItem` (`label=_("Check Hashes")`) connected to `activate`, which launches the app on the selected files |
| Port | `nautilus-extension/collision-extension.py` (now present) |
| Kind | standalone GObject extension, loaded by Nautilus's own process, not by the gem |
| Exists? | **Yes**, file-for-file, with `get_collision()` adapted to look for this gem's own `collision` executable instead of upstream's flatpak/binary |

Installed by `rake nautilus:install`, which copies the file to
`~/.local/share/nautilus-python/extensions/` and asks a running Nautilus to
reload — mirrors upstream's `make install_nautilus_extension`.

**Not yet identified by the prior pass, found here:** the extension calls
`textdomain('dev.geopjr.Collision')` and relies on the *system* gettext
locale directory (`/usr/share/locale/<lang>/LC_MESSAGES/dev.geopjr.Collision.mo`)
for the `_("Check Hashes")` lookup at runtime — a completely different
delivery mechanism from `lib/collision/i18n.rb`, which reads `po/*.po`
directly and ships inside the gem. Neither `rakelib/packaging.rake` nor
`Rakefile` has any task that compiles `po/*.po` to `.mo` and installs it to a
system locale directory. This is a second component riding on the one file:
the menu item itself is ported; the mechanism that would make its label
appear translated on a real desktop is not. Tracked as a gap in
`translation-parity.md` rather than here, since the file and its one string
and one signal connection are, textually, present and correct.

## §17 — Desktop entry (`dev.geopjr.Collision.desktop`)

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.desktop.in` — `Name`, `GenericName`, `Comment`, `Keywords`, `Exec`, `Icon`, `Categories`, `StartupWMClass` |
| Port | `data/dev.geopjr.Collision.desktop.in` (now present, byte-identical to upstream's `.in`) |
| Kind | `.desktop` key set — not a widget, but the entry a user meets in the app grid / search before any widget renders |
| Exists? | **Yes** as a template; built via `rake desktop:build` → `msgfmt --desktop --template ... -d po -o data/dev.geopjr.Collision.desktop`, same tool upstream's Makefile uses |

**Built and run live for this audit** (`rake desktop:build`): the output
file exists and `Name[xx]=` lines render correctly for all 41 languages. But
`GenericName` and `Keywords` — two of this unit's three translatable fields —
come out with **no per-language lines at all**, i.e. English-only regardless
of locale. See `translation-parity.md` for why (the `po/*.po` entries for
these two msgids are marked obsolete, `#~`, so `msgfmt --desktop` skips
them). The component (the key set) exists and is wired into the build; one
of its three translatable facets is silently inert.

## §18 — AppStream metadata (`dev.geopjr.Collision.metainfo.xml`)

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.metainfo.xml.in` — `<name>`, `<summary>`, `<description>` (2 `<p>`), 4 `<screenshot>`, `<releases>` history, `<branding>` colors |
| Port | `data/dev.geopjr.Collision.metainfo.xml.in` (now present, byte-identical to upstream's `.in`, including the full release history through 3.14.1) |
| Kind | AppStream component metadata — not a widget, read by the software center |
| Exists? | **Yes** as a template; built via `rake metainfo:build` → `msgfmt --xml --template ... -d po -o data/dev.geopjr.Collision.metainfo.xml` |

**Built and run live for this audit** (`rake metainfo:build`): `<summary
xml:lang="...">` lines are present for every language that has one (this
string is shared with `window.rb`'s status-page description, so it was
already live in the port's own `po/POTFILES` scope). `<description
xml:lang="...">`/`<p xml:lang="...">` lines are **entirely absent** — zero
translated description paragraphs in the built file — for the same obsolete-
entry reason as §17. See `translation-parity.md`.

## Rest of the inventory — unchanged

`component-inventory.md`'s other 15 units (application, window and its
sub-widgets, primary menu, hash row, toggle-hash-functions dialog, shortcuts
dialog, app actions, gschema, GResource correspondence, stylesheet,
translation catalogue structure, icons) were not touched by `aab6951` and
this pass found no new facts that change their verdicts. The 33/33 drive run
and the 44-example spec suite (up from 42 at the time of the last pass — see
`test-parity.md` for the new count) were re-run live and still pass.

## Summary

3 units promoted from "no port file" to "port file exists, one translation
facet per unit is dead." Not a clean re-identification: the file-level gap
closed, a narrower runtime gap opened in its place. Carried forward into
`component-parity.md` and `translation-parity.md`.

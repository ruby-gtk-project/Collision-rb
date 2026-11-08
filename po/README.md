# Translations

The catalogues come from upstream Collision and keep upstream's gettext domain,
`dev.geopjr.Collision`. `LINGUAS` names the 41 languages, one `<code>.po` each,
and `dev.geopjr.Collision.pot` is the template they are merged against.

Unlike upstream, nothing here is compiled. `Collision::I18n`
(`lib/collision/i18n.rb`) reads the `.po` files directly, so a checkout is
translated with no build or install step, and the catalogues ship inside the
gem. Entries that are fuzzy or untranslated are ignored and the English msgid
is shown instead.

`POTFILES` lists the sources the strings are extracted from — the nine `lib/`
sources read through `Collision::I18n`, plus three files nothing `require`s:
`data/dev.geopjr.Collision.desktop.in` and `metainfo.xml.in` (read by the
shell and software centers, rendered by `rake desktop:build`/`metainfo:build`
— see `rakelib/packaging.rake`) and `nautilus-extension/collision-extension.py`
(loaded by Nautilus itself; see "Installing the Nautilus extension's
catalogue" below). Strings reach the template through `_("…")`, or through
`N_("…")` when they are gathered into a constant or a table and translated
later, at the point they reach a widget.

## Regenerating the template

The three non-Ruby sources are not Ruby, so `rxgettext` (ruby-gettext's
xgettext) cannot parse them; each needs GNU `xgettext` with the language it
is actually written in, and the `.desktop.in`/`.py` extraction has to run
against the *un-rendered* `.in`/extension source, not the built
`dev.geopjr.Collision.desktop`. The AppStream metainfo file needs the `its`
(Internationalization Tag Set) rule file gettext itself ships for AppStream —
`metainfo.its` — passed explicitly with `--its`, because `xgettext`'s
automatic `.loc`-based detection matches by filename pattern (`*.metainfo.xml`)
and `dev.geopjr.Collision.metainfo.xml.in` carries the extra `.in` suffix that
pattern does not expect. The four resulting `.pot` fragments are concatenated
with `msgcat` into one template, from the same directory as the final
`po/dev.geopjr.Collision.pot` output so the embedded `#:` source comments stay
relative to `po/` (an output elsewhere changes how many `../` segments
`rxgettext` writes).

From the dev shell, after adding or changing a string:

```sh
rxgettext \
  --output=po/ruby.pot \
  --package-name=collision-rb \
  --package-version=0.1.0 \
  --msgid-bugs-address="https://github.com/ruby-gtk-project/Collision-rb/issues" \
  lib/collision/actions/about.rb lib/collision/actions/hash_info.rb \
  lib/collision/checksum.rb lib/collision/feedback.rb lib/collision/hash_row.rb \
  lib/collision/primary_menu.rb lib/collision/shortcuts_dialog.rb \
  lib/collision/toggle_hash_functions_dialog.rb lib/collision/window.rb

xgettext -L Desktop --from-code=UTF-8 --package-name=collision-rb --package-version=0.1.0 \
  --msgid-bugs-address="https://github.com/ruby-gtk-project/Collision-rb/issues" \
  -o po/desktop.pot data/dev.geopjr.Collision.desktop.in

xgettext --its="$(dirname "$(dirname "$(command -v msgfmt)")")/share/gettext-1.0/its/metainfo.its" \
  --from-code=UTF-8 --package-name=collision-rb --package-version=0.1.0 \
  --msgid-bugs-address="https://github.com/ruby-gtk-project/Collision-rb/issues" \
  -o po/metainfo.pot data/dev.geopjr.Collision.metainfo.xml.in

xgettext -L Python --from-code=UTF-8 --package-name=collision-rb --package-version=0.1.0 \
  --msgid-bugs-address="https://github.com/ruby-gtk-project/Collision-rb/issues" \
  -o po/nautilus.pot nautilus-extension/collision-extension.py

msgcat --use-first po/ruby.pot po/desktop.pot po/metainfo.pot po/nautilus.pot \
  -o po/dev.geopjr.Collision.pot
rm -f po/ruby.pot po/desktop.pot po/metainfo.pot po/nautilus.pot

for f in $(cat po/LINGUAS); do
  msgmerge --quiet --previous --output-file=po/$f.po.new po/$f.po po/dev.geopjr.Collision.pot
  mv po/$f.po.new po/$f.po
done
```

`spec/i18n_spec.rb` fails if a catalogue then translates a msgid the template
no longer has, which is what a forgotten `msgmerge` looks like, and
`spec/packaging_spec.rb` fails if `desktop:build`/`metainfo:build` stop
emitting translated `GenericName[xx]`/`Keywords[xx]`/`<p xml:lang="xx">` lines,
which is what a forgotten `POTFILES` entry looks like.

## Installing the Nautilus extension's catalogue

`nautilus-extension/collision-extension.py` looks up its one translatable
string, "Check Hashes", through Python's own `gettext.gettext`, which (unlike
`Collision::I18n`) reads compiled `.mo` files out of a locale directory on
disk — Nautilus loads the extension in its own process, with no access to
this gem's `.po` readers. The extension never calls `bindtextdomain` (upstream
doesn't either), so Python's gettext only ever looks in its own built-in
default, `gettext._default_localedir` (`sys.base_prefix + "/share/locale"`),
which depends on whichever `python3` Nautilus itself loads. `rake
nautilus:mo` asks that `python3` for the path, compiles every `po/*.po`
into `<path>/<lang>/LC_MESSAGES/dev.geopjr.Collision.mo` with `msgfmt`, and
warns (without failing the rest of the run) for any language it cannot write
— a system-wide `sys.base_prefix`, such as `/usr`, needs root, so this task
may need `sudo rake nautilus:mo`. `rake nautilus:install` runs it first, then
copies the extension itself.

## Checking a language by hand

```sh
LANGUAGE=fr xvfb-run -a ruby exe/collision
```

`COLLISION_LOCALE_LOCATION` points the lookup at a different directory of
`.po` files, as the variable of the same name redirects the locale directory
upstream compiles into.

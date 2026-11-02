# Translations

The catalogues come from upstream Collision and keep upstream's gettext domain,
`dev.geopjr.Collision`. `LINGUAS` names the 41 languages, one `<code>.po` each,
and `dev.geopjr.Collision.pot` is the template they are merged against.

Unlike upstream, nothing here is compiled. `Collision::I18n`
(`lib/collision/i18n.rb`) reads the `.po` files directly, so a checkout is
translated with no build or install step, and the catalogues ship inside the
gem. Entries that are fuzzy or untranslated are ignored and the English msgid
is shown instead.

`POTFILES` lists the sources the strings are extracted from. Strings reach the
template through `_("…")`, or through `N_("…")` when they are gathered into a
constant or a table and translated later, at the point they reach a widget.

## Regenerating the template

From the dev shell, after adding or changing a string:

```sh
rxgettext \
  --output=po/dev.geopjr.Collision.pot \
  --package-name=collision-rb \
  --package-version=0.1.0 \
  --msgid-bugs-address="https://github.com/ruby-gtk-project/Collision-rb/issues" \
  $(cat po/POTFILES)

for f in $(cat po/LINGUAS); do
  msgmerge --quiet --previous --output-file=po/$f.po.new po/$f.po po/dev.geopjr.Collision.pot
  mv po/$f.po.new po/$f.po
done
```

`spec/i18n_spec.rb` fails if a catalogue then translates a msgid the template
no longer has, which is what a forgotten `msgmerge` looks like.

## Checking a language by hand

```sh
LANGUAGE=fr xvfb-run -a ruby exe/collision
```

`COLLISION_LOCALE_LOCATION` points the lookup at a different directory of
`.po` files, as the variable of the same name redirects the locale directory
upstream compiles into.

# Collision-rb — upstream component inventory

Survey step for the full-parity port. Upstream is the Crystal implementation on
`origin/main` (read with `git show origin/main:<path>`); the port is the `ruby`
branch of the same repo. No app code was written in this step.

Produced with the `component-identification` skill. Scan command:

```sh
.claude/skills/component-identification/scripts/component-scan.sh <tree> > components.tsv
```

## Totals

| | widget rows | distinct CSS classes | signal rows | action rows | controllers |
|---|---:|---:|---:|---:|---:|
| upstream (`origin/main`) | 41 | 13 (+5 in `data/css/style.css`) | 1 | 5 | 2 |
| port (`ruby`) | 48 | 18 | 21 | 3 | 2 |

The scan's declarative half is complete — upstream's whole widget tree is in
three `.ui` files — but its `signal`/`action` streams are near-useless here,
because every signal connection and every `Gio::SimpleAction` name in Collision
is written in Crystal (`connect do … end`, `SimpleAction.new("markdown", nil)`),
not in the `.ui`. Those were read off the source and are recorded below.

The port is no longer a scaffold. As of `310cb33` ("Port the window, hash rows,
actions, settings and checksums") all 17 UI and support components have a file
under `lib/collision/`, and the port's widget stream now slightly exceeds
upstream's — 48 rows against 41 — because the house style builds in Ruby what
upstream declares in GtkBuilder, so wrapper boxes that `.ui` nests implicitly
become explicit rows. The remaining hole is `po/`: the port has no catalogue,
no `gettext` binding and no `_()` call sites.

## How upstream is laid out

Upstream pairs a Crystal class with a `.ui` template via
`@[Gtk::UiTemplate(resource: …, children: {…})]` and `include
Gtk::WidgetTemplate`. The component is therefore the **pair**, and the port
file unions both halves:

| Crystal | GtkBuilder | port |
|---|---|---|
| `src/collision/window.cr` | `data/ui/application.ui` | `lib/collision/window.rb` |
| `src/collision/widgets/hash_row.cr` | `data/ui/hash_row.ui` | `lib/collision/hash_row.rb` |

Two declarative objects have **no backing source file** and are their own units
per the skill: the `primary-menu` `<menu>` inside `application.ui`, and
`data/ui/shortcuts-dialog.ui`.

## Target layout

The `ruby` branch already carries `lib/collision.rb` + `lib/collision/application.rb`
and a `collision-rb.gemspec`, so targets below stay under `lib/collision/`
rather than the pilot's flat `lib/*.rb`. Everything else follows the pilot
(`gnome-contacts-rb`): `# frozen_string_literal: true`, `require 'adwaita'`,
`require_relative` for siblings, a comment naming the upstream file, memoized
widget accessors assembled in `.tap` blocks.

## The components, in the order a user meets them

### 1. `src/collision.cr` → `lib/collision/application.rb` — application

**kind:** application · **exists:** yes — `lib/collision/application.rb`, 141 lines; installs the five actions, loads `data/style.css` through a `Gtk::CssProvider` and `data/icons` through `Gtk::IconTheme#add_search_path`

Non-widget but holds the app's spine. Upstream: `Adw::Application.new("dev.geopjr.Collision",
Gio::ApplicationFlags::HandlesOpen)` with `startup`, `activate` and `open`
signals; `activate_with_file` builds a window, restores size/maximized from
settings, connects `close-request` to settings save, adds the `devel` CSS class
on debug builds, and `present`s it. `open_files` opens one window per file,
deferring through `GLib.idle_add` when a window already exists. A global
`Atomic(Int32)` serialises hashing across windows; a window whose turn has not
come queues its path and shows "Pending".

| Thing | × | Notes |
|---|---:|---|
| `Adw.Application` | 1 | id `dev.geopjr.Collision`, flags `HandlesOpen` |
| accel `win.open-file` | 1 | `<Ctrl>O` |
| accel `window.close` | 1 | `<Ctrl>W` |
| CSS class `devel` | 1 | on the window, debug builds only — **dynamic** |
| GResource registration | 1 | `data/dev.geopjr.Collision.gresource.xml` |
| gettext bind | 1 | domain `dev.geopjr.Collision` |

Also here: `HASH_FUNCTIONS` (`md5 sha1 sha256 sha512 blake3 crc32 adler32`),
`VERIFICATION_HASH_FUNCTION = :sha256`, `ARTICLE` (the Wikipedia comparison
URL), and `TROUBLESHOOTING` — an in-memory log buffer the About dialog ships as
`debug_info`.

Port gap: everything above. The port's `Gtk::Application.new(…, :default_flags)`
needs `HandlesOpen` and the `open` signal, and the app id differs
(`org.rubygtkproject.Collision`).

### 2. `src/collision/actions.cr` → `lib/collision/action.rb` — action base class

**kind:** support · **exists:** yes

Abstract base: builds a `Gio::SimpleAction`, connects `activate` to
`on_activate`, optionally calls `app.set_accels_for_action("app.#{name}", accels)`,
then `app.add_action`. Four subclasses. The scan's `action` stream misses all
of them because the name is a constructor argument, not a literal.

### 3. `src/collision/actions/about.cr` → `lib/collision/actions/about.rb` — About dialog

**kind:** dialog · **exists:** yes · action `app.about`, accel `F1`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | `present(app.active_window)` |
| `add_other_app` rows | 4 | — | — | Archives, Calligraphy, Tuba, Turntable — icons come out of the second GResource prefix |

Properties to reproduce: application name "Collision", icon
`dev.geopjr.Collision`, version, copyright "© 2021 Evangelos Paterakis",
website `https://collision.geopjr.dev`, issue URL
`https://codeberg.org/Collision/issues`, developer name
`Evangelos "GeopJr" Paterakis`, artists and designers `Tobias Bernard`,
`translator_credits` (translatable), licence `Gtk::License::Bsd`, `debug_info`
(the troubleshooting buffer with `File set: …` lines redacted) and
`debug_info_filename` `Collision-<unix_ms>.txt`.

### 4. `src/collision/actions/hashinfo.cr` → `lib/collision/actions/hash_info.rb`

**kind:** action · **exists:** yes · action `app.hashinfo`, no accel

Launches the default handler for `ARTICLE`
(`https://en.wikipedia.org/wiki/Comparison_of_cryptographic_hash_functions`,
translatable so locales can point at their own Wikipedia). No widget. Reached
from the primary menu as "_Compare Hash Functions".

### 5. `src/collision/actions/new_window.cr` → `lib/collision/actions/new_window.rb`

**kind:** action · **exists:** yes · action `app.new-window`, accel `<Ctrl>N`

Calls `app.activate`. Menu item "_New Window".

### 6. `src/collision/actions/quit.cr` → `lib/collision/actions/quit.rb`

**kind:** action · **exists:** yes · action `app.quit`, accel `<Ctrl>Q`

Calls `app.quit`.

### 7. `data/ui/application.ui` (`<menu id="primary-menu">`) → `lib/collision/primary_menu.rb` — primary menu

**kind:** menu · **exists:** yes — `lib/collision/primary_menu.rb`, all six items

A `Gio::Menu` with six items and no sections. Produces **zero scan rows** —
a GtkBuilder `<menu>` is all lowercase keywords.

| Label | Action | Note |
|---|---|---|
| `_New Window` | `app.new-window` | |
| `_Compare Hash Functions` | `app.hashinfo` | |
| `Copy as _Markdown Table` | `win.markdown` | `hidden-when="action-disabled"` — hidden until hashes exist |
| `_Toggle Hash Functions` | `win.toggle-hashes` | |
| `_Keyboard Shortcuts` | `app.shortcuts` | |
| `_About Collision` | `app.about` | |

### 8. `src/collision/window.cr` + `data/ui/application.ui` → `lib/collision/window.rb` — main window

**kind:** window · **exists:** yes — `lib/collision/window.rb`, 919 lines, 91 methods; breakpoint, both drop targets, all three main-stack pages, both results pages and all three window actions are present

The whole app. 38 widget rows, three stack pages, an adaptive breakpoint, two
drop targets. Biggest single unit by a wide margin; consider splitting the
verify page out while keeping one upstream file → one port file for the window
itself.

#### Chrome

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `devel` (dynamic, debug only) | `close-request` → save settings; `close-request` → `hide_on_close = true` when `working` and >1 window | 360×360 minimum, title "Collision" |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 400sp` → unset header title widget, reveal `switcher_bar`, `tools` box becomes vertical with spacing 32 |
| `Adw.Bin` | 1 | css-name `dropoverlay` | — | drop-shadow suppression hook for the stylesheet |
| `Gtk.Overlay` | 1 | — | — | hosts the drop overlay |
| `Gtk.Revealer` (`dropOverlayRevealer`) | 1 | — | revealed by `mainDnd` enter, hidden on leave; inverted by `compareDnd` | `can-target=0`, crossfade, 600 ms |
| `Adw.StatusPage` (drop overlay) | 1 | `status` | — | "Drop to hash", icon `paper-symbolic` |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` (`header_bar`) | 1 | — | `show_title` toggled by `loading` / results | `show-title=0` initially |
| `Gtk.Button` (`openFileBtn`) | 1 | `flat` | `clicked` → `on_open_btn_clicked` | hidden until results exist |
| `Adw.ButtonContent` | 1 | — | — | `document-open-symbolic`, "_Open", tooltip "Open…" |
| `Adw.ViewSwitcher` | 1 | — | — | policy `wide`, header title widget, drives `resultsStack` |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, tooltip "Main Menu", `primary=True`, model `primary-menu` |
| `Adw.ViewSwitcherBar` (`switcher_bar`) | 1 | — | visibility toggled with results | bottom bar, hidden initially |

#### `mainStack` — the three app states

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Gtk.Stack` (`mainStack`) | 1 | `no-drop` | `visible_child_name` ∈ `welcomer`, `spinner`, `results` | |
| `Gtk.DropTarget` (`mainDnd`) | 1 | — | `enter` → reveal overlay unless spinner, returns `Copy`; `leave` → hide; `drop` → first `file://` entry of the `GdkFileList` → `on_drop` | **controller**, not a widget |
| **page `welcomer`** — empty state | | | | |
| `Adw.StatusPage` | 1 | `icon-dropshadow` | — | icon `dev.geopjr.Collision`, "Collision" / "Check hashes for your files" |
| `Gtk.Button` (`welcomeBtn`) | 1 | `suggested-action`, `pill` | `clicked` → `on_open_btn_clicked` | "_Open a File", centred |
| **page `spinner`** — progress state | | | | |
| `Adw.StatusPage` | 1 | — | — | "Calculating Hashes" / "This might take a while" |
| `Adw.Clamp` | 1 | — | — | tightening 100, max 400 |
| `Gtk.ProgressBar` (`progressbar`) | 1 | — | fraction and text driven by `Checksum#generate` | text starts "Pending", becomes `"%d of %d hashes calculated"` |
| **page `results`** | | | | |
| `Adw.StatusPage` (`fileInfo`) | 1 | — | title ← file basename, description ← containing directory | under Flatpak the real path comes from the `xattr::document-portal.host-path` attribute, queried async |
| `Adw.Clamp` | 1 | — | — | tightening 100 |
| `Adw.ViewStack` (`resultsStack`) | 1 | — | — | non-homogeneous both axes |

#### `resultsStack` page `hashes`

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Adw.ViewStackPage` | 1 | — | — | title "Hash", icon `octothorp-symbolic` |
| `Gtk.ListBox` (`hash_row_container`) | 1 | `content` | — | centred both axes |
| `HashRow` (component 10) | **7** | — | `clicked(hash_type)` → `copy_btn_cb` → clipboard | **repeater** over `HASH_FUNCTIONS`, built by the `setup_hashrows` macro; each row's `visible` is recomputed from the disabled-hash-functions setting |

#### `resultsStack` page `verify` — the verification tool

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Adw.ViewStackPage` | 1 | — | — | title "Verify", icon `test-pass-symbolic` |
| `Gtk.Box` (`tools`) | 1 | — | orientation and spacing flipped by the breakpoint | horizontal, homogeneous, spacing 45 |
| `Gtk.Box` | 2 | — | — | one column per half, vertical, spacing 20 |
| `Gtk.Label` (column titles) | 2 | `title`, `title-1`, `compact-title` | — | "Checksum" and "File" |
| `Gtk.Overlay` | 1 | — | — | overflow hidden, wraps the text view |
| `Gtk.Image` (`verifyFeedback`) | 1 | `success` ↔ `error` (**dynamic**, mutually exclusive) | icon ← `Feedback.icon(result)` | 16 px, bottom-end, insensitive, hidden while the entry is empty |
| `Gtk.Label` (`verifyOverlayLabel`) | 1 | `monospace` | hidden once the entry has text | placeholder "MD5,SHA-1,SHA-256,SHA-512,Blake3,CRC32 or Adler32 Hash" |
| `Gtk.ScrolledWindow` | 1 | — | — | 125 px high |
| `Gtk.TextView` (`verifyTextView`) | 1 | `card-like`, `monospace`, + `success` ↔ `error` (**dynamic**) | buffer `notify::text` → `handle_input_change`; tooltip ← `Feedback.title`; `announce(…, High)` on GTK ≥ 4.14 | css-name `entry`, char wrap, no tab, `no-spellcheck \| no-emoji` |
| `Gtk.Button` (`compareBtn`) | 1 | `card-like`, + `success` ↔ `error` (**dynamic**) | `clicked` → `Gtk::FileDialog#open`; `announce(title, High)` on GTK ≥ 4.14 | 125 px high, tooltip "Select Another File to Check Against" |
| `Gtk.DropTarget` (`compareDnd`) | 1 | — | `enter`/`leave` invert the main overlay; `drop` → `comparefile=` | **controller** |
| `Gtk.Stack` (`compareBtnStack`) | 1 | — | `image` ↔ `spinner` | |
| `Gtk.Image` (`compareBtnImage`) | 1 | — | icon `paper-symbolic` → `Feedback.icon(result)`; tooltip ← `Feedback.title` | 36 px |
| `Adw.Spinner` | 1 | — | — | 32×32, shown while comparing |
| `Gtk.Label` (`compareBtnLabel`) | 1 | — | label ← chosen file basename | "Choose File…", ellipsised at 15 chars |
| `Gtk.Box` | 1 | — | — | inner vertical box, spacing 12 |

#### Window actions (none of these appear in the scan — all built from string literals in `initialize`)

| Action | Accel | Behaviour |
|---|---|---|
| `win.open-file` | `<Ctrl>O` (set by the application) | `Gtk::FileDialog#open_multiple` titled "Choose a File", modal; first file into this window, the rest into new windows |
| `win.markdown` | — | Markdown table of the computed hashes onto the clipboard, columns `CRF`/`Value`, values in backticks, padded to the widest entry. Starts **disabled**, enabled when results arrive, disabled again by `loading` — which is what drives the menu item's `hidden-when` |
| `win.toggle-hashes` | — | presents the Toggle Hash Functions dialog (component 11) |

#### Other behaviour to reproduce

- `loading` resets the window to the spinner page: progress text "Pending",
  fraction 0, markdown action off, header title off, open button and switcher
  bar hidden, then `reset_feedback`.
- `reset_feedback` clears the verify buffer, returns `compareBtnStack` to
  `image`, relabels the compare button "Choose File…", strips `success`/`error`
  and restores `paper-symbolic`.
- Comparison reads the chosen file's SHA-256 and falls back to scanning the
  file's text for any known hash when it is smaller than
  `MAX_COMPARE_READ_SIZE = 1000` bytes; it sleeps 500 ms before showing the
  verdict so the spinner is visible.
- Hash subtitles are grouped in fours by `Collision.split_by_4` unless shorter
  than 8 characters.

### 9. `data/ui/shortcuts-dialog.ui` → `lib/collision/shortcuts_dialog.rb` — keyboard shortcuts

**kind:** dialog · **exists:** yes

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | id `shortcuts_dialog` |
| `Adw.ShortcutsSection` | 1 | title "General" |
| `Adw.ShortcutsItem` | 5 | Open a File → `win.open-file`; Show Keyboard Shortcuts → `app.shortcuts`; New Window → `app.new-window`; Close Window → `window.close`; Quit → `app.quit` |

**Upstream gap, carried deliberately or not:** the `app.shortcuts` action this
dialog is reached by is **never registered** — `git grep shortcuts origin/main
-- src` returns nothing, there is no `actions/shortcuts.cr`, and nothing loads
`shortcuts-dialog.ui` even though the GResource ships it. The menu item is
therefore dead upstream. The port should register `app.shortcuts` and present
this dialog; see **Open questions**.

The pilot port has a working equivalent at
`/home/nathan/src/github/ruby-gtk-project/gnome-contacts-rb/lib/shortcuts_dialog.rb`,
including the binding quirk that `Adwaita::ShortcutsItem.new` takes its title
and accelerator **positionally** despite advertising keywords. Note upstream
uses `action-name`, not a literal accelerator, so the port either resolves
accels from the application or hard-codes the five above.

### 10. `src/collision/widgets/hash_row.cr` + `data/ui/hash_row.ui` → `lib/collision/hash_row.rb` — one hash row

**kind:** row · **exists:** yes — but the custom `clicked(hash_type)` GObject signal is not registered; a Ruby block carries the callback instead

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` (template root) | 1 | `hash-row` | custom `clicked(hash_type : String)` signal | not selectable, `subtitle-lines=100`; title is the digest name, subtitle the value |
| `Gtk.Button` (`copy_btn`) | 1 | `circular`, + `success` ↔ `error` (**dynamic**) | `clicked` → `copy_btn_clicked_cb` | tooltip "Copy", icon `edit-copy-symbolic` |

`copy_btn_clicked_cb` locks the button (`copy_btn_locked`), emits `clicked`
with the hash type, swaps the icon to `test-pass-symbolic` and adds `success`,
then after **1.1 s** restores `edit-copy-symbolic`, drops the class and
unlocks. The stylesheet's `.hash-row .subtitle { font-family: monospace }` is
the only thing making the value monospaced.

Ruby note: a custom GObject signal needs `type_register` / `signal_new`, or the
port uses a plain callback block instead — a decision for the build step.

### 11. `src/collision/widgets/toggle_hash_functions_dialog.cr` → `lib/collision/toggle_hash_functions_dialog.rb` — Toggle Hash Functions

**kind:** preferences dialog · **exists:** yes · action `win.toggle-hashes`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | `close-attempt` → `on_close_attempt` | `can_close = false`, title "Toggle Hash Functions" (reuses the underlined menu string with `_` stripped, to avoid a second translatable string) |
| `Adw.PreferencesPage` | 1 | — | — | description "Select which hash functions should be calculated." |
| `Adw.PreferencesGroup` | 1 | — | — | |
| `Adw.SwitchRow` | **7** | — | read on close attempt | **repeater** over `HASH_FUNCTIONS`; active = not in the disabled list |
| `Adw.Toast` | 1 | — | — | "Wait for all ongoing operations to finish", shown when hashing is in flight |

The SHA-256 row is special-cased: insensitive, forced active, subtitle "This
hash function is used for file verification and cannot be disabled". On close
attempt: if nothing changed, `force_close`; if work is in flight, toast and
stay open; otherwise persist the disabled list and `force_close`.

### 12. `src/collision/functions/settings.cr` + `data/dev.geopjr.Collision.gschema.xml` → `lib/collision/settings.rb`

**kind:** support · **exists:** yes — `Gio::Settings` when the schema is installed, a JSON file under `XDG_CONFIG_HOME` otherwise; `data/dev.geopjr.Collision.gschema.xml` is carried on `ruby`

Four keys: `window-width` (600), `window-height` (460), `is-maximized`
(false), `disabled-hash-functions` (`[]`). Upstream guards every access with
`available?`, which diffs required keys against `settings.list_keys` so a
missing compiled schema degrades to defaults instead of aborting, and caches
the disabled list as symbols. The verification function is never allowed into
the disabled list.

The pilot port faced the same "GSettings needs an installed schema" problem and
backed the identical keys with a JSON file under `XDG_CONFIG_HOME`
(`gnome-contacts-rb/lib/settings.rb`). Same approach fits here.

### 13. `src/collision/functions/feedback.cr` → `lib/collision/feedback.rb`

**kind:** support · **exists:** yes

Three lookups shared by four call sites. `icon` → `test-pass-symbolic` /
`cross-large-symbolic`; `class` → `{add:, remove:}` over `{"success", "error"}`;
`title` → "They Match" / "They Don't Match" (both translatable). This is the
source of every dynamic CSS class in the app.

### 14. `src/collision/functions/file_utils.cr` → `lib/collision/file_utils.rb`

**kind:** support · **exists:** yes

`real_path` (returns nil for `/run/user/…` paths under Flatpak so the status
page shows nothing rather than a portal path), `file?`, and `compare_content`,
which scans a file's lines for any known hash. Covered upstream by
`spec/compare_spec.cr`.

### 15. `src/collision/functions/checksum.cr` → `lib/collision/checksum.rb`

**kind:** support · **exists:** yes — but only six of the seven digests. **Blake3 is dropped**: no Ruby gem provides it, and the verify placeholder string names it, so the omission is user-visible

`calculate(type, filename)` for the seven digests (MD5, SHA1, SHA256, SHA512,
Blake3, CRC32, Adler32 — Blake3 needs a gem or an extension in Ruby), and
`generate`, which fans the enabled digests out across an 8-way worker pool,
steps the progress bar from the main loop and yields the result hash.
`Collision.split_by_4` lives here too. Covered upstream by
`spec/hash_generator_spec.cr`.

### 16. `data/css/style.css` → shipped asset + loader in `lib/collision/application.rb`

**kind:** stylesheet · **exists:** yes — `data/style.css`, loaded by `Collision::Application`

Five rules the widget tree depends on and the scan cannot see from the source
side: `.hash-row .subtitle` (monospace), `.card-like` (12 px radius),
`.compact-title` (18 pt), the `dropoverlay` / `dropoverlay > overlay`
box-shadow suppression plus `dropoverlay .status` accent tint using
`color-mix(… var(--accent-bg-color) 80% …)`, and `.no-drop:drop(active)`.
Every class here is applied in `application.ui` and `hash_row.ui`; none is
dead. The port needs a `Gtk::CssProvider` since it has no GResource.

### 17. `data/icons/*.svg` → shipped assets

**kind:** assets · **exists:** yes — `data/icons/` carries all 11 SVGs and the icon theme search path is added at startup

Four app-local symbolics the UI names directly — `cross-large-symbolic`,
`test-pass-symbolic`, `octothorp-symbolic`, `paper-symbolic` — plus the app
icon and the four sibling-app icons the About dialog's `add_other_app` rows
need. Without them the status pages, the verify feedback image and the view
switcher tabs render blank. They must be installed into a
`Gtk::IconTheme` search path (the port has no GResource).

### 18. `po/` (41 locales + `.pot`) → translation parity

**kind:** i18n · **exists:** **no** — nothing on `ruby`

41 languages in `po/LINGUAS`, domain `dev.geopjr.Collision`. Note `po/POTFILES`
is **stale** — it still lists `data/ui/shortcuts_window.ui`, which no longer
exists (the file is now `shortcuts-dialog.ui`). Translatable strings live in
the three `.ui` files, the `.desktop.in` and the `.metainfo.xml.in`, plus the
Crystal-side `Gettext.gettext(…)` calls in the About dialog, the toggle dialog,
`feedback.cr`, `checksum.cr` and `window.cr`. Out of scope for this step; the
`translation-parity` skill owns it.

## Not part of the UI port

| Upstream | Why |
|---|---|
| `src/license.cr`, `data/scripts/licenses.cr`, `data/scripts/shards_to_sources.cr` | Crystal/shards build-time licence aggregation and a `--licenses` CLI flag. Ruby's bundler has no equivalent; reproduce only if the flag is wanted |
| `nautilus-extension/collision-extension.py` | A Python Nautilus 4.x `MenuProvider`, not part of the app binary |
| `data/dev.geopjr.Collision.json` | Flatpak manifest |
| `data/dev.geopjr.Collision.metainfo.xml.in`, `.desktop.in` | Packaging metadata; the desktop file matters if the port ever installs (`Exec=collision %F`, keywords, `X-Purism-FormFactor`) |
| `Makefile`, `shard.yml`, `shard.lock`, CI configs | Crystal build system |

## Status summary

| # | Upstream | Port target | Kind | Exists |
|---:|---|---|---|---|
| 1 | `src/collision.cr` | `lib/collision/application.rb` | application | yes — but app id is `org.rubygtkproject.Collision`, not upstream's |
| 2 | `src/collision/actions.cr` | `lib/collision/action.rb` | support | yes |
| 3 | `src/collision/actions/about.cr` | `lib/collision/actions/about.rb` | dialog | yes |
| 4 | `src/collision/actions/hashinfo.cr` | `lib/collision/actions/hash_info.rb` | action | yes |
| 5 | `src/collision/actions/new_window.cr` | `lib/collision/actions/new_window.rb` | action | yes |
| 6 | `src/collision/actions/quit.cr` | `lib/collision/actions/quit.rb` | action | yes |
| 7 | `data/ui/application.ui` (`primary-menu`) | `lib/collision/primary_menu.rb` | menu | yes |
| 8 | `src/collision/window.cr` + `data/ui/application.ui` | `lib/collision/window.rb` | window | yes |
| 9 | `data/ui/shortcuts-dialog.ui` | `lib/collision/shortcuts_dialog.rb` | dialog | yes — plus a port-only `lib/collision/actions/shortcuts.rb` that registers the `app.shortcuts` upstream leaves dead |
| 10 | `src/collision/widgets/hash_row.cr` + `data/ui/hash_row.ui` | `lib/collision/hash_row.rb` | row | yes — but no registered GObject signal; a Ruby block stands in for `clicked(hash_type)` |
| 11 | `src/collision/widgets/toggle_hash_functions_dialog.cr` | `lib/collision/toggle_hash_functions_dialog.rb` | preferences dialog | yes |
| 12 | `src/collision/functions/settings.cr` + gschema | `lib/collision/settings.rb` | support | yes — `Gio::Settings` when the schema is installed, JSON under `XDG_CONFIG_HOME` otherwise |
| 13 | `src/collision/functions/feedback.cr` | `lib/collision/feedback.rb` | support | yes |
| 14 | `src/collision/functions/file_utils.cr` | `lib/collision/file_utils.rb` | support | yes |
| 15 | `src/collision/functions/checksum.cr` | `lib/collision/checksum.rb` | support | yes — six of seven digests; **Blake3 is dropped**, no gem available |
| 16 | `data/css/style.css` | `data/style.css` + loader | stylesheet | yes — `data/style.css` |
| 17 | `data/icons/*.svg` | `data/icons/` + icon-theme path | assets | yes — `data/icons/`, 11 SVGs |
| 18 | `po/` (41 locales) | `po/` | i18n | **no** — no `po/` on `ruby`, no gettext binding, no `_()` call sites |

Seventeen of the eighteen rows now have a port file; the placeholder status page
that stood in for the window is gone. What is left for the parity steps is not
missing files but missing detail inside them — the i18n row, Blake3, the
`HashRow` signal, the app id, and whatever the `component-parity` pass finds
when it diffs the two widget streams widget by widget. `spec/` on `ruby` holds
only a `spec_helper.rb` and a README, so upstream's four Crystal specs
(`compare_spec`, `feedback_spec`, `hash_generator_spec`) have no counterpart
either — that belongs to `test-parity`.

## Open questions for the build step

1. **`app.shortcuts` is dead upstream.** The menu item and the dialog both
   exist, nothing wires them. Implement it in the port (the dialog is fully
   specified by `shortcuts-dialog.ui`) or reproduce the dead menu item?
   Implementing it is the obvious reading of intent.
2. **Blake3.** No Ruby stdlib digest. Needs a gem or a C extension, and the
   verify-page placeholder string names Blake3, so dropping it is visible.
3. **Custom GObject signal.** `HashRow`'s `clicked(hash_type : String)` is a
   real registered signal upstream. A Ruby callback block is simpler and
   invisible to users; registering the signal is the faithful port.
4. **Cross-window serialisation.** The global atomic, the per-window queue, the
   "Pending" progress text and `hide_on_close` interact; Ruby's GVL and the
   GTK main loop make the threading model a port decision, not a translation.
5. **GSettings vs JSON.** The pilot chose JSON to avoid an install step. Same
   here, or compile the schema in the dev shell?
6. **App id.** The port currently uses `org.rubygtkproject.Collision`;
   upstream's is `dev.geopjr.Collision`, which is also the gettext domain, the
   GSettings path and the icon name.

### How the build step answered them

Re-surveyed after `310cb33`:

| # | Resolution |
|---:|---|
| 1 | **Implemented.** `lib/collision/actions/shortcuts.rb` registers `app.shortcuts` with accel `<Ctrl>question` and presents `ShortcutsDialog`. Its own comment claims the action "comes from the Crystal binary's generated action set" — that is wrong, upstream never registers it; the comment should be corrected to say the port adds it |
| 2 | **Dropped.** `lib/collision/checksum.rb` carries six digests and says so in a comment. Still open as a parity gap, because the verify placeholder names Blake3 |
| 3 | **Not registered.** `HashRow` uses a Ruby block. Open for `component-parity` to rule on |
| 4 | Ported inside `window.rb`; needs exercising under two windows before it can be called settled |
| 5 | **Both.** `Gio::Settings` when the compiled schema is found, a JSON file under `XDG_CONFIG_HOME` otherwise |
| 6 | **Still `org.rubygtkproject.Collision`.** Open |
| 7 | **New.** No `po/` at all, so every string in the port is an untranslated literal. `translation-parity` owns this and it is the single largest remaining gap |

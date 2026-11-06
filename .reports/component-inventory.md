# Component inventory — Collision

Upstream is a Crystal/GTK4/libadwaita app (`src/collision/**.cr`, backed by
`data/ui/*.ui` templates and `data/dev.geopjr.Collision.gresource.xml`). This
inventory enumerates every user-facing component (windows, dialogs, menus,
rows, actions, shortcuts, settings-backed state, empty/error/progress states)
and maps it to the `ruby` branch.

Scope note: this is the whole-app opening survey the `component-identification`
skill calls for on a fresh fork — totals and a per-unit map, not a full
widget/CSS/signal table for each file (that level of detail belongs to a
`component-parity` pass once a unit is picked to work on).

## Summary

- Upstream: 1 application class, 1 window (template), 2 custom widget classes
  (1 template-backed, 1 built in code), 1 standalone shortcuts dialog (`.ui`,
  no backing class), 1 menu model, 4 `Gio::SimpleAction` app actions + 3 window
  actions, 1 GSettings schema, 44 translated `.po` catalogues + `.pot`.
- `ruby` branch `lib/`: all of the above already exist, file-for-file, plus a
  `shortcuts` action class upstream does not have (see note below). The port
  is at full structural parity, including Blake3 (via the `digest-blake3` gem,
  wired into `lib/collision/checksum.rb`'s `HASH_FUNCTIONS`/`DIGESTS`).

## Components

### 1. Application — `dev.geopjr.Collision`

| | |
|---|---|
| Upstream | `src/collision.cr` (module `Collision`, top-level `startup`/`activate`/`open_with`/`open_files`) |
| Port | `lib/collision/application.rb` — `Collision::Application` |
| Kind | application class (actions, accelerators, resource loading) |
| Exists on `ruby`? | **Yes** |

Installs 4 actions (`about`, `hashinfo`, `new-window`, `quit`) and 2 window
accelerators (`win.open-file` → `<Ctrl>O`, `window.close` → `<Ctrl>W`).
Upstream loads its CSS/icons from a compiled `GResource`; the port loads the
same `data/style.css` and `data/icons/` directly since it has no resource
compile step — a deliberate, documented difference, not a gap.

### 2. Main window — `Collision-Window`

| | |
|---|---|
| Upstream | `src/collision/window.cr` (class `Collision::Window`) + template `data/ui/application.ui` |
| Port | `lib/collision/window.rb` — `Collision::Window` |
| Kind | `Adw.ApplicationWindow` template — the whole app surface |
| Exists on `ruby`? | **Yes** |

Sub-components inside the one template, each reproduced in the port's
`build`/memoized methods:

| Upstream widget/state | Port method | Notes |
|---|---|---|
| Drop overlay (`AdwBin` + `GtkOverlay` + `GtkRevealer` + `AdwStatusPage` "Drop to hash") | `drop_bin`, `overlay`, `drop_revealer`, `drop_status_page` | present |
| `AdwBreakpoint` (max-width 400sp — narrow layout) | `narrow_breakpoint`, `narrow_condition` | present, with a documented binding workaround for `GValue` setters |
| `AdwToolbarView` + `AdwHeaderBar` (open button, view switcher title, menu button) | `toolbar_view`, `header_bar`, `open_file_button`, `open_button_content`, `view_switcher`, `menu_button` | present |
| `AdwViewSwitcherBar` | `switcher_bar` | present |
| `GtkStack` "welcomer"/"spinner"/"results" pages (empty/progress/results states) | `main_stack`, `welcome_page`, `welcome_button`, `spinner_page`, `progress_clamp`, `progressbar`, `file_info`, `results_clamp` | present — covers the app's empty state (welcomer) and loading state (spinner) |
| Main `GtkDropTarget` (file drag-drop onto window) | `main_dnd` + `on_main_drag_enter`/`on_main_drop` | present |
| `AdwViewStack` "hashes"/"verify" pages | `results_stack` | present |
| Hash list (`GtkListBox` of `HashRow`) | `hash_row_container`, `hash_rows` | present |
| Verify tool (checksum entry, overlay hint/feedback label+icon) | `checksum_box`, `checksum_title`, `verify_overlay`, `verify_feedback`, `verify_overlay_label`, `verify_scroller`, `verify_text_view` | present; `handle_input_change` / `show_verify_feedback` / `clear_verify_feedback` reproduce the success/error feedback states |
| Compare tool (drop target + file dialog button, image/spinner stack) | `file_box`, `file_title`, `compare_button`, `compare_box`, `compare_button_stack`, `compare_button_image`, `compare_spinner`, `compare_button_label`, `compare_dnd` | present; `comparefile=`/`spawn_comparison`/`show_compare_feedback` reproduce match/no-match/error states |
| Window actions (`open-file`, `markdown`, `toggle-hashes`) | `open_file_action`, `markdown_action`, `toggle_hashes_action` | present |
| Close handling (hide-on-close while hashing, settings save) | `on_close_request` | present |
| Multi-window hash queue (one window hashes at a time) | `Window.pending`/`increase`/`decrease`, `continue_queue`, `hand_on_queue` | present |

### 3. Primary menu (header bar menu button model)

| | |
|---|---|
| Upstream | `<menu id="primary-menu">` in `data/ui/application.ui` |
| Port | `lib/collision/primary_menu.rb` — `Collision::PrimaryMenu` |
| Kind | `Gio::Menu` model, no backing widget subclass upstream |
| Exists on `ruby`? | **Yes** |

6 items: New Window, Compare Hash Functions, Copy as Markdown Table (hidden
when `win.markdown` is disabled — reproduced via `hidden-when`/`action-disabled`
attribute), Toggle Hash Functions, Keyboard Shortcuts, About Collision.

### 4. Hash row — one row per hash function

| | |
|---|---|
| Upstream | `src/collision/widgets/hash_row.cr` + template `data/ui/hash_row.ui` |
| Port | `lib/collision/hash_row.rb` — `Collision::HashRow` |
| Kind | `Adw.ActionRow` template, repeated once per entry in `HASH_FUNCTIONS` (7 on the port, matching upstream) |
| Exists on `ruby`? | **Yes** |

Copy button with timed success-icon feedback (`Feedback.icon`/`css_classes`),
locked against repeat clicks while the feedback is showing — reproduced.

### 5. Toggle Hash Functions dialog

| | |
|---|---|
| Upstream | `src/collision/widgets/toggle_hash_functions_dialog.cr` (no `.ui`, built in code) |
| Port | `lib/collision/toggle_hash_functions_dialog.rb` — `Collision::ToggleHashFunctionsDialog` |
| Kind | `Adw.PreferencesDialog` with one `Adw.PreferencesGroup` of `Adw.SwitchRow`s |
| Exists on `ruby`? | **Yes** |

One switch row per hash function; the verification hash's row is forced on and
disabled. Close is intercepted (`can_close = false` / `close-attempt` signal)
to write settings first and to refuse closing while a hash run is in flight
(toast shown) — all reproduced.

### 6. Shortcuts dialog

| | |
|---|---|
| Upstream | `data/ui/shortcuts-dialog.ui` — standalone `AdwShortcutsDialog` object, no backing class |
| Port | `lib/collision/shortcuts_dialog.rb` — `Collision::ShortcutsDialog` |
| Kind | `Adw.ShortcutsDialog`, one `AdwShortcutsSection` ("General") |
| Exists on `ruby`? | **Yes** |

5 items upstream (Open a File, Show Keyboard Shortcuts, New Window, Close
Window, Quit), all reproduced with accelerators spelled out next to each
action (upstream's items name the action rather than the key, relying on the
app's own accel binding; the port lists both label and accelerator string).

**Note on `app.shortcuts`:** upstream's menu and shortcuts dialog both
reference the action `app.shortcuts`, but no `Collision::Action` subclass
defines it in `src/collision/actions/*.cr` or in `startup` — recent
libadwaita (≥1.6) auto-installs `app.shortcuts` on `Adw::Application` when a
`.../ui/shortcuts-dialog.ui` resource exists at the conventional GResource
path. The port instead defines this explicitly as
`lib/collision/actions/shortcuts.rb` (`Collision::Action::Shortcuts`). This is
an intentional, visible divergence (the Ruby bindings/app have no equivalent
auto-install convention) rather than a missing component — flag it if a
parity pass wants the two to match behaviourally (accelerator binding, F1-style
handling) rather than just by outcome.

### 7. App actions

| Upstream file | Action name | Accel | Port file | Exists? |
|---|---|---|---|---|
| `src/collision/actions/about.cr` | `app.about` | `F1` | `lib/collision/actions/about.rb` | **Yes** |
| `src/collision/actions/hashinfo.cr` | `app.hashinfo` | — | `lib/collision/actions/hash_info.rb` | **Yes** |
| `src/collision/actions/new_window.cr` | `app.new-window` | `<Ctrl>N` | `lib/collision/actions/new_window.rb` | **Yes** |
| `src/collision/actions/quit.cr` | `app.quit` | `<Ctrl>Q` | `lib/collision/actions/quit.rb` | **Yes** |
| *(auto-installed by libadwaita, no upstream `.cr` file)* | `app.shortcuts` | — | `lib/collision/actions/shortcuts.rb` | **Yes** (port-only file, see note above) |
| `src/collision/actions.cr` (abstract base) | — | — | `lib/collision/action.rb` — `Collision::Action` | **Yes** |

Window-owned actions (`win.open-file`, `win.markdown`, `win.toggle-hashes`) are
listed under the window component above, not here.

### 8. About dialog

| | |
|---|---|
| Upstream | `src/collision/actions/about.cr` → `Adw::AboutDialog` built in code |
| Port | `lib/collision/actions/about.rb`, `#dialog` |
| Kind | `Adw.AboutDialog`, built on demand (not a template) |
| Exists on `ruby`? | **Yes** |

Same metadata, same 4 "other apps" (Archives, Calligraphy, Tuba, Turntable),
translator-credits handling, and a debug-info block. Upstream's debug block is
accumulated continuously into a `TROUBLESHOOTING` buffer in `src/collision.cr`
(including a redacted log of every file opened); the port's `#troubleshooting`
instead assembles a static snapshot (flatpak?, version, ruby/gtk/libadwaita
versions, settings backend, hash function list) with no running log — a
documented, intentional simplification, not an omission of a visible
component.

### 9. Non-widget support modules (ported, not independent UI components but back every component above)

| Upstream | Port | Exists? |
|---|---|---|
| `src/collision/functions/checksum.cr` (+ `HASH_FUNCTIONS`/`VERIFICATION_HASH_FUNCTION` from `src/collision.cr`) | `lib/collision/checksum.rb` | **Yes** — Blake3 included via the `digest-blake3` gem |
| `src/collision/functions/feedback.cr` | `lib/collision/feedback.rb` | **Yes** |
| `src/collision/functions/file_utils.cr` | `lib/collision/file_utils.rb` | **Yes** |
| `src/collision/functions/settings.cr` | `lib/collision/settings.rb` | **Yes** |
| `src/license.cr` | `lib/collision/rb/version.rb` (+ gemspec `LICENSE`) | **Yes**, different shape but same role |
| i18n/gettext setup in `src/collision.cr` | `lib/collision/i18n.rb` | **Yes** |

### 10. GSettings schema

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.gschema.xml` — `window-width`, `window-height`, `is-maximized`, `disabled-hash-functions` |
| Port | `data/dev.geopjr.Collision.gschema.xml` | **Yes**, present verbatim on `ruby` |

### 11. GResource manifest

| | |
|---|---|
| Upstream | `data/dev.geopjr.Collision.gresource.xml` — bundles `data/ui/*.ui` and `data/css/style.css` into the compiled binary |
| Port | not present under `data/` on `ruby`; the port loads `data/style.css` and `data/icons/` directly at runtime (see Application, above) instead of compiling a resource bundle | **N/A by design** — not a missing UI component, a build-pipeline difference already called out in `lib/collision/application.rb`'s header comment |

### 12. Stylesheet

| | |
|---|---|
| Upstream | `data/css/style.css` |
| Port | `data/style.css` (note: one directory level up from upstream) | **Yes**, present; not diffed line-by-line in this pass — a `component-parity` pass on the window should confirm every CSS class the window inventory above lists (`dropoverlay`, `status`, `flat`, `no-drop`, `icon-dropshadow`, `suggested-action`, `pill`, `content`, `title`/`title-1`/`compact-title`, `monospace`, `card-like`, `circular`, `hash-row`, `success`, `error`, `verify-entry`) is still defined there. |

### 13. Translation catalogue

| | |
|---|---|
| Upstream | `po/*.po` (44 locales) + `po/dev.geopjr.Collision.pot` + `po/LINGUAS` + `po/POTFILES` |
| Port | `po/` present on `ruby` with the same catalogue files | **Yes** — a `translation-parity` pass (there is a dedicated skill for this) should confirm message IDs still match the port's `N_()`/`_()` call sites; `VERIFY_HINT`/`VERIFY_TOOLTIP` in `window.rb` now read Blake3-inclusive, matching upstream, but the `.po` catalogues were not re-translated for the new wording this round, so those two strings fall back to English until a translation pass catches up. |

### 14. Packaging-only files (not user-facing components; no port file expected)

`data/dev.geopjr.Collision.desktop.in`, `data/dev.geopjr.Collision.metainfo.xml.in`,
`data/dev.geopjr.Collision.json` (Flatpak manifest), `data/scripts/*.cr`,
`nautilus-extension/collision-extension.py`, `Collision.doap`. None of these
define UI; listed here only so a future pass doesn't mistake their absence
from `lib/` for a gap.

### 15. Icons

| Upstream file | Used by | Port (`data/icons/`) |
|---|---|---|
| `dev.geopjr.Collision.svg` | app icon, welcome page | **Yes** |
| `dev.geopjr.Collision-symbolic.svg` | window/taskbar symbolic | **Yes** |
| `dev.geopjr.Collision.Source.svg` | — | **Yes** |
| `paper-symbolic.svg` | drop status page, compare button image | **Yes** |
| `octothorp-symbolic.svg` | "Hash" view-stack page icon | **Yes** |
| `test-pass-symbolic.svg` | "Verify" view-stack page icon, success feedback icon | **Yes** |
| `cross-large-symbolic.svg` | failure feedback icon | **Yes** |
| `dev.geopjr.Archives.svg`, `dev.geopjr.Calligraphy.svg`, `dev.geopjr.Tuba.svg`, `dev.geopjr.Turntable.svg` | About dialog "other apps" | **Yes** |

## Gaps / flags for a future parity pass

1. **`app.shortcuts` origin differs** (libadwaita auto-install upstream vs. an
   explicit `Action` subclass on the port) — behaviourally equivalent today,
   but worth a side-by-side check (does it get the same `F1`-style treatment,
   does `app.set_accels_for_action` need to run for it the way it does for the
   others) rather than assuming the outcome stays matched as libadwaita
   versions move.
2. **About dialog's `debug_info`** is a static snapshot on the port vs. an
   accumulating redacted log upstream — not a missing component, but a
   behavioural difference worth a conscious decision rather than letting it
   default to "simpler is fine."
4. **CSS and translation catalogues were not diffed line-by-line** in this
   pass; flagged for `component-parity` / `translation-parity` skills.

# Component parity — Collision

| | |
|---|---|
| Upstream | `main` @ `9d35ba0` |
| Port | `ruby` @ `1c70cce` |
| Units with full 4-axis parity | 15 / 18 |

Scope: all 18 components from `.reports/component-inventory.md` plus the three
this audit added in `component-identification.md`. For the 15 that
`component-inventory.md` already maps file-for-file (application, window and
its sub-widgets, primary menu, hash row, toggle-hash-functions dialog,
shortcuts dialog, the 4 `Gio::SimpleAction` app actions + the port-only
`shortcuts` action, gschema, stylesheet, translation catalogue, icons), this
audit's own drive run (`test/drive_window.rb`, re-run live: **33/33 checks,
`DRIVE OK`**) independently exercises count, style class presence
(`toggle-hashes opens a dialog with a row per function`,
`primary menu has six items`, `the markdown menu item is hidden-when
action-disabled`), behaviour (every accelerator, every window/app action,
open/compare/verify flows, the copy-feedback timers) and — for the strings the
drive script asserts on literally (`"welcome page is shown"` reads
`main_stack.visible_child_name`, not label text) — presence. That corroborates
`component-inventory.md`'s per-component rows rather than re-deriving them;
see that file for the row-by-row widget/CSS/signal table.

## Gaps this pass adds

| Unit | Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---|---:|---:|---|---|:-:|---|
| Nautilus extension | `Nautilus.MenuItem` | 1 | 0 | — | ✗ `activate` | ✗ | **gap**: no port file at all, see `component-identification.md` §16 |
| Desktop entry | (not a widget — a `.desktop` key set) | 4 keys | 1 of 4 (`Name`, indirectly) | — | — | ✗ 3 of 4 | **gap**: §17 |
| AppStream metadata | (not a widget — a `.metainfo.xml` key set) | name+summary+description+4 screenshots | 0 | — | — | ✗ | **gap**: §18 |
| GResource manifest | — | — | — | — | — | — | **correspondence**, not a gap — css/icons loaded directly, same rendered result |

## Stylesheet

`component-inventory.md` flagged the stylesheet as "not diffed line-by-line."
Diffed here:

```
diff <(git show origin/main:data/css/style.css) data/style.css
```

Byte-identical (confirmed: `diff` emitted nothing). Full parity on this axis
for every CSS class the window inventory lists.

## Text axis

Deferred to `translation-parity.md`'s census, which is scoped to the whole
app rather than per-component here — see that document for the per-string
table. Two of this pass's three gaps (desktop entry, AppStream metadata) are
simultaneously text-axis gaps: `GenericName`, `Comment`-as-launcher-entry,
`Keywords`, and the metainfo `<summary>` have no port call site because the
files that would carry them do not exist. Carried in both ledgers per the
skill's rule.

## Driven behaviour — what 33/33 actually covers, and what it does not

The drive run is real and green (re-run live for this audit, not taken on
faith). It covers 15 of the app's components by the task's own count. It does
**not** drive, and no other check in this port drives:

- the Nautilus extension (cannot — it has no port file to drive);
- the About dialog's four "other app" entries (`add_other_app` calls) —
  `check_app_actions`'s `"app.about opens the about dialog"` only asserts the
  dialog opens, not that the four entries are present with the right
  icon/name/summary;
- the app running under a non-English locale with the UI actually rendering
  translated text — see `translation-parity.md`, which found this gap is not
  cosmetic: the locale path crashes.

A component no check exercises is unverified, not done, per this audit's
brief. The second and third items above are exactly that.

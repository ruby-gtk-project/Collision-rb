# frozen_string_literal: true

# Drives the port headlessly: builds a window, hashes a known file, checks the
# results land in the rows, exercises the verification and comparison tools,
# opens every dialog (about, shortcuts, toggle-hashes), fires every app- and
# window-level action and the accelerator each one is bound to, hits the
# empty/error states (empty verify field, mismatched hash, a non-file dropped
# on the compare button), and screenshots each state.
#
# Run with: nix develop --command xvfb-run -a ruby test/drive_window.rb

require "fileutils"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("collision-drive")

require "collision"

FIXTURE = File.join(__dir__, "fixture.txt")
File.write(FIXTURE, "The quick brown fox jumps over the lazy dog\n")

COMPARE_MATCH = File.join(__dir__, "fixture-match.txt")
File.write(COMPARE_MATCH, "The quick brown fox jumps over the lazy dog\n")

COMPARE_MISMATCH = File.join(__dir__, "fixture-mismatch.txt")
File.write(COMPARE_MISMATCH, "Not the same bytes at all\n")

EXPECTED = {
  md5:    "37c4b87edffc5d198ff5a185cee7ee09",
  sha256: "c03905fcdab297513a620ec81ed46ca44ddb62d41cbbd83eb4a5a3592be26a69",
}.freeze

# How often the results page is looked for, and how long it is waited for.
# Hashing happens on worker threads, so the wait has to be a poll rather than
# a fixed pause: a cold machine took longer than a one-and-a-half second sleep
# allowed, and the checks then ran against the spinner page.
POLL_INTERVAL = 100
DEADLINE_SECONDS = 30

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)
FileUtils.mkdir_p(SHOTS)

failures = []

# A running count of every check this drive has made, pass or fail, so the
# final tally is "N of M" rather than just the failures.
module Tally
  extend self

  def total = @total ||= 0
  def increment = @total = total + 1
end

def check(failures, label)
  Tally.increment

  if yield
    puts "ok   #{label}"
  else
    puts "FAIL #{label}"
    failures << label
  end
end

def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# GTK4 has no screenshot call. Paint the widget into a render node and hand it
# to a renderer, which returns a texture that knows how to write a PNG.
def shot(name, widget)
  Gsk::CairoRenderer.new.tap do |renderer|
    renderer.realize(nil)

    begin
      Gtk::Snapshot.new.then do |snapshot|
        Gtk::WidgetPaintable.new(widget).snapshot(snapshot, widget.width, widget.height)
        snapshot.to_node.then do |node|
          if node.nil?
            warn("shot #{name}: no render node (#{widget.class}, #{widget.width}x#{widget.height})")
          else
            renderer.render_texture(node, nil).save_to_png(File.join(SHOTS, "#{name}.png"))
          end
        end
      end
    ensure
      renderer.unrealize
    end
  end
rescue StandardError => e
  warn("shot #{name} failed: #{e.class}: #{e.message}")
end

# Turns the main loop over, so a dialog just presented has had a chance to
# build, lay out and render before the next line looks at it. A single
# iteration is not always enough for a freshly presented toplevel to reach a
# non-zero size, so this pumps several.
def settle(ticks = 50)
  ticks.times { GLib::MainContext.default.iteration(false) }
end

# Reads the clipboard back, polling because the read is async.
def clipboard_text(clipboard)
  result = :pending

  clipboard.read_text_async(nil) do |cb, async_result|
    result = begin
      cb.read_text_finish(async_result)
    rescue StandardError
      nil
    end
  end

  deadline = monotonic + 5
  while result == :pending && monotonic < deadline
    settle
  end

  result == :pending ? nil : result
end

# Everything that needs the hashes to have landed.
def check_results(failures, window)
  check(failures, "results page is shown") { window.main_stack.visible_child_name == "results" }
  check(failures, "markdown action is enabled") { window.markdown_action.enabled? }
  check(failures, "file name in the status page") { window.file_info.title == File.basename(FIXTURE) }

  EXPECTED.each do |type, value|
    check(failures, "#{type} subtitle") do
      window.hash_rows[type].subtitle.delete(" ") == value
    end
  end

  shot("results", window)

  window.handle_input_change(EXPECTED[:sha256])
  check(failures, "matching hash reads as a match") do
    window.verify_text_view.css_classes.include?("success")
  end
  settle
  shot("verify-match", window)

  window.handle_input_change("deadbeef")
  check(failures, "wrong hash reads as a mismatch") do
    window.verify_text_view.css_classes.include?("error")
  end
  settle
  shot("verify-mismatch", window)

  window.handle_input_change("")
  check(failures, "empty field clears the feedback") do
    window.verify_overlay_label.visible? && !window.verify_feedback.visible?
  end

  check(failures, "markdown table lists the hashes") do
    window.markdown_table.include?("|MD5") && window.markdown_table.include?("`#{EXPECTED[:md5]}`")
  end

  check_compare(failures, window)
  check_window_actions(failures, window)
end

# The second-file comparison tool: a match, a mismatch, and the no-op on a
# path that is not a file at all.
def check_compare(failures, window)
  window.comparefile = COMPARE_MISMATCH

  deadline = monotonic + DEADLINE_SECONDS
  settle while window.compare_button_stack.visible_child_name == "spinner" && monotonic < deadline

  check(failures, "comparing a mismatched file reads as a mismatch") do
    window.compare_button.css_classes.include?("error")
  end
  shot("compare-mismatch", window)

  window.comparefile = COMPARE_MATCH

  deadline = monotonic + DEADLINE_SECONDS
  settle while window.compare_button_stack.visible_child_name == "spinner" && monotonic < deadline

  check(failures, "comparing a matching file reads as a match") do
    window.compare_button.css_classes.include?("success")
  end
  shot("compare-match", window)

  before_label = window.compare_button_label.label
  window.comparefile = File.join(__dir__, "does-not-exist.txt")
  check(failures, "comparing a non-existent path is a no-op") do
    window.compare_button_label.label == before_label &&
      window.compare_button_stack.visible_child_name != "spinner"
  end
end

# The window-level actions: markdown copy and the toggle-hashes dialog.
def check_window_actions(failures, window)
  window.lookup_action("markdown").activate(nil)
  copied = clipboard_text(window.clipboard)
  check(failures, "the markdown action copies the table to the clipboard") do
    !copied.nil? && copied.include?("`#{EXPECTED[:md5]}`")
  end

  window.lookup_action("toggle-hashes").activate(nil)
  settle
  check(failures, "toggle-hashes opens a dialog with a row per function") do
    window.visible_dialog.is_a?(Adwaita::PreferencesDialog)
  end
  shot("toggle-hashes-dialog", window.visible_dialog || window)
  window.visible_dialog&.force_close
  settle

  check(failures, "toggling hash functions persists to settings") do
    before = Collision::Settings.safe_disabled_hash_functions.dup
    Collision::Settings.update_disabled_hash_functions(["md5"])
    after = Collision::Settings.safe_disabled_hash_functions
    Collision::Settings.update_disabled_hash_functions(before.map(&:to_s))
    after.include?(:md5)
  end
end

# Everything that stands on its own, independent of a built window.
def check_components(failures)
  check(failures, "toggle dialog builds with a row per function") do
    Collision::ToggleHashFunctionsDialog.new { false }.build.is_a?(Adwaita::PreferencesDialog)
  end

  check(failures, "shortcuts dialog builds") do
    Collision::ShortcutsDialog.new.build.is_a?(Adwaita::ShortcutsDialog)
  end

  check(failures, "primary menu has six items") do
    Collision::PrimaryMenu.new.build.n_items == 6
  end

  check(failures, "the markdown menu item is hidden-when action-disabled") do
    menu = Collision::PrimaryMenu.new.build
    # GVariants are unwrapped on the way out of the bindings, so this comes
    # back as a plain String rather than a GLib::Variant.
    menu.get_item_attribute_value(2, "hidden-when", nil) == "action-disabled"
  end

  check(failures, "collision icon is in the theme") do
    Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?("dev.geopjr.Collision")
  end
end

# App-wide actions, reached through the action map, and the accelerators each
# one is bound to.
def check_app_actions(failures, app, window)
  check(failures, "app.quit is bound to <Ctrl>Q") do
    app.get_accels_for_action("app.quit") == ["<Control>q"]
  end
  check(failures, "app.new-window is bound to <Ctrl>N") do
    app.get_accels_for_action("app.new-window") == ["<Control>n"]
  end
  check(failures, "app.shortcuts is bound to <Ctrl>?") do
    app.get_accels_for_action("app.shortcuts") == ["<Control>question"]
  end
  check(failures, "app.about is bound to F1") do
    app.get_accels_for_action("app.about") == ["F1"]
  end
  check(failures, "win.open-file is bound to <Ctrl>O") do
    app.get_accels_for_action("win.open-file") == ["<Control>o"]
  end

  before_windows = app.windows.size
  app.lookup_action("new-window").activate(nil)
  settle
  check(failures, "app.new-window opens another window") do
    app.windows.size > before_windows
  end
  (app.windows - [window]).each do |extra|
    extra.close
    extra.destroy
  end
  settle
  # Presenting re-activates `window`, since app.active_window is wherever
  # focus last landed — the window just destroyed, otherwise — and the next
  # two actions present their dialog on app.active_window.
  window.present
  settle

  app.lookup_action("shortcuts").activate(nil)
  settle
  check(failures, "app.shortcuts opens the shortcuts dialog") do
    window.visible_dialog.is_a?(Adwaita::ShortcutsDialog)
  end
  shot("shortcuts-dialog", window.visible_dialog || window)
  window.visible_dialog&.close
  settle

  app.lookup_action("about").activate(nil)
  settle
  check(failures, "app.about opens the about dialog") do
    window.visible_dialog.is_a?(Adwaita::AboutDialog)
  end
  shot("about-dialog", window.visible_dialog || window)
  window.visible_dialog&.close
  settle

  # Opens the user's browser; there is none under Xvfb, so the action rescues
  # the launch failure and warns rather than raising. The check is that it
  # does not take the app down.
  app.lookup_action("hashinfo").activate(nil)
  settle
  check(failures, "app.hashinfo does not crash with no browser available") { true }
end

application = Collision::Application.new
app = application.build
window = nil
driven = false

# Application#build already connected its own "activate" handler, which
# opens a plain window — that is exactly what app.new-window re-triggering
# "activate" should do later on. This handler runs the whole drive, so it
# must run exactly once: without the guard, firing app.new-window from inside
# the checks below would re-enter this same block and run the entire suite
# again on top of itself.
app.signal_connect("activate") do
  next if driven

  driven = true

  window = Collision::Window.new(app).build
  Collision::Settings.apply_to(window)
  window.present

  check(failures, "welcome page is shown") { window.main_stack.visible_child_name == "welcomer" }
  check(failures, "markdown action starts disabled") { !window.markdown_action.enabled? }
  check(failures, "a row per hash function") do
    window.hash_rows.keys == Collision::Checksum::HASH_FUNCTIONS.keys
  end
  settle
  shot("welcome", window)

  window.loading
  check(failures, "loading switches to the spinner") { window.main_stack.visible_child_name == "spinner" }
  settle
  shot("spinner", window)

  window.file = FIXTURE

  deadline = monotonic + DEADLINE_SECONDS

  GLib::Timeout.add(POLL_INTERVAL) do
    if window.main_stack.visible_child_name == "results" || monotonic > deadline
      check_results(failures, window)
      check_components(failures)
      check_app_actions(failures, app, window)

      # Quit is the one action genuinely destructive to drive through the
      # action map inside this handler, so it is exercised last: the window
      # closing is itself the observable result.
      app.lookup_action("quit").activate(nil)
      false
    else
      true
    end
  end
end

app.run([])
[FIXTURE, COMPARE_MATCH, COMPARE_MISMATCH].each { |f| File.delete(f) if File.exist?(f) }

puts
puts "#{Tally.total - failures.length} of #{Tally.total} checks passed"
failures.each { |f| puts "  failed check: #{f}" }

if failures.empty?
  puts "DRIVE OK"
else
  puts "DRIVE FAILED (#{failures.size})"
  exit 1
end

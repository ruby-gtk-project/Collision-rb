# frozen_string_literal: true

# Drives the port headlessly: builds a window, hashes a known file, checks the
# results land in the rows, exercises the verification tools and the markdown
# table, and opens each dialog.
#
# Run with: nix develop --command xvfb-run -a ruby test/drive_window.rb

require "collision"

FIXTURE = File.join(__dir__, "fixture.txt")
File.write(FIXTURE, "The quick brown fox jumps over the lazy dog\n")

EXPECTED = {
  md5:    "37c4b87edffc5d198ff5a185cee7ee09",
  sha256: "c03905fcdab297513a620ec81ed46ca44ddb62d41cbbd83eb4a5a3592be26a69",
}.freeze

failures = []

def check(failures, label)
  if yield
    puts "ok   #{label}"
  else
    puts "FAIL #{label}"
    failures << label
  end
end

application = Collision::Application.new
app = application.build
window = nil

app.signal_connect("activate") do
  window = Collision::Window.new(app).build
  Collision::Settings.apply_to(window)
  window.present

  check(failures, "welcome page is shown") { window.main_stack.visible_child_name == "welcomer" }
  check(failures, "markdown action starts disabled") { !window.markdown_action.enabled? }
  check(failures, "a row per hash function") do
    window.hash_rows.keys == Collision::Checksum::HASH_FUNCTIONS.keys
  end

  window.loading
  check(failures, "loading switches to the spinner") { window.main_stack.visible_child_name == "spinner" }

  window.file = FIXTURE

  GLib::Timeout.add(1500) do
    check(failures, "results page is shown") { window.main_stack.visible_child_name == "results" }
    check(failures, "markdown action is enabled") { window.markdown_action.enabled? }
    check(failures, "file name in the status page") { window.file_info.title == File.basename(FIXTURE) }

    EXPECTED.each do |type, value|
      check(failures, "#{type} subtitle") do
        window.hash_rows[type].subtitle.delete(" ") == value
      end
    end

    window.handle_input_change(EXPECTED[:sha256])
    check(failures, "matching hash reads as a match") do
      window.verify_text_view.css_classes.include?("success")
    end

    window.handle_input_change("deadbeef")
    check(failures, "wrong hash reads as a mismatch") do
      window.verify_text_view.css_classes.include?("error")
    end

    window.handle_input_change("")
    check(failures, "empty field clears the feedback") do
      window.verify_overlay_label.visible? && !window.verify_feedback.visible?
    end

    check(failures, "markdown table lists the hashes") do
      window.markdown_table.include?("|MD5") && window.markdown_table.include?("`#{EXPECTED[:md5]}`")
    end

    check(failures, "toggle dialog builds with a row per function") do
      Collision::ToggleHashFunctionsDialog.new { false }.build.is_a?(Adwaita::PreferencesDialog)
    end

    check(failures, "shortcuts dialog builds") do
      Collision::ShortcutsDialog.new.build.is_a?(Adwaita::ShortcutsDialog)
    end

    check(failures, "primary menu has six items") do
      Collision::PrimaryMenu.new.build.n_items == 6
    end

    check(failures, "collision icon is in the theme") do
      Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?("dev.geopjr.Collision")
    end

    app.quit
    false
  end
end

app.run([])
File.delete(FIXTURE)

if failures.empty?
  puts "all checks passed"
else
  warn "#{failures.size} failed: #{failures.join(", ")}"
  exit 1
end

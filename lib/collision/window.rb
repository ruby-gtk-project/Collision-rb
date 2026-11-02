# frozen_string_literal: true

require "adwaita"

require_relative "checksum"
require_relative "feedback"
require_relative "file_utils"
require_relative "hash_row"
require_relative "primary_menu"
require_relative "settings"
require_relative "toggle_hash_functions_dialog"

module Collision
  # Window is the application window: a welcome page, a progress page, and a
  # results page carrying the hash list and the verification tools.
  #
  # Ported from upstream's src/collision/window.cr and the Collision-Window
  # template in data/ui/application.ui. Upstream builds the tree from the UI
  # file and picks the widgets back out with template_child; the port builds
  # the same tree declaratively, so every widget in the UI file is a memoized
  # method here and the structure lives in `build`.
  #
  # The hashing queue is upstream's too: only one window hashes at a time, the
  # others hold their file until the running one reports in, and a window
  # closed while it is still hashing is hidden rather than destroyed so its
  # results can hand the queue on.
  class Window < Adwaita::ApplicationWindow
    # Content below this size is also searched for any of the hashes, so a
    # dropped `SHA256SUMS` file verifies. Larger files are not read into
    # memory; upstream uses the same cutoff.
    MAX_COMPARE_READ_SIZE = 1000

    # How long the comparison result is held back, so a result that lands
    # instantly still reads as a result rather than a flicker.
    COMPARE_SETTLE_SECONDS = 0.5

    VERIFY_HINT = "MD5,SHA-1,SHA-256,SHA-512,CRC32 or Adler32 Hash"
    VERIFY_TOOLTIP = "Insert a MD5/SHA-1/SHA-256/SHA-512/CRC32/Adler32 Hash"
    CHOOSE_FILE_LABEL = "Choose File…"

    # Upstream keeps the count of in-flight hash runs in an atomic in
    # src/collision.cr, shared by every window and by the toggle dialog. The
    # port keeps it on the class, behind a mutex, because the count is changed
    # from the worker threads' completion callbacks.
    class << self
      def lock = @lock ||= Mutex.new
      def pending = lock.synchronize { @pending.to_i }
      def pending? = pending.positive?
      def increase = lock.synchronize { @pending = @pending.to_i + 1 }
      def decrease = lock.synchronize { @pending = [@pending.to_i - 1, 0].max }
    end

    attr_reader :working

    def initialize(app)
      super(app)
      @hash_results = {}
      @queued_path = nil
      @working = false
    end

    def build
      tap do |win|
        win.title = "Collision"
        win.set_size_request(360, 360)
        win.content = drop_bin
        win.add_breakpoint(narrow_breakpoint)

        win.add_action(open_file_action)
        win.add_action(markdown_action)
        win.add_action(toggle_hashes_action)

        open_file_action.signal_connect("activate") { open_file_dialog }
        markdown_action.signal_connect("activate") { copy_markdown_table }
        toggle_hashes_action.signal_connect("activate") { toggle_hash_functions }

        drop_bin.tap do |bin|
          bin.child = overlay

          overlay.tap do |stack_overlay|
            stack_overlay.add_overlay(drop_revealer)
            stack_overlay.child = toolbar_view

            drop_revealer.child = drop_status_page

            toolbar_view.tap do |view|
              view.add_top_bar(header_bar)
              view.add_bottom_bar(switcher_bar)
              view.content = main_stack

              header_bar.tap do |bar|
                bar.pack_start(open_file_button)
                bar.title_widget = view_switcher
                bar.pack_end(menu_button)

                open_file_button.signal_connect("clicked") { open_file_dialog }
              end

              main_stack.tap do |stack|
                stack.add_controller(main_dnd)
                stack.add_named(welcome_page, "welcomer")
                stack.add_named(spinner_page, "spinner")
                stack.add_named(file_info, "results")

                welcome_page.tap do |page|
                  page.child = welcome_button
                  welcome_button.signal_connect("clicked") { open_file_dialog }
                end

                spinner_page.child = progress_clamp
                progress_clamp.child = progressbar

                file_info.child = results_clamp
                results_clamp.child = results_stack
              end
            end
          end
        end

        results_stack.tap do |stack|
          stack.add_titled_with_icon(
            hash_row_container,
            "hashes",
            "Hash",
            "octothorp-symbolic",
          )
          stack.add_titled_with_icon(
            tools_box,
            "verify",
            "Verify",
            "test-pass-symbolic",
          )

          hash_row_container.tap do |container|
            hash_rows.each_value { |row| container.append(row.build) }
          end

          tools_box.tap do |box|
            box.append(checksum_box)
            box.append(file_box)

            checksum_box.tap do |column|
              column.append(checksum_title)
              column.append(verify_overlay)

              verify_overlay.tap do |over|
                over.add_overlay(verify_feedback)
                over.add_overlay(verify_overlay_label)
                over.child = verify_scroller

                verify_scroller.child = verify_text_view
              end

              verify_text_view.buffer.signal_connect("notify::text") do |buffer|
                handle_input_change(buffer.text)
              end
            end

            file_box.tap do |column|
              column.append(file_title)
              column.append(compare_button)

              compare_button.tap do |button|
                button.add_controller(compare_dnd)
                button.child = compare_box
                button.signal_connect("clicked") { open_compare_dialog }

                compare_box.tap do |inner|
                  inner.append(compare_button_stack)
                  inner.append(compare_button_label)

                  compare_button_stack.tap do |stack_of_two|
                    stack_of_two.add_named(compare_button_image, "image")
                    stack_of_two.add_named(compare_spinner, "spinner")
                  end
                end
              end
            end
          end
        end

        main_dnd.tap do |target|
          target.signal_connect("enter") { on_main_drag_enter }
          target.signal_connect("leave") { drop_revealer.reveal_child = false }
          target.signal_connect("drop") { |_target, value| on_main_drop(value) }
        end

        compare_dnd.tap do |target|
          target.signal_connect("enter") { on_compare_drag_enter }
          target.signal_connect("leave") { drop_revealer.reveal_child = true }
          target.signal_connect("drop") { |_target, value| on_compare_drop(value) }
        end

        win.signal_connect("close-request") { on_close_request }
      end
    end

    # Hands the window a path to hash. Only one window hashes at a time, so a
    # path handed over while another run is in flight is held until it ends.
    def file=(filepath)
      if self.class.pending?
        @queued_path = filepath
      else
        start_hashing(filepath)
      end
    end

    # Starts the held-back file, if there is one. Called on every window when a
    # run finishes.
    def continue_queue
      unless @queued_path.nil?
        self.file = @queued_path
      end
    end

    # Switches to the progress page and clears the previous results.
    def loading
      progressbar.text = "Pending"
      progressbar.fraction = 0.0
      main_stack.visible_child_name = "spinner"
      markdown_action.enabled = false
      header_bar.show_title = false
      open_file_button.visible = false
      switcher_bar.visible = false
      reset_feedback
    end

    # Puts the verification tools back to their untouched state.
    def reset_feedback
      verify_text_view.buffer.text = ""
      compare_button_stack.visible_child_name = "image"
      compare_button_label.label = CHOOSE_FILE_LABEL
      compare_button.remove_css_class("success")
      compare_button.remove_css_class("error")
      compare_button_image.icon_name = "paper-symbolic"
      compare_button_image.tooltip_text = ""
    end

    # Shows whether the typed hash is one of the file's hashes.
    def handle_input_change(text)
      if text.empty?
        clear_verify_feedback
      else
        show_verify_feedback(@hash_results.value?(text.downcase.delete(" ")))
      end
    end

    # Hashes a second file and reports whether it matches the first one.
    def comparefile=(filepath)
      if FileUtils.file?(filepath)
        compare_button_stack.visible_child_name = "spinner"
        compare_button.remove_css_class("success")
        compare_button.remove_css_class("error")
        compare_button_label.label = File.basename(filepath)
        compare_button_label.tooltip_text = File.basename(filepath)
        spawn_comparison(filepath)
      end
    end

    # Copies the results as a Markdown table, as the menu item promises.
    def copy_markdown_table
      clipboard.set(markdown_table)
    end

    # The table the markdown action copies: one row per calculated hash, with
    # the columns padded so the table lines up as plain text too.
    def markdown_table
      @hash_results.keys.then do |types|
        labels = types.map { |type| Checksum::HASH_FUNCTIONS[type] }
        key_width = [labels.map(&:size).max.to_i, 3].max
        value_width = [@hash_results.values.map { |value| value.size + 2 }.max.to_i, 3].max

        [
          "|#{"CRF".center(key_width)}|#{"Value".center(value_width)}|",
          "|#{"-" * key_width}|#{"-" * value_width}|",
          *markdown_rows(key_width, value_width),
        ].join("\n")
      end
    end

    # Hides the rows of the hash functions that are switched off.
    def update_hashrow_visibility
      Settings.safe_disabled_hash_functions.then do |disabled|
        hash_rows.each do |type, row|
          row.visible = !disabled.include?(type)
        end
      end
    end

    # One row per hash function, in the order HASH_FUNCTIONS declares them.
    def hash_rows
      @hash_rows ||= Checksum::HASH_FUNCTIONS.to_h do |type, label|
        [type, HashRow.new(label, type.to_s) { |copied| copy_hash(copied) }]
      end
    end

    # Widgets — the tree of data/ui/application.ui, one method per object.

    def drop_bin
      @drop_bin ||= Adwaita::Bin.new.tap do |bin|
        bin.add_css_class("dropoverlay")
      end
    end

    def overlay = @overlay ||= Gtk::Overlay.new

    def drop_revealer
      @drop_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.can_target = false
        revealer.transition_type = :crossfade
        revealer.transition_duration = 600
      end
    end

    def drop_status_page
      @drop_status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = "Drop to hash"
        page.icon_name = "paper-symbolic"
        page.add_css_class("status")
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def open_file_button
      @open_file_button ||= Gtk::Button.new.tap do |button|
        button.visible = false
        button.child = open_button_content
        button.add_css_class("flat")
      end
    end

    def open_button_content
      @open_button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "document-open-symbolic"
        content.label = "_Open"
        content.tooltip_text = "Open…"
        content.use_underline = true
      end
    end

    def view_switcher
      @view_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
        switcher.policy = :wide
        switcher.stack = results_stack
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Main Menu"
        button.menu_model = PrimaryMenu.new.build
        button.primary = true
      end
    end

    def switcher_bar
      @switcher_bar ||= Adwaita::ViewSwitcherBar.new.tap do |bar|
        bar.stack = results_stack
        bar.visible = false
      end
    end

    def main_stack
      @main_stack ||= Gtk::Stack.new.tap do |stack|
        stack.add_css_class("no-drop")
      end
    end

    def welcome_page
      @welcome_page ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
        page.icon_name = "dev.geopjr.Collision"
        page.title = "Collision"
        page.description = "Check hashes for your files"
        page.add_css_class("icon-dropshadow")
      end
    end

    def welcome_button
      @welcome_button ||= Gtk::Button.new.tap do |button|
        button.halign = :center
        button.label = "_Open a File"
        button.use_underline = true
        button.add_css_class("suggested-action")
        button.add_css_class("pill")
      end
    end

    def spinner_page
      @spinner_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = "Calculating Hashes"
        page.description = "This might take a while"
      end
    end

    def progress_clamp
      @progress_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.tightening_threshold = 100
        clamp.maximum_size = 400
      end
    end

    def progressbar
      @progressbar ||= Gtk::ProgressBar.new.tap do |bar|
        bar.text = "Pending"
        bar.show_text = true
        bar.valign = :center
        bar.hexpand = true
        bar.vexpand = true
      end
    end

    def file_info
      @file_info ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
      end
    end

    def results_clamp
      @results_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.tightening_threshold = 100
      end
    end

    def results_stack
      @results_stack ||= Adwaita::ViewStack.new.tap do |stack|
        stack.vhomogeneous = false
        stack.hhomogeneous = false
      end
    end

    def hash_row_container
      @hash_row_container ||= Gtk::ListBox.new.tap do |list|
        list.halign = :center
        list.valign = :center
        list.add_css_class("content")
      end
    end

    def tools_box
      @tools_box ||= Gtk::Box.new(:horizontal, 45).tap do |box|
        box.homogeneous = true
      end
    end

    def checksum_box = @checksum_box ||= Gtk::Box.new(:vertical, 20)
    def file_box = @file_box ||= Gtk::Box.new(:vertical, 20)

    def checksum_title = @checksum_title ||= column_title("Checksum")
    def file_title = @file_title ||= column_title("File")

    def verify_overlay
      @verify_overlay ||= Gtk::Overlay.new.tap do |over|
        over.overflow = :hidden
      end
    end

    def verify_feedback
      @verify_feedback ||= Gtk::Image.new.tap do |image|
        image.pixel_size = 16
        image.icon_name = "test-pass-symbolic"
        image.halign = :end
        image.valign = :end
        image.margin_end = 5
        image.margin_bottom = 5
        image.sensitive = false
        image.visible = false
      end
    end

    def verify_overlay_label
      @verify_overlay_label ||= Gtk::Label.new(VERIFY_HINT).tap do |label|
        label.halign = :start
        label.valign = :start
        label.justify = :fill
        label.margin_end = 22
        label.margin_start = 14
        label.margin_top = 11
        label.wrap_mode = :char
        label.wrap = true
        label.sensitive = false
        label.add_css_class("monospace")
      end
    end

    def verify_scroller
      @verify_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.height_request = 125
      end
    end

    # Upstream sets css-name to "entry" so the text view is styled as one.
    # css-name is construct-only and the Ruby bindings expose no constructor
    # that takes it, so the entry look comes from the port's own
    # `.verify-entry` class in data/style.css instead.
    def verify_text_view
      @verify_text_view ||= Gtk::TextView.new.tap do |view|
        view.top_margin = 11
        view.bottom_margin = 11
        view.left_margin = 5
        view.right_margin = 5
        view.height_request = 125
        view.wrap_mode = :char
        view.accepts_tab = false
        view.input_purpose = :free_form
        view.input_hints = [:no_spellcheck, :no_emoji]
        view.tooltip_text = VERIFY_TOOLTIP
        view.add_css_class("verify-entry")
        view.add_css_class("card-like")
        view.add_css_class("monospace")
      end
    end

    def compare_button
      @compare_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = "Select Another File to Check Against"
        button.height_request = 125
        button.use_underline = true
        button.add_css_class("card-like")
      end
    end

    def compare_box
      @compare_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.valign = :center
      end
    end

    def compare_button_stack = @compare_button_stack ||= Gtk::Stack.new

    def compare_button_image
      @compare_button_image ||= Gtk::Image.new.tap do |image|
        image.pixel_size = 36
        image.icon_name = "paper-symbolic"
      end
    end

    def compare_spinner
      @compare_spinner ||= Adwaita::Spinner.new.tap do |spinner|
        spinner.valign = :center
        spinner.halign = :center
        spinner.hexpand = true
        spinner.vexpand = true
        spinner.width_request = 32
        spinner.height_request = 32
      end
    end

    def compare_button_label
      @compare_button_label ||= Gtk::Label.new(CHOOSE_FILE_LABEL).tap do |label|
        label.max_width_chars = 15
        label.ellipsize = :end
      end
    end

    def main_dnd
      @main_dnd ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)
    end

    def compare_dnd
      @compare_dnd ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)
    end

    # The breakpoint from the UI file: on a narrow window the title switcher
    # moves into the bottom bar and the two verification tools stack.
    def narrow_breakpoint
      @narrow_breakpoint ||= Adwaita::Breakpoint.new(narrow_condition).tap do |breakpoint|
        breakpoint.add_setter(header_bar, "title-widget", empty_widget_value)
        breakpoint.add_setter(switcher_bar, "reveal", true)
        breakpoint.add_setter(tools_box, "orientation", vertical_value)
        breakpoint.add_setter(tools_box, "spacing", 32)
      end
    end

    def narrow_condition
      @narrow_condition ||= Adwaita::BreakpointCondition.parse("max-width: 400sp")
    end

    # A breakpoint setter needs a real GValue for anything that is not a
    # plain boolean or number: Ruby's nil fails the binding's G_IS_VALUE
    # assertion and the setter is dropped, and a bare enum constant arrives as
    # a string, which aborts the process.
    def empty_widget_value = GLib::Value.new(Gtk::Widget.gtype)

    def vertical_value
      GLib::Value.new(Gtk::Orientation.gtype, Gtk::Orientation::VERTICAL)
    end

    def open_file_action = @open_file_action ||= Gio::SimpleAction.new("open-file", nil)

    def markdown_action
      @markdown_action ||= Gio::SimpleAction.new("markdown", nil).tap do |action|
        action.enabled = false
      end
    end

    def toggle_hashes_action
      @toggle_hashes_action ||= Gio::SimpleAction.new("toggle-hashes", nil)
    end

    private

      def column_title(text)
        Gtk::Label.new(text).tap do |label|
          label.wrap = true
          label.wrap_mode = :word_char
          label.justify = :center
          label.valign = :center
          label.vexpand = true
          label.add_css_class("title")
          label.add_css_class("title-1")
          label.add_css_class("compact-title")
        end
      end

      def start_hashing(filepath)
        @queued_path = nil
        self.class.increase
        @working = true
        file_info.title = File.basename(filepath)
        file_info.description = FileUtils.real_path(filepath).to_s
        Checksum.new.generate(filepath, progressbar) { |results| on_hashes(results) }
      end

      # A window hidden while it was hashing has nothing to show the results
      # on, so it only passes the queue along and goes away.
      def on_hashes(results)
        if visible?
          show_results(results)
        end

        finish_hashing
      end

      def show_results(results)
        @hash_results = results

        results.each do |type, value|
          hash_rows[type].subtitle = displayed_hash(value)
        end

        main_stack.visible_child_name = "results"
        markdown_action.enabled = true
        header_bar.show_title = true
        open_file_button.visible = true
        switcher_bar.visible = true
        update_hashrow_visibility
      end

      # Short checksums read better on one line; long ones are grouped into
      # fours so they wrap at predictable places.
      def displayed_hash(value)
        if value.size < 8
          value
        else
          Checksum.split_by_4(value)
        end
      end

      def finish_hashing
        @working = false
        self.class.decrease
        hand_on_queue

        unless visible?
          destroy
        end
      end

      def hand_on_queue
        unless application.nil?
          application.windows.each do |window|
            if window.is_a?(Window)
              window.continue_queue
            end
          end
        end
      end

      def copy_hash(hash_type)
        @hash_results[hash_type.to_sym].then do |value|
          unless value.nil?
            clipboard.set(value)
          end
        end
      end

      def markdown_rows(key_width, value_width)
        Checksum::HASH_FUNCTIONS.filter_map do |type, label|
          @hash_results[type].then do |value|
            unless value.nil?
              "|#{label.ljust(key_width)}|#{"`#{value}`".ljust(value_width)}|"
            end
          end
        end
      end

      def clear_verify_feedback
        verify_overlay_label.visible = true
        verify_feedback.visible = false
        verify_text_view.remove_css_class("success")
        verify_text_view.remove_css_class("error")
        verify_text_view.tooltip_text = VERIFY_TOOLTIP
      end

      def show_verify_feedback(matched)
        verify_overlay_label.visible = false
        verify_feedback.visible = true

        Feedback.css_classes(matched).then do |classes|
          verify_text_view.add_css_class(classes[:add])
          verify_text_view.remove_css_class(classes[:remove])
          verify_feedback.icon_name = Feedback.icon(matched)
          verify_feedback.add_css_class(classes[:add])
          verify_feedback.remove_css_class(classes[:remove])
        end

        Feedback.title(matched).tap do |title|
          verify_text_view.tooltip_text = title
          verify_text_view.announce(title, Gtk::AccessibleAnnouncementPriority::HIGH)
        end
      end

      # The comparison runs off the main loop: hashing the second file is as
      # slow as hashing the first one.
      def spawn_comparison(filepath)
        Thread.new do
          matched = compare(filepath)
          sleep(COMPARE_SETTLE_SECONDS)

          GLib::Idle.add do
            show_compare_feedback(matched)
            false
          end
        end
      end

      # The verification hash is the primary test; a small file that is not
      # itself the same bytes may still be a checksum listing that names one
      # of the hashes.
      def compare(filepath)
        calculated = Checksum.new.calculate(Checksum::VERIFICATION_HASH_FUNCTION, filepath)

        if @hash_results[Checksum::VERIFICATION_HASH_FUNCTION] == calculated
          true
        elsif File.size(filepath) < MAX_COMPARE_READ_SIZE
          FileUtils.compare_content(filepath, @hash_results.values)
        else
          false
        end
      end

      def show_compare_feedback(matched)
        compare_button_stack.visible_child_name = "image"
        compare_button_image.icon_name = Feedback.icon(matched)

        Feedback.css_classes(matched).then do |classes|
          compare_button.add_css_class(classes[:add])
          compare_button.remove_css_class(classes[:remove])
        end

        Feedback.title(matched).tap do |title|
          compare_button_image.tooltip_text = title
          compare_button.announce(title, Gtk::AccessibleAnnouncementPriority::HIGH)
        end
      end

      def toggle_hash_functions
        ToggleHashFunctionsDialog.new { self.class.pending? }.then do |dialog|
          dialog.build.present(self)
          dialog.signal_connect("closed") { update_hashrow_visibility }
        end
      end

      def file_dialog
        Gtk::FileDialog.new.tap do |dialog|
          dialog.title = "Choose a File"
          dialog.modal = true
        end
      end

      # The first file is hashed here; any others are opened as new windows,
      # the way upstream's open_files does.
      def open_file_dialog
        file_dialog.open_multiple(self, nil) do |dialog, result|
          chosen_files(dialog, result).then do |files|
            unless files.empty?
              loading
              self.file = files.shift.path
              open_extra_windows(files)
            end
          end
        end
      end

      def open_compare_dialog
        file_dialog.open(self, nil) do |dialog, result|
          begin
            dialog.open_finish(result).then do |file|
              unless file.nil?
                self.comparefile = file.path
              end
            end
          rescue StandardError => e
            warn("File dialog cancelled: #{e.message}")
          end
        end
      end

      def chosen_files(dialog, result)
        dialog.open_multiple_finish(result).then do |model|
          if model.nil?
            []
          else
            model.n_items.times.map { |index| model.get_item(index) }
          end
        end
      rescue StandardError => e
        warn("File dialog cancelled: #{e.message}")
        []
      end

      def open_extra_windows(files)
        files.each do |file|
          Window.new(application).build.then do |window|
            Settings.apply_to(window)
            window.present
            window.loading
            window.file = file.path
          end
        end
      end

      def on_main_drag_enter
        unless main_stack.visible_child_name == "spinner"
          drop_revealer.reveal_child = true
        end

        Gdk::DragAction::COPY
      end

      def on_compare_drag_enter
        drop_revealer.reveal_child = false
        Gdk::DragAction::COPY
      end

      def on_main_drop(value)
        drop_revealer.reveal_child = false

        if main_stack.visible_child_name == "spinner"
          false
        else
          accept_drop(value) do |file|
            loading
            self.file = file.path
          end
        end
      end

      def on_compare_drop(value)
        drop_revealer.reveal_child = false

        accept_drop(value) do |file|
          self.comparefile = file.path
        end
      end

      def accept_drop(value)
        dropped_file(value).then do |file|
          if file.nil?
            warn("No files starting with 'file://' given")
            false
          else
            yield(file)
            true
          end
        end
      end

      # The dropped value is a GdkFileList; the bindings hand it over either as
      # the boxed type or as the plain array of files it holds, so both shapes
      # are unpacked here.
      def dropped_file(value)
        files_in(value).find do |file|
          file.respond_to?(:uri) && file.uri.to_s.downcase.start_with?("file://")
        end
      end

      def files_in(value)
        if value.respond_to?(:files)
          value.files
        elsif value.is_a?(Array)
          value
        else
          [value]
        end
      end

      # A window still hashing is hidden rather than closed, so its results can
      # release the queue for the other windows; the last window closes for
      # real, otherwise the app would have nothing left to show.
      def on_close_request
        if working && application.windows.size > 1
          self.hide_on_close = true
        end

        Settings.save(self)
      end
  end
end

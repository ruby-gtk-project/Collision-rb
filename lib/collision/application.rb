# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "action"
require_relative "actions/about"
require_relative "actions/hash_info"
require_relative "actions/new_window"
require_relative "actions/quit"
require_relative "actions/shortcuts"
require_relative "checksum"
require_relative "file_utils"
require_relative "settings"
require_relative "window"

module Collision
  # Application wires the actions, the stylesheet and the icons together and
  # opens a window per file it is handed.
  #
  # Ported from upstream's src/collision.cr: the startup handler registers the
  # app actions and the window accelerators, the activate handler opens an
  # empty window, and the open handler opens one window per file — queuing the
  # extra ones, because only one window hashes at a time.
  #
  # Upstream ships its CSS and icons inside a GResource bundle compiled into
  # the binary. The port has no compile step to build one, so the same files
  # are loaded from the data/ directory next to lib/: the stylesheet through a
  # Gtk::CssProvider and the icons through the icon theme's search path.
  class Application
    DATA_DIR = File.expand_path("../../data", __dir__)
    STYLESHEET = File.join(DATA_DIR, "style.css")
    ICON_DIR = File.join(DATA_DIR, "icons")

    APPLICATION_ID = "dev.geopjr.Collision"

    # Accelerators for the actions that belong to the window rather than the
    # app, so they are bound here rather than by an Action subclass.
    WINDOW_ACCELS = {
      "win.open-file" => ["<Ctrl>O"],
      "window.close"  => ["<Ctrl>W"],
    }.freeze

    def build
      app.tap do |application|
        application.signal_connect("startup") { on_startup }
        application.signal_connect("activate") { activate_with_file }
        application.signal_connect("open") { |_app, files| open_with(files) }
      end
    end

    # Gio::Application#run reads the first element as the program name, so it
    # is passed explicitly and only the non-flag arguments follow it — the same
    # clean_argv upstream builds before calling run.
    def run(argv = ARGV)
      app.run([$PROGRAM_NAME, *argv.reject { |argument| argument.start_with?("-") }])
    end

    def app
      @app ||= Gtk::Application.new(APPLICATION_ID, :handles_open)
    end

    private

      def on_startup
        load_stylesheet
        load_icons

        Action::HashInfo.new(app)
        Action::About.new(app)
        Action::NewWindow.new(app)
        Action::Quit.new(app)
        Action::Shortcuts.new(app)

        WINDOW_ACCELS.each do |action, accels|
          app.set_accels_for_action(action, accels)
        end
      end

      # Creates a window, restores its geometry, and hands it a file if there
      # is one. Upstream's activate_with_file.
      def activate_with_file(file = nil)
        Window.new(app).build.tap do |window|
          Settings.apply_to(window)
          window.present

          unless file.nil?
            window.loading
            window.file = file.path
          end
        end
      end

      # Upstream's open_with: no files means a plain window, otherwise one
      # window per file that really is a file.
      def open_with(files)
        openable(files).then do |paths|
          if paths.empty?
            activate_with_file
          else
            paths.each { |file| activate_with_file(file) }
          end
        end
      end

      def openable(files)
        gio_files(files).select do |file|
          !file.path.nil? && FileUtils.file?(file.path)
        end
      end

      # The open signal hands over either a list model of files or a plain
      # array of them, depending on the bindings' conversion.
      def gio_files(files)
        if files.respond_to?(:n_items)
          files.n_items.times.map { |index| files.get_item(index) }
        else
          Array(files)
        end
      end

      def load_stylesheet
        if File.exist?(STYLESHEET)
          Gtk::CssProvider.new.tap do |provider|
            provider.load_from_path(STYLESHEET)
            Gtk::StyleContext.add_provider_for_display(
              Gdk::Display.default,
              provider,
              Gtk::StyleProvider::PRIORITY_APPLICATION,
            )
          end
        end
      end

      def load_icons
        if File.directory?(ICON_DIR)
          Gtk::IconTheme.get_for_display(Gdk::Display.default).add_search_path(ICON_DIR)
        end
      end
  end
end

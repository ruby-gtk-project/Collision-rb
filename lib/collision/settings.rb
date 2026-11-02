# frozen_string_literal: true

require "json"
require "fileutils"
require "adwaita"

module Collision
  # Settings holds the keys of upstream's GSettings schema.
  #
  # Ported from upstream's src/collision/functions/settings.cr plus
  # data/dev.geopjr.Collision.gschema.xml, whose schema is shipped unchanged in
  # this port's data/ directory.
  #
  # Upstream reads the schema through Gio::Settings and falls back to
  # DEFAULT_SETTINGS whenever the compiled schema is missing — which is what
  # happens in a dev build, or when a packager disables it. The port keeps both
  # halves: when the compiled schema is installed, Gio::Settings is used and
  # the values are shared with the Crystal build; when it is not, the same keys
  # are persisted to a small JSON file under XDG_CONFIG_HOME so running from a
  # checkout does not need an install step.
  module Settings
    extend self

    SCHEMA_ID = "dev.geopjr.Collision"

    DEFAULTS = {
      "window-width"            => 600,
      "window-height"           => 460,
      "is-maximized"            => false,
      "disabled-hash-functions" => [],
    }.freeze

    # Reads and writes the keys through the compiled GSettings schema.
    class GioBackend
      def initialize(schema_id)
        @settings = Gio::Settings.new(schema_id)
      end

      def [](key)
        case DEFAULTS.fetch(key)
        when Integer then @settings.get_int(key)
        when true, false then @settings.get_boolean(key)
        else @settings.get_strv(key)
        end
      end

      def []=(key, value)
        case DEFAULTS.fetch(key)
        when Integer then @settings.set_int(key, value)
        when true, false then @settings.set_boolean(key, value)
        else @settings.set_strv(key, Array(value))
        end
      end

      def location = "gsettings:#{SCHEMA_ID}"
    end

    # Reads and writes the keys through a JSON file.
    class JsonBackend
      def initialize(path)
        @path = path
        @values = DEFAULTS.merge(read)
      end

      def [](key) = @values.fetch(key, DEFAULTS.fetch(key))

      def []=(key, value)
        @values[key] = value
        write
      end

      def location = @path

      private

        def read
          if File.exist?(@path)
            JSON.parse(File.read(@path))
          else
            {}
          end
        rescue JSON::ParserError => e
          warn("Error parsing #{@path}: #{e.message}")
          {}
        end

        def write
          ::FileUtils.mkdir_p(File.dirname(@path))
          File.write(@path, JSON.pretty_generate(@values))
        end
    end

    # True when every key the app needs exists in the installed schema.
    # Upstream calls this Settings.available? and logs what is missing.
    def schema_available?
      Gio::SettingsSchemaSource.default.lookup(SCHEMA_ID, true).then do |schema|
        if schema.nil?
          false
        else
          DEFAULTS.keys.all? { |key| schema.has_key?(key) }
        end
      end
    end

    def backend
      @backend ||= begin
        if schema_available?
          GioBackend.new(SCHEMA_ID)
        else
          JsonBackend.new(default_path)
        end
      end
    end

    def [](key) = backend[key]

    def []=(key, value)
      backend[key] = value
      value
    end

    def window_width = self["window-width"]
    def window_height = self["window-height"]
    def window_maximized? = self["is-maximized"] == true
    def disabled_hash_functions = Array(self["disabled-hash-functions"])

    # Restores the geometry the previous run recorded.
    def apply_to(window)
      window.set_default_size(window_width, window_height)

      if window_maximized?
        window.maximize
      end
    end

    # Records the geometry on close. Returns false so the close request is not
    # swallowed, exactly as upstream's Settings.save does.
    def save(window)
      unless window.maximized?
        self["window-width"] = window.default_width
        self["window-height"] = window.default_height
      end

      self["is-maximized"] = window.maximized?
      false
    end

    # Stores the disabled hash functions and refreshes the cached symbols.
    def update_disabled_hash_functions(names)
      self["disabled-hash-functions"] = Array(names).map(&:to_s)
      @safe_disabled_hash_functions = nil
      safe_disabled_hash_functions
    end

    # The disabled hash functions as symbols, with the verification function
    # filtered out because it can never be disabled. Upstream caches this for
    # the same reason: it is read once per file per hash function.
    def safe_disabled_hash_functions
      @safe_disabled_hash_functions ||= disabled_hash_functions.then do |names|
        Checksum::HASH_FUNCTIONS.keys.select do |key|
          names.include?(key.to_s) && key != Checksum::VERIFICATION_HASH_FUNCTION
        end
      end
    end

    private

      def default_path
        File.join(
          ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
          "collision-rb",
          "settings.json",
        )
      end
  end
end

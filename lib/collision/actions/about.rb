# frozen_string_literal: true

require "adwaita"

require_relative "../action"
require_relative "../checksum"
require_relative "../file_utils"
require_relative "../i18n"
require_relative "../rb/version"
require_relative "../settings"

module Collision
  class Action
    # About presents the about dialog.
    #
    # Ported from upstream's src/collision/actions/about.cr. The troubleshooting
    # block upstream accumulates in src/collision.cr's TROUBLESHOOTING buffer is
    # assembled here instead, since the port has no debug log to copy into it.
    class About < Action
      include I18n

      OTHER_APPS = [
        ["dev.geopjr.Archives", N_("Archives"), N_("Create and view web archives")],
        ["dev.geopjr.Calligraphy", N_("Calligraphy"), N_("Turn text into ASCII banners")],
        ["dev.geopjr.Tuba", N_("Tuba"), N_("Browse the Fediverse")],
        ["dev.geopjr.Turntable", N_("Turntable"), N_("Scrobble your music")],
      ].freeze

      TRANSLATOR_CREDITS = N_("translator-credits")

      def initialize(app)
        super(app, "about", ["F1"])
      end

      def on_activate
        dialog.tap do |about|
          OTHER_APPS.each do |id, name, description|
            about.add_other_app(id, _(name), _(description))
          end

          about.present(app.active_window)
        end
      end

      private

        def dialog
          Adwaita::AboutDialog.new.tap do |about|
            about.application_name = _("Collision")
            about.application_icon = "dev.geopjr.Collision"
            about.version = Collision::Rb::VERSION
            about.copyright = "© 2021 Evangelos Paterakis"
            about.website = "https://collision.geopjr.dev"
            about.issue_url = "https://codeberg.org/Collision/issues"
            about.developer_name = "Evangelos \"GeopJr\" Paterakis"
            about.artists = ["Tobias Bernard"]
            about.designers = ["Tobias Bernard"]
            about.translator_credits = translator_credits
            about.license_type = Gtk::License::BSD
            about.debug_info = troubleshooting
            about.debug_info_filename = "Collision-#{(Time.now.to_f * 1000).to_i}.txt"
          end
        end

        # The names the catalogue's translators put in. An untranslated
        # catalogue leaves the msgid itself, which is not a name, so it is
        # dropped rather than shown.
        def translator_credits
          _(TRANSLATOR_CREDITS).then do |credits|
            if credits == TRANSLATOR_CREDITS
              ""
            else
              credits
            end
          end
        end

        def troubleshooting
          <<~DEBUG
            flatpak: #{FileUtils.flatpak?}
            version: #{Collision::Rb::VERSION}
            ruby: #{RUBY_VERSION}
            gtk: #{Gtk::Version::STRING}
            libadwaita: #{Adwaita::VERSION_S}
            settings: #{Settings.backend.location}
            hash functions: #{Checksum::HASH_FUNCTIONS.values.join(", ")}
          DEBUG
        end
    end
  end
end

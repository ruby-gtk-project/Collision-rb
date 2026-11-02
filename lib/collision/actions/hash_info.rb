# frozen_string_literal: true

require "adwaita"

require_relative "../action"
require_relative "../i18n"

module Collision
  class Action
    # HashInfo opens the Wikipedia comparison of cryptographic hash functions
    # in the user's browser.
    #
    # Ported from upstream's src/collision/actions/hashinfo.cr; the URL is
    # upstream's ARTICLE constant from src/collision.cr.
    class HashInfo < Action
      include I18n

      # Translatable, so a locale can point at its own Wikipedia. Upstream's
      # comment to translators reads: "Wikipedia article. If available, set it
      # to the LANGUAGE's version, else leave it as is."
      ARTICLE = N_("https://en.wikipedia.org/wiki/Comparison_of_cryptographic_hash_functions")

      def initialize(app)
        super(app, "hashinfo")
      end

      def article = _(ARTICLE)

      def on_activate
        Gio::AppInfo.launch_default_for_uri(article, nil)
      rescue StandardError => e
        warn("Could not open #{article}: #{e.message}")
      end
    end
  end
end

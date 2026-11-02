# frozen_string_literal: true

require "adwaita"

require_relative "../action"

module Collision
  class Action
    # HashInfo opens the Wikipedia comparison of cryptographic hash functions
    # in the user's browser.
    #
    # Ported from upstream's src/collision/actions/hashinfo.cr; the URL is
    # upstream's ARTICLE constant from src/collision.cr.
    class HashInfo < Action
      ARTICLE = "https://en.wikipedia.org/wiki/Comparison_of_cryptographic_hash_functions"

      def initialize(app)
        super(app, "hashinfo")
      end

      def on_activate
        Gio::AppInfo.launch_default_for_uri(ARTICLE, nil)
      rescue StandardError => e
        warn("Could not open #{ARTICLE}: #{e.message}")
      end
    end
  end
end

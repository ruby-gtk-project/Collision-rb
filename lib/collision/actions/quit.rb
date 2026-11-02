# frozen_string_literal: true

require "adwaita"

require_relative "../action"

module Collision
  class Action
    # Quit closes the application.
    #
    # Ported from upstream's src/collision/actions/quit.cr.
    class Quit < Action
      def initialize(app)
        super(app, "quit", ["<Ctrl>Q"])
      end

      def on_activate
        app.quit
      end
    end
  end
end

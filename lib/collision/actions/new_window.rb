# frozen_string_literal: true

require "adwaita"

require_relative "../action"

module Collision
  class Action
    # NewWindow opens another window on the same application.
    #
    # Ported from upstream's src/collision/actions/new_window.cr: it activates
    # the application again, and the activate handler is what builds a window.
    class NewWindow < Action
      def initialize(app)
        super(app, "new-window", ["<Ctrl>N"])
      end

      def on_activate
        app.activate
      end
    end
  end
end

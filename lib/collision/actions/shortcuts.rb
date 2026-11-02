# frozen_string_literal: true

require "adwaita"

require_relative "../action"
require_relative "../shortcuts_dialog"

module Collision
  class Action
    # Shortcuts presents the keyboard shortcuts dialog.
    #
    # Upstream has no action file of its own for this: the dialog is
    # data/ui/shortcuts-dialog.ui and the `app.shortcuts` action that the
    # primary menu and the dialog itself reference comes from the Crystal
    # binary's generated action set. The port registers it the same way as
    # every other app action.
    class Shortcuts < Action
      def initialize(app)
        super(app, "shortcuts", ["<Ctrl>question"])
      end

      def on_activate
        ShortcutsDialog.new.build.present(app.active_window)
      end
    end
  end
end

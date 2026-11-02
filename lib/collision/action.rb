# frozen_string_literal: true

require "adwaita"

module Collision
  # Action is the base class for the app-wide actions.
  #
  # Ported from upstream's src/collision/actions.cr: constructing one registers
  # a Gio::SimpleAction on the application under `app.<name>`, binds its
  # accelerators, and routes its activation to the subclass's `on_activate`.
  class Action
    attr_reader :app, :name

    def initialize(app, name, accels = nil)
      @app = app
      @name = name

      Gio::SimpleAction.new(name, nil).tap do |action|
        action.signal_connect("activate") { on_activate }
        app.add_action(action)
      end

      unless accels.nil? || accels.empty?
        app.set_accels_for_action("app.#{name}", accels)
      end
    end
  end
end

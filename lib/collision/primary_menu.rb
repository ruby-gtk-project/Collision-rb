# frozen_string_literal: true

require "adwaita"

require_relative "i18n"

module Collision
  # PrimaryMenu is the model behind the header bar's menu button.
  #
  # Ported from the `primary-menu` menu in upstream's data/ui/application.ui.
  # The "Copy as Markdown Table" item carries the same `hidden-when`
  # attribute, so it disappears while the window's markdown action is disabled
  # — which is whenever no hashes have been calculated yet.
  class PrimaryMenu
    include I18n

    ITEMS = [
      [N_("_New Window"), "app.new-window"],
      [N_("_Compare Hash Functions"), "app.hashinfo"],
      [N_("Copy as _Markdown Table"), "win.markdown"],
      [N_("_Toggle Hash Functions"), "win.toggle-hashes"],
      [N_("_Keyboard Shortcuts"), "app.shortcuts"],
      [N_("_About Collision"), "app.about"],
    ].freeze

    HIDDEN_WHEN_DISABLED = ["win.markdown"].freeze

    def build
      menu.tap do |model|
        ITEMS.each do |label, action|
          model.append_item(item(_(label), action))
        end
      end
    end

    def menu = @menu ||= Gio::Menu.new

    private

      def item(label, action)
        Gio::MenuItem.new(label, action).tap do |entry|
          if HIDDEN_WHEN_DISABLED.include?(action)
            entry.set_attribute_value("hidden-when", GLib::Variant.new("action-disabled"))
          end
        end
      end
  end
end

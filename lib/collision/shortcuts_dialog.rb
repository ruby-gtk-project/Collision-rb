# frozen_string_literal: true

require "adwaita"

require_relative "i18n"

module Collision
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's data/ui/shortcuts-dialog.ui: one "General" section
  # whose items name the actions rather than the accelerators, so the dialog
  # shows whatever the application has bound to them. Adwaita::ShortcutsItem in
  # the Ruby bindings takes its title and accelerator positionally, so the
  # accelerators this port binds are listed next to each action.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include I18n

    SECTIONS = {
      N_("General") => [
        [N_("Open a File"), "<Control>o"],
        [N_("Show Keyboard Shortcuts"), "<Control>question"],
        [N_("New Window"), "<Control>n"],
        [N_("Close Window"), "<Control>w"],
        [N_("Quit"), "<Control>q"],
      ],
    }.freeze

    def initialize
      super()
      # The underlined menu label with its mnemonic stripped, so the
      # dialog does not introduce a second string to translate — the
      # trick upstream's toggle dialog uses for its own title.
      self.title = _("_Keyboard Shortcuts").delete("_")
    end

    def build
      tap do |dialog|
        SECTIONS.each do |title, items|
          dialog.add(section(_(title), items))
        end
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = title
          items.each { |label, accelerator| group.add(item(_(label), accelerator)) }
        end
      end

      # Positional, not keyword, arguments — the Ruby bindings advertise
      # "title: utf8, accelerator: utf8" but only accept them positionally.
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end

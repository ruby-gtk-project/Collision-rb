# frozen_string_literal: true

require "adwaita"

module Collision
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's data/ui/shortcuts-dialog.ui: one "General" section
  # whose items name the actions rather than the accelerators, so the dialog
  # shows whatever the application has bound to them. Adwaita::ShortcutsItem in
  # the Ruby bindings takes its title and accelerator positionally, so the
  # accelerators this port binds are listed next to each action.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      "General" => [
        ["Open a File", "<Control>o"],
        ["Show Keyboard Shortcuts", "<Control>question"],
        ["New Window", "<Control>n"],
        ["Close Window", "<Control>w"],
        ["Quit", "<Control>q"],
      ],
    }.freeze

    def initialize
      super()
      self.title = "Keyboard Shortcuts"
    end

    def build
      tap do |dialog|
        SECTIONS.each do |title, items|
          dialog.add(section(title, items))
        end
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = title
          items.each { |label, accelerator| group.add(item(label, accelerator)) }
        end
      end

      # Positional, not keyword, arguments — the Ruby bindings advertise
      # "title: utf8, accelerator: utf8" but only accept them positionally.
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end

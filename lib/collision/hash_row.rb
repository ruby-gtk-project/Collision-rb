# frozen_string_literal: true

require "adwaita"

require_relative "feedback"
require_relative "i18n"

module Collision
  # HashRow shows one hash function's name and its value, with a button that
  # copies the value.
  #
  # Ported from upstream's src/collision/widgets/hash_row.cr and
  # data/ui/hash_row.ui. Upstream declares a `clicked(hash_type)` signal that
  # the window connects to; the port takes the same callback as a block on the
  # constructor.
  class HashRow < Adwaita::ActionRow
    include I18n

    # Long enough that the copy feedback registers, short enough that the
    # button is usable again straight away — upstream's comment reads "1 feels
    # fast, 1.5 feels slow".
    FEEDBACK_DURATION = 1100

    COPY_ICON = "edit-copy-symbolic"

    attr_reader :hash_type

    def initialize(hash_name, hash_type, &on_copy)
      super()
      @hash_type = hash_type
      @on_copy = on_copy
      @copy_locked = false
      self.title = hash_name
      self.selectable = false
      self.subtitle_lines = 100
      add_css_class("hash-row")
    end

    def build
      tap do |row|
        row.add_suffix(copy_button)

        copy_button.tap do |button|
          button.signal_connect("clicked") { on_copy_clicked }
        end
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = COPY_ICON
        button.tooltip_text = _("Copy")
        button.valign = :center
        button.add_css_class("circular")
      end
    end

    private

      # The button shows its success icon for FEEDBACK_DURATION and ignores
      # further clicks until it has changed back, so a held-down button cannot
      # stack up timeouts.
      def on_copy_clicked
        unless @copy_locked
          @copy_locked = true
          @on_copy&.call(hash_type)
          Feedback.css_classes(true).then do |classes|
            copy_button.icon_name = Feedback.icon(true)
            copy_button.add_css_class(classes[:add])
            GLib::Timeout.add(FEEDBACK_DURATION) { reset_copy_button(classes[:add]) }
          end
        end
      end

      def reset_copy_button(feedback_class)
        copy_button.icon_name = COPY_ICON
        copy_button.remove_css_class(feedback_class)
        @copy_locked = false
        false
      end
  end
end

# frozen_string_literal: true

require "adwaita"

require_relative "checksum"
require_relative "i18n"
require_relative "settings"

module Collision
  # ToggleHashFunctionsDialog switches individual hash functions on and off.
  #
  # Ported from upstream's src/collision/widgets/toggle_hash_functions_dialog.cr.
  # The dialog cannot be closed directly: its close attempt is intercepted so
  # the new selection is written to the settings first, and refused outright
  # while hashes are still being calculated, because the window would then
  # display rows for functions it is no longer calculating.
  class ToggleHashFunctionsDialog < Adwaita::PreferencesDialog
    include I18n

    VERIFICATION_SUBTITLE =
      N_("This hash function is used for file verification and cannot be disabled")

    # Asked before the dialog closes; a truthy answer refuses the close.
    def initialize(&busy)
      super()
      @busy = busy
      @rows = {}
      self.can_close = false
      self.title = _("_Toggle Hash Functions").delete("_")
    end

    def build
      tap do |dialog|
        page.tap do |group_page|
          group_page.add(group)

          group.tap do |rows|
            Checksum::HASH_FUNCTIONS.each do |type, label|
              rows.add(row(type, label))
            end
          end
        end

        dialog.add(page)
        dialog.signal_connect("close-attempt") { on_close_attempt }
      end
    end

    def page
      @page ||= Adwaita::PreferencesPage.new.tap do |group_page|
        group_page.description = _("Select which hash functions should be calculated.")
      end
    end

    def group = @group ||= Adwaita::PreferencesGroup.new

    private

      def row(type, label)
        Adwaita::SwitchRow.new.tap do |switch|
          switch.title = label
          switch.active = !Settings.safe_disabled_hash_functions.include?(type)

          if type == Checksum::VERIFICATION_HASH_FUNCTION
            switch.sensitive = false
            switch.active = true
            switch.subtitle = _(VERIFICATION_SUBTITLE)
          end

          @rows[type] = switch
        end
      end

      def on_close_attempt
        disabled.then do |selection|
          if selection.sort == Settings.safe_disabled_hash_functions.sort
            force_close
          elsif @busy&.call
            add_toast(Adwaita::Toast.new(_("Wait for all ongoing operations to finish")))
          else
            Settings.update_disabled_hash_functions(selection.map(&:to_s))
            force_close
          end
        end
      end

      def disabled
        @rows.reject { |_type, switch| switch.active? }.keys
      end
  end
end

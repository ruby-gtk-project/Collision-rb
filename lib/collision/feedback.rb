# frozen_string_literal: true

module Collision
  # Feedback names the icon, style classes and title that say whether a
  # comparison succeeded.
  #
  # Ported from upstream's src/collision/functions/feedback.cr. Upstream's
  # method is called Feedback.class; naming a method `class` in Ruby would
  # shadow Object#class on the module itself, so it is `css_classes` here.
  module Feedback
    extend self

    CLASSES = %w[success error].freeze

    def icon(success = false)
      if success
        "test-pass-symbolic"
      else
        "cross-large-symbolic"
      end
    end

    # The style class to add and the one to take off, so a widget can be
    # flipped from one state to the other without tracking which it was in.
    def css_classes(success = false)
      if success
        {add: CLASSES.first, remove: CLASSES.last}
      else
        {add: CLASSES.last, remove: CLASSES.first}
      end
    end

    def title(success = false)
      if success
        "They Match"
      else
        "They Don't Match"
      end
    end
  end
end

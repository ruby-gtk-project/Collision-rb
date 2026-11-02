# frozen_string_literal: true

# Ported from upstream's spec/feedback_spec.cr.
#
# Upstream's second example calls Feedback.class; the port names that method
# css_classes, because `class` on a Ruby module would shadow Object#class.
RSpec.describe Collision::Feedback do
  describe ".icon" do
    it "returns the correct symbolic icon for feedback based on whether or not the task was successful" do
      expect([described_class.icon(true), described_class.icon]).to eq(
        ["test-pass-symbolic", "cross-large-symbolic"],
      )
    end
  end

  describe ".css_classes" do
    it "returns the correct class to add and remove for feedback based on whether or not the task was successful" do
      expect([described_class.css_classes(true), described_class.css_classes]).to eq(
        [{add: "success", remove: "error"}, {add: "error", remove: "success"}],
      )
    end
  end

  describe ".title" do
    it "returns the verdict the verify page shows for each outcome" do
      expect([described_class.title(true), described_class.title]).to eq(
        ["They Match", "They Don't Match"],
      )
    end
  end
end

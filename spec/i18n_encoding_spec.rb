# frozen_string_literal: true

require "open3"
require "rbconfig"

# Regression coverage for lib/collision/i18n.rb's catalogue reader, for the
# class of bug spec/i18n_spec.rb's `with_environment` helper cannot see: that
# helper mutates ENV *after* this RSpec process has already booted, and
# Encoding.default_external is fixed once, at process start, from the
# environment the process inherited at boot. By the time an example flips
# LANG/LC_ALL/LC_MESSAGES, Ruby has long since decided
# Encoding.default_external is UTF-8 (RSpec's own runner boots under a UTF-8
# locale), so that helper can never reproduce a process that actually boots
# with no locale set at all.
#
# This spec instead shells out to a brand new Ruby process with
# LANG/LC_ALL/LC_MESSAGES/LANGUAGE all unset, which is exactly the
# environment a minimal container, a cron job, or a stripped-down CI runner
# gives a process. Under that environment Encoding.default_external falls
# back to US-ASCII, and lib/collision/i18n.rb's catalogue reader must not
# crash loading a UTF-8 .po file.
RSpec.describe "Collision::I18n booted with no locale environment at all" do
  def run_in_clean_process(script, env)
    ruby = RbConfig.ruby
    lib = File.expand_path("../lib", __dir__)

    Open3.capture3(
      env,
      ruby,
      "-I",
      lib,
      "-e",
      script,
    )
  end

  it "falls back to the string itself instead of raising Encoding::CompatibilityError" do
    env = {"LANG" => nil, "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANGUAGE" => nil}
    script = <<~RUBY
      require "collision/i18n"
      print Collision::I18n._("Pending")
    RUBY

    stdout, stderr, status = run_in_clean_process(script, env)

    expect(status).to be_success, "expected the catalogue load to succeed, got:\n#{stderr}"
    expect(stdout).to eq("Pending")
  end

  it "still translates once a language is requested, even with no locale otherwise set" do
    env = {"LANG" => nil, "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANGUAGE" => "fr"}
    script = <<~RUBY
      require "collision/i18n"
      print Collision::I18n._("Pending")
    RUBY

    stdout, stderr, status = run_in_clean_process(script, env)

    expect(status).to be_success, "expected the catalogue load to succeed, got:\n#{stderr}"
    expect(stdout).to eq("En attente")
  end
end

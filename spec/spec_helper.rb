# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  unless error.message.include?("kettle")
    raise error
  end
end

# External RSpec & related config
#
# The suite is plain RSpec and the Nix dev shell carries only rspec, because
# the GTK gems are not installable from the development bundle. kettle-test is
# therefore optional: when it is present its harness helpers (documented in
# spec/README.md) are installed, and when it is not the suite still runs.
begin
  require "kettle/test/rspec"
rescue LoadError => error
  unless error.message.include?("kettle")
    raise error
  end
end

# This library. Loading it pulls in GTK, which needs a display to initialise,
# so the suite is run through xvfb-run — see the dev shell's banner.
require "collision"

# Fixtures and expected values shared by the specs, ported from the Collision
# module upstream's spec/spec_helper.cr defines.
module Collision
  # Values the specs assert against, kept out of the library namespace proper.
  module Spec
    # The file every hash below was taken over. Upstream's copy says "DO NOT
    # MODIFY" for the same reason: the expectations are hard-coded.
    FIXTURE = File.join(__dir__, "test.txt")

    # A checksum file naming FIXTURE's SHA-256, as sha256sum would write it.
    FIXTURE_CONTENT = File.join(__dir__, "test_content.txt")

    # Every hash function the port implements, over FIXTURE. Upstream calls
    # this CLIPBOARD_HASH and also lists Blake3, which this port does not
    # calculate.
    CLIPBOARD_HASH = {
      md5:     "f7e3f382f0382147661c82af20e274e8",
      sha1:    "c8f0b71214e8164aa69419b7ac0bcd8a74f529a6",
      sha256:  "08e3dfc089e66c44ae8abd3476b0f810f11f4cfc2ab925f1607c7df21345d639",
      sha512:  "2ddb9cca7753a01fcbcdbacc228ae8c314ff4e735c6fffb42286272fb460930d" \
               "c74f122a9f365053a13016b22403ad4e192142e8668bc5f7d6fce865eb38ec2c",
      crc32:   "592339ec",
      adler32: "1ba80397",
    }.freeze
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

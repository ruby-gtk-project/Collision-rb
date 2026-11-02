# frozen_string_literal: true

# Ported from upstream's spec/hash_generator_spec.cr.
#
# Upstream spawns one fiber per hash function and busy-waits for the results;
# the port's Checksum#generate owns that fan-out, so the generate example below
# drives it the way the window does — through a GLib main loop, because the
# finished hashes are handed back with GLib::Idle.add.
RSpec.describe Collision::Checksum do
  let(:path) { Collision::Spec::FIXTURE }
  let(:expected) { Collision::Spec::CLIPBOARD_HASH }

  # Long enough that a loaded machine does not fail the example, short enough
  # that a hang is still a failure rather than a stuck suite.
  GENERATE_TIMEOUT_SECONDS = 30

  describe "#calculate" do
    it "gets hashes from file" do
      calculated = described_class::HASH_FUNCTIONS.keys.to_h do |type|
        [type, described_class.new.calculate(type, path)]
      end

      expect(calculated).to eq(expected)
    end

    it "offers exactly the hash functions it can calculate" do
      expect(described_class::HASH_FUNCTIONS.keys).to eq(expected.keys)
    end

    it "refuses a hash function it has no digest for" do
      expect { described_class.new.calculate(:blake3, path) }
        .to raise_error(ArgumentError, /blake3/)
    end
  end

  describe "#enabled_hash_functions" do
    it "drops the hash functions the settings switched off" do
      allow(Collision::Settings).to receive(:safe_disabled_hash_functions).and_return([:md5, :crc32])

      expect(described_class.new.enabled_hash_functions).to eq(expected.keys - [:md5, :crc32])
    end
  end

  describe "#generate" do
    it "calculates every enabled hash function and reports back on the main loop" do
      allow(Collision::Settings).to receive(:safe_disabled_hash_functions).and_return([])

      expect(run_generate(path)).to eq(expected)
    end

    it "honours the disabled hash functions and keeps the display order" do
      allow(Collision::Settings).to receive(:safe_disabled_hash_functions).and_return([:sha1, :sha512])

      expect(run_generate(path)).to eq(expected.reject { |type, _| [:sha1, :sha512].include?(type) })
    end

    it "steps the progress bar to full and names the count" do
      allow(Collision::Settings).to receive(:safe_disabled_hash_functions).and_return([])
      progressbar = Gtk::ProgressBar.new

      run_generate(path, progressbar)

      expect([progressbar.fraction, progressbar.text]).to eq(
        [1.0, format(described_class::PROGRESS_FORMAT, expected.size, expected.size)],
      )
    end
  end

  describe ".split_by_4" do
    it "splits strings by 4" do
      input_by_4 = "Wait ingf orso meth ingt ohap pen?"

      expect(described_class.split_by_4(input_by_4.split(" ").join)).to eq(input_by_4)
    end

    it "leaves a string shorter than a block alone" do
      expect(described_class.split_by_4("abc")).to eq("abc")
    end
  end

  # Runs Checksum#generate under a main loop and returns what it handed back,
  # draining the idle callbacks the progress reports queued on the way.
  def run_generate(filename, progressbar = nil)
    main_loop = GLib::MainLoop.new
    result = nil

    GLib::Timeout.add_seconds(GENERATE_TIMEOUT_SECONDS) do
      main_loop.quit
      false
    end

    described_class.new.generate(filename, progressbar) do |hashes|
      result = hashes
      GLib::Idle.add do
        main_loop.quit
        false
      end
      false
    end

    main_loop.run
    result
  end
end

# frozen_string_literal: true

require "tempfile"

# Ported from upstream's spec/compare_spec.cr, which covers compare_content
# only; the other two FileUtils answers are exercised here as well because the
# window asks them of every path it is handed.
RSpec.describe Collision::FileUtils do
  let(:fixture) { Collision::Spec::FIXTURE }
  let(:fixture_content) { Collision::Spec::FIXTURE_CONTENT }
  let(:hashes) { Collision::Spec::CLIPBOARD_HASH.values }

  describe ".compare_content" do
    it "returns whether the file contains one of the hashes" do
      expect(described_class.compare_content(fixture_content, hashes)).to be(true)
    end

    it "returns false when the file names none of the hashes" do
      expect(described_class.compare_content(fixture, hashes)).to be(false)
    end

    it "matches a hash the file spells in upper case" do
      Tempfile.create("collision-compare") do |file|
        file.puts("#{Collision::Spec::CLIPBOARD_HASH.fetch(:sha256).upcase}  ./test.txt")
        file.flush

        expect(described_class.compare_content(file.path, hashes)).to be(true)
      end
    end
  end

  describe ".file?" do
    it "is true for an existing regular file" do
      expect(described_class.file?(fixture)).to be(true)
    end

    it "is false for a directory" do
      expect(described_class.file?(__dir__)).to be(false)
    end

    it "is false for a path that does not exist" do
      expect(described_class.file?(File.join(__dir__, "no-such-file.txt"))).to be(false)
    end
  end

  describe ".real_path" do
    it "is the containing directory outside a Flatpak sandbox" do
      allow(described_class).to receive(:flatpak?).and_return(false)

      expect(described_class.real_path(fixture)).to eq(__dir__)
    end

    it "is nil for a document-portal path inside a Flatpak sandbox" do
      allow(described_class).to receive(:flatpak?).and_return(true)

      expect(described_class.real_path("/run/user/1000/doc/abcd1234/test.txt")).to be_nil
    end

    it "is the containing directory for a host path inside a Flatpak sandbox" do
      allow(described_class).to receive(:flatpak?).and_return(true)

      expect(described_class.real_path(fixture)).to eq(__dir__)
    end
  end
end

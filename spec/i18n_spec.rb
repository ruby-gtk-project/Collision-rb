# frozen_string_literal: true

require "tempfile"

# Covers lib/collision/i18n.rb, which has no upstream counterpart: upstream
# leaves the catalogue lookup to the C gettext library, so there was nothing
# to port and nothing upstream tests. The port reads the .po files itself, so
# the reading is tested here, along with the catalogues in po/.
RSpec.describe Collision::I18n do
  # Parsing and language selection are below the public surface on purpose —
  # nothing but `_` should reach them from the app — so they are exercised
  # through send rather than being made public for the specs.
  def parse(source)
    Tempfile.create(["catalogue", ".po"]) do |file|
      file.write(source)
      file.flush

      described_class.send(:parse, file.path)
    end
  end

  # The module memoizes its catalogue for the life of the process, which is
  # right for an app whose locale cannot change and wrong for a suite that
  # looks at several, so each example that touches the environment puts both
  # back.
  def with_environment(values)
    originals = values.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
    memoized = described_class.instance_variable_get(:@catalogue)

    values.each { |name, value| ENV[name] = value }
    described_class.instance_variable_set(:@catalogue, nil)

    yield
  ensure
    originals.each { |name, value| ENV[name] = value }
    described_class.instance_variable_set(:@catalogue, memoized)
  end

  describe "._" do
    it "falls back to the string itself when the locale has no catalogue" do
      with_environment("LANGUAGE" => "zz", "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => nil) do
        expect(described_class._("Pending")).to eq("Pending")
      end
    end

    it "translates against the catalogue of the requested language" do
      with_environment("LANGUAGE" => "fr", "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => nil) do
        expect(described_class._("Pending")).to eq("En attente")
      end
    end

    it "falls back to the string itself for an entry the catalogue leaves fuzzy" do
      with_environment("LANGUAGE" => "fr", "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => nil) do
        expect(described_class._("Main Menu")).to eq("Main Menu")
      end
    end
  end

  describe ".N_" do
    it "hands the string straight back, so it is only marked for extraction" do
      expect(described_class.N_("Pending")).to eq("Pending")
    end
  end

  describe ".languages" do
    it "offers the bare language after the territory, most specific first" do
      with_environment("LANGUAGE" => nil, "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => "pt_BR.UTF-8") do
        expect(described_class.languages).to eq(["pt_BR", "pt"])
      end
    end

    it "reads every language LANGUAGE lists, and the more specific variables first" do
      with_environment("LANGUAGE" => "ka:kab", "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => "el_GR.UTF-8") do
        expect(described_class.languages).to eq(["ka", "kab", "el_GR", "el"])
      end
    end

    it "drops the locales that mean no translation" do
      with_environment("LANGUAGE" => nil, "LC_ALL" => "C", "LC_MESSAGES" => nil, "LANG" => "POSIX") do
        expect(described_class.languages).to be_empty
      end
    end

    it "drops a modifier and a codeset" do
      with_environment("LANGUAGE" => nil, "LC_ALL" => nil, "LC_MESSAGES" => nil, "LANG" => "sr_RS.UTF-8@latin") do
        expect(described_class.languages).to eq(["sr_RS", "sr"])
      end
    end
  end

  describe "the PO reader" do
    it "reads a plain entry" do
      expect(parse(<<~PO)).to eq({"Pending" => "En attente"})
        msgid "Pending"
        msgstr "En attente"
      PO
    end

    it "joins the continuation lines of a wrapped entry" do
      expect(parse(<<~PO)).to eq({"Check hashes for your files" => "Vérifiez les sommes de vos fichiers"})
        msgid ""
        "Check hashes "
        "for your files"
        msgstr ""
        "Vérifiez les sommes "
        "de vos fichiers"
      PO
    end

    it "skips the header, whose msgid is empty" do
      expect(parse(<<~PO)).to be_empty
        msgid ""
        msgstr ""
        "Content-Type: text/plain; charset=UTF-8\\n"
      PO
    end

    it "skips an entry nobody has translated yet" do
      expect(parse(<<~PO)).to eq({"Verify" => "Vérifier"})
        msgid "Pending"
        msgstr ""

        msgid "Verify"
        msgstr "Vérifier"
      PO
    end

    it "skips a fuzzy entry, which is a guess rather than a translation" do
      expect(parse(<<~PO)).to eq({"Verify" => "Vérifier"})
        #, fuzzy
        #| msgid "Menu"
        msgid "Main Menu"
        msgstr "Menu"

        msgid "Verify"
        msgstr "Vérifier"
      PO
    end

    it "keeps an entry whose other flags are not fuzzy" do
      expect(parse(<<~PO)).to eq({"%d of %d hashes calculated" => "%d sur %d sommes calculées"})
        #. The variables are numbers
        #: lib/collision/checksum.rb:52
        #, c-format
        msgid "%d of %d hashes calculated"
        msgstr "%d sur %d sommes calculées"
      PO
    end

    it "unescapes the sequences a PO string can carry" do
      expect(parse(%(msgid "They Don't Match"\nmsgstr "a\\tb\\nc\\"d\\\\e"\n)))
        .to eq({"They Don't Match" => "a\tb\nc\"d\\e"})
    end

    it "ignores the obsolete entries msgmerge comments out" do
      expect(parse(<<~PO)).to eq({"Verify" => "Vérifier"})
        msgid "Verify"
        msgstr "Vérifier"

        #~ msgid "Hash Generator"
        #~ msgstr "Générateur de sommes"
      PO
    end
  end

  describe "the catalogues in po/" do
    let(:directory) { described_class.po_directory }
    let(:linguas) { File.read(File.join(directory, "LINGUAS")).split }

    it "has a catalogue for every language LINGUAS names" do
      missing = linguas.reject { |code| File.file?(File.join(directory, "#{code}.po")) }

      expect(missing).to be_empty
    end

    it "names every language it ships a catalogue for" do
      shipped = Dir.glob(File.join(directory, "*.po")).map { |path| File.basename(path, ".po") }

      expect(shipped.sort).to eq(linguas.sort)
    end

    it "reads every catalogue" do
      read = linguas.map do |code|
        described_class.send(:parse, File.join(directory, "#{code}.po"))
      end

      expect(read.size).to eq(linguas.size)
    end

    # ber is the one catalogue upstream ships with nothing in it: every entry
    # is fuzzy, so there is no translation to find. Every other language has
    # at least one.
    it "finds a translation in every catalogue upstream filled in" do
      empty = linguas.reject do |code|
        described_class.send(:parse, File.join(directory, "#{code}.po")).any?
      end

      expect(empty).to eq(["ber"])
    end

    it "translates nothing the template has dropped, so no catalogue is stale" do
      stale = translated_msgids - template_msgids

      expect(stale).to be_empty
    end
  end

  # Every msgid in the template, translated or not — the reader keeps only
  # entries that have a translation, and a template has none.
  def template_msgids
    File.read(File.join(described_class.po_directory, "dev.geopjr.Collision.pot")).then do |source|
      described_class.send(:entries, source).filter_map { |entry| entry["msgid"] }
    end
  end

  # Every msgid any catalogue translates. One that is no longer in the
  # template is a string the code stopped asking for and msgmerge has not been
  # run over.
  def translated_msgids
    File.read(File.join(described_class.po_directory, "LINGUAS")).split.flat_map do |code|
      described_class.send(:parse, File.join(described_class.po_directory, "#{code}.po")).keys
    end.uniq
  end
end

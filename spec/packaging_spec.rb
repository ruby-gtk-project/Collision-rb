# frozen_string_literal: true

require "rake"
require "tmpdir"
require "open3"

# Covers rakelib/packaging.rake, which has no upstream counterpart (upstream
# renders these through its own Makefile/meson targets) and, until now, no
# test coverage at all: the 44-example RSpec suite and test/drive_window.rb
# never invoked desktop:build, metainfo:build or nautilus:mo, so a POTFILES
# regression that silently drops every non-English GenericName/Keywords/
# metainfo-description line went undetected by every automated signal this
# port has. These specs build the real artifacts from the real po/ catalogues
# and assert translated output actually appears for a sample of locales, so
# that regression is caught the next time it happens.
RSpec.describe "packaging" do
  # Reloading the same .rake file once per example redefines its top-level
  # constants and `nautilus_locale_dir` each time, which is harmless here
  # (the file carries no state across loads) but noisy, so warnings are
  # silenced just for the load.
  def load_packaging_tasks
    application = Rake::Application.new
    previous_application = Rake.application
    previous_verbose = $VERBOSE

    Rake.application = application
    $VERBOSE = nil
    load File.expand_path("../rakelib/packaging.rake", __dir__)
    application
  ensure
    Rake.application = previous_application
    $VERBOSE = previous_verbose
  end

  # Loaded once: the tasks have no state of their own (DATA_DIR/PO_DIR are
  # read-only constants), so every example can execute the same task object.
  let(:application) { load_packaging_tasks }

  def run_task(name)
    application[name].execute
  end

  # A handful of locales, not all 41 — enough to prove translated lines
  # exist at all without pinning the suite to the full catalogue list.
  SAMPLE_LOCALES = %w[de fr ja].freeze

  describe "desktop:build" do
    it "renders GenericName and Keywords for a sample of locales" do
      run_task("desktop:build")
      output = File.read(File.join(DATA_DIR, "dev.geopjr.Collision.desktop"))

      SAMPLE_LOCALES.each do |locale|
        expect(output).to match(/^GenericName\[#{locale}\]=.+$/)
        expect(output).to match(/^Keywords\[#{locale}\]=.+$/)
      end
    end
  end

  describe "metainfo:build" do
    it "renders translated name, summary and description paragraphs for a sample of locales" do
      run_task("metainfo:build")
      output = File.read(File.join(DATA_DIR, "dev.geopjr.Collision.metainfo.xml"))

      SAMPLE_LOCALES.each do |locale|
        expect(output).to match(/<name xml:lang="#{locale}">.+<\/name>/)
        expect(output).to match(/<summary xml:lang="#{locale}">.+<\/summary>/)
        expect(output.scan(/<p xml:lang="#{locale}">.+?<\/p>/).size).to be >= 2
      end
    end
  end

  describe "nautilus:mo" do
    it "compiles a .mo that translates 'Check Hashes' for a sample of locales" do
      Dir.mktmpdir do |locale_root|
        with_environment("COLLISION_NAUTILUS_LOCALE_DIR" => locale_root) do
          run_task("nautilus:mo")
        end

        SAMPLE_LOCALES.each do |locale|
          mo_path = File.join(locale_root, locale, "LC_MESSAGES", "dev.geopjr.Collision.mo")
          expect(File.file?(mo_path)).to be(true)

          decompiled, status = Open3.capture2("msgunfmt", mo_path)
          expect(status).to be_success
          expect(decompiled).to include('msgid "Check Hashes"')
          expect(decompiled).not_to match(/msgstr "Check Hashes"/)
        end
      end
    end
  end

  def with_environment(values)
    originals = values.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
    values.each { |name, value| ENV[name] = value }

    yield
  ensure
    originals.each { |name, value| ENV[name] = value }
  end
end

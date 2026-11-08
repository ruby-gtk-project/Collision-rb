# frozen_string_literal: true

# Packaging tasks for the two files that have no `require`-based call site —
# a desktop entry and an AppStream metainfo file are read by the shell and
# the software center, not by the Ruby app itself — plus the Nautilus/GNOME
# Files extension, which Nautilus loads directly and the gem never touches.
#
# These mirror upstream's Makefile targets of the same names (`desktop`,
# `metainfo`, `install_nautilus_extension`), substituting rake/FileUtils for
# make/cp so the port's own build reaches them instead of leaving them as
# files nothing invokes.

require "fileutils"

DATA_DIR = File.expand_path("data", __dir__ + "/..")
PO_DIR = File.expand_path("po", __dir__ + "/..")

# The gettext domain upstream's src/collision.cr binds and the Nautilus
# extension's `textdomain('dev.geopjr.Collision')` call looks up. It is not
# `Collision::I18n::DOMAIN` because that constant lives in lib/, and this
# Rakefile intentionally stays loadable without requiring the gem's code.
NAUTILUS_GETTEXT_DOMAIN = "dev.geopjr.Collision"

namespace :desktop do
  desc "Render data/dev.geopjr.Collision.desktop from the .in template, translated via po/"
  task :build do
    template = File.join(DATA_DIR, "dev.geopjr.Collision.desktop.in")
    output = File.join(DATA_DIR, "dev.geopjr.Collision.desktop")

    sh(
      "msgfmt",
      "--desktop",
      "--template",
      template,
      "-d",
      PO_DIR,
      "-o",
      output,
    )
  end
end

namespace :metainfo do
  desc "Render data/dev.geopjr.Collision.metainfo.xml from the .in template, translated via po/"
  task :build do
    template = File.join(DATA_DIR, "dev.geopjr.Collision.metainfo.xml.in")
    output = File.join(DATA_DIR, "dev.geopjr.Collision.metainfo.xml")

    sh(
      "msgfmt",
      "--xml",
      "--template",
      template,
      "-d",
      PO_DIR,
      "-o",
      output,
    )
  end
end

namespace :nautilus do
  # collision-extension.py calls Python's own `gettext.textdomain`/`gettext`,
  # not Collision::I18n, and never calls `bindtextdomain` (matching upstream,
  # which leaves that same call out) — so it only ever looks in Python's own
  # default locale directory, `gettext._default_localedir`, which is
  # `sys.base_prefix + "/share/locale"`, not any XDG or `~/.local` path.
  # That is a property of whichever `python3` Nautilus itself loads, not of
  # this gem, so it has to be asked rather than assumed.
  def nautilus_locale_dir
    ENV["COLLISION_NAUTILUS_LOCALE_DIR"] ||
      `python3 -c 'import gettext; print(gettext._default_localedir)'`.strip
  end

  desc "Compile po/*.po into .mo and install them where the extension's gettext can find them"
  task :mo do
    locale_root = nautilus_locale_dir
    linguas = File.readlines(File.join(PO_DIR, "LINGUAS")).flat_map(&:split)

    linguas.each do |language|
      source = File.join(PO_DIR, "#{language}.po")
      destination_dir = File.join(locale_root, language, "LC_MESSAGES")
      destination = File.join(destination_dir, "#{NAUTILUS_GETTEXT_DOMAIN}.mo")

      begin
        FileUtils.mkdir_p(destination_dir)
        sh("msgfmt", "--output-file", destination, source)
      rescue SystemCallError, RuntimeError => e
        warn("NOTE: could not install #{destination} (#{e.message}); " \
          "re-run with permission to write to #{locale_root}")
      end
    end
  end

  desc "Install the Nautilus/GNOME Files 'Check Hashes' extension for the current user"
  task install: :mo do
    source = File.expand_path("nautilus-extension/collision-extension.py", __dir__ + "/..")
    destination_dir = File.expand_path("~/.local/share/nautilus-python/extensions")

    FileUtils.mkdir_p(destination_dir)
    FileUtils.cp(source, destination_dir)
    sh("nautilus", "-q") do |ok, _|
      unless ok
        warn("NOTE: nautilus not running or not found; restart it to pick up the extension")
      end
    end
  end
end

desc "Build the desktop entry and the AppStream metainfo file"
task package_data: ["desktop:build", "metainfo:build"]

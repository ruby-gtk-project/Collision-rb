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
  desc "Install the Nautilus/GNOME Files 'Check Hashes' extension for the current user"
  task :install do
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

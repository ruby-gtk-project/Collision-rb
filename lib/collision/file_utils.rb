# frozen_string_literal: true

module Collision
  # FileUtils answers the questions the window asks about a path before it
  # hashes it.
  #
  # Ported from upstream's src/collision/functions/file_utils.cr. Upstream
  # hides the directory of a file handed over by the Flatpak document portal,
  # whose /run/user path says nothing useful; the port does the same whenever
  # it is running inside a Flatpak sandbox.
  module FileUtils
    extend self

    PORTAL_PREFIX = File.join("/", "run", "user")

    # The directory to show under the file name, or nil when it would only
    # leak a portal path.
    def real_path(filepath)
      if flatpak? && File.expand_path(filepath).start_with?("#{PORTAL_PREFIX}/")
        nil
      else
        File.dirname(filepath)
      end
    end

    # True when the path is an existing regular file.
    def file?(file)
      File.file?(file).tap do |exists|
        unless exists
          warn("\"#{file}\" does not exist or is not a File")
        end
      end
    end

    # True when any of `needles` appears as a whitespace-separated word in the
    # file — how a checksum file (`<hash>  <filename>`) is matched.
    def compare_content(file_path, needles)
      File.foreach(file_path).any? do |line|
        line.split(" ").any? { |word| needles.include?(word.downcase) }
      end
    end

    def flatpak?
      !ENV["FLATPAK_ID"].nil? || File.exist?("/.flatpak-info")
    end
  end
end

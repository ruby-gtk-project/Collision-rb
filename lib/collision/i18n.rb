# frozen_string_literal: true

module Collision
  # I18n translates the strings the interface shows.
  #
  # Ported from the Gettext calls spread through upstream's Crystal sources —
  # src/collision.cr binds the "dev.geopjr.Collision" domain and every
  # user-visible string goes through Gettext.gettext — together with po/, whose
  # catalogues come from upstream.
  #
  # Upstream reads compiled .mo files out of an installed locale directory,
  # which puts a build step and an install step between a translation and the
  # window. The port reads the .po files directly: there is nothing to compile,
  # a checkout is translated, and the catalogues ship inside the gem. Entries
  # that are marked fuzzy or whose translation is empty are ignored, which is
  # what gettext does with them too.
  #
  # Including the module gives a class the `_` method upstream spells
  # Gettext.gettext.
  module I18n
    extend self

    # Including the module also extends the includer, so a class body can mark
    # the strings it collects into a constant with N_ before any instance
    # exists.
    def self.included(base) = base.extend(self)

    DOMAIN = "dev.geopjr.Collision"

    # The environment variables gettext consults, most specific first.
    LOCALE_VARIABLES = %w[LANGUAGE LC_ALL LC_MESSAGES LANG].freeze

    # Locale names that mean "no translation".
    UNTRANSLATED_LOCALES = %w[C POSIX].freeze

    # A keyword line: the keyword, then the first piece of its string.
    KEYWORD = /\A(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)[ \t]+"(.*)"\z/

    # The escapes a PO string can carry. Anything else after a backslash
    # stands for itself.
    ESCAPES = {
      "n"  => "\n",
      "t"  => "\t",
      "r"  => "\r",
      "\"" => "\"",
      "\\" => "\\",
    }.freeze

    # Translates one string, falling back to the string itself — so an
    # untranslated locale, a missing catalogue and an untranslated entry all
    # show the English original rather than an empty label.
    def _(msgid) = catalogue.fetch(msgid, msgid)

    # Marks a string for extraction without translating it, for the strings
    # that are gathered into a constant or a table and translated later, at
    # the point they reach a widget. Upstream has no equivalent because its
    # strings sit in GtkBuilder files, which xgettext reads directly.
    def N_(msgid) = msgid

    # Memoized: the catalogue is parsed once. A running GTK process cannot
    # change its locale, so there is nothing to invalidate.
    def catalogue
      @catalogue ||= load_catalogue
    end

    # Where the catalogues are. COLLISION_LOCALE_LOCATION overrides it, as the
    # variable of the same name overrides the locale directory upstream
    # compiles into.
    def po_directory
      ENV.fetch("COLLISION_LOCALE_LOCATION", File.expand_path("../../po", __dir__))
    end

    # The language codes to try, most specific first. "pt_BR.UTF-8" offers
    # pt_BR and then pt, and LANGUAGE may list several, separated by colons.
    def languages
      LOCALE_VARIABLES
        .filter_map { |name| ENV[name] }
        .reject(&:empty?)
        .flat_map { |value| value.split(":") }
        .flat_map { |value| candidates(value) }
        .uniq
        .reject { |code| UNTRANSLATED_LOCALES.include?(code) }
    end

    # The catalogue file for the first language that has one, or nil.
    def catalogue_path
      languages
        .map { |code| File.join(po_directory, "#{code}.po") }
        .find { |path| File.file?(path) }
    end

    private

      def load_catalogue
        catalogue_path.then do |path|
          if path.nil?
            {}
          else
            parse(path)
          end
        end
      end

      # "pt_BR.UTF-8@euro" offers "pt_BR" and then "pt". The modifier and the
      # codeset are dropped because the catalogues are named by language and
      # territory alone.
      def candidates(value)
        value.split(".").first.to_s.split("@").first.to_s.then do |code|
          [code, code.split("_").first].compact.reject(&:empty?).uniq
        end
      end

      # The translated, non-fuzzy entries of a PO file, as msgid => msgstr.
      def parse(path)
        {}.tap do |translations|
          entries(File.read(path)).each do |entry|
            msgid = entry.fetch("msgid", "")
            msgstr = entry.fetch("msgstr", "")

            if usable?(entry, msgid, msgstr)
              translations[msgid] = msgstr
            end
          end
        end
      end

      # The header entry has an empty msgid, an untranslated entry has an
      # empty msgstr, and a fuzzy entry is a guess msgmerge made rather than a
      # translation anyone approved.
      def usable?(entry, msgid, msgstr)
        !msgid.empty? && !msgstr.empty? && !entry.fetch(:flags).include?("fuzzy")
      end

      # Splits a PO file into entries. The format is line based: `#` comments,
      # a keyword followed by a quoted string, and continuation lines that are
      # bare quoted strings appended to whatever keyword came last. A blank
      # line ends the entry.
      def entries(source)
        [].tap do |all|
          entry = blank_entry

          source.each_line do |line|
            if line.strip.empty?
              all << entry
              entry = blank_entry
            else
              consume(entry, line.strip)
            end
          end

          all << entry
        end
      end

      def blank_entry = {flags: [], last: nil}

      def consume(entry, line)
        if line.start_with?("#,")
          entry.fetch(:flags).concat(flags(line))
        elsif line.start_with?("#")
          entry
        elsif (keyword = line.match(KEYWORD))
          entry[:last] = keyword[1]
          entry[keyword[1]] = unescape(keyword[2])
        elsif continuation?(entry, line)
          entry[entry.fetch(:last)] = entry.fetch(entry.fetch(:last), "") + unescape(line[1..-2])
        else
          entry
        end
      end

      def flags(line)
        line.delete_prefix("#,").split(",").map(&:strip)
      end

      def continuation?(entry, line)
        !entry.fetch(:last).nil? && line.start_with?("\"") && line.end_with?("\"")
      end

      def unescape(text)
        text.gsub(/\\(.)/) do
          ESCAPES.fetch(Regexp.last_match(1), Regexp.last_match(1))
        end
      end
  end
end

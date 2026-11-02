# frozen_string_literal: true

require "digest"
require "zlib"
require "adwaita"

require_relative "i18n"
require_relative "settings"

module Collision
  # Checksum calculates file hashes.
  #
  # Ported from upstream's src/collision/functions/checksum.cr, which also
  # carries the HASH_FUNCTIONS / VERIFICATION_HASH_FUNCTION constants in
  # src/collision.cr. Both live here because every caller that wants the list
  # of hash functions also wants the thing that computes them.
  #
  # Upstream spawns one fiber per hash function on an eight-strong
  # multi-threaded execution context and funnels the results back through a
  # channel. The port spawns the same work onto a pool of WORKER_COUNT Ruby
  # threads: the digests release the GVL while reading, so the files are read
  # concurrently, and the progress bar and the completion callback are handed
  # back to the main loop with GLib::Idle.add rather than touched from a
  # worker.
  #
  # Upstream's list includes Blake3, which has no implementation in the gems
  # this port depends on; it is left out of HASH_FUNCTIONS rather than listed
  # and left uncalculated.
  class Checksum
    include I18n

    # The hash functions offered, in display order. The key is the settings
    # name and the internal identifier; the value is the label shown in the UI.
    HASH_FUNCTIONS = {
      md5:     "MD5",
      sha1:    "SHA1",
      sha256:  "SHA256",
      sha512:  "SHA512",
      crc32:   "CRC32",
      adler32: "Adler32",
    }.freeze

    # The hash function used by the verification tool. It cannot be disabled
    # and has to be one without known collisions.
    VERIFICATION_HASH_FUNCTION = :sha256

    # Size of the pool the hash functions are calculated on, matching the
    # width of upstream's "worker-threads" execution context.
    WORKER_COUNT = 8

    # Bytes read per iteration when streaming a file through a digest.
    CHUNK_SIZE = 1 << 16

    # Progress-bar text while the hashes are being calculated.
    PROGRESS_FORMAT = N_("%d of %d hashes calculated")

    DIGESTS = {
      md5:    Digest::MD5,
      sha1:   Digest::SHA1,
      sha256: Digest::SHA256,
      sha512: Digest::SHA512,
    }.freeze

    # The rolling checksums, each with the value it has to start from when a
    # file is fed through it in chunks. CRC-32 starts at zero; Adler-32 starts
    # at one, which is what Zlib.adler32 substitutes when it is called with no
    # running value, and seeding it with zero yields a different digest for
    # every input.
    ZLIB_CHECKSUMS = {
      crc32:   {function: Zlib.method(:crc32), seed: 0},
      adler32: {function: Zlib.method(:adler32), seed: 1},
    }.freeze

    # Groups a hash into blocks of four characters so a long hex string wraps
    # at predictable places. Upstream calls this Collision.split_by_4.
    def self.split_by_4(hash_str)
      hash_str.scan(/.{1,4}/).join(" ")
    end

    # Calculates one hash function over one file, as lowercase hex.
    def calculate(type, filename)
      if DIGESTS.key?(type)
        digest(type, filename)
      elsif ZLIB_CHECKSUMS.key?(type)
        zlib_checksum(type, filename)
      else
        raise(ArgumentError, "no digest for #{type}")
      end
    end

    # Calculates every enabled hash function over the file, reporting progress
    # into `progressbar`, and hands the finished {type => hash} map to the
    # block on the main loop.
    def generate(filename, progressbar = nil, &block)
      enabled_hash_functions.then do |types|
        reset_progress(progressbar, types.size)
        spawn_pool(
          filename,
          types,
          progressbar,
          &block
        )
      end
    end

    # The hash functions that are not switched off in the settings.
    def enabled_hash_functions
      Settings.safe_disabled_hash_functions.then do |disabled|
        HASH_FUNCTIONS.keys.reject { |type| disabled.include?(type) }
      end
    end

    private

      def digest(type, filename)
        DIGESTS.fetch(type).new.tap do |hash|
          File.open(filename, "rb") do |io|
            while (chunk = io.read(CHUNK_SIZE))
              hash.update(chunk)
            end
          end
        end.hexdigest.downcase
      end

      def zlib_checksum(type, filename)
        ZLIB_CHECKSUMS.fetch(type).then do |checksum|
          accumulator = checksum.fetch(:seed)
          function = checksum.fetch(:function)

          File.open(filename, "rb") do |io|
            while (chunk = io.read(CHUNK_SIZE))
              accumulator = function.call(chunk, accumulator)
            end
          end

          format("%08x", accumulator)
        end
      end

      def reset_progress(progressbar, amount)
        unless progressbar.nil?
          progressbar.fraction = 0.0
          progressbar.text = format(_(PROGRESS_FORMAT), 0, amount)
        end
      end

      # Runs `types` over a pool of worker threads and calls `block` once they
      # have all reported in. The coordinating thread is the only one that
      # joins, so `generate` returns immediately.
      def spawn_pool(filename, types, progressbar, &block)
        Queue.new.tap do |pending|
          types.each { |type| pending << type }
          WORKER_COUNT.times { pending << nil }

          results = {}
          lock = Mutex.new
          done = 0

          workers = Array.new(WORKER_COUNT) do
            Thread.new do
              while (type = pending.pop)
                calculated = calculate(type, filename)

                lock.synchronize do
                  results[type] = calculated
                  done += 1
                  report(progressbar, done, types.size)
                end
              end
            end
          end

          Thread.new do
            workers.each(&:join)
            ordered = HASH_FUNCTIONS.keys.select { |type| results.key?(type) }
            sorted = ordered.to_h { |type| [type, results[type]] }
            GLib::Idle.add do
              block.call(sorted)
              false
            end
          end
        end
      end

      # Progress has to reach the progress bar on the main loop, not from the
      # worker that finished.
      def report(progressbar, done, amount)
        unless progressbar.nil?
          GLib::Idle.add do
            progressbar.fraction = [done.fdiv(amount), 1.0].min
            progressbar.text = format(_(PROGRESS_FORMAT), done, amount)
            false
          end
        end
      end
  end
end

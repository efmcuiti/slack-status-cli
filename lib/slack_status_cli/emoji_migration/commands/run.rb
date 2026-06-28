module SlackStatusCli
  module EmojiMigration
    module Commands
      # Orchestrates an emoji export: filters the raw `emoji.list` map into
      # downloadable images / aliases / unparseable leftovers, fans the images
      # out over a small threadpool calling DownloadImage per entry, accumulates
      # bytes, then persists aliases.json and skipped.json. Returns a Result
      # struct the CLI renders into its summary line.
      #
      # Both the unparseable entries (from FilteredEntries) and any per-image
      # download failures land in `skipped` as uniform { name:, reason: } hashes
      # so skipped.json has a single shape.
      class Run
        extend Callable

        DEFAULT_CONCURRENCY = 6
        UNPARSEABLE_REASON = "no downloadable image URL".freeze

        Result = Struct.new(:downloaded, :aliases, :skipped, :total_bytes)

        def initialize(emoji_map:, out_dir:, filter: nil, logger: nil, concurrency: DEFAULT_CONCURRENCY)
          @emoji_map = emoji_map
          @out_dir = out_dir
          @filter = filter
          @logger = logger
          @concurrency = concurrency
        end

        def call
          entries = Queries::FilteredEntries.call(emoji_map: emoji_map, pattern: filter)
          real = entries[:real]
          aliases = entries[:aliases]
          skipped = entries[:skipped].map { |name| { name: name, reason: UNPARSEABLE_REASON } }

          log "found #{real.size} image#{real.size == 1 ? "" : "s"}, " \
              "#{aliases.size} alias#{aliases.size == 1 ? "" : "es"}, " \
              "#{skipped.size} unparseable"

          downloaded, failures = download_all(real)
          skipped.concat(failures)
          total_bytes = downloaded.sum { |entry| entry[:bytes] }

          WriteAliases.call(out_dir: out_dir, aliases: aliases)
          WriteSkipped.call(out_dir: out_dir, skipped: skipped)

          Result.new(downloaded, aliases, skipped, total_bytes)
        end

        private

        attr_reader :emoji_map, :out_dir, :filter, :logger, :concurrency

        def download_all(real)
          queue = ::Queue.new
          real.each { |pair| queue.push(pair) }
          downloaded = []
          failures = []
          mutex = ::Mutex.new

          workers = Array.new([concurrency, 1].max) do
            ::Thread.new do
              loop do
                begin
                  name, url = queue.pop(true)
                rescue ::ThreadError
                  break
                end

                download_one(name, url, downloaded, failures, mutex)
              end
            end
          end
          workers.each(&:join)

          [downloaded, failures]
        end

        def download_one(name, url, downloaded, failures, mutex)
          entry = DownloadImage.call(name: name, url: url, out_dir: out_dir)
          mutex.synchronize do
            downloaded << entry
            log "  ✓ #{name}.#{entry[:extension]} (#{Queries::HumanBytes.call(bytes: entry[:bytes])})"
          end
        rescue StandardError => e
          mutex.synchronize do
            failures << { name: name, reason: e.message }
            log "  ✗ #{name} skipped: #{e.message}"
          end
        end

        def log(message)
          logger&.info(message)
        end
      end
    end
  end
end

require "fileutils"
require "net/http"
require "uri"

module SlackStatusCli
  module EmojiMigration
    module Commands
      # Fetches a single emoji image over HTTP and writes it to disk under a
      # sanitized, extension-tagged filename. Returns the metadata the
      # orchestrator needs to tally a run. Raises on a non-2xx response so the
      # caller can record the failure as skipped.
      class DownloadImage
        extend Callable

        READ_TIMEOUT = 30

        def initialize(name:, url:, out_dir:)
          @name = name
          @url = url
          @out_dir = out_dir
        end

        def call
          body = fetch
          extension = Queries::ExtensionFor.call(url: url, body: body)
          filename = "#{Queries::SanitizeFilename.call(name: name)}.#{extension}"

          ::FileUtils.mkdir_p(out_dir)
          path = ::File.join(out_dir, filename)
          ::File.binwrite(path, body)

          { name: name, path: path, bytes: body.bytesize, extension: extension }
        end

        private

        attr_reader :name, :url, :out_dir

        def fetch
          uri = URI(url)
          ::Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.read_timeout = READ_TIMEOUT
            response = http.get(uri.request_uri)
            raise "HTTP #{response.code}" unless response.is_a?(::Net::HTTPSuccess)

            response.body
          end
        end
      end
    end
  end
end

require "fileutils"
require "json"
require "pathname"

module SlackStatusCli
  module EmojiMigration
    module Commands
      # Writes the skipped list to `skipped.json` in the output directory. Unlike
      # the original migrator, the file is always written (an empty `[]` when
      # nothing was skipped) so consumers can rely on it existing.
      class WriteSkipped
        extend Callable

        FILENAME = "skipped.json".freeze

        def initialize(out_dir:, skipped:)
          @out_dir = out_dir
          @skipped = skipped
        end

        def call
          ::FileUtils.mkdir_p(out_dir)
          path = Pathname.new(::File.join(out_dir, FILENAME))
          path.write(JSON.pretty_generate(skipped))
          path
        end

        private

        attr_reader :out_dir, :skipped
      end
    end
  end
end

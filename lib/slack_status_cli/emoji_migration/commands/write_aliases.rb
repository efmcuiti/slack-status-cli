require "fileutils"
require "json"
require "pathname"

module SlackStatusCli
  module EmojiMigration
    module Commands
      # Writes the alias map ({name => target_name}) to `aliases.json` in the
      # output directory. Alias emoji have no image file of their own, so this
      # record is how the user reproduces them in the destination workspace.
      class WriteAliases
        extend Callable

        FILENAME = "aliases.json".freeze

        def initialize(out_dir:, aliases:)
          @out_dir = out_dir
          @aliases = aliases
        end

        def call
          ::FileUtils.mkdir_p(@out_dir)
          path = Pathname.new(::File.join(@out_dir, FILENAME))
          path.write(JSON.pretty_generate(@aliases))
          path
        end
      end
    end
  end
end

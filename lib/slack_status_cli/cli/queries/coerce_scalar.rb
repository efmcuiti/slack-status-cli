module SlackStatusCli
  module Cli
    module Queries
      # Coerces a CLI-supplied string into the scalar it looks like, so
      # `config set` can store typed YAML values instead of bare strings.
      # Recognizes booleans ("true"/"yes", "false"/"no"), nulls, integers, and
      # floats; everything else is returned unchanged.
      class CoerceScalar
        extend Callable

        INTEGER = /\A-?\d+\z/.freeze
        FLOAT = /\A-?\d+\.\d+\z/.freeze

        def initialize(value:)
          @value = value
        end

        def call
          case value
          when "true", "yes" then true
          when "false", "no" then false
          when "null", "nil" then nil
          when INTEGER then Integer(value)
          when FLOAT then Float(value)
          else value
          end
        end

        private

        attr_reader :value
      end
    end
  end
end

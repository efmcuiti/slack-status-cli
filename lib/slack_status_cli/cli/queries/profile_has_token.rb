module SlackStatusCli
  module Cli
    module Queries
      # Answers whether a profile currently resolves to a token, by attempting
      # the full Tokens precedence walk and treating the pod's NotFoundError as
      # "no token" rather than letting it propagate. Used by setup to decide
      # whether it is about to overwrite an existing token.
      class ProfileHasToken
        extend Callable

        def initialize(profile:, config_path:)
          @profile = profile
          @config_path = config_path
        end

        def call
          Tokens::Queries::ResolveToken.call(profile: profile, config_path: config_path)
          true
        rescue Tokens::Errors::NotFoundError
          false
        end

        private

        attr_reader :profile, :config_path
      end
    end
  end
end

module SlackStatusCli
  module Cli
    module Commands
      # Persists a profile's token by delegating to the Tokens pod's WriteToken
      # command. Returns WriteToken's `{ source:, location: }` so the caller can
      # report where the token landed; backends that can't write unattended
      # raise ManualWriteRequired, which propagates to the orchestrator.
      class PersistProfileToken
        extend Callable

        def initialize(profile:, token:, backend_name:, settings:)
          @profile = profile
          @token = token
          @backend_name = backend_name
          @settings = settings
        end

        def call
          Tokens::Commands::WriteToken.call(
            token: token,
            profile: profile,
            backend_name: backend_name,
            settings: settings,
          )
        end

        private

        attr_reader :profile, :token, :backend_name, :settings
      end
    end
  end
end

module SlackStatusCli
  module Tokens
    module Commands
      # Persists a token through the named storage backend, built from the
      # already-merged settings the caller passes in. Extracted from the legacy
      # `TokenResolver#write_token`. Returns `{ source:, location: }` so the
      # caller can tell the user where the token landed; backends that can't
      # write unattended (Env, Dashlane) raise ManualWriteRequired with
      # copy-paste instructions instead.
      class WriteToken
        extend Callable

        BACKEND_CLASSES = {
          "dashlane" => Backends::Dashlane,
          "keychain" => Backends::Keychain,
          "file" => Backends::File,
          "env" => Backends::Env
        }.freeze

        def initialize(token:, profile:, backend_name:, settings:)
          @token = token
          @profile = profile
          @backend_name = backend_name
          @settings = settings || {}
        end

        def call
          backend = build_backend
          backend.write(token)
          { source: backend.source_label, location: backend.location }
        end

        private

        attr_reader :token, :profile, :backend_name, :settings

        def build_backend
          klass = BACKEND_CLASSES[backend_name.to_s]
          unless klass
            raise Errors::ConfigError,
                  "Unknown storage_backend '#{backend_name}' (supported: #{BACKEND_CLASSES.keys.join(', ')})"
          end

          klass.new(profile: profile, settings: settings)
        end
      end
    end
  end
end

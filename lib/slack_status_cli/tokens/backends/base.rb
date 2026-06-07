module SlackStatusCli
  module Tokens
    module Backends
      # Abstract base for every token storage backend (Dashlane, Keychain,
      # File, Env). Concrete backends extracted in T4.2 subclass this and
      # implement `#read` / `#write`. The `#name` and `#source_label` defaults
      # derive from the demodulized class name so a backend gets a sensible
      # identifier and human label for free.
      class Base
        attr_reader :profile, :settings, :last_error

        def initialize(profile:, settings: {})
          @profile = profile
          @settings = settings || {}
          @last_error = nil
        end

        def read
          raise NotImplementedError
        end

        def write(_token)
          raise NotImplementedError
        end

        # Snake_case symbol identifier, e.g. KeychainBackend -> :keychain_backend.
        def name
          demodulized_name.to_sym
        end

        # Human-facing label, e.g. KeychainBackend -> "Keychain backend".
        def source_label
          demodulized_name.tr("_", " ").capitalize
        end

        def location
          ""
        end

        # Backends override to explain WHY their read returned nil, including
        # how the user can fix it. Surfaced by Errors::NotFoundError.
        def not_found_hint
          nil
        end

        private

        def demodulized_name
          self.class.name
              .split("::")
              .last
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
        end
      end
    end
  end
end

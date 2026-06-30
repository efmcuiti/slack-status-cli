module SlackStatusCli
  module Cli
    module Commands
      # Prints the one-time walkthrough for creating the Slack App and finding its
      # Client ID / Client Secret. Pure output: writes to an injected IO (defaults
      # to $stdout) so the interactive pause stays in the orchestrator.
      class PrintAppCreationInstructions
        extend Callable

        INSTRUCTIONS = <<~INSTR.freeze
          Where to find your Client ID + Client Secret:
            1) Open https://api.slack.com/apps?new_app=1
            2) Pick "From a manifest", then pick your workspace.
            3) Paste the contents of docs/slack-app-manifest.yml and confirm.
            4) On the new app's "Basic Information" page, scroll to "App Credentials":
               - Client ID looks like 1234567890123.0987654321098
               - Click "Show" next to Client Secret to reveal it.
            5) The manifest pre-fills the OAuth redirect URL; double-check it under
               "OAuth & Permissions" → "Redirect URLs": http://localhost:53682/callback
        INSTR

        def initialize(output: $stdout)
          @output = output
        end

        def call
          output.puts(INSTRUCTIONS)
          nil
        end

        private

        attr_reader :output
      end
    end
  end
end

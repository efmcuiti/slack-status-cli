module SlackStatusCli
  module Music
    module Queries
      # Pure derivation of a tune's playback state as a symbol
      # (`:playing | :paused | :silent`) from a raw tune hash. No IO.
      # A nil tune (an errored tick) defaults to `:playing` so callers keep
      # the conservative cadence instead of hammering Slack during transient
      # failures. Ported from the old `Slack#tune_state`.
      class TuneState
        extend Callable

        def initialize(tune:)
          @tune = tune
        end

        def call
          return :playing if tune.nil?
          return :silent if tune[:name].nil?

          tune[:playing] ? :playing : :paused
        end

        private

        attr_reader :tune
      end
    end
  end
end

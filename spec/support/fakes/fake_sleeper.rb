# Real-fake replacement for `Kernel#sleep` in specs that exercise loops
# (notably the musical-myth status updater). Pods inject an instance via a
# `sleeper:` keyword and call `sleeper.call(seconds)` instead of `sleep`.
#
# When constructed with `raise_after: N`, the Nth call raises `StopIteration`
# and so does every call after it — the tripwire stays tripped, even if a
# misbehaving call site rescues `StopIteration` and keeps calling. The
# expected consumer is `Kernel#loop`, which catches `StopIteration` cleanly
# on the first raise; that gives musical-loop specs a deterministic way to
# run the real loop body a finite number of times without monkey-patching
# `break`.
#
#   sleeper = FakeSleeper.new(raise_after: 3)
#   sleeper.call(10)   # => 10, records 10
#   sleeper.call(10)   # => 10, records 10
#   sleeper.call(10)   # raises StopIteration (and still records 10)
#   sleeper.call(10)   # raises StopIteration again (and still records 10)
#   sleeper.calls      # => [10, 10, 10, 10]
class FakeSleeper
  def initialize(raise_after: nil)
    @raise_after = raise_after
    @calls = []
  end

  attr_reader :calls

  def call(seconds)
    @calls << seconds
    raise StopIteration if @raise_after && @calls.size >= @raise_after

    seconds
  end
end

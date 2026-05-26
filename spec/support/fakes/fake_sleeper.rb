# Spec-only collaborator for code paths that would otherwise call `Kernel#sleep`
# (notably the musical-myth status updater). This is **not** a `Kernel#sleep`
# drop-in — it just happens to be call-compatible at the surface
# (`call(seconds)` accepts the same positional Numeric argument as
# `sleep(seconds)`), with a deliberately different contract designed for spec
# ergonomics:
#
#   - Records every requested duration in `#calls` so specs can assert the
#     loop's sleep schedule.
#   - Echoes the requested duration back. Real `Kernel#sleep` returns an
#     Integer of seconds actually slept; the fake does no real waiting and
#     simply returns whatever you passed, so tests get a stable, asserted
#     value. Call sites must not read the return value — that's the seam
#     that keeps the diverging contract harmless.
#   - Constructed with `raise_after: N`, the Nth call raises `StopIteration`
#     and so does every call after it — the tripwire stays tripped, even if
#     a misbehaving call site rescues `StopIteration` and keeps calling. The
#     expected consumer is `Kernel#loop`, which catches `StopIteration`
#     cleanly on the first raise; that gives musical-loop specs a
#     deterministic way to run the real loop body a finite number of times
#     without monkey-patching `break`.
#
# Pods inject an instance via a `sleeper:` keyword and call
# `sleeper.call(seconds)` instead of `sleep`.
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

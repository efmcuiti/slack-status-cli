# Spec-only collaborator for code paths that would otherwise call
# `Open3.capture3` (music detection, Dashlane/Keychain backends, etc.). This
# is **not** an `Open3` drop-in — it just happens to be call-compatible at the
# surface (`#capture3(*argv)` matches `Open3.capture3(*argv)`'s signature), with
# a deliberately different contract designed for spec ergonomics:
#
#   - Stubs are registered ahead of time and matched against the joined argv
#     (Regexp or non-empty String). Pods inject an instance via a `runner:`
#     keyword and call `runner.capture3(...)` instead of `Open3.capture3(...)`.
#   - Unmatched calls raise `UnstubbedCommandError` loudly so a missing stub
#     can never masquerade as a silently-empty shell response — the opposite
#     of `Open3.capture3`, which would actually spawn the process.
#   - The returned status object only implements `#success?` (no `#exitstatus`,
#     `#pid`, etc.); the real `Process::Status` surface isn't reproduced
#     because no call site reads it. Add to `Status` if a downstream spec
#     ever needs more.
#   - Every `capture3` invocation is recorded in `#calls` as the argv array, so
#     specs can assert what was shelled out to (and in what order).
#
#   runner = FakeShellRunner.new
#   runner.stub(/osascript.*current track/, stdout: "Sirens|Cult of Luna|playing")
#   runner.capture3("osascript", "-e", "...")  # => ["Sirens|Cult of Luna|playing", "", <success?>]
#   runner.calls                                # => [["osascript", "-e", "..."]]
class FakeShellRunner
  UnstubbedCommandError = Class.new(StandardError)

  Status = Struct.new(:success) do
    alias_method :success?, :success
  end

  Stub = Struct.new(:matcher, :stdout, :stderr, :success, keyword_init: true) do
    def matches?(joined_argv)
      case matcher
      when Regexp then matcher.match?(joined_argv)
      else joined_argv.include?(matcher.to_s)
      end
    end
  end

  def initialize
    @stubs = []
    @calls = []
  end

  attr_reader :calls

  def stub(matcher, stdout: "", stderr: "", success: true)
    raise ArgumentError, "FakeShellRunner stub matcher cannot be nil or empty" if matcher.nil? || matcher == ""

    @stubs << Stub.new(matcher: matcher, stdout: stdout, stderr: stderr, success: success)
    self
  end

  def capture3(*argv)
    @calls << argv
    joined = argv.join(" ")
    stub = @stubs.find { |candidate| candidate.matches?(joined) }
    raise UnstubbedCommandError, "no FakeShellRunner stub matched: #{joined}" if stub.nil?

    [stub.stdout, stub.stderr, Status.new(stub.success)]
  end
end

# Real-fake replacement for `Open3` in specs that exercise shell-driven
# collaborators (music detection, Dashlane/Keychain backends, etc.).
#
# Pods inject an instance via a `runner:` keyword and call `runner.capture3(...)`
# instead of `Open3.capture3(...)`. Stubs are registered ahead of time and
# matched against the joined argv; unmatched calls raise loudly so a missing
# stub can never masquerade as a silently-empty shell response.
#
#   runner = FakeShellRunner.new
#   runner.stub(/osascript.*current track/, stdout: "Sirens|Cult of Luna|playing")
#   runner.capture3("osascript", "-e", "...")  # => ["Sirens|Cult of Luna|playing", "", <success>]
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

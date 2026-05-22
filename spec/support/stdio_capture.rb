require "stringio"

# Silences and captures anything the block writes to $stdout / $stderr,
# returning a `{ stdout:, stderr: }` hash. The original streams are always
# restored, even if the block raises.
module StdioCapture
  def capture_stdio
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    { stdout: $stdout.string, stderr: $stderr.string }
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

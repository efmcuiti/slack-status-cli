require 'io/console'
require 'slack_status_cli'

# Standard interactive UX helpers shared by every CLI prompt in this tool.
# Centralizing them keeps `[Y/n]` semantics, secret-input echo-off, and the
# emoji progress vocabulary consistent between `setup`, `doctor`, and friends.
module CliPrompt
  EMOJI = {
    step:    "🔧",
    done:    "✅",
    skip:    "⏭",
    manual:  "✋",
    browser: "🌐",
    secret:  "🔐",
    warn:    "⚠️ ",
    fail:    "❌",
  }.freeze

  module_function

  def ask_yes_no(question, default: :yes, input: $stdin, output: $stdout, non_interactive: false)
    suffix = default == :yes ? "[Y/n]" : "[y/N]"
    return default == :yes if non_interactive || !input.respond_to?(:gets)

    loop do
      output.print "#{question} #{suffix} "
      output.flush
      raw = input.gets
      return default == :yes if raw.nil?
      answer = raw.strip.downcase
      return default == :yes if answer.empty?
      return true  if %w[y yes].include?(answer)
      return false if %w[n no].include?(answer)
      output.puts "  please answer y or n."
    end
  end

  def ask(question, default: nil, secret: false, input: $stdin, output: $stdout, non_interactive: false)
    if non_interactive
      return default if default
      raise ArgumentError, "Cannot prompt for '#{question}' in non-interactive mode"
    end

    prompt = default ? "#{question} [#{default}] " : "#{question} "
    output.print prompt
    output.flush

    raw =
      if secret && input.respond_to?(:noecho) && input.tty?
        value = input.noecho(&:gets)
        output.puts
        value
      else
        input.gets
      end

    return default if raw.nil?
    answer = raw.chomp
    answer = answer.strip unless secret
    return default if answer.empty? && default
    answer
  end

  def select(question, options:, default: nil, input: $stdin, output: $stdout, non_interactive: false)
    raise ArgumentError, "select requires at least one option" if options.empty?
    if non_interactive
      return default if default && options.include?(default)
      return options.first
    end

    output.puts question
    options.each_with_index { |opt, i| output.puts "  #{i + 1}) #{opt}" }
    default_idx = default ? options.index(default) : nil
    suffix = default_idx ? " [#{default_idx + 1}]" : ""

    loop do
      output.print "Pick 1-#{options.size}#{suffix}: "
      output.flush
      raw = input.gets
      return options[default_idx] if raw.nil? && default_idx
      answer = raw.to_s.strip
      return options[default_idx] if answer.empty? && default_idx
      idx = Integer(answer, 10) rescue nil
      return options[idx - 1] if idx && idx.between?(1, options.size)
      output.puts "  pick a number from 1 to #{options.size}."
    end
  end

  def step(current, total, label, output: $stdout)
    output.puts "#{emoji(:step)} Step #{current}/#{total}: #{label}"
  end

  def done(label, output: $stdout)
    output.puts "#{emoji(:done)} #{label}"
  end

  def skip(label, output: $stdout)
    output.puts "#{emoji(:skip)} #{label}"
  end

  def info(label, output: $stdout)
    output.puts "   #{label}"
  end

  def browser(label, output: $stdout)
    output.puts "#{emoji(:browser)} #{label}"
  end

  def secret_written(label, output: $stdout)
    output.puts "#{emoji(:secret)} #{label}"
  end

  def warn(label, output: $stderr)
    output.puts "#{emoji(:warn)} #{label}"
  end

  def fail(label, output: $stderr)
    output.puts "#{emoji(:fail)} #{label}"
  end

  # Renders a "you do this part" block and blocks on Enter.
  def manual(instructions, input: $stdin, output: $stdout, non_interactive: false)
    output.puts
    output.puts "#{emoji(:manual)} Manual step required"
    instructions.to_s.each_line { |line| output.puts "   #{line.chomp}" }
    output.puts
    return if non_interactive
    output.print "   Press Enter once you're done… "
    output.flush
    input.gets
  end

  # Truncated form for confirming secret-ish values without echoing them in full.
  def redacted(value, keep: 4)
    return "" if value.nil? || value.empty?
    str = value.to_s
    return "*" * str.length if str.length <= keep
    "…#{str[-keep, keep]}"
  end

  # Scrubs Slack token shapes (xoxp-, xoxb-, xoxc-, xoxd-, xoxa-, xoxs-, xoxr-)
  # from any string so caught exceptions or response bodies don't accidentally
  # log the secret. Thin delegation to the shared Callable so every pod sees
  # an identical redaction shape.
  def scrub_secrets(text)
    SlackStatusCli::SecretScrubber.call(text: text)
  end

  def emoji(key)
    return "" if emoji_disabled?
    EMOJI.fetch(key)
  end

  def emoji_disabled?
    return true if ENV["NO_EMOJI"] && !ENV["NO_EMOJI"].empty?
    return true unless $stdout.respond_to?(:tty?) && $stdout.tty?
    false
  end
end

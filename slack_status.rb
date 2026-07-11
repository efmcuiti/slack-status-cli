#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, "lib"))

# Activate the pinned bundle (webrick left stdlib in Ruby 3.0); fall back to ambient gems if missing.
if File.exist?(File.join(__dir__, "Gemfile.lock"))
  begin
    ENV["BUNDLE_GEMFILE"] = File.join(__dir__, "Gemfile")
    require "bundler"
    Bundler.setup(:default)
  rescue LoadError, StandardError
  end
end

require "cli_prompt"
require "slack_status_cli"

if __FILE__ == $PROGRAM_NAME
  begin
    options = SlackStatusCli::Cli::Queries::ParseGlobalFlags.call(argv: ARGV)
    command = ARGV.shift
    case command
    when "setup"          then SlackStatusCli::Cli::Commands::Setup.call(options: options)
    when "doctor"         then SlackStatusCli::Cli::Commands::Doctor.call(options: options)
    when "config"         then SlackStatusCli::Cli::Commands::Config.call(args: ARGV, options: options)
    when "profiles"       then SlackStatusCli::Cli::Commands::Profiles.call(args: ARGV, options: options)
    when "migrate-emojis" then SlackStatusCli::Cli::Commands::MigrateEmojis.call(options: options)
    else                       SlackStatusCli::Cli::Commands::RunStatusMode.call(command: command, args: ARGV, options: options)
    end
  rescue SlackStatusCli::Cli::Errors::HelpRequested => e
    puts e.help_text
    exit 0
  rescue SlackStatusCli::Cli::Errors::ConfigKeyUnset => e
    warn e.message
    exit 1
  rescue SlackStatusCli::Cli::Errors::Error => e
    CliPrompt.fail(e.message)
    exit 1
  end
end

require "spec_helper"
require "stringio"

RSpec.describe SlackStatusCli::Cli::Commands::PrintAppCreationInstructions do
  describe ".call" do
    it "writes the multi-line instructions to the given output" do
      output = StringIO.new
      described_class.call(output: output)
      expect(output.string.lines.size).to be > 1
    end

    it "mentions the Slack apps console URL" do
      output = StringIO.new
      described_class.call(output: output)
      expect(output.string).to include("api.slack.com/apps")
    end
  end
end

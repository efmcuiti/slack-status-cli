require "spec_helper"

RSpec.describe SlackStatusCli::Tokens::Commands::WriteToken do
  describe ".call" do
    it "delegates the write to the requested backend" do
      with_tmp_config do |dir:, **|
        token_path = File.join(dir, "work.token")
        settings = { "backend_options" => { "file" => { "path" => token_path } } }

        described_class.call(token: "xoxp-written", profile: "work", backend_name: "file", settings: settings)

        expect(File.read(token_path).strip).to eq("xoxp-written")
      end
    end

    it "returns { source:, location: } describing where the token landed" do
      with_tmp_config do |dir:, **|
        token_path = File.join(dir, "work.token")
        settings = { "backend_options" => { "file" => { "path" => token_path } } }

        result = described_class.call(token: "xoxp-x", profile: "work", backend_name: "file", settings: settings)

        expect(result).to eq(source: "File", location: token_path)
      end
    end

    it "raises ManualWriteRequired when the backend rejects programmatic writes (Env)" do
      expect do
        described_class.call(token: "xoxp-x", profile: "work", backend_name: "env", settings: {})
      end.to raise_error(SlackStatusCli::Tokens::Errors::ManualWriteRequired, /SLACK_STATUS_TOKEN_WORK/)
    end

    it "raises ConfigError for an unknown backend_name" do
      expect do
        described_class.call(token: "xoxp-x", profile: "work", backend_name: "bogus", settings: {})
      end.to raise_error(SlackStatusCli::Tokens::Errors::ConfigError, /bogus/)
    end
  end
end

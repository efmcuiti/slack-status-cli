require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Commands::PersistProfileToken do
  describe ".call" do
    it "delegates to WriteToken, persisting the token through the named backend" do
      with_tmp_config do |dir:, **|
        token_path = File.join(dir, "tokens", "work")
        settings = { "backend_options" => { "file" => { "path" => token_path } } }

        described_class.call(profile: "work", token: "xoxp-leaf", backend_name: "file", settings: settings)

        expect(File.read(token_path).strip).to eq("xoxp-leaf")
      end
    end

    it "returns WriteToken's source/location so the caller can report where it landed" do
      with_tmp_config do |dir:, **|
        token_path = File.join(dir, "tokens", "work")
        settings = { "backend_options" => { "file" => { "path" => token_path } } }

        result = described_class.call(profile: "work", token: "xoxp-leaf", backend_name: "file", settings: settings)

        expect(result).to include(location: token_path)
      end
    end
  end
end

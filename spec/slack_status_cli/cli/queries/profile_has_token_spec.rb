require "spec_helper"

RSpec.describe SlackStatusCli::Cli::Queries::ProfileHasToken do
  describe ".call" do
    # ProfileHasToken delegates to ResolveToken, which reads ENV directly, so we
    # snapshot and restore the two vars it consults rather than stubbing it out.
    around do |example|
      saved = ENV.values_at("SLACK_STATUS_TOKEN_DEFAULT", "SLACK_SECRET_TOKEN")
      ENV.delete("SLACK_STATUS_TOKEN_DEFAULT")
      ENV.delete("SLACK_SECRET_TOKEN")
      example.run
    ensure
      ENV["SLACK_STATUS_TOKEN_DEFAULT"], ENV["SLACK_SECRET_TOKEN"] = saved
      ENV.delete("SLACK_STATUS_TOKEN_DEFAULT") if saved[0].nil?
      ENV.delete("SLACK_SECRET_TOKEN") if saved[1].nil?
    end

    it "returns true when ResolveToken finds a token" do
      ENV["SLACK_STATUS_TOKEN_DEFAULT"] = "xoxp-present"
      with_tmp_config do |path:, **|
        expect(described_class.call(profile: "default", config_path: path)).to be(true)
      end
    end

    it "returns false when ResolveToken raises NotFoundError" do
      with_tmp_config do |path:, **|
        expect(described_class.call(profile: "default", config_path: path)).to be(false)
      end
    end
  end
end

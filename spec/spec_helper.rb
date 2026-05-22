require "webmock/rspec"

# Block every real HTTP request — the Slack pod's specs whitelist endpoints
# via `stub_request`, and nothing else should touch the network.
WebMock.disable_net_connect!

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "slack_status_cli"

# Support modules and shared fakes land in T1.2 / T1.3 under spec/support/**.
# The glob is harmless until they exist.
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end

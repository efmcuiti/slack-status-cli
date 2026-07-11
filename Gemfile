source "https://rubygems.org"

ruby ">= 3.2"

# WEBrick was extracted from stdlib in Ruby 3.0; the OAuth flow boots a
# one-shot listener on localhost (loopback) to capture the Slack redirect.
gem "webrick", "~> 1.8"

group :test do
  gem "rspec", "~> 3.13"
  gem "webmock", "~> 3.23"
  gem "simplecov", "~> 0.22", require: false
end

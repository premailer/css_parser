# Keep Gemfile.lock in repo. Reason: https://grosser.it/2015/08/14/check-in-your-gemfile-lock/

source "https://rubygems.org"

gemspec

gem 'rake'
gem 'bump'
gem 'maxitest'
gem 'public_suffix', '~> 1.4.0', platform: [:ruby_19, :jruby]

platforms :jruby do
  gem 'jruby-openssl'
end


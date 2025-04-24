# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in arfi.gemspec
gemspec

gem 'irb'
gem 'rails' unless ENV['RAILS_VERSION']
gem 'rake', '~> 13.0'
gem 'repl_type_completor'
gem 'rspec', '~> 3.0'
gem 'rubocop', '~> 1.21'
gem 'thor'

if ENV['RAILS_VERSION']
  custom_gemfile = File.expand_path("Gemfile-rails-#{ENV['RAILS_VERSION'][..2]}", __dir__)
  eval_gemfile custom_gemfile if File.exist?(custom_gemfile)
end

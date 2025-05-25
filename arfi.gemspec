# frozen_string_literal: true

require_relative 'lib/arfi/version'

Gem::Specification.new do |spec|
  spec.name = 'arfi'
  spec.version = Arfi::VERSION
  spec.authors = ['unurgunite']
  spec.email = ['senpaiguru1488@gmail.com']

  spec.summary = 'ActiveRecord Functional Indexes.'
  spec.description = <<~STR
    ARFI — ActiveRecord Functional Indexes. Provides the ability to create and maintain functions that can be used as indexes, as well as in other parts of the project without switching to structure.sql.
  STR
  spec.homepage = 'https://github.com/unurgunite/arfi'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/unurgunite/arfi'
  spec.metadata['changelog_uri'] = 'https://github.com/unurgunite/arfi/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 6.0'
  spec.add_dependency 'rake', '>= 12.0'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_development_dependency 'irb', '>= 1.15'
  spec.add_development_dependency 'repl_type_completor', '>= 0.1.11'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '>= 1.21'
  spec.add_development_dependency 'steep', '~> 1.3'
  spec.add_development_dependency 'yard', '~> 0.9.37'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end

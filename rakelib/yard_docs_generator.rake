# frozen_string_literal: true

require 'yard'

# run as `rm -rf arfi_docs && bundle exec rake docs:generate && bundle exec rake docs:push`

namespace :docs do
  desc 'Generate new docs and push them repo'
  task :generate do
    puts 'Generating docs...'
    args = %w[--no-cache --private --protected --readme README.md --no-progress --output-dir doc]
    YARD::CLI::Yardoc.run(*args)
    puts 'Docs generated'
  end

  desc 'Push docs to repo'
  task :push do
    puts 'Copying docs...'
    `git clone git@github.com:unurgunite/arfi_docs.git`
    Dir.chdir('arfi_docs') do
      cp_r('../doc/.', '.', remove_destination: true)
      `git add .`
      `git commit -m "Update docs #{Time.now.utc}"`
      `git push`
    end
    rm_rf('arfi_docs')
    puts 'Docs pushed'
  end
end

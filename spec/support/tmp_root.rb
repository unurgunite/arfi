# frozen_string_literal: true

require 'fileutils'

module ArfiSpec
  module TmpRoot
    module_function

    def with_tmp_root
      Dir.mktmpdir('arfi-spec-') do |dir|
        root = Pathname.new(dir)
        FileUtils.mkdir_p(root.join('db/functions'))
        FileUtils.mkdir_p(root.join('db/functions/postgresql'))

        allow(Rails).to receive_messages(root: root, env: ActiveSupport::StringInquirer.new('test'))

        yield root
      end
    end
  end
end

# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

module ArfiSpec
  module TmpRoot
    module_function

    # +ArfiSpec::TmpRoot.with_tmp_root+ -> Object
    #
    # Create a temporary Rails.root with ARFI directory structure, stub Rails.root,
    # yield the root Pathname, then clean it up.
    #
    # @private
    # @yieldparam [Pathname] root Param documentation.
    # @return [Object]
    def with_tmp_root
      Dir.mktmpdir('arfi-spec-') do |dir|
        root = Pathname.new(dir)

        FileUtils.mkdir_p(root.join('db/functions/public'))
        FileUtils.mkdir_p(root.join('db/functions/postgresql/public'))
        FileUtils.mkdir_p(root.join('db/functions/mysql/public'))

        allow(Rails).to receive_messages(root: root, env: ActiveSupport::StringInquirer.new('test'))

        yield root
      end
    end
  end
end

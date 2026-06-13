# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

module ArfiSpec
  module TmpRoot
    SUBDIRS = %w[
      db/functions/public
      db/functions/postgresql/public
      db/functions/mysql/public
      db/triggers/public
      db/triggers/postgresql/public
      db/triggers/mysql/public
    ].freeze

    def self.included(mod)
      mod.let(:root) { build_tmp_root }
      mod.before { allow(Rails).to receive_messages(root: root, env: ActiveSupport::StringInquirer.new('test')) }
      mod.after { FileUtils.rm_rf(root.to_s) }
    end

    def build_tmp_root
      dir = Dir.mktmpdir('arfi-spec-')
      SUBDIRS.each { |s| FileUtils.mkdir_p(Pathname.new(dir).join(s)) }
      Pathname.new(dir)
    end

    def write_function(rel, sql = nil)
      path = root.join(rel)
      path.dirname.mkpath
      path.write(sql || "-- #{rel}\n")
    end
  end
end

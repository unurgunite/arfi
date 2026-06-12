# frozen_string_literal: true

module ArfiSpec
  module DbConnectionHelper
    CONNECTION_ERROR_CLASSES = %w[
      PG::ConnectionBad
      Mysql2::Error::ConnectionError
      ActiveRecord::DatabaseConnectionError
      ActiveRecord::ConnectionNotEstablished
      ActiveRecord::NoDatabaseError
    ].filter_map do |name|
      Object.const_get(name) rescue nil # rubocop:disable Style/RescueModifier
    end

    def self.connection_error?(error)
      CONNECTION_ERROR_CLASSES.any? { |klass| error.is_a?(klass) }
    end
  end
end

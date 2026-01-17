# frozen_string_literal: true

module Arfi
  module Errors
    # Raised when there is no `db/functions` directory in the Rails project.
    class NoFunctionsDir < StandardError
      # +Arfi::Errors::NoFunctionsDir#initialize+ -> Object
      #
      # Method documentation.
      #
      # @param [String] message Param documentation.
      # @return [Object]
      def initialize(message =
                       'There is no such directory: db/functions. Did you run `bundle exec arfi project:create`?')
        @message = message
        super
      end
    end

    # Raised when Rails schema format is not ruby (`schema.rb`).
    class InvalidSchemaFormat < StandardError
      # +Arfi::Errors::InvalidSchemaFormat#initialize+ -> Object
      #
      # Method documentation.
      #
      # @param [String] message Param documentation.
      # @return [Object]
      def initialize(message = 'Invalid schema format. ARFI supports only ruby format schemas.')
        @message = message
        super
      end
    end

    # Raised when the configured/selected adapter is not supported by ARFI.
    class AdapterNotSupported < StandardError
      # +Arfi::Errors::AdapterNotSupported#initialize+ -> Object
      #
      # Method documentation.
      #
      # @param [String] message Param documentation.
      # @return [Object]
      def initialize(message = 'Adapter not supported')
        @message = message
        super
      end
    end
  end
end

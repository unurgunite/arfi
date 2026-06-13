# frozen_string_literal: true

module Arfi
  module Errors
    # Raised when there is no `db/functions` directory in the Rails project.
    class NoFunctionsDir < StandardError
      # Initialize a new NoFunctionsDir error with an optional custom message.
      #
      # @param [String] message Error message
      # @return [void]
      def initialize(message =
                       'There is no such directory: db/functions. Did you run `bundle exec arfi project:create`?')
        @message = message
        super
      end
    end

    # Raised when Rails schema format is not ruby (`schema.rb`).
    class InvalidSchemaFormat < StandardError
      # Initialize a new InvalidSchemaFormat error with an optional custom message.
      #
      # @param [String] message Error message
      # @return [void]
      def initialize(message = 'Invalid schema format. ARFI supports only ruby format schemas.')
        @message = message
        super
      end
    end

    # Raised when the configured/selected adapter is not supported by ARFI.
    class AdapterNotSupported < StandardError
      # Initialize a new AdapterNotSupported error with an optional custom message.
      #
      # @param [String] message Error message
      # @return [void]
      def initialize(message = 'Adapter not supported')
        @message = message
        super
      end
    end

    # Raised when there is no `db/triggers` directory in the Rails project.
    class NoTriggersDir < StandardError
      # Initialize a new NoTriggersDir error with an optional custom message.
      #
      # @param [String] message Error message
      # @return [void]
      def initialize(message =
                       'There is no such directory: db/triggers. Did you run `bundle exec arfi triggers create`?')
        @message = message
        super
      end
    end

    # Raised when a function is not found in the database.
    class FunctionNotFound < StandardError; end
  end
end

# frozen_string_literal: true

module Arfi
  module Errors
    # This error is raised when there is no `db/functions` directory
    class NoFunctionsDir < StandardError
      def initialize(message =
                       'There is no such directory: db/functions. Did you run `bundle exec arfi project:create`?')
        @message = message
        super
      end
    end

    # This error is raised when Rails project schema format is not +schema.rb+
    class InvalidSchemaFormat < StandardError
      def initialize(message = 'Invalid schema format. ARFI supports only ruby format schemas.')
        @message = message
        super
      end
    end

    class AdapterNotSupported < StandardError
      def initialize(message = 'Adapter not supported')
        @message = message
        super
      end
    end
  end
end

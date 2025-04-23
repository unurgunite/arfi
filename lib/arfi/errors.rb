# frozen_string_literal: true

module Arfi
  module Errors
    class NoFunctionsDir < StandardError
      def initialize(message = 'There is no such directory: db/functions. Did you run `bundle exec arfi project:create`?')
        @message = message
        super
      end
    end

    class InvalidSchemaFormat < StandardError
      def initialize(message = 'Invalid schema format. ARFI supports only ruby format schemas.')
        @message = message
        super
      end
    end
  end
end

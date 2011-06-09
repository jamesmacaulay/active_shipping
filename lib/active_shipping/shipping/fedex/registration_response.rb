module ActiveMerchant #:nodoc:
  module Shipping
    class FedExCSP < Carrier
      class RegistrationResponse < Response
        attr_reader :key
        attr_reader :password
      
        def initialize(success, message, params = {}, options = {})
          @key = options[:key]
          @password = options[:password]
          super
        end
      end
    end
  end
end
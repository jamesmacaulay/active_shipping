module ActiveMerchant #:nodoc:
  module Shipping
    class FedExCSP < Carrier
      class RegistrationResponse < Response
        attr_reader :user_key
        attr_reader :user_password
      
        def initialize(success, message, params = {}, options = {})
          @user_key = options[:user_key]
          @user_password = options[:user_password]
          super
        end
      end
    end
  end
end
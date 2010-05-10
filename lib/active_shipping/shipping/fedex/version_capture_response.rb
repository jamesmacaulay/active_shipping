module ActiveMerchant #:nodoc:
  module Shipping
    class FedExCSP < Carrier
      class VersionCaptureResponse < Response
        attr_reader :version, :customer_transaction_id
      
        def initialize(success, message, params = {}, options = {})
          @customer_transaction_id = options[:customer_transaction_id]
          @version = options[:version]
          super
        end
      end
    end    
  end
end
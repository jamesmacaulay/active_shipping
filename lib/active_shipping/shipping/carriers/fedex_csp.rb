# FedEx module by Jimmy Baker
# http://github.com/jimmyebaker
# 
# Updates for user registration, etc. by Edward Ocampo-Gooding <edward@shopify.com>, http://github.com/edward

module ActiveMerchant
  module Shipping
    
    # Requires a valid Compatible Solutions Program (CSP) provider key and password available from Fedex
    
    # :csp_key is a registered CSP provider's API key
    # :csp_password is a registered CSP provider's API password
    # :account_number is a registered user's FedEx account number
    # :meter_number is a registered user's meter number, acquired through a #subscribe call
    # :user_key is a CSP user's key, acquired through a #register call
    # :user_password is a CSP user's password, acquired through a #register call
    #
    class FedExCSP < Carrier
      REGISTRATION_REQUEST_VERSION_CODE = ['fcas', 2, 1, 0]
      SUBSCRIPTION_REQUEST_VERSION_CODE = ['fcas', 2, 1, 0]
      VERSION_CAPTURE_REQUEST_VERSION_CODE = ['fcas', 2, 1, 0]
      RATE_REQUEST_VERSION_CODE = ['crs', 7, 0, 0]
      TRACKING_REQUEST_VERSION_CODE = ['trck', 4, 0, 0]
      
      self.retry_safe = true
      
      cattr_reader :name
      @@name = "FedEx"
      
      TEST_URL = 'https://gatewaybeta.fedex.com:443/xml'
      #LIVE_URL = 'https://gateway.fedex.com:443/xml'
      LIVE_URL = 'https://gateway.fedex.com/web-services'
      
      CarrierCodes = {
        "fedex_ground" => "FDXG",
        "fedex_express" => "FDXE"
      }
      
      ServiceTypes = {
        "PRIORITY_OVERNIGHT" => "FedEx Priority Overnight®",
        "PRIORITY_OVERNIGHT_SATURDAY_DELIVERY" => "FedEx Priority Overnight® Saturday Delivery",
        "FEDEX_2_DAY" => "FedEx 2Day®",
        "FEDEX_2_DAY_SATURDAY_DELIVERY" => "FedEx 2Day® Saturday Delivery",
        "STANDARD_OVERNIGHT" => "FedEx Standard Overnight®",
        "FIRST_OVERNIGHT" => "FedEx First Overnight®",
        "FEDEX_EXPRESS_SAVER" => "FedEx Express Saver®",
        "FEDEX_1_DAY_FREIGHT" => "FedEx 1Day® Freight",
        "FEDEX_1_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 1Day® Freight Saturday Delivery",
        "FEDEX_2_DAY_FREIGHT" => "FedEx 2Day® Freight",
        "FEDEX_2_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 2Day® Freight Saturday Delivery",
        "FEDEX_3_DAY_FREIGHT" => "FedEx 3Day® Freight",
        "FEDEX_3_DAY_FREIGHT_SATURDAY_DELIVERY" => "FedEx 3Day® Freight Saturday Delivery",
        "INTERNATIONAL_PRIORITY" => "FedEx International Priority®",
        "INTERNATIONAL_PRIORITY_SATURDAY_DELIVERY" => "FedEx International Priority® Saturday Delivery",
        "INTERNATIONAL_ECONOMY" => "FedEx International Economy®",
        "INTERNATIONAL_FIRST" => "FedEx International First®",
        "INTERNATIONAL_PRIORITY_FREIGHT" => "FedEx International Priority® Freight",
        "INTERNATIONAL_ECONOMY_FREIGHT" => "FedEx International Economy® Freight",
        "GROUND_HOME_DELIVERY" => "FedEx Ground Home Delivery®",
        "FEDEX_GROUND" => "FedEx Ground®",
        "INTERNATIONAL_GROUND" => "FedEx International Ground®"
      }

      PackageTypes = {
        "fedex_envelope" => "FEDEX_ENVELOPE",
        "fedex_pak" => "FEDEX_PAK",
        "fedex_box" => "FEDEX_BOX",
        "fedex_tube" => "FEDEX_TUBE",
        "fedex_10_kg_box" => "FEDEX_10KG_BOX",
        "fedex_25_kg_box" => "FEDEX_25KG_BOX",
        "your_packaging" => "YOUR_PACKAGING"
      }

      DropoffTypes = {
        'regular_pickup' => 'REGULAR_PICKUP',
        'request_courier' => 'REQUEST_COURIER',
        'dropbox' => 'DROP_BOX',
        'business_service_center' => 'BUSINESS_SERVICE_CENTER',
        'station' => 'STATION'
      }

      PaymentTypes = {
        'sender' => 'SENDER',
        'recipient' => 'RECIPIENT',
        'third_party' => 'THIRDPARTY',
        'collect' => 'COLLECT'
      }
      
      PackageIdentifierTypes = {
        'tracking_number' => 'TRACKING_NUMBER_OR_DOORTAG',
        'door_tag' => 'TRACKING_NUMBER_OR_DOORTAG',
        'rma' => 'RMA',
        'ground_shipment_id' => 'GROUND_SHIPMENT_ID',
        'ground_invoice_number' => 'GROUND_INVOICE_NUMBER',
        'ground_customer_reference' => 'GROUND_CUSTOMER_REFERENCE',
        'ground_po' => 'GROUND_PO',
        'express_reference' => 'EXPRESS_REFERENCE',
        'express_mps_master' => 'EXPRESS_MPS_MASTER'
      }

      def self.service_name_for_code(service_code)
        ServiceTypes[service_code] || begin
          name = service_code.downcase.split('_').collect{|word| word.capitalize }.join(' ')
          "FedEx #{name.sub(/Fedex /, '')}"
        end
      end
      
      def requirements
        [:csp_key, :csp_password]
      end
      
      def user_credentials
        {:account_number => @options[:account_number],
         :meter_number => @options[:meter_number],
         :user_key => @options[:user_key],
         :user_password => @options[:user_password]}
      end
      
      def register_user(options = {})
        options = @options.update(options)
        
        register_user_request = build_registration_request
        response = commit(save_request(register_user_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_registration_response(response, options)
      end
      
      def subscribe_user(options = {})
        options = @options.update(options)
        subscribe_user_request = build_subscription_request
        response = commit(save_request(subscribe_user_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        parse_subscription_response(response, options)
      end
      
      # Example usage:
      # 
      #  version_capture('Version Capture Request', :origin_location_id => 'VXYZ(FedEx Provided)', :vendor_product_platform => 'Windows OS')
      # 
      def version_capture(customer_transaction_id, options = {})
        options = @options.update(options)
        
        version_capture_request = build_version_capture_request(customer_transaction_id)
        response = commit(save_request(version_capture_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_version_capture_response(response, options)
      end
      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        rate_request = build_rate_request(origin, destination, packages, options)
        response = commit(save_request(rate_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(save_request(tracking_request), (options[:test] || false)).gsub(/<(\/)?.*?\:(.*?)>/, '<\1\2>')
        
        parse_tracking_response(response, options)
      end
      
      protected
      
      def build_registration_request
        xml_request = XmlNode.new('RegisterWebCspUserRequest', 'xmlns' => 'http://fedex.com/ws/registration/v2') do |root_node|
          root_node << XmlNode.new('WebAuthenticationDetail') do |wad|
            wad << XmlNode.new('CspCredential') do |cc|
              cc << XmlNode.new('Key', @options[:csp_key])
              cc << XmlNode.new('Password', @options[:csp_password])
            end
          end
          
          root_node << XmlNode.new('ClientDetail') do |cd|
            cd << XmlNode.new('AccountNumber', @options[:account_number])
            cd << XmlNode.new('ClientProductId', @options[:client_product_id])
            cd << XmlNode.new('ClientProductVersion', @options[:client_product_version])
            cd << XmlNode.new('Region', @options[:client_region])
          end
          
          root_node << XmlNode.new('TransactionDetail') do |td|
            td << XmlNode.new('CustomerTransactionId', 'Registration Request')
          end
          
          root_node << build_version_node(REGISTRATION_REQUEST_VERSION_CODE)
          
          root_node << XmlNode.new('Categories', @options[:categories])
          
          root_node << XmlNode.new('BillingAddress') do |ba|
            ba << XmlNode.new('StreetLines', @options[:billing_street_lines])
            ba << XmlNode.new('City', @options[:billing_city])
            ba << XmlNode.new('StateOrProvinceCode', @options[:billing_state_or_province_code])
            ba << XmlNode.new('PostalCode', @options[:billing_postal_code])
            ba << XmlNode.new('CountryCode', @options[:billing_country_code])
          end
          
          root_node << XmlNode.new('UserContactAndAddress') do |uca|
            uca << XmlNode.new('Contact') do |c|
              c << XmlNode.new('PersonName') do |pn|
                pn << XmlNode.new('FirstName', @options[:user_first_name])
                pn << XmlNode.new('LastName', @options[:user_last_name])
              end
              
              c << XmlNode.new('CompanyName', @options[:user_company_name])
              c << XmlNode.new('PhoneNumber', @options[:user_phone_number])
              c << XmlNode.new('EMailAddress', @options[:user_email])
            end
            
            uca << XmlNode.new('Address') do |a|
              a << XmlNode.new('StreetLines', @options[:user_streetlines])
              a << XmlNode.new('City', @options[:user_city])
              a << XmlNode.new('StateOrProvinceCode', @options[:user_state_or_province_code])
              a << XmlNode.new('PostalCode', @options[:user_postal_code])
              a << XmlNode.new('CountryCode', @options[:user_country_code])
            end
          end
        end
        
        xml_request.to_s
      end
      
      def build_subscription_request
        xml_request = XmlNode.new('SubscriptionRequest', 'xmlns' => 'http://fedex.com/ws/registration/v2') do |root_node|
          root_node << XmlNode.new('WebAuthenticationDetail') do |wad|
            wad << XmlNode.new('CspCredential') do |cc|
              cc << XmlNode.new('Key', @options[:csp_key])
              cc << XmlNode.new('Password', @options[:csp_password])
            end
            
            wad << XmlNode.new('UserCredential') do |uc|
              uc << XmlNode.new('Key', @options[:user_key])
              uc << XmlNode.new('Password', @options[:user_password])
            end
          end
          
          root_node << XmlNode.new('ClientDetail') do |cd|
            cd << XmlNode.new('AccountNumber', @options[:account_number])
            cd << XmlNode.new('MeterNumber')
            cd << XmlNode.new('ClientProductId', @options[:client_product_id])
            cd << XmlNode.new('ClientProductVersion', @options[:client_product_version])
          end
          
          root_node << XmlNode.new('TransactionDetail') do |td|
            td << XmlNode.new('CustomerTransactionId', 'Subscription Request')
          end
          
          root_node << build_version_node(SUBSCRIPTION_REQUEST_VERSION_CODE)
          
          root_node << XmlNode.new('CspSolutionId', @options[:csp_solution_id])
          root_node << XmlNode.new('CspType', 'CERTIFIED_SOLUTION_PROVIDER')
          
          root_node << XmlNode.new('Subscriber') do |s|
            s << XmlNode.new('AccountNumber', @options[:account_number])
            s << XmlNode.new('Contact') do |c|
              c << XmlNode.new('PersonName', @options[:user_first_name] + ' ' + @options[:user_last_name])
              
              c << XmlNode.new('CompanyName', @options[:user_company_name])
              c << XmlNode.new('PhoneNumber', @options[:user_phone_number])
              c << XmlNode.new('FaxNumber', @options[:user_fax_number])
              c << XmlNode.new('EMailAddress', @options[:user_email])
            end
            
            s << XmlNode.new('Address') do |a|
              a << XmlNode.new('StreetLines', @options[:user_streetlines])
              a << XmlNode.new('City', @options[:user_city])
              a << XmlNode.new('StateOrProvinceCode', @options[:user_state_or_province_code])
              a << XmlNode.new('PostalCode', @options[:user_postal_code])
              a << XmlNode.new('CountryCode', @options[:user_country_code])
            end
          end
          
          root_node << XmlNode.new('AccountShippingAddress') do |asa|
            asa << XmlNode.new('StreetLines', @options[:billing_street_lines])
            asa << XmlNode.new('City', @options[:billing_city])
            asa << XmlNode.new('StateOrProvinceCode', @options[:billing_state_or_province_code])
            asa << XmlNode.new('PostalCode', @options[:billing_postal_code])
            asa << XmlNode.new('CountryCode', @options[:billing_country_code])
          end
        end
        
        xml_request.to_s
      end
      
      def build_version_capture_request(customer_transaction_id)
        xml_request = XmlNode.new('VersionCaptureRequest', 'xmlns' => 'http://fedex.com/ws/registration/v2') do |root_node|
          root_node << XmlNode.new('WebAuthenticationDetail') do |wad|
            wad << XmlNode.new('CspCredential') do |cc|
              cc << XmlNode.new('Key', @options[:csp_key])
              cc << XmlNode.new('Password', @options[:csp_password])
            end
            
            wad << XmlNode.new('UserCredential') do |uc|
              uc << XmlNode.new('Key', @options[:user_key])
              uc << XmlNode.new('Password', @options[:user_password])
            end
          end
          
          root_node << XmlNode.new('ClientDetail') do |cd|
            cd << XmlNode.new('AccountNumber', @options[:account_number])
            cd << XmlNode.new('MeterNumber', @options[:meter_number])
            cd << XmlNode.new('ClientProductId', @options[:client_product_id])
            cd << XmlNode.new('ClientProductVersion', @options[:client_product_version])
            cd << XmlNode.new('Region', @options[:client_region])
          end
          
          root_node << XmlNode.new('TransactionDetail') do |td|
            td << XmlNode.new('CustomerTransactionId', customer_transaction_id)
          end
          
          root_node << build_version_node(VERSION_CAPTURE_REQUEST_VERSION_CODE)
          
          root_node << XmlNode.new('OriginLocationId', @options[:origin_location_id])
          root_node << XmlNode.new('VendorProductPlatform', @options[:vendor_product_platform])
        end
        
        xml_request.to_s
      end
      
      def build_rate_request(origin, destination, packages, options = {})
        imperial = (packages.first.options[:units] == :imperial) ? true : false

        xml_request = XmlNode.new('RateRequest', 'xmlns' => 'http://fedex.com/ws/rate/v7') do |root_node|
          root_node << build_request_header
          
          root_node << build_version_node(RATE_REQUEST_VERSION_CODE)
          
          # Returns delivery dates
          root_node << XmlNode.new('ReturnTransitAndCommit', true)
          
          root_node << XmlNode.new('CarrierCodes', options[:carrier_code]) if options[:carrier_code]
          
          # FIXME - remove when requesting rates for a specific service
          # Returns saturday delivery shipping options when available
          # root_node << XmlNode.new('VariableOptions', 'SATURDAY_DELIVERY')
          
          root_node << XmlNode.new('RequestedShipment') do |rs|
            rs << XmlNode.new('ShipTimestamp', options[:ship_date] || Time.now)
            rs << XmlNode.new('DropoffType', options[:dropoff_type] || 'REGULAR_PICKUP')
            rs << XmlNode.new('ServiceType', options[:service_type]) if options[:service_type]
            rs << XmlNode.new('PackagingType', options[:packaging_type] || 'YOUR_PACKAGING')
            
            rs << build_location_node('Shipper', options[:shipper] || origin)
            rs << build_location_node('Recipient', destination)
            
            if options[:shipper] && options[:shipper] != origin
              rs << build_location_node('Origin', origin)
            end
            
            if options[:shipping_charges]
              rs << XmlNode.new('ShippingChargesPayment') do |scp|
                scp << XmlNode.new('PaymentType', options[:shipping_charges][:payment_type])
                scp << XmlNode.new('Payor') do |payor|
                  payor << XmlNode.new('AccountNumber', options[:shipping_charges][:payor_account_number])
                  payor << XmlNode.new('CountryCode', options[:shipping_charges][:payor_country_code])
                end
              end
            end
            
            if options[:saturday_pickup] || options[:saturday_delivery] || options[:cod] || options[:dry_ice] || options[:hold_at_location] ||  options[:home_delivery_premium]
              rs << XmlNode.new('SpecialServicesRequested') do |ssr|
                ssr << XmlNode.new('SpecialServiceTypes', 'SATURDAY_PICKUP') if options[:saturday_pickup]
                ssr << XmlNode.new('SpecialServiceTypes', 'SATURDAY_DELIVERY') if options[:saturday_delivery]
                ssr << XmlNode.new('SpecialServiceTypes', 'DRY_ICE') if options[:dry_ice]
                #ssr << XmlNode.new('SpecialServiceTypes', 'COD') if options[:cod]
                ssr << XmlNode.new('SpecialServiceTypes', 'HOLD_AT_LOCATION') if options[:hold_at_location]
                ssr << XmlNode.new('SpecialServiceTypes', 'HOME_DELIVERY_PREMIUM') if options[:home_delivery_premium]
              
                if options[:cod]
                  ssr << XmlNode.new('CodDetail') do |cd|
                    cd << XmlNode.new('CollectionType', options[:cod][:type] || 'ANY')
                  end
                  ssr << XmlNode.new('CodCollectionAmount') do |cda|
                    cda << XmlNode.new('Currency', options[:cod][:currency])
                    cda << XmlNode.new('Amount', options[:cod][:amount])
                  end
                end
                
                if options[:hold_at_location]
                  ssr << XmlNode.new('HoldAtLocationDetail') do |hald|
                    location = options[:hold_at_location]
                    hald << XmlNode.new('PhoneNumber', location.phone)
                    hald << XmlNode.new('Address') do |address_node|
                      address_node << XmlNode.new('StreetLines', location.address1)
                      address_node << XmlNode.new('City', location.city)
                      address_node << XmlNode.new('StateOrProvinceCode', location.province)
                      address_node << XmlNode.new('PostalCode', location.postal_code)
                      address_node << XmlNode.new('UrbanizationCode', location.address2)
                      address_node << XmlNode.new("CountryCode", location.country_code(:alpha2))
                      address_node << XmlNode.new("Residential", true) if location.address_type == 'residential'
                    end
                  end
                end
                
                if options[:dry_ice]
                  ssr << XmlNode.new('ShipmentDryIceDetail') do |sdid|
                    sdid << XmlNode.new('PackageCount', options[:dry_ice][:quantity]) if options[:dry_ice][:quantity]
                    sdid << XmlNode.new('TotalWeight') do |tw|
                      tw << XmlNode.new('Units', options[:dry_ice][:weight_units])
                      tw << XmlNode.new('Value', options[:dry_ice][:weight_value])
                    end
                  end
                end
                
                if options[:home_delivery_premium]
                  ssr << XmlNode.new('HomeDeliveryPremiumDetail') do |sdid|
                    sdid << XmlNode.new('HomeDeliveryPremiumType', options[:home_delivery_premium][:type])
                    sdid << XmlNode.new('Date', options[:home_delivery_premium][:date].strftime("%Y-%m-%d"))
                    sdid << XmlNode.new('PhoneNumber', options[:home_delivery_premium][:phone])
                  end
                end
              end
            end
            
            if options[:customs_value]
              rs << XmlNode.new('InternationalDetail') do |intd|
                intd << XmlNode.new('CustomsValue') do |cv|
                  cv << XmlNode.new('Currency', packages.first.currency)
                  cv << XmlNode.new('Amount', "%.2f" % Integer(options[:customs_value]))
                end
              end
            end
            
            rs << XmlNode.new('RateRequestTypes', options[:rate_request_types] || 'ACCOUNT')
            rs << XmlNode.new('PackageCount', packages.size)
            
            rs << XmlNode.new('PackageDetail', 'INDIVIDUAL_PACKAGES')
            
            packages.each_with_index do |pkg, i|
              rs << XmlNode.new('RequestedPackageLineItems') do |rps|
                rps << XmlNode.new('SequenceNumber', "%03d" % (i + 1))
                if packages.first.options[:value]
                  rps << XmlNode.new('InsuredValue') do |iv|
                    iv << XmlNode.new('Currency', packages.first.currency)
                    iv << XmlNode.new('Amount', packages.first.options[:value])
                  end
                end
                rps << XmlNode.new('Weight') do |tw|
                  tw << XmlNode.new('Units', imperial ? 'LB' : 'KG')
                  tw << XmlNode.new('Value', [((imperial ? pkg.lbs : pkg.kgs).to_f*1000).round/1000.0, 0.1].max)
                end

                unless [:length,:width,:height].all? { |v| pkg.inches(v) == 0 }
                  rps << XmlNode.new('Dimensions') do |dimensions|
                    [:length,:width,:height].each do |axis|
                      value = ((imperial ? pkg.inches(axis) : pkg.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                      dimensions << XmlNode.new(axis.to_s.capitalize, value.ceil)
                    end
                    dimensions << XmlNode.new('Units', imperial ? 'IN' : 'CM')
                  end
                end
                
                rps << XmlNode.new('SpecialServicesRequested') do |ssr|
                  ssr << XmlNode.new('SpecialServiceTypes', 'DANGEROUS_GOODS') if options[:dangerous_goods]
                  ssr << XmlNode.new('SpecialServiceTypes', 'SIGNATURE_OPTION') if options[:signature_option]
                  ssr << XmlNode.new('SpecialServiceTypes', 'NON_STANDARD_CONTAINER') if options[:non_standard_container]
                  ssr << XmlNode.new('SpecialServiceTypes', 'DRY_ICE') if pkg.options[:dry_ice]
                  
                  if dg = options[:dangerous_goods]
                    ssr << XmlNode.new('DangerousGoodsDetail') do |dgd|
                      dgd << XmlNode.new('Accessibility', dg[:accessibility]) if dg[:accessibility]
                      dgd << XmlNode.new('CargoAircraftOnly', dg[:cargo_aircraft_only])
                      dgd << XmlNode.new('HazMatCertificateData') do |hmc|
                        hmc << XmlNode.new('DotProperShippingName', dg[:dot_proper_shipping_name])
                        hmc << XmlNode.new('DotHazardClassOrDivision', dg[:dot_hazard_class_or_division])
                        hmc << XmlNode.new('DotIdNumber', dg[:dot_id_number])
                        hmc << XmlNode.new('DotLabelType', dg[:dot_label_type])
                        hmc << XmlNode.new('PackingGroup', dg[:packing_group])
                        hmc << XmlNode.new('Quantity', dg[:quantity])
                        hmc << XmlNode.new('Units', dg[:units])
                        hmc << XmlNode.new('TwentyFourHourEmergencyResponseContactNumber', dg[:twenty_four_hour_emergency_response_contact_number])
                        hmc << XmlNode.new('TwentyFourHourEmergencyResponseContactName', dg[:twenty_four_hour_emergency_response_contact_name])
                      end
                    end
                  end
                  
                  if pkg.options[:dry_ice]
                    ssr << XmlNode.new('DryIceWeight') do |diw|
                      diw << XmlNode.new('Units', 'KG')
                      diw << XmlNode.new('Value', pkg.options[:dry_ice].to_kilograms.amount)
                    end
                  end
                  
                  if options[:signature_option]
                    ssr << XmlNode.new('SignatureOptionDetail') do |sod|
                      sod << XmlNode.new('OptionType', options[:signature_option])
                    end
                  end
                end
              end
            end
            
          end
        end
        xml_request.to_s
      end
      
      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest', 'xmlns' => 'http://fedex.com/ws/track/v4') do |root_node|
          root_node << build_request_header
          
          root_node << build_version_node(TRACKING_REQUEST_VERSION_CODE)
          
          root_node << XmlNode.new('PackageIdentifier') do |package_node|
            package_node << XmlNode.new('Value', tracking_number)
            package_node << XmlNode.new('Type', PackageIdentifierTypes[options['package_identifier_type'] || 'tracking_number'])
          end
          
          # root_node << XmlNode.new('ShipDateRangeBegin', options['ship_date_range_begin']) if options['ship_date_range_begin']
          # root_node << XmlNode.new('ShipDateRangeEnd', options['ship_date_range_end']) if options['ship_date_range_end']
          root_node << XmlNode.new('IncludeDetailedScans', true)
        end
        xml_request.to_s
      end
      
      def build_request_header
        web_authentication_detail = XmlNode.new('WebAuthenticationDetail') do |wad|
          wad << XmlNode.new('CspCredential') do |cc|
            cc << XmlNode.new('Key', @options[:csp_key])
            cc << XmlNode.new('Password', @options[:csp_password])
          end
          
          wad << XmlNode.new('UserCredential') do |uc|
            uc << XmlNode.new('Key', @options[:user_key])
            uc << XmlNode.new('Password', @options[:user_password])
          end
        end
        
        client_detail = XmlNode.new('ClientDetail') do |cd|
          cd << XmlNode.new('AccountNumber', @options[:account_number])
          cd << XmlNode.new('MeterNumber', @options[:meter_number])
          cd << XmlNode.new('ClientProductId', @options[:client_product_id])
          cd << XmlNode.new('ClientProductVersion', @options[:client_product_version])
        end
        
        trasaction_detail = XmlNode.new('TransactionDetail') do |td|
          td << XmlNode.new('CustomerTransactionId', @options[:customer_transaction_id] || 'ActiveShipping')
        end
        
        [web_authentication_detail, client_detail, trasaction_detail]
      end
            
      def build_location_node(name, location, options = {})
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('AccountNumber', options[:account_number])
          
          xml_node << XmlNode.new('Contact') do |c|
            c << XmlNode.new('PersonName', location.person_name)
            c << XmlNode.new('CompanyName', location.company_name)
            c << XmlNode.new('PhoneNumber', location.phone)
          end
          
          xml_node << XmlNode.new('Address') do |address_node|
            address_node << XmlNode.new('StreetLines', location.address1)
            address_node << XmlNode.new('City', location.city)
            address_node << XmlNode.new('StateOrProvinceCode', location.province)
            address_node << XmlNode.new('PostalCode', location.postal_code)
            address_node << XmlNode.new("CountryCode", location.country_code(:alpha2))
            address_node << XmlNode.new("Residential", true) if location.address_type == 'residential'
          end
        end
      end
      
      def build_version_node(version)
        version_node = XmlNode.new('Version') do |v|
          v << XmlNode.new('ServiceId', version[0])
          v << XmlNode.new('Major', version[1])
          v << XmlNode.new('Intermediate', version[2])
          v << XmlNode.new('Minor', version[3])
        end
      end
      
      def preparse_response(response)
        REXML::Document.new(response)
      rescue REXML::ParseException
        # Some Bea-backed FedEx errors are invalid XML that cause REXML to choke
        # so just raise an error with the response
        raise StandardError, response
      end
      
      def parse_rate_response(origin, destination, packages, response, options)
        rate_estimates = []
        success, message = nil
        
        xml = preparse_response(response)
        root_node = xml.elements['RateReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        root_node.elements.each('RateReplyDetails') do |rated_shipment|
          service_code = rated_shipment.get_text('ServiceType').to_s
          is_saturday_delivery = rated_shipment.get_text('AppliedOptions').to_s == 'SATURDAY_DELIVERY'
          service_type = is_saturday_delivery ? "#{service_code}_SATURDAY_DELIVERY" : service_code
          
          currency = handle_uk_currency(rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Currency').to_s)
          rate_estimates << RateEstimate.new(origin, destination, @@name,
                              self.class.service_name_for_code(service_type),
                              :service_code => service_code,
                              :total_price => rated_shipment.get_text('RatedShipmentDetails/ShipmentRateDetail/TotalNetCharge/Amount').to_s.to_f,
                              :currency => currency,
                              :packages => packages,
                              :delivery_date => rated_shipment.get_text('DeliveryTimestamp').to_s)
        end
        
        if rate_estimates.empty?
          success = false
          message = "No shipping rates could be found for the destination address" if message.blank?
        end

        RateResponse.new(success, message, Hash.from_xml(response), 
          :xml => response,
          :request => last_request,
          :log_xml => options[:log_xml],
          :test => options[:test],
          :rates => rate_estimates)
      end
      
      def parse_tracking_response(response, options)
        xml = preparse_response(response)
        root_node = xml.elements['TrackReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          tracking_number, origin, destination = nil
          shipment_events = []
          
          tracking_details = root_node.elements['TrackDetails']
          tracking_number = tracking_details.get_text('TrackingNumber').to_s
          
          destination_node = tracking_details.elements['DestinationAddress']
          destination = Location.new(
            :country => destination_node.get_text('CountryCode').to_s,
            :province => destination_node.get_text('StateOrProvinceCode').to_s,
            :city => destination_node.get_text('City').to_s)
          
          tracking_details.elements.each('Events') do |event|
            address  = event.elements['Address']

            city     = address.get_text('City').to_s
            state    = address.get_text('StateOrProvinceCode').to_s
            zip_code = address.get_text('PostalCode').to_s
            country  = address.get_text('CountryCode').to_s
            next if country.blank?
            
            description = event.get_text('EventDescription').to_s
            event_type = event.get_text('EventType').to_s
            
            location = nil
            if event_type != 'OC'
              location = Location.new(:city => city, :state => state, :postal_code => zip_code, :country => country)
            end
            
            description = event.get_text('EventDescription').to_s
            time = Time.parse(event.get_text('Timestamp').to_s)
            
            shipment_events << ShipmentEvent.new(description, time.utc, location)
          end
          shipment_events = shipment_events.sort_by(&:time)
        end
        
        TrackingResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :destination => destination,
          :tracking_number => tracking_number
        )
      end
      
      def parse_registration_response(response, options)
        xml = preparse_response(response)
        root_node = xml.elements['RegisterWebCspUserReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          version_details = root_node.elements['Version']
          version = {:service_id => version_details.get_text('ServiceId').to_s,
                     :major => version_details.get_text('Major').to_s,
                     :intermediate => version_details.get_text('Intermediate').to_s,
                     :minor => version_details.get_text('Minor').to_s}
          
          credentials_details = root_node.elements['Credential']
          @options[:user_key] = credentials_details.get_text('Key').to_s
          @options[:user_password] = credentials_details.get_text('Password').to_s
        end
        
        RegistrationResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :log_xml => options[:log_xml],
          :request => last_request,
          :test => options[:test],
          :user_key => @options[:user_key],
          :user_password => @options[:user_password],
          :version => version
        )
      end
      
      def parse_subscription_response(response, options)
        xml = preparse_response(response)
        root_node = xml.elements['SubscriptionReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          version_details = root_node.elements['Version']
          version = {:service_id => version_details.get_text('ServiceId').to_s,
                     :major => version_details.get_text('Major').to_s,
                     :intermediate => version_details.get_text('Intermediate').to_s,
                     :minor => version_details.get_text('Minor').to_s}
          
          @options[:meter_number] = root_node.get_text('MeterNumber').to_s
        end
        
        SubscriptionResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :log_xml => options[:log_xml],
          :request => last_request,
          :test => options[:test],
          :meter_number => @options[:meter_number]
        )
      end
      
      def parse_version_capture_response(response, options)
        xml = preparse_response(response)
        root_node = xml.elements['VersionCaptureReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        version = nil
        
        if success
          version_details = root_node.elements['Version']
          version = {:service_id => version_details.get_text('ServiceId').to_s,
                     :major => version_details.get_text('Major').to_s,
                     :intermediate => version_details.get_text('Intermediate').to_s,
                     :minor => version_details.get_text('Minor').to_s}
          
          @options[:version_service_id] = version[:service_id]
          @options[:version_major] = version[:major]
          @options[:version_intermediate] = version[:intermediate]
          @options[:version_minor] = version[:minor]
          
          transaction_detail = root_node.elements['TransactionDetail']
          customer_transaction_id = transaction_detail.get_text('CustomerTransactionId').to_s
        end
        
        VersionCaptureResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :log_xml => options[:log_xml],
          :request => last_request,
          :test => options[:test],
          :customer_transaction_id => customer_transaction_id,
          :version => version
        )
      end
      
      def response_status_node(document)
        document.elements['/*/Notifications/']
      end
      
      def response_success?(document)
        %w{SUCCESS WARNING NOTE}.include? response_status_node(document).get_text('Severity').to_s
      end
      
      def response_message(document)
        response_node = response_status_node(document)
        "#{response_status_node(document).get_text('Severity').to_s} - #{response_node.get_text('Code').to_s}: #{response_node.get_text('Message').to_s}"
      end
      
      def commit(request, test = false)
        ssl_post(test ? TEST_URL : LIVE_URL, request.gsub("\n",''))
      end
      
      def handle_uk_currency(currency)
        currency =~ /UKL/i ? 'GBP' : currency
      end
    end
  end
end

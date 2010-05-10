require 'test_helper'

class FedExCSPTest < Test::Unit::TestCase
  def setup
    @packages               = TestFixtures.packages
    @locations              = TestFixtures.locations
    @carrier                = FedExCSP.new(:csp_key => '1111', :csp_password => '2222', :account_number => '3333', :meter_number => '4444', :user_key => '5555', :user_password => '6666', :client_product_id => '7777', :client_product_version => '8888', :categories => 'SHIPPING')
  end
  
  def test_initialize_options_requirements
    assert_raises(ArgumentError) { FedExCSP.new }
    assert_raises(ArgumentError) { FedExCSP.new(:login => '999999999') }
    assert_raises(ArgumentError) { FedExCSP.new(:password => '7777777') }
    assert_nothing_raised { FedExCSP.new(:csp_key => '999999999', :csp_password => '7777777') }
  end
  
  def test_register_user_returns_a_registration_response
    @carrier = FedExCSP.new(:csp_key => 'CSP KEY', :csp_password => 'CSP PWD', :account_number => '000000000', :client_product_id => 'ABCD', :client_product_version => '1234', :categories => 'SHIPPING')
    
    @carrier.expects(:commit).returns(xml_fixture('fedex_csp/registration_response'))
    assert_instance_of ActiveMerchant::Shipping::FedExCSP::RegistrationResponse, @carrier.register_user(registration_parameters)
  end
  
  def test_building_request_and_parsing_registration_response
    @carrier = FedExCSP.new(:csp_key => 'CSP KEY', :csp_password => 'CSP PWD', :client_product_id => 'ABCD', :client_product_version => '1234', :client_region => 'US', :categories => 'SHIPPING')
    
    expected_request = xml_fixture('fedex_csp/registration_request')
    mock_response = xml_fixture('fedex_csp/registration_response')
    
    @carrier.expects(:commit).with {|request, test_mode| Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode}.returns(mock_response)
    response = @carrier.register_user(registration_parameters.merge({:test => true}))
    
    assert_equal 'Generated USER KEY', response.user_key
    assert_equal 'Generated USER PWD', response.user_password
  end
  
  def test_building_and_parsing_subscription_response
    @carrier = FedExCSP.new(:csp_solution_id => '000 (FedEx Provided)', :csp_key => 'CSP KEY', :csp_password => 'CSP PWD', :user_key => 'Generated USER KEY', :user_password => 'Generated USER PWD', :user_first_name => 'Your', :user_last_name => 'Name', :user_phone_number => 'Your Phone #', :user_fax_number => '', :user_email => 'abc@xyz.com', :user_streetlines => 'Your Address Info', :user_city => ' Your Address Info ', :user_state_or_province_code => ' Your State Code ', :user_postal_code => 'Your Postal Code', :user_country_code => ' Your Address Info ', :billing_street_lines => ' Your Address Info ', :billing_city => ' Your Address Info ', :billing_state_or_province_code => ' Your Address Info ', :billing_postal_code => ' Your Address Info ', :billing_postal_code => 'Your Address Info ', :billing_country_code => ' Your Address Info ', :account_number => '000000000', :client_product_id => 'ABCD', :client_product_version => '1234', :categories => 'SHIPPING')
    
    expected_request = xml_fixture('fedex_csp/subscription_request')
    mock_response = xml_fixture('fedex_csp/subscription_response')
    
    @carrier.expects(:commit).with do |request, test_mode| 
      Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode
    end.returns(mock_response)
    response = @carrier.subscribe_user(:test => true)
    
    assert_equal 'Generated Meter Number', response.meter_number
  end
  
  def test_building_and_parsing_version_capture_response
    @carrier = FedExCSP.new(:csp_key => 'CSP KEY', :csp_password => 'CSP PWD', :user_key => 'Generated USER KEY', :user_password => 'Generated USER PWD', :account_number => '000000000', :meter_number => 'Generated Meter Number', :client_product_id => 'ABCD', :client_product_version => '1234', :client_region => 'US or CA', :origin_location_id => 'VXYZ(FedEx)', :vendor_product_platform => 'Windows OS')
    
    expected_request = xml_fixture('fedex_csp/version_capture_request')
    mock_response = xml_fixture('fedex_csp/version_capture_response')
    
    @carrier.expects(:commit).with do |request, test_mode| 
      Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode
    end.returns(mock_response)
    
    response = @carrier.version_capture('Version Capture Request', :origin_location_id => 'VXYZ(FedEx Provided)', :vendor_product_platform => 'Windows OS', :test => true)

    assert_equal 'Version Capture Request', response.customer_transaction_id
  end
  
  # def test_no_rates_response
  #   @carrier.expects(:commit).returns(xml_fixture('fedex_csp/empty_response'))
  # 
  #   response = @carrier.find_rates(
  #     @locations[:ottawa],                                
  #     @locations[:beverly_hills],            
  #     @packages.values_at(:book, :wii)
  #   )
  #   assert_equal "WARNING - 556: There are no valid services available. ", response.message
  # end
  
  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(xml_fixture('fedex_csp/tracking_response'))
    assert_instance_of ActiveMerchant::Shipping::TrackingResponse, @carrier.find_tracking_info('077973360403984', :test => true)
  end
  
  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(xml_fixture('fedex_csp/tracking_response'))
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal 6, response.shipment_events.size
  end
  
  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(xml_fixture('fedex_csp/tracking_response'))
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end
  
  def test_find_tracking_info_should_not_include_events_without_an_address
    @carrier.expects(:commit).returns(xml_fixture('fedex_csp/tracking_response'))
    assert_nothing_raised do
      response = @carrier.find_tracking_info('077973360403984', :test => true)
      assert_nil response.shipment_events.find{|event| event.name == 'Shipment information sent to FedEx' }
    end
  end
  
  def test_building_rating_request_and_parsing_response
    expected_request = xml_fixture('fedex_csp/ottawa_to_beverly_hills_rate_request')
    mock_response = xml_fixture('fedex_csp/ottawa_to_beverly_hills_rate_response')
    Time.any_instance.expects(:to_xml_value).returns("2009-07-20T12:01:55-04:00")
    
    @carrier.expects(:commit).with do |request, test_mode|
      Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode
    end.returns(mock_response)
    
    response = @carrier.find_rates(@locations[:ottawa],
                                   @locations[:beverly_hills],
                                   @packages.values_at(:book, :wii), :test => true)
    assert_equal ["FedEx Ground®"], response.rates.map(&:service_name)
    assert_equal [3836], response.rates.map(&:price)
    
    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates
    
    rate = response.rates.first
    assert_equal 'FedEx', rate.carrier
    assert_equal 'CAD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :wii), rate.packages
    
    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end
  
  def test_service_name_for_code
    FedExCSP::ServiceTypes.each do |capitalized_name, readable_name|
      assert_equal readable_name, FedExCSP.service_name_for_code(capitalized_name)
    end
  end
  
  def test_service_name_for_code_handles_yet_unknown_codes
    assert_equal "FedEx Express Saver Saturday Delivery", FedExCSP.service_name_for_code('FEDEX_EXPRESS_SAVER_SATURDAY_DELIVERY')
    assert_equal "FedEx Some Weird Rate", FedExCSP.service_name_for_code('SOME_WEIRD_RATE')
  end
  
  def test_returns_gbp_instead_of_ukl_currency_for_uk_rates
    mock_response = xml_fixture('fedex_csp/ottawa_to_beverly_hills_rate_response').gsub('CAD', 'UKL')
    Time.any_instance.expects(:to_xml_value).returns("2009-07-20T12:01:55-04:00")
    
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( @locations[:ottawa],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:book, :wii), :test => true)
    assert_equal ["FedEx Ground®"], response.rates.map(&:service_name)
    assert_equal [3836], response.rates.map(&:price)
    
    assert response.success?, response.message
    assert_not_equal [], response.rates
    
    response.rates.each do |rate|
      assert_equal 'FedEx', rate.carrier
      assert_equal 'GBP', rate.currency
    end
  end

  def registration_parameters
    {:account_number => '000000000', :client_region => 'US', :billing_street_lines => 'Your Address Info', :billing_city => 'Your Address Info', :billing_state_or_province_code => 'MO', :billing_postal_code => 'Your Address Info', :billing_country_code => 'Your Address Info', :user_first_name => 'Your F!st Name', :user_last_name => 'Your last name', :user_email => 'abc@xyz.com', :user_streetlines => 'Your Address Info', :user_city => 'Your Address Info', :user_state_or_province_code => 'Your Address Info', :user_postal_code => 'Your Address Info', :user_country_code => 'Your Address Info', :user_company_name => 'Your Company name', :user_phone_number => 'Your Phone #'}
  end
end

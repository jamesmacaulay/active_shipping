require 'test_helper'
require "date"

class FedExCSPTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = FedExCSP.new(fixtures(:fedex_csp).merge(:test => true))
    # FedExCSP.logger = Logger.new($stdout)
  end  
  
  def test_register_user
    assert_nothing_raised do
      response = register_user
      
      assert response.success?
      assert response.test?
      assert_match(/^[a-zA-Z0-9]{16}$/, response.user_key)
      assert_match(/^[a-zA-Z0-9]{25}$/, response.user_password)
    end
  end
  
  def register_canadian_user
    @carrier.register_user(:account_number => '630103983', :client_region => 'CA', :billing_street_lines => '80 FedEx Prkwy', :billing_city => 'Toronto', :billing_state_or_province_code => 'ON', :billing_postal_code => 'L4W5K6', :billing_country_code => 'CA', :user_first_name => 'James', :user_last_name => 'MacAulay', :user_email => 'james@jadedpixel.com', :user_streetlines => '80 FedEx Prkwy', :user_city => 'Toronto', :user_state_or_province_code => 'ON', :user_postal_code => 'L4W5K6', :user_country_code => 'CA', :user_company_name => 'Shopify', :user_phone_number => '9012635448')
  end
  
  def register_us_user
    @carrier.register_user(:account_number => '630054800', :client_region => 'US', :billing_street_lines => '80 FedEx Prkwy', :billing_city => 'AURORA', :billing_state_or_province_code => 'OH', :billing_postal_code => '44202', :billing_country_code => 'US', :user_first_name => 'James', :user_last_name => 'MacAulay', :user_email => 'james@jadedpixel.com', :user_streetlines => '80 FedEx Prkwy', :user_city => 'AURORA', :user_state_or_province_code => 'OH', :user_postal_code => '44202', :user_country_code => 'US', :user_company_name => 'Shopify', :user_phone_number => '9012635448')
  end
  
  def register_user
    register_canadian_user
    # register_us_user
  end
  
  def test_subscribe_user
    register_user
    
    assert_nothing_raised do
      response = @carrier.subscribe_user
      
      assert response.success?
      assert response.test?
      assert_match(/[0-9]{9}/, response.meter_number)
    end
  end
  
  def setup_user(client_account = 'Canadian')
    if client_account == 'Canadian'
      register_canadian_user
    elsif client_account == 'US'
      register_us_user
    end
    
    @carrier.subscribe_user
  end
  
  def test_version_capture
    setup_user
    
    assert_nothing_raised do
      response = @carrier.version_capture('Version Capture Request', :origin_location_id => 'YZRA', :vendor_product_platform => 'Windows OS')
    end
  end
  
  def test_us_to_canada
    setup_user 'US'
    
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:ottawa],
                   @packages.values_at(:american_wii)
                 )
      
      assert response.success?
      assert response.test?
      
      assert !response.rates.empty?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_zip_to_zip_fails
    setup_user
    
    begin
      @carrier.find_rates(
        Location.new(:zip => 40524),
        Location.new(:zip => 40515),
        @packages[:wii]
      )
    rescue ResponseError => e
      assert_match(/country\s?code/i, e.message)
      assert_match(/(missing|invalid)/, e.message)
    end
  end
  
  # FedEx requires a valid origin and destination postal code
  def test_rates_for_locations_with_only_zip_and_country  
    setup_user 'US'
    response = @carrier.find_rates(
                 @locations[:bare_beverly_hills],
                 @locations[:bare_ottawa],
                 @packages.values_at(:american_wii)
               )
  
    assert response.rates.size > 0
  end
  
  def test_rates_for_location_with_only_country_code
    setup_user 'US'
    begin
      response = @carrier.find_rates(
                   @locations[:bare_beverly_hills],
                   Location.new(:country => 'CA'),
                   @packages.values_at(:american_wii)
                 )
    rescue ResponseError => e
      assert_match(/postal code/i, e.message)
      assert_match(/(missing|invalid)/i, e.message)
    end
  end
  
  def test_invalid_recipient_country
    setup_user 'US'
    assert_raise ResponseError do
      begin
        response = @carrier.find_rates(
                     @locations[:bare_beverly_hills],
                     Location.new(:country => 'KP'),
                     @packages.values_at(:american_wii)
                   )
      rescue ResponseError => e
        assert_match /Destination country is not serviced/i, e.message
        raise
      end
    end
  end
  
  def test_ottawa_to_beverly_hills
    setup_user
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_ottawa_to_london
    setup_user
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_beverly_hills_to_london
    setup_user 'US'
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_tracking
    setup_user
    
    assert_nothing_raised do
      @carrier.find_tracking_info('798850782313')
    end
  end
end

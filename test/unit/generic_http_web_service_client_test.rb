require 'minitest/autorun'
require_relative 'resource'
require_relative '../../weburg/ghowst/generic_http_web_service_client'
require_relative '../../weburg/ghowst/http_web_service_exception'

class GenericHTTPWebServiceClientTest < Minitest::Test
  def setup
    @test_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://nohost/noservice")
  end

  def test_create_test_resource
    assert_raises HttpWebServiceException do
      @test_web_service.create_resource(resource: Resource.new)
    end
  end
end
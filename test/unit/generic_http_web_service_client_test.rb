require 'minitest/autorun'
require_relative '../../engine'
require_relative '../../weburg/ghowst/generic_http_web_service_client'
require_relative '../../weburg/ghowst/http_web_service_exception'

class GenericHTTPWebServiceClientTest < Minitest::Test
  def setup
    @test_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://nohost/noservice")
  end

  def test_service_exception
    engine = Engine.new
    engine.name = "RubyTestEngine"
    engine.cylinders = 12
    engine.throttle_setting = 50

    assert_raises HttpWebServiceException do
      @test_web_service.create_engines(engine: engine)
    end
  end
end
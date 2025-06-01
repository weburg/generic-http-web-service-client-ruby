require 'minitest/autorun'
require_relative '../../engine'
require_relative '../../weburg/ghowst/generic_http_web_service_client'

class GenericHTTPWebServiceClientTest < Minitest::Test
  def setup
    @test_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://localhost:8081/generichttpws")
  end

  def test_create_engine
    engine = Engine.new
    engine.name = "RubyTestEngine"
    engine.cylinders = 12
    engine.throttle_setting = 50

    engine_id = @test_web_service.create_engines(engine: engine)

    assert engine_id > 0
  end
end
require_relative 'engine'
require_relative 'photo'
require_relative 'truck'
require_relative 'weburg/ghowst/generic_http_web_service_client'
require_relative 'weburg/ghowst/http_web_service_exception'

http_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://localhost:8081/generichttpws")

### Photo ###

# Create
photo = Photo.new
photo.caption = "Some Ruby K"
photo.photo_file = File.open("IMAG0777.jpg", 'rb')
http_web_service.create_photos(photo: photo)

### Engine ###

# Create
engine = Engine.new
engine.name = "RubyEngine"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id1 = http_web_service.create_engines(engine: engine)

# CreateOrReplace (which will create)
engine = Engine.new
engine.id = -1
engine.name = "RubyEngineCreatedNotReplaced"
engine.cylinders = 45
engine.throttle_setting = 50
http_web_service.create_or_replace_engines(engine: engine)

# Prepare for CreateOrReplace
engine = Engine.new
engine.name = "RubyEngine2"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id2 = http_web_service.create_engines(engine: engine)

# CreateOrReplace (which will replace)
engine = Engine.new
engine.id = engine_id2
engine.name = "RubyEngine2Replacement"
engine.cylinders = 56
engine.throttle_setting = 59
http_web_service.create_or_replace_engines(engine: engine)

# Prepare for Update
engine = Engine.new
engine.name = "RubyEngine3"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id3 = http_web_service.create_engines(engine: engine)

# Update
engine = Engine.new
engine.id = engine_id3
engine.name = "RubyEngine3Updated"
http_web_service.update_engines(engine: engine)

# Get
engine = http_web_service.get_engines(id: engine_id1)
puts "Engine returned: #{engine.name}"

# Get all
engines = http_web_service.get_engines
puts "Engines returned: #{engines.length}"

# Prepare for Delete
engine = Engine.new
engine.name = "RubyEngine4ToDelete"
engine.cylinders = 89
engine.throttle_setting = 70
engine_id4 = http_web_service.create_engines(engine: engine)

# Delete
http_web_service.delete_engines(id: engine_id4)

# Custom verb
http_web_service.restart_engines(id: engine_id2)

# Repeat, complex objects with different names
truck1 = Truck.new
truck1.name = "Ram"
truck1.engine_id = engine_id1
truck2 = Truck.new
truck2.name = "Ford"
truck2.engine_id = engine_id2
truckNameCompareResult = http_web_service.race_trucks(truck1: truck1, truck2: truck2)

if truckNameCompareResult == 0
  raise RuntimeError.new("Did not expect both trucks to have the same name.")
end

# Induce a not found error and catch it
begin
  engine = http_web_service.get_engines(id: -2)
  puts "Engine returned: " + engine.name
rescue HttpWebServiceException => e
  puts "Status: " + e.http_status.to_s + " Message: " + e.message
end

# Induce a service error and catch it
begin
  http_web_service_wrong = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://nohost:8081/generichttpws")
  http_web_service_wrong.get_engines(id: -2)
rescue HttpWebServiceException => e
  puts "Status: " + e.http_status.to_s + " Message: " + e.message
end
require_relative 'engine'
require_relative 'photo'
require_relative 'weburg/ghowst/generic_http_web_service_client'

http_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://localhost:8081/generichttpws")

### Photo ###

# Create
photo = Photo.new
photo.caption = "Some Ruby K"
photo.photo_file = File.open("IMAG0777.jpg", 'rb')
http_web_service.create_photos(photo)

### Engine ###

# Create
engine = Engine.new
engine.name = "RubyEngine"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id1 = http_web_service.create_engines(engine)

# CreateOrReplace (which will create)
engine = Engine.new
engine.id = -1
engine.name = "RubyEngineCreatedNotReplaced"
engine.cylinders = 45
engine.throttle_setting = 50
http_web_service.create_or_replace_engines(engine)

# Prepare for CreateOrReplace
engine = Engine.new
engine.name = "RubyEngine2"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id2 = http_web_service.create_engines(engine)

# CreateOrReplace (which will replace)
engine = Engine.new
engine.id = engine_id2
engine.name = "RubyEngine2Replacement"
engine.cylinders = 56
engine.throttle_setting = 59
http_web_service.create_or_replace_engines(engine)

# Prepare for Update
engine = Engine.new
engine.name = "RubyEngine3"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id3 = http_web_service.create_engines(engine)

# Update
engine = Engine.new
engine.id = engine_id3
engine.name = "RubyEngine3Updated"
http_web_service.update_engines(engine)

# Get
engine = http_web_service.get_engines(engine_id1)
puts "Engine returned: #{engine.name}"

# Get all
engines = http_web_service.get_engines
puts "Engines returned: #{engines.length}"

# Prepare for Delete
engine = Engine.new
engine.name = "RubyEngine4ToDelete"
engine.cylinders = 89
engine.throttle_setting = 70
engine_id4 = http_web_service.create_engines(engine)

# Delete
http_web_service.delete_engines(engine_id4)

# Custom verb
http_web_service.restart_engines(engine_id2)
# Generic HTTP Web Service Client in Ruby (GHoWSt)

## A client written to talk to the Generic HTTP Web Service Server

### Design goals

- Use local language semantics to talk to the server dynamically. The only thing
  required are the ghowst classes and domain object classes which only need the
  accessors defined.
- Every call, using a method name convention to map to HTTP methods, gets
  translated to HTTP requests. Responses are parsed from JSON and mapped back to
  local objects.

### Example code

```ruby
require_relative 'engine'
require_relative 'weburg/ghowst/generic_http_web_service_client'

http_web_service = WEBURG::GHOWST::GenericHTTPWebServiceClient.new("http://localhost:8081/generichttpws")

# Create
engine = Engine.new
engine.name = "RubyEngine"
engine.cylinders = 44
engine.throttle_setting = 49
engine_id1 = http_web_service.create_engines(engine)
```

### Running the example

First, ensure the server is running. Refer to other grouped GHoWSt projects to
get and run the server. Ensure Ruby 3 or better is installed.

If using the CLI, ensure you are in the project directory. Run:

`ruby run_example_generic_http_web_service_client.rb`

If using an IDE, you should only need to run the below file:

`run_example_generic_http_web_service_client.rb`

The example runs several calls to create, update, replace, read, delete, and do
a custom action on resources.
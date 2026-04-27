require 'json'
require 'logger'
require 'http/form_data'
require 'net/http'
require 'ostruct'
require_relative 'http_web_service_exception'

module WEBURG
  module GHOWST
    class HTTPWebServiceInvoker
      private

      LOGGER = Logger.new($stderr)

      class NameConvertingOpenStruct < OpenStruct
        def method_missing(method, *arguments, &block)
          new_method = HTTPWebServiceInvoker::underbar_to_camel method.to_s
          self.public_send new_method if self.respond_to? new_method
        end
      end

      def self.get_resource_name(name, verb)
        name.slice(verb.length + 1, name.length).downcase
      end

      def self.object_to_hash(object)
        hash = {}
        object.instance_variables.each do | var |
          hash[underbar_to_camel var.to_s.delete("@")] = object.instance_variable_get(var)
        end

        hash
      end

      def self.underbar_to_camel(string)
        new_string = ''

        upper_next = false
        string.each_char do | char |
          if char == '_'
            upper_next = true
            next
          end

          if upper_next
            new_string += char.upcase
            upper_next = false
          else
            new_string += char
          end
        end

        new_string
      end

      def self.camel_to_underbar(string)
        new_string = ''

        string.each_char do | char |
          if new_string != '' and char.match /[[:upper:]]/
            new_string += "_#{char.downcase}"
          else
            new_string += char.downcase
          end
        end

        new_string
      end

      def self.generate_qs(arguments)
        qs = ''
        if arguments.length > 0
          qs += '?'

          renamed_arguments = []
          arguments.each do | name, value |
            renamed_arguments << [ self.underbar_to_camel(name.to_s), value ]
          end

          qs += URI.encode_www_form(renamed_arguments.to_a)
        end

        qs
      end

      def self.prepare_request(request, arguments)
        request[:accept] = "application/json"

        has_file = false
        arguments.each_value do | argument |
          self.object_to_hash(argument).each_value do | property |
            if property.class == File
              has_file = true
              break 2
            end
          end
        end

        if !has_file
          values = []
          arguments.each do | name, value |
            if value.instance_variables.length == 0
              values << [ self.underbar_to_camel(name.to_s), value ]
            else
              value.instance_variables.each do | property |
                values << [ self.underbar_to_camel(name.to_s + '.' + property.to_s.delete('@')), value.instance_variable_get(property) ]
              end
            end
          end

          request.set_form_data values
        else
          values = {}

          arguments.each do | argument, value |
            value.instance_variables.each do | property |
              name = self.underbar_to_camel(argument.to_s + '.' + property.to_s.delete('@'))
              property_value = value.instance_variable_get(property)

              values[name] =
                if property_value.class == File
                  HTTP::FormData::File.new(
                    property_value,
                    filename: File.basename(property_value.path),
                    content_type: "application/octet-stream"
                  )
                else
                  property_value.to_s
                end
            end
          end

          form = HTTP::FormData.create(values)

          request.set_content_type(form.content_type)
          request.body = form.to_s
        end
      end

      def self.execute_and_handle_result(request, uri, json_quirks_mode = true)
        result = Net::HTTP.start(uri.hostname, uri.port) do | http |
          http.request(request)
        end

        if result.code.to_i >= 400 or result.code.to_i < 200
          raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
        elsif result.code.to_i >= 300 and result.code.to_i < 400
          raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
        end

        begin
          if json_quirks_mode
            return JSON.parse(result.body, {:quirks_mode => true})
          else
            return JSON.parse(result.body, object_class: NameConvertingOpenStruct)
          end
        rescue
          return
        end
      end

      public

      def invoke(method_name, arguments, base_url)
        if method_name.index("get") == 0
          verb = "get"
          resource = self.class.get_resource_name(method_name, verb)
        elsif method_name.index("create_or_replace") == 0
          verb = "create_or_replace"
          resource = self.class.get_resource_name(method_name, verb)
        elsif method_name.index("create") == 0
          verb = "create"
          resource = self.class.get_resource_name(method_name, verb)
        elsif method_name.index("update") == 0
          verb = "update"
          resource = self.class.get_resource_name(method_name, verb)
        elsif method_name.index("delete") == 0
          verb = "delete"
          resource = self.class.get_resource_name(method_name, verb)
        else
          parts = method_name.split('_')

          verb = parts[0].downcase
          resource =  self.class.get_resource_name(method_name, verb)
        end

        LOGGER.info("Verb: #{verb}")
        LOGGER.info("Resource: #{resource}")

        begin
          case verb
          when "get"
            uri = URI(base_url + '/' + resource + self.class.generate_qs(arguments))
            request = Net::HTTP::Get.new(uri)
            self.class.prepare_request(request, {})

            return self.class.execute_and_handle_result(request, uri, false)
          when "create"
            uri = URI(base_url + '/' + resource)

            request = Net::HTTP::Post.new(uri)
            self.class.prepare_request(request, arguments)

            return self.class.execute_and_handle_result(request, uri)
          when "create_or_replace"
            uri = URI(base_url + '/' + resource)

            request = Net::HTTP::Put.new(uri)
            self.class.prepare_request(request, arguments)

            return self.class.execute_and_handle_result(request, uri)
          when "update"
            uri = URI(base_url + '/' + resource)

            request = Net::HTTP::Patch.new(uri)
            self.class.prepare_request(request, arguments)

            return self.class.execute_and_handle_result(request, uri)
          when "delete"
            uri = URI(base_url + '/' + resource + self.class.generate_qs(arguments))

            request = Net::HTTP::Delete.new(uri)
            self.class.prepare_request(request, {})

            return self.class.execute_and_handle_result(request, uri)
          else
            # POST to a custom verb resource

            uri = URI(base_url + '/' + resource + '/' + verb)

            request = Net::HTTP::Post.new(uri)
            self.class.prepare_request(request, arguments)

            return self.class.execute_and_handle_result(request, uri)
          end
        rescue HttpWebServiceException => e
          raise e
        rescue Exception => e
          raise HttpWebServiceException.new(0, "There was a problem processing the web service request: " + e.message)
        end
      end
    end
  end
end
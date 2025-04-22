require 'json'
require 'net/http'

module WEBURG
  module GHOWST
    class HTTPWebServiceInvoker
      private

      MULTIPART_BOUNDARY = "AaB03x"

      class NameConvertingOpenStruct < OpenStruct
        def method_missing(method, *arguments, &block)
          new_method = HTTPWebServiceInvoker::underbar_to_camel method.to_s
          self.public_send new_method if self.respond_to? new_method
        end
      end

      def self.get_entity_name(name, verb)
        name.slice(verb.length + 1, name.length).downcase
      end

      def self.object_to_hash(object)
        hash = {}
        object.instance_variables.each do |var|
          hash[underbar_to_camel var.to_s.delete("@")] = object.instance_variable_get(var)
        end

        hash
      end

      def self.underbar_to_camel(string)
        new_string = ''

        upper_next = false
        string.each_char do |char|
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

        string.each_char do |char|
          if new_string != '' and char.match /[[:upper:]]/
            new_string += "_#{char.downcase}"
          else
            new_string += char.downcase
          end
        end

        new_string
      end

      def generate_qs(arguments)
        # TODO all names should be ran through self.class.underbar_to_camel(name)
        (arguments.length > 0 ? '?' + URI.encode_www_form(arguments.to_a) : "")
      end

      public

      def invoke(method_name, arguments, base_url)
        if method_name.index("get") == 0
          verb = "get"
          entity = self.class.get_entity_name(method_name, verb)
        elsif method_name.index("create_or_replace") == 0
          verb = "create_or_replace"
          entity = self.class.get_entity_name(method_name, verb)
        elsif method_name.index("create") == 0
          verb = "create"
          entity = self.class.get_entity_name(method_name, verb)
        elsif method_name.index("update") == 0
          verb = "update"
          entity = self.class.get_entity_name(method_name, verb)
        elsif method_name.index("delete") == 0
          verb = "delete"
          entity = self.class.get_entity_name(method_name, verb)
        else
          parts = method_name.split('_')

          verb = parts[0].downcase
          entity =  self.class.get_entity_name(method_name, verb)
        end

        puts "Verb: #{verb}"
        puts "Entity: #{entity}"

        begin
          case verb
          when "get"
            uri = URI(base_url + '/' + entity + self.generate_qs(arguments))
            request = Net::HTTP::Get.new(uri)
            request[:accept] = "application/json"

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            return JSON.parse(result.body, object_class: NameConvertingOpenStruct)
          when "create"
            uri = URI(base_url + '/' + entity)

            has_file = false
            arguments.each_value do |argument|
              self.class.object_to_hash(argument).each_value do |property|
                if property.class == File
                  has_file = true
                end
              end
            end

            request = Net::HTTP::Post.new(uri)
            request[:accept] = "application/json"

            if !has_file
              values = []

              arguments.each do | name, value |
                value.instance_variables.each do | property |
                  values << [ self.class.underbar_to_camel(name.to_s + '.' + property.to_s.delete('@')), value.instance_variable_get(property) ]
                end
              end

              request.set_form_data values
            else
              post_body = []

              arguments.each do | argument, value |
                value.instance_variables.each do | property |
                  name = self.class.underbar_to_camel(argument.to_s + '.' + property.to_s.delete('@'))

                  if value.instance_variable_get(property).class != File
                    post_body << "--#{MULTIPART_BOUNDARY}\r\n"
                    post_body << "Content-Disposition: form-data; name=\"#{name}\"\r\n";
                    post_body << "\r\n"
                    post_body << "#{value.instance_variable_get(property)}\r\n"
                  else
                    post_body << "--#{MULTIPART_BOUNDARY}\r\n"
                    post_body << "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{File.basename(value.instance_variable_get(property).path)}\"\r\n"
                    post_body << "Content-Type: application/octet-stream\r\n"
                    post_body << "\r\n"
                    post_body << value.instance_variable_get(property).read
                  end
                end
              end

              post_body << "\r\n--#{MULTIPART_BOUNDARY}--\r\n"

              request.set_content_type "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"
              request.body = post_body.join
            end

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            return JSON.parse(result.body, {:quirks_mode => true})
          when "create_or_replace"
            uri = URI(base_url + '/' + entity)

            values = []

            arguments.each do | name, value |
              value.instance_variables.each do | property |
                values << [ self.class.underbar_to_camel(name.to_s + '.' + property.to_s.delete('@')), value.instance_variable_get(property) ]
              end
            end

            request = Net::HTTP::Put.new(uri)
            request[:accept] = "application/json"
            request.set_form_data values

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            return JSON.parse(result.body, {:quirks_mode => true})
          when "update"
            uri = URI(base_url + '/' + entity)

            values = []

            arguments.each do | name, value |
              value.instance_variables.each do | property |
                values << [ self.class.underbar_to_camel(name.to_s + '.' + property.to_s.delete('@')), value.instance_variable_get(property) ]
              end
            end

            request = Net::HTTP::Patch.new(uri)
            request[:accept] = "application/json"
            request.set_form_data values

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            return
          when "delete"
            uri = URI(base_url + '/' + entity + self.generate_qs(arguments))

            request = Net::HTTP::Delete.new(uri)
            request[:accept] = "application/json"

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            return
          else
            # POST to a custom verb resource

            uri = URI(base_url + '/' + entity + '/' + verb)

            request = Net::HTTP::Post.new(uri)
            request[:accept] = "application/json"

            values = []
            arguments.each do | name, value |
              if value.instance_variables.length == 0
                values << [ self.class.underbar_to_camel(name.to_s), value ]
              else
                value.instance_variables.each do | property |
                  values << [ self.class.underbar_to_camel(name.to_s + '.' + property.to_s.delete('@')), value.instance_variable_get(property) ]
                end
              end
            end

            request.set_form_data values

            result = Net::HTTP.start(uri.hostname, uri.port) do |http|
              http.request(request)
            end

            if result.code.to_i >= 400 or result.code.to_i < 200
              raise HttpWebServiceException.new(result.code.to_i, result.header["x-error-message"])
            elsif result.code.to_i >= 300 and result.code.to_i < 400
              raise HttpWebServiceException.new(result.code.to_i, result.header["location"])
            end

            begin
              return JSON.parse(result.body, {:quirks_mode => true})
            rescue
              return
            end
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
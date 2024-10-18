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

        case verb
        when "get"
          uri = URI(base_url + '/' + entity + (arguments.length > 0 ? "?id=" + URI.encode_www_form_component(arguments[0]) : ""))

          result = Net::HTTP.get_response(uri)

          if result.is_a?(Net::HTTPOK)
            return JSON.parse(result.body, object_class: NameConvertingOpenStruct)
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        when "create"
          uri = URI(base_url + '/' + entity)

          arg_hash = self.class.object_to_hash(arguments[0])

          has_file = false
          arg_hash.each_value do |argument|
            if argument.class == File
              has_file = true
            end
          end

          request = Net::HTTP::Post.new(uri)

          if !has_file
            request.set_form_data arg_hash
          else
            post_body = []

            arg_hash.each do |name, argument|
              if argument.class != File
                post_body << "--#{MULTIPART_BOUNDARY}\r\n"
                post_body << "Content-Disposition: form-data; name=\"#{name}\"\r\n";
                post_body << "\r\n"
                post_body << "#{argument}\r\n"
              else
                post_body << "--#{MULTIPART_BOUNDARY}\r\n"
                post_body << "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{File.basename(argument.path)}\"\r\n"
                post_body << "Content-Type: application/octet-stream\r\n"
                post_body << "\r\n"
                post_body << argument.read
              end
            end

            post_body << "\r\n--#{MULTIPART_BOUNDARY}--\r\n"

            request.set_content_type "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"
            request.body = post_body.join
          end

          result = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end

          if result.is_a?(Net::HTTPOK) || result.is_a?(Net::HTTPCreated)
            return JSON.parse(result.body, {:quirks_mode => true})
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        when "create_or_replace"
          uri = URI(base_url + '/' + entity + "?id=" + URI.encode_www_form_component(arguments[0].id))

          arg_hash = self.class.object_to_hash(arguments[0])

          request = Net::HTTP::Put.new(uri)
          request.set_form_data arg_hash

          result = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end

          if result.is_a?(Net::HTTPOK) || result.is_a?(Net::HTTPCreated)
            return JSON.parse(result.body, {:quirks_mode => true})
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        when "update"
          uri = URI(base_url + '/' + entity + "?id=" + URI.encode_www_form_component(arguments[0].id))

          arg_hash = self.class.object_to_hash(arguments[0])

          request = Net::HTTP::Patch.new(uri)
          request.set_form_data arg_hash

          result = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end

          if result.is_a?(Net::HTTPOK) || result.is_a?(Net::HTTPCreated)
            return
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        when "delete"
          uri = URI(base_url + '/' + entity + "?id=" + URI.encode_www_form_component(arguments[0]))

          request = Net::HTTP::Delete.new(uri)

          result = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end

          if result.is_a?(Net::HTTPOK)
            return
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        else
          # POST to a custom verb resource

          uri = URI(base_url + '/' + entity + '/' + verb + (arguments.length > 0 && !(arguments[0].respond_to? :each) ? "?id=" + URI.encode_www_form_component(arguments[0]) : ""))
          # TODO we assume id is passed but need to detect that more proper, custom verbs might pass different things

          request = Net::HTTP::Post.new(uri)

          if arguments[0].respond_to? :each
            arg_hash = self.class.object_to_hash(arguments[0])
            request.set_form_data arg_hash
          end

          result = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end

          if result.is_a?(Net::HTTPOK) || result.is_a?(Net::HTTPCreated)
            return
          else
            raise "HTTP #{result.code} when requesting #{uri}"
          end
        end
      end
    end
  end
end
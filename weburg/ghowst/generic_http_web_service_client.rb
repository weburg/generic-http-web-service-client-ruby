require_relative 'http_web_service_invoker'

# Thin wrapper for stubless client
module WEBURG
  module GHOWST
    class GenericHTTPWebServiceClient
      public

      def initialize(base_url)
        @base_url = base_url
        @http_web_service_invoker = HTTPWebServiceInvoker.new()
      end

      def method_missing(method, *arguments, &block)
        @http_web_service_invoker.invoke(method.to_s, arguments, @base_url)
      end
    end
  end
end
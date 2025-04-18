class HttpWebServiceException < RuntimeError
  attr_accessor :http_status

  def initialize(http_status, message)
    super(message)
    @http_status = http_status
  end
end
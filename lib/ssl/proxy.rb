
require_relative 'base_rewriter'
require_relative 'server'

require 'net/http'
require 'openssl'

require 'rack'

module SSL
  class Proxy
    DEFAULT_PORT = 1235
    DEFAULT_TARGET_HOST = 'localhost'
    DEFAULT_TARGET_PORT = 1234

    SSL_OPTS = {
      use_ssl: true,
      ssl_version: 'SSLv3',
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    }

    def initialize(port: DEFAULT_PORT,
                   rewriter: BaseRewriter.new,
                   target_host: DEFAULT_TARGET_HOST,
                   target_port: DEFAULT_TARGET_PORT)
      @rewriter = rewriter
      @server = SSL::Server.new(port: port)
      @target_host = target_host
      @target_port = target_port
    end

    def call(env)
      request = rewriter.modify_request(init_request(env))
      response = rewriter.modify_response(init_response(request))
      [response.code.to_i, response_headers(response), [response.read_body]]
    end

    def start
      server.start(app: self)
    end

    def stop
      server.stop
    end

    private

    attr_reader :rewriter, :server, :target_host, :target_port

    def add_body(request, original_request)
      if request.request_body_permitted? && original_request.body
        request.body_stream = original_request.body
        request.content_length = original_request.content_length
        request.content_type = original_request.content_type
      end
      request
    end

    def add_headers(request, original_request)
      request['X-Forwarded-For'] = forwarded_for(original_request)
      request['Accept-Encoding'] = original_request.accept_encoding
      request['Referer'] = original_request.referer
      request
    end

    def forwarded_for(original_request)
      forwarded_for = original_request.env['X-Forwarded-For'].to_s.split(/, +/)
      forwarded_for << original_request.env['REMOTE_ADDR']
      forwarded_for.join(', ')
    end

    def init_request(env)
      original_request = Rack::Request.new(env)
      method = original_request.request_method.downcase
      method[0..0] = method[0..0].upcase
      add_headers(
        add_body(
          Net::HTTP.const_get(method).new(original_request.url),
          original_request),
        original_request)
    end

    def init_response(request)
      Net::HTTP.start(target_host, target_port, SSL_OPTS) do |http|
        http.request(request)
      end
    end

    def response_headers(response)
      headers = {}
      response.each_header do |k, v|
        headers[k] = v unless k.to_s =~ /content-length|transfer-encoding/i
      end
      headers
    end
  end
end

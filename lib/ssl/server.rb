
require 'json'
require 'openssl'
require 'webrick'
require 'webrick/https'

require 'rack'

module SSL
  class Server
    def initialize(access_log: [], certificate: 'auth/certificate',
                   logger: WEBrick::BasicLog.new(nil, WEBrick::BasicLog::WARN),
                   port: 1234, private_key: 'auth/key')
      @access_log = access_log
      @certificate = certificate
      @logger = logger
      @port = port
      @private_key = private_key
    end

    def call(_env)
      [
        200,
        { 'Content-Type' => 'application/json' },
        [{ ssl_server: 'running' }.to_json]
      ]
    end

    def start(app: self)
      @thread = Thread.new do
        Rack::Handler::WEBrick.run app, webrick_options
      end
      sleep 1
    end

    def stop
      Thread.kill(@thread)
    end

    private

    attr_reader :access_log, :certificate, :logger, :logger_options, :port,
                :private_key, :ssl_options, :webrick_options

    def logger_options
      @logger_options ||= {
        AccessLog:          access_log,
        Logger:             logger
      }
    end

    def ssl_options
      @ssl_options ||= {
        SSLEnable:       true,
        SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
        SSLCertificate:  OpenSSL::X509::Certificate.new(
                           File.open(certificate).read),
        SSLPrivateKey:   OpenSSL::PKey::RSA.new(File.open(private_key).read)
      }
    end

    def webrick_options
      @webrick_options ||= logger_options.merge(ssl_options.merge(Port: port))
    end
  end
end

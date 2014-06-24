require 'ssl/proxy'

require 'net/http'

require 'rspec'

module SSL
  class FakeTargetApp
    FAKE_TARGET_RESPONSE = { 'fake_ssl_server' => 'fake response' }

    def call(env)
      headers = { 'Content-Type' => 'application/json' }

      if env['HTTP_INJECTED_REQUEST_HEADER']
        headers['injected-request-header'] = env['HTTP_INJECTED_REQUEST_HEADER']
      end

      [200, headers, [FAKE_TARGET_RESPONSE.to_json]]
    end
  end

  class Rewriter < BaseRewriter
    def modify_request(request)
      request['injected-request-header'] = 'injected request header'
      request
    end

    def modify_response(response)
      response['injected-response-header'] = 'injected response header'
      response
    end
  end

  describe Proxy do
    proxy = Proxy.new(rewriter: Rewriter.new)
    target = SSL::Server.new

    before(:context) do
      proxy.start
      target.start(app: FakeTargetApp.new)
    end

    after(:context) do
      proxy.stop
      target.stop
    end

    let(:request) do
      Net::HTTP::Get.new("https://localhost:#{Proxy::DEFAULT_PORT}/")
    end
    let(:response) do
      Net::HTTP.start('localhost', Proxy::DEFAULT_PORT, ssl_opts) do |http|
        http.request(request)
      end
    end
    let(:ssl_opts) do
      {
        use_ssl: true,
        ssl_version: 'SSLv3',
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      }
    end

    it 'allows requests to be modified' do
      expect(response.header['injected-request-header'])
        .to eq('injected request header')
    end

    it 'allows response headers to be modified' do
      expect(response.header['injected-response-header'])
        .to eq('injected response header')
    end
  end
end

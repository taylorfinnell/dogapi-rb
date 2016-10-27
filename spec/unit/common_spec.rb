require_relative '../spec_helper'

describe 'Common' do
  context 'Scope' do
    it 'validates the Scope class' do
      obj = Dogapi::Scope.new('somehost', 'somedevice')

      expect(obj.host).to eq 'somehost'
      expect(obj.device).to eq 'somedevice'
    end
  end # end Scope

  context 'HttpConnection' do
    it 'respects the proxy configuration' do
      service = Dogapi::APIService.new('api_key', 'app_key')

      service.connect do |conn|
        expect(conn.proxy_address).to be(nil)
        expect(conn.proxy_port).to be(nil)
      end

      ENV['http_proxy'] = 'https://www.proxy.com:443'

      service.connect do |conn|
        expect(conn.proxy_address).to eq 'www.proxy.com'
        expect(conn.proxy_port).to eq 443
      end

      ENV['http_proxy'] = nil
    end

    it 'respects the endpoint configuration' do
      service = Dogapi::APIService.new('api_key', 'app_key', true, nil, 'https://app.example.com')

      service.connect do |conn|
        expect(conn.address).to eq 'app.example.com'
        expect(conn.port).to eq 443
      end
    end
  end
end

class FakeResponse
  attr_accessor :code, :body, :headers
  def initialize(code, body, headers = [])
    # Instance variables
    @code = code
    @body = body
    @headers = headers
  end

  # Net::HTTPResponse#each yields headers...
  def each
    @headers.each
  end
end

describe Dogapi::APIService do
  let(:dogapi_service_silent) { Dogapi::APIService.new 'API_KEY', 'APP_KEY' }
  let(:dogapi_service) { Dogapi::APIService.new 'API_KEY', 'APP_KEY', false }
  let(:std_error) { StandardError.new('test3') }

  describe '#suppress_error_if_silent' do
    context 'when silent' do
      it "doesn't raise an error" do
        dog = dogapi_service_silent
        expect { dog.suppress_error_if_silent(std_error) }.not_to raise_error
        expect { dog.suppress_error_if_silent(std_error) }.to output("test3\n").to_stderr
        expect(dog.suppress_error_if_silent(std_error)).to eq(Dogapi::Response.new(-1, {}.to_json))
      end
    end
    context 'when not silent' do
      it 'raises an error' do
        dog = dogapi_service
        expect { dog.suppress_error_if_silent(std_error) }.to raise_error(std_error)
      end
    end
  end

  describe '#handle_response' do
    context 'when receiving a correct reponse with valid json' do
      it 'returns a response object' do
        dog = dogapi_service

        resp = FakeResponse.new(202, { test2: 'test3' }.to_json, [{ header: 'one' }])

        expect(dog.handle_response(resp)).to eq(
          Dogapi::Response.new(202, resp.body, [{ header: 'one' }])
        )
      end
    end

    context 'when receiving a bad response' do
      it 'returns the error code and an empty body' do
        dog = dogapi_service
        resp = FakeResponse.new 204, ''
        expect(dog.handle_response(resp)).to eq(Dogapi::Response.new(204, ''))

        resp = FakeResponse.new 202, nil
        expect(dog.handle_response(resp)).to eq(Dogapi::Response.new(202, nil))

        resp = FakeResponse.new 202, 'null'
        expect(dog.handle_response(resp)).to eq(Dogapi::Response.new(202, 'null'))
      end
    end
  end
end

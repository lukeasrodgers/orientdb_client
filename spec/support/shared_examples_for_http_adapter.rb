RSpec.shared_examples 'http adapter' do
  let(:adapter) { adapter_klass.new }

  describe 'username and password' do
    it 'allows username and password to be set and unset' do
      adapter.username = 'test'
      adapter.password = 'pw'
      expect(adapter.username).to eq('test')
      expect(adapter.password).to eq('pw')
    end
  end

  describe '#reset_credentials' do
    it 'resets usernamd and password' do
      adapter.username = 'test'
      adapter.password = 'pw'
      adapter.reset_credentials
      expect(adapter.username).to be_nil
      expect(adapter.password).to be_nil
    end
  end

  describe '#request' do
    describe 'GET' do
      let(:url) { 'http://localhost:2480/listDatabases' }

      it 'makes GET request' do
        stub_request(:get, url).
         to_return(:status => 200, :body => "", :headers => {})
        adapter.request(:get, url)
        expect(WebMock).to have_requested(:get, url)
      end

      it 'returns a response that responds to `response_code`' do
        stub_request(:get, url).
         to_return(:status => 200, :body => {a: 1}.to_json, :headers => {})
        r = adapter.request(:get, url)
        expect(r.response_code).to eq(200)
      end

      it 'returns a response that responds to `body`' do
        stub_request(:get, url).
         to_return(:status => 200, :body => {a: 1}.to_json, :headers => {})
        r = adapter.request(:get, url)
        expect(r.body).to eq({a: 1}.to_json)
      end

      it 'returns a response that responds to `content_type`' do
        stub_request(:get, url).
         to_return(:status => 200, :body => {a: 1}.to_json, :headers => {'Content-Type' => 'application/json; charset=utf8'})
        r = adapter.request(:get, url)
        expect(r.content_type).to eq('application/json; charset=utf8')
      end
    end

    describe 'POST' do
      let(:url) { 'http://localhost:2480/database/test/plocal/graph' }

      it 'makes POST request' do
        stub_request(:post, "http://localhost:2480/database/test/plocal/graph").
         to_return(:status => 200, :body => "", :headers => {})
        adapter.request(:post, url)
        expect(WebMock).to have_requested(:post, url)
      end
    end
  end
end

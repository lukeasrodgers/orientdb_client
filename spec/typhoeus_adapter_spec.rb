require 'spec_helper'
require 'support/shared_examples_for_http_adapter'

RSpec.describe OrientdbClient::HttpAdapters::TyphoeusAdapter do
  it_behaves_like 'http adapter' do
    let(:adapter_klass) { OrientdbClient::HttpAdapters::TyphoeusAdapter }
  end

  describe '#request' do
    let(:adapter) { OrientdbClient::HttpAdapters::TyphoeusAdapter.new }
    subject { adapter.request(:get, 'http://localhost/noodbhere') }

    it 'raises a connection failure if it cannot connect' do
      expect { subject }.to raise_exception(OrientdbClient::ConnectionError)
    end
  end
end

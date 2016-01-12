require 'spec_helper'
require 'support/shared_examples_for_http_adapter'

RSpec.describe OrientdbClient::HttpAdapters::CurbAdapter do
  it_behaves_like 'http adapter' do
    let(:adapter_klass) { OrientdbClient::HttpAdapters::CurbAdapter }
  end

  describe '#request' do
    let(:adapter) { OrientdbClient::HttpAdapters::CurbAdapter.new }
    subject { adapter.request(:get, 'http://localhost/foo') }

    it 'converts Curl::Err::ConnectionFailedError into a ConnectionError' do
      allow(adapter).to receive(:run_request) { raise Curl::Err::ConnectionFailedError }
      expect { subject }.to raise_exception(OrientdbClient::ConnectionError)
    end

    it 'converts Curl::Err::HostResolutionError into a ConnectionError' do
      allow(adapter).to receive(:run_request) { raise Curl::Err::HostResolutionError }
      expect { subject }.to raise_exception(OrientdbClient::ConnectionError)
    end

    it 'converts Curl::Err::MalformedURLError into a ClientError' do
      allow(adapter).to receive(:run_request) { raise Curl::Err::MalformedURLError }
      expect { subject }.to raise_exception(OrientdbClient::ClientError)
    end

    it 'converts other Curl errors into HttpAdapaterError' do
      allow(adapter).to receive(:run_request) { raise Curl::Err::HTTPFailedError }
      expect { subject }.to raise_exception(OrientdbClient::HttpAdapterError)
    end
  end
end

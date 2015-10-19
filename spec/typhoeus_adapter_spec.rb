require 'spec_helper'
require 'support/shared_examples_for_http_adapter'

RSpec.describe OrientdbClient::HttpAdapters::TyphoeusAdapter do
  it_behaves_like 'http adapter' do
    let(:adapter_klass) { OrientdbClient::HttpAdapters::TyphoeusAdapter }
  end
end

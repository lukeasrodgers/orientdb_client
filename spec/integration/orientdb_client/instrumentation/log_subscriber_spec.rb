require 'spec_helper'
require 'logger'
require 'stringio'
require 'orientdb_client/instrumentation/log_subscriber'

# Only required for testing purposes, no difference in public API that impacts
# actual libraryr code. Rails 4 changes `.logger=` from a `class_attribute` to a
# `attr_writer` which affects inheritabiltiy.
begin
  require 'active_support/gem_version'
  version = ActiveSupport::VERSION::MAJOR
rescue LoadError
  version = 3
end

RSpec.describe OrientdbClient::Instrumentation::LogSubscriber do
  let(:client) { OrientdbClient.client instrumenter: ActiveSupport::Notifications }

  before do
    @io = StringIO.new
    if version == 3
      OrientdbClient::Instrumentation::LogSubscriber.logger = Logger.new(@io)
    else
      ActiveSupport::LogSubscriber.logger = Logger.new(@io)
    end
  end

  after do
    if version == 3
      OrientdbClient::Instrumentation::LogSubscriber.logger = nil
    else
      ActiveSupport::LogSubscriber.logger = nil
    end
  end

  let(:regex) { Regexp.new('get http://localhost:2480/listDatabases') }

  it "works" do
    begin
      client.list_databases
    rescue
    end
    log = @io.string
    expect(log).to match(regex)
  end

  it "works through exceptions" do
    allow_any_instance_of(OrientdbClient::HttpAdapters::TyphoeusAdapter).to receive(:request) { raise 'err' }
    begin
      client.list_databases
    rescue
    end
    log = @io.string
    expect(log).to match(regex)
  end
end

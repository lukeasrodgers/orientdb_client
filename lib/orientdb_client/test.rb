module OrientdbClient
  module Test
    OrientdbClient::Test::DatabaseName = ENV['ORIENTDB_TEST_DATABASENAME'] || 'orientdb_client_rb_test'
    OrientdbClient::Test::Username = ENV['ORIENTDB_TEST_USERNAME'] || 'test'
    OrientdbClient::Test::Password = ENV['ORIENTDB_TEST_PASSWORD'] || 'test'
  end
end

require 'orientdb_client/http_adapters/curb_adapter'

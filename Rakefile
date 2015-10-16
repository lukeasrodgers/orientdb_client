require "bundler/gem_tasks"
require 'orientdb_client'
require 'orientdb_client/test'

task :console do
  require 'pry'
  require 'orientdb_client'

  def reload!
    files = $LOADED_FEATURES.select { |feat| feat =~ /\/orientdb_client\// }
    files.each { |file| load file }
  end

  ARGV.clear
  Pry.start
end

namespace :db do
  namespace :test do
    task :create do
      client = OrientdbClient.client
      db = OrientdbClient::Test::DatabaseName
      username = OrientdbClient::Test::Username
      password = OrientdbClient::Test::Password
      if !client.database_exists?(db)
        client.create_database(db, 'plocal', 'graph', username: username, password: password)
      end
    end
  end
end

# OrientdbClient

Ruby client for Orientdb.
Inspired by https://github.com/veny/orientdb4r

Goals:

* speed (as much as possible with ruby)
* fine-grained handling of Orientdb errors, via rich set of ruby exceptions

## Installation

Add this line to your application's Gemfile:

    gem 'orientdb_client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install orientdb_client

## Usage

```ruby
# basic usage
my_client = OrientdbClient.client
# connect to default Orientdb database
my_client.connect(username: 'root', password: 'YOURPASSWORD', db: 'GratefulDeadConcerts')
my_client.query('select * from V')

# create database
my_client.create_database('new_db', 'plocal', 'graph')

# use a different logger
class MyLogger
  def info(message)
    puts "my message: #{message}"
  end
end
Orientdb::logger = MyLogger.new

# use a different HttpAdapter
require 'orientdb_client'
require 'orientdb_client/http_adapters/curb_adapter'
client = OrientdbClient.cient(adapter: 'CurbAdapter')
```

## Development

Launch pry session with the gem: `rake console`, in pry use `reload!` to reload all gem files.

Run tests: `rake db:test:create` (consult `test.rb` for information on customizing auth credentials via env variables).

Turn on/off rudimentary debug mode with `client.debug = true/false`.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orientdb_client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

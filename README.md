# OrientdbClient

[![Build Status](https://travis-ci.org/lukeasrodgers/orientdb_client.svg)](https://travis-ci.org/lukeasrodgers/orientdb_client)

While not yet at version 1.0, the client has been in use in a production environment for several months, working fine, with some minor improvements and bugfixes along the way.

Inspired by https://github.com/veny/orientdb4r

Goals:

* speed (as much as possible with ruby)
* fine-grained handling of Orientdb errors, via rich set of ruby exceptions

Tested on:
* 2.2.30
* 2.2.10
* 2.1.10
* 2.1.9
* 2.1.5
* 2.1.4
* 2.0.6 - specs may fail due to Orientdb bug with deleting database (https://github.com/orientechnologies/orientdb/issues/3746)
* 2.0.4
* 2.0.2

CI tests with Travis currently only run non-integration tests (i.e. they don't actually hit an Orientdb server). This means that the "tested on versions x.x.x" is *manual testing*.
That is to say, this testing process is error-prone, so you should run the tests yourself with whatever version of Orientdb you are using.

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

# use a different HttpAdapter
require 'orientdb_client'
require 'orientdb_client/http_adapters/curb_adapter'
client = OrientdbClient.client(adapter: 'CurbAdapter')

# initialize client with an HTTP request timeout of 30s
client = OrientdbClient.client(host: 'localhost', timeout: 30)
```

## Logging/instrumentation

OrientdbClient does no logging by default, but will use ActiveSupport::Notifications
if you `require 'orientdb_client/instrumentation/log_subscriber'`.

If you are using Rails, this should *just work*. You will have to initialize your client instance
with the option `instrumenter: ActiveSupport::Notifications`, e.g.:


```ruby
my_client = OrientdbClient.client(host: 'localhost', instrumenter: ActiveSupport::Notifications)
```

If you aren't, you'll need to manually specify the logger, like so:


```ruby
# activesupport version 3
OrientdbClient::Instrumentation::LogSubscriber.logger = Logger.new(STDOUT)

# activesupport version 4
ActiveSupport::LogSubscriber.logger = Logger.new(STDOUT)
```

The right-hand side of the assignment here can be an instance of whatever
logger class you want.

The following events are instrumented:

* `request.orientdb_client`: most of this is corresponds to time spent in HTTP
* `process_response.orientdb_client`: most of this will correspond to JSON parsing
and error response code/message handling.

### Skylight.io integration

If you use Skylight for application monitoring, you can include an OrientDB normalizer so that Skylight will group
your OrientDB queries with other db (sql, redis) queries and visually separate them from the rest of your rails code.

The best way I've found to do this is including this in your `config/application.rb`:

```ruby
config.before_initialize do
  # This will run before initializers for all railties, which is where Skylight registers its normalizers.
  require 'orientdb_client/integration/skylight_normalizer'
end
```

## HTTP Adapters

OrientdbClient currently supports Typhoeus and Curb HTTP adapters.

Benchmarks:

```ruby
#tc is typhoeus client, cc is curb client

require 'benchmark'
Benchmark.bmbm do |x|
  x.report('typhoeus') { 100.times { tc.query('select * from V') } }
  x.report('curb') { 100.times { cc.query('select * from V') } }
end
Rehearsal --------------------------------------------
typhoeus   0.100000   0.010000   0.110000 (  0.392666)
curb       0.060000   0.000000   0.060000 (  0.347496)
----------------------------------- total: 0.170000sec

               user     system      total        real
typhoeus   0.100000   0.010000   0.110000 (  0.387320)
curb       0.060000   0.010000   0.070000 (  0.331764)
```

## Development

Launch pry session with the gem: `rake console`, in pry use `reload!` to reload all gem files.

Turn on/off rudimentary debug mode with `client.debug = true/false`.

### Running the tests

Currently, we don't run integration tests in CI due to the hackyness of setting running orientdb on Travis, and also because
some of the integration tests fail non-deterministically (especially the ones involving multiple threads).

To run all the tests:

1. install orientdb locally
2. if you used a different username or password than `root`, then you'll have to specify those values via environment variables, e.g.:

    ```
    export ORIENTDB_TEST_USERNAME=your_username
    export ORIENTDB_TEST_PASSWORD=your_password
    ```

3. run `bundle exec rake db:test:create` to create the test database
4. run `bundle exec rspec` to run the tests

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orientdb_client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

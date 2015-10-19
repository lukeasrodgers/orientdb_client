# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orientdb_client/version'

Gem::Specification.new do |spec|
  spec.name          = "orientdb_client"
  spec.version       = OrientdbClient::VERSION
  spec.authors       = ["Luke Rodgers"]
  spec.email         = ["lukeasrodgers@gmail.com"]
  spec.summary       = %q{Orientdb ruby client}
  spec.description   = %q{Orientdb ruby client aiming to be simple, fast, and provide good integration with Orientdb error messages.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "typhoeus", "~> 0.6"
  spec.add_dependency "oj", "~> 2.0"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "rspec-mocks", "~> 3.3"
  spec.add_development_dependency "webmock", '~> 1.22'
  spec.add_development_dependency "byebug"
end

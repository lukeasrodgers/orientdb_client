# Changelog

## Master

* Added `CHANGELOG.md`
* Breaking change: Swapped logging to use ActiveSupport::Notifications (#16). You will need to 
update any code that assigns `MyClient::logger = `. Requests and response processing are
both instrumented.

## 0.0.2

* Integrated Travic CI (#15).
* Add handling more Orientdb errors (#14).

## 0.0.1

* Initial release.
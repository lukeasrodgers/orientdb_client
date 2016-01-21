# Changelog

## Master

* Correctly handle error message for database creation conflict exceptions.
* Ensure `NegativeArraySizeException`s are correctly converted to `NotFoundError`s across all supported versions of Orientdb.
* Ensure "database already exists" errors messages are consistent across all supported versions of Orientdb.

## 0.0.5

* Differentiate between Typhoeus adapter timeouts and connection failures.
* Prevent Curb errors from bubbling up to gem user; convert some of them to native
OrientdbClient errors.

## 0.0.4

* Added support for timeouts.

## 0.0.3

* Added `CHANGELOG.md`
* Breaking change: Swapped logging to use ActiveSupport::Notifications (#16). You will need to 
update any code that assigns `MyClient::logger = `. Requests and response processing are
both instrumented.

## 0.0.2

* Integrated Travic CI (#15).
* Add handling more Orientdb errors (#14).

## 0.0.1

* Initial release.

# Changelog

## v0.7.1

* Fix issue with preDeleteObjectData interceptor that errors for objects with no id field

## v0.7.0

* Re-introduced support for bundled enhanced record view of Preside 10.24.0
* Fixed label length issue for content records (field increase and limit input)
* Various scan performance improvements

## v0.6.11

* Fix some admin permission checking issues

## v0.6.10

* reverted changes from v0.6.9

## v0.6.9

* adding support for bundled enhanced record view of Preside 10.24.0

## v0.6.8

* fix issue with brand new applications failing to startup with Content dependency tracker installed

## v0.6.7

* added missing link to tracker event config for formbuilder forms, added asset folder for scanning

## v0.6.6

* fixing missing filter during delta scanning

## v0.6.5

* support task interruption, increase task exclusive lock time

## v0.6.4

* fix to support rare case of content objects invalid labelField definitions

## v0.6.3

* fix to support rare case of content objects with null values in labels
## v0.6.2

* added global feature for dependency tracker (not used in logic, just for app and other extension to know that the extension is installed)

## v0.6.1

* updated Readme

## v0.6.0

* added auto-tracking option

## v0.5.2

* Moved global link from anywhere into the tracker in the global nav next to system alerts

## v0.5.1

* Added missing database indexes (for better performance)

## v0.5.0

* Initial working commit (alpha version)

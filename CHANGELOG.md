## [2.0.0-nullsafety.0] - 2021-05-13

- Update to null safety

## [1.4.0] - 2021-03-15

- Fix dependencies to NOT include sdk 2.12 ones
- It's been reported that apps using background processes using this cannot access encrypted data
  - Changed the default IOS Accessability option to `IOSAccessibility.first_unlock_this_device`

## [1.3.0] - 2021-03-12

- Update dependencies (including sdk now needs >=2.9.0 <3.0.0)

## [1.2.0] - 2020-11-06

- Update dependencies (including Flutter)
- Add option to provide a location for the database file
- [WARNING] Previously the default time to live was 365 days. This has now been changed to `null` which makes it never expire 

## [1.1.0] - 2020-06-15

- Update dependencies
- Add `deleteLike` to delete items with similar keys

## [1.0.3] - 2020-04-11

- Update dependencies
- Update example to use AndroidX
- Improve security
  - Use fromSecureRandom() to get better random bytes for key and IV
  - Use different IV for each row
  - Backward compatability should be entact

## [1.0.2] - 2019-11-11

- Update dependencies

## [1.0.1+1] - 2019-09-21

- Fix readme

## [1.0.1] - 2019-09-21

- Add ability to provide optional database name
- Updated readme, explaining singleton

## [1.0.0] - 2019-09-21

- Initial Release

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixes

- Fix deferred nodes, now deferring using `task.defer`

## 0.5.0

### Added

- Add number springs by @alicesaidhi in #14
- Add switch by @alicesaidhi in #17
- Add controls for spring by @alicesaidhi in #19
- Allow `cleanup` to disconnect connections, instances and objects with a destroy function by @alicesaidhi in #18
- Implement rbxm build workflow by @alicesaidhi in #21

### Changed

- Add spring sleeping by @alicesaidhi in #22

### Fixes

- Fix source type by @alicesaidhi in #15
- Fix for_values by @dipsplitter in #16
- Adjust type for show and allow static values for show by @alicesaidhi in #20

## 0.4.0

### Added

- Add `fluid.bind` by @alicesaidhi in #12
- Add `deferred` by @alicesaidhi in #13

## 0.3.2

### Changed

- Exported `GetProperties` type

## 0.3.1

### Fixes

- Exported `Action` type

## 0.3.0

### Added

- Added `fluid.show` utility

### Fixes

- Fixed resource leak where singular reactive children were not destroyed
- Exported `fluid.read`

## 0.2.0

### Added

- Added `fluid.tags` utility which applies tags based off reactive values (#7)
- Added `fluid.lerp` (#9)
- Added `fluid.spring`
- Added `fluid.for_keys` (#3)
- Added `fluid.provide_scheduler`
- Added a delayed destruction parameter to `for_keys` and `for_values`

### Changed

- Improved the type signature of `fluid.create` (#10, #4)
- `fluid.for_values` now caches values (#3)
- Improved `fluid.read` type

## 0.1.0

### Added

- Initial release

## 0.0.0-D

### Fixed

- Authenticating releases

## 0.0.0-C

### Fixed

- Authenticating Wally

## 0.0.0-B

### Fixed

- Fixed release deployments?

## 0.0.0-A

### Added

- Initial commit.

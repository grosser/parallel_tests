# Changelog

## Unreleased

### Breaking Changes

- None

### Added

- None

### Fixed

- None

## 3.1.0 - 2020-07-23

### Added

- `--fail-fast` stops all groups if one group fails. Can be used to stop all groups if one test failed by using `fail-fast` in the test-framework too (for example rspec via `--test-options '--fail-fast'` or in `.rspec_parallel`).

## 3.0.0 - 2020-06-10

### Breaking Changes

- The `--group-by` flag with value `steps` and `features` now requires end users to add the `cuke_modeler` gem to their Gemfile (#762).

### Added

- Cucumber 4 support (#762)

### Fixed

- Fix a bundler deprecation when running specs (#761)
- remove name override logic that never worked (#758)

### Dependencies

- Drop ruby 2.3 support (#760)
- Drop ruby 2.2 support (#759)

## Previous versions

No docs yet. Contributions welcome!

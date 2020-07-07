# Changelog

## Unreleased

### Breaking Changes

- None

### Added

- `--fail-fast` options which stops all threads if one of them return not zero exit code. Which add possibility to stop whole suite if one test failed. Works if the option `--fail-fast` enabled for the rspec (passed to the test_options: `--test-options '--fail-fast'` or enabled at the .rspec_parallel file).  

### Fixed

- None

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

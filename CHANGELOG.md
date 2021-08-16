# Changelog

## Unreleased

### Breaking Changes

- None

### Added

- None

### Fixed

- None

## v3.7.1 - 2021-08-14

### Breaking Changes

- None

### Added

- None

### Fixed

- All cucumber options are now pushed to the end of the command invocation
  - Fixes an issue where the `--retry` flag wouldn't work correctly 

## v3.7.0 - 2021-04-08

### Breaking Changes

- None

### Added

- Added `--highest-exit-status` option to return the highest exit status to allow sub-processes to send things other than 1

### Fixed

- None

## v3.6.0 - 2021-03-25

### Breaking Changes

- Drop ruby 2.4 support

### Added

- Run default test folder if no arguments are passed.

### Fixed

- None

## v3.5.1 - 2021-03-07

### Breaking Changes

- None

### Added

- None

### Fixed

- Do not use db:structure for rails 6.1

## v3.5.0 - 2021-02-24

### Breaking Changes

- None

### Added

- Add support for specifying exactly how isolated processes run tests with 'specify-groups' option.
- Refactorings for rubocop

### Fixed

- None

## v3.4.0 - 2020-12-24

### Breaking Changes

- None

### Added

- Colorize summarized RSpec results.([#787](https://github.com/grosser/parallel_tests/pull/787)).

### Fixed

- replace deprecated db:structure by db:schema (#801).

## 3.3.0 - 2020-09-16

### Added

- Added support for multiple isolated processes.

## 3.2.0 - 2020-08-27

### Breaking Changes

- RAILS_ENV cannot be specified for rake tasks (#776).

### Added

- None

### Fixed

- Rake tasks will no longer run against development environment when using a Spring-ified rake binstub (#776).

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

## 2.32.0 - 2020-03-15

### Fixed
- Calculate unknown runtimes lazily when running tests grouped by runtime ([#750](https://github.com/grosser/parallel_tests/pull/750)).

## 2.31.0 - 2020-01-31

### Fixed
- File paths passed from the CLI are now cleaned (consecutive slashes and useless dots removed) ([#748](https://github.com/grosser/parallel_tests/pull/748)).

## 2.30.1 - 2020-01-14

### Added
- Add project metadata to gemspec ([#739](https://github.com/grosser/parallel_tests/pull/739)).

## Fixed
- Fix bundler deprecation warning related to `bundle show`) ([#744](https://github.com/grosser/parallel_tests/pull/744)).
- Fix numerous flakey tests ([#736](https://github.com/grosser/parallel_tests/pull/736), [#741](https://github.com/grosser/parallel_tests/pull/741)).

## 2.30.0 - 2019-12-10

### Added
- Support db:structure:dump and load structure in parallel ([#732](ht.tps://github.com/grosser/parallel_tests/pull/732)).
- Add note to the README about using the spring-commands-parallel-tests gem to automatically patch and enable Spring ([#731](https://github.com/grosser/parallel_tests/pull/731)).

### Fixed
- Refactor logic in the `parallel:prepare` task ([#737](https://github.com/grosser/parallel_tests/pull/737)).
- Update README to use :sql schema format.
- Fix loading of the `version` file when using a local git repo with Bundler ([#730](https://github.com/grosser/parallel_tests/pull/730)).

## 2.29.2 - 2019-08-06

### Fixed
- Eliminate some ruby warnings relating to ambigious arguments, unused variables, a redefined method, and uninitialized instance variables ([#712](https://github.com/grosser/parallel_tests/pull/712)).

## 2.29.1 - 2019-06-13

### Fixed
- Fix NameError due to not requiring `shellwords` ([#707](https://github.com/grosser/parallel_tests/pull/707)).

## 2.29.0 - 2019-05-04

### Added
- `--verbose-process-command`, which prints the command that will be executed by each process before it begins ([#697](https://github.com/grosser/parallel_tests/pull/697/files)).
- `--verbose-rerun-command`, which prints the command executed by that process after a process fails ([#697](https://github.com/grosser/parallel_tests/pull/697/files)).

## 2.28.0 - 2019-02-07

### Added
- `exclude-pattern`, which excludes tests matching the passed in regex pattern ([#682](https://github.com/grosser/parallel_tests/pull/682), [#683](https://github.com/grosser/parallel_tests/pull/683)).

## 2.27.1 - 2019-01-01

### Changed
- `simulate_output_for_ci` now outputs dots (`.`) even after the first parallel thread finishes ([#673](https://github.com/grosser/parallel_tests/pull/673)).

### Fixed
- Typo in CLI options ([#672](https://github.com/grosser/parallel_tests/pull/672)).

## 2.27.0 - 2018-11-09

### Added
- Support for new Cucumber tag expressions syntax ([#668](https://github.com/grosser/parallel_tests/pull/668)).

## 2.26.2 - 2018-10-29

### Added
- `db:test:purge` is now `db:purge` so it can be used in any environment, not just the `test` environment. This change is backwards compatible. ([#665](https://github.com/grosser/parallel_tests/pull/665)).
- Tests against Rails 5.1 and 5.2 ([#663])(https://github.com/grosser/parallel_tests/pull/663)).

## 2.26.0 - 2018-10-25

### Fixed
- Update formatter to use Cucumber events API instead of deprecated API ([#664](https://github.com/grosser/parallel_tests/pull/664))

## 2.25.0 - 2018-10-24

### Fixed
- Commands and their respective outputs are now grouped together when using the `verbose` and `serialize-output` flags together ([#660](https://github.com/grosser/parallel_tests/pull/660)).

### Dependencies
- Dropped support for MiniTest 4 and Test-Unit ([#662](https://github.com/grosser/parallel_tests/pull/662)).
- Dropped support for Ruby 2.1 ([#659](https://github.com/grosser/parallel_tests/pull/659))

## 2.24.0 - 2018-10-24

### Fixed
- Improve accuracy when recording example times ([#661](https://github.com/grosser/parallel_tests/pull/661)).

### Dependencies
- Dropped support for Ruby 2.0 ([#661](https://github.com/grosser/parallel_tests/pull/661)).

## 2.23.0 - 2018-09-14

### Added
- Rake task now passes through additional arguments to the CLI ([#656](https://github.com/grosser/parallel_tests/pull/656)).


## Previous versions

No docs yet. Contributions welcome!

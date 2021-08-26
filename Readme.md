# parallel_tests

[![Gem Version](https://badge.fury.io/rb/parallel_tests.svg)](https://rubygems.org/gems/parallel_tests)
[![Build Status](https://travis-ci.org/grosser/parallel_tests.svg)](https://travis-ci.org/grosser/parallel_tests/builds)
[![Build status](https://github.com/grosser/parallel_tests/workflows/windows/badge.svg)](https://github.com/grosser/parallel_tests/actions?query=workflow%3Awindows)

Speedup Test::Unit + RSpec + Cucumber + Spinach by running parallel on multiple CPU cores.<br/>
ParallelTests splits tests into even groups (by number of lines or runtime) and runs each group in a single process with its own database.

Setup for Rails
===============
[RailsCasts episode #413 Fast Tests](http://railscasts.com/episodes/413-fast-tests)

### Install
`Gemfile`:

```ruby
gem 'parallel_tests', group: [:development, :test]
```

### Add to `config/database.yml`

ParallelTests uses 1 database per test-process.
<table>
  <tr><td>Process number</td><td>1</td><td>2</td><td>3</td></tr>
  <tr><td>ENV['TEST_ENV_NUMBER']</td><td>''</td><td>'2'</td><td>'3'</td></tr>
</table>

```yaml
test:
  database: yourproject_test<%= ENV['TEST_ENV_NUMBER'] %>
```

### Create additional database(s)
    rake parallel:create

### Copy development schema (repeat after migrations)
    rake parallel:prepare

### Run migrations in additional database(s) (repeat after migrations)
    rake parallel:migrate

### Setup environment from scratch (create db and loads schema, useful for CI)
    rake parallel:setup
    
### Drop all test databases
    rake parallel:drop

### Run!
    rake parallel:test          # Test::Unit
    rake parallel:spec          # RSpec
    rake parallel:features      # Cucumber
    rake parallel:features-spinach       # Spinach

    rake parallel:test[1] --> force 1 CPU --> 86 seconds
    rake parallel:test    --> got 2 CPUs? --> 47 seconds
    rake parallel:test    --> got 4 CPUs? --> 26 seconds
    ...

Test by pattern with Regex (e.g. use one integration server per subfolder / see if you broke any 'user'-related tests)

    rake parallel:test[^test/unit] # every test file in test/unit folder
    rake parallel:test[user]  # run users_controller + user_helper + user tests
    rake parallel:test['user|product']  # run user and product related tests
    rake parallel:spec['spec\/(?!features)'] # run RSpec tests except the tests in spec/features


### Example output

    2 processes for 210 specs, ~ 105 specs per process
    ... test output ...

    843 examples, 0 failures, 1 pending

    Took 29.925333 seconds

### Run an arbitrary task in parallel
```Bash
RAILS_ENV=test parallel_test -e "rake my:custom:task"
# or
rake parallel:rake[my:custom:task]
# limited parallelism
rake parallel:rake[my:custom:task,2]
```


Running things once
===================

```Ruby
require "parallel_tests"

# preparation:
# affected by race-condition: first process may boot slower than the second
# either sleep a bit or use a lock for example File.lock
ParallelTests.first_process? ? do_something : sleep(1)

# cleanup:
# last_process? does NOT mean last finished process, just last started
ParallelTests.last_process? ? do_something : sleep(1)

at_exit do
  if ParallelTests.first_process?
    ParallelTests.wait_for_other_processes_to_finish
    undo_something
  end
end
```

Even test group run-times
=========================

Test groups are often not balanced and will run for different times, making everything wait for the slowest group.
Use these loggers to record test runtime and then use the recorded runtime to balance test groups more evenly.

### RSpec

Rspec: Add to your `.rspec_parallel` (or `.rspec`) :

    --format progress
    --format ParallelTests::RSpec::RuntimeLogger --out tmp/parallel_runtime_rspec.log

To use a custom logfile location (default: `tmp/parallel_runtime_rspec.log`), use the CLI: `parallel_test spec -t rspec --runtime-log my.log`

### Minitest

Add to your `test_helper.rb`:
```ruby
require 'parallel_tests/test/runtime_logger' if ENV['RECORD_RUNTIME']
```

results will be logged to tmp/parallel_runtime_test.log when `RECORD_RUNTIME` is set,
so it is not always required or overwritten.

Loggers
=======

RSpec: SummaryLogger
--------------------

Log the test output without the different processes overwriting each other.

Add the following to your `.rspec_parallel` (or `.rspec`) :

    --format progress
    --format ParallelTests::RSpec::SummaryLogger --out tmp/spec_summary.log

RSpec: FailuresLogger
-----------------------

Produce pastable command-line snippets for each failed example. For example:

```bash
rspec /path/to/my_spec.rb:123 # should do something
```

Add to `.rspec_parallel` or use as CLI flag:

    --format progress
    --format ParallelTests::RSpec::FailuresLogger --out tmp/failing_specs.log

(Not needed to retry failures, for that pass [--only-failures](https://relishapp.com/rspec/rspec-core/docs/command-line/only-failures) to rspec)

Cucumber: FailuresLogger
-----------------------

Log failed cucumber scenarios to the specified file. The filename can be passed to cucumber, prefixed with '@' to rerun failures.

Usage:

    cucumber --format ParallelTests::Cucumber::FailuresLogger --out tmp/cucumber_failures.log

Or add the formatter to the `parallel:` profile of your `cucumber.yml`:

    parallel: --format progress --format ParallelTests::Cucumber::FailuresLogger --out tmp/cucumber_failures.log

Note if your `cucumber.yml` default profile uses `<%= std_opts %>` you may need to insert this as follows `parallel: <%= std_opts %> --format progress...`

To rerun failures:

    cucumber @tmp/cucumber_failures.log

Setup for non-rails
===================

    gem install parallel_tests
    # go to your project dir
    parallel_test
    parallel_rspec
    parallel_cucumber
    parallel_spinach

 - use `ENV['TEST_ENV_NUMBER']` inside your tests to select separate db/memcache/etc. (docker compose: expose it)

 - Only run a subset of files / folders:
 
    `parallel_test test/bar test/baz/foo_text.rb`

 - Pass test-options and files via `--`:
 
    `parallel_rspec -- -t acceptance -f progress -- spec/foo_spec.rb spec/acceptance`
    
 - Pass in test options, by using the -o flag (wrap everything in quotes):
 
    `parallel_cucumber -n 2 -o '-p foo_profile --tags @only_this_tag or @only_that_tag --format summary'`

Options are:
<!-- copy output from bundle exec ./bin/parallel_test -h -->
    -n [PROCESSES]                   How many processes to use, default: available CPUs
    -p, --pattern [PATTERN]          run tests matching this regex pattern
        --exclude-pattern [PATTERN]  exclude tests matching this regex pattern
        --group-by [TYPE]            group tests by:
                                     found - order of finding files
                                     steps - number of cucumber/spinach steps
                                     scenarios - individual cucumber scenarios
                                     filesize - by size of the file
                                     runtime - info from runtime log
                                     default - runtime when runtime log is filled otherwise filesize
    -m, --multiply-processes [FLOAT] use given number as a multiplier of processes to run
    -s, --single [PATTERN]           Run all matching files in the same process
    -i, --isolate                    Do not run any other tests in the group used by --single(-s)
        --isolate-n [PROCESSES]      Use 'isolate'  singles with number of processes, default: 1.
        --highest-exit-status        Exit with the highest exit status provided by test run(s)
        --specify-groups [SPECS]     Use 'specify-groups' if you want to specify multiple specs running in multiple
                                     processes in a specific formation. Commas indicate specs in the same process,
                                     pipes indicate specs in a new process. Cannot use with --single, --isolate, or
                                     --isolate-n.  Ex.
                                     $ parallel_tests -n 3 . --specify-groups '1_spec.rb,2_spec.rb|3_spec.rb'
                                       Process 1 will contain 1_spec.rb and 2_spec.rb
                                       Process 2 will contain 3_spec.rb
                                       Process 3 will contain all other specs
        --only-group INT[,INT]
    -e, --exec [COMMAND]             execute this code parallel and with ENV['TEST_ENV_NUMBER']
    -o, --test-options '[OPTIONS]'   execute test commands with those options
    -t, --type [TYPE]                test(default) / rspec / cucumber / spinach
        --suffix [PATTERN]           override built in test file pattern (should match suffix):
                                     '_spec.rb$' - matches rspec files
                                     '_(test|spec).rb$' - matches test or spec files
        --serialize-stdout           Serialize stdout output, nothing will be written until everything is done
        --prefix-output-with-test-env-number
                                     Prefixes test env number to the output when not using --serialize-stdout
        --combine-stderr             Combine stderr into stdout, useful in conjunction with --serialize-stdout
        --non-parallel               execute same commands but do not in parallel, needs --exec
        --no-symlinks                Do not traverse symbolic links to find test files
        --ignore-tags [PATTERN]      When counting steps ignore scenarios with tags that match this pattern
        --nice                       execute test commands with low priority.
        --runtime-log [PATH]         Location of previously recorded test runtimes
        --allowed-missing [INT]      Allowed percentage of missing runtimes (default = 50)
        --unknown-runtime [FLOAT]    Use given number as unknown runtime (otherwise use average time)
        --first-is-1                 Use "1" as TEST_ENV_NUMBER to not reuse the default test environment
        --fail-fast                  Stop all groups when one group fails (best used with --test-options '--fail-fast' if supported
        --verbose                    Print debug output
        --verbose-process-command    Displays only the command that will be executed by each process
        --verbose-rerun-command      When there are failures, displays the command executed by each process that failed
        --quiet                      Print only tests output
    -v, --version                    Show Version
    -h, --help                       Show this.

You can run any kind of code in parallel with -e / --exec

    parallel_test -n 5 -e 'ruby -e "puts %[hello from process #{ENV[:TEST_ENV_NUMBER.to_s].inspect}]"'
    hello from process "2"
    hello from process ""
    hello from process "3"
    hello from process "5"
    hello from process "4"

<table>
<tr><td></td><td>1 Process</td><td>2 Processes</td><td>4 Processes</td></tr>
<tr><td>RSpec spec-suite</td><td>18s</td><td>14s</td><td>10s</td></tr>
<tr><td>Rails-ActionPack</td><td>88s</td><td>53s</td><td>44s</td></tr>
</table>

TIPS
====

### RSpec

 - Add a `.rspec_parallel` to use different options, e.g. **no --drb**
 - Remove `--loadby` from `.rspec`
 - Instantly see failures (instead of just a red F) with [rspec-instafail](https://github.com/grosser/rspec-instafail)
 - Use [rspec-retry](https://github.com/NoRedInk/rspec-retry) (not rspec-rerun) to rerun failed tests.
 - [JUnit formatter configuration](https://github.com/grosser/parallel_tests/wiki#with-rspec_junit_formatter----by-jgarber)
 - Use [parallel_split_test](https://github.com/grosser/parallel_split_test) to run multiple scenarios in a single spec file, concurrently. (`parallel_tests` [works at the file-level and intends to stay that way](https://github.com/grosser/parallel_tests/issues/747#issuecomment-580216980))

### Cucumber

 - Add a `parallel: foo` profile to your `config/cucumber.yml` and it will be used to run parallel tests
 - [ReportBuilder](https://github.com/rajatthareja/ReportBuilder) can help with combining parallel test results
   - Supports Cucumber 2.0+ and is actively maintained
   - Combines many JSON files into a single file
   - Builds a HTML report from JSON with support for debug msgs & embedded Base64 images.

### General
 - [ZSH] use quotes to use rake arguments `rake "parallel:prepare[3]"`
 - [Memcached] use different namespaces<br/>
   e.g. `config.cache_store = ..., namespace: "test_#{ENV['TEST_ENV_NUMBER']}"`
 - Debug errors that only happen with multiple files using `--verbose` and [cleanser](https://github.com/grosser/cleanser)
 - `export PARALLEL_TEST_PROCESSORS=13` to override default processor count
 - Shell alias: `alias prspec='parallel_rspec -m 2 --'`
 - [Spring] Add the [spring-commands-parallel-tests](https://github.com/DocSpring/spring-commands-parallel-tests) gem to your `Gemfile` to get `parallel_tests` working with Spring.
 - `--first-is-1` will make the first environment be `1`, so you can test while running your full suite.<br/>
   `export PARALLEL_TEST_FIRST_IS_1=true` will provide the same result
 - [email_spec and/or action_mailer_cache_delivery](https://github.com/grosser/parallel_tests/wiki)
 - [zeus-parallel_tests](https://github.com/sevos/zeus-parallel_tests)
 - [Distributed Parallel Tests on CI systems)](https://github.com/grosser/parallel_tests/wiki/Distributed-Parallel-Tests-on-CI-systems) learn how `parallel_tests` can run on distributed servers such as Travis and GitLab-CI. Also shows you how to use parallel_tests without adding `TEST_ENV_NUMBER`-backends
 - [Capybara setup](https://github.com/grosser/parallel_tests/wiki)
 - [Sphinx setup](https://github.com/grosser/parallel_tests/wiki)
 - [Capistrano setup](https://github.com/grosser/parallel_tests/wiki/Remotely-with-capistrano) let your tests run on a big box instead of your laptop

Contribute your own gotchas to the [Wiki](https://github.com/grosser/parallel_tests/wiki) or even better open a PR :)

Authors
====
inspired by [pivotal labs](https://blog.pivotal.io/labs/labs/parallelize-your-rspec-suite)

### [Contributors](https://github.com/grosser/parallel_tests/contributors)
 - [Charles Finkel](http://charlesfinkel.com/)
 - [Indrek Juhkam](http://urgas.eu)
 - [Jason Morrison](http://jayunit.net)
 - [jinzhu](http://github.com/jinzhu)
 - [Joakim Kolsjö](http://www.rubyblocks.se)
 - [Kevin Scaldeferri](http://kevin.scaldeferri.com/blog/)
 - [Kpumuk](http://kpumuk.info/)
 - [Maksim Horbul](http://github.com/mhorbul)
 - [Pivotal Labs](http://www.pivotallabs.com)
 - [Rohan Deshpande](http://github.com/rdeshpande)
 - [Tchandy](http://thiagopradi.net/)
 - [Terence Lee](http://hone.heroku.com/)
 - [Will Bryant](http://willbryant.net/)
 - [Fred Wu](http://fredwu.me)
 - [xxx](https://github.com/xxx)
 - [Levent Ali](http://purebreeze.com/)
 - [Michael Kintzer](https://github.com/rockrep)
 - [nathansobo](https://github.com/nathansobo)
 - [Joe Yates](http://titusd.co.uk)
 - [asmega](http://www.ph-lee.com)
 - [Doug Barth](https://github.com/dougbarth)
 - [Geoffrey Hichborn](https://github.com/phene)
 - [Trae Robrock](https://github.com/trobrock)
 - [Lawrence Wang](https://github.com/levity)
 - [Sean Walbran](https://github.com/seanwalbran)
 - [Lawrence Wang](https://github.com/levity)
 - [Potapov Sergey](https://github.com/greyblake)
 - [Łukasz Tackowiak](https://github.com/lukasztackowiak)
 - [Pedro Carriço](https://github.com/pedrocarrico)
 - [Pablo Manrubia Díez](https://github.com/pmanrubia)
 - [Slawomir Smiechura](https://github.com/ssmiech)
 - [Georg Friedrich](https://github.com/georg)
 - [R. Tyler Croy](https://github.com/rtyler)
 - [Ulrich Berkmüller](https://github.com/ulrich-berkmueller)
 - [Grzegorz Derebecki](https://github.com/madmax)
 - [Florian Motlik](https://github.com/flomotlik)
 - [Artem Kuzko](https://github.com/akuzko)
 - [Zeke Fast](https://github.com/zekefast)
 - [Joseph Shraibman](https://github.com/jshraibman-mdsol)
 - [David Davis](https://github.com/daviddavis)
 - [Ari Pollak](https://github.com/aripollak)
 - [Aaron Jensen](https://github.com/aaronjensen)
 - [Artur Roszczyk](https://github.com/sevos)
 - [Caleb Tomlinson](https://github.com/calebTomlinson)
 - [Jawwad Ahmad](https://github.com/jawwad)
 - [Iain Beeston](https://github.com/iainbeeston)
 - [Alejandro Pulver](https://github.com/alepulver)
 - [Felix Clack](https://github.com/felixclack)
 - [Izaak Alpert](https://github.com/karlhungus)
 - [Micah Geisel](https://github.com/botandrose)
 - [Exoth](https://github.com/Exoth)
 - [sidfarkus](https://github.com/sidfarkus)
 - [Colin Harris](https://github.com/aberant)
 - [Wataru MIYAGUNI](https://github.com/gongo)
 - [Brandon Turner](https://github.com/blt04)
 - [Matt Hodgson](https://github.com/mhodgson)
 - [bicarbon8](https://github.com/bicarbon8)
 - [seichner](https://github.com/seichner)
 - [Matt Southerden](https://github.com/mattsoutherden)
 - [Stanislaw Wozniak](https://github.com/sponte)
 - [Dmitry Polushkin](https://github.com/dmitry)
 - [Samer Masry](https://github.com/smasry)
 - [Volodymyr Mykhailyk](https:/github.com/volodymyr-mykhailyk)
 - [Mike Mueller](https://github.com/mmueller)
 - [Aaron Jensen](https://github.com/aaronjensen)
 - [Ed Slocomb](https://github.com/edslocomb)
 - [Cezary Baginski](https://github.com/e2)
 - [Marius Ioana](https://github.com/mariusioana)
 - [Lukas Oberhuber](https://github.com/lukaso)
 - [Ryan Zhang](https://github.com/ryanus)
 - [Rhett Sutphin](https://github.com/rsutphin)
 - [Doc Ritezel](https://github.com/ohrite)
 - [Alexandre Wilhelm](https://github.com/dogild)
 - [Jerry](https://github.com/boblington)
 - [Aleksei Gusev](https://github.com/hron)
 - [Scott Olsen](https://github.com/scottolsen)
 - [Andrei Botalov](https://github.com/abotalov)
 - [Zachary Attas](https://github.com/snackattas)
 - [David Rodríguez](https://github.com/deivid-rodriguez)
 - [Justin Doody](https://github.com/justindoody)
 - [Sandeep Singh](https://github.com/sandeepnagra)
 - [Calaway](https://github.com/calaway)
 - [alboyadjian](https://github.com/alboyadjian)
 - [Nathan Broadbent](https://github.com/ndbroadbent)
 - [Vikram B Kumar](https://github.com/v-kumar)
 - [Joshua Pinter](https://github.com/joshuapinter)
 - [Zach Dennis](https://github.com/zdennis)

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT

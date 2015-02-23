Speedup Test::Unit + RSpec + Cucumber + Spinach by running parallel on multiple CPU cores.<br/>
ParallelTests splits tests into even groups (by number of lines or runtime) and runs each group in a single process with its own database.

Setup for Rails
===============
[RailsCasts episode #413 Fast Tests](http://railscasts.com/episodes/413-fast-tests)

### Install

```ruby
# Gemfile
gem "parallel_tests", :group => :development
```

### Add to `config/database.yml`

ParallelTests uses 1 database per test-process.
<table>
  <tr><td>Process number</td><td>1</td><td>2</td><td>3</td></tr>
  <tr><td>`ENV['TEST_ENV_NUMBER']`</td><td>''</td><td>'2'</td><td>'3'</td></tr>
</table>

```yaml
test:
  database: yourproject_test<%= ENV['TEST_ENV_NUMBER'] %>
```

### Create additional database(s)
    rake parallel:create

### Copy development schema (repeat after migrations)
    rake parallel:prepare

### Run!
    rake parallel:test          # Test::Unit
    rake parallel:spec          # RSpec
    rake parallel:features      # Cucumber
    rake parallel:features-spinach       # Spinach

    rake parallel:test[1] --> force 1 CPU --> 86 seconds
    rake parallel:test    --> got 2 CPUs? --> 47 seconds
    rake parallel:test    --> got 4 CPUs? --> 26 seconds
    ...

Test by pattern (e.g. use one integration server per subfolder / see if you broke any 'user'-related tests)

    rake parallel:test[^test/unit] # every test file in test/unit folder
    rake parallel:test[user]  # run users_controller + user_helper + user tests
    rake parallel:test['user|product']  # run user and product related tests


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
```


Running things once
===================

```Ruby
# effected by race-condition: first process may boot slower the second
# either sleep a bit or use a lock for example File.lock
ParallelTests.first_process? ? do_something : sleep(1)

at_exit do
  if ParallelTests.first_process?
    ParallelTests.wait_for_other_processes_to_finish
    undo_something
  end
end
```

Loggers
===================

Even test group run-times
-------------------------

### RSpec

Add the `RuntimeLogger` to log how long each test takes to run.
This log file will be loaded on the next test run, and the tests will be grouped
so that each process should finish around the same time.

Rspec: Add to your `.rspec_parallel` (or `.rspec`) :

    --format progress
    --format ParallelTests::RSpec::RuntimeLogger --out tmp/parallel_runtime_rspec.log

### Test::Unit

Add to your `test_helper.rb`:
```ruby
require 'parallel_tests/test/runtime_logger'
```

results will be logged to tmp/parallel_runtime_test.log

RSpec: SummaryLogger
--------------------

Log the test output without the different processes overwriting each other.

Add the following to your `.rspec_parallel` (or `.rspec`) :

    --format progress
    --format ParallelTests::RSpec::SummaryLogger --out tmp/spec_summary.log

RSpec: FailuresLogger
-----------------------

Produce pasteable command-line snippets for each failed example.

E.g.

    rspec /path/to/my_spec.rb:123 # should do something

Add the following to your `.rspec_parallel` (or `.rspec`) :

    --format progress
    --format ParallelTests::RSpec::FailuresLogger --out tmp/failing_specs.log

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
    parallel_test test/
    parallel_rspec spec/
    parallel_cucumber features/
    parallel_spinach features/

 - use ENV['TEST_ENV_NUMBER'] inside your tests to select separate db/memcache/etc.
 - Only run selected files & folders:

    parallel_test test/bar test/baz/foo_text.rb

Options are:

    -n [PROCESSES]                   How many processes to use, default: available CPUs
    -p, --pattern [PATTERN]          run tests matching this pattern
        --group-by [TYPE]            group tests by:
          found - order of finding files
          steps - number of cucumber/spinach steps
          scenarios - individual cucumber scenarios
          filesize - by size of the file
          default - runtime or filesize
    -m, --multiply-processes [FLOAT] use given number as a multiplier of processes to run
    -s, --single [PATTERN]           Run all matching files in the same process
    -i, --isolate                    Do not run any other tests in the group used by --single(-s)
        --only-group INT[, INT]
    -e, --exec [COMMAND]             execute this code parallel and with ENV['TEST_ENV_NUM']
    -o, --test-options '[OPTIONS]'   execute test commands with those options
    -t, --type [TYPE]                test(default) / rspec / cucumber / spinach
        --serialize-stdout           Serialize stdout output, nothing will be written until everything is done
        --combine-stderr             Combine stderr into stdout, useful in conjunction with --serialize-stdout
        --non-parallel               execute same commands but do not in parallel, needs --exec
        --no-symlinks                Do not traverse symbolic links to find test files
        --ignore-tags [PATTERN]      When counting steps ignore scenarios with tags that match this pattern
        --nice                       execute test commands with low priority.
        --runtime-log [PATH]         Location of previously recorded test runtimes
        --verbose                    Print more output
    -v, --version                    Show Version
    -h, --help                       Show this.

You can run any kind of code in parallel with -e / --execute

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
 - [RSpec] add a `.rspec_parallel` to use different options, e.g. **no --drb**
 - Spring does not work with parallel_tests, use `DISABLE_SPRING=1 rake parallel:spec` if you have spring hardcoded in your binaries
 - [RSpec] remove `--loadby` from `.rspec`
 - [RSpec] Instantly see failures (instead of just a red F) with [rspec-instafail](https://github.com/grosser/rspec-instafail)
 - [Cucumber] add a `parallel: foo` profile to your `config/cucumber.yml` and it will be used to run parallel tests
 - [Capybara setup](https://github.com/grosser/parallel_tests/wiki)
 - [Sphinx setup](https://github.com/grosser/parallel_tests/wiki)
 - [Capistrano setup](https://github.com/grosser/parallel_tests/wiki/Remotely-with-capistrano) let your tests run on a big box instead of your laptop
 - [SQL schema format] use :ruby schema format to get faster parallel:prepare`
 - `export PARALLEL_TEST_PROCESSORS=X` in your environment and parallel_tests will use this number of processors by default
 - [ZSH] use quotes to use rake arguments `rake "parallel:prepare[3]"`
 - [email_spec and/or action_mailer_cache_delivery](https://github.com/grosser/parallel_tests/wiki)
 - [Memcached] use different namespaces e.g. `config.cache_store = ..., namespace: "test_#{ENV['TEST_ENV_NUMBER']}"`
 - [zeus-parallel_tests](https://github.com/sevos/zeus-parallel_tests)
 - [Distributed parallel test (e.g. Travis Support)](https://github.com/grosser/parallel_tests/wiki/Distributed-Parallel-Tests-and-Travis-Support)
 - Contribute your own gotaches to the [Wiki](https://github.com/grosser/parallel_tests/wiki) or even better open a PR :)

TODO
====
 - make tests consistently pass with `--order random` in .rspec
 - fix tests vs cucumber >= 1.2 `unknown option --format`
 - add integration tests for the rake tasks, maybe generate a rails project ...
 - add unit tests for cucumber runtime formatter
 - make windows compatible

Authors
====
inspired by [pivotal labs](http://pivotallabs.com/users/miked/blog/articles/849-parallelize-your-rspec-suite)

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

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/parallel_tests.png)](https://travis-ci.org/grosser/parallel_tests)

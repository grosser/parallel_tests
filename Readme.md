Speedup Test::Unit + RSpec + Cucumber by running parallel on multiple CPUs (or cores).<br/>
ParallelTests splits tests into even groups(by number of tests or runtime) and runs each group in a single process with its own database.

[upgrading from 0.6 ?](https://github.com/grosser/parallel_tests/wiki/Upgrading-0.6.x-to-0.7.x)

Setup for Rails
===============
[still using Rails 2?](https://github.com/grosser/parallel_tests/blob/master/ReadmeRails2.md)

## Install
If you use RSpec: ensure you got >= 2.4

As gem

    # add to Gemfile
    gem "parallel_tests", :group => :development

OR as plugin

    rails plugin install git://github.com/grosser/parallel_tests.git

    # add to Gemfile
    gem "parallel", :group => :development

## Setup
ParallelTests uses 1 database per test-process, 2 processes will use `*_test` and `*_test2`.


### 1: Add to `config/database.yml`
    test:
      database: yourproject_test<%= ENV['TEST_ENV_NUMBER'] %>

### 2: Create additional database(s)
    rake parallel:create

### 3: Copy development schema (repeat after migrations)
    rake parallel:prepare

### 4: Run!
    rake parallel:test          # Test::Unit
    rake parallel:spec          # RSpec
    rake parallel:features      # Cucumber

    rake parallel:test[1] --> force 1 CPU --> 86 seconds
    rake parallel:test    --> got 2 CPUs? --> 47 seconds
    rake parallel:test    --> got 4 CPUs? --> 26 seconds
    ...

Test by pattern (e.g. use one integration server per subfolder / see if you broke any 'user'-related tests)

    rake parallel:test[^test/unit] # every test file in test/unit folder
    rake parallel:test[user]  # run users_controller + user_helper + user tests
    rake parallel:test['user|product']  # run user and product related tests


Example output
--------------
    2 processes for 210 specs, ~ 105 specs per process
    ... test output ...

    843 examples, 0 failures, 1 pending

    Took 29.925333 seconds

Loggers
===================

Even process runtimes
-----------------

Log test runtime to give each process the same runtime.

Rspec: Add to your `.rspec_parallel` (or `.rspec`) :

    RSpec
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelTests::RSpec::RuntimeLogger --out tmp/parallel_runtime_rspec.log

Test::Unit:  Add to your `test_helper.rb`:

    require 'parallel_tests/test/runtime_logger'


SpecSummaryLogger
--------------------

This logger logs the test output without the different processes overwriting each other.

Add the following to your `.rspec_parallel` (or `.rspec`) :

    RSpec:
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelTests::RSpec::SummaryLogger --out tmp/spec_summary.log

SpecFailuresLogger
-----------------------

This logger produces pasteable command-line snippets for each failed example.

E.g.

    rspec /path/to/my_spec.rb:123 # should do something

Add the following to your `.rspec_parallel` (or `.rspec`) :

    RSpec:
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelTests::RSpec::FailuresLogger --out tmp/failing_specs.log

Setup for non-rails
===================
    gem install parallel_tests
    # go to your project dir
    parallel_test test/
    parallel_rspec spec/
    parallel_cucumber features/

 - use ENV['TEST_ENV_NUMBER'] inside your tests to select separate db/memcache/etc.
 - Only run selected files & folders:

    parallel_test test/bar test/baz/foo_text.rb

Options are:

    -n [PROCESSES]                   How many processes to use, default: available CPUs
    -p, --path [PATH]                run tests inside this path only
        --no-sort                    do not sort files before running them
    -m, --multiply-processes [FLOAT] use given number as a multiplier of processes to run
    -e, --exec [COMMAND]             execute this code parallel and with ENV['TEST_ENV_NUM']
    -o, --test-options '[OPTIONS]'   execute test commands with those options
    -t, --type [TYPE]                test(default) / spec / cucumber
        --non-parallel               execute same commands but do not in parallel, needs --exec
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
 - [Capybara + Selenium] add to env.rb: `Capybara.server_port = 8888 + ENV['TEST_ENV_NUMBER'].to_i`
 - [RSpec] add a `.rspec_parallel` to use different options, e.g. **no --drb**
 - [RSpec] delete `script/spec`
 - [RSpec] [spork](https://github.com/timcharper/spork) does not work in parallel
 - [RSpec] remove --loadby from you spec/*.opts
 - [RSpec] Instantly see failures (instead of just a red F) with [rspec-instafail](https://github.com/grosser/rspec-instafail)
 - [Bundler] if you have a `Gemfile` then `bundle exec` will be used to run tests
 - [Capybara setup](https://github.com/grosser/parallel_tests/wiki)
 - [Sphinx setup](https://github.com/grosser/parallel_tests/wiki)
 - [Capistrano setup](https://github.com/grosser/parallel_tests/wiki/Remotely-with-capistrano) let your tests run on a big box instead of your laptop
 - [SQL schema format] use :ruby schema format to get faster parallel:prepare`
 - [ActiveRecord] if you do not have `db:abort_if_pending_migrations` add this to your Rakefile: `task('db:abort_if_pending_migrations'){}`
 - `export PARALLEL_TEST_PROCESSORS=X` in your environment and parallel_tests will use this number of processors by default
 - [ZSH] use quotes to use rake arguments `rake "parallel:prepare[3]"`

TODO
====
 - add unit tests for cucumber runtime formatter
 - make jRuby compatible [basics](http://yehudakatz.com/2009/07/01/new-rails-isolation-testing/)
 - make windows compatible

Authors
====
inspired by [pivotal labs](http://pivotallabs.com/users/miked/blog/articles/849-parallelize-your-rspec-suite)

### [Contributors](http://github.com/grosser/parallel_tests/contributors)
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

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT

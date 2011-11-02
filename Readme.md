Speedup Test::Unit + RSpec + Cucumber by running parallel on multiple CPUs (or cores).<br/>
ParallelTests splits tests into even groups(by number of tests or runtime) and runs each group in a single process with its own database.

Setup for Rails
===============
## Install
### Rails 3
If you use RSpec: ensure you got >= 2.4

As gem

    # add to Gemfile
    gem "parallel_tests", :group => :development

OR as plugin

    rails plugin install git://github.com/grosser/parallel_tests.git

    # add to Gemfile
    gem "parallel", :group => :development


### Rails 2

As gem

    gem install parallel_tests

    # add to config/environments/development.rb
    config.gem "parallel_tests"

    # add to Rakefile
    begin; require 'parallel_tests/tasks'; rescue LoadError; end

OR as plugin

    gem install parallel

    # add to config/environments/development.rb
    config.gem "parallel"

    ./script/plugin install git://github.com/grosser/parallel_tests.git

## Setup
ParallelTests uses 1 database per test-process, 2 processes will use `*_test` and `*_test2`.


### 1: Add to `config/database.yml`
    test:
      database: xxx_test<%= ENV['TEST_ENV_NUMBER'] %>

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

    rake parallel:test[^unit] # everything in test/unit folder (every test file matching /^unit/)
    rake parallel:test[user]  # run users_controller + user_helper + user tests
    rake parallel:test['user|product']  # run user and product related tests


Example output
--------------
    2 processes for 210 specs, ~ 105 specs per process
    ... test output ...

    843 examples, 0 failures, 1 pending

    Took 29.925333 seconds

Spec Loggers
===================

Even process runtimes
-----------------

Log test runtime to give each process the same runtime.

Add to your `spec/parallel_spec.opts` (or `spec/spec.opts`) :

    RSpec 1.x:
      --format progress
      --format ParallelSpecs::SpecRuntimeLogger:tmp/parallel_profile.log
    RSpec >= 2.4:
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelSpecs::SpecRuntimeLogger --out tmp/parallel_profile.log

SpecSummaryLogger
--------------------

This logger logs the test output without the different processes overwriting each other.

Add the following to your `spec/parallel_spec.opts` (or `spec/spec.opts`) :

    RSpec 1.x:
      --format progress
      --format ParallelSpecs::SpecSummaryLogger:tmp/spec_summary.log
    RSpec >= 2.2:
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelSpecs::SpecSummaryLogger --out tmp/spec_summary.log

SpecFailuresLogger
-----------------------

This logger produces pasteable command-line snippets for each failed example.

E.g.

    spec /path/to/my_spec.rb -e "should do something"

Add the following to your `spec/parallel_spec.opts` (or `spec/spec.opts`) :

    RSpec 1.x:
      --format progress
      --format ParallelSpecs::SpecFailuresLogger:tmp/failing_specs.log
    RSpec >= 2.4:
      If installed as plugin: -I vendor/plugins/parallel_tests/lib
      --format progress
      --format ParallelSpecs::SpecFailuresLogger --out tmp/failing_specs.log

Setup for non-rails
===================
    sudo gem install parallel_tests
    # go to your project dir
    parallel_test OR parallel_spec OR parallel_cucumber
    # [Optional] use ENV['TEST_ENV_NUMBER'] inside your tests to select separate db/memcache/etc.

[optional] Only run selected files & folders:

    parallel_test test/bar test/baz/xxx_text.rb

Options are:

    -n [PROCESSES]                   How many processes to use, default: available CPUs
    -p, --path [PATH]                run tests inside this path only
        --no-sort                    do not sort files before running them
    -m, --multiply-processes [FLOAT] use given number as a multiplier of processes to run
    -r, --root [PATH]                execute test commands from this path
    -e, --exec [COMMAND]             execute this code parallel and with ENV['TEST_ENV_NUM']
    -o, --test-options '[OPTIONS]'   execute test commands with those options
    -t, --type [TYPE]                which type of tests to run? test, spec or features
        --non-parallel               execute same commands but do not in parallel, needs --exec
    -v, --version                    Show Version
    -h, --help                       Show this.

You can run any kind of code with -e / --execute

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
 - [RSpec] add a `spec/parallel_spec.opts` to use different options, e.g. no --drb (default: `spec/spec.opts`)
 - [RSpec] if something looks fishy try to delete `script/spec`
 - [RSpec] if `script/spec` is missing parallel:spec uses just `spec` (which solves some issues with double-loaded environment.rb)
 - [RSpec] 'script/spec_server' or [spork](http://github.com/timcharper/spork/tree/master) do not work in parallel
 - [RSpec] `./script/generate rspec` if you are running rspec from gems (this plugin uses script/spec which may fail if rspec files are outdated)
 - [RSpec] remove --loadby from you spec/*.opts
 - [Bundler] if you have a `Gemfile` then `bundle exec` will be used to run tests
 - [Capybara setup](https://github.com/grosser/parallel_tests/wiki)
 - [Sphinx setup](https://github.com/grosser/parallel_tests/wiki)
 - [SQL schema format] use :ruby schema format to get faster parallel:prepare`
 - `export PARALLEL_TEST_PROCESSORS=X` in your environment and parallel_tests will use this number of processors by default
 - with zsh this would be `rake "parallel:prepare[3]"`

TODO
====
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

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
Hereby placed under public domain, do what you want, just do not hold me accountable...<br/>
[![Flattr](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=grosser&url=https://github.com/grosser/parallel_tests&title=parallel_tests&language=en_GB&tags=github&category=software)

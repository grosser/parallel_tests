Speedup Test::Unit + RSpec + Cucumber by running parallel on multiple CPUs.

Setup for Rails
===============

    sudo gem install parallel
    script/plugin install git://github.com/grosser/parallel_tests.git

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

Test just a subfolder (e.g. use one integration server per subfolder)
    rake parallel:test[models]
    rake parallel:test[something/else]

    partial paths are OK too...
    rake parallel:test[functional] == rake parallel:test[fun]

Example output
--------------
    2 processes for 210 specs, ~ 105 specs per process
    ... test output ...

    Results:
    877 examples, 0 failures, 11 pending
    843 examples, 0 failures, 1 pending

    Took 29.925333 seconds

Even process runtimes (for specs only atm)
-----------------
Add to your `spec/parallel_spec.opts` (or `spec/spec.opts`) :
    --format ParallelSpecs::SpecRuntimeLogger:tmp/parallel_profile.log
It will log test runtime and partition the test-load accordingly.

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
    -o, --test-options '[OPTIONS]' execute test commands with those options
    -t, --type [TYPE]                which type of tests to run? test, spec or features
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
 - [RSpec] add a `spec/parallel_spec.opts` to use different options, e.g. no --drb (default: `spec/spec.opts`) 
 - [RSpec] if something looks fishy try to delete `script/spec`
 - [RSpec] if `script/spec` is missing parallel:spec uses just `spec` (which solves some issues with double-loaded environment.rb)
 - [RSpec] 'script/spec_server' or [spork](http://github.com/timcharper/spork/tree/master) do not work in parallel
 - [RSpec] `./script/generate rspec` if you are running rspec from gems (this plugin uses script/spec which may fail if rspec files are outdated)
 - [Bundler] if you have a `Gemfile` then `bundle exec` will be used to run tests 
 - with zsh this would be `rake "parallel:prepare[3]"`

TODO
====
 - make jRuby compatible [basics](http://yehudakatz.com/2009/07/01/new-rails-isolation-testing/)
 - make windows compatible

Authors
====
inspired by [pivotal labs](http://pivotallabs.com/users/miked/blog/articles/849-parallelize-your-rspec-suite)  

###Contributors (alphabetical)
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

[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...

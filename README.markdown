Speedup RSpec + Test::Unit + Cucumber by running parallel on multiple CPUs.

Setup
=====

    sudo gem install parallel
    script/plugin install git://github.com/grosser/parallel_specs.git

### 1: Add to `config/database.yml`
    test:
      database: xxx_test<%= ENV['TEST_ENV_NUMBER'] %>

### 2: Create additional database(s)
    script/db_console
    create database xxx_test2;
    ...

### 3: Copy development schema (repeat after migrations)
    rake parallel:prepare

### 4: Run!
    rake parallel:spec          # RSpec
    rake parallel:test          # Test::Unit
    rake parallel:features      # Cucumber

    rake parallel:spec[1] --> force 1 CPU --> 86 seconds
    rake parallel:spec    --> got 2 CPUs? --> 47 seconds
    rake parallel:spec    --> got 4 CPUs? --> 26 seconds
    ...

Test just a subfolder (e.g. use one integration server per subfolder)
    rake parallel:spec[models]
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
Add to your `spec/spec.opts` :
    --format ParallelSpecs::SpecRuntimeLogger:tmp/prallel_profile.log
It will log test runtime and partition the test-load accordingly.

TIPS
====
 - if something looks fishy try to delete `script/spec`
 - if `script/spec` is missing parallel:spec uses just `spec` (which solves some issues with double-loaded environment.rb)
 - 'script/spec_server' or [spork](http://github.com/timcharper/spork/tree/master) do not work in parallel
 - `./script/generate rspec` if you are running rspec from gems (this plugin uses script/spec which may fail if rspec files are outdated)
 - with zsh this would be `rake "parallel:prepare[3]"`

TODO
====
 - disable --drb for parallel running, so it works while e.g. spork is running
 - make spec runtime recording/evaluating work with sub-folders
 - add gem + cli interface `parallel_specs` + `parallel_tests` + `parallel_features` -> non-rails projects
 - build parallel:bootstrap [idea/basics](http://github.com/garnierjm/parallel_specs/commit/dd8005a2639923dc5adc6400551c4dd4de82bf9a)
 - make jRuby compatible [basics](http://yehudakatz.com/2009/07/01/new-rails-isolation-testing/)
 - make windows compatible (does anyone care ?)

Authors
====
inspired by [pivotal labs](http://pivotallabs.com/users/miked/blog/articles/849-parallelize-your-rspec-suite)  

###Contributors (alphabetical)
 - [Charles Finkel](http://charlesfinkel.com/) -- charles.finkel<$at$>gmail.com
 - [Jason Morrison](http://jayunit.net) -- jason.p.morrison<$at$>gmail.com
 - [Joakim Kolsjö](http://www.rubyblocks.se) -- joakim.kolsjo<$at$>gmail.com
 - [Maksim Horbu](http://github.com/mhorbul) -- likonar<$at$>gmail.com
 - [Kpumuk](http://kpumuk.info/) -- kpumuk<$at$>kpumuk.info
 - [Tchandy](http://thiagopradi.net/) -- tchandy<$at$>gmail.com

[Michael Grosser](http://pragmatig.wordpress.com)  
grosser.michael@gmail.com  
Hereby placed under public domain, do what you want, just do not hold me accountable...

### Install

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

Even process runtimes
-----------------

    RSpec 1.x:
      --format progress
      --require parallel_tests/spec/runtime_logger
      --format ParallelTests::Spec::RuntimeLogger:tmp/parallel_profile.log

SpecSummaryLogger
--------------------

    RSpec 1.x:
      --format progress
      --require parallel_tests/spec/summary_logger
      --format ParallelTests::Spec::SummaryLogger:tmp/spec_summary.log

SpecFailuresLogger
-----------------------

    RSpec 1.x:
      --format progress
      --require parallel_tests/spec/failures_logger
      --format ParallelTests::Spec::FailuresLogger:tmp/failing_specs.log

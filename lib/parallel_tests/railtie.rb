# rake tasks for Rails 3+
module ParallelTests
  class Railtie < ::Rails::Railtie
    rake_tasks do
      require "parallel_tests/tasks"
    end
  end
end

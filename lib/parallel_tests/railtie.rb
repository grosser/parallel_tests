# add rake tasks if we are inside Rails
if defined?(Rails::Railtie)
  class ParallelTests
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load File.expand_path("../../tasks/parallel_tests.rake", __FILE__)
      end
    end
  end
end

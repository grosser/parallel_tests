require 'rails/railtie'

class ParallelTests
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../../tasks/parallel_tests.rake", __FILE__)
    end
  end
end
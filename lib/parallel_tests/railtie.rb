# add rake tasks if we are inside Rails 3
if defined?(Rails::Railtie)
  module ParallelTests
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load File.expand_path("../tasks.rake", __FILE__)
      end
    end
  end
end

require 'parallel_tests/test/runner'

module ParallelTests
  module Cucumber
    class Runner < ParallelTests::Test::Runner
      def self.run_tests(test_files, process_number, options)
        color = ($stdout.tty? ? 'AUTOTEST=1 ; export AUTOTEST ;' : '')#display color when we are in a terminal
        runtime_logging = " --format ParallelTests::Cucumber::RuntimeLogger --out #{runtime_log}"
        cmd = [
          color,
          executable,
          (runtime_logging if File.directory?(File.dirname(runtime_log))),
          cucumber_opts(options[:test_options]),
          *test_files
        ].compact.join(" ")
        execute_command(cmd, process_number, options)
      end

      def self.executable
        if ParallelTests.bundler_enabled?
          "bundle exec cucumber"
        elsif File.file?("script/cucumber")
          "script/cucumber"
        else
          "cucumber"
        end
      end

      def self.runtime_log
        'tmp/parallel_runtime_cucumber.log'
      end

      def self.test_file_name
        "feature"
      end

      def self.test_suffix
        ".feature"
      end

      def self.line_is_result?(line)
        line =~ /^\d+ (steps?|scenarios?)/
      end

      def self.summarize_results(results)
        sort_order = %w[scenario step failed undefined skipped pending passed]

        %w[scenario step].map do |group|
          all_group_results = results.select{|v| v =~ /^\d+ #{group}s?/}
          next if all_group_results.empty?

          sums = sum_up_results(all_group_results)

          group_results = sums.map do |word, number|
            "#{number} #{word}"
          end

          # sort results like cucumber does it
          group_results = group_results.sort do |a, b|
            (sort_order.index{|order_item| a.include?(order_item) } || sort_order.size)  <=> (sort_order.index{|order_item| b.include?(order_item) } || sort_order.size)
          end

          # pluralize group results
          group_results[0] += 's' if sums[group] > 1
          "#{group_results[0]} (#{group_results[1..-1].join(", ")})"

        end.compact.join("\n")
      end

      def self.cucumber_opts(given)
        if given =~ /--profile/ or given =~ /(^|\s)-p /
          given
        else
          [given, profile_from_config].compact.join(" ")
        end
      end

      def self.profile_from_config
        config = 'config/cucumber.yml'
        if File.exists?(config) && File.read(config) =~ /^parallel:/
          "--profile parallel"
        end
      end

      def self.tests_in_groups(tests, num_groups, options={})
        if options[:group_by] == :steps
          Grouper.by_steps(find_tests(tests, options), num_groups)
        else
          super
        end
      end
    end
  end
end

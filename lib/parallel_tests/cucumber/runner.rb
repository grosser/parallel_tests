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

        summarized_results = []

        %w[scenario step].each do |group|

          counts = results.select{|v| v =~ /^\d+ #{group}s?/}.join(' ').gsub(/s\b/,'').scan(/(\d+) (\w+)/)
          sums = counts.inject(Hash.new(0)) do |sum, (number, word)|
            sum[word] += number.to_i
            sum
          end

          group_results = sums.map do |word, number|
            "#{number} #{word}"
          end

          sort_order = %w[scenario step failed skipped pending passed]
          group_results = group_results.sort do |a, b|
            (sort_order.index{|order_item| a.include?(order_item) } || sort_order.size)  <=> (sort_order.index{|order_item| b.include?(order_item) } || sort_order.size)
          end

          unless group_results.empty?
            group_results[0] += 's' if group_results.first && group_results.first.scan(/\d+/).first.to_i > 1
            summarized_results << "#{group_results[0]} (#{group_results[1..-1].join(", ")})"
          end

        end

        unless summarized_results.empty?
          summarized_results.unshift ">>>>> parallel_tests summary >>>>>".ljust(80, ">") + "\n"
          summarized_results <<      "\n" + ("<" * 80)
        end

        summarized_results.join("\n")
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

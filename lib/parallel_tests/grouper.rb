module ParallelTests
  class Grouper
    class << self
      def by_steps(tests, num_groups, options)
        features_with_steps = build_features_with_steps(tests, options)
        in_even_groups_by_size(features_with_steps, num_groups)
      end

      def by_scenarios(tests, num_groups, options={})
        scenarios = group_by_scenarios(tests, options)
        in_even_groups_by_size(scenarios, num_groups)
      end

      def in_even_groups_by_size(items, num_groups, options= {})
        groups = Array.new(num_groups) { {:items => [], :size => 0} }

        # add all files that should run in a single process to one group
        (options[:single_process] || []).each do |pattern|
          matched, items = items.partition { |item, size| item =~ pattern }
          matched.each { |item, size| add_to_group(groups.first, item, size) }
        end

        groups_to_fill = (options[:isolate] ? groups[1..-1] : groups)
        group_features_by_size(items_to_group(items), groups_to_fill)

        groups.map!{|g| g[:items].sort }
      end

      private

      def largest_first(files)
        files.sort_by{|item, size| size }.reverse
      end

      def smallest_group(groups)
        groups.min_by{|g| g[:size] }
      end

      def add_to_group(group, item, size)
        group[:items] << item
        group[:size] += size
      end

      def build_features_with_steps(tests, options)
        require 'parallel_tests/gherkin/listener'
        listener = ParallelTests::Gherkin::Listener.new
        listener.ignore_tag_pattern = Regexp.compile(options[:ignore_tag_pattern]) if options[:ignore_tag_pattern]
        parser = ::Gherkin::Parser::Parser.new(listener, true, 'root')
        tests.each{|file|
          parser.parse(File.read(file), file, 0)
        }
        listener.collect.sort_by{|_,value| -value }
      end

      def group_by_scenarios(tests, options={})
        require 'parallel_tests/cucumber/scenarios'
        ParallelTests::Cucumber::Scenarios.all(tests, options)
      end

      def group_features_by_size(items, groups_to_fill)
        items.each do |item, size|
          size ||= 1
          smallest = smallest_group(groups_to_fill)
          add_to_group(smallest, item, size)
        end
      end

      def items_to_group(items)
        items.first && items.first.size == 2 ? largest_first(items) : items
      end
    end
  end
end

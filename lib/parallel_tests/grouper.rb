# frozen_string_literal: true
module ParallelTests
  class Grouper
    class << self
      def by_steps(tests, num_groups, options)
        features_with_steps = group_by_features_with_steps(tests, options)
        in_even_groups_by_size(features_with_steps, num_groups)
      end

      def by_scenarios(tests, num_groups, options = {})
        scenarios = group_by_scenarios(tests, options)
        in_even_groups_by_size(scenarios, num_groups)
      end

      def in_even_groups_by_size(items, num_groups, options = {})
        groups = Array.new(num_groups) { { items: [], size: 0 } }

        # add all files that should run in a single process to one group
        single_process_patterns = options[:single_process] || []

        single_items, items = items.partition do |item, _size|
          single_process_patterns.any? { |pattern| item =~ pattern }
        end

        isolate_count = isolate_count(options)

        if isolate_count >= num_groups
          raise 'Number of isolated processes must be less than total the number of processes'
        end

        if options[:specify_groups]
          specify_spec_processes = options[:specify_groups].split('|')
          specified_specs = options[:specify_groups].split(/[,|]/)
          if specify_spec_processes.count > num_groups
            raise 'Number of processes separated by pipe must be less than or equal to the total number of processes'
          end

          specified_items, items = items.partition do |item, _size|
            specified_specs.any? { |pattern| item =~ /#{pattern}/ }
          end

          if (specified_specs - specified_items.map(&:first)).any?
            raise 'Could not find all specs from --specify-spec-processes in main selected files & folders'
          end

          specify_spec_processes.each_with_index do |specify_spec_process, i|
            groups[i] = specify_spec_process.split(',')
          end
          return groups if specify_spec_processes.count == num_groups
          group_features_by_size(items_to_group(items), groups[specify_spec_processes.count..-1])
          # Don't sort all the groups, only sort the ones not specified in specify_groups
          sorted_groups = groups[specify_spec_processes.count..-1].map { |g| g[:items].sort }
          groups[specify_spec_processes.count..-1] = sorted_groups
          return groups
        elsif isolate_count >= 1
          # add all files that should run in a multiple isolated processes to their own groups
          group_features_by_size(items_to_group(single_items), groups[0..(isolate_count - 1)])
          # group the non-isolated by size
          group_features_by_size(items_to_group(items), groups[isolate_count..-1])
        else
          # add all files that should run in a single non-isolated process to first group
          single_items.each { |item, size| add_to_group(groups.first, item, size) }

          # group all by size
          group_features_by_size(items_to_group(items), groups)
        end
        groups.map! { |g| g[:items].sort }
      end

      private

      def isolate_count(options)
        if options[:isolate_count] && options[:isolate_count] > 1
          options[:isolate_count]
        elsif options[:isolate]
          1
        else
          0
        end
      end

      def largest_first(files)
        files.sort_by { |_item, size| size }.reverse
      end

      def smallest_group(groups)
        groups.min_by { |g| g[:size] }
      end

      def add_to_group(group, item, size)
        group[:items] << item
        group[:size] += size
      end

      def group_by_features_with_steps(tests, options)
        require 'parallel_tests/cucumber/features_with_steps'
        ParallelTests::Cucumber::FeaturesWithSteps.all(tests, options)
      end

      def group_by_scenarios(tests, options = {})
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

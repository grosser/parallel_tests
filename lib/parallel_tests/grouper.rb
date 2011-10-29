class ParallelTests
  class Grouper
    def self.in_groups(items, num_groups)
      [].tap do |groups|
        while ! items.empty?
          (0...num_groups).map do |group_number|
            groups[group_number] ||= []
            groups[group_number] << items.shift
          end
        end
      end.map(&:sort)
    end

    def self.in_even_groups_by_size(items_with_sizes, num_groups)
      items_with_size = smallest_first(items_with_sizes)
      groups = Array.new(num_groups){{:items => [], :size => 0}}
      items_with_size.each do |item, size|
        # always add to smallest group
        smallest = groups.sort_by{|g| g[:size] }.first
        smallest[:items] << item
        smallest[:size] += size
      end

      groups.map{|g| g[:items].sort }
    end

    def self.smallest_first(files)
      files.sort_by{|item, size| size }.reverse
    end

    def self.by_directories items, root, directories_to_group_by
      directory_groups = items.group_by do | item |
        group_name = 'non_matching'
        directories_to_group_by.each do | dir |
          group_name = dir if item.start_with?("#{root}/#{dir}")
        end
        group_name
      end
      directory_groups.values
    end
  end
end

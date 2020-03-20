require 'parallel_tests'

module ParallelTests
  class OutputRewriter
    CURSOR_UP_CHARACTER = "\033[A"

    $output_rewrite_mutex = Mutex.new
    $output_by_group = []

    def self.rewrite(new_group_output:, group_index:)
      $output_rewrite_mutex.synchronize do
        number_of_lines_to_overwrite = $output_by_group.sum { |s| s.to_s.count("\n") }

        $output_by_group[group_index] = new_group_output

        result = CURSOR_UP_CHARACTER * number_of_lines_to_overwrite
        $output_by_group.each { |group_output| result += group_output.to_s }

        $stdout.print result
        $stdout.flush
      end
    end
  end
end

# frozen_string_literal: true

require 'rspec/core/formatters/base_text_formatter'
require 'parallel_tests/rspec/runner'

class ParallelTests::RSpec::VerboseFormatter < RSpec::Core::Formatters::BaseTextFormatter
  RSpec::Core::Formatters.register(
    self,
    :example_group_started,
    :example_group_finished,
    :example_started,
    :example_passed,
    :example_pending,
    :example_failed
  )

  def initialize(output)
    super
    @line = []
  end

  def example_group_started(notification)
    @line.push(notification.group.description)
  end

  def example_group_finished(_notification)
    @line.pop
  end

  def example_started(notification)
    @line.push(notification.example.description)
    output_formatted_line('STARTED', :yellow)
  end

  def example_passed(_passed)
    output_formatted_line('PASSED', :success)
    @line.pop
  end

  def example_pending(_pending)
    output_formatted_line('PENDING', :pending)
    @line.pop
  end

  def example_failed(_failure)
    output_formatted_line('FAILED', :failure)
    @line.pop
  end

  private

  def output_formatted_line(status, console_code)
    prefix = ["[#{Process.pid}]"]
    if ENV.include?('TEST_ENV_NUMBER')
      test_env_number = ENV['TEST_ENV_NUMBER'] == '' ? 1 : Integer(ENV['TEST_ENV_NUMBER'])
      prefix << "[#{test_env_number}]"
    end
    prefix << RSpec::Core::Formatters::ConsoleCodes.wrap("[#{status}]", console_code)

    output.puts [*prefix, *@line].join(' ')
  end
end

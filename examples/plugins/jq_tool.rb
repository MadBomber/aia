# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'
require 'ruby_llm/tool'

class JqTool < RubyLLM::Tool
  def self.name = 'jq_tool'

  description <<~DESC
    Run jq safely for JSON querying and transformation.
    Supports passing a jq filter, optional input text or input file, and common
    read-oriented jq flags such as raw/slurp/null-input/compact-output/sort-keys.
    This wrapper is intended for analysis and formatting tasks, not arbitrary
    shell scripting.
  DESC

  parameter :filter, type: :string, required: true,
            description: 'The jq filter/program to execute, such as .foo, .items[], map(.name), or keys.'
  parameter :input_text, type: :string,
            description: 'Optional JSON text to pipe into jq via stdin.'
  parameter :input_file, type: :string,
            description: 'Optional path to a JSON input file. Use this instead of input_text for file-based input.'
  parameter :raw_input, type: :boolean,
            description: 'Pass --raw-input (-R): read input as raw text instead of JSON.'
  parameter :slurp, type: :boolean,
            description: 'Pass --slurp (-s): read all inputs into an array before filtering.'
  parameter :null_input, type: :boolean,
            description: 'Pass --null-input (-n): do not read input, run the filter once with null input.'
  parameter :compact_output, type: :boolean,
            description: 'Pass --compact-output (-c): produce compact JSON output.'
  parameter :raw_output, type: :boolean,
            description: 'Pass --raw-output (-r): write strings without JSON quoting.'
  parameter :sort_keys, type: :boolean,
            description: 'Pass --sort-keys (-S): sort keys of output objects.'
  parameter :monochrome_output, type: :boolean,
            description: 'Pass --monochrome-output (-M): disable colorized output.'
  parameter :ascii_output, type: :boolean,
            description: 'Pass --ascii-output (-a): force non-ASCII characters to be escaped.'
  parameter :exit_status, type: :boolean,
            description: 'Pass --exit-status (-e): use jq exit code semantics based on result truthiness.'
  parameter :arg_name, type: :string,
            description: 'Optional variable name for a single --arg binding.'
  parameter :arg_value, type: :string,
            description: 'Optional string value for a single --arg binding.'
  parameter :json_arg_name, type: :string,
            description: 'Optional variable name for a single --argjson binding.'
  parameter :json_arg_value, type: :string,
            description: 'Optional JSON text for a single --argjson binding.'
  parameter :max_output_chars, type: :integer,
            description: 'Maximum number of output characters to return. Defaults to 12000.'

  def available?
    system('command -v jq >/dev/null 2>&1')
  end

  def execute(filter:, input_text: nil, input_file: nil, raw_input: nil, slurp: nil,
              null_input: nil, compact_output: nil, raw_output: nil, sort_keys: nil,
              monochrome_output: true, ascii_output: nil, exit_status: nil,
              arg_name: nil, arg_value: nil, json_arg_name: nil, json_arg_value: nil,
              max_output_chars: 12_000)
    return error('filter is required') if filter.to_s.strip.empty?
    return error('use either input_text or input_file, not both') if present?(input_text) && present?(input_file)

    cmd = ['jq'] + build_flag_args(raw_input: raw_input, slurp: slurp, null_input: null_input,
                                   compact_output: compact_output, raw_output: raw_output,
                                   sort_keys: sort_keys, monochrome_output: monochrome_output,
                                   ascii_output: ascii_output, exit_status: exit_status)

    err = apply_arg_binding(cmd, arg_name, arg_value)
    return err if err

    err = apply_json_arg_binding(cmd, json_arg_name, json_arg_value)
    return err if err

    cmd << filter.to_s

    stdin_data, err = resolve_jq_input(cmd, input_file, input_text, null_input)
    return err if err

    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin_data)

    {
      success: status.success?,
      command: cmd.shelljoin,
      stdout: truncate(stdout, max_output_chars),
      stderr: truncate(stderr, max_output_chars),
      exit_status: status.exitstatus,
      truncated_stdout: stdout.to_s.length > normalize_max_output(max_output_chars),
      truncated_stderr: stderr.to_s.length > normalize_max_output(max_output_chars)
    }
  rescue StandardError => e
    error(e.message)
  end

  private

  def build_flag_args(raw_input:, slurp:, null_input:, compact_output:,
                      raw_output:, sort_keys:, monochrome_output:,
                      ascii_output:, exit_status:)
    flags = []
    flags << '--raw-input'      if raw_input
    flags << '--slurp'          if slurp
    flags << '--null-input'     if null_input
    flags << '--compact-output' if compact_output
    flags << '--raw-output'     if raw_output
    flags << '--sort-keys'      if sort_keys
    flags << '--monochrome-output' if monochrome_output
    flags << '--ascii-output'   if ascii_output
    flags << '--exit-status'    if exit_status
    flags
  end

  def apply_arg_binding(cmd, arg_name, arg_value)
    return unless present?(arg_name)
    return error('arg_value is required when arg_name is provided') unless present?(arg_value)

    cmd.push('--arg', arg_name.to_s, arg_value.to_s)
    nil
  end

  def apply_json_arg_binding(cmd, json_arg_name, json_arg_value)
    return unless present?(json_arg_name)
    return error('json_arg_value is required when json_arg_name is provided') unless present?(json_arg_value)

    validated = validate_json_text(json_arg_value.to_s)
    return validated if validated.is_a?(Hash)

    cmd.push('--argjson', json_arg_name.to_s, json_arg_value.to_s)
    nil
  end

  def resolve_jq_input(cmd, input_file, input_text, null_input)
    if present?(input_file)
      expanded = File.expand_path(input_file.to_s, Dir.pwd)
      return [nil, error("input file not found: #{input_file}")] unless File.file?(expanded)

      cmd << expanded
      [nil, nil]
    elsif present?(input_text)
      [input_text.to_s, nil]
    elsif !null_input
      [nil, error('provide input_text, input_file, or set null_input: true')]
    else
      [nil, nil]
    end
  end

  def present?(value)
    !value.nil? && !value.to_s.strip.empty?
  end

  def error(message)
    {
      success: false,
      error: message
    }
  end

  def validate_json_text(text)
    JSON.parse(text)
    true
  rescue JSON::ParserError => e
    error("invalid json_arg_value: #{e.message}")
  end

  def normalize_max_output(value)
    limit = value.to_i
    return 12_000 if limit <= 0

    [limit, 100_000].min
  end

  def truncate(text, max_output_chars)
    value = text.to_s
    limit = normalize_max_output(max_output_chars)
    return value if value.length <= limit

    value[0, limit] + "\n... [truncated]"
  end
end

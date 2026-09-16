# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'shellwords'
require 'ruby_llm/tool'

class CliHelpAnalyzerTool < RubyLLM::Tool
  def self.name = 'cli_help_analyzer'

  description <<~DESC
    Analyze a CLI utility by reading its --help output and infer a draft tool schema.
    This is useful for generating future RubyLLM tool wrappers around existing commands.
    It classifies the command, extracts option candidates, identifies positional arguments,
    and proposes tool/class names.
  DESC

  parameter :command, type: :string, required: true,
            description: 'CLI command to inspect, such as ag, rg, jq, git, or find.'
  parameter :subcommand, type: :string,
            description: 'Optional subcommand to inspect, such as log for git log.'
  parameter :help_flag, type: :string,
            description: 'Optional help flag override. Defaults to --help.'
  parameter :max_lines, type: :integer,
            description: 'Maximum number of help lines to analyze. Defaults to 300.'
  parameter :generate_plugin, type: :boolean,
            description: 'When true, also generate a draft RubyLLM tool plugin file in the plugins directory.'
  parameter :plugins_dir, type: :string,
            description: 'Optional plugins directory override for generated plugin output.'

  OPTION_LINE_REGEX = /^\s{0,6}(?:-\w(?:,\s*)?)?(?:--\w[\w-]*)(?:[=\s]+[A-Z][A-Z0-9_-]*)?/i

  def available?
    true
  end

  def execute(command:, subcommand: nil, help_flag: '--help', max_lines: 300, generate_plugin: false, plugins_dir: nil)
    cmd = [command.to_s]
    cmd << subcommand.to_s unless subcommand.to_s.strip.empty?
    cmd << help_flag.to_s

    stdout, stderr, status = Open3.capture3(*cmd)
    output = [stdout, stderr].reject(&:empty?).join("\n")
    return { success: false, error: "No help output returned", command: cmd.shelljoin } if output.strip.empty?

    lines          = output.lines.map(&:rstrip).first(normalize_limit(max_lines))
    parsed_options = extract_options(lines)
    positionals    = infer_positionals(lines)
    category       = classify_command(command.to_s, subcommand.to_s, lines)
    tool_name      = suggest_tool_name(command.to_s, subcommand.to_s, category)
    class_name     = suggest_class_name(tool_name)

    result = build_analysis_result(command, subcommand, cmd, status, output, lines,
                                   category, tool_name, class_name, parsed_options, positionals)
    maybe_generate_plugin!(result, command, subcommand, tool_name, class_name, parsed_options, positionals, plugins_dir) if generate_plugin
    result
  rescue Errno::ENOENT
    { success: false, error: "command not found: #{command}" }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def normalize_limit(value)
    limit = value.to_i
    return 300 if limit <= 0

    [limit, 1000].min
  end

  def blank_to_nil(value)
    v = value.to_s.strip
    v.empty? ? nil : v
  end

  def extract_options(lines)
    raw = lines.filter_map do |line|
      next unless line.match?(OPTION_LINE_REGEX)

      parse_option_line(line)
    end
    raw.uniq { |opt| [opt[:long], opt[:short], opt[:value_name]] }
  end

  def parse_option_line(line)
    short = line[/-(\w)\b/, 1]
    long = line[/--([\w-]+)\b/, 1]
    value_name = line[/--[\w-]+(?:[=\s]+)([A-Z][A-Z0-9_-]*)/, 1] || line[/-\w(?:[=\s]+)([A-Z][A-Z0-9_-]*)/, 1]

    {
      short: short && "-#{short}",
      long: long && "--#{long}",
      takes_value: !value_name.nil?,
      value_name: value_name,
      inferred_type: infer_value_type(value_name, line),
      description: infer_description(line)
    }
  end

  def infer_value_type(value_name, line)
    token = [value_name, line].compact.join(' ').downcase
    return 'boolean' if value_name.nil?
    return 'integer' if token.match?(/\b(num|count|lines|depth|jobs|threads|port|timeout|limit|max|min)\b/)
    return 'path' if token.match?(/\b(file|path|dir|directory|output|input)\b/)
    'string'
  end

  def infer_description(line)
    parts = line.split(/\s{2,}/, 2)
    parts[1].to_s.strip
  end

  def infer_positionals(lines)
    usage = lines.find { |line| line.strip.downcase.start_with?('usage:') }
    return [] unless usage

    rhs = usage.sub(/\A\s*usage:\s*/i, '')
    tokens = rhs.split.reject { |t| t.start_with?('-') }
    tokens = tokens.drop(1)

    raw = tokens.filter_map do |tok|
      next if tok.start_with?('[') && tok.include?('-')
      cleaned = tok.gsub(/[\[\]<>]/, '')
      next if cleaned.empty?
      next if cleaned.include?('|')
      next unless cleaned.match?(/^[a-zA-Z][\w-]*$/)

      {
        name: cleaned.downcase.gsub('-', '_'),
        required: !tok.start_with?('['),
        raw: tok
      }
    end
    raw.uniq { |p| p[:name] }
  end

  def classify_command(command, subcommand, lines)
    full = [command, subcommand, lines.join("\n")].join(' ').downcase
    return 'read_only_search' if full.match?(/\b(search|find matches|pattern|grep|silver searcher|ripgrep)\b/)
    return 'read_only_inspection' if full.match?(/\b(list|show|print|display|status|info|describe|version)\b/)
    return 'network_client' if full.match?(/\b(http|url|request|download|upload|api)\b/)
    return 'filesystem_mutation' if full.match?(/\b(delete|remove|move|rename|write|overwrite|create)\b/)
    return 'package_or_system_management' if full.match?(/\b(install|uninstall|upgrade|deploy|service|system)\b/)
    'general_cli'
  end

  def safe_category?(category)
    %w[read_only_search read_only_inspection].include?(category)
  end

  def suggest_tool_name(command, subcommand, category)
    parts = [command, subcommand].compact.map { |s| s.strip.downcase.gsub(/[^a-z0-9]+/, '_') }.reject(&:empty?)
    base = parts.join('_')
    return 'search_files' if category == 'read_only_search' && base == 'ag'
    return "#{base}_tool" unless base.empty?
    'generated_cli_tool'
  end

  def suggest_class_name(tool_name)
    tool_name.split('_').map(&:capitalize).join + 'Tool'
  end

  def resolve_plugins_dir(plugins_dir)
    dir = plugins_dir.to_s.strip
    return File.expand_path(dir, Dir.pwd) unless dir.empty?

    default_dir = File.expand_path('plugins', Dir.pwd)
    return default_dir if Dir.exist?(default_dir)

    default_dir
  end

  def write_generated_plugin(command:, subcommand:, tool_name:, class_name:, options:, positionals:, plugins_dir:)
    FileUtils.mkdir_p(plugins_dir)

    file_path = File.join(plugins_dir, "#{tool_name}.rb")
    source = build_plugin_source(
      command: command,
      subcommand: subcommand,
      tool_name: tool_name,
      class_name: class_name,
      options: options,
      positionals: positionals
    )
    File.write(file_path, source)
    file_path
  end

  def build_plugin_source(command:, subcommand:, tool_name:, class_name:, options:, positionals:)
    command_parts = [command, blank_to_nil(subcommand)].compact
    description   = "Generated wrapper for #{command_parts.join(' ')} based on CLI help analysis."
    params_source = build_params_lines(positionals, options)
    execute_lines = build_execute_lines(command_parts, positionals, options)
    signature     = build_method_signature(positionals, options)

    <<~RUBY
      # frozen_string_literal: true

      require 'open3'
      require 'shellwords'
      require 'ruby_llm/tool'

      class #{class_name} < RubyLLM::Tool
        def self.name = #{tool_name.inspect}

        description #{description.inspect}

      #{params_source.join("\n")}

        def execute(#{signature})
      #{execute_lines.join("\n")}
        rescue StandardError => e
          {
            success: false,
            error: e.message
          }
        end
      end
    RUBY
  end

  def build_params_lines(positionals, options)
    lines = []
    positionals.each do |pos|
      req = pos[:required] ? ', required: true' : ''
      lines << "  param :#{pos[:name]}, type: :string#{req},"
      lines << "        desc: 'Positional argument from usage: #{pos[:raw]}'"
    end
    options.each do |opt|
      next unless opt[:long]
      name = opt[:long].delete_prefix('--').tr('-', '_')
      lines << "  param :#{name}, type: :#{ruby_param_type(opt[:inferred_type])},"
      lines << "        desc: #{opt[:description].inspect}"
    end
    lines
  end

  def build_execute_lines(command_parts, positionals, options)
    lines = ['    cmd = []']
    command_parts.each { |part| lines << "    cmd << #{part.inspect}" }
    positionals.each do |pos|
      lines << "    cmd << #{pos[:name]}.to_s unless #{pos[:name]}.nil? || #{pos[:name]}.to_s.strip.empty?"
    end
    options.each do |opt|
      next unless opt[:long]
      name = opt[:long].delete_prefix('--').tr('-', '_')
      flag = opt[:long]
      lines << if opt[:takes_value]
                 "    cmd += [#{flag.inspect}, #{name}.to_s] unless #{name}.nil? || #{name}.to_s.strip.empty?"
               else
                 "    cmd << #{flag.inspect} if #{name}"
               end
    end
    lines + ['    stdout, stderr, status = Open3.capture3(*cmd)', '    {',
             '      success: status.success?,', '      command: cmd.shelljoin,',
             '      stdout: stdout,', '      stderr: stderr,',
             '      exit_status: status.exitstatus', '    }']
  end

  def build_method_signature(positionals, options)
    parts  = positionals.map { |pos| "#{pos[:name]}: nil" }
    parts += options.filter_map do |opt|
      next unless opt[:long]
      "#{opt[:long].delete_prefix('--').tr('-', '_')}: nil"
    end
    parts.join(', ')
  end

  def build_analysis_result(command, subcommand, cmd, status, output, lines,
                            category, tool_name, class_name, parsed_options, positionals)
    {
      success: status.success? || !output.strip.empty?,
      command: command,
      subcommand: blank_to_nil(subcommand),
      invoked_as: cmd.shelljoin,
      category: category,
      safe_by_default: safe_category?(category),
      suggested_tool_name: tool_name,
      suggested_class_name: class_name,
      positional_arguments: positionals,
      options: parsed_options,
      analyzed_line_count: lines.size,
      help_excerpt: lines.first(80)
    }
  end

  def maybe_generate_plugin!(result, command, subcommand, tool_name, class_name, options, positionals, plugins_dir)
    output_dir = resolve_plugins_dir(plugins_dir)
    file_path = write_generated_plugin(
      command: command, subcommand: subcommand, tool_name: tool_name,
      class_name: class_name, options: options, positionals: positionals,
      plugins_dir: output_dir
    )
    result[:generated_plugin] = file_path
  end

  def ruby_param_type(inferred_type)
    case inferred_type
    when 'integer' then 'integer'
    when 'boolean' then 'boolean'
    else 'string'
    end
  end
end

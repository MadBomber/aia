# lib/aia/directives.rb

require 'hashie'

=begin
  AIA.config.directives is an Array of Arrays.  An
  entry looks like this:
    [directive, parameters]
  where both are String objects
=end


class AIA::Directives
  def execute_my_directives
    return if AIA.config.directives.nil? || AIA.config.directives.empty?
    
    result    = ""
    not_mine  = []

    AIA.config.directives.each do |entry|
      directive   = entry[0].to_sym
      parameters  = entry[1]

      if respond_to? directive
        output  = send(directive, parameters)
        result << "#{output}\n" unless output.nil?
      else
        not_mine << entry
      end
    end

    AIA.config.directives = not_mine

    result.empty? ? nil : result
  end


  def box(what)
    f   = what[0]
    bar = "#{f}"*what.size
    puts "#{bar}\n#{what}\n#{bar}"
  end


  # Allows a prompt to change its configuration environment
  def config(what)
    parts = what.split(' ')
    item  = parts.shift
    parts.shift if %w[:= =].include? parts[0]

    if '<<' == parts[0]
      parts.shift
      value = parts.join
      if AIA.config(item).is_a?(Array)
        AIA.config[item] << value
      else
        AIA.config[item] = [ value ]
      end
    else
      value = parts.join
      if item.end_with?('?')
        AIA.config[item] = %w[1 y yea yes t true].include?(value.downcase)
      elsif item.end_with?('_file')
        if "STDOUT" == value.upcase
          AIA.config[item] = STDOUT
        elsif "STDERR" == value.upcase
          AIA.config[item] = STDERR
        else
          AIA.config[item] = value.start_with?('/') ? 
            Pathname.new(value) :
            Pathname.pwd + value
        end
      elsif %w[next pipeline].include? item.downcase
        pipeline(value)
      else
        AIA.config[item] = value
      end
    end

    nil
  end


  # TODO: we need a way to submit CLI arguments into
  #       the next prompt(s) from the main prompt.
  #       currently the config for subsequent prompts
  #       is expected to be set within those prompts.
  #       Maybe something like:
  #         //next prompt_id CLI args
  #       This would mean that the pipeline would be:
  #         //pipeline id1 cli args, id2 cli args, id3 cli args
  #
  
  # TODO: Change AIA.config.pipline Array to be an Array of arrays
  #       where each entry is:
  #         [prompt_id, cli_args]
  #       This means that:
  #         entry = AIA.config.pipeline.shift
  #         entry.is_A?(Sring) ? 'old format' : 'new format'
  #

  # //next id
  # //pipeline id1,id2, id3   ,   id4
  def pipeline(what)
    return if what.empty?
    AIA.config.pipeline << what.split(',').map(&:strip)
    AIA.config.pipeline.flatten!
  end
  alias_method :next, :pipeline

  # when path_to_file is relative it will be
  # relative to the PWD.
  #
  # TODO: Consider an AIA_INCLUDE_DIR --include_dir
  # option to be used for all relative include paths
  #
  def include(path_to_file)
    path = Pathname.new path_to_file
    if path.exist? && path.readable?
      content = path.readlines.reject do |a_line|
        a_line.strip.start_with?(AIA::Prompt::COMMENT_SIGNAL) ||
        a_line.strip.start_with?(AIA::Prompt::DIRECTIVE_SIGNAL)
      end.join("\n")
    else
      abort "ERROR: could not include #{path_to_file}"
    end

    content
  end


  def shell(command)
    `#{command}`
  end


  def ruby(code)
    output = eval(code)

    output.is_a?(String) ? output : nil
  end
end

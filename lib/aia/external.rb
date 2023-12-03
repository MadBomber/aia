# lib/aia/external.rb

# FIXME:  This concept of having a class for each external
#         tool used to define its options may go away
#         with the introduction of the Config class
#         and the TOML config file.

module AIA::External
  TOOLS = {

    'mods'  => [  'AI on the command-line',
                  'https://github.com/charmbracelet/mods'],
    
  }


  HELP = <<~EOS
    External Tools Used
    -------------------

    To install the external CLI programs used by aia:
      brew install #{TOOLS.keys.join(' ')}

    #{TOOLS.to_a.map{|t| t.join("\n  ") }.join("\n\n")}

    A text editor whose executable is setup in the 
    system environment variable 'EDITOR' like this:

    export EDITOR="#{ENV['EDITOR']}"

  EOS


  # Setup the AI CLI program with necessary variables
  def setup_external_programs
    verify_external_tools

    ai_default_opts = "-m #{MODS_MODEL} --no-limit "
    ai_default_opts += "-f " if markdown?
    @ai_options     = ai_default_opts.dup


    @ai_options     += @extra_options.join(' ') 

    @ai_command     = "#{AI_CLI_PROGRAM} #{@ai_options} "
  end


  # Check if the external tools are present on the system
  def verify_external_tools
    missing_tools = []

    TOOLS.each do |tool, url|
      path = `which #{tool}`.chomp
      if path.empty? || !File.executable?(path)
        missing_tools << { name: tool, url: url }
      end
    end

    if missing_tools.any?
      puts format_missing_tools_response(missing_tools)
    end
  end


  def format_missing_tools_response(missing_tools)
    response = <<~EOS

      WARNING:  #{MY_NAME} makes use of a few external CLI tools.
                #{MY_NAME} may not respond as designed without these.
                
      The following tools are missing on your system:

    EOS

    missing_tools.each do |tool|
      response << "  #{tool[:name]}: install from #{tool[:url]}\n"
    end

    response
  end


  # Build the command to interact with the AI CLI program
  def build_command
    command = @ai_command + %Q["#{@prompt.to_s}"]

    @arguments.each do |input_file|
      file_path = Pathname.new(input_file)
      abort("File does not exist: #{input_file}") unless file_path.exist?
      command += " < #{input_file}"
    end

    command
  end


  # Execute the command and log the results
  def send_prompt_to_external_command
    command = build_command

    puts command if verbose?
    @result = `#{command}`

    if output.nil?
      puts @result
    else
      output.write @result
    end

    @result
  end
end

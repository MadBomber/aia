# lib/aia/main.rb

module AIA
end

# This module defines constants that may
# be used by other modules.  It should come first.
require_relative 'configuration'

# The order of the following is not important
require_relative 'cli'
require_relative 'external_commands'
require_relative 'prompt_processing'
require_relative 'logging'


class AIA::RememberTheMain
  include AIA::Configuration
  include AIA::Cli
  # include AIA::ExternalCommands
  # include AIA::PromptProcessing
  # include AIA::Logging


  def initialize(args= ARGV)
    setup_defaults
    setup_options(args)
    setup_external_programs
  end


  # Setup the AI CLI program with necessary variables
  def setup_external_programs

    ai_default_opts = "-m #{MODS_MODEL} --no-limit "
    ai_default_opts += "-f " if markdown?
    @ai_options     = ai_default_opts.dup


    @ai_options     += @extra_options.join(' ') 

    @ai_command     = "#{AI_CLI_PROGRAM} #{@ai_options} "
  end





  def call
    show_usage    if help?
    show_version  if version?

    prompt_id = get_prompt_id

    search_for_a_matching_prompt(prompt_id) unless existing_prompt?(prompt_id)
    process_prompt
    execute_and_log_command(build_command)
  end


  # Fetch the first argument which should be the prompt id
  def get_prompt_id
    prompt_id = @arguments.shift

    # TODO: or maybe go to a search and select process

    abort("Please provide a prompt id") unless prompt_id
    prompt_id
  end


  # Check if a prompt with the given id already exists
  def existing_prompt?(prompt_id)
    @prompt = PromptManager::Prompt.get(id: prompt_id)
    true
  rescue ArgumentError
    false
  end


  # Process the prompt's associated keywords and parameters
  def process_prompt
    unless @prompt.keywords.empty?
      replace_keywords
      @prompt.build
      @prompt.save
    end
  end


  def replace_keywords
    print "\nQuit #{MY_NAME} with a CNTL-D or a CNTL-C\n\n"
    
    defaults = @prompt.parameters

    @prompt.keywords.each do |kw|
      defaults[kw] = keyword_value(kw, defaults[kw])
    end

    @prompt.parameters = defaults
  end


  # query the user for a value to the keyword allow the
  # reuse of the previous value shown as the default
  def keyword_value(kw, default)
    label = "Default: "
    puts "Parameter #{kw} ..."
    default_wrapped = default.wrap(indent: label.size)
    default_wrapped[0..label.size] = label
    puts default_wrapped

    begin
      a_string = Readline.readline("\n-=> ", false)
    rescue Interrupt
      a_string = nil
    end

    if a_string.nil?
      puts "okay. Come back soon."
      exit
    end

    puts
    a_string.empty? ? default : a_string
  end


  # Search for a prompt with a matching id or keyword
  def search_for_a_matching_prompt(prompt_id)
    # TODO: using the rgfzf version of the search_proc should only
    #       return a single prompt_id
    found_prompts = PromptManager::Prompt.search(prompt_id)
    prompt_id     = found_prompts.size == 1 ? found_prompts.first : handle_multiple_prompts(found_prompts, prompt_id)
    @prompt       = PromptManager::Prompt.get(id: prompt_id)
  end


  def handle_multiple_prompts(found_these, while_looking_for_this)
    raise ArgumentError, "Argument is not an Array" unless found_these.is_a?(Array)
    
    # TODO: Make this a class constant for defaults; make the header content
    #       a parameter so it can be varied.
    fzf_options       = [
      "--tabstop=2",  # 2 soaces for a tab
      "--header='Prompt IDs which contain: #{while_looking_for_this}\nPress ESC to cancel.'",
      "--header-first",
      "--prompt='Search term: '",
      '--delimiter :',
      "--preview 'cat $PROMPTS_DIR/{1}.txt'",
      "--preview-window=down:50%:wrap"
    ].join(' ') 


    # Create a temporary file to hold the list of strings
    temp_file = Tempfile.new('fzf-input')

    begin
      # Write all strings to the temp file
      temp_file.puts(found_these)
      temp_file.close

      # Execute fzf command-line utility to allow selection
      selected = `cat #{temp_file.path} | fzf #{fzf_options}`.strip

      # Check if fzf actually returned a string; if not, return nil
      result = selected.empty? ? nil : selected
    ensure
      # Ensure that the tempfile is closed and unlinked
      temp_file.unlink
    end

    exit unless result

    result
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
  def execute_and_log_command(command)
    puts command if verbose?
    result = `#{command}`
    output.write result

    write_to_log(result) unless log.nil?
  end


  def write_to_log(answer)
    f = File.open(log, "ab")

    f.write <<~EOS
      =======================================
      == #{Time.now}
      == #{@prompt.path}

      PROMPT:
      #{@prompt}

      RESULT:
      #{answer}

    EOS
  end
end


# TODO: gotta do some here after moving day
# Create an instance of the RememberTheMain class and run the program
AIA::RememberTheMain.new.call if $PROGRAM_NAME == __FILE__


__END__


# TODO: Consider using this history process to preload the default
#       so that an up arrow will bring the previous answer into
#       the read buffer for line editing.
#       Instead of usin the .history file just push the default
#       value from the JSON file.

while input = Readline.readline('> ', true)
  # Skip empty entries and duplicates
  if input.empty? || Readline::HISTORY.to_a[-2] == input
    Readline::HISTORY.pop
  end
  break if input == 'exit'

  # Do something with the input
  puts "You entered: #{input}"

  # Save the history in case you want to preserve it for the next sessions
  File.open('.history', 'a') { |f| f.puts(input) }
end

# Load history from file at the beginning of the program
if File.exist?('.history')
  File.readlines('.history').each do |line|
    Readline::HISTORY.push(line.chomp)
  end
end


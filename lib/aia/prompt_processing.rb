# lib/aia/prompt_processing.rb

module AIA::PromptProcessing

  # Fetch the first argument which should be the prompt id
  def get_prompt
    prompt_id = @arguments.shift

    # TODO: or maybe go to a generic search and select process

    abort("Please provide a prompt id") unless prompt_id

    search_for_a_matching_prompt(prompt_id) unless existing_prompt?(prompt_id)
    edit_prompt if edit?
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

    if found_prompts.empty?
      if edit?
        create_prompt(prompt_id)
        edit_prompt
      else
        abort <<~EOS
          
          No prompts where found for: #{prompt_id}
          To create a prompt with this ID use the --edit option
          like this:
            #{MY_NAME} #{prompt_id} --edit

        EOS
      end
    else    
      prompt_id     = 1 == found_prompts.size ? found_prompts.first : handle_multiple_prompts(found_prompts, prompt_id)
      @prompt       = PromptManager::Prompt.get(id: prompt_id)
    end
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


  def create_prompt(prompt_id)
    @prompt = PromptManager::Prompt.create(id: prompt_id)
    # TODO: consider a configurable prompt template
    #       ERB ???
  end


  def edit_prompt
    `#{EDITOR} #{@prompt.path}`
    @options[:edit?][0] = false
    @prompt = PromptManager::Prompt.get(id: @prompt.id)
  end

end

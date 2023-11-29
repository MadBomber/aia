# lib/aia/prompt_processing.rb

module AIA::PromptProcessing
  KW_HISTORY_MAX = 5

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
  
    # FIXME:  Kludge until prompt_manager is changed
    #         prompt_manager v0.3.0 now supports this feature.
    #         keeping the kludge in for legacy JSON files
    #         files which have not yet been reformatted.
    @prompt.keywords.each do |kw|
      if @prompt.parameters[kw].nil? || @prompt.parameters[kw].empty?
        @prompt.parameters[kw] = []
      else
        @prompt.parameters[kw] = Array(@prompt.parameters[kw])
      end
    end

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
    puts
    puts "ID: #{@prompt.id}"
    
    show_prompt_without_comments

    puts "\nPress up/down arrow to scroll through history."
    puts "Type new input or edit the current input."
    puts  "Quit #{MY_NAME} with a CNTL-D or a CNTL-C"
    puts
    @prompt.keywords.each do |kw|
      value = keyword_value(kw, @prompt.parameters[kw])
      
      unless value.nil? || value.strip.empty?
        value_inx = @prompt.parameters[kw].index(value)
        
        if value_inx
          @prompt.parameters[kw].delete_at(value_inx)
        end

        # The most recent value for this kw will always be
        # in the last position
        @prompt.parameters[kw] << value
        @prompt.parameters[kw].shift if @prompt.parameters[kw].size > KW_HISTORY_MAX
      end
    end
  end


  # query the user for a value to the keyword allow the
  # reuse of the previous value shown as the default
  def keyword_value(kw, history_array)

    Readline::HISTORY.clear
    Array(history_array).each { |entry| Readline::HISTORY.push(entry) unless entry.nil? || entry.empty? }

    puts "Parameter #{kw} ..."

    begin
      a_string = Readline.readline("\n-=> ", true)
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


  def show_prompt_without_comments
    puts remove_comments.wrap(indent: 4)
  end


  def remove_comments
    lines           = @prompt.text
                        .split("\n")
                        .reject{|a_line| a_line.strip.start_with?('#')}

    # Remove empty lines at the start of the prompt
    #
    lines = lines.drop_while(&:empty?)

    # Drop all the lines at __END__ and after
    #
    logical_end_inx = lines.index("__END__")

    if logical_end_inx
      lines[0...logical_end_inx] # NOTE: ... means to not include last index
    else
      lines
    end.join("\n") 
  end
end


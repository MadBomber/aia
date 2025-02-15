# lib/aia/prompt.rb

require 'reline'

require_relative 'dynamic_content'
require_relative 'prompt_manager/storage'
require_relative 'prompt_manager/storage/file_system_adapter'
require_relative 'user_query'

module AIA
  class Prompt
    include AIA::DynamicContent
    include AIA::UserQuery

    KW_HISTORY_MAX    = 5
    COMMENT_SIGNAL    = '#'
    DIRECTIVE_SIGNAL  = "//"

    attr_reader :prompt

    # setting build: false supports unit testing.
    def initialize(build: true)
      setup_prompt_manager
      
      if AIA.config&.role.nil? || AIA.config.role.empty?
        @role = nil
      else
        @role = (AIA.config.roles_dir + "#{AIA.config.role}.txt").read
      end

      get_prompt
      
      @prompt_text_before_role = @prompt&.text&.dup

      if @role && @prompt && !@prompt.is_a?(Prompt::Fake)
        @prompt.text.prepend @role
      end

      if build && @prompt && !@prompt.is_a?(Prompt::Fake)
        @prompt.text = render_erb(@prompt.text)   if AIA.config.erb?
        @prompt.text = render_env(@prompt.text)   if AIA.config.shell?
        process_prompt_keywords
      end

      AIA.config.directives = @prompt&.directives || []
    end

    private

    def setup_prompt_manager
      PromptManager::Prompt.storage_adapter = 
        PromptManager::Storage::FileSystemAdapter.config do |config|
          config.prompts_dir = AIA.config.prompts_dir
          config.prompt_extension = '.txt'
          config.params_extension = '.json'
          config.search_proc = nil
        end.new
    end

    def process_prompt_keywords
      return if @prompt.keywords.empty?
      replace_keywords
      @prompt.build
      save(@prompt_text_before_role)
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

          @prompt.parameters[kw] << value
          @prompt.parameters[kw].shift if @prompt.parameters[kw].size > KW_HISTORY_MAX
        end
      end
    end

    def save(original_text)
      temp_text = @prompt.text
      @prompt.text = original_text
      @prompt.save
      @prompt.text = temp_text
    end

    def get_prompt
      prompt_id = AIA.config.arguments&.shift
      if prompt_id.nil?
        @prompt = Prompt::Fake.new
      else
        search_for_a_matching_prompt(prompt_id) unless existing_prompt?(prompt_id)
      end
    end

    def existing_prompt?(prompt_id)
      return false unless prompt_id
      @prompt = PromptManager::Prompt.get(id: prompt_id) rescue Prompt::Fake.new
      true
    rescue ArgumentError
      false
    end

    def search_for_a_matching_prompt(prompt_id)
      return if prompt_id.nil?
      
      found_prompts = PromptManager::Prompt.search(prompt_id)

      if found_prompts.empty?
        abort <<~EOS
          
          No prompts where found for: #{prompt_id}
          You need to create a text file for this prompt:
            #{AIA.config.editor} #{AIA.config.prompts_dir}/#{prompt_id}.txt

        EOS
      else    
        prompt_id = 1 == found_prompts.size ? found_prompts.first : handle_multiple_prompts(found_prompts, prompt_id)
        @prompt = PromptManager::Prompt.get(id: prompt_id)
      end
    end

    def handle_multiple_prompts(found_these, while_looking_for_this)
      raise ArgumentError, "Argument is not an Array" unless found_these.is_a?(Array)

      # Create an instance of AIA::Fzf with appropriate parameters
      fzf_instance = AIA::Fzf.new(
        list:       found_these,
        directory:  AIA.config.prompts_dir, # Assuming this is the correct directory
        query:      while_looking_for_this,
        subject:    'Prompt IDs',
        prompt:     'Select one: '
      )

      # Run the fzf instance and get the selected result
      result = fzf_instance.run

      exit unless result

      result
    end

    def create_prompt(prompt_id)
      @prompt = PromptManager::Prompt.create(id: prompt_id)
      # TODO: consider a configurable prompt template
      #       ERB ???
    end

    def show_prompt_without_comments
      puts remove_comments.wrap(indent: 4)
    end

    # removes comments and directives
    def remove_comments
      lines           = @prompt.text
                          .split("\n")
                          .reject{|a_line| 
                            a_line.strip.start_with?('#') ||
                            a_line.strip.start_with?('//')
                          }

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

    def keyword_value(kw, history_array)
      setup_reline_history
      
      default = history_array&.last || ''

      Array(history_array).each { |entry| Reline::HISTORY.push(entry) unless entry.nil? || entry.empty? }

      puts "Parameter #{kw} ..."

      if default.empty?
        user_prompt = "\n-=> "
      else
        user_prompt = "\n(#{default}) -=> "
      end

      a_string = ask_question_with_reline(user_prompt)

      if a_string.nil?
        puts "okay. Come back soon."
        exit
      end

      puts
      a_string.empty? ? default : a_string
    end

    def setup_reline_history(max_history_size=5)
      Reline::HISTORY.clear
    end
  end

  class Prompt::Fake
    def id;         '_fake_'; end
    def path;       '_fake_'; end
    def to_s;       '';       end
    def keywords;   [];       end
    def directives; [];       end
    def text;       '';       end
    def text=(val); @text = val; end
  end
end

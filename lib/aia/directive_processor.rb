# lib/aia/directive_processor.rb


module AIA
  class DirectiveProcessor
    EXCLUDED_METHODS = %w[ run initialize private? ]

    def initialize
      @prefix_size    = PromptManager::Prompt::DIRECTIVE_SIGNAL.size
      @included_files = []
    end


    def directive?(a_string)
      a_string.strip.start_with?(PromptManager::Prompt::DIRECTIVE_SIGNAL)
    end

    # Used with the chat loop to allow user to enter a single directive
    def process(a_string)
      return a_string unless directive?(a_string)
      key = a_string.strip
      run({ key => ""})[key]
    end

    def run(directives)
      return {} if directives.nil? || directives.empty?
      results = []
      directives.each do |key, _|
        sans_prefix = key[@prefix_size..]
        args        = sans_prefix.split(' ')
        method_name = args.shift.downcase

        if EXCLUDED_METHODS.include?(method_name)
          directives[key] = "Error: #{method_name} is not a valid directive: #{key}"
          next
        elsif private?(method_name)
          directives[key] =  send(method_name, *args)
        else
          directives[key] = "Error: Unknown directive '#{key}'"
        end
      end

      directives
    end

    #####################################################
    ## Directives are implemented as private methods
    ## All directives return a String.  It can be empty.
    #
    private

    def private?(method_name)
      !respond_to?(method_name) && respond_to?(method_name, true)
    end

    def include(file_path)
      if @included_files.include?(file_path)
        ""
      else
        if File.exist?(file_path) && File.readable?(file_path)
          @included_files << file_path
          File.read(file_path)
        else
          "Error: File '#{file_path}' is not accessible"
        end
      end
    end
    alias_method :include_file, :include
    alias_method :import,       :include

    def config(args=[])
      args = Array(args)

      if args.empty?
        ap AIA.config
        ""
      elsif args.length == 1
        config_item = args.first
        local_cfg   = Hash.new
        local_cfg[config_item] = AIA.config[config_item]
        ap local_cfg
        ""
      else
        config_item  = args.shift
        config_value = args.join(' ').gsub('=', '').strip

        AIA.config[config_item] = config_value
        ""
      end
    end
    alias_method :cfg, :config

    def top_p(*args)
      send(:config, args.prepend('top_p'))
    end
    alias_method :topp, :top_p

    def model(*args)
      send(:config, args.prepend('model'))
    end

    def temperature(*args)
      send(:config, args.prepend('temperature'))
    end
    alias_method :temp, :temperature

    def clear(*args)
      "TODO: How do I clear the context?"
    end

    # Depends upon PromptManager::Prompt#to_s evaluating ERB
    # after it has evaluated directives.
    def ruby(*args)
      "<%= #{args.join(' ')} %>"
    end

    def say(*args)
      `say #{args.join(' ')}`
      ""
    end

    def help(...)
      directives  = self.class
                      .private_instance_methods(false)
                      .map(&:to_s)
                      .reject { |m| EXCLUDED_METHODS.include?(m) }
                      .map { |m| "//#{m}" }
                      .sort
      puts directives.join("\n")
      ""
    end
  end
end

# lib/aia/directive_processor.rb

module AIA
  class DirectiveProcessor
    EXCLUDED_METHODS = %w[ run initialize private? ]
    @descriptions = {}
    @aliases      = {}

    class << self
      attr_reader :descriptions, :aliases

      def desc(description, method_name = nil)
        @last_description = description
        @descriptions[method_name.to_s] = description if method_name
        nil
      end

      def method_added(method_name)
        if @last_description
          @descriptions[method_name.to_s] = @last_description
          @last_description = nil
        end
        super if defined?(super)
      end

      def build_aliases(private_methods)
        private_methods.each do |method_name|
          method = instance_method(method_name)

          @aliases[method_name] = []

          private_methods.each do |other_method_name|
            next if method_name == other_method_name

            other_method = instance_method(other_method_name)

            if method == other_method
              @aliases[method_name] << other_method_name
            end
          end
        end
      end
    end

    def initialize
      @prefix_size    = PromptManager::Prompt::DIRECTIVE_SIGNAL.size
      @included_files = []
    end

    def directive?(a_string)
      a_string.strip.start_with?(PromptManager::Prompt::DIRECTIVE_SIGNAL)
    end

    # Used with the chat loop to allow user to enter a single directive
    def process(a_string, context_manager)
      return a_string unless directive?(a_string)

      key = a_string.strip
      sans_prefix = key[@prefix_size..]
      args        = sans_prefix.split(' ')
      method_name = args.shift.downcase

      if EXCLUDED_METHODS.include?(method_name)
        return "Error: #{method_name} is not a valid directive: #{key}"
      elsif respond_to?(method_name, true)
        return send(method_name, args)
      else
        return "Error: Unknown directive '#{key}'"
      end
    end

    def run(directives)
      return {} if directives.nil? || directives.empty?
      directives.each do |key, _|
        sans_prefix = key[@prefix_size..]
        args        = sans_prefix.split(' ')
        method_name = args.shift.downcase

        if EXCLUDED_METHODS.include?(method_name)
          directives[key] = "Error: #{method_name} is not a valid directive: #{key}"
          next
        elsif respond_to?(method_name, true)
          directives[key] = send(method_name, args)
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

    ################
    ## Directives ##
    ################

    desc "Specify the next prompt ID to process after this one"
    def next(args = [])
      if args.empty?
        ap AIA.config.next
      else
        AIA.config.next = args.shift
      end
      ''
    end

    desc "Specify a sequence pf prompt IDs to process after this one"
    def pipeline(args = [])
      if args.empty?
        ap AIA.config.pipeline
      else
        AIA.config.pipeline += args.map {|id| id.gsub(',', '').strip}
      end
      ''
    end

    desc "Inserts the contents of a file  Example: //include path/to/file"
    def include(args)
      # echo takes care of envars and tilde expansion
      file_path = `echo #{args.shift}`.strip

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

    desc "Without arguments it will print a list of all config items and their values _or_ //config item (for one item's value) _or_ //config item = value (to set a value of an item)"
    def config(args = [])
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
        boolean      = AIA.respond_to?("#{config_item}?")
        new_value    = args.join(' ').gsub('=', '').strip

        if boolean
          new_value = %w[true t yes y on 1 yea yeah yep yup].include?(new_value.downcase)
        end

        AIA.config[config_item] = new_value
        ""
      end
    end
    alias_method :cfg, :config

    desc "Shortcut for //config top_p _and_ //config top_p = value"
    def top_p(*args)
      send(:config, args.prepend('top_p'))
    end
    alias_method :topp, :top_p

    desc "Shortcut for //config model _and_ //config model = value"
    def model(*args)
      send(:config, args.prepend('model'))
    end

    desc "Shortcut for //config temperature _and_ //config temperature = value"
    def temperature(*args)
      send(:config, args.prepend('temperature'))
    end
    alias_method :temp, :temperature

    desc "Clears the conversation history (aka context) same as //config clear = true"
    def clear(args, context_manager)
      if context_manager.nil?
        return "Error: Context manager not available for //clear directive."
      end
      context_manager.clear_context
      nil
    end

    desc "Shortcut for a one line of ruby code; result is added to the context"
    def ruby(*args)
      ruby_code = args.join(' ')

      begin
        String(eval(ruby_code))
      rescue Exception => e
        <<~ERROR
          This ruby code failed: #{ruby_code}
          #{e.message}
        ERROR
      end
    end
    alias_method :rb, :ruby


    desc "Executes one line of shell code; result is added to the context"
    def shell(*args)
      shell_code = args.join(' ')

      `#{shell_code}`
    end
    alias_method :sh, :shell



    desc "Use the system's say command to speak text //say some text"
    def say(*args)
      `say #{args.join(' ')}`
      ""
    end

    desc "Inserts an instruction to keep responses short and to the point."
    def terse(*args)
      AIA::Session::TERSE_PROMPT
    end

    desc "Display the ASCII art AIA robot."
    def robot(*args)
      AIA::Utility.robot
      ""
    end

    desc "Generates this help content"
    def help(*args)
      puts
      puts "Available Directives"
      puts "===================="
      puts

      directives  = self.class
                      .private_instance_methods(false)
                      .map(&:to_s)
                      .reject { |m| EXCLUDED_METHODS.include?(m) }
                      .sort

      self.class.build_aliases(directives)

      directives.each do |directive|
        next unless self.class.descriptions[directive]

        others = self.class.aliases[directive]

        if others.empty?
          others_line = ""
        else
          with_prefix = others.map{|m| PromptManager::Prompt::DIRECTIVE_SIGNAL + m}
          others_line = "\tAliases:#{with_prefix.join('  ')}\n"
        end

        puts <<~TEXT
          //#{directive} #{self.class.descriptions[directive]}
          #{others_line}
        TEXT
      end

      ""
    end
  end
end

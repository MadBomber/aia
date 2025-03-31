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

    ################
    ## Directives ##
    ################

    desc "Inserts the contents of a file  Example: //include path/to/file"
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

    desc "Without arguments it will print a list of all config items and their values _or_ //config item (for one item's value) _or_ //config item = value (to set a value of an item)"
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

    desc "TODO: wanting to clear the chat context"
    def clear(*args)
      "TODO: How do I clear the context?"
    end

    # Depends upon PromptManager::Prompt#to_s evaluating ERB
    # after it has evaluated directives.
    desc "Shortcut for a one line ERB statement"
    def ruby(*args)
      "<%= #{args.join(' ')} %>"
    end

    desc "Use the system's say command to speak text //say some text"
    def say(*args)
      `say #{args.join(' ')}`
      ""
    end

    desc "Generates this help content"
    def help(...)
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
      # ap self.class.descriptions
      # ap self.class.aliases
      ""
    end
  end
end

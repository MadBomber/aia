# lib/aia/directive_processor.rb

require 'faraday'

module AIA
  class DirectiveProcessor
    using Refinements

    PUREMD_API_KEY   = ENV.fetch('PUREMD_API_KEY', nil)
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
      # Handle RubyLLM::Message objects by extracting their content first
      content = if a_string.is_a?(RubyLLM::Message)
                 a_string.content rescue a_string.to_s
               else
                 a_string.to_s
               end

      content.strip.start_with?(PromptManager::Prompt::DIRECTIVE_SIGNAL)
    end

    # Used with the chat loop to allow user to enter a single directive
    def process(a_string, context_manager)
      return a_string unless directive?(a_string)

      # Handle RubyLLM::Message objects by extracting their content first
      content = if a_string.is_a?(RubyLLM::Message)
                 a_string.content rescue a_string.to_s
               else
                 a_string.to_s
               end

      key = content.strip
      sans_prefix = key[@prefix_size..]
      args        = sans_prefix.split(' ')
      method_name = args.shift.downcase

      if EXCLUDED_METHODS.include?(method_name)
        return "Error: #{method_name} is not a valid directive: #{key}"
      elsif respond_to?(method_name, true)
        return send(method_name, args, context_manager)
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


    desc "webpage inserted as markdown to context using pure.md"
    def webpage(args, context_manager=nil)
      if PUREMD_API_KEY.nil?
        "ERROR: PUREMD_API_KEY is required in order to include a webpage"
      else
        url        = `echo #{args.shift}`.strip
        puremd_url = "https://pure.md/#{url}"

        response = Faraday.get(puremd_url) do |req|
          req.headers['x-puremd-api-token'] = PUREMD_API_KEY
        end

        if 200 == response.status
          response.body
        else
          "Error: wtatus was #{r.status}\n#{ap response}"
        end
      end
    end

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
    alias_method :workflow, :pipeline

    desc "Inserts the contents of a file  Example: //include path/to/file"
    def include(args, context_manager=nil)
      # echo takes care of envars and tilde expansion
      file_path = `echo #{args.shift}`.strip

      if file_path.start_with?(/http?:\/\//)
        return webpage(args)
      end

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
    def config(args = [], context_manager=nil)
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
    def top_p(args, context_manager=nil)
      send(:config, args.prepend('top_p'), context_manager)
    end
    alias_method :topp, :top_p

    desc "Review the current context"
    def review(args, context_manager=nil)
      ap context_manager.get_context
      ''
    end
    alias_method :context, :review

    desc "Shortcut for //config model _and_ //config model = value"
    def model(args, context_manager=nil)
      send(:config, args.prepend('model'), context_manager)
    end

    desc "Shortcut for //config temperature _and_ //config temperature = value"
    def temperature(args, context_manager=nil)
      send(:config, args.prepend('temperature'), context_manager)
    end
    alias_method :temp, :temperature

    desc "Clears the conversation history (aka context) same as //config clear = true"
    def clear(args, context_manager=nil)
      # TODO: review the robot's code in the Session class for when the
      #       //clear directive is used in a follow up prompt.  That processing
      #       should be moved here so that it is also available in batch
      #       sessions.
      if context_manager.nil?
        return "Error: Context manager not available for //clear directive."
      end

      context_manager.clear_context

      ''
    end

    desc "Shortcut for a one line of ruby code; result is added to the context"
    def ruby(args, context_manager=nil)
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
    def shell(args, context_manager=nil)
      shell_code = args.join(' ')

      `#{shell_code}`
    end
    alias_method :sh, :shell

    desc "Use the system's say command to speak text //say some text"
    def say(args, context_manager=nil)
      `say #{args.join(' ')}`
      ""
    end

    desc "Inserts an instruction to keep responses short and to the point."
    def terse(args, context_manager=nil)
      AIA::Session::TERSE_PROMPT
    end

    desc "Display the ASCII art AIA robot."
    def robot(args, context_manager=nil)
      AIA::Utility.robot
      ""
    end

    desc "All Available models or query on [partial LLM or provider name] Examples: //llms ; //llms openai ; //llms claude"
    def available_models( args=nil, context_manager=nil)
      query     = args
      header    = "\nAvailable LLMs"
      header   += " for #{query.join(' and ')}" if query

      puts header + ':'
      puts

      q1 = query.select{|q| q.include?('_to_')}.map{|q| ':'==q[0] ? q[1...] : q}
      q2 = query.reject{|q| q.include?('_to_')}

      counter = 0

      RubyLLM.models.all.each do |llm|
        inputs  = llm.modalities.input.join(',')
        outputs = llm.modalities.output.join(',')
        entry   = "- #{llm.id} (#{llm.provider}) #{inputs} to #{outputs}"

        if query.nil? || query.empty?
          counter += 1
          puts entry
          next
        end

        show_it = true
        q1.each{|q| show_it &&= llm.modalities.send("#{q}?")}
        q2.each{|q| show_it &&= entry.include?(q)}

        if show_it
          counter += 1
          puts entry
        end
      end

      puts if counter > 0
      puts "#{counter} LLMs matching your query"
      puts

      ""
    end
    alias_method :am,         :available_models
    alias_method :available,  :available_models
    alias_method :models,     :available_models
    alias_method :all_models, :available_models
    alias_method :llms,       :available_models

    desc "Generates this help content"
    def help(args=nil, context_manager=nil)
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

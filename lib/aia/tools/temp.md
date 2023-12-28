# lib/aia/tools.rb

```ruby
require 'hashie'

module AIA
  class Tools
    @subclasses = {}

    class << self
      attr_reader :subclasses, :metadata

      def inherited(subclass)
        @subclasses[subclass.name.split('::').last.downcase] = subclass
        subclass.instance_variable_set(:@metadata, Jashie::Mash.new)
      end

      def meta
        @metadata ||= Jashie::Mash.new
      end

      def define_metadata(&block)
        meta.instance_eval(&block)
      end

      def search_for(name: nil, role: nil)
        return subclasses[name.downcase] if name
        return subclasses.values.select { |subclass| subclass.meta.role == role } if role
      end
    end

    def self.method_missing(name, *args, &block)
      @metadata.public_send(name, *args, &block)
    end

    def self.respond_to_missing?(method_name, include_private = false)
      @metadata.respond_to?(method_name) || super
    end
  end
end
```

# lib/aia/tools/mods.rb

```ruby
require_relative 'tools'

module AIA
  class Mods < Tools
    DEFAULT_PARAMETERS = "--no-limit".freeze

    attr_accessor :command, :extra_options, :text, :files

    define_metadata do
      role :backend
      desc 'AI on the command-line'
      url  'https://github.com/charmbracelet/mods'
    end

    def initialize(extra_options: "", text: "", files: [])
      @extra_options = extra_options
      @text = text
      @files = files
      build_command
    end

    def build_command
      parameters = DEFAULT_PARAMETERS.dup + " "
      parameters += "-f " if ::AIA.config.markdown?
      parameters += "-m #{AIA.config.model} " if ::AIA.config.model
      parameters += @extra_options
      @command = "mods #{parameters}"
      @command += %Q["#{@text}"]

      @files.each { |f| @command += " < #{f}" }

      @command
    end

    def run
      `#{@command}`
    end
  end
end
```

```ruby
# Example usage:
# mods_class = AIA::Tools.search_for(name: 'mods')
# mods_instance = mods_class.new(text: "Hello, mods!")
# result = mods_instance.run

# backend_tools = AIA::Tools.search_for(role: :backend)
```

Note: The `Jashie::Mash` class is assumed to behave like `Hashie::Mash` (or similar) in providing a flexible object for storing metadata. You'll need to define `Jashie::Mash` or import a library that provides a similar functionality to match this example.


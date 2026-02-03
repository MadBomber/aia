# lib/aia/directives/utility.rb

require 'tty-screen'
require 'word_wrapper'

module AIA
  module Directives
    module Utility
      TERSE_PROMPT = "" # DEPRECATED: terse mode has been removed

      def self.tools(args = [], context_manager = nil)
          indent = 4
          spaces = " " * indent
          width = TTY::Screen.width - indent - 2
          filter = args.first&.downcase

          loaded_tools = AIA.config.loaded_tools || []
          if loaded_tools.empty?
            puts "No tools are available"
          else
            tools_to_display = loaded_tools

            if filter
              tools_to_display = tools_to_display.select do |tool|
                name = tool.respond_to?(:name) ? tool.name : tool.class.name
                name.downcase.include?(filter)
              end
            end

            if tools_to_display.empty?
              puts "No tools match the filter: #{args.first}"
            else
              puts
              header = filter ? "Available Tools (filtered by '#{args.first}')" : "Available Tools"
              puts header
              puts "=" * header.length

              tools_to_display.each do |tool|
                name = tool.respond_to?(:name) ? tool.name : tool.class.name
                puts "\n#{name}"
                puts "-" * name.size
                puts WordWrapper::MinimumRaggedness.new(width, tool.description).wrap.split("\n").map { |s| spaces + s + "\n" }.join
              end
            end
          end
          puts

          ''
        end

      def self.next(args = [], context_manager = nil)
          if args.empty?
            ap AIA.config.next
          else
            AIA.config.next = args.shift
          end
          ''
        end

      def self.pipeline(args = [], context_manager = nil)
          if args.empty?
            ap AIA.config.pipeline
          elsif 1 == args.size
            AIA.config.pipeline += args.first.split(',').map(&:strip).reject { |id| id.empty? }
          else
            AIA.config.pipeline += args.map { |id| id.gsub(',', '').strip }.reject { |id| id.empty? }
          end
          ''
        end

      def self.terse(args, context_manager = nil)
          TERSE_PROMPT
        end

      def self.robot(args, context_manager = nil)
          AIA::Utility.robot
          ""
        end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :workflow, :pipeline
      end
    end
  end
end

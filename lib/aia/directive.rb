# lib/aia/directive.rb
#
# Application-level directive base class.
# Inherits the DSL (desc, method_added, alias detection, register_all)
# from PM::Directive and adds AIA-specific concerns:
#
#   - DIRECTIVE_PREFIX for chat-time slash commands
#   - help output formatting
#   - build_dispatch_block override for AIA's (args, context_manager) convention
#
# Subclass to define a category of directives. The subclass name
# determines the category heading in /help output:
#
#   class AIA::ContextDirectives < AIA::Directive  -->  "Context"
#   class AIA::ExecutionDirectives < AIA::Directive -->  "Execution"
#
# Use `desc` immediately before a method definition to mark it as a
# directive and provide its help description. Methods without a
# preceding `desc` are ordinary helpers and will not be registered.
#
# Use Ruby's own `alias_method` to create directive aliases;
# they are detected automatically via UnboundMethod#original_name.
#
# Example:
#
#   class AIA::ExecutionDirectives < AIA::Directive
#     desc "Execute Ruby code"
#     def ruby(args, context_manager = nil)
#       String(eval(args.join(' ')))
#     end
#     alias_method :rb, :ruby
#   end
#

module AIA
  class Directive < PM::Directive
    DIRECTIVE_PREFIX = '/'

    class << self
      # ---- Dispatch override ------------------------------------------------
      # AIA directive methods use (args_array, context_manager) convention,
      # not (ctx, *args). Override build_dispatch_block to adapt.

      def build_dispatch_block(inst, method_name)
        proc { |_ctx, *args| inst.send(method_name, Array(args).flatten, nil) }
      end

      # ---- Help output ------------------------------------------------------
      # Application-level concern: formats help text using DIRECTIVE_PREFIX
      # and all registered directive subclasses.

      def help
        puts
        puts "Available Directives"
        puts "===================="
        puts

        total = 0

        PM::Directive.directive_subclasses.each do |klass|
          next if klass.directive_descriptions.empty?

          cat = klass.category_name
          puts "#{cat}:"
          puts "-" * cat.length

          klass.directive_descriptions.each do |method_name, description|
            aliases    = klass.directive_aliases[method_name] || []
            alias_text = if aliases.any?
                           " (aliases: #{aliases.map { |a| "#{DIRECTIVE_PREFIX}#{a}" }.join(', ')})"
                         else
                           ""
                         end

            puts "  #{DIRECTIVE_PREFIX}#{method_name}#{alias_text}"
            puts "      #{description}"
            puts

            total += 1
          end
        end

        puts "\nTotal: #{total} directives available"
        ""
      end
    end
  end
end

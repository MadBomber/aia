# examples/plugins/joke.rb
#
# Chat-time directive plugin:
#   /joke            # tells a random joke
#   /joke dad        # dad-joke flavor
#   /joke pirate     # pirate-joke flavor
#   /joke programming
#
# Loaded dynamically by AIA::PluginLoader. Top-level methods become available
# immediately and are removed/reloaded cleanly by the plugin monitor.

require 'shellwords'

module AIA
  class PluginJokeDirective < Directive
    JOKES = {
      'default' => [
        "Why don't robots ever panic? They keep their bytes together.",
        "I told my computer I needed a break, so it said: 'No problem — I'll go to sleep.'",
        "Why was the developer calm during the outage? They had cache flow."
      ],
      'dad' => [
        "I only know 25 letters of the alphabet. I don't know y.",
        "What do you call cheese that isn't yours? Nacho cheese.",
        "I used to hate facial hair, but then it grew on me."
      ],
      'pirate' => [
        "Why did the pirate buy an extra keyboard? For the arrrrrow keys.",
        "What language do pirates use for coding? Arrrruby.",
        "Why don't pirates shower before they walk the plank? They just wash up on shore."
      ],
      'programming' => [
        "Why do programmers prefer dark mode? Because light attracts bugs.",
        "A SQL query walks into a bar, walks up to two tables, and asks: 'Can I join you?'",
        "There are only 10 kinds of people in the world: those who understand binary and those who don't."
      ]
    }.freeze

    desc 'Tell a joke. Optional category: dad, pirate, programming'
    def joke(args = [], context_manager = nil)
      requested = args.first.to_s.downcase
      category = JOKES.key?(requested) ? requested : 'default'
      joke = JOKES.fetch(category).sample

      if requested.empty? || requested == category
        joke
      else
        "Unknown joke category '#{requested}'. Try: #{available_categories}.\n\n#{joke}"
      end
    end

    private

    def available_categories
      (JOKES.keys - ['default']).join(', ')
    end
  end
end

AIA::PluginJokeDirective.register_all

# aia/lib/aia/dynamic_content.rb

require 'erb'

module AIA::DynamicContent

  # inserts environment variables (envars) and dynamic content into a prompt
  # replaces patterns like $HOME and ${HOME} with the value of ENV['HOME']
  # replaces patterns like $(shell command) with the output of the shell command
  #
  def render_env(a_string)
    a_string.gsub(/\$(\w+|\{\w+\})/) do |match|
      ENV.fetch(match.tr('$', '').tr('{}', ''), '')
    end.gsub(/\$\((.*?)\)/) do |match|
      `#{match[2..-2]}`.chomp
    end
  end


  # Need to use instance variables in assignments
  # to maintain binding from one follow up prompt
  # to another.
  def render_erb(the_prompt_text)
    ERB.new(the_prompt_text).result(binding)
  end
end

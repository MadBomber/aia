# lib/aia/directives.rb

require 'hashie'

class AIA::Directives
  def initialize( prompt: )
    @prompt = prompt  # PromptManager::Prompt instance
    AIA.config.directives = @prompt.directives
  end


  def execute_my_directives
    return if AIA.config.directives.nil? || AIA.config.directives.empty?
    
    not_mine = []

    AIA.config.directives.each do |entry|
      directive   = entry[0].to_sym
      parameters  = entry[1]

      if respond_to? directive
        send(directive, parameters)
      else
        not_mine << entry
      end
    end

    AIA.config.directives = not_mine
  end


  def box(what)
    f   = what[0]
    bar = "#{f}"*what.size
    puts "#{bar}\n#{what}\n#{bar}"
  end


  # Allows a prompt to change its configuration environment
  def config(what)
    parts = what.split(' ')
    item  = parts.shift
    parts.shift if %w[:= =].include? parts[0]

    if '<<' == parts[0]
      parts.shift
      value = parts.join
      if AIA.config(item).is_a?(Array)
        AIA.config[item] << value
      else
        AIA.config[item] = [ value ]
      end
    else
      value = parts.join
      if item.end_with?('?')
        AIA.config[item] = %w[1 y yea yes t true].include?(value.downcase)
      else
        AIA.config[item] = "STDOUT" == value ? STDOUT : value
      end
    end
  end
end

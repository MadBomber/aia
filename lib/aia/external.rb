# lib/aia/external.rb

# TODO: move stuff associated with the CLI options for
#       external commands to this module.
#       Is the EDITOR considered an external command? Yes.

=begin

There are at least 4 processes handled by external tools:

  search .......... default PromptManager::Prompt or search_proc
  review/select ... using fzf either exact or fuzzy
  edit ............ ENV['EDITOR']
  execute ......... mods or sgpt or ???
                      with different models / settings

  sgpt is the executable for "shell-gpt" a python project

=end

module AIA::External
  class Mods;    end
  class Fzf;     end
  class Rg;      end
  class Editor;  end
end

module AIA::External
  TOOLS = {
    'fzf'   => [  'Command-line fuzzy finder written in Go',
                  'https://github.com/junegunn/fzf'],
    
    'mods'  => [  'AI on the command-line',
                  'https://github.com/charmbracelet/mods'],
    
    'rg'    => [  'Search tool like grep and The Silver Searcher',
                  'https://github.com/BurntSushi/ripgrep']
  }


  HELP = <<~EOS
    External Tools Used
    -------------------

    To install the external CLI programs used by aia:
      brew install #{TOOLS.keys.join(' ')}

    #{TOOLS.to_a.map{|t| t.join("\n  ") }.join("\n\n")}

    A text editor whose executable is setup in the 
    system environment variable 'EDITOR' like this:

    export EDITOR="#{ENV['EDITOR']}"

  EOS


  # Setup the AI CLI program with necessary variables
  def setup_external_programs
    verify_external_tools

    ai_default_opts = "-m #{MODS_MODEL} --no-limit "
    ai_default_opts += "-f " if markdown?
    @ai_options     = ai_default_opts.dup


    @ai_options     += @extra_options.join(' ') 

    @ai_command     = "#{AI_CLI_PROGRAM} #{@ai_options} "
  end


  # Check if the external tools are present on the system
  def verify_external_tools
    missing_tools = []

    TOOLS.each do |tool, url|
      path = `which #{tool}`.chomp
      if path.empty? || !File.executable?(path)
        missing_tools << { name: tool, url: url }
      end
    end

    if missing_tools.any?
      puts format_missing_tools_response(missing_tools)
    end
  end


  def format_missing_tools_response(missing_tools)
    response = <<~EOS

      WARNING:  #{MY_NAME} makes use of a few external CLI tools.
                #{MY_NAME} may not respond as designed without these.
                
      The following tools are missing on your system:

    EOS

    missing_tools.each do |tool|
      response << "  #{tool[:name]}: install from #{tool[:url]}\n"
    end

    response
  end


  # Build the command to interact with the AI CLI program
  def build_command
    command = @ai_command + %Q["#{@prompt.to_s}"]

    @arguments.each do |input_file|
      file_path = Pathname.new(input_file)
      abort("File does not exist: #{input_file}") unless file_path.exist?
      command += " < #{input_file}"
    end

    command
  end


  # Execute the command and log the results
  def send_prompt_to_external_command
    command = build_command

    puts command if verbose?
    @result = `#{command}`

    if output.nil?
      puts @result
    else
      output.write @result
    end

    @result
  end
end


__END__



MODS_MODEL      = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'

AI_CLI_PROGRAM  = "mods"
ai_default_opts = "-m #{MODS_MODEL} --no-limit -f"
ai_options      = ai_default_opts.dup

extra_inx       = ARGV.index('--')

if extra_inx
  ai_options += " " + ARGV[extra_inx+1..].join(' ')
  ARGV.pop(ARGV.size - extra_inx)
end

AI_COMMAND        = "#{AI_CLI_PROGRAM} #{ai_options} "
EDITOR            = ENV['EDITOR']
PROMPT_DIR        = HOME + ".prompts"
PROMPT_LOG        = PROMPT_DIR + "_prompts.log"
PROMPT_EXTNAME    = ".txt"
DEFAULTS_EXTNAME  = ".json"
# SEARCH_COMMAND    = "ag -l"
KEYWORD_REGEX     = /(\[[A-Z _|]+\])/

AVAILABLE_PROMPTS = PROMPT_DIR
                      .children
                      .select{|c| PROMPT_EXTNAME == c.extname}
                      .map{|c| c.basename.to_s.split('.')[0]}

AVAILABLE_PROMPTS_HELP  = AVAILABLE_PROMPTS
                            .map{|c| "  * " + c}
                            .join("\n")


AI_CLI_PROGRAM_HELP = `#{AI_CLI_PROGRAM} --help`

HELP = <<EOHELP
AI CLI Program
==============

The AI cli program being used is: #{AI_CLI_PROGRAM}

The defaul options to #{AI_CLI_PROGRAM} are:
  "#{ai_default_opts}"

You can pass additional CLI options to #{AI_CLI_PROGRAM} like this:
  "#{my_name} my options -- options for #{AI_CLI_PROGRAM}"

#{AI_CLI_PROGRAM_HELP}

EOHELP



AG_COMMAND        = "ag --file-search-regex '\.txt$' e" # searching for the letter "e"
CD_COMMAND        = "cd #{PROMPT_DIR}"
FIND_COMMAND      = "find . -name '*.txt'"

FZF_OPTIONS       = [
  "--tabstop=2",  # 2 soaces for a tab
  "--header='Prompt contents below'",
  "--header-first",
  "--prompt='Search term: '",
  '--delimiter :',
  "--preview 'ww {1}'",              # ww comes from the word_wrap gem
  "--preview-window=down:50%:wrap"
].join(' ')

FZF_OPTIONS += " --exact" unless fuzzy?

FZF_COMMAND       = "#{CD_COMMAND} ; #{FIND_COMMAND} | fzf #{FZF_OPTIONS}"
AG_FZF_COMMAND    = "#{CD_COMMAND} ; #{AG_COMMAND}   | fzf #{FZF_OPTIONS}"

# use `ag` ti build a list of text lines from each prompt
# use `fzf` to search through that list to select a prompt file

def ag_fzf = `#{AG_FZF_COMMAND}`.split(':')&.first&.strip&.gsub('.txt','')


if configatron.prompt.empty?
  unless first_argument_is_a_prompt?
    configatron.prompt  = ag_fzf
  end
end

###############################################



#!/usr/bin/env bash
# ~/scripts/ripfzfsubl
#
# Uses Sublime Text (subl) as the text editor
#
# brew install bat ripgrep fzf
# 
# bat  Clone of cat(1) with syntax highlighting and Git integration
#      |__ https://github.com/sharkdp/bat
# 
# ripgrep  Search tool like grep and The Silver Searcher
#          |__ https://github.com/BurntSushi/ripgrep
# 
# fzf  Command-line fuzzy finder written in Go
#      |__ https://github.com/junegunn/fzf
#
#
# 1. Search for text in files using Ripgrep
# 2. Interactively narrow down the list using fzf
# 3. Open the file in Sublime Text Editor

rg --color=always --line-number --no-heading --smart-case "${*:-}" |
  fzf --ansi \
      --color "hl:-1:underline,hl+:-1:underline:reverse" \
      --delimiter : \
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
      --bind 'enter:become(subl {1}:{2})'


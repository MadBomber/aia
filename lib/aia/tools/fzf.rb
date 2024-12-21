# lib/aia/tools/fzf.rb
# Wrapper for the fzf (fuzzy finder) command-line tool
#
# This class provides an interface to the fzf utility for fuzzy searching through lists
# of items. It's primarily used for interactive selection of prompts, roles, and other
# items throughout the AIA system.
#
# Features:
# - Configurable search parameters and preview window
# - Temporary file handling for input lists
# - Customizable prompt and header text
# - Integration with system fzf installation
#
# @see https://github.com/junegunn/fzf
#

require 'shellwords'
require 'tempfile'

class AIA::Fzf < AIA::Tools

  meta(
    name:     'fzf',
    role:     :search_tool,
    desc:     "A command-line fuzzy finder",
    url:      "https://github.com/junegunn/fzf",
    install:  "brew install fzf",
  )

  DEFAULT_PARAMETERS = %w[
    --tabstop=2
    --header-first
    --prompt='Search term: '
    --delimiter :
    --preview-window=down:50%:wrap
  ]

  attr_reader :list, :directory, :query, :subject, :prompt, :extension, :command

  def initialize(
      list:,          # Array of Strings (basenames of files w/o extension)
      directory:,     # Parent directory of the list items
      query:      '', # String, the thing be searched for
      subject:    'Prompt IDs', # or 'Role Names'
      prompt:     'Select one:',
      extension:  '.txt'
    )

    @list       = list
    @directory  = directory
    @query      = query
    @subject    = subject
    @prompt     = prompt
    @extension  = extension
    
    build_command
  end


  def build_command
    fzf_options = DEFAULT_PARAMETERS.dup
    fzf_options << "--header='#{subject} which contain: #{query}\\nPress ESC to cancel.'"
    fzf_options << "--preview='cat #{directory}/{1}#{extension}'"
    fzf_options << "--prompt=#{Shellwords.escape(prompt)}"
    
    fzf_command = "#{meta.name} #{fzf_options.join(' ')}"

    @command = "cat #{tempfile_path} | #{fzf_command}"
  end
  

  def run
    puts "Executing: #{@command}"
    selected = `#{@command}`
    selected.strip.empty? ? nil : selected.strip
  ensure
    unlink_tempfile
  end

  ##############################################
  private

  def tempfile_path
    @tempfile ||= Tempfile.new('fzf-input').tap do |file|
      list.each { |item| file.puts item }
      file.close
    end
    @tempfile.path
  end

  def unlink_tempfile
    @tempfile&.unlink
  end
end


__END__

$ fzf --help

USAGE
    fzf [OPTIONS]

OPTIONS
    -x, --extended        Extended-search mode
    -e, --exact           Enable Exact-match
    --algo=TYPE           Fuzzy matching algorithm: [v1|v2] (default: v2)
    +i                    Case-insensitive match (default: smart-case match)
    +s                    Synchronous search for multi-staged filtering
    --multi               Enable multi-select with tab/shift-tab

    ... (Other options)

EXAMPLES
    find * -type f | fzf > selected
    fzf < /path/to/file_list

For full documentation, please visit https://github.com/junegunn/fzf.

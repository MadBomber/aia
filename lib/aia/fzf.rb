# lib/aia/tools/fzf.rb
# fzf is a general-purpose command-line fuzzy finder

require 'shellwords'
require 'tempfile'

class AIA::Fzf
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
      extension:  '.md'
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
    fzf_options << "--header='#{subject} which contain: #{query}\nPress ESC to cancel.'"
    fzf_options << "--preview='cat #{directory}/{1}#{extension}'"
    fzf_options << "--prompt=#{Shellwords.escape(prompt)}"

    fzf_command = "fzf #{fzf_options.join(' ')}"

    @command = "cat #{tempfile_path} | #{fzf_command}"
  end


  def run
    # puts "Executing: #{@command}"
    selected = `#{@command}`.strip

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

# aia/lib/aia/tools/glow.rb

require 'tempfile'
require 'tty-screen'
require 'shellwords'


=begin

  This class supports two use cases:
  1) rendering markdown from an existing file
  2) rendering markdown from a String object via a temporary file

  In both cases a String object is created and returned that contains the
  rendered version of the content so that it can be written to STDOUT
  by the caller.

=end

class AIA::Glow < AIA::Tools

  meta(
    name:     'glow',
    role:     :markdown_renderer,
    desc:     "A markdown renderer utility",
    url:      "https://github.com/charmbracelet/glow",
    install:  "brew install glow",
  )

  DEFAULT_PARAMETERS = "--width #{TTY::Screen.width-2}" # Magic: -2 just because I want it

  attr_accessor :content, :file_path


  def initialize(content: nil, file_path: nil)
    @content = content
    @file_path = file_path
  end


  def build_command(file_path)
    "#{self.class.meta[:name]} #{DEFAULT_PARAMETERS} #{Shellwords.escape(file_path)}"
  end


  def run
    markdown_content = ""
    return markdown_content unless content || file_path

    # Determine whether to use a temporary file or an existing file
    if @file_path && File.exist?(@file_path)
      # Using the existing file, so don't delete it afterward
      command = build_command(@file_path)
      markdown_content = `#{command}`
    else
      # Use a temporary file
      Tempfile.create(['glow', '.md']) do |file|
        file.write(@content)
        file.close
        command = build_command(file.path)
        markdown_content = `#{command}`
      end
    end

    markdown_content
  end


  def run_now
    return unless content || file_path

    if @file_path && File.exist?(@file_path)
      command = build_command(@file_path)
      system(command)
    else
      Tempfile.create(['glow', '.md']) do |file|
        file.write(@content)
        file.close
        command = build_command(file.path)
        system(command)
      end
    end
  end
end

__END__

$ glow --help

  Render markdown on the CLI, with pizzazz!

Usage:
  glow [SOURCE|DIR] [flags]
  glow [command]

Available Commands:
  completion  Generate the autocompletion script for the specified shell
  config      Edit the glow config file
  help        Help about any command
  stash       Stash a markdown

Flags:
  -a, --all             show system files and directories (TUI-mode only)
      --config string   config file (default /Users/dewayne/Library/Preferences/glow/glow.yml)
  -h, --help            help for glow
  -l, --local           show local files only; no network (TUI-mode only)
  -p, --pager           display with pager
  -s, --style string    style name or JSON path (default "auto")
  -v, --version         version for glow
  -w, --width uint      word-wrap at width

Use "glow [command] --help" for more information about a command.


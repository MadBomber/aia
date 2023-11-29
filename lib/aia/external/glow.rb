# lib/aia/external/glow.rb

class AIA::External::Glow < AIA::External::Tool
  def initialize
    super
    @role = :render
    @desc = 'Render markdown on the CLI'
    @url  = 'https://github.com/charmbracelet/glow'
  end
end


__END__
                                                                              
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

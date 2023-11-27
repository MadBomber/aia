# lib/aia/external/fzf.rb

class AIA::External::Fzf < AIA::External::Tool
  def initialize
    super
    @role = :selecter
    @desc = 'Command-line fuzzy finder written in Go'
    @url  = 'https://github.com/junegunn/fzf'
  end


  def command(options = {})
    cd_command = "cd #{options[:prompt_dir]}"
    find_command = "find . -name '*.txt'"
    fzf_options = build_fzf_options(options[:fuzzy])
    "#{cd_command} ; #{find_command} | fzf #{fzf_options}"
  end

  private

  def build_fzf_options(fuzzy)
    [
      "--tabstop=2",
      "--header='Prompt contents below'",
      "--header-first",
      "--prompt='Search term: '",
      '--delimiter :',
      "--preview 'ww {1}'",              # 'ww' from word_wrap gem
      "--preview-window=down:50%:wrap"
    ].tap { |opts| opts << "--exact" unless fuzzy }.join(' ')
  end
end

__END__

usage: fzf [options]

  Search
    -x, --extended         Extended-search mode
                           (enabled by default; +x or --no-extended to disable)
    -e, --exact            Enable Exact-match
    -i                     Case-insensitive match (default: smart-case match)
    +i                     Case-sensitive match
    --scheme=SCHEME        Scoring scheme [default|path|history]
    --literal              Do not normalize latin script letters before matching
    -n, --nth=N[,..]       Comma-separated list of field index expressions
                           for limiting search scope. Each can be a non-zero
                           integer or a range expression ([BEGIN]..[END]).
    --with-nth=N[,..]      Transform the presentation of each line using
                           field index expressions
    -d, --delimiter=STR    Field delimiter regex (default: AWK-style)
    +s, --no-sort          Do not sort the result
    --track                Track the current selection when the result is updated
    --tac                  Reverse the order of the input
    --disabled             Do not perform search
    --tiebreak=CRI[,..]    Comma-separated list of sort criteria to apply
                           when the scores are tied [length|chunk|begin|end|index]
                           (default: length)

  Interface
    -m, --multi[=MAX]      Enable multi-select with tab/shift-tab
    --no-mouse             Disable mouse
    --bind=KEYBINDS        Custom key bindings. Refer to the man page.
    --cycle                Enable cyclic scroll
    --keep-right           Keep the right end of the line visible on overflow
    --scroll-off=LINES     Number of screen lines to keep above or below when
                           scrolling to the top or to the bottom (default: 0)
    --no-hscroll           Disable horizontal scroll
    --hscroll-off=COLS     Number of screen columns to keep to the right of the
                           highlighted substring (default: 10)
    --filepath-word        Make word-wise movements respect path separators
    --jump-labels=CHARS    Label characters for jump and jump-accept

  Layout
    --height=[~]HEIGHT[%]  Display fzf window below the cursor with the given
                           height instead of using fullscreen.
                           If prefixed with '~', fzf will determine the height
                           according to the input size.
    --min-height=HEIGHT    Minimum height when --height is given in percent
                           (default: 10)
    --layout=LAYOUT        Choose layout: [default|reverse|reverse-list]
    --border[=STYLE]       Draw border around the finder
                           [rounded|sharp|bold|block|thinblock|double|horizontal|vertical|
                            top|bottom|left|right|none] (default: rounded)
    --border-label=LABEL   Label to print on the border
    --border-label-pos=COL Position of the border label
                           [POSITIVE_INTEGER: columns from left|
                            NEGATIVE_INTEGER: columns from right][:bottom]
                           (default: 0 or center)
    --margin=MARGIN        Screen margin (TRBL | TB,RL | T,RL,B | T,R,B,L)
    --padding=PADDING      Padding inside border (TRBL | TB,RL | T,RL,B | T,R,B,L)
    --info=STYLE           Finder info style
                           [default|right|hidden|inline[:SEPARATOR]|inline-right]
    --separator=STR        String to form horizontal separator on info line
    --no-separator         Hide info line separator
    --scrollbar[=C1[C2]]   Scrollbar character(s) (each for main and preview window)
    --no-scrollbar         Hide scrollbar
    --prompt=STR           Input prompt (default: '> ')
    --pointer=STR          Pointer to the current line (default: '>')
    --marker=STR           Multi-select marker (default: '>')
    --header=STR           String to print as header
    --header-lines=N       The first N lines of the input are treated as header
    --header-first         Print header before the prompt line
    --ellipsis=STR         Ellipsis to show when line is truncated (default: '..')

  Display
    --ansi                 Enable processing of ANSI color codes
    --tabstop=SPACES       Number of spaces for a tab character (default: 8)
    --color=COLSPEC        Base scheme (dark|light|16|bw) and/or custom colors
    --no-bold              Do not use bold text

  History
    --history=FILE         History file
    --history-size=N       Maximum number of history entries (default: 1000)

  Preview
    --preview=COMMAND      Command to preview highlighted line ({})
    --preview-window=OPT   Preview window layout (default: right:50%)
                           [up|down|left|right][,SIZE[%]]
                           [,[no]wrap][,[no]cycle][,[no]follow][,[no]hidden]
                           [,border-BORDER_OPT]
                           [,+SCROLL[OFFSETS][/DENOM]][,~HEADER_LINES]
                           [,default][,<SIZE_THRESHOLD(ALTERNATIVE_LAYOUT)]
    --preview-label=LABEL
    --preview-label-pos=N  Same as --border-label and --border-label-pos,
                           but for preview window

  Scripting
    -q, --query=STR        Start the finder with the given query
    -1, --select-1         Automatically select the only match
    -0, --exit-0           Exit immediately when there's no match
    -f, --filter=STR       Filter mode. Do not start interactive finder.
    --print-query          Print query as the first line
    --expect=KEYS          Comma-separated list of keys to complete fzf
    --read0                Read input delimited by ASCII NUL characters
    --print0               Print output delimited by ASCII NUL characters
    --sync                 Synchronous search for multi-staged filtering
    --listen[=[ADDR:]PORT] Start HTTP server to receive actions (POST /)
                           (To allow remote process execution, use --listen-unsafe)
    --version              Display version information and exit

  Environment variables
    FZF_DEFAULT_COMMAND    Default command to use when input is tty
    FZF_DEFAULT_OPTS       Default options
                           (e.g. '--layout=reverse --inline-info')
    FZF_API_KEY            X-API-Key header for HTTP server (--listen)


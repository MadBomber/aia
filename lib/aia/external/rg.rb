# lib/aia/external/rg.rb

class AIA::External::Rg < AIA::External::Tool
  def initialize
    super
    @role     = :search
    @desc     = "Search tool like grep and The Silver Searcher"
    @url      = "https://github.com/BurntSushi/ripgrep"
  end

  def command(search_term, options = {})
    rg_command = "rg --color=always --line-number --no-heading --smart-case #{search_term}"
    "#{rg_command} | fzf #{options[:fzf_options]}"
  end
end

__END__

ripgrep 13.0.0
Andrew Gallant <jamslam@gmail.com>

ripgrep (rg) recursively searches the current directory for a regex pattern.
By default, ripgrep will respect gitignore rules and automatically skip hidden
files/directories and binary files.

Use -h for short descriptions and --help for more details.

Project home page: https://github.com/BurntSushi/ripgrep


USAGE:
    rg [OPTIONS] PATTERN [PATH ...]
    rg [OPTIONS] -e PATTERN ... [PATH ...]
    rg [OPTIONS] -f PATTERNFILE ... [PATH ...]
    rg [OPTIONS] --files [PATH ...]
    rg [OPTIONS] --type-list
    command | rg [OPTIONS] PATTERN
    rg [OPTIONS] --help
    rg [OPTIONS] --version

ARGS:
    <PATTERN>    
            A regular expression used for searching. To match a pattern beginning with a
            dash, use the -e/--regexp flag.
            
            For example, to search for the literal '-foo', you can use this flag:
            
                rg -e -foo
            
            You can also use the special '--' delimiter to indicate that no more flags
            will be provided. Namely, the following is equivalent to the above:
            
                rg -- -foo
             
    <PATH>...    
            A file or directory to search. Directories are searched recursively. File paths
            specified on the command line override glob and ignore rules.  

OPTIONS:
    -A, --after-context <NUM>                    
            Show NUM lines after each match.
            
            This overrides the --context and --passthru flags.
             
        --auto-hybrid-regex                      
            DEPRECATED. Use --engine instead.
            
            When this flag is used, ripgrep will dynamically choose between supported regex
            engines depending on the features used in a pattern. When ripgrep chooses a
            regex engine, it applies that choice for every regex provided to ripgrep (e.g.,
            via multiple -e/--regexp or -f/--file flags).
            
            As an example of how this flag might behave, ripgrep will attempt to use
            its default finite automata based regex engine whenever the pattern can be
            successfully compiled with that regex engine. If PCRE2 is enabled and if the
            pattern given could not be compiled with the default regex engine, then PCRE2
            will be automatically used for searching. If PCRE2 isn't available, then this
            flag has no effect because there is only one regex engine to choose from.
            
            In the future, ripgrep may adjust its heuristics for how it decides which
            regex engine to use. In general, the heuristics will be limited to a static
            analysis of the patterns, and not to any specific runtime behavior observed
            while searching files.
            
            The primary downside of using this flag is that it may not always be obvious
            which regex engine ripgrep uses, and thus, the match semantics or performance
            profile of ripgrep may subtly and unexpectedly change. However, in many cases,
            all regex engines will agree on what constitutes a match and it can be nice
            to transparently support more advanced regex features like look-around and
            backreferences without explicitly needing to enable them.
            
            This flag can be disabled with --no-auto-hybrid-regex.
             
    -B, --before-context <NUM>                   
            Show NUM lines before each match.
            
            This overrides the --context and --passthru flags.
             
        --binary                                 
            Enabling this flag will cause ripgrep to search binary files. By default,
            ripgrep attempts to automatically skip binary files in order to improve the
            relevance of results and make the search faster.
            
            Binary files are heuristically detected based on whether they contain a NUL
            byte or not. By default (without this flag set), once a NUL byte is seen,
            ripgrep will stop searching the file. Usually, NUL bytes occur in the beginning
            of most binary files. If a NUL byte occurs after a match, then ripgrep will
            still stop searching the rest of the file, but a warning will be printed.
            
            In contrast, when this flag is provided, ripgrep will continue searching a file
            even if a NUL byte is found. In particular, if a NUL byte is found then ripgrep
            will continue searching until either a match is found or the end of the file is
            reached, whichever comes sooner. If a match is found, then ripgrep will stop
            and print a warning saying that the search stopped prematurely.
            
            If you want ripgrep to search a file without any special NUL byte handling at
            all (and potentially print binary data to stdout), then you should use the
            '-a/--text' flag.
            
            The '--binary' flag is a flag for controlling ripgrep's automatic filtering
            mechanism. As such, it does not need to be used when searching a file
            explicitly or when searching stdin. That is, it is only applicable when
            recursively searching a directory.
            
            Note that when the '-u/--unrestricted' flag is provided for a third time, then
            this flag is automatically enabled.
            
            This flag can be disabled with '--no-binary'. It overrides the '-a/--text'
            flag.
             
        --block-buffered                         
            When enabled, ripgrep will use block buffering. That is, whenever a matching
            line is found, it will be written to an in-memory buffer and will not be
            written to stdout until the buffer reaches a certain size. This is the default
            when ripgrep's stdout is redirected to a pipeline or a file. When ripgrep's
            stdout is connected to a terminal, line buffering will be used. Forcing block
            buffering can be useful when dumping a large amount of contents to a terminal.
            
            Forceful block buffering can be disabled with --no-block-buffered. Note that
            using --no-block-buffered causes ripgrep to revert to its default behavior of
            automatically detecting the buffering strategy. To force line buffering, use
            the --line-buffered flag.
             
    -b, --byte-offset
            Print the 0-based byte offset within the input file before each line of output.
            If -o (--only-matching) is specified, print the offset of the matching part
            itself.
            
            If ripgrep does transcoding, then the byte offset is in terms of the the result
            of transcoding and not the original data. This applies similarly to another
            transformation on the source, such as decompression or a --pre filter. Note
            that when the PCRE2 regex engine is used, then UTF-8 transcoding is done by
            default.
             
    -s, --case-sensitive                         
            Search case sensitively.
            
            This overrides the -i/--ignore-case and -S/--smart-case flags.
             
        --color <WHEN>                           
            This flag controls when to use colors. The default setting is 'auto', which
            means ripgrep will try to guess when to use colors. For example, if ripgrep is
            printing to a terminal, then it will use colors, but if it is redirected to a
            file or a pipe, then it will suppress color output. ripgrep will suppress color
            output in some other circumstances as well. For example, if the TERM
            environment variable is not set or set to 'dumb', then ripgrep will not use
            colors.
            
            The possible values for this flag are:
            
                never    Colors will never be used.
                auto     The default. ripgrep tries to be smart.
                always   Colors will always be used regardless of where output is sent.
                ansi     Like 'always', but emits ANSI escapes (even in a Windows console).
            
            When the --vimgrep flag is given to ripgrep, then the default value for the
            --color flag changes to 'never'.
             
        --colors <COLOR_SPEC>...                 
            This flag specifies color settings for use in the output. This flag may be
            provided multiple times. Settings are applied iteratively. Colors are limited
            to one of eight choices: red, blue, green, cyan, magenta, yellow, white and
            black. Styles are limited to nobold, bold, nointense, intense, nounderline
            or underline.
            
            The format of the flag is '{type}:{attribute}:{value}'. '{type}' should be
            one of path, line, column or match. '{attribute}' can be fg, bg or style.
            '{value}' is either a color (for fg and bg) or a text style. A special format,
            '{type}:none', will clear all color settings for '{type}'.
            
            For example, the following command will change the match color to magenta and
            the background color for line numbers to yellow:
            
                rg --colors 'match:fg:magenta' --colors 'line:bg:yellow' foo.
            
            Extended colors can be used for '{value}' when the terminal supports ANSI color
            sequences. These are specified as either 'x' (256-color) or 'x,x,x' (24-bit
            truecolor) where x is a number between 0 and 255 inclusive. x may be given as
            a normal decimal number or a hexadecimal number, which is prefixed by `0x`.
            
            For example, the following command will change the match background color to
            that represented by the rgb value (0,128,255):
            
                rg --colors 'match:bg:0,128,255'
            
            or, equivalently,
            
                rg --colors 'match:bg:0x0,0x80,0xFF'
            
            Note that the the intense and nointense style flags will have no effect when
            used alongside these extended color codes.
             
        --column                                 
            Show column numbers (1-based). This only shows the column numbers for the first
            match on each line. This does not try to account for Unicode. One byte is equal
            to one column. This implies --line-number.
            
            This flag can be disabled with --no-column.
             
    -C, --context <NUM>                          
            Show NUM lines before and after each match. This is equivalent to providing
            both the -B/--before-context and -A/--after-context flags with the same value.
            
            This overrides both the -B/--before-context and -A/--after-context flags,
            in addition to the --passthru flag.
             
        --context-separator <SEPARATOR>          
            The string used to separate non-contiguous context lines in the output. This
            is only used when one of the context flags is used (-A, -B or -C). Escape
            sequences like \x7F or \t may be used. The default value is --.
            
            When the context separator is set to an empty string, then a line break
            is still inserted. To completely disable context separators, use the
            --no-context-separator flag.
             
    -c, --count
            This flag suppresses normal output and shows the number of lines that match
            the given patterns for each file searched. Each file containing a match has its
            path and count printed on each line. Note that this reports the number of lines
            that match and not the total number of matches, unless -U/--multiline is
            enabled. In multiline mode, --count is equivalent to --count-matches.
            
            If only one file is given to ripgrep, then only the count is printed if there
            is a match. The --with-filename flag can be used to force printing the file
            path in this case. If you need a count to be printed regardless of whether
            there is a match, then use --include-zero.
            
            This overrides the --count-matches flag. Note that when --count is combined
            with --only-matching, then ripgrep behaves as if --count-matches was given.
             
        --count-matches
            This flag suppresses normal output and shows the number of individual
            matches of the given patterns for each file searched. Each file
            containing matches has its path and match count printed on each line.
            Note that this reports the total number of individual matches and not
            the number of lines that match.
            
            If only one file is given to ripgrep, then only the count is printed if there
            is a match. The --with-filename flag can be used to force printing the file
            path in this case.
            
            This overrides the --count flag. Note that when --count is combined with
            --only-matching, then ripgrep behaves as if --count-matches was given.
             
        --crlf                                   
            When enabled, ripgrep will treat CRLF ('\r\n') as a line terminator instead
            of just '\n'.
            
            Principally, this permits '$' in regex patterns to match just before CRLF
            instead of just before LF. The underlying regex engine may not support this
            natively, so ripgrep will translate all instances of '$' to '(?:\r??$)'. This
            may produce slightly different than desired match offsets. It is intended as a
            work-around until the regex engine supports this natively.
            
            CRLF support can be disabled with --no-crlf.
             
        --debug                                  
            Show debug messages. Please use this when filing a bug report.
            
            The --debug flag is generally useful for figuring out why ripgrep skipped
            searching a particular file. The debug messages should mention all files
            skipped and why they were skipped.
            
            To get even more debug output, use the --trace flag, which implies --debug
            along with additional trace data. With --trace, the output could be quite
            large and is generally more useful for development.
             
        --dfa-size-limit <NUM+SUFFIX?>           
            The upper size limit of the regex DFA. The default limit is 10M. This should
            only be changed on very large regex inputs where the (slower) fallback regex
            engine may otherwise be used if the limit is reached.
            
            The argument accepts the same size suffixes as allowed in with the
            --max-filesize flag.
             
    -E, --encoding <ENCODING>                    
            Specify the text encoding that ripgrep will use on all files searched. The
            default value is 'auto', which will cause ripgrep to do a best effort automatic
            detection of encoding on a per-file basis. Automatic detection in this case
            only applies to files that begin with a UTF-8 or UTF-16 byte-order mark (BOM).
            No other automatic detection is performed. One can also specify 'none' which
            will then completely disable BOM sniffing and always result in searching the
            raw bytes, including a BOM if it's present, regardless of its encoding.
            
            Other supported values can be found in the list of labels here:
            https://encoding.spec.whatwg.org/#concept-encoding-get
            
            For more details on encoding and how ripgrep deals with it, see GUIDE.md.
            
            This flag can be disabled with --no-encoding.
             
        --engine <ENGINE>
            Specify which regular expression engine to use. When you choose a regex engine,
            it applies that choice for every regex provided to ripgrep (e.g., via multiple
            -e/--regexp or -f/--file flags).
            
            Accepted values are 'default', 'pcre2', or 'auto'.
            
            The default value is 'default', which is the fastest and should be good for
            most use cases. The 'pcre2' engine is generally useful when you want to use
            features such as look-around or backreferences. 'auto' will dynamically choose
            between supported regex engines depending on the features used in a pattern on
            a best effort basis.
            
            Note that the 'pcre2' engine is an optional ripgrep feature. If PCRE2 wasn't
            included in your build of ripgrep, then using this flag will result in ripgrep
            printing an error message and exiting.
            
            This overrides previous uses of --pcre2 and --auto-hybrid-regex flags.
              [default: default]
        --field-context-separator <SEPARATOR>    
            Set the field context separator, which is used to delimit file paths, line
            numbers, columns and the context itself, when printing contextual lines. The
            separator may be any number of bytes, including zero. Escape sequences like
            \x7F or \t may be used. The default value is -.
             
        --field-match-separator <SEPARATOR>      
            Set the field match separator, which is used to delimit file paths, line
            numbers, columns and the match itself. The separator may be any number of
            bytes, including zero. Escape sequences like \x7F or \t may be used. The
            default value is -.
             
    -f, --file <PATTERNFILE>...                  
            Search for patterns from the given file, with one pattern per line. When this
            flag is used multiple times or in combination with the -e/--regexp flag,
            then all patterns provided are searched. Empty pattern lines will match all
            input lines, and the newline is not counted as part of the pattern.
            
            A line is printed if and only if it matches at least one of the patterns.
             
        --files                                  
            Print each file that would be searched without actually performing the search.
            This is useful to determine whether a particular file is being searched or not.
             
    -l, --files-with-matches                     
            Print the paths with at least one match and suppress match contents.
            
            This overrides --files-without-match.
             
        --files-without-match                    
            Print the paths that contain zero matches and suppress match contents. This
            inverts/negates the --files-with-matches flag.
            
            This overrides --files-with-matches.
             
    -F, --fixed-strings                          
            Treat the pattern as a literal string instead of a regular expression. When
            this flag is used, special regular expression meta characters such as .(){}*+
            do not need to be escaped.
            
            This flag can be disabled with --no-fixed-strings.
             
    -L, --follow                                 
            When this flag is enabled, ripgrep will follow symbolic links while traversing
            directories. This is disabled by default. Note that ripgrep will check for
            symbolic link loops and report errors if it finds one.
            
            This flag can be disabled with --no-follow.
             
    -g, --glob <GLOB>...                         
            Include or exclude files and directories for searching that match the given
            glob. This always overrides any other ignore logic. Multiple glob flags may be
            used. Globbing rules match .gitignore globs. Precede a glob with a ! to exclude
            it. If multiple globs match a file or directory, the glob given later in the
            command line takes precedence.
            
            As an extension, globs support specifying alternatives: *-g ab{c,d}* is
            equivalet to *-g abc -g abd*. Empty alternatives like *-g ab{,c}* are not
            currently supported. Note that this syntax extension is also currently enabled
            in gitignore files, even though this syntax isn't supported by git itself.
            ripgrep may disable this syntax extension in gitignore files, but it will
            always remain available via the -g/--glob flag.
            
            When this flag is set, every file and directory is applied to it to test for
            a match. So for example, if you only want to search in a particular directory
            'foo', then *-g foo* is incorrect because 'foo/bar' does not match the glob
            'foo'. Instead, you should use *-g 'foo/**'*.
             
        --glob-case-insensitive                  
            Process glob patterns given with the -g/--glob flag case insensitively. This
            effectively treats --glob as --iglob.
            
            This flag can be disabled with the --no-glob-case-insensitive flag.
             
    -h, --help
            Prints help information. Use --help for more details.

        --heading                                
            This flag prints the file path above clusters of matches from each file instead
            of printing the file path as a prefix for each matched line. This is the
            default mode when printing to a terminal.
            
            This overrides the --no-heading flag.
             
    -., --hidden                                 
            Search hidden files and directories. By default, hidden files and directories
            are skipped. Note that if a hidden file or a directory is whitelisted in an
            ignore file, then it will be searched even if this flag isn't provided.
            
            A file or directory is considered hidden if its base name starts with a dot
            character ('.'). On operating systems which support a `hidden` file attribute,
            like Windows, files with this attribute are also considered hidden.
            
            This flag can be disabled with --no-hidden.
             
        --iglob <GLOB>...                        
            Include or exclude files and directories for searching that match the given
            glob. This always overrides any other ignore logic. Multiple glob flags may be
            used. Globbing rules match .gitignore globs. Precede a glob with a ! to exclude
            it. Globs are matched case insensitively.
             
    -i, --ignore-case                            
            When this flag is provided, the given patterns will be searched case
            insensitively. The case insensitivity rules used by ripgrep conform to
            Unicode's "simple" case folding rules.
            
            This flag overrides -s/--case-sensitive and -S/--smart-case.
             
        --ignore-file <PATH>...                  
            Specifies a path to one or more .gitignore format rules files. These patterns
            are applied after the patterns found in .gitignore and .ignore are applied
            and are matched relative to the current working directory. Multiple additional
            ignore files can be specified by using the --ignore-file flag several times.
            When specifying multiple ignore files, earlier files have lower precedence
            than later files.
            
            If you are looking for a way to include or exclude files and directories
            directly on the command line, then used -g instead.
             
        --ignore-file-case-insensitive           
            Process ignore files (.gitignore, .ignore, etc.) case insensitively. Note that
            this comes with a performance penalty and is most useful on case insensitive
            file systems (such as Windows).
            
            This flag can be disabled with the --no-ignore-file-case-insensitive flag.
             
        --include-zero                           
            When used with --count or --count-matches, print the number of matches for
            each file even if there were zero matches. This is disabled by default but can
            be enabled to make ripgrep behave more like grep.
             
    -v, --invert-match                           
            Invert matching. Show lines that do not match the given patterns.
             
        --json                                   
            Enable printing results in a JSON Lines format.
            
            When this flag is provided, ripgrep will emit a sequence of messages, each
            encoded as a JSON object, where there are five different message types:
            
            **begin** - A message that indicates a file is being searched and contains at
            least one match.
            
            **end** - A message the indicates a file is done being searched. This message
            also include summary statistics about the search for a particular file.
            
            **match** - A message that indicates a match was found. This includes the text
            and offsets of the match.
            
            **context** - A message that indicates a contextual line was found. This
            includes the text of the line, along with any match information if the search
            was inverted.
            
            **summary** - The final message emitted by ripgrep that contains summary
            statistics about the search across all files.
            
            Since file paths or the contents of files are not guaranteed to be valid UTF-8
            and JSON itself must be representable by a Unicode encoding, ripgrep will emit
            all data elements as objects with one of two keys: 'text' or 'bytes'. 'text' is
            a normal JSON string when the data is valid UTF-8 while 'bytes' is the base64
            encoded contents of the data.
            
            The JSON Lines format is only supported for showing search results. It cannot
            be used with other flags that emit other types of output, such as --files,
            --files-with-matches, --files-without-match, --count or --count-matches.
            ripgrep will report an error if any of the aforementioned flags are used in
            concert with --json.
            
            Other flags that control aspects of the standard output such as
            --only-matching, --heading, --replace, --max-columns, etc., have no effect
            when --json is set.
            
            A more complete description of the JSON format used can be found here:
            https://docs.rs/grep-printer/*/grep_printer/struct.JSON.html
            
            The JSON Lines format can be disabled with --no-json.
             
        --line-buffered                          
            When enabled, ripgrep will use line buffering. That is, whenever a matching
            line is found, it will be flushed to stdout immediately. This is the default
            when ripgrep's stdout is connected to a terminal, but otherwise, ripgrep will
            use block buffering, which is typically faster. This flag forces ripgrep to
            use line buffering even if it would otherwise use block buffering. This is
            typically useful in shell pipelines, e.g.,
            'tail -f something.log | rg foo --line-buffered | rg bar'.
            
            Forceful line buffering can be disabled with --no-line-buffered. Note that
            using --no-line-buffered causes ripgrep to revert to its default behavior of
            automatically detecting the buffering strategy. To force block buffering, use
            the --block-buffered flag.
             
    -n, --line-number                            
            Show line numbers (1-based). This is enabled by default when searching in a
            terminal.
             
    -x, --line-regexp                            
            Only show matches surrounded by line boundaries. This is equivalent to putting
            ^...$ around all of the search patterns. In other words, this only prints lines
            where the entire line participates in a match.
            
            This overrides the --word-regexp flag.
             
    -M, --max-columns <NUM>                      
            Don't print lines longer than this limit in bytes. Longer lines are omitted,
            and only the number of matches in that line is printed.
            
            When this flag is omitted or is set to 0, then it has no effect.
             
        --max-columns-preview                    
            When the '--max-columns' flag is used, ripgrep will by default completely
            replace any line that is too long with a message indicating that a matching
            line was removed. When this flag is combined with '--max-columns', a preview
            of the line (corresponding to the limit size) is shown instead, where the part
            of the line exceeding the limit is not shown.
            
            If the '--max-columns' flag is not set, then this has no effect.
            
            This flag can be disabled with '--no-max-columns-preview'.
             
    -m, --max-count <NUM>                        
            Limit the number of matching lines per file searched to NUM.
             
        --max-depth <NUM>                        
            Limit the depth of directory traversal to NUM levels beyond the paths given. A
            value of zero only searches the explicitly given paths themselves.
            
            For example, 'rg --max-depth 0 dir/' is a no-op because dir/ will not be
            descended into. 'rg --max-depth 1 dir/' will search only the direct children of
            'dir'.
             
        --max-filesize <NUM+SUFFIX?>             
            Ignore files larger than NUM in size. This does not apply to directories.
            
            The input format accepts suffixes of K, M or G which correspond to kilobytes,
            megabytes and gigabytes, respectively. If no suffix is provided the input is
            treated as bytes.
            
            Examples: --max-filesize 50K or --max-filesize 80M
             
        --mmap                                   
            Search using memory maps when possible. This is enabled by default when ripgrep
            thinks it will be faster.
            
            Memory map searching doesn't currently support all options, so if an
            incompatible option (e.g., --context) is given with --mmap, then memory maps
            will not be used.
            
            Note that ripgrep may abort unexpectedly when --mmap if it searches a file that
            is simultaneously truncated.
            
            This flag overrides --no-mmap.
             
    -U, --multiline                              
            Enable matching across multiple lines.
            
            When multiline mode is enabled, ripgrep will lift the restriction that a match
            cannot include a line terminator. For example, when multiline mode is not
            enabled (the default), then the regex '\p{any}' will match any Unicode
            codepoint other than '\n'. Similarly, the regex '\n' is explicitly forbidden,
            and if you try to use it, ripgrep will return an error. However, when multiline
            mode is enabled, '\p{any}' will match any Unicode codepoint, including '\n',
            and regexes like '\n' are permitted.
            
            An important caveat is that multiline mode does not change the match semantics
            of '.'. Namely, in most regex matchers, a '.' will by default match any
            character other than '\n', and this is true in ripgrep as well. In order to
            make '.' match '\n', you must enable the "dot all" flag inside the regex.
            For example, both '(?s).' and '(?s:.)' have the same semantics, where '.' will
            match any character, including '\n'. Alternatively, the '--multiline-dotall'
            flag may be passed to make the "dot all" behavior the default. This flag only
            applies when multiline search is enabled.
            
            There is no limit on the number of the lines that a single match can span.
            
            **WARNING**: Because of how the underlying regex engine works, multiline
            searches may be slower than normal line-oriented searches, and they may also
            use more memory. In particular, when multiline mode is enabled, ripgrep
            requires that each file it searches is laid out contiguously in memory
            (either by reading it onto the heap or by memory-mapping it). Things that
            cannot be memory-mapped (such as stdin) will be consumed until EOF before
            searching can begin. In general, ripgrep will only do these things when
            necessary. Specifically, if the --multiline flag is provided but the regex
            does not contain patterns that would match '\n' characters, then ripgrep
            will automatically avoid reading each file into memory before searching it.
            Nevertheless, if you only care about matches spanning at most one line, then it
            is always better to disable multiline mode.
            
            This flag can be disabled with --no-multiline.
             
        --multiline-dotall                       
            This flag enables "dot all" in your regex pattern, which causes '.' to match
            newlines when multiline searching is enabled. This flag has no effect if
            multiline searching isn't enabled with the --multiline flag.
            
            Normally, a '.' will match any character except newlines. While this behavior
            typically isn't relevant for line-oriented matching (since matches can span at
            most one line), this can be useful when searching with the -U/--multiline flag.
            By default, the multiline mode runs without this flag.
            
            This flag is generally intended to be used in an alias or your ripgrep config
            file if you prefer "dot all" semantics by default. Note that regardless of
            whether this flag is used, "dot all" semantics can still be controlled via
            inline flags in the regex pattern itself, e.g., '(?s:.)' always enables "dot
            all" whereas '(?-s:.)' always disables "dot all".
            
            This flag can be disabled with --no-multiline-dotall.
             
        --no-config                              
            Never read configuration files. When this flag is present, ripgrep will not
            respect the RIPGREP_CONFIG_PATH environment variable.
            
            If ripgrep ever grows a feature to automatically read configuration files in
            pre-defined locations, then this flag will also disable that behavior as well.
             
    -I, --no-filename                            
            Never print the file path with the matched lines. This is the default when
            ripgrep is explicitly instructed to search one file or stdin.
            
            This flag overrides --with-filename.
             
        --no-heading                             
            Don't group matches by each file. If --no-heading is provided in addition to
            the -H/--with-filename flag, then file paths will be printed as a prefix for
            every matched line. This is the default mode when not printing to a terminal.
            
            This overrides the --heading flag.
             
        --no-ignore                              
            Don't respect ignore files (.gitignore, .ignore, etc.). This implies
            --no-ignore-dot, --no-ignore-exclude, --no-ignore-global, no-ignore-parent and
            --no-ignore-vcs.
            
            This does *not* imply --no-ignore-files, since --ignore-file is specified
            explicitly as a command line argument.
            
            When given only once, the -u flag is identical in behavior to --no-ignore and
            can be considered an alias. However, subsequent -u flags have additional
            effects; see --unrestricted.
            
            This flag can be disabled with the --ignore flag.
             
        --no-ignore-dot                          
            Don't respect .ignore files.
            
            This does *not* affect whether ripgrep will ignore files and directories
            whose names begin with a dot. For that, see the -./--hidden flag.
            
            This flag can be disabled with the --ignore-dot flag.
             
        --no-ignore-exclude                      
            Don't respect ignore files that are manually configured for the repository
            such as git's '.git/info/exclude'.
            
            This flag can be disabled with the --ignore-exclude flag.
             
        --no-ignore-files                        
            When set, any --ignore-file flags, even ones that come after this flag, are
            ignored.
            
            This flag can be disabled with the --ignore-files flag.
             
        --no-ignore-global                       
            Don't respect ignore files that come from "global" sources such as git's
            `core.excludesFile` configuration option (which defaults to
            `$HOME/.config/git/ignore`).
            
            This flag can be disabled with the --ignore-global flag.
             
        --no-ignore-messages                     
            Suppresses all error messages related to parsing ignore files such as .ignore
            or .gitignore.
            
            This flag can be disabled with the --ignore-messages flag.
             
        --no-ignore-parent                       
            Don't respect ignore files (.gitignore, .ignore, etc.) in parent directories.
            
            This flag can be disabled with the --ignore-parent flag.
             
        --no-ignore-vcs                          
            Don't respect version control ignore files (.gitignore, etc.). This implies
            --no-ignore-parent for VCS files. Note that .ignore files will continue to be
            respected.
            
            This flag can be disabled with the --ignore-vcs flag.
             
    -N, --no-line-number                         
            Suppress line numbers. This is enabled by default when not searching in a
            terminal.
             
        --no-messages                            
            Suppress all error messages related to opening and reading files. Error
            messages related to the syntax of the pattern given are still shown.
            
            This flag can be disabled with the --messages flag.
             
        --no-mmap                                
            Never use memory maps, even when they might be faster.
            
            This flag overrides --mmap.
             
        --no-pcre2-unicode                       
            DEPRECATED. Use --no-unicode instead.
            
            This flag is now an alias for --no-unicode. And --pcre2-unicode is an alias
            for --unicode.
             
        --no-require-git                         
            By default, ripgrep will only respect global gitignore rules, .gitignore rules
            and local exclude rules if ripgrep detects that you are searching inside a
            git repository. This flag allows you to relax this restriction such that
            ripgrep will respect all git related ignore rules regardless of whether you're
            searching in a git repository or not.
            
            This flag can be disabled with --require-git.
             
        --no-unicode                             
            By default, ripgrep will enable "Unicode mode" in all of its regexes. This
            has a number of consequences:
            
            * '.' will only match valid UTF-8 encoded scalar values.
            * Classes like '\w', '\s', '\d' are all Unicode aware and much bigger
              than their ASCII only versions.
            * Case insensitive matching will use Unicode case folding.
            * A large array of classes like '\p{Emoji}' are available.
            * Word boundaries ('\b' and '\B') use the Unicode definition of a word
              character.
            
            In some cases it can be desirable to turn these things off. The --no-unicode
            flag will do exactly that.
            
            For PCRE2 specifically, Unicode mode represents a critical trade off in the
            user experience of ripgrep. In particular, unlike the default regex engine,
            PCRE2 does not support the ability to search possibly invalid UTF-8 with
            Unicode features enabled. Instead, PCRE2 *requires* that everything it searches
            when Unicode mode is enabled is valid UTF-8. (Or valid UTF-16/UTF-32, but for
            the purposes of ripgrep, we only discuss UTF-8.) This means that if you have
            PCRE2's Unicode mode enabled and you attempt to search invalid UTF-8, then
            the search for that file will halt and print an error. For this reason, when
            PCRE2's Unicode mode is enabled, ripgrep will automatically "fix" invalid
            UTF-8 sequences by replacing them with the Unicode replacement codepoint. This
            penalty does not occur when using the default regex engine.
            
            If you would rather see the encoding errors surfaced by PCRE2 when Unicode mode
            is enabled, then pass the --no-encoding flag to disable all transcoding.
            
            The --no-unicode flag can be disabled with --unicode. Note that
            --no-pcre2-unicode and --pcre2-unicode are aliases for --no-unicode and
            --unicode, respectively.
             
    -0, --null                                   
            Whenever a file path is printed, follow it with a NUL byte. This includes
            printing file paths before matches, and when printing a list of matching files
            such as with --count, --files-with-matches and --files. This option is useful
            for use with xargs.
             
        --null-data                              
            Enabling this option causes ripgrep to use NUL as a line terminator instead of
            the default of '\n'.
            
            This is useful when searching large binary files that would otherwise have very
            long lines if '\n' were used as the line terminator. In particular, ripgrep
            requires that, at a minimum, each line must fit into memory. Using NUL instead
            can be a useful stopgap to keep memory requirements low and avoid OOM (out of
            memory) conditions.
            
            This is also useful for processing NUL delimited data, such as that emitted
            when using ripgrep's -0/--null flag or find's --print0 flag.
            
            Using this flag implies -a/--text.
             
        --one-file-system
            When enabled, ripgrep will not cross file system boundaries relative to where
            the search started from.
            
            Note that this applies to each path argument given to ripgrep. For example, in
            the command 'rg --one-file-system /foo/bar /quux/baz', ripgrep will search both
            '/foo/bar' and '/quux/baz' even if they are on different file systems, but will
            not cross a file system boundary when traversing each path's directory tree.
            
            This is similar to find's '-xdev' or '-mount' flag.
            
            This flag can be disabled with --no-one-file-system.
             
    -o, --only-matching                          
            Print only the matched (non-empty) parts of a matching line, with each such
            part on a separate output line.
             
        --passthru                               
            Print both matching and non-matching lines.
            
            Another way to achieve a similar effect is by modifying your pattern to match
            the empty string. For example, if you are searching using 'rg foo' then using
            'rg "^|foo"' instead will emit every line in every file searched, but only
            occurrences of 'foo' will be highlighted. This flag enables the same behavior
            without needing to modify the pattern.
            
            This overrides the --context, --after-context and --before-context flags.
             
        --path-separator <SEPARATOR>             
            Set the path separator to use when printing file paths. This defaults to your
            platform's path separator, which is / on Unix and \ on Windows. This flag is
            intended for overriding the default when the environment demands it (e.g.,
            cygwin). A path separator is limited to a single byte.
             
    -P, --pcre2                                  
            When this flag is present, ripgrep will use the PCRE2 regex engine instead of
            its default regex engine.
            
            This is generally useful when you want to use features such as look-around
            or backreferences.
            
            Note that PCRE2 is an optional ripgrep feature. If PCRE2 wasn't included in
            your build of ripgrep, then using this flag will result in ripgrep printing
            an error message and exiting. PCRE2 may also have worse user experience in
            some cases, since it has fewer introspection APIs than ripgrep's default regex
            engine. For example, if you use a '\n' in a PCRE2 regex without the
            '-U/--multiline' flag, then ripgrep will silently fail to match anything
            instead of reporting an error immediately (like it does with the default
            regex engine).
            
            Related flags: --no-pcre2-unicode
            
            This flag can be disabled with --no-pcre2.
             
        --pcre2-version                          
            When this flag is present, ripgrep will print the version of PCRE2 in use,
            along with other information, and then exit. If PCRE2 is not available, then
            ripgrep will print an error message and exit with an error code.
             
        --pre <COMMAND>                          
            For each input FILE, search the standard output of COMMAND FILE rather than the
            contents of FILE. This option expects the COMMAND program to either be an
            absolute path or to be available in your PATH. Either an empty string COMMAND
            or the '--no-pre' flag will disable this behavior.
            
                WARNING: When this flag is set, ripgrep will unconditionally spawn a
                process for every file that is searched. Therefore, this can incur an
                unnecessarily large performance penalty if you don't otherwise need the
                flexibility offered by this flag. One possible mitigation to this is to use
                the '--pre-glob' flag to limit which files a preprocessor is run with.
            
            A preprocessor is not run when ripgrep is searching stdin.
            
            When searching over sets of files that may require one of several decoders
            as preprocessors, COMMAND should be a wrapper program or script which first
            classifies FILE based on magic numbers/content or based on the FILE name and
            then dispatches to an appropriate preprocessor. Each COMMAND also has its
            standard input connected to FILE for convenience.
            
            For example, a shell script for COMMAND might look like:
            
                case "$1" in
                *.pdf)
                    exec pdftotext "$1" -
                    ;;
                *)
                    case $(file "$1") in
                    *Zstandard*)
                        exec pzstd -cdq
                        ;;
                    *)
                        exec cat
                        ;;
                    esac
                    ;;
                esac
            
            The above script uses `pdftotext` to convert a PDF file to plain text. For
            all other files, the script uses the `file` utility to sniff the type of the
            file based on its contents. If it is a compressed file in the Zstandard format,
            then `pzstd` is used to decompress the contents to stdout.
            
            This overrides the -z/--search-zip flag.
             
        --pre-glob <GLOB>...
            This flag works in conjunction with the --pre flag. Namely, when one or more
            --pre-glob flags are given, then only files that match the given set of globs
            will be handed to the command specified by the --pre flag. Any non-matching
            files will be searched without using the preprocessor command.
            
            This flag is useful when searching many files with the --pre flag. Namely,
            it permits the ability to avoid process overhead for files that don't need
            preprocessing. For example, given the following shell script, 'pre-pdftotext':
            
                #!/bin/sh
            
                pdftotext "$1" -
            
            then it is possible to use '--pre pre-pdftotext --pre-glob '*.pdf'' to make
            it so ripgrep only executes the 'pre-pdftotext' command on files with a '.pdf'
            extension.
            
            Multiple --pre-glob flags may be used. Globbing rules match .gitignore globs.
            Precede a glob with a ! to exclude it.
            
            This flag has no effect if the --pre flag is not used.
             
    -p, --pretty                                 
            This is a convenience alias for '--color always --heading --line-number'. This
            flag is useful when you still want pretty output even if you're piping ripgrep
            to another program or file. For example: 'rg -p foo | less -R'.
             
    -q, --quiet                                  
            Do not print anything to stdout. If a match is found in a file, then ripgrep
            will stop searching. This is useful when ripgrep is used only for its exit
            code (which will be an error if no matches are found).
            
            When --files is used, then ripgrep will stop finding files after finding the
            first file that matches all ignore rules.
             
        --regex-size-limit <NUM+SUFFIX?>         
            The upper size limit of the compiled regex. The default limit is 10M.
            
            The argument accepts the same size suffixes as allowed in the --max-filesize
            flag.
             
    -e, --regexp <PATTERN>...                    
            A pattern to search for. This option can be provided multiple times, where
            all patterns given are searched. Lines matching at least one of the provided
            patterns are printed. This flag can also be used when searching for patterns
            that start with a dash.
            
            For example, to search for the literal '-foo', you can use this flag:
            
                rg -e -foo
            
            You can also use the special '--' delimiter to indicate that no more flags
            will be provided. Namely, the following is equivalent to the above:
            
                rg -- -foo
             
    -r, --replace <REPLACEMENT_TEXT>             
            Replace every match with the text given when printing results. Neither this
            flag nor any other ripgrep flag will modify your files.
            
            Capture group indices (e.g., $5) and names (e.g., $foo) are supported in the
            replacement string. Capture group indices are numbered based on the position of
            the opening parenthesis of the group, where the leftmost such group is $1. The
            special $0 group corresponds to the entire match.
            
            In shells such as Bash and zsh, you should wrap the pattern in single quotes
            instead of double quotes. Otherwise, capture group indices will be replaced by
            expanded shell variables which will most likely be empty.
            
            To write a literal '$', use '$$'.
            
            Note that the replacement by default replaces each match, and NOT the entire
            line. To replace the entire line, you should match the entire line.
            
            This flag can be used with the -o/--only-matching flag.
             
    -z, --search-zip                             
            Search in compressed files. Currently gzip, bzip2, xz, LZ4, LZMA, Brotli and
            Zstd files are supported. This option expects the decompression binaries to be
            available in your PATH.
            
            This flag can be disabled with --no-search-zip.
             
    -S, --smart-case                             
            Searches case insensitively if the pattern is all lowercase. Search case
            sensitively otherwise.
            
            A pattern is considered all lowercase if both of the following rules hold:
            
            First, the pattern contains at least one literal character. For example, 'a\w'
            contains a literal ('a') but just '\w' does not.
            
            Second, of the literals in the pattern, none of them are considered to be
            uppercase according to Unicode. For example, 'foo\pL' has no uppercase
            literals but 'Foo\pL' does.
            
            This overrides the -s/--case-sensitive and -i/--ignore-case flags.
             
        --sort <SORTBY>
            This flag enables sorting of results in ascending order. The possible values
            for this flag are:
            
                none      (Default) Do not sort results. Fastest. Can be multi-threaded.
                path      Sort by file path. Always single-threaded.
                modified  Sort by the last modified time on a file. Always single-threaded.
                accessed  Sort by the last accessed time on a file. Always single-threaded.
                created   Sort by the creation time on a file. Always single-threaded.
            
            If the chosen (manually or by-default) sorting criteria isn't available on your
            system (for example, creation time is not available on ext4 file systems), then
            ripgrep will attempt to detect this, print an error and exit without searching.
            
            To sort results in reverse or descending order, use the --sortr flag. Also,
            this flag overrides --sortr.
            
            Note that sorting results currently always forces ripgrep to abandon
            parallelism and run in a single thread.
             
        --sortr <SORTBY>
            This flag enables sorting of results in descending order. The possible values
            for this flag are:
            
                none      (Default) Do not sort results. Fastest. Can be multi-threaded.
                path      Sort by file path. Always single-threaded.
                modified  Sort by the last modified time on a file. Always single-threaded.
                accessed  Sort by the last accessed time on a file. Always single-threaded.
                created   Sort by the creation time on a file. Always single-threaded.
            
            If the chosen (manually or by-default) sorting criteria isn't available on your
            system (for example, creation time is not available on ext4 file systems), then
            ripgrep will attempt to detect this, print an error and exit without searching.
            
            To sort results in ascending order, use the --sort flag. Also, this flag
            overrides --sort.
            
            Note that sorting results currently always forces ripgrep to abandon
            parallelism and run in a single thread.
             
        --stats                                  
            Print aggregate statistics about this ripgrep search. When this flag is
            present, ripgrep will print the following stats to stdout at the end of the
            search: number of matched lines, number of files with matches, number of files
            searched, and the time taken for the entire search to complete.
            
            This set of aggregate statistics may expand over time.
            
            Note that this flag has no effect if --files, --files-with-matches or
            --files-without-match is passed.
            
            This flag can be disabled with --no-stats.
             
    -a, --text                                   
            Search binary files as if they were text. When this flag is present, ripgrep's
            binary file detection is disabled. This means that when a binary file is
            searched, its contents may be printed if there is a match. This may cause
            escape codes to be printed that alter the behavior of your terminal.
            
            When binary file detection is enabled it is imperfect. In general, it uses
            a simple heuristic. If a NUL byte is seen during search, then the file is
            considered binary and search stops (unless this flag is present).
            Alternatively, if the '--binary' flag is used, then ripgrep will only quit
            when it sees a NUL byte after it sees a match (or searches the entire file).
            
            This flag can be disabled with '--no-text'. It overrides the '--binary' flag.
             
    -j, --threads <NUM>                          
            The approximate number of threads to use. A value of 0 (which is the default)
            causes ripgrep to choose the thread count using heuristics.
             
        --trim                                   
            When set, all ASCII whitespace at the beginning of each line printed will be
            trimmed.
            
            This flag can be disabled with --no-trim.
             
    -t, --type <TYPE>...                         
            Only search files matching TYPE. Multiple type flags may be provided. Use the
            --type-list flag to list all available types.
            
            This flag supports the special value 'all', which will behave as if --type
            was provided for every file type supported by ripgrep (including any custom
            file types). The end result is that '--type all' causes ripgrep to search in
            "whitelist" mode, where it will only search files it recognizes via its type
            definitions.
             
        --type-add <TYPE_SPEC>...                
            Add a new glob for a particular file type. Only one glob can be added at a
            time. Multiple --type-add flags can be provided. Unless --type-clear is used,
            globs are added to any existing globs defined inside of ripgrep.
            
            Note that this MUST be passed to every invocation of ripgrep. Type settings are
            NOT persisted. See CONFIGURATION FILES for a workaround.
            
            Example:
            
                rg --type-add 'foo:*.foo' -tfoo PATTERN.
            
            --type-add can also be used to include rules from other types with the special
            include directive. The include directive permits specifying one or more other
            type names (separated by a comma) that have been defined and its rules will
            automatically be imported into the type specified. For example, to create a
            type called src that matches C++, Python and Markdown files, one can use:
            
                --type-add 'src:include:cpp,py,md'
            
            Additional glob rules can still be added to the src type by using the
            --type-add flag again:
            
                --type-add 'src:include:cpp,py,md' --type-add 'src:*.foo'
            
            Note that type names must consist only of Unicode letters or numbers.
            Punctuation characters are not allowed.
             
        --type-clear <TYPE>...                   
            Clear the file type globs previously defined for TYPE. This only clears the
            default type definitions that are found inside of ripgrep.
            
            Note that this MUST be passed to every invocation of ripgrep. Type settings are
            NOT persisted. See CONFIGURATION FILES for a workaround.
             
        --type-list                              
            Show all supported file types and their corresponding globs.
             
    -T, --type-not <TYPE>...                     
            Do not search files matching TYPE. Multiple type-not flags may be provided. Use
            the --type-list flag to list all available types.
             
    -u, --unrestricted                           
            Reduce the level of "smart" searching. A single -u won't respect .gitignore
            (etc.) files (--no-ignore). Two -u flags will additionally search hidden files
            and directories (-./--hidden). Three -u flags will additionally search binary
            files (--binary).
            
            'rg -uuu' is roughly equivalent to 'grep -r'.
             
    -V, --version                                
            Prints version information

        --vimgrep                                
            Show results with every match on its own line, including line numbers and
            column numbers. With this option, a line with more than one match will be
            printed more than once.
             
    -H, --with-filename                          
            Display the file path for matches. This is the default when more than one
            file is searched. If --heading is enabled (the default when printing to a
            terminal), the file path will be shown above clusters of matches from each
            file; otherwise, the file name will be shown as a prefix for each matched line.
            
            This flag overrides --no-filename.
             
    -w, --word-regexp                            
            Only show matches surrounded by word boundaries. This is roughly equivalent to
            putting \b before and after all of the search patterns.
            
            This overrides the --line-regexp flag.
             

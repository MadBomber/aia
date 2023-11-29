# lib/aia/external/ag.rb

class AIA::External::Ag < AIA::External::Tool
  def initialize
    super
    @role = :search
    @desc = "the_silver_searcher Code-search similar to ack"
    @url  = "https://github.com/ggreer/the_silver_searcher"
  end
end

__END__

Usage: ag [FILE-TYPE] [OPTIONS] PATTERN [PATH]

  Recursively search for PATTERN in PATH.
  Like grep or ack, but faster.

Example:
  ag -i foo /bar/

Output Options:
     --ackmate            Print results in AckMate-parseable format
  -A --after [LINES]      Print lines after match (Default: 2)
  -B --before [LINES]     Print lines before match (Default: 2)
     --[no]break          Print newlines between matches in different files
                          (Enabled by default)
  -c --count              Only print the number of matches in each file.
                          (This often differs from the number of matching lines)
     --[no]color          Print color codes in results (Enabled by default)
     --color-line-number  Color codes for line numbers (Default: 1;33)
     --color-match        Color codes for result match numbers (Default: 30;43)
     --color-path         Color codes for path names (Default: 1;32)
     --column             Print column numbers in results
     --[no]filename       Print file names (Enabled unless searching a single file)
  -H --[no]heading        Print file names before each file's matches
                          (Enabled by default)
  -C --context [LINES]    Print lines before and after matches (Default: 2)
     --[no]group          Same as --[no]break --[no]heading
  -g --filename-pattern PATTERN
                          Print filenames matching PATTERN
  -l --files-with-matches Only print filenames that contain matches
                          (don't print the matching lines)
  -L --files-without-matches
                          Only print filenames that don't contain matches
     --print-all-files    Print headings for all files searched, even those that
                          don't contain matches
     --[no]numbers        Print line numbers. Default is to omit line numbers
                          when searching streams
  -o --only-matching      Prints only the matching part of the lines
     --print-long-lines   Print matches on very long lines (Default: >2k characters)
     --passthrough        When searching a stream, print all lines even if they
                          don't match
     --silent             Suppress all log messages, including errors
     --stats              Print stats (files scanned, time taken, etc.)
     --stats-only         Print stats and nothing else.
                          (Same as --count when searching a single file)
     --vimgrep            Print results like vim's :vimgrep /pattern/g would
                          (it reports every match on the line)
  -0 --null --print0      Separate filenames with null (for 'xargs -0')

Search Options:
  -a --all-types          Search all files (doesn't include hidden files
                          or patterns from ignore files)
  -D --debug              Ridiculous debugging (probably not useful)
     --depth NUM          Search up to NUM directories deep (Default: 25)
  -f --follow             Follow symlinks
  -F --fixed-strings      Alias for --literal for compatibility with grep
  -G --file-search-regex  PATTERN Limit search to filenames matching PATTERN
     --hidden             Search hidden files (obeys .*ignore files)
  -i --ignore-case        Match case insensitively
     --ignore PATTERN     Ignore files/directories matching PATTERN
                          (literal file/directory names also allowed)
     --ignore-dir NAME    Alias for --ignore for compatibility with ack.
  -m --max-count NUM      Skip the rest of a file after NUM matches (Default: 10,000)
     --one-device         Don't follow links to other devices.
  -p --path-to-ignore STRING
                          Use .ignore file at STRING
  -Q --literal            Don't parse PATTERN as a regular expression
  -s --case-sensitive     Match case sensitively
  -S --smart-case         Match case insensitively unless PATTERN contains
                          uppercase characters (Enabled by default)
     --search-binary      Search binary files for matches
  -t --all-text           Search all text files (doesn't include hidden files)
  -u --unrestricted       Search all files (ignore .ignore, .gitignore, etc.;
                          searches binary and hidden files as well)
  -U --skip-vcs-ignores   Ignore VCS ignore files
                          (.gitignore, .hgignore; still obey .ignore)
  -v --invert-match
  -w --word-regexp        Only match whole words
  -W --width NUM          Truncate match lines after NUM characters
  -z --search-zip         Search contents of compressed (e.g., gzip) files

File Types:
The search can be restricted to certain types of files. Example:
  ag --html needle
  - Searches for 'needle' in files with suffix .htm, .html, .shtml or .xhtml.

For a list of supported file types run:
  ag --list-file-types

ag was originally created by Geoff Greer. More information (and the latest release)
can be found at http://geoff.greer.fm/ag

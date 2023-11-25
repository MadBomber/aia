# AI Assistant (AIA)

**Under Development**

`aia` is a command-line utility that integrates prameterized prompt management with generative AI (gen-AI) execution.

Uses the gem "prompt_manager" to manage the prompts sent to the `mods` command-line utility.  Uses the command line tools "ripgrep" to search for prompts to send and "fzf" to select the prompts that match the search term.



## Installation

Install the gem by executing:

    gem install aia


Install the command-line utilities by executing:

    brew install mods fzf ripgrep

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable named "PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts_dir"

You will also need to source the completion script.

TODO: May want to add a `setup` function to the command-line options that will create the directory, and do something with the completion function.

TODO: don't forget to mention have access token (API keys) setup as envars for the various backend services like OpenAI... if they are still in business.

## Usage

```text
$ aia --help

configuration v0.0.5

Usage:  aia [options] prompt_id [context_file]* [-- external_options+]

Options
-------

-e --edit Edit the Prompt File
-d --debug  Turn On Debugging
-v --verbose  Be Verbose
--version Print Version
-h --help Show Usage
--fuzzy Use Fuzzy Matching
-o --output --no-output Out FILENAME
-l --log --no-log Log FILEPATH
-m --markdown --no-markdown --md --no-md  Format with Markdown

Notes
-----

To install the external CLI programs used by configuration:
  brew install mods ripgrep fzf

fzf      Command-line fuzzy finder written in Go
         |__ https://github.com/junegunn/fzf

mods     AI on the command-line
         |__ https://github.com/charmbracelet/mods

ripgrep  Search tool like grep and The Silver Searcher
         |__ https://github.com/BurntSushi/ripgrep

```

TODO: Put default values ins usage text.

The `_prompts.log` file is also located in the `$PROMPTS_DIR`

The default output file is `temp.md` which is written to the current directory from which `aia` was executed.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

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

## Usage

`aia prompt_id [context_file]*`

`prompt_id` is the basename of the `prompt_id.txt` file that is located in the `$PROMPTS_DIR` directory.  There is also a `prompt_id.json` file saved in the same place to hold the last-used values (parameters) for the keywords (if any) found in your prompt file.

TODO: consider a config file.
TODO: consider a --no-log option to turn off logging

The `_prompts.log` file is also located in the `$PROMPTS_DIR`

TODO: show the usage help text

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

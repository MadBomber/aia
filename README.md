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

`aia prompt_id [context_file]*`

`prompt_id` is the basename of the `prompt_id.txt` file that is located in the `$PROMPTS_DIR` directory.  There is also a `prompt_id.json` file saved in the same place to hold the last-used values (parameters) for the keywords (if any) found in your prompt file.

TODO: consider a config file.
TODO: consider a --no-log option to turn off logging

The `_prompts.log` file is also located in the `$PROMPTS_DIR`

The default output file is `temp.md` which is written to the current directory from which `aia` was executed.


```text
$ aia -h
Use generative AI with saved parameterized prompts

Usage: aia [options] ...

Where:

  Common Options Are:
    -h, --help     show this message
    -v, --verbose  enable verbose mode
    -d, --debug    enable debug mode
    --version      print the version: 1.2.0

  Program Options Are:
    -f, --fuzzy    Allow fuzzy matching
    -o, --output   The output file

AI Assistant (aia)
==================

The AI cli program being used is: mods

The defaul options to mods are:
  "-m gpt-4-1106-preview --no-limit -f"

You can pass additional CLI options to mods like this:
  "aia my options -- options for mods"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

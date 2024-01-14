# AI Assistant (AIA)

`aia` is a command-line utility that facilitates interaction with AI models. It automates the management of pre-compositional prompts and executes generative AI (Gen-AI) commands on those prompts.

It leverages the `prompt_manager` gem to manage prompts for the `mods` and `sgpt` CLI utilities. It utilizes "ripgrep" for searching for prompt files.  It uses `fzf` for prompt selection based on a search term and fuzzy matching.

**Most Recent Change**: Refer to the [Changelog](CHANGELOG.md)

v0.5.0 - Breaking changes: 
- `--config` is now `--config_file`
- `--env` is now `--shell`
- `--output` is now `--out_file`

<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

  - [Installation](#installation)
  - [Usage](#usage)
  - [Configuration Using Envars](#configuration-using-envars)
  - [Shell Integration inside of a Prompt](#shell-integration-inside-of-a-prompt)
      - [Access to System Environment Variables](#access-to-system-environment-variables)
      - [Dynamic Shell Commands](#dynamic-shell-commands)
  - [*E*mbedded *R*u*B*y (ERB)](#embedded-ruby-erb)
  - [Prompt Directives](#prompt-directives)
    - [`aia` Specific Directive Commands](#aia-specific-directive-commands)
      - [//config](#config)
    - [Backend Directive Commands](#backend-directive-commands)
  - [All About ROLES](#all-about-roles)
    - [Other Ways to Insert Roles into Prompts](#other-ways-to-insert-roles-into-prompts)
  - [External CLI Tools Used](#external-cli-tools-used)
  - [Shell Completion](#shell-completion)
  - [My Most Powerful Prompt](#my-most-powerful-prompt)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)

<!-- Tocer[finish]: Auto-generated, don't remove. -->


## Installation

Install the gem by executing:

    gem install aia


Install the command-line utilities by executing:

    brew install mods fzf ripgrep

You will also need to establish a directory in your file system where your prompt text files, last used parameters and usage log files are kept.

Setup a system environment variable named "AIA_PROMPTS_DIR" that points to your prompts directory.  The default is in your HOME directory named ".prompts_dir"

You may also want to install the completion script for your shell.  To get a copy of the completion script do:

`aia --completion bash`

`fish` and `zsh` are also available.


## Usage

The usage report obtained using either `-h` or `--help` is implemented as a standard `man` page.  You can use both `--help --verbose` of `-h -v` together to get not only the `aia` man page but also the usage report from the `backend` LLM processing tool.

```text
$ aia --help

aia(1)                                   User Manuals                                  aia(1)

NAME
       aia - command-line interface for an AI assistant

SYNOPSIS
       aia [options]* PROMPT_ID [CONTEXT_FILE]* [-- EXTERNAL_OPTIONS+]

DESCRIPTION
       The aia command-line tool is an interface for interacting with an AI model backend,
       providing a simple way to send prompts and receive responses. The CLI supports various
       options to customize the interaction, load a configuration file, edit prompts, set
       debugging levels, and more.

ARGUMENTS
       PROMPT_ID
              This is a required argument.

       CONTEXT_FILES
              This is an optional argument.  One or more files can be added to the prompt as
              context for the backend gen-AI tool to process.

       EXTERNAL_OPTIONS
              External options are optional.  Anything that follow “ -- “ will be sent to the
              backend gen-AI tool.  For example “-- -C -m gpt4-128k” will send the options
              “-C -m gpt4-128k” to the backend gen-AI tool.  aia will not validate these
              external options before sending them to the backend gen-AI tool.

OPTIONS
       --chat begin a chat session with the backend after the initial prompt response;  will
              set --no-out_file so that the backend response comes to STDOUT.

       --completion SHELL_NAME

       --dump FORMAT

       -e, --edit
              Invokes an editor on the prompt file.  You can make changes to the prompt file,
              save it and the newly saved prompt will be processed by the backend.

       --shell
              This option tells aia to replace references to system environment variables in
              the prompt with the value of the envar.  envars are like $HOME and ${HOME} in
              this example their occurance will be replaced by the value of ENV[‘HOME’].
              Also the dynamic shell command in the pattern $(shell command) will be executed
              and its output replaces its pattern.  It does not matter if your shell uses
              different patters than BASH since the replacement is being done within a Ruby
              context.

       --erb  If dynamic prompt content using $(...) wasn’t enough here is ERB.  Embedded
              RUby.  <%= ruby code %> within a prompt will have its ruby code executed and
              the results of that execution will be inserted into the prompt.  I’m sure we
              will find a way to truly misuse this capability.  Remember, some say that the
              simple prompt is the best prompt.

       --model NAME
              Name of the LLM model to use - default is gpt-4-1106-preview

       --render
              Render markdown to the terminal using the external tool “glow” - default: false

       --speak
              Simple implementation. Uses the “say” command to speak the response.  Fun with
              --chat

       --terse
              Add a clause to the prompt text that instructs the backend to be terse in its
              response.

       --version
              Print Version - default is false

       -b, --[no]-backend LLM TOOL
              Specify the backend prompt resolver - default is mods

       -c, --config_file PATH_TO_CONFIG_FILE
              Load Config File - default is nil

       -d, --debug
              Turn On Debugging - default is false

       -e, --edit
              Edit the Prompt File - default is false

       -f, --fuzzy`
              Use Fuzzy Matching when searching for a prompt - default is false

       -h, --help
              Show Usage - default is false

       -l, --[no]-log_file PATH_TO_LOG_FILE
              Log FILEPATH - default is $HOME/.prompts/prompts.log

       -m, --[no]-markdown
              Format with Markdown - default is true

       -o, --[no]-out_file PATH_TO_OUTPUT_FILE
              Out FILENAME - default is ./temp.md

       -p, --prompts PATH_TO_DIRECTORY
              Directory containing the prompt files - default is ~/.prompts

       -r, --role ROLE_ID
              A role ID is the same as a prompt ID.  A “role” is a specialized prompt that
              gets pre-pended to another prompt.  It’s purpose is to configure the LLM into a
              certain orientation within which to resolve its primary prompt.

       -v, --verbose
              Be Verbose - default is false

CONFIGURATION HIERARCHY
       System Environment Variables (envars) that are all uppercase and begin with “AIA_” can
       be used to over-ride the default configuration settings.  For example setting “export
       AIA_PROMPTS_DIR=~/Documents/prompts” will over-ride the default configuration;
       however, a config value provided by a command line options will over-ride an envar
       setting.

       Configuration values found in a config file will over-ride all other values set for a
       config item.

       ”//config” directives found inside a prompt file over-rides that config item
       regardless of where the value was set.

       For example “//config chat? = true” within a prompt will setup the chat back and forth
       chat session for that specific prompt regardless of the command line options or the
       envar AIA_CHAT settings

OpenAI ACCOUNT IS REQUIRED
       Additionally, the program requires an OpenAI access key, which can be specified using
       one of the following environment variables:

              • OPENAI_ACCESS_TOKEN

              • OPENAI_API_KEY

       Currently there is not specific standard for name of the OpenAI key.  Some programs
       use one name, while others use a different name.  Both of the envars listed above mean
       the same thing.  If you use more than one tool to access OpenAI resources, you may
       have to set several envars to the same key value.

       To acquire an OpenAI access key, first create an account on the OpenAI platform, where
       further documentation is available.

USAGE NOTES
       aia is designed for flexibility, allowing users to pass prompt ids and context files
       as arguments. Some options change the behavior of the output, such as --out_file for
       specifying a file or --no-out_file for disabling file output in favor of standard
       output (STDPIT).

       The --completion option displays a script that enables prompt ID auto-completion for
       bash, zsh, or fish shells. It’s crucial to integrate the script into the shell’s
       runtime to take effect.

       The --dump options will send the current configuration to STDOUT in the format
       requested.  Both YAML and TOML formats are supported.

PROMPT DIRECTIVES
       Within a prompt text file any line that begins with “//” is considered a prompt
       directive.  There are numerious prompt directives available.  In the discussion above
       on the configuration you learned about the “//config” directive.

       Detail discussion on individual prompt directives is TBD.  Most likely it will be
       handled in the github wiki <https://github.com/MadBomber/aia>

SEE ALSO

              • OpenAI Platform Documentation <https://platform.openai.com/docs/overview>
                 for more information on obtaining access tokens
                <https://platform.openai.com/account/api-keys>
                 and working with OpenAI models.

              • mods <https://github.com/charmbracelet/mods>
                 for more information on mods - AI for the command line, built for pipelines.
                LLM based AI is really good at interpreting the output of commands and
                returning the results in CLI friendly text formats like Markdown. Mods is a
                simple tool that makes it super easy to use AI on the command line and in
                your pipelines. Mods works with OpenAI
                <https://platform.openai.com/account/api-keys>
                 and LocalAI <https://github.com/go-skynet/LocalAI>

              • sgpt <https://github.com/tbckr/sgpt>
                 (aka shell-gpt) is a powerful command-line interface (CLI) tool designed for
                seamless interaction with OpenAI models directly from your terminal.
                Effortlessly run queries, generate shell commands or code, create images from
                text, and more, using simple commands. Streamline your workflow and enhance
                productivity with this powerful and user-friendly CLI tool.

              • fzf <https://github.com/junegunn/fzf>
                 fzf is a general-purpose command-line fuzzy finder.  It’s an interactive
                Unix filter for command-line that can be used with any list; files, command
                history, processes, hostnames, bookmarks, git commits, etc.

              • ripgrep <https://github.com/BurntSushi/ripgrep>
                 Search tool like grep and The Silver Searcher. It is a line-oriented search
                tool that recursively searches a directory tree for a regex pattern. By
                default, ripgrep will respect gitignore rules and automatically skip hidden
                files/directories and binary files. (To disable all automatic filtering by
                default, use rg -uuu.) ripgrep has first class support on Windows, macOS and
                Linux, with binary downloads available for every release.

              • glow <https://github.com/charmbracelet/glow>
                 Render markdown on the CLI

AUTHOR
       Dewayne VanHoozer <dvanhoozer@gmail.com>

AIA                                       2024-01-01                                   aia(1)
```

## Configuration Using Envars

The `aia` configuration defaults can be over-ridden by system environment variables *(envars)* with the prefix "AIA_" followed by the config item name also in uppercase. All configuration items can be over-ridden in this way by an envar.  The following table show a few examples.

| Config Item   | Default Value | envar key |
| ------------- | ------------- | --------- |
| backend       | mods          | AIA_BACKEND |
| config_file   | nil           | AIA_CONFIG_FILE |
| debug         | false         | AIA_DEBUG |
| edit          | false         | AIA_EDIT |
| extra         | ''            | AIA_EXTRA |
| fuzzy         | false         | AIA_FUZZY |
| log_file      | ~/.prompts/_prompts.log | AIA_LOG_FILE |
| markdown      | true          | AIA_MARKDOWN |
| model         | gpt-4-1106-preview | AIA_MODEL |
| out_file       | STDOUT        | AIA_OUT_FILE |
| prompts_dir   | ~/.prompts    | AIA_PROMPTS_DIR |
| VERBOSE       | FALSE         | AIA_VERBOSE |


See the `@options` hash in the `cli.rb` file for a complete list.  There are some config items that do not necessarily make sense for use as an envar over-ride.  For example if you set `export AIA_DUMP=yaml` then `aia` would dump a config file in YAML format and exit every time it is ran until you finally did `unset AIA_DUMP`

In addition to these config items for `aia` the optional command line parameters for the backend prompt processing utilities (mods and sgpt) can also be set using envars with the "AIA_" prefix.  For example "export AIA_TOPP=1.0" will set the "--topp 1.0" command line option for the `mods` utility when its used as the backend processor.

## Shell Integration inside of a Prompt

Using the option `--shell` enables `aia` to access your terminal's shell environment from inside the prompt text.

#### Access to System Environment Variables

`aia` can replace any system environment variable (envar) references in the prompt text with the value of the envar.  Patterns like $USER and ${USER} in the prompt will be replaced with that envar's value - the name of the user's account.  Any envar can be used.

#### Dynamic Shell Commands

Dynamic content can be inserted into the prompt using the pattern $(shell command) where the output of the shell command will replace the $(...) pattern.

Consider the power to tailoring a prompt to your specific operating system:

```
As a system administration on a $(uname -v) platform what is the best way to [DO_SOMETHING]
```

or insert content from a file in your home directory:

```
Given the following constraints $(cat ~/3_laws_of_robotics.txt) determine the best way to instruct my roomba to clean my kids room.
```


## *E*mbedded *R*u*B*y (ERB)

The inclusion of dynamic content through the shell integration provided by the `--shell` option is significant.  `aia` also provides the full power of embedded Ruby code processing within the prompt text.

The `--erb` option turns the prompt text file into a fully functioning ERB template. The [Embedded Ruby (ERB) template syntax (2024)](https://bophin-com.ngontinh24.com/article/language-embedded-ruby-erb-template-syntax) provides a good overview of the syntax and power of ERB.

Most websites that have information about ERB will give examples of how to use ERB to generate dynamice HTML content for web-based applications.  That is a common use case for ERB.  `aia` on the other hand uses ERB to generate dynamic prompt text.


## Prompt Directives

Downstream processing directives were added to the `prompt_manager` gem used by `au` at version 0.4.1.  These directives are lines in the prompt text file that begin with "//" having this pattern:

```
//command parameters
```

There is no space between the "//" and the command.

### `aia` Specific Directive Commands

At this time `aia` only has one directive command `//config`

#### //config

The `//config` directive within a prompt text file is used to tailor the specific configuration environment for the prompt.  All configuration items are available to have their values changed.  The order of value assignment for a configuration item starts with the default value which is replaced by the envar value which is replaced by the command line option value which is replaced by the value from the config file.

The `//config` is the last and final way of changing the value for a configuration item for a specific prompt.

The switch options are treated like booleans.  They are either `true` or `false`. Their name within the context of a `//config` directive always ends with a "?" character - question mark.

To set the value of a switch using ``//config` for example `--terse` or `--chat` to this:

```
//config chat? = true
//config terse? = true
```

A configuration item such as `--out_file` or `--model` has an associated value on the command line.  To set that value with the `//config` directive do it like this:

```
//config model = gpt-3.5-turbo
//config out_file = temp.md
//config backend = mods
```

### Backend Directive Commands

See the source code for the directives supported by the backends which at this time are configuration-based as well.

- [mods](lib/aia/tools/mods.rb)
- [sgpt](lib/aia/tools/sgpt.rb)

FOr example `mods` has a configuration item `topp` which can be set by a directive in a prompt text file directly.

```
//topp 1.5
```

If `mods` is not the backend the `//topp` direcive is ignored.

## All About ROLES

`aia` provides the `--role` CLI option to identify a prompt ID within your prompts directory which defines the context within which the LLM is to provide its response.  The text of the role ID is pre-pended to the text of the primary prompt to form a complete prompt to be processed by the backend.

For example consider:

```shell
aia -r ruby refactor my_class.rb
```

Within the prompts directory the contents of the text file `ruby.txt` will be pre-pre-pended to the contents of the `refactor.txt` file to produce a complete prompt.  That complete prompt will have any parameters then directives processed before sending the prompt text to the backend.

Note that `--role` is just a way of saying add this prompt text file to the front of this other prompt text file.  The contents of the "role" prompt could be anything.  It does not necessarily have be an actual role.

You might consider have a sub-directory of your `prompts_dir` name `role` in which you put the prompt files that describe the various roles that you commonly use with your prompts.  `aia` fully supports a directory tree within the `prompts_dir` as a way of organization or classification of your different prompt text files.

```shell
aia -r roles/sw_eng doc_the_methods my_class.rb
```

In this example the prompt text file `$AIA_PROMPTS_DIR/roles/sw_eng.txt` is prepended to the prompt text file `$AIA_PROMPTS_DIR/doc_the_methods.txt`


### Other Ways to Insert Roles into Prompts

Since `aia` supports parameterized prompts you could make a keyword like "[ROLE]" be part of your prompt.  For example consider this prompt:

```text
As a [ROLE] tell me what you think about [SUBJECT]
```

When this prompt is processed, `aia` will ask you for a value for the keyword "ROLE" and the keyword "SUBJECT" to complete the prompt.  Since `aia` maintains a history your previous answers, you could just choose something that you used in the past or answer with a completely new value.

## External CLI Tools Used

To install the external CLI programs used by aia:
  
  brew install fzf mods rg glow

fzf
  Command-line fuzzy finder written in Go
  [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)

mods
  AI on the command-line
  [https://github.com/charmbracelet/mods](https://github.com/charmbracelet/mods)

rg
  Search tool like grep and The Silver Searcher
  [https://github.com/BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)

glow
  Render markdown on the CLI
  [https://github.com/charmbracelet/glow](https://github.com/charmbracelet/glow)

A text editor whose executable is setup in the
system environment variable 'EDITOR' like this:

  export EDITOR="subl -w"



## Shell Completion

You can setup a completion function in your shell that will complete on the prompt_id saved in your `prompts_dir` - functions for `bash`, `fish` and `zsh` are available.  To get a copy of these functions do this:

```shell
aia --completion bash
```

If you're not a fan of "born again" replace `bash` with one of the others.

Copy the function to a place where it can be installed in your shell's instance.  This might be a `.profile` or `.bashrc` file, etc.

## My Most Powerful Prompt

This is just between you and me so don't go blabbing this around to everyone.  My most power prompt is in a file named `ad_hoc.txt`. It looks like this:

> [WHAT NOW HUMAN]

Yep.  Just a single parameter for which I can provide a value of anything that is on my mind at the time.  Its advantage is that I do not pollute my shell's command history with lots of text.

Which do you think is better to have in your shell's history file?

```shell
mods "As a certified public accountant specializing in forensic audit and analysis of public company financial statements, what do you think of mine?  What is the best way to hide the millions dracma that I've skimmed?"  < financial_statement.txt
```

or

```shell
aia ad_hoc financial_statement.txt
```

Both do the same thing; however, `aia` does not put the text of the prompt into the shell's history file.... of course the keyword/parameter value is saved in the prompt's JSON file and the prompt with the response are logged unless `--no-log` is specified; but, its not messing up the shell history!

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/aia.

I've designed `aia` so that it should be easy to integrate other backend LLM processors.  If you've found one that you like, send me a pull request or a feature request.

When you find problems with `aia` please note them as an issue.  This thing was written mostly by a human and you know how error prone humans are.  There should be plenty of errors to find.

I've been thinking that the REGEX used to identify a keyword within a prompt could be a configuration item.  I chose to use square brackets and uppercase in the default regex; maybe, you have a collection of prompt files that use some other regex.  Why should it be one way and not the other.

Also I'm not happy with the way where I a some command line options for external command hard coded.  I think they should be part of the configuration as well.  For example the way I'm using `rg` and `fzf` may not be the way that you want to use them.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

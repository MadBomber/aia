# aia 1 "2024-01-01" AIA "User Manuals"

## NAME

aia - command-line interface for an AI assistant  

## SYNOPSIS

aia [options]* PROMPT_ID [CONTEXT_FILE]* [-- EXTERNAL_OPTIONS+]  

## DESCRIPTION

The aia command-line tool is an interface for interacting with an AI model backend, providing a simple way to send prompts and receive responses. The CLI supports various options to customize the interaction, load a configuration file, edit prompts, set debugging levels, and more.

## ARGUMENTS

*PROMPT_ID*
: This is a required argument.

*CONTEXT_FILES*
: This is an optional argument.  One or more files can be added to the prompt as context for the backend gen-AI tool to process.

*EXTERNAL_OPTIONS*
: External options are optional.  Anything that follow " -- " will be sent to the backend gen-AI tool.  For example "-- -C -m gpt4-128k" will send the options "-C -m gpt4-128k" to the backend gen-AI tool.  `aia` will not validate these external options before sending them to the backend gen-AI tool.

## OPTIONS

`--chat`
: begin a chat session with the backend after the initial prompt response;  will set --no-out_file so that the backend response comes to STDOUT.

`--completion` *SHELL_NAME*
: Show completion script for bash|zsh|fish - default is nil

`--dump` *FORMAT*
: Dump a Config File in [yaml | toml] to STDOUT - default is nil

`-e`, `--edit`
: Invokes an editor on the prompt file.  You can make changes to the prompt file, save it and the newly saved prompt will be processed by the backend.

`--shell`
: This option tells `aia` to replace references to system environment variables in the prompt with the value of the envar.  envars are like $HOME and ${HOME} in this example their occurance will be replaced by the value of ENV['HOME'].  Also the dynamic shell command in the pattern $(shell command) will be executed and its output replaces its pattern.  It does not matter if your shell uses different patters than BASH since the replacement is being done within a Ruby context.

`--erb`
: If dynamic prompt content using $(...) wasn't enough here is ERB.  Embedded RUby.  <%= ruby code %> within a prompt will have its ruby code executed and the results of that execution will be inserted into the prompt.  I'm sure we will find a way to truly misuse this capability.  Remember, some say that the simple prompt is the best prompt.

`--model` *NAME*
: Name of the LLM model to use - default is gpt-4-1106-preview

`--render`
: Render markdown to the terminal using the external tool "glow" - default: false

`--speak`
: Simple implementation. Uses the "say" command to speak the response.  Fun with --chat

`--terse`
: Add a clause to the prompt text that instructs the backend to be terse in its response.

`--version`
: Print Version - default is false

`-b`, `--[no]-backend` *LLM TOOL*
: Specify the backend prompt resolver - default is mods

`-c`, `--config_file` *PATH_TO_CONFIG_FILE*
: Load Config File - default is nil

`-d`, `--debug`
: Turn On Debugging - default is false

`-e`, `--edit`
: Edit the Prompt File - default is false

`-f`, --fuzzy`
: Use Fuzzy Matching when searching for a prompt - default is false

`-h`, `--help`
: Show Usage - default is false

`-l`, `--[no]-log_file` *PATH_TO_LOG_FILE*
: Log FILEPATH - default is $HOME/.prompts/prompts.log

`-m`, `--[no]-markdown`
: Format with Markdown - default is true

`-o`, `--[no]-out_file` *PATH_TO_OUTPUT_FILE*
: Out FILENAME - default is ./temp.md

`-p`, `--prompts` *PATH_TO_DIRECTORY*
: Directory containing the prompt files - default is ~/.prompts

`-r`, `--role` *ROLE_ID*
: A role ID is the same as a prompt ID.  A "role" is a specialized prompt that gets pre-pended to another prompt.  It's purpose is to configure the LLM into a certain orientation within which to resolve its primary prompt.

`-v`, `--verbose`
: Be Verbose - default is false


## CONFIGURATION HIERARCHY

System Environment Variables (envars) that are all uppercase and begin with "AIA_" can be used to over-ride the default configuration settings.  For example setting "export AIA_PROMPTS_DIR=~/Documents/prompts" will over-ride the default configuration; however, a config value provided by a command line options will over-ride an envar setting.

Configuration values found in a config file will over-ride all other values set for a config item.

"//config" directives found inside a prompt file over-rides that config item regardless of where the value was set.

For example "//config chat? = true" within a prompt will setup the chat back and forth chat session for that specific prompt regardless of the command line options or the envar AIA_CHAT settings

## OpenAI ACCOUNT IS REQUIRED

Additionally, the program requires an OpenAI access key, which can be specified using one of the following environment variables:

- `OPENAI_ACCESS_TOKEN`
- `OPENAI_API_KEY`

Currently there is not specific standard for name of the OpenAI key.  Some programs use one name, while others use a different name.  Both of the envars listed above mean the same thing.  If you use more than one tool to access OpenAI resources, you may have to set several envars to the same key value.

To acquire an OpenAI access key, first create an account on the OpenAI platform, where further documentation is available.

## USAGE NOTES

`aia` is designed for flexibility, allowing users to pass prompt ids and context files as arguments. Some options change the behavior of the output, such as `--out_file` for specifying a file or `--no-out_file` for disabling file output in favor of standard output (STDPIT).

The `--completion` option displays a script that enables prompt ID auto-completion for bash, zsh, or fish shells. It's crucial to integrate the script into the shell's runtime to take effect.

The `--dump` options will send the current configuration to STDOUT in the format requested.  Both YAML and TOML formats are supported.

## PROMPT DIRECTIVES

Within a prompt text file any line that begins with "//" is considered a prompt directive.  There are numerious prompt directives available.  In the discussion above on the configuration you learned about the "//config" directive.

Detail discussion on individual prompt directives is TBD.  Most likely it will be handled in the [github wiki](https://github.com/MadBomber/aia).

## SEE ALSO

- [OpenAI Platform Documentation](https://platform.openai.com/docs/overview) for more information on [obtaining access tokens](https://platform.openai.com/account/api-keys) and working with OpenAI models.

- [mods](https://github.com/charmbracelet/mods) for more information on `mods` - AI for the command line, built for pipelines.  LLM based AI is really good at interpreting the output of commands and returning the results in CLI friendly text formats like Markdown. Mods is a simple tool that makes it super easy to use AI on the command line and in your pipelines. Mods works with [OpenAI](https://platform.openai.com/account/api-keys) and [LocalAI](https://github.com/go-skynet/LocalAI)

- [sgpt](https://github.com/tbckr/sgpt) (aka shell-gpt) is a powerful command-line interface (CLI) tool designed for seamless interaction with OpenAI models directly from your terminal. Effortlessly run queries, generate shell commands or code, create images from text, and more, using simple commands. Streamline your workflow and enhance productivity with this powerful and user-friendly CLI tool.

- [fzf](https://github.com/junegunn/fzf) fzf is a general-purpose command-line fuzzy finder.  It's an interactive Unix filter for command-line that can be used with any list; files, command history, processes, hostnames, bookmarks, git commits, etc.

- [ripgrep](https://github.com/BurntSushi/ripgrep) Search tool like grep and The Silver Searcher. It is a line-oriented search tool that recursively searches a directory tree for a regex pattern. By default, ripgrep will respect gitignore rules and automatically skip hidden files/directories and binary files. (To disable all automatic filtering by default, use rg -uuu.) ripgrep has first class support on Windows, macOS and Linux, with binary downloads available for every release. 

- [glow](https://github.com/charmbracelet/glow) Render markdown on the CLI


## AUTHOR

Dewayne VanHoozer <dvanhoozer@gmail.com>

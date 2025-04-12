# aia 1 "v0.7.0" AIA "User Manuals"

## NAME

aia - command-line AI assistant

## SYNOPSIS

aia [options] PROMPT_ID [CONTEXT_FILE]*

## DESCRIPTION

The aia command-line tool is an interface for interacting with AI models, facilitating the management of pre-compositional prompts and executing generative AI commands. It supports various options to customize interactions, load configuration files, and integrate shell and ERB for dynamic content. Recent updates include enhanced features such as directive processing, history management, shell command execution, and chat processing services.

## ARGUMENTS

*PROMPT_ID*
: This is a required argument.

*CONTEXT_FILES*
: This is an optional argument.  One or more files can be added to the prompt as context for the LLM to process.

## OPTIONS

`--chat`
: Begin a chat session with the LLM after the initial prompt response; will set --no-out_file so that the LLM response comes to STDOUT.


`--completion` *SHELL_NAME*
: Show completion script for bash|zsh|fish - default is nil

`--dump` *PATH/TO/FILE.ext*
: Dump the current configuration to a file in the format denoted by the file's extension.  Currently only .yml, .yaml and .toml are acceptable file extensions.  *If the file exists, it will be over-written without warning.*

`--shell`
: Enables `aia` to access your terminal's shell environment from inside the prompt text, allowing for dynamic content insertion using system environment variables and shell commands. Includes safety features to confirm or block dangerous commands.

`--erb`
: Turns the prompt text file into a fully functioning ERB template, allowing for embedded Ruby code processing within the prompt text. This enables dynamic content generation and complex logic within prompts.

`--iq`, `--image_quality` *VALUE*
: Used with an LLM that supports image generation - default: ''

`--is`, `--image_size` *VALUE*
: Used with an LLM that supports image generation - default: ''

`--model` *NAME*
: Name of the LLM model to use - default is gpt-4o-mini

`--speak`
: Simple implementation. Uses the speech model to convert text to audio, then plays the audio. Fun with --chat. Supports configuration of speech model and voice.

`--sm`, `--speech_model` *MODEL NAME*
: The model to use for text-to-speech (TTS) - default: tts-1

`--voice` *VOICE NAME*
: Which voice to use with the speech model.  If its "siri" and the platform is a Mac, then the CLI utility "say" is used.  Any other name will be used with speech model - default: alloy

`--terse`
: Add a clause to the prompt text that instructs the LLM to be terse in its response.

`--tm`, `--transcription_model` *MODEL NAME*
: Which LLM to use for audio-to-text - default: whisper-1

`--version`
: Print the aia ersion - default is false

`-c`, `--config_file` *PATH_TO_CONFIG_FILE*
: Load Config File. both YAML and TOML formats are supported.  Also ERB is supported.  For example ~/aia_config.yml.erb will be processed through ERB and then through YAML.  The result will be written out to ~/aia_config.yml so that you can manually verify that you got what you wanted from the ERB processing.

`-d`, `--debug`
: Turn On Debugging - default is false

`-f`, --fuzzy`
: Use Fuzzy Matching when searching for a prompt - default is false

`-h`, `--help`
: Show Usage - default is false

`-l`, `--[no]-log_file` *PATH_TO_LOG_FILE*
: Log FILEPATH - default is $AIA_PROMPTS_DIR/_prompts.log

`-m`, `--[no]-markdown`
: Format with Markdown - default is true

`-n`, `--next PROMPT_ID`
: Specifies the next prompt ID to be processed using the response from the previous prompt ID's processing as a context within which to process the next prompt - default is an empty string

`-o`, `--[no]-out_file` *PATH_TO_OUTPUT_FILE*
: Out FILENAME - default is ./temp.md

`--pipeline PID1,PID2,PID3`
: Specifies a pipeline of prompt IDs (PID) in which the respone from the first prompt is fed into the second prompt as context whose response is fed into the third as context, etc.  It is a comma seperated list.  There is no artificial limit to the number of prompt IDs in the pipeline - default is an empty list

`-p`, `--prompts_dir` *PATH_TO_DIRECTORY*
: Directory containing the prompt files - default is ~/.prompts

`--roles_dir` *PATH_TO_DIRECTORY*
: Directory containing the personification prompt files - default is $AIA_PROMPTS_DIR/roles

`-r`, `--role` *ROLE_ID*
: A role ID is the same as a prompt ID.  A "role" is a specialized prompt that gets pre-pended to another prompt.  It's purpose is to configure the LLM into a certain orientation (personality) within which to resolve its primary prompt.

`-v`, `--verbose`
: Be Verbose - default is false

## CONFIGURATION HIERARCHY

System Environment Variables (envars) that are all uppercase and begin with "AIA_" can be used to over-ride the default configuration settings.  For example setting "export AIA_PROMPTS_DIR=~/Documents/prompts" will over-ride the default configuration; however, a config value provided by a command line options will over-ride an envar setting.

Configuration values found in a config file will override all other values set for a config item.

"//config" directives found inside a prompt file override that config item regardless of where the value was set.

For example, "//config chat? = true" within a prompt will set up the chat session for that specific prompt regardless of the command line options or the envar AIA_CHAT settings.

## OpenAI ACCOUNT IS REQUIRED

Additionally, the program requires an OpenAI access key, which can be specified using one of the following environment variables:

- `OPENAI_ACCESS_TOKEN`
- `OPENAI_API_KEY`

Currently there is not specific standard for name of the OpenAI key.  Some programs use one name, while others use a different name.  Both of the envars listed above mean the same thing.  If you use more than one tool to access OpenAI resources, you may have to set several envars to the same key value.

To acquire an OpenAI access key, first create an account on the OpenAI platform, where further documentation is available.

## USAGE NOTES

`aia` is designed for flexibility, allowing users to pass prompt ids and context files as arguments. Some options change the behavior of the output, such as `--out_file` for specifying a file or `--no-out_file` for disabling file output in favor of standard output (STDPIT).

The `--completion` option displays a script that enables prompt ID auto-completion for bash, zsh, or fish shells. It's crucial to integrate the script into the shell's runtime to take effect.

The `--dump path/to/file.ext` option will write the current configuration to a file in the format requested by the file's extension.  The following extensions are supported:  .yml, .yaml and .toml


## PROMPT DIRECTIVES

Within a prompt text file any line that begins with "//" is considered a prompt directive.  There are numerious prompt directives available.  In the discussion above on the configuration you learned about the "//config" directive.

Prompt directives are lines in the prompt text file that begin with "//" and are used to tailor the specific configuration environment for the prompt. Some directives include:

- `//config item value`: Sets configuration items for a specific prompt.
- `//include path_to_file`: Includes the content of a specified file into the prompt.
- `//ruby ruby_code`: Executes Ruby code and includes the result in the prompt.
- `//shell shell_command`: Executes a shell command and includes the output in the prompt.

## Prompt Sequences

The `--next` and `--pipeline` command line options allow for the sequencing of prompts such that the first prompt's response feeds into the second prompt's context and so on.  Suppose you had a complex sequence of prompts with IDs one, two, three and four.  You would use the following `aia` command to process them in sequence:

`aia one --pipeline two,three,four`

Notice that the value for the pipelined prompt IDs has no spaces.  This is so that the command line parser does not mistake one of the promp IDs as a CLI option and issue an error.

### Prompt Sequences Inside of a Prompt File

You can also use the `config` directive inside of a prompt file to specify a sequence.  Given the example above of 4 prompt IDs you could add this directive to the prompt file `one.txt`

`//config next two`

Then inside the prompt file `two.txt` you could use this directive:

`//config pipeline three,four`

or just

`//config next three`

if you want to specify them one at a time.

You can also use the shortcuts `//next` and `//pipeline`

```
//next two
//next three
//next four
//next five
```

Is the same thing as

```
//pipeline two,three,four
//next five
```

## SEE ALSO

- [fzf](https://github.com/junegunn/fzf) fzf is a general-purpose command-line fuzzy finder.  It's an interactive Unix filter for command-line that can be used with any list; files, command history, processes, hostnames, bookmarks, git commits, etc.

- [ripgrep](https://github.com/BurntSushi/ripgrep) Search tool like grep and The Silver Searcher. It is a line-oriented search tool that recursively searches a directory tree for a regex pattern. By default, ripgrep will respect gitignore rules and automatically skip hidden files/directories and binary files. (To disable all automatic filtering by default, use rg -uuu.) ripgrep has first class support on Windows, macOS and Linux, with binary downloads available for every release.

## Image Generation

aia supports image generation using the `dall-e-2` and `dall-e-3` models through OpenAI.  The result of your prompt will be a URL that points to the OpenAI storage space where your image is placed.

Use --image_size and --image_quality to specified the desired size and quality of the generated image.  The valid values are available at the OpenAI website.

https://platform.openai.com/docs/guides/images/usage?context=node

## AUTHOR

Dewayne VanHoozer <dvanhoozer@duck.com>

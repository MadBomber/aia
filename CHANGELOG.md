# Changelog
## [Unreleased]

## Released

### [0.8.2] 2025-04-18
- fixed problems with pre-loaded context and chat repl
- piped content into `aia --chat` is now a part of the context/instructions
- content via "aia --chat < some_file" is added to the context/instructions
- `aia --chat context_file.txt context_file2.txt` now works
- `aia --chat prompt_id context)file.txt` also works



### [0.8.1] 2025-04-17
- bumped version to 0.8.1 after correcting merge conflicts

### [0.8.0] WIP - 2025-04-15
- Updated PromptManager to v0.5.1 which has some of the functionality that was originally developed in the AIA.
- Enhanced README.md to include a comprehensive table of configuration options with defaults and associated environment variables.
- Added a note in README.md about the expandability of configuration options from a config file for dynamic prompt generation.
- Improved shell command protection by ensuring dangerous patterns are checked and confirmed before execution.
- Ensured version consistency across `.version`, `aia.gemspec`, and `lib/aia/version.rb`.
- Verified and updated documentation to ensure readiness for release on RubyGems.org.

### [0.7.1] WIP - 2025-03-22
- Added `UIPresenter` class for handling user interface presentation.
- Added `DirectiveProcessor` class for processing chat-based directives.
- Added `HistoryManager` class for managing conversation and variable history.
- Added `ShellCommandExecutor` class for executing shell commands.
- Added `ChatProcessorService` class for managing conversation processing logic.
- Added `PromptProcessor` class for processing prompts.
- Enhanced `Session` class to manage interactive session logic.
- Updated `Config` class to handle new configuration options and defaults.
- Improved handling of chat prompts and AI interactions.
- Added support for dynamic content processing in prompts, including shell commands and ERB.
- Improved error handling and user feedback for directive processing.
- Enhanced logging and output options for chat sessions.

### [0.7.0] WIP - 2025-03-17
- Major code refactoring for better organization and maintainability:
  - Extracted `DirectiveProcessor` class to handle chat-based directives
  - Extracted `HistoryManager` class for conversation and variable history management
  - Extracted `UIPresenter` class for UI-related functionality
  - Extracted `ChatProcessorService` class for prompt processing and AI interactions
  - Significantly reduced complexity of the `Session` class by applying separation of concerns
- Enhanced the `//clear` directive to properly reset conversation context
- Improved output handling to suppress STDOUT when chat mode is off and output file is specified
- Updated spinner format in the process_prompt method for better user experience

### [0.6.?] WIP
- Implemented Tony Stark's Clean Slate Protocol on the develop branch

### [0.5.17] 2024-05-17
- removed replaced `semver` with `versionaire`

### [0.5.16] 2024-04-02
- fixed prompt pipelines
- added //next and //pipeline directives as shortcuts to //config [next,pipeline]
- Added new backend "client" as an internal OpenAI client
- Added --sm, --speech_model default: tts-1
- Added --tm, --transcription_model default: whisper-1
- Added --voice default: alloy (if "siri" and Mac? then uses cli tool "say")
- Added --image_size and --image_quality (--is --iq)


### [0.5.15] 2024-03-30
- Added the ability to accept piped in text to be appeded to the end of the prompt text: curl $URL | aia ad_hoc
- Fixed bugs with entering directives as follow-up prompts during a chat session

### [0.5.14] 2024-03-09
- Directly access OpenAI to do text to speech when using the `--speak` option
- Added --voice to specify which voice to use
- Added --speech_model to specify which TTS model to use

### [0.5.13] 2024-03-03
- Added CLI-utility `llm` as a backend processor

### [0.5.12] 2024-02-24
- Happy Birthday Ruby!
- Added --next CLI option
- Added --pipeline CLI option

### [0.5.11] 2024-02-18
- allow directives to return information that is inserted into the prompt text
- added //shell command directive
- added //ruby ruby_code directive
- added //include path_to_file directive

### [0.5.10] 2024-02-03
- Added --roles_dir to isolate roles from other prompts if desired
- Changed --prompts to --prompts_dir to be consistent
- Refactored common fzf usage into its own tool class

### [0.5.9] 2024-02-01
- Added a "I'm working" spinner thing when "--verbose" is used as an indication that the backend is in the process of composing its response to the prompt.

### [0.5.8] 2024-01-17
- Changed the behavior of the --dump option.  It must now be followed by path/to/file.ext where ext is a supported config file format: yml, yaml, toml

### [0.5.7] 2024-01-15
- Added ERB processing to the config_file

### [0.5.6] 2024-01-15
- Adding processing for directives, shell integration and erb to the follow up prompt in a chat session
- some code refactoring.

## [0.5.3] 2024-01-14
- adding ability to render markdown to the terminal using the "glow" CLI utility

### [0.5.2] 2024-01-13
- wrap response when its going to the terminal

### [0.5.1] 2024-01-12
- removed a wicked puts "loaded" statement
- fixed missed code when the options were changed to --out_file and --log_file
- fixed completion functions by updating $PROMPT_DIR to $AIA_PROMPTS_DIR to match the documentation.

### [0.5.0] 2024-01-05
- breaking changes:
    - changed `--config` to `--config_file`
    - changed `--env` to `--shell`
    - changed `--output` to `--out_file`
        - changed default `out_file` to `STDOUT`

### [0.4.3] 2023-12-31
- added --env to process embedded system environment variables and shell commands within a prompt.
- added --erb to process Embedded RuBy within a prompt because have embedded shell commands will only get you in a trouble.  Having ERB will really get you into trouble.  Remember the simple prompt is usually the best prompt.

### [0.4.2] 2023-12-31
- added the --role CLI option to pre-pend a "role" prompt to the front of a primary prompt.

### [0.4.1] 2023-12-31
- added a chat mode
- prompt directives now supported
- version bumped to match the `prompt_manager` gem

### [0.3.20] 2023-12-28
- added work around to issue with multiple context files going to the `mods` backend
- added shellwords gem to santize prompt text on the command line

### [0.3.19] 2023-12-26
- major code refactoring.
- supports config files \*.yml, \*.yaml and \*.toml
- usage implemented as a man page. --help will display the man page/
- added "--dump <yml|yaml|toml>" to send current configuration to STDOUT
- added "--completion <bash|fish|zsh>" to send a a completion function for the indicated shell to STDOUT
- added system environment variable (envar) over-rides of default config values uppercase environment variables prefixed with "AIA_" + config item name for example AIA_PROMPTS_DIR and AIA_MODEL.  All config items can be over-ridden by their cooresponding envars.
- config value hierarchy is:
    1. values from config file  over-rides ...
    2. command line values      over-rides ...
    3. envar values             over-rides ...
    4. default values

### [0.3.0] = 2023-11-23

- Matching version to [prompt_manager](https://github.com/prompt_manager) This version allows for the user of history in the entery of values to prompt keywords.  KW_HISTORY_MAX is set at 5.  Changed CLI enteraction to use historical selection and editing of prior keyword values.

### [0.1.0] - 2023-11-23

- Initial release

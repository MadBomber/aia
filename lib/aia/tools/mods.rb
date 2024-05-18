# lib/aia/tools/mods.rb

=begin
  The mods --role parameter is much different than the
  aia usage of --role which inserts a prompt in front
  of the given prompt.

  What mods does is within its settings file it has
  different "system prompts" defined by name under
  the "roles" section of its YAML file.  The standard
  values for this section are empty - e.g. none
  are predefined.  If you choose to add a role
  to the mods settings, it will be sent in the
  request as a "system" prompt in addition to the
  normal "user" prompt.

  To use the mods role with aia do this:

      aia prompt_name -b mods -- --role role_name

  Where role_name is the name you gave your system
  prompt in the mods settings YAML file.

  You can use both the aia --role and the mods --role
  option at the same time.

    aia --role role_file_name prompt_name -b mods -- --role mods_role_name

  The content of role_file_name will be prepended to
  the content of the prompt_name file and used as
  the "user" prompt.  The content associated with
  with the mods_role_name will be used as the "system"
  prompt in the request.

=end

require_relative 'backend_common'

class AIA::Mods < AIA::Tools
  include AIA::BackendCommon

  meta(
    name:     'mods',
    role:     :backend,
    desc:     'GPT on the command line. Built for pipelines.',
    url:      'https://github.com/charmbracelet/mods',
    install:  'brew install mods',
  )

  
  DEFAULT_PARAMETERS = [
    # "--no-cache",           # do not save prompt and response
    "--no-limit",             # no limit on input context
    "--quiet",                # Quiet mode (hide the spinner while loading and stderr messages for success).
  ].join(' ').freeze


  DIRECTIVES = %w[
    api
    ask-model
    continue
    continue-last
    fanciness
    format-as
    http-proxy
    max-retries
    max-retries
    max-tokens
    max-tokens 
    model
    no-cache
    no-limit  
    prompt
    prompt-args
    quiet
    raw
    status-text
    temp
    title
    topp
    word-wrap
  ]
end

__END__


##########################################################

mods version 1.3.1 (Homebre)

GPT on the command line. Built for pipelines.

Usage:
  mods [OPTIONS] [PREFIX TERM]

Options:
  -m, --model           Default model (gpt-3.5-turbo, gpt-4, ggml-gpt4all-j...).
  -M, --ask-model       Ask which model to use with an interactive prompt.
  -a, --api             OpenAI compatible REST API (openai, localai).
  -x, --http-proxy      HTTP proxy to use for API requests.
  -f, --format          Ask for the response to be formatted as markdown unless otherwise set.
  --format-as
  -r, --raw             Render output as raw text when connected to a TTY.
  -P, --prompt          Include the prompt from the arguments and stdin, truncate stdin to specified number of lines.
  -p, --prompt-args     Include the prompt from the arguments in the response.
  -c, --continue        Continue from the last response or a given save title.
  -C, --continue-last   Continue from the last response.
  -l, --list            Lists saved conversations.
  -t, --title           Saves the current conversation with the given title.
  -d, --delete          Deletes a saved conversation with the given title or ID.
  --delete-older-than   Deletes all saved conversations older than the specified duration. Valid units are: ns, us, µs, μs, ms, s, m, h, d, w, mo, and y.
  -s, --show            Show a saved conversation with the given title or ID.
  -S, --show-last       Show the last saved conversation.
  -q, --quiet           Quiet mode (hide the spinner while loading and stderr messages for success).
  -h, --help            Show help and exit.
  -v, --version         Show version and exit.
  --max-retries         Maximum number of times to retry API calls.
  --no-limit            Turn off the client-side limit on the size of the input into the model.
  --max-tokens          Maximum number of tokens in response.
  --word-wrap           Wrap formatted output at specific width (default is 80)
  --temp                Temperature (randomness) of results, from 0.0 to 2.0.
  --stop                Up to 4 sequences where the API will stop generating further tokens.
  --topp                TopP, an alternative to temperature that narrows response, from 0.0 to 1.0.
  --fanciness           Your desired level of fanciness.
  --status-text         Text to show while generating.
  --no-cache            Disables caching of the prompt/response.
  --reset-settings      Backup your old settings file and reset everything to the defaults.
  --settings            Open settings in your $EDITOR.
  --dirs                Print the directories in which mods store its data
  --role                System role to use.

Example:
  # Write new sections for a readme
  cat README.md | mods "write a new section to this README documenting a pdf sharing feature"

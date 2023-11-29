# lib/aia/external/mods.rb

class AIA::External::Mods < AIA::External::Tool
  def initialize
    super
    @role = :search
    @desc = 'AI on the command-line'
    @url  = 'https://github.com/charmbracelet/mods'
  end

  def command(extra_options = [])
    model = ENV['MODS_MODEL'] || 'gpt-4-1106-preview'
    ai_default_opts = "-m #{model} --no-limit -f"
    "#{name} #{ai_default_opts} #{extra_options.join(' ')}"
  end
end

__END__

GPT on the command line. Built for pipelines.

Usage:
  mods [OPTIONS] [PREFIX TERM]

Options:
  -m, --model                                  Default model (gpt-3.5-turbo, gpt-4, ggml-gpt4all-j...).
  -a, --api                                    OpenAI compatible REST API (openai, localai).
  -x, --http-proxy                             HTTP proxy to use for API requests.
  -f, --format                                 Ask for the response to be formatted as markdown unless otherwise set.
  -r, --raw                                    Render output as raw text when connected to a TTY.
  -P, --prompt                                 Include the prompt from the arguments and stdin, truncate stdin to specified number of lines.
  -p, --prompt-args                            Include the prompt from the arguments in the response.
  -c, --continue                               Continue from the last response or a given save title.
  -C, --continue-last                          Continue from the last response.
  -l, --list                                   Lists saved conversations.
  -t, --title                                  Saves the current conversation with the given title.
  -d, --delete                                 Deletes a saved conversation with the given title or ID.
  -s, --show                                   Show a saved conversation with the given title or ID.
  -S, --show-last                              Show a the last saved conversation.
  -q, --quiet                                  Quiet mode (hide the spinner while loading and stderr messages for success).
  -h, --help                                   Show help and exit.
  -v, --version                                Show version and exit.
  --max-retries                                Maximum number of times to retry API calls.
  --no-limit                                   Turn off the client-side limit on the size of the input into the model.
  --max-tokens                                 Maximum number of tokens in response.
  --temp                                       Temperature (randomness) of results, from 0.0 to 2.0.
  --topp                                       TopP, an alternative to temperature that narrows response, from 0.0 to 1.0.
  --fanciness                                  Your desired level of fanciness.
  --status-text                                Text to show while generating.
  --no-cache                                   Disables caching of the prompt/response.
  --reset-settings                             Backup your old settings file and reset everything to the defaults.
  --settings                                   Open settings in your $EDITOR.
  --dirs                                       Print the directories in which mods store its data

Example:
  # Editorialize your video files
  ls ~/vids | mods -f "summarize each of these titles, group them by decade" | glow

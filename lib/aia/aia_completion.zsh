# lib/aia/aia_completion.zsh
# Setup a prompt completion for use with
# the zsh shell
#
# This script assumes that the system environment
# variable AIA_PROMPTS__DIR has been set correctly

_aia_completion() {
  # The current word being completed
  local cur_word="$words[$CURRENT]"

  # The previous word before the current word
  local prev_word="$words[$CURRENT-1]"

  # Store the previous directory to return to it later
  local initial_pwd=$PWD

  # Check if we are currently completing the option that requires prompt IDs
  if [[ "$prev_word" == "aia" ]]; then
    # Change directory to the prompts directory
    cd "$AIA_PROMPTS__DIR" || return

    # Generate a list of relative paths from the ~/.prompts directory (without .txt extension)
    local files=($(find . -name "*.txt" -type f | sed 's|^\./||' | sed 's/\.txt$//'))

    # Change back to the initial directory
    cd "$initial_pwd" || return

    # Generate possible matches and store them in an array
    _describe 'prompt ID' files
  else
    # If not the specific option, use the standard filename completion
    _files
  fi
}

# Register the completion function for the aia command using compctl
compctl -K _aia_completion aia


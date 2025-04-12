# lib/aia/aia_completion.bash
# Setup a prompt completion for use with
# the bash shell
#
# This script assumes that the system environment
# variable AIA_PROMPTS_DIR has been set correctly

_aia_completion() {
  # The current word being completed
  local cur_word="${COMP_WORDS[COMP_CWORD]}"

  # The previous word before the current word
  local prev_word="${COMP_WORDS[COMP_CWORD-1]}"

  # Store the previous directory to return to it later
  local initial_pwd=$(pwd)

  # Check if we are currently completing the option that requires prompt IDs
  if [[ "$prev_word" == "aia" ]]; then
    # Change directory to the prompts directory
    cd "$AIA_PROMPTS_DIR" || return

    # Generate a list of relative paths from the ~/.prompts directory (without .txt extension)
    local files=($(find . -name "*.txt" -type f | sed 's|^\./||' | sed 's/\.txt$//'))

    # Change back to the initial directory
    cd "$initial_pwd" || return

    # Generate possible matches and store them in the COMPREPLY array
    COMPREPLY=($(compgen -W "${files[*]}" -- "$cur_word"))
  else
    # If not the specific option, perform regular file completion
    COMPREPLY=($(compgen -o default -- "$cur_word"))
  fi
}

# Register the completion function for the aia command
complete -F _aia_completion aia


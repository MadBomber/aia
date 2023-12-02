# lib/aia/external.rb

# TODO: move stuff associated with the CLI options for
#       external commands to this module.
#       Is the EDITOR considered an external command? Yes.

=begin

There are at least 4 processes handled by external tools:

  search .......... default PromptManager::Prompt or search_proc
  review/select ... using fzf either exact or fuzzy
  edit ............ ENV['EDITOR']
  execute ......... mods or sgpt or ???
                      with different models / settings

  sgpt is the executable for "shell-gpt" a python project

=end

module AIA::External
  # class Tool;    end
  # class Editor;  end
  # class Fzf;     end
  # class Mods;    end
  # class Rg;      end
end


require_relative 'external/tool'



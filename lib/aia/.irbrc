module AIA
end

require_relative 'cli'
 
AIA::CLI.setup_cli_options([])

require_relative 'config'


# lib/aia/external_two.rb
#
# Maybe something like this ...
#
# or a class structure based upon function where the external
# tool and its default options can be injected.
#
module AIA::External
  EDITOR = ENV['EDITOR']


end

# Usage example:

# Verify and install tools if needed
mods = AIA::External::Mods.new
fzf = AIA::External::Fzf.new
rg = AIA::External::Rg.new
tools = [mods, fzf, rg]
AIA::External.verify_tools(tools)

# Build command for Mods tool with extra_options
extra_options = ['--some-extra-option']
mods_command = mods.command(extra_options)
puts "Mods command: #{mods_command}"

# Open a file with the system editor
AIA::External::Editor.open('path/to/file.txt')

# Search and select a file using Fzf tool
fzf_options = {
  prompt_dir: 'path/to/prompts',
  fuzzy: true
}
fzf_command = fzf.command(fzf_options)
puts "Fzf command: #{fzf_command}"

# Use Rg tool to search within files
search_term = 'search_query'
rg_command = rg.command(search_term, fzf_options: fzf.options)
puts "Rg command: #{rg_command}"


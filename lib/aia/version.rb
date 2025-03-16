# lib/aia/version.rb
#
# This file defines the version of the AIA application.

# The AIA module serves as the namespace for the AIA application, which
# provides an interface for interacting with AI models and managing prompts.
module AIA
  # The VERSION constant defines the current version of the AIA application,
  # which is read from the .version file in the project root.
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', '..', '.version')).strip
end

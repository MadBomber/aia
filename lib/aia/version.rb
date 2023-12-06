# lib/aia/version.rb
# frozen_string_literal: true

require 'semver'

module AIA
  # .semver is located at the gem's root directory
  version_file_path = File.join(__dir__, '..', '..')
  VERSION = SemVer.find(version_file_path).to_s[1..]
end

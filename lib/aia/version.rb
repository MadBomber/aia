# lib/aia/version.rb
# frozen_string_literal: true

require 'semver'

module AIA
  VERSION = SemVer.find.to_s[1..]
end

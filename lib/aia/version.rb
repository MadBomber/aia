# lib/aia/version.rb
# frozen_string_literal: true

require 'versionaire'

module AIA
  VERSION_FILEPATH  = "#{__dir__}/../../.version"
  VERSION           = Versionaire::Version File.read(VERSION_FILEPATH).strip
  def self.version  = VERSION
end

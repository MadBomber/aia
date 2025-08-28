# lib/aia/directives/web_and_file.rb

require 'faraday'
require 'active_support/all'

module AIA
  module Directives
    module WebAndFile
      PUREMD_API_KEY = ENV.fetch('PUREMD_API_KEY', nil)

      def self.webpage(args, context_manager = nil)
          if PUREMD_API_KEY.nil?
            "ERROR: PUREMD_API_KEY is required in order to include a webpage"
          else
            url = `echo #{args.shift}`.strip
            puremd_url = "https://pure.md/#{url}"

            response = Faraday.get(puremd_url) do |req|
              req.headers['x-puremd-api-token'] = PUREMD_API_KEY
            end

            if 200 == response.status
              response.body
            else
              "Error: Status was #{response.status}\n#{ap response}"
            end
          end
        end

      def self.include(args, context_manager = nil)
          # echo takes care of envars and tilde expansion
          file_path = `echo #{args.shift}`.strip

          if file_path.start_with?(/http?:\/\//)
            webpage(args)
          else
            include_file(file_path)
          end
        end

        def self.include_file(file_path)
          @included_files ||= []
          if @included_files.include?(file_path)
            ""
          else
            if File.exist?(file_path) && File.readable?(file_path)
              @included_files << file_path
              File.read(file_path)
            else
              "Error: File '#{file_path}' is not accessible"
            end
          end
        end

      def self.included_files
        @included_files ||= []
      end

      def self.included_files=(files)
        @included_files = files
      end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias_method :website, :webpage
        alias_method :web, :webpage  
        alias_method :import, :include
      end
    end
  end
end

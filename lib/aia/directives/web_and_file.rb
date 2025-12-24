# lib/aia/directives/web_and_file.rb

require 'faraday'
# require 'active_support/all'
require 'clipboard'

module AIA
  module Directives
    module WebAndFile
      PUREMD_API_KEY = ENV.fetch('PUREMD_API_KEY', nil)

      def self.webpage(args, _context_manager = nil)
        if PUREMD_API_KEY.nil?
          'ERROR: PUREMD_API_KEY is required in order to include a webpage'
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


      def self.include(args, _context_manager = nil)
        # echo takes care of envars and tilde expansion
        file_path = `echo #{args.shift}`.strip

        if file_path.start_with?(%r{http?://})
          webpage(args)
        else
          include_file(file_path)
        end
      end


      def self.include_file(file_path)
        @included_files ||= []
        if @included_files.include?(file_path)
          ''
        elsif File.exist?(file_path) && File.readable?(file_path)
          @included_files << file_path
          File.read(file_path)
        else
          "Error: File '#{file_path}' is not accessible"
        end
      end


      def self.included_files
        @included_files ||= []
      end


      def self.included_files=(files)
        @included_files = files
      end


      def self.paste(_args = [], _context_manager = nil)

        content = Clipboard.paste
        content.to_s
      rescue StandardError => e
        "Error: Unable to paste from clipboard - #{e.message}"

      end

      # Set up aliases - these work on the module's singleton class
      class << self
        alias website webpage
        alias web webpage
        alias import include
        alias clipboard paste
      end
    end
  end
end

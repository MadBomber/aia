# lib/aia/tools.rb

class AIA::Tools
  @@subclasses = []

  def self.inherited(subclass)
    @@subclasses << subclass
  end

  attr_reader :role, :name, :description, :url, :install
  

  def initialize(*)
    @role         = :role
    @name         = self.class.name.split('::').last.downcase
    @description  = "description"
    @url          = "URL"
    @install      = "brew install #{name}"
  end


  def installed?
    path = `which #{name}`.chomp
    !path.empty? && File.executable?(path)
  end


  def help
    `#{name} --help`
  end
  

  def version
    `#{name} --version`
  end


  #########################################
  class << self
    def tools
      @@subclasses.map(&:name)
    end


    def verify_tools
      missing_tools = @@subclasses.map(&:new).reject(&:installed?)
      unless missing_tools.empty?
        puts format_missing_tools_response(missing_tools)
      end
    end


    def format_missing_tools_response(missing_tools)
      response = <<~EOS

        WARNING: AIA makes use of external CLI tools that are missing.

        Please install the following tools:

      EOS

      missing_tools.each do |tool|
        response << "  #{tool.name}: install from #{tool.url}\n"
      end

      response
    end
  end
end


(Pathname.new(__dir__)+"tools")
  .glob('*.rb')
  .each do |tool|
    require_relative "tools/#{tool.basename.to_s}" 
  end

